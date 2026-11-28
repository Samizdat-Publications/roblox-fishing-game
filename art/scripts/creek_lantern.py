"""The Cedar Creek lantern post (leg 3, N3; Neon's creek review of 11/28/2026, Part B, rank 2).
Layer B of the look kit: three meshes, each keeps its vertex colours for hue and wears one of
our MaterialVariants, so nothing here carries a texture of its own.

    CreekLanternPost_bark    the hewn post, the arm, the knee brace, the peg and the mossy
                             stone collar                                    CedarBark (or WeatheredPlank)
    CreekLanternPost_metal   the strap and link, the pitched roof, the cage, the base    Aluminium
    CreekLanternPost_glass   the recessed core the game lights (part colour 255,190,120)  Glass, Neon while lit

The arm reaches along Blender -Y, which is Roblox -Z (built like the boathouse: Roblox (x, y, z)
is Blender (-x, z, y)). The pivot is the foot of the post, at the ground line. The bark and
metal meshes share one box, even about that pivot, through two specks at opposite corners, so
both drop in at the same CFrame. The glass has NO specks: its box is the core itself, so the
PointLight the game parents to it (ClientModules/Lanterns lights `light.Parent`) burns in the
middle of the cage. Its centre from the pivot is in the manifest (`placing.glass_core`).

Rules this rests on (stands_split.py and boathouse.py, proven in Studio 11/27/2026):
  * a variant's neutral colour map MULTIPLIES the vertex colour and has a mean of 0.80, so the
    bark and metal colours are stored 1.25 times lighter than the colour wanted;
  * a variant's maps follow the mesh UVs, one tile every StudsPerTile UV units; here 1 UV unit
    is 1 stud. Timber faces sit inside one board of the plank map, so no groove runs up the
    post whichever of the two wood families it wears. The stones' UVs are shrunk and turned, so
    the wood grain on them is magnified into soft bands that read as stone, not as boards.

    python art/scripts/creek_lantern.py                 build, export, render, sheet
    python art/scripts/creek_lantern.py --no-render     models and manifest only
    python art/scripts/creek_lantern.py --views day,night
    python art/scripts/creek_lantern.py --wear weathered_plank   previews under the other wood family
    python art/scripts/creek_lantern.py --tag before    renders go to artifacts/creek_lantern/before/
    python art/scripts/creek_lantern.py --compose-only  rebuild the sheet from the renders made
    blender -b -P art/scripts/creek_lantern.py -- --no-render    (the Blender half on its own)

Writes art/models/<Mesh>.glb (linear colours), art/models/roblox/<Mesh>.glb (display colours,
the copy to upload), the previews in art/previews/ and its own entries in
art/models/manifest.json. Scratch goes to artifacts/creek_lantern/ (git-ignored).
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
SCRATCH = REPO / "artifacts" / "creek_lantern"
MANIFEST = MODELS / "manifest.json"
SHOTS = REPO / "artifacts" / "shots" / "2026-11-28-0154"  # the game as it is: the flat pane on a stick
BLENDER = os.environ.get("BLENDER", r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe")

try:
    import bpy  # noqa: F401

    IN_BLENDER = True
except ModuleNotFoundError:
    IN_BLENDER = False

NAME = "CreekLanternPost"
# family -> how the game dresses it.
FAMILIES = {
    "bark": {"slug": "cedar_bark", "variant": "CedarBark", "lift": 1.25, "anchors": True},
    "metal": {"slug": "aluminium", "variant": "Aluminium", "lift": 1.25, "anchors": True},
    "glass": {"slug": None, "variant": None, "lift": 1.0, "anchors": False},
}
WEARS = {"cedar_bark": "CedarBark", "weathered_plank": "WeatheredPlank", "bark": "Bark"}
BUDGET = 400          # the brief says about 360
BOARD = 8.0 / 5       # one board of weathered_plank, studs: timber faces sit inside one
ANCHOR = 0.02         # side of the corner specks, studs

# The box the brief gives (studs): 1.4 wide, 7.5 tall, 2.4 deep, the arm 1.7 forward of the
# post's centre and the collar 0.7 behind it. The shared box is even about the pivot.
HALF_W, TALL, FRONT, BACK = 0.70, 7.5, 1.70, 0.70

# ---------------------------------------------------------------------------------------
# Palette: the colours we want to SEE in the game (sRGB 0..255), before the lift.
# Cedar Creek: shaded woodland, old cedar timber gone silver-brown, damp and green at the foot.
# ---------------------------------------------------------------------------------------
PAL = {
    "post": (114, 94, 76),
    "post_top": (134, 116, 98),     # the top third, where the weather silvers it
    "post_foot": (74, 66, 54),      # damp wood at the ground
    "post_moss": (76, 92, 54),      # green creeping up the shaded side of the foot
    "arm": (122, 100, 80),
    "arm_end": (92, 76, 62),        # end grain, darker
    "brace": (104, 86, 70),
    "peg": (150, 124, 92),          # a newer oak peg
    "stone_a": (118, 114, 106),
    "stone_b": (98, 100, 100),
    "stone_c": (132, 124, 112),
    "stone_wet": (72, 72, 70),      # the stones' damp skirts
    "moss": (78, 104, 52),          # MossProp's own green
    "moss_dark": (58, 82, 44),
    "iron": (42, 44, 48),           # the brief's dark iron
    "iron_roof": (54, 53, 54),      # the roof plates, a little chalkier
    "iron_rust": (72, 56, 46),      # along the eave, where the rain runs off
    "iron_in": (30, 31, 34),        # faces that look inward or down
    "glass": (255, 255, 255),       # white: the part's own colour (255,190,120) shows through
}
LANTERN = (255, 190, 120)       # WorldBuilder.LANTERN.color
LANTERN_POOL = (255, 186, 108)  # WorldBuilder.LANTERN.pool.color

# The post (Blender: x width, y depth with the arm toward -y, z up).
POST_RINGS = ((0.0, 0.36), (1.0, 0.33), (3.0, 0.305), (5.2, 0.265), (7.32, 0.225))  # height, half width
POST_PEAK = 7.5
ARM_Z0, ARM_Z1 = 6.78, 7.14       # the arm's underside and top
ARM_TIP, ARM_TAIL = -1.62, 0.50   # it runs through the post and shows a stub behind
BRACE_A, BRACE_B = (-0.08, 5.53), (-0.86, 6.86)  # (y, z) of the knee brace's two ends
LY = -1.20                        # the lantern hangs here, under the arm
ROOF_Z, ROOF_HALF = 6.10, 0.50    # underside of the roof plates and their half width
ROOF_RISE = 0.36                  # the plates rise this far to the vent cap
CAGE_Z0, CAGE_Z1 = 5.17, 6.01     # the cage, between the base plate and the rim
CAGE_H0, CAGE_H1 = 0.31, 0.42     # its half width at the bottom and the top: it tapers down
CORE_H0, CORE_H1 = 0.20, 0.30     # the glass core, recessed 0.11 behind the cage's faces
CORE_Z0, CORE_Z1 = CAGE_Z0 - 0.02, CAGE_Z1 + 0.02


def parse_args(argv):
    ap = argparse.ArgumentParser(description="Build the Cedar Creek lantern post (Layer B).")
    ap.add_argument("--no-render", action="store_true", help="build and export only")
    ap.add_argument("--compose-only", action="store_true", help="rebuild the sheet from the renders already made")
    ap.add_argument("--views", default="", help="only these renders (hero, day, night, ingame, ingame_night, back, wear; backface is a check)")
    ap.add_argument("--tag", default="final", help="scratch subfolder for the renders; only 'final' reaches art/previews")
    ap.add_argument("--wear", default="cedar_bark", choices=sorted(WEARS), help="the wood family the previews dress the bark mesh in")
    ap.add_argument("--samples", type=int, default=int(os.environ.get("ART_SAMPLES", "96")))
    return ap.parse_args(argv)


def family_tiles():
    table = json.loads((HERE / "texture_families.json").read_text(encoding="utf-8"))["families"]
    return {slug: float(f["studs_per_tile"]) for slug, f in table.items()}


def to_roblox(p):
    return [round(-p[0], 3) + 0.0, round(p[2], 3) + 0.0, round(p[1], 3) + 0.0]  # + 0.0: no minus zero


# =======================================================================================
# Blender half
# =======================================================================================

def blender_main(argv):
    import bmesh
    import bpy
    from mathutils import Vector

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

    def mix(a, b, t):
        t = min(1.0, max(0.0, t))
        return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

    # ------------------------------------------------------------------ parts
    class Part:
        """One solid: its mesh, the family it joins, its grain, and how it is coloured.
        `color(co, normal, face)` gives the colour to SEE at a corner (sRGB 0..255)."""

        def __init__(self, obj, family, grain, color, groups=None, mag=1.0, jitter=0.04):
            self.obj, self.family, self.grain, self.color = obj, family, grain.normalized(), color
            self.groups, self.mag, self.jitter = groups, mag, jitter

    parts: list = []
    rng = random.Random(NAME)

    def newell(ring):
        n = Vector((0, 0, 0))
        for i, a in enumerate(ring):
            b = ring[(i + 1) % len(ring)]
            n += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
        return n

    def loft(name, family, rings, grain, color, cap0=False, cap1=False, apex0=None, apex1=None, **kw):
        """Skin a stack of rings (each the same number of points). Faces point outward whichever
        way the rings were wound. Side faces come first, ring by ring, then the ends."""
        rings = [[Vector(p) for p in r] for r in rings]
        n = len(rings[0])
        mid = lambda r: sum(r, Vector((0, 0, 0))) / len(r)  # noqa: E731
        end = Vector(apex1) if apex1 is not None else mid(rings[-1])
        start = Vector(apex0) if apex0 is not None and len(rings) == 1 else mid(rings[0])
        if newell(rings[0]).dot(end - start) < 0:
            rings = [r[::-1] for r in rings]
        bm = bmesh.new()
        vs = [[bm.verts.new(p) for p in r] for r in rings]
        for k in range(len(rings) - 1):
            for i in range(n):
                bm.faces.new([vs[k][i], vs[k][(i + 1) % n], vs[k + 1][(i + 1) % n], vs[k + 1][i]])
        if cap0:
            bm.faces.new(vs[0][::-1])
        if apex0 is not None:
            tip = bm.verts.new(Vector(apex0))
            for i in range(n):
                bm.faces.new([vs[0][(i + 1) % n], vs[0][i], tip])
        if cap1:
            bm.faces.new(vs[-1])
        if apex1 is not None:
            tip = bm.verts.new(Vector(apex1))
            for i in range(n):
                bm.faces.new([vs[-1][i], vs[-1][(i + 1) % n], tip])
        bm.faces.index_update()
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        obj = bpy.data.objects.new(name, me)
        scene_of().collection.objects.link(obj)
        p = Part(obj, family, grain, color, **kw)
        parts.append(p)
        return p

    def square(cx, cy, z, h):
        return [(cx - h, cy - h, z), (cx + h, cy - h, z), (cx + h, cy + h, z), (cx - h, cy + h, z)]

    def flat(key):
        return lambda co, n, f: PAL[key]

    # ------------------------------------------------------------------ the timber
    def build_post():
        """A hewn timber: square with its four edges knocked off unevenly, tapering to the
        top, each ring a little off true, and a low four-sided peak to shed the rain."""
        corners = [rng.uniform(0.07, 0.15) for _ in range(4)]
        rings = []
        for k, (z, h) in enumerate(POST_RINGS):
            ox, oy = (0.0, 0.0) if k == 0 else (rng.uniform(-0.035, 0.035), rng.uniform(-0.03, 0.03))
            c = [corners[i] * (h / POST_RINGS[0][1]) * rng.uniform(0.8, 1.2) for i in range(4)]
            pts = [(h, h - c[0]), (h - c[0], h), (-(h - c[1]), h), (-h, h - c[1]),
                   (-h, -(h - c[2])), (-(h - c[2]), -h), (h - c[3], -h), (h, -(h - c[3]))]
            a = math.radians(rng.uniform(-3.5, 3.5)) if k else 0.0
            ca, sa = math.cos(a), math.sin(a)
            rings.append([(ox + x * ca - y * sa, oy + x * sa + y * ca, z) for x, y in pts])
        top = rings[-1]
        peak = (sum(p[0] for p in top) / 8, sum(p[1] for p in top) / 8, POST_PEAK)
        shade = [rng.uniform(0.93, 1.07) for _ in range(8)]  # each hewn face catches the light its own way
        seg = len(POST_RINGS) - 1

        def color(co, n, f):
            if co.z < 1.0:
                c = mix(PAL["post_foot"], PAL["post"], co.z)
                if co.z < 0.05 and (co.y > 0.05 or co.x > 0.2):  # the shaded side greens
                    c = mix(c, PAL["post_moss"], 0.75)
            elif co.z < 3.1:
                c = PAL["post"]
            else:
                c = mix(PAL["post"], PAL["post_top"], (co.z - 3.0) / 4.3)
            k = shade[f % 8] if f < 8 * seg else 1.04
            return tuple(v * k for v in c)

        loft("post", "bark", rings, Z, color, apex1=peak, jitter=0.0,
             groups=[[k * 8 + j for k in range(seg)] for j in range(8)])

    def build_arm():
        """The arm: one timber through the post, its tip undercut, a stub showing behind."""
        prof = [(-1.44, ARM_Z0), (0.42, ARM_Z0), (ARM_TAIL, ARM_Z0 + 0.09), (ARM_TAIL, ARM_Z1 - 0.03),
                (ARM_TIP, ARM_Z1), (ARM_TIP, ARM_Z1 - 0.15)]
        hw = lambda y: 0.16 - 0.035 * min(1.0, max(0.0, -y / 1.62))  # noqa: E731  it thins toward the tip

        def color(co, n, f):
            if abs(n.y) > 0.6:
                return PAL["arm_end"]
            if n.z > 0.7:
                return mix(PAL["arm"], PAL["post_top"], 0.6)
            if n.z < -0.7:
                return mix(PAL["arm"], PAL["post_foot"], 0.45)
            return PAL["arm"]

        loft("arm", "bark", [[(-hw(y), y, z) for y, z in prof], [(hw(y), y, z) for y, z in prof]], -Y, color,
             cap0=True, cap1=True, jitter=0.03)

    def build_brace():
        a, b = Vector((0, BRACE_A[0], BRACE_A[1])), Vector((0, BRACE_B[0], BRACE_B[1]))
        d = (b - a).normalized()
        v = d.cross(X)
        ring = lambda c, hx, hv: [c - X * hx - v * hv, c + X * hx - v * hv, c + X * hx + v * hv, c - X * hx + v * hv]  # noqa: E731

        def color(co, n, f):
            return mix(PAL["brace"], PAL["post_foot"], 0.4) if n.z < -0.3 else PAL["brace"]

        loft("brace", "bark", [ring(a, 0.115, 0.12), ring(b, 0.10, 0.105)], d, color, jitter=0.03)

    def build_peg():
        """An oak peg through the post and the arm's tenon; a nub shows on each side."""
        z = (ARM_Z0 + ARM_Z1) / 2
        ring = lambda x: [(x, -0.05, z - 0.05), (x, 0.05, z - 0.05), (x, 0.05, z + 0.05), (x, -0.05, z + 0.05)]  # noqa: E731
        loft("peg", "bark", [ring(-0.33), ring(0.34)], X, flat("peg"), cap0=True, cap1=True, jitter=0.0)

    def build_collar():
        """The stone collar: six river stones packed round the foot, moss on their tops and
        creeping down the sides that face away from the path."""
        # angle round the post, how far out it reaches, half width across, height
        spots = ((10, 0.74, 0.30, 0.70), (58, 0.88, 0.27, 0.52), (104, 0.72, 0.31, 0.95), (152, 0.86, 0.26, 0.60),
                 (201, 0.74, 0.30, 0.82), (252, 0.72, 0.29, 0.50), (308, 0.88, 0.28, 0.66))
        greys = ("stone_a", "stone_b", "stone_c", "stone_b", "stone_a", "stone_c", "stone_b")
        for i, (ang, reach, half, h) in enumerate(spots):
            a = math.radians(ang + rng.uniform(-4, 4))
            out, side = Vector((math.cos(a), math.sin(a), 0)), Vector((-math.sin(a), math.cos(a), 0))
            # A five-sided footprint: two points in under the post, two blunt shoulders, one nose.
            foot = [(0.16, -half * 0.8), (rng.uniform(0.72, 0.84) * reach, -half), (reach, rng.uniform(-0.35, 0.35) * half),
                    (rng.uniform(0.74, 0.88) * reach, half), (0.16, half * 0.8)]
            cx, cy = (out * (0.48 * reach)).x, (out * (0.48 * reach)).y
            sx, sy = rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03)
            base, top = [], []
            for r, t in foot:
                q = out * (r * rng.uniform(0.94, 1.06)) + side * (t * rng.uniform(0.9, 1.1))
                x = max(-HALF_W, min(HALF_W, q.x))
                y = max(-BACK, min(BACK, q.y))
                base.append((x, y, 0.0))
                top.append((cx + sx + (x - cx) * 0.70, cy + sy + (y - cy) * 0.70, h * rng.uniform(0.84, 1.0)))
            turn = a + rng.uniform(-0.5, 0.5)
            grey = PAL[greys[i]]
            mossy = i not in (5, 6)  # the two stones toward the path stay bare
            creep = [rng.random() for _ in range(5)]

            def color(co, n, f, grey=grey, mossy=mossy, h=h, creep=creep):
                if co.z < 0.02:
                    return mix(PAL["stone_wet"], grey, 0.25)
                if not mossy:
                    return mix(grey, PAL["moss_dark"], 0.18) if n.z > 0.7 else grey
                if n.z > 0.7:
                    return PAL["moss"]
                return mix(PAL["moss_dark"], PAL["moss"], creep[f % 5]) if creep[f % 5] > 0.35 else mix(grey, PAL["moss_dark"], 0.3)

            # The grain direction is nearly level and the UVs are shrunk: wood grain, magnified
            # and laid on its side, reads as the banding of a river stone.
            lay = Vector((math.cos(turn), math.sin(turn), rng.uniform(-0.25, 0.25)))
            loft(f"stone{i}", "bark", [base, top], lay, color, cap1=True, mag=0.22, jitter=0.05)

    # ------------------------------------------------------------------ the iron
    def build_iron():
        iron = flat("iron")
        # A strap round the arm and a link down to the roof.
        hw = 0.19
        ring = lambda y: [(-hw, y, ARM_Z0 - 0.05), (hw, y, ARM_Z0 - 0.05), (hw, y, ARM_Z1 + 0.045), (-hw, y, ARM_Z1 + 0.045)]  # noqa: E731
        loft("strap", "metal", [ring(LY - 0.065), ring(LY + 0.065)], Z, iron, cap0=True, cap1=True, jitter=0.0)
        loft("link", "metal", [square(0, LY, ROOF_Z + ROOF_RISE + 0.08, 0.036), square(0, LY, ARM_Z0 - 0.02, 0.036)], Z, iron, jitter=0.0)

        # The pitched roof: four plates with a thick eave, and a small vent cap on top.
        def roof_color(co, n, f):
            if n.z < -0.5:
                return PAL["iron_in"]
            if co.z < ROOF_Z + 0.06:
                return mix(PAL["iron_roof"], PAL["iron_rust"], 0.7)
            return PAL["iron_roof"]

        loft("roof", "metal", [square(0, LY, ROOF_Z, ROOF_HALF), square(0, LY, ROOF_Z + 0.05, ROOF_HALF),
                               square(0, LY, ROOF_Z + 0.13, 0.35), square(0, LY, ROOF_Z + ROOF_RISE, 0.13)], Z, roof_color,
             cap0=True, jitter=0.0)
        loft("vent", "metal", [square(0, LY, ROOF_Z + ROOF_RISE, 0.17)], Z, roof_color, cap0=True,
             apex1=(0, LY, ROOF_Z + ROOF_RISE + 0.14), jitter=0.0)
        # The rim under the roof, a touch proud of the cage.
        loft("rim", "metal", [square(0, LY, CAGE_Z1, CAGE_H1 + 0.02), square(0, LY, ROOF_Z + 0.01, CAGE_H1 + 0.02)], Z,
             lambda co, n, f: PAL["iron_in"] if n.z < -0.5 else PAL["iron"], cap0=True, jitter=0.0)
        # Four corner mullions of angle iron, leaning in as the cage tapers.
        leg = 0.09
        for sx, sy in ((1, 1), (-1, 1), (-1, -1), (1, -1)):
            tri = lambda h, z: [(sx * h, LY + sy * h, z), (sx * (h - leg), LY + sy * h, z), (sx * h, LY + sy * (h - leg), z)]  # noqa: E731
            loft("mullion", "metal", [tri(CAGE_H0, CAGE_Z0 - 0.02), tri(CAGE_H1, CAGE_Z1 + 0.02)], Z,
                 lambda co, n, f, sx=sx, sy=sy: PAL["iron_in"] if n.x * sx + n.y * sy < 0 else PAL["iron"], jitter=0.0)
        # A guard bar across each pane, two fifths of the way up.
        zb = CAGE_Z0 + 0.38 * (CAGE_Z1 - CAGE_Z0)
        hb = CAGE_H0 + 0.38 * (CAGE_H1 - CAGE_H0)
        for ax, sg in ((0, 1), (0, -1), (1, 1), (1, -1)):
            def bar(t, ax=ax, sg=sg):
                pts = []
                for dn, dz in ((0.0, -0.028), (0.0, 0.028), (-0.04, 0.028), (-0.04, -0.028)):
                    n_off = sg * (hb - 0.006 + dn)
                    pts.append((n_off, LY + t, zb + dz) if ax == 0 else (t, LY + n_off, zb + dz))
                return pts
            run = hb - 0.045  # ends inside the angle iron
            loft("bar", "metal", [bar(-run), bar(run)], Y if ax == 0 else X, iron, jitter=0.0)
        # The base plate, drawn down to a point underneath.
        loft("base", "metal", [square(0, LY, CAGE_Z0 - 0.08, CAGE_H0 + 0.02), square(0, LY, CAGE_Z0, CAGE_H0 + 0.02)], Z,
             lambda co, n, f: PAL["iron_in"] if n.z > 0.5 else PAL["iron"], cap1=True,
             apex0=(0, LY, CAGE_Z0 - 0.24), jitter=0.0)

    def build_glass():
        loft("core", "glass", [square(0, LY, CORE_Z0, CORE_H0), square(0, LY, CORE_Z1, CORE_H1)], Z, flat("glass"),
             cap0=True, cap1=True, jitter=0.0)

    # ------------------------------------------------------------------ finishing
    def project_uv(p):
        """Each flat side is laid out at world scale, v along the grain. A timber face sits
        inside one board of the plank map; a stone's UVs are shrunk by `mag`."""
        me = p.obj.data
        layer = me.uv_layers.get("UVMap") or me.uv_layers.new(name="UVMap")
        v_off = rng.uniform(0, 8.0)
        groups = {}
        taken = set()
        for gi, faces in enumerate(p.groups or []):
            groups[("g", gi)] = [me.polygons[i] for i in faces]
            taken |= set(faces)
        for poly in me.polygons:
            if poly.index not in taken:
                n = poly.normal
                groups.setdefault((round(n.x, 2), round(n.y, 2), round(n.z, 2)), []).append(poly)
        for polys in groups.values():
            n = sum((q.normal * q.area for q in polys), Vector((0, 0, 0))).normalized()
            ref = p.grain
            if abs(n.dot(ref)) > 0.92:  # end grain
                ref = min((X, Y, Z), key=lambda ax: abs(ax.dot(n)))
            along = (ref - ref.dot(n) * n).normalized()
            across = along.cross(n)
            coords = []
            for poly in polys:
                for li in poly.loop_indices:
                    co = me.vertices[me.loops[li].vertex_index].co
                    coords.append((li, co.dot(across), co.dot(along)))
            u0, u1 = min(c[1] for c in coords), max(c[1] for c in coords)
            if p.mag == 1.0 and u1 - u0 <= BOARD * 0.9:
                u_off = (rng.randrange(5) + 0.5) * BOARD - (u0 + u1) / 2
            else:
                u_off = rng.uniform(0, 8.0)
            for li, u, v in coords:
                layer.data[li].uv = (u * p.mag + u_off, v * p.mag + v_off)

    def paint_part(p):
        me = p.obj.data
        attr = me.color_attributes.get("Col") or me.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
        lift = FAMILIES[p.family]["lift"]
        for poly in me.polygons:
            poly.use_smooth = False
            shade = 1 + rng.uniform(-p.jitter, p.jitter)
            for li in poly.loop_indices:
                co = me.vertices[me.loops[li].vertex_index].co
                rgb = p.color(co, poly.normal, poly.index)
                attr.data[li].color = tuple(srgb_to_linear(min(255.0, c * shade * lift)) for c in rgb) + (1.0,)

    def anchors(obj, lo, hi, key, lift):
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
        col = tuple(srgb_to_linear(min(255.0, c * lift)) for c in PAL[key]) + (1.0,)
        for i in idx:
            for li in me.polygons[i].loop_indices:
                me.color_attributes["Col"].data[li].color = col

    def outward(p):
        """Roblox draws one side of a face: every part's faces must point out."""
        me = p.obj.data
        mid = sum((v.co for v in me.vertices), Vector((0, 0, 0))) / len(me.vertices)
        vol = sum((poly.center - mid).dot(poly.normal) * poly.area for poly in me.polygons)
        return vol > 0

    def build(specks=True):
        """Build every part, give it UVs and colours, then join one mesh per family."""
        common.reset()
        parts.clear()
        rng.seed(NAME)
        build_post()
        build_arm()
        build_brace()
        build_peg()
        build_collar()
        build_iron()
        build_glass()
        inside_out = [p.obj.name for p in parts if not outward(p)]
        if inside_out:
            raise SystemExit(f"{NAME}: faces point inward on {inside_out}")
        for p in parts:
            project_uv(p)
            paint_part(p)
        bpy.context.view_layer.update()
        lo, hi = bounds([p.obj for p in parts])
        if abs(lo.z) > 1e-4:
            raise SystemExit(f"{NAME}: the base is at {lo.z:.4f}, not 0")
        fits = (-lo.x <= HALF_W + 1e-4 and hi.x <= HALF_W + 1e-4 and -lo.y <= FRONT + 1e-4 and hi.y <= BACK + 1e-4
                and hi.z <= TALL + 1e-4)
        if not fits:
            raise SystemExit(f"{NAME}: {tuple(round(v, 3) for v in lo)} to {tuple(round(v, 3) for v in hi)} is outside the brief's box")
        true_extent = [round(hi.x - lo.x, 2), round(hi.z - lo.z, 2), round(hi.y - lo.y, 2)]
        hy = max(FRONT, BACK)  # the shared box is even about the pivot, the foot of the post
        box_lo, box_hi = Vector((-HALF_W, -hy, 0.0)), Vector((HALF_W, hy, TALL))
        out = {}
        for fam, f in FAMILIES.items():
            members = [p for p in parts if p.family == fam]
            objs = [p.obj for p in members]
            for o in objs:
                o.data.materials.clear()
            obj = common.join(objs, f"{NAME}_{fam}") if len(objs) > 1 else objs[0]
            obj.name = obj.data.name = f"{NAME}_{fam}"
            obj.data.color_attributes.active_color = obj.data.color_attributes["Col"]
            obj.data.color_attributes.render_color_index = obj.data.color_attributes.find("Col")
            if f["anchors"] and specks:
                anchors(obj, box_lo, box_hi, "stone_wet" if fam == "bark" else "iron", f["lift"])
            obj.data.update()
            obj["parts"] = len(members)
            out[fam] = obj
        bpy.context.view_layer.update()
        glo, ghi = bounds([out["glass"]])
        core = (glo + ghi) / 2
        info = {
            "pivot": "the foot of the post at the ground line: the base centre of the bark and metal meshes' shared box",
            "box_studs": [round(2 * HALF_W, 2), TALL, round(2 * hy, 2)],
            "true_extent_studs": true_extent,
            "true_extent_note": (f"the shape itself reaches {FRONT} toward -Z (the arm and the lantern roof) and {BACK} toward +Z "
                                 f"(the stone collar); the shared box is even about the pivot, so it reads {round(2 * hy, 2)} deep"),
            "arm": "reaches along Roblox -Z; turn the model about Y to aim it at the path or the water",
            "bury": 0.1,
            "bury_note": "sink the pivot 0.1 below the ground so the stones bite in; they stand 0.45 to 0.95 tall",
            "glass_core": {
                "centre": to_roblox(core),
                "size": [round(ghi.x - glo.x, 3), round(ghi.z - glo.z, 3), round(ghi.y - glo.y, 3)],
                "note": ("the glass mesh has no corner specks, so its own box is the core: place it at pivot * CFrame.new(centre) "
                         "and parent the PointLight to it. It tapers from 0.6 square at the top to 0.4 at the bottom"),
            },
            "lantern": {
                "hangs_at": to_roblox((0, LY, ARM_Z0)),
                "roof_peak": round(ROOF_Z + ROOF_RISE + 0.14, 2),
                "underside": round(CAGE_Z0 - 0.24, 2),
                "roof_half_width": ROOF_HALF,
            },
            "post_top": POST_PEAK,
            "arm_top": ARM_Z1,
        }
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
                     sky=(0.80, 0.88, 1.0), sky_strength=0.8, exposure=-0.45, samples=None):
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
        scene.cycles.samples = samples or args.samples
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

    def flat_mat(name, rgb, rough=0.95, emit=0.0, metal=0.0):
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

    def family_material(slug, tint=None, color_map="neutral"):
        """What the game shows: vertex colour times the family's neutral map, with its normal and
        roughness maps, one tile every StudsPerTile UV units. With `tint` (a ground family on
        the stage) the colour map is used as it is, laid out by world position."""
        m = bpy.data.materials.new(f"Preview_{slug}")
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        mapping = nt.nodes.new("ShaderNodeMapping")
        s = 1.0 / tiles[slug]
        mapping.inputs["Scale"].default_value = (s, s, 1)
        if tint is None:
            uv = nt.nodes.new("ShaderNodeUVMap")
            uv.uv_map = "UVMap"
            nt.links.new(uv.outputs[0], mapping.inputs[0])
        else:
            geo = nt.nodes.new("ShaderNodeNewGeometry")
            nt.links.new(geo.outputs["Position"], mapping.inputs[0])

        def tex(kind, non_color):
            node = nt.nodes.new("ShaderNodeTexImage")
            node.image = bpy.data.images.load(str(TEXTURES / slug / f"{slug}_{kind}.png"), check_existing=True)
            if non_color:
                node.image.colorspace_settings.name = "Non-Color"
            nt.links.new(mapping.outputs[0], node.inputs[0])
            return node

        mul = nt.nodes.new("ShaderNodeMix")
        mul.data_type = "RGBA"
        mul.blend_type = "MULTIPLY"
        mul.inputs[0].default_value = 1.0
        nt.links.new(tex(color_map, False).outputs[0], mul.inputs[6])
        if tint is None:
            vc = nt.nodes.new("ShaderNodeVertexColor")
            vc.layer_name = "Col"
            nt.links.new(vc.outputs["Color"], mul.inputs[7])
        else:
            mul.inputs[7].default_value = tuple(srgb_to_linear(c) for c in tint) + (1.0,)
        nt.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
        nt.links.new(tex("rough", True).outputs[0], bsdf.inputs["Roughness"])
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        if tint is None:
            nmap.uv_map = "UVMap"
        nt.links.new(tex("normal", True).outputs[0], nmap.inputs["Color"])
        nt.links.new(nmap.outputs[0], bsdf.inputs["Normal"])
        return m

    def glass_material(lit):
        """The game's glass: the part colour 255,190,120 on Glass by day, Neon while lit."""
        m = bpy.data.materials.new("LanternGlass")
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        mul = nt.nodes.new("ShaderNodeMix")
        mul.data_type = "RGBA"
        mul.blend_type = "MULTIPLY"
        mul.inputs[0].default_value = 1.0
        mul.inputs[7].default_value = tuple(srgb_to_linear(c) for c in LANTERN) + (1.0,)
        nt.links.new(vc.outputs["Color"], mul.inputs[6])
        nt.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.12
        if lit:
            nt.links.new(mul.outputs[2], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = 1.1
        return m

    def dress(objs, lit=False, wear=None):
        for fam, obj in objs.items():
            obj.data.materials.clear()
            if fam == "glass":
                obj.data.materials.append(glass_material(lit))
            elif fam == "bark":
                obj.data.materials.append(family_material(wear or args.wear))
            else:
                obj.data.materials.append(family_material(FAMILIES[fam]["slug"]))

    def stage(obj, kind="set"):
        obj["_stage"] = kind
        return obj

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
        print(f"[creek_lantern] rendered {path}")

    def lantern_light(core, energy=650.0):
        """The game's PointLight, in the middle of the core (WorldBuilder.LANTERN.pool)."""
        light = bpy.data.objects.new("LanternLight", bpy.data.lights.new("LanternLight", "POINT"))
        light.data.energy = energy
        light.data.color = tuple(srgb_to_linear(c) for c in LANTERN_POOL)
        light.data.shadow_soft_size = 0.25
        light.location = core
        scene_of().collection.objects.link(light)
        return stage(light)

    def bank_stage(objs):
        """A stand-in for the pool's east bank: the gravel path, a mossy verge, the pool's dark
        water toward -y (where the arm points), cedar trunks behind. Stage only."""
        bury = 0.1
        for o in objs.values():
            o.location.z = -bury
        gravel = family_material("footpath_gravel", tint=(255, 255, 255), color_map="color")
        moss = family_material("moss", tint=(200, 210, 195), color_map="color")
        bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 12, 0))
        g = stage(bpy.context.object)
        g.scale = (160, 30, 1)
        g.data.materials.append(gravel)
        bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 60, 0.01))
        g = stage(bpy.context.object)
        g.scale = (260, 90, 1)
        g.data.materials.append(moss)
        bpy.ops.mesh.primitive_plane_add(size=1, location=(0, -4.2, 0.012))
        g = stage(bpy.context.object)  # the mossy lip between the path and the water
        g.scale = (160, 2.6, 1)
        g.data.materials.append(moss)
        water = bpy.data.materials.new("Pool")
        water.use_nodes = True
        nt = water.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = tuple(srgb_to_linear(c) for c in (30, 46, 40)) + (1.0,)
        bsdf.inputs["Roughness"].default_value = 0.07
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 0.5
        noise.inputs["Detail"].default_value = 3.0
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.10
        nt.links.new(noise.outputs[0], bump.inputs["Height"])
        nt.links.new(bump.outputs[0], bsdf.inputs["Normal"])
        bpy.ops.mesh.primitive_plane_add(size=1, location=(0, -55, -0.9))
        w = stage(bpy.context.object)
        w.scale = (300, 100, 1)
        w.data.materials.append(water)
        bank = flat_mat("BankFace", (62, 54, 44))
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -5.9, -0.75))
        b = stage(bpy.context.object)
        b.scale = (300, 1.0, 1.5)
        b.rotation_euler = (math.radians(-28), 0, 0)
        b.data.materials.append(bank)
        far = flat_mat("FarBank", (44, 58, 40))
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -72, 0.2))
        b = stage(bpy.context.object)
        b.scale = (300, 30, 2.6)
        b.data.materials.append(far)
        trunk = flat_mat("Trunk", (74, 50, 40))
        crown = flat_mat("Crown", (30, 50, 36))
        srng = random.Random(11)
        spots = [(srng.uniform(-70, 70), srng.uniform(16, 60)) for _ in range(34)]
        spots += [(srng.uniform(-90, 90), srng.uniform(-90, -62)) for _ in range(30)]
        for x, y in spots:
            h = srng.uniform(26, 40)
            bpy.ops.mesh.primitive_cylinder_add(vertices=9, radius=srng.uniform(0.7, 1.2), depth=h * 0.5, location=(x, y, h * 0.25))
            stage(bpy.context.object).data.materials.append(trunk)
            bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=h * 0.2, radius2=0.3, depth=h * 0.78, location=(x, y, h * 0.61))
            stage(bpy.context.object).data.materials.append(crown)
        figure = []  # a 5 stud figure on the path, for scale only; hidden unless a view asks
        skin = flat_mat("Figure", (150, 150, 152))
        for size, loc in (((1.9, 0.95, 2.0), (2.4, 2.4, 1.0)), ((2.0, 1.0, 2.0), (2.4, 2.4, 3.0)), ((1.15, 1.15, 1.1), (2.4, 2.4, 4.55))):
            bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
            o = stage(bpy.context.object)
            o.scale = size
            o.data.materials.append(skin)
            o.hide_render = True
            figure.append(o)
        return figure

    DAY = dict(sun_rot=(52, 0, 72), sun_rgb=(1.0, 0.95, 0.86), sun_energy=3.4, sky=(0.62, 0.74, 0.86), sky_strength=0.55,
               exposure=-0.2)
    NIGHT = dict(sun_rot=(48, 0, 200), sun_rgb=(0.62, 0.74, 1.0), sun_energy=0.10, sky=(0.10, 0.14, 0.30), sky_strength=0.06,
                 exposure=0.9)

    def night_setup(objs, w, h):
        cam, _ = setup_cycles(w, h, **NIGHT)
        # In the game the cage casts no shadow from its own light (CastShadow off on the metal
        # and the glass, as on the shore lamps), so the light pools on the bank.
        for fam in ("metal", "glass"):
            objs[fam].visible_shadow = False
        return cam

    # ------------------------------------------------------------------ run
    for d in (MODELS, ROBLOX, PREVIEWS, SCRATCH, out_dir):
        d.mkdir(parents=True, exist_ok=True)

    objs, info = build()
    entry = dict(info)
    entry["meshes"] = {}
    for fam, obj in objs.items():
        entry["meshes"][fam] = export(obj)
        print(f"[creek_lantern] {obj.name}: {entry['meshes'][fam]['triangles']} triangles")
    total = sum(m["triangles"] for m in entry["meshes"].values())
    if total > BUDGET:
        raise SystemExit(f"{NAME}: {total} triangles is over the {BUDGET} budget")
    entry["triangles"] = total
    (SCRATCH / "result.json").write_text(json.dumps(entry, indent=1), encoding="utf-8")
    print(f"[creek_lantern] {NAME}: {total} triangles")
    if args.no_render:
        return

    def want(v):
        return not views or v in views

    core = Vector((0, LY, (CORE_Z0 + CORE_Z1) / 2))

    if want("hero"):  # the model alone, three-quarter, as the other previews
        objs, _ = build()
        dress(objs)
        cam, _ = setup_cycles(1024, 1024, sun_rot=(51, 0, -75))
        bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=14, depth=0.01, location=(0, 0, -0.005))
        stage(bpy.context.object, "shot").data.materials.append(flat_mat("Ground", (150, 150, 146)))
        d = Vector((math.sin(math.radians(-52)) * math.cos(math.radians(16)), -math.cos(math.radians(-52)) * math.cos(math.radians(16)),
                    math.sin(math.radians(16))))
        centre = Vector((0, -0.5, 3.75))
        aim(cam, centre + d * 30, centre, ortho=8.6, clip=200)
        render(out_dir / "hero.png")

    if "backface" in views:  # a check, not a preview: any face seen from behind shows red
        objs, _ = build(specks=False)  # the specks are single triangles: red from behind by design
        m = bpy.data.materials.new("Backface")
        m.use_nodes = True
        nt = m.node_tree
        nt.nodes.clear()
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        emit = nt.nodes.new("ShaderNodeEmission")
        ramp = nt.nodes.new("ShaderNodeMix")
        ramp.data_type = "RGBA"
        ramp.inputs[6].default_value = (0.0, 0.05, 0.0, 1.0)
        ramp.inputs[7].default_value = (1.0, 0.0, 0.0, 1.0)
        nt.links.new(geo.outputs["Backfacing"], ramp.inputs[0])
        nt.links.new(ramp.outputs[2], emit.inputs[0])
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(emit.outputs[0], out.inputs[0])
        for o in objs.values():
            o.data.materials.clear()
            o.data.materials.append(m)
        black = bpy.data.materials.new("Black")
        black.use_nodes = True
        black.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0, 0, 0, 1)
        black.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
        bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0.04))
        stage(bpy.context.object).data.materials.append(black)
        i = 0
        for target, dist, elevs in ((Vector((0, -0.5, 3.75)), 16, (8, 35)), (Vector((0, LY, 5.7)), 5, (-35, 0, 40)),
                                    (Vector((0, 0, 0.4)), 4, (15, 55))):
            for el in elevs:
                for az in range(0, 360, 45):
                    cam, sun = setup_cycles(384, 384, sky=(0, 0, 0), sky_strength=0.0, sun_energy=0.0, samples=4)
                    scene_of().cycles.use_denoising = False
                    scene_of().view_settings.exposure = 0.0
                    a, e = math.radians(az), math.radians(el)
                    eye = target + Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))) * dist
                    aim(cam, eye, target, fov=34)
                    render(out_dir / "backface" / f"{i:02d}.png")
                    i += 1

    if want("day") or want("night") or want("ingame") or want("ingame_night") or want("back"):
        objs, _ = build()
        dress(objs)
        figure = bank_stage(objs)
        lit_core = core - Vector((0, 0, 0.1))
        near_eye, near_look = (8.4, -5.2, 4.4), (0.0, -0.5, 3.6)
        if want("day"):  # a player standing on the bank beside it, mid-day under the trees
            cam, _ = setup_cycles(1600, 900, **DAY)
            aim(cam, near_eye, near_look, fov=52)
            render(out_dir / "day.png")
        if want("back"):  # round the far side, to see the unseen faces honestly
            cam, _ = setup_cycles(1280, 720, **DAY)
            aim(cam, (-6.5, 6.8, 6.2), (0.0, -0.5, 4.2), fov=50)
            render(out_dir / "back.png")
        if want("ingame"):  # shot 10's framing: along the bank, 30 studs off, Roblox's 70 degree view
            cam, _ = setup_cycles(1600, 900, **DAY)
            aim(cam, (26.0, -1.0, 5.2), (0.0, -6.0, 2.6), fov=70)
            for o in figure:
                o.hide_render = False
            render(out_dir / "ingame.png")
            for o in figure:
                o.hide_render = True
        if want("night") or want("ingame_night"):
            dress(objs, lit=True)
            light = lantern_light(lit_core)
            if want("night"):
                cam = night_setup(objs, 1600, 900)
                aim(cam, near_eye, near_look, fov=52)
                render(out_dir / "night.png")
            if want("ingame_night"):  # shot 12's framing
                cam = night_setup(objs, 1600, 900)
                aim(cam, (26.0, -1.0, 5.2), (0.0, -6.0, 2.6), fov=70)
                render(out_dir / "ingame_night.png")
            _ = light

    if want("wear"):  # the same mesh under the other wood family, close on the timber and stones
        for slug in ("cedar_bark", "weathered_plank"):
            objs, _ = build()
            dress(objs, wear=slug)
            bank_stage(objs)
            cam, _ = setup_cycles(900, 900, **DAY)
            aim(cam, (5.6, -5.0, 3.6), (0.0, -0.4, 3.5), fov=64)
            render(out_dir / f"wear_{slug}.png")


# =======================================================================================
# Driver half (plain Python and Pillow)
# =======================================================================================

def read_glb(path: Path):
    data = path.read_bytes()
    json_len = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20:20 + json_len])


def check_glb(path: Path):
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
    tris = g["accessors"][prim["indices"]]["count"] // 3
    return pos["min"], pos["max"], tris


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
    entry = json.loads((SCRATCH / "result.json").read_text(encoding="utf-8"))

    # Check what was written, then record it. Only this script's own manifest entries are touched.
    box = entry["box_studs"]
    records = {}
    for fam, mesh in entry["meshes"].items():
        for sub in ("glb", "roblox_glb"):
            lo, hi, tris = check_glb(REPO / mesh[sub])
        size = [round(b - a, 2) for a, b in zip(lo, hi)]
        if tris != mesh["triangles"]:
            raise SystemExit(f"{NAME}_{fam}: {tris} triangles in the file, {mesh['triangles']} in Blender")
        f = FAMILIES[fam]
        if f["anchors"]:
            if any(abs(a - b) > 0.011 for a, b in zip(size, box)):
                raise SystemExit(f"{NAME}_{fam}: size {size}, expected {box}")
            if abs(lo[1]) > 0.002 or abs(lo[0] + hi[0]) > 0.002 or abs(lo[2] + hi[2]) > 0.002:
                raise SystemExit(f"{NAME}_{fam}: pivot is not the base centre ({lo} to {hi})")
        else:  # the glass: its own box is the core. glTF is Y up, and Roblox turns it half round Y.
            centre = [round(-(lo[0] + hi[0]) / 2, 3), round((lo[1] + hi[1]) / 2, 3), round(-(lo[2] + hi[2]) / 2, 3)]
            want = entry["glass_core"]["centre"]
            if any(abs(a - b) > 0.002 for a, b in zip(centre, want)):
                raise SystemExit(f"{NAME}_{fam}: the core's centre in the file is {centre}, the manifest says {want}")
        if fam == "bark":
            wears = ("MaterialVariant CedarBark (or WeatheredPlank: the same mesh takes either) with its NEUTRAL colour map, "
                     "normal and roughness. Vertex colours stored 1.25 times the colour wanted; part colour white")
            keys = [k for k in PAL if k.startswith(("post", "arm", "brace", "peg", "stone", "moss"))]
        elif fam == "metal":
            wears = ("MaterialVariant Aluminium with its NEUTRAL colour map. The dark iron (42, 44, 48) is in the vertex "
                     "colours, stored 1.25 times lighter, so the part colour stays white: do not tint the part as well")
            keys = [k for k in PAL if k.startswith("iron")]
        else:
            wears = ("no family: the game's lantern glass. Material Glass by day, Neon while lit (ClientModules/Lanterns), part "
                     "colour 255,190,120. Vertex colours are white so the part colour shows as it is")
            keys = ["glass"]
        where = ("Goes at the same CFrame as the other boxed mesh: pivot at the foot of the post, the arm along -Z."
                 if f["anchors"] else
                 f"Has no corner specks: its box is the core itself. Place it at pivot * CFrame.new({entry['glass_core']['centre']}) "
                 f"and parent the lantern's PointLight to it.")
        records[f"{NAME}_{fam}"] = {
            "name": f"{NAME}_{fam}",
            "studs": size,
            "triangles": tris,
            "parts": mesh["parts"],
            "replaces": "The creek's gray-box lantern posts (CreekSwap.buildLantern: the pool lantern and the gate lamp)",
            "notes": (f"Layer B, {fam}: {wears}. UVs at 1 stud per UV unit. Upload art/models/roblox/{NAME}_{fam}.glb. {where} "
                      f"The set is {entry['triangles']} triangles in all."),
            "family": fam,
            "variant": f["slug"],
            "uv_studs": 1.0,
            "lift": f["lift"],
            "set": NAME,
            "set_triangles": entry["triangles"],
            "palette_seen_rgb": {k: list(PAL[k]) for k in keys},
            "placing": {k: v for k, v in entry.items() if k not in ("meshes", "triangles")},
        }
        print(f"{NAME}_{fam}: {size} studs, {tris} triangles")
    print(f"{NAME}: {entry['triangles']} triangles (budget {BUDGET}, the brief says about 360)")
    # Read, change and write in one go: another script may be adding its own entries meanwhile.
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    for key in [k for k in manifest if k.startswith(NAME + "_")]:
        del manifest[key]
    manifest.update(records)
    MANIFEST.write_text(json.dumps(dict(sorted(manifest.items())), indent=2) + "\n", encoding="utf-8")
    if args.no_render:
        return

    bad = out_dir / "backface"
    if bad.exists() and "backface" in args.views:
        worst = 0
        for p in sorted(bad.glob("*.png")):
            raw = Image.open(p).convert("RGB").tobytes()
            red = sum(1 for i in range(0, len(raw), 3) if raw[i] > 120 and raw[i + 1] < 60)
            worst = max(worst, red)
            if red:
                print(f"backface check: {p.name} shows {red} red pixels")
        print(f"backface check: {len(list(bad.glob('*.png')))} views, worst {worst} red pixels")

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

    names = {"hero.png": f"{NAME}.png", "day.png": f"{NAME}-day.png", "night.png": f"{NAME}-night.png",
             "ingame.png": f"{NAME}-ingame.png", "ingame_night.png": f"{NAME}-ingame-night.png", "back.png": f"{NAME}-back.png"}
    if args.tag == "final":
        for src, dst in names.items():
            if (out_dir / src).exists():
                save_small(out_dir / src, PREVIEWS / dst, 1600)

    def fit(im, w, h):
        s = max(w / im.width, h / im.height)
        im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
        x, y = (im.width - w) // 2, (im.height - h) // 2
        return im.crop((x, y, x + w, y + h))

    def load(path, crop=None, whole=None):
        if not Path(path).exists():
            return None
        im = Image.open(path).convert("RGB")
        if crop:
            x0, y0, x1, y1 = crop
            im = im.crop((round(x0 * im.width), round(y0 * im.height), round(x1 * im.width), round(y1 * im.height)))
        if whole:  # keep all of a picture that is not the cell's shape: stand it on a dark card
            w, h = whole
            s = min(w / im.width, h / im.height)
            im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
            card = Image.new("RGB", (w, h), (34, 34, 38))
            card.paste(im, ((w - im.width) // 2, (h - im.height) // 2))
            return card
        return im

    def sheet(title, sub, rows, out, cell_w=800, cell_h=450):
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
            for i, (label, pic) in enumerate(row):
                x = pad + i * (cell_w + pad)
                draw.text((x, y + 6), label, font=font(17), fill=(210, 210, 214))
                if pic is not None:
                    im.paste(fit(pic, cell_w, cell_h), (x, y + head))
                else:
                    draw.rectangle((x, y + head, x + cell_w, y + head + cell_h), outline=(80, 80, 84))
                    draw.text((x + 12, y + head + 12), "not rendered", font=font(16), fill=(120, 120, 124))
            y += head + cell_h + pad
        im.save(out, optimize=True)
        print(f"sheet: {out}")

    if args.tag != "final":
        return
    tri = ", ".join(f"{fam} {m['triangles']}" for fam, m in entry["meshes"].items())
    now_crop = (0.66, 0.20, 0.96, 0.62)  # where the pool lantern stands in shots 10 and 12
    new_crop = (0.36, 0.22, 0.79, 0.70)  # the same share of the frame, so the two posts are the same size
    sheet("CreekLanternPost: the game now, and the new post",
          f"Left: the game as captured 11/28/2026 (a flat pane on a square stick). Right: the new post under the family maps, "
          f"as the game will show it. Triangles: {tri}, {entry['triangles']} in all. Bank, water and trees are a stage.",
          [[("The game now: shot 10, golden hour (crop)", load(SHOTS / "10-pool-golden.jpg", now_crop)),
            ("New, along the bank from 26 studs, day, 70 degree view (crop)", load(out_dir / "ingame.png", new_crop))],
           [("The game now: shot 12, night (crop)", load(SHOTS / "12-pool-night.jpg", now_crop)),
            ("New, the same view at night, the core lit (crop)", load(out_dir / "ingame_night.png", new_crop))],
           [("New, a player's view on the bank, day", load(out_dir / "day.png")),
            ("New, the same at night", load(out_dir / "night.png"))],
           [("New, round the back", load(out_dir / "back.png")),
            ("The model alone", load(out_dir / "hero.png", whole=(800, 450)))]],
          PREVIEWS / f"{NAME}-sheet.png")
    a, b = load(out_dir / "wear_cedar_bark.png"), load(out_dir / "wear_weathered_plank.png")
    if a is not None and b is not None:
        sheet("CreekLanternPost: one mesh, two wood families",
              "The same bark mesh and vertex colours. Left wears CedarBark, right wears WeatheredPlank.",
              [[("CedarBark", a), ("WeatheredPlank", b)]], PREVIEWS / f"{NAME}-wear.png", cell_w=700, cell_h=700)


if __name__ == "__main__":
    if IN_BLENDER:
        blender_main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    else:
        driver_main()
