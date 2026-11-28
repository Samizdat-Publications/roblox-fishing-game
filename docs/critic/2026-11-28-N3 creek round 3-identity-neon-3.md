# Critic: N3 creek round 3-identity (review, gemini-4-neon)

Date: 2026-11-28 01:10. Rubric: `identity`.

Files shown:
- `09-riffle-dawn.jpg`
- `10-pool-golden.jpg`
- `11-gate-noon.jpg`
- `12-pool-night.jpg`

**Score: 4/10**

The golden-hour and night shots of the pond already hint at the calm, moody fishing world you want, with warm low light, fireflies, and grounded water framing. However, the moment the scene hits daylight or close-up detail, stock Roblox terrain grass and mud, the default skybox, stock Wood and LeafyGrass materials, and mismatched low-poly tree styles pull it right back into default Roblox territory.

| Point | Score |
|---|---|
| materials | 4 |
| signature | 3 |
| cohesion | 4 |
| stock_free | 3 |
| identity | 4 |

Top fixes:
1. Override default Terrain Grass, Ground/Mud, Cobblestone, and the over-bright shoreline path (11-gate-noon.jpg foreground, 10-pool-golden.jpg and 12-pool-night.jpg right bank, 09-riffle-dawn.jpg banks) with custom muted PBR MaterialVariant textures such as forest-floor pine-needle grass, dark packed gravel/dirt, and mossy river stones.
2. Unify all trees into one consistent Real-ish cedar/pine model family and strip stock LeafyGrass off foliage (replacing both the sharp geometric cones in 11-gate-noon.jpg and the puffy teardrop-topped trees in 10-pool-golden.jpg, plus the dome bush in 09-riffle-dawn.jpg) using a custom cedar-bark MaterialVariant on trunks and bespoke pine-bough textures.
3. Replace the default Roblox Skybox across all times of day (especially the harsh cobalt noon sky in 11-gate-noon.jpg and default clouds in 10-pool-golden.jpg and 12-pool-night.jpg) with a custom skybox and softer Atmosphere haze, while swapping the sharp rectangular riffle decals in 09-riffle-dawn.jpg for soft-edged animated foam beams around real rocks and upgrading the boxy Wood/Neon trail lanterns to chamfered timber and dark metal frames.

Strengths:
- Warm golden-hour lighting cutting through the tree trunks in 10-pool-golden.jpg creates a genuinely calm, inviting fishing mood.
- The night atmosphere in 12-pool-night.jpg works well, with subtle green fireflies over the water and warm lantern spill guiding the eye along the shoreline.
- Natural pond composition in 10-pool-golden.jpg and 12-pool-night.jpg (curving bank, cattails, submerged weed patches, and a distant log crossing) reads as a real fishing spot rather than a flat showcase map.
- The dense misty blue-violet forest canopy in the background of 09-riffle-dawn.jpg establishes a quiet early-morning mood.

Broken or ugly:
- 09-riffle-dawn.jpg (center foreground in the stream): three overlapping flat whitewater riffle decals or planes have stark, unfeathered 90-degree edges cutting across the dark water.
- 10-pool-golden.jpg and 12-pool-night.jpg (middle-right bank just behind the cattails): a dark rock sits awkwardly perched at the steep edge of the pale path, appearing half-floating and clipping warm light underneath in 10-pool-golden.jpg.

Reads as stock Roblox:
- Terrain Grass and Ground/Mud path (11-gate-noon.jpg, entire foreground): Bright yellow-green default Roblox terrain grass and brown dirt with Roblox's unmistakable soft voxel-blend edges.
- Terrain pale path and lumpy mud/cobble shoreline (10-pool-golden.jpg and 12-pool-night.jpg, right bank; 09-riffle-dawn.jpg, bottom-left and right bank): Default Roblox terrain materials with a flat, overly bright pale path abruptly blending into stock bumpy brown mud and cobbles.
- Default Skybox and clouds (10-pool-golden.jpg, upper sky; 11-gate-noon.jpg, upper blue sky and top-right clouds; 12-pool-night.jpg, night clouds and stars): Standard Roblox sky dome with recognizable default wispy clouds and saturated noon blue.
- LeafyGrass material on geometric tree cones and dome bush (11-gate-noon.jpg, left and right pine trees; 09-riffle-dawn.jpg, bottom-left foreground bush): Repeating stock Roblox LeafyGrass texture wrapped directly over sharp-faceted pyramids and a plain dome primitive.
- Stock Wood material on plain box posts, rails, and trunks (11-gate-noon.jpg, center archway posts, left and right fence rails, lantern post; 09-riffle-dawn.jpg, lit tree trunk on right): Uncustomized default Roblox Wood grain applied to straight, unchamfered rectangular parts and cylindrical trunks.
- Boxy trail lanterns with glowing Neon cube (11-gate-noon.jpg, right of gate; 10-pool-golden.jpg and 12-pool-night.jpg, right bank): Simple unchamfered square wooden post holding a plain box frame around a default Roblox Neon block.
- Flat rectangular whitewater riffle planes (09-riffle-dawn.jpg, bottom-center in stream): Raw overlapping rectangular decals or transparent parts with hard straight corners sitting on top of the creek.

Action taken: (fill in: what we changed, or why we didn't)
