"""Dock: a T-shaped wooden dock with posts, planks, two lamp posts, bollards and a ladder.

Matches the gray box in WorldBuilder.luau: an 8 stud wide walkway 46 studs long and a
16 x 8 end deck, deck top at y = 1.5, posts down to the lake floor (y = -7.5).
Blender +Y is the lake end (Roblox -Z once exported).
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import box, cyl, finish, mat, main_guard, sphere  # noqa: E402

WALK_W, WALK_L = 8, 46
END_W, END_L = 16, 8
TOP = 9.0  # deck top above the model's base (the base is the lake floor at y = -7.5)
PLANK_T = 0.35


def build():
    plank = mat("plank")
    dark = mat("darkWood")
    wood = mat("wood")
    rope = mat("rope")
    metal = mat("metal")
    lamp = mat("lamp", emit=4)

    parts = []
    # Walkway runs from y = 0 (shore) to y = WALK_L (lake end); the end deck overlaps its tip.
    y = 0.5
    i = 0
    while y < WALK_L - END_L:
        w = WALK_W + (0.25 if i % 3 == 0 else 0)  # slightly uneven plank ends look hand-built
        parts.append(box((w, 0.9, PLANK_T), (0.1 if i % 2 else -0.1, y, TOP - PLANK_T / 2), plank if i % 4 else wood))
        y += 1.0
        i += 1
    y = WALK_L - END_L + 0.5
    while y < WALK_L:
        parts.append(box((END_W, 0.9, PLANK_T), (0, y, TOP - PLANK_T / 2), plank if i % 4 else wood))
        y += 1.0
        i += 1
    # Stringers under the planks.
    for x in (-WALK_W / 2 + 0.6, 0, WALK_W / 2 - 0.6):
        parts.append(box((0.6, WALK_L - END_L, 0.6), (x, (WALK_L - END_L) / 2, TOP - PLANK_T - 0.3), dark))
    for x in (-END_W / 2 + 0.6, END_W / 2 - 0.6):
        parts.append(box((0.6, END_L, 0.6), (x, WALK_L - END_L / 2, TOP - PLANK_T - 0.3), dark))
    # Posts: pairs along the walkway, four under the end deck. They stick up a little.
    for py in range(4, WALK_L - END_L, 7):
        for px in (-WALK_W / 2 + 0.4, WALK_W / 2 - 0.4):
            parts.append(cyl(0.45, TOP + 0.6, (px, py, (TOP + 0.6) / 2), dark, verts=8))
    for px in (-END_W / 2 + 0.4, END_W / 2 - 0.4):
        for py in (WALK_L - END_L + 0.5, WALK_L - 0.5):
            parts.append(cyl(0.5, TOP + 0.8, (px, py, (TOP + 0.8) / 2), dark, verts=8))
    # Bollards with a coil of rope, for tying up the boat later.
    for px in (-WALK_W / 2 + 0.5, WALK_W / 2 - 0.5):
        parts.append(cyl(0.35, 1.0, (px, WALK_L - END_L - 2, TOP + 0.5), metal, verts=8))
        parts.append(cyl(0.55, 0.25, (px, WALK_L - END_L - 2, TOP + 0.15), rope, verts=10))
    # Ladder off the end into the water.
    for px in (-0.8, 0.8):
        parts.append(box((0.2, 0.2, 4.5), (px, WALK_L + 0.2, TOP - 2.0), metal))
    for k in range(4):
        parts.append(box((1.6, 0.2, 0.15), (0, WALK_L + 0.2, TOP - 0.6 - k * 1.0), metal))
    # Two lamp posts at the end deck corners (the game adds the PointLight).
    for px in (-END_W / 2 + 0.5, END_W / 2 - 0.5):
        ly = WALK_L - 1.5
        parts.append(cyl(0.22, 7.5, (px, ly, TOP + 3.75), dark, verts=6))
        parts.append(box((1.4, 1.4, 0.25), (px, ly, TOP + 7.6), dark))
        parts.append(box((0.9, 0.9, 1.0), (px, ly, TOP + 8.2), lamp))
        parts.append(cyl(0.85, 0.5, (px, ly, TOP + 8.95), dark, verts=4, radius2=0.1))
    # A bait bucket for character.
    parts.append(cyl(0.45, 0.8, (2.4, WALK_L - END_L - 4, TOP + 0.4), mat("tub"), verts=10))
    parts.append(sphere(0.25, (2.4, WALK_L - END_L - 4, TOP + 0.85), mat("worm"), scale=(1.4, 1, 0.5)))


if __name__ == "__main__":
    main_guard(build)
    finish(
        "Dock",
        replaces="Workspace.Lake.Dock (Deck, EndDeck, Posts) and the two dock-end lamp posts",
        notes="Deck top is 9 studs above the model base; place the base at y = -7.5 so the deck top sits at y = 1.5.",
        view=(40, 30),
    )
