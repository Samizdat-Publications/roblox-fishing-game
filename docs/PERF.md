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

## After L5a, 11/27/2026 (place version 61)

| Shot | Render CPU avg | CPU p95 | CPU worst | GPU avg |
|------|---------------:|--------:|----------:|--------:|
| 01-dock-dawn | 5.06 ms | 6.57 ms | 8.31 ms | 7.95 ms |
| 04-dockend-night | 4.99 ms | 6.07 ms | 6.67 ms | 9.14 ms |
| 07-overview-golden | 5.03 ms | 6.26 ms | 6.97 ms | 9.16 ms |
| 10-pool-golden | 5.17 ms | 7.17 ms | 9.05 ms | 10.37 ms |

Inside the budget. Client memory 2,116 MB, 58,555 instances (Studio included).

## After L5b, L5c and L6 (land, trees, clouds, weather), 11/27/2026 (place version 71)

| Shot | Render CPU avg | CPU p95 | CPU worst | GPU avg |
|------|---------------:|--------:|----------:|--------:|
| 01-dock-dawn | 5.30 ms | 8.26 ms | 28.10 ms | 9.37 ms |
| 04-dockend-night | 4.54 ms | 7.82 ms | 8.67 ms | 9.05 ms |
| 07-overview-golden | 4.35 ms | 7.31 ms | 8.47 ms | 7.39 ms |
| 10-pool-golden | 4.18 ms | 6.68 ms | 7.69 ms | 7.35 ms |

Averages inside the budget. One 28 ms frame on the first view (the first seconds after the camera jumps, likely terrain and clouds loading in); watch for it on the phone check. Client memory 2,371 MB, 60,052 instances (Studio included).

## Probe fields from leg 3 (N0, 11/27/2026)

`tools/shots/probe.luau` now pins graphics quality before it samples (Level21 on the desktop tier; Studio's Automatic drops low when its window is not in front) and also reports triangles and draw calls in view (`Stats.SceneTriangleCount`, `Stats.SceneDrawcallCount`) and texture, terrain, mesh-part and part graphics memory. Set `PHONE = true` at the top for the phone-tier stand-in: it sets the `LookTier` attribute to `phone` and graphics quality to Level 3, samples, then puts both back. Budgets for these are in the leg 3 plan, "Measurable checks" 3.

## Leg 3 budgets, measured at the proof corner (N0, 11/27/2026, place version 119 plus the corner)

Studio Play, HUD hidden, weather Clear, 3 to 4 s per view. Desktop tier = graphics quality Level 21 with Realistic lighting; phone stand-in = Level 3 with Soft lighting (the same PC, so a proxy only).

**Before** (place as it was, Level 21, Soft): render CPU 5.3 to 8.6 ms average across the 12 set A shots (worst single frame 49.6 ms once at the night shot, right after the camera jumped), 285,000 to 392,000 triangles and 153 to 336 draw calls in view, texture memory 61 MB, terrain 74 to 78 MB.

**After the corner** (hero dock, split stands with our variants, our meadow on all grass, painted boards and five shadow-casting lanterns):

| Shot | Tier | CPU avg | CPU worst | GPU avg | Triangles | Draw calls | Texture MB |
|---|---|---:|---:|---:|---:|---:|---:|
| 01-dock-dawn | desktop | 5.08 | 8.07 | 5.23 | 276,860 | 268 | 73 |
| 02-dock-golden | desktop | 4.71 | 6.25 | 4.18 | 276,861 | 268 | 73 |
| 08-stands-noon | desktop | 5.04 | 8.61 | 4.35 | 361,613 | 211 | 73 |
| 01-dock-dawn | phone | 4.16 | 5.42 | 5.06 | 259,250 | 308 | 73 |
| 02-dock-golden | phone | 4.35 | 7.67 | 5.27 | 259,682 | 309 | 73 |
| 08-stands-noon | phone | 4.38 | 7.33 | 7.42 | 193,622 | 199 | 73 |

**What this says.**
- Realistic costs nothing measurable here: at the same Level 21 the corner with Realistic is no slower than the old place with Soft (render CPU 5.0 against 6.5 at shot 01).
- The kit is cheap: 8 variants and one 1024 hero set added 12 MB of texture memory.
- GPU numbers are not reliable in Studio. When Studio's window is not in front, GPU time reads either near 0 or 21 to 25 ms (a throttled frame), so GPU averages swing between runs of the same view. Read render CPU, triangles, draw calls and memory; GPU only as a trend. The real GPU check is Stewart's frame counter on his PC and phone.
- The phone stand-in at shot 08 read 7.4 ms GPU against the plan's 6 ms. Given the throttling above that is not a clean reading; it is logged, and the first step-down (smaller maps and fewer shadows on the phone tier) is ready if Stewart's phone check shows a problem.

**Projection for the whole home lake (N1).** About 14 more families at 512 to 1024 (three maps each) and the stands' split meshes on every prop: roughly 60 to 70 MB more texture memory, so about 130 to 145 MB on the desktop tier (budget 200) and the same on the phone stand-in (budget 130). The phone tier will need its first step-down (half-size maps) by the end of N1; the desktop tier has room.

**Budgets, rewritten with these numbers.** Desktop: render CPU 7 ms average or less, worst frame under 16 ms (a single spike right after a camera jump is logged, not counted), 700,000 triangles, 600 draw calls, 200 MB textures, 170 MB terrain. Phone tier: 5 ms render CPU average, 350,000 triangles, 300 draw calls, 130 MB textures. GPU stays in the plan (11 ms desktop, 6 ms phone) but is only judged on Stewart's devices.
