"""CedarCanoe: the two-seat cedar-strip canoe of leg 3 (N4), as a hero set, with its paddle
and the plain vertex-coloured twins for the phone tier.

    blender -b --factory-startup -P art/scripts/cedar_canoe.py -- [options]

    --samples 48       preview render samples
    --views a,b        only these previews (hero, golden, match, threequarter, ingame, inside, low, paddle, plain)
    --maps-only        compose the maps and the atlas sheets, then stop (fast, for tuning)
    --no-render        build and export, skip the previews
    --no-scan          draw the grain by noise even if the board scan is there (to test that
                       path; use it with --maps-only, the maps go to artifacts/cedar_canoe/no-scan/)
    --tag first        write the previews to artifacts/cedar_canoe/renders-<tag>/ only (for before and after)

What it makes
  CedarCanoe.glb        the hull: one mesh, one UV set, colour, normal (OpenGL) and roughness
                        maps at 1024 embedded, so Roblox imports a MeshPart with a SurfaceAppearance
  CanoePaddle.glb       one paddle, its own mesh and 512 x 256 maps; the top grip is the origin
  CedarCanoePlain.glb   the lighter twin: fewer faces, vertex colours only (as Dock is to DockHero)
  CanoePaddlePlain.glb  the paddle with vertex colours only

Axes. The model is designed with the bow toward +Y, then turned half round before export, so
the bow is at Blender -Y. Roblox shows Blender (x, y, z) at (-x, z, y) (art/README.md,
"Importing"), which puts the bow on Roblox -Z and starboard on Roblox +X. The origin of the
canoe file is the middle of the hull on the waterline. The hull is the same fore and aft, so
if an import ever lands it the other way round, a half turn only swaps the seats.

How it is made (the same way as dock_hero.py: no Blender bake, every pixel deliberate)
  1. The hull is lofted from sections: a plan curve, a sheer curve, a keel with a little
     rocker that turns up into curved stems, and a section that goes from a round bilge
     amidships to a V at the ends. Each section is cut into equal lengths of girth, so the
     strips in the texture follow rows of the mesh.
  2. An atlas is painted with numpy. The planking takes its grain from a CC0 scan of clean
     softwood boards (ambientCG Planks 021, already in artifacts/textures_src/; without it
     the grain is drawn by noise), one thin slice per strip, pulled to cedar colours that
     differ strip to strip. Seams, scarf joints, the feature stripe, ribs with their tacks
     and shadows, the cane weave and the worn varnish are drawn on top; normals come from
     the height of each rectangle.
  3. Port and starboard share the outside, gunwale, deck and stem rectangles by a half turn
     (never a mirror, so the normal map stays right). The two inside faces have their own.

Scratch (loose maps, full-size renders) goes to artifacts/cedar_canoe/, which is git-ignored.
The loose maps are also kept in art/textures/cedar_canoe/.
"""

import json
import math
import shutil
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common  # noqa: E402
import roblox_colors  # noqa: E402
from common import MANIFEST, MODELS, PREVIEWS, bounds, reset  # noqa: E402
from dock_hero import LUMA, blur, load_rgb, mix, noise, resize, rgb, shrink, smooth, write_png  # noqa: E402

NAME, PLAIN, PADDLE, PADDLE_PLAIN = "CedarCanoe", "CedarCanoePlain", "CanoePaddle", "CanoePaddlePlain"
REPO = Path(__file__).resolve().parents[2]
SCRATCH = REPO / "artifacts" / "cedar_canoe"
MAPS = REPO / "art" / "textures" / "cedar_canoe"
SCAN = REPO / "artifacts" / "textures_src" / "Planks021"

# ---- the boat, in studs. Heights are above the waterline (the pivot).
L = 12.4                 # over the stems
HULL_B = 3.0             # planking, outside to outside, at the sheer amidships
OUT_W, IN_W = 0.09, 0.11  # outwale and inwale; the beam over the outwales is HULL_B + 2 * OUT_W
SKIN = 0.08
# Roblox draws its lake inside any hull that reaches below the water, so the boat is drawn
# as an empty canoe floats (high) and the bottom boards are kept above the waterline: the
# bottom is thicker than a real one, which nobody can see.
DRAFT = 0.22             # keel below the waterline
FLOOR_Z = 0.22           # lowest point of the inside, above the waterline
ROCKER = 0.08
SHEER_MID, SHEER_RISE = 1.00, 0.58
STEM_TOP = 1.66
RAIL_UP, OUT_DROP, IN_DROP = 0.04, 0.10, 0.09
SEAT_Z = 0.64            # top of the seat frames
BOW_SEAT_Y, STERN_SEAT_Y = 2.30, -3.00      # design axes: bow toward +Y
SEAT_HALF = 0.44         # half the seat's length fore and aft
THWART_Z = 0.87
DECK_Y = 4.50
RIB_STEP, RIB_W, RIB_H = 0.40, 0.17, 0.05
UL = L + 0.4             # the length every lengthwise rectangle stands for
GIRTH = 2.35             # keel to sheer amidships, for texel scale
GIRTH_IN = 2.05          # the same on the inside

HERO_YS = [0.0, 0.8, 1.6, 2.4, 3.1, 3.7, 4.2, 4.6, 4.95, 5.25, 5.5, 5.72, 5.9]
PLAIN_YS = [0.0, 1.5, 3.0, 4.2, 5.0, 5.6]

# ---- palette (sRGB 0..255). Our own picks: the canoe is the warm note against the
# silver-brown dock timber (122,104,86) and the dark lake (26,66,62) of the Home lake row.
HONEY = (206, 138, 68)
AMBER = (196, 120, 54)
RUSSET = (176, 100, 48)
BROWN = (150, 86, 44)
PALE = (216, 170, 108)      # the light strip of the feature stripe, and the ribs' high tone
WALNUT = (78, 50, 34)       # the dark strips of the feature stripe
GUNWALE = (116, 66, 36)     # gunwales, stems, keel strip
ASH = (214, 172, 112)       # seat frames and the thwart
CANE = (216, 178, 110)
CANE_HOLE = (92, 64, 40)
RIB = (206, 140, 74)
TACK = (150, 118, 66)
SHADOW = (40, 28, 20)
WATER = (26, 66, 62)


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {"samples": 48, "views": None, "maps_only": False, "no_render": False, "tag": None, "no_scan": False}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--samples":
            opt["samples"] = int(argv[i + 1]); i += 1
        elif a == "--views":
            opt["views"] = argv[i + 1].split(","); i += 1
        elif a == "--tag":
            opt["tag"] = argv[i + 1]; i += 1
        elif a == "--maps-only":
            opt["maps_only"] = True
        elif a == "--no-render":
            opt["no_render"] = True
        elif a == "--no-scan":
            opt["no_scan"] = True
        else:
            raise SystemExit(f"unknown option {a}")
        i += 1
    return opt


# --------------------------------------------------------------------------- the atlas

class Atlas:
    """A shelf-packed atlas, width x height pixels. Each rectangle keeps a 3 pixel skirt of
    its own edge colour so mip levels do not bleed between neighbours."""
    PAD = 3

    def __init__(self, width, height, fill):
        self.w, self.h = width, height
        self.color = np.empty((height, width, 3), np.float32); self.color[:] = rgb(fill)
        self.normal = np.empty((height, width, 3), np.float32); self.normal[:] = (0.5, 0.5, 1.0)
        self.rough = np.full((height, width), 0.5, np.float32)
        self.rects = {}
        self._x = self._y = self._shelf = 0

    def alloc(self, name, w, h):
        p = self.PAD
        if self._x + w + 2 * p > self.w:
            self._x, self._y, self._shelf = 0, self._y + self._shelf, 0
        if self._y + h + 2 * p > self.h:
            raise SystemExit(f"atlas full at {name}")
        self.rects[name] = (self._x + p, self._y + p, w, h)
        self._x += w + 2 * p
        self._shelf = max(self._shelf, h + 2 * p)

    def column(self, items):
        p = self.PAD
        wide = max(w for _, w, _ in items) + 2 * p
        if self._x + wide > self.w:
            self._x, self._y, self._shelf = 0, self._y + self._shelf, 0
        y = self._y
        for name, w, h in items:
            if y + h + 2 * p > self.h:
                raise SystemExit(f"atlas full at {name}")
            self.rects[name] = (self._x + p, y + p, w, h)
            y += h + 2 * p
        self._x += wide
        self._shelf = max(self._shelf, y - self._y)

    def dims(self, name):
        return self.rects[name][2], self.rects[name][3]

    def paint(self, name, col, hgt, rough, su, sv):
        """Store a painted rectangle. `hgt` is in studs; su, sv are pixels per stud across
        and down, which turn height into true slopes for the normal map (OpenGL: green up)."""
        x, y, w, h = self.rects[name]
        assert col.shape[:2] == (h, w), (name, col.shape, (h, w))
        p = self.PAD
        hp = np.pad(hgt, 1, mode="edge")
        dx = (hp[1:-1, 2:] - hp[1:-1, :-2]) * 0.5 * su
        dy = (hp[2:, 1:-1] - hp[:-2, 1:-1]) * 0.5 * sv
        n = np.stack([-dx, dy, np.ones_like(dx)], -1)
        n /= np.linalg.norm(n, axis=-1, keepdims=True)
        ys = slice(max(y - p, 0), min(y + h + p, self.h)); xs = slice(max(x - p, 0), min(x + w + p, self.w))
        cy = slice(ys.start - (y - p), ys.stop - (y - p)); cx = slice(xs.start - (x - p), xs.stop - (x - p))

        def put(dst, src):
            spec = [(p, p), (p, p)] + [(0, 0)] * (src.ndim - 2)
            dst[ys, xs] = np.pad(src, spec, mode="edge")[cy, cx]

        put(self.color, np.clip(col, 0, 1))
        put(self.normal, n * 0.5 + 0.5)
        put(self.rough, np.clip(rough, 0.04, 1))

    def pt(self, name, a, b):
        """UV of the point a across and b up a rectangle (fractions)."""
        x, y, w, h = self.rects[name]
        return ((x + a * w) / self.w, 1 - (y + h - b * h) / self.h)

    def used(self):
        return sum(w * h for _, _, w, h in self.rects.values()) / (self.w * self.h)


# --------------------------------------------------------------------------- wood

class Grain:
    """Straight softwood grain from the board scan, one thin slice at a time."""

    use_scan = True

    def __init__(self):
        self.col, self.boards = None, []
        try:
            if not Grain.use_scan:
                raise FileNotFoundError("--no-scan")
            col = load_rgb(SCAN / "Planks021_1K-JPG_Color.jpg")
            ao = load_rgb(SCAN / "Planks021_1K-JPG_AmbientOcclusion.jpg")[:, :, 0].mean(1)
        except Exception as err:   # the scan is a git-ignored download: fall back to drawn grain
            print(f"[cedar_canoe] no Planks021 scan ({err}); grain is drawn by noise")
            return
        n = col.shape[0]
        gap = ao < ao.mean() - 1.2 * ao.std()
        start = None
        for y in range(n + 1):
            solid = y < n and not gap[y]
            if solid and start is None:
                start = y
            elif not solid and start is not None:
                if y - start > n // 24:
                    self.boards.append((start + 5, y - 5))
                start = None
        if len(self.boards) < 4:
            self.boards = [(int(n * (i + 0.15) / 12), int(n * (i + 0.85) / 12)) for i in range(12)]
        self.col = col
        print(f"[cedar_canoe] grain scan: {len(self.boards)} boards")

    def take(self, h, w, rng):
        """h x w x 3, grain running across the picture."""
        if self.col is None:
            a = 0.62 + 0.2 * noise(h, w, (1.6, 140), rng, 3) + 0.1 * noise(h, w, (h, 300), rng, 2)
            return np.repeat(a[..., None], 3, 2) * np.array([1.0, 0.8, 0.55], np.float32)
        y0, y1 = self.boards[int(rng.integers(len(self.boards)))]
        bh = y1 - y0
        hh = int(min(bh * 0.7, max(h * 2.2, 14)))
        top = y0 + int(rng.integers(0, max(1, bh - hh)))
        a = np.roll(self.col[top:top + hh], int(rng.integers(self.col.shape[1])), axis=1)
        if rng.random() < 0.5:
            a = a[::-1, ::-1]
        reps = -(-w // a.shape[1])
        a = np.tile(a, (1, reps, 1))[:, :w]
        return resize(a, h, w)


def tinted(src, target, value=1.0, contrast=1.0, chroma=0.5):
    """Scan wood pulled to `target`: its light and dark kept, its own hue mostly dropped."""
    lum = src @ LUMA
    ratio = np.clip((lum / lum.mean()) ** contrast, 0.45, 1.7)
    mean = src.reshape(-1, 3).mean(0)
    resid = src - mean * (lum / lum.mean())[..., None]
    t = rgb(target) * value
    return (t * ratio[..., None] + chroma * resid * (t.mean() / mean.mean())).astype(np.float32)


def planking(h, w, grain, rng, plan, value=1.0, joints=True):
    """Strips laid across the picture from the top row down. `plan` is a list of
    (rows, kind); kind is 'cedar', 'walnut', 'pale' or 'keel'. Returns colour, the seam
    mask (1 on a seam) and each strip's rows."""
    col = np.zeros((h, w, 3), np.float32)
    seam = np.zeros((h, w), np.float32)
    rows, y, last = [], 0, None
    cedar = [HONEY, AMBER, RUSSET, BROWN]
    weight = np.array([0.36, 0.34, 0.24, 0.06])
    for n, kind in plan:
        y1 = min(y + n, h)
        if y1 <= y:
            break
        cuts = [0, w]
        if joints and kind == "cedar":      # a strip is two or three lengths, scarfed end to end
            cuts = sorted({0, w, *(int(c) for c in rng.uniform(0.12, 0.88, int(rng.integers(1, 3))) * w)})
        for x0, x1 in zip(cuts[:-1], cuts[1:]):
            if x1 - x0 < 4:
                continue
            if kind == "cedar":
                p = weight.copy()
                if last is not None:
                    p[last] *= 0.15
                last = int(rng.choice(4, p=p / p.sum()))
                tone, val, con = cedar[last], value * rng.uniform(0.94, 1.06), 0.7
            elif kind == "walnut":
                tone, val, con = WALNUT, value, 0.6
            elif kind == "pale":
                tone, val, con = PALE, value, 0.5
            else:
                tone, val, con = GUNWALE, value * 0.9, 0.6
            col[y:y1, x0:x1] = tinted(grain.take(y1 - y, x1 - x0, rng), tone, val, con)
            if x0 > 0:
                seam[y:y1, x0] = np.maximum(seam[y:y1, x0], 0.7)
        seam[y1 - 1, :] = 1.0
        rows.append((y, y1, kind))
        y = y1
    if y < h:                                # whatever is left repeats the last strip's wood
        col[y:] = col[y - 1:y]
    return col, seam, rows


def hardwood(h, w, grain, rng, tone, value=1.0, upright=False):
    src = grain.take(w, h, rng).transpose(1, 0, 2) if upright else grain.take(h, w, rng)
    col = tinted(src, tone, value, 0.55, 0.2)
    lum = col @ LUMA
    hgt = 0.0012 * (lum - blur(lum, 2.0)) / (lum.std() + 1e-6)
    return col, hgt.astype(np.float32)


def round_edges(col, hgt, px, depth, dark=0.25, top=True, bottom=True, left=False, right=False):
    """A rounded-over arris: the height falls away and the edge takes a little shade."""
    h, w = hgt.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.full((h, w), 1e9, np.float32)
    if top:
        d = np.minimum(d, yy)
    if bottom:
        d = np.minimum(d, h - 1 - yy)
    if left:
        d = np.minimum(d, xx)
    if right:
        d = np.minimum(d, w - 1 - xx)
    t = 1 - smooth(0, px, d)
    return col * (1 - dark * t)[..., None], hgt - depth * t * t


# --------------------------------------------------------------------------- painters

def layout(at):
    at.alloc("outer", 1016, 236)
    at.alloc("innerS", 1016, 196)
    at.alloc("innerP", 1016, 196)
    at.alloc("gunTop", 1016, 28)
    at.alloc("gunSide", 1016, 16)
    at.alloc("gunIn", 1016, 14)
    at.alloc("cane", 264, 150)
    at.alloc("deck", 180, 180)
    at.column([("thwart", 250, 46), ("rail", 256, 20), ("stem", 256, 22), ("under", 128, 30)])


def paint_outer(at, grain, rng):
    w, h = at.dims("outer")
    su, sv = w / UL, h / GIRTH
    plan = [(15, "cedar"), (15, "cedar"), (3, "walnut"), (9, "pale"), (3, "walnut")] + [(15, "cedar")] * 12 + [(11, "keel")]
    col, seam, rows = planking(h, w, grain, rng, plan)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    lum = col @ LUMA
    hgt = 0.0010 * (lum - blur(lum, 1.6)) / (lum.std() + 1e-6)
    soft = blur(seam, 0.7)
    col *= (1 - 0.42 * np.clip(soft * 1.6, 0, 1))[..., None]
    hgt -= 0.0045 * np.clip(soft * 1.8, 0, 1)
    rough = 0.36 + 0.06 * (noise(h, w, (30, 120), rng) - 0.5) + 0.14 * np.clip(soft * 1.6, 0, 1)
    # Shade under the outwale, then the hull falls away from the light toward the bilge.
    col *= (0.62 + 0.38 * smooth(11, 26, yy))[..., None]
    # The bottom has met a few beaches: pale scratches along the run, and a duller finish.
    low = smooth(h * 0.58, h * 0.9, yy)
    scratch = smooth(0.66, 0.8, noise(h, w, (1.3, 90), rng, 2)) * low * (0.5 + 0.5 * noise(h, w, (40, 200), rng))
    col = mix(col, col * 1.22 + 0.03, 0.55 * scratch)
    rough = rough + 0.22 * scratch + 0.08 * low
    hgt -= 0.0015 * scratch
    # A faint tide mark where the lake dries on the varnish.
    mark = np.exp(-((yy - h * 0.53 - 3 * np.sin(xx / 70.0)) / 2.2) ** 2) * (0.4 + 0.6 * noise(h, w, (4, 60), rng))
    col = mix(col, col * 0.86 + 0.02, 0.35 * mark)
    rough += 0.08 * mark
    at.paint("outer", col, hgt, rough, su, sv)
    return rows


def rib_centres():
    n = int((L / 2 - 0.55) / RIB_STEP)
    return [k * RIB_STEP for k in range(-n, n + 1)]


def paint_inner(at, grain, rng, name):
    w, h = at.dims(name)
    su, sv = w / UL, h / GIRTH_IN
    plan = [(15, "cedar")] * 14
    col, seam, rows = planking(h, w, grain, rng, plan, value=0.80)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    lum = col @ LUMA
    hgt = 0.0010 * (lum - blur(lum, 1.6)) / (lum.std() + 1e-6)
    soft = blur(seam, 0.7)
    col *= (1 - 0.4 * np.clip(soft * 1.6, 0, 1))[..., None]
    hgt -= 0.004 * np.clip(soft * 1.8, 0, 1)
    rough = 0.44 + 0.06 * (noise(h, w, (30, 120), rng) - 0.5) + 0.12 * np.clip(soft * 1.6, 0, 1)
    # Grit and footmarks on the bottom boards, a dull finish there.
    floor = smooth(h * 0.72, h * 0.96, yy) * (0.55 + 0.45 * noise(h, w, (26, 70), rng))
    col = mix(col, col * 0.78 + rgb((60, 52, 40)) * 0.1, 0.6 * floor)
    rough += 0.16 * floor
    # Ribs: bent half-round laths across the planking, lighter than it, each with its shadow.
    half = RIB_W / 2 * su
    rib = np.zeros((h, w), np.float32)
    dist = np.full((h, w), 1e9, np.float32)
    for y in rib_centres():
        dist = np.minimum(dist, np.abs(xx - (y + UL / 2) / UL * (w - 1)))
    rib = smooth(half + 0.6, half - 0.6, dist)
    shade = smooth(half + 4.5, half, dist) * (1 - rib)
    col = mix(col, rgb(SHADOW), 0.5 * shade)
    rcol, rh = hardwood(h, w, grain, rng, RIB, upright=True)
    rcol *= (0.9 + 0.2 * noise(h, w, (60, 6), rng))[..., None]
    rcol *= (0.80 + 0.20 * smooth(half, half - 3.2, dist))[..., None]           # the rounded edge turns from the light
    rcol = mix(rcol, rcol * 0.72, 0.7 * floor)
    profile = np.sqrt(np.clip(1 - (dist / (half + 0.6)) ** 2, 0, 1))
    hgt = hgt * (1 - rib) + rib * (RIB_H * profile + rh)
    col = mix(col, rcol, rib)
    rough = mix(rough, 0.38 + 0.14 * floor, rib)
    # A clenched tack where a rib crosses a strip: small, so it reads as a glint, not a dot.
    for y in rib_centres():
        cx = (y + UL / 2) / UL * (w - 1)
        for (r0, r1, _kind) in rows:
            cy = (r0 + r1 - 1) / 2 + rng.uniform(-1.5, 1.5)
            d = np.hypot(xx - cx - rng.uniform(-0.12, 0.12) * 2 * half, yy - cy)
            head = smooth(1.5, 0.7, d)
            col = mix(col, rgb(TACK) * 0.95, 0.6 * head)
            hgt += 0.003 * head
            rough = mix(rough, 0.3, head)
    # Shade tucked up under the inwale.
    col *= (0.55 + 0.45 * smooth(8, 24, yy))[..., None]
    at.paint(name, col, hgt, rough, su, sv)


def paint_gunwales(at, grain, rng):
    # Top: outwale (bottom of the picture), the edge of the planking as a pale pinstripe, inwale.
    w, h = at.dims("gunTop")
    su, sv = w / UL, h / (OUT_W + SKIN + IN_W)
    col, hgt = hardwood(h, w, grain, rng, GUNWALE, 1.06)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    v = (h - 1 - yy) / sv                                  # studs in from the outer edge
    edge = smooth(0.012, 0.0, np.abs(v - OUT_W)) + smooth(0.012, 0.0, np.abs(v - OUT_W - SKIN))
    plank = smooth(OUT_W + 0.008, OUT_W + 0.02, v) * smooth(OUT_W + SKIN - 0.008, OUT_W + SKIN - 0.02, v)
    pcol, _ = hardwood(h, w, grain, rng, HONEY, 0.95)
    col = mix(col, pcol, plank)
    col *= (1 - 0.5 * np.clip(edge, 0, 1))[..., None]
    hgt -= 0.004 * np.clip(edge, 0, 1)
    rough = np.full((h, w), 0.4, np.float32) + 0.06 * (noise(h, w, (8, 90), rng) - 0.5)
    # Hands and paddle shafts have rubbed the varnish thin in places.
    wear = smooth(0.55, 0.8, noise(h, w, (12, 140), rng, 2))
    col = mix(col, col * 1.12 + 0.01, 0.3 * wear)
    rough += 0.12 * wear
    for sx in np.arange(0.45, UL, 0.9):                    # bronze screws down the inwale
        d = np.hypot(xx - sx * su, yy - (h - 1 - (OUT_W + SKIN + IN_W * 0.5) * sv))
        head = smooth(2.3, 1.3, d)
        col = mix(col, rgb(TACK), 0.9 * head)
        col *= (1 - 0.35 * smooth(3.6, 2.2, d) * (1 - head))[..., None]
        hgt -= 0.003 * head
        rough = mix(rough, 0.3, head)
    col, hgt = round_edges(col, hgt, 3.0, 0.012, 0.3)
    at.paint("gunTop", col, hgt, rough, su, sv)

    for name, tall, value in (("gunSide", RAIL_UP + OUT_DROP, 1.0), ("gunIn", RAIL_UP + IN_DROP, 0.9)):
        w, h = at.dims(name)
        col, hgt = hardwood(h, w, grain, rng, GUNWALE, value)
        yy = np.mgrid[0:h, 0:w][0].astype(np.float32)
        col *= (0.72 + 0.28 * smooth(h - 1, h * 0.35, yy))[..., None]       # darker toward the under edge
        rough = np.full((h, w), 0.42, np.float32)
        if name == "gunSide":                              # dock rash: pale knocks along the rubbing edge
            knock = smooth(0.7, 0.86, noise(h, w, (3, 26), rng, 2)) * smooth(0.2, 0.6, noise(h, w, (h, 160), rng))
            col = mix(col, col * 1.3 + 0.02, 0.3 * knock)
            rough += 0.2 * knock
            hgt -= 0.002 * knock
        col, hgt = round_edges(col, hgt, 2.5, 0.01, 0.2, bottom=False)
        at.paint(name, col, hgt, rough, w / UL, h / tall)


def paint_cane(at, rng):
    """Woven cane: paired strands both ways with thin diagonals, small dark holes between."""
    w, h = at.dims("cane")
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    c = 10.0
    fx, fy = (xx % c) / c, (yy % c) / c
    ix, iy = np.floor(xx / c), np.floor(yy / c)
    across = smooth(0.0, 0.08, fy) * smooth(0.70, 0.62, fy)
    up = smooth(0.0, 0.08, fx) * smooth(0.70, 0.62, fx)
    split_a = 1 - 0.4 * smooth(0.06, 0.0, np.abs(fy - 0.34))         # each band is a pair of strands
    split_u = 1 - 0.4 * smooth(0.06, 0.0, np.abs(fx - 0.34))
    over = ((ix + iy) % 2 == 0).astype(np.float32)                    # which strand rides on top at a crossing
    both = across * up
    strand = np.clip(across + up, 0, 1)
    d1 = smooth(0.13, 0.06, np.abs(((fx + fy + 0.15) % 1.0) - 0.5))
    d2 = smooth(0.13, 0.06, np.abs(((fx - fy + 0.5) % 1.0) - 0.5))
    diag = np.clip(d1 + d2, 0, 1) * (1 - strand)
    shade = 0.84 + 0.16 * (across * split_a * (1 - both * (1 - over)) + up * split_u * (1 - both * over))
    fibre = 0.9 + 0.2 * noise(h, w, 2.5, rng, 2)
    jit = 0.92 + 0.16 * noise(h, w, (c, c * 9), rng, 1)
    col = rgb(CANE) * (shade * fibre * jit)[..., None]
    col = mix(col, rgb(CANE) * 0.8 * fibre[..., None], diag)
    hole = (1 - strand) * (1 - 0.85 * diag)
    col = mix(col, rgb(CANE_HOLE), hole)
    hgt = 0.012 * strand * (0.7 + 0.3 * (across * (1 - both * (1 - over)) + up * (1 - both * over))) + 0.006 * diag - 0.03 * hole
    rough = mix(np.full((h, w), 0.62, np.float32), 0.9, hole)
    # The frame's shadow round the edge, and a hollow where people sit.
    rim = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
    col *= (0.7 + 0.3 * smooth(0, 9, rim))[..., None]
    sat = np.exp(-(((xx - w / 2) / (w * 0.3)) ** 2 + ((yy - h / 2) / (h * 0.3)) ** 2))
    col = mix(col, col * 0.9, 0.5 * sat)
    at.paint("cane", col, hgt, rough, 165.0, 165.0)


def paint_small(at, grain, rng):
    # Deck: two bookmatched leaves either side of a dark king plank, grain toward the stem.
    w, h = at.dims("deck")
    left, lh = hardwood(h, w, grain, rng, HONEY, 1.08, upright=True)
    col = np.where((np.mgrid[0:h, 0:w][1] < w / 2)[..., None], left, left[:, ::-1])
    hgt = np.where(np.mgrid[0:h, 0:w][1] < w / 2, lh, lh[:, ::-1])
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    off = np.abs(xx - (w - 1) / 2) / w
    king = smooth(0.062, 0.05, off)
    kcol, _ = hardwood(h, w, grain, rng, WALNUT, 1.0, upright=True)
    col = mix(col, kcol, king)
    line = smooth(0.012, 0.0, np.abs(off - 0.056))
    col *= (1 - 0.5 * line)[..., None]
    hgt = hgt - 0.004 * line
    pin = smooth(0.012, 0.004, np.abs(off - 0.085))                    # a pale inlay line beside it
    col = mix(col, rgb(PALE), 0.7 * pin)
    rough = np.full((h, w), 0.36, np.float32) + 0.05 * (noise(h, w, 30, rng) - 0.5)
    at.paint("deck", col, hgt, rough, w / 1.7, h / 1.7)

    w, h = at.dims("thwart")
    col, hgt = hardwood(h, w, grain, rng, ASH, 1.0)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    worn = np.exp(-((xx - w / 2) / (w * 0.22)) ** 2)                    # the carrying yoke shines in the middle
    col = mix(col, col * 0.9, 0.5 * worn)
    rough = 0.44 - 0.08 * worn + 0.05 * (noise(h, w, (8, 60), rng) - 0.5)
    ends = smooth(w * 0.07, 0, np.minimum(xx, w - 1 - xx))
    col *= (1 - 0.35 * ends)[..., None]
    col, hgt = round_edges(col, hgt, 3.0, 0.012, 0.22)
    at.paint("thwart", col, hgt, rough, w / 3.0, h / 0.56)

    w, h = at.dims("rail")
    col, hgt = hardwood(h, w, grain, rng, ASH, 0.97)
    col, hgt = round_edges(col, hgt, 2.5, 0.01, 0.25)
    at.paint("rail", col, hgt, np.full((h, w), 0.44, np.float32), w / 3.2, h / 0.15)

    w, h = at.dims("stem")
    col, hgt = hardwood(h, w, grain, rng, GUNWALE, 1.0)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    knock = smooth(0.72, 0.86, noise(h, w, (3, 20), rng, 2)) * smooth(h * 0.25, h * 0.45, yy) * smooth(h * 0.75, h * 0.55, yy)
    col = mix(col, col * 1.4 + 0.03, 0.45 * knock)                      # the stem takes the knocks
    at.paint("stem", col, hgt, 0.42 + 0.2 * knock, w / 2.6, h / 0.4)

    w, h = at.dims("under")
    col, hgt = hardwood(h, w, grain, rng, GUNWALE, 0.62)
    at.paint("under", col, hgt, np.full((h, w), 0.6, np.float32), 40.0, 40.0)


def compose():
    at = Atlas(1024, 1024, GUNWALE)
    layout(at)
    grain = Grain()
    rng = np.random.default_rng(1203)
    rows = paint_outer(at, grain, rng)
    paint_inner(at, grain, rng, "innerS")
    paint_inner(at, grain, rng, "innerP")
    paint_gunwales(at, grain, rng)
    paint_cane(at, rng)
    paint_small(at, grain, rng)
    x, y, w, h = at.rects["outer"]
    mean = tuple(int(round(c * 255)) for c in at.color[y:y + h, x:x + w].reshape(-1, 3).mean(0))
    print(f"[cedar_canoe] hull atlas: {len(at.rects)} rectangles, {at.used():.0%} used; outside mean {mean}")
    return at, save_maps(at, NAME), mean, rows


def compose_paddle():
    """512 x 256: the two faces of the paddle, laid flat. A laminated blade (ash with a
    walnut heart and a darker tip), a plain ash shaft and grip."""
    at = Atlas(512, 256, ASH)
    at.alloc("faceA", 506, 110)
    at.alloc("faceB", 506, 110)
    grain = Grain()
    rng = np.random.default_rng(77)
    for name in ("faceA", "faceB"):
        w, h = at.dims(name)
        su, sv = w / P_LEN, h / (2 * P_HALF)
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        along, off = xx / su, np.abs(yy - (h - 1) / 2) / sv            # studs from the grip; studs off the centre line
        col, hgt = hardwood(h, w, grain, rng, ASH, 1.0)
        blade = smooth(2.45, 2.75, along)
        heart = smooth(0.062, 0.05, off) * blade
        wing = smooth(0.2, 0.215, off) * blade
        hcol, _ = hardwood(h, w, grain, rng, WALNUT, 1.05)
        wcol, _ = hardwood(h, w, grain, rng, RUSSET, 1.0)
        col = mix(col, wcol, wing)
        col = mix(col, hcol, heart)
        glue = (smooth(0.012, 0.0, np.abs(off - 0.056)) + smooth(0.012, 0.0, np.abs(off - 0.207))) * blade
        col *= (1 - 0.4 * np.clip(glue, 0, 1))[..., None]
        hgt -= 0.003 * np.clip(glue, 0, 1)
        tip = smooth(P_LEN - 0.22, P_LEN - 0.15, along)                 # a hardwood tip against the gravel
        tcol, _ = hardwood(h, w, grain, rng, GUNWALE, 0.9, upright=True)
        col = mix(col, tcol, tip)
        rough = np.full((h, w), 0.38, np.float32) + 0.05 * (noise(h, w, (8, 60), rng) - 0.5)
        hands = np.exp(-((along - 0.15) / 0.25) ** 2) + np.exp(-((along - 2.2) / 0.4) ** 2)   # where it is held
        col = mix(col, col * 0.9, 0.4 * np.clip(hands, 0, 1) * (1 - blade))
        rough += 0.1 * np.clip(hands, 0, 1)
        scuff = smooth(0.68, 0.84, noise(h, w, (2, 40), rng, 2)) * smooth(P_LEN - 1.0, P_LEN - 0.2, along)
        col = mix(col, col * 1.25 + 0.02, 0.5 * scuff)
        rough += 0.2 * scuff
        at.paint(name, col, hgt, rough, su, sv)
    print(f"[cedar_canoe] paddle atlas: {at.used():.0%} used")
    return at, save_maps(at, PADDLE)


def save_maps(at, name):
    paths = {}
    for folder in ((SCRATCH, MAPS) if Grain.use_scan else (SCRATCH / "no-scan",)):   # a test run leaves the real maps alone
        folder.mkdir(parents=True, exist_ok=True)
        for key, arr in (("color", at.color), ("normal", at.normal), ("rough", at.rough)):
            write_png(folder / f"{name}_{key}.png", arr)
            paths[key] = folder / f"{name}_{key}.png"
    return paths


# --------------------------------------------------------------------------- hull lines

def resample(pts, k):
    """k + 1 points at equal lengths along a polyline."""
    pts = np.asarray(pts, np.float64)
    d = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    t = np.linspace(0, d[-1], k + 1)
    return np.stack([np.interp(t, d, pts[:, c]) for c in range(pts.shape[1])], 1)


class Hull:
    """The lines of the boat. Design axes: bow +Y, starboard +X, up +Z, waterline z = 0."""

    def __init__(self, ys, k):
        self.k = k
        u = np.linspace(0, 1, 401)[:, None]
        ctrl = np.array([(0.0, -DRAFT + ROCKER), (1.25, -DRAFT + ROCKER + 0.03), (1.97, 0.50), (1.74, STEM_TOP)])
        c = ((1 - u) ** 3 * ctrl[0] + 3 * (1 - u) ** 2 * u * ctrl[1] + 3 * (1 - u) * u ** 2 * ctrl[2] + u ** 3 * ctrl[3])
        self.imax = int(c[:, 0].argmax())
        self.y_f = L / 2 - c[self.imax, 0]          # where the keel starts to turn up
        self.stem = c + (self.y_f, 0.0)             # (y, z) from the forefoot to the stem head
        self.y_head = self.stem[-1, 0]
        half = [y for y in ys if y < self.y_head - 0.12]
        self.ys = [-y for y in reversed(half[1:])] + half

    def keel_z(self, y):
        a = abs(y)
        if a <= self.y_f:
            return -DRAFT + ROCKER * (a / self.y_f) ** 2.5
        return float(np.interp(a, self.stem[:self.imax + 1, 0], self.stem[:self.imax + 1, 1]))

    def half_b(self, y):
        s = min(abs(y) / self.y_head, 1.0)
        return HULL_B / 2 * (1 - s ** 2.3) ** 0.92

    def sheer_z(self, y):
        return SHEER_MID + SHEER_RISE * min(abs(y) / (L / 2), 1.0) ** 2.3

    def section(self, y, m=121):
        """Starboard half section, keel to sheer, as (x, z)."""
        s = min(abs(y) / self.y_head, 1.0)
        n = 2.6 + (1.08 - 2.6) * float(smooth(0.3, 1.0, s))
        th = np.linspace(0, math.pi / 2, m)
        b, zk, zs = self.half_b(y), self.keel_z(y), self.sheer_z(y)
        return np.stack([b * np.sin(th) ** (2 / n), zk + (zs - zk) * (1 - np.cos(th) ** (2 / n))], 1)

    def inner_section(self, y, m=121):
        """The inside: the same kind of curve, a skin narrower, on a bottom that never
        comes below FLOOR_Z (see the note at the top), so it always lies inside the outside."""
        s = min(abs(y) / self.y_head, 1.0)
        n = 2.4 + (1.08 - 2.4) * float(smooth(0.3, 1.0, s))
        th = np.linspace(0, math.pi / 2, m)
        b, zs = max(self.half_b(y) - SKIN, 0.012), self.sheer_z(y)
        zk = min(max(FLOOR_Z, self.keel_z(y) + 0.14), zs - 0.05)
        return np.stack([b * np.sin(th) ** (2 / n), zk + (zs - zk) * (1 - np.cos(th) ** (2 / n))], 1)

    def inner_x(self, y, z):
        """Half breadth of the inside at height z."""
        q = self.inner_section(y)
        return float(np.interp(z, q[:, 1], q[:, 0]))

    def outer_grid(self):
        """Rows of points, stern stem to bow stem, each keel to sheer."""
        rows = []
        for y in self.ys:
            r = resample(self.section(y), self.k)
            rows.append([(x, y, z) for x, z in r])
        last = self.ys[-1]
        i0 = int(np.searchsorted(self.stem[:self.imax + 1, 0], last))
        ring = resample(np.vstack([[last, self.keel_z(last)], self.stem[i0:]]), self.k)
        bow = [(0.0, y, z) for y, z in ring]
        stern = [(0.0, -y, z) for y, z in ring]
        return [stern] + rows + [bow]

    def inner_grid(self):
        rows = []
        for y in self.ys:
            r = resample(self.inner_section(y), self.k)
            rows.append([(x, y, z) for x, z in r])
        last = self.ys[-1]
        z0, z1 = rows[-1][0][2], STEM_TOP
        bow = [(0.0, last + 0.08, z0 + (z1 - z0) * j / self.k) for j in range(self.k + 1)]
        stern = [(0.0, -last - 0.08, z) for _, _, z in bow]
        return [stern] + rows + [bow]

    def rail(self, outer, inner):
        """Per ring: outer top, outer bottom, shell sheer, inner top, inner bottom, inner shell top."""
        sheer = [r[-1] for r in outer]
        out = []
        for i, (x, y, z) in enumerate(sheer):
            if i == 0:
                n = (0.0, -1.0)
            elif i == len(sheer) - 1:
                n = (0.0, 1.0)
            else:
                a, b = sheer[i - 1], sheer[i + 1]
                tx, ty = b[0] - a[0], b[1] - a[1]
                m = math.hypot(tx, ty)
                n = (ty / m, -tx / m)
            ox, oy = x + n[0] * OUT_W, y + n[1] * OUT_W
            ix, iy = x - n[0] * (SKIN + IN_W), y - n[1] * (SKIN + IN_W)
            if ix < 0:
                ix = 0.0
            out.append({
                "OT": (ox, oy, z + RAIL_UP), "OB": (ox, oy, z - OUT_DROP), "SH": (x, y, z),
                "IT": (ix, iy, z + RAIL_UP), "IB": (ix, iy, z - IN_DROP), "IS": inner[i][-1],
            })
        return out


# --------------------------------------------------------------------------- the mesh

def _lin(c):
    return tuple(common.srgb_to_linear(v) for v in c) + (1.0,)


class Mesh:
    """Collects faces with explicit UVs (hero) or a flat colour each (plain). Faces are
    wound to face the way their hint points; a mapping that would mirror its picture is
    counted, and a grid may flip its own v to avoid it."""

    def __init__(self, at=None, plain=False):
        self.at, self.plain = at, plain
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.tone = self.bm.faces.layers.int.new("tone")
        self.tones = []
        self.turn = False           # True: the half-turned copy (port side, stern end)
        self.mirrored = 0

    def _p(self, p):
        return (-p[0], -p[1], p[2]) if self.turn else tuple(p)

    def _tone(self, tone):
        tone = tuple(int(c) for c in (tone or (128, 128, 128)))
        if tone not in self.tones:
            self.tones.append(tone)
        return self.tones.index(tone)

    def _emit(self, verts, uvs, smooth_, tone):
        seen, vs, ts = set(), [], []
        for v, t in zip(verts, uvs):
            if v not in seen:
                seen.add(v); vs.append(v); ts.append(t)
        if len(vs) < 3:
            return
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return
        f.smooth = smooth_
        f[self.tone] = self._tone(tone)
        for loop, t in zip(f.loops, ts):
            loop[self.uv].uv = t
        area = sum(ts[i][0] * ts[(i + 1) % len(ts)][1] - ts[(i + 1) % len(ts)][0] * ts[i][1] for i in range(len(ts)))
        if area < -1e-9 and not self.plain:
            self.mirrored += 1

    @staticmethod
    def _normal(pts):
        n = Vector((0, 0, 0))
        for i in range(len(pts)):
            a, b = Vector(pts[i]), Vector(pts[(i + 1) % len(pts)])
            n += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
        return n

    def poly(self, pts, rect, ab, hint, smooth_=False, tone=None):
        """One polygon. `ab` are its corners' places in the rectangle (fractions)."""
        pts, ab = list(pts), list(ab)
        if self._normal(pts).dot(Vector(hint)) < 0:
            pts.reverse(); ab.reverse()
        uvs = [self.at.pt(rect, a, b) if self.at else (a, b) for a, b in ab]
        self._emit([self.bm.verts.new(self._p(p)) for p in pts], uvs, smooth_, tone)

    def grid(self, pts, rect, a_of, b_of, hint, smooth_=True, tone=None, auto_v=False):
        """A sheet of quads over pts[i][j]. a_of(i, j, p) and b_of(i, j, p) place each point
        in the rectangle. `hint` is a vector, or a function of a point, that the sheet
        should face. `tone` is a colour or a function of (i, j) for the plain model."""
        ni, nj = len(pts), len(pts[0])
        best, ref = -1.0, None
        for i in range(ni - 1):
            for j in range(nj - 1):
                q = [pts[i][j], pts[i + 1][j], pts[i + 1][j + 1], pts[i][j + 1]]
                ar = self._normal(q).length
                if ar > best:
                    best, ref = ar, (i, j, q)
        i, j, q = ref
        c = Vector(q[0]) + Vector(q[1]) + Vector(q[2]) + Vector(q[3])
        h = Vector(hint(c / 4)) if callable(hint) else Vector(hint)
        flip = self._normal(q).dot(h) < 0
        A = [[a_of(i, j, pts[i][j]) for j in range(nj)] for i in range(ni)]
        B = [[b_of(i, j, pts[i][j]) for j in range(nj)] for i in range(ni)]
        order = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
        if flip:
            order.reverse()
        area = sum(A[p[0]][p[1]] * B[r[0]][r[1]] - A[r[0]][r[1]] * B[p[0]][p[1]] for p, r in zip(order, order[1:] + order[:1]))
        if auto_v and area < 0:
            B = [[1 - b for b in row] for row in B]
        cache = {}

        def vert(i, j):
            key = tuple(round(c, 5) for c in pts[i][j])
            if key not in cache:
                cache[key] = self.bm.verts.new(self._p(pts[i][j]))
            return cache[key]

        for i in range(ni - 1):
            for j in range(nj - 1):
                idx = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
                if flip:
                    idx.reverse()
                uvs = [self.at.pt(rect, A[a][b], B[a][b]) if self.at else (A[a][b], B[a][b]) for a, b in idx]
                t = tone(i, j) if callable(tone) else tone
                vs = [vert(a, b) for a, b in idx]
                # A warped quad is cut by hand, along the diagonal that leaves its two halves
                # most nearly in one plane. Left to the exporter, port and starboard can be cut
                # differently, and at the stems one half then stands on edge facing the wrong way.
                if len(set(vs)) == 4:
                    q = [Vector(pts[a][b]) for a, b in idx]
                    cuts = []
                    for tri in (((0, 1, 2), (0, 2, 3)), ((0, 1, 3), (1, 2, 3))):
                        n = [(q[k[1]] - q[k[0]]).cross(q[k[2]] - q[k[0]]) for k in tri]
                        flat = n[0].normalized().dot(n[1].normalized()) if min(n[0].length, n[1].length) > 1e-9 else -2.0
                        cuts.append((flat, tri))
                    if min(c[0] for c in cuts) < 0.99995:
                        for k in max(cuts, key=lambda c: c[0])[1]:
                            self._emit([vs[x] for x in k], [uvs[x] for x in k], smooth_, t)
                        continue
                self._emit(vs, uvs, smooth_, t)

    def beam(self, a, b, wdir, tdir, half_w, half_t, rect, faces, u=(0.0, 1.0), tone=None):
        """A square timber from a to b. `faces` names the long faces to make: '+t', '-t',
        '+w', '-w', each as (rect or None for the default)."""
        a, b, wdir, tdir = Vector(a), Vector(b), Vector(wdir), Vector(tdir)
        d = (b - a).normalized()
        for key in faces:
            n = {"+t": tdir, "-t": -tdir, "+w": wdir, "-w": -wdir}[key]
            off = half_t if key[1] == "t" else half_w
            ext = half_w if key[1] == "t" else half_t
            vd = n.cross(d)
            p = [a + n * off - vd * ext, b + n * off - vd * ext, b + n * off + vd * ext, a + n * off + vd * ext]
            r = "under" if (key == "-t" and rect != "cane") else rect
            self.poly([tuple(x) for x in p], r, [(u[0], 0), (u[1], 0), (u[1], 1), (u[0], 1)], tuple(n), tone=tone)

    def finish(self, name):
        me = bpy.data.meshes.new(name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        if self.plain:
            idx = [d.value for d in me.attributes["tone"].data]
            attr = me.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
            for poly in me.polygons:
                lin = _lin(self.tones[idx[poly.index]])
                for li in poly.loop_indices:
                    attr.data[li].color = lin
            me.color_attributes.active_color = attr
        me.attributes.remove(me.attributes["tone"])
        return ob


def U(y):
    return (y + UL / 2) / UL


def build_canoe(at, ys, k, plain=False):
    """The canoe in design axes (bow +Y). Returns the object and a few measured numbers."""
    m = Mesh(at, plain)
    hull = Hull(ys, k)
    outer, inner = hull.outer_grid(), hull.inner_grid()
    rail = hull.rail(outer, inner)
    n = len(outer)
    row_tones = [BROWN, RUSSET, AMBER, HONEY, RUSSET, AMBER, HONEY, AMBER]

    def out_tone(i, j):
        return row_tones[min(j, len(row_tones) - 1)]

    def away(c):                    # down and out from a line above the boat
        return (4 * c.x, 0.0, c.z - 2.6)

    def toward(c):
        return (-4 * c.x, 0.0, 2.6 - c.z)

    for turn, inside in ((False, "innerS"), (True, "innerP")):
        m.turn = turn
        # The planking, outside and in.
        m.grid(outer, "outer", lambda i, j, p: U(p[1]), lambda i, j, p: j / k, away, tone=out_tone)
        m.grid(inner, inside, lambda i, j, p: 1 - U(p[1]), lambda i, j, p: j / k, toward,
               tone=tuple(int(c * 0.78) for c in RUSSET))
        # The gunwale: top, outside, the chamfer under the outwale, inside, under the inwale.
        # At the two ends the inwales meet on the centre line; their inside faces stop there,
        # or the two sides would lie in the same plane back to back.
        open_ = [i for i, r in enumerate(rail) if r["IT"][0] > 0]
        inside_rings = rail[open_[0] - 1:open_[-1] + 2]

        def strip(k0, k1, rect, hint, auto=True, b0=0.0, b1=1.0, tone=GUNWALE, rings=rail):
            m.grid([[r[k0], r[k1]] for r in rings], rect, lambda i, j, p: U(p[1]), lambda i, j, p: b1 if j else b0,
                   hint, tone=tone, auto_v=auto)
        strip("OT", "IT", "gunTop", (0, 0, 1), auto=False)
        strip("OB", "OT", "gunSide", lambda c: (c.x, 0.3 * c.y, 0), auto=False)
        strip("SH", "OB", "under", lambda c: (c.x, 0, -3), tone=tuple(int(c * 0.7) for c in GUNWALE))
        strip("IT", "IB", "gunIn", lambda c: (-c.x, -0.3 * c.y, 0), tone=tuple(int(c * 0.85) for c in GUNWALE), rings=inside_rings)
        strip("IB", "IS", "under", lambda c: (-c.x, 0, -3), tone=tuple(int(c * 0.7) for c in GUNWALE), rings=inside_rings)

        # The outer stem: a hardwood strip up the bow, standing a little proud at the head.
        seg = 9 if not plain else 5
        line = resample(hull.stem, seg)
        line = np.vstack([line, line[-1] + (line[-1] - line[-2]) / np.linalg.norm(line[-1] - line[-2]) * 0.08])
        rows = []
        for q in range(len(line)):
            a, b = line[max(q - 1, 0)], line[min(q + 1, len(line) - 1)]
            t = (b - a) / np.linalg.norm(b - a)
            nrm = np.array([t[1], -t[0]])
            proud = 0.06 * float(smooth(0.0, 2.0, q))
            base, front = line[q] - 0.07 * nrm, line[q] + proud * nrm
            rows.append([(-0.075, base[0], base[1]), (-0.05, front[0], front[1]), (0.05, front[0], front[1]), (0.075, base[0], base[1])])
        m.grid(rows, "stem", lambda i, j, p: i / (len(rows) - 1), lambda i, j, p: j / 3,
               lambda c: (8 * c.x, 1.0, -0.2), smooth_=False, tone=GUNWALE, auto_v=True)
        m.poly(rows[-1], "stem", [(0.9, 0.0), (0.9, 0.3), (1.0, 0.3), (1.0, 0.0)], (0, 0, 1), tone=GUNWALE)
        # Its back, so nothing shows through the sliver where it stands off the planking.
        m.grid([[r[3], r[0]] for r in rows], "under", lambda i, j, p: 0.1 + 0.8 * i / (len(rows) - 1), lambda i, j, p: 0.2 + 0.6 * j,
               (0, -1, 1), smooth_=False, tone=tuple(int(c * 0.7) for c in GUNWALE), auto_v=True)

        # The deck: a plate between the inwales with a hollow after edge.
        it = [r["IT"] for r in rail]
        mid = n // 2
        fore = [p for p in it[mid:] if p[0] > 0.03 and p[1] > DECK_Y + 0.34]
        tip = next(p for p in it[mid:] if p[0] <= 0.03)
        xs = [p[0] for p in it[mid:]]; yy_ = [p[1] for p in it[mid:]]; zz = [p[2] for p in it[mid:]]
        xd = float(np.interp(DECK_Y, yy_, xs)); zd = float(np.interp(DECK_Y, yy_, zz))
        across = (-1.0, -0.5, 0.0, 0.5, 1.0)
        drows = [[(f * xd, DECK_Y + 0.26 * (1 - f * f), zd - 0.015 + 0.04 * (1 - f * f)) for f in across]]
        for x, y, z in fore:
            drows.append([(f * x, y, z - 0.015 + 0.04 * (1 - f * f) * min(1.0, x / xd * 1.5)) for f in across])
        drows.append([(0.0, tip[1], tip[2] - 0.015)] * 5)
        span = tip[1] - DECK_Y
        m.grid(drows, "deck", lambda i, j, p: 0.5 + p[0] / 1.7, lambda i, j, p: 0.04 + 0.92 * (p[1] - DECK_Y) / 1.7 * (1.7 / max(span, 1.7)),
               (0, 0, 1), smooth_=False, tone=HONEY)
        low = [[(x, y, z - 0.09) for x, y, z in r] for r in drows]
        m.grid(low, "under", lambda i, j, p: 0.1 + 0.2 * j, lambda i, j, p: 0.1 + 0.15 * i, (0, 0, -1), smooth_=False,
               tone=tuple(int(c * 0.6) for c in GUNWALE), auto_v=True)
        m.grid([drows[0], low[0]], "rail", lambda i, j, p: 0.1 + 0.2 * j, lambda i, j, p: 1.0 - i, (0, -1, 0), smooth_=False,
               tone=AMBER, auto_v=True)
    m.turn = False

    # The plain model has no rib texture, so it gets seven real ribs: thin bands lying on the planking.
    if plain:
        for y in np.arange(-3.9, 4.0, 1.3):
            q = resample(hull.inner_section(float(y))[:-8], 4)
            band = [(-x + 0.02, z + 0.035) for x, z in q[:0:-1]] + [(x - 0.02 if x > 0.02 else x, z + 0.035) for x, z in q]
            m.grid([[(x, float(y) - RIB_W / 2 - 0.03, z) for x, z in band], [(x, float(y) + RIB_W / 2 + 0.03, z) for x, z in band]],
                   "rail", lambda i, j, p: 0.0, lambda i, j, p: 0.0, (0, 0, 1), smooth_=False, tone=RIB)

    # Seats: an ash frame hung between the sides, cane in the middle.
    seats = {}
    for key, y0 in (("bow", BOW_SEAT_Y), ("stern", STERN_SEAT_Y)):
        rw, rt = 0.075, 0.055
        zc = SEAT_Z - rt
        ends = (y0 - SEAT_HALF + rw, y0 + SEAT_HALF - rw)
        hb = [hull.inner_x(y, zc) for y in ends]
        xs_ = min(min(hb) - 0.15, 0.80)
        for y, b in zip(ends, hb):
            m.beam((-b - 0.03, y, zc), (b + 0.03, y, zc), (0, 1, 0), (0, 0, 1), rw, rt, "rail",
                   ("+t", "-t", "+w", "-w"), u=(0.0, min(1.0, 2 * b / 3.2)), tone=ASH)
        for s in (-1, 1):
            m.beam((s * xs_, ends[0] + rw, zc), (s * xs_, ends[1] - rw, zc), (1, 0, 0), (0, 0, 1), rw, rt, "rail",
                   ("+t", "-t", "+w", "-w"), u=(0.05, 0.05 + (ends[1] - ends[0] - 2 * rw) / 3.2), tone=ASH)
        x1, ya, yb = xs_ - rw, ends[0] + rw, ends[1] - rw
        cw, ch = at.dims("cane") if at else (264, 150)
        fa, fb = min(1.0, 2 * x1 * 165.0 / cw), min(1.0, (yb - ya) * 165.0 / ch)
        for z, hint in ((SEAT_Z - 0.03, (0, 0, 1)), (SEAT_Z - 2 * rt + 0.02, (0, 0, -1))):
            ab = [(0.5 - fa / 2, 0.5 - fb / 2), (0.5 + fa / 2, 0.5 - fb / 2), (0.5 + fa / 2, 0.5 + fb / 2), (0.5 - fa / 2, 0.5 + fb / 2)]
            if hint[2] < 0:
                ab = [ab[1], ab[0], ab[3], ab[2]]
            m.poly([(-x1, ya, z), (x1, ya, z), (x1, yb, z), (-x1, yb, z)], "cane", ab, hint, tone=CANE)
        seats[key] = {"y": y0, "cane_half_width": round(x1, 3), "frame_half_width": round(xs_ + rw, 3),
                      "hull_half_width": round(min(hb), 3)}

    # The thwart: a carrying yoke amidships, waisted in the middle.
    zt = THWART_Z - 0.05
    b = hull.inner_x(0.0, zt) + 0.03
    xsn = (-1.0, -0.55, 0.0, 0.55, 1.0)
    half = (0.27, 0.16, 0.2, 0.16, 0.27)
    top = [[(f * b, -hw, THWART_Z), (f * b, hw, THWART_Z)] for f, hw in zip(xsn, half)]
    bot = [[(x, y, z - 0.1) for x, y, z in r] for r in top]
    m.grid(top, "thwart", lambda i, j, p: 0.5 + p[0] / 3.0, lambda i, j, p: 0.5 + p[1] / 0.56, (0, 0, 1), smooth_=False, tone=ASH)
    m.grid(bot, "under", lambda i, j, p: i / 4, lambda i, j, p: j, (0, 0, -1), smooth_=False, tone=tuple(int(c * 0.7) for c in ASH), auto_v=True)
    for j, hint in ((0, (0, -1, 0)), (1, (0, 1, 0))):
        m.grid([[t[j], q[j]] for t, q in zip(top, bot)], "rail", lambda i, j, p: 0.05 + 0.9 * i / 4, lambda i, j, p: 1.0 - j, hint,
               smooth_=False, tone=tuple(int(c * 0.88) for c in ASH), auto_v=True)

    ob = m.finish(PLAIN if plain else NAME)
    info = {"seats": seats, "mirrored": m.mirrored, "thwart_half_width": round(b, 3),
            "y_forefoot": round(hull.y_f, 3), "y_head": round(hull.y_head, 3),
            "floor_z": round(hull.inner_section(0.0)[0, 1], 3),
            "sheer_mid": SHEER_MID + RAIL_UP, "ribs": len(rib_centres())}
    return ob, info


# ---- the paddle: design axes with the top grip at the origin and the blade toward +Y, flat in XY.
P_LEN, P_HALF = 4.6, 0.34
# (distance from the grip, half width, half thickness)
P_RINGS = [(0.0, 0.11, 0.05), (0.05, 0.2, 0.078), (0.17, 0.2, 0.078), (0.36, 0.085, 0.078), (1.4, 0.078, 0.078),
           (2.5, 0.078, 0.078), (2.72, 0.12, 0.062), (2.98, 0.24, 0.046), (3.4, 0.31, 0.036), (3.9, 0.33, 0.03),
           (4.3, 0.3, 0.028), (4.52, 0.2, 0.026), (4.6, 0.09, 0.022)]


def build_paddle(at, plain=False):
    m = Mesh(at, plain)
    rings = []
    for y, hw, ht in P_RINGS:
        f = 0.5 if hw < 0.1 else 0.62
        rings.append([(-hw, y, 0.0), (-f * hw, y, ht), (f * hw, y, ht), (hw, y, 0.0), (f * hw, y, -ht), (-f * hw, y, -ht)])

    def tone(i, j):
        if i >= len(P_RINGS) - 2:
            return GUNWALE
        if i >= 6:
            return ASH if j == 1 else RUSSET
        return ASH

    def tone_b(i, j):
        return tone(i, 2 - j)

    # Face A looks up (+Z), face B down; each is laid flat in its own rectangle.
    m.grid([r[0:4] for r in rings], "faceA", lambda i, j, p: 0.004 + 0.992 * p[1] / P_LEN, lambda i, j, p: 0.5 - p[0] / (2 * P_HALF),
           (0, 0, 1), tone=tone)
    m.grid([[r[3], r[4], r[5], r[0]] for r in rings], "faceB", lambda i, j, p: 0.004 + 0.992 * p[1] / P_LEN, lambda i, j, p: 0.5 + p[0] / (2 * P_HALF),
           (0, 0, -1), tone=tone_b)
    for r, hint, a in ((rings[0], (0, -1, 0), 0.004), (rings[-1], (0, 1, 0), 0.996)):
        m.poly(r, "faceA", [(a, 0.5 - p[0] / (2 * P_HALF)) for p in r], hint, tone=ASH if a < 0.5 else GUNWALE)
    ob = m.finish(PADDLE_PLAIN if plain else PADDLE)
    return ob, m.mirrored


def half_turn(ob):
    """Design axes (bow +Y) to file axes (bow -Y)."""
    for v in ob.data.vertices:
        v.co.x, v.co.y = -v.co.x, -v.co.y
    ob.data.update()


# --------------------------------------------------------------------------- materials, export

def material(name, paths):
    m = bpy.data.materials.new(name)
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
    m.use_backface_culling = True      # every surface is closed, so the file says single-sided
    return m


def vertex_material(name):
    m = bpy.data.materials.new(name + "_VertexColor")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.6
    a = nt.nodes.new("ShaderNodeVertexColor")
    a.layer_name = "Col"
    nt.links.new(a.outputs["Color"], bsdf.inputs["Base Color"])
    m.use_backface_culling = True
    return m


def export(ob, plain):
    MODELS.mkdir(parents=True, exist_ok=True)
    (MODELS / "roblox").mkdir(exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    out = MODELS / f"{ob.name}.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(out), use_selection=True, export_format="GLB", export_image_format="AUTO",
        export_yup=True, export_apply=True, export_vertex_color="ACTIVE" if plain else "NONE", export_tangents=False,
    )
    if plain:      # vertex colours need the linear to display fix for Roblox
        roblox_colors.convert(out, MODELS / "roblox" / f"{ob.name}.glb")
    else:          # image textures are display colours already: a byte-for-byte copy
        shutil.copyfile(out, MODELS / "roblox" / f"{ob.name}.glb")
    return out


def tris(ob):
    ob.data.calc_loop_triangles()
    return len(ob.data.loop_triangles)


def record(ob, glb, replaces, notes, extra=None):
    lo, hi = bounds([ob])
    d = hi - lo
    entry = {
        "name": ob.name,
        "studs": [round(d.x, 2), round(d.z, 2), round(d.y, 2)],
        "triangles": tris(ob),
        "parts": 1,
        "replaces": replaces,
        "notes": notes,
        "glb_bytes": glb.stat().st_size,
    }
    entry.update(extra or {})
    data = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    data[ob.name] = entry
    MANIFEST.write_text(json.dumps(dict(sorted(data.items())), indent=2) + "\n")
    return entry


def rbx(p):
    """Blender file axes to Roblox model axes (art/README.md, 'Importing')."""
    return [round(-p[0], 3), round(p[2], 3), round(p[1], 3)]


# --------------------------------------------------------------------------- previews

def _flat(name, colour, rough=0.9):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = _lin(colour)
    bsdf.inputs["Roughness"].default_value = rough
    return m


def camera(pos, look, fov, ortho=None):
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    bpy.context.scene.collection.objects.link(cam)
    cam.location = pos
    cam.rotation_euler = (Vector(look) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    if ortho:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = ortho
    else:
        cam.data.sensor_fit = "VERTICAL"
        cam.data.angle_y = math.radians(fov)
    cam.data.clip_start, cam.data.clip_end = 0.05, 2000
    bpy.context.scene.camera = cam
    return cam


def stage(golden, to_sun=None):
    """The lake: dark water with a little chop, a ring of dark trees far off, a sky that
    is warm at the horizon, and one sun. Returns what it made."""
    scene = bpy.context.scene
    made = []
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes["Background"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(tc.outputs["Generated"], sep.inputs["Vector"])
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    e = ramp.color_ramp.elements
    if golden:
        e[0].position, e[0].color = 0.0, (1.0, 0.62, 0.34, 1)
        e[1].position, e[1].color = 0.55, (0.42, 0.56, 0.82, 1)
    else:
        e[0].position, e[0].color = 0.0, (0.80, 0.86, 0.92, 1)
        e[1].position, e[1].color = 0.6, (0.42, 0.62, 0.92, 1)
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.85 if golden else 1.0
    scene.world = world

    sun = bpy.data.objects.new("SunG", bpy.data.lights.new("SunG", "SUN"))
    sun.data.angle = math.radians(2.5)
    if golden:
        sun.data.energy, sun.data.color = 4.2, (1.0, 0.70, 0.42)
        to_sun = Vector(to_sun or (0.78, -0.42, 0.30))
    else:
        sun.data.energy, sun.data.color = 3.6, (1.0, 0.96, 0.9)
        to_sun = Vector(to_sun or (0.45, -0.35, 0.82))
    sun.rotation_euler = to_sun.to_track_quat("Z", "Y").to_euler()
    scene.collection.objects.link(sun)
    made.append(sun)

    bpy.ops.mesh.primitive_plane_add(size=600, location=(0, 0, 0))
    water = bpy.context.object
    wm = _flat("_water", WATER, 0.05)
    nt = wm.node_tree
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 0.55
    nz.inputs["Detail"].default_value = 2.0
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.10
    bump.inputs["Distance"].default_value = 0.6
    nt.links.new(nz.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], nt.nodes["Principled BSDF"].inputs["Normal"])
    water.data.materials.append(wm)
    made.append(water)

    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=150, depth=44, end_fill_type="NOTHING", location=(0, 0, 22))
    trees = bpy.context.object
    trees.data.materials.append(_flat("_trees", (30, 46, 34), 1.0))
    trees.visible_shadow = False
    made.append(trees)
    return made


def place(ob, pos, yaw=0.0, pitch=0.0, roll=0.0):
    ob.matrix_world = Matrix.Translation(pos) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(pitch, 4, "X") @ Matrix.Rotation(roll, 4, "Y")


# Where two paddles lie in the boat for the previews (file axes: bow at -Y): side by side
# across the thwart, blades flat on the bow seat. Each is (grip position, yaw, pitch, roll).
STOW = [
    ((0.36, 1.45, THWART_Z + 0.25), math.radians(1.5), math.radians(5.9), 0.0),
    ((-0.36, 1.00, THWART_Z + 0.20), math.radians(-1.5), math.radians(5.9), 0.0),
]


def previews(canoe, paddle, plain, paddle_plain, opt):
    scene = bpy.context.scene
    out = SCRATCH / (f"renders-{opt['tag']}" if opt["tag"] else "renders")
    out.mkdir(parents=True, exist_ok=True)
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    keep = opt["tag"] is None
    want = opt["views"] or ["hero", "golden", "match", "threequarter", "ingame", "inside", "low", "paddle", "plain"]
    common.PREVIEW_SAMPLES = opt["samples"]

    def copy_of(ob):
        c = bpy.data.objects.new(ob.name + "_copy", ob.data)
        scene.collection.objects.link(c)
        return c

    def render(key, res):
        scene.render.resolution_x, scene.render.resolution_y = res
        name = NAME if key == "hero" else PADDLE if key == "paddle" else PLAIN if key == "plain" else f"{NAME}-{key}"
        scene.render.filepath = str(out / f"{name}.png")
        bpy.ops.render.render(write_still=True)
        if keep:
            shrink(out / f"{name}.png", PREVIEWS / f"{name}.png")

    def hide(obs, flag):
        for o in obs:
            o.hide_render = flag

    hide([plain, paddle_plain], True)
    stowed = []
    for pos, yaw, pitch, roll in STOW:
        c = copy_of(paddle)
        place(c, pos, yaw, pitch, roll)
        stowed.append(c)
    hide([paddle], True)

    # Studio-style views: the same camera and light as the other previews.
    for key, obs, view in (("hero", [canoe] + stowed, (35, 30)), ("paddle", [paddle], (20, 55)), ("plain", [plain, paddle_plain], (35, 30))):
        if key not in want:
            continue
        hide([canoe, paddle, plain, paddle_plain] + stowed, True)
        hide(obs, False)
        if key == "plain":
            place(paddle_plain, (2.6, 2.2, -0.3), math.radians(8))
        lo, hi = bounds(obs)
        ground, sun, cam = common._setup_render(lo, hi, view)
        render(key, (1024, 1024))
        for o in (ground, sun, cam):
            bpy.data.objects.remove(o, do_unlink=True)
    hide([canoe] + stowed, False)
    hide([paddle, plain, paddle_plain], True)

    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = opt["samples"]
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "Standard"
    shots = {
        # From off the bow quarter at golden hour, a little above a standing player.
        "golden": (True, (8.6, -10.4, 5.6), (0.2, -0.2, 0.15), 30, (1376, 768)),
        # The reference picture's framing: closer, the near end at the right, the light from the left.
        "match": ("left", (-8.8, -5.0, 4.6), (0.0, -0.5, 0.15), 44, (1376, 680)),
        # Set C looks down on the boat from a high three-quarter view.
        "threequarter": (True, (8.2, -8.6, 11.0), (0.0, 0.0, 0.2), 34, (1280, 800)),
        # A player on the dock, eyes 7 studs over the water, the canoe 22 studs off.
        "ingame": (False, (15.0, -16.0, 7.0), (0.0, 0.0, 0.5), 70, (1280, 720)),
        # Looking down into the boat from over the stern seat.
        "inside": (False, (1.5, 5.6, 4.6), (0.0, 0.6, 0.1), 46, (1280, 800)),
        # From another boat alongside: the sheer line and the planking.
        "low": (True, (11.0, -5.5, 1.5), (0.0, -0.4, 0.6), 34, (1376, 640)),
    }
    for golden in (True, "left", False):
        keys = [k for k, v in shots.items() if v[0] == golden and k in want]
        if not keys:
            continue
        made = stage(bool(golden), (-0.80, 0.36, 0.30) if golden == "left" else None)
        for key in keys:
            _, pos, look, fov, res = shots[key]
            cam = camera(pos, look, fov)
            render(key, res)
            bpy.data.objects.remove(cam, do_unlink=True)
        for o in made:
            bpy.data.objects.remove(o, do_unlink=True)


def sheets(paths, paddle_paths):
    col, nor, rou = (load_rgb(paths[k]) for k in ("color", "normal", "rough"))
    half = lambda a: resize(a, 512, 512)
    sheet = np.concatenate([half(col), half(nor), half(rou)], 1)
    pc, pn, pr = (load_rgb(paddle_paths[k]) for k in ("color", "normal", "rough"))
    strip = np.concatenate([pc, pn, pr], 1)
    if not Grain.use_scan:
        write_png(SCRATCH / "no-scan" / f"{NAME}-atlas.png", np.concatenate([sheet, strip], 0))
        return
    write_png(SCRATCH / f"{NAME}-atlas.png", np.concatenate([sheet, strip], 0))
    shrink(SCRATCH / f"{NAME}-atlas.png", PREVIEWS / f"{NAME}-atlas.png")


def compare():
    """Side by side sheets, when their halves exist: the reference picture's canoe beside the
    golden hour render, and the first pass (--tag first) beside the final one."""
    def pair(left, right, name, height=640):
        if not (left.exists() and right.exists()):
            return
        a, b = load_rgb(left), load_rgb(right)
        a = resize(a, height, int(a.shape[1] * height / a.shape[0]))
        b = resize(b, height, int(b.shape[1] * height / b.shape[0]))
        gap = np.ones((height, 10, 3), np.float32)
        write_png(SCRATCH / name, np.concatenate([a, gap, b], 1))
        shrink(SCRATCH / name, PREVIEWS / name)

    ref = REPO / "docs" / "looks" / "leg3-references" / "n4-cedar-canoe-and-boathouse-golden.jpg"
    final = SCRATCH / "renders" / f"{NAME}-golden.png"
    match = SCRATCH / "renders" / f"{NAME}-match.png"
    if ref.exists() and match.exists():
        r = load_rgb(ref)[330:740, 180:1010]            # the canoe in the reference picture
        write_png(SCRATCH / "reference-crop.png", r)
        pair(SCRATCH / "reference-crop.png", match, f"{NAME}-vs-reference.png", 560)
    pair(SCRATCH / "renders-first" / f"{NAME}-golden.png", final, f"{NAME}-before-after.png", 560)


def main():
    opt = parse_args()
    reset()
    Grain.use_scan = not opt["no_scan"]
    at, paths, mean, _rows = compose()
    pat, ppaths = compose_paddle()
    sheets(paths, ppaths)
    if opt["maps_only"]:
        return

    canoe, info = build_canoe(at, HERO_YS, 8)
    plain, pinfo = build_canoe(None, PLAIN_YS, 6, plain=True)
    paddle, pm = build_paddle(pat)
    paddle_plain, _ = build_paddle(None, plain=True)
    for ob in (canoe, plain, paddle, paddle_plain):
        half_turn(ob)
    canoe.data.materials.append(material(NAME, paths))
    paddle.data.materials.append(material(PADDLE, ppaths))
    plain.data.materials.append(vertex_material(PLAIN))
    paddle_plain.data.materials.append(vertex_material(PADDLE_PLAIN))
    print(f"[cedar_canoe] mirrored faces: hull {info['mirrored']}, paddle {pm} (both should be 0)")

    lo, hi = bounds([canoe])
    seats = {k: rbx((0.0, -v["y"], SEAT_Z)) for k, v in info["seats"].items()}
    box_mid = (lo + hi) / 2
    geometry = {
        "length": round(hi.y - lo.y, 3), "beam": round(hi.x - lo.x, 3), "height": round(hi.z - lo.z, 3),
        "pivot": "the file's origin: the middle of the hull on the waterline",
        "waterline_above_keel": round(-lo.z, 3),
        "pivot_from_box_centre_roblox": rbx((-box_mid.x, -box_mid.y, -box_mid.z)),
        "bow": "Roblox -Z (Blender -Y)",
        "seat_top_roblox": seats,
        "seat_detail": info["seats"],
        "gunwale_top_amidships": round(info["sheer_mid"], 3),
        "stem_top": round(hi.z, 3),
        "floor_amidships": info["floor_z"],
        "thwart_top": THWART_Z,
        "ribs_painted": info["ribs"],
    }
    notes = ("Hero set (leg 3, N4): one mesh, one UV set, colour, normal (OpenGL) and roughness maps at 1024 embedded in the GLB; "
             "Roblox makes the SurfaceAppearance on import. Upload art/models/roblox/CedarCanoe.glb as it is (no roblox_colors.py step). "
             "The loose maps are in art/textures/cedar_canoe/. The file's origin is the middle of the hull on the waterline, "
             "not the bottom centre: if the importer puts the pivot on the middle of the box, see geometry.pivot_from_box_centre_roblox. "
             "Bow toward Roblox -Z, starboard +X. Two cane seats; a carrying thwart amidships; small decks at both ends. "
             "The ribs, strips, tacks and cane are in the maps, not the mesh.")
    extra = {"textures": {"size": 1024, "maps": ["color", "normal", "roughness"], "outside_mean_rgb": list(mean)}, "geometry": geometry}
    glb = export(canoe, False)
    e1 = record(canoe, glb, "Nothing yet: the Cedar Canoe of leg 3, N4 (BoatService builds a gray box until it is placed)", notes, extra)

    plo, phi = bounds([plain])
    pmid = (plo + phi) / 2
    glb = export(plain, True)
    e2 = record(plain, glb, "CedarCanoe on the phone tier (the lighter twin: same lines, pivot, seats and size)",
                "Vertex colours only, no maps: the plain twin of CedarCanoe, as Dock is to DockHero. Flat colour per face, one tone per row of "
                "planking, seven real ribs in place of the painted ones. Upload art/models/roblox/CedarCanoePlain.glb (colours already converted "
                "for Roblox). Same origin (hull centre on the waterline), bow toward Roblox -Z.",
                {"lite_of": NAME, "geometry": {"pivot_from_box_centre_roblox": rbx((-pmid.x, -pmid.y, -pmid.z)),
                                               "length": round(phi.y - plo.y, 3), "beam": round(phi.x - plo.x, 3)}})

    qlo, qhi = bounds([paddle])
    qmid = (qlo + qhi) / 2
    pgeo = {"pivot": "the file's origin: the middle of the top grip", "blade": "toward Roblox -Z (Blender -Y), flat faces up and down (Roblox Y)",
            "length": P_LEN, "blade_width": 2 * 0.33, "lower_hand_roblox": [0.0, 0.0, -2.2],
            "pivot_from_box_centre_roblox": rbx((-qmid.x, -qmid.y, -qmid.z))}
    glb = export(paddle, False)
    e3 = record(paddle, glb, "Nothing yet: the canoe's paddle, held by the avatar (leg 3, N4)",
                "Hero set: one mesh, colour, normal (OpenGL) and roughness maps at 512 x 256 embedded. Upload art/models/roblox/CanoePaddle.glb as it is. "
                "The origin is the top grip; the shaft runs 4.6 studs toward Roblox -Z; the lower hand holds it about 2.2 studs down the shaft. "
                "A laminated blade: ash with a walnut heart, cedar wings and a hardwood tip.",
                {"textures": {"size": [512, 256], "maps": ["color", "normal", "roughness"]}, "geometry": pgeo})
    glb = export(paddle_plain, True)
    e4 = record(paddle_plain, glb, "CanoePaddle on the phone tier", "Vertex colours only: the plain twin of CanoePaddle, same mesh and origin. "
                "Upload art/models/roblox/CanoePaddlePlain.glb.", {"lite_of": PADDLE, "geometry": pgeo})

    for e in (e1, e2, e3, e4):
        print(f"[cedar_canoe] {e['name']}: {e['studs']} studs (X, up, Z), {e['triangles']} triangles, GLB {e['glb_bytes'] / 1e6:.2f} MB")
    print(f"[cedar_canoe] geometry {json.dumps(geometry)}")
    (MAPS / "cedar_canoe.json").write_text(json.dumps({
        "what": "Hero maps baked for the Cedar Canoe and its paddle by art/scripts/cedar_canoe.py (the same maps are embedded in the GLBs)",
        "grain_source": "ambientCG Planks 021 (CC0), https://ambientcg.com/a/Planks021; everything else is drawn by the script",
        "CedarCanoe": {"size": [1024, 1024], "outside_mean_rgb": list(mean), "rectangles": {k: list(v) for k, v in at.rects.items()}},
        "CanoePaddle": {"size": [512, 256], "rectangles": {k: list(v) for k, v in pat.rects.items()}},
    }, indent=2) + "\n")
    if not opt["no_render"]:
        previews(canoe, paddle, plain, paddle_plain, opt)
        if opt["tag"] is None:
            compare()


if __name__ == "__main__":
    main()
