"""Fallen logs, three variants: a long log with branch stubs (22 studs, matches the gray box
cylinders), a broken shorter one, and one with its root ball. Replace Workspace.Lake.Logs.Log1-5."""

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import box, cyl, finish, jitter, mat, reset, sphere  # noqa: E402

R = 1.1  # 2.2 stud diameter like the gray box


def log_body(length, seed, broken=False):
    rng = random.Random(seed)
    bark = mat("bark")
    dark = mat("darkWood")
    end = mat("logEnd", (190, 150, 100))
    body = cyl(R, length, (0, 0, R), bark, rot=(0, math.pi / 2, 0), verts=10)
    jitter(body, 0.08, seed)
    # End caps with lighter wood rings.
    cyl(R * 0.85, 0.12, (length / 2 + 0.02, 0, R), end, rot=(0, math.pi / 2, 0), verts=10)
    if not broken:
        cyl(R * 0.85, 0.12, (-length / 2 - 0.02, 0, R), end, rot=(0, math.pi / 2, 0), verts=10)
    else:
        for k in range(5):  # jagged splinters at the broken end
            a = k / 5 * 2 * math.pi
            cyl(0.25, rng.uniform(0.8, 1.6), (-length / 2 - 0.4, math.cos(a) * 0.6, R + math.sin(a) * 0.6), end, rot=(0, math.pi / 2, 0), verts=4, radius2=0.02)
    # Branch stubs and a moss patch.
    for k in range(3 if length > 15 else 2):
        x = rng.uniform(-length / 2 + 2, length / 2 - 2)
        ang = rng.uniform(0.5, 1.2)
        cyl(0.3, 2.0, (x, rng.choice((-0.8, 0.8)), R + 0.9), dark, rot=(ang, 0, 0), verts=6, radius2=0.12)
    sphere(0.9, (rng.uniform(-3, 3), 0, R * 1.85), mat("moss"), scale=(2.5, 1.1, 0.25))


def build(variant):
    reset()
    if variant == 1:
        log_body(22, 1)
    elif variant == 2:
        log_body(14, 2, broken=True)
    else:
        log_body(16, 3)
        rng = random.Random(9)
        root = mat("bark")
        disc = sphere(2.0, (8.6, 0, 1.9), mat("rootBall", (110, 85, 60)), scale=(0.45, 1.0, 1.0), subdiv=1)
        jitter(disc, 0.2, 3)
        for k in range(7):
            a = k / 7 * 2 * math.pi
            cyl(0.22, 2.4, (9.2, math.cos(a) * 1.6, 1.9 + math.sin(a) * 1.6), root, rot=(math.cos(a) * 0.9, math.pi / 2 - 0.3, 0), verts=4, radius2=0.05)


if __name__ == "__main__":
    for v in (1, 2, 3):
        build(v)
        finish(f"Log{v}", replaces="Workspace.Lake.Logs.Log1 to Log5 (mix the variants)",
               notes="Lies along X. The gray box sinks logs 0.4 to 1.6 studs; keep that.", view=(25, 30))
