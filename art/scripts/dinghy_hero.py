"""DinghyHero: the Inflatable Dinghy of leg 3 (N4) as a hero set, with its outboard as a
second mesh and the plain vertex-coloured twins for the phone tier.

    blender -b --factory-startup -P art/scripts/dinghy_hero.py -- [options]

    --samples 48       preview render samples
    --views a,b        only these previews (hero, outboard, plain, golden, before, match,
                       threequarter, ingame, inside, low, bow)
    --maps-only        compose the maps and the atlas sheet, then stop (fast, for tuning)
    --no-render        build and export, skip the previews
    --tag first        write the previews to artifacts/dinghy/renders-<tag>/ only (for before and after)

What it makes
  DinghyHero.glb           the boat: one mesh, one UV set, colour, normal (OpenGL) and roughness
                           maps at 1024 embedded, so Roblox imports a MeshPart with a SurfaceAppearance
  DinghyOutboard.glb       the tiller outboard, its own mesh and 512 maps; its origin is the
                           pivot it steers and tilts about
  DinghyPlain.glb          the lighter twin of the boat: fewer faces, vertex colours only
  DinghyOutboardPlain.glb  the outboard with vertex colours only

The old vertex-colour Dinghy (boats.py) is left alone; these replace it in the game.

Axes. Designed with the bow toward +Y, then turned half round before export, so the bow is
at Blender -Y. Roblox shows Blender (x, y, z) at (-x, z, y) (art/README.md, "Importing"),
which puts the bow on Roblox -Z and starboard on Roblox +X. The origin of the boat file is
the middle of the hull (8 x 4 studs) on the waterline.

How it is made (the same way as cedar_canoe.py and dock_hero.py: no Blender bake, every
pixel deliberate)
  1. One tube is swept along a U: two stern cones, straight sides, a bow that rises. The
     starboard and port halves each get their own strip of the atlas, laid along the tube,
     so nothing is mirrored and the seams, strake, grab line, rope holders, D-rings and
     valves can be drawn where they sit.
  2. The hypalon is drawn by numpy (no scan fits it): a fine weave, sun fade on top, a
     damp band at the waterline, taped panel seams, the rubbing strake and the fittings.
     The plywood (slats, bench, transom) takes its grain from the CC0 board scan the canoe
     uses (ambientCG Planks 021; drawn by noise without it).
  3. Roblox draws the lake inside any hull that reaches below the water, so the boat floats
     high: the keel is 0.22 under, the tubes 0.14, and the floor never comes below 0.27
     above the waterline. The bottom is far thicker than a real one, which cannot be seen.

Scratch (loose maps, full-size renders) goes to artifacts/dinghy/, which is git-ignored.
The loose maps are also kept in art/textures/dinghy/.
"""

import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common  # noqa: E402
import cedar_canoe as cc  # noqa: E402
from cedar_canoe import Atlas, Grain, Mesh, camera, hardwood, rbx, round_edges, stage, tris  # noqa: E402
from common import MODELS, PREVIEWS, bounds, reset  # noqa: E402
from dock_hero import LUMA, blur, load_rgb, mix, noise, resize, rgb, shrink, smooth, write_png  # noqa: E402

NAME, PLAIN, MOTOR, MOTOR_PLAIN = "DinghyHero", "DinghyPlain", "DinghyOutboard", "DinghyOutboardPlain"
REPO = Path(__file__).resolve().parents[2]
SCRATCH = REPO / "artifacts" / "dinghy"
MAPS = REPO / "art" / "textures" / "dinghy"

# ---- the boat, in studs. Design axes: bow +Y, starboard +X, heights above the waterline.
L, BEAM = 8.0, 4.0           # BoatData.luau: the server hull
R = 0.52                     # tube radius
STRAKE = 0.04                # how far the rubbing strake stands off the tube
EDGE = (R + STRAKE) * math.cos(math.radians(9))   # how far the strake's corners stand from the tube's centre line
XC = BEAM / 2 - EDGE         # tube centre line, off the middle
ZC = 0.38                    # tube centre above the water: the tubes draw 0.14
DRAFT = 0.22                 # the keel under the fabric bottom
Y_TIP = -L / 2               # the ends of the stern cones
Y_TR, TR_T, TR_TOP = -3.14, 0.16, 0.96      # transom: middle plane, thickness, top
Y_BOW0 = 0.9                 # where the sides start to turn in
Y_BOWC = L / 2 - EDGE        # the tube centre line at the stem
BOW_N = 2.35                 # fullness of the bow (2 is an ellipse)
RISE, RISE_Y0 = 0.40, 1.0    # the bow tubes lift this much, starting here
Y_BENCH, BENCH_HALF, BENCH_TOP, BENCH_T, BENCH_X = -0.70, 0.38, 0.80, 0.12, 1.25
Y_OAR = -1.75                # oarlocks: a stud aft of the bench (you row facing aft)
Y_PASS = 1.75                # where the bow passenger sits, on the floor boards
SLAT_Y0, SLAT_PITCH, SLAT_W, SLAT_N, SLAT_H = Y_TR + 0.20, 0.56, 0.46, 9, 0.045
# The outboard steers and tilts about this point (design axes): the top of its swivel
# column, just aft of the transom.
PIVOT = (0.0, -3.38, 1.00)
PROP = (0.0, -4.13, -0.62)   # the middle of the propeller
COWL_Y, COWL_HL, COWL_HW = -3.66, 0.62, 0.44
TILLER = ((-0.17, -3.10, 1.52), (-0.21, -1.62, 1.63))

# Ring angles round the tube, degrees: 0 is outboard, 90 the top, 180 inboard. The floor
# meets the tube at 192 and the fabric bottom at -108 (= 252), so the arc between them is
# hidden and left out, except on the cones aft of the transom.
ANGLES = [-108, -76, -44, -12, -9, 9, 12, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165, 180, 192, 222, 252]
ANGLES_PLAIN = [-108, -60, -12, 12, 45, 90, 135, 192, 252]
PHI_KEYS = [-108.0, -44.0, 192.0, 252.0]    # where each angle lies up the tube's strip of the atlas:
V_KEYS = [0.0, 0.07, 0.94, 1.0]             # the under-water and hidden arcs get few rows
CONE = [(0.0, 0.17), (0.10, 0.275), (0.30, 0.395), (0.54, 0.485), (0.78, R)]      # (distance from the tip, radius)
CONE_PLAIN = [(0.0, 0.19), (0.30, 0.395), (0.78, R)]
D_TR = Y_TR - Y_TIP
FLOOR_Z = ZC + R * math.sin(math.radians(192))                    # floor in the straight part
FL_HALF = XC + R * math.cos(math.radians(192))                    # half its width there
FW = 2 * FL_HALF + 0.02                                           # the floor rectangle stands for this width
FL = (Y_BOWC + R * math.cos(math.radians(192))) - Y_TR + 0.01     # and this length, from the transom
TW, TZ0, TH = 2.62, -0.26, 1.25                                   # the transom rectangles: width, lowest z, height
BOT_W = 2.7

# Where things sit along the tube, in studs from the stern tip (D = y - Y_TIP on the straight).
SEAMS = [0.78, 2.60, 4.90, 6.35]             # taped panel seams (and one at the stem)
HOLDERS = [1.75, 3.20, 4.45, 5.70, 6.95]     # grab line holders (and one at the stem)
ROPE_PHI, ROPE_SAG = 52.0, 13.0
D_DRING, PHI_DRING = 1.22, 30.0              # towing D-rings on the quarters
PHI_BOW_DRING = -28.0                        # and one low on the stem
D_VALVE, PHI_VALVE = 1.50, 142.0
D_OAR, D_BENCH = Y_OAR - Y_TIP, Y_BENCH - Y_TIP
CHAFE = (3.80, 4.72, 64.0, 138.0)            # a doubled patch where you step aboard

# ---- palette (sRGB 0..255)
TUBE = (204, 108, 48)        # docs/DECISIONS.md: the dinghy is orange again
TAPE = (186, 94, 40)         # seam tape and doubled patches, a touch deeper
RUBBER = (58, 56, 54)        # strake, holders, cone caps: charcoal moulded rubber
RUBBER_PALE = (150, 146, 140)
FABRIC = (62, 62, 64)        # the fabric floor and bottom
PLY = (176, 140, 92)         # varnished marine ply, sun-bleached: paler and greyer than the cedar canoe
FLOORPLY = (160, 132, 96)
ROPE = (198, 188, 166)
STEEL = (196, 198, 196)
ALGAE = (58, 70, 44)
SCUM = (190, 176, 150)
COWL = (64, 66, 70)          # the outboard: dark grey cowl, our own design, no maker
PAN = (40, 41, 44)
LEG = (94, 98, 104)
CREAM = (214, 204, 180)
PROP_BLACK = (36, 36, 38)
ALU = (172, 174, 172)
WATER = (26, 66, 62)


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {"samples": 48, "views": None, "maps_only": False, "no_render": False, "tag": None}
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
        else:
            raise SystemExit(f"unknown option {a}")
        i += 1
    return opt


# --------------------------------------------------------------------------- the lines

def rise(y):
    t = np.clip((np.asarray(y, np.float64) - RISE_Y0) / (Y_BOWC - RISE_Y0), 0, 1)
    return RISE * t * t


class Lines:
    """The tube's centre line: from the starboard stern tip (d = 0) forward, round the bow
    (d = S at the stem) and back to the port stern tip (d = 2 S)."""

    def __init__(self):
        t = np.linspace(0, math.pi / 2, 4001)
        e = 2 / BOW_N
        arc = np.stack([XC * np.cos(t) ** e, Y_BOW0 + (Y_BOWC - Y_BOW0) * np.sin(t) ** e], 1)
        self.xy = np.vstack([[XC, Y_TIP], arc])
        self.dd = np.r_[0, np.cumsum(np.linalg.norm(np.diff(self.xy, axis=0), axis=1))]
        self.S = float(self.dd[-1])
        self.d_bow0 = Y_BOW0 - Y_TIP
        # The tightest turn of the centre line must stay wider than the tube, or the inside pinches.
        d = np.arange(self.d_bow0, self.S, 0.01)
        p = np.array([self.point(x)[:2] for x in d])
        v, a = np.gradient(p, 0.01, axis=0), np.gradient(np.gradient(p, 0.01, axis=0), 0.01, axis=0)
        k = np.abs(v[:, 0] * a[:, 1] - v[:, 1] * a[:, 0]) / (np.linalg.norm(v, axis=1) ** 3 + 1e-12)
        self.min_radius = float(1 / k[3:-3].max())

    def point(self, d):
        if d > self.S:
            x, y, z = self.point(2 * self.S - d)
            return (-x, y, z)
        x = float(np.interp(d, self.dd, self.xy[:, 0]))
        y = float(np.interp(d, self.dd, self.xy[:, 1]))
        return (x, y, ZC + float(rise(y)))

    def frame(self, d):
        """Centre, tangent, outboard normal and upward binormal at d."""
        a, b = self.point(max(d - 0.01, 0.0)), self.point(min(d + 0.01, 2 * self.S))
        t = (Vector(b) - Vector(a)).normalized()
        n = Vector((t.y, -t.x, 0.0)).normalized()
        return Vector(self.point(d)), t, n, n.cross(t).normalized()

    def d_of_y(self, y):
        """Distance along the starboard tube to the section whose centre is at y."""
        return float(np.interp(y, self.xy[:, 1], self.dd))

    def sections(self, plain=False):
        """(d, radius, strake) for every ring, starboard tip to port tip."""
        cone = CONE_PLAIN if plain else CONE
        straight = [D_TR, self.d_bow0] if plain else [D_TR, 2.2, 3.55, self.d_bow0]
        bow = list(np.linspace(self.d_bow0, self.S, (6 if plain else 12) + 1)[1:])
        half = [(d, r, 0.0) for d, r in cone] + [(d, R, 1.0) for d in straight + bow]
        return half + [(2 * self.S - d, r, s) for d, r, s in reversed(half[:-1])], len(half) - 1, len(cone)


def v_of_phi(phi):
    return float(np.interp(phi, PHI_KEYS, V_KEYS))


# --------------------------------------------------------------------------- painters: the boat

def layout(at):
    at.alloc("tubeS", 1016, 286)
    at.alloc("tubeP", 1016, 286)
    at.alloc("floor", 760, 220)
    at.column([("bench", 244, 100), ("plyEdge", 244, 20), ("bottom", 244, 40), ("plyUnder", 244, 30)])
    at.alloc("transIn", 280, 150)
    at.alloc("transOut", 280, 150)
    at.alloc("metal", 120, 80)
    at.alloc("cap", 80, 80)


def paint_tube(at, name, lines, rng, port):
    """One half of the tube, laid flat: columns run from the stern tip to the stem, rows
    round the tube from the fabric bottom (bottom row) over the top to the floor."""
    w, h = at.dims(name)
    S = lines.S
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = (xx + 0.5) / w * S
    phi = np.interp(1 - (yy + 0.5) / h, V_KEYS, PHI_KEYS).astype(np.float32)
    wv = R * np.radians(phi)                                   # studs round the tube from the strake
    su = w / S
    sv = h * (V_KEYS[2] - V_KEYS[1]) / (R * math.radians(PHI_KEYS[2] - PHI_KEYS[1]))
    px = 1 / su

    def band(x, c, half, soft=None):
        soft = soft or 1.3 * px
        return smooth(half + soft, half - soft, np.abs(x - c))

    def dist(d0, p0):
        return np.hypot(d - d0, R * np.radians(phi - p0))

    def rrect(d0, p0, hd, hp, soft=None):                      # a rounded rectangle, half sizes in studs
        soft = soft or 1.3 * px
        qx = np.maximum(np.abs(d - d0) - hd + 0.04, 0)
        qy = np.maximum(np.abs(R * np.radians(phi - p0)) - hp + 0.04, 0)
        return smooth(0.04 + soft, 0.04 - soft, np.hypot(qx, qy))

    # ---- the hypalon itself
    mott = noise(h, w, (70, 170), rng, 3) - 0.5
    fine = noise(h, w, (5, 5), rng, 2) - 0.5
    weave = (np.sin(2 * np.pi * d / 0.046) * np.sin(2 * np.pi * wv / 0.046)).astype(np.float32)
    col = np.empty((h, w, 3), np.float32); col[:] = rgb(TUBE)
    col *= (1 + 0.10 * mott + 0.035 * fine + 0.007 * weave)[..., None]
    hgt = 0.0004 * weave + 0.0025 * mott
    rough = 0.56 + 0.08 * mott + 0.03 * fine
    # The sun has chalked the top a little; rain has run the dust down the outside.
    top = smooth(30, 78, phi) * smooth(170, 118, phi) * (0.55 + 0.9 * noise(h, w, (60, 200), rng, 2))
    col = mix(col, col * 1.07 + rgb((250, 214, 170)) * 0.06, 0.55 * np.clip(top, 0, 1))
    rough += 0.07 * np.clip(top, 0, 1)
    runs = smooth(0.56, 0.78, noise(h, w, (h * 1.6, 5), rng, 2)) * smooth(60, 20, phi) * smooth(-44, -20, phi)
    col *= (1 - 0.10 * runs)[..., None]
    # Dirt gathers in the crease against the floor.
    crease = smooth(168, 192, phi) * (0.6 + 0.4 * noise(h, w, (10, 60), rng, 2))
    col = mix(col, col * 0.62 + rgb((70, 62, 50)) * 0.06, 0.8 * crease)
    rough += 0.12 * crease
    # Pull the dry fabric exactly onto the house orange before anything is drawn on it.
    dry = (phi > -36) & (phi < 165)
    col *= (rgb(TUBE) / col[dry].reshape(-1, 3).mean(0))[None, None, :]

    # ---- the waterline: a damp dark band, a pale dried line above it, green below
    wet = smooth(-33, -46, phi + 3.0 * (noise(h, w, (h, 90), rng, 2) - 0.5))
    col = mix(col, col * 0.66, 0.85 * wet)
    rough = mix(rough, 0.30, 0.8 * wet)
    under = smooth(-46, -70, phi)
    col = mix(col, rgb(ALGAE) * (0.8 + 0.4 * noise(h, w, (8, 40), rng, 2))[..., None], 0.55 * under)
    scum = np.exp(-((phi + 35.5 - 2.5 * np.sin(d * 5.1)) / 1.8) ** 2) * (0.35 + 0.65 * noise(h, w, (3, 40), rng, 2))
    col = mix(col, rgb(SCUM), 0.38 * scum)
    rough += 0.2 * scum

    # ---- a doubled patch where people step aboard and sit
    d0, d1, p0, p1 = CHAFE
    patch = rrect((d0 + d1) / 2, (p0 + p1) / 2, (d1 - d0) / 2, R * math.radians(p1 - p0) / 2)
    inner = rrect((d0 + d1) / 2, (p0 + p1) / 2, (d1 - d0) / 2 - 0.035, R * math.radians(p1 - p0) / 2 - 0.035)
    col = mix(col, col * 0.955, patch)
    col *= (1 - 0.22 * (patch - inner))[..., None]
    scuff = smooth(0.52, 0.8, noise(h, w, (14, 30), rng, 3)) * inner
    col = mix(col, col * 1.10 + 0.02, 0.5 * scuff)
    hgt += 0.004 * patch
    rough += 0.05 * patch + 0.12 * scuff

    # ---- taped seams: round the tube between panels, and one along the inside
    cone_end = smooth(CONE[-1][0] - 0.03, CONE[-1][0] + 0.03, d)
    for s0 in SEAMS + [S]:
        tape = band(d, s0, 0.058)
        edge = band(d, s0 - 0.058, 0.006, 1.0 * px) + band(d, s0 + 0.058, 0.006, 1.0 * px)
        col = mix(col, col * (rgb(TAPE) / rgb(TUBE))[None, None, :], 0.8 * tape)
        col *= (1 - 0.30 * np.clip(edge, 0, 1))[..., None]
        hgt += 0.005 * tape - 0.016 * np.exp(-((d - s0) / 0.20) ** 2)       # the tube waists a little at each seam
        rough = mix(rough, 0.50, 0.6 * tape)
    long_ = band(wv, R * math.radians(166), 0.045) * cone_end
    col = mix(col, col * (rgb(TAPE) / rgb(TUBE))[None, None, :], 0.7 * long_)
    hgt += 0.004 * long_

    # ---- the rubbing strake, with its two glue flanges
    start = smooth(0.80, 0.88, d)
    half_s = R * math.radians(10.5)
    flange = band(wv, 0.0, R * math.radians(16.0)) * start
    strake = band(wv, 0.0, half_s) * start
    col = mix(col, col * (rgb(TAPE) / rgb(TUBE))[None, None, :] * 0.94, flange)
    hgt += 0.003 * flange
    scol = rgb(RUBBER) * (0.9 + 0.25 * noise(h, w, (6, 90), rng, 2))[..., None]
    rash = smooth(0.60, 0.80, noise(h, w, (2.5, 46), rng, 3)) * smooth(0.25, 0.6, noise(h, w, (h, 150), rng, 2))
    scol = mix(scol, rgb(RUBBER_PALE), 0.5 * rash)
    col = mix(col, scol, strake)
    hgt += strake * (0.004 * np.cos(2 * np.pi * wv / (half_s * 0.67)) - 0.003 * rash)
    rough = mix(rough, 0.64 + 0.22 * rash, strake)
    shade = smooth(-11, -14, phi) * smooth(-30, -14, phi) * start          # the strake's own shadow under it
    col *= (1 - 0.16 * shade)[..., None]

    # ---- moulded rubber: the transom holder, the seat holder, the oarlock pad, the cone cap
    def rubber(mask, lift=0.010, tone=1.0):
        nonlocal col, hgt, rough
        rc = rgb(RUBBER) * tone * (0.9 + 0.22 * noise(h, w, (9, 9), rng, 2))[..., None]
        col = mix(col, rc, mask)
        hgt = hgt * (1 - mask) + mask * (lift + 0.0006 * weave * 0)
        rough = mix(rough, 0.62, mask)
        col *= (1 - 0.25 * np.clip(blur(mask, 2.2) - mask, 0, 1) * 2.2)[..., None]      # a soft shadow round it

    rubber(rrect(D_TR, 150.0, 0.11, R * math.radians(48)))
    rubber(rrect(D_BENCH, 150.0, BENCH_HALF + 0.09, R * math.radians(27)))
    rubber(rrect(D_OAR, 90.0, 0.27, 0.19))
    cap = smooth(0.135, 0.115, d)
    rubber(cap, 0.006, 1.05)
    lip = band(d, 0.125, 0.012)
    col *= (1 - 0.3 * lip)[..., None]

    # ---- an inflation valve on the inside, aft
    dv = dist(D_VALVE, PHI_VALVE)
    rubber(smooth(0.125, 0.11, dv), 0.008)
    capm = smooth(0.078, 0.066, dv)
    slot = capm * np.clip(band(d, D_VALVE, 0.012) + band(wv, R * math.radians(PHI_VALVE), 0.012), 0, 1)
    col = mix(col, rgb((152, 154, 152)), capm)
    col = mix(col, rgb((70, 70, 72)), 0.8 * slot)
    hgt += capm * 0.014 * np.sqrt(np.clip(1 - (dv / 0.08) ** 2, 0, 1)) - 0.004 * slot
    rough = mix(rough, 0.42, capm)

    # ---- D-rings: a round doubled patch, a webbing strap and a steel ring hanging from it
    def dring(d0, p0):
        nonlocal col, hgt, rough
        dp = dist(d0, p0)
        patch = smooth(0.155, 0.14, dp)
        rim = patch - smooth(0.125, 0.11, dp)
        col = mix(col, col * 0.95, patch)
        col *= (1 - 0.22 * rim)[..., None]
        hgt += 0.004 * patch
        up = R * np.radians(phi - p0)
        strap = band(d, d0, 0.036) * smooth(-0.035, -0.02, up) * smooth(0.10, 0.085, up)
        col = mix(col, rgb(RUBBER) * 1.15, strap)
        hgt += 0.006 * strap
        cy = -0.065                                             # the ring hangs below the strap
        dr = np.hypot(d - d0, up - cy)
        ring = band(dr, 0.066, 0.017, 0.9 * px)
        shadow = band(np.hypot(d - d0 - 0.012, up - cy + 0.02), 0.066, 0.022, 2.5 * px) * (1 - ring)
        col *= (1 - 0.35 * shadow)[..., None]
        glint = 0.82 + 0.3 * smooth(-0.05, 0.07, (up - cy) - (d - d0))
        col = mix(col, rgb(STEEL) * glint[..., None], ring)
        hgt += 0.016 * ring
        rough = mix(rough, 0.28, ring)

    dring(D_DRING, PHI_DRING)
    dring(S, PHI_BOW_DRING)

    # ---- the grab line: holders along the shoulder, the rope sagging between them
    stops = HOLDERS + [S, 2 * S - HOLDERS[-1]]
    phi_r = np.full_like(d, ROPE_PHI)
    for a, b in zip(stops[:-1], stops[1:]):
        t = np.clip((d - a) / (b - a), 0, 1)
        inside = (d >= a) & (d < b)
        phi_r = np.where(inside, ROPE_PHI - ROPE_SAG * np.sin(np.pi * t) ** 2, phi_r)
    off = R * np.radians(phi - phi_r)
    run = smooth(HOLDERS[0] - 0.10, HOLDERS[0] - 0.08, d)
    holder = np.zeros((h, w), np.float32)
    tunnel = np.zeros((h, w), np.float32)
    for h0 in HOLDERS + [S]:
        holder = np.maximum(holder, rrect(h0, ROPE_PHI, 0.16, 0.115))
        tunnel = np.maximum(tunnel, band(d, h0, 0.058) * band(R * np.radians(phi - ROPE_PHI), 0.0, 0.085))
    rubber(holder, 0.008)
    knot = smooth(0.062, 0.05, dist(HOLDERS[0] - 0.115, ROPE_PHI))
    rope = np.clip(band(off, 0.0, 0.036, 1.1 * px) * run + knot, 0, 1)
    cast = band(off + 0.028, 0.0, 0.05, 4 * px) * run * (1 - rope) * (1 - 0.6 * holder)
    col *= (1 - 0.34 * cast)[..., None]
    lay = 0.5 + 0.5 * np.sin(2 * np.pi * (d + 1.5 * off) / 0.07)
    rcol = rgb(ROPE) * (0.78 + 0.30 * lay)[..., None] * (0.92 + 0.16 * noise(h, w, (4, 30), rng, 2))[..., None]
    rcol *= (0.72 + 0.28 * smooth(-0.036, 0.012, off))[..., None]           # round: darker along its lower edge
    col = mix(col, rcol, rope)
    hgt = hgt * (1 - rope) + rope * (0.008 + 0.030 * np.sqrt(np.clip(1 - (off / 0.04) ** 2, 0, 1)) * np.maximum(run, knot)
                                     + 0.004 * lay)
    rough = mix(rough, 0.86, rope)
    tcol = rgb(RUBBER) * (1.0 + 0.5 * smooth(0.06, 0.0, np.abs(R * np.radians(phi - ROPE_PHI) - 0.02)))[..., None]
    col = mix(col, tcol, tunnel)
    hgt = hgt * (1 - tunnel) + tunnel * 0.045
    rough = mix(rough, 0.6, tunnel)

    # ---- a few pale scrapes on the outside, where it has lain against the dock
    scrape = smooth(0.74, 0.86, noise(h, w, (2.0, 50), rng, 2)) * smooth(-28, -8, phi) * smooth(46, 18, phi) * (1 - strake) * start
    col = mix(col, col * 1.16 + 0.03, 0.42 * scrape)
    rough += 0.14 * scrape

    stats = {"dry_mean": [int(round(c * 255)) for c in col[dry & (strake < 0.01)].reshape(-1, 3).mean(0)]}
    if port:
        col, hgt, rough = col[:, ::-1], hgt[:, ::-1], rough[:, ::-1]
    at.paint(name, np.ascontiguousarray(col), np.ascontiguousarray(hgt), np.ascontiguousarray(rough), su, sv)
    return stats


def fabric(h, w, rng, value=1.0):
    col = np.empty((h, w, 3), np.float32); col[:] = rgb(FABRIC) * value
    n = noise(h, w, (30, 60), rng, 3) - 0.5
    f = noise(h, w, (3, 3), rng, 1) - 0.5
    col *= (1 + 0.22 * n + 0.10 * f)[..., None]
    return col, (0.002 * n + 0.0008 * f).astype(np.float32), (0.68 + 0.1 * n).astype(np.float32)


def paint_floor(at, grain, rng):
    """Looking down into the boat: columns run from the transom to the stem, rows across."""
    w, h = at.dims("floor")
    su, sv = w / FL, h / FW
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    y = Y_TR + (xx + 0.5) / su
    x = ((yy + 0.5) / h - 0.5) * FW
    col, hgt, rough = fabric(h, w, rng)
    keel = smooth(0.11, 0.09, np.abs(x))                        # the tape over the keel seam
    col = mix(col, col * 1.22, keel)
    hgt += 0.004 * keel
    fold = noise(h, w, (60, 9), rng, 2) - 0.5                    # the bow fabric lies in soft folds
    fore = smooth(SLAT_Y0 + SLAT_N * SLAT_PITCH - 0.2, Y_BOWC - 0.9, y)
    hgt += 0.012 * fold * fore
    col *= (1 + 0.25 * fold * fore)[..., None]
    grit = smooth(0.84, 0.92, noise(h, w, (2, 2), rng, 1)) * (0.3 + 0.7 * noise(h, w, (40, 40), rng, 2))
    col = mix(col, rgb((150, 138, 114)), 0.3 * grit)

    # Plywood slats across the boat, their ends in fabric sleeves along both sides.
    walked = np.exp(-(x / 0.60) ** 2) * (0.25 + 1.1 * noise(h, w, (46, 70), rng, 3))
    for k in range(SLAT_N):
        y0 = SLAT_Y0 + k * SLAT_PITCH
        c0, c1 = int(round((y0 - Y_TR) * su)), int(round((y0 + SLAT_W - Y_TR) * su))
        sw = c1 - c0
        wood, wh = hardwood(h, sw, grain, rng, FLOORPLY, float(rng.uniform(0.93, 1.07)), upright=True)
        wr = np.full((h, sw), 0.42, np.float32)
        wk = walked[:, c0:c1]
        # Varnish worn through to grey wood where feet go; dirt trodden in round it.
        bare = smooth(0.5, 0.85, wk * (0.7 + 0.6 * noise(h, sw, (30, 20), rng, 2)))
        lum = (wood @ LUMA)[..., None]
        wood = mix(wood, mix(wood, lum * rgb((200, 190, 172)) / 0.72, 0.55), 0.6 * bare)
        wr += 0.28 * bare
        dirt = smooth(0.55, 0.8, noise(h, sw, (18, 26), rng, 3)) * (0.4 + 0.6 * wk)
        wood = mix(wood, wood * 0.66 + rgb((60, 52, 40)) * 0.08, 0.55 * dirt)
        wr += 0.12 * dirt
        wood, wh = round_edges(wood, wh, 3.5, 0.014, 0.34, top=False, bottom=False, left=True, right=True)
        col[:, c0:c1] = wood
        hgt[:, c0:c1] = SLAT_H + wh
        rough[:, c0:c1] = wr
        if c1 + 3 < w:                                          # each slat shades the fabric beside it
            col[:, c1:c1 + 3] *= 0.6
        if c0 - 3 >= 0:
            col[:, c0 - 3:c0] *= 0.72
    slats_end = SLAT_Y0 + SLAT_N * SLAT_PITCH - (SLAT_PITCH - SLAT_W)
    sleeve = smooth(FL_HALF - 0.19, FL_HALF - 0.175, np.abs(x)) * smooth(slats_end + 0.12, slats_end + 0.08, y)
    scol, sh, sr = fabric(h, w, rng, 1.12)
    over = smooth(0.0, 0.03, np.maximum(hgt - 0.02, 0))          # the sleeve bulges over each slat end
    col = mix(col, scol * (0.82 + 0.28 * over)[..., None], sleeve)
    hgt = mix(hgt, hgt * 0.9 + 0.008 + sh, sleeve)
    rough = mix(rough, sr, sleeve)
    stitch = band_px(np.abs(x), FL_HALF - 0.155, 0.008, sv) * (np.sin(2 * np.pi * y / 0.07) > 0.1) * smooth(slats_end + 0.1, slats_end + 0.06, y)
    col = mix(col, rgb((176, 168, 150)), 0.6 * stitch)
    # Shade where the floor runs in under the tubes and against the transom; a little under the bench.
    edge = smooth(FL_HALF - 0.16, FL_HALF + 0.01, np.abs(x))
    col *= (1 - 0.42 * edge)[..., None]
    col *= (1 - 0.40 * smooth(Y_TR + 0.30, Y_TR + 0.08, y))[..., None]
    col *= (1 - 0.10 * smooth(BENCH_HALF + 0.35, BENCH_HALF - 0.1, np.abs(y - Y_BENCH)))[..., None]
    at.paint("floor", col, hgt, rough, su, sv)


def band_px(x, c, half, scale):
    soft = 1.2 / scale
    return smooth(half + soft, half - soft, np.abs(x - c))


def paint_wood(at, grain, rng):
    # ---- the bench: a varnished ply plank, worn pale where people sit
    w, h = at.dims("bench")
    su, sv = w / (2 * BENCH_X), h / (2 * BENCH_HALF)
    col, hgt = hardwood(h, w, grain, rng, PLY, 0.93)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    x = (xx + 0.5) / su - BENCH_X
    sat = np.exp(-((x / 0.62) ** 2 + (((yy - h / 2) / sv) / 0.30) ** 2)) * (0.55 + 0.8 * noise(h, w, (26, 40), rng, 2))
    bare = smooth(0.55, 0.95, sat)
    lum = (col @ LUMA)[..., None]
    col = mix(col, mix(col, lum * rgb((204, 190, 164)) / 0.7, 0.5), 0.6 * bare)
    rough = 0.36 + 0.3 * bare + 0.05 * (noise(h, w, (8, 60), rng) - 0.5)
    ends = smooth(1.02, 1.12, np.abs(x))                        # shade where it runs into the tubes
    col *= (1 - 0.4 * ends)[..., None]
    col, hgt = round_edges(col, hgt, 3.5, 0.016, 0.28)
    at.paint("bench", col, hgt, rough, su, sv)

    # ---- the cut edge of the ply: five veneers
    w, h = at.dims("plyEdge")
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    v = (yy + 0.5) / h * 5
    ply = np.where((np.floor(v) % 2) == 0, 1.0, 0.72).astype(np.float32) * (0.9 + 0.2 * noise(h, w, (h, 40), rng, 2))
    glue = smooth(0.12, 0.0, np.abs(v - np.round(v)))
    col = rgb(PLY)[None, None, :] * (0.92 * ply * (1 - 0.45 * glue))[..., None]
    at.paint("plyEdge", col, -0.002 * glue, np.full((h, w), 0.5, np.float32), 100.0, h / 0.14)

    w, h = at.dims("plyUnder")
    col, hgt = hardwood(h, w, grain, rng, PLY, 0.55)
    at.paint("plyUnder", col, hgt, np.full((h, w), 0.6, np.float32), 100.0, 100.0)

    # ---- the transom, inside and out
    for name, outside in (("transIn", False), ("transOut", True)):
        w, h = at.dims(name)
        su, sv = w / TW, h / TH
        col, hgt = hardwood(h, w, grain, rng, PLY, 0.96 if outside else 0.92)
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        x = (xx + 0.5) / su - TW / 2
        z = TZ0 + (1 - (yy + 0.5) / h) * TH
        rough = 0.38 + 0.06 * (noise(h, w, (8, 60), rng) - 0.5)
        weather = smooth(0.5, 0.82, noise(h, w, (40, 30), rng, 3)) * (0.9 if outside else 0.5)
        lum = (col @ LUMA)[..., None]
        col = mix(col, mix(col, lum * rgb((200, 192, 176)) / 0.7, 0.5), 0.5 * weather)
        rough += 0.2 * weather
        if outside:
            # The lake has stained the foot of it: wet and dark at the water, green under.
            wave = 0.02 * np.sin(x * 9.0) + 0.05 * (noise(h, w, (h, 50), rng, 2) - 0.5)
            wet = smooth(0.10, 0.0, z + wave)
            col = mix(col, col * 0.55, 0.85 * wet)
            rough = mix(rough, 0.28, 0.8 * wet)
            col = mix(col, rgb(ALGAE), 0.5 * smooth(0.0, -0.12, z + wave))
            line = np.exp(-((z + wave - 0.11) / 0.012) ** 2) * (0.4 + 0.6 * noise(h, w, (3, 30), rng, 2))
            col = mix(col, rgb(SCUM), 0.4 * line)
        else:
            foot = smooth(FLOOR_Z + 0.26, FLOOR_Z + 0.02, z) * (0.6 + 0.4 * noise(h, w, (10, 40), rng, 2))
            col = mix(col, col * 0.6, 0.7 * foot)
            rough += 0.12 * foot
        # The motor pad: a dark plate under the clamp, held by four bolts.
        ph, pz0 = (0.36, 0.46) if outside else (0.34, 0.52)
        qx = np.maximum(np.abs(x) - ph + 0.03, 0)
        qz = np.maximum(np.abs(z - (pz0 + TR_TOP + 0.05) / 2) - (TR_TOP + 0.05 - pz0) / 2 + 0.03, 0)
        pad = smooth(0.03 + 1.2 / su, 0.03 - 1.2 / su, np.hypot(qx, qz))
        col *= (1 - 0.3 * np.clip(blur(pad, 2.5) - pad, 0, 1) * 2.0)[..., None]
        pcol = rgb((70, 72, 76)) * (0.9 + 0.2 * noise(h, w, (12, 12), rng, 2))[..., None]
        col = mix(col, pcol, pad)
        hgt = hgt * (1 - pad) + 0.012 * pad
        rough = mix(rough, 0.5, pad)
        spots = [(sx * (ph - 0.07), pz0 + 0.07) for sx in (-1, 1)]
        spots += [(sx * 0.80, 0.56) for sx in (-1, 1)]                   # the bolts of two lifting eyes
        if outside:
            spots.append((0.62, 0.20))                                   # the drain bung
        for bx, bz in spots:
            dd = np.hypot(x - bx, z - bz)
            big = 0.06 if (bx, bz) == (0.62, 0.20) else 0.034
            head = smooth(big, big - 1.5 / su, dd)
            col *= (1 - 0.35 * smooth(big + 0.03, big, dd) * (1 - head))[..., None]
            col = mix(col, rgb(RUBBER if big > 0.05 else STEEL) * (0.85 + 0.3 * smooth(0.03, -0.03, (z - bz) - (x - bx)))[..., None], head)
            hgt += 0.008 * head
            rough = mix(rough, 0.6 if big > 0.05 else 0.3, head)
        col *= (0.86 + 0.14 * smooth(TR_TOP - 0.01, TR_TOP - 0.08, z))[..., None]
        at.paint(name, col, hgt, rough, su, sv)

    # ---- the fabric bottom, its keel strip rubbed pale, green where it stays wet
    w, h = at.dims("bottom")
    col, hgt, rough = fabric(h, w, rng, 0.9)
    yy = np.mgrid[0:h, 0:w][0].astype(np.float32)
    col = mix(col, rgb(ALGAE) * 0.8, 0.35 * noise(h, w, (10, 30), rng, 2))
    keel = smooth(3.5, 2.0, np.abs(yy - (h - 1) / 2))
    col = mix(col, rgb((96, 94, 92)), 0.7 * keel)
    hgt += 0.006 * keel
    at.paint("bottom", col, hgt, rough, w / FL, h / BOT_W)

    # ---- painted alloy (left three fifths) and bare steel (the rest): clamp, oarlocks
    w, h = at.dims("metal")
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    col = np.empty((h, w, 3), np.float32); col[:] = rgb((68, 70, 74))
    col *= (0.9 + 0.2 * noise(h, w, (14, 14), rng, 2))[..., None]
    chip = smooth(0.80, 0.88, noise(h, w, (3, 3), rng, 2))
    col = mix(col, rgb(ALU), 0.6 * chip)
    steel = xx > w * 0.6
    brushed = 0.88 + 0.24 * noise(h, w, (2, 40), rng, 2)
    col = np.where(steel[..., None], rgb(STEEL)[None, None, :] * 0.8 * brushed[..., None], col)
    at.paint("metal", col, 0.002 * chip, np.where(steel, 0.3, 0.5).astype(np.float32), 100.0, 100.0)

    # ---- the cap on the end of each cone
    w, h = at.dims("cap")
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    r = np.hypot(xx - (w - 1) / 2, yy - (h - 1) / 2) / (w / 2)
    col = np.empty((h, w, 3), np.float32); col[:] = rgb(RUBBER) * 1.05
    col *= (0.9 + 0.2 * noise(h, w, (9, 9), rng, 2))[..., None]
    ridge = smooth(0.06, 0.0, np.abs(r - 0.62))
    col *= (1 - 0.18 * ridge)[..., None]
    boss = smooth(0.24, 0.19, r)
    col = mix(col, rgb((74, 72, 70)), boss)
    at.paint("cap", col, -0.004 * ridge + 0.008 * boss, np.full((h, w), 0.6, np.float32), w / 0.4, h / 0.4)


def compose(lines):
    at = Atlas(1024, 1024, FABRIC)
    layout(at)
    grain = Grain()
    rng = np.random.default_rng(1128)
    stats = paint_tube(at, "tubeS", lines, rng, False)
    paint_tube(at, "tubeP", lines, rng, True)
    paint_floor(at, grain, rng)
    paint_wood(at, grain, rng)
    x, y, w, h = at.rects["tubeS"]
    mean = [int(round(c * 255)) for c in at.color[y:y + h, x:x + w].reshape(-1, 3).mean(0)]
    print(f"[dinghy] hull atlas: {len(at.rects)} rectangles, {at.used():.0%} used; dry hypalon mean {stats['dry_mean']}, "
          f"whole tube strip mean {mean}")
    return at, save_maps(at, NAME), {"dry_hypalon_mean_rgb": stats["dry_mean"], "tube_strip_mean_rgb": mean}


# --------------------------------------------------------------------------- painters: the outboard

COWL_Z0, COWL_Z1, COWL_SPLIT = 1.20, 2.02, 1.43
LEG_Z0, LEG_Z1 = -0.66, 1.26


def layout_motor(at):
    at.alloc("cowl", 506, 118)
    at.alloc("top", 110, 158)
    at.alloc("leg", 132, 216)
    at.column([("gear", 160, 84), ("tiller", 240, 26), ("plate", 100, 60)])
    at.alloc("prop", 60, 90)
    at.alloc("skeg", 60, 60)
    at.alloc("dark", 60, 60)


def cowl_a(x, y):
    """Where a point of the cowl's plan lies round the wrap: 0 and 1 at the stern, 0.25 on
    the starboard side, 0.5 at the front."""
    return (math.atan2(x / COWL_HW, -(y - COWL_Y) / COWL_HL) / (2 * math.pi)) % 1.0


def paint_motor(at, rng):
    # ---- the cowl, unwrapped round its sides
    w, h = at.dims("cowl")
    per = 3.4
    su, sv = w / per, h / (COWL_Z1 - COWL_Z0)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    a = (xx + 0.5) / w
    z = COWL_Z0 + (1 - (yy + 0.5) / h) * (COWL_Z1 - COWL_Z0)
    side = np.minimum(np.abs(a - 0.25), np.abs(a - 0.75)) * per          # studs from the middle of a side
    back = np.minimum(a, 1 - a) * per
    front = np.abs(a - 0.5) * per
    col = np.empty((h, w, 3), np.float32); col[:] = rgb(COWL)
    mott = noise(h, w, (40, 80), rng, 3) - 0.5
    col *= (1 + 0.10 * mott)[..., None]
    hgt = np.zeros((h, w), np.float32)
    rough = 0.36 + 0.08 * mott
    dust = smooth(COWL_Z1 - 0.2, COWL_Z1, z)                              # the shoulder catches the dust
    col = mix(col, col * 1.12 + 0.015, 0.6 * dust)
    rough += 0.12 * dust
    # Two pinstripes along each side, tapering out before the front and the back.
    taper = smooth(0.62, 0.42, side)
    for z0, half, tone in ((1.705, 0.030, CREAM), (1.650, 0.012, TUBE)):
        stripe = smooth(half * taper + 0.6 / sv, half * taper - 0.6 / sv, np.abs(z - z0)) * (taper > 0.02)
        col = mix(col, rgb(tone) * (0.92 + 0.16 * noise(h, w, (6, 30), rng, 2))[..., None], stripe)
    # Louvres at the back, a latch under them.
    for z0 in (1.80, 1.86, 1.92):
        slot = smooth(0.016, 0.008, np.abs(z - z0)) * smooth(0.26, 0.22, back)
        col = mix(col, rgb((14, 14, 16)), slot)
        hgt -= 0.012 * slot
    latch = smooth(0.07, 0.06, back) * smooth(0.05, 0.04, np.abs(z - 1.50))
    col = mix(col, rgb(ALU) * 0.9, latch)
    hgt += 0.01 * latch
    rough = mix(rough, 0.3, latch)
    # The front: the starter cord's grommet, a choke knob and a stop button.
    ah = cowl_a(0.20, COWL_Y + COWL_HL)
    for da, z0, rad, tone in (((ah - 0.5) * per, 1.74, 0.05, (20, 20, 22)), (0.0, 1.58, 0.04, (26, 26, 28)), (-0.16, 1.58, 0.032, (150, 52, 40))):
        dd = np.hypot((a - 0.5) * per - da, z - z0)
        knob = smooth(rad, rad - 0.012, dd)
        col *= (1 - 0.35 * smooth(rad + 0.03, rad, dd) * (1 - knob))[..., None]
        col = mix(col, rgb(tone), knob)
        hgt += 0.01 * knob
    # The lower pan: darker, matt, with a black seal where the cowl sits on it.
    pan = smooth(COWL_SPLIT + 0.005, COWL_SPLIT - 0.005, z)
    pcol = rgb(PAN)[None, None, :] * (0.9 + 0.2 * noise(h, w, (10, 40), rng, 2))[..., None]
    col = mix(col, pcol, pan)
    rough = mix(rough, 0.62, pan)
    seal = smooth(0.016, 0.008, np.abs(z - COWL_SPLIT))
    col = mix(col, rgb((12, 12, 14)), seal)
    hgt -= 0.01 * seal
    lipc = smooth(0.012, 0.004, np.abs(z - COWL_SPLIT - 0.026))
    col = mix(col, col * 1.35, 0.6 * lipc)
    scratch = smooth(0.80, 0.9, noise(h, w, (1.5, 26), rng, 2)) * (1 - pan)
    col = mix(col, col * 1.5 + 0.03, 0.35 * scratch)
    rough += 0.2 * scratch
    at.paint("cowl", col, hgt, rough, su, sv)

    # ---- the cowl from above
    w, h = at.dims("top")
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    col = np.empty((h, w, 3), np.float32); col[:] = rgb(COWL) * 1.08
    mott = noise(h, w, (30, 30), rng, 3) - 0.5
    col *= (1 + 0.12 * mott)[..., None]
    fx, fy = (xx - (w - 1) / 2) / (w / 2), ((h - 1) / 2 - yy) / (h / 2)       # fy is +1 at the front
    rib = smooth(0.05, 0.02, np.abs(fx)) * smooth(0.78, 0.6, np.abs(fy + 0.1))  # a moulded spine down the middle
    hgt = 0.01 * rib
    col *= (1 + 0.10 * rib)[..., None]
    scratch = smooth(0.80, 0.9, noise(h, w, (20, 2), rng, 2))
    col = mix(col, col * 1.45 + 0.03, 0.3 * scratch)
    at.paint("top", col, hgt, 0.42 + 0.1 * mott + 0.2 * scratch, w / 0.92, h / 1.32)

    # ---- the leg: painted alloy, a joint with bolts, stained below the water
    w, h = at.dims("leg")
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    z = LEG_Z0 + (1 - (yy + 0.5) / h) * (LEG_Z1 - LEG_Z0)
    col = np.empty((h, w, 3), np.float32); col[:] = rgb(LEG)
    mott = noise(h, w, (30, 30), rng, 3) - 0.5
    col *= (1 + 0.12 * mott)[..., None]
    hgt = np.zeros((h, w), np.float32)
    rough = 0.46 + 0.1 * mott
    joint = smooth(0.016, 0.006, np.abs(z - 0.22))
    col *= (1 - 0.5 * joint)[..., None]
    hgt -= 0.008 * joint
    for bx in (0.17, 0.5, 0.83):
        dd = np.hypot((xx / w - bx) * 1.2, z - 0.29)
        head = smooth(0.03, 0.02, dd)
        col = mix(col, rgb(STEEL) * 0.9, head)
        hgt += 0.008 * head
    chip = smooth(0.80, 0.9, noise(h, w, (3, 3), rng, 2))
    col = mix(col, rgb(ALU), 0.5 * chip)
    wet = smooth(0.08, -0.02, z + 0.05 * (noise(h, w, (h, 20), rng, 2) - 0.5))
    col = mix(col, col * 0.62, 0.8 * wet)
    col = mix(col, rgb(ALGAE) * 1.1, 0.35 * smooth(0.0, -0.3, z))
    rough = mix(rough, 0.3, 0.7 * wet)
    line = np.exp(-((z - 0.10) / 0.014) ** 2) * (0.4 + 0.6 * noise(h, w, (3, 20), rng, 2))
    col = mix(col, rgb(SCUM), 0.4 * line)
    at.paint("leg", col, hgt, rough, w / 1.2, h / (LEG_Z1 - LEG_Z0))

    for name, tone, value in (("gear", LEG, 0.62), ("plate", LEG, 0.66), ("skeg", LEG, 0.6), ("dark", PAN, 1.15)):
        w, h = at.dims(name)
        col = np.empty((h, w, 3), np.float32); col[:] = rgb(tone) * value
        col *= (0.88 + 0.24 * noise(h, w, (16, 16), rng, 3))[..., None]
        if name != "dark":
            col = mix(col, rgb(ALGAE), 0.3 * noise(h, w, (12, 20), rng, 2))
        chip = smooth(0.78, 0.9, noise(h, w, (3, 3), rng, 2))
        col = mix(col, rgb(ALU) * 0.9, 0.45 * chip)
        at.paint(name, col, 0.002 * chip, np.full((h, w), 0.4 if name != "dark" else 0.55, np.float32), 110.0, 110.0)

    # ---- a propeller blade: black paint worn to bare alloy along the edges and the tip
    w, h = at.dims("prop")
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    edge = np.minimum(np.minimum(xx, w - 1 - xx), yy)                      # the tip is the top row
    worn = smooth(9, 2, edge + 6 * (noise(h, w, (8, 8), rng, 2) - 0.5))
    col = mix(np.broadcast_to(rgb(PROP_BLACK), (h, w, 3)).copy(), rgb(ALU), 0.85 * worn)
    at.paint("prop", col, np.zeros((h, w), np.float32), 0.42 - 0.1 * worn, 200.0, 200.0)

    # ---- the tiller: a painted arm, then a ribbed rubber twist grip
    w, h = at.dims("tiller")
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    u = (xx + 0.5) / w
    grip = smooth(0.655, 0.665, u)
    col = np.empty((h, w, 3), np.float32); col[:] = rgb(COWL) * 0.95
    col *= (0.9 + 0.2 * noise(h, w, (h, 20), rng, 2))[..., None]
    ribs = np.cos(2 * np.pi * u * 1.52 / 0.035)
    gcol = rgb((24, 24, 26))[None, None, :] * (0.85 + 0.25 * ribs)[..., None]
    col = mix(col, gcol, grip)
    collar = smooth(0.012, 0.006, np.abs(u - 0.645))
    col = mix(col, rgb(ALU) * 0.85, collar)
    at.paint("tiller", col, 0.004 * ribs * grip, mix(np.full((h, w), 0.42, np.float32), 0.8, grip), w / 1.52, h / 0.36)


def compose_motor():
    at = Atlas(512, 512, COWL)
    layout_motor(at)
    paint_motor(at, np.random.default_rng(404))
    print(f"[dinghy] outboard atlas: {len(at.rects)} rectangles, {at.used():.0%} used")
    return at, save_maps(at, MOTOR)


def save_maps(at, name):
    paths = {}
    for folder in (SCRATCH, MAPS):
        folder.mkdir(parents=True, exist_ok=True)
        for key, arr in (("color", at.color), ("normal", at.normal), ("rough", at.rough)):
            write_png(folder / f"{name}_{key}.png", arr)
            paths[key] = folder / f"{name}_{key}.png"
    return paths


# --------------------------------------------------------------------------- the mesh

def shade(c, k):
    return tuple(int(v * k) for v in c)


class DMesh(Mesh):
    """cedar_canoe.Mesh with a sheet whose every quad names its own rectangle, boxes and
    lofts. `shift` moves the whole mesh (the outboard is built in the boat's axes, then
    moved so that its pivot is the origin)."""

    def __init__(self, at=None, plain=False, shift=(0.0, 0.0, 0.0)):
        super().__init__(at, plain)
        self.shift = shift

    def _p(self, p):
        return (p[0] - self.shift[0], p[1] - self.shift[1], p[2] - self.shift[2])

    def sheet(self, pts, uv_of, hint, smooth_=True, tone=None, skip=None):
        """Quads over pts[i][j]. uv_of(i, j) gives (rectangle, four (a, b)) for the corners
        (i, j), (i+1, j), (i+1, j+1), (i, j+1). `hint` is a vector the faces should look
        along, or a function of (centre, i, j)."""
        ni, nj = len(pts), len(pts[0])
        cache = {}

        def vert(i, j):
            key = tuple(round(c, 5) for c in pts[i][j])
            if key not in cache:
                cache[key] = self.bm.verts.new(self._p(pts[i][j]))
            return cache[key]

        for i in range(ni - 1):
            for j in range(nj - 1):
                if skip and skip(i, j):
                    continue
                idx = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
                q = [Vector(pts[a][b]) for a, b in idx]
                rect, ab = uv_of(i, j)
                c = (q[0] + q[1] + q[2] + q[3]) / 4
                hv = Vector(hint(c, i, j)) if callable(hint) else Vector(hint)
                order = [0, 1, 2, 3]
                if self._normal(q).dot(hv) < 0:
                    order.reverse()
                vs = [vert(*idx[k]) for k in order]
                uvs = [self.at.pt(rect, *ab[k]) if self.at else ab[k] for k in order]
                q = [q[k] for k in order]
                t = tone(i, j) if callable(tone) else tone
                if len(set(vs)) == 4:                    # cut a warped quad along its flatter diagonal
                    cuts = []
                    for tri in (((0, 1, 2), (0, 2, 3)), ((0, 1, 3), (1, 2, 3))):
                        n = [(q[k[1]] - q[k[0]]).cross(q[k[2]] - q[k[0]]) for k in tri]
                        flat = n[0].normalized().dot(n[1].normalized()) if min(n[0].length, n[1].length) > 1e-9 else -2.0
                        cuts.append((flat, tri))
                    if min(c_[0] for c_ in cuts) < 0.99995:
                        for k in max(cuts, key=lambda c_: c_[0])[1]:
                            self._emit([vs[x] for x in k], [uvs[x] for x in k], smooth_, t)
                        continue
                self._emit(vs, uvs, smooth_, t)

    def wrap(self, pts, rect, a_of, b_of, hint, smooth_=True, tone=None, skip=None):
        A = [[a_of(i, j, p) for j, p in enumerate(row)] for i, row in enumerate(pts)]
        B = [[b_of(i, j, p) for j, p in enumerate(row)] for i, row in enumerate(pts)]

        def uv_of(i, j):
            return rect, [(A[i][j], B[i][j]), (A[i + 1][j], B[i + 1][j]), (A[i + 1][j + 1], B[i + 1][j + 1]), (A[i][j + 1], B[i][j + 1])]
        self.sheet(pts, uv_of, hint, smooth_, tone, skip)

    def box(self, lo, hi, rect, faces="+x-x+y-y+z-z", region=(0.0, 0.0, 1.0, 1.0), tone=None, rects=None):
        """An axis-aligned box. Each face takes `region` (a0, b0, a1, b1) of `rect`, or its
        own (rect, region) from `rects`, laid so that the picture is never mirrored."""
        x0, y0, z0 = lo; x1, y1, z1 = hi
        quads = {
            "+x": ([(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], (1, 0, 0)),
            "-x": ([(x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1)], (-1, 0, 0)),
            "+y": ([(x1, y1, z0), (x0, y1, z0), (x0, y1, z1), (x1, y1, z1)], (0, 1, 0)),
            "-y": ([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], (0, -1, 0)),
            "+z": ([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], (0, 0, 1)),
            "-z": ([(x0, y1, z0), (x1, y1, z0), (x1, y0, z0), (x0, y0, z0)], (0, 0, -1)),
        }
        for key, (pts, n) in quads.items():
            if key not in faces:
                continue
            r, (a0, b0, a1, b1) = (rects or {}).get(key, (rect, region))
            self.poly(pts, r, [(a0, b0), (a1, b0), (a1, b1), (a0, b1)], n, tone=tone)

    def tube(self, rings, rect, hint_axis, a_span=(0.0, 1.0), b_of=None, tone=None, smooth_=True, caps=(None, None)):
        """A loft through closed rings (each a list of points). Round the ring is `a`,
        along the loft is `b` (or b_of(i))."""
        closed = [r + [r[0]] for r in rings]
        n = len(rings[0])
        cen = [sum((Vector(p) for p in r), Vector()) / len(r) for r in rings]
        self.wrap(closed, rect, lambda i, j, p: a_span[0] + (a_span[1] - a_span[0]) * j / n,
                  (lambda i, j, p: b_of(i)) if b_of else (lambda i, j, p: i / (len(rings) - 1)),
                  lambda c, i, j: c - (cen[i] + cen[i + 1]) / 2, smooth_, tone)
        for k, capn in zip((0, -1), caps):
            if capn:
                r = rings[k]
                d = (cen[k] - cen[1 if k == 0 else -2])
                self.poly(r, capn[0], [capn[1]] * len(r), tuple(d), tone=tone if not callable(tone) else tone(0, 0))


def build_boat(at, lines, plain=False):
    """The boat in design axes (bow +Y). Returns the object and a few measured numbers."""
    m = DMesh(at, plain)
    S = lines.S
    angles = ANGLES_PLAIN if plain else ANGLES
    secs, tip, ncone = lines.sections(plain)
    j_floor = angles.index(192)
    bump_at = 12.01 if plain else 9.01

    rings, cens = [], []
    for d, r, s in secs:
        c, t, n, b = lines.frame(d)
        row = []
        for a in angles:
            rr = r + (STRAKE * s if abs(a) <= bump_at else 0.0)
            ph = math.radians(a)
            row.append(tuple(c + rr * (math.cos(ph) * n + math.sin(ph) * b)))
        rings.append(row)
        cens.append(c)
    i_tr = ncone                               # the ring in the transom, starboard; its twin is len - 1 - i_tr
    last = len(secs) - 1

    def tube_uv(i, j):
        rect = "tubeS" if i < tip else "tubeP"
        a = [(secs[k][0] / S) if rect == "tubeS" else (secs[k][0] - S) / S for k in (i, i + 1)]
        b = [v_of_phi(angles[k]) for k in (j, j + 1)]
        return rect, [(a[0], b[0]), (a[1], b[0]), (a[1], b[1]), (a[0], b[1])]

    def tube_tone(i, j):
        if i == 0 or i == last - 1:
            return RUBBER
        if abs(angles[j]) <= 12 and abs(angles[j + 1]) <= 12 and secs[i][2] + secs[i + 1][2] > 0:
            return RUBBER
        if angles[j + 1] <= -44:
            return shade(TUBE, 0.62)
        return shade(TUBE, 1.05) if 30 <= angles[j] < 135 else TUBE

    m.sheet(rings, tube_uv, lambda c, i, j: c - (cens[i] + cens[i + 1]) / 2, tone=tube_tone,
            skip=lambda i, j: j >= j_floor and i_tr <= i < last - i_tr)
    for k in (0, last):                        # the caps on the cone ends
        c, r = cens[k], secs[k][1]
        ring = rings[k][:-1]
        m.poly(ring, "cap", [(0.5 + 0.47 * (p[0] - c.x) / r, 0.5 + 0.47 * (p[2] - c.z) / r) for p in ring], (0, -1, 0), tone=RUBBER)

    # The floor (fabric, the slats drawn on it) and the fabric bottom, both hung between the
    # two tubes ring by ring, so they follow the bow as it narrows and lifts.
    half = list(range(i_tr, tip + 1))
    floor, bottom = [], []
    z_att0 = rings[i_tr][0][2]
    x_att0 = rings[i_tr][0][0]
    pa = rings[i_tr][0]
    bottom.append([(-pa[0], Y_TR - TR_T / 2, pa[2]), (0.0, Y_TR - TR_T / 2, -DRAFT), (pa[0], Y_TR - TR_T / 2, pa[2])])
    for i in half:
        ps = rings[i][j_floor]
        floor.append([(f * ps[0], ps[1], ps[2]) for f in (-1.0, -0.5, 0.0, 0.5, 1.0)])
        pa = rings[i][0]
        zk = pa[2] - (z_att0 + DRAFT) * (pa[0] / x_att0)
        bottom.append([(-pa[0], pa[1], pa[2]), (0.0, pa[1], zk), (pa[0], pa[1], pa[2])])
    m.wrap(floor, "floor", lambda i, j, p: (p[1] - Y_TR) / FL, lambda i, j, p: 0.5 - p[0] / FW, (0, 0, 1),
           smooth_=True, tone=FABRIC)
    m.wrap(bottom, "bottom", lambda i, j, p: (p[1] - Y_TR + TR_T / 2) / (FL + TR_T), lambda i, j, p: 0.5 + p[0] / BOT_W, (0, 0, -1),
           smooth_=False, tone=shade(FABRIC, 0.8))
    if plain:                                  # no map on the twin, so its slats are real: thin plates on the floor
        for k in range(SLAT_N):
            y0 = SLAT_Y0 + k * SLAT_PITCH
            z = FLOOR_Z + float(rise(y0 + SLAT_W / 2)) + 0.02
            hw = FL_HALF + 0.05
            m.poly([(-hw, y0, z), (hw, y0, z), (hw, y0 + SLAT_W, z), (-hw, y0 + SLAT_W, z)], "floor", [(0, 0)] * 4, (0, 0, 1),
                   tone=shade(FLOORPLY, 0.94 + 0.06 * (k % 3)))

    # The transom: a ply board between the tubes, its top corners cut away.
    # Its foot lies on the V of the bottom and its sides run on into the tubes, so nothing shows past it from astern.
    out = [(-0.74, TR_TOP), (0.74, TR_TOP), (1.10, 0.74), (x_att0, 0.30), (x_att0, z_att0), (0.0, -DRAFT),
           (-x_att0, z_att0), (-x_att0, 0.30), (-1.10, 0.74)]
    yi, yo = Y_TR + TR_T / 2, Y_TR - TR_T / 2
    m.poly([(x, yi, z) for x, z in out], "transIn", [(0.5 - x / TW, (z - TZ0) / TH) for x, z in out], (0, 1, 0), tone=shade(PLY, 0.9))
    m.poly([(x, yo, z) for x, z in out], "transOut", [(0.5 + x / TW, (z - TZ0) / TH) for x, z in out], (0, -1, 0), tone=shade(PLY, 0.8))
    for (xa, za), (xb, zb) in ((out[8], out[0]), (out[0], out[1]), (out[1], out[2])):       # the top edge and the two cut corners
        ln = math.hypot(xb - xa, zb - za) / 2.44
        m.poly([(xa, yo, za), (xb, yo, zb), (xb, yi, zb), (xa, yi, za)], "plyEdge", [(0.02, 0.1), (0.02 + ln, 0.1), (0.02 + ln, 0.9), (0.02, 0.9)],
               (-(zb - za), 0.0, xb - xa), tone=PLY)

    # The bench: a ply plank let into the seat holders on the tubes.
    b0, b1, zb0 = Y_BENCH - BENCH_HALF, Y_BENCH + BENCH_HALF, BENCH_TOP - BENCH_T
    m.box((-BENCH_X, b0, zb0), (BENCH_X, b1, BENCH_TOP), "bench", "+z-z+y-y", tone=PLY, rects={
        "-z": ("plyUnder", (0.02, 0.1, 0.98, 0.9)), "+y": ("plyEdge", (0.0, 0.05, 1.0, 0.95)), "-y": ("plyEdge", (0.0, 0.05, 1.0, 0.95))})

    # The outboard's clamp stays with the boat (the motor swivels in it): a saddle over the
    # transom, a plate down each face and two thumb screws inside.
    dark, steel = (0.04, 0.1, 0.5, 0.9), (0.68, 0.1, 0.96, 0.9)
    m.box((-0.25, yo - 0.07, 0.54), (0.25, yo, TR_TOP + 0.05), "metal", "+x-x-y+z-z", dark, tone=(68, 70, 74))
    m.box((-0.25, yo, TR_TOP), (0.25, yi + 0.05, TR_TOP + 0.05), "metal", "+x-x+z", dark, tone=(68, 70, 74))
    m.box((-0.25, yi, 0.58), (0.25, yi + 0.05, TR_TOP + 0.05), "metal", "+x-x+y-z", dark, tone=(68, 70, 74))
    for sx, upright in ((-0.14, False), (0.14, True)):
        m.box((sx - 0.028, yi + 0.05, 0.672), (sx + 0.028, yi + 0.20, 0.728), "metal", "+x-x+z-z", steel, tone=STEEL)
        hx, hz = (0.03, 0.10) if upright else (0.10, 0.03)
        m.box((sx - hx, yi + 0.19, 0.70 - hz), (sx + hx, yi + 0.245, 0.70 + hz), "metal", "+x-x+y-y+z-z", steel, tone=STEEL)

    # Oarlocks: a rubber block on its pad with a steel pin and a button top.
    for sx in (-1, 1):
        zt = ZC + R
        m.box((sx * XC - 0.10, Y_OAR - 0.17, zt - 0.02), (sx * XC + 0.10, Y_OAR + 0.17, zt + 0.08), "metal", "+x-x+y-y+z",
              (0.04, 0.1, 0.5, 0.9), tone=RUBBER)
        prof = [(zt + 0.07, 0.042), (zt + 0.27, 0.042), (zt + 0.27, 0.068), (zt + 0.33, 0.068)]
        pin = [[(sx * XC + r * math.cos(k * math.pi / 3), Y_OAR + r * math.sin(k * math.pi / 3), z) for k in range(6)] for z, r in prof]
        m.tube(pin, "metal", None, a_span=(0.68, 0.96), b_of=lambda i: 0.1 + 0.8 * i / 3, tone=shade(STEEL, 0.8), caps=(None, ("metal", (0.8, 0.5))))

    ob = m.finish(PLAIN if plain else NAME)
    info = {
        "mirrored": m.mirrored, "S": round(S, 3), "min_radius": round(lines.min_radius, 3),
        "floor_z": round(FLOOR_Z, 3), "floor_at_passenger": round(FLOOR_Z + float(rise(Y_PASS)), 3),
        "tube_top": round(ZC + R, 3), "bow_top": round(ZC + R + RISE, 3), "tube_bottom": round(ZC - R, 3),
        "inside_half_width": round(FL_HALF, 3), "sections": len(secs),
    }
    return ob, info


def build_motor(at, plain=False):
    """The outboard, built in the boat's design axes and moved so that PIVOT is the origin."""
    m = DMesh(at, plain, shift=PIVOT)
    n = 16
    seen = [0]

    def mark(label):
        if m.mirrored != seen[0] and not plain:
            print(f"[dinghy] mirrored in {label}: {m.mirrored - seen[0]}")
        seen[0] = m.mirrored

    def plan(sx, sy, dy=0.0, dz=0.0):
        """The cowl's outline at one height: fuller than an ellipse, narrower aft. Starts at
        the stern and goes round by the starboard side."""
        pts = []
        for k in range(n):
            th = 2 * math.pi * k / n
            cx, cy = math.sin(th), -math.cos(th)
            ex = 2 / 2.8
            x = COWL_HW * sx * math.copysign(abs(cx) ** ex, cx)
            y = COWL_HL * sy * math.copysign(abs(cy) ** ex, cy)
            if y < 0:
                x *= 1 - 0.16 * smooth(0.0, 1.0, -y / (COWL_HL * sy))
            pts.append((x, COWL_Y + y + dy, y))
        return pts

    def cowl_ring(z, sx, sy, dy=0.0, tilt=0.0):
        return [(x, y, z + tilt * yl / COWL_HL) for x, y, yl in plan(sx, sy, dy)]

    # The cowl: a pan, the split, straight sides, a rounded shoulder, a crown that is a
    # little higher at the front.
    prof = [(COWL_Z0, 0.60, 0.66, -0.04, 0.0), (1.37, 0.95, 0.96, 0.0, 0.0), (COWL_SPLIT, 1.0, 1.0, 0.0, 0.0),
            (1.84, 1.0, 1.0, 0.0, 0.02), (1.97, 0.93, 0.94, 0.0, 0.035), (COWL_Z1, 0.80, 0.83, 0.0, 0.045)]
    rings = [cowl_ring(z, sx, sy, dy, tilt) for z, sx, sy, dy, tilt in prof]
    zs = [p[0] for p in prof]

    def cowl_tone(i, j):
        return PAN if i < 2 else (shade(COWL, 1.12) if i >= 4 else COWL)

    rings.append(cowl_ring(2.09, 0.50, 0.56, 0.0, 0.05))
    closed = [r + [r[0]] for r in rings]
    cen = Vector((0.0, COWL_Y, 1.7))

    def top_uv(p):
        return (0.5 + p[0] / 0.92, 0.5 + (p[1] - COWL_Y) / 1.32)

    def cowl_uv(i, j):
        if i == len(rings) - 2:                 # the crown is seen from above
            return "top", [top_uv(closed[a][b]) for a, b in ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))]
        b = [(zs[k] - COWL_Z0) / (COWL_Z1 - COWL_Z0) for k in (i, i + 1)]
        return "cowl", [(j / n, b[0]), (j / n, b[1]), ((j + 1) / n, b[1]), ((j + 1) / n, b[0])]

    m.sheet(closed, cowl_uv, lambda c, i, j: Vector((c.x, c.y - COWL_Y, 0.25 if i >= len(rings) - 3 else 0.0)), tone=cowl_tone)
    m.poly(rings[0], "dark", [(0.5, 0.5)] * n, (0, 0, -1), tone=PAN)
    m.poly(rings[-1], "top", [top_uv(p) for p in rings[-1]], (0, 0, 1), smooth_=True, tone=shade(COWL, 1.15))
    mark("cowl")
    # The fuel cap, forward on the crown, and the starter's T handle on the front.
    capz = 2.09 + 0.05 * (0.26 / COWL_HL)
    cap = [[(0.0 + r * math.cos(k * math.pi / 4), COWL_Y + 0.26 + r * math.sin(k * math.pi / 4), z) for k in range(8)]
           for z, r in ((capz - 0.03, 0.105), (capz + 0.05, 0.105), (capz + 0.065, 0.08))]
    m.tube(cap, "dark", None, a_span=(0.1, 0.9), b_of=lambda i: 0.2 + 0.3 * i, tone=(24, 24, 26), caps=(None, ("dark", (0.5, 0.5))))
    fy = COWL_Y + COWL_HL
    m.box((0.12, fy - 0.03, 1.715), (0.28, fy + 0.055, 1.765), "dark", "+x-x+y+z-z", (0.1, 0.1, 0.9, 0.9), tone=(24, 24, 26))

    mark("cap and handle")
    # The tiller: an arm out of the front of the pan, a thicker twist grip at its end.
    a, b = Vector(TILLER[0]), Vector(TILLER[1])
    ax = (b - a).normalized()
    sx_ = ax.cross(Vector((0, 0, 1))).normalized()
    up = sx_.cross(ax).normalized()
    ln = (b - a).length
    tprof = [(0.0, 0.05), (ln * 0.645, 0.045), (ln * 0.655, 0.066), (ln, 0.066)]
    trings = [[tuple(a + ax * s + r * (math.cos(k * math.pi / 3) * sx_ + math.sin(k * math.pi / 3) * up)) for k in range(6)] for s, r in tprof]
    m.wrap([[r[j % 6] for r in trings] for j in range(7)], "tiller", lambda i, j, p: tprof[j][0] / ln, lambda i, j, p: i / 6,
           lambda c, i, j: c - (a + ax * ax.dot(c - a)), tone=lambda i, j: (24, 24, 26) if j >= 2 else shade(COWL, 0.95))
    m.poly(trings[-1], "tiller", [(0.99, 0.5)] * 6, tuple(ax), tone=(24, 24, 26))

    mark("tiller")
    # The swivel column (it turns in the boat's clamp) and the leg under the cowl.
    col_ = [[(0.10 * math.cos(k * math.pi / 4), PIVOT[1] + 0.10 * math.sin(k * math.pi / 4), z) for k in range(8)] for z in (0.44, 1.22)]
    m.tube(col_, "dark", None, a_span=(0.1, 0.9), b_of=lambda i: 0.1 + 0.8 * i, tone=shade(PAN, 1.2), caps=(("dark", (0.5, 0.5)), ("dark", (0.5, 0.5))))
    m.box((-0.07, -3.60, 0.50), (0.07, PIVOT[1], 0.66), "dark", "+x-x+z-z", (0.1, 0.1, 0.9, 0.9), tone=shade(PAN, 1.2))
    m.box((-0.07, -3.60, 1.02), (0.07, PIVOT[1], 1.22), "dark", "+x-x-z", (0.1, 0.1, 0.9, 0.9), tone=shade(PAN, 1.2))

    mark("swivel")
    def leg_ring(z, hw, y0, y1):
        ln_ = y0 - y1
        return [(0.0, y1, z), (hw, y1 + 0.24 * ln_, z), (hw, y0 - 0.30 * ln_, z), (0.0, y0, z), (-hw, y0 - 0.30 * ln_, z), (-hw, y1 + 0.24 * ln_, z)]

    lprof = [(LEG_Z1, 0.19, -3.50, -4.02), (0.86, 0.15, -3.53, -3.97), (0.22, 0.12, -3.55, -3.94), (-0.30, 0.105, -3.56, -3.94),
             (-0.50, 0.075, -3.58, -3.90), (LEG_Z0, 0.075, -3.58, -3.90)]
    lz = [p[0] for p in lprof]
    m.tube([leg_ring(*p) for p in reversed(lprof)], "leg", None, b_of=lambda i: (lz[len(lz) - 1 - i] - LEG_Z0) / (LEG_Z1 - LEG_Z0),
           tone=lambda i, j: shade(LEG, 0.62) if lz[len(lz) - 2 - i] < 0 else LEG)

    mark("leg")
    # The anti-ventilation plate over the propeller.
    pz = -0.30
    outline = [(0.0, -3.50), (0.25, -3.64), (0.27, -4.24), (0.0, -4.40), (-0.27, -4.24), (-0.25, -3.64)]
    for z, hint in ((pz + 0.02, (0, 0, 1)), (pz - 0.02, (0, 0, -1))):
        ab = [(0.5 + (x / 0.6) * (1 if hint[2] > 0 else -1), (y + 4.45) / 1.0) for x, y in outline]
        m.poly([(x, y, z) for x, y in outline], "plate", ab, hint, tone=shade(LEG, 0.66))
    edge = [[(x, y, pz - 0.02) for x, y in outline + outline[:1]], [(x, y, pz + 0.02) for x, y in outline + outline[:1]]]
    m.wrap(edge, "plate", lambda i, j, p: 0.05 + 0.1 * i, lambda i, j, p: 0.05 + 0.12 * j, lambda c, i, j: (c.x, c.y + 3.95, 0.0),
           smooth_=False, tone=shade(LEG, 0.6))

    mark("plate")
    # The gearcase: a torpedo with the propeller hub behind it, and the skeg under it.
    gz = PROP[2]
    gprof = [(-3.36, 0.03), (-3.44, 0.11), (-3.60, 0.165), (-3.88, 0.165), (-4.03, 0.12), (-4.05, 0.105), (-4.24, 0.07)]
    grings = [[(r * math.cos(k * math.pi / 4), y, gz + r * math.sin(k * math.pi / 4)) for k in range(8)] for y, r in gprof]
    m.tube(grings, "gear", None, b_of=lambda i: 0.04 + 0.92 * (gprof[0][0] - gprof[i][0]) / (gprof[0][0] - gprof[-1][0]),
           tone=lambda i, j: shade(LEG, 0.6) if i < 4 else PROP_BLACK, caps=(("gear", (0.5, 0.04)), ("gear", (0.5, 0.96))))
    sk = [(-3.50, gz - 0.13), (-3.94, gz - 0.13), (-3.90, gz - 0.46), (-3.74, gz - 0.50)]
    for sx, hint in ((0.022, (1, 0, 0)), (-0.022, (-1, 0, 0))):
        ab = [(0.5 + (y + 3.72) / 0.5 * (1 if sx > 0 else -1), 1 - (gz - 0.13 - z) / 0.4) for y, z in sk]
        m.poly([(sx, y, z) for y, z in sk], "skeg", ab, hint, tone=shade(LEG, 0.58))
    loop = sk + sk[:1]
    m.wrap([[(-0.022, y, z) for y, z in loop], [(0.022, y, z) for y, z in loop]], "skeg", lambda i, j, p: 0.1 + 0.15 * j, lambda i, j, p: 0.1 + 0.1 * i,
           lambda c, i, j: (0.0, c.y + 3.75, c.z - gz + 0.3), smooth_=False, tone=shade(LEG, 0.52))

    mark("gearcase and skeg")
    # Three blades, each a twisted plate seen from both sides.
    py = PROP[1]
    for k in range(3):
        th = 2 * math.pi * k / 3 + 0.5
        rad = Vector((math.cos(th), 0.0, math.sin(th)))
        tan = Vector((-math.sin(th), 0.0, math.cos(th)))
        yv = Vector((0.0, 1.0, 0.0))
        c0 = Vector((0.0, py, gz))
        blade = [(0.085, -0.07, 0.045), (0.085, 0.07, -0.045), (0.27, 0.15, -0.055), (0.37, 0.03, -0.01), (0.30, -0.12, 0.05)]
        pts = [tuple(c0 + rad * r + tan * t + yv * f) for r, t, f in blade]
        nrm = (Vector(pts[1]) - Vector(pts[0])).cross(Vector(pts[2]) - Vector(pts[0])).normalized()
        for sign in (1, -1):               # the two faces stand a hair apart
            ab = [(0.5 + sign * t / 0.36, (r - 0.06) / 0.33) for r, t, f in blade]
            face = [tuple(Vector(q) + nrm * (0.003 * sign)) for q in pts]
            for tri in ((0, 1, 2), (0, 2, 3), (0, 3, 4)):      # the same three triangles on both faces of the twisted plate
                m.poly([face[q] for q in tri], "prop", [ab[q] for q in tri], tuple(nrm * sign), smooth_=True,
                       tone=ALU if sign > 0 else PROP_BLACK)

    mark("blades")
    ob = m.finish(MOTOR_PLAIN if plain else MOTOR)
    return ob, m.mirrored


# --------------------------------------------------------------------------- previews

def to_file(p):
    """Design axes (bow +Y) to file axes (bow -Y)."""
    return (-p[0], -p[1], p[2])


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [o for o in bpy.data.objects if o not in before and o.type == "MESH"]


def previews(boat, motor, plain, motor_plain, opt):
    scene = bpy.context.scene
    out = SCRATCH / (f"renders-{opt['tag']}" if opt["tag"] else "renders")
    out.mkdir(parents=True, exist_ok=True)
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    keep = opt["tag"] is None
    want = opt["views"] or ["hero", "outboard", "plain", "golden", "before", "match", "threequarter", "ingame", "inside", "low", "bow"]
    common.PREVIEW_SAMPLES = opt["samples"]
    pivot = to_file(PIVOT)
    for o in (motor, motor_plain):
        o.matrix_world = Matrix.Translation(pivot)

    def render(key, res):
        scene.render.resolution_x, scene.render.resolution_y = res
        name = {"hero": NAME, "outboard": MOTOR, "plain": PLAIN}.get(key, f"{NAME}-{key}")
        scene.render.filepath = str(out / f"{name}.png")
        bpy.ops.render.render(write_still=True)
        if keep and key != "before":
            shrink(out / f"{name}.png", PREVIEWS / f"{name}.png")

    def show(obs):
        for o in (boat, motor, plain, motor_plain):
            o.hide_render = o not in obs

    # Studio-style views: the same camera and light as the other previews.
    for key, obs, view in (("hero", [boat, motor], (148, 30)), ("outboard", [motor], (140, 16)), ("plain", [plain, motor_plain], (148, 30))):
        if key not in want:
            continue
        show(obs)
        lo, hi = bounds(obs)
        ground, sun, cam = common._setup_render(lo, hi, view)
        render(key, (1024, 1024))
        for o in (ground, sun, cam):
            bpy.data.objects.remove(o, do_unlink=True)
    show([boat, motor])

    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = opt["samples"]
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "Standard"

    # The Cedar Canoe lies alongside for scale, and the old dinghy stands in for "before".
    canoe, old = [], []
    canoe_x = 4.6
    if (MODELS / "CedarCanoe.glb").exists():
        canoe = import_glb(MODELS / "CedarCanoe.glb")
        for o in canoe:
            o.matrix_world = Matrix.Translation((canoe_x, -1.2, 0.0)) @ o.matrix_world
    if "before" in want and (MODELS / "Dinghy.glb").exists():
        old = import_glb(MODELS / "Dinghy.glb")
        for o in old:      # its origin is the foot of its motor; its tubes sit 0.425 above that. Bow to -Y like the new one.
            o.matrix_world = Matrix.Translation((0, 0, -0.575)) @ Matrix.Rotation(math.pi, 4, "Z") @ o.matrix_world
            o.hide_render = True

    def hide(obs, flag):
        for o in obs:
            o.hide_render = flag

    # File axes: the bow is at -Y, starboard at -X, the outboard at +Y.
    shots = {
        # From off the starboard quarter at golden hour, the canoe beyond.
        "golden": (True, (-8.4, 9.6, 4.9), (0.9, -0.3, 0.2), 36, (1376, 768), True),
        "before": (True, (-8.4, 9.6, 4.9), (0.9, -0.3, 0.2), 36, (1376, 768), True),
        # Set C looks down on the boats from a high three-quarter view.
        "threequarter": (True, (-7.6, 9.2, 11.5), (1.4, -0.6, 0.0), 40, (1280, 800), True),
        # From another boat alongside: the tubes, the strake and the grab line.
        "low": (True, (-9.5, 3.2, 1.5), (0.0, 0.3, 0.45), 30, (1376, 640), False),
        "bow": (True, (-6.0, -8.6, 3.0), (0.0, -0.4, 0.3), 30, (1376, 768), False),
        # The reference picture's framing: from astern, the outboard nearest, the light from the left.
        "match": ("left", (-4.6, 8.8, 5.6), (0.0, -0.2, 0.3), 36, (1100, 760), False),
        # A player on the dock, eyes 7 studs over the water, the boat 22 studs off.
        "ingame": (False, (-15.0, 16.0, 7.0), (0.0, 0.0, 0.5), 70, (1280, 720), True),
        # The driver's camera: looking down into the boat from over the outboard.
        "inside": (False, (-1.2, 7.4, 5.4), (0.0, -0.6, 0.2), 46, (1280, 800), False),
    }
    for golden in (True, "left", False):
        keys = [k for k, v in shots.items() if v[0] == golden and k in want]
        if not keys:
            continue
        made = stage(bool(golden), (0.90, -0.20, 0.32) if golden == "left" else ((0.44, 0.84, 0.32) if golden else (-0.45, 0.35, 0.82)))
        for key in keys:
            _, pos, look, fov, res, with_canoe = shots[key]
            hide(canoe, not with_canoe)
            hide([boat, motor], key == "before")
            hide(old, key != "before")
            cam = camera(pos, look, fov)
            render(key, res)
            bpy.data.objects.remove(cam, do_unlink=True)
        for o in made:
            bpy.data.objects.remove(o, do_unlink=True)
    hide([boat, motor], False)


def sheets(paths, mpaths):
    col, nor, rou = (load_rgb(paths[k]) for k in ("color", "normal", "rough"))
    half = lambda a: resize(a, 512, 512)
    sheet = np.concatenate([half(col), half(nor), half(rou)], 1)
    mc, mn, mr = (half(load_rgb(mpaths[k])) for k in ("color", "normal", "rough"))
    write_png(SCRATCH / f"{NAME}-atlas.png", np.concatenate([sheet, np.concatenate([mc, mn, mr], 1)], 0))
    shrink(SCRATCH / f"{NAME}-atlas.png", PREVIEWS / f"{NAME}-atlas.png")


def compare():
    """Side by side sheets, when their halves exist: the old dinghy beside the new one, the
    first pass (--tag first) beside the final one, and the reference picture's dinghy beside ours."""
    def pair(left, right, name, height=560):
        if not (left.exists() and right.exists()):
            return
        a, b = load_rgb(left), load_rgb(right)
        a = resize(a, height, int(a.shape[1] * height / a.shape[0]))
        b = resize(b, height, int(b.shape[1] * height / b.shape[0]))
        gap = np.ones((height, 10, 3), np.float32)
        write_png(SCRATCH / name, np.concatenate([a, gap, b], 1))
        shrink(SCRATCH / name, PREVIEWS / name)

    r = SCRATCH / "renders"
    pair(r / f"{NAME}-before.png", r / f"{NAME}-golden.png", f"{NAME}-before-after.png")
    pair(SCRATCH / "renders-first" / f"{NAME}-golden.png", r / f"{NAME}-golden.png", f"{NAME}-first-final.png")
    ref = REPO / "docs" / "looks" / "leg3-references" / "n4-cedar-canoe-and-boathouse-golden.jpg"
    if ref.exists() and (r / f"{NAME}-match.png").exists():
        write_png(SCRATCH / "reference-crop.png", load_rgb(ref)[300:600, 800:1240])       # the dinghy in the reference picture
        pair(SCRATCH / "reference-crop.png", r / f"{NAME}-match.png", f"{NAME}-vs-reference.png")


# --------------------------------------------------------------------------- main

def main():
    opt = parse_args()
    reset()
    lines = Lines()
    print(f"[dinghy] tube path: half length {lines.S:.3f} studs, tightest turn {lines.min_radius:.2f} (tube radius {R})")
    at, paths, colour = compose(lines)
    mat_, mpaths = compose_motor()
    sheets(paths, mpaths)
    if opt["maps_only"]:
        return

    boat, info = build_boat(at, lines)
    plain, pinfo = build_boat(None, lines, plain=True)
    motor, mm = build_motor(mat_)
    motor_plain, _ = build_motor(None, plain=True)
    for ob in (boat, plain, motor, motor_plain):
        cc.half_turn(ob)
    boat.data.materials.append(cc.material(NAME, paths))
    motor.data.materials.append(cc.material(MOTOR, mpaths))
    plain.data.materials.append(cc.vertex_material(PLAIN))
    motor_plain.data.materials.append(cc.vertex_material(MOTOR_PLAIN))
    print(f"[dinghy] mirrored faces: boat {info['mirrored']}, outboard {mm} (both should be 0)")

    lo, hi = bounds([boat])
    mid = (lo + hi) / 2
    seat = lambda p: rbx(to_file(p))
    geometry = {
        "length": round(hi.y - lo.y, 3), "beam": round(hi.x - lo.x, 3), "height": round(hi.z - lo.z, 3),
        "pivot": "the file's origin: the middle of the 8 x 4 hull on the waterline",
        "draft": DRAFT, "tube_bottom": info["tube_bottom"], "waterline_above_lowest_point": round(-lo.z, 3),
        "pivot_from_box_centre_roblox": rbx((-mid.x, -mid.y, -mid.z)),
        "bow": "Roblox -Z (Blender -Y)",
        "floor_lowest": info["floor_z"], "inside_width_at_floor": round(2 * info["inside_half_width"], 3),
        "tube_radius": R, "tube_top": info["tube_top"], "bow_top": info["bow_top"], "transom_top": TR_TOP,
        "driver_seat_top_roblox": seat((0.0, Y_BENCH, BENCH_TOP)),
        "bench_roblox": {"centre_top": seat((0.0, Y_BENCH, BENCH_TOP)), "clear_width": round(2 * (XC - math.sqrt(R * R - (BENCH_TOP - ZC) ** 2)), 2), "fore_and_aft": 2 * BENCH_HALF, "thickness": BENCH_T},
        "passenger_seat_roblox": seat((0.0, Y_PASS, info["floor_at_passenger"])),
        "oarlocks_roblox": [seat((s * XC, Y_OAR, ZC + R + 0.33)) for s in (1, -1)],
        "outboard_pivot_roblox": seat(PIVOT),
        "prop_roblox": seat(PROP),
        "tiller_grip_end_roblox": seat(TILLER[1]),
        "transom_outer_face_z_roblox": round(-(Y_TR - TR_T / 2), 3),
    }
    notes = ("Hero set (leg 3, N4): one mesh, one UV set, colour, normal (OpenGL) and roughness maps at 1024 embedded in the GLB; "
             "Roblox makes the SurfaceAppearance on import. Upload art/models/roblox/DinghyHero.glb as it is (no roblox_colors.py step). "
             "The loose maps are in art/textures/dinghy/. The file's origin is the middle of the hull on the waterline, not the bottom "
             "centre: if the importer puts the pivot on the middle of the box, see geometry.pivot_from_box_centre_roblox. Bow toward "
             "Roblox -Z, starboard +X. Orange hypalon tubes (204,108,48) with seams, strake, grab line, holders, D-rings and valves in "
             "the maps; a slatted ply floor, one ply bench, a ply transom carrying the outboard's clamp, two oarlocks. The outboard is "
             "DinghyOutboard, a mesh of its own, placed at geometry.outboard_pivot_roblox.")
    extra = {"textures": {"size": 1024, "maps": ["color", "normal", "roughness"], **colour}, "geometry": geometry}
    glb = cc.export(boat, False)
    e1 = cc.record(boat, glb, "Dinghy (the vertex-colour dinghy from boats.py that BoatService shows now): same 8 x 4 hull, new pivot on the waterline",
                   notes, extra)

    mlo, mhi = bounds([motor])
    mmid = (mlo + mhi) / 2
    rel = lambda p: rbx(to_file((p[0] - PIVOT[0], p[1] - PIVOT[1], p[2] - PIVOT[2])))
    mgeo = {
        "pivot": "the file's origin: the top of the swivel column, where the motor steers (about Roblox Y) and tilts (about Roblox X)",
        "place_at_roblox_from_boat_pivot": seat(PIVOT),
        "prop_roblox_from_outboard_pivot": rel(PROP), "prop_roblox_from_boat_pivot": seat(PROP), "prop_radius": 0.37,
        "skeg_foot_below_waterline": round(-(PROP[2] - 0.50), 3),
        "cowl_top_above_waterline": round(mhi.z + PIVOT[2], 3),
        "tiller_grip_end_roblox_from_outboard_pivot": rel(TILLER[1]),
        "pivot_from_box_centre_roblox": rbx((-mmid.x, -mmid.y, -mmid.z)),
        "front": "Roblox -Z (the tiller points at the bow)",
    }
    glb = cc.export(motor, False)
    e2 = cc.record(motor, glb, "The block-and-stick motor that was part of the old Dinghy mesh",
                   "Hero set: one mesh, colour, normal (OpenGL) and roughness maps at 512 embedded. Upload art/models/roblox/DinghyOutboard.glb as it is. "
                   "A small tiller outboard of our own design, no maker: dark grey cowl with a cream and an orange pinstripe, a darker pan, a grey "
                   "alloy leg, gearcase, skeg and a three-blade propeller, a tiller with a rubber twist grip. Its origin is the pivot; the clamp "
                   "that holds it is part of DinghyHero, so the motor can turn and tilt in it.",
                   {"textures": {"size": 512, "maps": ["color", "normal", "roughness"]}, "geometry": mgeo})

    plo, phi_ = bounds([plain])
    pmid = (plo + phi_) / 2
    glb = cc.export(plain, True)
    e3 = cc.record(plain, glb, "DinghyHero on the phone tier (the lighter twin: same lines, pivot, seats and size)",
                   "Vertex colours only, no maps: the plain twin of DinghyHero, as Dock is to DockHero. Flat colour per face: orange tubes, a "
                   "charcoal strake and cone caps, a dark fabric floor with nine real slats, ply bench and transom. Upload "
                   "art/models/roblox/DinghyPlain.glb (colours already converted for Roblox). Same origin (hull centre on the waterline), bow toward Roblox -Z.",
                   {"lite_of": NAME, "geometry": {"pivot_from_box_centre_roblox": rbx((-pmid.x, -pmid.y, -pmid.z)),
                                                  "length": round(phi_.y - plo.y, 3), "beam": round(phi_.x - plo.x, 3)}})
    glb = cc.export(motor_plain, True)
    e4 = cc.record(motor_plain, glb, "DinghyOutboard on the phone tier", "Vertex colours only: the plain twin of DinghyOutboard, same mesh and origin. "
                   "Upload art/models/roblox/DinghyOutboardPlain.glb.", {"lite_of": MOTOR, "geometry": mgeo})

    for e in (e1, e2, e3, e4):
        print(f"[dinghy] {e['name']}: {e['studs']} studs (X, up, Z), {e['triangles']} triangles, GLB {e['glb_bytes'] / 1e6:.2f} MB")
    print(f"[dinghy] geometry {json.dumps(geometry)}")
    print(f"[dinghy] outboard {json.dumps(mgeo)}")
    (MAPS / "dinghy.json").write_text(json.dumps({
        "what": "Hero maps baked for the Inflatable Dinghy and its outboard by art/scripts/dinghy_hero.py (the same maps are embedded in the GLBs)",
        "sources": "The hypalon, rubber, rope and metal are drawn by the script. The plywood grain is ambientCG Planks 021 (CC0), https://ambientcg.com/a/Planks021",
        NAME: {"size": [1024, 1024], **colour, "rectangles": {k: list(v) for k, v in at.rects.items()}},
        MOTOR: {"size": [512, 512], "rectangles": {k: list(v) for k, v in mat_.rects.items()}},
    }, indent=2) + "\n")
    if not opt["no_render"]:
        previews(boat, motor, plain, motor_plain, opt)
        if opt["tag"] is None:
            compare()


if __name__ == "__main__":
    main()
