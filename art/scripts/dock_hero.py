"""DockHero: the dock as a hero set. Same chunky shapes, size, pivot and orientation as
dock.py, but one UV-mapped mesh with a baked colour, normal (OpenGL) and roughness map, so
Roblox imports it as a MeshPart with a SurfaceAppearance. Two things differ from dock.py on
purpose: the end deck's boards lie across it (on three beams, post to post), and there are
two rope coils and two cleats.

    blender -b --factory-startup -P art/scripts/dock_hero.py -- [options]

    --size 1024        atlas size in pixels (1024 is the hero-set budget; 2048 also works)
    --samples 48       preview render samples
    --views a,b        only these previews (hero, front, threequarter, deck, ingame, posts)
    --maps-only        compose the maps and the atlas sheet, then stop (fast, for tuning)
    --no-render        build and export, skip the previews

How it works (no Blender bake pass, so every pixel is deliberate):
  1. An atlas is laid out by a small shelf packer: 14 deck-board tops, then one or two
     shared rectangles per other surface (board sides, end grain, stringers, posts in a
     dry-top and an under-water part, lamp, bollard, rope, ladder, bucket).
  2. Each rectangle is painted with numpy from a CC0 scan of weathered boards (Poly Haven
     "wood_planks_grey", the same scan the weathered_plank family in art/textures/ is made
     from, here at its full 1K): one real board per deck board, so the grain follows the board.
     Colour is pulled to the Home lake dock timber (122,104,86). Height comes from the
     scan's own dark grain; nail heads at the joists, worn edges, end checks, the wet band
     on the posts and the rope lay are added on top. The normal map is taken from that
     height, per rectangle, so nothing bleeds between neighbours.
  3. The mesh is built quad by quad with explicit UVs. Boards reuse the 14 tops (straight
     or turned 180 degrees, never mirrored, so normals stay right).
  4. Export: a GLB with the three maps embedded as PNG. Image textures are sRGB already,
     so roblox_colors.py (the vertex colour fix) is not needed; art/models/roblox/ gets a
     byte-for-byte copy.

Scratch (loose maps, full-size renders) goes to artifacts/dock_hero/, which is git-ignored.
"""

import json
import math
import random
import shutil
import struct
import subprocess
import sys
import urllib.request
import zlib
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common  # noqa: E402
from common import MANIFEST, MODELS, PREVIEWS, bounds, reset  # noqa: E402
from dock import END_L, END_W, PLANK_T, TOP, WALK_L, WALK_W  # noqa: E402

NAME = "DockHero"
REPO = Path(__file__).resolve().parents[2]
SCRATCH = REPO / "artifacts" / "dock_hero"
SCAN_DIR = REPO / "artifacts" / "textures_src" / "wood_planks_grey"
SCAN_URL = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/{res}/wood_planks_grey/wood_planks_grey_{kind}_{res}.jpg"

# Palette (sRGB 0..255). Dock timber is the Home lake row of the leg 3 plan.
DECK = (122, 104, 86)
TIMBER = (94, 80, 66)       # posts, stringers, lamp poles: the same wood, darker and older
WET = (44, 40, 33)          # soaked timber
ALGAE = (58, 72, 42)
IRON = (50, 48, 49)
RUST = (98, 66, 46)
ZINC = (112, 116, 118)      # galvanised ladder, bucket, cleats
ROPE = (176, 152, 112)       # the rope family's light hemp (art/textures/rope)
LANTERN = (255, 190, 120)
WATERLINE = 7.5             # studs above the model base (game water y = 0, base y = -7.5)
LUMA = np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {"size": 1024, "samples": 48, "views": None, "maps_only": False, "no_render": False}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--size":
            opt["size"] = int(argv[i + 1]); i += 1
        elif a == "--samples":
            opt["samples"] = int(argv[i + 1]); i += 1
        elif a == "--views":
            opt["views"] = argv[i + 1].split(","); i += 1
        elif a == "--maps-only":
            opt["maps_only"] = True
        elif a == "--no-render":
            opt["no_render"] = True
        else:
            raise SystemExit(f"unknown option {a}")
        i += 1
    return opt


# --------------------------------------------------------------------------- images

def load_rgb(path):
    """An image file as float32 H x W x 3, top row first, values as stored (sRGB 0..1)."""
    img = bpy.data.images.load(str(path))
    w, h = img.size
    a = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(a)
    bpy.data.images.remove(img)
    return a.reshape(h, w, 4)[::-1, :, :3].copy()


def write_png(path, arr):
    """8-bit PNG (grey or RGB) with per-row adaptive filters and zlib 9. Blender's own
    writer would do, but this keeps the files small and byte-stable."""
    a = np.clip(np.rint(arr * 255.0), 0, 255).astype(np.uint8) if arr.dtype != np.uint8 else arr
    if a.ndim == 2:
        a = a[:, :, None]
    h, w, c = a.shape
    cur = a.reshape(h, w * c).astype(np.int16)
    left = np.zeros_like(cur); left[:, c:] = cur[:, :-c]
    up = np.zeros_like(cur); up[1:] = cur[:-1]
    ul = np.zeros_like(cur); ul[1:, c:] = cur[:-1, :-c]
    p = left + up - ul
    pa, pb, pc = np.abs(p - left), np.abs(p - up), np.abs(p - ul)
    paeth = np.where((pa <= pb) & (pa <= pc), left, np.where(pb <= pc, up, ul))
    cands = [cur, cur - left, cur - up, cur - (left + up) // 2, cur - paeth]
    cands = [(x & 0xFF).astype(np.uint8) for x in cands]
    cost = np.stack([np.abs(x.astype(np.int8).astype(np.int16)).sum(1) for x in cands])
    pick = cost.argmin(0)
    rows = np.empty((h, w * c + 1), np.uint8)
    rows[:, 0] = pick
    for f, x in enumerate(cands):
        m = pick == f
        rows[m, 1:] = x[m]

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    head = struct.pack(">IIBBBBB", w, h, 8, {1: 0, 3: 2}[c], 0, 0, 0)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", head) + chunk(b"IDAT", zlib.compress(rows.tobytes(), 9)) + chunk(b"IEND", b""))


def _resize_axis(a, n, axis):
    """Exact box (area) resampling along one axis."""
    a = np.moveaxis(a, axis, 0)
    m = a.shape[0]
    if m == n:
        return np.moveaxis(a, 0, axis)
    cum = np.concatenate([np.zeros((1,) + a.shape[1:], a.dtype), np.cumsum(a, 0)], 0)
    e = np.linspace(0, m, n + 1)
    i = np.minimum(e.astype(int), m - 1)
    f = (e - i).astype(a.dtype).reshape((-1,) + (1,) * (a.ndim - 1))
    c = cum[i] + (cum[i + 1] - cum[i]) * f
    out = (c[1:] - c[:-1]) / (m / n)
    return np.moveaxis(out, 0, axis)


def resize(a, h, w):
    return _resize_axis(_resize_axis(a.astype(np.float32), h, 0), w, 1)


def blur(a, sigma, wrap_x=False):
    """Gaussian blur by FFT. Edges reflect; wrap_x makes the horizontal direction periodic."""
    if sigma <= 0:
        return a
    pad = int(3 * sigma) + 1
    spec = [(pad, pad), (0, 0) if wrap_x else (pad, pad)] + [(0, 0)] * (a.ndim - 2)
    b = np.pad(a, spec, mode="reflect")
    fy = np.fft.fftfreq(b.shape[0])[:, None]
    fx = np.fft.rfftfreq(b.shape[1])[None, :]
    g = np.exp(-2 * (math.pi * sigma) ** 2 * (fx * fx + fy * fy))
    if b.ndim == 3:
        g = g[:, :, None]
    out = np.fft.irfft2(np.fft.rfft2(b, axes=(0, 1)) * g, s=b.shape[:2], axes=(0, 1)).astype(np.float32)
    out = out[pad:-pad]
    return out if wrap_x else out[:, pad:-pad]


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def noise(h, w, cell, rng, octaves=3, wrap_x=False):
    """Soft value noise, 0..1. `cell` is the size of the biggest blobs in pixels (y, x)."""
    cy, cx = (cell, cell) if np.isscalar(cell) else cell
    out = np.zeros((h, w), np.float32)
    amp, total = 1.0, 0.0
    for _ in range(octaves):
        gh, gw = max(2, int(round(h / cy)) + 1), max(2, int(round(w / cx)) + 1)
        g = rng.random((gh, gw)).astype(np.float32)
        if wrap_x:
            g[:, -1] = g[:, 0]
        ys = np.linspace(0, gh - 1, h); xs = np.linspace(0, gw - 1, w)
        y0 = np.minimum(ys.astype(int), gh - 2); x0 = np.minimum(xs.astype(int), gw - 2)
        ty = smooth(0, 1, ys - y0)[:, None].astype(np.float32); tx = smooth(0, 1, xs - x0)[None, :].astype(np.float32)
        a = g[y0][:, x0] * (1 - tx) + g[y0][:, x0 + 1] * tx
        b = g[y0 + 1][:, x0] * (1 - tx) + g[y0 + 1][:, x0 + 1] * tx
        out += amp * (a * (1 - ty) + b * ty)
        total += amp
        amp *= 0.5; cy = max(cy / 2, 1); cx = max(cx / 2, 1)
    return out / total


def rgb(c):
    return np.array(c, np.float32) / 255.0


def mix(a, b, t):
    t = t[..., None] if (np.ndim(t) == 2 and np.ndim(a) == 3) else t
    return a * (1 - t) + b * t


# --------------------------------------------------------------------------- the scan

class Scan:
    """The board scan: five upright boards with a row of screws we steer round."""

    def __init__(self, res="1k"):
        self.res = res
        self.col = load_rgb(self._file("diff"))
        self.rough = load_rgb(self._file("rough"))[:, :, 0]
        ao = load_rgb(self._file("ao"))[:, :, 0].mean(0)
        n = self.col.shape[0]
        gap = ao < ao.mean() - 1.5 * ao.std()
        self.boards, start = [], None
        for x in range(n + 1):
            solid = x < n and not gap[x]
            if solid and start is None:
                start = x
            elif not solid and start is not None:
                if x - start > n // 10:
                    self.boards.append((start + 4, x - 4))
                start = None
        self.n = n
        self.clear = int(n * 0.182)   # first row below the screws
        self.run = int(n * 0.945)     # rows that follow before the screws come round again
        print(f"[dock_hero] scan {res}: boards {self.boards}")

    def _file(self, kind):
        p = SCAN_DIR / f"wood_planks_grey_{kind}_{self.res}.jpg"
        if not p.exists():
            p.parent.mkdir(parents=True, exist_ok=True)
            url = SCAN_URL.format(res=self.res, kind=kind)
            print(f"[dock_hero] fetching {url}")
            req = urllib.request.Request(url, headers={"User-Agent": "texture-pipeline/1.0"})
            p.write_bytes(urllib.request.urlopen(req, timeout=60).read())
        return p

    def strip(self, board, start, length, width=None, flip=False):
        """One board's wood, grain upright: `length` rows from `start` (fractions of the
        clear run), `width` columns (fraction of the board, centred). Colour and roughness."""
        x0, x1 = self.boards[board % len(self.boards)]
        if width:
            mid, half = (x0 + x1) // 2, int((x1 - x0) * width / 2)
            x0, x1 = mid - half, mid + half
        rows = (self.clear + int(start * self.run) + np.arange(int(length * self.run))) % self.n
        c, r = self.col[rows, x0:x1], self.rough[rows, x0:x1]
        if flip:
            c, r = c[::-1, ::-1], r[::-1, ::-1]
        return c, r


def tile_x(a, blend):
    """Make the horizontal direction wrap by cross-fading the last `blend` columns into the first."""
    w = a.shape[1] - blend
    t = np.linspace(0, 1, blend, dtype=np.float32)
    t = t[None, :, None] if a.ndim == 3 else t[None, :]
    out = a[:, :w].copy()
    out[:, :blend] = a[:, w:] * (1 - t) + a[:, :blend] * t
    return out


def wood(src_col, src_rough, h, w, target, value=1.0, warm=0.0, contrast=1.0, chroma=0.45, grain=0.004, wrap_x=False, upright=False, rng=None):
    """Scan wood resized to h x w and pulled to `target`. Returns colour, height (studs),
    roughness. The grain runs across the picture, or up it when `upright`."""
    c = resize(src_col, h, w)
    c = c + 0.6 * (c - blur(c, 1.2, wrap_x))          # the scan is soft at this size: bring the grain back
    r = resize(src_rough, h, w)
    lum = c @ LUMA
    ratio = np.clip((lum / lum.mean()) ** contrast, 0.3, 2.0)
    mean = c.reshape(-1, 3).mean(0)
    resid = c - mean * (lum / lum.mean())[..., None]
    t = rgb(target) * value * np.array([1 + warm, 1.0, 1 - warm], np.float32)
    col = t * ratio[..., None] + chroma * resid * (t.mean() / mean.mean())
    fine = lum - blur(lum, 2.5, wrap_x)
    broad = blur(lum, 2.5, wrap_x) - blur(lum, 12, wrap_x)
    hgt = (fine / (fine.std() + 1e-6) + 0.6 * broad / (broad.std() + 1e-6)) * grain
    if rng is not None:                                # raised hard grain, finer than the scan resolves
        streak = noise(h, w, (26, 1.4) if upright else (1.4, 26), rng, 2, wrap_x) - 0.5
        hgt = hgt + 1.6 * grain * streak
        col = col * (1 + 0.16 * streak)[..., None]
    rough = np.clip(0.82 + (r - r.mean()) * 1.6 - 0.05 * (ratio - 1), 0.55, 0.97)
    return col.astype(np.float32), hgt.astype(np.float32), rough.astype(np.float32)


# --------------------------------------------------------------------------- the atlas

class Atlas:
    PAD = 3

    def __init__(self, size):
        self.size = size
        self.k = size // 1024
        self.color = np.empty((size, size, 3), np.float32); self.color[:] = rgb(TIMBER)
        self.normal = np.empty((size, size, 3), np.float32); self.normal[:] = (0.5, 0.5, 1.0)
        self.rough = np.full((size, size), 0.85, np.float32)
        self.emit = np.zeros((size, size), np.float32)
        self.rects = {}
        self._x = self._y = self._shelf = 0

    def alloc(self, name, w, h):
        """Reserve w x h pixels (given for a 1024 atlas) on the current shelf."""
        w, h, p = w * self.k, h * self.k, self.PAD
        if self._x + w + 2 * p > self.size:
            self._x, self._y, self._shelf = 0, self._y + self._shelf, 0
        if self._y + h + 2 * p > self.size:
            raise SystemExit(f"atlas full at {name}: lower the sizes or raise --size")
        self.rects[name] = (self._x + p, self._y + p, w, h)
        self._x += w + 2 * p
        self._shelf = max(self._shelf, h + 2 * p)
        return w, h

    def column(self, items):
        """Stack several small rectangles in one column of the current shelf."""
        p = self.PAD
        wide = max(w for _, w, _ in items) * self.k + 2 * p
        if self._x + wide > self.size:
            self._x, self._y, self._shelf = 0, self._y + self._shelf, 0
        y = self._y
        for name, w, h in items:
            w, h = w * self.k, h * self.k
            if y + h + 2 * p > self.size:
                raise SystemExit(f"atlas full at {name}: lower the sizes or raise --size")
            self.rects[name] = (self._x + p, y + p, w, h)
            y += h + 2 * p
        self._x += wide
        self._shelf = max(self._shelf, y - self._y)

    def dims(self, name):
        return self.rects[name][2], self.rects[name][3]

    def paint(self, name, col, hgt, rough, su, sv, emit=None):
        """Store a painted rectangle. `hgt` is in studs; su, sv are pixels per stud across
        and down, which turn height into true slopes for the normal map."""
        x, y, w, h = self.rects[name]
        assert col.shape[:2] == (h, w), (name, col.shape, (h, w))
        p = self.PAD
        hp = np.pad(hgt, 1, mode="edge")
        dx = (hp[1:-1, 2:] - hp[1:-1, :-2]) * 0.5 * su
        dy = (hp[2:, 1:-1] - hp[:-2, 1:-1]) * 0.5 * sv   # down the image
        n = np.stack([-dx, dy, np.ones_like(dx)], -1)    # OpenGL: green points up the image
        n /= np.linalg.norm(n, axis=-1, keepdims=True)
        ys = slice(max(y - p, 0), min(y + h + p, self.size)); xs = slice(max(x - p, 0), min(x + w + p, self.size))
        cy = slice(ys.start - (y - p), ys.stop - (y - p)); cx = slice(xs.start - (x - p), xs.stop - (x - p))

        def put(dst, src):
            spec = [(p, p), (p, p)] + [(0, 0)] * (src.ndim - 2)
            dst[ys, xs] = np.pad(src, spec, mode="edge")[cy, cx]

        put(self.color, np.clip(col, 0, 1))
        put(self.normal, n * 0.5 + 0.5)
        put(self.rough, np.clip(rough, 0.04, 1))
        if emit is not None:
            put(self.emit, emit)

    def uv(self, name, sub=(0, 0, 1, 1)):
        """UV corners (bottom-left, bottom-right, top-right, top-left) of a rectangle, or
        of the part of it given as fractions (u0, v0, u1, v1) with v up."""
        x, y, w, h = self.rects[name]
        s = float(self.size)
        u0, u1 = (x + sub[0] * w) / s, (x + sub[2] * w) / s
        v0, v1 = 1 - (y + h - sub[1] * h) / s, 1 - (y + h - sub[3] * h) / s
        return [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]

    def point(self, name, a, b):
        x, y, w, h = self.rects[name]
        return ((x + a * w) / self.size, 1 - (y + h - b * h) / self.size)


N_BOARDS = 14


def layout(at):
    """Every rectangle, sizes for a 1024 atlas. Deck-board tops come first: they are what
    the player stands on, so they get two thirds of the pixels (64 px per stud along the
    board, 104 across the grain)."""
    for i in range(N_BOARDS):
        at.alloc(f"board{i}", 506, 94)
    for name, w, h in [("postTopA", 180, 170), ("postTopB", 180, 170), ("postLowA", 96, 170), ("postLowB", 96, 170),
                       ("pole", 64, 170), ("rail", 16, 170)]:
        at.alloc(name, w, h)
    at.column([("bollard", 126, 58), ("bucket", 126, 58), ("zinc", 60, 30)])
    at.column([("glass", 60, 66), ("capA", 60, 60)])
    at.column([("capB", 60, 60), ("roof", 60, 46), ("soil", 46, 46)])
    at.column([("iron", 44, 44), ("endA", 84, 32), ("endB", 84, 32), ("rung", 80, 16)])
    at.column([("under", 506, 40), ("stringer", 506, 36), ("side", 506, 22)])
    at.column([("ropeWrap", 250, 48), ("rope", 250, 48)])


# --------------------------------------------------------------------------- painters

def paint_boards(at, scan, rng):
    """The 14 deck-board tops: one scan board each (ten clean windows, four turned ones)."""
    w, h = at.dims("board0")
    su, sv = w / 8.0, h / 0.9
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    edge_v = np.minimum(yy, h - 1 - yy) / sv           # studs to the nearest long edge
    edge_u = np.minimum(xx, w - 1 - xx) / su           # studs to the nearest end
    edge = np.minimum(edge_v, edge_u)
    sums = np.zeros(3); stash = []
    for i in range(N_BOARDS):
        board, start, flip = (i % 5, 0.5 * (i // 5), False) if i < 10 else ((i * 2 + 1) % 5, 0.26, True)
        sc, sr = scan.strip(board, start, 0.49, flip=flip)
        value = (0.88, 1.06, 0.97, 1.12, 0.93, 1.02, 0.9, 1.08, 1.0, 0.95, 1.1, 0.86, 1.04, 0.98)[i]
        warm = (0.02, -0.02, 0.035, 0.0, -0.03, 0.02, 0.04, -0.01, 0.0, 0.03, -0.025, 0.01, -0.015, 0.03)[i]
        col, hgt, rough = wood(sc.transpose(1, 0, 2), sr.T, h, w, DECK, value, warm, contrast=0.95, rng=rng)
        # A few boards have a darker, older end where water sits.
        if i in (2, 6, 9, 12):
            reach = (0.9 + 1.6 * rng.random()) * su
            ragged = xx + (noise(h, w, (10, 60), rng) - 0.5) * 70
            dark = 1 - smooth(reach * 0.35, reach, ragged)
            col *= 1 - 0.34 * dark[..., None]
            col = mix(col, col * np.array([0.93, 1.0, 0.96], np.float32), 0.6 * dark)
            rough -= 0.06 * dark
        # Dirt in the gaps, a rounded worn arris, and a paler rubbed band just inside it.
        col *= (0.62 + 0.38 * smooth(0.0, 0.05, edge))[..., None]
        rub = smooth(0.02, 0.06, edge) * (1 - smooth(0.06, 0.14, edge)) * noise(h, w, (6, 40), rng)
        col = mix(col, col * 1.16 + 0.02, 0.5 * rub)
        hgt = hgt * smooth(0.0, 0.03, edge) - 0.03 * (1 - smooth(0.0, 0.045, edge)) ** 2
        # End checks: splits running in from the ends along the grain.
        for _ in range(int(rng.integers(1, 4))):
            cy = rng.uniform(0.15, 0.85) * h
            reach = rng.uniform(0.35, 1.3) * su
            from_left = rng.random() < 0.5
            d_end = xx if from_left else (w - 1 - xx)
            wander = cy + 2.5 * np.sin(d_end / (0.25 * su) + rng.uniform(0, 6))
            width = (1.5 * at.k) * (1 - d_end / reach)
            crack = np.clip(1 - np.abs(yy - wander) / np.maximum(width, 0.01), 0, 1) * (d_end < reach)
            col *= (1 - 0.6 * crack)[..., None]
            hgt -= 0.02 * crack
            rough += 0.05 * crack
        # Nail heads: two at each joist (the joists sit under +-3.4 and 0 studs).
        for jx in (-3.4, 0.0, 3.4):
            for jy in (0.24, 0.76):
                nx = (jx + 4.0) * su + rng.uniform(-0.05, 0.05) * su
                ny = jy * h + rng.uniform(-0.05, 0.05) * sv
                d = np.sqrt(((xx - nx) / su) ** 2 + ((yy - ny) / sv) ** 2)   # studs
                stain = np.exp(-((xx - nx) / (0.22 * su)) ** 2 - ((yy - ny) / (0.045 * sv)) ** 2)
                col = mix(col, col * rgb(RUST) / rgb(DECK).mean() * 0.9, 0.34 * stain * (0.6 + 0.4 * rng.random()))
                ring = smooth(0.075, 0.045, d)
                col *= (1 - 0.42 * ring)[..., None]
                head = smooth(0.043, 0.034, d)
                iron = rgb(IRON) * (0.9 + 0.5 * noise(h, w, 3, rng, 1))[..., None]
                iron = mix(iron, rgb(RUST) * 0.8, 0.35 * noise(h, w, 4, rng, 1))
                col = mix(col, iron, head)
                dome = np.clip(1 - (d / 0.04) ** 2, 0, 1)
                hgt = hgt * (1 - head) - 0.012 * np.exp(-(d / 0.06) ** 2) + 0.011 * dome * head
                rough = mix(rough, 0.5 + 0.2 * noise(h, w, 3, rng, 1), head)
        stash.append((col, hgt, rough))
        sums += col.reshape(-1, 3).mean(0)
    # Hold the deck's mean colour exactly on the palette value.
    gain = rgb(DECK) / (sums / N_BOARDS)
    for i, (col, hgt, rough) in enumerate(stash):
        at.paint(f"board{i}", col * gain, hgt, rough, su, sv)
    return gain


def paint_plain_wood(at, scan, rng):
    """Board undersides and sides, stringers, end grain, post caps."""
    w, h = at.dims("under")
    sc, sr = scan.strip(3, 0.3, 0.49, width=0.5)
    col, hgt, rough = wood(sc.transpose(1, 0, 2), sr.T, h, w, DECK, 0.52, 0.0, rng=rng)
    damp = noise(h, w, (12, 90), rng)
    col = mix(col, col * np.array([0.86, 1.0, 0.9], np.float32), 0.5 * damp)
    at.paint("under", col, hgt, rough - 0.12 * damp, w / 8.0, h / 0.9)

    w, h = at.dims("side")
    sc, sr = scan.strip(1, 0.55, 0.45, width=0.3)
    col, hgt, rough = wood(sc.transpose(1, 0, 2), sr.T, h, w, DECK, 0.7, 0.01, rng=rng)
    yy = np.mgrid[0:h, 0:w][0].astype(np.float32)
    col *= (0.7 + 0.3 * smooth(h * 1.0, h * 0.2, yy))[..., None]     # darker toward the bottom edge
    at.paint("side", col, hgt, rough, w / 8.0, h / PLANK_T)

    w, h = at.dims("stringer")
    sc, sr = scan.strip(4, 0.1, 0.47, width=0.4)
    col, hgt, rough = wood(sc.transpose(1, 0, 2), sr.T, h, w, TIMBER, 0.86, 0.0, grain=0.005, rng=rng)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    for bx in (0.18, 0.5, 0.82):       # a bolt and its washer where a post would be
        d = np.sqrt(((xx - bx * w) / (w / 9.5)) ** 2 + ((yy - 0.5 * h) / (h / 0.6)) ** 2)
        washer = smooth(0.13, 0.11, d)
        col = mix(col, rgb(IRON) * (0.8 + 0.4 * noise(h, w, 3, rng, 1))[..., None], washer)
        col = mix(col, col * 0.55, smooth(0.2, 0.13, d) * (1 - washer))
        hgt += 0.012 * washer + 0.012 * smooth(0.07, 0.05, d)
        rough = mix(rough, 0.55, washer)
    at.paint("stringer", col, hgt, rough, w / 9.5, h / 0.6)

    for name, target, size in (("endA", DECK, (0.9, PLANK_T)), ("endB", DECK, (0.9, PLANK_T)),
                               ("capA", TIMBER, (0.95, 0.95)), ("capB", TIMBER, (0.95, 0.95))):
        w, h = at.dims(name)
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        px, py = (xx - w / 2) / w * size[0], (yy - h / 2) / h * size[1]
        if name.startswith("end"):     # flat-sawn board: shallow arcs from a heart far below
            r = np.sqrt((px - rng.uniform(-0.3, 0.3)) ** 2 + (py - rng.uniform(0.5, 0.9)) ** 2)
            freq, lift = 96.0, 0.74
        else:                          # a round pile: full rings, heart a little off centre
            ox, oy = rng.uniform(-0.08, 0.08), rng.uniform(-0.08, 0.08)
            r = np.sqrt((px - ox) ** 2 + (py - oy) ** 2)
            freq, lift = 52.0, 1.0
        r = r + 0.012 * (noise(h, w, 9, rng) - 0.5)
        rings = 0.5 + 0.5 * np.sin(r * freq)
        speck = noise(h, w, 2, rng, 1)
        saw = noise(h, w, (h, 2.5), rng, 1)            # saw marks straight across the cut
        col = rgb(target) * lift * (0.84 + 0.15 * rings + 0.14 * (speck - 0.5) + 0.12 * (saw - 0.5))[..., None]
        hgt = 0.005 * rings + 0.003 * speck + 0.004 * saw
        rough = np.full((h, w), 0.9, np.float32)
        if name.startswith("end"):
            for _ in range(2):         # a faint check or two across the rings
                cx, top = rng.uniform(0.1, 0.9) * w, rng.uniform(0, 0.5) * h
                crack = np.clip(1 - np.abs(xx - cx - 0.3 * (yy - top)) / 1.0, 0, 1) * smooth(top, top + 3, yy) * smooth(top + 0.45 * h, top + 0.3 * h, yy)
                col *= (1 - 0.3 * crack)[..., None]
                hgt -= 0.01 * crack
            rim = np.minimum(np.minimum(xx, w - 1 - xx) / w * size[0], np.minimum(yy, h - 1 - yy) / h * size[1])
            col *= (0.75 + 0.25 * smooth(0.0, 0.05, rim))[..., None]
        else:
            ang = np.arctan2(py - oy, px - ox)
            for _ in range(5):         # drying checks from the heart outward
                a0 = rng.uniform(-math.pi, math.pi)
                da = np.abs(np.angle(np.exp(1j * (ang - a0))))
                reach = rng.uniform(0.2, 0.46)
                crack = np.clip(1 - da * r / (0.012 * (1.15 - r / reach)).clip(0.002), 0, 1) * (r < reach)
                col *= (1 - 0.6 * crack)[..., None]
                hgt -= 0.025 * crack
            col *= (0.82 + 0.18 * smooth(0.5, 0.36, np.sqrt(px ** 2 + py ** 2)))[..., None]   # grimy rim
            col = mix(col, col * 1.2, 0.5 * noise(h, w, 14, rng))                          # sun-bleached top
        at.paint(name, col, hgt, rough, w / size[0], h / size[1])


def paint_posts(at, scan, rng):
    """Piles in two parts. The top part (7.0 to 9.6 studs) carries the waterline: soaked
    and dark to the water at 7.5 and a ragged half stud above it, a green line, then dry.
    The low part (0 to 7.0) is all under water: dark, greener near the light, mud at the foot."""
    for v, name in enumerate(("postTopA", "postTopB")):
        w, h = at.dims(name)
        su, sv = w / 2.83, h / 2.6
        blend = int(0.12 * (scan.boards[0][1] - scan.boards[0][0]))
        sc, sr = scan.strip(1 + 2 * v, 0.05 + 0.4 * v, 0.34)
        col, hgt, rough = wood(tile_x(sc, blend), tile_x(sr, blend), h, w, TIMBER, 1.0 + 0.06 * v, 0.01, grain=0.004, wrap_x=True, upright=True, rng=rng)
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        z = 7.0 + (h - 1 - yy) / sv
        # Deep checks: weathered piles split along the grain.
        for _ in range(7):
            cx = rng.uniform(0, w); top = rng.uniform(7.6, 9.6); length = rng.uniform(0.5, 1.6)
            dx = np.abs((xx - cx + w / 2) % w - w / 2 + 1.2 * np.sin(z * 5 + cx))
            along = smooth(top - length, top - length + 0.3, z) * smooth(top, top - 0.25, z)
            crack = np.clip(1 - dx / (1.6 * at.k), 0, 1) * along
            col *= (1 - 0.62 * crack)[..., None]
            hgt -= 0.035 * crack
        # The water is at 7.5; waves and wicking keep the wood dark for about half a stud above it.
        line = WATERLINE + 0.45 + 0.3 * (noise(1, w, (1, w / 5), rng, 3, wrap_x=True)[0][None, :] - 0.5)
        wet = smooth(line + 0.2, line - 0.1, z)
        soaked = smooth(line - 0.12, line - 0.34, z)
        wetcol = mix(col * 0.36, rgb(WET) * 0.75 * (col @ LUMA / (col @ LUMA).mean())[..., None], 0.7)
        col = mix(col, wetcol, wet)
        hgt = hgt * (1 - 0.45 * wet)                      # soaked wood swells smooth
        scum = smooth(line + 0.02, line + 0.12, z) * smooth(line + 0.3, line + 0.14, z)
        col = mix(col, rgb((150, 142, 124)), 0.16 * scum * noise(h, w, (5, 14), rng, wrap_x=True))
        green = np.exp(-((z - WATERLINE - 0.1) / 0.17) ** 2) * (0.35 + 0.65 * noise(h, w, (10, 20), rng, wrap_x=True))
        col = mix(col, rgb(ALGAE), 0.5 * green)
        # Wet wood is only a little glossier: a mirror finish would pick up the sky and read pale.
        rough = mix(rough, 0.46 + 0.12 * noise(h, w, 8, rng, wrap_x=True), soaked)
        rough = mix(rough, 0.7, 0.6 * wet * (1 - soaked))
        bleach = smooth(9.3, 9.6, z)
        col = mix(col, col * 1.14 + 0.015, 0.7 * bleach)
        at.paint(name, col, hgt, rough, su, sv)
    for v, name in enumerate(("postLowA", "postLowB")):
        w, h = at.dims(name)
        su, sv = w / 2.83, h / 7.0
        blend = int(0.12 * (scan.boards[0][1] - scan.boards[0][0]))
        sc, sr = scan.strip(2 * v, 0.5, 0.45)
        col, hgt, rough = wood(tile_x(sc, blend), tile_x(sr, blend), h, w, TIMBER, 1.0, 0.0, grain=0.008, wrap_x=True, upright=True, rng=rng)
        yy = np.mgrid[0:h, 0:w][0].astype(np.float32)
        z = 7.0 * (h - 1 - yy) / (h - 1)
        col = mix(col * 0.42, rgb(WET) * 0.85 * (col @ LUMA / (col @ LUMA).mean())[..., None], 0.7)
        green = smooth(3.0, 7.0, z) * (0.3 + 0.7 * noise(h, w, (16, 12), rng, wrap_x=True))
        col = mix(col, rgb(ALGAE) * 0.9, 0.42 * green)
        mud = smooth(1.6, 0.2, z + 0.8 * (noise(h, w, (12, 12), rng, wrap_x=True) - 0.5))
        col = mix(col, rgb((74, 66, 50)), 0.75 * mud)
        rough = mix(np.full((h, w), 0.5, np.float32), 0.8, mud)
        at.paint(name, col, hgt, rough, su, sv)

    w, h = at.dims("pole")              # lamp pole, used twice up its height
    blend = int(0.12 * (scan.boards[0][1] - scan.boards[0][0]))
    sc, sr = scan.strip(0, 0.2, 0.5, width=0.62)
    col, hgt, rough = wood(tile_x(sc, blend // 2), tile_x(sr, blend // 2), h, w, TIMBER, 0.9, 0.015, grain=0.005, wrap_x=True, upright=True, rng=rng)
    at.paint("pole", col, hgt, rough, w / 1.38, h / 3.75)


def metal(h, w, rng, base, rust_amount, wrap_x=False):
    """Painted or galvanised metal: mottled, chipped, rust where `rust_amount` (0..1 map or number) allows."""
    mott = noise(h, w, 10, rng, 3, wrap_x)
    fine = noise(h, w, 2, rng, 1, wrap_x)
    col = rgb(base) * (0.82 + 0.3 * mott + 0.12 * (fine - 0.5))[..., None]
    patch = smooth(0.52, 0.7, noise(h, w, 8, rng, 3, wrap_x) + 0.35 * (rust_amount - 0.5))
    patch = patch * np.clip(rust_amount * 2, 0, 1)
    col = mix(col, rgb(RUST) * (0.75 + 0.4 * fine)[..., None], 0.85 * patch)
    hgt = 0.004 * (mott - 0.5) + 0.006 * patch * fine
    rough = mix(0.42 + 0.2 * mott, 0.88, patch)
    return col.astype(np.float32), hgt.astype(np.float32), rough.astype(np.float32)


def paint_metal(at, rng):
    w, h = at.dims("iron")              # lamp plate, roof underside, cleat, lantern bars
    at.paint("iron", *metal(h, w, rng, IRON, 0.45), 40, 40)

    w, h = at.dims("zinc")
    at.paint("zinc", *metal(h, w, rng, ZINC, 0.3), 40, 40)

    w, h = at.dims("bollard")           # cast iron bollard, 2.2 studs round by 0.88 tall
    yy = np.mgrid[0:h, 0:w][0].astype(np.float32)
    col, hgt, rough = metal(h, w, rng, IRON, 0.35 + 0.5 * smooth(h * 0.4, h, yy), wrap_x=True)
    rubbed = np.exp(-((yy - 0.62 * h) / (0.1 * h)) ** 2)           # where the rope runs it shines
    col = mix(col, rgb((98, 96, 96)), 0.5 * rubbed)
    rough = mix(rough, 0.34, 0.6 * rubbed)
    at.paint("bollard", col, hgt, rough, w / 2.2, h / 0.88)

    w, h = at.dims("rail")              # ladder rail, 4.5 studs tall: z 4.75 to 9.25
    yy = np.mgrid[0:h, 0:w][0].astype(np.float32)
    z = 4.75 + 4.5 * (h - 1 - yy) / (h - 1)
    under = smooth(WATERLINE + 0.2, WATERLINE - 0.1, z)
    splash = np.exp(-((z - WATERLINE - 0.1) / 0.5) ** 2)
    col, hgt, rough = metal(h, w, rng, ZINC, 0.25 + 0.75 * np.maximum(splash, 0.6 * under))
    col = mix(col, col * 0.5, under)
    col = mix(col, rgb(ALGAE), 0.3 * under * smooth(4.75, 7.2, z))
    rough = mix(rough, 0.35, 0.7 * under)
    at.paint("rail", col, hgt, rough, w / 0.8, h / 4.5)

    w, h = at.dims("rung")              # worn bright in the middle by feet
    xx = np.mgrid[0:h, 0:w][1].astype(np.float32)
    col, hgt, rough = metal(h, w, rng, ZINC, 0.4)
    worn = np.exp(-((xx - w / 2) / (0.28 * w)) ** 2)
    col = mix(col, rgb((150, 153, 154)), 0.45 * worn)
    rough = mix(rough, 0.3, 0.5 * worn)
    at.paint("rung", col, hgt, rough, w / 1.6, h / 0.35)

    w, h = at.dims("bucket")            # galvanised bait bucket, 2.83 round by 0.8 tall
    yy = np.mgrid[0:h, 0:w][0].astype(np.float32)
    v = 1 - yy / (h - 1)
    col, hgt, rough = metal(h, w, rng, ZINC, 0.15 + 0.6 * smooth(0.25, 0.0, v), wrap_x=True)
    spangle = noise(h, w, 5, rng, 2, wrap_x=True)
    col *= (0.9 + 0.2 * spangle)[..., None]
    ribs = np.exp(-((v - 0.3) / 0.035) ** 2) + np.exp(-((v - 0.72) / 0.035) ** 2) + 1.4 * np.exp(-((v - 0.97) / 0.03) ** 2)
    hgt += 0.02 * ribs
    col *= (1 - 0.18 * (np.exp(-((v - 0.25) / 0.03) ** 2) + np.exp(-((v - 0.67) / 0.03) ** 2)))[..., None]
    at.paint("bucket", col, hgt, rough, w / 2.83, h / 0.8)

    w, h = at.dims("soil")              # looking down into the bucket: rim, dark soil, worms
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    px, py = (xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2)
    r = np.sqrt(px ** 2 + py ** 2)
    crumb = noise(h, w, 3, rng, 2)
    col = rgb((52, 40, 30)) * (0.7 + 0.6 * crumb)[..., None]
    hgt = 0.02 * crumb
    rough = np.full((h, w), 0.93, np.float32)
    for _ in range(5):
        cx, cy, a = rng.uniform(-0.45, 0.45), rng.uniform(-0.45, 0.45), rng.uniform(0, math.pi)
        ux = (px - cx) * math.cos(a) + (py - cy) * math.sin(a)
        uy = -(px - cx) * math.sin(a) + (py - cy) * math.cos(a) + 0.1 * np.sin(ux * 11)
        worm = np.clip(1 - np.abs(uy) / 0.055, 0, 1) * smooth(0.26, 0.2, np.abs(ux))
        col = mix(col, rgb((150, 98, 90)) * (0.85 + 0.15 * np.cos(ux * 60))[..., None], 0.85 * smooth(0.1, 0.5, worm))
        hgt += 0.02 * np.sqrt(worm)
        rough = mix(rough, 0.35, smooth(0.1, 0.5, worm))
    rim = smooth(0.8, 0.86, r)
    zc, _, zr = metal(h, w, rng, ZINC, 0.2)
    col = mix(col, zc, rim); rough = mix(rough, zr, rim); hgt = hgt * (1 - rim) + 0.03 * rim
    at.paint("soil", col, hgt, rough, w / 0.9, h / 0.9)


def paint_rope(at, rng):
    """Three-strand rope. `rope` is one length (wraps both ways, for the coils); `ropeWrap`
    is three turns stacked, for the hitch round each bollard."""
    def lay(h, w, turns, strands, bands):
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        u, v = xx / w, yy / h
        vb = (v * bands) % 1.0
        phase = (turns * u + strands * vb) % 1.0
        strand = np.sqrt(np.clip(1 - (2 * phase - 1) ** 2, 0, 1))          # round strands
        fibre = noise(h, w, (2, 7), rng, 2, wrap_x=True)
        round_ = np.sqrt(np.clip(1 - (2 * vb - 1) ** 2, 0, 1)) if bands > 1 else np.ones_like(vb)
        grime = noise(h, w, (h / 2, w / 6), rng, 2, wrap_x=True)
        shade = (0.4 + 0.58 * strand ** 0.7 + 0.34 * (fibre - 0.5)) * (0.5 + 0.5 * round_)
        col = mix(rgb((86, 66, 46)), rgb(ROPE), np.clip(shade, 0, 1)[..., None])            # warm brown in the lay, bleached on top
        col = mix(col, col * np.array([0.7, 0.69, 0.68], np.float32), 0.8 * smooth(0.35, 0.7, grime))        # handled, weathered lengths
        hgt = 0.035 * strand * round_ + 0.05 * (round_ - 1) + 0.006 * fibre
        rough = np.clip(0.93 - 0.08 * strand, 0, 1)
        return col.astype(np.float32), hgt.astype(np.float32), rough.astype(np.float32)

    w, h = at.dims("rope")              # 4 studs of rope, 0.7 round: the strands lie at about 40 degrees
    at.paint("rope", *lay(h, w, 15, 3, 1), w / 4.0, h / 0.7)
    w, h = at.dims("ropeWrap")
    at.paint("ropeWrap", *lay(h, w, 22, 1, 3), w / 3.3, h / 0.42)


def paint_lamp(at, rng):
    w, h = at.dims("glass")             # one lantern pane, shared by the four sides
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    px, py = (xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2)
    frame = np.maximum(smooth(0.8, 0.86, np.abs(px)), smooth(0.84, 0.9, np.abs(py)))
    glow = np.exp(-(px ** 2 + (py - 0.15) ** 2) / 0.5)
    pane = rgb(LANTERN) * (0.7 + 0.3 * glow)[..., None]
    pane = mix(pane, pane * 0.8, 0.5 * noise(h, w, 10, rng))         # a little soot
    ic, ih, ir = metal(h, w, rng, IRON, 0.4)
    col = mix(pane, ic, frame)
    hgt = 0.03 * frame + ih
    rough = mix(np.full((h, w), 0.18, np.float32), ir, frame)
    at.paint("glass", col, hgt, rough, w / 0.9, h / 1.0, emit=(1 - frame) * (0.75 + 0.25 * glow))

    w, h = at.dims("roof")              # one roof slope: standing seams, rust at the eaves
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    v = 1 - yy / (h - 1)
    col, hgt, rough = metal(h, w, rng, IRON, 0.25 + 0.6 * smooth(0.35, 0.0, v))
    seam = np.exp(-(((xx / w * 4) % 1.0 - 0.5) / 0.09) ** 2)
    hgt += 0.02 * seam
    col *= (1 + 0.12 * seam)[..., None]
    at.paint("roof", col, hgt, rough, w / 1.7, h / 0.9)


def compose(size):
    at = Atlas(size)
    layout(at)
    scan = Scan("1k" if size <= 1024 else "2k")
    rng = np.random.default_rng(1127)
    gain = paint_boards(at, scan, rng)
    paint_plain_wood(at, scan, rng)
    paint_posts(at, scan, rng)
    paint_metal(at, rng)
    paint_rope(at, rng)
    paint_lamp(at, rng)
    used = sum(w * h for _, _, w, h in at.rects.values()) / size ** 2
    tops = np.concatenate([at.color[y:y + h, x:x + w].reshape(-1, 3) for n, (x, y, w, h) in at.rects.items() if n.startswith("board")])
    mean = tuple(int(round(c * 255)) for c in tops.mean(0))
    print(f"[dock_hero] atlas {size}: {len(at.rects)} rectangles, {used:.0%} used; deck mean {mean} (target {DECK}), gain {np.round(gain, 3)}")
    SCRATCH.mkdir(parents=True, exist_ok=True)
    paths = {k: SCRATCH / f"{NAME}_{k}.png" for k in ("color", "normal", "rough", "emissive")}
    write_png(paths["color"], at.color)
    write_png(paths["normal"], at.normal)
    write_png(paths["rough"], at.rough)
    write_png(paths["emissive"], at.emit)
    return at, paths, mean


# --------------------------------------------------------------------------- the mesh

class Builder:
    """Collects quads and fans with explicit UVs into one mesh."""

    def __init__(self, at):
        self.at = at
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def face(self, pts, uvs, smooth_=False, verts=None):
        vs = verts or [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(vs)
        f.smooth = smooth_
        for loop, t in zip(f.loops, uvs):
            loop[self.uv].uv = t
        return f

    def quad(self, pts, rect, rot=0, sub=(0, 0, 1, 1)):
        """A flat quad, corners counter-clockwise seen from outside, first corner at the
        rectangle's bottom-left. `rot` turns the picture in quarter turns."""
        uvs = self.at.uv(rect, sub)
        self.face(pts, [uvs[(i + rot) % 4] for i in range(4)])

    def box(self, size, loc, faces):
        """A box. `faces` maps '+x' '-x' '+y' '-y' '+z' '-z' to (rect, rot) or (rect, rot, sub);
        '*' is the default. Picture 'up' is +z on the sides and +y on the top."""
        x, y, z = (s / 2 for s in size)
        cx, cy, cz = loc
        corners = {
            "+z": [(-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)],
            "-z": [(-x, y, -z), (x, y, -z), (x, -y, -z), (-x, -y, -z)],
            "+y": [(x, y, -z), (-x, y, -z), (-x, y, z), (x, y, z)],
            "-y": [(-x, -y, -z), (x, -y, -z), (x, -y, z), (-x, -y, z)],
            "+x": [(x, -y, -z), (x, y, -z), (x, y, z), (x, -y, z)],
            "-x": [(-x, y, -z), (-x, -y, -z), (-x, -y, z), (-x, y, z)],
        }
        for key, pts in corners.items():
            spec = faces.get(key, faces.get("*"))
            if spec is None:
                continue
            rect, rot = spec[0], spec[1]
            sub = spec[2] if len(spec) > 2 else (0, 0, 1, 1)
            self.quad([(cx + a, cy + b, cz + c) for a, b, c in pts], rect, rot, sub)

    def cyl(self, r, zs, loc, n, rects, cap_top=None, cap_bottom=None, r_top=None, phase=0.0, smooth_=True):
        """An upright n-sided cylinder through the heights `zs`; each span between two
        heights wraps one rectangle from `rects` right round. Optional taper and caps."""
        cx, cy = loc
        r_top = r if r_top is None else r_top
        rings = []
        for z in zs:
            t = (z - zs[0]) / (zs[-1] - zs[0])
            rr = r + (r_top - r) * t
            rings.append([self.bm.verts.new((cx + rr * math.cos(phase + 2 * math.pi * i / n), cy + rr * math.sin(phase + 2 * math.pi * i / n), z)) for i in range(n)])
        for k, rect in enumerate(rects):
            a, b = rings[k], rings[k + 1]
            for i in range(n):
                j = (i + 1) % n
                uvs = self.at.uv(rect, (i / n, 0, (i + 1) / n, 1))
                self.face(None, uvs, smooth_, verts=[a[i], a[j], b[j], b[i]])
        ang = [phase + 2 * math.pi * i / n for i in range(n)]
        if cap_top:
            rr, z = r_top, zs[-1]
            self.face([(cx + rr * math.cos(a), cy + rr * math.sin(a), z) for a in ang],
                      [self.at.point(cap_top, 0.5 + 0.5 * math.cos(a - phase), 0.5 + 0.5 * math.sin(a - phase)) for a in ang])
        if cap_bottom:
            z = zs[0]
            self.face([(cx + r * math.cos(a), cy + r * math.sin(a), z) for a in reversed(ang)],
                      [self.at.point(cap_bottom, 0.5 + 0.5 * math.cos(a - phase), 0.5 - 0.5 * math.sin(a - phase)) for a in reversed(ang)])

    def torus(self, loc, big, small, n_big, n_small, rect, tilt=(0.0, 0.0), squash=1.0):
        """A ring of rope lying flat: the rectangle runs along the rope and wraps round it."""
        cx, cy, cz = loc
        grid = []
        for i in range(n_big):
            th = 2 * math.pi * i / n_big
            ring = []
            for j in range(n_small):
                ph = 2 * math.pi * j / n_small
                x, y = (big + small * math.cos(ph)) * math.cos(th), (big + small * math.cos(ph)) * math.sin(th)
                z = small * squash * math.sin(ph) + x * tilt[0] + y * tilt[1]
                ring.append(self.bm.verts.new((cx + x, cy + y, cz + z)))
            grid.append(ring)
        for i in range(n_big):
            for j in range(n_small):
                i2, j2 = (i + 1) % n_big, (j + 1) % n_small
                uvs = self.at.uv(rect, (i / n_big, j / n_small, (i + 1) / n_big, (j + 1) / n_small))
                self.face(None, uvs, True, verts=[grid[i][j], grid[i2][j], grid[i2][j2], grid[i][j2]])

    def finish(self, name):
        me = bpy.data.meshes.new(name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def build(at):
    b = Builder(at)
    rnd = random.Random(27)
    deck_z = TOP - PLANK_T / 2
    shore_l = WALK_L - END_L            # 38: where the walkway meets the end deck

    # Deck boards. Each takes one of the 14 tops, straight or turned half round (never
    # mirrored), and never the same one as its neighbours. Every board is 8 studs long,
    # the length of its picture, so the nail heads land on the timbers below. On the
    # walkway the boards lie across it. On the end deck they lie the other way, across
    # the three beams that span from post to post, which is how a dock head is built and
    # leaves no butt joints.
    last = [-1]

    def board(length, x, y, across=True):
        v = rnd.choice([i for i in range(N_BOARDS) if i not in last])
        last[:] = (last + [v])[-3:]
        ends = [(rnd.choice(("endA", "endB")), 0) for _ in range(2)]
        if across:
            b.box((length, 0.9, PLANK_T), (x, y, deck_z), {
                "+z": (f"board{v}", rnd.choice((0, 2))), "-z": ("under", rnd.choice((0, 2))),
                "+y": ("side", 0), "-y": ("side", 2), "+x": ends[0], "-x": ends[1]})
        else:
            b.box((0.9, length, PLANK_T), (x, y, deck_z), {
                "+z": (f"board{v}", rnd.choice((1, 3))), "-z": ("under", rnd.choice((1, 3))),
                "+x": ("side", 0), "-x": ("side", 2), "+y": ends[0], "-y": ends[1]})

    y, i = 0.5, 0
    while y < shore_l:
        board(WALK_W + (0.25 if i % 3 == 0 else 0), 0.1 if i % 2 else -0.1, y)
        y += 1.0; i += 1
    x, i = -END_W / 2 + 0.5, 0
    while x < END_W / 2:
        # Uneven ends on the lake side only; the two boards the ladder hangs from stay square.
        extra = 0.0 if abs(x) < 1 else (0.0, 0.18, 0.07, 0.22, 0.0, 0.12)[i % 6]
        board(END_L - 0.04 + extra, x, shore_l + 0.04 + (END_L - 0.04 + extra) / 2, across=False)
        x += 1.0; i += 1

    # Stringers under the walkway, in four lengths so the strip keeps its texel density.
    # They run on to meet the first beam of the end deck.
    str_z = TOP - PLANK_T - 0.3
    seg = (shore_l + 0.3) / 4
    for x in (-WALK_W / 2 + 0.6, 0, WALK_W / 2 - 0.6):
        for k in range(4):
            b.box((0.6, seg, 0.6), (x, seg * (k + 0.5), str_z), {
                "+x": ("stringer", 0), "-x": ("stringer", 2), "+z": ("stringer", 1), "-z": ("stringer", 3),
                "-y": ("endA", 0) if k == 0 else None, "+y": ("endA", 0) if k == 3 else None})
    # Three beams under the end deck, post to post, each in two lengths. They sit where
    # the end deck boards' nails are (3.4 studs either side of the middle).
    for y in (shore_l + 0.6, shore_l + 4.0, WALK_L - 0.6):
        for side in (-1, 1):
            b.box((END_W / 2, 0.6, 0.6), (side * END_W / 4, y, str_z), {
                "+y": ("stringer", 0, (0, 0, 0.84, 1)), "-y": ("stringer", 2, (0.16, 0, 1, 1)),
                "+z": ("stringer", 0, (0, 0, 0.84, 1)), "-z": ("stringer", 0, (0.16, 0, 1, 1)),
                "+x": ("endB", 0) if side > 0 else None, "-x": ("endB", 0) if side < 0 else None})

    # Posts: pairs along the walkway, four under the end deck, split at 7 studs so the
    # part above the water gets most of the pixels.
    n = 0
    for py in range(4, shore_l, 7):
        for px in (-WALK_W / 2 + 0.4, WALK_W / 2 - 0.4):
            ab = "AB"[n % 2]
            b.cyl(0.45, (0, 7.0, TOP + 0.6), (px, py), 8, (f"postLow{ab}", f"postTop{'AB'[(n // 2) % 2]}"),
                  cap_top=f"cap{ab}", cap_bottom="iron", phase=rnd.uniform(0, 6.28))
            n += 1
    for px in (-END_W / 2 + 0.4, END_W / 2 - 0.4):
        for py in (shore_l + 0.5, WALK_L - 0.5):
            ab = "AB"[n % 2]
            b.cyl(0.5, (0, 7.0, TOP + 0.8), (px, py), 8, (f"postLow{ab}", f"postTop{'BA'[(n // 2) % 2]}"),
                  cap_top=f"cap{'BA'[n % 2]}", cap_bottom="iron", phase=rnd.uniform(0, 6.28))
            n += 1

    # Bollards with a hitch of rope, for tying up the boat.
    for px in (-WALK_W / 2 + 0.5, WALK_W / 2 - 0.5):
        py = shore_l - 2
        b.cyl(0.35, (TOP, TOP + 0.88), (px, py), 8, ("bollard",), phase=px)
        b.cyl(0.45, (TOP + 0.88, TOP + 1.0), (px, py), 8, ("zinc",), cap_top="iron", cap_bottom="iron", phase=px)
        b.cyl(0.5, (TOP, TOP + 0.42), (px, py), 10, ("ropeWrap",), cap_top="iron", phase=px + 0.3)

    # Two coils of rope, off the walking line, and a tail of line to a cleat.
    def coil(x, y, rings, seed):
        r2 = random.Random(seed)
        z = TOP + 0.105
        for k, big in enumerate(rings):
            b.torus((x + r2.uniform(-0.05, 0.05), y + r2.uniform(-0.05, 0.05), z), big, 0.11, 12, 6, "rope",
                    tilt=(r2.uniform(-0.035, 0.035), r2.uniform(-0.035, 0.035)), squash=0.95)
            z += 0.17 if k % 2 else 0.02

    # Each coil: pairs of turns side by side, a narrower pair laid on top.
    coil(-6.1, shore_l + 1.9, (0.84, 0.62, 0.74, 0.52, 0.66), 3)
    coil(-2.8, 29.6, (0.72, 0.5, 0.62), 5)

    def cleat(x, y, along_x):
        """A horn cleat: two feet and a bar."""
        l, w = (1.3, 0.22) if along_x else (0.22, 1.3)
        fx, fy = (0.3, 0.0) if along_x else (0.0, 0.3)
        for s in (-1, 1):
            b.box((0.2, 0.2, 0.2), (x + s * fx, y + s * fy, TOP + 0.1), {"*": ("zinc", 0, (0, 0, 0.5, 1)), "-z": None})
        top = ("zinc", 0) if along_x else ("zinc", 1)
        b.box((l, w, 0.16), (x, y, TOP + 0.28), {"*": ("zinc", 0), "+z": top, "-z": top})

    cleat(4.3, WALK_L - 0.55, True)
    cleat(WALK_W / 2 - 0.45, 21.4, False)

    # Ladder off the end into the water.
    for px in (-0.8, 0.8):
        b.box((0.2, 0.2, 4.5), (px, WALK_L + 0.2, TOP - 2.0), {"*": ("rail", 0), "+z": ("zinc", 0, (0, 0, 0.4, 0.8)), "-z": ("zinc", 0, (0, 0, 0.4, 0.8))})
    for k in range(4):
        b.box((1.6, 0.2, 0.15), (0, WALK_L + 0.2, TOP - 0.6 - k * 1.0), {
            "+z": ("rung", 0), "-z": ("rung", 0), "+y": ("rung", 0, (0, 0, 1, 0.45)), "-y": ("rung", 0, (0, 0, 1, 0.45))})

    # Two lamp posts at the end deck corners: a timber pole, an iron lantern.
    for px in (-END_W / 2 + 0.5, END_W / 2 - 0.5):
        ly = WALK_L - 1.5
        b.cyl(0.22, (TOP, TOP + 3.75, TOP + 7.5), (px, ly), 6, ("pole", "pole"), phase=0.5)
        b.box((1.4, 1.4, 0.25), (px, ly, TOP + 7.6), {"*": ("iron", 0, (0, 0, 1, 0.3)), "+z": ("iron", 0), "-z": ("iron", 0)})
        b.box((0.9, 0.9, 1.0), (px, ly, TOP + 8.2), {"+x": ("glass", 0), "-x": ("glass", 0), "+y": ("glass", 0), "-y": ("glass", 0)})
        for sx in (-1, 1):
            for sy in (-1, 1):
                b.box((0.14, 0.14, 1.0), (px + sx * 0.45, ly + sy * 0.45, TOP + 8.2), {
                    "*": ("iron", 0, (0, 0, 0.3, 1)), "+z": None, "-z": None})
        a, c, z0, z1 = 0.85, 0.1, TOP + 8.7, TOP + 9.2
        inset = 0.5 * (1 - c / a)
        sub_uv = at.uv("roof")
        (u0, v0), (u1, _), (_, v1), _ = sub_uv
        trap = [(u0, v0), (u1, v0), (u1 - (u1 - u0) * inset, v1), (u0 + (u1 - u0) * inset, v1)]
        for q in range(4):
            ca, sa = round(math.cos(q * math.pi / 2)), round(math.sin(q * math.pi / 2))
            def turn(x, y, z):
                return (px + x * ca - y * sa, ly + x * sa + y * ca, z)
            b.face([turn(a, a, z0), turn(-a, a, z0), turn(-c, c, z1), turn(c, c, z1)], trap)
        b.quad([(px - c, ly - c, z1), (px + c, ly - c, z1), (px + c, ly + c, z1), (px - c, ly + c, z1)], "iron", 0, (0, 0, 0.2, 0.2))
        b.quad([(px - a, ly + a, z0), (px + a, ly + a, z0), (px + a, ly - a, z0), (px - a, ly - a, z0)], "iron", 0)

    # A bait bucket for character.
    bx, by = 2.4, shore_l - 4
    b.cyl(0.38, (TOP, TOP + 0.8), (bx, by), 10, ("bucket",), cap_top="soil", cap_bottom="iron", r_top=0.45)

    ob = b.finish(NAME)
    # Pivot: bottom centre of the bounding box, the same rule as every other model.
    lo, hi = bounds([ob])
    shift = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for v in ob.data.vertices:
        v.co -= shift
    ob.data.update()
    return ob, shift


def material(paths, glow=False):
    m = bpy.data.materials.new(NAME)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]

    def tex(key, space):
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(str(paths[key]), check_existing=True)
        t.image.colorspace_settings.name = space
        return t

    nt.links.new(tex("color", "sRGB").outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex("rough", "Non-Color").outputs["Color"], bsdf.inputs["Roughness"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tex("normal", "Non-Color").outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Metallic"].default_value = 0.0
    if glow:   # previews only: stands in for the Neon part and light the game adds
        e = tex("emissive", "Non-Color")
        mul = nt.nodes.new("ShaderNodeMixRGB"); mul.blend_type = "MULTIPLY"; mul.inputs[0].default_value = 1.0
        mul.inputs[1].default_value = tuple(common.srgb_to_linear(c) for c in LANTERN) + (1.0,)
        nt.links.new(e.outputs["Color"], mul.inputs[2])
        nt.links.new(mul.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 4.0
    return m


def export(ob):
    MODELS.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    out = MODELS / f"{NAME}.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(out), use_selection=True, export_format="GLB", export_image_format="AUTO",
        export_yup=True, export_apply=True, export_vertex_color="NONE", export_tangents=False,
    )
    (MODELS / "roblox").mkdir(exist_ok=True)
    shutil.copyfile(out, MODELS / "roblox" / f"{NAME}.glb")   # textures need no colour fix
    return out


# --------------------------------------------------------------------------- previews

def _lin(c):
    return tuple(common.srgb_to_linear(v) for v in c) + (1.0,)


def _flat(name, colour, rough=0.9, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = _lin(colour)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Alpha"].default_value = alpha
    return m


def stage(lo, hi):
    """Water at the game's level, a bank at the shore end and the lake bed, so the
    perspective previews read like the place. Model space: the pivot is the origin."""
    made = []

    def slab(size, loc, m):
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
        o = bpy.context.object
        o.scale = size
        o.data.materials.append(m)
        made.append(o)

    y0 = lo.y
    slab((400, 400, 0.02), (0, y0 + 150, WATERLINE), _flat("_water", (26, 66, 62), 0.06, 0.86))
    slab((400, 400, 0.1), (0, y0 + 150, -0.05), _flat("_bed", (70, 64, 50)))
    slab((400, 120, 8.5), (0, y0 - 59.5, 4.25), _flat("_bank", (104, 122, 62)))
    slab((400, 3, 8.2), (0, y0 + 1.2, 4.1), _flat("_wetsand", (112, 98, 74)))
    return made


def camera(pos, look, fov=70.0):
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    bpy.context.scene.collection.objects.link(cam)
    cam.location = pos
    cam.rotation_euler = (Vector(look) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle_y = math.radians(fov)     # Roblox's FieldOfView is the vertical angle, 70 by default
    cam.data.clip_start, cam.data.clip_end = 0.05, 2000
    bpy.context.scene.camera = cam
    return cam


def shrink(src, dst):
    """Previews in git are 256-colour PNGs (the same rule as common._shrink_png). Blender's
    Python has no Pillow, so this asks the system Python; without it the full file is copied.
    The palette is picked for coverage first: median cut alone turned the small grey parts
    (lantern roofs, cleats) the colour of the water."""
    code = ("import sys;from PIL import Image;im=Image.open(sys.argv[1]).convert('RGB');"
            "pal=im.quantize(colors=256,method=Image.Quantize.MAXCOVERAGE);"
            "im.quantize(palette=pal,dither=Image.Dither.FLOYDSTEINBERG).save(sys.argv[2],optimize=True)")
    try:
        subprocess.run(["python", "-c", code, str(src), str(dst)], check=True, capture_output=True, timeout=120)
    except Exception:
        shutil.copyfile(src, dst)


def previews(ob, paths, opt):
    scene = bpy.context.scene
    lo, hi = bounds([ob])
    renders = SCRATCH / "renders"
    renders.mkdir(parents=True, exist_ok=True)
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    ob.data.materials.clear()
    ob.data.materials.append(material(paths, glow=True))
    want = opt["views"] or ["hero", "front", "threequarter", "deck", "ingame", "posts"]
    common.PREVIEW_SAMPLES = opt["samples"]
    top = TOP                                   # the pivot is the model base, so heights carry over
    y0 = lo.y                                   # the shore end; y0 + 46.3 is the lake end

    if "hero" in want:                          # the same camera and light as art/previews/Dock.png
        ground, sun, cam = common._setup_render(lo, hi, (40, 30))
        scene.render.filepath = str(renders / f"{NAME}.png")
        bpy.ops.render.render(write_still=True)
        shrink(renders / f"{NAME}.png", PREVIEWS / f"{NAME}.png")
        for o in (ground, sun, cam):
            bpy.data.objects.remove(o, do_unlink=True)

    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = opt["samples"]
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("sky2")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.62, 0.76, 0.92, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    scene.world = world
    sun = bpy.data.objects.new("Sun2", bpy.data.lights.new("Sun2", "SUN"))
    sun.data.energy = 3.4
    sun.data.angle = math.radians(3)
    sun.rotation_euler = (math.radians(58), 0, math.radians(-125))   # mid-afternoon, raking across the boards
    scene.collection.objects.link(sun)
    stage(lo, hi)

    shots = {
        # From a boat off the lake end, looking back at the end deck.
        "front": ((7.0, y0 + 46.3 + 21.0, top + 3.2), (0.0, y0 + 43.0, top + 1.6), 50, (1280, 800)),
        "threequarter": ((23.0, y0 + 46.3 + 13.0, top + 9.5), (-1.0, y0 + 30.0, top - 0.5), 50, (1280, 800)),
        # Standing on the walkway looking down at the boards: the lens is 3 studs from them.
        "deck": ((1.3, y0 + 27.6, top + 2.45), (0.2, y0 + 29.35, top), 70, (1280, 800)),
        # A player on the bank, eyes about 5.5 studs up, 45 studs from the middle of the dock.
        "ingame": ((-34.0, y0 - 5.0, top + 5.0), (2.0, y0 + 27.0, top + 1.0), 70, (1280, 720)),
        # From a boat alongside, low: the waterline on the posts, the stringers, the board ends.
        "posts": ((-11.5, y0 + 30.5, WATERLINE + 2.3), (-3.0, y0 + 26.0, WATERLINE + 0.9), 50, (1280, 800)),
    }
    for key, (pos, look, fov, res) in shots.items():
        if key not in want:
            continue
        cam = camera(pos, look, fov)
        scene.render.resolution_x, scene.render.resolution_y = res
        scene.render.filepath = str(renders / f"{NAME}-{key}.png")
        bpy.ops.render.render(write_still=True)
        shrink(renders / f"{NAME}-{key}.png", PREVIEWS / f"{NAME}-{key}.png")
        bpy.data.objects.remove(cam, do_unlink=True)


def sheets(paths):
    """The atlas sheet (colour, normal, roughness) and the before and after pair."""
    col, nor, rou = (load_rgb(paths[k]) for k in ("color", "normal", "rough"))
    half = lambda a: resize(a, 512, 512)
    sheet = np.concatenate([half(col), half(nor), half(rou)], 1)
    write_png(SCRATCH / f"{NAME}-atlas.png", sheet)
    shrink(SCRATCH / f"{NAME}-atlas.png", PREVIEWS / f"{NAME}-atlas.png")
    before, after = PREVIEWS / "Dock.png", SCRATCH / "renders" / f"{NAME}.png"
    if before.exists() and after.exists():
        a, c = load_rgb(before), load_rgb(after)
        if a.shape != c.shape:
            a = resize(a, c.shape[0], c.shape[1])
        gap = np.ones((c.shape[0], 12, 3), np.float32)
        write_png(SCRATCH / f"{NAME}-before-after.png", np.concatenate([a, gap, c], 1))
        shrink(SCRATCH / f"{NAME}-before-after.png", PREVIEWS / f"{NAME}-before-after.png")


def record(ob, glb, tris, size, deck_mean):
    lo, hi = bounds([ob])
    d = hi - lo
    entry = {
        "name": NAME,
        "studs": [round(d.x, 2), round(d.z, 2), round(d.y, 2)],
        "triangles": tris,
        "parts": 1,
        "replaces": "Dock (the vertex-colour dock in Lake.Art): same size, pivot and orientation",
        "notes": ("Hero set: one mesh, one UV set, colour, normal (OpenGL) and roughness maps embedded in the GLB; "
                  "Roblox makes the SurfaceAppearance on import. Upload art/models/roblox/DockHero.glb as it is "
                  "(no roblox_colors.py step). Base at y = -7.5, deck top y = 1.5, turned 180 degrees like Dock."),
        "textures": {"size": size, "maps": ["color", "normal", "roughness"], "deck_mean_rgb": list(deck_mean)},
        "glb_bytes": glb.stat().st_size,
    }
    data = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    data[NAME] = entry
    MANIFEST.write_text(json.dumps(dict(sorted(data.items())), indent=2) + "\n")
    return entry


def main():
    opt = parse_args()
    reset()
    at, paths, deck_mean = compose(opt["size"])
    if opt["maps_only"]:
        sheets(paths)
        return
    ob, shift = build(at)
    ob.data.materials.append(material(paths))
    ob.data.calc_loop_triangles()
    tris = len(ob.data.loop_triangles)
    if tris > 20000:
        raise SystemExit(f"{NAME}: {tris} triangles is over Roblox's 20,000")
    glb = export(ob)
    entry = record(ob, glb, tris, opt["size"], deck_mean)
    lo, hi = bounds([ob])
    print(f"[dock_hero] {NAME}: {entry['studs']} studs, {tris} triangles, GLB {glb.stat().st_size / 1e6:.2f} MB")
    print(f"[dock_hero] pivot shift {tuple(round(c, 3) for c in shift)}; bounds {tuple(round(c, 3) for c in lo)} to {tuple(round(c, 3) for c in hi)}")
    # Where the lantern glass is, for the Neon part and light the game adds (model space, studs, Blender axes).
    for px in (-END_W / 2 + 0.5, END_W / 2 - 0.5):
        c = Vector((px, WALK_L - 1.5, TOP + 8.2)) - shift
        print(f"[dock_hero] lantern glass 0.9 x 1.0 x 0.9 centred at Blender {tuple(round(v, 3) for v in c)} = Roblox model ({-c.x:.3f}, {c.z:.3f}, {c.y:.3f}) before the 180 degree turn")
    if not opt["no_render"]:
        previews(ob, paths, opt)
    sheets(paths)


if __name__ == "__main__":
    main()
