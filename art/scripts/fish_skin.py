"""Procedural fish skin: a tileable field of overlapping scales.

No photo scan fits (scans carry one species' colours, and our fish are vertex coloured
per species), so this makes the source maps by code. `texture_pipeline.py fish_skin`
runs it and then treats the result like any scan.

    python art/scripts/fish_skin.py            # writes artifacts/textures_src/fish_skin_proc/

Writes (1024 px, the pipeline sizes it to 512):
    fish_skin_Color.png             near-grey: a small tone step from scale to scale, nothing else
    fish_skin_NormalGL.png          OpenGL normals from the scale height field
    fish_skin_Roughness.png         low (wet sheen), a little rougher in the creases
    fish_skin_AmbientOcclusion.png  the creases where one scale tucks under the next

How the scales are laid out: columns of round scales along U, every other column shifted
half a scale along V. Each scale tilts up toward its free edge, and the highest surface
wins, so each scale covers the root of the one behind it. Free edges point toward -U:
put the fish's head toward +U if you want the scales to lie the right way (the family
materials are box-mapped, so check this on the first fish in Studio).

Knobs are the constants below. COLS must be even or the tile will not wrap.
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    import numpy as np
    from PIL import Image
except ModuleNotFoundError:  # python -I hides the per-user site-packages
    import site

    sys.path.append(site.getusersitepackages())
    import numpy as np
    from PIL import Image

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "artifacts" / "textures_src" / "fish_skin_proc"

SIZE = 1024
COLS = 12          # scale columns along U (must be even)
ROWS = 6           # scales per column along V
RADIUS = 0.60      # scale radius, as a fraction of the row spacing
TILT = 0.55        # how much each scale rises toward its free edge
DOME = 0.45        # how rounded each scale is
HEIGHT_PX = 9.0    # height range in pixels at SIZE; sets the normal strength
TONE_STEP = 0.035  # per-scale brightness step (plus or minus)
ROUGH_BASE = 0.28
ROUGH_CREASE = 0.30
SEED = 7


def blur_wrap(a: np.ndarray, sigma: float) -> np.ndarray:
    h, w = a.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.rfftfreq(w)[None, :]
    g = np.exp(-2.0 * (np.pi ** 2) * (sigma ** 2) * (fx ** 2 + fy ** 2))
    return np.fft.irfft2(np.fft.rfft2(a) * g, s=(h, w))


def build() -> dict:
    rng = np.random.default_rng(SEED)
    du = SIZE / COLS
    dv = SIZE / ROWS
    r = RADIUS * dv
    v, u = np.mgrid[0:SIZE, 0:SIZE].astype(np.float64) + 0.5

    best = np.full((SIZE, SIZE), -1e9)
    tone = np.zeros((SIZE, SIZE))
    for j in range(COLS):
        for i in range(ROWS):
            cu = (j + 0.5) * du
            cv = (i + 0.5 + 0.5 * (j % 2)) * dv
            # a little hand-made wobble so the grid does not look stamped
            cu += rng.uniform(-0.05, 0.05) * du
            cv += rng.uniform(-0.04, 0.04) * dv
            rr = r * rng.uniform(0.96, 1.04)
            pu = ((u - cu + SIZE / 2) % SIZE) - SIZE / 2
            pv = ((v - cv + SIZE / 2) % SIZE) - SIZE / 2
            p = -pu                                   # toward the free edge (-U)
            d = np.sqrt(pu * pu + (pv * 0.92) ** 2) / rr
            inside = d < 1.0
            h = TILT * (p / rr) + DOME * np.sqrt(np.clip(1.0 - d ** 3, 0.0, 1.0))
            h += rng.uniform(-0.03, 0.03)
            h = np.where(inside, h, -1e9)
            win = h > best
            best = np.where(win, h, best)
            tone = np.where(win, rng.uniform(-1.0, 1.0), tone)

    height = best - best.min()
    height = height / height.max()
    height = blur_wrap(height, 1.6)

    # creases: where the surface sits below its neighbourhood
    crease = np.clip((blur_wrap(height, 7.0) - height) * 6.0, 0.0, 1.0)
    crease = blur_wrap(crease, 1.2)

    hp = height * HEIGHT_PX
    dx = (np.roll(hp, -1, axis=1) - np.roll(hp, 1, axis=1)) * 0.5
    drow = (np.roll(hp, -1, axis=0) - np.roll(hp, 1, axis=0)) * 0.5
    n = np.stack([-dx, drow, np.ones_like(hp)], axis=-1)   # OpenGL: green points up the image
    n /= np.linalg.norm(n, axis=-1, keepdims=True)

    tone = blur_wrap(tone, 1.5)
    color = 0.80 * (1.0 + TONE_STEP * tone)
    rough = ROUGH_BASE + ROUGH_CREASE * crease + 0.03 * tone
    ao = 1.0 - 0.85 * crease
    return {
        "Color": np.repeat(np.clip(color, 0, 1)[..., None], 3, axis=2),
        "NormalGL": (n + 1.0) * 0.5,
        "Roughness": np.clip(rough, 0, 1),
        "AmbientOcclusion": np.clip(ao, 0, 1),
    }


def main() -> None:
    if COLS % 2:
        raise SystemExit("COLS must be even or the tile will not wrap")
    OUT.mkdir(parents=True, exist_ok=True)
    for name, a in build().items():
        u8 = np.clip(np.rint(a * 255.0), 0, 255).astype(np.uint8)
        Image.fromarray(u8, "RGB" if u8.ndim == 3 else "L").save(OUT / f"fish_skin_{name}.png")
    print(f"fish skin source maps written to {OUT}")


if __name__ == "__main__":
    main()
