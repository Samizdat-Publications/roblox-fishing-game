# Critic: l5f2-light-signs (review, gemini-4-neon)

Date: 2026-11-27 03:26. Rubric: `look`.

Files shown:
- `01-dock-dawn.jpg`
- `02-dock-golden.jpg`
- `03-dockend-noon.jpg`
- `04-dockend-night.jpg`
- `05-weedbed-golden.jpg`
- `06-logs-dawn.jpg`
- `07-overview-golden.jpg`
- `08-stands-noon.jpg`
- `09-riffle-dawn.jpg`
- `10-pool-golden.jpg`
- `11-gate-noon.jpg`
- `12-pool-night.jpg`

**Score: 7/10**

This update is a real step forward: the cool lavender dawn and warm golden hour now feel genuinely distinct, noon water is clean, the open Cedar Creek gate looks tidy, and the round Your Pond and meadow grass add lots of charm. The biggest things holding the look back are night lighting and bobber readability, clipped AlwaysOnTop signs with inconsistent contrast, and a few overly geometric paths and creek banks that still feel man-made rather than wild.

| Point | Score |
|---|---|
| composition | 7 |
| light | 6.5 |
| water | 6 |
| mood | 7 |
| want_to_fish | 7.5 |
| phone_readability | 6 |
| broken_or_ugly | 7 |

Top fixes:
1. Rework night lighting and bobber visibility (04-dockend-night.jpg, 12-pool-night.jpg): lower night Atmosphere.Color and Atmosphere.Decay to deep navy so distant hills do not glow pale blue-grey against the black sky, add subtle cool moonlight directional lighting so water ripples catch highlights instead of going flat black, change dock PointLights to a warmer amber with tighter Range to remove the greenish water wash, and add a small Neon glowing tip or faint PointLight to the bobber at night.
2. Tighten BillboardGui sign distance and contrast (01-dock-dawn.jpg, 02-dock-golden.jpg, 06-logs-dawn.jpg, 08-stands-noon.jpg): set MaxDistance around 45 to 60 studs and disable AlwaysOnTop at long range so signs stop clipping off screen edges or floating over distant trees, lighten the Bait and Tackle text to bright sky blue or white on its dark pill, and give Your Pond the same dark backing pill for phone readability.
3. Naturalize the creek riffle, pool banks, and pond path (07-overview-golden.jpg, 09-riffle-dawn.jpg, 10-pool-golden.jpg): curve and widen the riffle slightly with low-poly river stones and white ripple particles so it reads as moving water rather than a straight blue trench, add reeds, rocks, and low bushes along the bare right-hand sand ramp of the creek pool, and vary the width and shoreline edges of the uniform beige racetrack path around the main pond.

Strengths:
- Distinct, atmospheric time-of-day shifts: cool pink-lavender dawn in 01-dock-dawn.jpg, 06-logs-dawn.jpg, and 09-riffle-dawn.jpg contrasts nicely with warm peach-gold evening light in 02-dock-golden.jpg, 05-weedbed-golden.jpg, and 10-pool-golden.jpg.
- Clean noon water and sky in 03-dockend-noon.jpg and 08-stands-noon.jpg with no distracting orange blotches.
- Fishing structure reads immediately like real water you want to cast into: cattails and lily pads in 05-weedbed-golden.jpg, sunken logs in 06-logs-dawn.jpg, and deep open water off the dock in 03-dockend-noon.jpg.
- Charming hub and progression details: the round stone-ringed Your Pond with visible fish in 07-overview-golden.jpg, detailed market stalls in 08-stands-noon.jpg, clean open gate archway in 11-gate-noon.jpg, and tall creek meadow grass in 09-riffle-dawn.jpg.

Broken or ugly:
- Clipped AlwaysOnTop BillboardGui text at screen edges: l Fish and Bait and T in 01-dock-dawn.jpg and 02-dock-golden.jpg, plus a stray clipped green letter d on the far left edge of 06-logs-dawn.jpg.
- Thin dark horizontal striping artifacts visible on the dark brown corner posts of both stalls in 01-dock-dawn.jpg and 02-dock-golden.jpg.
- Washed-out pale blue-grey distant hills contrasting abruptly with a pitch-black sky in 12-pool-night.jpg due to bright night Atmosphere settings.
- Greenish light wash on the near water while the red bobber nearly disappears into black mid-water in 04-dockend-night.jpg.
- Low-contrast blue text on a dark translucent pill for the Bait and Tackle sign in 08-stands-noon.jpg.
- Steep, blocky green terrain wall dropping into the water right below the sandy path in 08-stands-noon.jpg.

Action taken: Not yet: night water and bobber, sign fade distance and Bait and Tackle text contrast, creek pool bank, lake path width. Logged in PROGRESS as the next asks.
