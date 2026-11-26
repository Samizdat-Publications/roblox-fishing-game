# Performance budget

The beauty pass (L5) and the living lake (L6) must not make the game slow on a phone. This page holds the baseline and the budget. Measure with `tools/shots/probe.luau` (Client, during Play, camera pinned to a fixed shot).

## How to read the numbers

- Studio holds a window that is not in front to about 15 fps, so the raw frame time is always about 66.7 ms and means nothing.
- Render CPU and GPU time (from the Stats service) are what each frame costs. A phone at 30 fps has about 33 ms per frame for everything, and phones are several times slower than this PC, so the PC numbers must stay small.
- Studio's Device Simulator only changes the screen size and does not slow the GPU, so it cannot stand in for a phone. The real phone check is on Stewart's list.

## Baseline, 11/26/2026 (commit 0286de1, before L1)

PC, Studio Play mode, viewport 1237 x 787, graphics quality Automatic, HUD hidden, 4 seconds per view.

| Shot | Render CPU avg | CPU p95 | CPU worst | GPU avg |
|------|---------------:|--------:|----------:|--------:|
| 01-dock-dawn | 4.21 ms | 5.35 ms | 5.80 ms | 6.03 ms |
| 04-dockend-night | 4.15 ms | 5.31 ms | 5.49 ms | 6.23 ms |
| 07-overview-golden | 4.49 ms | 6.17 ms | 10.18 ms | 8.79 ms |
| 10-pool-golden | 4.01 ms | 4.84 ms | 6.15 ms | 6.22 ms |

Client memory 2,245 MB (Studio included), 58,122 instances (Studio included), 588 in the workspace.

## Budget for L5 and L6

- Render CPU average at most 2x the baseline (about 9 ms) at every shot, worst frame under 16 ms.
- GPU average at most 2x the baseline (about 18 ms at the overview, 12 ms elsewhere).
- If a step goes over, it gets cheaper before it ships (fewer shadows, fewer particles, lower part count), not the budget raised.
- After L5, Stewart opens the game on his own phone once and says whether it feels smooth.
