# Critic: n1-home-lake (review, gemini-4-neon)

Date: 2026-11-27 16:58. Rubric: `look`.

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

**Score: 6.8/10**

The main lake already has genuine charm and real fishing appeal: the weathered dock planks, golden-hour weedbed cove, submerged timber, and misty dawn horizons nail the calm Real-ish mood and make you want to cast a line. What holds the game back is an inconsistent second area (Cedar Creek looks flat-shaded, boxy, and sparse compared to the lake), an overblown golden-hour glare artifact in the overview, and dark, hard-to-read night lighting.

| Point | Score |
|---|---|
| composition | 6.5 |
| light | 6.5 |
| water | 7 |
| mood | 7 |
| want_to_fish | 7.5 |
| phone_readability | 7 |
| broken_or_ugly | 5.5 |

Top fixes:
1. Unify Cedar Creek's assets and terrain with the main lake (09-riffle-dawn.jpg, 10-pool-golden.jpg, 11-gate-noon.jpg): swap the flat-shaded smooth grey boulder in 09 and the smooth-cone pines in 08-12 for the textured rock meshes from 05 and the lake's textured conifers, reshape 10's boxy 90-degree pond edges into organic curved banks, and widen 09's narrow ditch into a shallow stony stream with moving whitewater so it looks fishable.
2. Tune golden-hour glare and night moonlight in Lighting and Atmosphere (07-overview-golden.jpg, 04-dockend-night.jpg, 12-pool-night.jpg): reduce Atmosphere.Glare, Atmosphere.Haze, and SunRaysEffect.Intensity so the sun no longer washes out the lake or creates the sharp vertical glow seam in 07; at night, raise OutdoorAmbient slightly with a cool blue moonlit fill and add gentle lantern light pools so shorelines stay readable on a phone, and replace the sharp 8-point star firefly sprites with soft round glow dots.
3. Dress the empty approach behind the dock and clean up prop rough edges (01-dock-dawn.jpg, 02-dock-golden.jpg, 05-weedbed-golden.jpg, 08-stands-noon.jpg, 10-pool-golden.jpg): add a gravel path, tufts of grass, benches, or tackle crates across the bare green lawn in 01 and 02 so players are not staring past two blank stall backs, move the cattails blocking the left chalkboard in 08, replace the sharp rectangular green cattail blocks in 05 with tapered stalks, and straighten the crooked glowing post in 10 and 12.

Strengths:
- 05-weedbed-golden.jpg is a standout spot: warm low sunlight across textured boulders, lily pads among the reeds, and sunset reflections immediately read as prime bass and panfish cover.
- 08-stands-noon.jpg nails the Real-ish art style on the dock, with chunky weathered wood planks, nail heads, stubby pilings, cleats, and crisp Bait and Tackle and Sell Fish signs that will still read well on a phone.
- The main lake offers clear, readable fishing structure - weedbeds (05), submerged logs (06), dock pilings (08), and a bridge channel marked by a buoy (03) - that naturally invites spot-based fishing knowledge.
- Dawn and golden hour on the main lake (01, 02, 05, 06) deliver a calm, memorable lakeside mood with layered mist over the distant hills and inviting water reflections.
- Clean, unobstructed screen presentation with world-integrated signage instead of cluttered HUD elements.

Broken or ugly:
- 07-overview-golden.jpg: extreme orange sun glare and haze wash out the entire lake and produce a harsh vertical lighting seam cutting down the center of the water.
- 09-riffle-dawn.jpg: the central rock mound is smooth, flat-shaded grey geometry with no stone texture (clashing with the textured boulders in 05), and the riffle is a tiny narrow trench rather than a fishable creek.
- 10-pool-golden.jpg and 12-pool-night.jpg: the pool shoreline forms unnatural straight boxy corners like a dug-out retention basin, and the right-hand lamp post leans at an awkward angle while casting a hard rectangular shadow at night.
- 08-stands-noon.jpg: a cluster of cattails sits directly in front of the left chalkboard and partially obscures its text; faceted low-poly trees on the far left clash with the textured pines.
- 05-weedbed-golden.jpg: foreground cattails on the left are chunky, sharp-edged rectangular green prisms sticking straight out of smooth sand.
- 06-logs-dawn.jpg: a dark tree trunk and sharp foliage corner clip into the left and top-right camera edges, and the submerged logs read as repeated plain cylinders with stiff peg branches.
- 04-dockend-night.jpg and 12-pool-night.jpg: fireflies use harsh 8-point star textures (one looks oversized in the lower left of 04) and the pitch-dark shorelines lose shape on smaller screens.

Action taken: (fill in: what we changed, or why we didn't)
