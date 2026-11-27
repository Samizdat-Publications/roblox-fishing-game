"""Material sheet: every family on a sphere, on the thing it is for, and at 30 studs.

    python art/scripts/material_sheet.py                       # writes art/textures/sheet-n0.png
    python art/scripts/material_sheet.py --out artifacts/n0/sheet-test.png --samples 32
    python art/scripts/material_sheet.py --only meadow_grass wet_sand
    python art/scripts/material_sheet.py --dir rope=artifacts/textures_candidates/rope__Rope003

The same file runs twice. Plain Python (the driver) reads `texture_families.json`, starts
Blender headless on this file to render one small picture per cell, then pastes the cells
into one labelled sheet with Pillow. Inside Blender (the `bpy` half) it builds each cell:

  row 1  sphere, colour map                    (3 studs across, seen from about 8 studs)
  row 2  the thing the family is for, colour   (dock section, rope coil, awning, ground, boulders, fish)
  row 3  the same thing 30 studs away, with a bobber for scale (a crop of the screen)
  row 4  sphere, NEUTRAL map times sample colour A (how Layer B and tinted terrain slots look)
  row 5  the thing, NEUTRAL map times sample colour B (a second hue, to show the map carries any colour)

Units: 1 Blender unit = 1 stud. Maps repeat every `studs_per_tile` studs, as a Roblox
MaterialVariant would. Light: one warm sun at 40 degrees and a plain sky, Standard view
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
}
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

    grey = flat_material("StageGrey", [150, 150, 150])
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
            ground("Patch", mat, 140.0 if far else 40.0, spt, 0.35)
            return
        stage()
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
            else:
                look((1.2, -6.0, 2.4), (0.0, 0.0, 1.6), 55)
        else:  # far: 30 studs, a crop of the screen
            target = (0.0, 0.0, 0.4 if fam["kind"] == "terrain" else 1.4)
            look((8.0, -28.0, 7.0), target, 85)

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
                    pos = (0.0, 0.0, z) if fam["kind"] == "terrain" or fam["slug"] == "weathered_plank" else (-3.6, -3.4, 0.3)
                    bobber(pos)
            camera_for(fam, kind)
            scene.render.filepath = str(out_dir / f"{fam['slug']}__{kind}__{mode}.png")
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
    ap.add_argument("--out", default=str(REPO / "art" / "textures" / "sheet-n0.png"))
    ap.add_argument("--only", nargs="*", help="only these families")
    ap.add_argument("--dir", action="append", default=[], metavar="FAMILY=FOLDER",
                    help="take a family's maps from another folder (a candidate run)")
    ap.add_argument("--cell", type=int, default=384)
    ap.add_argument("--samples", type=int, default=64)
    ap.add_argument("--title", default="Material families, N0")
    ap.add_argument("--compose-only", action="store_true", help="reuse the cells already rendered")
    args = ap.parse_args()

    with open(TABLE, "r", encoding="utf-8") as f:
        table = json.load(f)
    overrides = dict(d.split("=", 1) for d in args.dir)
    fams = []
    for slug, cfg in table["families"].items():
        if args.only and slug not in args.only:
            continue
        folder = Path(overrides.get(slug, REPO / "art" / "textures" / slug))
        if not folder.is_absolute():
            folder = REPO / folder
        meta = {}
        meta_path = folder / f"{slug}.json"
        if meta_path.exists():
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
        a, b = SAMPLES.get(slug, (cfg["target_rgb"], cfg["target_rgb"]))
        fams.append({
            "slug": slug, "kind": cfg.get("kind", "prop"),
            "studs_per_tile": float(cfg.get("studs_per_tile", 4)),
            "source": meta.get("source", cfg["source"]), "target": cfg["target_rgb"],
            "sample_a": a, "sample_b": b,
            "color": str(folder / f"{slug}_color.png"), "neutral": str(folder / f"{slug}_neutral.png"),
            "normal": str(folder / f"{slug}_normal.png"), "rough": str(folder / f"{slug}_rough.png"),
        })

    out = Path(args.out).resolve()
    cells_dir = REPO / "artifacts" / "sheet_cells" / out.stem
    job = {"families": fams, "cell": args.cell, "samples": args.samples, "cells_dir": str(cells_dir)}
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
    width = left + len(fams) * (cell + gap) + gap
    height = top + len(ROWS) * (cell + gap) + gap
    sheet = Image.new("RGB", (width, height), (24, 24, 26))
    draw = ImageDraw.Draw(sheet)
    f_big, f_mid, f_small = font(26), font(17), font(13)
    draw.text((12, 10), args.title, font=f_big, fill=(240, 240, 240))
    for c, fam in enumerate(fams):
        x = left + c * (cell + gap)
        draw.text((x + 2, 46), fam["slug"], font=f_mid, fill=(240, 240, 240))
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
