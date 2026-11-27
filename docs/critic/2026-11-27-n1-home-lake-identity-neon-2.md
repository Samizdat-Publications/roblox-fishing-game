# Critic: n1-home-lake-identity (review, gemini-4-neon)

Date: 2026-11-27 17:03. Rubric: `identity`.

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

**Score: 5/10**

The game is split between two visual worlds. Around the main dock, the weathered wood planks, bark pilings, striped-awning bait stalls, serif signage, and textured shoreline boulders nail the Real-ish target and give the game genuine handcrafted charm - especially at dawn and golden hour. Everywhere else, however, default Roblox Terrain (grass, leafy grass, mud, sand, and swirly water), bright cyan noon skies, flat SmoothPlastic cone trees and blocky cattails, primitive neon-ball posts, and stock starburst fireflies pull it straight back into a default Roblox look.

| Point | Score |
|---|---|
| materials | 5 |
| signature | 5 |
| cohesion | 4 |
| stock_free | 4 |
| identity | 5 |

Top fixes:
1. Override default Terrain Grass, LeafyGrass, Mud, and Sand with muted custom MaterialVariants in MaterialService (most visible in 01-dock-dawn.jpg, 09-riffle-dawn.jpg, and 11-gate-noon.jpg), and replace the default noon Skybox and Atmosphere settings so 03-dockend-noon.jpg, 08-stands-noon.jpg, and 11-gate-noon.jpg lose the harsh cyan Roblox sky and oily water sheen.
2. Replace all flat untextured SmoothPlastic nature props - specifically the rectangular blocky cattails (01, 05, 08), the faceted grey rock mound (09-riffle-dawn.jpg center), and the flat-shaded cone pines and low-poly blob trees (08-stands-noon.jpg left, 09, 10, 11 background) - with textured assets matching the stone in 05-weedbed-golden.jpg and the textured wood and pines on the main lake.
3. Swap placeholder primitives and stock particles for props that match the dock craft: replace the bare post-and-neon-sphere lamps (10-pool-golden.jpg, 11-gate-noon.jpg, 12-pool-night.jpg) with the dock's lantern model, replace the untextured orange boat block beside the dock (01, 02) with a wood-plank skiff, and change the 6-point star firefly sprites (04-dockend-night.jpg, 12-pool-night.jpg) to soft round glow dots.

Strengths:
- The dock in 08-stands-noon.jpg has convincing weathered wood planks, nail details, and bark-textured pilings that hit the Real-ish brief.
- The Bait and Tackle and Sell Fish stalls (01-dock-dawn.jpg, 02-dock-golden.jpg, 08-stands-noon.jpg) and Cedar Creek arch (11-gate-noon.jpg) share a cohesive rustic wood-and-serif-signage style.
- The shoreline boulders in 05-weedbed-golden.jpg read as real stone and catch golden-hour light well.
- Dawn and golden-hour lighting in 02-dock-golden.jpg, 05-weedbed-golden.jpg, and 06-logs-dawn.jpg create a calm, believable fishing atmosphere.

Broken or ugly:
- 07-overview-golden.jpg center-left: a harsh, vertical rectangular wall of blown-out orange sunlight/bloom slices across the lake and washes out the entire overview shot.
- 10-pool-golden.jpg and 12-pool-night.jpg right bank: the placeholder lamp post is visibly tilted/leaning sideways in the sand, and a flat grey wedge/block sticks awkwardly out of the pool bank next to the cattails.
- 06-logs-dawn.jpg far-left and top-right corners: a dark tree trunk and flat pine branch clip into the camera frame edges.

Reads as stock Roblox:
- Default Roblox Terrain grass, leafy grass, mud, sand, and grass Decoration blades (01-dock-dawn.jpg foreground, 09-riffle-dawn.jpg foreground, 10-pool-golden.jpg banks, 11-gate-noon.jpg foreground and background): Immediately recognizable default Roblox Terrain textures, blotchy mud-to-grass transitions, and uniform procedural grass blades.
- Stock Roblox Terrain water (03-dockend-noon.jpg, 04-dockend-night.jpg, 06-logs-dawn.jpg, 10-pool-golden.jpg, 12-pool-night.jpg): Shows the signature swirly specular highlights and oily reflections of default Roblox water.
- Default bright blue noon Sky and volumetric Clouds (03-dockend-noon.jpg, 08-stands-noon.jpg, 11-gate-noon.jpg upper half): Unmodified cyan sky dome and standard Roblox Clouds look.
- Flat SmoothPlastic blocky cattails (05-weedbed-golden.jpg foreground left and right, 01-dock-dawn.jpg shoreline, 08-stands-noon.jpg left and right banks): Untextured rectangular green bars and blocky brown cylinders sitting directly next to realistic stone and wood.
- Flat-shaded cone pines and faceted low-poly deciduous trees (08-stands-noon.jpg far left, 09-riffle-dawn.jpg center hill and right, 10-pool-golden.jpg center, 11-gate-noon.jpg behind fence): Untextured SmoothPlastic geometric cones and poly-blob foliage that read as generic simulator free models.
- Faceted untextured grey rock mound (09-riffle-dawn.jpg center under the three pines): Plain flat-shaded grey SmoothPlastic mesh that clashes heavily with the textured boulders in 05-weedbed-golden.jpg.
- Primitive lamp posts made of a brown pole and Neon sphere (10-pool-golden.jpg right bank, 11-gate-noon.jpg right of the Cedar Creek gate, 12-pool-night.jpg right bank): Unmodeled basic cylinder and glowing Neon ball primitive instead of a real lantern prop.
- Starburst firefly particle sprites (04-dockend-night.jpg over the lake, 12-pool-night.jpg over the pool): Uses a stock 6-pointed star/sparkle texture that reads as default Roblox Sparkles rather than natural fireflies.
- Plain untextured orange boat beside the dock (01-dock-dawn.jpg and 02-dock-golden.jpg center-right of dock): Reads as a flat SmoothPlastic orange block floating beside weathered timber.
- Default blocky Roblox avatar (01-dock-dawn.jpg, 02-dock-golden.jpg, 08-stands-noon.jpg center on dock): Standard blocky player avatar in a Santa hat and plaid pants immediately signals default Roblox.

Action taken: (fill in: what we changed, or why we didn't)
