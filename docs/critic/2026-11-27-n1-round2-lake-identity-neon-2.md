# Critic: n1-round2-lake-identity (review, gemini-4-neon)

Date: 2026-11-27 18:10. Rubric: `identity`.

Files shown:
- `01-dock-dawn.jpg`
- `02-dock-golden.jpg`
- `03-dockend-noon.jpg`
- `04-dockend-night.jpg`
- `05-weedbed-golden.jpg`
- `06-logs-dawn.jpg`
- `07-overview-golden.jpg`
- `08-stands-noon.jpg`

**Score: 5/10**

The game already has the right calm, clutter-free fishing-camp instinct and a genuinely strong Real-ish benchmark in the weathered plank dock, stall timber, and cove rocks. However, the surfaces that fill most of every frame - the water, the shoreline terrain, the noon sky, and the flat SurfaceGui signs - still read immediately as stock Roblox, keeping the game halfway between its own identity and a default Roblox terrain map.

| Point | Score |
|---|---|
| materials | 5 |
| signature | 4 |
| cohesion | 6 |
| stock_free | 4 |
| identity | 5 |

Top fixes:
1. Replace stock Roblox Terrain materials via MaterialService MaterialVariants for Grass, Sand, Ground, Mud, and LeafyGrass across the entire pond perimeter (especially the bare foreground paths in 01-dock-dawn.jpg and 06-logs-dawn.jpg and the shore flanking the dock in 08-stands-noon.jpg), using matte earthy PBR textures and breaking up the ruler-straight dirt waterlines beside the dock with rocks, pebbles, and shoreline sedges.
2. Restyle the water and skybox to remove the default Roblox look: tune Workspace.Terrain WaterWaveSize, WaterWaveSpeed, WaterColor, and WaterReflectance so the water stops showing glossy blobby ripples (03-dockend-noon.jpg, 08-stands-noon.jpg) and the horizontal reflection band at night (04-dockend-night.jpg), replace the bright cyan default Sky cubemap (03-dockend-noon.jpg, 08-stands-noon.jpg) with a custom cohesive sky and Atmosphere palette, and dial back the overexposed golden-hour BloomEffect/glare in 07-overview-golden.jpg.
3. Upgrade the signs, buoy, and moored boat to match the weathered dock: replace the crisp white SurfaceGui text on Bait and Tackle, Sell Fish, Your Pond, Boat Slips, and the green notice board (08-stands-noon.jpg, 05-weedbed-golden.jpg) with weathered painted-wood textures using a distinct, larger high-contrast rustic typeface that reads on a phone, and swap the flat SmoothPlastic red-and-white buoy (03-dockend-noon.jpg) and plain white moored boat (01-dock-dawn.jpg, 02-dock-golden.jpg) for chipped-paint and weathered-wood PBR meshes.

Strengths:
- The dock in 08-stands-noon.jpg is standout material work: individual weathered planks, visible nail heads, varied wood tones, and bark-textured pilings hit the Real-ish goal dead-on.
- The weathered vertical wood siding on the stalls (01-dock-dawn.jpg, 02-dock-golden.jpg) and the chunky sculpted shoreline boulders in 05-weedbed-golden.jpg read as real wood and stone.
- Restraint and mood are working in your favour: there are no floating neon name labels, simulator UI clutter, or clashing free-model packs, and the dawn mist (06-logs-dawn.jpg) and golden-hour reed cove (05-weedbed-golden.jpg) already feel peaceful and fishable.
- Readable fishing spots are built naturally into the world - reed beds with lily pads (05-weedbed-golden.jpg), sunken logs (06-logs-dawn.jpg), and the outlet channel under the bridge (03-dockend-noon.jpg, 07-overview-golden.jpg).

Broken or ugly:
- In 04-dockend-night.jpg, a harsh horizontal brownish reflection/lighting seam cuts straight across the lower third of the water surface.
- In 08-stands-noon.jpg, the text on the green notice board left of Bait and Tackle is unreadable white speckles from the dock (and will be completely illegible on a small phone), and the purple-bordered board to its left is partially blocked behind it.
- In 07-overview-golden.jpg, golden-hour bloom and haze blow out the upper sky and wash the water and far shore into flat overexposed orange-white.
- In 06-logs-dawn.jpg, a sharp dark-green tree branch clips directly into the upper-right corner of the camera frame, and the submerged logs have clean, flat tan cut ends that look artificially trimmed.
- In 01-dock-dawn.jpg and 02-dock-golden.jpg, the shoreline on both sides of the dock meets the water in a ruler-straight horizontal line.

Reads as stock Roblox:
- Stock Roblox Terrain Water (all files 01-dock-dawn.jpg through 08-stands-noon.jpg, filling the lake and cove).: Displays the unmistakable default smooth-terrain glossy sinusoidal ripples and bright plastic-like specular highlights, clashing sharply with the custom weathered wood dock in 08-stands-noon.jpg.
- Stock Roblox Terrain Grass, Sand, Ground, Mud, and spiky grass decoration (01-dock-dawn.jpg and 02-dock-golden.jpg foreground; 05-weedbed-golden.jpg foreground sand and lower-right grass; 06-logs-dawn.jpg foreground grey ground and dark mud; 07-overview-golden.jpg bottom-left grass blades and smooth rounded background hills; 08-stands-noon.jpg shoreline sand, grass, and speckled ground patches).: Uses default Roblox Terrain textures, blotchy voxel-painted material transitions, and smooth rounded terrain mounds that immediately read as default Roblox terrain.
- Default bright blue Roblox daytime Sky and soft dynamic Clouds (03-dockend-noon.jpg and 08-stands-noon.jpg upper half; Clouds also visible in 01-dock-dawn.jpg and 02-dock-golden.jpg).: Saturated cyan default sky tone and standard procedural Roblox Clouds instance give noon shots a generic engine look.
- Plain SurfaceGui signboards (08-stands-noon.jpg: Bait and Tackle, Sell Fish, Your Pond, and green notice board; 05-weedbed-golden.jpg: Boat Slips sign at far right).: Clean, unweathered standard Roblox fonts placed flat on plain rectangular boards read as default UI labels rather than painted or carved lakeside wood signs.
- Untextured red-and-white buoy (03-dockend-noon.jpg and 04-dockend-night.jpg, center of water).: Reads as smooth Plastic/SmoothPlastic cylinder and cone primitives with flat solid red and white colour bands and no surface wear.
- Plain white moored boat/float beside the right side of the main dock (01-dock-dawn.jpg, 02-dock-golden.jpg, 06-logs-dawn.jpg, 07-overview-golden.jpg).: Reads as an untextured, flat-shaded white block sitting directly against the richly textured wooden dock.
- Default blocky Roblox player avatar (01-dock-dawn.jpg, 02-dock-golden.jpg, 08-stands-noon.jpg, center on dock).: Standard blocky Roblox avatar in casual hoodie, red plaid pants, and Santa hat immediately anchors the screenshot in default Roblox visual language.

Action taken: (fill in: what we changed, or why we didn't)
