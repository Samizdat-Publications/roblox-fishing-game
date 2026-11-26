# Critic: baseline-l0 (review, gemini-4-neon)

Date: 2026-11-26 16:10. Rubric: `look`.

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

This pre-beauty-pass baseline has smart gameplay bones - distinct fishing spots like the weedbed, sunken logs, deep hole, and creek riffle are easy to understand - and a charming chunky low-poly dock and tackle stand. Right now, though, flat matte water, boxy 90-degree grass pits with an empty horizon, off-clock lighting (golden shots are actually night), clipping signs, and a floating creek water slab keep it looking like an early greybox rather than a place you want to linger and fish.

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
1. Overhaul the water and seal the creek geometry: replace the flat grey pond floor and floating blue deep-zone tile (03-dockend-noon.jpg) with either Roblox Terrain Water (tuned WaterColor, WaterTransparency, WaterReflectance, and gentle WaterWaveSize) or a translucent reflective water surface over a sloped lakebed whose deeper center naturally darkens the water; simultaneously lower and seal the floating riffle slab (09-riffle-dawn.jpg) and close the purple seam along the pool bank (10-pool-golden.jpg).
2. Create real Lighting and Atmosphere LookPresets for each time of day: move Dawn (~6:15) and Golden Hour (~17:45) onto actual low-angle sun times with warm Atmosphere Color/Decay, SunRaysEffect, and soft shadows so dawn stops looking like midday (01, 06, 09) and golden hour stops looking like night with stars and a moon (02, 05, 07, 10); tone down night OutdoorAmbient so grass stops glowing bright green (02-dock-golden.jpg), soften harsh circular lantern PointLights (01, 04, 07), and add subtle moonlit fill at the creek pool (10, 12) so dark water and banks remain readable on a phone.
3. Soften the boxy world silhouette and fix sign placement: replace the straight 90-degree grass trenches (03, 07, 09) with sloped low-poly banks, varied shoreline rocks, and a background ring of chunky low-poly hills and multi-sized trees to frame the view and hide the floating baseplate void (07-overview-golden.jpg); raise every BillboardGui via StudsOffset above roofs and walls and set MaxDistance to ~50 studs so labels stop clipping into posts/walls (01, 08, 11) or piling on top of each other across the lake (06-logs-dawn.jpg).

Strengths:
- Clear fishing-spot design: the weedbed (05-weedbed-golden.jpg), submerged logs (06-logs-dawn.jpg), deep drop-off with buoy (03-dockend-noon.jpg), and separate creek riffle/pool (09-riffle-dawn.jpg, 10-pool-golden.jpg) immediately suggest different habitats and tactics.
- Charming chunky low-poly focal props: the wooden dock planks and posts (08-stands-noon.jpg) and the Bait and Tackle stall with its blue-and-white awning and rod rack (01-dock-dawn.jpg, 08-stands-noon.jpg) fit the intended art direction well.
- Good core hub framing: placing Sell Fish and Bait and Tackle on either side of the dock path (01-dock-dawn.jpg) naturally draws the eye straight toward the pier and the water.

Broken or ugly:
- 09-riffle-dawn.jpg: The blue textured riffle water slab visibly floats in mid-air above an open gap in the foreground, and a bright white sky seam pokes through the far end of the creek trench.
- 10-pool-golden.jpg: A bright purple seam leaks along the entire back waterline where the dark pool water meets the vertical grass bank (also visible as a dark gap in 12-pool-night.jpg).
- 01-dock-dawn.jpg, 02-dock-golden.jpg, 08-stands-noon.jpg, 11-gate-noon.jpg: BillboardGui signs clip behind wooden posts, awnings, and the Cedar Creek wall ('Sell Fis', 'Ba', 'B a t and Ta ckle', '...dar Creek'), and overlap into an unreadable jumble from across the pond in 06-logs-dawn.jpg.
- 02-dock-golden.jpg, 05-weedbed-golden.jpg, 07-overview-golden.jpg, 10-pool-golden.jpg: ClockTime for 'golden' is set in deep twilight/night (stars and full moon visible) instead of golden hour, while 'dawn' shots (01, 06, 09) read as plain midday blue.
- 03-dockend-noon.jpg, 04-dockend-night.jpg: The deep-water area looks like a solid dark-blue square mat floating on top of a flat grey-tan surface rather than underwater depth.
- 07-overview-golden.jpg: Sharp rectangular edges of the map drop straight into black empty void.

Action taken: (fill in: what we changed, or why we didn't)
