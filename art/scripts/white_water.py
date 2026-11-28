"""White water for the riffle: a scrolling foam strip and a spray sprite, both made by code.

    python art/scripts/white_water.py            # writes art/textures/white_water/

These are plain images with alpha for a Beam, a Texture or a ParticleEmitter. They are not
a MaterialVariant, so they do not go through texture_pipeline.py; the settings live under
`effects.white_water` in texture_families.json.

    white_water_foam.png    512 x 512 RGBA, white on transparent. Soft streaks run along
                            the image's X axis (U): scroll it along U. It wraps exactly in
                            U. In V the foam fades out to nothing at the top and bottom
                            edge behind a ragged line, so one tile is a soft-edged strip
                            (a Beam) and several tiles stacked in V are lanes of foam with
                            no seam.
    white_water_spray.png   128 x 128 RGBA, white on transparent. One puff of spray: a
                            soft core and a scatter of droplets, clear at the border.
    white_water_tile3.jpg   preview over creek water: the foam 3 x 3, the spray enlarged
                            and scattered. Seam check only, do not upload.
    white_water.json        settings and measured numbers.

The colour channels are pure white everywhere (also where alpha is 0), so no dark fringe
shows when the engine filters the edges. Tint and fade it in the engine.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from texture_pipeline import REPO, TABLE, blur_wrap, tile_noise  # noqa: E402

try:
    import numpy as np
    from PIL import Image
except ModuleNotFoundError:
    import site

    sys.path.append(site.getusersitepackages())
    import numpy as np
    from PIL import Image

OUT = REPO / "art" / "textures" / "white_water"
CREEK_WATER = (44, 60, 46)        # the creek water 64,84,58 in shade, for previews only

DEFAULTS = {
    "foam_size": 512, "spray_size": 128, "seed": 7,
    "cover": 0.68,                # share of the strip that carries any foam at all
    "streak": 16.0,               # how many times longer than wide the streaks are
    "wander": 7.0,                # how far the streaks wander sideways, pixels at 512
    "edge": 0.045,                # clear margin at the top and bottom edge, share of the tile
    "edge_ragged": 0.07,          # how far the ragged edge reaches in beyond the margin
    "peak": 0.92,                 # the most opaque the foam gets
    "spray_drops": 34,
}


def smooth(x: np.ndarray) -> np.ndarray:
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def sample_wrap(a: np.ndarray, rows: np.ndarray, cols: np.ndarray) -> np.ndarray:
    """Bilinear lookup that wraps on both axes."""
    h, w = a.shape
    r0, c0 = np.floor(rows).astype(int), np.floor(cols).astype(int)
    fr, fc = rows - r0, cols - c0
    r0, c0, r1, c1 = r0 % h, c0 % w, (r0 + 1) % h, (c0 + 1) % w
    return ((a[r0, c0] * (1 - fc) + a[r0, c1] * fc) * (1 - fr)
            + (a[r1, c0] * (1 - fc) + a[r1, c1] * fc) * fr)


def make_foam(cfg: dict) -> np.ndarray:
    """Alpha of the foam strip, 0..1. Flow runs along X."""
    size, seed = int(cfg["foam_size"]), int(cfg["seed"])
    k = size / 512.0
    st = float(cfg["streak"])
    long_ = tile_noise(size, 2.4 * k, seed, stretch=(1.0, st))             # the streaks
    thread = tile_noise(size, 1.1 * k, seed + 1, stretch=(1.0, st * 0.7))  # fine threads in them
    clump = tile_noise(size, 5.0 * k, seed + 2, stretch=(1.0, 2.5))        # clots of foam
    gather = tile_noise(size, 20.0 * k, seed + 3, stretch=(1.0, 3.5))      # where the foam gathers
    field = 0.60 * long_ + 0.30 * thread + 0.36 * clump + 0.50 * gather

    # let the streaks wander a little, so they read as water and not as brushed metal
    rows, cols = np.meshgrid(np.arange(size, dtype=np.float64), np.arange(size, dtype=np.float64), indexing="ij")
    wander = tile_noise(size, 30.0 * k, seed + 4, stretch=(1.0, 2.0)) * float(cfg["wander"]) * k
    field = sample_wrap(field, rows + wander, cols)

    lo = float(np.quantile(field, 1.0 - float(cfg["cover"])))
    hi = float(np.quantile(field, 0.975))
    alpha = smooth((field - lo) / (hi - lo)) ** 1.15            # a long soft ramp: little of it is solid white

    # lace: small holes inside the foam where the bubbles have burst
    holes = tile_noise(size, 2.6 * k, seed + 5, stretch=(1.0, 1.6))
    alpha *= 1.0 - 0.45 * smooth((holes - 0.7) / 0.9)
    alpha = blur_wrap(alpha[..., None], 0.8 * k)[..., 0]

    # the strip's soft, ragged top and bottom edge (each edge has its own line; both wrap in X)
    rag = tile_noise(size, 14.0 * k, seed + 6, stretch=(1.0, 2.0))
    v = (np.arange(size) + 0.5) / size
    top = v[:, None] - float(cfg["edge"]) - float(cfg["edge_ragged"]) * (0.5 + 0.5 * np.tanh(rag[0][None, :]))
    bot = (1.0 - v)[:, None] - float(cfg["edge"]) - float(cfg["edge_ragged"]) * (0.5 + 0.5 * np.tanh(rag[size // 2][None, :]))
    alpha *= smooth(top / 0.11) * smooth(bot / 0.11)
    alpha[0, :] = alpha[-1, :] = 0.0
    return np.clip(alpha * float(cfg["peak"]), 0.0, 1.0)


def make_spray(cfg: dict) -> np.ndarray:
    """Alpha of the spray puff, 0..1: a soft core, droplets around it, clear at the border."""
    size, seed = int(cfg["spray_size"]), int(cfg["seed"]) + 40
    rng = np.random.default_rng(seed)
    k = size / 128.0
    yy, xx = np.meshgrid(np.arange(size) + 0.5, np.arange(size) + 0.5, indexing="ij")
    c = size / 2.0
    r = np.hypot(xx - c, yy - c)
    mist = tile_noise(size, 7.0 * k, seed + 1)
    alpha = 0.34 * np.exp(-(r / (23.0 * k)) ** 2) * (1.0 + 0.45 * mist)
    alpha += 0.18 * np.exp(-(r / (38.0 * k)) ** 2) * np.clip(0.6 + 0.5 * tile_noise(size, 4.0 * k, seed + 2), 0.0, 1.5)
    for _ in range(int(cfg["spray_drops"])):
        ang = rng.uniform(0.0, 2.0 * np.pi)
        dist = abs(rng.normal(0.0, 24.0 * k)) + 4.0 * k
        if dist > 50.0 * k:
            continue
        cx, cy = c + dist * np.cos(ang), c + dist * np.sin(ang)
        rad = rng.uniform(1.3, 3.4) * k * (1.0 - 0.4 * dist / (50.0 * k))
        alpha += rng.uniform(0.3, 0.7) * np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (rad * rad)))
    alpha *= smooth((60.0 * k - r) / (16.0 * k))            # nothing reaches the border
    return np.clip(alpha, 0.0, 1.0)


def rgba(alpha: np.ndarray) -> Image.Image:
    a = np.clip(np.rint(alpha * 255.0), 0, 255).astype(np.uint8)
    out = np.full(a.shape + (4,), 255, dtype=np.uint8)
    out[..., 3] = a
    return Image.fromarray(out, "RGBA")


def over(alpha: np.ndarray, rgb=CREEK_WATER) -> Image.Image:
    a = alpha[..., None]
    img = (1.0 - a) * np.array(rgb, dtype=np.float64)[None, None, :] + a * 255.0
    return Image.fromarray(np.clip(np.rint(img), 0, 255).astype(np.uint8), "RGB")


def spray_scatter(spray: np.ndarray, size: int, count: int = 22, seed: int = 3) -> np.ndarray:
    """A handful of puffs at different sizes, the way an emitter would throw them (preview)."""
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size))
    for _ in range(count):
        s = int(rng.uniform(0.18, 0.5) * size)
        puff = np.asarray(Image.fromarray((spray * 255).astype(np.uint8), "L").resize((s, s), Image.LANCZOS),
                          dtype=np.float64) / 255.0 * rng.uniform(0.35, 0.9)
        x, y = int(rng.uniform(0, size - s)), int(rng.uniform(0.25 * size, size - s))
        out[y:y + s, x:x + s] = 1.0 - (1.0 - out[y:y + s, x:x + s]) * (1.0 - puff)
    return out


def main() -> None:
    with open(TABLE, "r", encoding="utf-8") as f:
        table = json.load(f)
    cfg = dict(DEFAULTS)
    cfg.update({k: v for k, v in table.get("effects", {}).get("white_water", {}).items() if k in DEFAULTS})

    foam, spray = make_foam(cfg), make_spray(cfg)
    OUT.mkdir(parents=True, exist_ok=True)
    rgba(foam).save(OUT / "white_water_foam.png", optimize=True)
    rgba(spray).save(OUT / "white_water_spray.png", optimize=True)

    cell = 256
    prev = Image.new("RGB", (cell * 6 + 16, cell * 3), (20, 20, 20))
    small = over(foam).resize((cell, cell), Image.LANCZOS)
    for iy in range(3):
        for ix in range(3):
            prev.paste(small, (ix * cell, iy * cell))
    prev.paste(over(spray).resize((cell * 3 // 2, cell * 3 // 2), Image.LANCZOS), (cell * 3 + 16, 0))
    prev.paste(over(spray_scatter(spray, cell * 3 // 2)), (cell * 3 + 16 + cell * 3 // 2, 0))
    strip = over(np.tile(foam, (1, 3))).resize((cell * 3, cell), Image.LANCZOS)       # one strip, three tiles long
    prev.paste(strip, (cell * 3 + 16, cell * 3 // 2 + (cell * 3 // 2 - cell) // 2))
    prev.save(OUT / "white_water_tile3.jpg", quality=90)

    wrap_u = float(np.abs(foam[:, 0] - foam[:, -1]).mean())
    inner_u = float(np.abs(np.diff(foam, axis=1)).mean())
    stats = {
        "effect": "white_water",
        "source": "procedural: art/scripts/white_water.py",
        "licence": "ours",
        "settings": cfg,
        "foam": {
            "file": "white_water_foam.png", "size": [foam.shape[1], foam.shape[0]], "mode": "RGBA",
            "flow_axis": "U (image X)",
            "alpha_mean": round(float(foam.mean()), 4), "alpha_max": round(float(foam.max()), 4),
            "cover_over_0.1": round(float((foam > 0.1).mean()), 4),
            "wrap_step_u": round(wrap_u, 5), "inner_step_u": round(inner_u, 5),
            "edge_rows_alpha_max": round(float(max(foam[0].max(), foam[-1].max())), 4),
        },
        "spray": {
            "file": "white_water_spray.png", "size": [spray.shape[1], spray.shape[0]], "mode": "RGBA",
            "alpha_mean": round(float(spray.mean()), 4), "alpha_max": round(float(spray.max()), 4),
            "border_alpha_max": round(float(max(spray[0].max(), spray[-1].max(), spray[:, 0].max(), spray[:, -1].max())), 4),
        },
    }
    with open(OUT / "white_water.json", "w", encoding="utf-8") as f:
        json.dump(stats, f, indent=2)
        f.write("\n")
    print(f"white_water      foam {stats['foam']['size']} alpha mean {stats['foam']['alpha_mean']} "
          f"cover {stats['foam']['cover_over_0.1']} wrap step {stats['foam']['wrap_step_u']} "
          f"(inner {stats['foam']['inner_step_u']})  spray {stats['spray']['size']} "
          f"alpha mean {stats['spray']['alpha_mean']} border {stats['spray']['border_alpha_max']}")


if __name__ == "__main__":
    main()
