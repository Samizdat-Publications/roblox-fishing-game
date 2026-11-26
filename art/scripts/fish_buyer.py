"""Fish Buyer stand: striped yellow awning, counter with a hanging scale and an ice chest
of fish. Replaces Workspace.Lake.SellStand (Counter, PostL, PostR, Roof)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import box, cyl, finish, main_guard, mat, sphere  # noqa: E402
from stands import stand_frame  # noqa: E402


def build():
    wood, dark, plank, accent = stand_frame("sell", (230, 180, 60))
    metal = mat("metal")
    white = mat("white")
    # Hanging scale under the awning.
    cyl(0.05, 1.4, (-2.5, -1.0, 7.6), metal, verts=4)
    cyl(0.6, 0.25, (-2.5, -1.0, 6.7), white, rot=(1.5708, 0, 0), verts=12)
    box((0.08, 0.05, 0.4), (-2.5, -1.15, 6.75), mat("red"))
    cyl(0.04, 0.8, (-2.5, -1.0, 6.2), metal, verts=4)
    box((1.2, 0.8, 0.15), (-2.5, -1.0, 5.75), metal)
    # Ice chest on the counter with three fish tails poking out.
    box((2.6, 1.6, 1.2), (2.2, -0.4, 4.1), mat("tub"))
    box((2.7, 1.7, 0.2), (2.2, -0.4, 4.75), white)
    for i, rgb in enumerate(((215, 190, 70), (85, 125, 60), (70, 110, 150))):
        cyl(0.35, 0.05, (1.5 + i * 0.7, -0.4, 5.1), mat(f"tail{i}", rgb), rot=(0, 0, 0.3), verts=3)
    # A crate of ice by the counter's side.
    box((1.6, 1.6, 1.6), (6.0, -0.8, 0.8), wood)
    box((1.4, 1.4, 0.3), (6.0, -0.8, 1.7), mat("ice", (210, 235, 245)))
    # Fish-shaped sign mount.
    sphere(0.5, (0, 1.75, 12.3), accent, scale=(2.0, 0.4, 0.8), seg=(10, 6))
    cyl(0.5, 0.1, (1.25, 1.75, 12.3), accent, rot=(1.5708, 0, 0), verts=3)


if __name__ == "__main__":
    main_guard(build)
    finish("FishBuyerStand", replaces="Workspace.Lake.SellStand (Counter, PostL, PostR, Roof); keep the SellPrompt and sign on an invisible counter part",
           notes="Open front faces the lake. Base sits on the ground (y = 1).", view=(-30, 22))
