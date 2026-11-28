# Critic: N3 creek round 2 (review, gemini-4-neon)

Date: 2026-11-28 00:01. Rubric: `look`.

Files shown:
- `09-riffle-dawn.jpg`
- `10-pool-golden.jpg`
- `11-gate-noon.jpg`
- `12-pool-night.jpg`

**Score: 5.5/10**

This has a genuinely charming Real-ish foundation - especially the chunky pine trees and the gorgeous golden-hour light streaming across the pool in 10-pool-golden.jpg - that already hints at a memorable fishing spot. Right now, however, opaque swirled Roblox terrain water, a stark unfinished right-hand shoreline, an unlit night lantern, and a tree-blocked dawn riffle hold it back from feeling like a place where you can comfortably read the water and settle in to fish.

| Point | Score |
|---|---|
| composition | 5 |
| light | 6 |
| water | 4 |
| mood | 6 |
| want_to_fish | 6 |
| phone_readability | 5 |
| broken_or_ugly | 6 |

Top fixes:
1. Dial in the Terrain Water and dress the shoreline: lower Terrain.WaterWaveSize (around 0.05 to 0.1) and WaterWaveSpeed to remove the oily marbled swirls in 10-pool-golden.jpg and grey blotches in 12-pool-night.jpg, raise WaterTransparency (around 0.5 to 0.7) over a pebbled/muddy riverbed so players can actually read depth and shallows, and replace the smooth, steeply sloped bare sand bank on the right of the pool with a flatter grassy/pebbled casting spot lined with half-submerged rocks, ferns, and thicker reed clusters.
2. Fix night lighting and soften midday contrast: put a warm amber PointLight (Shadows enabled, range around 20 studs) inside the lantern in 12-pool-night.jpg so it casts a cozy pool of light onto the casting bank and water, swap the pale Sand bank material for darker Ground/Dirt/Pebble so it stops glowing snow-white at night, and add subtle Atmosphere haze and slightly less saturated greens to 11-gate-noon.jpg so noon stops looking flat and harsh.
3. Open up the riffle view, thicken the background woods, and enlarge signage: move or remove the two foreground pine trunks blocking the water in 09-riffle-dawn.jpg so the shallow riffle is clearly visible, add a second staggered row of pines and low shrubs behind the far bank of the pool so the bright meadow does not show through a single thin row of trunks, and make the Cedar Creek gate sign text much larger and bolder in 11-gate-noon.jpg so it reads cleanly on a phone.

Strengths:
- 10-pool-golden.jpg has wonderful evening mood: low golden sunbeams cutting through the pine trunks and catching the water immediately create a calm fishing atmosphere.
- The chunky pine trees with textured bark and layered foliage fit the Real-ish art direction well and give Cedar Creek a cohesive, hand-crafted silhouette.
- Small environmental storytelling details - the Cedar Creek timber gate and split-rail fence in 11-gate-noon.jpg, the fallen log across the far side of the pool, bankside cattails, and tiny night fireflies in 12-pool-night.jpg - make the place feel cared for.
- 09-riffle-dawn.jpg captures a convincing cool early-morning sky with soft pinkish-blue horizon haze and warm dawn light grazing the foreground tree bark.

Broken or ugly:
- In 12-pool-night.jpg, the wooden post lantern on the right has a lit pale panel yet casts zero light onto the post, ground, or water.
- In 10-pool-golden.jpg and 12-pool-night.jpg, the Terrain Water shows harsh, oily-looking marbled reflections by sunset and bright grey-white blotches at night, with no visible shallow transparency along the banks.
- In 09-riffle-dawn.jpg, two thick foreground pine trunks block almost the entire view of the riffle (leaving only a tiny blue corner of water), and the bottom-left grass has blurry pale-grey terrain blend patches.
- In 10-pool-golden.jpg and 12-pool-night.jpg, the right-hand bank is a steep, bare, overly smooth strip of light terrain that looks artificial in daylight and reads like snow at night.

Action taken: (fill in: what we changed, or why we didn't)
