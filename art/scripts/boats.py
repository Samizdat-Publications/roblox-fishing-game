"""The two boats in BoatData.luau, sized to their hulls in studs:
- Inflatable Dinghy, 8 x 4: orange tubes in a U round a flat floor, a little seat, a tiny outboard.
- Deep-V Boat, 16 x 7: white V hull with a blue stripe, a centre console with a windscreen,
  a helm seat behind it, a seat up front for the second player, and a big outboard.
Bow toward Blender +Y (Roblox -Z), as JonBoat. Not yet in the game (BoatService builds gray
boxes first); see docs/superpowers/plans/2026-11-26-boat.md, Task 2.

Usage:  python art/scripts/boats.py            (both)
        python art/scripts/boats.py Dinghy     (one)
"""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import box, cyl, finish, mat, reset, sphere  # noqa: E402


def dinghy():
    L, W = 8.0, 4.0
    r = 0.6  # tube radius
    orange = mat("dinghyTube", (235, 120, 40))
    seam = mat("dinghySeam", (180, 85, 30))
    floor = mat("dinghyFloor", (70, 72, 78))
    dark = mat("metal")
    # Side tubes from the stern to where the bow starts curving.
    straight = L - W / 2
    yc = -L / 2 + straight / 2
    for s in (-1, 1):
        cyl(r, straight, (s * (W / 2 - r), yc, r), orange, rot=(math.pi / 2, 0, 0), verts=10)
        cyl(r * 1.02, 0.12, (s * (W / 2 - r), yc - straight / 2 + 0.3, r), seam, rot=(math.pi / 2, 0, 0), verts=10)
        sphere(r, (s * (W / 2 - r), -L / 2, r), orange, seg=(10, 6))  # rounded tube ends at the stern
    # The bow: a half ring of short tube pieces.
    br = W / 2 - r
    cy = -L / 2 + straight
    n = 6
    for i in range(n):
        a0 = math.pi * i / n
        a1 = math.pi * (i + 1) / n
        am = (a0 + a1) / 2
        x, y = br * math.cos(am), cy + br * math.sin(am)
        seg = 2 * br * math.sin((a1 - a0) / 2) + 0.15
        cyl(r, seg, (x, y, r), orange, rot=(math.pi / 2, 0, am - math.pi / 2), verts=10)
    # Floor, transom board and a bench.
    box((W - 2 * r + 0.2, straight + br * 0.6, 0.2), (0, -L / 2 + (straight + br * 0.6) / 2, 0.15), floor)
    box((W - 2 * r, 0.25, 1.1), (0, -L / 2 + 0.15, 0.6), mat("plank"))
    box((W - 2 * r, 1.0, 0.2), (0, -L / 2 + 2.2, 0.75), mat("plank"))
    # Tiny outboard with its tiller.
    box((0.6, 0.7, 0.7), (0, -L / 2 - 0.3, 1.35), mat("motor", (40, 40, 45)), bevel=0.08)
    cyl(0.1, 1.4, (0, -L / 2 - 0.35, 0.4), dark, verts=6)
    box((0.15, 0.45, 0.25), (0, -L / 2 - 0.35, -0.3), dark)
    cyl(0.05, 0.9, (0.2, -L / 2 + 0.2, 1.5), dark, rot=(math.pi / 2.4, 0, 0), verts=4)
    # Grab rope along the tubes.
    for s in (-1, 1):
        cyl(0.05, straight - 0.8, (s * (W / 2 - r), yc, 2 * r + 0.02), mat("rope"), rot=(math.pi / 2, 0, 0), verts=4)


def deepv():
    L, W, H = 16.0, 7.0, 2.2
    white = mat("white")
    stripe = mat("deepvStripe", (40, 70, 120))
    deck = mat("deepvDeck", (200, 200, 195))
    dark = mat("metal")
    glass = mat("glass", (150, 190, 210))
    # V hull: two slanted bottom panels meeting at the keel, then the topsides to y = 4.5,
    # then two bow panels that meet at the stem.
    yb = 4.5  # where the sides start turning in
    stern = -L / 2 + 0.4
    side_len = yb - stern
    for s in (-1, 1):
        box((W / 2 + 0.3, side_len, 0.25), (s * W / 4, (yb + stern) / 2, 0.45), white, rot=(0, s * -0.32, 0))
        box((0.25, side_len, H), (s * (W / 2 - 0.12), (yb + stern) / 2, H / 2 + 0.3), white)
        box((0.28, side_len, 0.35), (s * (W / 2 - 0.1), (yb + stern) / 2, H - 0.15), stripe)
        dx, dy = W / 2 - 0.12, L / 2 - yb
        ln = math.hypot(dx, dy)
        ang = math.atan2(dx, dy)
        cx, cy = s * dx / 2, yb + dy / 2
        box((0.25, ln + 0.2, H), (cx, cy, H / 2 + 0.3), white, rot=(0, 0, s * ang))
        box((0.28, ln + 0.2, 0.35), (cx, cy, H - 0.15), stripe, rot=(0, 0, s * ang))
        box((W / 4, ln, 0.25), (cx * 0.5, cy, 0.5), white, rot=(0, s * -0.32, s * ang))
    box((0.4, 0.4, H + 0.2), (0, L / 2 + 0.05, H / 2 + 0.3), white)
    box((W - 0.6, 0.25, H), (0, -L / 2 + 0.4, H / 2 + 0.3), white)  # transom
    box((W - 0.6, side_len, 0.15), (0, (yb + stern) / 2, 0.85), deck)
    box((W * 0.55, 1.8, 0.15), (0, yb + 0.9, 0.85), deck)
    # Console with a windscreen, the helm seat behind it, a seat up front.
    box((2.4, 1.4, 2.0), (0, -0.5, 1.9), white, bevel=0.1)
    box((2.2, 0.15, 0.9), (0, 0.1, 3.3), glass, rot=(0.45, 0, 0))
    cyl(0.4, 0.15, (0, -1.25, 2.6), dark, rot=(math.pi / 2.6, 0, 0), verts=8)  # wheel
    box((1.6, 1.2, 0.9), (0, -2.8, 1.35), stripe, bevel=0.1)
    box((1.6, 0.3, 1.2), (0, -3.35, 2.1), stripe, bevel=0.08)
    box((1.6, 1.2, 0.9), (0, L / 2 - 4.0, 1.35), stripe, bevel=0.1)
    # A fish finder screen on the console's top, for the navigator (boat plan Task 8).
    box((0.8, 0.12, 0.55), (0.6, -0.1, 3.0), mat("screen", (40, 200, 160), emit=0.6))
    # Big outboard.
    box((1.2, 1.3, 1.5), (0, -L / 2 - 0.5, H + 0.5), mat("motor", (40, 40, 45)), bevel=0.12)
    cyl(0.2, 2.6, (0, -L / 2 - 0.6, H - 1.0), dark, verts=6)
    box((0.3, 0.9, 0.4), (0, -L / 2 - 0.6, -0.2), dark)
    # Rod holders and bow cleat.
    for s in (-1, 1):
        cyl(0.12, 0.6, (s * (W / 2 - 0.5), -6.0, H + 0.4), dark, verts=6)
    box((0.9, 0.2, 0.15), (0, L / 2 - 1.0, H + 0.4), dark)


BOATS = {
    "Dinghy": (dinghy, "8 x 4 stud inflatable; bow toward -Z. Tubes about 1.2 studs high.", (30, 30)),
    "DeepV": (deepv, "16 x 7 stud hull; bow toward -Z. Helm seat behind the console, navigator seat up front.", (35, 32)),
}

if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ids = [a for a in args if a in BOATS] or list(BOATS)
    for bid in ids:
        build, notes, view = BOATS[bid]
        reset()
        build()
        finish(bid, replaces="The gray-box boat BoatService builds (boat plan Task 2)", notes=notes, view=view)
