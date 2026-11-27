# Critic: n1-round1-lake (review, gemini-4-neon)

Date: 2026-11-27 18:13. Rubric: `look`.

Files shown:
- `01-dock-dawn.jpg`
- `02-dock-golden.jpg`
- `03-dockend-noon.jpg`
- `04-dockend-night.jpg`
- `05-weedbed-golden.jpg`
- `06-logs-dawn.jpg`
- `07-overview-golden.jpg`
- `08-stands-noon.jpg`

**Score: 7.5/10**

This already feels like a real, memorable northern lake you would want to spend an evening fishing. The weathered dock planks, cozy bait and sell stands, distinct fishing habitats (dock pilings, cattail cove, submerged logs, bridge channel), and dawn/golden-hour mood hit the Real-ish art target very well. The main things holding it back are a harsh golden-hour glare blowout from higher angles, flat noon lighting and water, a few rough props up close (blocky cattails, faceted background trees, spiky night fireflies), and bare grass both in front of and behind the stands.

| Point | Score |
|---|---|
| composition | 8 |
| light | 7 |
| water | 7 |
| mood | 8 |
| want_to_fish | 8 |
| phone_readability | 7 |
| broken_or_ugly | 6 |

Top fixes:
1. Fix the golden-hour lighting blowout in 07-overview-golden.jpg: reduce Atmosphere.Glare (keep around 0.2 to 0.4), lower Atmosphere.Density/Haze slightly, and dial back SunRaysEffect.Intensity and Spread so the sun stops creating that sharp vertical white-orange wall across the lake and washing out elevated views.
2. Dress the bare grass approach and backdrop around the stands: in 01-dock-dawn.jpg and 02-dock-golden.jpg, add a worn dirt or gravel footpath, grass tufts, stepping stones, and a couple of lakeside props (bench, tackle crates, boat rack) to break up the huge flat green foreground; in 08-stands-noon.jpg, add a denser treeline behind the stands to hide the empty horizon gap and replace the blocky faceted deciduous trees on the far left so they match the pine and birch style.
3. Upgrade the closest props and tune noon/night readability: give the cattail blades in 05-weedbed-golden.jpg and 08-stands-noon.jpg tapered, slightly angled shapes instead of straight rectangular blocks; swap the spiky 8-point star firefly texture in 04-dockend-night.jpg for a smaller soft circular warm-yellow glow and slightly raise night OutdoorAmbient (cool moonlight tint) for phone visibility; and enrich noon (03, 08) by deepening Terrain.WaterColor to a slightly darker lake teal-green with subtle Atmosphere.Haze so midday feels less flat.

Strengths:
- Strong sightlines and framing: 01-dock-dawn.jpg and 02-dock-golden.jpg neatly frame the dock, bridge, and distant mountain right between the two wooden stands.
- Excellent Real-ish hero materials on the dock and shore in 08-stands-noon.jpg and 05-weedbed-golden.jpg: the weathered plank grain, nail heads, log pilings, slip numbers, striped awnings, and sunlit shoreline boulders look genuinely tactile.
- Believable fish-holding structure across the map: cattail weedbeds with lily pads (05), submerged logs (06), dock pilings (08), and the buoyed channel under the bridge (03) immediately tell a fisherman where to cast.
- Distinct time-of-day atmosphere: misty cool dawn (01, 06), warm golden hour at shore level (02, 05), and quiet starlit night with a warm buoy light reflecting on the water (04) give the lake real mood.

Broken or ugly:
- 07-overview-golden.jpg: Severe vertical light/glare seam slicing down the middle-left of the lake and extreme orange haze washing out nearly all detail.
- 05-weedbed-golden.jpg and 08-stands-noon.jpg: Cattail reeds are stark, untapered rectangular green blocks poking straight out of the sand, clashing with the detailed rocks and dock wood.
- 08-stands-noon.jpg: Low-poly faceted green trees on the far left clash with the more detailed pines and birches, and the two wooden info boards to the left of Bait and Tackle visually crowd/overlap each other.
- 04-dockend-night.jpg: Firefly particles use an oversized spiky star-glare sprite (especially prominent in the bottom-left foreground) rather than soft firefly points.
- 06-logs-dawn.jpg: Submerged logs read as smooth uniform cylinders with flat cut ends and tiny straight pegs, and a sharp pine branch clips into the top-right corner of the view.
- 03-dockend-noon.jpg: The bright flat-green wedge abutments on the distant bridge look untextured and stark against the sandy banks.

Action taken: (fill in: what we changed, or why we didn't)
