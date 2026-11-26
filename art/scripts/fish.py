"""Every fish in FishData.luau and BigLakeFishData.luau, each with its real colours and markings, at true relative
size: 1 stud = 12 cm (the same scale the catch on the line uses), built at the species'
average length. Head points along +X (Roblox +X), back up.

Usage:  python art/scripts/fish.py              (all of them)
        python art/scripts/fish.py Walleye      (one)
"""

import math
import random
import sys
from pathlib import Path

import bpy  # noqa: I001  (bpy must load before bmesh)
import bmesh
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import cyl, finish, mat, paint, reset, sphere  # noqa: E402

CM_PER_STUD = 12


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def plate(points, thickness, material, y=0.0, name="fin"):
    """A thin prism from a 2D outline in the XZ plane, centred on y."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    front = [bm.verts.new((px, y - thickness / 2, pz)) for px, pz in points]
    back = [bm.verts.new((px, y + thickness / 2, pz)) for px, pz in points]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(points)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(material)
    return o


def side_plate(points, thickness, material, y, tilt, name="pectoral"):
    """A fin on the flank: an outline in XZ, rotated out from the body by `tilt` radians."""
    o = plate(points, thickness, material, 0.0, name)
    o.rotation_euler = (tilt, 0, 0)
    o.location = (0, y, 0)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=False)
    o.select_set(False)
    return o


def body(L, depth, width, snout=1.0, belly_drop=0.0, flat_head=0.0):
    """Body along X from -L/2 (tail) to +L/2 (head). Returns the object and its profile."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1)
    o = bpy.context.object
    H, W = depth * L, width * L
    for v in o.data.vertices:
        x, y, z = v.co
        u = x  # -1 tail .. 1 head
        taper = 0.28 + 0.72 * smooth(-1.05, 0.1, u)  # thin tail stem
        headshape = 1 - 0.25 * smooth(0.5, 1.0, u) * (1 - snout * 0.0)
        hz = H / 2 * taper * headshape
        wy = W / 2 * taper
        nz = z * hz - belly_drop * H * 0.15 * smooth(-0.6, 0.4, u) * (1 if z < 0 else 0) * abs(z)
        if flat_head and u > 0.3 and z > 0:
            nz *= 1 - flat_head * smooth(0.3, 1.0, u)
        nx = u * L / 2 * (snout if u > 0 else 1)
        v.co = Vector((nx, y * wy, nz))
    return o, H, W


def tail(L, H, color, fork=0.6, size=1.0, thick=0.03, x0=None):
    x0 = -L / 2 + L * 0.04 if x0 is None else x0
    th = H * 0.55 * size
    tl = L * 0.2 * size
    pts = [(x0, H * 0.08), (x0 - tl, th), (x0 - tl * (1 - fork * 0.5), 0), (x0 - tl, -th), (x0, -H * 0.08)]
    return plate(pts, L * thick, color, name="tail")


def taper_at(u):
    return 0.28 + 0.72 * smooth(-1.05, 0.1, u)


def dorsal(L, H, color, start=0.35, end=-0.25, height=0.35, spiky=False):
    xs, xe = start * L / 2, end * L / 2
    # Sit the fin on the back where it actually is (the body narrows toward the tail).
    top = H / 2 * 0.85 * taper_at((start + end) / 2)
    pts = [(xs, H / 2 * 0.8 * taper_at(start) - H * 0.05)]
    if spiky:
        n = 6
        for k in range(n):
            t = (k + 0.5) / n
            x = xs + (xe - xs) * t
            pts.append((x, top + H * height * (0.9 if k % 2 == 0 else 0.6)))
    else:
        pts.append((xs - (xs - xe) * 0.3, top + H * height))
        pts.append((xe, top + H * height * 0.5))
    pts.append((xe - L * 0.03, H / 2 * 0.8 * taper_at(end) - H * 0.1))
    return plate(pts, L * 0.02, color, name="dorsal")


def surface_y(obj, x, z, sgn):
    """Where the body's side is at (x, z): cast a ray in from outside."""
    bpy.context.view_layer.update()
    hit, loc, *_ = obj.ray_cast(Vector((x, sgn * 50, z)), Vector((0, -sgn, 0)))
    return loc.y if hit else 0.0


def eye(L, H, x, z, iris=(20, 20, 20), ring=(235, 225, 160), size=1.0, body_obj=None):
    r = max(L * 0.035, 0.05) * size
    for sgn in (-1, 1):
        y = surface_y(body_obj, x, z, sgn) + sgn * r * 0.15 if body_obj else sgn * (H * 0.18 + r * 0.2)
        sphere(r * 1.3, (x, y * 0.92, z), mat(f"eyering{ring}", ring), scale=(1, 0.4, 1), seg=(8, 6))
        sphere(r * 0.8, (x, y * 0.98 + sgn * r * 0.12, z), mat(f"iris{iris}", iris), scale=(1, 0.5, 1), seg=(8, 6))


def fins_lower(L, H, color):
    # Pelvic and anal fins under the body, pectorals on the sides.
    plate([(L * 0.12, -H * 0.38), (L * 0.02, -H * 0.62), (-L * 0.02, -H * 0.4)], L * 0.02, color, name="pelvic")
    plate([(-L * 0.12, -H * 0.36), (-L * 0.2, -H * 0.58), (-L * 0.3, -H * 0.3)], L * 0.02, color, name="anal")
    for s in (-1, 1):
        side_plate([(L * 0.24, 0), (L * 0.08, H * 0.1), (L * 0.1, -H * 0.18)], L * 0.012, color, s * H * 0.17, s * 0.5)


# ---------------------------------------------------------------- species

def species(sid):
    rng = random.Random(sid)

    def spots(density, color, base_fn, zmin=-2, zmax=2, size=0.18):
        """Speckles: a face goes `color` when it falls near one of random spot centres."""
        centres = [(rng.uniform(-0.8, 0.85), rng.uniform(zmin, zmax)) for _ in range(density)]

        def fn(c, n, u, v):
            for cu, cv in centres:
                if (u - cu) ** 2 + ((v - cv) * 0.5) ** 2 < size ** 2:
                    return color
            return base_fn(c, n, u, v)

        return fn

    # Each entry: avg cm (from FishData), depth and width ratios, fin colour, painter.
    if sid == "Bluegill":
        def p(c, n, u, v):
            if (u - 0.48) ** 2 + (v - 0.12) ** 2 < 0.02:
                return (20, 25, 40)  # black ear flap
            base = mix((220, 165, 80), (70, 105, 125), smooth(-0.6, 0.4, v))
            if math.sin(u * 14) > 0.55 and v > -0.3:
                base = mix(base, (40, 60, 80), 0.35)  # faint vertical bars
            return base
        return dict(cm=18.5, depth=0.5, width=0.16, fin=(60, 85, 100), paint=p, spiky=True)
    if sid == "Pumpkinseed":
        def p(c, n, u, v):
            if (u - 0.48) ** 2 + (v - 0.12) ** 2 < 0.02:
                return (210, 40, 40) if u > 0.5 else (25, 25, 30)  # black flap, red tip
            if u > 0.55 and math.sin(v * 18 + u * 9) > 0.7:
                return (70, 150, 170)  # blue cheek lines
            base = mix((240, 140, 45), (150, 120, 60), smooth(-0.5, 0.4, v))
            return mix(base, (110, 80, 40), 0.4) if rng.random() < 0.18 else base
        return dict(cm=16, depth=0.48, width=0.16, fin=(160, 120, 60), paint=p, spiky=True)
    if sid == "YellowPerch":
        def p(c, n, u, v):
            base = mix((235, 225, 190), (215, 190, 70), smooth(-0.7, -0.2, v))
            base = mix(base, (110, 120, 55), smooth(0.3, 0.9, v))
            if math.sin((u + 0.1) * 21) > 0.45 and v > -0.45:
                return mix(base, (55, 65, 35), 0.75)  # dark saddles
            return base
        return dict(cm=23.5, depth=0.28, width=0.15, fin=(220, 110, 50), paint=p, spiky=True)
    if sid == "BlackCrappie":
        base = lambda c, n, u, v: mix((215, 215, 205), (120, 125, 115), smooth(-0.3, 0.8, v))
        return dict(cm=25, depth=0.46, width=0.14, fin=(90, 95, 90), paint=spots(38, (45, 50, 45), base, -0.7, 0.9, 0.075), spiky=True)
    if sid == "LargemouthBass":
        def p(c, n, u, v):
            if u > 0.82 and -0.25 < v < 0.1:
                return (40, 50, 30)  # the big mouth line
            base = mix((235, 235, 215), (120, 155, 85), smooth(-0.6, -0.1, v))
            base = mix(base, (55, 85, 40), smooth(0.35, 0.9, v))
            if abs(v - 0.05 - 0.08 * math.sin(u * 12)) < 0.13 and u < 0.8:
                return (45, 65, 35)  # jagged dark stripe
            return base
        return dict(cm=42.5, depth=0.3, width=0.17, fin=(95, 120, 70), paint=p)
    if sid == "ChannelCatfish":
        base = lambda c, n, u, v: mix((235, 235, 230), (100, 105, 120), smooth(-0.5, -0.1, v))
        return dict(cm=62.5, depth=0.2, width=0.2, fin=(90, 95, 105), paint=spots(14, (45, 48, 58), base, 0.0, 0.8, 0.045), barbels=True, flat_head=0.4, adipose=True, fork=0.9)
    if sid == "CommonCarp":
        def p(c, n, u, v):
            base = mix((235, 205, 120), (175, 135, 60), smooth(-0.6, 0.0, v))
            base = mix(base, (110, 90, 45), smooth(0.4, 0.95, v))
            if (math.sin(u * 30) > 0.8) or (math.sin(v * 16 + u * 15) > 0.85):
                return mix(base, (90, 65, 30), 0.35)  # scale grid
            return base
        return dict(cm=57.5, depth=0.32, width=0.18, fin=(150, 105, 60), paint=p, barbels=True, short_barbels=True)
    if sid == "NorthernPike":
        def p(c, n, u, v):
            base = mix((225, 225, 190), (95, 125, 75), smooth(-0.6, -0.2, v))
            base = mix(base, (55, 80, 45), smooth(0.4, 0.95, v))
            if v > -0.5 and math.sin(u * 26) > 0.6 and math.sin(v * 9 + u * 7) > 0.2:
                return (205, 210, 150)  # rows of pale bean spots
            return base
        return dict(cm=77.5, depth=0.16, width=0.13, fin=(130, 110, 70), paint=p, snout=1.35, dorsal=(-0.45, -0.75, 0.6), flat_head=0.3)
    if sid == "RainbowTrout":
        base = lambda c, n, u, v: (205, 95, 125) if -0.22 < v < 0.18 else mix((235, 235, 235), (95, 115, 75), smooth(-0.6, 0.4, v))
        return dict(cm=35, depth=0.25, width=0.15, fin=(150, 130, 110), paint=spots(40, (30, 30, 30), base, 0.1, 0.95, 0.06), adipose=True, fork=0.3)
    if sid == "SmallmouthBass":
        def p(c, n, u, v):
            base = mix((225, 210, 165), (140, 110, 60), smooth(-0.6, -0.1, v))
            base = mix(base, (90, 70, 40), smooth(0.4, 0.95, v))
            if math.sin(u * 17) > 0.5 and u < 0.75:
                return mix(base, (70, 55, 30), 0.6)  # vertical bars
            return base
        return dict(cm=35, depth=0.3, width=0.17, fin=(120, 100, 60), paint=p, eye_iris=(170, 30, 30))
    if sid == "Walleye":
        def p(c, n, u, v):
            base = mix((235, 230, 205), (175, 155, 75), smooth(-0.6, -0.1, v))
            if v > 0.35 and math.sin(u * 10 + 1) > 0.5:
                return (85, 75, 40)  # dark saddles
            return base
        return dict(cm=52.5, depth=0.21, width=0.15, fin=(150, 135, 80), paint=p, eye_iris=(215, 215, 200), eye_ring=(70, 70, 60), eye_size=1.15, spiky=True, white_tail_tip=True)
    # Added overnight 2026-11-26 (second run): the nine new species and the Big Lake three.
    if sid == "Bowfin":
        def p(c, n, u, v):
            if (u + 0.62) ** 2 + ((v - 0.1) * 0.8) ** 2 < 0.012:
                return (20, 25, 15)  # eyespot near the tail
            base = mix((205, 210, 160), (95, 110, 60), smooth(-0.6, 0.0, v))
            if math.sin(u * 19 + v * 6) > 0.75:
                base = mix(base, (60, 70, 35), 0.5)  # mottling
            return base
        return dict(cm=65, depth=0.2, width=0.16, fin=(80, 100, 55), paint=p, dorsal=(0.1, -0.72, 0.3), fork=0.05)
    if sid == "LakeSturgeon":
        def p(c, n, u, v):
            base = mix((215, 210, 200), (100, 95, 85), smooth(-0.5, 0.1, v))
            for row in (0.85, 0.35, -0.3):
                if abs(v - row) < 0.07 and math.sin(u * 24) > 0.3:
                    return (190, 185, 165)  # rows of bony scutes
            return base
        return dict(cm=135, depth=0.14, width=0.16, fin=(95, 90, 80), paint=p, snout=1.3, flat_head=0.3, barbels=True, short_barbels=False, fork=0.5, dorsal=(-0.45, -0.7, 0.3))
    if sid == "CreekChub":
        def p(c, n, u, v):
            if abs(v - 0.02) < 0.09 and u < 0.85:
                return (50, 55, 50)  # dark side stripe
            return mix((225, 220, 200), (125, 120, 90), smooth(-0.4, 0.5, v))
        return dict(cm=17.5, depth=0.22, width=0.14, fin=(150, 140, 110), paint=p, fork=0.6)
    if sid == "RockBass":
        base = lambda c, n, u, v: mix((200, 170, 110), (100, 80, 45), smooth(-0.4, 0.7, v))
        return dict(cm=22.5, depth=0.45, width=0.17, fin=(110, 85, 50), paint=spots(45, (45, 35, 20), base, -0.6, 0.9, 0.07), spiky=True, eye_iris=(190, 30, 30))
    if sid == "BrookTrout":
        def p(c, n, u, v):
            if v < -0.45:
                return (225, 120, 50)  # orange belly
            if v > 0.3 and math.sin(u * 22) * math.sin(v * 14) > 0.35:
                return (190, 190, 130)  # pale worm marks on the back
            if -0.3 < v < 0.25 and math.sin(u * 17 + 2) > 0.9 and math.sin(v * 13) > 0.6:
                return (210, 40, 40)  # red spots
            return mix((105, 120, 90), (55, 70, 55), smooth(-0.2, 0.7, v))
        return dict(cm=29, depth=0.24, width=0.15, fin=(190, 95, 50), paint=p, adipose=True, fork=0.25, white_tail_tip=False)
    if sid == "BrownTrout":
        def p(c, n, u, v):
            if -0.25 < v < 0.2 and math.sin(u * 15 + 1) > 0.88 and math.sin(v * 11) > 0.5:
                return (200, 60, 40)  # red spots
            base = mix((240, 215, 140), (150, 110, 55), smooth(-0.6, 0.2, v))
            if v > -0.2 and math.sin(u * 21) * math.sin(v * 17) > 0.6:
                return (40, 30, 20)  # black spots
            return base
        return dict(cm=57.5, depth=0.24, width=0.16, fin=(150, 115, 65), paint=p, adipose=True, fork=0.2)
    if sid == "WhiteBass":
        def p(c, n, u, v):
            base = mix((240, 240, 240), (150, 160, 175), smooth(-0.3, 0.8, v))
            for row in (0.45, 0.2, -0.05):
                if abs(v - row) < 0.035:
                    return mix(base, (70, 75, 85), 0.7)  # thin dark stripes
            return base
        return dict(cm=30, depth=0.35, width=0.14, fin=(170, 175, 185), paint=p, spiky=True, fork=0.7)
    if sid == "LakeTrout":
        base = lambda c, n, u, v: mix((225, 225, 215), (85, 100, 90), smooth(-0.5, 0.2, v))
        return dict(cm=65, depth=0.2, width=0.15, fin=(90, 105, 95), paint=spots(70, (215, 215, 195), base, -0.4, 0.95, 0.055), adipose=True, fork=0.95)
    if sid == "Muskellunge":
        def p(c, n, u, v):
            base = mix((225, 225, 195), (150, 140, 90), smooth(-0.6, 0.3, v))
            if v > -0.45 and math.sin(u * 20) > 0.55:
                return (85, 80, 50)  # dark vertical bars
            return base
        return dict(cm=95, depth=0.16, width=0.13, fin=(160, 110, 70), paint=p, snout=1.4, dorsal=(-0.45, -0.75, 0.6), flat_head=0.3)
    if sid == "LakeWhitefish":
        base = lambda c, n, u, v: mix((240, 240, 235), (125, 135, 140), smooth(0.0, 0.9, v))
        return dict(cm=45, depth=0.27, width=0.14, fin=(180, 180, 175), paint=base, snout=0.8, adipose=True, fork=0.8)
    if sid == "FreshwaterDrum":
        base = lambda c, n, u, v: mix((225, 225, 220), (85, 95, 120), smooth(-0.4, 0.6, v))
        return dict(cm=42.5, depth=0.42, width=0.15, fin=(150, 155, 160), paint=base, spiky=True, fork=0.05, dorsal=(0.3, -0.6, 0.35))
    if sid == "Burbot":
        def p(c, n, u, v):
            base = mix((210, 195, 140), (120, 105, 60), smooth(-0.5, 0.2, v))
            if math.sin(u * 23 + v * 9) * math.sin(v * 15 - u * 5) > 0.35:
                return (60, 50, 30)  # mottling
            return base
        return dict(cm=57.5, depth=0.15, width=0.14, fin=(110, 95, 55), paint=p, dorsal=(-0.05, -0.85, 0.2), fork=0.05, barbels=True, short_barbels=True)
    # Mythics (tied to weather): pale, golden and striped versions of real fish.
    if sid == "AlbinoCatfish":
        base = lambda c, n, u, v: mix((250, 240, 240), (235, 205, 205), smooth(-0.5, 0.4, v))
        return dict(cm=75, depth=0.2, width=0.2, fin=(240, 200, 200), paint=base, barbels=True, flat_head=0.4, adipose=True, fork=0.9, eye_iris=(200, 50, 60), barbel_color=(235, 190, 190))
    if sid == "GoldenTrout":
        base = lambda c, n, u, v: (235, 120, 50) if -0.18 < v < 0.14 else mix((250, 225, 120), (235, 180, 40), smooth(-0.6, 0.5, v))
        return dict(cm=42.5, depth=0.25, width=0.15, fin=(240, 170, 60), paint=base, adipose=True, fork=0.3)
    if sid == "TigerMuskie":
        def p(c, n, u, v):
            base = mix((230, 225, 190), (165, 150, 80), smooth(-0.6, 0.3, v))
            if v > -0.5 and math.sin(u * 18 + math.sin(v * 6) * 1.2) > 0.25:
                return (60, 55, 30)  # bold wavy tiger bars
            return base
        return dict(cm=110, depth=0.16, width=0.13, fin=(170, 120, 70), paint=p, snout=1.4, dorsal=(-0.45, -0.75, 0.6), flat_head=0.3)
    raise KeyError(sid)


def build_fish(sid):
    reset()
    s = species(sid)
    L = s["cm"] / CM_PER_STUD
    o, H, W = body(L, s["depth"], s["width"], snout=s.get("snout", 1.0), flat_head=s.get("flat_head", 0.0))
    o.name = sid + "Body"
    painter = s["paint"]
    paint(o, lambda c, n: painter(c, n, c.x / (L / 2), c.z / (H / 2 + 1e-6)))
    fin = mat(f"fin{sid}", s["fin"])
    t = tail(L, H, fin, fork=s.get("fork", 0.6))
    if s.get("white_tail_tip"):
        paint(t, lambda c, n: (240, 240, 235) if c.z < -H * 0.3 else s["fin"])
    d = s.get("dorsal", (0.35, -0.3, 0.35))
    dorsal(L, H, fin, start=d[0], end=d[1], height=d[2], spiky=s.get("spiky", False))
    if s.get("adipose"):
        ta = H / 2 * taper_at(-0.64)
        plate([(-L * 0.28, ta * 0.8), (-L * 0.32, ta * 1.25), (-L * 0.36, ta * 0.75)], L * 0.02, fin, name="adipose")
    fins_lower(L, H, fin)
    eye(L, H, L * 0.38 * s.get("snout", 1.0) ** 0.5, H * 0.12, iris=s.get("eye_iris", (20, 20, 20)), ring=s.get("eye_ring", (230, 215, 150)), size=s.get("eye_size", 1.0), body_obj=o)
    if s.get("barbels"):
        n = 2 if s.get("short_barbels") else 4
        for k in range(n):
            sgn = 1 if k % 2 else -1
            ln = L * (0.06 if s.get("short_barbels") else 0.16)
            cyl(L * 0.006 + 0.01, ln, (L * 0.5 - ln * 0.3, sgn * W * 0.25, -H * 0.1 - (k // 2) * H * 0.1), mat("barbel" + sid, s.get("barbel_color", (50, 50, 55))), rot=(0, 1.9, sgn * 0.6), verts=4)
    return L


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ids = [a for a in args if not a.startswith("-") and not a.endswith(".py")] or ["Bluegill", "Pumpkinseed", "YellowPerch", "BlackCrappie", "LargemouthBass", "ChannelCatfish",
                           "CommonCarp", "NorthernPike", "RainbowTrout", "SmallmouthBass", "Walleye",
                           "Bowfin", "LakeSturgeon", "CreekChub", "RockBass", "BrookTrout", "BrownTrout",
                           "WhiteBass", "LakeTrout", "Muskellunge", "LakeWhitefish", "FreshwaterDrum", "Burbot",
                           "AlbinoCatfish", "GoldenTrout", "TigerMuskie"]
    for sid in ids:
        L = build_fish(sid)
        finish(sid, replaces="FishShadows blobs and the catch held on the line (FishingService.showCatch)",
               notes=f"Built at the species' average length, {L * CM_PER_STUD:.1f} cm = {L:.2f} studs (1 stud = 12 cm). Scale by caught cm / average cm. Head along +X.",
               view=(0, 12), max_tris=4000)
