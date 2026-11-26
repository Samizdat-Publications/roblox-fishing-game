"""Pond rim: chunky stones around the home pond, matching the gray box (water 22 x 14,
rim 1 stud wide and 1.6 tall, so 24 x 16 outside). Replaces HomePond RimN, RimS, RimW, RimE."""

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import box, finish, jitter, main_guard, mat, sphere  # noqa: E402

W, D = 22, 14  # water size


def build():
    rng = random.Random(7)
    stones = [mat("stone"), mat("darkStone"), mat("stoneLight", (165, 162, 152))]
    moss = mat("moss")
    # Walk the rectangle's edge (rounded corners) and drop a stone every ~1.6 studs.
    hw, hd = W / 2 + 0.5, D / 2 + 0.5
    perim = 2 * (2 * hw + 2 * hd)
    n = int(perim / 1.55)
    for i in range(n):
        t = i / n * perim
        if t < 2 * hw:
            x, y = -hw + t, -hd
        elif t < 2 * hw + 2 * hd:
            x, y = hw, -hd + (t - 2 * hw)
        elif t < 4 * hw + 2 * hd:
            x, y = hw - (t - 2 * hw - 2 * hd), hd
        else:
            x, y = -hw, hd - (t - 4 * hw - 2 * hd)
        r = rng.uniform(0.75, 0.95)
        s = sphere(r, (x, y, 0.65), rng.choice(stones), scale=(1.15, 1.0, 0.85), subdiv=1)
        jitter(s, 0.12, seed=i)
        if rng.random() < 0.25:  # a patch of moss on top
            m = sphere(r * 0.55, (x, y, 0.65 + r * 0.65), moss, scale=(1.2, 1.0, 0.35), subdiv=1)
    # A low inner lip so the water edge reads cleanly.
    for (sx, sy, x, y) in ((W + 1, 0.4, 0, -D / 2 - 0.1), (W + 1, 0.4, 0, D / 2 + 0.1), (0.4, D, -W / 2 - 0.1, 0), (0.4, D, W / 2 + 0.1, 0)):
        box((sx, sy, 0.9), (x, y, 0.45), stones[1])


if __name__ == "__main__":
    main_guard(build)
    finish("PondRim", replaces="Workspace.Lake.HomePond RimN, RimS, RimW, RimE",
           notes="Centre it on the pond (50, 1, 106 in the gray box); base on the ground.", view=(30, 40))
