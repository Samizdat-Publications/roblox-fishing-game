"""Jon Boat for the boat plan (BoatData.luau: 14 x 6 studs): a flat-bottom aluminium boat
with a raised square bow, two benches and a small outboard. Bow toward Blender +Y
(Roblox -Z). Not yet in the game; see docs/superpowers/plans/2026-11-26-boat.md."""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import box, cyl, finish, main_guard, mat, sphere  # noqa: E402

L, W, H = 14, 6, 1.8


def build():
    hull = mat("hull", (120, 140, 110))
    trim = mat("hullTrim", (90, 105, 85))
    inside = mat("hullInside", (165, 170, 160))
    wood = mat("plank")
    dark = mat("metal")
    # Flat bottom and floor.
    box((W - 0.6, L - 2.5, 0.25), (0, -1.0, 0.12), hull)
    box((W - 1.0, L - 3.0, 0.1), (0, -1.0, 0.3), inside)
    # Sides, flared out a little.
    for s in (-1, 1):
        box((0.18, L - 0.4, H), (s * (W / 2 - 0.35), 0, H / 2), hull, rot=(0, s * 0.18, 0))
        box((0.35, L - 0.4, 0.18), (s * (W / 2 - 0.15), 0, H + 0.02), trim)
    # Transom (stern) and the raised, sloped square bow.
    box((W - 0.5, 0.2, H), (0, -L / 2 + 0.3, H / 2), hull)
    box((W - 0.6, 2.9, 0.2), (0, L / 2 - 1.25, 1.0), hull, rot=(0.62, 0, 0))
    box((W - 0.4, 0.2, 0.5), (0, L / 2 - 0.25, 1.75), trim)
    # Bench seats (driver at the back, passenger up front).
    for y in (-3.6, 2.2):
        box((W - 0.8, 1.2, 0.25), (0, y, 1.05), wood)
        box((W - 0.8, 0.15, 0.8), (0, y, 0.55), inside)
    # Ribs on the floor.
    for y in (-5, -1, 1, 4):
        box((W - 1.2, 0.15, 0.12), (0, y, 0.37), trim)
    # Outboard motor on the transom.
    box((1.0, 1.0, 1.0), (0, -L / 2 - 0.2, H + 0.4), mat("motor", (200, 60, 50)), bevel=0.1)
    box((1.05, 1.05, 0.25), (0, -L / 2 - 0.2, H + 1.0), dark)
    cyl(0.15, 2.4, (0, -L / 2 - 0.35, H - 1.0), dark, verts=6)
    box((0.25, 0.7, 0.35), (0, -L / 2 - 0.35, H - 2.2), dark)
    for a in (0, 2.1, 4.2):  # little propeller
        box((0.1, 0.12, 0.55), (0, -L / 2 - 0.75, H - 2.2), mat("prop", (190, 190, 195)), rot=(0, a, 0))
    cyl(0.05, 1.2, (0.3, -L / 2 + 0.4, H + 0.5), dark, rot=(math.pi / 2.4, 0, 0), verts=4)  # tiller
    # Rod holders and a cleat on the bow.
    for s in (-1, 1):
        cyl(0.12, 0.5, (s * (W / 2 - 0.4), -5.2, H + 0.1), dark, verts=6)
    box((0.8, 0.2, 0.15), (0, L / 2 - 0.6, 2.05), dark)


if __name__ == "__main__":
    main_guard(build)
    finish("JonBoat", replaces="Nothing yet: the boat from the boat plan (gray box in Task 2, this model after)",
           notes="Hull 14 x 6 studs; floor at about 0.35 studs above the base. Bow toward -Z.", view=(35, 32))
