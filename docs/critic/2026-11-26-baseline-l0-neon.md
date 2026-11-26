# Critic: baseline-l0 (review, gemini-4-neon)

Date: 2026-11-26 16:08. Rubric: `look`.

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

**Score: 2.5/10**

This is a clear functional greybox with genuinely smart fishing-spot layout (weedbed, sunken logs, deep hole, creek riffle and pool), but as a pre-beauty-pass baseline it does not yet look like water or an inviting lake. The biggest blockers right now are opaque concrete-like water, broken floating water slabs in Cedar Creek, misconfigured dawn and golden-hour ClockTimes, and overlapping BillboardGuis that clip into buildings.

| Point | Score |
|---|---|
| composition | 3 |
| light | 2 |
| water | 1 |
| mood | 2 |
| want_to_fish | 3 |
| phone_readability | 3 |
| broken_or_ugly | 2 |

Top fixes:
1. Rebuild the water and seal the creek seams: replace the opaque matte grey pond surface and floating dark-blue deep-hole slab (03, 04) with translucent Roblox Terrain water or layered semi-transparent stylized water over a sloped, colour-tinted lakebed (darker in the deep hole, sandy/muddy near shore) with subtle ripples. Extend the Cedar Creek riffle water slab to connect cleanly down into the pool and tuck all water edges into the bank walls to eliminate the hollow pit in 09-riffle-dawn.jpg and the purple skybox gap in 10-pool-golden.jpg.
2. Build real Time-of-Day Lighting and Atmosphere presets: fix ClockTime so golden hour is actually low warm sun (~17.3 to 17.8) instead of starry night (02, 05, 07, 10) and dawn (~6.1 to 6.5) has warm low-angle light instead of flat midday blue (01, 06, 09). Add an Atmosphere object for horizon haze, tune OutdoorAmbient and Moon/Night lighting so grass does not glow unnaturally (02) and night pools stay readable on phones (12), and turn off dock lantern PointLights during daytime (01, 03, 06).
3. Break up the boxy horizon and fix sign clutter: add sloped banks, shoreline rocks, and a chunky low-poly treeline and distant hills around the perimeter so players do not stare at a 90-degree grass box and empty sky (03) or raw baseplate edges over black void (07). Set BillboardGui MaxDistance (around 45 to 60 studs) and raise StudsOffset above roofs and walls, or use physical 3D wooden signs, so labels stop stacking across the lake (06, 07) and clipping through posts and walls (01, 08, 11).

Strengths:
- The fishing-spot layout already communicates real fishing knowledge: distinct weedbed (05), sunken logs (06), marked deep hole (03), creek riffle (09), and creek pool (10) give players clear places to read.
- The chunky wooden dock planks and the Bait and Tackle stand with its blue-and-white striped awning and rod rack in 08-stands-noon.jpg show a charming, cohesive low-poly direction.
- Framing the dock directly between the two stalls in 01-dock-dawn.jpg creates a strong, intuitive central sightline toward the water.
- The warm lantern pools around the dock pilings in 05-weedbed-golden.jpg hint at a cozy evening mood once the surrounding water and sky catch up.

Broken or ugly:
- 09-riffle-dawn.jpg: The blue textured creek water slab terminates in mid-air over an empty grey pit with blue void visible underneath, plus a white gap at the far bend.
- 10-pool-golden.jpg and 12-pool-night.jpg: A continuous gap along the seam between the pool water and grass trench walls lets the purple skybox shine straight through the ground.
- 01-dock-dawn.jpg, 02-dock-golden.jpg, 08-stands-noon.jpg, 11-gate-noon.jpg: BillboardGui labels (Sell Fish, Bait and Tackle, Cedar Creek) clip through wooden stall posts, awnings, and the plank gate wall.
- 06-logs-dawn.jpg and 07-overview-golden.jpg: Oversized BillboardGuis have no distance fade and pile on top of each other across the pond.
- 03-dockend-noon.jpg and 04-dockend-night.jpg: The dark-navy deep-hole marker reads as a flat solid square hovering on top of matte beige/grey floor rather than deeper water.
- 02-dock-golden.jpg, 05-weedbed-golden.jpg, 07-overview-golden.jpg, 10-pool-golden.jpg: Golden-hour shots are pitched in dark starry night with a full moon rather than golden hour.
- 07-overview-golden.jpg: Sharp floating edges of the green baseplate drop off directly into black void.

Action taken: (fill in: what we changed, or why we didn't)
