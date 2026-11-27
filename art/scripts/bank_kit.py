"""The bank kit: the small natural props that make the home lake's shore look real.

Plan: docs/superpowers/plans/2026-11-27-leg-3.md, "Visual direction: Real-ish", home lake row
("A bank kit: waterline stones, driftwood, a leaning birch, better reeds. Twice the trees on
the far shore, as a continuous treeline with undergrowth") and "Season-ready" (every tree's
canopy is its own mesh). Everything here is Layer B of the look kit: a MaterialVariant of ours
on a mesh that keeps its vertex colours for hue. So each model is one mesh per family:

    <Name>_bark    trunks, limbs, driftwood          family: bark
    <Name>_leaf    canopies, ferns, bushes, reeds    family: leaf_needle
    <Name>_stone   waterline stones                  family: shore_stone

The kit (15 models, 19 meshes):
    DriftwoodBranch, DriftwoodStump, DriftwoodLog          bark
    BirchLean1, BirchLean2                                  bark + leaf
    ShorePine1 (a spire), ShorePine2 (wind-shaped)          bark + leaf
    Fern1, Fern2, Bush1, Bush2                              leaf
    ReedClump1 (cattails), ReedClump2 (rush and cattails)   leaf
    ShoreStones1, ShoreStones2                              stone

What the game does with these (proven in Studio, 11/27/2026, see stands_split.py):
  * the variant's neutral colour map MULTIPLIES the vertex colour and has a mean of 0.80, so
    every vertex colour is stored 1.25 times lighter than the colour we want to see (--lift),
    clamped at white. The lightest colour a family mesh can show is therefore 204;
  * the variant's maps follow the mesh UVs: 1 UV unit = 1 stud, grain along the long axis
    (V runs along every trunk, limb, blade and frond; blobs and stones are box-mapped).

Where each model sits: it is built with the ground (or the water surface) at height 0 and
reaches a little below it, so it never floats on a slope or a wave. The pivot is the bottom
centre of the box, as everywhere in art/. `bury` in the manifest is how far the ground line is
above the pivot: place the pivot at ground height minus bury. The two-mesh trees carry two
specks at opposite corners so both meshes share one box, and that box is centred on the foot
of the trunk: both meshes go at the same CFrame and a turn spins the tree about its foot.

    python art/scripts/bank_kit.py                 build, export, render, sheet
    python art/scripts/bank_kit.py --no-render     models and manifest only
    python art/scripts/bank_kit.py --compose-only  rebuild the sheet from the renders already made
    blender -b -P art/scripts/bank_kit.py -- --no-render       (the Blender half on its own)

Writes art/models/<Name>_<family>.glb (linear colours, as Blender wants them),
art/models/roblox/<Name>_<family>.glb (display colours, the copy to upload) and the sheet
art/previews/bank_kit.png (plus bank_kit-lineup-*.png and bank_kit-bank-*.png). Scratch goes to
artifacts/bank_kit/. Only this script's own entries in art/models/manifest.json are touched,
and nothing in art/textures/ is written: the family maps are only read for the previews. A
family whose maps are not there yet gets a stand-in map made in artifacts/bank_kit/standin/.
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
SCRATCH = REPO / "artifacts" / "bank_kit"
MANIFEST = MODELS / "manifest.json"
BLENDER = os.environ.get("BLENDER", r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe")

try:
    import bpy  # noqa: F401

    IN_BLENDER = True
except ModuleNotFoundError:
    IN_BLENDER = False

FAMILIES = ("bark", "leaf", "stone")
# The folder names each family's maps may arrive under (the texture modeler is making bark and
# leaf_needle today), and the tile size to assume until texture_families.json says otherwise.
SLUGS = {
    "bark": ("bark", "rough_timber", "rough_timber_bark", "timber_bark"),
    "leaf": ("leaf_needle", "leaf", "needle"),
    "stone": ("shore_stone",),
}
WANTED = {"bark": "bark", "leaf": "leaf_needle", "stone": "shore_stone"}
DEFAULT_TILE = {"bark": 6.0, "leaf": 4.0, "stone": 8.0}

# ---------------------------------------------------------------------------------------
# Palette: the colours we want to SEE in the game (sRGB 0..255), before the lift.
# Home lake, Real-ish: silver driftwood, pale birch, dark pines, olive reeds, grey-brown stone.
# ---------------------------------------------------------------------------------------
PAL = {
    # driftwood (Big Lake row: driftwood 170,162,150)
    "drift_light": (170, 162, 150),
    "drift_dark": (140, 130, 118),
    "drift_crack": (106, 98, 88),
    "drift_end": (184, 174, 156),
    # birch
    "birch_white": (204, 200, 190),   # 204 is as light as the neutral map lets it be
    "birch_shade": (180, 176, 166),
    "birch_mark": (54, 50, 46),
    "birch_foot": (112, 104, 94),
    "birch_twig": (104, 88, 74),
    "birch_leaf": (110, 140, 70),
    "birch_leaf_deep": (88, 118, 58),
    "birch_leaf_sun": (124, 152, 78),
    # shore pine
    "pine_bark": (98, 80, 64),
    "pine_bark_dark": (76, 63, 52),
    "pine_bark_high": (120, 92, 70),
    "pine_needle": (52, 84, 66),
    "pine_needle_sun": (60, 92, 58),
    "pine_needle_deep": (38, 62, 48),
    # undergrowth
    "fern": (84, 118, 56),
    "fern_tip": (112, 140, 68),
    "fern_deep": (62, 90, 46),
    "bush": (78, 108, 58),
    "bush_sun": (98, 126, 64),
    "bush_deep": (58, 84, 48),
    # reeds
    "reed": (110, 120, 60),
    "reed_tip": (140, 130, 80),
    "reed_base": (84, 96, 52),
    "rush": (92, 110, 58),
    "cattail_head": (96, 64, 40),
    "cattail_head_dark": (70, 46, 30),
    # waterline stones (shore_stone target 118,112,102)
    "stone": (118, 112, 102),
    "stone_light": (136, 130, 118),
    "stone_brown": (124, 110, 94),
    "stone_grey": (108, 108, 104),
    "stone_wet": (72, 70, 62),
}

# name -> what it is for (the builders themselves are in the Blender half)
KIT = {
    "DriftwoodBranch": {"kind": "driftwood", "where": "On the sand or half in the shallows, any turn. Lies along X.",
                        "replaces": "Nothing yet: new dressing for the home lake bank"},
    "DriftwoodStump": {"kind": "driftwood", "where": "On the bank or the wet band, roots on the ground.",
                       "replaces": "Nothing yet: new dressing for the home lake bank"},
    "DriftwoodLog": {"kind": "driftwood", "where": "On the sand, or at the waterline with one end in the water. Lies along X.",
                     "replaces": "Nothing yet: new dressing for the home lake bank"},
    "BirchLean1": {"kind": "birch", "where": "Foot on the bank 1 to 3 studs back from the water. It leans toward Roblox -X: turn that at the water.",
                   "replaces": "Nothing yet (LeafyTree stays for inland spots)"},
    "BirchLean2": {"kind": "birch", "where": "A twin-stem birch for the bank, as BirchLean1. Leans toward Roblox -X.",
                   "replaces": "Nothing yet (LeafyTree stays for inland spots)"},
    "ShorePine1": {"kind": "pine", "where": "The treeline: on land, 8 studs or more back from the water. Any turn, scale 0.8 to 1.2.",
                   "replaces": "PineTall on the lake's far shore (the creek keeps PineTall and PineShort for now)"},
    "ShorePine2": {"kind": "pine", "where": "The treeline's front row and gaps: on land. The long limbs point toward Roblox -X.",
                   "replaces": "PineShort on the lake's far shore"},
    "Fern1": {"kind": "fern", "where": "On land under the trees and along the path, in groups of two to four.",
              "replaces": "Nothing yet: undergrowth for the treeline"},
    "Fern2": {"kind": "fern", "where": "On land, mixed with Fern1.", "replaces": "Nothing yet: undergrowth for the treeline"},
    "Bush1": {"kind": "bush", "where": "On land at the feet of the treeline and between the trees.",
              "replaces": "Nothing yet: undergrowth for the treeline"},
    "Bush2": {"kind": "bush", "where": "On land, mixed with Bush1.", "replaces": "Nothing yet: undergrowth for the treeline"},
    "ReedClump1": {"kind": "reeds", "where": "IN THE WATER: the shallows and the weed bed. The stems reach 1 stud under the surface.",
                   "replaces": "Reeds (the stick reeds over the weed bed)"},
    "ReedClump2": {"kind": "reeds", "where": "IN THE WATER, mixed with ReedClump1; also right at the waterline.",
                   "replaces": "Reeds (the stick reeds over the weed bed)"},
    "ShoreStones1": {"kind": "stones", "where": "AT THE WATERLINE, half in the water: the dark wet band is painted on at the ground line.",
                     "replaces": "Nothing yet: new dressing for the home lake bank"},
    "ShoreStones2": {"kind": "stones", "where": "AT THE WATERLINE, mixed with ShoreStones1.",
                     "replaces": "Nothing yet: new dressing for the home lake bank"},
}


def parse_args(argv):
    ap = argparse.ArgumentParser(description="Build the home lake bank kit (Layer B, one mesh per family).")
    ap.add_argument("--lift", type=float, default=1.25, help="how much lighter than the target the vertex colours are stored")
    ap.add_argument("--no-render", action="store_true", help="build and export only")
    ap.add_argument("--compose-only", action="store_true", help="rebuild the sheet from the renders already made")
    ap.add_argument("--check-faces", action="store_true",
                    help="render the line-ups with back faces in magenta to artifacts/bank_kit/faces-*.png, and stop")
    ap.add_argument("--samples", type=int, default=int(os.environ.get("ART_SAMPLES", "64")))
    return ap.parse_args(argv)


def family_maps():
    """Where each family's maps are, and how many studs one tile covers. Read only."""
    table = {}
    try:
        table = json.loads((HERE / "texture_families.json").read_text(encoding="utf-8"))["families"]
    except (OSError, KeyError, ValueError):
        pass
    out = {}
    for fam in FAMILIES:
        found = None
        for slug in SLUGS[fam]:
            if all((TEXTURES / slug / f"{slug}_{k}.png").exists() for k in ("neutral", "normal", "rough")):
                found = slug
                break
        if found:
            out[fam] = {"slug": found, "dir": str(TEXTURES / found), "standin": False,
                        "tile": float(table.get(found, {}).get("studs_per_tile", DEFAULT_TILE[fam]))}
        else:
            slug = WANTED[fam]
            out[fam] = {"slug": slug, "dir": str(SCRATCH / "standin" / slug), "standin": True,
                        "tile": float(table.get(slug, {}).get("studs_per_tile", DEFAULT_TILE[fam]))}
    return out


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
    maps = family_maps()
    LIFT = args.lift
    UP = Vector((0, 0, 1))

    def scene_of():
        return bpy.context.scene

    def mix(a, b, t):
        t = min(1.0, max(0.0, t))
        return tuple(x + (y - x) * t for x, y in zip(a, b))

    def shade(c, f):
        return tuple(x * f for x in c)

    def clamp(x, lo=0.0, hi=1.0):
        return lo if x < lo else hi if x > hi else x

    # ------------------------------------------------------------------ geometry
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

        def flat(self, pts, cols, interior=None, uvs=None):
            """A flat-shaded face on its own vertices, box-mapped at 1 UV unit = 1 stud. With
            `interior`, it is turned to face away from that point."""
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
        """n points on a Catmull-Rom curve through the control points."""
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
        """A limb along `path`. Round the limb the UV runs out and back (mirrored), so there is
        no seam; V is the length in studs. `col` is a colour or fn(segment, side, mid, out).
        cap0/cap1: None (open, for a tip or a hidden joint) or a dict for cap()."""
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
        """Close the end of a limb. depth > 0 hollows it; heart = (colour, share) adds a darker
        or lighter middle, for end grain."""
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
        """A lumpy ball: an icosphere pushed about by slow noise. `col` is fn(point, normal).
        floor: cut it off flat at that height (and close it). power < 1 squares it up."""
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
        """Two specks at opposite corners, so each mesh of a model has the model's whole box."""
        e = 0.02
        G.flat([lo, lo + Vector((e, 0, 0)), lo + Vector((0, e, 0))], rgb)
        G.flat([hi, hi - Vector((e, 0, 0)), hi - Vector((0, e, 0))], rgb)

    # ------------------------------------------------------------------ colour helpers
    def leaf_col(deep, base, sun, zc, rz, tone=1.0):
        def fn(p, n):
            h = clamp((p.z - (zc - rz)) / (2 * rz))
            t = 0.55 * h + 0.45 * (0.5 + 0.5 * n.z)
            c = mix(deep, base, t * 2) if t < 0.5 else mix(base, sun, t * 2 - 1)
            return shade(c, tone)
        return fn

    def drift_col(rng, span=0.07):
        """Bleached wood: silver on top, greyer underneath, a slow change of tone along the limb."""
        tone = {}

        def fn(i, k, mid, out):
            f = tone.setdefault(i, rng.random())
            c = mix(PAL["drift_dark"], PAL["drift_light"], 0.55 + 0.6 * out.z)
            return shade(c, 1 - span / 2 + span * f)
        return fn

    def jag(rng, sides, lo, hi):
        return [rng.uniform(lo, hi) if k % 2 == 0 else rng.uniform(lo, hi) * 0.25 for k in range(sides)]

    # ------------------------------------------------------------------ 1. driftwood
    def driftwood_branch():
        rng = random.Random(11)
        G = Geo()
        col = drift_col(rng)
        n = 11
        main = spline([(-4.3, 0.1, 0.34), (-2.5, 0.4, 0.44), (-0.7, -0.1, 0.62), (1.1, 0.15, 0.86), (2.8, 0.6, 1.3), (4.3, 1.25, 2.05)], n)
        tube(G, main, ramp([0.46, 0.42, 0.36, 0.28, 0.17, 0.04], n), 6, col, cap0={"col": PAL["drift_end"], "depth": 0.1},
             jag0=jag(rng, 6, 0.05, 0.3), ring_fn=lambda i, k, a: 1 + 0.08 * math.sin(i * 1.7 + k * 2.1))
        # a leg that props it up, a fork that points at the sky, and a broken stub
        tube(G, spline([(0.1, 0.0, 0.7), (0.8, -0.9, 0.6), (1.45, -1.9, 0.26), (1.8, -2.7, 0.02)], 6), ramp([0.25, 0.2, 0.13, 0.04], 6), 6, col)
        tube(G, spline([(1.5, 0.2, 0.9), (2.0, -0.35, 1.65), (2.25, -0.75, 2.5), (2.8, -1.0, 3.15)], 6), ramp([0.19, 0.15, 0.1, 0.03], 6), 6, col)
        tube(G, spline([(-1.7, 0.25, 0.5), (-1.95, 0.95, 0.85), (-2.05, 1.4, 1.35)], 4), ramp([0.2, 0.15, 0.09], 4), 6, col,
             cap1={"col": PAL["drift_end"], "depth": 0.05}, jag1=jag(rng, 6, 0.0, 0.25))
        tube(G, spline([(3.0, 0.65, 1.38), (3.3, 1.5, 1.5), (3.35, 2.1, 1.85)], 4), ramp([0.11, 0.08, 0.02], 4), 6, col)
        return {"bark": G}, {"keys": {"bark": ["drift_light", "drift_dark", "drift_end"]}}

    def driftwood_stump():
        rng = random.Random(23)
        G = Geo()
        col = drift_col(rng)
        n = 5
        trunk = spline([(0, 0, -0.4), (0.03, 0.0, 0.45), (0.1, 0.03, 1.1), (0.26, 0.07, 1.8)], n)
        tube(G, trunk, ramp([1.25, 0.97, 0.85, 0.78], n), 8, col, cap0={"col": PAL["drift_dark"]},
             ring_fn=lambda i, k, a: 1 + (0.14 * math.cos(3 * a + 0.6) if i < 2 else 0.05 * math.sin(2 * a + i)),
             jag1=[0.6, 0.05, 0.3, 0.85, 0.1, 0.45, 0.0, 0.25], cap1={"col": PAL["drift_crack"], "depth": 0.5})
        # roots the lake has washed bare: thick at the trunk, low, each its own length
        for j, (a, L) in enumerate(((0.3, 2.7), (1.35, 1.9), (2.45, 2.4), (3.3, 1.7), (4.35, 2.9), (5.4, 2.1))):
            a2 = a + rng.uniform(-0.3, 0.3)
            a3 = a2 + rng.uniform(-0.35, 0.35)
            arch = rng.uniform(0.0, 0.22)
            ctrl = [(0.3 * math.cos(a), 0.3 * math.sin(a), 0.62), (0.42 * L * math.cos(a), 0.42 * L * math.sin(a), 0.5 + arch),
                    (0.72 * L * math.cos(a2), 0.72 * L * math.sin(a2), 0.2 + arch * 0.4), (L * math.cos(a3), L * math.sin(a3), -0.35)]
            pts = spline(ctrl, 6)
            tube(G, pts, ramp([0.5, 0.4, 0.25, 0.08], 6), 6, col, spin=j)
            if j in (0, 4):   # a rootlet forks off the two long ones
                side = Vector((-math.sin(a2), math.cos(a2), 0)) * (1 if j == 0 else -1)
                tube(G, [pts[2], pts[3] + side * 0.5 - UP * 0.1, pts[3] + side * 1.1 - UP * 0.45], [0.2, 0.14, 0.05], 4, col)
        # one root torn off short, pointing up
        tube(G, spline([(-0.2, 0.25, 0.75), (-0.8, 0.9, 0.95), (-1.1, 1.3, 1.45)], 4), ramp([0.32, 0.24, 0.14], 4), 6, col,
             cap1={"col": PAL["drift_end"], "depth": 0.05}, jag1=jag(rng, 6, 0.0, 0.3))
        return {"bark": G}, {"keys": {"bark": ["drift_light", "drift_dark", "drift_crack", "drift_end"]}}

    def driftwood_log():
        rng = random.Random(37)
        G = Geo()
        col = drift_col(rng)
        n = 8
        body = spline([(-2.5, 0.0, 0.38), (-0.8, 0.1, 0.43), (0.9, 0.03, 0.45), (2.45, -0.14, 0.4)], n)
        tube(G, body, ramp([0.66, 0.63, 0.59, 0.55], n), 8, col,
             ring_fn=lambda i, k, a: 1 + 0.06 * math.sin(i * 2.3 + k * 1.3),
             cap0={"col": PAL["drift_end"], "depth": 0.0, "heart": (shade(PAL["drift_end"], 0.86), 0.42)},
             jag1=[0.5, 0.1, 0.25, 0.7, 0.05, 0.45, 0.15, 0.3], cap1={"col": PAL["drift_crack"], "depth": 0.35})
        tube(G, spline([(0.6, 0.0, 0.85), (0.78, 0.28, 1.3), (0.82, 0.45, 1.72)], 4), ramp([0.21, 0.16, 0.1], 4), 6, col,
             cap1={"col": PAL["drift_end"], "depth": 0.04}, jag1=jag(rng, 6, 0.0, 0.2))
        tube(G, spline([(-1.2, 0.1, 0.8), (-1.3, -0.35, 1.05), (-1.3, -0.6, 1.15)], 3), [0.16, 0.12, 0.08], 6, col,
             cap1={"col": PAL["drift_end"], "depth": 0.03})
        return {"bark": G}, {"keys": {"bark": ["drift_light", "drift_dark", "drift_crack", "drift_end"]}}

    # ------------------------------------------------------------------ 2. leaning birch
    def lean_path(L, th0, th1, az, start, rng, steps=64):
        """A stem that starts leaning th0 degrees from upright toward `az` and straightens to th1."""
        pts = [Vector(start)]
        ds = L / steps
        ph = rng.uniform(0, 6.28)
        for j in range(steps):
            s = (j + 0.5) * ds
            th = math.radians(th0 + (th1 - th0) * s / L)
            side = 0.05 * math.cos(s * 0.6 + ph)
            d = Vector((math.sin(th) * math.cos(az) - side * math.sin(az), math.sin(th) * math.sin(az) + side * math.cos(az), math.cos(th)))
            pts.append(pts[-1] + d.normalized() * ds)

        def at(s):
            t = clamp(s / L) * steps
            i = min(int(t), steps - 1)
            return pts[i].lerp(pts[i + 1], t - i)
        return at

    def birch_stem(bark, leaf, rng, at, L, r0, limbs, n_marks, crown, foot=True, tone=1.0):
        """One white stem with dark marks, its limbs, and the leaf masses of its crown.
        crown: (how far up the stem 0..1, which side in degrees, how far off the stem, radius)."""
        def radius(s):
            r = r0 * (1 - s / L) ** 0.85 + 0.06
            return r * (1.5 - 0.8 * s) if foot and s < 0.6 else r

        base = [0.0, 0.3, 0.6, 1.4] if foot else [0.0, 1.2]
        while base[-1] + 2.3 < L:
            base.append(base[-1] + 2.3)
        if L - base[-1] > 0.9:
            base.append(L)
        else:
            base[-1] = L
        marks = {}   # station -> (direction the mark faces, how far round it reaches)
        for _ in range(n_marks):
            s = rng.uniform(1.5, L * 0.88)
            a = rng.uniform(0, 6.28)
            marks[round(s, 3)] = (Vector((math.cos(a), math.sin(a), 0)), rng.uniform(-0.25, 0.5))
        for s, az, _length, _rise in limbs:   # the dark "eyebrow" under each limb
            marks[round(s - 0.36, 3)] = (Vector((math.cos(az), math.sin(az), 0)), 0.1)
        stations = list(base)
        band = 0.2
        for s in marks:
            stations = [x for x in stations if not (s - 0.14 < x < s + band + 0.14) or x in (0.0, L)]
            stations += [s, s + band]
        stations = sorted(set(stations))
        fleck = {}

        def col(i, k, mid, out):
            s = stations[i]
            key = round(s, 3)
            if key in marks and out.dot(marks[key][0]) > marks[key][1]:
                return PAL["birch_mark"]
            f = fleck.setdefault((i, k), rng.random())
            c = mix(PAL["birch_white"], PAL["birch_shade"], f * 0.8)
            if foot and s < 2.2:   # rough grey at the foot, with black flecks
                c = mix(PAL["birch_foot"], c, s / 2.2)
                if f < 0.3 - s * 0.1:
                    c = mix(c, PAL["birch_mark"], 0.7)
            return shade(c, tone)

        tube(bark, [at(s) for s in stations], [radius(s) for s in stations], 6, col,
             cap0={"col": PAL["birch_foot"]} if foot else None, ring_fn=(lambda i, k, a: 1 + (0.14 * math.cos(3 * a + 1.0) if stations[i] < 0.4 else 0.0)) if foot else None)

        def twig_col(i, k, mid, out):
            return shade(mix(PAL["birch_white"], PAL["birch_twig"], clamp(i / 2)), tone)

        masses = []   # (centre, radii, turn, hangs)
        for s, az, length, rise in limbs:
            p0 = at(s)
            h = Vector((math.cos(az), math.sin(az), 0))
            pts = spline([p0, p0 + (h * 0.45 + UP * 0.42 * rise) * length, p0 + (h * 0.85 + UP * 0.7 * rise) * length,
                          p0 + (h * 1.0 + UP * 0.66 * rise) * length], 4)
            r = radius(s) * 0.55
            tube(bark, pts, ramp([r, r * 0.7, 0.04], 4), 4, twig_col, spin=0.5)
            # a long mass over the outer two thirds of the limb, its far end hanging
            c = pts[1].lerp(pts[3], 0.62) - UP * 0.15
            masses.append((c, (length * 0.56, length * 0.4, length * 0.35), Euler((rng.uniform(-0.15, 0.15), rng.uniform(0.22, 0.4), az)), True))
        for frac, side, dist, r in crown:
            a = math.radians(side)
            c = at(L * frac) + Vector((math.cos(a), math.sin(a), 0)) * dist + (UP * 0.3 if frac >= 1 else UP * 0)
            masses.append((c, (r, r * 0.88, r * 1.15), Euler((rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), rng.uniform(0, 3.1))), False))
        for j, (c, radii, turn, hangs) in enumerate(masses):
            f = rng.uniform(0.94, 1.08)
            radii = tuple(x * f for x in radii)
            fn = leaf_col(PAL["birch_leaf_deep"], PAL["birch_leaf"], PAL["birch_leaf_sun"], c.z, radii[2], rng.uniform(0.95, 1.04))
            blob(leaf, c, radii, fn, 2, seed=rng.randrange(999), jit=0.2, freq=1.5, rot=turn)
            if hangs and j % 2 == 0:   # a spray hanging under the limb's leaves
                far = Vector((math.cos(turn.z), math.sin(turn.z), 0))
                c2 = c + far * radii[0] * 0.45 - UP * radii[2] * 1.0
                fn2 = leaf_col(PAL["birch_leaf_deep"], PAL["birch_leaf_deep"], PAL["birch_leaf"], c2.z, radii[2] * 0.7, 1.0)
                blob(leaf, c2, (radii[0] * 0.4, radii[1] * 0.5, radii[2] * 0.8), fn2, 1, seed=rng.randrange(999), jit=0.12)

    def birch(variant):
        rng = random.Random(100 + variant)
        bark, leaf = Geo(), Geo()
        rad = math.radians
        if variant == 1:   # one stem, 16 studs, leaning about 16 degrees
            L = 16.6
            at = lean_path(L, 23, 9, 0.0, (0, 0, -1.0), rng)
            limbs = [(7.6, rad(20), 3.9, 0.85), (8.9, rad(205), 3.3, 0.95), (10.2, rad(-70), 3.4, 0.9), (11.5, rad(110), 2.9, 1.0),
                     (12.7, rad(-5), 2.7, 1.0), (13.8, rad(180), 2.2, 1.1)]
            birch_stem(bark, leaf, rng, at, L, 0.5, limbs, 6, [(0.9, 60, 0.5, 1.15), (1.0, 0, 0.0, 0.95)])
        else:              # twin stems from one foot, 14 studs, leaning about 12 and 20 degrees
            L = 14.8
            at = lean_path(L, 17, 7, rad(-12), (0, 0, -1.0), rng)
            birch_stem(bark, leaf, rng, at, L, 0.46,
                       [(7.2, rad(-85), 3.3, 0.9), (8.8, rad(160), 3.0, 1.0), (10.3, rad(-150), 2.6, 1.0), (11.6, rad(-20), 2.3, 1.05)], 4,
                       [(0.9, 200, 0.45, 1.05), (1.0, 0, 0.0, 0.9)])
            L2 = 11.6
            at2 = lean_path(L2, 31, 12, rad(38), at(1.1) - Vector((0, 0, 0.1)), rng)
            birch_stem(bark, leaf, rng, at2, L2, 0.34, [(6.0, rad(80), 2.9, 0.9), (7.7, rad(-10), 2.5, 1.0)], 3,
                       [(1.0, 0, 0.0, 0.95)], foot=False, tone=0.985)
        return {"bark": bark, "leaf": leaf}, {
            "keys": {"bark": ["birch_white", "birch_shade", "birch_mark", "birch_foot", "birch_twig"],
                     "leaf": ["birch_leaf", "birch_leaf_deep", "birch_leaf_sun"]},
            "foot_centred": True}

    # ------------------------------------------------------------------ 3. shore pines
    def pine_bark_col(rng, z_hi):
        fl = {}

        def fn(i, k, mid, out):
            f = fl.setdefault((i, k), rng.random())
            c = mix(PAL["pine_bark_dark"], PAL["pine_bark"], clamp(mid.z / 3.0 + 0.2))
            c = mix(c, PAL["pine_bark_high"], clamp((mid.z - z_hi * 0.45) / (z_hi * 0.4)))
            return shade(c, 0.93 + 0.14 * f)
        return fn

    def path_at(path):
        def at(z):
            for a, b in zip(path, path[1:]):
                if a.z <= z <= b.z:
                    return a.lerp(b, (z - a.z) / max(b.z - a.z, 1e-6))
            return path[-1].copy() if z > path[-1].z else path[0].copy()
        return at

    def tier(G, rng, c, z0, R, h, N, wind_az, wind, tone):
        """One skirt of a spire pine: drooping tips, notches between them, a dark underside."""
        a0 = rng.uniform(0, 6.28)
        inside = Vector((c.x, c.y, z0 + 0.4 * h))
        apex = Vector((c.x + rng.uniform(-0.12, 0.12), c.y + rng.uniform(-0.12, 0.12), z0 + h))
        under = Vector((c.x, c.y, z0 + 0.3 + 0.12 * R))
        M, Tp, Nt = [], [], []
        for k in range(N):
            a = a0 + 2 * math.pi * k / N + rng.uniform(-0.14, 0.14)
            w = 1 + wind * math.cos(a - wind_az)
            rt = R * rng.uniform(0.84, 1.12) * w
            droop = rng.uniform(0.25, 0.7) * (0.45 + R / 7)
            Tp.append(Vector((c.x + math.cos(a) * rt, c.y + math.sin(a) * rt, z0 - droop)))
            M.append(Vector((c.x + math.cos(a) * R * 0.5 * w, c.y + math.sin(a) * R * 0.5 * w, z0 + 0.44 * h + rng.uniform(-0.1, 0.1) * h)))
            a2 = a + math.pi / N
            Nt.append(Vector((c.x + math.cos(a2) * R * 0.62 * w, c.y + math.sin(a2) * R * 0.62 * w, z0 + 0.22 + 0.05 * R)))
        sun, base, deep = (shade(PAL[k], tone) for k in ("pine_needle_sun", "pine_needle", "pine_needle_deep"))
        for k in range(N):
            k2 = (k + 1) % N
            f = rng.uniform(0.94, 1.06)
            G.flat([apex, M[k], M[k2]], shade(mix(base, sun, 0.8), f), inside)
            G.flat([M[k], Tp[k], Nt[k]], shade(mix(base, sun, 0.35), f), inside)
            G.flat([M[k], Nt[k], M[k2]], shade(base, f * 0.97), inside)
            G.flat([M[k2], Nt[k], Tp[k2]], shade(mix(base, deep, 0.25), f), inside)
            G.flat([under, Tp[k], Nt[k]], deep, inside)
            G.flat([under, Nt[k], Tp[k2]], shade(deep, 0.92), inside)

    def flare(i, k, a):
        return 1 + (0.3 * (0.5 + 0.5 * math.cos(4 * a + 0.8)) + 0.12 if i == 0 else 0.1 * math.cos(4 * a + 0.8) if i == 1 else 0.0)

    def stub(G, rng, p0, az, length, r, col):
        h = Vector((math.cos(az), math.sin(az), 0))
        pts = [p0, p0 + h * length * 0.55 + UP * 0.05, p0 + h * length - UP * 0.12 * length]
        tube(G, pts, [r, r * 0.7, r * 0.4], 4, col, cap1={"col": PAL["pine_bark_high"], "depth": 0.0}, spin=0.6)

    def pine_spire():
        """A spruce-shaped shore pine, 24 studs: seven ragged skirts on a bare lower trunk."""
        rng = random.Random(301)
        bark, leaf = Geo(), Geo()
        n = 13
        path = spline([(0, 0, -1.0), (0.04, 0.0, 3.0), (0.22, 0.1, 10.0), (0.12, 0.28, 18.0), (0.0, 0.32, 22.6)], n)
        col = pine_bark_col(rng, 22)
        tube(bark, path, ramp([0.98, 0.8, 0.58, 0.3, 0.07], n), 8, col, ring_fn=flare, cap0={"col": PAL["pine_bark_dark"]})
        at = path_at(path)
        for z, az, length in ((2.7, 0.9, 1.3), (3.9, 3.6, 1.0), (4.6, 5.3, 1.5)):
            stub(bark, rng, at(z), az, length, 0.13, col)
        zs = [5.2, 8.0, 10.7, 13.2, 15.5, 17.6, 19.5, 21.2]
        Rs = [5.3, 4.9, 4.3, 3.6, 2.9, 2.25, 1.6, 1.0]
        for j, (z0, R) in enumerate(zip(zs, Rs)):
            h = (zs[j + 1] - z0) * 1.85 if j + 1 < len(zs) else 3.1
            c = at(z0) + Vector((rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25), 0))
            tier(leaf, rng, c, z0, R, h, 7 if R > 2 else 6, 0.4, 0.1, rng.uniform(0.95, 1.05))
        return {"bark": bark, "leaf": leaf}, {
            "keys": {"bark": ["pine_bark", "pine_bark_dark", "pine_bark_high"],
                     "leaf": ["pine_needle", "pine_needle_sun", "pine_needle_deep"]},
            "foot_centred": True}

    def pine_wind():
        """A wind-shaped shore pine, 19 studs: a bare bent trunk, a full crown and flat pads of
        needles on a few long limbs, longest on the lee side (+X here)."""
        rng = random.Random(407)
        bark, leaf = Geo(), Geo()
        n = 13
        path = spline([(0, 0, -1.0), (0.08, 0.0, 2.5), (0.5, 0.1, 7.0), (0.85, 0.0, 12.0), (1.0, -0.15, 16.0), (1.3, -0.2, 18.2)], n)
        col = pine_bark_col(rng, 18)
        tube(bark, path, ramp([0.9, 0.7, 0.56, 0.43, 0.26, 0.07], n), 8, col, ring_fn=flare, cap0={"col": PAL["pine_bark_dark"]})
        at = path_at(path)
        for z, az, length in ((3.8, 2.4, 1.2), (5.6, 5.6, 1.6), (6.9, 1.0, 1.1)):
            stub(bark, rng, at(z), az, length, 0.12, col)
        rad = math.radians
        limbs = [(8.8, rad(12), 4.6, 0.5), (10.5, rad(170), 2.9, 0.6), (11.9, rad(-78), 3.7, 0.7), (13.2, rad(58), 3.6, 0.8),
                 (14.5, rad(205), 2.5, 0.8), (15.4, rad(-35), 2.9, 0.9)]

        def pad(c, rx, ry, rz, az, tilt=0.0):
            fn = leaf_col(PAL["pine_needle_deep"], PAL["pine_needle"], PAL["pine_needle_sun"], c.z, rz, rng.uniform(0.95, 1.05))
            blob(leaf, c, (rx, ry, rz), fn, 2, seed=rng.randrange(999), jit=0.22, freq=1.7, rot=Euler((0, tilt, az)), power=0.85)

        for z, az, length, rise in limbs:
            p0 = at(z)
            h = Vector((math.cos(az), math.sin(az), 0))
            pts = spline([p0, p0 + h * length * 0.45 + UP * rise * 0.5, p0 + h * length * 0.8 + UP * rise * 1.0, p0 + h * length + UP * rise * 1.35], 4)
            r = 0.2 + 0.035 * length
            tube(bark, pts, ramp([r, r * 0.7, 0.06], 4), 4, col, spin=0.5)
            pad(pts[2] + h * length * 0.08 + UP * 0.45, length * 0.6, length * 0.46, 0.72, az, -0.08)
            if length > 3.6:
                side = Vector((-h.y, h.x, 0)) * rng.choice((-1, 1))
                pad(pts[1] + h * length * 0.15 + side * length * 0.3 + UP * 0.7, length * 0.36, length * 0.3, 0.58, az + 0.6)
        top = at(18.0)
        pad(top + Vector((0.4, 0.1, -1.3)), 2.9, 2.4, 1.05, 0.3)
        pad(top + Vector((-0.6, -0.5, -0.3)), 2.0, 1.7, 0.9, 1.2)
        pad(top + Vector((0.5, 0.2, 0.6)), 1.25, 1.1, 0.85, 0.0)
        return {"bark": bark, "leaf": leaf}, {
            "keys": {"bark": ["pine_bark", "pine_bark_dark", "pine_bark_high"],
                     "leaf": ["pine_needle", "pine_needle_sun", "pine_needle_deep"]},
            "foot_centred": True}

    # ------------------------------------------------------------------ 4. undergrowth
    def frond(G, rng, az, length, e0, e1, width, stations=8, tone=1.0, pal=("fern_deep", "fern", "fern_tip"),
              origin=None, teeth=True):
        """One arching frond (toothed for a fern, plain for a leafy spray): v runs along it.
        It leaves `origin` at e0 degrees above level and ends at e1."""
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

    def fern(variant):
        rng = random.Random(500 + variant)
        G = Geo()
        count = 9 if variant == 1 else 7
        a0 = rng.uniform(0, 6.28)
        for k in range(count):
            az = a0 + 2 * math.pi * k / count + rng.uniform(-0.3, 0.3)
            if variant == 1:   # a full arching clump, about 3 studs across and 1.5 high
                frond(G, rng, az, rng.uniform(1.7, 2.1), rng.uniform(74, 84), rng.uniform(-22, 0), rng.uniform(0.36, 0.44),
                      tone=rng.uniform(0.94, 1.05))
            else:              # a shuttlecock: taller and more upright, about 2.4 across and 2 high
                frond(G, rng, az, rng.uniform(2.1, 2.5), rng.uniform(80, 86), rng.uniform(12, 34), rng.uniform(0.3, 0.38),
                      tone=rng.uniform(0.94, 1.05))
        for k in range(3 if variant == 1 else 2):   # young fronds standing in the middle
            frond(G, rng, rng.uniform(0, 6.28), rng.uniform(1.2, 1.7), 88, 60, 0.24, stations=6, tone=1.06)
        return {"leaf": G}, {"keys": {"leaf": ["fern", "fern_tip", "fern_deep"]}}

    def bush(variant):
        """A dome of broad leaves over a dark heart: the heart is three lumps you only see between
        the leaves, so the outline is a bush's and not a boulder's."""
        rng = random.Random(600 + variant)
        G = Geo()
        if variant == 1:   # rounded, about 4 studs across and 3 high
            lumps = [(0.0, 0.0, 1.2, 1.25, 1.15, 1.25), (0.85, 0.4, 0.85, 0.95, 0.9, 0.9), (-0.8, -0.3, 0.9, 1.0, 0.9, 0.95)]
            leaves = 24
        else:              # low and sprawling, about 5 studs across and 2.4 high
            lumps = [(-1.1, 0.15, 0.75, 1.2, 1.05, 0.9), (0.45, 0.35, 0.95, 1.3, 1.1, 1.05), (1.5, -0.35, 0.65, 0.95, 0.9, 0.75)]
            leaves = 26
        for x, y, z, rx, ry, rz in lumps:
            fn = leaf_col(PAL["bush_deep"], PAL["bush_deep"], PAL["bush"], z, rz, 1.0)
            blob(G, (x, y, z), (rx, ry, rz), fn, 2, seed=rng.randrange(999), jit=0.2, freq=1.8,
                 rot=Euler((0, 0, rng.uniform(0, 3.1))), floor=-0.25)
        for k in range(leaves):
            x, y, z, rx, ry, rz = lumps[k % len(lumps)]
            az = 2.4 * k + rng.uniform(-0.4, 0.4)             # the golden angle walks them round evenly
            el = math.radians(2 + 82 * ((k * 0.618) % 1.0) ** 1.25)
            dv = Vector((math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el)))
            o = Vector((x, y, z)) + Vector((dv.x * rx, dv.y * ry, dv.z * rz)) * 0.8
            deg = math.degrees(el)
            frond(G, rng, az, rng.uniform(0.9, 1.3), deg + rng.uniform(5, 20), deg - rng.uniform(35, 60), rng.uniform(0.34, 0.46),
                  stations=5, tone=rng.uniform(0.97, 1.08), pal=("bush", "bush", "bush_sun"), origin=o, teeth=False)
        return {"leaf": G}, {"keys": {"leaf": ["bush", "bush_sun", "bush_deep"]}}

    # ------------------------------------------------------------------ 5. better reeds
    def blade(G, rng, x, y, az, height, lean, width, kink=None, tone=1.0):
        """A cattail leaf: a three-sided strip standing in the water, arching at the tip."""
        d = Vector((math.cos(az), math.sin(az), 0))
        side = Vector((-d.y, d.x, 0))
        stations = 5
        p = Vector((x, y, -1.0))
        P, W, V = [], [], []
        ds = (height + 1.0) / (stations - 1)
        for i in range(stations):
            s = i / (stations - 1)
            e = lean * (0.3 + 1.6 * s * s)
            if kink and s > kink:
                e += 1.7   # the tip has folded over
            if i:
                p = p + (d * math.sin(e) + UP * math.cos(e)) * ds * (0.45 if kink and s > kink else 1.0)
            P.append(p.copy())
            W.append(max(0.02, width * (0.8 + 0.5 * math.sin(math.pi * s * 0.9)) * (1 - s ** 3)))
            V.append(i * ds)
        for i in range(stations - 1):
            s = (i + 0.5) / (stations - 1)
            c = mix(PAL["reed_base"], PAL["reed"], s * 3) if s < 0.33 else mix(PAL["reed"], PAL["reed_tip"], (s - 0.33) * 1.5)
            c = shade(c, tone)
            a, b = P[i], P[i + 1]
            wa, wb = W[i], W[i + 1]
            La, Ra, Ka = a - side * wa, a + side * wa, a - d * wa * 0.45
            Lb, Rb, Kb = b - side * wb, b + side * wb, b - d * wb * 0.45
            mid = (a + b) / 2 - d * (wa + wb) * 0.07
            G.flat([La, Ra, Rb, Lb], c, mid, uvs=[(-wa, V[i]), (wa, V[i]), (wb, V[i + 1]), (-wb, V[i + 1])])
            G.flat([Ra, Ka, Kb, Rb], shade(c, 0.86), mid, uvs=[(wa, V[i]), (wa * 2, V[i]), (wb * 2, V[i + 1]), (wb, V[i + 1])])
            G.flat([Ka, La, Lb, Kb], shade(c, 0.92), mid, uvs=[(-wa * 2, V[i]), (-wa, V[i]), (-wb, V[i + 1]), (-wb * 2, V[i + 1])])

    def cattail(G, rng, x, y, height, lean_az, lean):
        d = Vector((math.cos(lean_az), math.sin(lean_az), 0))
        top = Vector((x, y, height)) + d * math.sin(lean) * height
        pts = spline([(x, y, -1.0), Vector((x, y, height * 0.5)) + d * math.sin(lean) * height * 0.3, top], 4)

        def stem_col(i, k, mid, out):
            return mix(PAL["reed_base"], PAL["reed"], clamp(mid.z / 2.0))

        _, T = tube(G, pts, [0.09, 0.085, 0.075, 0.065], 4, stem_col, spin=rng.uniform(0, 1.5))
        t = T[-1]
        hl = rng.uniform(0.9, 1.2)

        def head_col(i, k, mid, out):
            return mix(PAL["cattail_head"], PAL["cattail_head_dark"], 0.5 - 0.5 * out.z + (0.25 if i == 2 else 0))

        tube(G, [top - t * 0.05, top + t * 0.12, top + t * (hl - 0.12), top + t * hl], [0.08, 0.21, 0.2, 0.07], 6, head_col,
             cap0={"col": PAL["cattail_head_dark"]}, cap1={"col": PAL["cattail_head_dark"]})
        tube(G, [top + t * hl, top + t * (hl + 0.45)], [0.045, 0.012], 4, PAL["reed_tip"])

    def rush(G, rng, x, y, count, height, spread):
        """A tussock of round rush stems fanning out, some with a small brown tuft near the tip."""
        for k in range(count):
            az = rng.uniform(0, 6.28)
            lean = rng.uniform(0.05, spread)
            h = height * rng.uniform(0.7, 1.05)
            d = Vector((math.cos(az), math.sin(az), 0))
            b = Vector((x, y, -1.0)) + d * rng.uniform(0, 0.25)
            mid = b + UP * (1.0 + h * 0.5) + d * math.sin(lean) * h * 0.35
            tip = b + UP * (1.0 + h * math.cos(lean * 0.8)) + d * math.sin(lean) * h
            tone = rng.uniform(0.92, 1.06)

            def col(i, kk, m, out, tone=tone):
                return shade(mix(PAL["reed_base"], PAL["rush"], clamp(m.z / 1.5)) if i < 1 else mix(PAL["rush"], PAL["reed_tip"], 0.4), tone)

            tube(G, [b, mid, tip], [0.08, 0.07, 0.015], 4, col, spin=rng.uniform(0, 1.5))
            if k % 4 == 0:
                c = mid.lerp(tip, 0.62)
                blob(G, c + d * 0.08, (0.15, 0.13, 0.22), lambda p, n: PAL["cattail_head"], 1, seed=k, jit=0.1)

    def reeds(variant):
        rng = random.Random(700 + variant)
        G = Geo()
        if variant == 1:   # cattails: five heads, a stand of leaves, one rush tussock at the edge
            spots = [(0.0, 0.1), (0.75, -0.45), (-0.7, 0.55), (0.3, 0.9), (-0.45, -0.75)]
            for j, (x, y) in enumerate(spots):
                cattail(G, rng, x, y, rng.uniform(3.9, 5.0), rng.uniform(0, 6.28), rng.uniform(0.02, 0.09))
            for k in range(12):
                a = rng.uniform(0, 6.28)
                r = rng.uniform(0.1, 1.2)
                blade(G, rng, math.cos(a) * r, math.sin(a) * r, a + rng.uniform(-0.6, 0.6), rng.uniform(3.8, 6.0),
                      rng.uniform(0.04, 0.17), rng.uniform(0.1, 0.14), kink=0.7 if k in (4, 9) else None, tone=rng.uniform(0.93, 1.06))
            rush(G, rng, 1.25, 0.6, 8, 3.0, 0.4)
        else:              # mostly rush, lower and wider, two cattails and a few leaves
            rush(G, rng, -0.8, 0.2, 11, 4.0, 0.36)
            rush(G, rng, 0.9, -0.5, 9, 3.4, 0.45)
            rush(G, rng, 0.4, 1.1, 6, 2.6, 0.5)
            cattail(G, rng, 0.1, 0.1, 4.6, 1.0, 0.07)
            cattail(G, rng, -0.5, -0.7, 4.0, 4.0, 0.09)
            for k in range(8):
                a = rng.uniform(0, 6.28)
                r = rng.uniform(0.1, 1.0)
                blade(G, rng, math.cos(a) * r - 0.1, math.sin(a) * r, a + rng.uniform(-0.6, 0.6), rng.uniform(3.6, 5.4),
                      rng.uniform(0.05, 0.2), rng.uniform(0.1, 0.14), kink=0.7 if k == 3 else None, tone=rng.uniform(0.93, 1.06))
        return {"leaf": G}, {"keys": {"leaf": ["reed", "reed_tip", "reed_base", "rush", "cattail_head", "cattail_head_dark"]}}

    # ------------------------------------------------------------------ 6. waterline stones
    def stones(variant):
        """Rounded shore stones, each about half under the ground line, the big one a stud high."""
        rng = random.Random(800 + variant)
        G = Geo()
        if variant == 1:   # five stones, about 4 studs across
            spec = [(0.0, 0.1, 0.32, 1.3, 1.0, 0.82, 3, "stone"), (1.4, -0.5, 0.16, 0.76, 0.62, 0.56, 2, "stone_brown"),
                    (-1.3, -0.55, 0.14, 0.62, 0.52, 0.48, 2, "stone_grey"), (0.75, 1.0, 0.1, 0.54, 0.44, 0.4, 2, "stone_light"),
                    (-0.7, 1.05, 0.05, 0.4, 0.33, 0.3, 2, "stone")]
        else:              # a long slab, two cobbles and a pebble
            spec = [(0.0, 0.0, 0.2, 1.7, 0.95, 0.68, 3, "stone_grey"), (1.4, 0.85, 0.2, 0.72, 0.6, 0.6, 2, "stone"),
                    (-1.35, -0.9, 0.12, 0.58, 0.5, 0.45, 2, "stone_brown"), (0.35, -1.2, 0.04, 0.32, 0.27, 0.25, 2, "stone_light")]
        for x, y, zc, rx, ry, rz, sub, key in spec:
            base = PAL[key]
            tone = rng.uniform(0.96, 1.04)

            def col(p, n, base=base, tone=tone):
                c = mix(base, PAL["stone_light"], 0.35 * clamp(n.z) * clamp(p.z / 0.5))   # sun-bleached tops
                wet = 1 - clamp((p.z - 0.08) / 0.22)                                        # the wet band at the water
                return shade(mix(c, PAL["stone_wet"], 0.85 * wet), tone)

            blob(G, (x, y, zc), (rx, ry, rz), col, sub, seed=rng.randrange(999), jit=0.17, freq=1.2,
                 rot=Euler((rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15), rng.uniform(0, 3.1))),
                 smooth=True, floor=-0.4, power=0.78, flat_top=0.8)
        return {"stone": G}, {"keys": {"stone": ["stone", "stone_light", "stone_brown", "stone_grey", "stone_wet"]}}

    BUILDERS = {
        "DriftwoodBranch": driftwood_branch, "DriftwoodStump": driftwood_stump, "DriftwoodLog": driftwood_log,
        "BirchLean1": lambda: birch(1), "BirchLean2": lambda: birch(2),
        "ShorePine1": pine_spire, "ShorePine2": pine_wind,
        "Fern1": lambda: fern(1), "Fern2": lambda: fern(2), "Bush1": lambda: bush(1), "Bush2": lambda: bush(2),
        "ReedClump1": lambda: reeds(1), "ReedClump2": lambda: reeds(2),
        "ShoreStones1": lambda: stones(1), "ShoreStones2": lambda: stones(2),
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

    kit = {}   # name -> {"objs": {fam: obj}, "lo": true bounds, "hi":, "bury":}

    def build_kit():
        result = {}
        for name, fn in BUILDERS.items():
            geos, info = fn()
            los, his = zip(*(g.bounds() for g in geos.values()))
            lo = Vector(tuple(min(v[i] for v in los) for i in range(3)))
            hi = Vector(tuple(max(v[i] for v in his) for i in range(3)))
            if info.get("foot_centred"):   # the box is centred on the trunk's foot
                hx, hy = max(abs(lo.x), abs(hi.x)), max(abs(lo.y), abs(hi.y))
                blo, bhi = Vector((-hx, -hy, lo.z)), Vector((hx, hy, hi.z))
                for fam, g in geos.items():
                    anchors(g, blo, bhi, PAL[info["keys"][fam][0]])
            else:
                blo, bhi = lo, hi
            pivot = Vector(((blo.x + bhi.x) / 2, (blo.y + bhi.y) / 2, blo.z))
            entry = {"kind": KIT[name]["kind"], "bury": round(-blo.z, 2), "height": round(hi.z, 2),
                     "true_studs": [round(hi.x - lo.x, 2), round(hi.z - lo.z, 2), round(hi.y - lo.y, 2)],
                     "studs": [round(bhi.x - blo.x, 2), round(bhi.z - blo.z, 2), round(bhi.y - blo.y, 2)],
                     "foot_centred": bool(info.get("foot_centred")), "anchors": bool(info.get("foot_centred")),
                     "palette": {k: list(PAL[k]) for keys in info["keys"].values() for k in keys},
                     "keys": info["keys"], "meshes": {}}
            objs = {}
            for fam, g in geos.items():
                g.verts = [(x - pivot.x, y - pivot.y, z - pivot.z) for x, y, z in g.verts]
                obj = to_object(g, f"{name}_{fam}")
                objs[fam] = obj
                entry["meshes"][fam] = {"triangles": g.triangles(), **export(obj)}
                print(f"[bank_kit] {obj.name}: {g.triangles()} triangles")
            kit[name] = {"objs": objs, "lo": lo - pivot, "hi": hi - pivot, "bury": -blo.z}
            result[name] = entry
        return result

    # ------------------------------------------------------------------ preview
    def setup_cycles(w, h, exposure=-0.45):
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
        if not (folder / f"{slug}_neutral.png").exists():   # no maps at all: the colour times 0.8
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
        """A plain 6 stud figure for scale."""
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

    def lineup(names, path, w, h, gap, view=(-22, 9), ground_rgb=(150, 150, 146), ground=True):
        """The models in a row with the figure at the right, through a level camera."""
        cam, _sun = setup_cycles(w, h)
        x = 0.0
        spots = []
        pts = []
        for name in names:
            item = kit[name]
            lo, hi = item["lo"], item["hi"]
            x -= lo.x
            instance(name, (x, 0, 0))
            spots.append((name, Vector((x + (lo.x + hi.x) / 2, 0, 0))))
            for cx in (lo.x, hi.x):
                for cy in (lo.y, hi.y):
                    for cz in (item["bury"], hi.z):   # from the ground line up
                        pts.append(Vector((x + cx, cy, cz - item["bury"])))
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

    # ---- the bank: a stretch of shore dressed with the kit, the way the game would
    def shore_y(x):
        return 2.6 * math.sin(x * 0.07 + 0.5) + 1.3 * math.sin(x * 0.19 + 2.0) + 0.5 * math.sin(x * 0.43)

    def ground_h(x, y):
        d = y - shore_y(x)
        if d < 0:
            return max(-3.2, d * 0.3)
        return 1.5 * (1 - math.exp(-d / 4.5)) + 0.03 * d + 0.25 * noise.noise(Vector((x * 0.09, y * 0.09, 0))) * clamp(d / 4)

    def bank_terrain():
        bm = bmesh.new()
        x0, x1, y0, y1, step = -90, 90, -70, 80, 1.0
        nx, ny = int((x1 - x0) / step) + 1, int((y1 - y0) / step) + 1
        grid = [[bm.verts.new((x0 + i * step, y0 + j * step, ground_h(x0 + i * step, y0 + j * step))) for i in range(nx)] for j in range(ny)]
        for j in range(ny - 1):
            for i in range(nx - 1):
                f = bm.faces.new([grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]])
                f.smooth = True
        me = bpy.data.meshes.new("Bank")
        bm.to_mesh(me)
        bm.free()
        attr = me.color_attributes.new(name="Col", type="BYTE_COLOR", domain="POINT")
        bed, wet, sand, meadow, floor = (64, 58, 44), (82, 71, 54), (146, 132, 104), (104, 122, 62), (92, 72, 48)
        for v in me.vertices:
            x, y = v.co.x, v.co.y
            d = y - shore_y(x) + 0.5 * noise.noise(Vector((x * 0.3, y * 0.3, 3.0)))
            if d < -0.4:
                c = mix(wet, bed, (-0.4 - d) / 2)
            elif d < 1.1:
                c = wet                                   # the dark wet band at the water's edge
            elif d < 2.6:
                c = mix(wet, sand, (d - 1.1) / 0.6)
            elif d < 4.2:
                c = mix(sand, meadow, (d - 2.6) / 1.6)
            else:
                t = clamp((d - 9) / 7 + 0.5 * noise.noise(Vector((x * 0.06, y * 0.06, 7.0))))
                c = mix(meadow, floor, t)                  # forest floor under the trees
            attr.data[v.index].color = tuple(srgb_to_linear(k) for k in c) + (1.0,)
        m = bpy.data.materials.new("BankGround")
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.85
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = 1.6
        tex.inputs["Detail"].default_value = 6
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.35
        nt.links.new(tex.outputs[0], bump.inputs["Height"])
        nt.links.new(bump.outputs[0], bsdf.inputs["Normal"])
        me.materials.append(m)
        obj = bpy.data.objects.new("Bank", me)
        obj["_stage"] = True
        scene_of().collection.objects.link(obj)
        # water: the home lake's 26,66,62, glossy, a little see-through over the shallows
        bpy.ops.mesh.primitive_plane_add(size=1, location=(0, -180, 0))
        wobj = bpy.context.object
        wobj.scale = (800, 400, 1)
        wobj["_stage"] = True
        wm = bpy.data.materials.new("Water")
        wm.use_nodes = True
        nt = wm.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = tuple(srgb_to_linear(c) for c in (26, 66, 62)) + (1.0,)
        bsdf.inputs["Roughness"].default_value = 0.06
        bsdf.inputs["Alpha"].default_value = 0.72
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = 0.6
        tex.inputs["Detail"].default_value = 2
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.04
        nt.links.new(tex.outputs[0], bump.inputs["Height"])
        nt.links.new(bump.outputs[0], bsdf.inputs["Normal"])
        wobj.data.materials.append(wm)

    def dress_bank(eye):
        rng = random.Random(4242)

        def near_eye(x, y, r):
            return (x - eye[0]) ** 2 + (y - eye[1]) ** 2 < r * r

        def on_shore(x, d):
            y = shore_y(x) + d
            return x, y, max(ground_h(x, y), 0.0)

        placed = []   # trunks: (x, y, clear radius)

        def free(x, y, r):
            return all((x - px) ** 2 + (y - py) ** 2 > (r + pr) ** 2 for px, py, pr in placed)

        # The treeline: dense, uneven, two rows deep in places, never on a grid.
        tries = 0
        while tries < 520:
            tries += 1
            x = rng.uniform(-84, 84)
            d = 8.5 + 31 * rng.random() ** 1.3
            dens = 0.55 + 0.45 * noise.noise(Vector((x * 0.045, d * 0.05, 1.7)))
            if rng.random() > dens + (0.25 if d > 16 else 0.0):
                continue
            px, py, pz = on_shore(x, d)
            if not free(px, py, 2.4) or near_eye(px, py, 9):
                continue
            spire = rng.random() < (0.72 if d > 14 else 0.4)
            instance("ShorePine1" if spire else "ShorePine2", (px, py, pz), rng.uniform(0, 6.28), rng.uniform(0.78, 1.18) * (1.0 if d < 22 else 1.1))
            placed.append((px, py, 2.4))
        # Undergrowth at their feet and out toward the water, in loose groups.
        for _ in range(26):
            x = rng.uniform(-70, 70)
            d = rng.uniform(4.5, 15)
            for k in range(rng.choice((1, 1, 2, 3))):
                px, py, pz = on_shore(x + rng.uniform(-3, 3) * k, d + rng.uniform(-2, 2) * k)
                if near_eye(px, py, 5):
                    continue
                instance(rng.choice(("Bush1", "Bush2")), (px, py, pz), rng.uniform(0, 6.28), rng.uniform(0.75, 1.2))
        for _ in range(34):
            x = rng.uniform(-70, 70)
            d = rng.uniform(3.2, 18)
            for k in range(rng.choice((1, 2, 2, 3, 4))):
                px, py, pz = on_shore(x + rng.uniform(-2, 2) * k, d + rng.uniform(-1.6, 1.6) * k)
                instance(rng.choice(("Fern1", "Fern2")), (px, py, pz), rng.uniform(0, 6.28), rng.uniform(0.8, 1.25))
        # Birches lean out over the water (the model leans toward +X; the water is toward -Y).
        for name, x, d, turn, s in (("BirchLean1", 5.0, 1.7, 0.15, 1.0), ("BirchLean2", -27.0, 2.2, -0.3, 1.05),
                                    ("BirchLean1", 31.0, 2.6, -0.5, 0.92), ("BirchLean2", 49.0, 1.9, 0.4, 1.0)):
            px, py, pz = on_shore(x, d)
            instance(name, (px, py, pz), -math.pi / 2 + turn, s)
        # Reeds stand in the shallows in three uneven stands.
        for x, d in ((-11.5, -3.6), (-9.4, -2.5)):
            instance("ReedClump1", (x, shore_y(x) + d, 0.0), rng.uniform(0, 6.28), 1.0)
        for cx, n, spread in ((16.0, 5, 3.0), (37.0, 7, 4.5), (-41.0, 4, 3.0), (-29.0, 3, 2.0)):
            for k in range(n):
                x = cx + rng.uniform(-spread, spread)
                d = rng.uniform(-4.2, -0.6)
                instance(rng.choice(("ReedClump1", "ReedClump1", "ReedClump2")), (x, shore_y(x) + d, 0.0), rng.uniform(0, 6.28), rng.uniform(0.85, 1.12))
        # Stones sit in the wet band, some alone, some in pairs.
        for x, d in ((-15.5, 0.1), (-12.6, -0.5), (0.6, 0.3), (8.2, -0.2), (10.4, 0.5), (11.9, -0.7), (21.5, 0.0), (27.5, 0.4),
                     (-24.0, -0.3), (-33.5, 0.3), (-35.0, -0.6), (44.0, 0.1)):
            instance(rng.choice(("ShoreStones1", "ShoreStones2")), (x, shore_y(x) + d, 0.0), rng.uniform(0, 6.28), rng.uniform(0.8, 1.3))
        # Driftwood: a branch half in the water, a stump on the bank, a log on the sand.
        x, y, z = on_shore(-4.5, -0.3)
        instance("DriftwoodBranch", (x, y, 0.0), 0.5)
        x, y, z = on_shore(17.5, 2.4)
        instance("DriftwoodStump", (x, y, z), 1.1)
        x, y, z = on_shore(-20.5, 1.2)
        instance("DriftwoodLog", (x, y, z), 0.25)
        x, y, z = on_shore(39.0, 1.0)
        instance("DriftwoodBranch", (x, y, z), 2.6, 0.9)
        x, y, z = on_shore(9.5, 4.2)
        figure((x, y, z), yaw=2.6)

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

    # ------------------------------------------------------------------ run
    for d in (MODELS, ROBLOX, PREVIEWS, SCRATCH):
        d.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene_of().unit_settings.system = "NONE"
    result = {"lift": LIFT, "uv_studs": 1.0, "maps": maps, "models": build_kit(), "lineups": {}}
    (SCRATCH / "result.json").write_text(json.dumps(result, indent=1), encoding="utf-8")
    if args.no_render:
        return

    rows = {
        "trees": (["ShorePine1", "ShorePine2", "BirchLean1", "BirchLean2"], 2400, 1150, 3.0),
        "growth": (["Bush1", "Bush2", "Fern1", "Fern2", "ReedClump1", "ReedClump2"], 2400, 760, 1.6),
        "shore": (["DriftwoodBranch", "DriftwoodStump", "DriftwoodLog", "ShoreStones1", "ShoreStones2"], 2400, 760, 1.6),
    }
    if args.check_faces:
        dress_kit(face_check_material)
        for key, (names, w, h, gap) in rows.items():
            lineup(names, SCRATCH / f"faces-{key}-front.png", w // 2, h // 2, gap)
            lineup(names, SCRATCH / f"faces-{key}-back.png", w // 2, h // 2, gap, view=(150, 40))
            lineup(names, SCRATCH / f"faces-{key}-under.png", w // 2, h // 2, gap, view=(-40, -30), ground=False)
        return
    dress_kit()
    for key, (names, w, h, gap) in rows.items():
        result["lineups"][key] = {"labels": lineup(names, PREVIEWS / f"bank_kit-lineup-{key}.png", w, h, gap), "w": w, "h": h}
    (SCRATCH / "result.json").write_text(json.dumps(result, indent=1), encoding="utf-8")

    setup_cycles(1600, 900)
    bank_terrain()
    ex, ey = -18.0, shore_y(-18.0) + 2.2
    ez = ground_h(ex, ey) + 5.5
    dress_bank((ex, ey))
    shoot(PREVIEWS / "bank_kit-bank-along.png", (ex, ey, ez), (6.0, shore_y(6.0) + 0.5, 4.6))
    shoot(PREVIEWS / "bank_kit-bank-water.png", (4.0, -30.0, 4.5), (6.0, 6.0, 6.0))
    shoot(SCRATCH / "bank-close.png", (3.0, shore_y(3.0) - 9.0, 3.5), (6.0, shore_y(6.0) + 2.0, 3.0), w=1280, h=720)
    shoot(SCRATCH / "bank-far.png", (10.0, -75.0, 6.0), (10.0, 10.0, 8.0), w=1280, h=720)


# =======================================================================================
# Driver half (plain Python, numpy and Pillow)
# =======================================================================================

def make_standins(maps):
    """Neutral, normal and roughness maps for a family whose real maps are not in art/textures/
    yet. Tileable, mean 0.80, quiet. Written to artifacts/bank_kit/standin/ only."""
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
        if fam == "bark":   # ridges that run along V
            for _ in range(48):
                fx, fy = rs.randint(3, 20), rs.randint(0, 3)
                h += np.cos(2 * np.pi * (fx * xx + fy * yy) + rs.uniform(0, 6.28)) / fx ** 0.6
            h = np.sign(h) * np.abs(h) ** 0.8
        else:                # soft clumps
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


def check_glb(path: Path, want_studs, boxed: bool):
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
    if abs(pos["min"][1]) > 0.002 or abs(pos["min"][0] + pos["max"][0]) > 0.002 or abs(pos["min"][2] + pos["max"][2]) > 0.002:
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
    maps = family_maps()
    if not args.compose_only:
        SCRATCH.mkdir(parents=True, exist_ok=True)
        if not (args.no_render or args.check_faces):
            make_standins(maps)
        subprocess.run([BLENDER, "-b", "--factory-startup", "-P", str(Path(__file__).resolve()), "--", *sys.argv[1:]], check=True)
    result = json.loads((SCRATCH / "result.json").read_text(encoding="utf-8"))
    maps = result["maps"]

    # Check what was written, then record it. Only this script's own entries are touched.
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    for key in [k for k in manifest if k.rsplit("_", 1)[0] in KIT and k.rsplit("_", 1)[-1] in FAMILIES]:
        del manifest[key]
    total = 0
    over = []
    for name, entry in result["models"].items():
        model_tris = sum(m["triangles"] for m in entry["meshes"].values())
        total += model_tris
        if model_tris > 1500:
            over.append(f"{name}: {model_tris} triangles is over the 1,500 budget")
        for fam, mesh in entry["meshes"].items():
            # A foot-centred tree: every mesh has the whole tree's box. Others: one mesh, its own box.
            for sub in ("glb", "roblox_glb"):
                size, tris = check_glb(REPO / mesh[sub], entry["studs"], entry["anchors"])
            if tris != mesh["triangles"]:
                raise SystemExit(f"{name}_{fam}: {tris} triangles in the file, {mesh['triangles']} in Blender")
            info = maps[fam]
            where = KIT[name]["where"]
            centre = (" The box is centred on the foot of the trunk and both meshes share it (two corner specks), so both go at "
                      "the same CFrame." if entry["foot_centred"] else "")
            manifest[f"{name}_{fam}"] = {
                "name": f"{name}_{fam}",
                "studs": size,
                "triangles": tris,
                "parts": 1,
                "replaces": KIT[name]["replaces"],
                "notes": (f"Bank kit, Layer B, {fam} family: MaterialVariant {WANTED[fam]} with its NEUTRAL colour map, normal and "
                          f"roughness. Vertex colours stored {result['lift']:g} times the colour wanted. UVs at 1 stud per UV unit. "
                          f"Upload art/models/roblox/{name}_{fam}.glb. Pivot at the bottom centre; the ground line is {entry['bury']:g} "
                          f"studs above it, so place the pivot at ground (or water) height minus {entry['bury']:g}. It stands "
                          f"{entry['height']:.1f} studs above the ground line.{centre} {where}"),
                "model": name,
                "family": fam,
                "variant": WANTED[fam],
                "uv_studs": 1.0,
                "lift": result["lift"],
                "bury": entry["bury"],
                "height_above_ground": entry["height"],
                "true_studs": entry["true_studs"],
                "model_triangles": model_tris,
                "palette_seen_rgb": {k: entry["palette"][k] for k in entry["keys"][fam]},
            }
            print(f"{name}_{fam}: {size} studs, {tris} triangles")
    if over and not os.environ.get("BANK_KIT_WIP"):
        raise SystemExit("\n".join(over))
    MANIFEST.write_text(json.dumps(dict(sorted(manifest.items())), indent=2) + "\n", encoding="utf-8")
    print(f"bank kit: {len(result['models'])} models, {sum(len(e['meshes']) for e in result['models'].values())} meshes, {total} triangles")
    if args.no_render or args.check_faces:
        return

    # ---- the sheet
    def font(size, bold=False):
        for f in (("segoeuib.ttf",) if bold else ()) + ("segoeui.ttf", "arial.ttf"):
            try:
                return ImageFont.truetype(f, size)
            except OSError:
                continue
        return ImageFont.load_default()

    pad, head = 16, 34
    W = 2400 + 2 * pad
    rows = [("trees", "The treeline and the birches"), ("growth", "Undergrowth and reeds"), ("shore", "Driftwood and waterline stones")]
    bank_w = (W - 3 * pad) // 2
    bank_h = int(bank_w * 9 / 16)
    sw_h = 250
    H = 78 + sum(result["lineups"][k]["h"] + head + 44 + pad for k, _ in rows) + 2 * (head + bank_h + pad) + head + sw_h + pad
    sheet = Image.new("RGB", (W, H), (24, 24, 27))
    draw = ImageDraw.Draw(sheet)
    draw.text((pad, 12), "Home lake bank kit, one mesh per material family (11/27/2026)", font=font(30, True), fill=(240, 240, 240))
    stand = [f"{WANTED[f]}" for f in FAMILIES if maps[f]["standin"]]
    note = "Rendered as the game shows them: vertex colour times each family's neutral map, 1 UV unit = 1 stud."
    if stand:
        note += f"  STAND-IN maps for {', '.join(stand)} (the real ones were not in art/textures yet)."
    draw.text((pad, 50), note, font=font(16), fill=(170, 170, 175))
    y = 78
    for key, title in rows:
        info = result["lineups"][key]
        draw.text((pad, y + 6), title, font=font(18, True), fill=(220, 220, 224))
        y += head
        sheet.paste(Image.open(PREVIEWS / f"bank_kit-lineup-{key}.png").convert("RGB"), (pad, y))
        for lab in info["labels"]:
            name = lab["name"]
            x = pad + int(lab["x"] * info["w"])
            entry = result["models"].get(name)
            line2 = ""
            if entry:
                tri = " + ".join(f"{fam} {m['triangles']}" for fam, m in entry["meshes"].items())
                line2 = f"{tri} tris, {entry['height']:.1f} tall"
            for i, text in enumerate((name, line2)):
                if not text:
                    continue
                f = font(16, True) if i == 0 else font(14)
                tw = draw.textlength(text, font=f)
                draw.text((min(max(pad, x - tw / 2), W - pad - tw), y + info["h"] + 4 + i * 20), text, font=f,
                          fill=(232, 232, 236) if i == 0 else (165, 165, 172))
        y += info["h"] + 44 + pad
    for pair in (
        (("In the game's camera (70 degrees, eye 5.5 studs up): along the bank", PREVIEWS / "bank_kit-bank-along.png"),
         ("From a boat 30 studs out: the treeline with its undergrowth", PREVIEWS / "bank_kit-bank-water.png")),
        (("Close on the waterline", SCRATCH / "bank-close.png"),
         ("From 75 studs out", SCRATCH / "bank-far.png")),
    ):
        for i, (label, path) in enumerate(pair):
            x = pad + i * (bank_w + pad)
            draw.text((x, y + 6), label, font=font(17), fill=(210, 210, 214))
            sheet.paste(Image.open(path).convert("RGB").resize((bank_w, bank_h), Image.LANCZOS), (x, y + head))
        y += head + bank_h + pad
    draw.text((pad, y + 6), "Colours as seen in the game (the stored vertex colour is this times the lift)", font=font(17), fill=(210, 210, 214))
    y += head
    groups = [("Driftwood", ("drift_light", "drift_dark", "drift_crack")), ("Birch", ("birch_white", "birch_mark", "birch_foot", "birch_leaf", "birch_leaf_deep")),
              ("Shore pine", ("pine_bark", "pine_bark_high", "pine_needle_sun", "pine_needle", "pine_needle_deep")),
              ("Fern and bush", ("fern", "fern_tip", "bush", "bush_sun")), ("Reeds", ("reed", "reed_tip", "rush", "cattail_head")),
              ("Stones", ("stone", "stone_light", "stone_brown", "stone_wet"))]
    sx = pad
    sw = (W - 2 * pad) // sum(len(k) for _, k in groups) - 6
    for title, keys in groups:
        draw.text((sx, y), title, font=font(16, True), fill=(230, 230, 232))
        for key in keys:
            rgb = PAL[key]
            draw.rectangle((sx, y + 28, sx + sw - 8, y + 88), fill=rgb)
            draw.text((sx, y + 92), key.split("_", 1)[-1] if "_" in key else key, font=font(13), fill=(190, 190, 195))
            draw.text((sx, y + 109), "%d, %d, %d" % rgb, font=font(13), fill=(150, 150, 156))
            sx += sw
        sx += 6
    tris = sum(m["triangles"] for e in result["models"].values() for m in e["meshes"].values())
    big = max(result["models"].items(), key=lambda kv: sum(m["triangles"] for m in kv[1]["meshes"].values()))
    draw.text((pad, y + 140), f"{len(result['models'])} models, {sum(len(e['meshes']) for e in result['models'].values())} meshes, "
              f"{tris} triangles in all; the biggest is {big[0]} at {sum(m['triangles'] for m in big[1]['meshes'].values())}.",
              font=font(16), fill=(200, 200, 205))
    out = PREVIEWS / "bank_kit.png"

    def small(im):   # 256 colours, as common.py does, so the previews stay small in git
        return im.convert("RGB").quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)

    small(sheet).save(out, optimize=True)
    for path in [PREVIEWS / f"bank_kit-lineup-{k}.png" for k, _ in rows] + [PREVIEWS / "bank_kit-bank-along.png", PREVIEWS / "bank_kit-bank-water.png"]:
        small(Image.open(path)).save(path, optimize=True)
    print(f"sheet: {out}")


if __name__ == "__main__":
    if IN_BLENDER:
        blender_main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    else:
        driver_main()
