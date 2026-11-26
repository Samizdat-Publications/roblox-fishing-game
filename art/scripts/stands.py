"""Shared builder for the two market stands. Used by fish_buyer.py and bait_shop.py.

Matches the gray box: a 10 x 3.5 x 4 counter, posts 4.7 studs either side at the back,
roof top about 10 studs up, 11 x 5. The counter's front faces Blender -Y (Roblox +Z after
export is the back), so in the game the open front faces the lake like the gray box.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import box, cyl, mat, paint  # noqa: E402

COUNTER = (10, 4, 3.5)  # x, depth (y), height (z)


def stand_frame(accent_name, stripe_rgb):
    wood = mat("wood")
    dark = mat("darkWood")
    plank = mat("plank")
    accent = mat(accent_name)
    # Counter: a plank box with a darker top and a skirt.
    box((COUNTER[0], COUNTER[1], COUNTER[2] - 0.4), (0, 0, (COUNTER[2] - 0.4) / 2), plank)
    box((COUNTER[0] + 0.4, COUNTER[1] + 0.4, 0.4), (0, 0, COUNTER[2] - 0.2), dark)
    for x in (-4.6, -2.3, 0, 2.3, 4.6):  # vertical boards on the front
        box((0.25, 0.15, COUNTER[2] - 0.6), (x, -COUNTER[1] / 2 - 0.05, (COUNTER[2] - 0.4) / 2), wood)
    box((COUNTER[0], 0.2, 0.6), (0, -COUNTER[1] / 2 - 0.1, COUNTER[2] - 1.0), accent)  # coloured band
    # Back wall and posts.
    for x in (-4.7, 4.7):
        box((0.6, 0.6, 9.4), (x, 1.7, 4.7), dark)
        box((0.6, 0.6, 8.4), (x, -1.9, 4.2), dark)
    box((10, 0.3, 5.5), (0, 1.85, 6.6), plank)
    # Striped awning: slats sloping down toward the front.
    n = 10
    for i in range(n):
        x = -5.25 + 10.5 * (i + 0.5) / n
        rgb = stripe_rgb if i % 2 == 0 else (240, 236, 225)
        slat = box((10.5 / n, 6.2, 0.25), (x, -0.3, 9.4), mat(f"stripe{i % 2}_{accent_name}", rgb), rot=(0.28, 0, 0))
    # Scalloped front edge.
    for i in range(n):
        x = -5.25 + 10.5 * (i + 0.5) / n
        rgb = stripe_rgb if i % 2 == 0 else (240, 236, 225)
        cyl(0.5, 0.2, (x, -3.3, 8.25), mat(f"stripe{i % 2}_{accent_name}", rgb), rot=(1.5708, 0, 0), verts=6)
    # Sign board above the awning (the game draws the words on it).
    box((7, 0.3, 1.6), (0, 1.9, 10.9), accent)
    box((7.4, 0.25, 2.0), (0, 2.0, 10.9), dark)
    return wood, dark, plank, accent
