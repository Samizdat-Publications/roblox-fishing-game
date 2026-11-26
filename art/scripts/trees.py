"""Trees: two pines (tall, short) and a leafy tree. Replace the gray-box pines at Cedar
Creek (trunk 1.4 x 8, crown 7 x 9, about 16 tall) and dress the lake shore."""

import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import cone, cyl, finish, jitter, mat, reset, sphere  # noqa: E402


def pine(height, seed):
    reset()
    rng = random.Random(seed)
    bark, needles, dark = mat("bark"), mat("pine"), mat("pineDark", (35, 78, 42))
    cyl(0.7, height * 0.35, (0, 0, height * 0.175), bark, verts=7, radius2=0.5)
    tiers = 4
    for k in range(tiers):
        r = 4.0 * (1 - k / (tiers + 0.6))
        z = height * 0.25 + k * height * 0.17
        c = cone(r, height * 0.32, (0, 0, z + height * 0.16), needles if k % 2 == 0 else dark, verts=8, rot=(0, 0, rng.uniform(0, 1)))
        jitter(c, 0.15, seed + k)


def leafy():
    reset()
    rng = random.Random(3)
    bark, leaf, dark = mat("bark"), mat("leaf"), mat("leafDark", (55, 110, 45))
    cyl(0.8, 8, (0, 0, 4), bark, verts=7, radius2=0.55)
    cyl(0.3, 3.5, (0.9, 0, 6.8), bark, rot=(0, 0.7, 0), verts=5)
    cyl(0.3, 3.0, (-0.8, 0.3, 7.3), bark, rot=(0.2, -0.7, 0), verts=5)
    for k, (x, y, z, r) in enumerate(((0, 0, 11, 3.6), (2.5, 0.6, 9.8, 2.6), (-2.4, -0.5, 10.2, 2.7), (0.4, 2.2, 10.0, 2.4), (-0.5, -2.3, 10.6, 2.5), (0.2, 0.2, 13.2, 2.4))):
        s = sphere(r, (x, y, z), leaf if k % 2 == 0 else dark, subdiv=1)
        jitter(s, 0.2, k)


if __name__ == "__main__":
    pine(16, 1)
    finish("PineTall", replaces="Cedar Creek Trunk and Crown pairs", notes="About 16 studs, like the gray box.", view=(30, 12))
    pine(11, 2)
    finish("PineShort", replaces="Cedar Creek Trunk and Crown pairs (mix with PineTall)", notes="About 11 studs.", view=(30, 12))
    leafy()
    finish("LeafyTree", replaces="Nothing yet: new dressing for the lake shore", notes="About 15 studs.", view=(30, 12))
