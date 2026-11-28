"""Fallen logs for the home lake, the weathered set: Log1b, Log2b, Log3b.

They take the place of Log1, Log2 and Log3 over the 22 stud gray-box logs
(Workspace.Lake.Logs.Log1 to Log5). Each has exactly the box and the pivot of the log it
replaces (two corner specks pin the box), and the trunk lies where the old trunk lay, so it
swaps in at the same CFrame. The old files are not touched: uploads are permanent, and
Log1 to Log3 stay in use until the new ones are swapped in.

What changed (leg 3, N1 round 5; the review note is docs/reviews/2026-11-27-gemini-leg3-review.md):
  * no flat tan end caps. Every end is broken: a jagged rim, a hollow behind it, loose
    splinters, all in dark soaked wood;
  * one mesh per log in the bark family (Layer B): the Bark MaterialVariant's neutral map
    multiplies the vertex colours, so the vertex colours are the hue, stored 1.25 times lighter
    than the colour wanted. UVs are world scale, 1 UV unit = 1 stud, grain along the log;
  * the water is painted on. The gray boxes lie at CFrame.Angles(0, yaw, 0.12) with their
    middles 0.4 to 1.6 studs under the water, so the water line is a slanted plane on the log:
    Blender -X (Roblox +X) is the high end that shows, Blender +X is under water. The mesh is
    cut along that plane, so the soaked wood below it, the thin green algae line on it and the
    wet band above it are exact, whatever the triangles do;
  * the old floating branch stubs are broken stubs that grow out of the trunk, at the same
    places along the log; the moss blob is gone (it was a second family).

    python art/scripts/logs.py                 build, export, render, sheet (runs Blender)
    python art/scripts/logs.py --no-render     models and manifest only
    python art/scripts/logs.py --compose-only  rebuild the sheet from the renders already made
    blender -b -P art/scripts/logs.py          the Blender half on its own (no sheet)
    blender -b -P art/scripts/logs.py -- --old rebuild the first Log1 to Log3 as they were

Writes art/models/Log<n>b.glb (linear colours), art/models/roblox/Log<n>b.glb (display
colours, the copy to upload), art/previews/Log<n>b.png, Log<n>b-ends.png, logs_b-ingame.png
and the sheet logs_b.png, and the three Log<n>b entries in art/models/manifest.json. Scratch
renders go to artifacts/logs_b/.
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
SCRATCH = REPO / "artifacts" / "logs_b"
MANIFEST = MODELS / "manifest.json"
BLENDER = os.environ.get("BLENDER", r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe")

R = 1.1          # 2.2 stud diameter like the gray box
SIDES = 10       # round the trunk, as the first logs had
TILT = 0.12      # the gray-box logs: CFrame.Angles(0, yaw, 0.12), Roblox +X end up
LIFT = 1.25      # the neutral map has a mean of 0.80
TILE = 4.0       # studs per tile of the bark family (art/textures/README.md)
MAX_TRIS = 400

# The colours we want to SEE in the game (sRGB 0..255), before the lift.
PAL = {
    "bark": (110, 96, 80),        # weathered grey-brown
    "bark_top": (114, 100, 84),   # the sky side, which is most of what shows
    "bark_low": (96, 83, 68),     # the flank that looks at the water
    "stub": (100, 87, 72),
    "end": (60, 50, 40),          # broken, soaked end wood
    "end_light": (70, 59, 47),
    "end_dark": (51, 42, 34),
    "soak": (70, 64, 52),         # bark under or just above the water
    "soak_deep": (61, 56, 46),
    "algae": (72, 80, 52),        # the line the water leaves, faint
}

# Depth below the water (studs) of the three cuts: soaked | algae line | wet band | drying, then dry.
CUT_ALGAE_LO, CUT_ALGAE_HI, CUT_WET = 0.05, -0.08, -0.34
FADE = 0.5   # the wet band dries out over at most this many studs above its top

# The box of each first log in its own building coordinates (trunk along X, its axis at
# height R, the middle of the trunk at x = 0), measured from the first models' vertices on
# 11/27/2026. The new log is built in the same coordinates and pinned to the same box.
# sink: how far under the water the middle of its gray boxes is (WorldBuilder logSpots).
# rings: (x, radius, height of the axis or None for "resting on the lake bed line", lumpiness)
# jag: how far each of the ten rim points (0 = top, going round by +Y) breaks past the ring.
# splinters: where round the rim (in rim points, fractions allowed) a shard is left standing.
# sway: how far the trunk wanders from side to side, and where the wander starts
# stubs: (x, degrees round from the top, rake along the log, reach from its foot inside the trunk to
#         the tip of its sliver, radius at the trunk, radius at the break)
SPECS = {
    1: {
        "name": "Log1b", "old": "Log1", "old_asset": 89531819976790, "spots": "gray-box logs 1 and 4", "seed": 101,
        "box": ((-11.080001, -1.743261, -0.01039), (11.080001, 1.747882, 2.804044)),
        "sink": 0.5,
        "sway": (0.28, 0.4),
        "rings": [(-10.2, 0.98, None, 0.045), (-7.2, 1.01, None, 0.05), (-4.2, 1.04, None, 0.05), (-1.2, 1.07, None, 0.05),
                  (1.8, 1.09, None, 0.05), (4.8, 1.11, None, 0.05), (7.8, 1.12, None, 0.05), (10.45, 1.13, None, 0.045)],
        "end_lo": {"rich": True, "jag": [0.88, 0.70, 0.18, 0.08, 0.30, 0.12, 0.05, 0.42, 0.15, 0.55], "splinters": [2.2, 2.9, 3.6, 7.3]},
        "end_hi": {"rich": False, "jag": [0.10, 0.45, 0.20, 0.63, 0.30, 0.05, 0.50, 0.15, 0.35, 0.60], "splinters": []},
        "stubs": [(-6.58, -38, 8, 1.42, 0.27, 0.15), (-4.41, 25, -6, 1.33, 0.30, 0.16), (-0.50, -30, 12, 1.22, 0.30, 0.17)],
    },
    2: {
        "name": "Log2b", "old": "Log2", "old_asset": 99209213624189, "spots": "gray-box logs 2 and 5", "seed": 202,
        "box": ((-8.182414, -1.499669, -0.025334), (7.08, 1.794097, 2.869443)),
        "sink": 0.8,
        "sway": (0.16, 2.1),
        "rings": [(-6.9, 1.0, None, 0.045), (-4.2, 1.03, None, 0.05), (-1.4, 1.06, None, 0.05), (1.4, 1.09, None, 0.05),
                  (4.2, 1.11, None, 0.05), (6.5, 1.13, None, 0.045)],
        "end_lo": {"rich": True, "jag": [1.28, 1.02, 0.50, 0.18, 0.05, 0.12, 0.0, 0.22, 0.62, 0.95], "splinters": [2.4, 3.0, 3.7, 7.6, 8.3]},
        "end_hi": {"rich": False, "jag": [0.50, 0.12, 0.30, 0.05, 0.58, 0.25, 0.10, 0.40, 0.08, 0.22], "splinters": []},
        "stubs": [(-2.48, -35, 10, 1.45, 0.28, 0.15), (2.36, 30, -8, 1.3, 0.30, 0.17)],
    },
    3: {
        "name": "Log3b", "old": "Log3", "old_asset": 92896234828500, "spots": "gray-box log 3", "seed": 303,
        "box": ((-8.080001, -2.462966, -0.217595), (10.338266, 2.676747, 4.074234)),
        # Its own gray box (log 3) lies 1.2 studs under, which hides all of Log3 but the tip of the
        # trunk. Painted for a box 0.5 under (logs 1 and 4), so the log can be shown if it is moved.
        "sink": 0.5, "sink_here": 1.2,
        "sway": (0.2, 5.0),
        "rings": [(-7.3, 1.0, None, 0.045), (-4.0, 1.04, None, 0.05), (-0.6, 1.07, None, 0.05), (2.8, 1.10, None, 0.05),
                  (6.0, 1.14, 1.18, 0.05), (7.5, 1.42, 1.50, 0.09), (8.5, 1.80, 1.92, 0.12)],
        "end_lo": {"rich": True, "jag": [0.20, 0.55, 0.78, 0.30, 0.10, 0.05, 0.35, 0.15, 0.60, 0.10], "splinters": [3.3, 4.0, 8.8, 9.5]},
        "end_hi": {"root": True},
        "stubs": [(-3.14, 30, 8, 1.65, 0.28, 0.15), (1.27, 40, -10, 1.1, 0.28, 0.17), (4.99, -35, 6, 1.75, 0.30, 0.16)],
    },
}

# Where the game puts them (WorldBuilder.luau logSpots and the ART table): Roblox position of
# the gray box, its yaw, and which model lies over it.
SPOTS = [((70, -0.4, 55), 0.5, 1), ((90, -0.8, 40), -0.3, 2), ((62, -1.2, 28), 1.1, 3),
         ((96, -0.6, 62), 0.9, 1), ((80, -1.6, 20), -0.8, 2)]
SHOT06 = {"eye": (126, 7, 65), "look": (76, -1, 46), "size": (1280, 814)}   # tools/shots/shots.json
SHOT06_FILE = REPO / "artifacts" / "shots" / "2026-11-27-1818" / "06-logs-dawn.jpg"
SHOT06_CROP = (380, 330, 900, 525)


def parse_args(argv):
    ap = argparse.ArgumentParser(description="Build the weathered fallen logs (Log1b, Log2b, Log3b).")
    ap.add_argument("--old", action="store_true", help="rebuild the first Log1 to Log3 as they were, and stop")
    ap.add_argument("--no-render", action="store_true", help="build and export only")
    ap.add_argument("--compose-only", action="store_true", help="rebuild the sheet from the renders already made")
    ap.add_argument("--samples", type=int, default=int(os.environ.get("ART_SAMPLES", "64")))
    return ap.parse_args(argv)


# =======================================================================================
# The first logs (Log1 to Log3), kept so they can still be rebuilt: --old
# =======================================================================================

def log_body(length, seed, broken=False):
    from common import cyl, jitter, mat, sphere

    rng = random.Random(seed)
    bark = mat("bark")
    dark = mat("darkWood")
    end = mat("logEnd", (190, 150, 100))
    body = cyl(R, length, (0, 0, R), bark, rot=(0, math.pi / 2, 0), verts=10)
    jitter(body, 0.08, seed)
    # End caps with lighter wood rings.
    cyl(R * 0.85, 0.12, (length / 2 + 0.02, 0, R), end, rot=(0, math.pi / 2, 0), verts=10)
    if not broken:
        cyl(R * 0.85, 0.12, (-length / 2 - 0.02, 0, R), end, rot=(0, math.pi / 2, 0), verts=10)
    else:
        for k in range(5):  # jagged splinters at the broken end
            a = k / 5 * 2 * math.pi
            cyl(0.25, rng.uniform(0.8, 1.6), (-length / 2 - 0.4, math.cos(a) * 0.6, R + math.sin(a) * 0.6), end, rot=(0, math.pi / 2, 0), verts=4, radius2=0.02)
    # Branch stubs and a moss patch.
    for k in range(3 if length > 15 else 2):
        x = rng.uniform(-length / 2 + 2, length / 2 - 2)
        ang = rng.uniform(0.5, 1.2)
        cyl(0.3, 2.0, (x, rng.choice((-0.8, 0.8)), R + 0.9), dark, rot=(ang, 0, 0), verts=6, radius2=0.12)
    sphere(0.9, (rng.uniform(-3, 3), 0, R * 1.85), mat("moss"), scale=(2.5, 1.1, 0.25))


def build(variant):
    from common import cyl, jitter, mat, reset, sphere

    reset()
    if variant == 1:
        log_body(22, 1)
    elif variant == 2:
        log_body(14, 2, broken=True)
    else:
        log_body(16, 3)
        root = mat("bark")
        disc = sphere(2.0, (8.6, 0, 1.9), mat("rootBall", (110, 85, 60)), scale=(0.45, 1.0, 1.0), subdiv=1)
        jitter(disc, 0.2, 3)
        for k in range(7):
            a = k / 7 * 2 * math.pi
            cyl(0.22, 2.4, (9.2, math.cos(a) * 1.6, 1.9 + math.sin(a) * 1.6), root, rot=(math.cos(a) * 0.9, math.pi / 2 - 0.3, 0), verts=4, radius2=0.05)


def build_old():
    from common import finish

    for v in (1, 2, 3):
        build(v)
        finish(f"Log{v}", replaces="Workspace.Lake.Logs.Log1 to Log5 (mix the variants)",
               notes="Lies along X. The gray box sinks logs 0.4 to 1.6 studs; keep that.", view=(25, 30))


# =======================================================================================
# Blender half
# =======================================================================================

def blender_main(argv):
    import bmesh
    import bpy
    from mathutils import Matrix, Vector, noise

    sys.path.insert(0, str(HERE))
    args = parse_args(argv)
    if args.old:
        build_old()
        return
    import roblox_colors

    BARK, STUB, WOOD, SPECK = 0, 1, 2, 3
    C_ROUND = 2 * math.pi * R
    SIN, COS = math.sin(TILT), math.cos(TILT)

    def scene_of():
        return bpy.context.scene

    def srgb_to_linear(c):
        c = c / 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    def clamp(x, lo=0.0, hi=1.0):
        return lo if x < lo else hi if x > hi else x

    def mix(a, b, t):
        t = clamp(t)
        return tuple(x + (y - x) * t for x, y in zip(a, b))

    def ease(t):
        t = clamp(t)
        return t * t * (3 - 2 * t)

    def rad(a):
        """The direction `a` radians round the trunk from the top, turning toward +Y."""
        return Vector((0.0, math.sin(a), math.cos(a)))

    def box_uv(pts, n):
        ax = max(range(3), key=lambda i: abs(n[i]))
        a, b = ((1, 2), (0, 2), (0, 1))[ax]
        return [(p[a], p[b]) for p in pts]

    def u_round(k):
        """Round the trunk the UV runs out and back, so there is no seam."""
        return C_ROUND / 2 - abs(k / SIDES * C_ROUND - C_ROUND / 2)

    # ------------------------------------------------------------------ geometry
    class Build:
        def __init__(self, spec):
            self.spec = spec
            self.bm = bmesh.new()
            self.uv = self.bm.loops.layers.uv.new("UVMap")
            self.kind = self.bm.faces.layers.int.new("kind")
            self.tone = self.bm.faces.layers.float.new("tone")
            self.dirt = self.bm.faces.layers.float.new("dirt")
            # the trunk wanders a little from side to side; it rests on the lake bed line
            sway, turn = spec["sway"]
            self.stations = [(x, r, sway * math.sin(x * 0.21 + turn), (r + 0.03) if cz is None else cz)
                             for x, r, cz, _amp in spec["rings"]]

        def axis(self, x):
            """Radius of the trunk at x, and where its axis is (y, z)."""
            st = self.stations
            if x <= st[0][0]:
                return st[0][1:]
            for a, b in zip(st, st[1:]):
                if x <= b[0]:
                    t = (x - a[0]) / (b[0] - a[0])
                    return tuple(p + (q - p) * t for p, q in zip(a[1:], b[1:]))
            return st[-1][1:]

        def v(self, p):
            return self.bm.verts.new(p)

        def face(self, verts, uvs, kind, away, smooth=False, tone=0.5, dirt=0.0, toward=None):
            """A face turned to look away from the point `away` (or, with `toward`, to look at
            that point instead: Roblox draws one side only). uvs None: box-mapped."""
            verts = list(verts)
            pts = [v.co for v in verts]
            n = Vector((0.0, 0.0, 0.0))
            for i in range(1, len(pts) - 1):
                n += (pts[i] - pts[0]).cross(pts[i + 1] - pts[0])
            if n.length < 1e-9:
                return None
            c = sum(pts, Vector((0.0, 0.0, 0.0))) / len(pts)
            if (n.dot(Vector(toward) - c) if toward is not None else n.dot(c - Vector(away))) < 0:
                verts.reverse()
                n = -n
                if uvs is not None:
                    uvs = list(reversed(uvs))
            if uvs is None:
                uvs = box_uv([v.co for v in verts], n)
            try:
                f = self.bm.faces.new(verts)
            except ValueError:
                return None
            f.smooth = smooth
            f[self.kind] = kind
            f[self.tone] = tone
            f[self.dirt] = dirt
            for loop, t in zip(f.loops, uvs):
                loop[self.uv].uv = t
            return f

    def trunk(B, rng):
        """The rings of the trunk and the bark between them. V is the place along the log."""
        spec = B.spec
        seed = spec["seed"]
        rings, centres = [], []
        for (x, r, _cz, amp), (_x, _r, cy, cz) in zip(spec["rings"], B.stations):
            c = Vector((x, cy, cz))
            ring = []
            for k in range(SIDES):
                a = 2 * math.pi * k / SIDES
                lump = noise.noise(Vector((x * 0.3 + seed * 1.7, math.sin(a) * 1.3 + seed * 0.37, math.cos(a) * 1.3)))
                ring.append(B.v(c + rad(a) * r * (1 + amp * 1.6 * lump)))
            rings.append(ring)
            centres.append(c)
        for end, ring in (("end_lo", rings[0]), ("end_hi", rings[-1])):
            e = spec[end]
            if e.get("root") or e["rich"]:
                continue
            for v, j in zip(ring, e["jag"]):   # a plain break: the last ring itself is the jagged rim
                v.co.x += j if end == "end_hi" else -j
        for i in range(len(rings) - 1):
            mid = (centres[i] + centres[i + 1]) / 2
            for k in range(SIDES):
                k2 = (k + 1) % SIDES
                a, b, c, d = rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]
                B.face([a, b, c, d], [(u_round(k), a.co.x), (u_round(k + 1), b.co.x), (u_round(k + 1), c.co.x), (u_round(k), d.co.x)],
                       BARK, mid, smooth=True)
        return rings, centres

    def grain_uv(pts, c, hub=None):
        """Broken wood: U round the trunk, V along it, like the bark, so the map's grain runs
        along the log on every splinter. hub: the corner on the axis, which has no place round."""
        us = [R * abs(math.atan2(p.y - c.y, p.z - c.z)) for p in pts]
        if hub is not None:
            us[hub] = sum(u for i, u in enumerate(us) if i != hub) / (len(us) - 1)
        return [(u, p.x) for u, p in zip(us, pts)]

    def broken_end(B, rng, ring, c, d, e, x_limit):
        """A break: the rim torn to uneven lengths, the wood behind it set back in a ragged
        slope that follows the rim, and shards left standing. d is +1 or -1, the way out of the
        log along X."""
        out = Vector((d, 0.0, 0.0))
        jag = e["jag"]
        jmax = max(jag)
        deep = c - out * 4.0
        if e["rich"]:
            teeth = []
            for k, v in enumerate(ring):
                spoke = Vector((0.0, v.co.y - c.y, v.co.z - c.z))
                teeth.append(B.v(c + spoke * (1 - 0.12 * jag[k] / jmax) + out * jag[k]))
            for k in range(SIDES):
                k2 = (k + 1) % SIDES
                a, b, cc, dd = ring[k], ring[k2], teeth[k2], teeth[k]
                B.face([a, b, cc, dd], [(u_round(k), a.co.x), (u_round(k + 1), b.co.x), (u_round(k + 1), cc.co.x), (u_round(k), dd.co.x)],
                       BARK, c, smooth=True)
        else:
            teeth = ring
        inner, heights = [], []
        for k, v in enumerate(ring):
            spoke = Vector((0.0, v.co.y - c.y, v.co.z - c.z))
            near = (jag[k - 1] + 2 * jag[k] + jag[(k + 1) % SIDES]) / 4
            h = 0.6 * near - rng.uniform(0.12, 0.3) - (0.22 if k % 2 else 0.0)   # set back behind the rim, in steps
            heights.append(h)
            inner.append(B.v(c + spoke * 0.55 * rng.uniform(0.72, 1.2) + out * h))
        hub = B.v(c + out * (sum(heights) / SIDES - rng.uniform(0.05, 0.22))
                  + Vector((0.0, rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3))))

        def wood(verts, tone, hub_at=None):
            # the break is a height field seen from in front of the end, so every face looks that way
            B.face(verts, grain_uv([v.co for v in verts], c, hub_at), WOOD, deep, tone=tone, toward=c + out * 8.0)

        for k in range(SIDES):
            k2 = (k + 1) % SIDES
            wood([teeth[k], teeth[k2], inner[k]], rng.uniform(0.35, 1.0))
            wood([teeth[k2], inner[k2], inner[k]], rng.uniform(0.25, 0.9))
            wood([inner[k], inner[k2], hub], rng.uniform(0.1, 0.7), 2)
        for k in e["splinters"]:   # shards left standing just inside the bark, where the rim broke short
            a = 2 * math.pi * (k + rng.uniform(-0.12, 0.12)) / SIDES
            at = int(round(k)) % SIDES
            r = (ring[at].co - c).length
            side = Vector((0.0, math.cos(a), -math.sin(a)))
            foot = c + rad(a) * r * 0.70 + out * (0.5 * jag[at] - 0.75)   # deep in the wood: its open foot never shows
            reach = min(rng.uniform(0.6, 1.0) * max(jmax, 0.75), abs(x_limit - c.x) - 0.02)
            tip = c + rad(a) * r * rng.uniform(0.72, 0.80) + side * rng.uniform(-0.1, 0.1) + out * reach
            w = rng.uniform(0.18, 0.26)
            base = [B.v(foot + side * w), B.v(foot - side * w), B.v(foot - rad(a) * 0.2)]
            top = B.v(tip)
            heart = (sum((v.co for v in base), Vector((0.0, 0.0, 0.0))) + tip) / 4   # inside the shard
            for i in range(3):
                verts = [base[i], base[(i + 1) % 3], top]
                B.face(verts, grain_uv([v.co for v in verts], c), WOOD, heart, tone=rng.uniform(0.55, 1.0))

    def tube_frame(t):
        n = t.cross(Vector((1.0, 0.0, 0.0)))
        if n.length < 1e-3:
            n = t.cross(Vector((0.0, 1.0, 0.0)))
        n.normalize()
        return n, t.cross(n)

    def stub(B, rng, x, az, rake, reach, r0, r1, sides=5):
        """A branch that snapped off: it starts inside the trunk, tapers, and ends in a slanted
        break with one sliver left standing. reach: from its foot inside the trunk to the tip
        of the sliver."""
        r, cy, cz = B.axis(x)
        c = Vector((x, cy, cz))
        a = math.radians(az)
        t = (rad(a) * math.cos(math.radians(rake)) + Vector((1.0, 0.0, 0.0)) * math.sin(math.radians(rake))).normalized()
        p0 = c + rad(a) * r * 0.5
        n, bn = tube_frame(t)
        snap_len = rng.uniform(0.28, 0.42)
        length = reach - snap_len
        high = rng.uniform(0, 2 * math.pi)
        ring0, ring1 = [], []
        for k in range(sides):
            ang = 2 * math.pi * k / sides
            spoke = math.cos(ang) * n + math.sin(ang) * bn
            ring0.append(B.v(p0 + spoke * r0 * 1.2))
            ring1.append(B.v(p0 + t * (length + snap_len * (0.5 + 0.5 * math.cos(ang - high)) ** 2) + spoke * r1))
        girth = 2 * math.pi * r0
        for k in range(sides):
            k2 = (k + 1) % sides
            B.face([ring0[k], ring0[k2], ring1[k2], ring1[k]],
                   [(k / sides * girth, 0.0), ((k + 1) / sides * girth, 0.0), ((k + 1) / sides * girth, length), (k / sides * girth, length)],
                   STUB, p0 + t * length / 2, smooth=True)
        pit = B.v(p0 + t * (length + snap_len * 0.12))
        for k in range(sides):
            B.face([ring1[k], ring1[(k + 1) % sides], pit], None, WOOD, p0, tone=rng.uniform(0.4, 1.0))

    def root_plate(B, rng, ring, c, lo, hi):
        """The root end: the back of the plate that tore out of the bank, and the roots left on
        it, bent back and broken short."""
        out = Vector((1.0, 0.0, 0.0))
        mid = []
        for k, v in enumerate(ring):
            spoke = Vector((0.0, v.co.y - c.y, v.co.z - c.z))
            mid.append(B.v(c + spoke * rng.uniform(0.40, 0.58) + out * rng.uniform(0.40, 0.70)))
        hub = B.v(c + out * 0.85 + Vector((0.0, rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2))))
        for k in range(SIDES):
            k2 = (k + 1) % SIDES
            B.face([ring[k], ring[k2], mid[k]], None, WOOD, c - out * 3, tone=rng.uniform(0.3, 1.0))
            B.face([ring[k2], mid[k2], mid[k]], None, WOOD, c - out * 3, tone=rng.uniform(0.2, 0.9))
            B.face([mid[k], mid[k2], hub], None, WOOD, c - out * 3, tone=rng.uniform(0.0, 0.5))

        def room(a):   # how far out from the plate's middle the first log's box lets a root go
            ca, sa = math.cos(a), math.sin(a)
            return min((hi.z - 0.05 - c.z) / ca if ca > 1e-3 else (c.z - lo.z - 0.05) / -ca if ca < -1e-3 else 9.0,
                       (hi.y - 0.05 - c.y) / sa if sa > 1e-3 else (c.y - lo.y - 0.05) / -sa if sa < -1e-3 else 9.0)

        back = hi.x - 0.05 - c.x
        for az, far, thick in ((15, 1.0, 0.44), (75, 0.62, 0.36), (140, 0.9, 0.42), (232, 1.0, 0.46), (300, 0.7, 0.36)):
            a = math.radians(az + rng.uniform(-8, 8))
            curl = rng.choice((-1, 1)) * rng.uniform(0.35, 0.6)
            a1, a2 = a + curl * 0.4, a + curl
            p0 = c + rad(a) * 1.0 - out * 0.15   # inside the plate: its open foot never shows
            p1 = c + rad(a1) * min(1.75, room(a1) - 0.3) + out * (0.55 + 0.45 * far)
            p2 = c + rad(a2) * min(2.4, room(a2)) * rng.uniform(0.9, 1.0) + out * min(back, 0.85 + 0.95 * far)
            p2 = p1 + (p2 - p1).normalized() * min((p2 - p1).length, 1.0)   # broken short, not a claw
            t = (p1 - p0).normalized()
            n, bn = tube_frame(t)
            ring0, ring1 = [], []
            for k in range(4):
                ang = math.pi / 4 + math.pi / 2 * k
                spoke = math.cos(ang) * n + math.sin(ang) * bn
                ring0.append(B.v(p0 + spoke * thick))
                ring1.append(B.v(p1 + spoke * thick * 0.62))
            tip = B.v(p2)
            g0, g1 = (p1 - p0).length, (p2 - p1).length
            for k in range(4):
                k2 = (k + 1) % 4
                B.face([ring0[k], ring0[k2], ring1[k2], ring1[k]],
                       [(k * 0.6, 0.0), ((k + 1) * 0.6, 0.0), ((k + 1) * 0.6, g0), (k * 0.6, g0)],
                       STUB, (p0 + p1) / 2, smooth=True, dirt=0.5)
                B.face([ring1[k], ring1[k2], tip], [(k * 0.6, g0), ((k + 1) * 0.6, g0), ((k + 0.5) * 0.6, g0 + g1)],
                       STUB, (p1 * 3 + p2) / 4, smooth=True, dirt=0.7)

    def build_log(spec):
        """One log as an object in the scene, in the pivot's coordinates. Returns (object, info)."""
        rng = random.Random(spec["seed"])
        lo, hi = Vector(spec["box"][0]), Vector(spec["box"][1])
        centre = (lo + hi) / 2
        up = Vector((-SIN, 0.0, COS))   # the world's up, seen from the lying log

        def depth(p):
            """How far under the water a point of the log is (minus: above it), in studs."""
            return spec["sink"] - up.dot(Vector(p) - centre)

        B = Build(spec)
        rings, centres = trunk(B, rng)
        broken_end(B, rng, rings[0], centres[0], -1, spec["end_lo"], lo.x)
        if spec["end_hi"].get("root"):
            root_plate(B, rng, rings[-1], centres[-1], lo, hi)
        else:
            c = centres[-1].copy()
            broken_end(B, rng, rings[-1], c, 1, spec["end_hi"], hi.x)
        for s in spec["stubs"]:
            stub(B, rng, *s)

        # nothing may leave the first log's box
        bm = B.bm
        over, where = 0.0, ""
        for v in bm.verts:
            for i in range(3):
                o = max(lo[i] - v.co[i], v.co[i] - hi[i])
                if o > over:
                    over, where = o, f"{'xyz'[i]} at {tuple(round(c, 2) for c in v.co)}"
                v.co[i] = min(max(v.co[i], lo[i]), hi[i])
        if over > 0.005:
            print(f"[logs] {spec['name']}: drawn in {over:.3f} to stay in the box ({where})")

        # cut the bark along the water: soaked | algae line | wet band | dry
        for d in (CUT_ALGAE_LO, CUT_ALGAE_HI, CUT_WET):
            faces = [f for f in bm.faces if f[B.kind] == BARK]
            geom = list({v for f in faces for v in f.verts}) + list({e for f in faces for e in f.edges}) + faces
            bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-4, plane_co=centre + up * (spec["sink"] - d), plane_no=up,
                                   clear_inner=False, clear_outer=False)

        # two specks at opposite corners pin the box (and so the pivot) to the first log's
        e = 0.02
        for p, s in ((lo, 1), (hi, -1)):
            B.face([B.v(p), B.v(p + Vector((e * s, 0, 0))), B.v(p + Vector((0, e * s, 0)))], None, SPECK, p - Vector((0, 0, s)))
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")

        me = bpy.data.meshes.new(spec["name"])
        bm.to_mesh(me)
        bm.free()
        me.update()
        kinds, tones, dirts = (me.attributes[n].data for n in ("kind", "tone", "dirt"))
        uv = me.uv_layers["UVMap"]
        seed = spec["seed"]
        x_lo, x_hi = spec["rings"][0][0], spec["rings"][-1][0]
        root = bool(spec["end_hi"].get("root"))

        def dry(p, kind):
            _r, _cy, cz = B.axis(p.x)
            sky = clamp((p.z - cz) / R, -1.0, 1.0)
            c = mix(PAL["bark_low"], PAL["bark_top"], 0.5 + 0.5 * sky)
            if kind == STUB:
                c = mix(c, PAL["stub"], 0.7)
            t = 1 + 0.07 * noise.noise(Vector((p.x * 0.45 + seed * 3.1, p.y * 0.8, p.z * 0.8)))
            return tuple(x * t for x in c)

        def shown(kind, tone, dirt, p, zone_depth):
            """The colour to see at corner p of a face whose middle is zone_depth under the water."""
            if kind == SPECK:
                return PAL["soak"]
            if kind == WOOD:
                return mix(PAL["end_dark"], PAL["end_light"], tone)
            d = depth(p)
            c = dry(p, kind)
            # toward the break the bark is gone and the wood is dark; the root plate is earth-dark
            wear = clamp((x_lo - p.x) / 0.9)
            if root:
                dirt = max(dirt, 0.8 * ease((p.x - 6.4) / 1.9)) if kind == BARK else dirt
            else:
                wear = max(wear, clamp((p.x - x_hi) / 0.6))
            c = mix(c, PAL["end"], max(0.6 * wear, dirt))
            if kind == STUB:
                return mix(PAL["soak"], c, ease((-d - 0.15) / 0.4))
            if zone_depth > CUT_ALGAE_LO:
                return mix(PAL["soak"], PAL["soak_deep"], (max(d, CUT_ALGAE_LO) - 0.3) / 1.6)
            if zone_depth > CUT_ALGAE_HI:
                return mix(PAL["algae"], PAL["soak"], 0.2 + 0.3 * noise.noise(Vector((p.x * 0.9, seed * 1.37 + 0.5, 0.31))))
            if zone_depth > CUT_WET:
                return PAL["soak"]
            return mix(PAL["soak"], c, ease((-d + CUT_WET) / FADE))   # soak on the cut, dry by the next ring up

        col = me.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
        zones = {"soaked": 0, "algae": 0, "wet": 0, "dry": 0}
        uv_slip = 0.0
        for poly in me.polygons:
            kind, tone, dirt = kinds[poly.index].value, tones[poly.index].value, dirts[poly.index].value
            zd = depth(poly.center)
            if kind == BARK:
                zones["soaked" if zd > CUT_ALGAE_LO else "algae" if zd > CUT_ALGAE_HI else "wet" if zd > CUT_WET else "dry"] += 1
            for li in poly.loop_indices:
                p = me.vertices[me.loops[li].vertex_index].co
                rgb = shown(kind, tone, dirt, p, zd)
                col.data[li].color = tuple(srgb_to_linear(min(255.0, max(0.0, x * LIFT))) for x in rgb) + (1.0,)
                if kind == BARK:   # the cuts must have carried the UVs: V is the place along the log
                    uv_slip = max(uv_slip, abs(uv.data[li].uv[1] - p.x))
        for n in ("kind", "tone", "dirt"):
            me.attributes.remove(me.attributes[n])
        me.color_attributes.active_color = me.color_attributes["Col"]
        me.color_attributes.render_color_index = me.color_attributes.find("Col")

        pivot = Vector((centre.x, centre.y, lo.z))
        me.transform(Matrix.Translation(-pivot))
        me.update()
        me.calc_loop_triangles()
        tris = len(me.loop_triangles)
        got_lo = Vector(tuple(min(v.co[i] for v in me.vertices) for i in range(3)))
        got_hi = Vector(tuple(max(v.co[i] for v in me.vertices) for i in range(3)))
        size = hi - lo
        want_lo, want_hi = Vector((-size.x / 2, -size.y / 2, 0.0)), Vector((size.x / 2, size.y / 2, size.z))
        if (got_lo - want_lo).length > 1e-4 or (got_hi - want_hi).length > 1e-4:
            raise SystemExit(f"{spec['name']}: box {tuple(got_lo)} to {tuple(got_hi)}, wanted {tuple(want_lo)} to {tuple(want_hi)}")
        if tris > MAX_TRIS:
            raise SystemExit(f"{spec['name']}: {tris} triangles is over the {MAX_TRIS} budget")
        if uv_slip > 1e-3:
            raise SystemExit(f"{spec['name']}: the water cuts moved the UVs by {uv_slip:.4f}")
        obj = bpy.data.objects.new(spec["name"], me)
        scene_of().collection.objects.link(obj)
        info = {"triangles": tris, "studs": [round(size.x, 2), round(size.z, 2), round(size.y, 2)],
                "drawn_in": round(max(over, 0.0), 3), "zones": zones, "pivot": [round(c, 6) for c in pivot],
                "water_at_high_end": round(depth(Vector((lo.x, 0.0, B.stations[0][3] - B.stations[0][1]))), 2),
                "under_from_x": round((spec["sink"] - COS * (B.stations[0][3] + B.stations[0][1] - centre.z)) / -SIN + centre.x, 2)}
        print(f"[logs] {spec['name']}: {info['studs']} studs, {tris} triangles, bark faces {zones}, drawn in {info['drawn_in']}")
        return obj, info

    def plain_material(name, layer="Col"):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        bsdf.inputs["Roughness"].default_value = 0.85
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = layer
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
        return roblox_colors.convert(path, ROBLOX / path.name)

    # ------------------------------------------------------------------ previews
    def setup_cycles(w, h, exposure=0.0):
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
            scene.world = bpy.data.worlds.new("Sky")
            scene.world.use_nodes = True
        cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        scene.collection.objects.link(cam)
        scene.camera = cam
        cam["_stage"] = True
        return cam

    def light(sky, sky_strength, sun_rgb, sun_energy, sun_dir, sun_angle=1.5):
        """sun_dir: the way the light travels."""
        bg = scene_of().world.node_tree.nodes["Background"]
        bg.inputs[0].default_value = (*sky, 1.0)
        bg.inputs[1].default_value = sky_strength
        sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
        sun.data.energy = sun_energy
        sun.data.color = sun_rgb
        sun.data.angle = math.radians(sun_angle)
        sun.rotation_euler = Vector(sun_dir).to_track_quat("-Z", "Y").to_euler()
        scene_of().collection.objects.link(sun)
        sun["_stage"] = True

    def flat(name, rgb, rough=0.95):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = tuple(srgb_to_linear(c) for c in rgb) + (1.0,)
        bsdf.inputs["Roughness"].default_value = rough
        return m

    bark_cache = {}

    def bark_material(layer="Col"):
        """What the game shows: vertex colour times the bark family's NEUTRAL map, with its
        normal and roughness maps, one tile every four studs. Without the maps: colour times 0.8."""
        if layer in bark_cache:
            return bark_cache[layer]
        m = bpy.data.materials.new(f"Preview_bark_{layer}")
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = layer
        mul = nt.nodes.new("ShaderNodeMix")
        mul.data_type = "RGBA"
        mul.blend_type = "MULTIPLY"
        mul.inputs[0].default_value = 1.0
        nt.links.new(vc.outputs["Color"], mul.inputs[7])
        nt.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
        folder = TEXTURES / "bark"
        if not (folder / "bark_neutral.png").exists():
            mul.inputs[6].default_value = (0.604, 0.604, 0.604, 1.0)
            bsdf.inputs["Roughness"].default_value = 0.85
        else:
            uv = nt.nodes.new("ShaderNodeUVMap")
            uv.uv_map = "UVMap"
            mapping = nt.nodes.new("ShaderNodeMapping")
            mapping.inputs["Scale"].default_value = (1 / TILE, 1 / TILE, 1)
            nt.links.new(uv.outputs[0], mapping.inputs[0])

            def tex(kind, non_color):
                node = nt.nodes.new("ShaderNodeTexImage")
                node.image = bpy.data.images.load(str(folder / f"bark_{kind}.png"), check_existing=True)
                if non_color:
                    node.image.colorspace_settings.name = "Non-Color"
                nt.links.new(mapping.outputs[0], node.inputs[0])
                return node

            nt.links.new(tex("neutral", False).outputs[0], mul.inputs[6])
            nt.links.new(tex("rough", True).outputs[0], bsdf.inputs["Roughness"])
            nmap = nt.nodes.new("ShaderNodeNormalMap")
            nmap.uv_map = "UVMap"
            nt.links.new(tex("normal", True).outputs[0], nmap.inputs["Color"])
            nt.links.new(nmap.outputs[0], bsdf.inputs["Normal"])
        bark_cache[layer] = m
        return m

    def staged(obj, matrix=None):
        o = obj.copy()
        o.hide_render = False
        o.matrix_world = matrix or Matrix.Identity(4)
        o["_stage"] = True
        scene_of().collection.objects.link(o)
        return o

    def aim(cam, eye, look, fov=None, ortho=None):
        cam.location = eye
        cam.rotation_euler = (Vector(look) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
        cam.data.clip_end = 3000
        if ortho:
            cam.data.type = "ORTHO"
            cam.data.ortho_scale = ortho
        else:
            cam.data.type = "PERSP"
            cam.data.sensor_fit = "VERTICAL"
            cam.data.angle_y = math.radians(fov)

    def snap(path):
        scene_of().render.filepath = str(path)
        bpy.ops.render.render(write_still=True)

    def studio(obj, size, side=-1):
        """The plain stage every art/previews picture uses: pale sky, one sun, a pale ground.
        side: which end of the log the sun stands over (-1: the end that shows)."""
        light((0.78, 0.86, 0.93), 0.9, (1.0, 1.0, 1.0), 3.2, (-0.35 * side, 0.55, -0.76), 8)
        staged(obj)
        bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=size.length * 1.5, depth=0.01, location=(0, 0, -0.005))
        g = bpy.context.object
        g.data.materials.append(flat("_ground", (205, 215, 200), 1.0))
        g["_stage"] = True

    def shoot_model(spec, obj):
        """Three-quarter from the end the player sees, and a close look at each end."""
        lo, hi = Vector(spec["box"][0]), Vector(spec["box"][1])
        size = hi - lo
        mid = Vector((0, 0, size.z / 2))
        cam = setup_cycles(1024, 1024)
        studio(obj, size)
        yaw, pitch = math.radians(-28), math.radians(27)
        d = Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
        aim(cam, mid + d * size.length * 3, mid, ortho=max(size.length * 0.9, max(size) * 1.12))
        snap(PREVIEWS / f"{spec['name']}.png")
        pivot_x = (lo.x + hi.x) / 2
        for tag, x, s in (("lo", spec["rings"][0][0] - pivot_x, -1), ("hi", spec["rings"][-1][0] - pivot_x, 1)):
            cam = setup_cycles(900, 700)
            studio(obj, size, s)
            far = 6.4 if (tag == "hi" and spec["end_hi"].get("root")) else 4.6
            aim(cam, (x + s * far, -far * 0.8, 1.2 + far * 0.48), (x + s * 0.2, 0.0, 1.25 if far < 5 else 1.9), fov=38)
            snap(SCRATCH / f"{spec['name']}-end-{tag}.png")

    def placed(spec, spot, yaw):
        """Where WorldBuilder.put lays a log model over its gray box, in Blender's axes
        (Roblox X, Y, Z is Blender X, -Z... see below). The model comes into Roblox with
        Blender +X along Roblox -X; its pivot goes to part.CFrame * CFrame.new(0, -height / 2, 0)."""
        lo, hi = Vector(spec["box"][0]), Vector(spec["box"][1])
        h = hi.z - lo.z
        imported = Matrix(((-1, 0, 0, 0), (0, 0, 1, -h / 2), (0, 1, 0, 0), (0, 0, 0, 1)))
        part = Matrix.Translation(spot) @ Matrix.Rotation(yaw, 4, "Y") @ Matrix.Rotation(TILT, 4, "Z")
        to_blender = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
        return to_blender @ part @ imported

    def rb(p):
        """A Roblox point in Blender's axes."""
        return Vector((p[0], -p[2], p[1]))

    def import_old(name):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(MODELS / f"{name}.glb"))
        new = [o for o in bpy.data.objects if o not in before]
        obj = next(o for o in new if o.type == "MESH")
        bpy.context.view_layer.update()
        world = obj.matrix_world.copy()
        obj.parent = None
        obj.data.transform(world)
        obj.matrix_world = Matrix.Identity(4)
        for o in new:
            if o is not obj:
                bpy.data.objects.remove(o, do_unlink=True)
        layer = obj.data.color_attributes[0].name if obj.data.color_attributes else "Col"
        obj.data.materials.clear()
        obj.data.materials.append(bark_material(layer))
        obj.hide_render = True
        return obj

    def lake(logs, mood):
        """The east bank of the home lake with the five logs where the game lays them. The
        water is a Blender stand-in, not the engine's."""
        if mood == "dawn":
            light((0.42, 0.44, 0.74), 0.55, (1.0, 0.72, 0.62), 0.5, (-0.9, 0.35, -0.16), 6)
        else:
            light((0.80, 0.88, 1.0), 0.8, (1.0, 0.96, 0.88), 3.4, (-0.45, 0.5, -0.74), 1.5)
        for spot, yaw, v in SPOTS:
            staged(logs[v], placed(SPECS[v], spot, yaw))
        # water: a box of tinted water from the surface down to the bed
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, -4))
        w = bpy.context.object
        w.scale = (224, 164, 8)
        w["_stage"] = True
        m = bpy.data.materials.new("Water")
        m.use_nodes = True
        nt = m.node_tree
        nt.nodes.remove(nt.nodes["Principled BSDF"])
        out = nt.nodes["Material Output"]
        clear = nt.nodes.new("ShaderNodeBsdfTransparent")
        clear.inputs[0].default_value = (0.80, 0.90, 0.90, 1.0)
        shine = nt.nodes.new("ShaderNodeBsdfGlossy")
        shine.inputs["Roughness"].default_value = 0.06
        ripple = nt.nodes.new("ShaderNodeTexNoise")
        ripple.inputs["Scale"].default_value = 0.6
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.06
        nt.links.new(ripple.outputs[0], bump.inputs["Height"])
        nt.links.new(bump.outputs[0], shine.inputs["Normal"])
        fres = nt.nodes.new("ShaderNodeFresnel")
        fres.inputs["IOR"].default_value = 1.33
        nt.links.new(bump.outputs[0], fres.inputs["Normal"])
        both = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(fres.outputs[0], both.inputs[0])
        nt.links.new(clear.outputs[0], both.inputs[1])
        nt.links.new(shine.outputs[0], both.inputs[2])
        nt.links.new(both.outputs[0], out.inputs["Surface"])
        murk = nt.nodes.new("ShaderNodeVolumeAbsorption")
        murk.inputs["Color"].default_value = (0.10, 0.36, 0.33, 1.0)
        murk.inputs["Density"].default_value = 0.9
        nt.links.new(murk.outputs[0], out.inputs["Volume"])
        w.data.materials.append(m)
        # the bed, and the east bank the camera stands on (ground top at y = 1)
        me = bpy.data.meshes.new("Bank")
        prof = [(-300, -7.0), (96, -7.0), (102, -3.0), (106, -0.6), (109, 0.4), (113, 1.0), (400, 1.0)]
        verts = [(x, y, z) for x, z in prof for y in (-300, 300)]
        faces = [(2 * i, 2 * i + 2, 2 * i + 3, 2 * i + 1) for i in range(len(prof) - 1)]
        me.from_pydata(verts, [], faces)
        bank = bpy.data.objects.new("Bank", me)
        bank.data.materials.append(flat("Gravel", (132, 124, 112)))
        bank["_stage"] = True
        scene_of().collection.objects.link(bank)

    def shoot_lake(logs, old):
        w, h = SHOT06["size"]
        for tag, group, mood in (("shot06-dawn", logs, "dawn"), ("shot06-dawn-old", old, "dawn"), ("shot06-day", logs, "day")):
            cam = setup_cycles(w, h)
            lake(group, mood)
            aim(cam, rb(SHOT06["eye"]), rb(SHOT06["look"]), fov=70)
            snap(SCRATCH / f"ingame-{tag}.png")
        # 30 studs from the near log (gray-box log 4), eye 5 studs up, square on to it
        spot, yaw, _v = SPOTS[3]
        along = Vector((math.cos(yaw), 0.0, -math.sin(yaw)))
        seen = Vector(spot) + along * 4.5
        eye = seen + Vector((math.sin(yaw), 0.0, math.cos(yaw))) * 30
        for tag, group, mood in (("near-day", logs, "day"), ("near-day-old", old, "day"), ("near-dawn", logs, "dawn")):
            cam = setup_cycles(1600, 900)
            lake(group, mood)
            aim(cam, rb((eye.x, 5.0, eye.z)), rb((seen.x, 0.4, seen.z)), fov=70)
            snap(SCRATCH / f"ingame-{tag}.png")

    # ------------------------------------------------------------------ run
    for d in (MODELS, ROBLOX, PREVIEWS, SCRATCH):
        d.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene_of().unit_settings.system = "NONE"
    logs, result = {}, {}
    for v, spec in SPECS.items():
        obj, info = build_log(spec)
        info["colours_converted"] = export(obj)
        obj.data.materials.clear()
        obj.data.materials.append(bark_material())
        obj.hide_render = True
        logs[v] = obj
        result[spec["name"]] = info
    write_manifest(result)
    (SCRATCH / "result.json").write_text(json.dumps(result, indent=1), encoding="utf-8")
    if args.no_render:
        return
    for v, spec in SPECS.items():
        shoot_model(spec, logs[v])
    old = {v: import_old(spec["old"]) for v, spec in SPECS.items()}
    shoot_lake(logs, old)


# =======================================================================================
# The record, the checks and the sheet (plain Python)
# =======================================================================================

def read_glb(path: Path):
    data = path.read_bytes()
    json_len = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20:20 + json_len]), data[20 + json_len + 8:]


def check_glb(name, old):
    """The new file against the first log's: one mesh, the same box to a ten-thousandth of a
    stud, UVs and colours present. Returns its triangle count."""
    out = None
    for folder in (MODELS, ROBLOX):
        gltf, _bin = read_glb(folder / f"{name}.glb")
        prims = [p for m in gltf["meshes"] for p in m["primitives"]]
        if len(gltf["meshes"]) != 1 or len(prims) != 1:
            raise SystemExit(f"{name}: {len(gltf['meshes'])} meshes and {len(prims)} primitives, wanted one of each")
        attrs = prims[0]["attributes"]
        for need in ("POSITION", "NORMAL", "TEXCOORD_0", "COLOR_0"):
            if need not in attrs:
                raise SystemExit(f"{name}: no {need} in {folder.name}/{name}.glb")
        pos = gltf["accessors"][attrs["POSITION"]]
        old_gltf, _ = read_glb(MODELS / f"{old}.glb")
        old_pos = old_gltf["accessors"][old_gltf["meshes"][0]["primitives"][0]["attributes"]["POSITION"]]
        worst = max(abs(a - b) for key in ("min", "max") for a, b in zip(pos[key], old_pos[key]))
        if worst > 1e-4:
            raise SystemExit(f"{name}: its box is {worst:.5f} studs off {old}'s ({pos['min']} to {pos['max']})")
        out = gltf["accessors"][prims[0]["indices"]]["count"] // 3
    return out


def write_manifest(result):
    """Only the three Log<n>b entries are touched: every other entry keeps its place and its
    text, and a new entry goes in straight after the log it replaces."""
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    entries = {}
    for v, spec in SPECS.items():
        name, info = spec["name"], result[spec["name"]]
        tris = check_glb(name, spec["old"])
        if tris != info["triangles"]:
            raise SystemExit(f"{name}: {tris} triangles in the file, {info['triangles']} in Blender")
        here = ""
        if "sink_here" in spec:
            here = (f" Its own gray box lies {spec['sink_here']:g} studs under, which hides all of it but the tip of the trunk "
                    f"(as it hides {spec['old']} now), so it is painted for a box {spec['sink']:g} under instead: lay it over "
                    f"gray-box log 1 or 4, or raise its box, to show it.")
        if spec["end_hi"].get("root"):
            ends = "The root plate is at Blender +X (Roblox -X), the broken end at Blender -X (Roblox +X)."
        else:
            ends = "Both ends are broken; the richer break is at Blender -X (Roblox +X), the end that shows."
        entries[name] = {
            "name": name,
            "studs": info["studs"],
            "triangles": tris,
            "parts": 1,
            "replaces": (f"{spec['old']} (asset {spec['old_asset']}) over {spec['spots']}: the same box and pivot to a "
                         f"ten-thousandth of a stud, so it swaps in at the same CFrame"),
            "notes": (f"Weathered fallen log, Layer B, bark family, one mesh: MaterialVariant bark (Bark on Wood) with its NEUTRAL "
                      f"colour map, normal and roughness. Vertex colours stored {LIFT:g} times the colour wanted. UVs at 1 stud per "
                      f"UV unit, grain along the log. Upload art/models/roblox/{name}.glb. Lies along X, pivot at the bottom centre "
                      f"of the box; two corner specks pin the box to {spec['old']}'s. {ends} The water is painted for the gray "
                      f"boxes as WorldBuilder lays them: CFrame.Angles(0, yaw, {TILT:g}) with the middle {spec['sink']:g} studs under "
                      f"the water, so the Roblox +X end is up.{here} Soaked wood below the water, a thin green algae line on it, a wet "
                      f"band above, dry bark over that. At that depth the water stands {info['water_at_high_end']:g} studs up the "
                      f"high end. If a log is laid another way the line will not sit on the water."),
            "model": name,
            "family": "bark",
            "variant": "bark",
            "uv_studs": 1.0,
            "lift": LIFT,
            "water": {"sink": spec["sink"], "sink_of_its_own_box": spec.get("sink_here", spec["sink"]), "tilt": TILT,
                      "high_end": "Roblox +X (Blender -X)", "cuts_depth": [CUT_ALGAE_LO, CUT_ALGAE_HI, CUT_WET]},
            "palette_seen_rgb": {k: list(PAL[k]) for k in ("bark", "bark_top", "bark_low", "end", "soak", "algae")},
        }
    out = {}
    for key, value in manifest.items():
        if key not in entries:
            out[key] = value
        for name, entry in entries.items():
            if key == name or (name not in manifest and key == name[:-1]):
                out[name] = entry
    for name, entry in entries.items():
        out.setdefault(name, entry)
    MANIFEST.write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")


def compose():
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ModuleNotFoundError:
        import site

        sys.path.append(site.getusersitepackages())
        from PIL import Image, ImageDraw, ImageFont

    def font(size, bold=False):
        for name in (("segoeuib.ttf", "arialbd.ttf") if bold else ("segoeui.ttf", "arial.ttf")):
            try:
                return ImageFont.truetype(name, size)
            except OSError:
                continue
        return ImageFont.load_default()

    def small(im):   # 256 colours, as common.py does, so the previews stay small in git
        return im.convert("RGB").quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)

    def fit(im, w):
        return im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)

    result = json.loads((SCRATCH / "result.json").read_text(encoding="utf-8"))
    names = [spec["name"] for spec in SPECS.values()]
    for name in names:   # the two ends side by side
        a, b = (Image.open(SCRATCH / f"{name}-end-{t}.png").convert("RGB") for t in ("lo", "hi"))
        both = Image.new("RGB", (a.width + b.width + 8, a.height), (255, 255, 255))
        both.paste(a, (0, 0))
        both.paste(b, (a.width + 8, 0))
        small(both).save(PREVIEWS / f"{name}-ends.png", optimize=True)
        three = Image.open(PREVIEWS / f"{name}.png")
        if three.mode != "P":
            small(three).save(PREVIEWS / f"{name}.png", optimize=True)
    near = Image.open(SCRATCH / "ingame-near-day.png").convert("RGB")
    small(near).save(PREVIEWS / "logs_b-ingame.png", optimize=True)

    W, pad, ink, soft = 2400, 24, (30, 34, 40), (95, 100, 108)
    cells = []   # rows of (title, image)
    col2 = (W - 3 * pad) // 2
    shot = Image.open(SHOT06_FILE).convert("RGB") if SHOT06_FILE.exists() else None
    row = []
    if shot is not None:
        row.append(("Before, in the game: shot 06, east bank at dawn (cropped)", fit(shot.crop(SHOT06_CROP), col2)))
    for title, tag in (("Before, Blender stand-in: Log1 to Log3, same camera", "shot06-dawn-old"),
                       ("After, Blender stand-in: Log1b to Log3b, same camera, dawn", "shot06-dawn"),
                       ("After, same camera, plain daylight (to judge the colours)", "shot06-day")):
        row.append((title, fit(Image.open(SCRATCH / f"ingame-{tag}.png").convert("RGB").crop(SHOT06_CROP), col2)))
    cells.append(row[:2])
    cells.append(row[2:])
    crop = (430, 300, 1230, 640)
    cells.append([("Before: Log1 from 30 studs, eye 5 studs up, daylight (crop of the 70 degree view)",
                   fit(Image.open(SCRATCH / "ingame-near-day-old.png").convert("RGB").crop(crop), col2)),
                  ("After: Log1b from 30 studs, eye 5 studs up, daylight (same crop)", fit(near.crop(crop), col2))])
    cells.append([("After: the same view at dawn", fit(Image.open(SCRATCH / "ingame-near-dawn.png").convert("RGB").crop(crop), col2)),
                  ("After: the whole width of the 70 degree view from 30 studs", fit(near.crop((0, 150, 1600, 830)), col2))])
    col3 = (W - 4 * pad) // 3
    cells.append([(f"Before: {spec['old']}", fit(Image.open(PREVIEWS / f"{spec['old']}.png").convert("RGB").crop((0, 250, 1024, 800)), col3))
                  for spec in SPECS.values()])
    cells.append([(f"After: {n}, {result[n]['triangles']} triangles, {result[n]['studs'][0]} x {result[n]['studs'][1]} x {result[n]['studs'][2]} studs",
                   fit(Image.open(PREVIEWS / f"{n}.png").convert("RGB").crop((0, 250, 1024, 800)), col3)) for n in names])
    cells.append([(f"{n}: the end that shows (left) and the sunk end (right)", fit(Image.open(PREVIEWS / f"{n}-ends.png").convert("RGB"), col3))
                  for n in names])
    head = 96
    height = head + sum(max(im.height for _t, im in row) + 44 + pad for row in cells) + pad
    sheet = Image.new("RGB", (W, height), (246, 246, 243))
    draw = ImageDraw.Draw(sheet)
    draw.text((pad, 18), "Fallen logs, weathered: Log1b, Log2b, Log3b", font=font(40, True), fill=ink)
    draw.text((pad, 66), "Broken soaked ends, the water painted on (soaked, algae line, wet band), bark family, one mesh each. "
              "Blender's water and light are stand-ins for the engine's.", font=font(20), fill=soft)
    y = head + pad
    for row in cells:
        x = pad
        for title, im in row:
            draw.text((x, y), title, font=font(22, True), fill=ink)
            sheet.paste(im, (x, y + 34))
            x += im.width + pad
        y += max(im.height for _t, im in row) + 44 + pad
    small(sheet).save(PREVIEWS / "logs_b.png", optimize=True)
    print(f"sheet: {PREVIEWS / 'logs_b.png'}")


def driver_main():
    import subprocess

    args = parse_args(sys.argv[1:])
    if not args.compose_only:
        subprocess.run([BLENDER, "-b", "--factory-startup", "-P", str(Path(__file__).resolve()), "--", *sys.argv[1:]], check=True)
    if args.old or args.no_render:
        return
    compose()


if __name__ == "__main__":
    try:
        import bpy  # noqa: F401
    except ModuleNotFoundError:
        driver_main()
    else:
        blender_main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
