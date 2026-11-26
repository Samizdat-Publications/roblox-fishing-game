"""Rocks in three sizes. Replace the creek boulders (Ball parts about 4 to 7 studs) and
pebbles, and dress the shore."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import finish, jitter, mat, reset, sphere  # noqa: E402


def rock(size, seed, name):
    reset()
    main = sphere(size / 2, (0, 0, size * 0.32), mat("stone"), scale=(1.15, 1.0, 0.75), subdiv=2)
    jitter(main, size * 0.06, seed)
    if size > 3:
        side = sphere(size / 4, (size * 0.45, size * 0.15, size * 0.15), mat("darkStone"), scale=(1.1, 1.0, 0.7), subdiv=1)
        jitter(side, size * 0.05, seed + 1)
    if size > 5:
        sphere(size * 0.22, (-size * 0.05, 0, size * 0.62), mat("moss"), scale=(1.5, 1.2, 0.35), subdiv=1)


if __name__ == "__main__":
    for size, seed, name in ((1.6, 1, "RockSmall"), (4, 2, "RockMedium"), (7, 3, "RockLarge")):
        rock(size, seed, name)
        finish(name, replaces="Cedar Creek Boulder1-5 and Pebble1-14 (pick the size that fits)", notes=f"About {size} studs across.", view=(30, 25))
