"""The boathouse set for the dock slips (leg 3, N4): the Boathouse, the PriceBoard and the
MooringFloat. Layer B of the look kit: every mesh keeps its vertex colours for hue and wears
one of our MaterialVariants, so nothing here carries a texture of its own.

    Boathouse_wood     posts, frame, plank walls, floor, canoe rack, counter, paddles   WeatheredPlank
    Boathouse_tin      the corrugated roof and its ridge cap                             TinRoofRust
    Boathouse_paint    the shop board, fascia boards, life ring, ledger                  PaintedWood
    Boathouse_metal    lantern cage and hook, floor cleat                                stock Metal
    PriceBoard_paint   one mesh: post, feet and a 3 by 2 painted board                   PaintedWood
    MooringFloat_wood  deck boards, rim, pontoons, four bitts                            WeatheredPlank
    MooringFloat_metal the horn cleat                                                    stock Metal

Front is Blender -Y, which is Roblox -Z (the stands are built the same way: Roblox (x, y, z)
is Blender (-x, z, y)). Every mesh of a set shares the set's pivot, the base centre, and,
through two specks at opposite corners, the set's whole box, so each one drops in at the same
CFrame whichever way the importer finds its centre.

Rules this rests on (stands_split.py, proven in Studio 11/27/2026):
  * a variant's colour map MULTIPLIES the vertex colour. The neutral maps have a mean of 0.80,
    so wood and paint colours are stored 1.25 times lighter than the colour wanted. The tin
    wears the COLOUR map (TinRoofRust, bare galvanised tin with brown rust), so its vertex
    colours are near white and only tint it;
  * a variant's maps follow the mesh UVs, one tile every StudsPerTile UV units. Wood and paint
    use 1 UV unit = 1 stud. The tin uses 1 UV unit = 2 studs: tin_roof has 15 ribs per tile,
    so at the family's 4 studs per tile that is one rib every 0.53 stud, and the roof's real
    corrugation is built at exactly that pitch and phase.

    python art/scripts/boathouse.py                 build, export, render, sheet
    python art/scripts/boathouse.py --no-render     models and manifest only
    python art/scripts/boathouse.py --tag before    renders go to artifacts/boathouse/before/
    python art/scripts/boathouse.py --views golden,front
    python art/scripts/boathouse.py --compose-only  rebuild the sheets from the renders made
    blender -b -P art/scripts/boathouse.py -- --no-render       (the Blender half on its own)

Writes art/models/<Mesh>.glb (linear colours), art/models/roblox/<Mesh>.glb (display colours,
the copy to upload), the previews in art/previews/ and its own entries in
art/models/manifest.json. Scratch goes to artifacts/boathouse/ (git-ignored).
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
SCRATCH = REPO / "artifacts" / "boathouse"
MANIFEST = MODELS / "manifest.json"
REFERENCE = REPO / "docs" / "looks" / "leg3-references" / "n4-cedar-canoe-and-boathouse-golden.jpg"
BLENDER = os.environ.get("BLENDER", r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe")

try:
    import bpy  # noqa: F401

    IN_BLENDER = True
except ModuleNotFoundError:
    IN_BLENDER = False

# family -> how the game dresses it. `map` is which colour map the variant carries.
FAMILIES = {
    "wood": {"slug": "weathered_plank", "variant": "WeatheredPlank", "map": "neutral", "lift": 1.25, "uv": 1.0, "boards": 5},
    "tin": {"slug": "tin_roof", "variant": "TinRoofRust", "map": "color", "lift": 1.0, "uv": 2.0, "boards": None},
    "paint": {"slug": "painted_wood", "variant": "PaintedWood", "map": "neutral", "lift": 1.25, "uv": 1.0, "boards": 4},
    "metal": {"slug": None, "variant": None, "map": None, "lift": 1.0, "uv": 1.0, "boards": None},
}
SETS = ("Boathouse", "PriceBoard", "MooringFloat")
MESHES = {
    "Boathouse": ("wood", "tin", "paint", "metal"),
    "PriceBoard": ("paint",),
    "MooringFloat": ("wood", "metal"),
}
BUDGET = {"Boathouse": 4000, "PriceBoard": 300, "MooringFloat": 400}
ANCHOR = 0.02  # side of the corner specks, studs
TIN_RIBS_PER_TILE = 15  # measured from tin_roof_normal.png (the driver checks it)

# ---------------------------------------------------------------------------------------
# Palette: the colours we want to SEE in the game (sRGB 0..255), before the lift.
# Home lake, Real-ish: dock timber 122,104,86 silver-brown, lantern 255,190,120.
# ---------------------------------------------------------------------------------------
PAL = {
    "post": (104, 90, 76),          # heavy frame timber, darker and older than the dock
    "beam": (114, 98, 82),
    "rafter": (108, 90, 72),        # under the roof, out of the sun: browner
    "wall_out": (136, 123, 108),    # plank walls, sun-silvered outside
    "wall_in": (112, 96, 79),       # the same boards inside the shed
    "floor": (138, 122, 102),       # walked-on deck boards
    "rim": (92, 80, 68),
    "rack": (156, 132, 100),         # newer, cleaner wood: the canoe rack
    "pad": (62, 57, 52),            # the worn dark pads the hulls rest on
    "counter": (142, 126, 106),
    "counter_top": (110, 95, 80),
    "paddle": (170, 140, 100),      # old ash paddles
    "pontoon": (84, 74, 64),
    "tin": (250, 250, 250),         # tint only: TinRoofRust's own map is 150,152,150 with rust
    "tin_eave": (244, 236, 226),    # a little warmer where the rust runs gather
    "tin_under": (176, 172, 166),
    "green": (68, 92, 78),          # boathouse green: the boards the game writes on
    "green_pale": (100, 118, 102),  # the same paint on the fascia, bleached by the sun
    "cream": (204, 198, 184),       # 204 is as light as a neutral map lets paint be
    "core": (50, 55, 51),           # the dark seen in the grooves between sign boards
    "ring_white": (204, 200, 190),
    "ring_red": (160, 74, 58),      # faded oxide red, not a primary
    "stain": (98, 84, 70),          # dark-stained post of the price board
    "book": (120, 62, 52),
    "iron": (58, 56, 56),
    "galv": (138, 143, 145),
}
LANTERN = (255, 190, 120)

# The boathouse's measurements (Blender: x width, y depth with the open front at -y, z up).
HX, HY = 8.0, 6.0          # half width and half depth of the body, to the posts' outer faces
POST = 0.9
FLOOR = 0.4                # top of the deck boards above the base
POST_TOP = 6.7
PLATE_TOP = 7.2
S = 0.44                   # roof slope (rise over run): 23.7 degrees
ZR = PLATE_TOP + 0.1 + HX * S  # the rafters' top line at the ridge
L = math.sqrt(1 + S * S)
QE = 8.6                   # eave, horizontal distance from the ridge
RIB = 8.0 / TIN_RIBS_PER_TILE  # corrugation pitch in studs (0.533)
N_RIB = 26
Y0 = -7.25                 # front edge of the tin
Y1 = Y0 + N_RIB * RIB      # back edge (6.617)
TIN_BOTTOM, TIN_MID, TIN_AMP = 0.25, 0.36, 0.07  # offsets above the rafters' top line
RACK_X, RACK_ARM_DX = -0.8, 3.3
RACK_TIERS = (2.2, 4.8)    # arm tops at the wall, above the base
KIOSK_X = 4.5
BOARD_Y, BOARD_Z = -3.6, 4.15  # the shop board's flat face: its plane and its centre height


def parse_args(argv):
    ap = argparse.ArgumentParser(description="Build the boathouse set (Layer B).")
    ap.add_argument("--no-render", action="store_true", help="build and export only")
    ap.add_argument("--compose-only", action="store_true", help="rebuild the sheets from the renders already made")
    ap.add_argument("--views", default="", help="only these renders (hero, golden, high, front, inside, ingame, back, pieces, fit; eave is scratch only)")
    ap.add_argument("--tag", default="final", help="scratch subfolder for the renders; only 'final' reaches art/previews")
    ap.add_argument("--samples", type=int, default=int(os.environ.get("ART_SAMPLES", "64")))
    ap.add_argument("--no-anchors", action="store_true", help="leave out the two bounding-box specks per mesh")
    return ap.parse_args(argv)


def family_tiles():
    table = json.loads((HERE / "texture_families.json").read_text(encoding="utf-8"))["families"]
    return {fam: float(table[f["slug"]]["studs_per_tile"]) if f["slug"] else 1.0 for fam, f in FAMILIES.items()}


# =======================================================================================
# Blender half
# =======================================================================================

def blender_main(argv):
    import bmesh
    import bpy
    import numpy as np
    from mathutils import Euler, Matrix, Vector

    sys.path.insert(0, str(HERE))
    import common
    from common import bounds, srgb_to_linear
    import roblox_colors

    args = parse_args(argv)
    tiles = family_tiles()
    views = [v for v in args.views.split(",") if v]
    out_dir = SCRATCH / args.tag
    scene_of = lambda: bpy.context.scene  # noqa: E731
    X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))

    def tin_crest_u():
        """Where a rib's crest sits in tin_roof_normal.png, as a fraction of the tile's width."""
        img = bpy.data.images.load(str(TEXTURES / "tin_roof" / "tin_roof_normal.png"), check_existing=True)
        w, h = img.size
        px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, img.channels)
        nx = px[:, :, 0].mean(axis=0) * 2 - 1
        height = -np.cumsum(nx)  # OpenGL normal map: nx = -dh/du
        spec = np.fft.rfft(height - height.mean())
        k = int(np.argmax(np.abs(spec[1:])) + 1)
        if k != TIN_RIBS_PER_TILE:
            raise SystemExit(f"tin_roof_normal.png has {k} ribs per tile, not {TIN_RIBS_PER_TILE}: fix TIN_RIBS_PER_TILE")
        return float((-np.angle(spec[k]) / (2 * math.pi)) % 1.0) / k

    # ------------------------------------------------------------------ parts
    class Part:
        def __init__(self, obj, family, key, grain, keys=None, jitter=0.05, uv_done=False, foot=False,
                     inner=None, tints=None, smooth=False):
            self.obj, self.family, self.key, self.grain = obj, family, key, grain.normalized()
            self.keys, self.jitter, self.uv_done, self.foot = keys, jitter, uv_done, foot
            self.inner, self.tints, self.smooth = inner, tints, smooth

    def new_obj(bm, name):
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        obj = bpy.data.objects.new(name, me)
        scene_of().collection.objects.link(obj)
        return obj

    def hexa(c, name="part"):
        """A six-sided solid from 8 corners: the bottom ring 0..3 and the top ring 4..7 above it."""
        bm = bmesh.new()
        vs = [bm.verts.new(Vector(p)) for p in c]
        for idx in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            bm.faces.new([vs[i] for i in idx])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        return new_obj(bm, name)

    def box_corners(size, loc, rot=(0, 0, 0), M=None):
        sx, sy, sz = (v / 2 for v in size)
        R = Euler(rot).to_matrix()
        loc = Vector(loc)
        pts = [loc + R @ Vector(p) for p in ((-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz),
                                             (-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz))]
        return [M @ p for p in pts] if M is not None else pts

    def slope_pt(sg, q, off, y):
        """A point on the roof slope on side sg (+1 or -1): q studs out from the ridge, `off`
        studs square off the rafters' top line."""
        return Vector((sg * (q + S * off / L), y, ZR - q * S + off / L))

    def chamfer(obj, width, along):
        """Knock the long edges off a timber (the ones that run along `along`)."""
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        edges = [e for e in bm.edges if abs((e.verts[1].co - e.verts[0].co).normalized().dot(along)) > 0.99]
        bmesh.ops.bevel(bm, geom=edges, offset=width, segments=1, affect="EDGES", profile=0.5)
        bm.to_mesh(obj.data)
        bm.free()

    class Builder:
        """Collects the parts of one set."""

        def __init__(self, name):
            self.name, self.parts, self.rng = name, [], random.Random(name)

        def add(self, obj, family, key, grain, **kw):
            p = Part(obj, family, key, grain, **kw)
            self.parts.append(p)
            return p

        def box(self, family, key, size, loc, rot=(0, 0, 0), grain=None, M=None, bevel=0.0, **kw):
            corners = box_corners(size, loc, rot, M)
            obj = hexa(corners, key)
            if grain is None:
                grain = "xyz"[max(range(3), key=lambda i: size[i])]
            if isinstance(grain, str):
                axis = {"x": X, "y": Y, "z": Z}[grain]
                g = Euler(rot).to_matrix() @ axis
                if M is not None:
                    g = M.to_3x3() @ g
            else:
                g = grain
            if bevel:
                chamfer(obj, bevel, g.normalized())
            return self.add(obj, family, key, g, **kw)

        def slope_box(self, family, key, sg, q0, q1, y0, y1, off0, off1, grain="q", **kw):
            ring = lambda off: [slope_pt(sg, q, off, y) for q, y in ((q0, y0), (q1, y0), (q1, y1), (q0, y1))]  # noqa: E731
            obj = hexa(ring(off0) + ring(off1), key)
            g = Vector((sg, 0, -S)) if grain == "q" else Y
            return self.add(obj, family, key, g, **kw)

    # ------------------------------------------------------------------ the tin roof
    def tin_roof(b, crest_u):
        """Both slopes as sheets of real corrugation: a rib every RIB studs, crests where the
        tin_roof map has them. Each sheet is a few ribs wide, hangs its own length past the eave
        and has its own tint. Flat underneath."""
        uvs = FAMILIES["tin"]["uv"]
        u0 = tiles["tin"] * crest_u  # UV units: one tile is `tiles` UV units wide
        rng = random.Random("tin")
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        cols = []  # per loop, in face order: (key, factor)

        def face(verts, want, uvmap, shade, smooth=False):
            f = bm.faces.new(verts)
            f.normal_update()
            if f.normal.dot(want) < 0:
                f.normal_flip()
            f.smooth = smooth
            for loop in f.loops:
                i = verts.index(loop.vert)
                loop[uv].uv = uvmap[i]
                cols.append(shade[i])

        for sg, split in ((1, (4, 5, 4, 5, 4, 4)), (-1, (5, 4, 4, 4, 5, 4))):
            n = Vector((sg * S, 0, 1)).normalized()
            down = Vector((sg, 0, -S)).normalized()
            flip = -1.0 if sg > 0 else 1.0  # keeps tangent x bitangent = normal on both slopes
            r0 = 0
            for width in split:
                r1 = r0 + width
                tint = rng.uniform(0.90, 1.0)
                warm = rng.random() < 0.3  # a sheet that has rusted more than its neighbours
                qe = QE + rng.uniform(0.0, 0.2)
                ys = [Y0 + (r0 + k / 2) * RIB for k in range(2 * width + 1)]
                offs = [TIN_MID + (TIN_AMP if k % 2 == 0 else -TIN_AMP) for k in range(2 * width + 1)]
                top_r = [bm.verts.new((0, y, ZR + o * L)) for y, o in zip(ys, offs)]
                top_e = [bm.verts.new(slope_pt(sg, qe, o, y)) for y, o in zip(ys, offs)]
                bot_e = [bm.verts.new(slope_pt(sg, qe, TIN_BOTTOM, y)) for y in ys]
                bot_r = [bm.verts.new((0, ys[0], ZR + TIN_BOTTOM * L)), bm.verts.new((0, ys[-1], ZR + TIN_BOTTOM * L))]
                u = [flip * (y - Y0) / uvs + u0 for y in ys]
                ub = [-flip * (y - Y0) / uvs + u0 for y in ys]  # the underside, seen from below
                v_e = qe * L / uvs
                ridge = ("tin_eave" if warm else "tin", tint)
                eave = ("tin_eave", tint * (0.93 if warm else 1.0))
                under = ("tin_under", tint)
                m = len(ys) - 1
                for k in range(m):
                    face([top_r[k], top_r[k + 1], top_e[k + 1], top_e[k]], n,
                         [(u[k], 0), (u[k + 1], 0), (u[k + 1], v_e), (u[k], v_e)], [ridge, ridge, eave, eave], smooth=True)
                    face([top_e[k], top_e[k + 1], bot_e[k + 1], bot_e[k]], down,
                         [(u[k], v_e), (u[k + 1], v_e), (u[k + 1], v_e + 0.08), (u[k], v_e + 0.08)], [eave] * 4)
                face([bot_r[0], bot_r[1]] + bot_e[::-1], -n,
                     [(ub[0], 0), (ub[m], 0)] + [(ub[k], v_e) for k in range(m, -1, -1)], [under] * (m + 3))
                for k, want in ((0, -Y), (m, Y)):
                    r = bot_r[0] if k == 0 else bot_r[1]
                    face([top_r[k], top_e[k], bot_e[k], r], want,
                         [(u[k], 0), (u[k], v_e), (u[k] + 0.06, v_e), (u[k] + 0.06, 0)], [ridge, eave, eave, ridge])
                r0 = r1
        for e in bm.edges:  # smooth over the ribs, crisp at every edge of a sheet
            if len(e.link_faces) != 2 or e.calc_face_angle(0.0) > 1.2:
                e.smooth = False
        obj = new_obj(bm, "tin_sheets")
        b.add(obj, "tin", None, Y, uv_done=True, jitter=0.0, tints=cols)

        # Ridge cap: two folded plates over the join.
        for sg in (1, -1):
            lo = [Vector((0, y, ZR + 0.44 * L)) if q == 0 else slope_pt(sg, q, 0.44, y)
                  for q, y in ((0, Y0 - 0.04), (0.7, Y0 - 0.04), (0.7, Y1 + 0.04), (0, Y1 + 0.04))]
            hi = [Vector((0, y, ZR + 0.51 * L)) if q == 0 else slope_pt(sg, q, 0.50, y)
                  for q, y in ((0, Y0 - 0.04), (0.7, Y0 - 0.04), (0.7, Y1 + 0.04), (0, Y1 + 0.04))]
            b.add(hexa(lo + hi, "ridge_cap"), "tin", "tin_eave", Vector((sg, 0, -S)), jitter=0.03)

    # ------------------------------------------------------------------ round things
    def ring(b, centre, R, r, nu=12, nv=6):
        """The life ring: a torus facing -y, four faded red bands."""
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        keys = []
        grid = [[bm.verts.new(Vector(centre) + Vector(((R + r * math.cos(2 * math.pi * j / nv)) * math.cos(2 * math.pi * i / nu),
                                                        -r * math.sin(2 * math.pi * j / nv),
                                                        (R + r * math.cos(2 * math.pi * j / nv)) * math.sin(2 * math.pi * i / nu))))
                 for j in range(nv)] for i in range(nu)]
        around = 2 * math.pi * R
        for i in range(nu):
            for j in range(nv):
                quad = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
                f = bm.faces.new([grid[a % nu][c % nv] for a, c in quad])
                f.smooth = True
                for loop, (a, c) in zip(f.loops, quad):
                    loop[uv].uv = (0.12 + c / nv, a / nu * around)  # round the tube stays inside one board
                keys.append("ring_red" if i % 3 == 1 else "ring_white")
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        b.add(new_obj(bm, "life_ring"), "paint", None, X, keys=keys, uv_done=True, jitter=0.0, smooth=True)

    def pyramid(b, family, key, centre, side, height):
        cx, cy, cz = centre
        h = side / 2
        bm = bmesh.new()
        base = [bm.verts.new((cx + sx * h, cy + sy * h, cz)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        tip = bm.verts.new((cx, cy, cz + height))
        bm.faces.new(base[::-1])
        for i in range(4):
            bm.faces.new([base[i], base[(i + 1) % 4], tip])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        b.add(new_obj(bm, key), family, key, Z, jitter=0.0)

    def cleat(b, x, y, z, along="x"):
        """A galvanised horn cleat, 1.2 studs long, standing on z."""
        M = Matrix.Translation((x, y, z)) @ (Matrix.Rotation(math.pi / 2, 4, "Z") if along == "y" else Matrix.Identity(4))
        b.box("metal", "galv", (0.95, 0.34, 0.06), (0, 0, 0.03), M=M, jitter=0.0)
        for sx in (-0.2, 0.2):
            b.box("metal", "galv", (0.14, 0.2, 0.2), (sx, 0, 0.16), M=M, jitter=0.0)
        b.box("metal", "galv", (0.64, 0.22, 0.14), (0, 0, 0.33), M=M, jitter=0.0)
        for sx in (-1, 1):  # the two horns taper
            a, c = 0.32 * sx, 0.62 * sx
            lo = [(a, -0.11, 0.26), (c, -0.06, 0.31), (c, 0.06, 0.31), (a, 0.11, 0.26)]
            hi = [(a, -0.11, 0.40), (c, -0.06, 0.39), (c, 0.06, 0.39), (a, 0.11, 0.40)]
            b.add(hexa([M @ Vector(p) for p in lo + hi], "horn"), "metal", "galv", M.to_3x3() @ X, jitter=0.0)

    # ------------------------------------------------------------------ the boathouse
    def build_boathouse():
        b = Builder("Boathouse")
        rng = b.rng
        px, py = HX - POST / 2, HY - POST / 2
        inner_x, inner_y = HX - POST, HY - POST  # 7.1 and 5.1: the posts' inner faces

        # Floor: deck boards run front to back, their ends ragged at the open front.
        n = 16
        for i in range(n):
            x = -HX + (i + 0.5) * 2 * HX / n
            y_front = -HY - rng.uniform(0.45, 0.7)
            b.box("wood", "floor", (2 * HX / n - 0.06, HY - y_front, 0.18),
                  (x, (HY + y_front) / 2, FLOOR - 0.09 - rng.uniform(0, 0.012)), grain="y", jitter=0.07)
        b.box("wood", "rim", (2 * HX - 0.1, 0.35, 0.22), (0, -HY - 0.2, 0.11), grain="x")
        b.box("wood", "rim", (2 * HX - 0.1, 0.35, 0.22), (0, HY - 0.3, 0.11), grain="x")
        for sx in (-1, 1):
            b.box("wood", "rim", (0.35, 2 * HY - 0.6, 0.22), (sx * (HX - 0.25), -0.25, 0.11), grain="y")

        # Posts: four corners and one in the middle of the back wall.
        for x, y in ((-px, -py), (px, -py), (-px, py), (px, py), (0, HY - 0.7)):
            b.box("wood", "post", (POST, POST, POST_TOP), (x, y, POST_TOP / 2), grain="z", bevel=0.07, foot=True, jitter=0.04)

        # Wall plates on the side posts, tie beams across the front and back.
        for sx in (-1, 1):
            b.box("wood", "beam", (0.5, 13.6, PLATE_TOP - POST_TOP), (sx * (HX - 0.25), -0.3, (PLATE_TOP + POST_TOP) / 2), grain="y")
        b.box("wood", "beam", (2 * HX - 1.0, 0.65, 0.8), (0, -py - 0.1, PLATE_TOP - 0.4), grain="x", bevel=0.07)
        b.box("wood", "beam", (2 * HX - 1.0, 0.5, 0.5), (0, HY - 0.55, PLATE_TOP - 0.25), grain="x")

        # Knee braces: the two that frame the open front, and one along each side wall per corner.
        for sx in (-1, 1):
            b.box("wood", "post", (2.6, 0.5, 0.5), (sx * 6.25, -py - 0.1, 5.6), rot=(0, sx * math.radians(45), 0), grain="x")
            b.box("wood", "beam", (0.35, 2.5, 0.35), (sx * 7.5, -4.3, 5.85), rot=(math.radians(45), 0, 0), grain="y")
            b.box("wood", "beam", (0.35, 2.5, 0.35), (sx * 7.5, 4.3, 5.85), rot=(math.radians(-45), 0, 0), grain="y")

        # Roof frame: ridge beam, rafter pairs (the front pair flies out under the overhang), purlins.
        b.box("wood", "rafter", (0.4, 13.6, 0.6), (0, -0.3, ZR - 0.25), grain="y")
        for y0, y1 in ((-7.12, -6.82), (-5.85, -5.45), (-2.1, -1.7), (1.7, 2.1), (5.25, 5.65)):
            for sg in (1, -1):
                b.slope_box("wood", "rafter", sg, 0.2, QE - 0.2, y0, y1, -0.35, 0.0)
        for q in (0.9, 4.55, 8.15):
            for sg in (1, -1):
                b.slope_box("wood", "rafter", sg, q - 0.125, q + 0.125, -7.12, 6.5, 0.0, TIN_BOTTOM - 0.005, grain="y")

        # The open front truss: king post and two struts.
        b.box("wood", "post", (0.5, 0.5, ZR - 0.55 - PLATE_TOP), (0, -py - 0.1, (ZR - 0.55 + PLATE_TOP) / 2), grain="z")
        a = math.atan2(1.49, 3.15)
        for sx in (-1, 1):
            b.box("wood", "beam", (3.6, 0.35, 0.35), (sx * 1.83, -py - 0.1, 8.2), rot=(0, -sx * a, 0), grain="x")

        # Plank walls on three sides: boards with gaps, silvered outside, browner inside.
        def wall_keys(out):
            return lambda centre, normal: "wall_in" if normal.dot(out) < -0.5 else "wall_out"

        for sx in (-1, 1):  # side walls stop short of the plate: a slot of light under the eave
            n = 10
            for i in range(n):
                y = -inner_y + (i + 0.5) * 2 * inner_y / n
                z0, z1 = rng.uniform(0.08, 0.26), 6.36 + rng.uniform(-0.1, 0.06)
                b.box("wood", "wall_out", (0.2, 2 * inner_y / n - rng.uniform(0.04, 0.09), z1 - z0),
                      (sx * (HX - 0.2 + rng.uniform(-0.02, 0.02)), y, (z0 + z1) / 2), grain="z",
                      keys=wall_keys(Vector((sx, 0, 0))), foot=rng.uniform(0.5, 1.3), jitter=0.08)
            for z in (2.3, 4.6):
                b.box("wood", "beam", (0.3, 2 * inner_y, 0.3), (sx * (HX - 0.45), 0, z), grain="y")
        n = 13  # the back wall runs up into the gable, cut to the roof line
        for i in range(n):
            x0 = -inner_x + i * 2 * inner_x / n + 0.03
            x1 = -inner_x + (i + 1) * 2 * inner_x / n - rng.uniform(0.02, 0.06)
            z0 = rng.uniform(0.08, 0.26)
            ya = HY - 0.25 + rng.uniform(-0.02, 0.02)
            top = lambda x: ZR - max(abs(x), 0.25) * S + TIN_BOTTOM * L - 0.06  # noqa: E731
            lo = [(x0, ya, z0), (x1, ya, z0), (x1, ya + 0.2, z0), (x0, ya + 0.2, z0)]
            hi = [(x0, ya, top(x0)), (x1, ya, top(x1)), (x1, ya + 0.2, top(x1)), (x0, ya + 0.2, top(x0))]
            b.add(hexa(lo + hi, "wall"), "wood", "wall_out", Z, keys=wall_keys(Y), foot=rng.uniform(0.5, 1.3), jitter=0.08)
        for z in (2.3, 4.6):
            for sx in (-1, 1):
                b.box("wood", "beam", (inner_x - 0.45, 0.3, 0.3), (sx * (inner_x + 0.45) / 2, HY - 0.4, z), grain="x")

        tin_roof(b, tin_crest_u())

        # Fascia boards on the front and back rakes, mitred at the ridge.
        for sg in (1, -1):
            for y0, y1 in ((-7.22, -7.12), (6.5, 6.59)):
                ring_at = lambda off: [Vector((0, y, ZR + off * L)) if q == 0 else slope_pt(sg, q, off, y)  # noqa: E731
                                       for q, y in ((0, y0), (QE + 0.05, y0), (QE + 0.05, y1), (0, y1))]
                b.add(hexa(ring_at(-0.34) + ring_at(TIN_BOTTOM - 0.02), "fascia"), "paint", "green_pale", Vector((sg, 0, -S)), jitter=0.04)

        # The life ring on the king post.
        ring(b, (0, -py - 0.1 - 0.25 - 0.2, 8.85), 0.7, 0.2)

        # The canoe rack on the back wall: two uprights, two arms each, one canoe per tier.
        up_y = HY - 0.9 + 0.175  # uprights stand off the wall on the girts
        for dx in (-RACK_ARM_DX, RACK_ARM_DX):
            x = RACK_X + dx
            b.box("wood", "rack", (0.5, 0.35, 6.2), (x, up_y, FLOOR + 3.1), grain="z", jitter=0.03)
            for tier in RACK_TIERS:
                tilt = math.radians(-4)  # the tips sit a little high so a hull cannot slide off
                M = Matrix.Translation((x, up_y - 0.175, tier - 0.2)) @ Matrix.Rotation(tilt, 4, "X")
                b.box("wood", "rack", (0.45, 3.8, 0.4), (0, -1.9, 0), M=M, grain="y", jitter=0.03)
                b.box("wood", "pad", (0.5, 2.7, 0.08), (0, -1.75, 0.24), M=M, grain="y", jitter=0.0)
                b.box("wood", "rack", (0.45, 0.35, 0.6), (0, -3.625, 0.42), M=M, grain="z", jitter=0.03)
                b.box("wood", "rack", (0.3, 1.2, 0.3), (x, up_y - 0.175 - 0.42, tier - 0.72), rot=(math.radians(-37), 0, 0), grain="y", jitter=0.03)

        # The shop corner: a low plank counter and, behind it, the board the Boats shop is drawn on.
        kx = KIOSK_X
        b.box("wood", "core", (4.0, 1.0, 1.84), (kx, -4.1, FLOOR + 0.92), grain="z", jitter=0.0)
        for i in range(4):
            b.box("wood", "counter", (1.0, 0.1, 1.9), (kx - 1.575 + i * 1.05, -4.65, FLOOR + 0.95), grain="z", jitter=0.07)
        for sx in (-1, 1):
            b.box("wood", "counter", (0.1, 1.1, 1.86), (kx + sx * 2.05, -4.1, FLOOR + 0.94), grain="z", jitter=0.07)
        for y in (-4.5, -3.82):
            b.box("wood", "counter_top", (4.58, 0.64, 0.16), (kx, y, FLOOR + 1.98), grain="x", jitter=0.05)
        for sx in (-1, 1):
            b.box("wood", "post", (0.35, 0.35, 5.4), (kx + sx * 2.1, BOARD_Y + 0.38, FLOOR + 2.7), grain="z", jitter=0.03)
        b.box("paint", "core", (4.3, 0.1, 3.3), (kx, BOARD_Y + 0.15, BOARD_Z), grain="x", jitter=0.0)
        for i in (-1, 0, 1):  # three boards, one flat face: 4 wide by 3 tall
            b.box("paint", "green", (4.0, 0.1, 0.97), (kx, BOARD_Y + 0.05, BOARD_Z + i * 1.0 + (0.015 if i > 0 else -0.015 if i < 0 else 0)),
                  grain="x", jitter=0.035)
        for sz in (-1, 1):
            b.box("paint", "cream", (4.5, 0.3, 0.25), (kx, BOARD_Y + 0.07, BOARD_Z + sz * 1.625), grain="x", jitter=0.02)
        for sx in (-1, 1):
            b.box("paint", "cream", (0.25, 0.3, 3.0), (kx + sx * 2.125, BOARD_Y + 0.07, BOARD_Z), grain="z", jitter=0.02)
        b.box("paint", "green", (4.9, 0.6, 0.12), (kx, BOARD_Y + 0.12, BOARD_Z + 1.81), rot=(math.radians(-8), 0, 0), grain="x", jitter=0.0)
        book = Matrix.Translation((kx + 1.1, -4.3, FLOOR + 2.06)) @ Matrix.Rotation(math.radians(12), 4, "Z")
        b.box("paint", "book", (0.74, 0.54, 0.1), (0, 0, 0.05), M=book, grain="x", jitter=0.0)
        b.box("paint", "cream", (0.68, 0.5, 0.07), (0.02, 0, 0.055), M=book, grain="x", jitter=0.0)

        # Two old paddles crossed on the left wall.
        for k, lean in ((0, 20), (1, -20)):
            M = (Matrix.Translation((-(HX - 0.6) + 0.07 + k * 0.15, 0.4, 3.75)) @ Matrix.Rotation(math.radians(lean), 4, "X"))
            b.box("wood", "paddle", (0.13, 0.13, 3.4), (0, 0, 0.5), M=M, grain="z", jitter=0.04)
            b.box("wood", "paddle", (0.07, 0.62, 1.5), (0, 0, -1.9), M=M, grain="z", jitter=0.04)
            b.box("wood", "paddle", (0.13, 0.46, 0.16), (0, 0, 2.26), M=M, grain="y", jitter=0.04)

        # The lantern bracket on the front post by the shop: a timber arm and brace, an iron hook,
        # cap, cage and base. The game puts its own warm glass box and light in the cage.
        lx, ly = px, -6.9
        b.box("wood", "post", (0.3, 1.35, 0.3), (lx, -6.525, 6.05), grain="y", jitter=0.03)
        b.box("wood", "post", (0.22, 1.15, 0.22), (lx, -6.42, 5.52), rot=(math.radians(-41), 0, 0), grain="y", jitter=0.03)
        b.box("metal", "iron", (0.1, 0.1, 0.36), (lx, ly, 5.72), grain="z", jitter=0.0)
        pyramid(b, "metal", "iron", (lx, ly, 5.4), 0.9, 0.22)
        b.box("metal", "iron", (0.9, 0.9, 0.06), (lx, ly, 5.4), grain="x", jitter=0.0)
        for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            b.box("metal", "iron", (0.06, 0.06, 0.87), (lx + sx * 0.37, ly + sy * 0.37, 4.945), grain="z", jitter=0.0)
        b.box("metal", "iron", (0.82, 0.82, 0.12), (lx, ly, 4.45), grain="x", jitter=0.0)

        # A cleat on the deck's front edge, for a painter.
        cleat(b, -4.5, -HY - 0.2, FLOOR)

        info = {
            "body_studs": [2 * HX, round(ZR + 0.51 * L, 2), 2 * HY],
            "pivot": "base centre of the 16 by 12 body (the four corner posts)",
            "floor_top": FLOOR,
            "opening": {"width_between_posts": 2 * inner_x, "clear_height_above_floor": round(PLATE_TOP - 0.8 - FLOOR, 2)},
            "roof": {"ridge_top": round(ZR + 0.51 * L, 2), "eave_underside": round(ZR - QE * S + TIN_BOTTOM / L, 2),
                     "slope_degrees": round(math.degrees(math.atan(S)), 1), "rib_pitch": round(RIB, 3),
                     "x_half": round(QE + 0.2 + S * (TIN_MID + TIN_AMP) / L, 2), "z_front": Y0, "z_back": round(Y1, 2)},
            "faces": {"shop_board": face_info((kx, BOARD_Y, BOARD_Z), 4.0, 3.0)},
            "lantern_glass": {"centre": to_roblox((lx, ly, 4.945)), "size": [0.65, 0.85, 0.65],
                              "note": "the game's own Glass part and PointLight go here, inside the iron cage"},
            "canoe_rack": {
                "arms_at_x": [round(-(RACK_X + d), 2) for d in (RACK_ARM_DX, -RACK_ARM_DX)],
                "berths": [{"centre": to_roblox((RACK_X, 3.4, tier + 0.2)), "rest_height": round(tier + 0.2, 2)} for tier in RACK_TIERS],
                "clear": "each berth takes a hull up to 13 long (along X), 3.4 wide and 2.0 high at the arms (the roof clears 2.3 over the top berth's ends); the arms are 6.6 apart",
            },
            "counter_top": {"centre": to_roblox((kx, -4.16, FLOOR + 2.06)), "size": [4.58, 1.32]},
        }
        return b, info

    def to_roblox(p):
        return [round(-p[0], 3), round(p[2], 3), round(p[1], 3)]

    def face_info(centre, w, h):
        return {"centre": to_roblox(centre), "size": [w, h], "normal": [0, 0, -1],
                "note": "flat, faces the front (-Z); a SurfaceGui part of this size goes 0.02 in front of it"}

    # ------------------------------------------------------------------ the price board
    def build_price_board():
        b = Builder("PriceBoard")
        face_y, face_z = -0.2, 3.1
        b.box("paint", "stain", (1.6, 0.36, 0.2), (0, 0.2, 0.1), grain="x", jitter=0.03)
        b.box("paint", "stain", (0.36, 1.6, 0.17), (0, 0, 0.085), grain="y", jitter=0.03)
        b.box("paint", "stain", (0.45, 0.45, 4.5), (0, 0.2, 2.25), grain="z", bevel=0.05, jitter=0.03)
        pyramid(b, "paint", "stain", (0, 0.2, 4.5), 0.45, 0.22)
        for sx in (-1, 1):
            b.box("paint", "stain", (1.0, 0.2, 0.2), (sx * 0.47, 0.2, 0.62), rot=(0, sx * math.radians(50), 0), grain="x", jitter=0.03)
        b.box("paint", "core", (3.16, 0.1, 2.16), (0, face_y + 0.15, face_z), grain="x", jitter=0.0)
        for sz in (-1, 1):  # two boards, one flat face: 3 wide by 2 tall
            b.box("paint", "green", (3.0, 0.1, 0.98), (0, face_y + 0.05, face_z + sz * 0.51), grain="x", jitter=0.035)
        for sz in (-1, 1):  # a thin cream edge, proud of the face
            b.box("paint", "cream", (3.28, 0.24, 0.14), (0, face_y + 0.06, face_z + sz * 1.07), grain="x", jitter=0.02)
        for sx in (-1, 1):
            b.box("paint", "cream", (0.14, 0.24, 2.0), (sx * 1.57, face_y + 0.06, face_z), grain="z", jitter=0.02)
        info = {
            "pivot": "base centre of the foot (the post stands 0.2 behind it)",
            "faces": {"price": face_info((0, face_y, face_z), 3.0, 2.0)},
            "stands_on": "a MooringFloat: pivot on the deck top (0.78 above the float's base), at the float's (0, 0.78, 1.1)",
        }
        return b, info

    # ------------------------------------------------------------------ the mooring float
    def build_float():
        b = Builder("MooringFloat")
        rng = b.rng
        deck = 0.78
        for sx in (-1, 1):  # two timber pontoons, mostly under water
            b.box("wood", "pontoon", (0.9, 3.7, 0.46), (sx * 1.25, 0, 0.23), grain="y", jitter=0.03)
        for sy in (-1, 1):
            b.box("wood", "rim", (4.0, 0.3, 0.5), (0, sy * 1.85, 0.37), grain="x", jitter=0.04)
        for sx in (-1, 1):
            b.box("wood", "rim", (0.3, 3.38, 0.5), (sx * 1.85, 0, 0.37), grain="y", jitter=0.04)
        n = 5
        for i in range(n):
            y = -2.0 + (i + 0.5) * 4.0 / n
            b.box("wood", "floor", (4.06 + rng.uniform(-0.05, 0.1), 4.0 / n - 0.05, 0.16),
                  (rng.uniform(-0.03, 0.03), y, deck - 0.08 - rng.uniform(0, 0.012)), grain="x", jitter=0.07)
        for sx in (-1, 1):
            for sy in (-1, 1):  # bitts at the corners to take a line
                b.box("wood", "post", (0.42, 0.42, 1.0), (sx * 1.62, sy * 1.62, 0.78), grain="z", bevel=0.05, jitter=0.04)
        cleat(b, 0, -1.25, deck)
        info = {
            "pivot": "base centre",
            "deck_top": deck,
            "float_it": "pivot 0.35 below the water line, so the deck rides 0.43 above the water",
            "cleat": {"centre": to_roblox((0, -1.25, deck + 0.2)), "note": "front edge (-Z), horn along X"},
            "price_board_at": [0, deck, 1.1],
        }
        return b, info

    # ------------------------------------------------------------------ finishing a set
    def shared_faces(name, parts):
        """Warn where two axis-aligned boxes share a face plane and overlap on it: that flickers."""
        boxes = []
        for p in parts:
            me = p.obj.data
            if len(me.polygons) != 6 or any(max(abs(c) for c in poly.normal) < 0.999 for poly in me.polygons):
                continue
            lo = [min(v.co[i] for v in me.vertices) for i in range(3)]
            hi = [max(v.co[i] for v in me.vertices) for i in range(3)]
            boxes.append((p, lo, hi))
        for i, (pa, alo, ahi) in enumerate(boxes):
            for pb, blo, bhi in boxes[i + 1:]:
                for ax in range(3):
                    o1, o2 = (ax + 1) % 3, (ax + 2) % 3
                    area = (max(0.0, min(ahi[o1], bhi[o1]) - max(alo[o1], blo[o1]))
                            * max(0.0, min(ahi[o2], bhi[o2]) - max(alo[o2], blo[o2])))
                    if area < 1e-4:
                        continue
                    for a, c, side in ((alo[ax], blo[ax], "min"), (ahi[ax], bhi[ax], "max")):
                        if ax == 2 and side == "min" and abs(a) < 1e-3:
                            continue  # both stand on the ground
                        if abs(a - c) < 1e-4:
                            print(f"[boathouse] WARNING {name}: {pa.key} and {pb.key} share the {'xyz'[ax]} {side} "
                                  f"face at {a:.3f} over {area:.2f} square studs")

    def damp_foot(p):
        """Wood that stands on the ground gets a darker, damp foot: a cut and a colour step."""
        me = p.obj.data
        zs = [v.co.z for v in me.vertices]
        z0, z1 = min(zs), max(zs)
        p.foot_z = None
        if not p.foot or z1 - z0 < 1.5:
            return
        cut = z0 + min(p.foot if isinstance(p.foot, float) else 1.0, (z1 - z0) * 0.3)
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, cut), plane_no=(0, 0, 1))
        bm.to_mesh(me)
        bm.free()
        p.foot_z = z0 + 0.02

    def project_uv(p, rng):
        """Each flat side is laid out flat at world scale, v along the grain. Narrow parts sit
        inside one board of the map, wide ones start on a groove."""
        me = p.obj.data
        layer = me.uv_layers.get("UVMap") or me.uv_layers.new(name="UVMap")
        fam = FAMILIES[p.family]
        scale, tile = fam["uv"], tiles[p.family] * fam["uv"]
        period = tile / fam["boards"] if fam["boards"] else None
        k = rng.randrange(fam["boards"] or 1)
        v_off = rng.uniform(0, tile)
        groups = {}
        for poly in me.polygons:
            n = poly.normal
            groups.setdefault((round(n.x, 2), round(n.y, 2), round(n.z, 2)), []).append(poly)
        for polys in groups.values():
            n = polys[0].normal.normalized()
            end_grain = abs(n.dot(p.grain)) > 0.92
            ref = p.grain
            if end_grain:
                ref = min((X, Y, Z), key=lambda ax: abs(ax.dot(n)))
            along = (ref - ref.dot(n) * n).normalized()
            across = along.cross(n)
            coords = []
            for poly in polys:
                for li in poly.loop_indices:
                    co = me.vertices[me.loops[li].vertex_index].co
                    coords.append((li, co.dot(across), co.dot(along)))
            u0, u1 = min(c[1] for c in coords), max(c[1] for c in coords)
            if period is None or end_grain:
                u_off = rng.uniform(0, tile)
            elif u1 - u0 <= period * 0.9:
                u_off = (k + 0.5) * period - (u0 + u1) / 2
            else:
                u_off = k * period - u0
            for li, u, v in coords:
                layer.data[li].uv = ((u + u_off) / scale, (v + v_off) / scale)

    def paint_part(p, rng):
        me = p.obj.data
        attr = me.color_attributes.get("Col") or me.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
        lift = FAMILIES[p.family]["lift"]
        shade = 1 + rng.uniform(-p.jitter, p.jitter)
        foot = getattr(p, "foot_z", None)
        li_all = 0
        for poly in me.polygons:
            if p.smooth:
                poly.use_smooth = True
            if callable(p.keys):
                key = p.keys(poly.center, poly.normal)
            elif p.keys:
                key = p.keys[poly.index]
            else:
                key = p.key
            for li in poly.loop_indices:
                f = shade
                if p.tints is not None:
                    key, f = p.tints[li_all]
                    li_all += 1
                if foot is not None and me.vertices[me.loops[li].vertex_index].co.z <= foot:
                    f *= 0.74
                attr.data[li].color = tuple(srgb_to_linear(min(255.0, c * f * lift)) for c in PAL[key]) + (1.0,)

    def anchors(obj, lo, hi, lift):
        me = obj.data
        bm = bmesh.new()
        bm.from_mesh(me)
        e = ANCHOR
        made = [
            bm.faces.new([bm.verts.new(lo), bm.verts.new(lo + Vector((e, 0, 0))), bm.verts.new(lo + Vector((0, e, 0)))]),
            bm.faces.new([bm.verts.new(hi), bm.verts.new(hi - Vector((e, 0, 0))), bm.verts.new(hi - Vector((0, e, 0)))]),
        ]
        bm.faces.index_update()
        idx = [f.index for f in made]
        bm.to_mesh(me)
        bm.free()
        col = tuple(srgb_to_linear(min(255.0, c * lift)) for c in PAL["rim"]) + (1.0,)
        for i in idx:
            for li in me.polygons[i].loop_indices:
                me.color_attributes["Col"].data[li].color = col

    def outward(p):
        """Roblox draws one side of a face: every part's faces must point out (a positive volume)."""
        vol = 0.0
        for poly in p.obj.data.polygons:
            vol += poly.center.dot(poly.normal) * poly.area
        return vol > 0

    def finish_set(b, info):
        """UVs and colours on every part, then one mesh per family, all sharing the set's box."""
        name, rng = b.name, b.rng
        shared_faces(name, b.parts)
        inside_out = [p.obj.name for p in b.parts if not outward(p)]
        if inside_out:
            raise SystemExit(f"{name}: faces point inward on {inside_out}")
        for p in b.parts:
            damp_foot(p)
            if not p.uv_done:
                project_uv(p, rng)
            paint_part(p, rng)
        bpy.context.view_layer.update()
        lo, hi = bounds([p.obj for p in b.parts])
        if abs(lo.z) > 1e-4:
            raise SystemExit(f"{name}: the base is at {lo.z:.4f}, not 0")
        hx, hy = max(-lo.x, hi.x), max(-lo.y, hi.y)  # the box is made even about the pivot
        lo, hi = Vector((-hx, -hy, 0.0)), Vector((hx, hy, hi.z))
        used = {}
        out = {}
        for fam in MESHES[name]:
            members = [p for p in b.parts if p.family == fam]
            keys = set()
            for p in members:
                if p.tints is not None:
                    keys |= {k for k, _ in p.tints}
                elif callable(p.keys):
                    keys |= {"wall_out", "wall_in"}
                elif p.keys:
                    keys |= set(p.keys)
                else:
                    keys.add(p.key)
            used[fam] = sorted(keys)
            objs = [p.obj for p in members]
            for o in objs:
                o.data.materials.clear()
            obj = common.join(objs, f"{name}_{fam}") if len(objs) > 1 else objs[0]
            obj.name = obj.data.name = f"{name}_{fam}"
            obj.data.color_attributes.active_color = obj.data.color_attributes["Col"]
            obj.data.color_attributes.render_color_index = obj.data.color_attributes.find("Col")
            if not args.no_anchors:
                anchors(obj, lo, hi, FAMILIES[fam]["lift"])
            obj.data.update()
            obj["parts"] = len(members)
            out[fam] = obj
        stray = {p.family for p in b.parts} - set(MESHES[name])
        if stray:
            raise SystemExit(f"{name}: parts in families it does not export: {stray}")
        info["studs"] = [round(2 * hx, 2), round(hi.z, 2), round(2 * hy, 2)]
        info["keys"] = used
        return out, info

    # ------------------------------------------------------------------ export
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
            "parts": int(obj["parts"]),
            "colours_converted": n,
            "glb": str(path.relative_to(REPO)).replace("\\", "/"),
            "roblox_glb": str((ROBLOX / path.name).relative_to(REPO)).replace("\\", "/"),
        }

    # ------------------------------------------------------------------ preview
    def setup_cycles(w, h, sun_rot=(50, 10, 35), sun_rgb=(1.0, 0.96, 0.88), sun_energy=3.6,
                     sky=(0.80, 0.88, 1.0), sky_strength=0.8, exposure=-0.45, horizon=None):
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
        nt = world.node_tree
        bg = nt.nodes["Background"]
        bg.inputs[0].default_value = tuple(sky) + (1.0,)
        bg.inputs[1].default_value = sky_strength
        if horizon is not None:  # a low-sun sky: warm at the horizon, blue overhead
            geo = nt.nodes.new("ShaderNodeNewGeometry")
            sep = nt.nodes.new("ShaderNodeSeparateXYZ")
            ramp = nt.nodes.new("ShaderNodeValToRGB")
            nt.links.new(geo.outputs["Incoming"], sep.inputs[0])
            nt.links.new(sep.outputs["Z"], ramp.inputs[0])
            ramp.color_ramp.elements[0].position = 0.0
            ramp.color_ramp.elements[0].color = tuple(horizon) + (1.0,)
            ramp.color_ramp.elements[1].position = 0.45
            ramp.color_ramp.elements[1].color = tuple(sky) + (1.0,)
            nt.links.new(ramp.outputs[0], bg.inputs[0])
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

    def flat(name, rgb, rough=0.95, emit=0.0, metal=0.0):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        lin = tuple(srgb_to_linear(c) for c in rgb) + (1.0,)
        bsdf.inputs["Base Color"].default_value = lin
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        if emit:
            bsdf.inputs["Emission Color"].default_value = lin
            bsdf.inputs["Emission Strength"].default_value = emit
        return m

    preview_cache = {}

    def preview_material(fam):
        """What the game shows: vertex colour times the family's colour map (neutral, or the
        tin's own colours), with its normal and roughness maps, one tile every StudsPerTile UV units."""
        if fam in preview_cache and preview_cache[fam].name in bpy.data.materials:
            return preview_cache[fam]
        m = bpy.data.materials.new(f"Preview_{fam}")
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        slug = FAMILIES[fam]["slug"]
        if slug is None:  # stock Metal
            nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
            bsdf.inputs["Metallic"].default_value = 0.6
            bsdf.inputs["Roughness"].default_value = 0.5
        else:
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

            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs[0].default_value = 1.0
            nt.links.new(tex(FAMILIES[fam]["map"], False).outputs[0], mix.inputs[6])
            nt.links.new(vc.outputs["Color"], mix.inputs[7])
            nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
            nt.links.new(tex("rough", True).outputs[0], bsdf.inputs["Roughness"])
            nmap = nt.nodes.new("ShaderNodeNormalMap")
            nmap.uv_map = "UVMap"
            nt.links.new(tex("normal", True).outputs[0], nmap.inputs["Color"])
            nt.links.new(nmap.outputs[0], bsdf.inputs["Normal"])
            if fam == "tin":
                bsdf.inputs["Metallic"].default_value = 0.35
        preview_cache[fam] = m
        return m

    def dress(objs):
        for fam, obj in objs.items():
            obj.data.materials.clear()
            obj.data.materials.append(preview_material(fam))

    def stage(obj, kind="set"):
        obj["_stage"] = kind
        return obj

    def stage_box(size, loc, material, kind="shot"):
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
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
        print(f"[boathouse] rendered {path}")

    def shoot_three_quarter(objs, path, view=(-32, 26), px=1024, pad=1.12, ground_rgb=(150, 150, 146)):
        cam, _ = setup_cycles(px, px)
        bpy.context.view_layer.update()
        lo, hi = bounds(objs)
        centre = (lo + hi) / 2
        size = (hi - lo).length
        bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=size * 1.5, depth=0.01, location=(centre.x, centre.y, lo.z - 0.005))
        g = stage(bpy.context.object, "shot")
        g.data.materials.append(flat("Ground", ground_rgb))
        yaw, pitch = (math.radians(v) for v in view)
        d = Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
        aim(cam, centre + d * size * 3, centre, ortho=max(size * 0.9, max(hi - lo) * pad), clip=size * 12)
        render(path)

    def lantern_standin(at, kind="set"):
        """The game's glass box and its light, so the previews show the bracket lit."""
        glass = stage_box((0.65, 0.85, 0.65), at, flat("LanternGlass", LANTERN, rough=0.3, emit=6.0), kind)
        light = bpy.data.objects.new("LanternLight", bpy.data.lights.new("LanternLight", "POINT"))
        light.data.energy = 900
        light.data.color = tuple(srgb_to_linear(c) for c in LANTERN)
        light.data.shadow_soft_size = 0.3
        light.location = at
        scene_of().collection.objects.link(light)
        stage(light, kind)
        return glass, light

    def golden_stage():
        """A stand-in for the place: a dock-height deck under the shed, lake water, a far bank."""
        water = bpy.data.materials.new("Water")
        water.use_nodes = True
        nt = water.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = tuple(srgb_to_linear(c) for c in (26, 66, 62)) + (1.0,)
        bsdf.inputs["Roughness"].default_value = 0.06
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 0.35
        noise.inputs["Detail"].default_value = 3.0
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.12
        nt.links.new(noise.outputs[0], bump.inputs["Height"])
        nt.links.new(bump.outputs[0], bsdf.inputs["Normal"])
        bpy.ops.mesh.primitive_plane_add(size=1200, location=(0, 0, -1.5))
        bpy.context.object.data.materials.append(water)
        stage(bpy.context.object)
        timber = flat("StageDeck", (122, 104, 86))
        dark = flat("StagePile", (84, 72, 60))
        stage_box((30, 15.5, 0.4), (3, 0.4, -0.2), timber, "set")       # the deck the shed stands on
        stage_box((5, 22, 0.4), (-9.5, -18.5, -0.2), timber, "set")     # a walkway out to the slips
        for x, y in ((-11.5, -8), (-7.5, -8), (-11.5, -18), (-7.5, -18), (-11.5, -29), (-7.5, -29), (17.5, -7), (17.5, 8), (-11.5, 8)):
            bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.45, depth=5.2, location=(x, y, -1.6))
            bpy.context.object.data.materials.append(dark)
            stage(bpy.context.object)
        bank = flat("Bank", (74, 92, 54))
        stage_box((600, 90, 3), (0, 95, -1.6), bank, "set")
        pine = flat("Pine", (38, 62, 46))
        rng = random.Random(7)
        for i in range(46):
            x = -230 + i * 10 + rng.uniform(-3, 3)
            h = rng.uniform(26, 44)
            bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=h * 0.2, radius2=0, depth=h, location=(x, 62 + rng.uniform(0, 40), h / 2))
            bpy.context.object.data.materials.append(pine)
            stage(bpy.context.object)

    def canoe_proxy(at):
        """A plain block the size of the canoe the other modeler is building (12 by 3), to prove
        the rack fits. Stage only: never exported."""
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, location=at)
        o = bpy.context.object
        o.scale = (6.0, 1.5, 0.7)
        o.data.materials.append(flat("CanoeProxy", (188, 120, 66), rough=0.5))
        return stage(o)

    def build_all():
        common.reset()
        preview_cache.clear()
        sets = {}
        for name, fn in (("Boathouse", build_boathouse), ("PriceBoard", build_price_board), ("MooringFloat", build_float)):
            objs, info = finish_set(*fn())
            sets[name] = (objs, info)
        return sets

    def copy_set(objs, loc, yaw=0.0):
        out = []
        for o in objs.values():
            c = o.copy()
            c.location = loc
            c.rotation_euler = (0, 0, yaw)
            scene_of().collection.objects.link(c)
            out.append(stage(c))
        return out

    def scene_composed(with_proxy=False):
        """The three sets as they might stand at the slips: the shed on its deck, two sales
        moorings on the water in front, each with its price board."""
        sets = build_all()
        for objs, _ in sets.values():
            dress(objs)
        house = sets["Boathouse"][0]
        board, floats = sets["PriceBoard"][0], sets["MooringFloat"][0]
        for (x, y, yaw) in ((-18.0, -13.3, -0.5), (0.5, -22.5, -0.85)):
            copy_set(floats, (x, y, -1.5 - 0.35), yaw)
            c, s = math.cos(yaw), math.sin(yaw)
            copy_set(board, (x - 1.1 * s, y + 1.1 * c, -1.5 - 0.35 + 0.78), yaw)
        for o in list(board.values()) + list(floats.values()):
            o.hide_render = True
        golden_stage()
        lantern_standin((HX - POST / 2, -6.9, 4.945))
        if with_proxy:
            canoe_proxy((RACK_X, 3.4, RACK_TIERS[1] + 0.2 + 0.7))
        return house

    GOLDEN = dict(sun_rot=(74, 0, -58), sun_rgb=(1.0, 0.82, 0.60), sun_energy=5.0, sky=(0.45, 0.60, 0.86), sky_strength=0.9,
                  exposure=0.0, horizon=(1.0, 0.80, 0.58))

    # ------------------------------------------------------------------ run
    for d in (MODELS, ROBLOX, PREVIEWS, SCRATCH, out_dir):
        d.mkdir(parents=True, exist_ok=True)

    sets = build_all()
    result = {"sets": {}}
    for name, (objs, info) in sets.items():
        entry = dict(info)
        entry["meshes"] = {}
        for fam, obj in objs.items():
            entry["meshes"][fam] = export(obj)
            print(f"[boathouse] {obj.name}: {entry['meshes'][fam]['triangles']} triangles")
        total = sum(m["triangles"] for m in entry["meshes"].values())
        if total > BUDGET[name]:
            raise SystemExit(f"{name}: {total} triangles is over the {BUDGET[name]} budget")
        entry["triangles"] = total
        result["sets"][name] = entry
    (SCRATCH / "result.json").write_text(json.dumps(result, indent=1), encoding="utf-8")
    if args.no_render:
        return

    def want(v):
        return not views or v in views

    if want("hero") or want("pieces"):
        for name in SETS:
            if name == "Boathouse" and not want("hero"):
                continue
            if name != "Boathouse" and not want("pieces"):
                continue
            sets = build_all()
            for other, (objs, _) in sets.items():
                if other != name:
                    for o in objs.values():
                        bpy.data.objects.remove(o, do_unlink=True)
            objs = sets[name][0]
            dress(objs)
            if name == "Boathouse":
                lantern_standin((HX - POST / 2, -6.9, 4.945), "set")
                shoot_three_quarter(list(objs.values()), out_dir / "Boathouse.png", view=(-34, 30))
            else:
                shoot_three_quarter(list(objs.values()), out_dir / f"{name}.png", view=(-30, 24), pad=1.3)

    if want("golden") or want("front") or want("ingame") or want("back") or want("high") or want("inside") or "eave" in views:
        scene_composed()
        if want("golden"):  # the reference's corner of the shed, across the water at golden hour
            cam, _ = setup_cycles(1600, 900, **GOLDEN)
            aim(cam, (-30.0, -36.0, 3.0), (0.0, -2.0, 5.0), fov=36)
            render(out_dir / "golden.png")
        if want("high"):  # the high three-quarter, same light
            cam, _ = setup_cycles(1600, 900, **GOLDEN)
            aim(cam, (-24.0, -30.0, 24.0), (-1.0, -3.0, 4.0), fov=36)
            render(out_dir / "golden-high.png")
        if want("front"):  # a player on the deck in front of the open side, noon
            cam, _ = setup_cycles(1600, 900)
            aim(cam, (0.5, -19.0, 5.2), (0.5, 0.0, 4.4), fov=70)
            render(out_dir / "front.png")
        if want("ingame"):  # from the dock walkway 45 studs off, Roblox's default 70 degree view
            cam, _ = setup_cycles(1600, 900)
            aim(cam, (-12.0, -45.0, 6.5), (0.0, 0.0, 4.5), fov=70)
            render(out_dir / "ingame.png")
        if want("inside"):  # inside the shed, looking at the rack on the back wall
            cam, _ = setup_cycles(1280, 720)
            aim(cam, (-5.5, -4.5, 5.0), (-0.5, 5.0, 3.6), fov=70)
            render(out_dir / "inside.png")
        if "eave" in views:  # scratch only: do the map's ribs sit on the roof's real ribs?
            cam, _ = setup_cycles(1280, 720)
            aim(cam, (-14.0, -11.5, 8.6), (-6.5, -4.5, 8.4), fov=24)
            render(out_dir / "eave.png")
        if want("back"):  # round the back, to see the unseen sides honestly
            cam, _ = setup_cycles(1280, 720)
            aim(cam, (16.0, 24.0, 9.0), (0.0, 0.0, 5.0), fov=50)
            render(out_dir / "back.png")

    if want("fit"):  # scratch only: a 12 by 3 block on the top berth, to prove the rack's size
        scene_composed(with_proxy=True)
        cam, _ = setup_cycles(1280, 720)
        aim(cam, (-4.0, -15.0, 5.4), (-1.0, 3.0, 4.6), fov=55)
        render(out_dir / "fit.png")


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

    # Check what was written, then record it. Only this script's own manifest entries are touched.
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    own = {f"{name}_{fam}" for name, fams in MESHES.items() for fam in fams}
    for key in [k for k in manifest if k in own]:
        del manifest[key]
    for name, entry in result["sets"].items():
        for fam, mesh in entry["meshes"].items():
            for sub in ("glb", "roblox_glb"):
                size, tris = check_glb(REPO / mesh[sub], entry["studs"], not args.no_anchors)
            if tris != mesh["triangles"]:
                raise SystemExit(f"{name}_{fam}: {tris} triangles in the file, {mesh['triangles']} in Blender")
            f = FAMILIES[fam]
            if f["variant"] is None:
                wears = "no family of ours: stock Metal (dark iron and galvanised steel are in the vertex colours)"
            elif f["map"] == "color":
                wears = (f"MaterialVariant {f['variant']} (the tin_roof COLOUR map, with its rust). Vertex colours are near "
                         f"white and only tint it")
            else:
                wears = (f"MaterialVariant {f['variant']} with its NEUTRAL colour map, normal and roughness. Vertex colours "
                         f"stored {f['lift']:g} times the colour wanted")
            extra = {k: v for k, v in entry.items() if k not in ("meshes", "keys", "studs", "triangles")}
            manifest[f"{name}_{fam}"] = {
                "name": f"{name}_{fam}",
                "studs": size,
                "triangles": tris,
                "parts": mesh["parts"],
                "replaces": {"Boathouse": "Nothing: new for N4, the shed at the dock slips",
                             "PriceBoard": "Nothing: new for N4, one per boat for sale",
                             "MooringFloat": "Nothing: new for N4, one per boat for sale"}[name],
                "notes": (f"Layer B, {fam} family: {wears}. UVs at {f['uv']:g} studs per UV unit. Upload "
                          f"art/models/roblox/{name}_{fam}.glb. Every mesh of the set goes at the same CFrame: pivot at the base "
                          f"centre, front along -Z. The set is {entry['triangles']} triangles in all."),
                "family": fam,
                "variant": f["slug"],
                "uv_studs": f["uv"],
                "lift": f["lift"],
                "set": name,
                "set_triangles": entry["triangles"],
                "palette_seen_rgb": {k: list(PAL[k]) for k in entry["keys"][fam]},
                "placing": extra,
            }
            print(f"{name}_{fam}: {size} studs, {tris} triangles")
        print(f"{name}: {entry['triangles']} triangles of {BUDGET[name]}")
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
            im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
        im.save(dst, optimize=True)

    names = {"Boathouse.png": "Boathouse.png", "golden.png": "Boathouse-golden.png", "golden-high.png": "Boathouse-high.png",
             "front.png": "Boathouse-front.png", "ingame.png": "Boathouse-ingame.png", "back.png": "Boathouse-back.png",
             "inside.png": "Boathouse-inside.png",
             "PriceBoard.png": "PriceBoard.png", "MooringFloat.png": "MooringFloat.png"}
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
    sheet("The boathouse set (N4): Layer B meshes under the family maps",
          f"Rendered as the game shows them: vertex colour times each family's map. Triangles: {tri}. Deck, water and trees are a stage, not part of the set.",
          [[("Reference (extra context, not orders)", REFERENCE), ("Golden hour, across the water", out_dir / "golden.png")],
           [("High three-quarter, golden hour", out_dir / "golden-high.png"), ("A player in front of the open side, noon, 70 degree view", out_dir / "front.png")],
           [("From the dock walkway, 45 studs, 70 degree view", out_dir / "ingame.png"), ("Round the back", out_dir / "back.png")]],
          PREVIEWS / "boathouse_set.png")
    before = SCRATCH / "before"
    if (before / "golden.png").exists():
        sheet("Boathouse: first pass and final",
              "Left: the first build, under a flat first-try sky. Right: after the fixes named in the modeler's report, with the stage re-lit and re-framed.",
              [[("First pass, golden hour", before / "golden.png"), ("Final, golden hour", out_dir / "golden.png")],
               [("First pass, high three-quarter", before / "golden-high.png"), ("Final, high three-quarter", out_dir / "golden-high.png")]],
              PREVIEWS / "Boathouse-before-after.png")


if __name__ == "__main__":
    if IN_BLENDER:
        blender_main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    else:
        driver_main()
