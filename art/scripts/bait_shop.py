"""Bait and Tackle stand: striped blue awning, a rod rack and bait tubs on the counter.
Replaces Workspace.Lake.ShopStand (Counter, PostL, PostR, Roof)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import box, cyl, finish, main_guard, mat, sphere  # noqa: E402
from stands import stand_frame  # noqa: E402


def build():
    wood, dark, plank, accent = stand_frame("shop", (90, 160, 220))
    # Rod rack beside the counter with three rods (willow, fiberglass, graphite colours).
    box((0.4, 0.8, 4.5), (6.0, 0.6, 2.25), dark)
    box((0.4, 0.8, 4.5), (7.6, 0.6, 2.25), dark)
    box((2.0, 0.8, 0.3), (6.8, 0.6, 0.8), wood)
    box((2.0, 0.8, 0.3), (6.8, 0.6, 3.2), wood)
    for i, rgb in enumerate(((110, 80, 50), (230, 200, 60), (40, 45, 60))):
        x = 6.3 + i * 0.5
        cyl(0.07, 6.5, (x, 0.6, 3.6), mat(f"rod{i}", rgb), verts=5)
        cyl(0.13, 1.0, (x, 0.6, 1.0), mat("cork", (180, 140, 95)), verts=6)
    # Bait tubs on the counter: worms, crickets, minnows.
    for i, (rgb, top) in enumerate((((70, 100, 150), (190, 110, 110)), ((200, 160, 80), (90, 70, 40)), ((60, 130, 160), (170, 210, 230)))):
        x = -3.2 + i * 1.6
        cyl(0.6, 0.9, (x, -0.6, 3.95), mat(f"tub{i}", rgb), verts=10)
        cyl(0.55, 0.1, (x, -0.6, 4.45), mat(f"bait{i}", top), verts=10)
    # A box of spinners and a stack of plastic worm packs.
    box((1.4, 1.0, 0.35), (2.2, -0.6, 3.7), mat("white"))
    for k in range(3):
        sphere(0.12, (1.8 + k * 0.4, -0.6, 3.95), mat("metalShine", (200, 200, 210), metal=0.8), seg=(6, 4))
    for k in range(3):
        box((1.1, 0.7, 0.15), (3.9, -0.5, 3.6 + k * 0.17), mat(f"pack{k}", ((120, 60, 160), (60, 160, 90), (200, 80, 60))[k]))
    # Minnow bucket on the ground.
    cyl(0.55, 1.1, (-6.0, -1.2, 0.55), mat("metal"), verts=10)
    cyl(0.5, 0.05, (-6.0, -1.2, 1.1), mat("water", (80, 150, 190)), verts=10)


if __name__ == "__main__":
    main_guard(build)
    finish("BaitShopStand", replaces="Workspace.Lake.ShopStand (Counter, PostL, PostR, Roof); keep the ShopPrompt and sign on an invisible counter part",
           notes="Open front faces the lake. Base sits on the ground (y = 1).", view=(-30, 22))
