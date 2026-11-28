"""Material sheet: every family on a sphere, on the thing it is for, and at 30 studs.

    python art/scripts/material_sheet.py                       # writes art/textures/sheet-n0.png
    python art/scripts/material_sheet.py --sheet n1            # the N1 families, art/textures/sheet-n1.png
    python art/scripts/material_sheet.py --sheet n3            # Cedar Creek, art/textures/sheet-n3.png
    python art/scripts/material_sheet.py --out artifacts/n0/sheet-test.png --samples 32
    python art/scripts/material_sheet.py --only meadow_grass wet_sand
    python art/scripts/material_sheet.py --dir rope=artifacts/textures_candidates/rope__Rope003

The same file runs twice. Plain Python (the driver) reads `texture_families.json`, starts
Blender headless on this file to render one small picture per cell, then pastes the cells
into one labelled sheet with Pillow. Inside Blender (the `bpy` half) it builds each cell:

  row 1  sphere, colour map                    (3 studs across, seen from about 8 studs)
  row 2  the thing the family is for, colour   (dock section, rope coil, awning, ground, boulders, fish,
                                                trunk and log, tree and bush, shed roof, board wall, jon boat;
                                                the two lake beds lie half under a sheet of lake water)
  row 3  the same thing 30 studs away, with a bobber for scale (a crop of the screen)
  row 4  sphere, NEUTRAL map times sample colour A (how Layer B and tinted terrain slots look)
  row 5  the thing, NEUTRAL map times sample colour B (a second hue, to show the map carries any colour)

An effect (`effects` in the table: white_water) gets a column of its own after the families:
the foam laid over creek water, a riffle built from the sheet's own families with foam strips
and spray on it, the same riffle at 30 studs, the spray sprite, and the foam's alpha tiled.

Units: 1 Blender unit = 1 stud. Maps repeat every `studs_per_tile` studs, as a Roblox
MaterialVariant would. A family belongs to the sheet named in its `sheet` field in the
table (n0 if it has none). Light: one warm sun at 40 degrees and a plain sky, Standard view
transform, exposure set so a flat sunlit surface shows about its own colour. This is a
judging tool, not the engine: final say is the patch in Studio.

Blender path: the BLENDER environment variable, or the default install folder below.
"""

from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
TABLE = Path(__file__).resolve().with_name("texture_families.json")
BLENDER = os.environ.get("BLENDER", r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe")

# sample colours for the neutral rows: (A, B) per family, sRGB 0..255
SAMPLES = {
    "weathered_plank": ([122, 104, 86], [150, 108, 74]),
    "rope": ([176, 152, 112], [62, 82, 112]),
    "canvas": ([198, 188, 160], [160, 72, 60]),
    "meadow_grass": ([104, 122, 62], [150, 128, 58]),
    "wet_sand": ([110, 96, 74], [84, 72, 60]),
    "shore_stone": ([118, 112, 102], [70, 78, 84]),
    "fish_skin": ([92, 120, 88], [214, 156, 62]),
    "forest_floor": ([92, 72, 48], [70, 60, 44]),
    "lake_mud": ([70, 62, 46], [84, 72, 60]),
    "footpath_gravel": ([140, 128, 108], [150, 140, 134]),
    "shore_sand": ([186, 170, 128], [176, 142, 132]),
    "deep_bed": ([40, 46, 40], [32, 40, 52]),
    "bark": ([104, 82, 62], [206, 200, 188]),            # pine brown, birch white
    "leaf_needle": ([62, 92, 48], [176, 132, 48]),       # summer green, autumn gold
    "tin_roof": ([150, 152, 150], [128, 58, 48]),        # galvanised, barn red
    "painted_wood": ([196, 190, 176], [62, 98, 104]),    # off-white, boathouse teal
    "aluminium": ([200, 204, 208], [96, 112, 92]),       # bare, olive paint worn thin
    "creek_pebble": ([126, 116, 100], [112, 114, 112]),  # warm bar gravel, cold grey shingle
    "wet_slate": ([70, 78, 84], [104, 98, 88]),          # wet slate, the same rock dry and warm
    "moss": ([78, 104, 52], [112, 118, 50]),             # shade moss, sunlit yellow moss
    "cedar_bark": ([110, 70, 50], [136, 124, 112]),      # red cedar, old silvered cedar
}
# lake water over the beds that are only ever seen through it: (tint, how far the bed lies under)
UNDER_WATER = {"lake_mud": ([26, 66, 62], 0.8), "deep_bed": ([26, 66, 62], 0.45),
               "creek_pebble": ([64, 84, 58], 0.92)}      # the creek is very clear
CREEK_WATER = ([64, 84, 58], 0.92)
WATER_LOOK = {"creek_pebble": {"body_mix": 0.07, "tint": 0.4}}   # clear creek: little body, weak tint
# what the effect column shows, row by row (the row labels on the left are for the families)
EFFECT_ROWS = ["foam over creek water, 2 x 2 tiles", "riffle: foam strips and spray",
               "the riffle 30 studs away", "spray sprite, and thrown by an emitter",
               "foam alpha, 3 x 3 tiles (seam check)"]
ROWS = [
    ("sphere", "color", "sphere, colour map"),
    ("object", "color", "in use, colour map"),
    ("far", "color", "30 studs away, bobber for scale"),
    ("sphere", "neutral_a", "sphere, neutral x colour A"),
    ("object", "neutral_b", "in use, neutral x colour B"),
]

try:
    import bpy  # noqa: F401
    IN_BLENDER = True
except ModuleNotFoundError:
    IN_BLENDER = False


# ============================================================================
# Blender half
# ============================================================================

def srgb_to_linear(c: float) -> float:
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def blender_main(job_path: str) -> None:
    import bmesh
    import bpy
    from mathutils import Vector, noise

    with open(job_path, "r", encoding="utf-8") as f:
        job = json.load(f)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
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
    scene.cycles.samples = int(job.get("samples", 64))
    scene.cycles.use_denoising = True
    scene.render.resolution_x = scene.render.resolution_y = int(job["cell"])
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = -0.45
    scene.render.film_transparent = False

    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.80, 0.88, 1.0, 1.0)
    bg.inputs[1].default_value = 0.8
    scene.world = world

    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 3.6
    sun_data.color = (1.0, 0.96, 0.88)
    sun_data.angle = math.radians(1.5)
    sun = bpy.data.objects.new("Sun", sun_data)
    scene.collection.objects.link(sun)
    # sun 40 degrees up, coming from the front left
    sun.rotation_euler = (math.radians(50), 0.0, math.radians(-40))

    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam

    def look(loc, target, lens):
        cam.location = Vector(loc)
        d = Vector(target) - Vector(loc)
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        cam_data.lens = lens
        cam_data.clip_end = 500

    # ---------------- materials ----------------
    images = {}

    def image(path, non_color):
        key = (path, non_color)
        if key not in images:
            img = bpy.data.images.load(path)
            if non_color:
                img.colorspace_settings.name = "Non-Color"
            images[key] = img
        return images[key]

    def family_material(fam, mode):
        mat = bpy.data.materials.new(f"{fam['slug']}_{mode}")
        mat.use_nodes = True
        nt = mat.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        uv = nt.nodes.new("ShaderNodeUVMap")
        uv.uv_map = "UVMap"

        def tex(path, non_color):
            node = nt.nodes.new("ShaderNodeTexImage")
            node.image = image(path, non_color)
            nt.links.new(uv.outputs[0], node.inputs[0])
            return node

        if mode == "color":
            col = tex(fam["color"], False)
            nt.links.new(col.outputs[0], bsdf.inputs["Base Color"])
        else:
            col = tex(fam["neutral"], False)
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs[0].default_value = 1.0
            rgb = fam["sample_a"] if mode == "neutral_a" else fam["sample_b"]
            mix.inputs[7].default_value = tuple(srgb_to_linear(c) for c in rgb) + (1.0,)
            nt.links.new(col.outputs[0], mix.inputs[6])
            nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        rough = tex(fam["rough"], True)
        nt.links.new(rough.outputs[0], bsdf.inputs["Roughness"])
        if fam.get("metal"):
            metal = tex(fam["metal"], True)
            nt.links.new(metal.outputs[0], bsdf.inputs["Metallic"])
        nrm = tex(fam["normal"], True)
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        nmap.uv_map = "UVMap"
        nt.links.new(nrm.outputs[0], nmap.inputs["Color"])
        nt.links.new(nmap.outputs[0], bsdf.inputs["Normal"])
        return mat

    def flat_material(name, rgb, rough=0.9):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = tuple(srgb_to_linear(c) for c in rgb) + (1.0,)
        bsdf.inputs["Roughness"].default_value = rough
        return mat

    def water_material(rgb, clear, body_mix=0.18, tint=0.65):
        """A stand-in for lake water seen from above: what is under it shows through, tinted
        and dimmed, with a little sky on top. `clear` is how much of the bed's light gets out,
        `tint` how strongly the water's own hue colours it, `body_mix` how much of the water's
        own colour lies over it (the clear creek asks for less of both)."""
        mat = bpy.data.materials.new("LakeWater")
        mat.use_nodes = True
        nt = mat.node_tree
        nt.nodes.remove(nt.nodes["Principled BSDF"])
        out_node = nt.nodes["Material Output"]
        through = nt.nodes.new("ShaderNodeBsdfTransparent")
        lin = [srgb_to_linear(c) for c in rgb]
        peak = max(lin)
        through.inputs["Color"].default_value = tuple(min(1.0, clear * (1.0 - tint + tint * c / peak)) for c in lin) + (1.0,)
        body = nt.nodes.new("ShaderNodeBsdfDiffuse")
        body.inputs["Color"].default_value = tuple(lin) + (1.0,)
        gloss = nt.nodes.new("ShaderNodeBsdfGlossy")
        gloss.inputs["Roughness"].default_value = 0.08
        mix1 = nt.nodes.new("ShaderNodeMixShader")
        mix1.inputs[0].default_value = body_mix
        nt.links.new(through.outputs[0], mix1.inputs[1])
        nt.links.new(body.outputs[0], mix1.inputs[2])
        mix2 = nt.nodes.new("ShaderNodeMixShader")
        mix2.inputs[0].default_value = 0.10
        nt.links.new(mix1.outputs[0], mix2.inputs[1])
        nt.links.new(gloss.outputs[0], mix2.inputs[2])
        nt.links.new(mix2.outputs[0], out_node.inputs["Surface"])
        return mat

    grey = flat_material("StageGrey", [150, 150, 150])
    cut_wood = flat_material("CutWood", [186, 160, 118], 0.8)
    trunk_brown = flat_material("TrunkBrown", [84, 66, 50], 0.9)
    wall_wood = flat_material("WallWood", [122, 104, 86], 0.85)
    bob_red = flat_material("BobberRed", [222, 44, 34], 0.35)
    bob_white = flat_material("BobberWhite", [245, 245, 240], 0.35)

    # ---------------- meshes ----------------
    made = []

    def finish(bm, name, mat, smooth):
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = smooth
        ob = bpy.data.objects.new(name, me)
        ob.data.materials.append(mat)
        scene.collection.objects.link(ob)
        made.append(ob)
        return ob

    def param_surface(name, mat, func, nu, nv, smooth=True):
        """func(u, v) -> ((x, y, z), (tex_u, tex_v)); u and v run 0..1."""
        bm = bmesh.new()
        layer = bm.loops.layers.uv.new("UVMap")
        grid, uvs = [], []
        for j in range(nv + 1):
            row, urow = [], []
            for i in range(nu + 1):
                pos, uv = func(i / nu, j / nv)
                row.append(bm.verts.new(pos))
                urow.append(uv)
            grid.append(row)
            uvs.append(urow)
        for j in range(nv):
            for i in range(nu):
                idx = [(j, i), (j, i + 1), (j + 1, i + 1), (j + 1, i)]
                try:
                    face = bm.faces.new([grid[a][b] for a, b in idx])
                except ValueError:
                    continue
                for loop, (a, b) in zip(face.loops, idx):
                    loop[layer].uv = uvs[a][b]
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return finish(bm, name, mat, smooth)

    def box_uv(bm, spt):
        layer = bm.loops.layers.uv.new("UVMap")
        for face in bm.faces:
            n = face.normal
            ax = max(range(3), key=lambda k: abs(n[k]))
            for loop in face.loops:
                co = loop.vert.co
                if ax == 2:
                    uv = (co.x, co.y)
                elif ax == 1:
                    uv = (co.x, co.z)
                else:
                    uv = (co.y, co.z)
                loop[layer].uv = (uv[0] / spt, uv[1] / spt)

    def box(name, mat, size, center, spt):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * size[0] + center[0], v.co.y * size[1] + center[1],
                           v.co.z * size[2] + center[2]))
        bm.normal_update()
        box_uv(bm, spt)
        return finish(bm, name, mat, False)

    def boulder(name, mat, radius, center, spt, seed):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
        for v in bm.verts:
            d = v.co.normalized()
            k = 1.0 + 0.22 * noise.noise(d * 1.7 + Vector((seed, seed * 2.0, 0.0)))
            v.co = Vector((d.x * radius * k * 1.15 + center[0], d.y * radius * k + center[1],
                           max(d.z * radius * k * 0.75, -radius * 0.35) + center[2]))
        bm.normal_update()
        box_uv(bm, spt)
        return finish(bm, name, mat, False)

    def sphere(name, mat, radius, center, spt):
        def f(u, v):
            lon, lat = u * 2 * math.pi, (v - 0.5) * math.pi
            p = (center[0] + radius * math.cos(lat) * math.cos(lon),
                 center[1] + radius * math.cos(lat) * math.sin(lon),
                 center[2] + radius * math.sin(lat))
            return p, (u * 2 * math.pi * radius / spt, v * math.pi * radius / spt)
        return param_surface(name, mat, f, 64, 32)

    def ground(name, mat, size, spt, bumps):
        def f(u, v):
            x, y = (u - 0.5) * size, (v - 0.5) * size
            z = bumps * (math.sin(x * 0.21 + 1.0) * math.cos(y * 0.17) + 0.5 * math.sin(y * 0.33 + x * 0.1))
            return (x, y, z), (x / spt, y / spt)
        n = max(16, int(size / 1.5))
        return param_surface(name, mat, f, n, n)

    def bobber(center, r=0.3):
        def top(u, v):
            lon, lat = u * 2 * math.pi, v * 0.5 * math.pi
            return (center[0] + r * math.cos(lat) * math.cos(lon), center[1] + r * math.cos(lat) * math.sin(lon),
                    center[2] + r * math.sin(lat)), (u, v)
        def bottom(u, v):
            lon, lat = u * 2 * math.pi, -v * 0.5 * math.pi
            return (center[0] + r * math.cos(lat) * math.cos(lon), center[1] + r * math.cos(lat) * math.sin(lon),
                    center[2] + r * math.sin(lat)), (u, v)
        param_surface("BobTop", bob_red, top, 24, 8)
        param_surface("BobBottom", bob_white, bottom, 24, 8)

    def stage(size=120.0):
        return ground("Stage", grey, size, 1.0, 0.0)

    # ---------------- what each family is shown on ----------------
    def build_object(fam, mat, far):
        slug, spt = fam["slug"], fam["studs_per_tile"]
        if fam["kind"] == "terrain":
            size = 140.0 if far else 40.0
            ground("Patch", mat, size, spt, 0.35)
            if slug in UNDER_WATER:
                rgb, clear = UNDER_WATER[slug]
                water = water_material(rgb, clear, **WATER_LOOK.get(slug, {}))
                if far:                                  # all of it under water, the bobber floats
                    param_surface("Water", water, lambda u, v: (((u - 0.5) * size, (v - 0.5) * size, 0.9), (u, v)), 2, 2)
                else:                                    # right half under water, left half dry
                    param_surface("Water", water, lambda u, v: ((u * size * 0.5, (v - 0.5) * size, 0.9), (u, v)), 2, 2)
            if slug == "moss":                           # also a prop map: boulders and a log
                boulder("MossRockA", mat, 2.1, (-4.2, 3.0, 0.9), spt, 1.0)
                boulder("MossRockB", mat, 1.2, (4.4, 1.2, 0.5), spt, 2.3)
                def mlog(u, v):
                    a = u * 2 * math.pi
                    x = -1.5 + v * 7.0
                    return ((x, -3.4 + 0.2 * v + 0.6 * math.cos(a), 0.75 + 0.6 * math.sin(a)),
                            (a * 0.6 / spt, v * 7.0 / spt))
                param_surface("MossLog", mat, mlog, 14, 4, smooth=True)
            if slug == "wet_slate":                      # rock shelves and a boulder
                box("ShelfA", mat, (11.0, 7.0, 1.0), (-4.0, 3.5, 0.55), spt)
                box("ShelfB", mat, (7.0, 5.0, 0.8), (-2.5, 2.8, 1.45), spt)
                boulder("SlateRock", mat, 1.6, (4.6, -1.5, 0.7), spt, 3.1)
            return
        stage()
        if slug in ("bark", "cedar_bark"):
            def trunk(u, v):                             # grain (map V) runs up the trunk
                a = u * 2 * math.pi
                r = 0.95 - 0.15 * v
                return (-2.6 + r * math.cos(a), 0.8 + r * math.sin(a), v * 8.0), (a * 0.9 / spt, v * 8.0 / spt)
            param_surface("Trunk", mat, trunk, 16, 6, smooth=True)
            def log(u, v):                               # a felled log: grain runs along it
                a = u * 2 * math.pi
                x = -1.2 + v * 6.0
                return (x, -1.6 + 0.25 * v + 0.6 * math.cos(a), 0.6 + 0.6 * math.sin(a)), (a * 0.6 / spt, v * 6.0 / spt)
            param_surface("Log", mat, log, 14, 4, smooth=True)
            for x in (-1.2, 4.8):
                def cap(u, v, x=x):
                    a = u * 2 * math.pi
                    yy = -1.6 + 0.25 * ((x + 1.2) / 6.0)
                    return (x, yy + 0.6 * v * math.cos(a), 0.6 + 0.6 * v * math.sin(a)), (u, v)
                param_surface("LogEnd", cut_wood, cap, 14, 1, smooth=False)
            return
        if slug == "leaf_needle":
            def blob(name, radius, center, squash, seed):
                bm = bmesh.new()
                bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
                for v in bm.verts:
                    d = v.co.normalized()
                    k = 1.0 + 0.2 * noise.noise(d * 1.9 + Vector((seed, seed * 1.7, 0.3)))
                    v.co = Vector((d.x * radius * k + center[0], d.y * radius * k + center[1],
                                   d.z * radius * k * squash + center[2]))
                bm.normal_update()
                box_uv(bm, spt)
                return finish(bm, name, mat, False)
            # a broadleaf tree: three canopy blobs on a trunk
            box("TreeTrunk", trunk_brown, (0.7, 0.7, 4.0), (-3.2, 0.5, 2.0), 1.0)
            blob("CanopyA", 2.6, (-3.2, 0.5, 5.6), 0.8, 1.0)
            blob("CanopyB", 1.9, (-1.5, 0.0, 4.6), 0.8, 2.6)
            blob("CanopyC", 1.7, (-4.8, 1.0, 4.4), 0.8, 4.2)
            # a pine: three stacked low-poly cones
            box("PineTrunk", trunk_brown, (0.5, 0.5, 2.0), (3.2, 1.0, 1.0), 1.0)
            for k, (r, z0, hgt) in enumerate(((2.3, 1.4, 3.2), (1.8, 3.4, 2.8), (1.2, 5.2, 2.6))):
                bm = bmesh.new()
                bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=r, radius2=0.0, depth=hgt)
                for v in bm.verts:
                    v.co = Vector((v.co.x + 3.2, v.co.y + 1.0, v.co.z + z0 + hgt * 0.5))
                bm.normal_update()
                box_uv(bm, spt)
                finish(bm, f"Pine{k}", mat, False)
            # a bush and a clump of reeds (flat blades)
            blob("Bush", 1.2, (0.6, -2.6, 0.8), 0.7, 6.3)
            return
        if slug == "tin_roof":
            box("Walls", wall_wood, (7.0, 5.0, 3.4), (0.0, 0.0, 1.7), 4.0)
            for side in (-1.0, 1.0):
                def slope(u, v, side=side):              # map U along the ridge, V down the slope
                    x = (u - 0.5) * 8.0
                    run = v * 3.4
                    return (x, side * run, 5.2 - run * 0.55), (x / spt, run * 1.14 / spt)
                param_surface("Roof", mat, slope, 2, 2, smooth=False)
            for gx in (-3.5, 3.5):
                param_surface("Gable", wall_wood,
                              lambda u, v, gx=gx: ((gx, (u - 0.5) * 5.0 * (1.0 - v), 3.4 + v * 1.8), (u, v)),
                              1, 1, smooth=False)
            return
        if slug == "painted_wood":
            box("Wall", mat, (9.0, 0.5, 5.0), (0.0, 1.0, 2.5), spt)       # boards run up the wall
            box("Post", wall_wood, (0.4, 0.4, 3.2), (2.2, -2.2, 1.6), 1.0)
            box("Sign", mat, (3.6, 0.3, 1.6), (2.2, -2.45, 2.9), spt)
            box("Crate", mat, (1.8, 1.8, 1.8), (-2.6, -1.8, 0.9), spt)
            return
        if slug == "aluminium":
            length, beam, depth = 11.0, 4.2, 1.5
            def hull(u, v):                              # a flat-bottomed jon boat, bow toward +x
                rise = max(0.0, (v - 0.62) / 0.38)
                half = 0.5 * beam * (1.0 - 0.3 * rise * rise)
                z0 = 0.25 + 1.05 * rise * rise
                x = (v - 0.5) * length
                pts = [(-half, depth), (-half * 0.8, z0), (half * 0.8, z0), (half, depth)]
                t = u * 3.0
                i = min(int(t), 2)
                f = t - i
                y = pts[i][0] + (pts[i + 1][0] - pts[i][0]) * f
                z = pts[i][1] + (pts[i + 1][1] - pts[i][1]) * f
                return (x, y, z), (x / spt, u * (beam + 2.0) / spt)
            param_surface("Hull", mat, hull, 3, 24, smooth=False)
            box("Transom", mat, (0.12, beam * 0.9, depth - 0.3), (-0.5 * length, 0.0, 0.25 + (depth - 0.3) * 0.5), spt)
            for bx in (-2.6, 1.2):
                box("Bench", mat, (1.0, beam * 0.86, 0.12), (bx, 0.0, 1.05), spt)
            return
        if slug == "weathered_plank":
            box("Deck", mat, (12.0, 6.0, 0.4), (0.0, 0.0, 1.6), spt)
            for sx in (-5.4, 5.4):
                for sy in (-2.6, 2.6):
                    box("Post", mat, (0.7, 0.7, 2.6), (sx, sy, 1.3), spt)
        elif slug == "rope":
            big, small = 1.5, 0.28
            for k in range(3):
                def f(u, v, k=k):
                    a, b = u * 2 * math.pi, v * 2 * math.pi
                    rr = big - 0.08 * k + small * math.cos(b)
                    p = (rr * math.cos(a), rr * math.sin(a), small + k * small * 1.75 + small * math.sin(b))
                    return p, (u * 2 * math.pi * big / spt, v * 2 * math.pi * small / spt)
                param_surface(f"Coil{k}", mat, f, 96, 16)
            def line(u, v):
                b = v * 2 * math.pi
                x = -5.0 + u * 10.0
                p = (x, -2.6 + 0.25 * math.sin(x * 0.9), small + small * math.sin(b) * 1.0 + 0.0)
                return (p[0], p[1] + small * math.cos(b), p[2]), (u * 10.0 / spt, v * 2 * math.pi * small / spt)
            param_surface("Line", mat, line, 64, 16)
        elif slug == "canvas":
            def f(u, v):
                x, y = (u - 0.5) * 8.0, (v - 0.5) * 5.0
                z = 3.0 + 0.45 * (v - 0.5) * 5.0 - 0.18 * math.cos(u * 6 * math.pi) * (0.3 + v)
                return (x, y, z), (x / spt, y / spt)
            param_surface("Awning", mat, f, 96, 24)
            for sx in (-3.8, 3.8):
                box("Pole", grey, (0.25, 0.25, 4.4), (sx, 2.3, 2.2), 1.0)
        elif slug == "shore_stone":
            boulder("RockA", mat, 2.2, (-1.2, 0.6, 1.0), spt, 1.0)
            boulder("RockB", mat, 1.3, (2.4, -0.8, 0.55), spt, 2.3)
            boulder("RockC", mat, 0.8, (0.6, -2.4, 0.35), spt, 4.1)
        elif slug == "fish_skin":
            length, height, width = 3.2, 1.25, 0.6
            def body(u, v):
                a = v * math.pi                      # head (+x) to tail (-x)
                b = u * 2 * math.pi
                taper = math.sin(a) ** 0.8
                p = (0.5 * length * math.cos(a), 0.5 * width * taper * math.cos(b),
                     1.6 + 0.5 * height * taper * math.sin(b))
                girth = math.pi * (height + width) * 0.5
                return p, ((1.0 - v) * length / spt, u * girth / spt)
            param_surface("Body", mat, body, 48, 48)
            def tail(u, v):
                x = -0.5 * length + 0.15 - v * 0.9
                p = (x, 0.04 * (1 - 2 * (u > 0.5)) * 0.0, 1.6 + (u - 0.5) * (0.25 + v * 1.1))
                return p, ((x + length) / spt, (u - 0.5) * 1.2 / spt)
            param_surface("Tail", mat, tail, 8, 8)

    def camera_for(fam, kind):
        slug = fam["slug"]
        if kind == "sphere":
            look((0.0, -8.0, 3.2), (0.0, 0.0, 1.5), 60)
        elif kind == "object":
            if fam["kind"] == "terrain":
                look((0.0, -13.0, 5.5), (0.0, 0.0, 0.3), 35)
            elif slug == "weathered_plank":
                look((9.0, -15.0, 8.0), (0.0, 0.0, 1.0), 42)
            elif slug == "rope":
                look((2.5, -7.0, 4.2), (0.0, -0.6, 0.5), 45)
            elif slug == "canvas":
                look((5.5, -11.0, 6.5), (0.0, 0.0, 2.8), 42)
            elif slug == "shore_stone":
                look((3.0, -9.0, 3.6), (0.4, -0.4, 0.9), 45)
            elif slug in ("bark", "cedar_bark"):
                look((5.5, -9.5, 4.2), (0.2, -0.4, 2.2), 40)
            elif slug == "leaf_needle":
                look((3.0, -16.0, 6.0), (-0.2, 0.0, 3.4), 40)
            elif slug == "tin_roof":
                look((8.0, -13.0, 9.0), (0.0, 0.0, 2.6), 40)
            elif slug == "painted_wood":
                look((3.5, -10.5, 4.2), (0.0, 0.0, 2.3), 38)
            elif slug == "aluminium":
                look((7.5, -11.0, 6.5), (0.0, 0.0, 0.8), 42)
            else:
                look((1.2, -6.0, 2.4), (0.0, 0.0, 1.6), 55)
        else:  # far: 30 studs, a crop of the screen
            tall = {"bark": 3.0, "cedar_bark": 3.0, "leaf_needle": 3.4, "tin_roof": 2.6, "painted_wood": 2.3}
            target = (0.0, 0.0, 0.4 if fam["kind"] == "terrain" else tall.get(slug, 1.4))
            look((8.0, -28.0, 7.0), target, 85)

    # ---------------- the riffle, for the white water column ----------------
    def alpha_material(name, path, emit=0.0, fade=None):
        """White, with the picture's alpha: a stand-in for a Beam, Texture or particle.
        fade = (head, tail): the strip fades in over `head` and out over `tail` of its length
        (the object's Y extent), as a Beam's Transparency sequence would."""
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        nt = mat.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (0.9, 0.9, 0.9, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.8
        uv = nt.nodes.new("ShaderNodeUVMap")
        uv.uv_map = "UVMap"
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = image(path, False)
        nt.links.new(uv.outputs[0], node.inputs[0])
        alpha_out = node.outputs["Alpha"]
        if fade:
            coord = nt.nodes.new("ShaderNodeTexCoord")
            sep = nt.nodes.new("ShaderNodeSeparateXYZ")
            nt.links.new(coord.outputs["Generated"], sep.inputs[0])
            for lo_v, hi_v in ((0.0, fade[1]), (1.0, 1.0 - fade[0])):   # tail (low Y), then head
                ramp = nt.nodes.new("ShaderNodeMapRange")
                ramp.interpolation_type = "SMOOTHSTEP"
                ramp.inputs["From Min"].default_value = lo_v
                ramp.inputs["From Max"].default_value = hi_v
                nt.links.new(sep.outputs["Y"], ramp.inputs["Value"])
                mul = nt.nodes.new("ShaderNodeMath")
                mul.operation = "MULTIPLY"
                nt.links.new(alpha_out, mul.inputs[0])
                nt.links.new(ramp.outputs["Result"], mul.inputs[1])
                alpha_out = mul.outputs[0]
        nt.links.new(alpha_out, bsdf.inputs["Alpha"])
        if emit > 0:
            bsdf.inputs["Emission Color"].default_value = (1.0, 1.0, 1.0, 1.0)
            bsdf.inputs["Emission Strength"].default_value = emit
        return mat

    def build_riffle(eff, cast, far):
        """A creek riffle seen looking upstream: pebble bed under clear water, a gravel bar on
        the left, a mossy cut bank and cedar trunks on the right, slate rocks with moss caps
        across the drop, foam strips running through the gaps and spray at their feet."""
        mats = {k: family_material(f, "color") for k, f in cast.items()}
        spt = {k: f["studs_per_tile"] for k, f in cast.items()}
        foam = alpha_material("Foam", eff["foam"], emit=0.15, fade=(0.08, 0.45))
        spray = alpha_material("Spray", eff["spray"], emit=0.15)
        half = 24.0
        lip, foot, hi, lo = 0.0, -2.6, 1.0, 0.42          # the drop: y of lip and foot, water heights

        def step(t):
            t = min(max(t, 0.0), 1.0)
            return t * t * (3.0 - 2.0 * t)

        def surf(y):
            return hi - (hi - lo) * step((lip - y) / (lip - foot))

        def bed(u, v):
            x, y = (u - 0.5) * 2 * half, (v - 0.5) * 2 * half
            z = surf(y) - 0.75 + 0.08 * math.sin(x * 0.9 + y * 0.4) + 1.9 * step((-x - 6.5) / 6.0)
            return (x, y, z), (x / spt["creek_pebble"], y / spt["creek_pebble"])
        param_surface("Bed", mats["creek_pebble"], bed, 64, 64)

        def water(u, v):
            x, y = -half + u * (half + 9.5), (v - 0.5) * 2 * half
            return (x, y, surf(y)), (u, v)
        rgb, clearness = CREEK_WATER
        param_surface("Water", water_material(rgb, clearness, **WATER_LOOK["creek_pebble"]), water, 2, 96)

        def bank(u, v):                                   # the cut bank, moss over the top
            x, y = 8.5 + u * (half - 8.5), (v - 0.5) * 2 * half
            z = -0.4 + 3.0 * step(u * 5.0) + 0.25 * math.sin(y * 0.3 + 1.0) * step(u * 5.0)
            return (x, y, z), (x / spt["moss"], y / spt["moss"])
        param_surface("Bank", mats["moss"], bank, 24, 32)

        for k, (tx, ty, tr) in enumerate(((12.5, 3.5, 1.0), (15.5, -5.0, 1.25), (11.5, 13.0, 0.85))):
            def trunk(u, v, tx=tx, ty=ty, tr=tr):
                a = u * 2 * math.pi
                r = tr * (1.0 - 0.12 * v) * (1.0 + 0.5 * max(0.0, 0.12 - v) / 0.12)   # a flare at the root
                return ((tx + r * math.cos(a), ty + r * math.sin(a), 2.2 + v * 14.0),
                        (a * tr / spt["cedar_bark"], v * 14.0 / spt["cedar_bark"]))
            param_surface(f"Cedar{k}", mats["cedar_bark"], trunk, 16, 8, smooth=True)

        rocks = ((-5.6, 0.2, 1.5), (-1.7, -0.4, 1.25), (2.1, 0.1, 1.6), (5.9, -0.5, 1.35), (8.2, 0.6, 1.5))
        for k, (rx, ry, rr) in enumerate(rocks):
            boulder(f"Rock{k}", mats["wet_slate"], rr, (rx, ry, 0.55), spt["wet_slate"], 1.0 + 1.7 * k)
            if k != 1:
                boulder(f"Cap{k}", mats["moss"], rr * 0.74, (rx + 0.1, ry + 0.25, 0.55 + rr * 0.42),
                        spt["moss"], 5.0 + 1.3 * k)
        boulder("PoolRock", mats["wet_slate"], 1.1, (-2.5, -9.5, 0.2), spt["wet_slate"], 9.0)

        tex_len = 6.0                                     # studs of water one foam tile covers
        for k, (gx, gw) in enumerate(((-3.7, 1.9), (0.2, 1.7), (4.0, 1.8), (-8.3, 1.5))):
            def strip(u, v, gx=gx, gw=gw, k=k):           # U of the picture runs with the flow
                y = 1.2 - v * 9.5
                w = gw * (1.0 + 0.9 * v)
                x = gx + (u - 0.5) * w + 0.5 * math.sin(v * 3.0 + k)
                return (x, y, surf(y) + 0.05), (v * 9.5 / tex_len + 0.37 * k, u)
            param_surface(f"Foam{k}", foam, strip, 2, 48, smooth=True)

            def strip2(u, v, gx=gx, gw=gw, k=k):          # a shorter second layer over the drop
                y = 0.6 - v * 5.0
                w = gw * (0.8 + 0.5 * v)
                x = gx + (u - 0.5) * w + 0.5 * math.sin((0.6 - y + 1.2) / 9.5 * 3.0 + k)
                return (x, y, surf(y) + 0.09), (v * 5.0 / tex_len + 0.61 * k + 0.5, u)
            param_surface(f"FoamTop{k}", foam, strip2, 2, 32, smooth=True)
            for j in range(3):                            # spray where the strip lands
                sx, sy, sz = gx + (j - 1) * 0.55, foot + 0.5 - 0.3 * j, lo + 0.5 + 0.22 * ((j + k) % 3)
                size = 1.5 + 0.35 * ((j + 2 * k) % 3)
                def puff(u, v, sx=sx, sy=sy, sz=sz, size=size):
                    return (sx + (u - 0.5) * size, sy - (v - 0.5) * size * 0.35, sz + (v - 0.5) * size), (u, v)
                param_surface(f"Spray{k}{j}", spray, puff, 1, 1, smooth=False)
        if far:
            bobber((1.5, -8.0, lo))

    def clear():
        for ob in made:
            me = ob.data
            bpy.data.objects.remove(ob, do_unlink=True)
            if me.users == 0:
                bpy.data.meshes.remove(me)
        made.clear()

    out_dir = Path(job["cells_dir"])
    out_dir.mkdir(parents=True, exist_ok=True)
    for fam in job["families"]:
        mats = {}
        for kind, mode, _ in ROWS:
            if mode not in mats:
                mats[mode] = family_material(fam, mode)
            mat = mats[mode]
            if kind == "sphere":
                stage()
                sphere("Ball", mat, 1.5, (0.0, 0.0, 1.5), fam["studs_per_tile"])
            else:
                build_object(fam, mat, kind == "far")
                if kind == "far":
                    z = 0.55 if fam["kind"] == "terrain" else (2.1 if fam["slug"] == "weathered_plank" else 0.3)
                    if fam["slug"] in UNDER_WATER:
                        z = 0.9
                    pos = (0.0, 0.0, z) if fam["kind"] == "terrain" or fam["slug"] == "weathered_plank" else (-3.6, -3.4, 0.3)
                    bobber(pos)
            camera_for(fam, kind)
            scene.render.filepath = str(out_dir / f"{fam['slug']}__{kind}__{mode}.png")
            bpy.ops.render.render(write_still=True)
            clear()
    for eff in job.get("effects", []):
        for kind in ("object", "far"):
            build_riffle(eff, job["cast"], kind == "far")
            if kind == "object":
                look((2.0, -16.5, 3.4), (2.0, -1.0, 1.3), 31)
            else:
                look((8.0, -29.0, 8.0), (0.5, -2.0, 0.6), 85)
            scene.render.filepath = str(out_dir / f"{eff['slug']}__{kind}__color.png")
            bpy.ops.render.render(write_still=True)
            clear()


# ============================================================================
# driver half (plain Python + Pillow)
# ============================================================================

def driver_main() -> None:
    import argparse
    import subprocess

    try:
        from PIL import Image, ImageDraw, ImageFont
    except ModuleNotFoundError:
        import site
        sys.path.append(site.getusersitepackages())
        from PIL import Image, ImageDraw, ImageFont

    ap = argparse.ArgumentParser(description="Render the material sheet.")
    ap.add_argument("--sheet", default="n0", help="which sheet: families whose `sheet` field says so (n0, n1)")
    ap.add_argument("--out", help="default art/textures/sheet-<sheet>.png")
    ap.add_argument("--only", nargs="*", help="only these families")
    ap.add_argument("--dir", action="append", default=[], metavar="FAMILY=FOLDER",
                    help="take a family's maps from another folder (a candidate run)")
    ap.add_argument("--spt", action="append", default=[], metavar="FAMILY=STUDS",
                    help="try another studs per tile for a family (this run only)")
    ap.add_argument("--cell", type=int, default=384)
    ap.add_argument("--samples", type=int, default=64)
    ap.add_argument("--title", help="default: Material families, <SHEET>")
    ap.add_argument("--compose-only", action="store_true", help="reuse the cells already rendered")
    args = ap.parse_args()

    with open(TABLE, "r", encoding="utf-8") as f:
        table = json.load(f)
    overrides = dict(d.split("=", 1) for d in args.dir)
    overrides_spt = {k: float(v) for k, v in (d.split("=", 1) for d in args.spt)}
    if not args.out:
        args.out = str(REPO / "art" / "textures" / f"sheet-{args.sheet}.png")
    if not args.title:
        args.title = f"Material families, {args.sheet.upper()}"
    def entry(slug, cfg):
        folder = Path(overrides.get(slug, REPO / "art" / "textures" / slug))
        if not folder.is_absolute():
            folder = REPO / folder
        meta = {}
        meta_path = folder / f"{slug}.json"
        if meta_path.exists():
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
        a, b = SAMPLES.get(slug, (cfg["target_rgb"], cfg["target_rgb"]))
        return {
            "slug": slug, "kind": cfg.get("kind", "prop"),
            "studs_per_tile": float(overrides_spt.get(slug, cfg.get("studs_per_tile", 4))),
            "source": meta.get("source", cfg["source"]), "target": cfg["target_rgb"],
            "sample_a": a, "sample_b": b,
            "color": str(folder / f"{slug}_color.png"), "neutral": str(folder / f"{slug}_neutral.png"),
            "normal": str(folder / f"{slug}_normal.png"), "rough": str(folder / f"{slug}_rough.png"),
            "metal": str(folder / f"{slug}_metal.png") if (folder / f"{slug}_metal.png").exists() else None,
        }

    fams = []
    for slug, cfg in table["families"].items():
        if args.only:
            if slug not in args.only:
                continue
        elif cfg.get("sheet", "n0") != args.sheet:
            continue
        fams.append(entry(slug, cfg))
    # effects (white water): plain alpha images, shown on a scene built from other families
    effects, cast = [], {}
    for slug, cfg in table.get("effects", {}).items():
        if args.only:
            if slug not in args.only:
                continue
        elif cfg.get("sheet", "n0") != args.sheet:
            continue
        folder = REPO / "art" / "textures" / slug
        effects.append({"slug": slug, "foam": str(folder / f"{slug}_foam.png"),
                        "spray": str(folder / f"{slug}_spray.png"), "source": cfg.get("source", "ours")})
        for need in cfg.get("shown_with", []):
            cast[need] = entry(need, table["families"][need])

    out = Path(args.out).resolve()
    cells_dir = REPO / "artifacts" / "sheet_cells" / out.stem
    job = {"families": fams, "cell": args.cell, "samples": args.samples, "cells_dir": str(cells_dir),
           "effects": effects, "cast": cast}
    cells_dir.mkdir(parents=True, exist_ok=True)
    job_path = cells_dir / "job.json"
    job_path.write_text(json.dumps(job, indent=1), encoding="utf-8")
    if not args.compose_only:
        subprocess.run([BLENDER, "-b", "--factory-startup", "-P", str(Path(__file__).resolve()),
                        "--", str(job_path)], check=True, stdout=subprocess.DEVNULL)

    def font(size):
        for name in ("segoeui.ttf", "arial.ttf", "DejaVuSans.ttf"):
            try:
                return ImageFont.truetype(name, size)
            except OSError:
                continue
        return ImageFont.load_default()

    cell, gap, left, top = args.cell, 6, 150, 112

    # the effect cells Blender does not render: flat pictures of the images themselves
    def effect_flats(eff):
        import random
        water = tuple(int(c * 0.7) for c in CREEK_WATER[0])
        foam_img = Image.open(eff["foam"]).convert("RGBA")
        spray_img = Image.open(eff["spray"]).convert("RGBA")

        def tiled(img, n, bg):
            small = img.resize((cell // n, cell // n), Image.LANCZOS)
            out_img = Image.new("RGBA", (cell, cell), bg + (255,))
            for iy in range(n + 1):
                for ix in range(n + 1):
                    out_img.alpha_composite(small, (ix * (cell // n), iy * (cell // n)))
            return out_img.convert("RGB")
        tiled(foam_img, 2, water).save(cells_dir / f"{eff['slug']}__sphere__color.png")
        puffs = Image.new("RGBA", (cell, cell), water + (255,))
        puffs.alpha_composite(spray_img.resize((cell // 2, cell // 2), Image.LANCZOS), (4, 4))
        puffs.alpha_composite(spray_img, (cell // 2 + 30, 30))        # 1 : 1
        rnd = random.Random(5)
        for _ in range(26):
            sz = rnd.randint(cell // 9, cell // 4)
            puff = spray_img.resize((sz, sz), Image.LANCZOS)
            puff.putalpha(puff.getchannel("A").point(lambda v, k=rnd.uniform(0.35, 0.9): int(v * k)))
            puffs.alpha_composite(puff, (rnd.randint(0, cell - sz), rnd.randint(cell // 2, cell - sz - 24)))
        puffs.convert("RGB").save(cells_dir / f"{eff['slug']}__sphere__neutral_a.png")
        alpha = Image.merge("RGBA", [foam_img.getchannel("A")] * 3 + [Image.new("L", foam_img.size, 255)])
        tiled(alpha, 3, (0, 0, 0)).save(cells_dir / f"{eff['slug']}__object__neutral_b.png")

    for eff in effects:
        effect_flats(eff)
    columns = fams + effects
    width = left + len(columns) * (cell + gap) + gap
    height = top + len(ROWS) * (cell + gap) + gap
    sheet = Image.new("RGB", (width, height), (24, 24, 26))
    draw = ImageDraw.Draw(sheet)
    f_big, f_mid, f_small = font(26), font(17), font(13)
    draw.text((12, 10), args.title, font=f_big, fill=(240, 240, 240))
    for c, fam in enumerate(columns):
        x = left + c * (cell + gap)
        draw.text((x + 2, 46), fam["slug"], font=f_mid, fill=(240, 240, 240))
        if fam in effects:
            foam_size = Image.open(fam["foam"]).size
            spray_size = Image.open(fam["spray"]).size
            draw.text((x + 2, 68), f"{fam['source']}  |  foam {foam_size[0]} x {foam_size[1]}, spray "
                      f"{spray_size[0]} x {spray_size[1]}, RGBA", font=f_small, fill=(180, 180, 180))
            draw.rectangle((x + 2, 88, x + 24, 104), fill=tuple(CREEK_WATER[0]), outline=(90, 90, 90))
            draw.text((x + 29, 88), "creek water", font=f_small, fill=(180, 180, 180))
            for r, (kind, mode, _) in enumerate(ROWS):
                cell_path = cells_dir / f"{fam['slug']}__{kind}__{mode}.png"
                y = top + r * (cell + gap)
                if cell_path.exists():
                    sheet.paste(Image.open(cell_path).convert("RGB").resize((cell, cell), Image.LANCZOS), (x, y))
                draw.rectangle((x, y + cell - 22, x + cell, y + cell), fill=(24, 24, 26))
                draw.text((x + 6, y + cell - 20), EFFECT_ROWS[r], font=f_small, fill=(210, 210, 210))
            continue
        draw.text((x + 2, 68), f"{fam['source']}  |  {fam['studs_per_tile']:g} studs per tile", font=f_small,
                  fill=(180, 180, 180))
        # swatches: target, sample A, sample B
        for k, (rgb, tag) in enumerate(((fam["target"], "target"), (fam["sample_a"], "A"), (fam["sample_b"], "B"))):
            sx = x + 2 + k * 96
            draw.rectangle((sx, 88, sx + 22, 104), fill=tuple(rgb), outline=(90, 90, 90))
            draw.text((sx + 27, 88), tag, font=f_small, fill=(180, 180, 180))
        for r, (kind, mode, _) in enumerate(ROWS):
            p = cells_dir / f"{fam['slug']}__{kind}__{mode}.png"
            y = top + r * (cell + gap)
            if p.exists():
                sheet.paste(Image.open(p).convert("RGB").resize((cell, cell), Image.LANCZOS), (x, y))
    for r, (_, _, label) in enumerate(ROWS):
        y = top + r * (cell + gap)
        words, line, lines = label.split(" "), "", []
        for w in words:
            if len(line) + len(w) > 16:
                lines.append(line.strip())
                line = ""
            line += w + " "
        lines.append(line.strip())
        for k, text in enumerate(lines):
            draw.text((10, y + 8 + k * 18), text, font=f_small, fill=(200, 200, 200))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out, optimize=True)
    print(f"sheet written to {out}  ({width} x {height})")


if __name__ == "__main__":
    if IN_BLENDER:
        blender_main(sys.argv[sys.argv.index("--") + 1])
    else:
        driver_main()
