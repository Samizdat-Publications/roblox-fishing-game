"""Reed clump (cattails) and a lily pad patch, for the weed bed and pond edges.
Replace the gray-box Weed sticks in Workspace.Lake.WeedBed."""

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import box, cyl, finish, mat, reset, sphere  # noqa: E402


def reeds():
    reset()
    rng = random.Random(4)
    reed, dark = mat("reed"), mat("cattail", (110, 75, 45))
    for k in range(14):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0, 1.6)
        x, y = math.cos(a) * r, math.sin(a) * r
        h = rng.uniform(4.5, 7.5)
        tilt = (rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15), 0)
        cyl(0.09, h, (x, y, h / 2), reed, rot=tilt, verts=4)
        if k % 2 == 0:  # cattail head
            cyl(0.22, 1.0, (x + tilt[1] * h * 0.45, y - tilt[0] * h * 0.45, h * 0.9), dark, rot=tilt, verts=6)
    for k in range(10):  # flat blades
        a = rng.uniform(0, 2 * math.pi)
        h = rng.uniform(3, 6)
        box((0.35, 0.06, h), (math.cos(a) * 1.2, math.sin(a) * 1.2, h / 2), mat("blade", (95, 145, 70)), rot=(rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), a))


def lilies():
    reset()
    rng = random.Random(8)
    pad, flower, centre = mat("lily"), mat("pinkFlower"), mat("sell")
    for k in range(7):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0, 3.2)
        size = rng.uniform(0.9, 1.5)
        z = 0.06 + k * 0.035  # each pad a hair higher so overlaps never share a surface
        p = cyl(size, 0.12, (math.cos(a) * r, math.sin(a) * r, z), pad if k % 2 else mat("lilyDark", (55, 120, 60)), verts=10)
    for k in range(2):
        x, y = rng.uniform(-1.5, 1.5), rng.uniform(-1.5, 1.5)
        for p in range(6):
            a = p / 6 * 2 * math.pi
            sphere(0.3, (x + math.cos(a) * 0.3, y + math.sin(a) * 0.3, 0.55), flower, scale=(1.4, 0.6, 0.6), subdiv=1)
        sphere(0.18, (x, y, 0.65), centre, subdiv=1)


if __name__ == "__main__":
    reeds()
    finish("Reeds", replaces="Workspace.Lake.WeedBed Weed sticks (scatter clumps over the weed bed)",
           notes="Base at the water line; about 7 studs tall.", view=(30, 15))
    lilies()
    finish("LilyPads", replaces="Nothing yet: new dressing for the weed bed and pond", notes="Sits on the water surface.", view=(30, 55))
