"""The plant kit: Cedar Creek (N3) and the first island (N6) vegetation, Layer B like the bank kit.

Plan: docs/superpowers/plans/2026-11-27-leg-3.md, "Area by area": the Cedar Creek row (mossy
boulders, roots showing on the cut banks, ferns, a log across the pool, a closed canopy) and the
first island row (pink granite, lichen with orange, juniper, heath red, "the lone bent pine against
a golden sky, seen from the boat", "one landmark you can read from 500 studs", a kit of at most 12
meshes). Same rules as art/scripts/bank_kit.py (on the N1 branch): one mesh per material family,

    <Name>_bark    trunks, limbs, roots, the log       family: bark         (MaterialVariant "bark")
    <Name>_leaf    crowns, ferns, moss, heath, lichen   family: leaf_needle  (MaterialVariant "leaf_needle")

world-scale UVs (1 UV unit = 1 stud, V along every trunk, limb, root and frond; blobs box-mapped),
and vertex colours stored 1.25 times lighter than the colour we want to see, because each family's
neutral colour map multiplies them and has a mean of 0.80 (so 204 is the lightest a mesh can show).

The kit (12 models, 17 meshes):
    Cedar Creek:  Cedar (bark + leaf), MossyLog (bark + leaf), CreekRoots (bark),
                  CreekFern1, CreekFern2, MossMat (leaf)
                  and CedarBough (bark + leaf), added after the kit of 12: a drooping spray that
                  hangs out over the stream from a bank cedar's trunk. Its pivot is the branch
                  base, not the bottom centre (see cedar_bough).
    The island:   LonePine (bark + leaf), Juniper1 (bark + leaf), Juniper2 (bark + leaf),
                  HeathTufts, LichenTufts, LichenCrust (leaf)          = 9 of the island's 12 meshes

Where PlantFactory helps, and where it does not (Stewart's PlantFactory exports, 11/27/2026):
  * Its foliage is alpha-cut leaf cards. Layer B meshes carry no textures, so those cards would
    show as opaque rectangles; and its trunks are true to scale, thin as pencils next to the
    chunky shapes this game uses. So no PlantFactory mesh is shipped.
  * The one real gain is a species' crown shape. The Cedar's crown follows the outline measured
    from the western red cedar export (Thuja plicata, ranch-twin's PlantFactory export, seed 0):
    crown radius by height and by side, the trunk's lean and where the crown starts. The numbers
    live in art/scripts/plant_envelopes.json, so a rebuild never needs the raw FBX (which stays out
    of git: the PlantCatalog licence allows derived game meshes, not the raw meshes).
  * Ferns, moss, juniper, heather and lichen were never exported, and each is a cushion or a few
    fronds that a script makes better than a decimated card cloud. The lone pine is a deliberate
    wind-shaped silhouette, so it is hand-built too.

Where each model sits: built with the ground at height 0, reaching a little below it. Pivot at the
bottom centre of the box. `bury` in the manifest is how far the ground line is above the pivot:
place the pivot at ground height minus bury. Two-mesh models carry two specks at opposite corners
so both meshes share one box, centred on the foot of the trunk (or the middle of the log): both
meshes go at the same CFrame. Anything that leans or faces a way leans toward Blender +X, which is
Roblox -X once imported (art/README.md, Importing, step 3).

    python art/scripts/plant_kit.py                 build, export, render, sheet
    python art/scripts/plant_kit.py --no-render     models and manifest only
    python art/scripts/plant_kit.py --compose-only  rebuild the sheet from the renders already made
    python art/scripts/plant_kit.py --only CedarBough   one model: its files, its manifest entries
                                                    and (CedarBough) art/previews/CedarBough.png
    blender -b -P art/scripts/plant_kit.py -- --measure <thuja.fbx>   re-measure the cedar outline

Writes art/models/<Name>_<family>.glb (linear colours, as Blender wants them),
art/models/roblox/<Name>_<family>.glb (display colours, the copy to upload), the sheet
art/previews/plant_kit.png (plus plant_kit-*.png), and its own entries in art/models/manifest.json.
Scratch goes to artifacts/plant_kit/. The family maps are read for the previews only: from
art/textures/ (bark, leaf_needle), or from the folder in PLANT_KIT_TEXTURES, else stand-ins.
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
SCRATCH = REPO / "artifacts" / "plant_kit"
MANIFEST = MODELS / "manifest.json"
ENVELOPES = HERE / "plant_envelopes.json"
BLENDER = os.environ.get("BLENDER", r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe")

try:
    import bpy  # noqa: F401

    IN_BLENDER = True
except ModuleNotFoundError:
    IN_BLENDER = False

FAMILIES = ("bark", "leaf")
WANTED = {"bark": "bark", "leaf": "leaf_needle"}
DEFAULT_TILE = {"bark": 4.0, "leaf": 8.0}

# ---------------------------------------------------------------------------------------
# Palette: the colours we want to SEE in the game (sRGB 0..255), before the lift.
# The plan's area rows: Cedar Creek moss 78,104,52, wet slate 70,78,84, cedar bark 110,70,50;
# the island: granite 176,142,132, lichen 150,160,120 and orange 204,130,48, juniper 52,84,66,
# heath red 120,54,48.
# ---------------------------------------------------------------------------------------
PAL = {
    # western red cedar
    "cedar_bark": (110, 70, 50),
    "cedar_bark_grey": (128, 112, 98),     # the weathered silver strips of a cedar's stringy bark
    "cedar_bark_dark": (78, 52, 40),
    "cedar_leaf": (66, 96, 50),
    "cedar_leaf_sun": (82, 112, 56),
    "cedar_leaf_deep": (42, 64, 38),
    # moss (creek)
    "moss": (78, 104, 52),
    "moss_sun": (98, 124, 58),
    "moss_deep": (56, 78, 40),
    "moss_gold": (112, 118, 56),
    # creek ferns: shade-grown, a little cooler than the lake's
    "cfern": (74, 110, 52),
    "cfern_tip": (100, 132, 62),
    "cfern_deep": (50, 78, 40),
    # the mossy log and the roots
    "log": (96, 76, 60),
    "log_grey": (118, 106, 92),
    "log_dark": (62, 50, 42),
    "log_end": (150, 118, 86),
    "log_heart": (124, 94, 66),
    "root": (92, 72, 56),
    "root_dark": (64, 50, 40),
    "root_pale": (130, 110, 90),
    # the island's lone pine
    "lpine_bark": (96, 78, 66),
    "lpine_bark_dark": (70, 58, 52),
    "lpine_bark_red": (122, 84, 62),
    "lpine_dead": (168, 160, 150),          # bleached snag and windward stubs
    "lpine_needle": (50, 80, 62),
    "lpine_needle_sun": (62, 92, 60),
    "lpine_needle_deep": (34, 56, 46),
    # junipers
    "juniper": (52, 84, 66),
    "juniper_sun": (66, 98, 72),
    "juniper_deep": (36, 60, 50),
    "juniper_bronze": (100, 94, 64),          # the wind-bronzed tips
    "juniper_bark": (104, 84, 72),
    "juniper_dead": (168, 160, 148),
    # heath and lichen
    "heath": (120, 54, 48),
    "heath_dark": (82, 42, 38),
    "heath_dry": (142, 98, 74),
    "heath_green": (92, 88, 54),
    "lichen": (150, 160, 120),
    "lichen_pale": (176, 182, 150),
    "lichen_shade": (114, 124, 94),
    "lichen_orange": (204, 130, 48),
    "lichen_orange_dark": (172, 100, 40),
    "lichen_grey": (164, 166, 150),
}

# name -> what it is for (the builders are in the Blender half). lean: which way it leans or faces.
KIT = {
    "Cedar": {"area": "creek", "kind": "tree",
              "where": "On the creek banks, 2 studs or more back from the water, in loose groups of two or three so the crowns meet over the stream (the closed canopy). Any turn; scale 0.7 to 1.1 for 13 to 20 studs. The nodding leader at the top leans toward Roblox -X.",
              "replaces": "PineTall and PineShort along Cedar Creek (the gray-box trunk and crown pairs)"},
    "MossyLog": {"area": "creek", "kind": "log",
                 "where": "Across the pool, each end on a bank top. Lies along X; the root-plate end is at Roblox +X, the broken end at Roblox -X. The ends sink their bury into the banks; the middle may hang over the water.",
                 "replaces": "Nothing yet: the log across the pool (plan, Cedar Creek row)"},
    "CreekRoots": {"area": "creek", "kind": "roots",
                   "where": "On a cut bank face: the model's Roblox +X side goes into the bank and the roots hang toward Roblox -X (the water). Its ground line is the bank lip, so the pivot goes at lip height minus bury. Roblox terrain is 4 stud voxels, so a cut bank is a slope, not a wall: set the model's back where the slope meets the water line, then check in Studio that the roots are not buried in it.",
                   "replaces": "Nothing yet: roots on the cut banks (plan, Cedar Creek row)"},
    "CreekFern1": {"area": "creek", "kind": "fern",
                   "where": "On the banks and under the cedars, in groups of two to five; any turn, scale 0.8 to 1.3.",
                   "replaces": "Nothing yet: creek undergrowth"},
    "CreekFern2": {"area": "creek", "kind": "fern",
                   "where": "On the lip of a cut bank or the top of a boulder, the fronds spilling over toward Roblox -X (the water). Its fronds hang 2 studs below its ground line on purpose.",
                   "replaces": "Nothing yet: creek undergrowth"},
    "MossMat": {"area": "creek", "kind": "moss",
                "where": "On the top of a boulder: fitted to RockLarge (scale 1) and RockMedium (scale 0.6). Sink it 0.1 so no gap shows; scale X and Z to fit, Y to match the rock's curve.",
                "replaces": "Nothing yet: moss on the creek boulders (RockLarge, RockMedium)"},
    "CedarBough": {"area": "creek", "kind": "bough", "pivot": "base",
                   "where": "On a bank cedar's trunk, 6 to 10 studs up (times the tree's scale), reaching out over the stream. The pivot is the branch base: put it on the trunk's centre line (the first 0.3 studs of wood hide inside the trunk). The bough runs 12 studs toward Roblox -X and hangs 4.3 studs below its base, so turn its -X toward the water: CFrame.new(base) * CFrame.Angles(0, Scatter.yawMinusX(dx, dz), 0), or on a placed Cedar, the tree's foot CFrame * CFrame.new(0, height, 0), since the Cedar's own -X already faces the water. One or two per tree, the second turned 0.4 to 0.7 radians and 2 to 3 studs higher; scale it with its tree.",
                   "replaces": "Nothing yet: the drooping cedar sprays over the creek (leg 3, N3)"},
    "LonePine": {"area": "island", "kind": "tree",
                 "where": "The island's landmark: on its highest granite knoll, alone, so the sky is behind it from the approach. The trunk bends and the crown streams toward Roblox -X: turn that away from the prevailing wind (downwind), and so the approach from the marina sees it side on. At scale 1 it stands 29.6 studs and its crown reaches 16 studs downwind of the foot.",
                 "replaces": "Nothing yet: the island landmark (plan, N6)"},
    "Juniper1": {"area": "island", "kind": "juniper",
                 "where": "A creeping mat: in the hollows and along the cracks of the granite, any turn, scale 0.7 to 1.3. Sink the rim slightly into rock edges.",
                 "replaces": "Nothing yet: island kit"},
    "Juniper2": {"area": "island", "kind": "juniper",
                 "where": "A wind-shorn shrub: on the island's exposed shoulders. It streams toward Roblox -X: turn that downwind, the same way as the LonePine. The bleached dead limb points upwind.",
                 "replaces": "Nothing yet: island kit"},
    "HeathTufts": {"area": "island", "kind": "heath",
                   "where": "Between the rocks on any thin soil, drifts of several, any turn.",
                   "replaces": "Nothing yet: island kit"},
    "LichenTufts": {"area": "island", "kind": "lichen",
                    "where": "Pale reindeer-lichen cushions: on thin soil and in the dips of the granite, near the heath.",
                    "replaces": "Nothing yet: island kit"},
    "LichenCrust": {"area": "island", "kind": "lichen",
                    "where": "Orange and grey-green crust on the granite itself: lay it on a rock face (tilt it to the slope; it is 0.1 studs thick), mostly on the sunny, bird-perch tops.",
                    "replaces": "Nothing yet: island kit"},
}


def parse_args(argv):
    ap = argparse.ArgumentParser(description="Build the plant kit (Layer B, one mesh per family).")
    ap.add_argument("--lift", type=float, default=1.25, help="how much lighter than the target the vertex colours are stored")
    ap.add_argument("--no-render", action="store_true", help="build and export only")
    ap.add_argument("--compose-only", action="store_true", help="rebuild the sheet from the renders already made")
    ap.add_argument("--only", nargs="+", metavar="NAME", choices=sorted(KIT), help="build these models only; the others' files are left alone")
    ap.add_argument("--check-faces", action="store_true", help="line-ups with back faces in magenta, to artifacts/plant_kit/")
    ap.add_argument("--measure", nargs="+", metavar="FBX", help="(in Blender) measure crown outlines from PlantFactory FBX files")
    ap.add_argument("--samples", type=int, default=int(os.environ.get("ART_SAMPLES", "64")))
    return ap.parse_args(argv)


def family_maps():
    """Where each family's maps are, and how many studs one tile covers. Read only."""
    table = {}
    try:
        table = json.loads((HERE / "texture_families.json").read_text(encoding="utf-8"))["families"]
    except (OSError, KeyError, ValueError):
        pass
    roots = [TEXTURES] + ([Path(os.environ["PLANT_KIT_TEXTURES"])] if os.environ.get("PLANT_KIT_TEXTURES") else [])
    out = {}
    for fam in FAMILIES:
        slug = WANTED[fam]
        tile = float(table.get(slug, {}).get("studs_per_tile", DEFAULT_TILE[fam]))
        found = None
        for root in roots:
            if all((root / slug / f"{slug}_{k}.png").exists() for k in ("neutral", "normal", "rough")):
                found = root / slug
                break
            js = root / slug / f"{slug}.json"
            if js.exists() and not table.get(slug):
                try:
                    tile = float(json.loads(js.read_text(encoding="utf-8")).get("studs_per_tile", tile))
                except (OSError, ValueError):
                    pass
        if found:
            try:
                tile = float(json.loads((found / f"{slug}.json").read_text(encoding="utf-8")).get("studs_per_tile", tile))
            except (OSError, ValueError, AttributeError):
                pass
            out[fam] = {"slug": slug, "dir": str(found), "standin": False, "tile": tile}
        else:
            out[fam] = {"slug": slug, "dir": str(SCRATCH / "standin" / slug), "standin": True, "tile": tile}
    return out


# =======================================================================================
# Measuring a PlantFactory export (Blender only, run by hand when a source changes)
# =======================================================================================

BINS, SECTORS = 12, 8


def measure_main(paths):
    import bpy
    import numpy as np

    data = json.loads(ENVELOPES.read_text(encoding="utf-8")) if ENVELOPES.exists() else {}
    for path in paths:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=path)
        fol, bark = [], []
        for o in bpy.context.scene.objects:
            if o.type != "MESH":
                continue
            me, M = o.data, o.matrix_world
            is_fol = []
            for m in me.materials:
                names = [n.image.name.lower() for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image] if m and m.use_nodes else []
                is_fol.append(any("alpha" in s for s in names))
            co = np.array([(M @ v.co)[:] for v in me.vertices])
            for p in me.polygons:
                (fol if is_fol and is_fol[p.material_index] else bark).extend(co[i] for i in p.vertices)
        fol, bark = np.array(fol), np.array(bark)
        H = float(max(fol[:, 2].max(), bark[:, 2].max()))
        fol, bark = fol / H, bark / H
        # the trunk axis: the middle of the bark in each height band (limbs pull it a little)
        axis = []
        for b in range(BINS):
            z0, z1 = b / BINS, (b + 1) / BINS
            sel = bark[(bark[:, 2] >= z0) & (bark[:, 2] < z1)]
            axis.append([float(np.median(sel[:, 0])), float(np.median(sel[:, 1]))] if len(sel) > 20 else (axis[-1] if axis else [0.0, 0.0]))
        R = []
        for b in range(BINS):
            z0, z1 = b / BINS, (b + 1) / BINS
            sel = fol[(fol[:, 2] >= z0) & (fol[:, 2] < z1)]
            row = [0.0] * SECTORS
            if len(sel) > 50:
                d = sel[:, :2] - np.array(axis[b])
                r = np.hypot(d[:, 0], d[:, 1])
                a = (np.arctan2(d[:, 1], d[:, 0]) % (2 * np.pi)) / (2 * np.pi) * SECTORS
                for s in range(SECTORS):
                    rs = r[a.astype(int) % SECTORS == s]
                    row[s] = round(float(np.percentile(rs, 92)), 4) if len(rs) > 10 else 0.0
            R.append(row)
        low = bark[(bark[:, 2] > 0.02) & (bark[:, 2] < 0.05)]
        trunk_r = float(np.median(np.hypot(low[:, 0] - axis[0][0], low[:, 1] - axis[0][1]))) if len(low) else 0.01
        key = Path(path).stem
        data[key] = {"source": f"PlantFactory export {Path(path).name} (ranch-twin assets/plantfactory_export), measured {__import__('datetime').date.today().strftime('%m/%d/%Y')}",
                     "height_m": round(H, 2), "bins": BINS, "sectors": SECTORS,
                     "crown_base": round(float(np.percentile(fol[:, 2], 1.5)), 4),
                     "trunk_r": round(trunk_r, 4), "axis": [[round(x, 4) for x in a] for a in axis], "R": R}
        print(f"[measure] {key}: {H:.1f} m tall, crown from {data[key]['crown_base']:.2f}, trunk radius {trunk_r:.3f} H")
        for b in reversed(range(BINS)):
            print("   %4.2f  " % ((b + 0.5) / BINS) + " ".join("%5.2f" % r for r in R[b]))
    ENVELOPES.write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8")


# =======================================================================================
# Blender half
# =======================================================================================

def blender_main(argv):
    import bmesh
    import bpy
    from bpy_extras.object_utils import world_to_camera_view
    from mathutils import Euler, Matrix, Vector, noise

    sys.path.insert(0, str(HERE))
    from common import srgb_to_linear
    import roblox_colors

    args = parse_args(argv)
    if args.measure:
        measure_main(args.measure)
        return
    maps = family_maps()
    LIFT = args.lift
    UP = Vector((0, 0, 1))
    ENV = json.loads(ENVELOPES.read_text(encoding="utf-8"))

    def scene_of():
        return bpy.context.scene

    def mix(a, b, t):
        t = min(1.0, max(0.0, t))
        return tuple(x + (y - x) * t for x, y in zip(a, b))

    def shade(c, f):
        return tuple(x * f for x in c)

    def clamp(x, lo=0.0, hi=1.0):
        return lo if x < lo else hi if x > hi else x

    # ------------------------------------------------------------------ geometry (as bank_kit.py)
    class Geo:
        """Faces with a UV and a colour (the colour we want to SEE) on every corner."""

        def __init__(self):
            self.verts, self.faces, self.uvs, self.cols, self.smooth = [], [], [], [], []

        def v(self, p):
            self.verts.append((p[0], p[1], p[2]))
            return len(self.verts) - 1

        def f(self, idx, uvs, cols, smooth=False):
            if isinstance(cols[0], (int, float)):
                cols = [cols] * len(idx)
            self.faces.append(tuple(idx))
            self.uvs.append([tuple(t) for t in uvs])
            self.cols.append([tuple(c) for c in cols])
            self.smooth.append(smooth)

        def face(self, idx, uvs, cols, inside, smooth=True):
            """A face on shared vertices, turned to face away from `inside`."""
            pts = [Vector(self.verts[i]) for i in idx]
            n = Vector((0, 0, 0))
            for i in range(1, len(pts) - 1):
                n += (pts[i] - pts[0]).cross(pts[i + 1] - pts[0])
            if n.length < 1e-9:
                return
            if n.dot(sum(pts, Vector()) / len(pts) - Vector(inside)) < 0:
                idx, uvs = list(reversed(idx)), list(reversed(uvs))
                if not isinstance(cols[0], (int, float)):
                    cols = list(reversed(cols))
            self.f(idx, uvs, cols, smooth)

        def flat(self, pts, cols, interior=None, uvs=None):
            pts = [Vector(p) for p in pts]
            n = Vector((0, 0, 0))
            for i in range(1, len(pts) - 1):
                n += (pts[i] - pts[0]).cross(pts[i + 1] - pts[0])
            if n.length < 1e-7:
                return
            per_corner = not isinstance(cols[0], (int, float))
            if interior is not None and n.dot(sum(pts, Vector()) / len(pts) - Vector(interior)) < 0:
                pts.reverse()
                n = -n
                if per_corner:
                    cols = list(reversed(cols))
                if uvs:
                    uvs = list(reversed(uvs))
            if uvs is None:
                uvs = box_uv(pts, n)
            self.f([self.v(p) for p in pts], uvs, cols)

        def triangles(self):
            return sum(len(f) - 2 for f in self.faces)

        def bounds(self):
            lo = Vector(tuple(min(v[i] for v in self.verts) for i in range(3)))
            hi = Vector(tuple(max(v[i] for v in self.verts) for i in range(3)))
            return lo, hi

    def box_uv(pts, n):
        ax = max(range(3), key=lambda i: abs(n[i]))
        a, b = ((1, 2), (0, 2), (0, 1))[ax]
        return [(p[a], p[b]) for p in pts]

    def spline(ctrl, n):
        P = [Vector(c) for c in ctrl]
        m = len(P)
        out = []
        for j in range(n):
            t = j / (n - 1) * (m - 1)
            i = min(int(t), m - 2)
            f = t - i
            p0, p1, p2, p3 = P[max(i - 1, 0)], P[i], P[i + 1], P[min(i + 2, m - 1)]
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * f ** 3))
        return out

    def ramp(vals, n):
        m = len(vals)
        out = []
        for j in range(n):
            t = j / (n - 1) * (m - 1)
            i = min(int(t), m - 2)
            f = t - i
            out.append(vals[i] * (1 - f) + vals[i + 1] * f)
        return out

    def frames(path):
        n = len(path)
        T = [(path[min(i + 1, n - 1)] - path[max(i - 1, 0)]).normalized() for i in range(n)]
        ref = UP if abs(T[0].z) < 0.9 else Vector((1, 0, 0))
        N = [(ref - ref.dot(T[0]) * T[0]).normalized()]
        for i in range(1, n):
            prev = N[-1]
            axis = T[i - 1].cross(T[i])
            if axis.length > 1e-6:
                prev = Matrix.Rotation(T[i - 1].angle(T[i]), 3, axis.normalized()) @ prev
            N.append((prev - prev.dot(T[i]) * T[i]).normalized())
        return T, N

    def tube(G, path, radii, sides=6, col=(128, 128, 128), cap0=None, cap1=None, ring_fn=None,
             jag0=None, jag1=None, v0=0.0, u0=0.0, spin=0.0, smooth=True):
        """A limb along `path`; UV mirrored round it (no seam), V is the length in studs."""
        assert sides % 2 == 0, "even sides only: the mirrored UV needs it"
        path = [Vector(p) for p in path]
        T, N = frames(path)
        n = len(path)
        C = 2 * math.pi * max(radii)
        arc = [0.0]
        for i in range(1, n):
            arc.append(arc[-1] + (path[i] - path[i - 1]).length)
        rings, pos = [], []
        for i, (p, r) in enumerate(zip(path, radii)):
            B = T[i].cross(N[i])
            ring, ps = [], []
            for k in range(sides):
                a = 2 * math.pi * k / sides + spin
                rr = r * (ring_fn(i, k, a) if ring_fn else 1.0)
                q = p + (math.cos(a) * N[i] + math.sin(a) * B) * rr
                if i == 0 and jag0:
                    q -= T[i] * jag0[k % len(jag0)]
                if i == n - 1 and jag1:
                    q += T[i] * jag1[k % len(jag1)]
                ring.append(G.v(q))
                ps.append(q)
            rings.append(ring)
            pos.append(ps)

        def u(k):
            return C / 2 - abs(k / sides * C - C / 2) + u0

        for i in range(n - 1):
            for k in range(sides):
                k2 = (k + 1) % sides
                idx = [rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]]
                uv = [(u(k), arc[i] + v0), (u(k + 1), arc[i] + v0), (u(k + 1), arc[i + 1] + v0), (u(k), arc[i + 1] + v0)]
                c = col
                if callable(col):
                    mid = (pos[i][k] + pos[i][k2] + pos[i + 1][k2] + pos[i + 1][k]) / 4
                    axis_mid = (path[i] + path[i + 1]) / 2
                    c = col(i, k, mid, (mid - axis_mid).normalized())
                G.f(idx, uv, c, smooth)
        if cap0:
            cap(G, pos[0], -T[0], **cap0)
        if cap1:
            cap(G, pos[-1], T[-1], **cap1)
        return path, T

    def cap(G, pts, axis, col, depth=0.0, heart=None):
        c = sum(pts, Vector()) / len(pts) - axis * depth
        inside = c - axis * 2.0
        n = len(pts)
        if heart:
            hc, share = heart
            inner = [c + (p - c) * share + axis * depth * 0.5 for p in pts]
            for k in range(n):
                G.flat([pts[k], pts[(k + 1) % n], inner[(k + 1) % n], inner[k]], col, inside)
                G.flat([inner[k], inner[(k + 1) % n], c], hc, inside)
        else:
            for k in range(n):
                G.flat([pts[k], pts[(k + 1) % n], c], col, inside)

    def blob(G, center, radii, col, subdiv=2, seed=0, jit=0.12, freq=1.3, rot=None, smooth=False,
             floor=None, power=1.0, flat_top=None):
        """A lumpy ball (icosphere and slow noise). `col` is fn(point, normal). floor: cut flat at
        that height and closed. power < 1 squares it up. subdiv 2 = 80 triangles."""
        center = Vector(center)
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
        off = Vector((seed * 7.31 % 97, seed * 3.17 % 89, seed * 5.71 % 83))
        R = (rot.to_matrix() if isinstance(rot, Euler) else rot) if rot is not None else Matrix.Identity(3)
        for v in bm.verts:
            d = v.co.normalized()
            if power != 1.0:
                d = Vector(tuple(math.copysign(abs(c) ** power, c) for c in d))
            s = 1.0 + jit * 1.6 * noise.noise(d * freq + off)
            p = Vector((d.x * radii[0], d.y * radii[1], d.z * radii[2])) * s
            if flat_top is not None and p.z > radii[2] * flat_top:
                p.z = radii[2] * flat_top + (p.z - radii[2] * flat_top) * 0.35
            v.co = center + R @ p
        if floor is not None:
            geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
            res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, floor), plane_no=(0, 0, 1), clear_inner=True)
            edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
            if edges:
                filled = bmesh.ops.edgeloop_fill(bm, edges=edges)
                bmesh.ops.triangulate(bm, faces=filled["faces"])
        bm.normal_update()
        shared = {}
        for face in bm.faces:
            pts = [l.vert.co.copy() for l in face.loops]
            n = face.normal.copy()
            on_floor = floor is not None and all(abs(p.z - floor) < 1e-4 for p in pts)
            if smooth and not on_floor:
                idx = []
                for l in face.loops:
                    if l.vert.index not in shared:
                        shared[l.vert.index] = G.v(l.vert.co)
                    idx.append(shared[l.vert.index])
                G.f(idx, box_uv(pts, n), [col(p, l.vert.normal) for p, l in zip(pts, face.loops)], True)
            else:
                G.flat(pts, col(face.calc_center_median(), n), center + UP * 0.01 if on_floor else None)
        bm.free()

    def anchors(G, lo, hi, rgb):
        e = 0.02
        G.flat([lo, lo + Vector((e, 0, 0)), lo + Vector((0, e, 0))], rgb)
        G.flat([hi, hi - Vector((e, 0, 0)), hi - Vector((0, e, 0))], rgb)

    def leaf_col(deep, base, sun, zc, rz, tone=1.0, speck=None, rng=None):
        """Darker low and on the shaded side, lighter on top; `speck` = (colour, share) tints a
        few faces (wind-bronzed juniper tips, gold moss)."""
        def fn(p, n):
            h = clamp((p.z - (zc - rz)) / (2 * rz))
            t = 0.55 * h + 0.45 * (0.5 + 0.5 * n.z)
            c = mix(deep, base, t * 2) if t < 0.5 else mix(base, sun, t * 2 - 1)
            if speck and rng and n.z > -0.2 and rng.random() < speck[1]:
                c = mix(c, speck[0], 0.7)
            return shade(c, tone)
        return fn

    def jag(rng, sides, lo, hi):
        return [rng.uniform(lo, hi) if k % 2 == 0 else rng.uniform(lo, hi) * 0.25 for k in range(sides)]

    def frond(G, rng, az, length, e0, e1, width, stations=8, tone=1.0, pal=("cfern_deep", "cfern", "cfern_tip"),
              origin=None, teeth=True):
        """One arching frond, v along it. Leaves `origin` at e0 degrees above level, ends at e1."""
        d = Vector((math.cos(az), math.sin(az), 0))
        side = Vector((-d.y, d.x, 0))
        p = Vector(origin) if origin is not None else d * 0.12 + UP * -0.2
        L, S, Rr, V = [], [], [], []
        ds = length / (stations - 1)
        for i in range(stations):
            s = i / (stations - 1)
            e = math.radians(e0 + (e1 - e0) * s ** 0.9)
            if i:
                p = p + (d * math.cos(e) + UP * math.sin(e)) * ds
            nrm = -d * math.sin(e) + UP * math.cos(e)
            w = width * (math.sin(math.pi * min(1.0, s * 1.02 + 0.06)) ** 0.75)
            if teeth:
                w *= 1.22 if i % 2 else 0.74
            w = max(w, 0.03)
            L.append(p - side * w)
            Rr.append(p + side * w)
            S.append(p + nrm * (0.16 * w + 0.02))
            V.append(i * ds)
        for i in range(stations - 1):
            s = (i + 0.5) / (stations - 1)
            c = shade(mix(PAL[pal[0]], PAL[pal[1]], s * 2.2) if s < 0.45 else mix(PAL[pal[1]], PAL[pal[2]], (s - 0.45) * 1.8), tone)
            wl, wl2 = (L[i] - Rr[i]).length / 2, (L[i + 1] - Rr[i + 1]).length / 2
            inside = (L[i] + Rr[i] + S[i] + L[i + 1] + Rr[i + 1] + S[i + 1]) / 6
            G.flat([L[i], S[i], S[i + 1], L[i + 1]], c, inside, uvs=[(-wl, V[i]), (0, V[i]), (0, V[i + 1]), (-wl2, V[i + 1])])
            G.flat([S[i], Rr[i], Rr[i + 1], S[i + 1]], shade(c, 0.94), inside, uvs=[(0, V[i]), (wl, V[i]), (wl2, V[i + 1]), (0, V[i + 1])])
            G.flat([L[i], L[i + 1], Rr[i + 1], Rr[i]], shade(c, 0.7), inside, uvs=[(-wl, V[i]), (-wl2, V[i + 1]), (wl2, V[i + 1]), (wl, V[i])])
        G.flat([L[0], Rr[0], S[0]], PAL[pal[0]], (L[1] + Rr[1] + S[1]) / 3)
        G.flat([L[-1], S[-1], Rr[-1]], PAL[pal[2]], (L[-2] + Rr[-2] + S[-2]) / 3)

    def path_at(path):
        def at(z):
            for a, b in zip(path, path[1:]):
                if a.z <= z <= b.z:
                    return a.lerp(b, (z - a.z) / max(b.z - a.z, 1e-6))
            return path[-1].copy() if z > path[-1].z else path[0].copy()
        return at

    def stub(G, p0, az, length, r, col, end_col, droop=0.12):
        h = Vector((math.cos(az), math.sin(az), 0))
        pts = [p0, p0 + h * length * 0.55 + UP * 0.05, p0 + h * length - UP * droop * length]
        tube(G, pts, [r, r * 0.7, r * 0.4], 4, col, cap1={"col": end_col, "depth": 0.0}, spin=0.6)

    def bark_col(rng, keys, z_hi, strips=None):
        """Bark: darker at the foot, a slow change up the trunk, a fleck per face; `strips`
        (colour, share) paints vertical strips round the trunk (a cedar's stringy bark)."""
        dark, base, high = (PAL[k] for k in keys)
        fl, st = {}, {}

        def fn(i, k, mid, out):
            f = fl.setdefault((i, k), rng.random())
            c = mix(dark, base, clamp(mid.z / 3.0 + 0.25))
            c = mix(c, high, clamp((mid.z - z_hi * 0.5) / (z_hi * 0.5)) * 0.6)
            if strips and st.setdefault(k, rng.random()) < strips[1]:
                c = mix(c, strips[0], 0.6 + 0.3 * f)
            return shade(c, 0.93 + 0.14 * f)
        return fn

    # ------------------------------------------------------------------ 1. the cedar
    def cedar():
        """A western red cedar, 18 studs: a fluted, flared red trunk with silver strips, drooping
        sprays shingled round a dark core, a nodding leader. The crown's reach at each height and on each side
        follows the PlantFactory Thuja plicata export (plant_envelopes.json)."""
        env = ENV["thuja-plicata-s0"]
        rng = random.Random(901)
        bark, leaf = Geo(), Geo()
        Ht = 18.0
        # Real cedars are too slender for this game's chunky shapes: the measured crown keeps its
        # shape but is widened, and the trunk is about three times the real thickness.
        widen = 1.9
        Rtab = env["R"]
        nb, ns = env["bins"], env["sectors"]

        def reach(zf, a):
            """The measured crown radius (studs) at height fraction zf, toward angle a."""
            t = clamp(zf * nb - 0.5, 0, nb - 1)
            b = min(int(t), nb - 2)
            fb = t - b
            s = (a % (2 * math.pi)) / (2 * math.pi) * ns - 0.5
            s0 = int(math.floor(s)) % ns
            fs = s - math.floor(s)

            def at(bb):
                row = Rtab[bb]
                return row[s0] * (1 - fs) + row[(s0 + 1) % ns] * fs
            return (at(b) * (1 - fb) + at(b + 1) * fb) * Ht * widen

        n = 14
        path = spline([(0, 0, -1.0), (0.05, 0.0, 2.0), (0.15, 0.06, 7.0), (0.12, 0.12, 12.0), (0.05, 0.16, 15.8),
                       (0.45, 0.2, 17.2), (1.05, 0.18, 17.75)], n)
        col = bark_col(rng, ("cedar_bark_dark", "cedar_bark", "cedar_bark"), Ht, strips=(PAL["cedar_bark_grey"], 0.35))
        r0 = 0.72   # about twice a real cedar's trunk at this height: chunky, not a cone

        def flute(i, k, a):
            if i == 0:
                return 1 + 0.3 * (0.5 + 0.5 * math.cos(5 * a + 0.4)) + 0.08
            if i == 1:
                return 1 + 0.14 * math.cos(5 * a + 0.4)
            return 1 + 0.06 * math.cos(7 * a + i * 0.5)

        tube(bark, path, ramp([r0 * 1.3, r0, r0 * 0.8, r0 * 0.58, r0 * 0.34, r0 * 0.16, 0.05], n), 8, col,
             ring_fn=flute, cap0={"col": PAL["cedar_bark_dark"]})
        at = path_at(path)
        for z, az, length in ((2.6, 0.7, 1.1), (3.4, 3.4, 0.9), (4.0, 5.2, 1.3)):
            stub(bark, at(z), az, length, 0.12, col, PAL["cedar_bark_grey"])
        keys = ("cedar_leaf_sun", "cedar_leaf", "cedar_leaf_deep")
        z_base = max(4.6, env["crown_base"] * Ht)
        z_top = 16.2
        mean_r = lambda zf: sum(reach(zf, 2 * math.pi * s / ns) for s in range(ns)) / ns
        # a dark core so no daylight shows through the middle of the column
        for z0, z1, share in ((z_base + 0.6, 11.5, 0.5), (10.5, z_top, 0.45)):
            zc = (z0 + z1) / 2
            r = mean_r(zc / Ht) * share
            fn = leaf_col(PAL["cedar_leaf_deep"], PAL["cedar_leaf_deep"], PAL["cedar_leaf"], zc, (z1 - z0) / 2, 1.0)
            blob(leaf, at(zc), (r, r * 0.92, (z1 - z0) / 2), fn, 2, seed=rng.randrange(999), jit=0.16, freq=1.4)
        # the sprays: drooping, shingled up a spiral, each reaching as far as the measured crown
        # does on its side at its height (the bulge at 0.4 of the height and the lopsided top)
        count = 9
        for j in range(count):
            f = (j + 0.5) / count
            z = z_base + 0.3 + (z_top - 0.8 - z_base) * f ** 0.85
            a = j * 2.39996 + rng.uniform(-0.25, 0.25)
            R = max(1.3, reach(z / Ht, a))
            u = Vector((math.cos(a), math.sin(a), 0))
            c = at(z) + u * R * 0.58 - UP * (0.2 + 0.14 * R)
            if j < 2:   # the lowest two hang from a bare limb you can see
                p0 = at(z + 0.4)
                tube(bark, [p0, p0 + u * R * 0.45 - UP * 0.15, c + u * R * 0.2], [0.2, 0.13, 0.05], 4, col, spin=0.4)
            fn = leaf_col(PAL["cedar_leaf_deep"], PAL["cedar_leaf"], PAL["cedar_leaf_sun"], c.z, 0.7, rng.uniform(0.95, 1.05))
            blob(leaf, c, (R * 0.68, R * 0.42, 0.42 + 0.08 * R), fn, 2, seed=rng.randrange(999), jit=0.2, freq=1.7,
                 rot=Euler((rng.uniform(-0.12, 0.12), 0.55, a)), power=0.92)
        # the nodding leader ends in a slim hanging spray, not a ball
        tip = path[-1]
        nod = (path[-1] - path[-3]).normalized()
        fn = leaf_col(PAL["cedar_leaf"], PAL["cedar_leaf"], PAL["cedar_leaf_sun"], tip.z, 0.5, 1.02)
        blob(leaf, tip - UP * 0.7 + nod * 0.15, (0.95, 0.4, 0.42), fn, 2, seed=77, jit=0.12, rot=Euler((0, 1.0, math.atan2(nod.y, nod.x))))
        return {"bark": bark, "leaf": leaf}, {
            "keys": {"bark": ["cedar_bark", "cedar_bark_grey", "cedar_bark_dark"], "leaf": list(keys)},
            "foot_centred": True, "source": env["source"]}

    # ------------------------------------------------------------------ 2. the mossy log
    def mossy_log():
        """A fallen cedar log, 24 studs, to bridge the pool: a root plate at +X, a broken end at
        -X, branch stubs, moss along its top with two small ferns."""
        rng = random.Random(911)
        bark, leaf = Geo(), Geo()
        n = 14
        L = 24.0
        path = spline([(-L / 2, 0.0, 1.05), (-L / 4, 0.25, 1.15), (0.0, 0.1, 1.2), (L / 4, -0.2, 1.22), (L / 2 - 1.3, -0.1, 1.3)], n)
        radii = ramp([0.92, 0.98, 1.04, 1.1, 1.22], n)
        flk = {}

        def col(i, k, mid, out):
            f = flk.setdefault((i, k), rng.random())
            c = mix(PAL["log_dark"], PAL["log"], 0.55 + 0.6 * out.z)
            c = mix(c, PAL["log_grey"], clamp(out.z) * 0.5)
            return shade(c, 0.92 + 0.15 * f)

        tube(bark, path, radii, 10, col, ring_fn=lambda i, k, a: 1 + 0.06 * math.sin(i * 1.9 + k * 1.4),
             jag0=[0.9, 0.2, 0.55, 1.2, 0.1, 0.7, 0.3, 1.0, 0.15, 0.5], cap0={"col": PAL["log_dark"], "depth": 0.6},
             cap1={"col": PAL["log_end"], "heart": (PAL["log_heart"], 0.45)})
        # the root wad: a plate of dark earth and root torn up with the tree, roots splaying from it
        end = path[-1]
        wad = end + Vector((0.55, 0, 0.35))
        blob(bark, wad, (0.85, 2.7, 2.2), lambda p, n: shade(mix(PAL["root_dark"], PAL["root"], 0.3 + 0.4 * clamp(n.z)), 0.92 + 0.1 * rng.random()),
             2, seed=13, jit=0.22, freq=1.6, floor=0.02)
        rp_col = lambda i, k, mid, out: shade(mix(PAL["root_dark"], PAL["root"], 0.5 + 0.5 * out.z), 0.95 + 0.1 * rng.random())
        for j in range(7):
            a = 2 * math.pi * j / 7 + rng.uniform(-0.3, 0.3)
            dvec = Vector((0.0, math.cos(a), math.sin(a)))
            Lr = rng.uniform(0.9, 1.7)
            p0 = wad + dvec * 1.6 + Vector((0.3, 0, 0))
            pts = spline([p0, p0 + dvec * Lr * 0.5 + Vector((0.6, 0, 0)), p0 + dvec * Lr + Vector((1.0, 0, -0.4))], 4)
            pts = [Vector((p.x, p.y, max(p.z, 0.08))) for p in pts]
            tube(bark, pts, ramp([0.36, 0.24, 0.12], 4), 6, rp_col, spin=j, cap1={"col": PAL["root_pale"]})
        # branch stubs
        at_x = lambda x: path[min(range(n), key=lambda i: abs(path[i].x - x))]
        for x, az, el, length in ((-6.5, 1.3, 0.6, 1.4), (-1.5, -1.9, 0.3, 1.1), (3.5, 1.7, 0.9, 1.7), (7.8, -1.2, 0.2, 1.0)):
            p0 = at_x(x)
            dvec = Vector((0.15, math.cos(az) * math.cos(el), math.sin(el))).normalized()
            pts = [p0 + dvec * 0.6, p0 + dvec * (0.6 + length * 0.6), p0 + dvec * (0.6 + length)]
            tube(bark, pts, [0.22, 0.17, 0.12], 6, col, cap1={"col": PAL["log_end"], "depth": 0.04}, jag1=jag(rng, 6, 0.0, 0.2))
        # moss along the top: strips over about the top third, thicker in the middle
        T, N = frames(path)
        strips = [(1, 6), (7, 13)]
        cols_n = 5
        for i0, i1 in strips:
            grid = []
            for i in range(i0, i1 + 1):
                side = T[i].cross(UP).normalized()
                up = side.cross(T[i]).normalized()
                half = (0.75 + 0.35 * noise.noise(Vector((i * 0.7, 3.1, 0.0)))) * (0.35 if i in (i0, i1) else 1.0)
                row = []
                for m in range(cols_n):
                    t = -1 + 2 * m / (cols_n - 1)
                    phi = t * half
                    off = 0.14 * math.cos(t * math.pi / 2) * (1.0 if i not in (i0, i1) else 0.3) + 0.01
                    off += 0.05 * noise.noise(Vector((i * 1.3, m * 1.7, 5.0)))
                    p = path[i] + (math.sin(phi) * side + math.cos(phi) * up) * (radii[i] + off)
                    row.append((leaf.v(p), p, phi * radii[i]))
                grid.append(row)
            for a in range(len(grid) - 1):
                for m in range(cols_n - 1):
                    q = [grid[a][m], grid[a][m + 1], grid[a + 1][m + 1], grid[a + 1][m]]
                    mid = sum((x[1] for x in q), Vector()) / 4
                    inside = path[i0 + a] - UP * 0.5
                    edge = m in (0, cols_n - 2)
                    c = PAL["moss_deep"] if edge else (PAL["moss_sun"] if rng.random() < 0.35 else PAL["moss"])
                    if rng.random() < 0.08:
                        c = PAL["moss_gold"]
                    leaf.face([x[0] for x in q], [(x[1].x, x[2]) for x in q], shade(c, rng.uniform(0.95, 1.05)), inside)
        # two small ferns growing from the log, and moss caps on two stubs
        for x, az in ((-3.2, 0.3), (5.6, 2.2)):
            p0 = at_x(x)
            top = p0 + UP * (radii[0] + 0.12)
            for k in range(4):
                frond(leaf, rng, az + k * 1.6 + rng.uniform(-0.3, 0.3), rng.uniform(0.9, 1.2), 70, -10, 0.24, stations=5,
                      tone=rng.uniform(0.95, 1.05), origin=top)
        for x, az, el, length in ((3.5, 1.7, 0.9, 1.7), (-6.5, 1.3, 0.6, 1.4)):
            p0 = at_x(x)
            dvec = Vector((0.15, math.cos(az) * math.cos(el), math.sin(el))).normalized()
            c = p0 + dvec * (0.6 + length) + UP * 0.05
            blob(leaf, c, (0.26, 0.26, 0.12), leaf_col(PAL["moss_deep"], PAL["moss"], PAL["moss_sun"], c.z, 0.12), 1, seed=int(x * 10) % 97)
        return {"bark": bark, "leaf": leaf}, {
            "keys": {"bark": ["log", "log_grey", "log_dark", "log_end", "root"], "leaf": ["moss", "moss_sun", "moss_deep", "cfern"]},
            "foot_centred": True, "ground": "ends"}

    # ------------------------------------------------------------------ 3. roots on a cut bank
    def creek_roots():
        """Roots washed out of a cut bank: they leave the bank face (the plane x = 0, the bank is
        x < 0), loop and hang toward +X and down, some back into the bank, some dangling. The
        ground line (z = 0) is the bank's lip."""
        rng = random.Random(921)
        G = Geo()

        def col(i, k, mid, out):
            c = mix(PAL["root_dark"], PAL["root"], 0.5 + 0.5 * out.z)
            if mid.x > 0.6:   # the parts out in the air are washed paler
                c = mix(c, PAL["root_pale"], 0.35 * clamp(mid.x - 0.6))
            return shade(c, 0.92 + 0.14 * rng.random())

        spec = [  # (y, z of exit, reach out, hang depth, back into the bank?, radius)
            (-2.4, -0.5, 1.3, 2.2, True, 0.22), (-1.1, -0.3, 1.8, 3.2, False, 0.17), (0.2, -0.7, 1.1, 1.6, True, 0.3),
            (1.3, -0.4, 1.6, 2.8, False, 0.14), (2.5, -0.9, 1.0, 2.3, True, 0.2), (-0.4, -1.6, 0.9, 1.9, False, 0.12),
            (1.9, -1.8, 1.2, 1.4, True, 0.16), (-2.0, -2.0, 0.8, 1.2, False, 0.1),
        ]
        for j, (y, z, out, hang, back, r) in enumerate(spec):
            y2 = y + rng.uniform(-0.6, 0.6)
            if back:   # a loop: out of the bank, down and back in lower
                ctrl = [(-0.5, y, z + 0.15), (0.3, y, z), (out, (y + y2) / 2, z - hang * 0.45), (out * 0.6, y2, z - hang * 0.9), (-0.4, y2, z - hang)]
                rr = [r, r, r * 0.85, r * 0.75, r * 0.7]
            else:      # a dangling root, tapering to a point
                ctrl = [(-0.5, y, z + 0.15), (0.35, y, z - 0.05), (out, (y + y2) / 2, z - hang * 0.4), (out * 1.05, y2, z - hang * 0.8), (out * 0.95, y2 + 0.2, z - hang)]
                rr = [r, r, r * 0.7, r * 0.4, 0.03]
            pts = spline(ctrl, 6)
            tube(G, pts, ramp([x * 1.3 for x in rr], 6), 6 if r >= 0.18 else 4, col, spin=j * 0.7)
            if not back and r > 0.13:   # rootlets off the dangling ones
                for t in (2, 3):
                    p = pts[t]
                    dd = Vector((rng.uniform(0.1, 0.5), rng.uniform(-0.6, 0.6), -rng.uniform(0.4, 0.8)))
                    tube(G, [p, p + dd * 0.5, p + dd + Vector((0, 0, -0.2))], [r * 0.4, r * 0.25, 0.02], 4, col)
        # a few fine hairs right under the lip
        for k in range(6):
            y = rng.uniform(-2.8, 2.8)
            p = Vector((-0.2, y, -0.15))
            dd = Vector((rng.uniform(0.3, 0.6), rng.uniform(-0.3, 0.3), -rng.uniform(0.6, 1.1)))
            tube(G, [p, p + dd * 0.5 + Vector((0.15, 0, 0)), p + dd], [0.05, 0.035, 0.01], 4, col)
        return {"bark": G}, {"keys": {"bark": ["root", "root_dark", "root_pale"]}, "ground": "lip"}

    # ------------------------------------------------------------------ 4. creek ferns
    def creek_fern(variant):
        rng = random.Random(930 + variant)
        G = Geo()
        if variant == 1:   # a lady fern: a full arching vase, about 4 studs across and 2 high
            count = 11
            a0 = rng.uniform(0, 6.28)
            for k in range(count):
                az = a0 + 2 * math.pi * k / count + rng.uniform(-0.25, 0.25)
                frond(G, rng, az, rng.uniform(2.1, 2.6), rng.uniform(70, 80), rng.uniform(-28, -6), rng.uniform(0.4, 0.5),
                      stations=7, tone=rng.uniform(0.93, 1.06))
            for k in range(2):
                frond(G, rng, rng.uniform(0, 6.28), rng.uniform(1.3, 1.7), 88, 62, 0.26, stations=5, tone=1.07)
        else:              # a fern on a lip: a fan that spills over the edge toward +X
            for k in range(9):
                az = math.radians(-70 + 140 * k / 8) + rng.uniform(-0.12, 0.12)
                frond(G, rng, az, rng.uniform(2.2, 2.9), rng.uniform(30, 48), rng.uniform(-80, -62), rng.uniform(0.36, 0.46),
                      stations=7, tone=rng.uniform(0.93, 1.05), origin=Vector((0.0, 0.0, 0.05)))
            for k in range(3):   # a few shorter fronds standing up behind, on the bank
                az = math.radians(180 + rng.uniform(-50, 50))
                frond(G, rng, az, rng.uniform(1.2, 1.6), 82, 30, 0.3, stations=5, tone=rng.uniform(0.97, 1.06))
        return {"leaf": G}, {"keys": {"leaf": ["cfern", "cfern_tip", "cfern_deep"]}, "foot_centred": variant == 2,
                             "ground": "lip" if variant == 2 else None}

    # ------------------------------------------------------------------ 5. the moss mat
    def moss_mat():
        """A thick cap of moss for the top of a boulder: a dome 6.4 by 4.8 studs whose edge drops
        1.1 studs below its middle, a lumpy top, a lobed edge that curls down."""
        rng = random.Random(941)
        G = Geo()
        rx, ry, drop = 3.2, 2.4, 1.1
        rings, segs = 5, 18
        lobe = [1.0 + 0.16 * noise.noise(Vector((math.cos(2 * math.pi * k / segs) * 1.4, math.sin(2 * math.pi * k / segs) * 1.4, 2.0)))
                + (0.14 if k % 5 == 2 else 0.0) for k in range(segs)]

        def surf(u, k, lift):
            a = 2 * math.pi * k / segs
            r = u * lobe[k]
            x, y = rx * r * math.cos(a), ry * r * math.sin(a)
            z = drop * (1 - min(r, 1.15) ** 2)
            bump = 0.07 * noise.noise(Vector((x * 0.9, y * 0.9, 7.0))) * (1 - u ** 2)
            return Vector((x, y, z + lift * (0.2 * (1 - u ** 3) + 0.05) + bump))

        centre = G.v(Vector((0, 0, drop + 0.25)))
        top = [[G.v(surf(j / rings, k, 1.0)) for k in range(segs)] for j in range(1, rings + 1)]
        lip = [G.v(surf(1.06, k, 0.0) - UP * 0.12) for k in range(segs)]
        base_c = G.v(Vector((0, 0, drop - 0.12)))
        inside = Vector((0, 0, -4.0))

        def col_at(i):
            p = Vector(G.verts[i])
            h = clamp(p.z / (drop + 0.25))
            c = mix(PAL["moss_deep"], PAL["moss"], h * 1.6) if h < 0.6 else mix(PAL["moss"], PAL["moss_sun"], (h - 0.6) * 2.4)
            if noise.noise(p * 1.7 + Vector((3, 1, 0))) > 0.35:
                c = mix(c, PAL["moss_gold"], 0.6)
            return c

        def uv(i):
            p = G.verts[i]
            return (p[0], p[1])

        for k in range(segs):
            k2 = (k + 1) % segs
            idx = [centre, top[0][k], top[0][k2]]
            G.face(idx, [uv(i) for i in idx], [col_at(i) for i in idx], inside)
            for j in range(rings - 1):
                idx = [top[j][k], top[j + 1][k], top[j + 1][k2], top[j][k2]]
                G.face(idx, [uv(i) for i in idx], [col_at(i) for i in idx], inside)
            idx = [top[-1][k], lip[k], lip[k2], top[-1][k2]]
            G.face(idx, [uv(i) for i in idx], [shade(PAL["moss_deep"], 0.9)] * 4, Vector((0, 0, drop * 0.3)))
            idx = [base_c, lip[k2], lip[k]]
            G.face(idx, [uv(i) for i in idx], [PAL["moss_deep"]] * 3, Vector((0, 0, drop + 3.0)), smooth=False)
        return {"leaf": G}, {"keys": {"leaf": ["moss", "moss_sun", "moss_deep", "moss_gold"]}, "ground": "rock"}

    # ------------------------------------------------------------------ 6. the island's lone pine
    def lone_pine():
        """The landmark: a 34 stud pine bent by the wind into a flag. The trunk leans and bows
        toward +X; the crown is a stack of flat needle pads streaming downwind; dead stubs
        point upwind and a bleached snag tops it, so its outline reads from far away."""
        rng = random.Random(951)
        bark, leaf = Geo(), Geo()
        n = 14
        path = spline([(0, 0, -1.5), (0.3, 0.0, 4.0), (1.4, 0.2, 10.0), (3.4, 0.1, 16.0), (6.2, -0.2, 21.5), (9.0, -0.3, 25.5),
                       (11.0, -0.1, 28.0)], n)
        col = bark_col(rng, ("lpine_bark_dark", "lpine_bark", "lpine_bark_red"), 28)
        flare = lambda i, k, a: 1 + (0.32 * (0.5 + 0.5 * math.cos(4 * a + 0.8)) + 0.1 if i == 0 else 0.12 * math.cos(4 * a + 0.8) if i == 1 else 0.04 * math.cos(3 * a + i))
        tube(bark, path, ramp([1.35, 1.05, 0.85, 0.68, 0.5, 0.32, 0.13], n), 8, col, ring_fn=flare, cap0={"col": PAL["lpine_bark_dark"]})
        at = path_at(path)
        dead = lambda i, k, mid, out: shade(mix(PAL["lpine_dead"], PAL["lpine_bark_dark"], 0.25 * (1 - out.z)), 0.94 + 0.1 * rng.random())
        # upwind: dead stubs, short and pointing -X
        for z, az, length in ((9.0, math.radians(175), 1.8), (12.5, math.radians(200), 2.4), (15.5, math.radians(160), 1.6),
                              (6.5, math.radians(120), 1.2), (18.5, math.radians(215), 1.3)):
            stub(bark, at(z), az, length, 0.18, dead, PAL["lpine_dead"], droop=0.05)
        # the snag: the old leader, dead, standing above the crown
        top = at(25.0)
        tube(bark, spline([top, top + Vector((0.4, 0.1, 2.2)), top + Vector((0.3, 0.2, 4.6))], 4), ramp([0.26, 0.17, 0.05], 4), 6, dead)
        # limbs streaming downwind. One long low limb with its own pad (the gap under it is the
        # signature), then the flag: big lumpy pads massed in the top two fifths, reaching downwind.
        def pad(c, rx, ry, rz, az, tilt=0.0, tone=1.0):
            fn = leaf_col(PAL["lpine_needle_deep"], PAL["lpine_needle"], PAL["lpine_needle_sun"], c.z, rz, tone)
            blob(leaf, c, (rx, ry, rz), fn, 2, seed=rng.randrange(999), jit=0.3, freq=1.9, rot=Euler((0, tilt, az)),
                 power=0.92, flat_top=0.55)

        limbs = [  # (height, direction, length, rise, pad reach, pad depth, pad thickness)
            (12.0, math.radians(12), 10.0, 1.0, 3.4, 2.6, 1.35),
            (18.0, math.radians(-28), 7.5, 1.2, 3.6, 2.9, 1.6),
            (20.0, math.radians(32), 8.5, 1.4, 4.0, 3.0, 1.7),
            (22.5, math.radians(-8), 7.5, 1.1, 3.8, 3.2, 1.7),
        ]
        for z, az, length, rise, prx, pry, prz in limbs:
            p0 = at(z)
            h = Vector((math.cos(az), math.sin(az), 0))
            pts = spline([p0, p0 + h * length * 0.4 + UP * rise * 0.6, p0 + h * length * 0.78 + UP * rise * 1.0,
                          p0 + h * length + UP * rise * 0.9], 5)
            r = 0.2 + 0.04 * length
            tube(bark, pts, ramp([r, r * 0.7, r * 0.45, 0.08], 5), 4, col, spin=0.4)
            pad(pts[3] + UP * (prz * 0.55), prx, pry, prz, az, -0.04, rng.uniform(0.95, 1.05))
            pad(pts[1] + h * length * 0.05 + UP * (prz * 0.5), prx * 0.62, pry * 0.7, prz * 0.85, az + 0.5, 0.0, rng.uniform(0.9, 0.98))
        # the crown cap: wide and lumpy, downwind of the snag, and a second mass under it
        pad(at(26.0) + Vector((2.6, 0.0, 1.3)), 5.0, 3.6, 1.8, 0.05, 0.0, 1.05)
        pad(at(24.0) + Vector((5.2, -0.6, 0.4)), 3.4, 2.8, 1.5, -0.2, 0.05, 0.98)
        return {"bark": bark, "leaf": leaf}, {
            "keys": {"bark": ["lpine_bark", "lpine_bark_dark", "lpine_bark_red", "lpine_dead"],
                     "leaf": ["lpine_needle", "lpine_needle_sun", "lpine_needle_deep"]},
            "foot_centred": True}

    # ------------------------------------------------------------------ 7. junipers
    def juniper(variant):
        rng = random.Random(960 + variant)
        bark, leaf = Geo(), Geo()
        bcol = lambda i, k, mid, out: shade(mix(PAL["juniper_bark"], PAL["juniper_dead"], 0.2 + 0.25 * out.z), 0.92 + 0.14 * rng.random())
        dcol = lambda i, k, mid, out: shade(mix(PAL["juniper_dead"], PAL["juniper_bark"], 0.2 * (1 - out.z)), 0.95 + 0.1 * rng.random())

        def mass(c, radii, az, tilt=0.0, sub=2, floor=-0.2, flat_top=0.8, tone=1.0):
            fn = leaf_col(PAL["juniper_deep"], PAL["juniper"], PAL["juniper_sun"], c[2], radii[2], tone,
                          speck=(PAL["juniper_bronze"], 0.06), rng=rng)
            blob(leaf, c, radii, fn, sub, seed=rng.randrange(999), jit=0.3, freq=2.6, rot=Euler((0, tilt, az)),
                 floor=floor, power=1.0, flat_top=flat_top)

        if variant == 1:   # a creeping mat, about 7 by 5 studs and 1.2 high, in arms
            mass((0.0, 0.0, 0.35), (1.6, 1.4, 0.85), 0.3)
            for k, (az, L) in enumerate(((0.2, 3.2), (1.3, 2.4), (2.5, 2.9), (3.6, 2.1), (4.6, 3.0), (5.6, 2.3))):
                h = Vector((math.cos(az), math.sin(az), 0))
                c = h * L * 0.62 + UP * 0.1
                mass(c, (L * 0.55, 0.9 * rng.uniform(0.8, 1.1), 0.6), az, tone=rng.uniform(0.95, 1.05))
                if k % 2 == 0:   # a gnarled limb shows at the tip of every other arm
                    p0 = h * L * 0.7 + UP * 0.1
                    tube(bark, [p0, p0 + h * 0.6 + UP * 0.15, p0 + h * 1.15 + UP * 0.05 + Vector((-h.y, h.x, 0)) * 0.3],
                         [0.14, 0.1, 0.05], 4, bcol, spin=k)
            tube(bark, [Vector((0, 0, -0.4)), Vector((0.1, 0.05, 0.3))], [0.32, 0.26], 6, bcol)
        else:              # a wind-shorn shrub, 3 studs high, streaming toward +X
            trunk = spline([(0, 0, -0.6), (0.25, 0.1, 0.7), (0.9, 0.0, 1.4), (1.8, -0.15, 1.85)], 6)
            tube(bark, trunk, ramp([0.42, 0.32, 0.22, 0.12], 6), 6, bcol, cap0={"col": PAL["juniper_bark"]},
                 ring_fn=lambda i, k, a: 1 + 0.12 * math.cos(3 * a + i * 0.9))
            for p, az, L in ((trunk[2], math.radians(30), 1.6), (trunk[3], math.radians(-35), 1.8), (trunk[4], math.radians(10), 1.5)):
                h = Vector((math.cos(az), math.sin(az), 0))
                tube(bark, [p, p + h * L * 0.6 + UP * 0.25, p + h * L + UP * 0.2], [0.13, 0.09, 0.04], 4, bcol)
            # the bleached dead limb, pointing upwind
            p = trunk[2]
            tube(bark, spline([p, p + Vector((-0.8, 0.3, 0.55)), p + Vector((-1.6, 0.45, 1.25)), p + Vector((-2.1, 0.5, 1.9))], 5),
                 [0.15, 0.12, 0.08, 0.03, 0.02], 6, dcol)
            mass((1.3, 0.0, 1.9), (2.2, 1.7, 1.15), 0.0, -0.12, floor=None, flat_top=0.6, tone=1.03)
            mass((3.1, -0.2, 1.35), (1.6, 1.2, 0.85), -0.1, 0.18, floor=None, flat_top=0.7)
            mass((0.4, 0.8, 0.55), (1.35, 1.0, 0.7), 0.6, 0.0)
            mass((0.6, -0.9, 0.5), (1.3, 1.0, 0.65), -0.5, 0.0)
            mass((2.2, 0.2, 0.45), (1.4, 1.2, 0.6), 0.2, 0.0)
        return {"bark": bark, "leaf": leaf}, {
            "keys": {"bark": ["juniper_bark", "juniper_dead"], "leaf": ["juniper", "juniper_sun", "juniper_deep", "juniper_bronze"]},
            "foot_centred": True}

    # ------------------------------------------------------------------ 8. heath and lichen
    def heath_tufts():
        """A drift of heather: three low cushions (the dark woody base, one greener) and on and
        round them five brushy tufts of upright toothed sprigs, so the outline is twiggy, not a
        stone's."""
        rng = random.Random(971)
        G = Geo()
        spec = [(0.0, 0.0, 1.1, 0.9, 0.42, "heath"), (1.6, 0.5, 0.8, 0.7, 0.34, "heath_green"), (-1.4, 0.4, 0.8, 0.7, 0.32, "heath")]
        for x, y, rx, ry, rz, key in spec:
            fn = leaf_col(PAL["heath_dark"], PAL[key], PAL["heath"], rz * 0.4, rz, rng.uniform(0.95, 1.05))
            blob(G, (x, y, rz * 0.3), (rx, ry, rz), fn, 2, seed=rng.randrange(999), jit=0.32, freq=3.2,
                 rot=Euler((0, 0, rng.uniform(0, 3.1))), floor=-0.15, power=1.0)
        tufts = [(0.1, 0.1, 0.45), (1.5, 0.6, 0.34), (-1.3, 0.3, 0.3), (0.7, -1.1, 0.0), (-0.6, -1.0, 0.0)]
        for x, y, z in tufts:
            a0 = rng.uniform(0, 6.28)
            for k in range(5):
                a = a0 + 2 * math.pi * k / 5 + rng.uniform(-0.3, 0.3)
                frond(G, rng, a, rng.uniform(0.55, 0.85), rng.uniform(72, 84), rng.uniform(40, 62), rng.uniform(0.13, 0.18),
                      stations=3, tone=rng.uniform(0.92, 1.08), pal=("heath_dark", "heath", "heath_dry"),
                      origin=Vector((x, y, z - 0.1)))
        return {"leaf": G}, {"keys": {"leaf": ["heath", "heath_dark", "heath_dry", "heath_green"]}}

    def lichen_tufts():
        """Reindeer-lichen cushions: pale, knobbly, low."""
        rng = random.Random(981)
        G = Geo()
        spec = [(0.0, 0.0, 0.8, 0.7, 0.42), (1.2, 0.5, 0.55, 0.5, 0.32), (-1.0, 0.6, 0.6, 0.55, 0.34), (0.4, -1.0, 0.5, 0.45, 0.28)]
        for x, y, rx, ry, rz in spec:
            fn = leaf_col(PAL["lichen_shade"], PAL["lichen"], PAL["lichen_pale"], rz * 0.4, rz, rng.uniform(0.96, 1.04))
            blob(G, (x, y, rz * 0.3), (rx, ry, rz), fn, 2, seed=rng.randrange(999), jit=0.3, freq=3.4,
                 rot=Euler((0, 0, rng.uniform(0, 3.1))), floor=-0.1, power=0.9)
        return {"leaf": G}, {"keys": {"leaf": ["lichen", "lichen_pale", "lichen_shade"]}}

    def lichen_crust():
        """Rosettes of crust lichen to lie on the granite: orange ones and grey-green ones, each a
        scalloped disc 0.3 to 1.3 studs across, a few hundredths of a stud thick."""
        rng = random.Random(991)
        G = Geo()
        spec = [(0.0, 0.0, 0.65, "o"), (1.1, 0.4, 0.45, "o"), (-0.9, 0.7, 0.5, "g"), (0.5, -0.9, 0.38, "o"), (-1.4, -0.4, 0.3, "o"),
                (1.8, -0.5, 0.55, "g"), (-0.2, 1.3, 0.32, "o"), (0.9, 1.2, 0.25, "g"), (-1.9, 0.9, 0.22, "o"), (2.3, 0.7, 0.3, "o")]
        m = 10
        for x, y, r, kind in spec:
            a0, ph = rng.uniform(0, 6.28), rng.uniform(0, 6.28)
            rim_c = PAL["lichen_orange_dark"] if kind == "o" else PAL["lichen_shade"]
            mid_c = PAL["lichen_orange"] if kind == "o" else rng.choice((PAL["lichen"], PAL["lichen_grey"]))
            ctr = Vector((x, y, 0.05 + 0.01 * r))
            rim, low = [], []
            for k in range(m):
                a = a0 + 2 * math.pi * k / m
                rr = r * (1 + 0.22 * math.sin(3 * a + ph) + 0.1 * rng.uniform(-1, 1))
                rim.append(Vector((x + math.cos(a) * rr, y + math.sin(a) * rr, 0.02)))
                low.append(Vector((x + math.cos(a) * rr * 1.02, y + math.sin(a) * rr * 1.02, -0.04)))
            ci = G.v(ctr)
            ri = [G.v(p) for p in rim]
            li = [G.v(p) for p in low]
            below = Vector((x, y, -2.0))
            for k in range(m):
                k2 = (k + 1) % m
                G.face([ci, ri[k], ri[k2]], [(ctr.x, ctr.y), (rim[k].x, rim[k].y), (rim[k2].x, rim[k2].y)],
                       [mid_c, shade(mix(mid_c, rim_c, 0.5), 1.0), shade(mix(mid_c, rim_c, 0.5), 1.0)], below)
                G.face([ri[k], li[k], li[k2], ri[k2]], [(rim[k].x, 0.06), (low[k].x, 0), (low[k2].x, 0), (rim[k2].x, 0.06)],
                       [rim_c] * 4, Vector((x, y, 0.0)), smooth=False)
        return {"leaf": G}, {"keys": {"leaf": ["lichen_orange", "lichen_orange_dark", "lichen", "lichen_grey"]}}

    # ------------------------------------------------------------------ 13. the cedar bough
    def spray(G, origin, az, length, e0, e1, half, prof=((0.24, 1.0), (0.6, 0.76), (1.0, 0.18)), tone=1.0, thick=0.22, bend=0.6):
        """One flat spray of cedar foliage: a tongue that leaves `origin` (a point) e0 degrees above
        level, turns over early (bend < 1) and hangs at e1 at its end, `half` studs to each side at
        its widest. A shallow ridge along the top, flat and a touch lighter underneath. prof =
        (share of the length, share of the width) for each ring; 16 triangles with three rings."""
        d = Vector((math.cos(az), math.sin(az), 0))
        side = Vector((-d.y, d.x, 0))
        deep, base, sun = PAL["cedar_leaf_deep"], PAL["cedar_leaf"], PAL["cedar_leaf_sun"]
        p, s0 = Vector(origin), 0.0
        rings = []
        for s1, wf in prof:
            for q in range(6):   # walk the curve in small steps so the hang is a true arc
                e = math.radians(e0 + (e1 - e0) * (s0 + (s1 - s0) * (q + 0.5) / 6) ** bend)
                p = p + (d * math.cos(e) + UP * math.sin(e)) * (s1 - s0) * length / 6
            e = math.radians(e0 + (e1 - e0) * s1 ** bend)
            nrm = -d * math.sin(e) + UP * math.cos(e)
            w = half * wf
            rings.append((p - side * w, p + nrm * (thick * w + 0.04), p + side * w, w, s1 * length, s1))
            s0 = s1

        def cols(sm):
            top = mix(deep, base, 0.35 + 1.6 * sm) if sm < 0.4 else mix(base, sun, (sm - 0.4) * 0.8)
            under = mix(base, sun, 0.75 + 0.25 * sm)
            return shade(top, tone), shade(top, tone * 0.93), shade(under, tone)

        o = Vector(origin)
        L, S, R, w, v, s1 = rings[0]
        a, b, u = cols(s1 * 0.5)
        inside = (o + L + S + R) / 4
        G.flat([o, S, L], a, inside, uvs=[(0, 0), (0, v), (-w, v)])
        G.flat([o, R, S], b, inside, uvs=[(0, 0), (w, v), (0, v)])
        G.flat([o, L, R], u, inside, uvs=[(0, 0), (-w, v), (w, v)])
        for (L0, S0, R0, w0, v0, t0), (L1, S1, R1, w1, v1, t1) in zip(rings, rings[1:]):
            a, b, u = cols((t0 + t1) / 2)
            inside = (L0 + S0 + R0 + L1 + S1 + R1) / 6
            G.flat([L0, S0, S1, L1], a, inside, uvs=[(-w0, v0), (0, v0), (0, v1), (-w1, v1)])
            G.flat([S0, R0, R1, S1], b, inside, uvs=[(0, v0), (w0, v0), (w1, v1), (0, v1)])
            G.flat([L0, L1, R1, R0], u, inside, uvs=[(-w0, v0), (-w1, v1), (w1, v1), (w0, v0)])
        L, S, R, w, v, s1 = rings[-1]
        if w > 1e-3:
            G.flat([L, S, R], cols(1.0)[0], inside, uvs=[(-w, v), (0, v + 0.1), (w, v)])

    def cedar_bough():
        """A western red cedar bough, 12 studs: a thick limb that leaves the trunk, lifts a little,
        then arcs over and droops; flat sprays hang from its outer half in layers, like a fringe,
        and one hangs from the tip. Built along +X from the branch base at the origin, which is
        the pivot (not the bottom centre): it goes on the trunk's centre line."""
        rng = random.Random(941)
        bark, leaf = Geo(), Geo()
        n = 6
        path = spline([(-0.3, 0.0, -0.03), (1.3, 0.0, 0.45), (3.7, 0.12, 0.9), (6.3, 0.2, 0.75), (8.6, 0.1, 0.05), (10.4, -0.05, -1.1)], n)
        radii = [0.36, 0.32, 0.26, 0.2, 0.13, 0.045]
        fl = {}

        def col(i, k, mid, out):
            f = fl.setdefault((i, k), rng.random())
            c = mix(PAL["cedar_bark_dark"], PAL["cedar_bark"], 0.65 + 0.5 * out.z)
            if out.z > 0.2 and f < 0.4:
                c = mix(c, PAL["cedar_bark_grey"], 0.55)
            return shade(c, 0.94 + 0.12 * f)

        tube(bark, path, radii, 4, col, spin=math.pi / 4)
        arc = [0.0]
        for a, b in zip(path, path[1:]):
            arc.append(arc[-1] + (b - a).length)

        def on_limb(t):
            """The point, the heading and the slope (degrees) of the limb at share t of its length."""
            want = t * arc[-1]
            for i in range(n - 1):
                if want <= arc[i + 1] or i == n - 2:
                    f = clamp((want - arc[i]) / (arc[i + 1] - arc[i]))
                    tan = (path[i + 1] - path[i]).normalized()
                    return path[i].lerp(path[i + 1], f), math.atan2(tan.y, tan.x), math.degrees(math.asin(tan.z))
        # the fringe: sprays to either side of the outer half that turn over and hang, long and
        # short by turns so their ends make layers
        #        share  side  turn  length  half  e0   e1
        sides = [(0.38, +1, 74, 2.6, 0.80, 12, -84), (0.45, -1, 70, 3.3, 0.88, 10, -86),
                 (0.54, +1, 66, 3.9, 0.98, 8, -86), (0.62, -1, 62, 3.0, 0.92, 6, -86),
                 (0.71, +1, 58, 4.2, 1.02, 2, -87), (0.79, -1, 54, 3.4, 0.98, 0, -87),
                 (0.88, +1, 44, 3.9, 0.98, -6, -88), (0.95, -1, 40, 3.2, 0.92, -10, -88)]
        for t, sd, turn, length, half, e0, e1 in sides:
            p, head, _slope = on_limb(t)
            spray(leaf, p, head + sd * math.radians(turn + rng.uniform(-4, 4)), length, e0, e1, half, tone=rng.uniform(0.96, 1.04))
        # the tip spray, and three shingles along the top of the limb
        p, head, slope = on_limb(1.0)
        spray(leaf, p - UP * 0.02, head, 3.6, slope + 6, -88, 1.0, tone=1.03)
        for t, turn, length, half in ((0.5, 8, 2.7, 0.72), (0.66, -10, 2.8, 0.78), (0.82, 6, 2.6, 0.75)):
            p, head, slope = on_limb(t)
            spray(leaf, p + UP * 0.1, head + math.radians(turn), length, slope + 16, slope - 55, half, tone=rng.uniform(0.98, 1.05), bend=0.9)
        # two small ones nearer the trunk, so the foliage thins out instead of stopping
        for t, sd, turn in ((0.27, +1, 48), (0.33, -1, 52)):
            p, head, slope = on_limb(t)
            spray(leaf, p, head + sd * math.radians(turn), 2.1, 14, -70, 0.6, prof=((0.45, 1.0), (1.0, 0.3)), tone=0.97)
        return {"bark": bark, "leaf": leaf}, {
            "keys": {"bark": ["cedar_bark", "cedar_bark_grey", "cedar_bark_dark"], "leaf": ["cedar_leaf", "cedar_leaf_sun", "cedar_leaf_deep"]},
            "pivot": "base"}

    BUILDERS = {
        "Cedar": cedar, "MossyLog": mossy_log, "CreekRoots": creek_roots,
        "CreekFern1": lambda: creek_fern(1), "CreekFern2": lambda: creek_fern(2), "MossMat": moss_mat,
        "CedarBough": cedar_bough,
        "LonePine": lone_pine, "Juniper1": lambda: juniper(1), "Juniper2": lambda: juniper(2),
        "HeathTufts": heath_tufts, "LichenTufts": lichen_tufts, "LichenCrust": lichen_crust,
    }

    # ------------------------------------------------------------------ meshes and export
    def to_object(G, name):
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
                col.data[li].color = tuple(srgb_to_linear(min(255.0, max(0.0, x * LIFT))) for x in c) + (1.0,)
                li += 1
        assert li == len(me.loops), f"{name}: {li} corners written, {len(me.loops)} in the mesh"
        me.color_attributes.active_color = col
        me.color_attributes.render_color_index = me.color_attributes.find("Col")
        obj = bpy.data.objects.new(name, me)
        scene_of().collection.objects.link(obj)
        return obj

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
        return {"colours_converted": n,
                "glb": str(path.relative_to(REPO)).replace("\\", "/"),
                "roblox_glb": str((ROBLOX / path.name).relative_to(REPO)).replace("\\", "/")}

    kit = {}

    def build_kit(only=None, stage_only=()):
        """Build, and export, the kit (or just `only`). `stage_only` models are built for the
        preview stage and neither exported nor recorded."""
        result = {}
        for name, fn in BUILDERS.items():
            if only and name not in only and name not in stage_only:
                continue
            geos, info = fn()
            los, his = zip(*(g.bounds() for g in geos.values()))
            lo = Vector(tuple(min(v[i] for v in los) for i in range(3)))
            hi = Vector(tuple(max(v[i] for v in his) for i in range(3)))
            two = len(geos) > 1 or bool(info.get("foot_centred"))
            base = info.get("pivot") == "base"
            if base:   # the pivot is the builder's origin (a bough's branch base); one box for both meshes,
                hy = max(abs(lo.y), abs(hi.y))   # the same to either side, so the pivot is on its middle plane
                blo, bhi = Vector((lo.x, -hy, lo.z)), Vector((hi.x, hy, hi.z))
                for fam, g in geos.items():
                    anchors(g, blo, bhi, PAL[info["keys"][fam][0]])
            elif two:   # the box is centred on the trunk's foot (or the log's middle)
                hx, hy = max(abs(lo.x), abs(hi.x)), max(abs(lo.y), abs(hi.y))
                blo, bhi = Vector((-hx, -hy, lo.z)), Vector((hx, hy, hi.z))
                for fam, g in geos.items():
                    anchors(g, blo, bhi, PAL[info["keys"][fam][0]])
            else:
                blo, bhi = lo, hi
            pivot = Vector((0, 0, 0)) if base else Vector(((blo.x + bhi.x) / 2, (blo.y + bhi.y) / 2, blo.z))
            entry = {"kind": KIT[name]["kind"], "area": KIT[name]["area"], "bury": 0.0 if base else round(-blo.z, 2), "height": round(hi.z, 2),
                     "true_studs": [round(hi.x - lo.x, 2), round(hi.z - lo.z, 2), round(hi.y - lo.y, 2)],
                     "studs": [round(bhi.x - blo.x, 2), round(bhi.z - blo.z, 2), round(bhi.y - blo.y, 2)],
                     "foot_centred": two, "anchors": two,
                     "palette": {k: list(PAL[k]) for keys in info["keys"].values() for k in keys},
                     "keys": info["keys"], "source": info.get("source", "hand-built in this script"), "meshes": {}}
            if base:   # the box about the pivot, in the file's axes (X, up, -Y) and as plain numbers
                entry["pivot"] = "base"
                entry["anchors"] = True
                entry["box"] = {"min": [round(blo.x, 3), round(blo.z, 3), round(-bhi.y, 3)], "max": [round(bhi.x, 3), round(bhi.z, 3), round(-blo.y, 3)]}
                entry["reach"] = round(hi.x, 2)
                entry["hang"] = round(-lo.z, 2)
            objs = {}
            for fam, g in geos.items():
                g.verts = [(x - pivot.x, y - pivot.y, z - pivot.z) for x, y, z in g.verts]
                obj = to_object(g, f"{name}_{fam}")
                objs[fam] = obj
                if name in stage_only and not (only and name in only):
                    continue
                entry["meshes"][fam] = {"triangles": g.triangles(), **export(obj)}
                print(f"[plant_kit] {obj.name}: {g.triangles()} triangles")
            kit[name] = {"objs": objs, "lo": lo - pivot, "hi": hi - pivot, "bury": 0.0 if base else -blo.z, "pivot": pivot}
            if entry["meshes"]:
                result[name] = entry
        return result

    # ------------------------------------------------------------------ preview
    def setup_cycles(w, h, exposure=-0.45, sky=(0.80, 0.88, 1.0), sky_strength=0.8, sun_rot=(50, 10, 35),
                     sun_energy=3.6, sun_color=(1.0, 0.96, 0.88)):
        scene = scene_of()
        for o in [o for o in scene.objects if o.get("_stage")]:
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
        if scene.world is None:
            world = bpy.data.worlds.new("Sky")
            world.use_nodes = True
            scene.world = world
        bg = scene.world.node_tree.nodes["Background"]
        bg.inputs[0].default_value = tuple(sky) + (1.0,)
        bg.inputs[1].default_value = sky_strength
        sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
        sun.data.energy = sun_energy
        sun.data.color = sun_color
        sun.data.angle = math.radians(1.5)
        sun.rotation_euler = tuple(math.radians(v) for v in sun_rot)
        scene.collection.objects.link(sun)
        cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        scene.collection.objects.link(cam)
        scene.camera = cam
        sun["_stage"] = cam["_stage"] = True
        return cam, sun

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
        if fam in preview_cache:
            return preview_cache[fam]
        info = maps[fam]
        m = bpy.data.materials.new(f"Preview_{fam}")
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        folder, slug = Path(info["dir"]), info["slug"]
        if not (folder / f"{slug}_neutral.png").exists():
            mul = nt.nodes.new("ShaderNodeMix")
            mul.data_type = "RGBA"
            mul.blend_type = "MULTIPLY"
            mul.inputs[0].default_value = 1.0
            mul.inputs[7].default_value = (0.604, 0.604, 0.604, 1.0)
            nt.links.new(vc.outputs["Color"], mul.inputs[6])
            nt.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
            bsdf.inputs["Roughness"].default_value = 0.85
        else:
            uv = nt.nodes.new("ShaderNodeUVMap")
            uv.uv_map = "UVMap"
            mapping = nt.nodes.new("ShaderNodeMapping")
            s = 1.0 / info["tile"]
            mapping.inputs["Scale"].default_value = (s, s, 1)
            nt.links.new(uv.outputs[0], mapping.inputs[0])

            def tex(kind, non_color):
                node = nt.nodes.new("ShaderNodeTexImage")
                node.image = bpy.data.images.load(str(folder / f"{slug}_{kind}.png"), check_existing=True)
                if non_color:
                    node.image.colorspace_settings.name = "Non-Color"
                nt.links.new(mapping.outputs[0], node.inputs[0])
                return node

            mul = nt.nodes.new("ShaderNodeMix")
            mul.data_type = "RGBA"
            mul.blend_type = "MULTIPLY"
            mul.inputs[0].default_value = 1.0
            nt.links.new(tex("neutral", False).outputs[0], mul.inputs[6])
            nt.links.new(vc.outputs["Color"], mul.inputs[7])
            nt.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
            nt.links.new(tex("rough", True).outputs[0], bsdf.inputs["Roughness"])
            nmap = nt.nodes.new("ShaderNodeNormalMap")
            nmap.uv_map = "UVMap"
            nt.links.new(tex("normal", True).outputs[0], nmap.inputs["Color"])
            nt.links.new(nmap.outputs[0], bsdf.inputs["Normal"])
        preview_cache[fam] = m
        return m

    def face_check_material(fam):
        if "check" in preview_cache:
            return preview_cache["check"]
        m = bpy.data.materials.new("FaceCheck")
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (0.5, 0.5, 0.5, 1.0)
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        back = nt.nodes.new("ShaderNodeEmission")
        back.inputs["Color"].default_value = (1.0, 0.0, 0.8, 1.0)
        back.inputs["Strength"].default_value = 2.0
        pick = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(geo.outputs["Backfacing"], pick.inputs[0])
        nt.links.new(bsdf.outputs[0], pick.inputs[1])
        nt.links.new(back.outputs[0], pick.inputs[2])
        nt.links.new(pick.outputs[0], nt.nodes["Material Output"].inputs["Surface"])
        preview_cache["check"] = m
        return m

    def dress_kit(material=None):
        for item in kit.values():
            for fam, obj in item["objs"].items():
                obj.data.materials.clear()
                obj.data.materials.append((material or preview_material)(fam))
                obj.hide_render = True

    def instance(name, loc=(0, 0, 0), yaw=0.0, scale=1.0):
        """A copy of a kit model with its ground line at loc.z."""
        item = kit[name]
        out = []
        for obj in item["objs"].values():
            o = obj.copy()
            o.hide_render = False
            o.location = (loc[0], loc[1], loc[2] - item["bury"] * scale)
            o.rotation_euler = (0, 0, yaw)
            o.scale = (scale, scale, scale)
            o["_stage"] = True
            scene_of().collection.objects.link(o)
            out.append(o)
        return out

    def figure(loc, yaw=0.0):
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
            o["_stage"] = True

    def rock(loc, radii, rgb, seed, floor=None, rot=0.0, name="Rock"):
        """A stand-in boulder for the previews only (the game's rocks are RockLarge and friends)."""
        G = Geo()
        blob(G, (0, 0, 0), radii, lambda p, n: rgb, 3, seed=seed, jit=0.14, freq=1.1, rot=Euler((0, 0, rot)), smooth=True,
             floor=floor, power=0.8, flat_top=0.75)
        me = bpy.data.meshes.new(name)
        me.from_pydata(G.verts, [], G.faces)
        me.polygons.foreach_set("use_smooth", G.smooth)
        o = bpy.data.objects.new(name, me)
        o.location = loc
        o.data.materials.append(flat(name + "M", rgb, 0.8))
        o["_stage"] = True
        scene_of().collection.objects.link(o)
        return o

    def lineup(names, path, w, h, gap, view=(-22, 9), ground_rgb=(150, 150, 146), ground=True, extras=None):
        cam, _sun = setup_cycles(w, h)
        x = 0.0
        spots, pts = [], []
        for name in names:
            item = kit[name]
            lo, hi = item["lo"], item["hi"]
            x -= lo.x
            gz = 0.0
            if extras and name in extras:
                gz = extras[name](x)
            instance(name, (x, 0, gz))
            spots.append((name, Vector((x + (lo.x + hi.x) / 2, 0, 0))))
            for cx in (lo.x, hi.x):
                for cy in (lo.y, hi.y):
                    for cz in (item["bury"], hi.z):
                        pts.append(Vector((x + cx, cy, cz - item["bury"] + gz)))
            x += hi.x + gap
        x += 1.5
        figure((x, 0, 0), yaw=0.35)
        spots.append(("6 stud figure", Vector((x, 0, 0))))
        pts += [Vector((x - 2, -1, 0)), Vector((x + 2, 1, 6.0))]
        if ground:
            bpy.ops.mesh.primitive_plane_add(size=1000, location=(x / 2, 0, 0))
            g = bpy.context.object
            g.data.materials.append(flat("Ground", ground_rgb))
            g["_stage"] = True
        yaw, pitch = (math.radians(v) for v in view)
        d = Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
        quat = (-d).to_track_quat("-Z", "Y")
        right, up = quat @ Vector((1, 0, 0)), quat @ Vector((0, 1, 0))
        us, vs = [p.dot(right) for p in pts], [p.dot(up) for p in pts]
        cu, cv = (min(us) + max(us)) / 2, (min(vs) + max(vs)) / 2
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = max(max(us) - min(us), (max(vs) - min(vs)) * w / h) * 1.06
        cam.location = right * cu + up * cv + d * 400
        cam.rotation_euler = quat.to_euler()
        cam.data.clip_end = 2000
        bpy.context.view_layer.update()
        labels = []
        for name, p in spots:
            co = world_to_camera_view(scene_of(), cam, p)
            labels.append({"name": name, "x": round(co.x, 4), "y": round(1 - co.y, 4)})
        scene_of().render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        return labels

    def terrain(fn, x0, x1, y0, y1, step, rgb, name="Ground", rough=0.95):
        nx, ny = int((x1 - x0) / step) + 1, int((y1 - y0) / step) + 1
        verts = [(x0 + i * step, y0 + j * step, fn(x0 + i * step, y0 + j * step)) for j in range(ny) for i in range(nx)]
        faces = [(j * nx + i, j * nx + i + 1, (j + 1) * nx + i + 1, (j + 1) * nx + i) for j in range(ny - 1) for i in range(nx - 1)]
        me = bpy.data.meshes.new(name)
        me.from_pydata(verts, [], faces)
        me.polygons.foreach_set("use_smooth", [True] * len(faces))
        o = bpy.data.objects.new(name, me)
        o.data.materials.append(rgb if isinstance(rgb, bpy.types.Material) else flat(name + "M", rgb, rough))
        o["_stage"] = True
        scene_of().collection.objects.link(o)
        return o

    def water(z, rgb, size=600, center=(0, 0), name="Water"):
        bpy.ops.mesh.primitive_plane_add(size=size, location=(center[0], center[1], z))
        o = bpy.context.object
        o.name = name
        m = bpy.data.materials.new(name + "M")
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = tuple(srgb_to_linear(c) for c in rgb) + (1.0,)
        b.inputs["Roughness"].default_value = 0.06
        b.inputs["Transmission Weight"].default_value = 0.85
        b.inputs["IOR"].default_value = 1.33
        o.data.materials.append(m)
        o["_stage"] = True
        return o

    def shoot(path, eye, look, fov=70.0, w=1600, h=900):
        """A Roblox camera: 70 degree field of view, measured up and down."""
        cam = scene_of().camera
        scene_of().render.resolution_x, scene_of().render.resolution_y = w, h
        cam.data.type = "PERSP"
        cam.data.sensor_fit = "VERTICAL"
        cam.data.angle_y = math.radians(fov)
        cam.location = eye
        cam.rotation_euler = (Vector(look) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
        cam.data.clip_end = 3000
        scene_of().render.filepath = str(path)
        bpy.ops.render.render(write_still=True)

    # ---- the creek: a pool under a cut bank, dressed with the kit
    def smooth(t):
        t = clamp(t)
        return t * t * (3 - 2 * t)

    def creek_h(x, y):
        """The stream runs along Y, 9 studs wide; a gentle bank at -X, a 2.6 stud cut bank at +X."""
        wob = 0.8 * math.sin(y * 0.11) + 0.4 * math.sin(y * 0.27 + 1.0)
        xx = x - wob
        if xx < -4.5:
            return -0.9 + 2.4 * smooth((-4.5 - xx) / 4.0) + 0.3 * math.sin(y * 0.2 + x * 0.3)
        if xx > 4.0:
            return -0.9 + 3.5 * smooth((xx - 4.0) / 0.7) + 0.2 * math.sin(y * 0.15)
        return -0.9 - 0.4 * (1 - abs(xx) / 4.5)

    def dress_creek():
        floor = flat("ForestFloor", (92, 72, 48))
        terrain(creek_h, -40, 40, -30, 70, 1.0, floor, "Creek")
        water(-0.15, (64, 84, 58), 200, name="CreekWater")
        slate = (88, 94, 100)
        # boulders in the stream and on the bank, two of them mossed
        for (x, y, rx, ry, rz, seed, moss) in ((-1.5, 9.0, 4.5, 3.3, 2.9, 3, 1.0), (2.2, 16.0, 2.6, 2.1, 1.6, 7, 0.6),
                                                (-5.6, 4.0, 2.4, 1.9, 1.5, 11, None), (1.0, 26.0, 3.2, 2.5, 2.1, 5, None)):
            gz = creek_h(x, y)
            rock((x, y, gz), (rx, ry, rz), slate, seed, floor=-rz * 0.45, rot=seed * 0.4)
            if moss:
                instance("MossMat", (x, y, gz + rz * 0.86 - 1.12 * moss), yaw=seed * 0.4, scale=moss)
        instance("MossyLog", (0.6, 20.5, 1.6), yaw=math.radians(-6))
        # roots on the cut bank, facing the water (-X), and a fern spilling over its lip
        for y in (5.0, 12.5, 30.0):
            xs = 4.0 + 0.8 * math.sin(y * 0.11) + 0.4 * math.sin(y * 0.27 + 1.0) + 0.45
            instance("CreekRoots", (xs - 0.6, y, creek_h(xs + 1.5, y)), yaw=math.pi)
        for y in (8.5, 23.0):
            xs = 4.0 + 0.8 * math.sin(y * 0.11) + 0.4 * math.sin(y * 0.27 + 1.0) + 0.8
            instance("CreekFern2", (xs, y, creek_h(xs + 0.5, y)), yaw=math.pi)
        for (x, y, s) in ((-7.5, 2.0, 1.0), (-8.5, 6.5, 1.2), (-6.8, 12.0, 0.9), (-9.5, 15.5, 1.1), (7.6, 2.5, 1.0), (8.0, 15.0, 1.2),
                          (7.4, 27.0, 0.9), (-7.8, 24.0, 1.0)):
            instance("CreekFern1", (x, y, creek_h(x, y)), yaw=x * y, scale=s)
        for (x, y, s, yaw) in ((-11.0, 4.0, 1.05, 0.3), (-10.0, 19.0, 0.95, 2.0), (-12.5, 31.0, 1.1, 4.0), (9.5, 8.0, 1.0, 3.0),
                               (11.0, 21.0, 1.1, 1.0), (10.0, 35.0, 0.9, 5.0), (-14.0, 44.0, 1.0, 2.5), (13.0, 46.0, 1.05, 0.5),
                               (-6.0, 52.0, 1.0, 1.5), (6.5, 58.0, 1.1, 3.5)):
            instance("Cedar", (x, y, creek_h(x, y)), yaw=yaw + math.pi, scale=s)

    # ---- the island: granite knolls, the lone pine on the top
    def granite_h(x, y):
        k = [(0, 0, 8.0, 26, 18), (-18, 10, 4.5, 16, 12), (16, -8, 3.5, 14, 11), (-6, -16, 2.6, 14, 9)]
        h = -3.0
        for cx, cy, top, rx, ry in k:
            d = (((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2)
            h = max(h, top * (1 - d) ** 0.7 if d < 1 else -3.0)
        return h + 0.25 * noise.noise(Vector((x * 0.12, y * 0.12, 2.0)))

    def dress_island():
        granite = flat("Granite", (176, 142, 132), 0.75)
        terrain(granite_h, -60, 60, -50, 50, 1.0, granite, "Island")
        water(0.0, (22, 60, 84), 3000, name="Sea")
        instance("LonePine", (2.0, 1.0, granite_h(2.0, 1.0)), yaw=0.0)
        for (x, y, yaw, s) in ((-10.0, 6.0, 0.2, 1.0), (7.0, -6.5, 1.4, 0.9), (-16.0, 12.0, 2.0, 1.2), (12.0, 5.0, 3.3, 0.8)):
            instance("Juniper1", (x, y, granite_h(x, y)), yaw=yaw, scale=s)
        for (x, y, s) in ((-4.0, -6.0, 1.0), (14.0, -10.0, 1.1), (-20.0, 4.0, 0.9)):
            instance("Juniper2", (x, y, granite_h(x, y)), yaw=0.0, scale=s)
        for (x, y) in ((-7.0, -2.0), (5.0, 7.0), (-12.0, -9.0), (9.0, -2.0), (-2.0, 10.0), (18.0, -5.0), (-15.0, 16.0)):
            instance("HeathTufts", (x, y, granite_h(x, y)), yaw=x + y)
        for (x, y) in ((-5.0, 4.0), (3.0, -9.0), (-13.0, 1.0), (11.0, 9.0)):
            instance("LichenTufts", (x, y, granite_h(x, y)), yaw=x * 0.7)
        for (x, y) in ((-1.0, -3.0), (6.0, 2.0), (-8.0, 9.0), (2.0, 6.0), (-3.0, -11.0)):
            instance("LichenCrust", (x, y, granite_h(x, y) + 0.02), yaw=x - y)

    # ---- the cedar bough: side on, from the water under it, and two on a cedar over the stream
    def bough_shots(tag="bough"):
        def stand_in(height=8.0, person=True):
            """A bare trunk with the bough on it at `height`, a figure under it, level ground."""
            bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.55, depth=16.0, location=(0, 0, 7.0))
            o = bpy.context.object
            o.data.materials.append(flat("StandInTrunk", PAL["cedar_bark"], 0.9))
            o["_stage"] = True
            bpy.ops.mesh.primitive_plane_add(size=1000, location=(0, 0, 0))
            g = bpy.context.object
            g.data.materials.append(flat("BoughGround", (150, 150, 146)))
            g["_stage"] = True
            instance("CedarBough", (0, 0, height))
            if person:
                figure((8.2, 0.6, 0), yaw=0.5)

        setup_cycles(1600, 900)
        stand_in()
        shoot(SCRATCH / f"{tag}-side.png", (5.6, -44.0, 6.2), (5.6, 0.0, 5.4), fov=17.0)
        shoot(SCRATCH / f"{tag}-front.png", (44.0, -10.0, 9.0), (5.0, 0.0, 5.6), fov=17.0)
        shoot(SCRATCH / f"{tag}-top.png", (6.0, -8.0, 44.0), (6.0, 0.0, 6.0), fov=17.0)
        # from under it: the game's camera, a little above the water, looking up and back at the trunk
        setup_cycles(1600, 900, sky=(0.72, 0.8, 0.86), sky_strength=1.0, sun_rot=(38, 8, 150))
        stand_in(person=False)
        shoot(SCRATCH / f"{tag}-below.png", (11.5, -4.2, 1.6), (5.6, 0.3, 7.4))
        # on a cedar on the creek's bank, two of them out over the water
        setup_cycles(1600, 900, sky=(0.72, 0.8, 0.86), sky_strength=0.9, sun_rot=(38, 8, 150))
        terrain(creek_h, -40, 40, -30, 70, 1.0, flat("ForestFloor", (92, 72, 48)), "Creek")
        water(-0.15, (64, 84, 58), 200, name="CreekWater")
        tx, ty = -7.6, 12.0
        gz = creek_h(tx, ty)
        instance("Cedar", (tx, ty, gz))
        for height, yaw in ((6.4, -0.12), (9.3, 0.5)):
            instance("CedarBough", (tx, ty, gz + height), yaw=yaw)
        instance("Cedar", (-11.5, 27.0, creek_h(-11.5, 27.0)), yaw=2.0, scale=1.05)
        instance("Cedar", (10.0, 30.0, creek_h(10.0, 30.0)), yaw=3.4, scale=0.95)
        figure((-5.2, 5.5, creek_h(-5.2, 5.5)), yaw=1.2)
        shoot(SCRATCH / f"{tag}-cedar.png", (3.4, -7.5, 3.4), (-3.2, 12.0, 6.6))

    # ------------------------------------------------------------------ run
    for d in (MODELS, ROBLOX, PREVIEWS, SCRATCH):
        d.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene_of().unit_settings.system = "NONE"
    only = set(args.only or ())
    stage_only = {"Cedar"} if "CedarBough" in only else set()   # the bough is shown on a cedar
    result_path = SCRATCH / ("result-only.json" if only else "result.json")
    result = {"lift": LIFT, "uv_studs": 1.0, "maps": maps, "models": build_kit(only, stage_only), "lineups": {}}
    result_path.write_text(json.dumps(result, indent=1), encoding="utf-8")
    if args.no_render:
        return
    if only:   # one model: no line-ups, no sheet
        if "CedarBough" in only:
            dress_kit(face_check_material if args.check_faces else None)
            bough_shots("faces-bough" if args.check_faces else "bough")
        return

    def on_rock(x):   # the MossMat in the line-up sits on a stand-in RockLarge
        rock((x, 0, 0), (4.4, 3.2, 2.85), (110, 112, 112), 3, floor=-0.1)
        return 2.85 * 0.98 - 1.12

    def on_bank(name, top):
        """The roots and the lip fern hang below their ground line: show them on a stand-in bank
        whose face is the model's x = 0 plane (the bank is on the model's -X side)."""
        def fn(x):
            face = x - kit[name]["pivot"].x
            bpy.ops.mesh.primitive_cube_add(size=1, location=(face - 1.0, 0, top / 2))
            o = bpy.context.object
            o.scale = (2.0, 7.0, top)
            o.data.materials.append(flat("Bank", (92, 72, 48)))
            o["_stage"] = True
            return top
        return fn

    rows = {
        "creek": (["Cedar", "MossyLog", "CreekRoots", "CreekFern1", "CreekFern2", "MossMat"], 2400, 720, 3.5,
                  {"MossMat": on_rock, "CreekRoots": on_bank("CreekRoots", 4.0), "CreekFern2": on_bank("CreekFern2", 2.6)}),
        "island": (["LonePine", "Juniper2", "Juniper1", "HeathTufts", "LichenTufts", "LichenCrust"], 2400, 980, 2.0, None),
    }
    if args.check_faces:
        dress_kit(face_check_material)
        for key, (names, w, h, gap, extras) in rows.items():
            lineup(names, SCRATCH / f"faces-{key}-front.png", w // 2, h // 2, gap, extras=extras)
            lineup(names, SCRATCH / f"faces-{key}-back.png", w // 2, h // 2, gap, view=(150, 40), extras=extras)
            lineup(names, SCRATCH / f"faces-{key}-under.png", w // 2, h // 2, gap, view=(-40, -30), ground=False, extras=extras)
        return
    dress_kit()
    for key, (names, w, h, gap, extras) in rows.items():
        result["lineups"][key] = {"labels": lineup(names, PREVIEWS / f"plant_kit-lineup-{key}.png", w, h, gap, extras=extras), "w": w, "h": h}
    (SCRATCH / "result.json").write_text(json.dumps(result, indent=1), encoding="utf-8")

    # the creek, in the game's camera, looking up the pool, and close on the cut bank
    setup_cycles(1600, 900, sky=(0.72, 0.8, 0.86), sky_strength=0.9, sun_rot=(38, 8, 150))
    dress_creek()
    shoot(PREVIEWS / "plant_kit-creek.png", (-2.5, -8.0, creek_h(-2.5, -8.0) + 5.5), (0.5, 22.0, 3.0))
    shoot(SCRATCH / "creek-bank.png", (0.5, -3.0, 1.3), (5.2, 6.5, 0.3), w=1280, h=720)
    # the island from a boat 70 studs out at noon, and the landmark from 500 studs against a golden sky
    setup_cycles(1600, 900, sky=(0.74, 0.84, 0.96), sky_strength=1.0, sun_rot=(42, 0, 210))
    dress_island()
    shoot(PREVIEWS / "plant_kit-island.png", (-6.0, -72.0, 5.5), (2.0, 0.0, 12.0))
    shoot(SCRATCH / "island-close.png", (-14.0, -20.0, granite_h(-14.0, -20.0) + 6.0), (-4.0, -2.0, 4.0), w=1280, h=720)
    setup_cycles(1600, 900, exposure=-0.2, sky=(1.0, 0.70, 0.36), sky_strength=1.4, sun_rot=(84, 0, 150), sun_energy=2.0,
                 sun_color=(1.0, 0.72, 0.42))
    dress_island()
    shoot(SCRATCH / "pine-500.png", (-30.0, -500.0, 5.5), (2.0, 0.0, 16.0))
    shoot(SCRATCH / "pine-500-tele.png", (-30.0, -500.0, 5.5), (2.0, 0.0, 16.0), fov=12.0)
    bough_shots()


# =======================================================================================
# Driver half (plain Python, numpy and Pillow)
# =======================================================================================

def make_standins(maps):
    import numpy as np
    from PIL import Image

    for fam, info in maps.items():
        if not info["standin"]:
            continue
        folder, slug = Path(info["dir"]), info["slug"]
        folder.mkdir(parents=True, exist_ok=True)
        n = 256
        rs = np.random.RandomState(sum(map(ord, slug)))
        yy, xx = np.mgrid[0:n, 0:n] / n
        h = np.zeros((n, n))
        if fam == "bark":
            for _ in range(48):
                fx, fy = rs.randint(3, 20), rs.randint(0, 3)
                h += np.cos(2 * np.pi * (fx * xx + fy * yy) + rs.uniform(0, 6.28)) / fx ** 0.6
            h = np.sign(h) * np.abs(h) ** 0.8
        else:
            for _ in range(90):
                fx, fy = rs.randint(-12, 13), rs.randint(-12, 13)
                if fx == 0 and fy == 0:
                    continue
                h += np.cos(2 * np.pi * (fx * xx + fy * yy) + rs.uniform(0, 6.28)) / (1 + np.hypot(fx, fy)) ** 0.9
        h = (h - h.mean()) / h.std()
        neutral = np.clip(0.80 + 0.055 * h, 0, 1)
        k = 1.6 if fam == "bark" else 1.1
        gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * k * n / 256
        gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * k * n / 256
        nz = 1 / np.sqrt(gx * gx + gy * gy + 1)
        normal = np.stack([-gx * nz * 0.5 + 0.5, gy * nz * 0.5 + 0.5, nz * 0.5 + 0.5], -1)
        rough = np.clip((0.86 if fam == "bark" else 0.62) - 0.05 * h, 0, 1)
        Image.fromarray((neutral * 255).astype("uint8"), "L").convert("RGB").save(folder / f"{slug}_neutral.png")
        Image.fromarray((normal * 255).astype("uint8"), "RGB").save(folder / f"{slug}_normal.png")
        Image.fromarray((rough * 255).astype("uint8"), "L").convert("RGB").save(folder / f"{slug}_rough.png")


def read_glb(path: Path):
    data = path.read_bytes()
    json_len = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20:20 + json_len])


def check_glb(path: Path, want_studs, box=None):
    """One mesh, one material, the four attributes, no texture, the right size and the right
    pivot: the bottom centre, or (box given) the origin where the builder put it."""
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
    if any(abs(a - b) > 0.011 for a, b in zip(size, want_studs)):
        raise SystemExit(f"{path.name}: size {size}, expected {want_studs}")
    if box:
        if any(abs(a - b) > 0.002 for k in ("min", "max") for a, b in zip(pos[k], box[k])):
            raise SystemExit(f"{path.name}: the box is {pos['min']} to {pos['max']}, expected {box['min']} to {box['max']}")
    elif abs(pos["min"][1]) > 0.002 or abs(pos["min"][0] + pos["max"][0]) > 0.002 or abs(pos["min"][2] + pos["max"][2]) > 0.002:
        raise SystemExit(f"{path.name}: pivot is not the bottom centre ({pos['min']} to {pos['max']})")
    return size, tris


BUDGET = {"Cedar": 1300, "LonePine": 1300, "MossyLog": 1200, "CedarBough": 270}   # everything else: 800


def driver_main():
    import subprocess

    try:
        from PIL import Image, ImageDraw, ImageFont
    except ModuleNotFoundError:
        import site

        sys.path.append(site.getusersitepackages())
        from PIL import Image, ImageDraw, ImageFont

    args = parse_args(sys.argv[1:])
    maps = family_maps()
    if not args.compose_only:
        SCRATCH.mkdir(parents=True, exist_ok=True)
        if not (args.no_render or args.check_faces):
            make_standins(maps)
        subprocess.run([BLENDER, "-b", "--factory-startup", "-P", str(Path(__file__).resolve()), "--", *sys.argv[1:]], check=True)
    result = json.loads((SCRATCH / ("result-only.json" if args.only else "result.json")).read_text(encoding="utf-8"))
    maps = result["maps"]

    # Check what was written, then record it. Only this script's own entries are touched
    # (with --only, only those models' entries).
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    mine = set(args.only) if args.only else set(KIT)
    for key in [k for k in manifest if k.rsplit("_", 1)[0] in mine and k.rsplit("_", 1)[-1] in FAMILIES]:
        del manifest[key]
    total, over, table = 0, [], []
    for name, entry in result["models"].items():
        model_tris = sum(m["triangles"] for m in entry["meshes"].values())
        total += model_tris
        if model_tris > BUDGET.get(name, 800):
            over.append(f"{name}: {model_tris} triangles is over its {BUDGET.get(name, 800)} budget")
        for fam, mesh in entry["meshes"].items():
            for sub in ("glb", "roblox_glb"):
                size, tris = check_glb(REPO / mesh[sub], entry["studs"], entry.get("box"))
            if tris != mesh["triangles"]:
                raise SystemExit(f"{name}_{fam}: {tris} triangles in the file, {mesh['triangles']} in Blender")
            where = KIT[name]["where"]
            centre = (" Both meshes share one box, centred on the foot of the trunk (or the middle of the log), so both go at "
                      "the same CFrame." if entry["anchors"] else "")
            src = "" if entry["source"].startswith("hand-built") else f" Crown shape from {entry['source']}."
            pivot = (f"Pivot at the bottom centre; the ground line is {entry['bury']:g} studs above it, so place the pivot at ground "
                     f"height minus {entry['bury']:g}. It stands {entry['height']:.1f} studs above the ground line.{centre}")
            extra = {}
            if entry.get("pivot") == "base":
                lo_b, hi_b = entry["box"]["min"], entry["box"]["max"]
                # the middle of the box, from the pivot, in Roblox's axes (the file's X is Roblox -X; up is up)
                mid = [round(-(lo_b[0] + hi_b[0]) / 2, 2), round((lo_b[1] + hi_b[1]) / 2, 2), 0.0]
                pivot = (f"Pivot at the BRANCH BASE (the file's origin), not the bottom centre: the bough runs {entry['reach']:g} studs "
                         f"toward Roblox -X (Blender +X), lifts {entry['height']:g} and hangs {entry['hang']:g} studs below the pivot. "
                         f"Both meshes share one box, so both go at the same CFrame. Not yet checked in Studio: if the importer "
                         f"puts the pivot on the middle of the box and not on the file's origin, the branch base is at "
                         f"({-mid[0]:g}, {-mid[1]:g}, 0) from the middle of each MeshPart, in the part's own axes "
                         f"(model.WorldPivot = part.CFrame * CFrame.new({-mid[0]:g}, {-mid[1]:g}, 0)).")
                extra = {"pivot": "branch base (file origin)", "reach": entry["reach"], "hang": entry["hang"],
                         "pivot_from_box_middle": [-mid[0], -mid[1], 0.0]}
            manifest[f"{name}_{fam}"] = {
                "name": f"{name}_{fam}",
                "studs": size,
                "triangles": tris,
                "parts": 1,
                "replaces": KIT[name]["replaces"],
                "notes": (f"Plant kit ({'Cedar Creek' if entry['area'] == 'creek' else 'the first island'}), Layer B, {fam} family: "
                          f"MaterialVariant {WANTED[fam]} with its NEUTRAL colour map, normal and roughness. Vertex colours stored "
                          f"{result['lift']:g} times the colour wanted. UVs at 1 stud per UV unit. Upload art/models/roblox/{name}_{fam}.glb. "
                          f"{pivot} {where}{src}"),
                "model": name,
                "family": fam,
                "variant": WANTED[fam],
                "area": entry["area"],
                "uv_studs": 1.0,
                "lift": result["lift"],
                "bury": entry["bury"],
                "height_above_ground": entry["height"],
                "true_studs": entry["true_studs"],
                "model_triangles": model_tris,
                "source": entry["source"],
                "palette_seen_rgb": {k: entry["palette"][k] for k in entry["keys"][fam]},
                **extra,
            }
            print(f"{name}_{fam}: {size} studs, {tris} triangles")
        tri = " + ".join(f"{m['triangles']} {fam}" for fam, m in entry["meshes"].items())
        table.append(f"| {name} | {'Cedar Creek' if entry['area'] == 'creek' else 'Island'} | "
                     f"{' x '.join('%g' % v for v in entry['true_studs'])} | {tri} = {model_tris} | {entry['bury']:g} | {KIT[name]['where']} |")
    if over and not os.environ.get("PLANT_KIT_WIP"):
        raise SystemExit("\n".join(over))
    # --only leaves the other entries where they are (its own go last), so the diff is just its own
    MANIFEST.write_text(json.dumps(manifest if args.only else dict(sorted(manifest.items())), indent=2) + "\n", encoding="utf-8")
    (SCRATCH / ("table-only.md" if args.only else "table.md")).write_text("\n".join(table) + "\n", encoding="utf-8")
    print(f"plant kit: {len(result['models'])} models, {sum(len(e['meshes']) for e in result['models'].values())} meshes, {total} triangles")
    if args.no_render or args.check_faces:
        return

    def font(size, bold=False):
        for f in (("segoeuib.ttf",) if bold else ()) + ("segoeui.ttf", "arial.ttf"):
            try:
                return ImageFont.truetype(f, size)
            except OSError:
                continue
        return ImageFont.load_default()

    def small(im):
        return im.convert("RGB").quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)

    # ---- the cedar bough's own preview: side on and from under it, then on a cedar over the stream
    bough = result["models"].get("CedarBough")
    if bough:
        pad, head, pw, ph = 16, 34, 960, 540
        W, H = 2 * pw + 3 * pad, 64 + 2 * (head + ph + pad) + 30
        sheet = Image.new("RGB", (W, H), (24, 24, 27))
        draw = ImageDraw.Draw(sheet)
        tri = " + ".join(f"{m['triangles']} {fam}" for fam, m in bough["meshes"].items())
        draw.text((pad, 12), f"CedarBough: a drooping western red cedar spray for the bank cedars ({tri} = "
                  f"{sum(m['triangles'] for m in bough['meshes'].values())} triangles)", font=font(26, True), fill=(240, 240, 240))
        panels = (("Side on, 8 studs up a stand-in trunk (6 stud figure)", "bough-side.png"),
                  ("From the water under it, the game's 70 degree camera", "bough-below.png"),
                  ("Two on a Cedar, out over the creek", "bough-cedar.png"),
                  ("From above: the pivot is the branch base, on the trunk's centre line", "bough-top.png"))
        for i, (label, name) in enumerate(panels):
            x, y = pad + (i % 2) * (pw + pad), 58 + (i // 2) * (head + ph + pad)
            draw.text((x, y + 6), label, font=font(17), fill=(210, 210, 214))
            sheet.paste(Image.open(SCRATCH / name).convert("RGB").resize((pw, ph), Image.LANCZOS), (x, y + head))
        draw.text((pad, H - 32), f"Runs {bough['reach']:g} studs toward Blender +X (Roblox -X) and hangs {bough['hang']:g} below its base. "
                  "Trunk, ground and water are preview stand-ins.", font=font(16), fill=(170, 170, 175))
        small(sheet).save(PREVIEWS / "CedarBough.png", optimize=True)
        print(f"sheet: {PREVIEWS / 'CedarBough.png'}")
    if args.only:
        return

    # ---- the sheet

    pad, head = 16, 34
    W = 2400 + 2 * pad
    rows = [("creek", "Cedar Creek (N3): cedar, mossy log, roots for the cut banks, two ferns, a moss mat (on a stand-in RockLarge)"),
            ("island", "The first island (N6): the lone pine, two junipers, heath, lichen cushions, lichen crust")]
    shot_w = (W - 3 * pad) // 2
    shot_h = int(shot_w * 9 / 16)
    sw_h = 150
    H = 78 + sum(result["lineups"][k]["h"] + head + 44 + pad for k, _ in rows) + 3 * (head + shot_h + pad) + head + sw_h + 40
    sheet = Image.new("RGB", (W, H), (24, 24, 27))
    draw = ImageDraw.Draw(sheet)
    draw.text((pad, 12), "Plant kit for Cedar Creek and the first island, one mesh per material family (11/27/2026)", font=font(30, True), fill=(240, 240, 240))
    stand = [WANTED[f] for f in FAMILIES if maps[f]["standin"]]
    note = "Rendered as the game shows them: vertex colour times each family's neutral map (bark, leaf_needle), 1 UV unit = 1 stud. Terrain, rocks and water are preview stand-ins."
    if stand:
        note += f"  STAND-IN maps for {', '.join(stand)}."
    draw.text((pad, 50), note, font=font(16), fill=(170, 170, 175))
    y = 78
    for key, title in rows:
        info = result["lineups"][key]
        draw.text((pad, y + 6), title, font=font(18, True), fill=(220, 220, 224))
        y += head
        sheet.paste(Image.open(PREVIEWS / f"plant_kit-lineup-{key}.png").convert("RGB"), (pad, y))
        for lab in info["labels"]:
            name = lab["name"]
            x = pad + int(lab["x"] * info["w"])
            entry = result["models"].get(name)
            line2 = ""
            if entry:
                tri = " + ".join(f"{fam} {m['triangles']}" for fam, m in entry["meshes"].items())
                line2 = (f"{tri} tris, {entry['height']:.1f} tall" if entry["bury"] < 1.0 else
                         f"{tri} tris, hangs {entry['bury']:.1f} below its lip")
            for i, text in enumerate((name, line2)):
                if not text:
                    continue
                f = font(16, True) if i == 0 else font(14)
                tw = draw.textlength(text, font=f)
                draw.text((min(max(pad, x - tw / 2), W - pad - tw), y + info["h"] + 4 + i * 20), text, font=f,
                          fill=(232, 232, 236) if i == 0 else (165, 165, 172))
        y += info["h"] + 44 + pad

    # the 500 stud shot: the full frame, with a zoomed crop of the middle so the silhouette is legible
    full = Image.open(SCRATCH / "pine-500.png").convert("RGB")
    tele = Image.open(SCRATCH / "pine-500-tele.png").convert("RGB")
    for pair in (
        (("Cedar Creek in the game's camera (70 degrees, eye 5.5 studs up), looking up the pool", PREVIEWS / "plant_kit-creek.png"),
         ("Close on the cut bank: roots, a fern over the lip, the moss mat, the log", SCRATCH / "creek-bank.png")),
        (("The island from a boat 70 studs out", PREVIEWS / "plant_kit-island.png"),
         ("Among the granite: junipers, heath, lichen", SCRATCH / "island-close.png")),
        (("The landmark from 500 studs, golden sky, the game's 70 degree camera (full frame: about 40 px tall on a 900 px screen)", full),
         ("The same view through a 12 degree lens: the outline that must read", tele)),
    ):
        for i, (label, src) in enumerate(pair):
            x = pad + i * (shot_w + pad)
            draw.text((x, y + 6), label, font=font(17), fill=(210, 210, 214))
            im = src if isinstance(src, Image.Image) else Image.open(src).convert("RGB")
            sheet.paste(im.resize((shot_w, shot_h), Image.LANCZOS), (x, y + head))
        y += head + shot_h + pad
    draw.text((pad, y + 6), "Colours as seen in the game (the stored vertex colour is this times the lift)", font=font(17), fill=(210, 210, 214))
    y += head
    groups = [("Cedar", ("cedar_bark", "cedar_bark_grey", "cedar_leaf", "cedar_leaf_deep")), ("Moss", ("moss", "moss_sun", "moss_gold")),
              ("Fern", ("cfern", "cfern_tip")), ("Log, roots", ("log", "log_grey", "root", "root_pale")),
              ("Lone pine", ("lpine_bark", "lpine_dead", "lpine_needle", "lpine_needle_sun")), ("Juniper", ("juniper", "juniper_sun", "juniper_bronze")),
              ("Heath", ("heath", "heath_dry", "heath_green")), ("Lichen", ("lichen", "lichen_pale", "lichen_orange"))]
    sx = pad
    sw = (W - 2 * pad) // sum(len(k) for _, k in groups) - 4
    for title, keys in groups:
        draw.text((sx, y), title, font=font(15, True), fill=(230, 230, 232))
        for key in keys:
            rgb = PAL[key]
            draw.rectangle((sx, y + 24, sx + sw - 6, y + 74), fill=rgb)
            draw.text((sx, y + 78), "%d, %d, %d" % rgb, font=font(12), fill=(150, 150, 156))
            sx += sw
        sx += 4
    tris = sum(m["triangles"] for e in result["models"].values() for m in e["meshes"].values())
    big = max(result["models"].items(), key=lambda kv: sum(m["triangles"] for m in kv[1]["meshes"].values()))
    draw.text((pad, y + 104), f"{len(result['models'])} models, {sum(len(e['meshes']) for e in result['models'].values())} meshes, "
              f"{tris} triangles in all; the biggest is {big[0]} at {sum(m['triangles'] for m in big[1]['meshes'].values())}. "
              "The Cedar's crown outline is measured from the PlantFactory western red cedar; everything else is hand-built.",
              font=font(16), fill=(200, 200, 205))
    out = PREVIEWS / "plant_kit.png"

    small(sheet).save(out, optimize=True)
    for path in [PREVIEWS / f"plant_kit-lineup-{k}.png" for k, _ in rows] + [PREVIEWS / "plant_kit-creek.png", PREVIEWS / "plant_kit-island.png"]:
        small(Image.open(path)).save(path, optimize=True)
    print(f"sheet: {out}")


if __name__ == "__main__":
    if IN_BLENDER:
        blender_main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    else:
        driver_main()
