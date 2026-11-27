# Critic: n1-home-lake-identity (review, gemini-4-neon)

Date: 2026-11-27 17:04. Rubric: `identity`.

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

**Score: 4/10**

The hub dock, rustic bait stalls, and mossy shore boulders show real promise and prove you can hit your Real-ish target, especially in dawn and golden-hour light. Outside that focal area, however, the game still reads heavily as a default Roblox Terrain map mixed with clashing low-poly SmoothPlastic trees, rocks, and props - most noticeably in the Cedar Creek shots and at noon.

| Point | Score |
|---|---|
| materials | 5 |
| signature | 4 |
| cohesion | 4 |
| stock_free | 3 |
| identity | 4 |

Top fixes:
1. Override stock Roblox Terrain materials (Grass, LeafyGrass, Sand, Mud) in MaterialService with custom muted PBR MaterialVariants that match the realistic dock wood (08-stands-noon.jpg) and mossy boulders (05-weedbed-golden.jpg), and desaturate the default bright-green Grass color visible in 10-pool-golden.jpg and 11-gate-noon.jpg.
2. Replace every smooth low-poly SmoothPlastic asset - specifically the stacked-cone pines (09-riffle-dawn.jpg, 10-pool-golden.jpg, 11-gate-noon.jpg), faceted blob trees (08-stands-noon.jpg left), smooth grey boulders (09-riffle-dawn.jpg center, 10-pool-golden.jpg right bank), and square-stick cattails (05-weedbed-golden.jpg foreground) - with PBR-textured meshes matching your textured shoreline boulders and dock.
3. Replace stock VFX, skies, and placeholder props: swap the spiky default firefly particle texture in 04-dockend-night.jpg and 12-pool-night.jpg for a soft round glow sprite, replace the Neon-sphere poles (10-pool-golden.jpg, 11-gate-noon.jpg, 12-pool-night.jpg) with matching wooden dock lanterns, and use a custom painterly Sky with softer Terrain Water settings (lower wave size and reflectance) to fix the harsh default noon look in 03-dockend-noon.jpg and 08-stands-noon.jpg.

Strengths:
- The dock planks and sawed log pilings in 08-stands-noon.jpg nail the Real-ish goal with chunky silhouettes and convincing weathered wood grain, knots, and nail holes.
- The Bait and Tackle and Sell Fish stalls (01-dock-dawn.jpg, 02-dock-golden.jpg, 08-stands-noon.jpg) and Cedar Creek gate (11-gate-noon.jpg) use restrained serif signage and weathered planks that feel handmade rather than stock Roblox UI.
- The mossy foreground boulders in 05-weedbed-golden.jpg have rich stone texture and catch raking golden-hour light well.
- Dawn and golden-hour lighting around the main lake (01-dock-dawn.jpg, 02-dock-golden.jpg, 05-weedbed-golden.jpg) create a calm, inviting atmosphere with strong framing toward the bridge and mountain.

Broken or ugly:
- 07-overview-golden.jpg has a severe vertical lighting or bloom cutoff seam running down the middle of the lake that washes out the scene in blinding orange fog.
- 10-pool-golden.jpg and 12-pool-night.jpg show the light pole on the right bank leaning at an awkward tilt with a harsh boxy shadow on the sand.
- 08-stands-noon.jpg shows two wooden info signs to the left of the Bait and Tackle stall overlapping each other from the dock perspective, making the back sign unreadable.

Reads as stock Roblox:
- Stock Roblox Terrain Grass, LeafyGrass, Sand, and Mud with default Terrain.Decoration blades: Dominates the ground in 01-dock-dawn.jpg (foreground grass), 06-logs-dawn.jpg (mud and sand shore), 09-riffle-dawn.jpg (speckled LeafyGrass and tall default grass), 10-pool-golden.jpg, and 11-gate-noon.jpg (patchy bright green grass and flat brown mud).
- Stock Roblox Terrain Water: Unmistakable swirling normal-map pattern and high-contrast specular highlights across 03-dockend-noon.jpg, 04-dockend-night.jpg, 10-pool-golden.jpg, and 12-pool-night.jpg.
- SmoothPlastic stacked-cone pine trees and faceted low-poly deciduous trees: Classic Roblox simulator/free-model silhouette and flat plastic shading in 08-stands-noon.jpg (left background), 09-riffle-dawn.jpg (center hill and right background), 10-pool-golden.jpg (center-left), and 11-gate-noon.jpg (midground behind the fence).
- Flat-shaded SmoothPlastic grey boulder formations: Reads as untextured low-poly Roblox terrain props in 09-riffle-dawn.jpg (center mound beneath the pines) and 10-pool-golden.jpg / 12-pool-night.jpg (right shoreline), clashing sharply with the mossy rocks in 05-weedbed-golden.jpg.
- Blocky SmoothPlastic cattail reeds: Close-up in 05-weedbed-golden.jpg (left foreground) clearly reveals sharp rectangular prism green stems and plain brown cylinder tops; also visible in 01-dock-dawn.jpg and 08-stands-noon.jpg.
- Default Roblox sparkle particle texture on night fireflies: Distinctive spiky starburst sprite floating over the water in 04-dockend-night.jpg (large star near bottom-left) and 12-pool-night.jpg (across the pool).
- Default noon sky palette and stock dynamic Clouds: Bright saturated default Roblox blue sky and recognizable stock cloud layer across 03-dockend-noon.jpg, 08-stands-noon.jpg, and 11-gate-noon.jpg.
- Plain cylinder posts with glowing Neon spheres on top: Reads as quick placeholder Roblox parts in 10-pool-golden.jpg (far right bank), 11-gate-noon.jpg (right of the Cedar Creek gate), and 12-pool-night.jpg (far right bank).
- Plain untextured orange rectangular boat/float: Reads like a flat SmoothPlastic block floating next to the right side of the dock in 01-dock-dawn.jpg and 02-dock-golden.jpg.
- Default blocky Roblox avatar look: Standard blocky character wearing casual streetwear and a Santa hat stands center frame on the dock in 01-dock-dawn.jpg, 02-dock-golden.jpg, and 08-stands-noon.jpg.

Action taken: (fill in: what we changed, or why we didn't)
