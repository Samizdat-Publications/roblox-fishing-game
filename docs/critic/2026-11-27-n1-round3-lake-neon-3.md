# Critic: n1-round3-lake (review, gemini-4-neon)

Date: 2026-11-27 18:26. Rubric: `look`.

Files shown:
- `01-dock-dawn.jpg`
- `02-dock-golden.jpg`
- `03-dockend-noon.jpg`
- `04-dockend-night.jpg`
- `05-weedbed-golden.jpg`
- `06-logs-dawn.jpg`
- `07-overview-golden.jpg`
- `08-stands-noon.jpg`

**Score: 7/10**

This lake already has genuine charm and clear fishing-game intent: the weathered plank dock, golden-hour light, and distinct habitats like the cattail weedbed and sunken logs make you immediately want to cast a line. It is held back from looking truly polished by a hard horizontal band artifact in the night water, overblown golden-hour glare from above, flat midday lighting, bare uniform gravel shorelines, and a few placeholder or clashing props.

| Point | Score |
|---|---|
| composition | 7 |
| light | 7 |
| water | 6 |
| mood | 7 |
| want_to_fish | 8 |
| phone_readability | 6 |
| broken_or_ugly | 6 |

Top fixes:
1. Fix the night water artifact and balance lighting across all times of day: investigate and remove the straight horizontal band cutting across the lower third of the water in 04-dockend-night.jpg (check Atmosphere Offset/Haze, skybox lower-hemisphere reflection, or a flat depth shelf in Terrain water), lower WaterReflectance/WaterWaveSize slightly at night so dark water does not turn into noisy pale swirls, tone down Atmosphere Glare and Bloom at golden hour so 07-overview-golden.jpg stops washing out the horizon, and add light Atmosphere Haze and softer sun warmth at noon (03-dockend-noon.jpg, 08-stands-noon.jpg) to eliminate the flat midday look.
2. Dress up the bare gravel shoreline and empty backdrop behind the shops: break up the smooth uniform gravel ring around the pond (06-logs-dawn.jpg, 07-overview-golden.jpg, 08-stands-noon.jpg) with shoreline rocks, reeds, patches of wet mud/grass, and varied bank height; replace the clean-cut cylindrical logs and lone faceted bush in 06-logs-dawn.jpg with weathered tapered trunks and multi-part foliage; and add a fuller treeline and hills behind Bait and Tackle and Sell Fish in 08-stands-noon.jpg so the skyline does not look empty.
3. Replace placeholder props and fix tiny signage for desktop and phone readability: replace the plain white box floating beside the right side of the dock (01-dock-dawn.jpg, 02-dock-golden.jpg, 06-logs-dawn.jpg, 07-overview-golden.jpg) with a proper wooden boat or textured slip, unify the flat-slab pine (left of 05-weedbed-golden.jpg) and smooth round-ball trees (left of 08-stands-noon.jpg) with your main evergreens, and replace the tiny illegible white text on the green chalkboard next to Bait and Tackle (08-stands-noon.jpg) with bold short headers plus an interactable UI panel.

Strengths:
- The dock craftsmanship in 08-stands-noon.jpg nails the Real-ish style, with chunky weathered planks, nail heads, rough log pilings, cleats, and numbered slips that read cleanly as real wood.
- 05-weedbed-golden.jpg is the standout shot: foreground boulders, rippled sand, cattails, pink lilypads, warm reflections, and the distant bridge create a believable, memorable fishing spot.
- Strong sightlines in 01-dock-dawn.jpg and 02-dock-golden.jpg frame the path between the two wooden stalls straight down the dock to the channel buoy, bridge, and distant hill.
- Fishing structure is readable at a glance across the pond (cattail cove, sunken logs cove, open-water buoy near the bridge), which directly supports real fishing knowledge gameplay.
- 04-dockend-night.jpg has thoughtful atmosphere with glowing fireflies and a lit red-and-white buoy reflecting on the dark water.

Broken or ugly:
- 04-dockend-night.jpg has a stark straight horizontal seam/band cutting across the entire lower third of the water surface, separating dark water above from a hazy light-blue band below.
- 07-overview-golden.jpg has severe golden-hour haze and bloom blow-out across the upper-left sky and distant hills, washing out detail.
- 01-dock-dawn.jpg, 02-dock-golden.jpg, 06-logs-dawn.jpg, and 07-overview-golden.jpg show an untextured bright white rectangular slab floating right beside the right side of the dock.
- 06-logs-dawn.jpg has an awkward stray pine branch jutting into the top-right corner, harsh dark brown mud blobs meeting light grey gravel, a lone blocky faceted bush on bare sand, and sunken logs with flat freshly sawed tan ends.
- 07-overview-golden.jpg shows two freestanding flat brown boards sitting isolated in bare grass behind the right-hand shop stand.
- 08-stands-noon.jpg shows green chalkboard text beside Bait and Tackle that is too small and thin to read even on desktop, and smooth round-blob trees on the far left that clash with the pine style.

Action taken: (fill in: what we changed, or why we didn't)
