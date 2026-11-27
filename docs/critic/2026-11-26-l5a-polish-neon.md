# Critic: l5a-polish (review, gemini-4-neon)

Date: 2026-11-26 22:59. Rubric: `look`.

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

**Score: 4.5/10**

The game already has charming chunky low-poly props (the Bait and Tackle stand, Sell Fish stand, dock, cattails, and logs) and clear real-world fishing structure, plus promising dawn and golden-hour colour palettes. Right now, though, both the lake and Cedar Creek look like rectangular swimming pools cut into a flat floating baseplate, with ruler-straight edges, stark underwater shelves, empty horizons, and a broken open end on the creek that drops straight into the sky void.

| Point | Score |
|---|---|
| composition | 4 |
| light | 5 |
| water | 4 |
| mood | 4 |
| want_to_fish | 5 |
| phone_readability | 6 |
| broken_or_ugly | 3 |

Top fixes:
1. Break up the rectangular swimming-pool basins and close off the horizon: replace the ruler-straight lake and creek banks with angled, organic low-poly shorelines, shoreline boulders, and gently sloped underwater beds (removing the stark 90-degree underwater ledges in 05, 06, 10, and 12), cap the open void end of Cedar Creek in 09-riffle-dawn.jpg with a rocky hillside or bridge culvert, and surround the map perimeter with layered low-poly hills and clustered, varied-height trees so players never look out at a flat void or two lone identical trees.
2. Unify the chunky flat-colour art style and rebuild the Cedar Creek divider: replace the realistic Roblox Terrain grass and realistic WoodPlanks wall (11-gate-noon.jpg) with SmoothPlastic flat-vertex-coloured low-poly ground planes, grass tufts, and a chunky timber split-rail fence with a proper arched wooden gate so the ground and divider match the charming stands, dock, and cattails.
3. Tune Lighting, Atmosphere, and Water settings per time of day: reduce Atmosphere Haze and Glare during golden hour so the horizon stops blowing out solid yellow (07-overview-golden.jpg, 10-pool-golden.jpg); shift Terrain.WaterColor from pool-cyan to a deeper, slightly murkier lake blue-green with slightly lower WaterTransparency so underwater part seams hide better; and narrow the dock PointLight falloff at night (04-dockend-night.jpg) while giving the bobber/buoy a faint warm or reflective highlight so night views stay atmospheric and readable.

Strengths:
- Fishing spots read clearly as distinct real-world habitats: cattail weed beds with lily pads (05-weedbed-golden.jpg), submerged snag logs (06-logs-dawn.jpg), open deep water off the dock with a buoy (03-dockend-noon.jpg), and a riffle-and-pool creek (09-riffle-dawn.jpg, 10-pool-golden.jpg).
- The chunky low-poly stands and dock in 08-stands-noon.jpg have great personality - striped awnings, rod racks, hanging scale, and chunky timber planks read crisply and fit the target art style.
- Dawn and golden-hour sky gradients (01-dock-dawn.jpg, 02-dock-golden.jpg, 05-weedbed-golden.jpg) and warm pools of light around the dock lanterns and stands (07-overview-golden.jpg) already differentiate time of day at a glance.
- Clean, uncluttered viewport with strong foreground silhouettes that will scale down well to a phone screen once minor contrast and night-readability issues are fixed.

Broken or ugly:
- 09-riffle-dawn.jpg: At the bottom-left end of Cedar Creek, the water trench ends abruptly in midair, exposing the underside of the water and the pink sky void beneath a floating flat stone slab.
- 07-overview-golden.jpg: The flat square corners of the map float visibly in the empty yellow void on the bottom-left and top-right edges.
- 05-weedbed-golden.jpg, 06-logs-dawn.jpg, 10-pool-golden.jpg, 12-pool-night.jpg: Sharp, ruler-straight underwater ledges and bright rectangular L-shaped seams are clearly visible through the water, making the lake and creek pool look like tiled swimming pools.
- 01-dock-dawn.jpg and 02-dock-golden.jpg: The floating 'Sell Fish' and 'Bait and Tackle' BillboardGui labels clip behind the stand roofs when viewed from the land side.
- 04-dockend-night.jpg: Unnatural bright cyan glow fills the foreground water near the dock at night, creating a harsh band against dark navy water while leaving the red buoy hard to read.
- 11-gate-noon.jpg: The Cedar Creek barrier is an abrupt, flat realistic-textured WoodPlanks wall with a mismatched short post on the left and a tall lamp on the right, clashing heavily with the low-poly aesthetic.

Action taken: (fill in: what we changed, or why we didn't)
