# Critic: n1-round3-lake-identity (review, gemini-4-neon)

Date: 2026-11-27 18:30. Rubric: `identity`.

Files shown:
- `01-dock-dawn.jpg`
- `02-dock-golden.jpg`
- `03-dockend-noon.jpg`
- `04-dockend-night.jpg`
- `05-weedbed-golden.jpg`
- `06-logs-dawn.jpg`
- `07-overview-golden.jpg`
- `08-stands-noon.jpg`

**Score: 4.5/10**

The dock planks in 08-stands-noon.jpg and the golden-hour cattail cove in 05-weedbed-golden.jpg prove your Real-ish art direction can look genuinely bespoke and atmospheric, but most frames are still dominated by stock Roblox Smooth Terrain, stock Terrain Water, default noon skies, clashing low-poly foliage, and plain signboard typography. Replacing the stock ground materials, unifying the foliage and props to match the dock's craft, and giving the sky and signs a cohesive signature style will pull the whole lake out of the default-Roblox look fast.

| Point | Score |
|---|---|
| materials | 5 |
| signature | 4 |
| cohesion | 4 |
| stock_free | 4 |
| identity | 4.5 |

Top fixes:
1. Override stock Smooth Terrain materials in MaterialService (Grass, Ground, Sand, Mud, LeafyGrass) with muted, matte PBR MaterialVariants matching the dock wood and boulders in 05-weedbed-golden.jpg, and break up the scalloped voxel shoreline edges in 01-dock-dawn.jpg, 02-dock-golden.jpg, 06-logs-dawn.jpg, and 08-stands-noon.jpg with shoreline stones, pebbles, and reed tufts.
2. Replace the clashing low-poly and primitive props with Real-ish textured models: swap the faceted green bush (06-logs-dawn.jpg lower right), blobby deciduous trees (08-stands-noon.jpg far left), smooth cylinder logs with flat ends (06-logs-dawn.jpg center), and the untextured white SmoothPlastic block beside the dock (01, 02, 06, 07) for bark-textured sunken timber, consistent foliage, and a finished wooden boat or slip.
3. Replace the default bright-blue Roblox Sky and wispy Clouds (03-dockend-noon.jpg, 08-stands-noon.jpg) with a custom skybox, lower WaterReflectance and WaterWaveSize to reduce the glossy stock-water look (while fixing the night reflection seam in 04-dockend-night.jpg and dialing back Bloom in 07-overview-golden.jpg), and rebuild the flat blue/red/green boards in 08-stands-noon.jpg as weathered wooden signs with one bold, phone-readable signature font.

Strengths:
- The weathered dock in 08-stands-noon.jpg (spaced wood planks, grain, bolts, and bark-wrapped log pilings with end-grain rings) nails the Real-ish brief and looks hand-crafted.
- 05-weedbed-golden.jpg captures genuine fishing-game mood, combining detailed mossy boulders, layered cattails, warm low-angle light, and clear spot readability.
- The weathered vertical wood siding on the stalls and the centered sightline down the dock toward the bridge and mountain in 01-dock-dawn.jpg and 02-dock-golden.jpg create strong framing.
- Time-of-day lighting already shifts the feeling of the lake well, notably the warm dawn/golden transitions in 02-dock-golden.jpg and the quiet firefly-lit night mood around the glowing buoy in 04-dockend-night.jpg.

Broken or ugly:
- 04-dockend-night.jpg (lower-middle water): A hard horizontal reflection/lighting band cuts straight across the lake surface, breaking the night water illusion.
- 01-dock-dawn.jpg, 02-dock-golden.jpg, 06-logs-dawn.jpg, and 07-overview-golden.jpg (right side of the dock): An untextured white/grey SmoothPlastic rectangular block floats next to the dock like an unfinished placeholder.
- 07-overview-golden.jpg (upper third): Excessive golden-hour Bloom and Atmosphere haze blow out the sky and far lake into flat yellow-white glare.
- 08-stands-noon.jpg (left of the Bait and Tackle stall): The green chalkboard sign has tiny, low-contrast white text that is illegible on desktop and unreadable on a phone.

Reads as stock Roblox:
- Stock Roblox Smooth Terrain (Grass, Ground, Sand, Mud, LeafyGrass) in 01-dock-dawn.jpg (foreground), 02-dock-golden.jpg (foreground), 06-logs-dawn.jpg (bottom half), 07-overview-golden.jpg (shoreline and slopes), and 08-stands-noon.jpg (midground bank and lawns).: Displays default Roblox terrain textures and unmistakable jagged voxel-blended edges between grass, dirt, sand, and mud.
- Stock Roblox Terrain Water in 03-dockend-noon.jpg (lower half), 04-dockend-night.jpg (lower half), 05-weedbed-golden.jpg (center), 06-logs-dawn.jpg (center), and 08-stands-noon.jpg (foreground left and right).: Shows the default Roblox water normal-map ripple pattern, glossy specular dots, and sharp terrain-water shoreline edges.
- Stock Roblox Terrain Decoration grass in 03-dockend-noon.jpg (far shoreline banks), 07-overview-golden.jpg (bottom-left meadow), and 08-stands-noon.jpg (far-left bank and background horizon ridge).: Standard uniform spiky Roblox terrain grass tufts.
- Default Roblox Sky and Dynamic Clouds in 03-dockend-noon.jpg (top half), 08-stands-noon.jpg (top half), and the wispy cloud layer in 01-dock-dawn.jpg, 02-dock-golden.jpg, and 04-dockend-night.jpg.: Unmistakable default bright-blue noon sky gradient and stock Terrain Clouds appearance.
- Untextured white/grey SmoothPlastic rectangular block beside the right edge of the dock in 01-dock-dawn.jpg (center), 02-dock-golden.jpg (center), 06-logs-dawn.jpg (midground left-center), and 07-overview-golden.jpg (center).: Reads as a raw default SmoothPlastic part left in the water.
- Default blocky Roblox player avatar in 01-dock-dawn.jpg (center), 02-dock-golden.jpg (center), and 08-stands-noon.jpg (center).: Standard blocky Roblox character proportions (in a Santa hat and plaid pants) immediately anchor the scene as default Roblox.
- Low-poly faceted bush in 06-logs-dawn.jpg (lower right) and lumpy low-poly deciduous trees in 08-stands-noon.jpg (midground far left).: Generic stylized free-model mesh look with flat shaded facets that clashes heavily with the realistic dock wood.
- Smooth cylindrical floating logs in 06-logs-dawn.jpg (center water) and 07-overview-golden.jpg (lower-right cove).: Read as simple smooth dark cylinder parts with flat light-colored ends and tiny cone nubs rather than weathered bark-covered timber.
- Flat single-color signboard panels with plain Roblox fonts in 08-stands-noon.jpg (blue 'Bait and Tackle', red 'Sell Fish', green chalkboard, and small 'Your Pond' sign) and 05-weedbed-golden.jpg (far right 'Boat Slips' sign).: Plain untextured rectangular slabs with default-looking system fonts and no bespoke framing or surface wear.
- Primitive geometric fish roof-topper in 01-dock-dawn.jpg (far upper left), 02-dock-golden.jpg (far upper left), and 08-stands-noon.jpg (upper right atop Sell Fish).: Built from obvious basic shapes (a triangular wedge tail beside a rounded oval body).

Action taken: (fill in: what we changed, or why we didn't)
