# Critic: N3 final creek (review, gemini-4-neon)

Date: 2026-11-28 03:37. Rubric: `look`.

Files shown:
- `09-riffle-dawn.jpg`
- `10-pool-golden.jpg`
- `11-gate-noon.jpg`
- `12-pool-night.jpg`

**Score: 5.5/10**

Cedar Creek already has a strong sense of place - a genuine woodland fishing spot with good pool framing, readable signage, cattails, a fallen log across the water, and charming night fireflies. What holds it back right now is overly dark, flat lighting that crushes foliage into black silhouettes (making dawn and night hard to read on a phone), a row of oddly shaped cloned trees around the pool, and very noticeable boxy whitewater strips on the dawn creek.

| Point | Score |
|---|---|
| composition | 7 |
| light | 4 |
| water | 5 |
| mood | 6 |
| want_to_fish | 6 |
| phone_readability | 5 |
| broken_or_ugly | 4 |

Top fixes:
1. Rebalance Lighting and add real lantern lights: raise Lighting.OutdoorAmbient and Lighting.EnvironmentDiffuseScale so shaded trees and banks stop crushing to black across all times of day; add warm golden Atmosphere.Color/Glare and ColorShift_Top for golden hour; and place warm orange PointLights inside the shore and gate lanterns so night fishing has a cozy focal glow on the path, reeds, and water (and darken the overly pale sand material so it stops reading like snow at night).
2. Replace the rectangular whitewater strips in 09-riffle-dawn.jpg: remove the flat, sharp-cornered white-streaked parts/beams on the creek surface and use alpha-feathered ParticleEmitters tucked behind each rock plus soft-edged transparent flow textures so riffle foam blends smoothly into the water.
3. Swap out and randomize the cloned pool trees in 10-pool-golden.jpg and 12-pool-night.jpg: replace the lumpy bent-tip conifers with the cleaner pointed pine models from 11-gate-noon.jpg, vary their Y-rotation, scale (0.75x to 1.3x), and distance from the shoreline, and add rocks and ferns along the far bank.

Strengths:
- Inviting pool composition in 10-pool-golden.jpg: the sandy bank, cattails, lantern post on the right, and fallen log across the water naturally draw your eye to places you actually want to cast.
- Pool water in 10-pool-golden.jpg has convincing sky reflections, pleasing ripple scale, and nice shallow clarity along the right edge.
- The Cedar Creek wooden archway and serif sign in 11-gate-noon.jpg look handcrafted and read clearly, and the layered pointed pine trees in that shot fit the Real-ish style well.
- Subtle fireflies hovering over the dark bank and water in 12-pool-night.jpg add real atmosphere, and the pale mist behind the left treeline in 09-riffle-dawn.jpg gives a believable early-morning chill.

Broken or ugly:
- Hard-edged rectangular whitewater foam patches with stretched white lines sit abruptly on the creek surface in 09-riffle-dawn.jpg, most jarring in the bottom-right foreground.
- The rounded conifer trees across the pool in 10-pool-golden.jpg and 12-pool-night.jpg all share an awkward bent teardrop nub on top and repeat at nearly identical rotations and heights.
- The shore lantern in 10-pool-golden.jpg and 12-pool-night.jpg has a glowing pane but casts zero light onto the post, path, cattails, or water.
- The dirt/sand path on the right bank in 12-pool-night.jpg reads as bright grey-white snow at night while the surrounding pool and far bank sink into near-black.
- Crushed near-black shadows on tree canopies and trunks appear even at midday in 11-gate-noon.jpg, contrasting harshly with the smooth bright-green terrain grass.

Action taken: (fill in: what we changed, or why we didn't)
