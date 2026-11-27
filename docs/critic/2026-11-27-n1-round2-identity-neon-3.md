# Critic: n1-round2-identity (review, gemini-4-neon)

Date: 2026-11-27 18:03. Rubric: `identity`.

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

The weathered plank dock, rustic shop walls, boulders, and dawn/golden-hour framing show genuine craft and point straight toward the calm Real-ish target, but across most frames 75 to 85 percent of the screen is still unmistakable stock Roblox terrain, stock water, and default noon sky. Dawn and golden hour mask those seams well; noon shots and the newly carved creek and pool areas immediately revert to looking like a default Roblox Studio terrain map with a few strong custom props placed on top.

| Point | Score |
|---|---|
| materials | 5 |
| signature | 4 |
| cohesion | 5 |
| stock_free | 4 |
| identity | 4.5 |

Top fixes:
1. Override stock Terrain materials (Grass, LeafyGrass, Mud, Sand, Ground) in MaterialService with custom muted, earthy PBR MaterialVariants to remove the neon-green grass patches in 11-gate-noon.jpg and speckled LeafyGrass in 09-riffle-dawn.jpg, then break up the ruler-straight voxel banks in 10-pool-golden.jpg, 12-pool-night.jpg, 09-riffle-dawn.jpg, and the bridge abutments in 03-dockend-noon.jpg using boulders, pebbles, and reeds like 05-weedbed-golden.jpg.
2. Replace the default bright-blue noon Skybox (03-dockend-noon.jpg, 08-stands-noon.jpg, 11-gate-noon.jpg) and oversized default SunTexture (10-pool-golden.jpg) with a custom softer skybox that holds the calm mood at midday, retune Terrain water color, reflectance, wave size, and transparency over a textured lakebed so it stops reading as oily stock Roblox water, and dial back golden-hour Bloom/Atmosphere haze in 07-overview-golden.jpg so the horizon hills do not wash out.
3. Unify the handmade props to match the weathered dock wood in 08-stands-noon.jpg: replace the flat solid-color SurfaceGui sign boards (Bait and Tackle, Sell Fish, Cedar Creek, and the illegible green guide board in 08-stands-noon.jpg and 11-gate-noon.jpg) with beveled painted-wood signs using a single warm rustic typeface, swap the primitive Neon-ball-on-a-stick posts in 10-pool-golden.jpg, 11-gate-noon.jpg, and 12-pool-night.jpg for wooden-and-iron lanterns matching the dock lamps in 01-dock-dawn.jpg, and replace the smooth blob deciduous trees on the left of 08-stands-noon.jpg.

Strengths:
- The dock in 08-stands-noon.jpg and the weathered vertical-plank exteriors of the stands in 01-dock-dawn.jpg and 02-dock-golden.jpg nail the Real-ish goal, with believable wood grain, nail heads, varied plank heights, and chunky timber silhouettes.
- The foreground boulders and cattail clusters in 05-weedbed-golden.jpg show how strong the shoreline reads once handcrafted props and foliage hide the terrain edge.
- The dawn and golden-hour atmospheres in 01-dock-dawn.jpg, 02-dock-golden.jpg, and 05-weedbed-golden.jpg establish a genuinely calm, inviting fishing mood, reinforced by the gentle fireflies in 04-dockend-night.jpg and 12-pool-night.jpg.
- The central framing down the path between the two stands toward the dock, bridge, and distant peak in 01-dock-dawn.jpg and 02-dock-golden.jpg gives the starting hub a clear focal composition.

Broken or ugly:
- 04-dockend-night.jpg has a sharp horizontal lighting or reflection cutoff band running straight across the lower third of the water.
- 10-pool-golden.jpg and 12-pool-night.jpg show a rectangular, straight-walled terrain cutout with a sharp corner that reads as an unshaped box-subtract edit rather than a natural creek pool.
- 08-stands-noon.jpg has a green guide board to the left of Bait and Tackle whose tiny thin white text is unreadable even on desktop and will completely vanish on a phone.
- 07-overview-golden.jpg suffers from heavy blown-out yellow-orange glare across the upper half that erases the distant hills, and shows an unexplained freestanding flat wooden wall sitting alone in the grass behind the stands.
- 06-logs-dawn.jpg has a sharp dark tree-branch polygon clipping into the top-right corner of the frame.
- 12-pool-night.jpg renders the right-hand sand bank unexpectedly pale grey-blue under night ambient light, making it read almost like snow next to the dark water.

Reads as stock Roblox:
- Stock Roblox Terrain Grass, LeafyGrass, Mud, and Sand textures with blobby voxel transitions (foregrounds and shorelines of 01-dock-dawn.jpg, 02-dock-golden.jpg, 05-weedbed-golden.jpg, 06-logs-dawn.jpg, 08-stands-noon.jpg, 09-riffle-dawn.jpg, 10-pool-golden.jpg, and across the entire lower half of 11-gate-noon.jpg): The bright green Grass, speckled LeafyGrass, flat brown Mud, and rippled Sand with soft voxel paint edges immediately read as default Roblox Smooth Terrain.
- Stock Roblox Terrain Decoration grass tufts (far shore of 03-dockend-noon.jpg, bottom left of 07-overview-golden.jpg, behind the stands in 08-stands-noon.jpg, midground of 09-riffle-dawn.jpg, entire background ridge of 10-pool-golden.jpg, and behind the fence in 11-gate-noon.jpg): Uniform, identical-height yellow-green spiky grass blades carpeting flat hills are an instant hallmark of default Roblox Terrain decoration.
- Stock Roblox Terrain Water (filling the lake, creek, and pool in 03-dockend-noon.jpg, 04-dockend-night.jpg, 05-weedbed-golden.jpg, 06-logs-dawn.jpg, 08-stands-noon.jpg, 09-riffle-dawn.jpg, 10-pool-golden.jpg, and 12-pool-night.jpg): The animated oily specular wave pattern and blue-black night reflection shader are unmistakable default Roblox water.
- Default bright-blue Roblox noon sky, clouds, and oversized sun disc (upper half of 03-dockend-noon.jpg, 08-stands-noon.jpg, 11-gate-noon.jpg, and upper left of 10-pool-golden.jpg): Unmodified default midday sky blue, volumetric clouds, and large glowing sun sphere read immediately as default Roblox Lighting.
- Voxel-carved terrain shapes (rectangular green bridge embankments in 03-dockend-noon.jpg center, smooth blobby hills in 07-overview-golden.jpg and 11-gate-noon.jpg background, V-shaped creek trench in 09-riffle-dawn.jpg right, and straight-edged rectangular pool in 10-pool-golden.jpg and 12-pool-night.jpg): Sharp rectilinear cutouts and uniform rounded mounds expose default Roblox Terrain brush and box-carve geometry.
- Default blocky Roblox character avatar (center dock in 01-dock-dawn.jpg, 02-dock-golden.jpg, and prominently center-frame in 08-stands-noon.jpg): Standard blocky torso and limbs, classic smirk face, Santa hat, and plaid pants read as a generic Roblox player model rather than part of this fishing world.
- Flat SurfaceGui sign boards with crisp digital white text (Bait and Tackle, Sell Fish, Your Pond, and green guide board in 08-stands-noon.jpg; Cedar Creek sign in 11-gate-noon.jpg center): Clean white text floating on flat, solid-color untextured rectangles reads like standard Roblox UI-on-a-Part rather than real painted wooden signage.
- Primitive stick-and-Neon-ball light posts (right bank of 10-pool-golden.jpg, right of the archway in 11-gate-noon.jpg, and glowing on the right bank of 12-pool-night.jpg): A plain brown cylinder topped with a bare glowing sphere looks like a raw primitive Part plus Neon ball placeholder.
- Smooth blob deciduous trees (far left of 08-stands-noon.jpg and distant left of 09-riffle-dawn.jpg): Simple rounded green canopy blobs on plain trunks read as generic low-poly free-model Roblox trees and clash with the detailed dock wood.

Action taken: (fill in: what we changed, or why we didn't)
