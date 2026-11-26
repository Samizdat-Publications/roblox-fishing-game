"""Marker buoy for the deep hole: red and white can buoy with a little cone top.
Replaces Workspace.Lake.DeepHoleBuoy (1.6 x 2.4)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import cone, cyl, finish, main_guard, mat, sphere  # noqa: E402


def build():
    red, white, metal = mat("red"), mat("white"), mat("metal")
    cyl(0.8, 1.0, (0, 0, 0.5), red, verts=12)
    cyl(0.82, 0.45, (0, 0, 1.2), white, verts=12)
    cyl(0.8, 0.6, (0, 0, 1.7), red, verts=12)
    cone(0.8, 0.7, (0, 0, 2.35), red, verts=12)
    cyl(0.05, 0.6, (0, 0, 2.9), metal, verts=4)
    sphere(0.12, (0, 0, 3.25), mat("lamp", emit=4), subdiv=1)
    cyl(0.9, 0.12, (0, 0, 0.25), metal, verts=12)  # chain collar


if __name__ == "__main__":
    main_guard(build)
    finish("Buoy", replaces="Workspace.Lake.DeepHoleBuoy", notes="Base at the water line minus about 0.6 so it floats.", view=(30, 15))
