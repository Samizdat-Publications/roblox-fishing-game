"""The three rods in RodData.luau (Willow 6, Fiberglass 6.6, Graphite 7.2 studs) with
their reels, and the bobber. The rod lies along Blender +Y with the tip at +Y, which is
Roblox -Z after export, the same way RodService points the gray-box rod."""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import box, cyl, finish, mat, reset, sphere  # noqa: E402

RODS = {
    "WillowRod": dict(length=6.0, blank=(110, 80, 50), wrap=(70, 50, 30), knots=True),
    "FiberglassRod": dict(length=6.6, blank=(230, 200, 60), wrap=(200, 60, 50)),
    "GraphiteRod": dict(length=7.2, blank=(40, 45, 60), wrap=(215, 175, 60)),
}
X90 = (math.pi / 2, 0, 0)


def rod(name, length, blank, wrap, knots=False):
    reset()
    L = length
    butt = -L / 2
    b = mat(name + "Blank", blank)
    w = mat(name + "Wrap", wrap)
    cork = mat("cork", (180, 140, 95))
    metal = mat("metal")
    # Handle and blank (the blank tapers to the tip).
    cyl(0.13, 1.3, (0, butt + 0.65, 0), cork, rot=X90, verts=8)
    cyl(0.1, 0.5, (0, butt + 1.55, 0), metal, rot=X90, verts=8)  # reel seat
    cyl(0.11, 0.7, (0, butt + 2.15, 0), cork, rot=X90, verts=8)
    blank_len = L - 2.5
    cyl(0.075, blank_len, (0, butt + 2.5 + blank_len / 2, 0), b, rot=X90, verts=6, radius2=0.022)
    # Guides: little rings on stalks under the blank, closer together toward the tip.
    for k, t in enumerate((0.12, 0.38, 0.58, 0.75, 0.88, 0.98)):
        y = butt + 2.5 + blank_len * t
        r = 0.16 * (1 - t * 0.6)
        cyl(0.02, r, (0, y, -r / 2 - 0.04), metal, verts=4)
        cyl(r * 0.55, 0.03, (0, y, -r - 0.04), metal, rot=X90, verts=8)
        cyl(0.085 * (1 - t * 0.7), 0.08, (0, y, 0), w, rot=X90, verts=6)  # thread wrap
    if knots:
        for t in (0.3, 0.6):
            sphere(0.07, (0.05, butt + 2.5 + blank_len * t, 0.03), mat(name + "Knot", (80, 58, 35)), subdiv=1)
    # Spinning reel hanging under the seat.
    cyl(0.04, 0.4, (0, butt + 1.55, -0.25), metal, verts=4)
    body = sphere(0.22, (0, butt + 1.55, -0.55), mat("reelBody", (60, 62, 70)), scale=(0.9, 1.1, 1.0), subdiv=1)
    cyl(0.2, 0.3, (0, butt + 1.85, -0.55), mat("spool", (200, 200, 205)), rot=X90, verts=10)
    cyl(0.03, 0.35, (0.25, butt + 1.55, -0.55), metal, rot=(0, math.pi / 2, 0), verts=4)
    box((0.05, 0.05, 0.3), (0.42, butt + 1.55, -0.68), metal)
    sphere(0.07, (0.42, butt + 1.55, -0.85), mat("knob", (30, 30, 30)), subdiv=1)
    # Butt cap.
    cyl(0.14, 0.12, (0, butt + 0.06, 0), mat("buttCap", (40, 40, 40)), rot=X90, verts=8)


def bobber():
    reset()
    red, white = mat("red"), mat("white")
    sphere(0.4, (0, 0, 0.4), red, seg=(12, 8))
    top = sphere(0.401, (0, 0, 0.4), white, seg=(12, 8))
    # Keep only the top half of the white sphere.
    import bmesh
    import bpy

    bm = bmesh.new()
    bm.from_mesh(top.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < 0.02], context="VERTS")
    bm.to_mesh(top.data)
    bm.free()
    cyl(0.06, 0.55, (0, 0, 0.95), white, verts=6)
    cyl(0.42, 0.06, (0, 0, 0.4), mat("metal"), verts=12)  # seam ring
    cyl(0.03, 0.2, (0, 0, -0.05), mat("metal"), verts=4)  # line eye


if __name__ == "__main__":
    for name, spec in RODS.items():
        rod(name, **spec)
        finish(name, replaces=f"the gray-box rod part from RodService ({name.replace('Rod', '')})",
               notes=f"{spec['length']} studs long along Z, tip toward -Z (as RodService points it). Put the RodTip attachment at the tip.",
               view=(60, 25))
    bobber()
    finish("Bobber", replaces="the ball Bobber and its Top from FishingService.makeBobber",
           notes="0.8 studs across like the gray box; the base is the line eye.", view=(30, 15))
