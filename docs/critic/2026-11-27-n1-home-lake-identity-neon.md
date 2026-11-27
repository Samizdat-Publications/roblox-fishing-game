# Critic: n1-home-lake-identity (review, gemini-4-neon)

Date: 2026-11-27 17:02. Rubric: `identity`.

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

The main dock, bait/sell stalls, and mossy weedbed boulders show a genuinely strong Real-ish identity with weathered wood, warm lanterns, and calm dawn/golden-hour mood. However, across the full 12 screenshots - especially at noon and around Cedar Creek, the riffle, and the pool - stock Roblox Terrain, Terrain Water, low-poly SmoothPlastic trees/rocks/cattails, and default sparkle particles dominate the frame and clash with the handcrafted assets.

| Point | Score |
|---|---|
| materials | 5 |
| signature | 4 |
| cohesion | 4 |
| stock_free | 4 |
| identity | 4.5 |

Top fixes:
1. Override stock Terrain materials via MaterialService MaterialVariants across the whole map (01, 09, 10, 11): replace default Grass, LeafyGrass, Sand, and Ground with muted, rougher PBR textures (damp bank dirt, sage/olive grass, shoreline gravel) and break up the uniform Terrain Decoration grass carpet while hiding straight voxel-cut pool/stream banks (09, 10, 12) with bank stones and overhang weeds.
2. Replace SmoothPlastic flora and rocks so everything matches the dock and 05-weedbed-golden.jpg boulders: swap the blocky prism cattails (05, 08) for tapered textured reed meshes, replace the smooth faceted grey rock mounds (09 center, 10 right bank) with mossy PBR rock models, and unify the four clashing tree types by removing the stacked-cone pines and faceted blocky deciduous trees (08, 09, 10, 11) in favor of one PBR-bark, textured-foliage tree family.
3. Replace the stock noon sky, firefly particle texture, and bare Neon lamp posts: install a custom softer lakeside Skybox and subtle hazy Atmosphere so noon (03, 08, 11) matches dawn/golden hour instead of default bright cyan; swap the default 8-point sparkle ParticleEmitter texture on night fireflies (04, 12) for a soft circular radial glow dot; and replace the tilted brown cylinder with a Neon sphere (10, 12) with the framed wooden lantern used on the main dock (01, 02).

Strengths:
- The weathered wooden dock in 08-stands-noon.jpg (plank grain, nail heads, cut log pilings with end-grain, metal cleat, numbered posts) nails the Real-ish style and reads immediately as real wood.
- The Bait and Tackle and Sell Fish stalls in 01-dock-dawn.jpg, 02-dock-golden.jpg, and 08-stands-noon.jpg feel handcrafted, with weathered vertical plank siding, striped awnings, a carved fish rooftop topper, and fitting serif wooden signs.
- Dawn and golden-hour lighting in 01-dock-dawn.jpg, 02-dock-golden.jpg, and 05-weedbed-golden.jpg create genuine calm lakeside mood, and the mossy PBR boulders in 05-weedbed-golden.jpg catch the low sun convincingly.
- Symmetrical framing between the two stalls looking down the lantern-lit dock toward the bridge and hills (01-dock-dawn.jpg, 02-dock-golden.jpg) establishes an inviting focal landmark.

Broken or ugly:
- 07-overview-golden.jpg (center): a massive hard-edged vertical translucent orange rectangle cuts straight down across the lake and sky, blowing out visibility across the entire overview shot.
- 10-pool-golden.jpg and 12-pool-night.jpg (far right bank): the wooden lamp post leans awkwardly out of the sand bank, and in 12-pool-night.jpg a sharp dark rectangular shadow sits oddly beneath it.
- 10-pool-golden.jpg and 12-pool-night.jpg (pool perimeter) and 09-riffle-dawn.jpg (stream bed): straight 90-degree voxel-cut shoreline corners and a rigid narrow trench read as raw terrain sculpting rather than natural water banks.
- 06-logs-dawn.jpg (far left and top-right corners): the camera view is clipped by a dark vertical trunk on the left edge and a sharp stray green leaf triangle jutting into the upper right.

Reads as stock Roblox:
- Stock Roblox Terrain Grass, LeafyGrass, Sand, Ground, and Terrain Decoration grass blades (01-dock-dawn.jpg foreground, 09-riffle-dawn.jpg throughout, 10-pool-golden.jpg banks and background hills, 11-gate-noon.jpg foreground dirt/grass/path and background hills): Immediately recognizable default Roblox voxel terrain textures, splodgy material transitions, and uniform spiky grass decoration carpet.
- Stock Roblox Terrain Water (03-dockend-noon.jpg lower half, 04-dockend-night.jpg lower half, 08-stands-noon.jpg around dock, 10-pool-golden.jpg and 12-pool-night.jpg entire pool): Unmistakable default Roblox swirling procedural water normal map and specular highlights.
- Stacked-cone SmoothPlastic pine trees and faceted blocky deciduous trees (08-stands-noon.jpg left background, 09-riffle-dawn.jpg center hill and horizon, 10-pool-golden.jpg and 12-pool-night.jpg far bank, 11-gate-noon.jpg behind gate): Untextured low-poly cone and lump primitives that read as generic Roblox free-model/starter trees and clash with the textured dock and boulders.
- Faceted untextured SmoothPlastic grey rocks (09-riffle-dawn.jpg large rock mound at center, 10-pool-golden.jpg and 12-pool-night.jpg single rock on upper-right bank edge): Flat-shaded smooth grey low-poly geometry with no stone surface grain, contrasting sharply against the PBR boulders in 05-weedbed-golden.jpg.
- Blocky SmoothPlastic/Plastic cattails (05-weedbed-golden.jpg left and right foreground, 06-logs-dawn.jpg left and right banks, 08-stands-noon.jpg left and right shore): Built from sharp rectangular green prisms and smooth brown cylinders that look like plain Roblox parts right next to detailed PBR rocks.
- Default Roblox 8-point sparkle particle texture used for fireflies (04-dockend-night.jpg across water and lower-left, 12-pool-night.jpg over pool and right bank): Uses the instantly recognizable default Roblox starburst sparkle sprite.
- Default Roblox noon Skybox and Clouds (03-dockend-noon.jpg, 08-stands-noon.jpg, 11-gate-noon.jpg upper half): Saturated default cyan-blue sky and standard dynamic Roblox cloud puffs give all noon shots a stock studio look.
- Default blocky Roblox player avatar (01-dock-dawn.jpg and 02-dock-golden.jpg center dock, 08-stands-noon.jpg center dock): Standard blocky Roblox character proportions wearing casual catalog items (Santa hat, hoodie, plaid pants) that stand out against the rustic fishing setting.
- Bare Neon sphere on a plain brown cylinder lamp post (10-pool-golden.jpg and 12-pool-night.jpg right bank): Reads as two unstyled Roblox primitives (a tilted brown cylinder and a glowing yellow Neon ball) rather than a crafted lantern.
- Smooth untextured primitive lake props (01-dock-dawn.jpg and 02-dock-golden.jpg bright orange rectangular boat hull right of dock; 06-logs-dawn.jpg smooth dark cylinder logs with cone stubs in center water): Simple smooth-shaded geometric blocks/cylinders lacking the wood grain and wear seen on the main dock.

Action taken: (fill in: what we changed, or why we didn't)
