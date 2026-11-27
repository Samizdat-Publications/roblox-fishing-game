# Critic: l5f2-light-signs (review, gemini-4-neon)

Date: 2026-11-27 03:27. Rubric: `look`.

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

**Score: 7.2/10**

This update is a clear step forward: dawn now feels genuinely cool and misty compared to the warm peach golden hour, noon is clean and crisp with no blotches, and the main pond's distinct fishing spots (weedbed, sunken logs, dock, and round Your Pond) read clearly at a glance. The biggest things holding the visuals back now are flat, hard-to-read night scenes (especially spotting the bobber in 04-dockend-night.jpg), overly neat smooth banks and bare water in Cedar Creek, and AlwaysOnTop signs bleeding across the whole lake from far away.

| Point | Score |
|---|---|
| composition | 7 |
| light | 7.5 |
| water | 6.5 |
| mood | 7 |
| want_to_fish | 7.5 |
| phone_readability | 7 |
| broken_or_ugly | 8 |

Top fixes:
1. Improve night readability and atmosphere (04-dockend-night.jpg, 12-pool-night.jpg): add a faint Neon tip or tiny PointLight to the bobber at night so it stays visible on phone screens, slightly raise Terrain.WaterReflectance and add subtle cool moonlight so night water shows ripples instead of turning flat navy-black, shorten the dock lanterns' PointLight.Range to remove the wide milky-green foreground wash in 04, and darken Atmosphere.Color and Decay at night so distant hills do not glow lighter than the black sky in 12.
2. Add natural stream structure and break up overly neat shorelines (09-riffle-dawn.jpg, 10-pool-golden.jpg, 07-overview-golden.jpg): place low-poly rocks, pebble banks, a sunken branch, and a subtle whitewater ripple/foam ParticleEmitter or scrolling decal in the Cedar Creek riffle and pool so they look like real moving trout water rather than smooth ditches, and paint irregular grass, rocks, and reeds across the uniform tan path ringing the main pond so it feels less like a racetrack.
3. Limit MaxDistance on AlwaysOnTop BillboardGuis and nudge the chalkboard reeds (01-dock-dawn.jpg, 06-logs-dawn.jpg, 08-stands-noon.jpg): set MaxDistance to roughly 45-60 studs (and scale down slightly) on Sell Fish, Bait and Tackle, and Your Pond so they stop drawing over trees from across the lake in 06 or clipping off the screen edges in 01 and 02, and move the cattails in front of the green chalkboard in 08 a few studs left so the text is unobstructed.

Strengths:
- Clear time-of-day mood contrast: 01-dock-dawn.jpg and 06-logs-dawn.jpg have a soft lavender-blue morning mist that feels completely distinct from the rich warm sunset in 02-dock-golden.jpg and 05-weedbed-golden.jpg.
- Strong fishing spot identity on the main pond: 05-weedbed-golden.jpg (cattails and pink lily pads) and 06-logs-dawn.jpg (half-submerged timber) immediately tell an angler where fish would hide.
- Crisp, charming low-poly hub in 08-stands-noon.jpg and 11-gate-noon.jpg: the striped awnings, scale, rod rack, dock planks, stone-ringed Your Pond, and open Cedar Creek archway read cleanly with zero visual clutter at noon.
- Daytime and golden hour water looks lively and inviting, especially the warm reflections dancing across the teal water in 05-weedbed-golden.jpg and 10-pool-golden.jpg.

Broken or ugly:
- In 06-logs-dawn.jpg, AlwaysOnTop shop labels (Sell Fish, Bait and Tackle, and a clipped cyan letter on the far left edge) render right through distant trees from across the pond.
- In 01-dock-dawn.jpg and 02-dock-golden.jpg, the Sell Fish and Bait and Tackle signs clip past the left and right edges of the screen when standing near the dock path, and thin dark horizontal striping shows on the brown stall corner posts.
- In 08-stands-noon.jpg, a clump of cattails sits directly in front of the green chalkboard and covers the right half of its text.
- In 04-dockend-night.jpg, the red-and-white bobber nearly disappears against pitch-black water while a bright green-tinted light spill dominates the foreground.
- In 12-pool-night.jpg, night Atmosphere haze makes the distant hills brighter blue-gray than the jet-black sky behind them.

Action taken: Not yet: see run 2.
