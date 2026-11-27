"""The two market stands, split by material family for Layer B of the look kit.

Layer B (docs/superpowers/plans/2026-11-27-leg-3.md, "The look kit"): a MaterialVariant of
ours on a mesh that keeps its vertex colours for hue. Each stand is exported as up to three
meshes, one per family:

    <Stand>_wood     posts, counter, frame, sign board, shelves, small props   weathered_plank
    <Stand>_canvas   the striped awning and its scalloped valance               canvas
    <Stand>_metal    the scale, the ice chest, the minnow bucket, spinners      no family of ours yet

The layout comes from the old builders (stands.py, bait_shop.py, fish_buyer.py): this script
runs them, keeps the parts that are fine, swaps the slab parts for boards and the slat awning
for a cloth one, then gives every part a family, a colour, and UVs.

What the game does with these (proven in Studio, 11/27/2026):
  * the variant's colour map MULTIPLIES the vertex colour, so the hue stays. Our neutral maps
    have a mean of 0.80, so every vertex colour is stored 1.25 times lighter than the colour
    we want to see (--lift), clamped at white;
  * the variant's textures follow the mesh UVs, so every face gets a projection at world scale:
    1 UV unit = 1 stud by default (--uv-studs), wood grain along each board's long axis.

Every mesh of a stand shares the stand's pivot (bottom centre of the whole stand) and, through
two specks at opposite corners (--no-anchors turns them off), the whole stand's bounding box.
So each one drops in at the old model's CFrame, whichever way the importer finds its centre.

    python art/scripts/stands_split.py                    build, export, render, sheet
    python art/scripts/stands_split.py --uv-studs 8       1 UV unit = 8 studs on every mesh
    python art/scripts/stands_split.py --uv-studs wood=8,canvas=3
    python art/scripts/stands_split.py --no-metal         fold the metal parts into the wood mesh
    python art/scripts/stands_split.py --no-render        models only
    blender -b -P art/scripts/stands_split.py -- --no-render      (the Blender half on its own)

Writes art/models/<Stand>_<family>.glb (linear colours, as Blender wants them),
art/models/roblox/<Stand>_<family>.glb (display colours, the copy to upload),
art/previews/<Stand>_split.png, art/previews/stands_split-ingame.png and the sheet
art/previews/stands_split.png. Scratch renders go to artifacts/stands_split/. Only this
script's own entries in art/models/manifest.json are touched.
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
SCRATCH = REPO / "artifacts" / "stands_split"
MANIFEST = MODELS / "manifest.json"
BLENDER = os.environ.get("BLENDER", r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe")

try:
    import bpy  # noqa: F401

    IN_BLENDER = True
except ModuleNotFoundError:
    IN_BLENDER = False

FAMILIES = ("wood", "canvas", "metal")
# Which of our material families each mesh wears (art/textures/<family>/). None: no family of
# ours yet, the game uses a built-in material until tin roof or aluminium is made.
VARIANT = {"wood": "weathered_plank", "canvas": "canvas", "metal": None}
# weathered_plank_neutral.png has five boards across one tile: the dark gaps sit at columns
# 0, 102, 204, 307 and 409 of 512 (the driver checks this). Parts are slid across the grain
# so a narrow part sits inside one board and a wide one starts on a gap.
PLANK_BOARDS_PER_TILE = 5
ANCHOR = 0.02  # side of the corner specks, studs

# ---------------------------------------------------------------------------------------
# Palette: the colours we want to SEE in the game (sRGB 0..255), before the lift.
# Home lake, Real-ish: dock timber 122,104,86 silver-brown; no saturated primaries.
# ---------------------------------------------------------------------------------------
SHARED = {
    "timber": (122, 104, 86),        # the dock timber: rails, rafters, crate
    "timber_dark": (97, 83, 69),     # posts and sign backing
    "timber_light": (150, 132, 110),  # counter boards
    "top": (108, 93, 78),            # counter top, worn by hands and bait tubs
    "core": (56, 49, 43),            # the dark seen through the gaps between boards
    "cork": (172, 144, 108),
    "whitewash": (204, 198, 184),
    "canvas_white": (204, 197, 178),  # warm off-white; 204 is as light as the neutral map lets it be
    "iron": (70, 72, 76),
    "galv": (138, 143, 145),
    "steel": (186, 188, 192),
    "enamel": (214, 210, 198),
    "ice": (208, 224, 230),
}
STANDS = {
    "BaitShopStand": {
        "module": "bait_shop",
        "accent": "shop",
        "old_studs": (14.32, 11.9, 6.11),
        "roblox_xz": (18.0, 96.5),
        "replaces": "BaitShopStand (the one-mesh vertex-colour stand in Lake.Art): same size, pivot and orientation",
        "palette": {
            "paint": (78, 112, 136),        # weathered lake blue: sign board and counter rail
            "paint_pale": (134, 153, 160),   # the same paint, sun-bleached, on the back wall
            "stripe": (88, 121, 146),        # awning stripe
            "rod_willow": (112, 88, 62),
            "rod_glass": (192, 170, 96),
            "rod_graphite": (54, 57, 64),
            "tub_a": (86, 105, 126),
            "tub_b": (172, 146, 98),
            "tub_c": (80, 120, 130),
            "bait_worm": (156, 106, 98),
            "bait_cricket": (92, 74, 48),
            "bait_minnow": (150, 180, 188),
            "pack_a": (112, 86, 126),
            "pack_b": (88, 132, 98),
            "pack_c": (168, 94, 74),
            "water": (70, 112, 122),
        },
    },
    "FishBuyerStand": {
        "module": "fish_buyer",
        "accent": "sell",
        "old_studs": (12.05, 12.8, 6.11),
        "roblox_xz": (-18.0, 96.5),
        "replaces": "FishBuyerStand (the one-mesh vertex-colour stand in Lake.Art): same size, pivot and orientation",
        "palette": {
            "paint": (186, 152, 92),        # weathered ochre
            "paint_pale": (200, 184, 146),
            "paint_deep": (170, 128, 66),    # the carved fish over the sign
            "stripe": (196, 162, 100),
            "needle": (158, 54, 44),
            "fish_a": (188, 168, 92),
            "fish_b": (94, 118, 74),
            "fish_c": (86, 112, 134),
        },
    },
}


def parse_args(argv):
    ap = argparse.ArgumentParser(description="Split the two market stands by material family (Layer B).")
    ap.add_argument("--uv-studs", default="1",
                    help="studs per UV unit: one number for every mesh, or wood=8,canvas=3 (default 1)")
    ap.add_argument("--lift", default="wood=1.25,canvas=1.25,metal=1.0",
                    help="how much lighter than the target each family's vertex colours are stored")
    ap.add_argument("--no-metal", action="store_true", help="two meshes per stand: metal parts join the wood mesh")
    ap.add_argument("--no-anchors", action="store_true", help="leave out the two bounding-box specks per mesh")
    ap.add_argument("--no-render", action="store_true", help="build and export only")
    ap.add_argument("--compose-only", action="store_true", help="rebuild the sheet from the renders already made")
    ap.add_argument("--samples", type=int, default=int(os.environ.get("ART_SAMPLES", "64")))
    ap.add_argument("--px", type=int, default=1024, help="side of the three-quarter previews")
    args = ap.parse_args(argv)
    args.uv = per_family(args.uv_studs, 1.0)
    args.lifts = per_family(args.lift, 1.0)
    return args


def per_family(text, default):
    out = {f: default for f in FAMILIES}
    text = str(text).strip()
    if "=" not in text:
        return {f: float(text) for f in FAMILIES}
    for item in text.split(","):
        k, v = item.split("=")
        if k.strip() not in out:
            raise SystemExit(f"unknown family {k!r}; use one of {', '.join(FAMILIES)}")
        out[k.strip()] = float(v)
    return out


def family_tiles():
    """Studs per tile of each family's maps, from the texture table (8 for planks, 3 for canvas)."""
    table = json.loads((HERE / "texture_families.json").read_text(encoding="utf-8"))["families"]
    return {fam: float(table[slug]["studs_per_tile"]) if slug else 1.0 for fam, slug in VARIANT.items()}


# =======================================================================================
# Blender half
# =======================================================================================

def blender_main(argv):
    import bmesh
    import bpy
    from mathutils import Matrix, Vector

    sys.path.insert(0, str(HERE))
    import common
    from common import bounds, box, cyl, srgb_to_linear
    import roblox_colors
    import stands as old_frame

    args = parse_args(argv)
    tiles = family_tiles()
    scene_of = lambda: bpy.context.scene  # noqa: E731
    CW, CD, CH = old_frame.COUNTER  # counter: width (x), depth (y), height (z)

    class Part:
        def __init__(self, obj, family, key, grain=None, keys=None, weather=True, uv_done=False, jitter=0.05):
            self.obj, self.family, self.key, self.keys = obj, family, key, keys
            self.weather, self.uv_done, self.jitter = weather, uv_done, jitter
            # Grain: a world direction. Default is the part's longest side.
            rot = obj.matrix_world.to_3x3().normalized()
            if grain is None:
                d = obj.dimensions
                grain = "xyz"[max(range(3), key=lambda i: d[i])]
            axis = {"x": Vector((1, 0, 0)), "y": Vector((0, 1, 0)), "z": Vector((0, 0, 1))}[grain]
            self.grain = (rot @ axis).normalized()
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    def near(a, b, tol=0.02):
        return all(abs(x - y) <= tol for x, y in zip(a, b))

    # ------------------------------------------------------------------ the cloth awning
    def cloth_awning(stripe_key):
        """One sagging sheet and a scalloped valance in place of the ten slats and ten discs.
        Top surface, eave height (about 8.45 to 8.66), front (y = -3.4), back and the 7.75 the
        scallops hang to are the old awning's, so the painted sign still hangs where it did."""
        a = 0.28
        ca, sa = math.cos(a), math.sin(a)
        cy, cz = -0.3, 9.4
        thick, top = 0.10, 0.125
        n_stripes, sub, rows = 10, 2, 6
        s_front = -3.1
        y_back = cy + 3.1 * ca + 0.125 * sa  # the old slats' rearmost point: the stand's back edge
        s_back = (y_back - cy + (top - thick) * sa) / ca

        def pt(x, s, off):
            return Vector((x, cy + s * ca - off * sa, cz + s * sa + off * ca))

        def sag(x, s):  # held by the rafters at x = 0 and +-4.7, slack between them
            q = (s - s_front) / (s_back - s_front)
            return 0.11 * math.sin(math.pi * q) * (0.3 + 0.7 * math.sin(math.pi * x / 4.7) ** 2)

        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        keys = []

        def face(verts, uvs, key, smooth=False):
            f = bm.faces.new(verts)
            f.smooth = smooth
            for loop, t in zip(f.loops, uvs):
                loop[uv].uv = t
            keys.append(key)

        def stripe(i):
            return stripe_key if i % 2 == 0 else "canvas_white"

        nx = n_stripes * sub
        xs = [-5.25 + 10.5 * i / nx for i in range(nx + 1)]
        ss = [s_front + (s_back - s_front) * j / rows for j in range(rows + 1)]
        topv = [[bm.verts.new(pt(x, s, top - sag(x, s))) for x in xs] for s in ss]
        botv = [[bm.verts.new(pt(x, s, top - thick - sag(x, s))) for x in xs] for s in ss]
        for j in range(rows):
            for i in range(nx):
                k = stripe(i // sub)
                t = [(xs[i], ss[j]), (xs[i + 1], ss[j]), (xs[i + 1], ss[j + 1]), (xs[i], ss[j + 1])]
                face([topv[j][i], topv[j][i + 1], topv[j + 1][i + 1], topv[j + 1][i]], t, k, smooth=True)
                face([botv[j][i], botv[j + 1][i], botv[j + 1][i + 1], botv[j][i + 1]], [t[0], t[3], t[2], t[1]], k, smooth=True)
        for i in range(nx):  # front and back edges of the sheet
            k = stripe(i // sub)
            for j, order in ((0, (0, 1)), (rows, (1, 0))):
                p, q = i + order[0], i + order[1]
                face([topv[j][p], botv[j][p], botv[j][q], topv[j][q]],
                     [(xs[p], ss[j]), (xs[p], ss[j] - thick), (xs[q], ss[j] - thick), (xs[q], ss[j])], k)
        for j in range(rows):  # the two side edges
            face([topv[j + 1][0], botv[j + 1][0], botv[j][0], topv[j][0]],
                 [(ss[j + 1], 0), (ss[j + 1], thick), (ss[j], thick), (ss[j], 0)], stripe(0))
            face([topv[j][nx], botv[j][nx], botv[j + 1][nx], topv[j + 1][nx]],
                 [(ss[j], 0), (ss[j], thick), (ss[j + 1], thick), (ss[j + 1], 0)], stripe(n_stripes - 1))

        # Valance: hangs from the eave, one scallop per stripe.
        seg = 6
        z_top, z_edge, drop = 8.66, 8.15, 0.40
        yf, yb = -3.4, -3.3
        half = 10.5 / n_stripes / 2
        cols = []
        for i in range(n_stripes):
            xc = -5.25 + (i + 0.5) * 2 * half
            for k in range(seg + (1 if i == n_stripes - 1 else 0)):
                x = xc - half + 2 * half * k / seg
                r = (x - xc) / half
                cols.append((x, z_edge - drop * math.sqrt(max(0.0, 1 - r * r)), i))
        ft = [bm.verts.new((x, yf, z_top)) for x, _, _ in cols]
        fb = [bm.verts.new((x, yf, zb)) for x, zb, _ in cols]
        bt = [bm.verts.new((x, yb, z_top)) for x, _, _ in cols]
        bb = [bm.verts.new((x, yb, zb)) for x, zb, _ in cols]
        v0 = s_front - (z_top - 0)  # valance v runs on from the sheet's front edge
        for k in range(len(cols) - 1):
            key = stripe(cols[k][2])
            (x0, z0, _), (x1, z1, _) = cols[k], cols[k + 1]
            front = [(x0, v0 + z_top), (x0, v0 + z0), (x1, v0 + z1), (x1, v0 + z_top)]
            face([ft[k], fb[k], fb[k + 1], ft[k + 1]], front, key)
            face([bt[k + 1], bb[k + 1], bb[k], bt[k]], [front[3], front[2], front[1], front[0]], key)
            face([fb[k], bb[k], bb[k + 1], fb[k + 1]], [(x0, 0), (x0, 0.1), (x1, 0.1), (x1, 0)], key)
            face([ft[k + 1], bt[k + 1], bt[k], ft[k]], [(x1, 0), (x1, 0.1), (x0, 0.1), (x0, 0)], key)
        last = len(cols) - 1
        face([ft[0], bt[0], bb[0], fb[0]], [(0, z_top), (0.1, z_top), (0.1, z_edge), (0, z_edge)], stripe(0))
        face([fb[last], bb[last], bt[last], ft[last]], [(0, z_edge), (0.1, z_edge), (0.1, z_top), (0, z_top)], stripe(n_stripes - 1))

        for e in bm.edges:  # smooth across the sag, crisp at the cloth's edges
            if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > 0.6:
                e.smooth = False
        me = bpy.data.meshes.new("Awning")
        bm.to_mesh(me)
        bm.free()
        obj = bpy.data.objects.new("Awning", me)
        scene_of().collection.objects.link(obj)
        return Part(obj, "canvas", None, grain="y", keys=keys, weather=False, uv_done=True, jitter=0.0), pt, top - thick

    # ------------------------------------------------------------------ one stand
    def build_stand(name):
        """Build the stand at the origin of the current scene. Returns ({family: object}, info)."""
        cfg = STANDS[name]
        pal = dict(SHARED)
        pal.update(cfg["palette"])
        accent = cfg["accent"]
        module = __import__(cfg["module"])
        rng = random.Random(name)

        before = set(scene_of().objects)
        module.build()
        old = [o for o in scene_of().objects if o not in before and o.type == "MESH"]
        ref_lo, ref_hi = bounds(old)

        parts = []
        dropped = {"stripe": 0, "wall": 0, "counter": 0, "batten": 0, "top": 0, "band": 0, "rail": 0}

        def drop(o, what):
            dropped[what] += 1
            bpy.data.objects.remove(o, do_unlink=True)

        def add(obj, family, key, grain=None, **kw):
            parts.append(Part(obj, family, key, grain, **kw))
            return obj

        metal = "wood" if args.no_metal else "metal"
        table = {
            "darkWood": ("wood", "timber_dark", None),
            "wood": ("wood", "timber", None),
            accent: ("wood", "paint", None),
            "cork": ("wood", "cork", "z"),
            "rod0": ("wood", "rod_willow", "z"), "rod1": ("wood", "rod_glass", "z"), "rod2": ("wood", "rod_graphite", "z"),
            "tub0": ("wood", "tub_a", "z"), "tub1": ("wood", "tub_b", "z"), "tub2": ("wood", "tub_c", "z"),
            "bait0": ("wood", "bait_worm", "z"), "bait1": ("wood", "bait_cricket", "z"), "bait2": ("wood", "bait_minnow", "z"),
            "pack0": ("wood", "pack_a", None), "pack1": ("wood", "pack_b", None), "pack2": ("wood", "pack_c", None),
            "white": ("wood", "whitewash", None),
            "metalShine": (metal, "steel", None),
            "metal": (metal, "galv", "z"),
            "water": (metal, "water", "z"),
            "red": (metal, "needle", None),
            "tub": (metal, "galv", None),
            "tail0": (metal, "fish_a", None), "tail1": (metal, "fish_b", None), "tail2": (metal, "fish_c", None),
            "ice": (metal, "ice", None),
        }
        for o in old:
            m = o.data.materials[0].name.split(".")[0]
            d = tuple(o.dimensions)
            if m.startswith("stripe"):
                drop(o, "stripe")
            elif m == "plank" and near(d, (CW, 0.3, 5.5)):
                drop(o, "wall")
            elif m == "plank" and near(d, (CW, CD, CH - 0.4)):
                drop(o, "counter")
            elif m == "wood" and near(d, (0.25, 0.15, CH - 0.6)):
                drop(o, "batten")
            elif m == "darkWood" and near(d, (CW + 0.4, CD + 0.4, 0.4)):
                drop(o, "top")
            elif m == accent and near(d, (CW, 0.2, 0.6)):
                drop(o, "band")
            elif m == "wood" and near(d, (2.0, 0.8, 0.3)):  # rod rack rails, flush with their posts
                add(box((1.9, 0.6, 0.3), tuple(o.location)), "wood", "timber", "x")
                drop(o, "rail")
            else:
                family, key, grain = table[m]
                if name == "FishBuyerStand":
                    if m == "metal":
                        key = "iron"  # the scale's rods and pan
                    elif m == "white":  # the scale's dial, and the chest's lid (now a bed of ice)
                        family, key = metal, ("ice" if near(d, (2.7, 1.7, 0.2)) else "enamel")
                    elif m == accent and o.location.z > 12:
                        key, grain = "paint_deep", "x"  # the carved fish
                    elif m == "wood" and near(d, (1.6, 1.6, 1.6)):
                        grain = "z"  # the ice crate
                add(o, family, key, grain, weather=(family == "wood"))
        want = {"stripe": 20, "wall": 1, "counter": 1, "batten": 5, "top": 1, "band": 1,
                "rail": 2 if name == "BaitShopStand" else 0}
        if dropped != want:
            raise SystemExit(f"{name}: stands.py has changed (swapped {dropped}, expected {want}); update stands_split.py")

        # Counter: a dark core behind real boards with gaps, a three-board top and a painted
        # rail. The old slabs shared faces with the posts (they flickered); nothing here does:
        # the posts stand 0.05 proud of the counter's sides and back, 0.2 proud of its front.
        h = CH - 0.4
        gap, t = 0.04, 0.08
        x0, x1, y0, y1 = -CW / 2 + 0.05, CW / 2 - 0.05, -CD / 2, CD / 2 - 0.05
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        add(box((x1 - x0 - 2 * t, y1 - y0 - 2 * t, h - 0.02), (cx, cy, (h - 0.02) / 2)), "wood", "core", "z", weather=False, jitter=0.0)
        n = 8
        for i in range(n):
            x = x0 + (x1 - x0) * (i + 0.5) / n
            for y in (y0 + t / 2, y1 - t / 2):
                add(box(((x1 - x0) / n - gap, t, h), (x, y, h / 2)), "wood", "timber_light", "z")
        n = 3
        side = y1 - y0 - 2 * t
        for i in range(n):
            y = y0 + t + side * (i + 0.5) / n
            for x in (x0 + t / 2, x1 - t / 2):
                add(box((t, side / n - gap, h), (x, y, h / 2)), "wood", "timber_light", "z")
        n = 3
        ty0, ty1 = -CD / 2 - 0.26, CD / 2 + 0.2
        wide = (ty1 - ty0 - (n - 1) * gap) / n
        for i in range(n):
            y = ty0 + wide / 2 + i * (wide + gap)
            add(box((CW + 0.4, wide, 0.4), (0, y, CH - 0.2)), "wood", "top", "x")
        post_in = 4.7 - 0.3  # the inner faces of the posts
        add(box((2 * post_in - gap, 0.2, 0.6), (0, -CD / 2 - 0.1, CH - 1.0)), "wood", "paint", "x")
        # Back wall: seven painted boards between the back posts.
        n = 7
        for i in range(n):
            x = -post_in + 2 * post_in * (i + 0.5) / n
            add(box((2 * post_in / n - gap, 0.3, 5.5), (x, 1.85, 6.6)), "wood", "paint_pale", "z", jitter=0.06)

        # The awning and the frame that carries it: a beam on each pair of posts, three rafters,
        # a purlin to hang things from and a rail at the eave.
        awning, pt, under = cloth_awning("stripe")
        parts.append(awning)
        add(box((10.0, 0.5, 0.35), (0, 1.7, 9.4 + 0.175)), "wood", "timber_dark", "x")
        add(box((10.0, 0.5, 0.30), (0, -1.9, 8.4 + 0.15)), "wood", "timber_dark", "x")
        s0, s1 = -3.02, 2.12
        for x in (-4.7, 0.0, 4.7):
            c = pt(x, (s0 + s1) / 2, under - 0.045 - 0.15)
            add(box((0.3, s1 - s0, 0.3), c, rot=(0.28, 0, 0)), "wood", "timber", "y")
        c = pt(0, -2.95, under - 0.045 - 0.10)
        add(box((10.5, 0.2, 0.2), c, rot=(0.28, 0, 0)), "wood", "timber", "x")
        purlin = pt(0, (-1.0 + 0.3) / math.cos(0.28), under - 0.045 - 0.30 - 0.125)
        add(box((10.0, 0.25, 0.25), purlin, rot=(0.28, 0, 0)), "wood", "timber", "x")
        if name == "FishBuyerStand":  # a hook from the purlin down to the scale's rod (top at 8.3)
            z1 = purlin.z - 0.1
            add(cyl(0.05, z1 - 8.3, (-2.5, -1.0, (z1 + 8.3) / 2), verts=5), metal, "iron", "z", weather=False)

        # Same box as the old stand, to the hundredth of a stud.
        objs = [p.obj for p in parts]
        bpy.context.view_layer.update()
        lo, hi = bounds(objs)
        if not (near(lo, ref_lo, 0.011) and near(hi, ref_hi, 0.011)):
            raise SystemExit(f"{name}: size moved. old {tuple(ref_lo)} to {tuple(ref_hi)}, new {tuple(lo)} to {tuple(hi)}")

        shared_faces(name, parts)
        for p in parts:
            if p.weather:
                damp_foot(p)
            if not p.uv_done:
                project_uv(p, rng)
            paint_part(p, pal, rng)
        for p in parts:  # the cloth's UVs were written in studs
            if p.uv_done:
                layer = p.obj.data.uv_layers["UVMap"]
                for d in layer.data:
                    d.uv = (d.uv[0] / args.uv[p.family], d.uv[1] / args.uv[p.family])

        pivot = Vector(((ref_lo.x + ref_hi.x) / 2, (ref_lo.y + ref_hi.y) / 2, ref_lo.z))
        out = {}
        for fam in FAMILIES:
            members = [p.obj for p in parts if p.family == fam]
            if not members:
                continue
            for o in members:
                o.data.materials.clear()
            obj = common.join(members, f"{name}_{fam}") if len(members) > 1 else members[0]
            obj.name = obj.data.name = f"{name}_{fam}"
            obj.data.color_attributes.active_color = obj.data.color_attributes["Col"]
            obj.data.color_attributes.render_color_index = obj.data.color_attributes.find("Col")
            if not args.no_anchors:
                anchors(obj, ref_lo, ref_hi, pal["timber"], args.lifts[fam])
            obj.data.transform(Matrix.Translation(-pivot))
            obj.data.update()
            obj["parts"] = len(members)
            out[fam] = obj
        info = {
            "size_blender": [round(v, 3) for v in (ref_hi - ref_lo)],
            "studs": [round(ref_hi.x - ref_lo.x, 2), round(ref_hi.z - ref_lo.z, 2), round(ref_hi.y - ref_lo.y, 2)],
            "palette": {k: list(v) for k, v in pal.items() if any(p.key == k or (p.keys and k in p.keys) for p in parts)},
            "keys": {fam: sorted({k for p in parts if p.family == fam for k in ([p.key] if p.key else set(p.keys))}) for fam in out},
        }
        return out, info

    def shared_faces(name, parts):
        """Warn where two box parts share a face plane and overlap on it: that flickers in the game."""
        boxes = []
        for p in parts:
            me = p.obj.data
            if p.family == "canvas" or any(max(abs(c) for c in poly.normal) < 0.999 for poly in me.polygons):
                continue  # not an axis-aligned box
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
                    for a, b, side in ((alo[ax], blo[ax], "min"), (ahi[ax], bhi[ax], "max")):
                        if ax == 2 and side == "min" and abs(a) < 1e-3:
                            continue  # both stand on the ground: nobody sees that face
                        if abs(a - b) < 1e-4:
                            print(f"[stands_split] WARNING {name}: {pa.key} and {pb.key} share the {'xyz'[ax]} {side} "
                                  f"face at {a:.3f} over {area:.2f} square studs")

    def damp_foot(p):
        """Tall wood that stands on the ground gets a darker, damp foot (a colour ramp)."""
        me = p.obj.data
        zs = [v.co.z for v in me.vertices]
        z0, z1 = min(zs), max(zs)
        p.foot = None
        if z0 > 0.06 or z1 - z0 < 1.5:
            return
        cut = z0 + min(1.2, (z1 - z0) * 0.35)
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, cut), plane_no=(0, 0, 1))
        bm.to_mesh(me)
        bm.free()
        p.foot = z0 + 0.02

    def project_uv(p, rng):
        """Each flat side is laid out flat at world scale, v along the grain. Faces that share a
        direction share one layout, so a bisected side stays in one piece."""
        me = p.obj.data
        layer = me.uv_layers.get("UVMap") or me.uv_layers.new(name="UVMap")
        scale = args.uv[p.family]
        tile = tiles[p.family]
        period = tile / PLANK_BOARDS_PER_TILE if p.family == "wood" else None
        k = rng.randrange(PLANK_BOARDS_PER_TILE)
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
                ref = min((Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))), key=lambda ax: abs(ax.dot(n)))
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
            elif u1 - u0 <= period * 1.001:
                u_off = (k + 0.5) * period - (u0 + u1) / 2  # a narrow part: inside one board
            else:
                u_off = k * period - u0  # a wide part: starts on a gap
            for li, u, v in coords:
                layer.data[li].uv = ((u + u_off) / scale, (v + v_off) / scale)

    def paint_part(p, pal, rng):
        me = p.obj.data
        attr = me.color_attributes.get("Col") or me.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
        lift = args.lifts[p.family]
        shade = 1 + rng.uniform(-p.jitter, p.jitter)
        foot = getattr(p, "foot", None)
        for poly in me.polygons:
            rgb = pal[p.keys[poly.index] if p.keys else p.key]
            for li in poly.loop_indices:
                f = shade
                if foot is not None and me.vertices[me.loops[li].vertex_index].co.z <= foot:
                    f *= 0.76
                attr.data[li].color = tuple(srgb_to_linear(min(255.0, c * f * lift)) for c in rgb) + (1.0,)

    def anchors(obj, lo, hi, rgb, lift):
        """Two specks at opposite corners of the whole stand, so this mesh has the stand's box."""
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
        col = tuple(srgb_to_linear(min(255.0, c * lift)) for c in rgb) + (1.0,)
        for i in idx:
            for li in me.polygons[i].loop_indices:
                me.color_attributes["Col"].data[li].color = col

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
        bpy.context.view_layer.update()
        lo, hi = bounds([obj])
        return {
            "triangles": len(obj.data.loop_triangles),
            "parts": int(obj["parts"]),
            "colours_converted": n,
            "studs": [round(hi.x - lo.x, 2), round(hi.z - lo.z, 2), round(hi.y - lo.y, 2)],
            "glb": str(path.relative_to(REPO)).replace("\\", "/"),
            "roblox_glb": str((ROBLOX / path.name).relative_to(REPO)).replace("\\", "/"),
        }

    # ------------------------------------------------------------------ preview
    def setup_cycles(w, h):
        scene = scene_of()
        for o in [o for o in scene.objects if o.get("_stage")]:  # the last shot's sun, camera and ground
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
        scene.view_settings.exposure = -0.45
        world = bpy.data.worlds.new("Sky")
        world.use_nodes = True
        bg = world.node_tree.nodes["Background"]
        bg.inputs[0].default_value = (0.80, 0.88, 1.0, 1.0)
        bg.inputs[1].default_value = 0.8
        scene.world = world
        sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
        sun.data.energy = 3.6
        sun.data.color = (1.0, 0.96, 0.88)
        sun.data.angle = math.radians(1.5)
        sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
        scene.collection.objects.link(sun)
        cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        scene.collection.objects.link(cam)
        scene.camera = cam
        sun["_stage"] = cam["_stage"] = True
        return cam

    def ground(obj, rgb):
        obj.data.materials.append(flat("Ground", rgb))
        obj["_stage"] = True

    def flat(name, rgb, rough=0.95):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = tuple(srgb_to_linear(c) for c in rgb) + (1.0,)
        bsdf.inputs["Roughness"].default_value = rough
        return m

    preview_cache = {}

    def preview_material(fam):
        """What the game shows: vertex colour times the family's NEUTRAL colour map, with its
        normal and roughness maps, one tile every studs_per_tile studs."""
        if fam in preview_cache and preview_cache[fam].name in bpy.data.materials:
            return preview_cache[fam]
        m = bpy.data.materials.new(f"Preview_{fam}")
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        slug = VARIANT[fam]
        if slug is None:  # built-in Metal for now
            nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
            bsdf.inputs["Metallic"].default_value = 0.55
            bsdf.inputs["Roughness"].default_value = 0.5
        else:
            uv = nt.nodes.new("ShaderNodeUVMap")
            uv.uv_map = "UVMap"
            mapping = nt.nodes.new("ShaderNodeMapping")
            s = args.uv[fam] / tiles[fam]
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
            nt.links.new(tex("neutral", False).outputs[0], mix.inputs[6])
            nt.links.new(vc.outputs["Color"], mix.inputs[7])
            nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
            nt.links.new(tex("rough", True).outputs[0], bsdf.inputs["Roughness"])
            nmap = nt.nodes.new("ShaderNodeNormalMap")
            nmap.uv_map = "UVMap"
            nt.links.new(tex("normal", True).outputs[0], nmap.inputs["Color"])
            nt.links.new(nmap.outputs[0], bsdf.inputs["Normal"])
        preview_cache[fam] = m
        return m

    def dress_for_preview(objs):
        for fam, obj in objs.items():
            obj.data.materials.clear()
            obj.data.materials.append(preview_material(fam))

    def shoot_three_quarter(objs, path, view=(-30, 22), ortho=None):
        cam = setup_cycles(args.px, args.px)
        bpy.context.view_layer.update()
        lo, hi = bounds(objs)
        center = (lo + hi) / 2
        size = (hi - lo).length
        bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=size * 1.5, depth=0.01, location=(center.x, center.y, lo.z - 0.005))
        ground(bpy.context.object, (150, 150, 146))
        yaw, pitch = (math.radians(v) for v in view)
        d = Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = ortho or max(size * 0.9, max(hi - lo) * 1.12)
        cam.location = center + d * size * 3
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        cam.data.clip_end = size * 12
        scene_of().render.filepath = str(path)
        bpy.ops.render.render(write_still=True)

    def shoot_ingame(path, fov=70.0, eye=(0, -46.5, 5.0), look=(0, 0, 4.5), w=1600, h=900):
        """Default: fixed shot 08-stands-noon, squared up: eye (0, 6, 50) on the dock, the stands
        46.5 studs off at z = 96.5 with their bases at y = 1. Roblox (x, y, z) is Blender
        (-x, z, y), and Roblox's default field of view is 70 degrees."""
        cam = setup_cycles(w, h)
        bpy.ops.mesh.primitive_plane_add(size=600, location=(0, 0, 0))
        ground(bpy.context.object, (104, 122, 62))
        cam.data.type = "PERSP"
        cam.data.sensor_fit = "VERTICAL"
        cam.data.angle_y = math.radians(fov)
        cam.location = eye
        aim = Vector(look) - Vector(eye)
        cam.rotation_euler = aim.to_track_quat("-Z", "Y").to_euler()
        cam.data.clip_end = 2000
        scene_of().render.filepath = str(path)
        bpy.ops.render.render(write_still=True)

    def old_stand(name):
        before = set(scene_of().objects)
        __import__(STANDS[name]["module"]).build()
        meshes = [o for o in scene_of().objects if o not in before and o.type == "MESH"]
        return common.bake_to_vertex_colors(meshes, name + "_old")

    # ------------------------------------------------------------------ run
    for d in (MODELS, ROBLOX, PREVIEWS, SCRATCH):
        d.mkdir(parents=True, exist_ok=True)
    result = {"uv_studs": args.uv, "lift": args.lifts, "tiles": tiles, "anchors": not args.no_anchors, "stands": {}}
    for name in STANDS:
        common.reset()
        preview_cache.clear()
        objs, info = build_stand(name)
        entry = {"studs": info["studs"], "palette": info["palette"], "keys": info["keys"], "meshes": {}}
        for fam, obj in objs.items():
            entry["meshes"][fam] = export(obj)
            print(f"[stands_split] {obj.name}: {entry['meshes'][fam]['triangles']} triangles")
        result["stands"][name] = entry
        for fam in FAMILIES:  # a family this run did not make (--no-metal): clear its old files
            if fam not in objs:
                for stale in (MODELS / f"{name}_{fam}.glb", ROBLOX / f"{name}_{fam}.glb"):
                    stale.unlink(missing_ok=True)
        if not args.no_render:
            dress_for_preview(objs)
            shoot_three_quarter(list(objs.values()), PREVIEWS / f"{name}_split.png")
    (SCRATCH / "result.json").write_text(json.dumps(result, indent=1), encoding="utf-8")
    if args.no_render:
        return

    for name in STANDS:  # the old stands under the same light, for the before column
        common.reset()
        shoot_three_quarter([old_stand(name)], SCRATCH / f"{name}-old.png")
    for which in ("new", "old"):
        common.reset()
        preview_cache.clear()
        for name, cfg in STANDS.items():
            x = -cfg["roblox_xz"][0]
            if which == "new":
                objs, _ = build_stand(name)
                dress_for_preview(objs)
                for o in objs.values():
                    o.location = (x, 0, 0)
            else:
                old_stand(name).location = (x, 0, 0)
        shoot_ingame(PREVIEWS / "stands_split-ingame.png" if which == "new" else SCRATCH / "ingame-old.png")
        shoot_ingame(SCRATCH / f"ingame-{which}-zoom.png", fov=30.0)
        if which == "new":  # scratch checks: a customer at the counter, and round the back
            for name, cfg in STANDS.items():
                x = -cfg["roblox_xz"][0]
                shoot_ingame(SCRATCH / f"{name}-customer.png", eye=(x + 3, -11, 5.0), look=(x, 0, 5.4), w=1280, h=720)
                shoot_ingame(SCRATCH / f"{name}-back.png", eye=(x - 9, 13, 7.0), look=(x, 0, 5.0), w=1280, h=720)


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
        raise SystemExit(f"{path.name}: pivot is not the bottom centre ({pos['min']} to {pos['max']})")
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
    tiles = family_tiles()

    # The board snap trusts five boards per tile: check the map still agrees.
    neutral = TEXTURES / "weathered_plank" / "weathered_plank_neutral.png"
    cols = list(Image.open(neutral).convert("L").resize((512, 1), Image.BOX).tobytes())
    mean = sum(cols) / len(cols)
    dark = [i for i, c in enumerate(cols) if c < mean * 0.86]
    off = max(min(abs(i - k * 512 / PLANK_BOARDS_PER_TILE) for k in range(PLANK_BOARDS_PER_TILE + 1)) for i in dark) if dark else 99
    if off > 4:
        print(f"WARNING: {neutral.name} no longer has {PLANK_BOARDS_PER_TILE} even boards per tile; fix PLANK_BOARDS_PER_TILE")

    if not args.compose_only:
        SCRATCH.mkdir(parents=True, exist_ok=True)
        subprocess.run([BLENDER, "-b", "--factory-startup", "-P", str(Path(__file__).resolve()), "--", *sys.argv[1:]], check=True)
    result = json.loads((SCRATCH / "result.json").read_text(encoding="utf-8"))

    # Check what was written, then record it.
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    for key in [k for k in manifest if k.split("_")[0] in STANDS and k.split("_")[-1] in FAMILIES]:
        del manifest[key]  # this script's own entries only
    for name, entry in result["stands"].items():
        for fam, mesh in entry["meshes"].items():
            for sub in ("glb", "roblox_glb"):
                size, tris = check_glb(REPO / mesh[sub], entry["studs"], result["anchors"])
            if tris != mesh["triangles"]:
                raise SystemExit(f"{name}_{fam}: {tris} triangles in the file, {mesh['triangles']} in Blender")
            slug = VARIANT[fam]
            variant = (f"MaterialVariant {slug} with its NEUTRAL colour map, normal and roughness"
                       if slug else "no family of ours yet: built-in Metal until tin roof or aluminium exists")
            manifest[f"{name}_{fam}"] = {
                "name": f"{name}_{fam}",
                "studs": size,
                "triangles": tris,
                "parts": mesh["parts"],
                "replaces": STANDS[name]["replaces"],
                "notes": (f"Layer B, {fam} family: {variant}. Vertex colours stored {result['lift'][fam]:g} times the "
                          f"colour wanted. UVs at {result['uv_studs'][fam]:g} studs per UV unit. Upload "
                          f"art/models/roblox/{name}_{fam}.glb. Every mesh of the stand goes at the old stand's CFrame."),
                "family": fam,
                "variant": slug,
                "uv_studs": result["uv_studs"][fam],
                "lift": result["lift"][fam],
                "palette_seen_rgb": {k: entry["palette"][k] for k in entry["keys"][fam]},
            }
            print(f"{name}_{fam}: {size} studs, {tris} triangles")
    MANIFEST.write_text(json.dumps(dict(sorted(manifest.items())), indent=2) + "\n", encoding="utf-8")
    if args.no_render:
        return

    # ---- the sheet
    def font(size, bold=False):
        for f in (("segoeuib.ttf",) if bold else ()) + ("segoeui.ttf", "arial.ttf"):
            try:
                return ImageFont.truetype(f, size)
            except OSError:
                continue
        return ImageFont.load_default()

    cell, pad, head = 600, 16, 34
    wide = 2 * cell + pad
    W = pad + 4 * cell + 3 * pad + pad
    ingame_h = int(wide * 9 / 16)
    sw_h = 150
    H = 70 + head + cell + pad + 2 * (head + ingame_h + pad) + head + sw_h + pad
    fams = {name: ", ".join(entry["meshes"]) for name, entry in result["stands"].items()}
    sheet = Image.new("RGB", (W, H), (24, 24, 27))
    draw = ImageDraw.Draw(sheet)
    draw.text((pad, 14), "Market stands, split by family for Layer B (11/27/2026)", font=font(30, True), fill=(240, 240, 240))
    uv_note = ", ".join(f"{f} {result['uv_studs'][f]:g}" for f in FAMILIES)
    draw.text((pad, 50), f"Rendered as the game shows them: vertex colour times each family's neutral map.  Studs per UV unit: {uv_note}.",
              font=font(16), fill=(170, 170, 175))
    y = 70
    row = [
        ("Bait shop, before (one mesh, flat colour)", SCRATCH / "BaitShopStand-old.png"),
        (f"Bait shop, split: {fams['BaitShopStand']}", PREVIEWS / "BaitShopStand_split.png"),
        ("Fish buyer, before", SCRATCH / "FishBuyerStand-old.png"),
        (f"Fish buyer, split: {fams['FishBuyerStand']}", PREVIEWS / "FishBuyerStand_split.png"),
    ]
    for i, (label, path) in enumerate(row):
        x = pad + i * (cell + pad)
        draw.text((x, y + 6), label, font=font(17), fill=(210, 210, 214))
        sheet.paste(Image.open(path).convert("RGB").resize((cell, cell), Image.LANCZOS), (x, y + head))
    y += head + cell + pad
    for pair in (
        (("From the dock, 46.5 studs, eye 6, 70 degree view (fixed shot 08, squared up): before", SCRATCH / "ingame-old.png"),
         ("The same view: split meshes with the family maps", PREVIEWS / "stands_split-ingame.png")),
        (("The same eye through a 30 degree lens: before", SCRATCH / "ingame-old-zoom.png"),
         ("30 degree lens: split meshes with the family maps", SCRATCH / "ingame-new-zoom.png")),
    ):
        for i, (label, path) in enumerate(pair):
            x = pad + i * (wide + pad)
            draw.text((x, y + 6), label, font=font(17), fill=(210, 210, 214))
            sheet.paste(Image.open(path).convert("RGB").resize((wide, ingame_h), Image.LANCZOS), (x, y + head))
        y += head + ingame_h + pad
    draw.text((pad, y + 6), "Colours as seen in the game (the stored vertex colour is this times the lift)", font=font(17), fill=(210, 210, 214))
    y += head
    show = ("paint", "paint_pale", "stripe", "canvas_white", "timber_light", "timber", "timber_dark", "top")
    for i, (name, entry) in enumerate(result["stands"].items()):
        x = pad + i * (wide + pad)
        tri = ", ".join(f"{fam} {m['triangles']}" for fam, m in entry["meshes"].items())
        draw.text((x, y), f"{name}: triangles {tri}", font=font(16, True), fill=(230, 230, 232))
        sx = x
        for key in show:
            rgb = tuple(entry["palette"][key])
            draw.rectangle((sx, y + 28, sx + 130, y + 78), fill=rgb)
            draw.text((sx, y + 82), key, font=font(13), fill=(190, 190, 195))
            draw.text((sx, y + 99), "%d, %d, %d" % rgb, font=font(13), fill=(150, 150, 156))
            sx += 142
    out = PREVIEWS / "stands_split.png"
    sheet.save(out, optimize=True)
    print(f"sheet: {out}")


if __name__ == "__main__":
    if IN_BLENDER:
        blender_main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    else:
        driver_main()
