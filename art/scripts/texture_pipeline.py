"""Texture pipeline for the Real-ish material families.

One command per family turns a CC0 photo scan (or a procedural source) into the
maps a Roblox MaterialVariant needs:

    art/textures/<family>/<family>_color.png    palette-pulled colour (final colour baked in)
    art/textures/<family>/<family>_neutral.png  luma-only colour, mean about 0.80 (sRGB), for
                                                meshes that keep their vertex colours (Layer B)
                                                and for terrain slots that use the slot tint
    art/textures/<family>/<family>_normal.png   OpenGL convention, re-normalized
    art/textures/<family>/<family>_rough.png    roughness (white = rough)
    art/textures/<family>/<family>_tile3.jpg    3x3 tiled preview (colour left, neutral right)
    art/textures/<family>/<family>.json         source, settings and measured stats

Usage (from the repo root; needs Python 3 with Pillow and numpy, nothing else):

    python art/scripts/texture_pipeline.py --list
    python art/scripts/texture_pipeline.py weathered_plank
    python art/scripts/texture_pipeline.py --all
    python art/scripts/texture_pipeline.py --all --fetch          # download missing sources first
    python art/scripts/texture_pipeline.py --candidates rope      # every candidate source, into
                                                                  # artifacts/textures_candidates/
    python art/scripts/texture_pipeline.py meadow_grass --source Grass004 --out artifacts/tmp/g4
    python art/scripts/texture_pipeline.py wet_sand --set rough_mean=0.3 --set soften=0.6

The table of families is `art/scripts/texture_families.json`. Each family names its
source, its size (1024 terrain, 512 props), its target palette colour and the knobs
below. `defaults` in that file fills in anything a family leaves out.

Steps, in order:
  1. Load colour, normal (OpenGL), roughness and optional AO from the source folder
     (ambientCG names: *_Color, *_NormalGL, *_Roughness, *_AmbientOcclusion; Poly Haven
     names: *_diff_*, *_nor_gl_*, *_rough_*, *_ao_*). Procedural families run their
     generator script first; it writes the same four names into its own source folder.
  2. Optional rotate (quarter turns, the normal vectors turn with the image) and crop.
  3. Seam check: the jump across the wrap edge compared with the strongest lines the
     picture already has (1.0 or less = seamless). If it fails (or the source was
     cropped, or seamless = "force"), make it tile with a two-pass offset-and-blend
     that keeps contrast in the blend zone.
  4. Resize with wrap padding, so the edge pixels stay tileable.
  5. Light AO multiply into the colour (ao_mix).
  6. Soften the fine noise: blend toward a wrap-around gaussian blur (soften,
     soften_sigma), and flatten very large blotches that make the repeat obvious
     (flatten, flatten_sigma). Big grain stays.
  7. Palette pull: the mean colour becomes target_rgb exactly; brightness variation is
     kept as a ratio but capped (max_rel_std), speckles are soft-clipped (despeckle_k),
     and hue variation is scaled down (hue_var).
  8. Neutral map: the same brightness ratio on pure grey, mean neutral_mean.
  9. Normal: soften, scale strength (normal_strength; below 1 flattens), re-normalize.
 10. Roughness: soften, move the mean to rough_mean, scale contrast, clamp.
 11. Write the maps, the tiled preview and the stats, and print the seam scores.

Nothing here talks to Roblox: uploading is a separate, deliberate step (uploads are
permanent). Raw downloads live under artifacts/textures_src/ and are not committed.
"""

from __future__ import annotations

import argparse
import io
import json
import subprocess
import sys
import urllib.request
import zipfile
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
TABLE = Path(__file__).resolve().with_name("texture_families.json")
LUMA = np.array([0.2126, 0.7152, 0.0722], dtype=np.float64)
USER_AGENT = "texture-pipeline/1.0"

MAP_PATTERNS = {
    "color": ["_Color.", "_diff_", "_BaseColor.", "_albedo."],
    "normal": ["_NormalGL.", "_nor_gl_"],
    "rough": ["_Roughness.", "_rough_"],
    "ao": ["_AmbientOcclusion.", "_ao_"],
}


# ----------------------------------------------------------------------------
# small image helpers (everything is float64, 0..1, H x W x C)
# ----------------------------------------------------------------------------

def load_table() -> dict:
    with open(TABLE, "r", encoding="utf-8") as f:
        return json.load(f)


def find_maps(src: Path) -> dict:
    found = {}
    files = sorted(p for p in src.iterdir() if p.suffix.lower() in (".jpg", ".jpeg", ".png"))
    for key, pats in MAP_PATTERNS.items():
        for p in files:
            if any(pat.lower() in p.name.lower() for pat in pats):
                found[key] = p
                break
    for need in ("color", "normal", "rough"):
        if need not in found:
            raise SystemExit(f"{src}: no {need} map found (looked for {MAP_PATTERNS[need]})")
    return found


def load_rgb(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float64) / 255.0


def load_grey(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("L"), dtype=np.float64)[..., None] / 255.0


def to_u8(a: np.ndarray) -> np.ndarray:
    return np.clip(np.rint(a * 255.0), 0, 255).astype(np.uint8)


def blur_wrap(a: np.ndarray, sigma: float) -> np.ndarray:
    """Gaussian blur that wraps around the edges (done in the frequency domain)."""
    if sigma <= 0:
        return a
    h, w = a.shape[:2]
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.rfftfreq(w)[None, :]
    g = np.exp(-2.0 * (np.pi ** 2) * (sigma ** 2) * (fx ** 2 + fy ** 2))
    spec = np.fft.rfft2(a, axes=(0, 1)) * g[..., None]
    return np.fft.irfft2(spec, s=(h, w), axes=(0, 1))


def resize_wrap(a: np.ndarray, size: int) -> np.ndarray:
    """Lanczos resize to size x size with wrap padding so the result still tiles."""
    h, w = a.shape[:2]
    if h == size and w == size:
        return a
    pad_y, pad_x = h // 8, w // 8
    padded = np.pad(a, ((pad_y, pad_y), (pad_x, pad_x), (0, 0)), mode="wrap")
    out_h = size + 2 * (size // 8)
    out_w = size + 2 * (size // 8)
    chans = []
    for c in range(a.shape[2]):
        im = Image.fromarray(padded[..., c].astype(np.float32), mode="F")
        chans.append(np.asarray(im.resize((out_w, out_h), Image.LANCZOS), dtype=np.float64))
    out = np.stack(chans, axis=-1)
    o = size // 8
    return out[o:o + size, o:o + size]


def seam_score(a: np.ndarray) -> float:
    """Jump across the wrap edge, measured against the picture's own strongest lines.

    For each axis: the mean jump between neighbouring pixel lines, for every line. The
    wrap edge is one more such line. The score is its jump over the 99th percentile of
    the inner lines, so 1.0 or less means "no worse than lines the picture already has"
    (a plank gap or a weave line that happens to sit on the edge does not count as a
    seam), and a real seam on a smooth picture scores several times that."""
    scores = []
    for axis in (0, 1):
        d = np.abs(a - np.roll(a, 1, axis=axis))
        other = tuple(i for i in range(a.ndim) if i != axis)
        per_line = d.mean(axis=other)
        inner = np.percentile(per_line[1:], 99)
        scores.append(float(per_line[0] / max(inner, 1e-6)))
    return max(scores)


def _ramp(n: int, blend: float) -> np.ndarray:
    """0 at both ends, 1 in the middle, smooth over blend * n pixels."""
    x = (np.arange(n) + 0.5) / n
    d = np.minimum(x, 1.0 - x) / max(blend, 1e-6)
    t = np.clip(d, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def make_seamless(a: np.ndarray, blend: float = 0.2, is_normal: bool = False) -> np.ndarray:
    """Two-pass offset-and-blend. Each pass cross-fades the image with a half-shifted copy
    of itself along one axis, so the wrap edge takes the copy's (continuous) middle. The
    cross-fade is variance-preserving so the blend zone does not go soft."""
    out = a.copy()
    for axis in (1, 0):
        n = out.shape[axis]
        w = _ramp(n, blend)
        shape = [1, 1, 1]
        shape[axis] = n
        w = w.reshape(shape)
        shifted = np.roll(out, n // 2, axis=axis)
        norm = np.sqrt(w * w + (1.0 - w) * (1.0 - w))
        if is_normal:
            v = out * 2.0 - 1.0
            s = shifted * 2.0 - 1.0
            m = w * v + (1.0 - w) * s
            m[..., :2] /= norm
            out = (normalize(m) + 1.0) * 0.5
        else:
            mean = out.mean(axis=(0, 1), keepdims=True)
            out = mean + (w * (out - mean) + (1.0 - w) * (shifted - mean)) / norm
    return out


def normalize(v: np.ndarray) -> np.ndarray:
    v = v.copy()
    v[..., 2] = np.maximum(v[..., 2], 1e-3)
    return v / np.linalg.norm(v, axis=-1, keepdims=True)


def rot90_maps(maps: dict, turns: int) -> dict:
    """Quarter turns counterclockwise. Normal vectors turn with the picture."""
    turns %= 4
    for _ in range(turns):
        for k in list(maps):
            maps[k] = np.rot90(maps[k], 1, axes=(0, 1)).copy()
        n = maps["normal"] * 2.0 - 1.0
        x, y = n[..., 0].copy(), n[..., 1].copy()
        n[..., 0], n[..., 1] = -y, x
        maps["normal"] = (n + 1.0) * 0.5
    return maps


def crop_maps(maps: dict, frac: float) -> dict:
    """Keep the middle frac of the picture (bigger grain). The result no longer tiles, so the
    seam step will fix it."""
    if frac >= 0.999:
        return maps
    for k in list(maps):
        h, w = maps[k].shape[:2]
        ch, cw = int(round(h * frac)), int(round(w * frac))
        y0, x0 = (h - ch) // 2, (w - cw) // 2
        maps[k] = maps[k][y0:y0 + ch, x0:x0 + cw].copy()
    return maps


def soft_clip(d: np.ndarray, limit: float) -> np.ndarray:
    """Soft limit on a deviation: linear near zero, levels off at +/- limit."""
    if limit <= 0:
        return d
    return limit * np.tanh(d / limit)


# ----------------------------------------------------------------------------
# the pipeline
# ----------------------------------------------------------------------------

def resolve_source(table: dict, name: str) -> tuple[str, Path, dict]:
    """A source is an id in the table's `sources`, or a folder path."""
    info = table.get("sources", {}).get(name, {})
    folder = Path(info["dir"]) if "dir" in info else Path(name)
    if not folder.is_absolute():
        cand = REPO / folder
        if not cand.exists() and "dir" not in info:
            cand = REPO / table.get("source_root", "artifacts/textures_src") / name
        folder = cand
    return name, folder, info


def fetch_source(name: str, folder: Path, info: dict) -> None:
    """Download a source if its folder is missing. Only image files are kept."""
    if folder.exists() and (any(folder.glob("*.jpg")) or any(folder.glob("*.png"))):
        return
    urls = info.get("files") or ([info["zip"]] if "zip" in info else [])
    if not urls:
        raise SystemExit(f"{name}: no download URL in the sources table")
    folder.mkdir(parents=True, exist_ok=True)
    for url in urls:
        print(f"  fetch {url}")
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        data = urllib.request.urlopen(req, timeout=120).read()
        if url.lower().endswith(".zip"):
            with zipfile.ZipFile(io.BytesIO(data)) as z:
                for member in z.namelist():
                    base = Path(member).name
                    if base.lower().endswith((".jpg", ".jpeg", ".png")):
                        (folder / base).write_bytes(z.read(member))
        else:
            (folder / Path(url).name).write_bytes(data)


def run_generator(script: str) -> None:
    path = Path(__file__).resolve().with_name(script)
    print(f"  generator {path.name}")
    subprocess.run([sys.executable, str(path)], check=True)


def process(family: str, table: dict, source_override: str | None = None,
            out_dir: Path | None = None, overrides: dict | None = None,
            fetch: bool = False) -> dict:
    cfg = dict(table.get("defaults", {}))
    cfg.update(table["families"][family])
    # a candidate can carry its own knobs (rotation, crop and so on)
    source_name = source_override or cfg["source"]
    for cand in cfg.get("candidates", []):
        if isinstance(cand, dict) and cand.get("source") == source_name:
            cfg.update({k: v for k, v in cand.items() if k != "source"})
    cfg.update(overrides or {})

    name, src, info = resolve_source(table, source_name)
    if info.get("generator"):
        run_generator(info["generator"])
    elif fetch:
        fetch_source(name, src, info)
    if not src.exists():
        raise SystemExit(f"{family}: source folder {src} is missing (try --fetch)")

    size = int(cfg["size"])
    files = find_maps(src)
    maps = {
        "color": load_rgb(files["color"]),
        "normal": load_rgb(files["normal"]),
        "rough": load_grey(files["rough"]),
    }
    if "ao" in files:
        maps["ao"] = load_grey(files["ao"])

    maps = rot90_maps(maps, int(cfg.get("rotate", 0)))
    maps = crop_maps(maps, float(cfg.get("crop", 1.0)))

    # 3. seam check and fix (at source resolution)
    seam_in = seam_score(maps["color"])
    mode = cfg.get("seamless", "auto")
    fixed = False
    cropped = float(cfg.get("crop", 1.0)) < 0.999      # a crop never tiles, whatever the score says
    if mode == "force" or (mode == "auto" and (cropped or seam_in > float(cfg.get("seam_limit", 1.25)))):
        blend = float(cfg.get("seam_blend", 0.2))
        for k in list(maps):
            maps[k] = make_seamless(maps[k], blend, is_normal=(k == "normal"))
        fixed = True

    # 4. resize
    for k in list(maps):
        maps[k] = resize_wrap(maps[k], size)

    color = np.clip(maps["color"], 0.0, 1.0)
    rough = np.clip(maps["rough"], 0.0, 1.0)
    nrm = maps["normal"] * 2.0 - 1.0

    # 5. AO, lightly
    ao_mix = float(cfg.get("ao_mix", 0.0))
    if "ao" in maps and ao_mix > 0:
        color = color * (1.0 - ao_mix + ao_mix * np.clip(maps["ao"], 0.0, 1.0))

    # 6. soften fine noise, flatten big blotches
    sigma = float(cfg.get("soften_sigma", 1.5)) * size / 512.0
    amount = float(cfg.get("soften", 0.5))
    if amount > 0:
        color = color + amount * (blur_wrap(color, sigma) - color)
    flat = float(cfg.get("flatten", 0.0))
    if flat > 0:
        big = blur_wrap(color, float(cfg.get("flatten_sigma", 0.12)) * size)
        color = color - flat * (big - big.mean(axis=(0, 1), keepdims=True))
    color = np.clip(color, 1e-4, 1.0)

    # 7. palette pull
    target = np.array(cfg["target_rgb"], dtype=np.float64) / 255.0
    luma = color @ LUMA
    mean_luma = float(luma.mean())
    ratio = luma / mean_luma                       # brightness as a ratio around 1
    dev = ratio - 1.0
    rel_std_in = float(dev.std())
    dev = dev * float(cfg.get("contrast", 1.0))
    max_rel = float(cfg.get("max_rel_std", 0.12))
    if dev.std() > max_rel:
        dev = dev * (max_rel / dev.std())
    k = float(cfg.get("despeckle_k", 2.5))
    dev = soft_clip(dev, k * max(float(dev.std()), 1e-6))
    dev = dev - dev.mean()
    ratio = 1.0 + dev
    # hue variation: what is left of the colour once its own brightness is taken out
    mean_rgb = color.reshape(-1, 3).mean(axis=0)
    chroma = color / luma[..., None] - (mean_rgb / mean_luma)[None, None, :]
    hue_var = float(cfg.get("hue_var", 0.4))
    t_luma = float(target @ LUMA)
    pulled = (target[None, None, :] + hue_var * chroma * t_luma) * ratio[..., None]
    pulled = np.clip(pulled, 0.0, 1.0)
    for _ in range(3):                             # land the mean exactly on the target
        pulled = np.clip(pulled + (target - pulled.reshape(-1, 3).mean(axis=0)), 0.0, 1.0)

    # 8. neutral: the same ratio on grey
    n_mean = float(cfg.get("neutral_mean", 0.80))
    n_dev = dev.copy()
    n_max = float(cfg.get("neutral_rel_std", max_rel))
    if n_dev.std() > n_max:
        n_dev = n_dev * (n_max / n_dev.std())
    headroom = (1.0 / n_mean) - 1.0                # how far above the mean before clipping
    n_dev = np.where(n_dev > 0, soft_clip(n_dev, headroom * 0.95), n_dev)
    n_dev = n_dev - n_dev.mean()
    neutral = np.clip(n_mean * (1.0 + n_dev), 0.0, 1.0)
    neutral = np.repeat(neutral[..., None], 3, axis=2)

    # 9. normal
    n_soft = float(cfg.get("normal_soften", amount))
    if n_soft > 0:
        nrm = nrm + n_soft * (blur_wrap(nrm, sigma) - nrm)
    nrm[..., :2] *= float(cfg.get("normal_strength", 1.0))
    nrm = normalize(nrm)
    normal = (nrm + 1.0) * 0.5

    # 10. roughness
    if amount > 0:
        rough = rough + amount * (blur_wrap(rough, sigma) - rough)
    r_mean = cfg.get("rough_mean")
    r = rough - rough.mean()
    r = r * float(cfg.get("rough_contrast", 1.0))
    rough = (float(r_mean) if r_mean is not None else float(rough.mean())) + r
    rough = np.clip(rough, float(cfg.get("rough_min", 0.08)), float(cfg.get("rough_max", 1.0)))

    # 11. write
    out = out_dir or (REPO / "art" / "textures" / family)
    out.mkdir(parents=True, exist_ok=True)
    paths = {
        "color": out / f"{family}_color.png",
        "neutral": out / f"{family}_neutral.png",
        "normal": out / f"{family}_normal.png",
        "rough": out / f"{family}_rough.png",
    }
    Image.fromarray(to_u8(pulled), "RGB").save(paths["color"], optimize=True)
    Image.fromarray(to_u8(neutral), "RGB").save(paths["neutral"], optimize=True)
    Image.fromarray(to_u8(normal), "RGB").save(paths["normal"], optimize=True)
    Image.fromarray(to_u8(rough)[..., 0], "L").save(paths["rough"], optimize=True)

    # tiled preview: colour left, neutral right, 3 x 3 each
    cell = 256
    def tiled(a: np.ndarray) -> Image.Image:
        small = Image.fromarray(to_u8(a), "RGB").resize((cell, cell), Image.LANCZOS)
        sheet = Image.new("RGB", (cell * 3, cell * 3))
        for iy in range(3):
            for ix in range(3):
                sheet.paste(small, (ix * cell, iy * cell))
        return sheet
    prev = Image.new("RGB", (cell * 6 + 16, cell * 3), (20, 20, 20))
    prev.paste(tiled(pulled), (0, 0))
    prev.paste(tiled(neutral), (cell * 3 + 16, 0))
    prev.save(out / f"{family}_tile3.jpg", quality=90)

    out_luma = pulled @ LUMA
    stats = {
        "family": family,
        "kind": cfg.get("kind"),
        "size": size,
        "source": name,
        "source_page": info.get("page"),
        "licence": info.get("licence", "CC0"),
        "studs_per_tile": cfg.get("studs_per_tile"),
        "target_rgb": cfg["target_rgb"],
        "mean_rgb": [round(float(v) * 255.0, 1) for v in pulled.reshape(-1, 3).mean(axis=0)],
        "luma_rel_std_in": round(rel_std_in, 4),
        "luma_rel_std_out": round(float(out_luma.std() / out_luma.mean()), 4),
        "neutral_mean": round(float(neutral.mean()), 4),
        "neutral_std": round(float(neutral[..., 0].std()), 4),
        "neutral_min_max": [round(float(neutral.min()), 3), round(float(neutral.max()), 3)],
        "rough_mean": round(float(rough.mean()), 4),
        "rough_std": round(float(rough.std()), 4),
        "normal_mean_tilt": round(float(np.sqrt((nrm[..., :2] ** 2).sum(axis=-1)).mean()), 4),
        "seam_in": round(seam_in, 3),
        "seam_fixed": fixed,
        "seam_out": {
            "color": round(seam_score(pulled), 3),
            "normal": round(seam_score(normal), 3),
            "rough": round(seam_score(rough), 3),
        },
        "settings": {k: cfg[k] for k in sorted(cfg) if k not in ("candidates", "note")},
    }
    with open(out / f"{family}.json", "w", encoding="utf-8") as f:
        json.dump(stats, f, indent=2)
        f.write("\n")
    worst = max(stats["seam_out"].values())
    flag = "ok" if worst < float(cfg.get("seam_limit", 1.25)) else "CHECK SEAM"
    print(f"{family:16s} <- {name:18s} mean {stats['mean_rgb']}  rel std {stats['luma_rel_std_in']} -> "
          f"{stats['luma_rel_std_out']}  neutral {stats['neutral_mean']}  rough {stats['rough_mean']}  "
          f"seam {stats['seam_in']} -> {worst} ({'fixed, ' if fixed else ''}{flag})")
    return stats


def parse_set(pairs: list[str]) -> dict:
    out = {}
    for p in pairs or []:
        key, _, val = p.partition("=")
        try:
            out[key] = json.loads(val)
        except json.JSONDecodeError:
            out[key] = val
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description="Make Roblox material maps for one family.")
    ap.add_argument("family", nargs="?", help="family slug from texture_families.json")
    ap.add_argument("--all", action="store_true", help="every family")
    ap.add_argument("--list", action="store_true", help="list families and sources")
    ap.add_argument("--candidates", action="store_true",
                    help="run every candidate source for the family into artifacts/textures_candidates/")
    ap.add_argument("--source", help="override the source (an id from the table, or a folder)")
    ap.add_argument("--out", help="override the output folder")
    ap.add_argument("--fetch", action="store_true", help="download missing sources first")
    ap.add_argument("--set", action="append", metavar="KEY=VALUE", help="override a knob for this run")
    args = ap.parse_args()

    table = load_table()
    fams = table["families"]
    if args.list:
        for name, cfg in fams.items():
            cands = [c["source"] if isinstance(c, dict) else c for c in cfg.get("candidates", [])]
            print(f"{name:16s} {cfg.get('kind', ''):8s} {cfg.get('size', table['defaults'].get('size'))}  "
                  f"source {cfg['source']}  candidates {cands}")
        return
    overrides = parse_set(args.set)
    if args.all:
        for name in fams:
            process(name, table, fetch=args.fetch, overrides=overrides)
        return
    if not args.family or args.family not in fams:
        raise SystemExit(f"pick a family: {', '.join(fams)}")
    if args.candidates:
        root = REPO / "artifacts" / "textures_candidates"
        cands = [c["source"] if isinstance(c, dict) else c for c in fams[args.family].get("candidates", [])]
        for src in [fams[args.family]["source"]] + [c for c in cands if c != fams[args.family]["source"]]:
            process(args.family, table, source_override=src, out_dir=root / f"{args.family}__{src}",
                    overrides=overrides, fetch=args.fetch)
        return
    process(args.family, table, source_override=args.source,
            out_dir=Path(args.out).resolve() if args.out else None,
            overrides=overrides, fetch=args.fetch)


if __name__ == "__main__":
    main()
