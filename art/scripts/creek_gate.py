"""The Cedar Creek gate set (leg 3, N3, Neon's review of 11/28/2026, Part B rank 1): the gate arch
and two split-rail fence sections. Layer B of the look kit: every mesh keeps its vertex colours
for hue and wears one of our MaterialVariants, so nothing here carries a texture of its own.

    CreekGateArch_bark          the two cedar log posts                                CedarBark
    CreekGateArch_wood          crossbeam, knee braces, rafter tails, shingle cap,     WeatheredPlank
                                the live-edge sign slab
    CreekGateArch_stone         the stone footings, and the two iron sign hangers      ShoreStone
    CreekFenceSection1_wood     two posts and six split rails, 10 studs of fence       WeatheredPlank
    CreekFenceSection2_wood     the same, split differently                            WeatheredPlank

Front is Blender -Y, which is Roblox -Z (the stands and the boathouse are built the same way:
Roblox (x, y, z) is Blender (-x, z, y)). The models are built with the ground at height 0 and
reach BURY below it, so the pivot (the base centre of the box) goes at ground height minus BURY.
Every mesh of the arch shares the arch's pivot and, through two specks at opposite corners, its
whole box, so each one drops in at the same CFrame.

The arch is fitted to the real gate in WorldBuilder and Scenery: the gate leaf is 8 wide, 8 tall
and 1 thick on the fence line, and the unseen fence walls start 4 studs either side of the
centre. So the posts leave 8.4 clear, the knee braces clear the leaf's top corners, and the sign
hangs 1 stud in FRONT of the leaf's plane, between the posts.

Rules this rests on (stands_split.py and boathouse.py, proven in Studio 11/27/2026):
  * a variant's NEUTRAL colour map multiplies the vertex colour and has a mean of 0.80, so the
    colours are stored 1.25 times lighter than the colour wanted;
  * a variant's maps follow the mesh UVs, one tile every StudsPerTile UV units; here 1 UV unit
    is 1 stud, V along the grain.

    python art/scripts/creek_gate.py                 build, export, render, sheets
    python art/scripts/creek_gate.py --no-render     models and manifest only
    python art/scripts/creek_gate.py --tag before    renders go to artifacts/creek_gate/before/
    python art/scripts/creek_gate.py --views shot11,close
    python art/scripts/creek_gate.py --compose-only  rebuild the sheets from the renders made
    blender -b -P art/scripts/creek_gate.py -- --no-render     (the Blender half on its own)

Writes art/models/<Mesh>.glb (linear colours), art/models/roblox/<Mesh>.glb (display colours,
the copy to upload), the previews in art/previews/ and its own entries in
art/models/manifest.json. Scratch goes to artifacts/creek_gate/ (git-ignored).
"""

from __future__ import annotations

import argparse
import json
import math
import os
import random
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ART = HERE.parent
REPO = ART.parent
MODELS = ART / "models"
ROBLOX = MODELS / "roblox"
PREVIEWS = ART / "previews"
TEXTURES = ART / "textures"
SCRATCH = REPO / "artifacts" / "creek_gate"
MANIFEST = MODELS / "manifest.json"
CURRENT_SHOT = PREVIEWS / "CreekGateArch-current-gate.jpg"  # shot 11 of 11/28/2026, the gate this replaces
BLENDER = os.environ.get("BLENDER", r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe")

try:
    import bpy  # noqa: F401

    IN_BLENDER = True
except ModuleNotFoundError:
    IN_BLENDER = False

FAMILIES = {
    "bark": {"slug": "cedar_bark", "variant": "CedarBark", "lift": 1.25, "boards": None},
    "wood": {"slug": "weathered_plank", "variant": "WeatheredPlank", "lift": 1.25, "boards": 5},
    "stone": {"slug": "shore_stone", "variant": "ShoreStone", "lift": 1.25, "boards": None},
}
ARCH, FENCE1, FENCE2 = "CreekGateArch", "CreekFenceSection1", "CreekFenceSection2"
MESHES = {ARCH: ("bark", "wood", "stone"), FENCE1: ("wood",), FENCE2: ("wood",)}
BUDGET = {ARCH: 1150, FENCE1: 230, FENCE2: 230}
ANCHOR = 0.02  # side of the corner specks, studs

# ---------------------------------------------------------------------------------------
# Palette: the colours we want to SEE in the game (sRGB 0..255), before the lift.
# Cedar Creek, Real-ish: cedar bark 110,70,50; moss 78,104,52; dock timber 122,104,86.
# ---------------------------------------------------------------------------------------
PAL = {
    "bark": (112, 76, 56),            # cedar log posts, bark on
    "bark_top": (124, 96, 78),        # sun-greyed toward the top
    "bark_foot": (82, 74, 52),        # damp and a little green at the ground
    "bark_cap": (96, 70, 54),
    "beam": (106, 90, 74),            # the hewn crossbeam: old, dark timber
    "beam_end": (156, 134, 104),      # its axe-cut end grain
    "brace": (128, 110, 90),
    "rafter": (110, 94, 78),
    "rafter_end": (146, 126, 100),
    "deck": (92, 80, 66),             # the roof boards, seen from underneath
    "shake": (146, 136, 120),         # silvered cedar shakes
    "shake_brown": (132, 112, 90),    # a newer, browner one
    "shake_moss": (120, 124, 96),     # one that has gone green
    "ridge": (126, 114, 100),
    "sign": (88, 64, 46),             # the slab's stained face: Signs.PAINT.creek is 86,62,42
    "sign_edge": (158, 132, 98),      # its live edge, pale sapwood
    "stone": (118, 112, 102),
    "stone_light": (136, 130, 118),
    "stone_brown": (124, 110, 94),
    "stone_grey": (108, 108, 104),
    "stone_wet": (76, 73, 64),
    "moss": (84, 106, 58),
    "iron": (46, 44, 44),
    "rail": (134, 122, 106),          # split cedar rails, silver grey
    "rail_brown": (124, 106, 86),
    "rail_end": (150, 136, 114),
    "fpost": (112, 98, 84),           # the fence posts, a little darker than the rails
    "fpost_top": (132, 120, 104),
    "fpost_foot": (80, 72, 58),
    "speck": (92, 80, 68),
}

# ---------------------------------------------------------------------------------------
# Measurements, in studs above the GROUND (the pivot is BURY lower).
# Blender: x along the fence line, y depth with the front (the lake side) at -y, z up.
# ---------------------------------------------------------------------------------------
BURY = 0.4
LEAF_W, LEAF_H, LEAF_T = 8.0, 8.0, 1.0   # WorldBuilder's CreekGate part, which must still fit
POST_X = 5.3                              # the posts' centres
POST_RINGS = ((-BURY, 1.06), (1.0, 0.97), (4.0, 0.87), (7.6, 0.79), (10.1, 0.72))  # height, radius
ZB = 9.8                                  # the crossbeam's underside
BEAM_H, BEAM_HD, BEAM_HL = 1.25, 0.8, 7.0  # its height, half depth and half length
ZT = ZB + BEAM_H + 0.06                   # its top at the middle (it is crowned a little)
BRACE_RUN, BRACE_DROP = 1.35, 1.85        # a knee brace: along the beam, down the post
BRACE_HT, BRACE_HD = 0.31, 0.28           # its half thickness (in the arch's plane) and half depth
S = 0.70                                  # roof slope, rise over run: 35 degrees
ZR_U = ZT + 0.02 + S * (BEAM_HD - 0.25)   # the roof boards' underside at the ridge (they sit on the beam's hewn shoulders)
DECK_T = 0.115                            # the roof boards' thickness, measured plumb
DECK_Q = 1.40                             # their eave, out from the ridge
DECK_X = 6.2                              # the beam's log ends run on past the roof
TAIL_X = (-5.4, -2.7, 0.0, 2.7, 5.4)      # the rafter tails
TAIL_Q, TAIL_D = (0.5, 1.32), (0.38, 0.22)  # a tail: from and to (out from the ridge), depth at each end
SIGN_Y, SIGN_HT = -1.02, 0.16             # the sign slab's plane and its half thickness
HANGER_X = 2.7                            # the two iron hangers hang from the rafter tails here
FENCE_BAY = 5.0                           # post to post
FENCE_TOP = 3.6
RAIL_H = (0.95, 1.95, 2.95)

# The slab's outline in its plane, (x, height), counter-clockwise seen from the front.
SIGN_OUTLINE = ((-3.95, 6.90), (-1.3, 6.82), (1.6, 6.93), (4.0, 6.86), (4.26, 7.24), (4.10, 7.92),
                (3.60, 8.58), (1.5, 8.71), (-0.9, 8.61), (-3.62, 8.65), (-4.08, 7.95), (-4.24, 7.30))
SIGN_INSET = 0.15                         # how far the flat face stops short of the live edge


def post_r(z):
    for (z0, r0), (z1, r1) in zip(POST_RINGS, POST_RINGS[1:]):
        if z <= z1:
            t = (z - z0) / (z1 - z0)
            return r0 + (r1 - r0) * max(0.0, t)
    return POST_RINGS[-1][1]


def parse_args(argv):
    ap = argparse.ArgumentParser(description="Build the Cedar Creek gate arch and fence sections (Layer B).")
    ap.add_argument("--no-render", action="store_true", help="build and export only")
    ap.add_argument("--compose-only", action="store_true", help="rebuild the sheets from the renders already made")
    ap.add_argument("--views", default="", help="only these renders (hero, shot11, close, back, fence, fit, pieces, under; cull is scratch only)")
    ap.add_argument("--tag", default="final", help="scratch subfolder for the renders; only 'final' reaches art/previews")
    ap.add_argument("--samples", type=int, default=int(os.environ.get("ART_SAMPLES", "64")))
    ap.add_argument("--no-anchors", action="store_true", help="leave out the two bounding-box specks per mesh")
    return ap.parse_args(argv)


def family_tiles():
    table = json.loads((HERE / "texture_families.json").read_text(encoding="utf-8"))["families"]
    return {fam: float(table[f["slug"]]["studs_per_tile"]) for fam, f in FAMILIES.items()}


# =======================================================================================
# Blender half
# =======================================================================================

def blender_main(argv):
    import bpy
    from mathutils import Matrix, Vector

    sys.path.insert(0, str(HERE))
    import common
    from common import srgb_to_linear
    import roblox_colors

    args = parse_args(argv)
    tiles = family_tiles()
    views = [v for v in args.views.split(",") if v]
    out_dir = SCRATCH / args.tag
    scene_of = lambda: bpy.context.scene  # noqa: E731
    X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))

    def mix(a, b, t):
        t = min(1.0, max(0.0, t))
        return tuple(p + (q - p) * t for p, q in zip(a, b))

    def shade(c, f):
        return tuple(v * f for v in c)

    def newell(pts):
        n = Vector((0, 0, 0))
        for i in range(1, len(pts) - 1):
            n += (pts[i] - pts[0]).cross(pts[i + 1] - pts[0])
        return n

    # ------------------------------------------------------------------ geometry
    class Geo:
        """Faces with a UV and a colour (the colour we want to SEE) on every corner."""

        def __init__(self):
            self.verts, self.faces, self.uvs, self.cols, self.smooth = [], [], [], [], []

        def v(self, p):
            self.verts.append((p[0], p[1], p[2]))
            return len(self.verts) - 1

        def f(self, idx, uvs, cols, smooth=False):
            self.faces.append(tuple(idx))
            self.uvs.append([tuple(t) for t in uvs])
            self.cols.append([tuple(c) for c in cols])
            self.smooth.append(smooth)

        def face(self, idx, uvs, cols, inside, smooth=False):
            """A face on shared vertices, turned to face away from `inside`."""
            pts = [Vector(self.verts[i]) for i in idx]
            n = newell(pts)
            if n.length < 1e-10:
                return
            if n.dot(sum(pts, Vector()) / len(pts) - Vector(inside)) < 0:
                idx, uvs, cols = list(reversed(idx)), list(reversed(uvs)), list(reversed(cols))
            self.f(idx, uvs, cols, smooth)

        def triangles(self):
            return sum(len(f) - 2 for f in self.faces)

        def volume(self, f0=0):
            """Six times the signed volume of the faces from f0 on: positive when they point out."""
            vol = 0.0
            for face in self.faces[f0:]:
                p0 = Vector(self.verts[face[0]])
                for i in range(1, len(face) - 1):
                    vol += p0.dot(Vector(self.verts[face[i]]).cross(Vector(self.verts[face[i + 1]])))
            return vol

    def closed(G, f0, what):
        if G.volume(f0) <= 0:
            raise SystemExit(f"creek_gate: {what} is inside out")

    def board_offset(fam, u0, u1, rng):
        """Where a flat side sits across the map: a narrow side inside one board, a wide one
        starting on a groove."""
        f, tile = FAMILIES[fam], tiles[fam]
        if not f["boards"]:
            return rng.uniform(0, tile) - u0
        period = tile / f["boards"]
        k = rng.randrange(f["boards"])
        if u1 - u0 <= period * 0.9:
            return (k + 0.5) * period - (u0 + u1) / 2
        return k * period - u0

    def planar(pts, n, grain, fam, rng):
        """A flat side laid out at world scale, V along the grain, never mirrored."""
        n = n.normalized()
        ref = grain
        if abs(n.dot(grain)) > 0.92:
            ref = min((X, Y, Z), key=lambda ax: abs(ax.dot(n)))
        along = (ref - ref.dot(n) * n).normalized()
        across = along.cross(n)
        us, vs = [p.dot(across) for p in pts], [p.dot(along) for p in pts]
        uo, vo = board_offset(fam, min(us), max(us), rng), rng.uniform(0, tiles[fam])
        return [(u + uo, v + vo) for u, v in zip(us, vs)]

    def poly(G, fam, pts, col, grain, rng, inside=None):
        """One flat face on its own vertices. `col` is fn(point, normal)."""
        pts = [Vector(p) for p in pts]
        n = newell(pts)
        if n.length < 1e-10:
            return
        if inside is not None and n.dot(sum(pts, Vector()) / len(pts) - Vector(inside)) < 0:
            pts.reverse()
            n = -n
        n.normalize()
        G.f([G.v(p) for p in pts], planar(pts, n, grain, fam, rng), [col(p, n) for p in pts])

    HEXA = ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7))

    def hexa(G, fam, c, col, grain, rng, skip=()):
        """A six-sided solid from 8 corners: the bottom ring 0..3 and the top ring 4..7 above it.
        `skip` leaves out faces nobody can see: 0 bottom, 1 top, 2..5 the sides from corner 0."""
        c = [Vector(p) for p in c]
        inside = sum(c, Vector()) / 8
        f0 = len(G.faces)
        for fi, idx in enumerate(HEXA):
            if fi not in skip:
                poly(G, fam, [c[i] for i in idx], col, grain, rng, inside)
        if not skip:
            closed(G, f0, "a hexa")

    def octagon(hw, hh, ch):
        """A timber's section, counter-clockwise: half width, half height, four chamfers."""
        c0, c1, c2, c3 = ch
        return [(-hw + c0, -hh), (hw - c1, -hh), (hw, -hh + c1), (hw, hh - c2),
                (hw - c2, hh), (-hw + c3, hh), (-hw, hh - c3), (-hw, -hh + c0)]

    def sweep(G, fam, path, section, col, rng, up=Z, scales=None, mod=None, cap0=None, cap1=None, strip_jit=0.04):
        """A timber: `section` (counter-clockwise (a, b) pairs, b toward `up`) carried along
        `path`. U runs round the section, V along the path. mod(i, k, a, b) returns (a, b, t)
        with t a shift along the path. cap0, cap1: fn(point, normal) colours for the ends."""
        path = [Vector(p) for p in path]
        n, m = len(path), len(section)
        rings = []
        for i, p in enumerate(path):
            T = (path[min(i + 1, n - 1)] - path[max(i - 1, 0)]).normalized()
            A = up.cross(T).normalized()
            B = T.cross(A)
            s = scales[i] if scales else 1.0
            sa, sb = s if isinstance(s, tuple) else (s, s)
            ring = []
            for k, (a, b) in enumerate(section):
                a, b, t = a * sa, b * sb, 0.0
                if mod:
                    a, b, t = mod(i, k, a, b)
                ring.append(p + A * a + B * b + T * t)
            rings.append(ring)
        widths = [math.hypot(section[(k + 1) % m][0] - section[k][0], section[(k + 1) % m][1] - section[k][1]) for k in range(m)]
        boards = FAMILIES[fam]["boards"]
        period = tiles[fam] / boards if boards else None
        u0s, cursor = [], 0.0
        for w in widths:  # a side no wider than a board never has a groove down it: it starts on the groove instead
            if period and w <= period:
                g = math.ceil((cursor + 0.04) / period) * period
                if g < cursor + w - 0.04:
                    cursor = g + 0.03
            u0s.append(cursor)
            cursor += w
        uo = board_offset(fam, 0.0, cursor, rng) if (period is None or cursor <= period * 0.9) else rng.randrange(boards) * period
        arc = [rng.uniform(0, tiles[fam])]
        for i in range(1, n):
            arc.append(arc[-1] + (path[i] - path[i - 1]).length)
        jit = [1 + rng.uniform(-strip_jit, strip_jit) for _ in range(m)]
        idx = [[G.v(q) for q in ring] for ring in rings]
        f0 = len(G.faces)
        for i in range(n - 1):
            mid_axis = (path[i] + path[i + 1]) / 2
            for k in range(m):
                k2 = (k + 1) % m
                quad = [(i, k), (i, k2), (i + 1, k2), (i + 1, k)]
                pts = [rings[a][c] for a, c in quad]
                nrm = newell(pts)
                if nrm.length < 1e-10:
                    continue
                nrm.normalize()
                if nrm.dot(sum(pts, Vector()) / 4 - mid_axis) < 0:
                    nrm = -nrm
                ua, ub = u0s[k] + uo, u0s[k] + widths[k] + uo
                uv = [(ua, arc[i]), (ub, arc[i]), (ub, arc[i + 1]), (ua, arc[i + 1])]
                G.face([idx[a][c] for a, c in quad], uv, [shade(col(p, nrm), jit[k]) for p in pts], mid_axis)
        for cap, ring, away in ((cap0, rings[0], path[1]), (cap1, rings[-1], path[-2])):
            if cap:
                poly(G, fam, ring, cap, (path[-1] - path[0]).normalized(), rng, away)
        if cap0 and cap1:
            closed(G, f0, "a timber")

    def log(G, fam, path, radii, sides, col, rng, ring_fn=None, cap1=None, strip_jit=0.05):
        """A round log, smooth, its UV mirrored round it so there is no seam."""
        assert sides % 2 == 0
        path = [Vector(p) for p in path]
        n = len(path)
        C = 2 * math.pi * max(radii)
        arc = [rng.uniform(0, tiles[fam])]
        for i in range(1, n):
            arc.append(arc[-1] + (path[i] - path[i - 1]).length)
        rings, idx = [], []
        for i, (p, r) in enumerate(zip(path, radii)):
            ring = []
            for k in range(sides):
                a = 2 * math.pi * k / sides
                rr = r * (ring_fn(i, k, a) if ring_fn else 1.0)
                ring.append(p + Vector((math.cos(a) * rr, math.sin(a) * rr, 0)))
            rings.append(ring)
            idx.append([G.v(q) for q in ring])
        u = lambda k: C / 2 - abs(k / sides * C - C / 2)  # noqa: E731
        jit = [1 + rng.uniform(-strip_jit, strip_jit) for _ in range(sides)]
        for i in range(n - 1):
            mid_axis = (path[i] + path[i + 1]) / 2
            for k in range(sides):
                k2 = (k + 1) % sides
                quad = [(i, k), (i, k2), (i + 1, k2), (i + 1, k)]
                pts = [rings[a][c] for a, c in quad]
                out = (sum(pts, Vector()) / 4 - mid_axis)
                out.z = 0
                out.normalize()
                uv = [(u(k), arc[i]), (u(k + 1), arc[i]), (u(k + 1), arc[i + 1]), (u(k), arc[i + 1])]
                G.face([idx[a][c] for a, c in quad], uv, [shade(col(p, out), jit[k]) for p in pts], mid_axis, smooth=True)
        if cap1:
            poly(G, fam, rings[-1], cap1, Z, rng, path[-2])

    # ------------------------------------------------------------------ colours
    def tone(key, rng=None, jit=0.0, under=0.84, foot=None, foot_key=None, top=None, top_key=None):
        """fn(point, normal): a palette colour, darker underneath, with an optional damp foot
        below `foot` and an optional weathered top above `top` (both blend over a short band)."""
        s = 1 + (rng.uniform(-jit, jit) if rng and jit else 0.0)

        def fn(p, n):
            c = PAL[key]
            if top is not None:
                c = mix(c, PAL[top_key], (p.z - top[0]) / (top[1] - top[0]))
            if foot is not None:
                c = mix(PAL[foot_key], c, (p.z - foot[0]) / (foot[1] - foot[0]))
            c = shade(c, s)
            if n.z < -0.5:
                c = shade(c, under)
            return c

        return fn

    # ------------------------------------------------------------------ the arch
    def z_u(q):
        """The roof boards' underside, q studs out from the ridge."""
        return ZR_U - S * q

    def slope_pt(sg, x, q, lift):
        """A point over the roof on side sg (-1 the front): `lift` plumb above the boards' top."""
        return Vector((x, sg * q, z_u(q) + DECK_T + lift))

    def lower_top(q):
        """How high the lower course of shakes stands above the boards, q out from the ridge."""
        return 0.07 + 0.17 * (q - 0.66) / 0.84

    def footing(St, sx, rng):
        """Six fitted stones round a post's foot, flared, lower toward the fence and tight to
        the post on the gate side so the leaf still swings."""
        cx = sx * POST_X
        limit = POST_X - (LEAF_W / 2 + 0.05)  # no stone reaches further into the opening than this
        heights = {0: 0.8, 60: 1.55, 120: 1.9, 180: 1.3, 240: 1.95, 300: 1.45}
        if sx > 0:
            heights = {0: 0.8, 60: 1.85, 120: 1.5, 180: 1.35, 240: 1.6, 300: 2.0}
        cuts = [30 + 60 * j + rng.uniform(-9, 9) for j in range(6)]  # where one stone ends and the next begins
        kinds = ["stone", "stone_light", "stone_brown", "stone_grey", "stone", "stone_light"]
        rng.shuffle(kinds)
        for j, deg in enumerate((0, 60, 120, 180, 240, 300)):
            a0 = math.radians(cuts[j - 1] - (360 if j == 0 else 0) + 2.5)
            a1 = math.radians(cuts[j] - 2.5)
            h = heights[deg] + rng.uniform(-0.1, 0.1)
            key = kinds[j]

            def at(a, r, z):
                # angle 0 points away from the opening, along the fence
                ex = math.cos(a) * r
                if ex < -limit:  # the gate side: hold the stone back
                    r *= -limit / ex
                return Vector((cx + sx * math.cos(a) * r, math.sin(a) * r, z))

            rb = 1.6 + rng.uniform(-0.06, 0.0)
            flare = rng.uniform(0.46, 0.6)
            r_in = 0.5
            sh = h * rng.uniform(0.62, 0.78)  # the shoulder, where the face turns in
            B0, B1 = at(a0, rb, -BURY), at(a1, rb, -BURY)
            S0, S1 = at(a0, rb - 0.1, sh + rng.uniform(-0.1, 0.1)), at(a1, rb - 0.1, sh + rng.uniform(-0.1, 0.1))
            T0, T1 = at(a0, rb - flare, h - rng.uniform(0.02, 0.2)), at(a1, rb - flare, h - rng.uniform(0.02, 0.2))
            I0, I1 = at(a0, r_in, h + rng.uniform(0.0, 0.08)), at(a1, r_in, h + rng.uniform(0.0, 0.08))
            J0, J1 = at(a0, r_in, -BURY), at(a1, r_in, -BURY)
            inside = (B0 + B1 + I0 + I1) / 4
            f = 1 + rng.uniform(-0.06, 0.06)
            mossy = rng.uniform(0.45, 0.95)

            def col(p, n, key=key, f=f, h=h, mossy=mossy):
                c = mix(PAL["stone_wet"], PAL[key], (p.z + 0.1) / 0.5)   # damp where it meets the ground
                if n.z > 0.5:
                    c = mix(c, PAL["moss"], mossy)                        # moss on the tops
                elif p.z > h * 0.55:
                    c = mix(c, PAL["moss"], mossy * 0.35)                 # and creeping over the shoulder
                return shade(c, f)

            poly(St, "stone", [T0, T1, I1, I0], col, Z, rng, inside)       # top
            poly(St, "stone", [S0, S1, T1, T0], col, Z, rng, inside)       # shoulder
            poly(St, "stone", [B0, B1, S1, S0], col, Z, rng, inside)       # face
            poly(St, "stone", [J0, B0, S0, T0, I0], col, Z, rng, inside)   # the two cheeks
            poly(St, "stone", [J1, B1, S1, T1, I1], col, Z, rng, inside)

    def sign_slab(W, rng):
        """The live-edge slab: a flat stained face front and back, the edge bevelled to a pale
        waney ridge all round. Returns the flat face's outline."""
        outer = [Vector((x, SIGN_Y, z)) for x, z in SIGN_OUTLINE]
        n = len(outer)
        inner2d = []
        for i in range(n):
            p0, p1, p2 = (Vector((q.x, q.z)) for q in (outer[i - 1], outer[i], outer[(i + 1) % n]))
            e0, e1 = (p1 - p0).normalized(), (p2 - p1).normalized()
            n0, n1 = Vector((-e0.y, e0.x)), Vector((-e1.y, e1.x))  # inward, the outline being counter-clockwise
            b = (n0 + n1).normalized()
            inner2d.append(p1 + b * (SIGN_INSET / max(0.5, b.dot(n0))))
        stain = tone("sign", rng, 0.0, under=1.0)
        f0 = len(W.faces)
        centre = Vector((0, SIGN_Y, sum(z for _, z in SIGN_OUTLINE) / n))
        for side in (-1, 1):
            y = SIGN_Y + side * SIGN_HT
            face = [Vector((p.x, y, p.y)) for p in inner2d]
            poly(W, "wood", face, stain, X, rng, centre)
            for i in range(n):
                i2 = (i + 1) % n
                f = 1 + rng.uniform(-0.07, 0.07)

                def col(p, nrm, y=y, f=f):
                    return shade(PAL["sign_edge"] if abs(p.y - y) > 1e-4 else mix(PAL["sign"], PAL["sign_edge"], 0.45), f)

                poly(W, "wood", [face[i], face[i2], outer[i2], outer[i]], col, X, rng, centre)
        closed(W, f0, "the sign slab")
        return inner2d

    def text_rect(inner2d, margin=0.07, ratio=5.6):
        """The biggest upright rectangle of about one line of lettering (ratio wide to 1 tall)
        that fits the flat face, centred on x = 0. Returns (centre height, width, height)."""
        def half(z):
            lo, hi = -1e9, 1e9
            m = len(inner2d)
            for i in range(m):
                a, b = inner2d[i], inner2d[(i + 1) % m]
                if (a.y - z) * (b.y - z) < 0:
                    x = a.x + (b.x - a.x) * (z - a.y) / (b.y - a.y)
                    if x > 0:
                        hi = min(hi, x)
                    else:
                        lo = max(lo, x)
            return min(hi, -lo)

        z0 = max(p.y for p, (_, zo) in zip(inner2d, SIGN_OUTLINE) if zo < 7.0) + margin
        best = None
        for step in range(60, 160):
            h = step / 100
            w = 2 * (min(half(z0 + h * t / 12) for t in range(13)) - margin)
            if w < h * ratio:
                break
            best = (z0 + h / 2, w, h)
        return best

    def build_arch():
        G = {fam: Geo() for fam in MESHES[ARCH]}
        Bk, W, St = G["bark"], G["wood"], G["stone"]
        rng = random.Random(ARCH)

        # Posts: cedar logs, bark on, fluted at the butt, a slight crook, each its own.
        for sx in (-1, 1):
            ph = rng.uniform(0, 2 * math.pi)
            crook = [(0, 0), (0, 0), (sx * rng.uniform(0.02, 0.09), rng.uniform(-0.08, 0.08)),
                     (sx * rng.uniform(-0.02, 0.06), rng.uniform(-0.07, 0.07)), (0, 0)]
            path = [Vector((sx * POST_X + c[0], c[1], z)) for (z, _), c in zip(POST_RINGS, crook)]

            def ring_fn(i, k, a, ph=ph):
                return 1 + (0.085, 0.06, 0.025, 0.012, 0.0)[i] * math.cos(3 * a + ph) + 0.015 * math.sin(5 * a + 2 * ph)

            col = tone("bark", foot=(0.8, 2.8), foot_key="bark_foot", top=(6.5, 10.0), top_key="bark_top")
            log(Bk, "bark", path, [r for _, r in POST_RINGS], 10, col, rng, ring_fn=ring_fn, cap1=tone("bark_cap"))
            footing(St, sx, rng)
            # branch stubs, sawn short: one out over the fence, and on one post a second toward the front
            hexagon = [(0.19 * math.cos(math.radians(v)), 0.19 * math.sin(math.radians(v))) for v in range(0, 360, 60)]
            stubs = [(rng.uniform(5.0, 5.8), math.radians(rng.uniform(-25, 25)), 0.35),
                     (rng.uniform(7.0, 7.6), math.radians(-rng.uniform(70, 100)), 0.5)]
            for z, az, up_tilt in stubs[: 2 if sx < 0 else 1]:
                d = Vector((sx * math.cos(az), math.sin(az), up_tilt)).normalized()
                base = Vector((sx * POST_X, 0, z)) + Vector((d.x, d.y, 0)).normalized() * (post_r(z) - 0.2)
                sweep(Bk, "bark", [base, base + d * rng.uniform(0.55, 0.75)], hexagon, tone("bark", rng, 0.05, under=0.9), rng, up=Z,
                      scales=[1.0, 0.62], cap1=tone("beam_end", rng, 0.05, under=1.0))

        # The crossbeam: hewn, crowned a little, its ends stepped up from below and undercut.
        xs = (-7.0, -6.42, -6.22, -3.2, 0.0, 3.2, 6.22, 6.42, 7.0)
        path = [Vector((x, 0.025 * math.sin(x * 0.45 + 1.0), ZB + BEAM_H / 2 + 0.06 * (1 - (x / BEAM_HL) ** 2))) for x in xs]
        ch = (0.28, 0.18, 0.30, 0.20)
        wob = [[rng.uniform(-0.02, 0.02) for _ in range(8)] for _ in xs]

        def beam_mod(i, k, a, b):
            t = 0.0
            b += wob[i][k]
            end = i in (0, 1, len(xs) - 2, len(xs) - 1)
            if end and b < 0:
                b += 0.42                       # the step: the last half stud is shallower
            if i in (0, len(xs) - 1):
                a *= 0.93
                sgn = -1.0 if i == 0 else 1.0
                t = sgn * (0.05 if b > 0 else -0.16)  # the end is cut back underneath
            return a, b, t

        beam_end = tone("beam_end", rng, 0.05, under=1.0)
        sweep(W, "wood", path, octagon(BEAM_HD, BEAM_H / 2, ch), tone("beam", under=0.8), rng, up=Z, mod=beam_mod,
              cap0=beam_end, cap1=beam_end, strip_jit=0.06)

        # Knee braces: in the arch's plane, clear of the leaf's top corners.
        for sx in (-1, 1):
            face_x = POST_X - post_r(ZB - BRACE_DROP)
            foot = Vector((sx * face_x, 0, ZB - BRACE_DROP))
            head = Vector((sx * (face_x - BRACE_RUN), 0, ZB + 0.03))
            d = (head - foot).normalized()
            sec = octagon(BRACE_HT, BRACE_HD, (0.09, 0.06, 0.10, 0.07))
            sweep(W, "wood", [foot - d * 0.46, head + d * 0.4], sec, tone("brace", rng, 0.04), rng, up=Y,
                  cap0=tone("brace"), cap1=tone("brace"))

        # The roof: a ridge pole on the beam, rafter tails, two boards, two courses of shakes a side.
        pole = [(-0.32, ZT - 0.05), (0.32, ZT - 0.05), (0.32, z_u(0.32)), (0.0, ZR_U), (-0.32, z_u(0.32))]
        sweep(W, "wood", [Vector((-DECK_X + 0.1, 0, 0)), Vector((DECK_X - 0.1, 0, 0))], pole, tone("rafter"), rng, up=Z,
              cap0=tone("rafter_end"), cap1=tone("rafter_end"))
        for sg in (-1, 1):
            for x in TAIL_X:
                w = 0.17 + rng.uniform(-0.015, 0.02)
                (q0, q1), (d0, d1) = TAIL_Q, TAIL_D  # the tail tapers to its end
                q1 += rng.uniform(-0.04, 0.04)
                c = [(x - w, sg * q0, z_u(q0) - d0), (x + w, sg * q0, z_u(q0) - d0), (x + w, sg * q1, z_u(q1) - d1), (x - w, sg * q1, z_u(q1) - d1),
                     (x - w, sg * q0, z_u(q0)), (x + w, sg * q0, z_u(q0)), (x + w, sg * q1, z_u(q1)), (x - w, sg * q1, z_u(q1))]

                def tail_col(p, n, sg=sg, f=1 + rng.uniform(-0.05, 0.05)):
                    return shade(PAL["rafter_end"] if n.y * sg > 0.7 else PAL["rafter"], f * (0.84 if n.z < -0.5 else 1.0))

                hexa(W, "wood", c, tail_col, Vector((0, sg, -S)), rng, skip=(1, 2))  # top is under the boards, one end in the beam
            c = [(-DECK_X, 0, z_u(0)), (DECK_X, 0, z_u(0)), (DECK_X, sg * DECK_Q, z_u(DECK_Q)), (-DECK_X, sg * DECK_Q, z_u(DECK_Q))]
            c += [(x, y, z + DECK_T) for x, y, z in c]
            hexa(W, "wood", c, tone("deck", under=1.0), Vector((0, sg, -S)), rng, skip=(2,))  # the ridge side meets its twin

            def course(n, x_half, q0, q1, lift, thick, skip):
                cuts = sorted(rng.uniform(-x_half, x_half) for _ in range(n - 1))
                for _ in range(200):  # no shake under 1.1 or over 2.3 studs wide
                    edges = [-x_half] + cuts + [x_half]
                    if all(1.1 <= b - a <= 2.3 for a, b in zip(edges, edges[1:])):
                        break
                    cuts = sorted(rng.uniform(-x_half, x_half) for _ in range(n - 1))
                for a, b in zip(edges, edges[1:]):
                    a, b = a + 0.02, b - 0.02
                    qm = q1 + rng.uniform(-0.1, 0.1)
                    qa, qb = qm + rng.uniform(-0.05, 0.05), qm + rng.uniform(-0.05, 0.05)  # a ragged butt line
                    t = 1 + rng.uniform(-0.2, 0.25)
                    lo = [slope_pt(sg, x, q, lift(q)) for x, q in ((a, q0), (b, q0), (b, qb), (a, qa))]
                    hi = [slope_pt(sg, x, q, lift(q) + thick(q) * t) for x, q in ((a, q0), (b, q0), (b, qb), (a, qa))]
                    r = rng.random()
                    key = "shake_moss" if r < 0.12 else "shake_brown" if r < 0.36 else "shake"
                    f = 1 + rng.uniform(-0.09, 0.08)

                    def col(p, nrm, key=key, f=f, sg=sg):
                        return shade(PAL[key], f * (0.74 if nrm.y * sg > 0.5 or nrm.z < -0.5 else 1.0))  # dark butts

                    hexa(W, "wood", lo + hi, col, Vector((0, sg, -S)), rng, skip=skip)

            # lower course: over the eave, its butts 0.05 to 0.2 past the boards
            course(8, DECK_X + 0.16, 0.66, 1.50, lambda q: 0.0, lambda q: lower_top(q), skip=(2,))
            # upper course: from the ridge, riding up over the lower one
            course(7, DECK_X + 0.1, 0.0, 0.96, lambda q: (lower_top(0.96) + 0.012) * q / 0.96, lambda q: 0.08 + 0.14 * q / 0.96, skip=(0, 2))
            # ridge board
            lift = lambda q: 0.09 + 0.22 * q  # noqa: E731
            rx = DECK_X + 0.26
            lo = [slope_pt(sg, x, q, lift(q)) for x, q in ((-rx, 0.0), (rx, 0.0), (rx, 0.42), (-rx, 0.42))]
            hi = [p + Z * 0.1 for p in lo]
            hexa(W, "wood", lo + hi, tone("ridge", rng, 0.05, under=0.8), X, rng, skip=(0, 2))

        # The sign slab, and its two iron hangers from the rafter tails.
        inner2d = sign_slab(W, rng)
        q = -SIGN_Y
        z_top = z_u(q) - (TAIL_D[0] + (TAIL_D[1] - TAIL_D[0]) * (q - TAIL_Q[0]) / (TAIL_Q[1] - TAIL_Q[0]))  # the tail's underside there
        tri = [(0.065 * math.cos(a), 0.065 * math.sin(a)) for a in (math.radians(v) for v in (90, 210, 330))]
        for sx in (-1, 1):
            x = sx * HANGER_X
            z_s = 8.66  # the slab's top edge at the hangers
            m = len(SIGN_OUTLINE)
            for i in range(m):  # read the edge height off the outline
                (xa, za), (xb, zb) = SIGN_OUTLINE[i], SIGN_OUTLINE[(i + 1) % m]
                if za > 8.3 and zb > 8.3 and min(xa, xb) <= x <= max(xa, xb):
                    z_s = za + (zb - za) * (x - xa) / (xb - xa)
            pts = [(x + 0.05, z_top + 0.05), (x - 0.06, z_top - 0.15), (x, z_top - 0.32),
                   (x, z_s + 0.32), (x + 0.06, z_s + 0.15), (x - 0.05, z_s - 0.06)]
            sweep(St, "stone", [Vector((px, SIGN_Y, pz)) for px, pz in pts], tri, tone("iron", under=1.0), rng, up=Y,
                  cap0=tone("iron"), cap1=tone("iron"), strip_jit=0.0)

        info = {"sign_inner": [(round(p.x, 3), round(p.y, 3)) for p in inner2d], "text_rect": text_rect(inner2d),
                # measured off the mesh: the clear width between the posts up to the leaf's top, and between the stones
                "clear_posts": round(2 * min(abs(v[0]) for v in Bk.verts if 0.0 <= v[2] <= LEAF_H + 0.2), 2),
                "clear_stones": round(2 * min(abs(v[0]) for v in St.verts if v[2] < 3.0), 2)}
        return G, info

    # ------------------------------------------------------------------ the fence
    def build_fence(variant):
        name = FENCE1 if variant == 1 else FENCE2
        W = Geo()
        rng = random.Random(name)
        tops = (FENCE_TOP - 0.1, FENCE_TOP - 0.42) if variant == 1 else (FENCE_TOP - 0.34, FENCE_TOP - 0.08)
        for x, top in zip((-FENCE_BAY, 0.0), tops):
            hw, hd = 0.33 + rng.uniform(-0.04, 0.04), 0.29 + rng.uniform(-0.03, 0.03)
            lx, ly = rng.uniform(-0.11, 0.11), rng.uniform(-0.07, 0.07)
            ch = tuple(rng.uniform(0.06, 0.14) for _ in range(4))
            sl = (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3))  # the top is sawn on a slant, not capped

            def top_cut(i, k, a, b, sl=sl):
                return (a, b, sl[0] * a + sl[1] * b) if i == 1 else (a, b, 0.0)

            path = [Vector((x, 0, -BURY)), Vector((x + lx, ly, top))]
            col = tone("fpost", foot=(0.05, 0.8), foot_key="fpost_foot", top=(2.5, 3.4), top_key="fpost_top")
            sweep(W, "wood", path, octagon(hw, hd, ch), col, rng, up=Y, scales=[1.0, 0.88], mod=top_cut,
                  cap1=tone("rail_end", rng, 0.06, under=1.0), strip_jit=0.07)
        base = [(-0.20, -0.15), (0.21, -0.17), (0.13, 0.17), (-0.10, 0.19)]  # a split rail is a wedge
        slipped = (1, 2) if variant == 1 else (0, 1)  # one rail a section has dropped in its mortise
        for bay, (xl, xr) in enumerate(((-FENCE_BAY, 0.0), (0.0, FENCE_BAY))):
            for j, h in enumerate(RAIL_H):
                size = rng.uniform(0.84, 1.2)
                turn = rng.uniform(0, 2 * math.pi)
                twist = rng.uniform(-0.3, 0.3)
                za, zb = h + 0.09 + rng.uniform(-0.07, 0.07), h - 0.09 + rng.uniform(-0.07, 0.07)  # ends lap in the mortise
                if (bay, j) == slipped:
                    za -= 0.3
                ya, yb = rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06)
                bow, sag = rng.uniform(-0.24, 0.24), rng.uniform(-0.14, 0.05)
                path = [Vector((xl - 0.5, ya, za))]
                for t in (rng.uniform(0.28, 0.4), rng.uniform(0.6, 0.74)):  # two knees: a split rail is never straight
                    w = math.sin(math.pi * t)
                    path.append(Vector((xl + (xr - xl) * t, ya + (yb - ya) * t + bow * w + rng.uniform(-0.05, 0.05),
                                        za + (zb - za) * t + sag * w + rng.uniform(-0.04, 0.04))))
                path.append(Vector((xr + 0.5, yb, zb)))
                fat = [rng.uniform(0.62, 0.78), rng.uniform(0.95, 1.12), rng.uniform(0.9, 1.1), rng.uniform(0.6, 0.76)]

                def mod(i, k, a, b, turn=turn, twist=twist, size=size, fat=fat):
                    ang = turn + twist * (i - 1.5)
                    a, b = base[k][0] * size * fat[i], base[k][1] * size * fat[i]
                    return a * math.cos(ang) - b * math.sin(ang), a * math.sin(ang) + b * math.cos(ang), 0.0

                key = "rail_brown" if rng.random() < 0.3 else "rail"
                end = tone("rail_end", rng, 0.06, under=1.0)
                sweep(W, "wood", path, base, tone(key, rng, 0.07, under=0.8), rng, up=Z, mod=mod, cap0=end, cap1=end, strip_jit=0.06)
        return {"wood": W}, {}

    # ------------------------------------------------------------------ finishing a set
    def to_object(G, name, lift):
        me = bpy.data.meshes.new(name)
        me.from_pydata(G.verts, [], G.faces)
        me.update()
        me.polygons.foreach_set("use_smooth", G.smooth)
        uv = me.uv_layers.new(name="UVMap")
        col = me.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
        li = 0
        for uvs, cols in zip(G.uvs, G.cols):
            for t, c in zip(uvs, cols):
                uv.data[li].uv = t
                col.data[li].color = tuple(srgb_to_linear(min(255.0, max(0.0, v * lift))) for v in c) + (1.0,)
                li += 1
        assert li == len(me.loops), f"{name}: {li} corners written, {len(me.loops)} in the mesh"
        me.color_attributes.active_color = col
        me.color_attributes.render_color_index = me.color_attributes.find("Col")
        obj = bpy.data.objects.new(name, me)
        scene_of().collection.objects.link(obj)
        return obj

    def finish_set(name, G, info):
        """Lift the set so its base is the pivot, give every mesh the set's box, make the objects."""
        for g in G.values():  # a leaning post's foot is cut level with the others
            g.verts = [(x, y, max(z, -BURY)) for x, y, z in g.verts]
        lo = Vector(tuple(min(v[i] for g in G.values() for v in g.verts) for i in range(3)))
        hi = Vector(tuple(max(v[i] for g in G.values() for v in g.verts) for i in range(3)))
        if abs(lo.z + BURY) > 1e-6:
            raise SystemExit(f"{name}: the lowest point is {lo.z:.4f}, not {-BURY}")
        hx, hy = max(-lo.x, hi.x), max(-lo.y, hi.y)  # the box is made even about the pivot
        out = {}
        for fam in MESHES[name]:
            g = G[fam]
            g.verts = [(x, y, z + BURY) for x, y, z in g.verts]
            real = g.triangles()
            if not args.no_anchors:
                e, c = ANCHOR, [PAL["speck"]] * 3
                a, b = Vector((-hx, -hy, 0.0)), Vector((hx, hy, hi.z + BURY))
                for pts in ([a, a + X * e, a + Y * e], [b, b - X * e, b - Y * e]):
                    g.f([g.v(p) for p in pts], [(0, 0), (e, 0), (0, e)], c)
            obj = to_object(g, f"{name}_{fam}", FAMILIES[fam]["lift"])
            obj["real_triangles"] = real
            out[fam] = obj
        info = dict(info)
        info["studs"] = [round(2 * hx, 2), round(hi.z + BURY, 2), round(2 * hy, 2)]
        info["true_min"] = [round(v, 3) for v in (lo.x, lo.y, lo.z + BURY)]
        info["true_max"] = [round(v, 3) for v in (hi.x, hi.y, hi.z + BURY)]
        return out, info

    def plain_material(name):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        bsdf.inputs["Roughness"].default_value = 0.85
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
        return m

    def export(obj):
        obj.data.materials.clear()
        obj.data.materials.append(plain_material(obj.name + "_VertexColor"))
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        path = MODELS / f"{obj.name}.glb"
        bpy.ops.export_scene.gltf(filepath=str(path), use_selection=True, export_format="GLB", export_yup=True,
                                  export_apply=True, export_vertex_color="ACTIVE", export_texcoords=True,
                                  export_normals=True)
        n = roblox_colors.convert(path, ROBLOX / path.name)
        obj.data.calc_loop_triangles()
        return {
            "triangles": len(obj.data.loop_triangles),
            "real_triangles": int(obj["real_triangles"]),
            "colours_converted": n,
            "glb": str(path.relative_to(REPO)).replace("\\", "/"),
            "roblox_glb": str((ROBLOX / path.name).relative_to(REPO)).replace("\\", "/"),
        }

    def build_all():
        common.reset()
        preview_cache.clear()
        sets = {}
        for name, fn in ((ARCH, build_arch), (FENCE1, lambda: build_fence(1)), (FENCE2, lambda: build_fence(2))):
            sets[name] = finish_set(name, *fn())
        return sets

    # ------------------------------------------------------------------ where things are (Roblox, from the pivot)
    def rbx(x, y, z):
        """Blender (x, y, height above the ground) to Roblox studs from the pivot."""
        return [round(-x, 3), round(z + BURY, 3), round(y, 3)]

    def arch_placing(info):
        zc, w, h = info["text_rect"]
        r0, r8 = post_r(0.0), post_r(LEAF_H)
        hinge = lambda sx, z: rbx(sx * (POST_X - post_r(z)), 0.0, z)  # noqa: E731
        top = info["true_max"][2]
        return {
            "bury": BURY,
            "ground_line": f"{BURY} above the pivot: place the pivot at ground height minus {BURY}",
            "height_above_ground": round(top - BURY, 2),
            "posts": {"centres_x": [-POST_X, POST_X], "radius_at_ground": r0, "radius_at_top": POST_RINGS[-1][1]},
            "opening": {
                "clear_between_posts": info["clear_posts"],
                "clear_between_posts_at_leaf_top": round(2 * (POST_X - r8), 2),
                "clear_between_footing_stones": info["clear_stones"],
                "clear_height_under_sign": round(min(z for _, z in SIGN_OUTLINE), 2),
                "clear_height_under_beam": ZB,
                "note": "heights here are above the GROUND. The 8 x 8 x 1 gate leaf fits on the centre plane (z = 0), "
                        "and the knee braces pass above its top corners.",
            },
            "gate_leaf": {
                "centre": rbx(0, 0, LEAF_H / 2), "size": [LEAF_W, LEAF_H, LEAF_T],
                "hinge_points": {
                    "post_at_minus_x": [hinge(1, 1.5), hinge(1, 6.5)],
                    "post_at_plus_x": [hinge(-1, 1.5), hinge(-1, 6.5)],
                    "note": "on the posts' inner faces, 1.5 and 6.5 above the ground, on the centre plane; hang the "
                            "leaf from either post (the other takes the latch)",
                },
            },
            "faces": {
                "sign_front": {"centre": rbx(0, SIGN_Y - SIGN_HT, zc), "size": [round(w, 2), round(h, 2)], "normal": [0, 0, -1],
                               "note": "flat, faces the front (-Z, the lake); a SurfaceGui part of this size goes 0.02 in front of it"},
                "sign_back": {"centre": rbx(0, SIGN_Y + SIGN_HT, zc), "size": [round(w, 2), round(h, 2)], "normal": [0, 0, 1],
                              "note": "the same flat face on the creek side"},
            },
            "sign_slab": {"plane_z": SIGN_Y, "thickness": 2 * SIGN_HT,
                          "width": round(max(x for x, _ in SIGN_OUTLINE) - min(x for x, _ in SIGN_OUTLINE), 2),
                          "bottom": round(min(z for _, z in SIGN_OUTLINE) + BURY, 2),
                          "top": round(max(z for _, z in SIGN_OUTLINE) + BURY, 2),
                          "note": "hangs 1 stud in front of the leaf's plane so it clears the leaf and the braces on it"},
            "crossbeam": {"underside": round(ZB + BURY, 2), "top": round(ZT + BURY, 2), "half_length": BEAM_HL, "half_depth": BEAM_HD},
            "roof": {"ridge_top": round(top, 2), "slope_degrees": round(math.degrees(math.atan(S)), 1), "half_depth": round(info["true_max"][1], 2)},
            "fence_join": {"first_section_pivot_x": [-(POST_X + 0.4 + FENCE_BAY), POST_X + 0.4 + FENCE_BAY],
                           "note": "a fence section's open end (its rails, no post) goes into the arch post: put the first "
                                   f"section's pivot {POST_X + 0.4 + FENCE_BAY:g} from the arch's centre line, open end toward the arch"},
        }

    def fence_placing():
        return {
            "bury": BURY,
            "ground_line": f"{BURY} above the pivot: place the pivot at ground height minus {BURY}",
            "height_above_ground": FENCE_TOP,
            "module": 2 * FENCE_BAY,
            "posts_at_x": [FENCE_BAY, 0.0],
            "open_end_x": -FENCE_BAY,
            "rail_heights_above_ground": list(RAIL_H),
            "note": "one section is 10 studs of fence: posts at Roblox x = +5 and 0, and rails that run on to x = -5.5, "
                    "into the next section's post (or the arch post). Chain them every 10 studs along X, the same way "
                    "round, mixing the two variants; a half turn (180 degrees about Y) gives two more looks but swaps "
                    "the open end. The end of a run needs one more post: a section sunk or cut works.",
        }

    # ------------------------------------------------------------------ preview
    def setup_cycles(w, h, sun_rot=(34, 0, 38), sun_rgb=(1.0, 0.97, 0.90), sun_energy=4.2,
                     sky=(0.62, 0.78, 1.0), sky_strength=0.9, exposure=-0.35):
        scene = scene_of()
        for o in [o for o in scene.objects if o.get("_stage") == "shot"]:
            bpy.data.objects.remove(o, do_unlink=True)
        scene.render.engine = "CYCLES"
        try:
            prefs = bpy.context.preferences.addons["cycles"].preferences
            for kind in ("OPTIX", "CUDA"):
                try:
                    prefs.compute_device_type = kind
                    prefs.get_devices()
                    if any(d.type == kind for d in prefs.devices):
                        for d in prefs.devices:
                            d.use = True
                        scene.cycles.device = "GPU"
                        break
                except Exception:
                    continue
        except Exception:
            pass
        scene.cycles.samples = args.samples
        scene.cycles.use_denoising = True
        scene.render.resolution_x, scene.render.resolution_y = w, h
        scene.render.resolution_percentage = 100
        scene.render.image_settings.file_format = "PNG"
        scene.render.film_transparent = False
        scene.view_settings.view_transform = "Standard"
        scene.view_settings.look = "None"
        scene.view_settings.exposure = exposure
        world = bpy.data.worlds.new("Sky")
        world.use_nodes = True
        bg = world.node_tree.nodes["Background"]
        bg.inputs[0].default_value = tuple(sky) + (1.0,)
        bg.inputs[1].default_value = sky_strength
        scene.world = world
        sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
        sun.data.energy = sun_energy
        sun.data.color = sun_rgb
        sun.data.angle = math.radians(1.5)
        sun.rotation_euler = tuple(math.radians(v) for v in sun_rot)
        scene.collection.objects.link(sun)
        cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        scene.collection.objects.link(cam)
        scene.camera = cam
        sun["_stage"] = cam["_stage"] = "shot"
        return cam, sun

    def flat(name, rgb, rough=0.95, emit=0.0):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        lin = tuple(srgb_to_linear(c) for c in rgb) + (1.0,)
        bsdf.inputs["Base Color"].default_value = lin
        bsdf.inputs["Roughness"].default_value = rough
        if emit:
            bsdf.inputs["Emission Color"].default_value = lin
            bsdf.inputs["Emission Strength"].default_value = emit
        return m

    def mottled(name, rgb_a, rgb_b, scale=0.25):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        bsdf.inputs["Roughness"].default_value = 0.95
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = scale
        noise.inputs["Detail"].default_value = 4.0
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position, ramp.color_ramp.elements[1].position = 0.38, 0.66
        ramp.color_ramp.elements[0].color = tuple(srgb_to_linear(c) for c in rgb_a) + (1.0,)
        ramp.color_ramp.elements[1].color = tuple(srgb_to_linear(c) for c in rgb_b) + (1.0,)
        nt.links.new(noise.outputs[0], ramp.inputs[0])
        nt.links.new(ramp.outputs[0], bsdf.inputs["Base Color"])
        return m

    preview_cache = {}

    def preview_material(fam):
        """What the game shows: vertex colour times the family's neutral map, with its normal and
        roughness maps, one tile every StudsPerTile UV units."""
        if fam in preview_cache and preview_cache[fam].name in bpy.data.materials:
            return preview_cache[fam]
        m = bpy.data.materials.new(f"Preview_{fam}")
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        slug = FAMILIES[fam]["slug"]
        uv = nt.nodes.new("ShaderNodeUVMap")
        uv.uv_map = "UVMap"
        mapping = nt.nodes.new("ShaderNodeMapping")
        s = 1.0 / tiles[fam]
        mapping.inputs["Scale"].default_value = (s, s, 1)
        nt.links.new(uv.outputs[0], mapping.inputs[0])

        def tex(kind, non_color):
            node = nt.nodes.new("ShaderNodeTexImage")
            node.image = bpy.data.images.load(str(TEXTURES / slug / f"{slug}_{kind}.png"), check_existing=True)
            if non_color:
                node.image.colorspace_settings.name = "Non-Color"
            nt.links.new(mapping.outputs[0], node.inputs[0])
            return node

        mixn = nt.nodes.new("ShaderNodeMix")
        mixn.data_type = "RGBA"
        mixn.blend_type = "MULTIPLY"
        mixn.inputs[0].default_value = 1.0
        nt.links.new(tex("neutral", False).outputs[0], mixn.inputs[6])
        nt.links.new(vc.outputs["Color"], mixn.inputs[7])
        nt.links.new(mixn.outputs[2], bsdf.inputs["Base Color"])
        nt.links.new(tex("rough", True).outputs[0], bsdf.inputs["Roughness"])
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        nmap.uv_map = "UVMap"
        nt.links.new(tex("normal", True).outputs[0], nmap.inputs["Color"])
        nt.links.new(nmap.outputs[0], bsdf.inputs["Normal"])
        preview_cache[fam] = m
        return m

    def dress(objs):
        for fam, obj in objs.items():
            obj.data.materials.clear()
            obj.data.materials.append(preview_material(fam))

    def stage(obj, kind="set"):
        obj["_stage"] = kind
        return obj

    def stage_box(size, loc, material, kind="set", rot=(0, 0, 0)):
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
        o = bpy.context.object
        o.scale = size
        o.data.materials.append(material)
        return stage(o, kind)

    def aim(cam, eye, look, fov=None, ortho=None, clip=2000):
        cam.location = eye
        d = Vector(look) - Vector(eye)
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        cam.data.clip_end = clip
        if ortho:
            cam.data.type = "ORTHO"
            cam.data.ortho_scale = ortho
        else:
            cam.data.type = "PERSP"
            cam.data.sensor_fit = "VERTICAL"
            cam.data.angle_y = math.radians(fov)

    def render(path):
        path.parent.mkdir(parents=True, exist_ok=True)
        scene_of().render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        print(f"[creek_gate] rendered {path}")

    def copy_set(objs, loc, yaw=0.0):
        out = []
        for o in objs.values():
            c = o.copy()
            c.location = loc
            c.rotation_euler = (0, 0, yaw)
            scene_of().collection.objects.link(c)
            out.append(stage(c))
        return out

    def figure(loc, yaw=0.0):
        """A stand-in player, 5.9 studs to the top of the head."""
        skin, shirt, legs = flat("FigSkin", (190, 178, 160)), flat("FigShirt", (124, 132, 150)), flat("FigLegs", (86, 90, 100))
        parts = [((0.9, 0.9, 2.3), (-0.5, 0, 1.15), legs), ((0.9, 0.9, 2.3), (0.5, 0, 1.15), legs),
                 ((2.0, 1.0, 2.3), (0, 0, 3.45), shirt), ((0.9, 0.9, 2.3), (-1.45, 0, 3.45), shirt),
                 ((0.9, 0.9, 2.3), (1.45, 0, 3.45), shirt), ((1.35, 1.35, 1.35), (0, 0, 5.3), skin)]
        rot = Matrix.Rotation(yaw, 4, "Z")
        for size, at, m in parts:
            bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
            o = bpy.context.object
            o.matrix_world = Matrix.Translation(loc) @ rot @ Matrix.Translation(at) @ Matrix.Diagonal((*size, 1.0))
            o.data.materials.append(m)
            stage(o)

    def lettering(info, back=False):
        """A stand-in for the game's SurfaceGui: the words at the size the flat face allows."""
        zc, w, h = info["text_rect"]
        cu = bpy.data.curves.new("Lettering", "FONT")
        cu.body = "Cedar Creek"
        cu.align_x, cu.align_y = "CENTER", "CENTER"
        o = bpy.data.objects.new("Lettering", cu)
        scene_of().collection.objects.link(o)
        bpy.context.view_layer.update()
        s = min((w * 0.94) / max(o.dimensions.x, 1e-6), (h * 0.80) / max(o.dimensions.y, 1e-6))
        o.scale = (s, s, s)
        y = SIGN_Y + (SIGN_HT + 0.015) * (1 if back else -1)
        o.location = (0, y, zc)
        o.rotation_euler = (math.radians(90), 0, math.radians(180) if back else 0)
        o.data.materials.append(flat("Paint", (226, 214, 184), rough=0.8))
        return stage(o)

    def woods(seed=11):
        """A stand-in for the place: the gravel walk through the gate, mossy ground, the dark
        cedars behind the fence line. Stage only."""
        rng = random.Random(seed)
        ground = mottled("Ground", (58, 72, 44), (84, 98, 58))
        bpy.ops.mesh.primitive_plane_add(size=600, location=(0, 0, 0))
        bpy.context.object.data.materials.append(ground)
        stage(bpy.context.object)
        gravel = mottled("Gravel", (128, 118, 102), (156, 146, 128), scale=1.6)
        stage_box((6.4, 120, 0.04), (0, -10, 0.0), gravel)
        trunk = flat("Trunk", (64, 46, 36))
        crown = flat("Crown", (30, 50, 36))
        spots = [(-11, 7), (10, 9), (-3, 16), (17, 15), (-19, 13), (5, 24), (-10, 27), (22, 28), (-26, 24), (13, 36), (-4, 40),
                 (-17, 44), (28, 44), (3, 52), (-30, 40), (20, 56), (-12, 60), (36, 30), (-38, 32), (-24, 58), (30, 66), (8, 68),
                 (-36, 52), (42, 50), (-44, 44), (0, 78), (-18, 76), (18, 80), (48, 70), (-50, 66)]
        for x, y in spots:
            x, y = x + rng.uniform(-1.5, 1.5), y + rng.uniform(-1.5, 1.5)
            h = rng.uniform(30, 44)
            r = rng.uniform(0.9, 1.5)
            bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=r, radius2=r * 0.45, depth=h, location=(x, y, h / 2))
            bpy.context.object.data.materials.append(trunk)
            stage(bpy.context.object)
            for k in range(3):
                z0 = 11 + k * 7 + rng.uniform(-1, 1)
                bpy.ops.mesh.primitive_cone_add(vertices=9, radius1=rng.uniform(7, 9.5) - k * 1.6, radius2=0.4, depth=11,
                                                location=(x, y, z0 + 5.5))
                bpy.context.object.data.materials.append(crown)
                stage(bpy.context.object)

    def scene_composed(leaf=False, person=False, back_text=False):
        """The arch on the walk with a fence run each side, the way the composer would lay it."""
        sets = build_all()
        for objs, _ in sets.values():
            dress(objs)
        arch, info = sets[ARCH]
        variants = (sets[FENCE1][0], sets[FENCE2][0])
        first = POST_X + 0.4 + FENCE_BAY
        for i in range(7):
            x = first + i * 2 * FENCE_BAY
            copy_set(variants[i % 2], (x, 0, 0), math.pi)        # open end toward the arch
            copy_set(variants[(i + 1) % 2], (-x, 0, 0), 0.0)
        for objs in variants:
            for o in objs.values():
                o.hide_render = True
        for o in arch.values():
            o.location = (0, 0, -BURY)
        for o in scene_of().objects:
            if o.get("_stage") == "set" and o.type == "MESH" and o.data.name.startswith("CreekFence"):
                o.location.z = -BURY
        woods()
        lettering(info)
        if back_text:
            lettering(info, back=True)
        if leaf:
            stage_box((LEAF_W, LEAF_T, LEAF_H), (0, 0, LEAF_H / 2), flat("Leaf", (122, 104, 86)))
        if person:
            figure((1.2, -3.2, 0), yaw=0.3)
        return sets

    # ------------------------------------------------------------------ run
    for d in (MODELS, ROBLOX, PREVIEWS, SCRATCH, out_dir):
        d.mkdir(parents=True, exist_ok=True)

    sets = build_all()
    result = {"sets": {}}
    for name, (objs, info) in sets.items():
        entry = {"studs": info["studs"], "true_min": info["true_min"], "true_max": info["true_max"], "meshes": {}}
        entry["placing"] = arch_placing(info) if name == ARCH else fence_placing()
        for fam, obj in objs.items():
            entry["meshes"][fam] = export(obj)
            print(f"[creek_gate] {obj.name}: {entry['meshes'][fam]['real_triangles']} triangles")
        total = sum(m["real_triangles"] for m in entry["meshes"].values())
        if total > BUDGET[name]:
            raise SystemExit(f"{name}: {total} triangles is over the {BUDGET[name]} budget")
        entry["triangles"] = total
        result["sets"][name] = entry
        print(f"[creek_gate] {name}: {total} triangles, box {info['studs']}")
    (SCRATCH / "result.json").write_text(json.dumps(result, indent=1), encoding="utf-8")
    if args.no_render:
        return

    def want(v):
        return not views or v in views

    W_, H_ = 1600, 900
    if want("shot11"):  # shot 11's camera, moved into the arch's own space: 25 studs off, 70 degree view
        scene_composed()
        cam, _ = setup_cycles(1600, 740)
        aim(cam, (-8.0, -22.0, 4.5), (1.0, 4.0, 2.8), fov=70)
        render(out_dir / "shot11.png")
    if want("close"):  # walking up to it, noon
        scene_composed()
        cam, _ = setup_cycles(W_, H_)
        aim(cam, (-4.2, -11.0, 5.0), (0.3, 0.0, 7.4), fov=62)
        render(out_dir / "close.png")
    if want("hero"):  # the high three-quarter
        scene_composed()
        cam, _ = setup_cycles(W_, H_)
        aim(cam, (-17.0, -21.0, 12.0), (0.5, 0.0, 5.6), fov=38)
        render(out_dir / "hero.png")
    if want("back"):  # from the creek side, to see the unseen side honestly
        scene_composed(back_text=True)
        cam, _ = setup_cycles(W_, H_, sun_rot=(34, 0, 150))
        aim(cam, (7.5, 15.0, 5.2), (-0.3, 0.0, 6.6), fov=58)
        render(out_dir / "back.png")
    if want("fence"):  # the fence run, close, both variants
        scene_composed()
        cam, _ = setup_cycles(W_, H_)
        aim(cam, (9.0, -9.5, 4.3), (17.5, 0.0, 1.7), fov=50)
        render(out_dir / "fence.png")
    if want("fit"):  # the real gate leaf and a player, square on
        scene_composed(leaf=True, person=True)
        cam, _ = setup_cycles(W_, H_)
        aim(cam, (0.0, -30.0, 6.2), (0.0, 0.0, 6.2), fov=30)
        render(out_dir / "fit.png")
    if want("under"):  # standing in the gateway, looking up at the roof's underside
        scene_composed()
        cam, _ = setup_cycles(W_, H_)
        aim(cam, (-1.2, 3.6, 5.2), (0.8, -0.4, 10.6), fov=75)
        render(out_dir / "under.png")
    if "cull" in views:  # scratch only: one-sided faces, as Roblox draws them, on a loud background; a hole is a face turned inward
        sets = build_all()
        for (objs, _), x in ((sets[ARCH], 0.0), (sets[FENCE1], -13.0), (sets[FENCE2], 13.0)):
            for o in objs.values():
                o.location = (x, 0, 0)
                o.data.materials.clear()
                o.data.materials.append(plain_material(o.name + "_cull"))
        cam, _ = setup_cycles(W_, H_)
        scene = scene_of()
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.show_backface_culling = True
        scene.display.shading.color_type = "VERTEX"
        scene.display.shading.light = "STUDIO"
        scene.world.node_tree.nodes["Background"].inputs[0].default_value = (1.0, 0.0, 1.0, 1.0)
        scene.world.color = (1.0, 0.0, 1.0)
        for tag, eye in (("front", (-6, -30, 9)), ("back", (8, 30, 7)), ("below", (3, -9, 0.6)), ("above", (-4, -8, 30)),
                         ("end", (34, -3, 6)), ("below_back", (-3, 9, 0.6))):
            aim(cam, eye, (0, 0, 6.2), fov=52)
            render(out_dir / f"cull-{tag}.png")
    if want("pieces"):  # the two fence variants on plain ground, and the arch alone
        sets = build_all()
        for objs, _ in sets.values():
            dress(objs)
        for o in sets[ARCH][0].values():
            o.hide_render = True
        for (objs, _), y in ((sets[FENCE1], 0.0), (sets[FENCE2], -4.5)):
            for o in objs.values():
                o.location = (0, y, -BURY)
        bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, 0))
        bpy.context.object.data.materials.append(flat("Plain", (150, 150, 146)))
        stage(bpy.context.object)
        cam, _ = setup_cycles(W_, H_)
        aim(cam, (-8.0, -16.0, 6.5), (0.0, -2.0, 1.6), fov=36)
        render(out_dir / "pieces.png")


# =======================================================================================
# Driver half (plain Python and Pillow)
# =======================================================================================

def read_glb(path: Path):
    data = path.read_bytes()
    json_len = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20:20 + json_len])


def check_glb(path: Path, want_studs, anchors: bool):
    g = read_glb(path)
    if len(g["meshes"]) != 1 or len(g["meshes"][0]["primitives"]) != 1:
        raise SystemExit(f"{path.name}: expected one mesh with one material")
    prim = g["meshes"][0]["primitives"][0]
    for need in ("POSITION", "NORMAL", "TEXCOORD_0", "COLOR_0"):
        if need not in prim["attributes"]:
            raise SystemExit(f"{path.name}: no {need}")
    if "images" in g or "textures" in g:
        raise SystemExit(f"{path.name}: a texture got into the file; Layer B meshes carry none")
    pos = g["accessors"][prim["attributes"]["POSITION"]]
    size = [round(b - a, 2) for a, b in zip(pos["min"], pos["max"])]
    tris = g["accessors"][prim["indices"]]["count"] // 3
    if anchors and any(abs(a - b) > 0.011 for a, b in zip(size, want_studs)):
        raise SystemExit(f"{path.name}: size {size}, expected {want_studs}")
    if anchors and (abs(pos["min"][1]) > 0.002 or abs(pos["min"][0] + pos["max"][0]) > 0.002 or abs(pos["min"][2] + pos["max"][2]) > 0.002):
        raise SystemExit(f"{path.name}: pivot is not the base centre ({pos['min']} to {pos['max']})")
    return size, tris


REPLACES = {
    ARCH: "Scenery's gray-box arch in Lake.Scenery.CreekFence (two ArchPost parts and the ArchBeam) and the flat "
          "CreekSign board WorldBuilder.paintSigns hangs under it; the CreekGate leaf, the GatePost prompt part and "
          "the unseen fence walls stay",
    FENCE1: "Scenery's Post and Rail parts in Lake.Scenery.CreekFence (mix the two variants along the run)",
    FENCE2: "Scenery's Post and Rail parts in Lake.Scenery.CreekFence (mix the two variants along the run)",
}


def driver_main():
    import subprocess

    try:
        from PIL import Image, ImageDraw, ImageFont
    except ModuleNotFoundError:
        import site

        sys.path.append(site.getusersitepackages())
        from PIL import Image, ImageDraw, ImageFont

    args = parse_args(sys.argv[1:])
    out_dir = SCRATCH / args.tag

    if not args.compose_only:
        SCRATCH.mkdir(parents=True, exist_ok=True)
        subprocess.run([BLENDER, "-b", "--factory-startup", "-P", str(Path(__file__).resolve()), "--", *sys.argv[1:]], check=True)
    result = json.loads((SCRATCH / "result.json").read_text(encoding="utf-8"))

    # Check what was written, then record it. Only this script's own manifest entries are touched,
    # and the manifest is read again right before it is written (other scripts write it too).
    entries = {}
    for name, entry in result["sets"].items():
        for fam, mesh in entry["meshes"].items():
            for sub in ("glb", "roblox_glb"):
                size, tris = check_glb(REPO / mesh[sub], entry["studs"], not args.no_anchors)
            if tris != mesh["triangles"]:
                raise SystemExit(f"{name}_{fam}: {tris} triangles in the file, {mesh['triangles']} in Blender")
            f = FAMILIES[fam]
            also = " The two iron sign hangers ride in this mesh as near-black vertex colour." if (name, fam) == (ARCH, "stone") else ""
            entries[f"{name}_{fam}"] = {
                "name": f"{name}_{fam}",
                "studs": size,
                "triangles": mesh["real_triangles"],
                "replaces": REPLACES[name],
                "notes": (f"Layer B, {fam} family: MaterialVariant {f['variant']} with its NEUTRAL colour map, normal and "
                          f"roughness. Vertex colours stored {f['lift']:g} times the colour wanted. UVs at 1 stud per UV "
                          f"unit, V along the grain.{also} Upload art/models/roblox/{name}_{fam}.glb. Pivot at the base "
                          f"centre, front along -Z; the ground line is {BURY} above the pivot, so place the pivot at ground "
                          f"height minus {BURY}. Every mesh of the set goes at the same CFrame. The file also holds two "
                          f"specks (2 triangles) that pin the set's box. The set is {entry['triangles']} triangles in all."),
                "family": fam,
                "variant": f["slug"],
                "uv_studs": 1.0,
                "lift": f["lift"],
                "bury": BURY,
                "set": name,
                "set_triangles": entry["triangles"],
                "true_min": entry["true_min"],
                "true_max": entry["true_max"],
                "placing": entry["placing"],
            }
            print(f"{name}_{fam}: {size} studs, {mesh['real_triangles']} triangles")
        print(f"{name}: {entry['triangles']} triangles of {BUDGET[name]}")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    own = {f"{name}_{fam}" for name, fams in MESHES.items() for fam in fams}
    manifest = {k: v for k, v in manifest.items() if k not in own}
    manifest.update(entries)
    MANIFEST.write_text(json.dumps(dict(sorted(manifest.items())), indent=2) + "\n", encoding="utf-8")
    if args.no_render:
        return

    def font(size, bold=False):
        for f in (("segoeuib.ttf",) if bold else ()) + ("segoeui.ttf", "arial.ttf"):
            try:
                return ImageFont.truetype(f, size)
            except OSError:
                continue
        return ImageFont.load_default()

    def save_small(src: Path, dst: Path, width=None):
        im = Image.open(src).convert("RGB")
        if width and im.width > width:
            im = im.resize((round(width), round(im.height * width / im.width)), Image.LANCZOS)
        im.save(dst, optimize=True)

    names = {"hero.png": "CreekGateArch.png", "shot11.png": "CreekGateArch-shot11.png", "close.png": "CreekGateArch-close.png",
             "back.png": "CreekGateArch-back.png", "fit.png": "CreekGateArch-fit.png", "under.png": "CreekGateArch-under.png",
             "fence.png": "CreekFenceSection.png", "pieces.png": "CreekFenceSection-pieces.png"}
    if args.tag == "final":
        for src, dst in names.items():
            if (out_dir / src).exists():
                save_small(out_dir / src, PREVIEWS / dst, 1600)

    def fit(path, w, h):
        im = Image.open(path).convert("RGB")
        s = max(w / im.width, h / im.height)
        im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
        x, y = (im.width - w) // 2, (im.height - h) // 2
        return im.crop((x, y, x + w, y + h))

    def sheet(title, sub, rows, out, cell_w=960, cell_h=540):
        pad, head = 16, 34
        cols = max(len(r) for r in rows)
        W = pad + cols * (cell_w + pad)
        H = 78 + sum(head + cell_h + pad for _ in rows)
        im = Image.new("RGB", (W, H), (24, 24, 27))
        draw = ImageDraw.Draw(im)
        draw.text((pad, 14), title, font=font(30, True), fill=(240, 240, 240))
        draw.text((pad, 52), sub, font=font(16), fill=(170, 170, 175))
        y = 78
        for row in rows:
            for i, (label, path) in enumerate(row):
                x = pad + i * (cell_w + pad)
                draw.text((x, y + 6), label, font=font(17), fill=(210, 210, 214))
                if Path(path).exists():
                    im.paste(fit(path, cell_w, cell_h), (x, y + head))
                else:
                    draw.rectangle((x, y + head, x + cell_w, y + head + cell_h), outline=(80, 80, 84))
                    draw.text((x + 12, y + head + 12), "not rendered", font=font(16), fill=(120, 120, 124))
            y += head + cell_h + pad
        im.save(out, optimize=True)
        print(f"sheet: {out}")

    if args.tag != "final":
        return
    tri = ", ".join(f"{n} {e['triangles']}" for n, e in result["sets"].items())
    stage_note = "Ground, walk, trees and the lettering are a stage, not part of the set."
    sheet("The Cedar Creek gate set (N3): Layer B meshes under the family maps",
          f"Rendered as the game shows them: vertex colour times each family's map. Triangles: {tri}. {stage_note}",
          [[("The gate it replaces (shot 11, 11/28/2026)", CURRENT_SHOT), ("The new arch from shot 11's camera: 25 studs, noon, 70 degree view", out_dir / "shot11.png")],
           [("Walking up to it", out_dir / "close.png"), ("High three-quarter", out_dir / "hero.png")],
           [("From the creek side", out_dir / "back.png"), ("The fence run, both variants", out_dir / "fence.png")],
           [("Square on, with the game's 8 by 8 gate leaf and a player", out_dir / "fit.png"), ("In the gateway, looking up", out_dir / "under.png")]],
          PREVIEWS / "creek_gate_set.png")
    sheet("Cedar Creek gate: the gate in the game today, and the new arch",
          f"Left: shot 11 as captured 11/28/2026. Right: the new set from shot 11's camera, in Blender. {stage_note}",
          [[("In the game today", CURRENT_SHOT), ("New arch and fence, shot 11's camera from shots.json", out_dir / "shot11.png")]],
          PREVIEWS / "CreekGateArch-vs-current.png", cell_w=1280, cell_h=592)
    before = SCRATCH / "before"
    if (before / "shot11.png").exists():
        sheet("Cedar Creek gate: first pass and final",
              "Left: the first build. Right: after the fixes named in the modeler's report.",
              [[("First pass, shot 11's camera", before / "shot11.png"), ("Final, shot 11's camera", out_dir / "shot11.png")],
               [("First pass, walking up", before / "close.png"), ("Final, walking up", out_dir / "close.png")]],
              PREVIEWS / "CreekGateArch-before-after.png")


if __name__ == "__main__":
    if IN_BLENDER:
        blender_main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    else:
        driver_main()
