# Critic: n1-round2-lake-identity (review, gemini-4-neon)

Date: 2026-11-27 18:11. Rubric: `identity`.

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

The hero wooden dock, weathered bait and fish stalls, sculpted shore rocks, and golden-hour weedbed show a genuinely appealing rustic fishing identity starting to come together. Right now, though, stock Roblox Terrain ground, glossy default Terrain water, the bright midday sky, and a default catalog avatar fill most of the frame, making the game still read primarily as a Roblox Studio terrain map with nice custom props placed on top.

| Point | Score |
|---|---|
| materials | 5 |
| signature | 5 |
| cohesion | 5 |
| stock_free | 4 |
| identity | 5 |

Top fixes:
1. Override stock Roblox Terrain materials (Grass, Sand, Ground, Mud, and LeafyGrass) in MaterialService with custom PBR MaterialVariants featuring muted earthy lakeside silt, damp pebbles, and desaturated mossy grass to match the weathered timber of the dock and stalls across 01-dock-dawn.jpg, 05-weedbed-golden.jpg, 06-logs-dawn.jpg, and 08-stands-noon.jpg, and dress the shoreline with rocks and reeds to hide voxel seams.
2. Replace the default midday Skybox and tune Terrain water and Lighting settings: use a custom desaturated Sky texture with subtle Atmosphere and ColorCorrection so noon (03-dockend-noon.jpg, 08-stands-noon.jpg) matches the grounded mood of dawn and golden hour, and lower Terrain WaterReflectance and WaterWaveSize with a deeper green-brown WaterColor to kill the glossy plastic-oil look and fix the night reflection seam in 04-dockend-night.jpg.
3. Replace remaining placeholder props and unify small details: swap the bare white block beside the dock (01-dock-dawn.jpg, 02-dock-golden.jpg, 06-logs-dawn.jpg, 07-overview-golden.jpg) for a weathered timber boat or slip matching the dock planks, replace the SmoothPlastic buoy in 03-dockend-noon.jpg with a weathered metal or painted-wood buoy, and redo the tiny chalkboard signs in 08-stands-noon.jpg with large, bold, weathered wood signage readable on a phone.

Strengths:
- The dock in 08-stands-noon.jpg nails the Real-ish art direction with weathered plank grain, visible nail heads, varied board lengths, and chunky bark-wrapped log posts.
- The Bait and Tackle and Sell Fish stalls in 01-dock-dawn.jpg, 02-dock-golden.jpg, and 08-stands-noon.jpg use rich weathered wood textures, striped awnings, and a carved wooden fish roof ornament that hint at a warm, handcrafted lakeside style.
- 05-weedbed-golden.jpg has strong mood and readability, combining chunky sculpted foreground rocks, warm golden reflections, cattails, and lily pads into the most distinct shot of the set.
- Lighting variety across dawn (01-dock-dawn.jpg, 06-logs-dawn.jpg), golden hour (02-dock-golden.jpg, 05-weedbed-golden.jpg), and night with glowing fireflies (04-dockend-night.jpg) establishes a calm, atmospheric fishing mood.

Broken or ugly:
- 04-dockend-night.jpg has a harsh horizontal orange-and-dark reflection seam cutting straight across the lower third of the water.
- 07-overview-golden.jpg has overblown golden bloom and haze that washes out the upper sky and distant hills into near-solid glare.
- 08-stands-noon.jpg has tiny, low-contrast text on the green Time on the Lake chalkboard and adjacent brown board on the left that is hard to read on desktop and illegible on a phone.
- 06-logs-dawn.jpg has a dark sharp tree branch clipping awkwardly into the top-right corner of the frame, and the sunken logs in the water have stark flat-cut ends.

Reads as stock Roblox:
- Stock Roblox Terrain water (01-dock-dawn.jpg through 08-stands-noon.jpg, across the entire lake and pond surface) : Instantly recognisable glossy, oily cellular ripples and bright plastic-like specular highlights of default Smooth Terrain water, plus a harsh planar reflection band at night in 04-dockend-night.jpg.
- Stock Roblox Terrain ground materials: Grass, Sand, Ground, Mud, and LeafyGrass (01-dock-dawn.jpg and 02-dock-golden.jpg foreground path and grass; 05-weedbed-golden.jpg foreground wavy sand and green grass; 06-logs-dawn.jpg foreground gravel, mud, and grass patch; 08-stands-noon.jpg shore sand, lawn, and speckled mud flanking the dock) : Default Roblox terrain textures, wavy sand normal map, and blobby voxel material transitions dominate most shots.
- Stock Roblox Terrain Decoration grass blades (03-dockend-noon.jpg far shoreline; 07-overview-golden.jpg bottom-left meadow; 08-stands-noon.jpg far-left bank and background treeline) : Uniform default Roblox grass tufts sticking out of flat painted terrain.
- Stock Roblox Smooth Terrain background hills (07-overview-golden.jpg along the upper horizon) : Soft, bulbous, uniform terrain mounds typical of default Roblox terrain sculpting.
- Default midday Roblox Sky and stock dynamic Clouds (03-dockend-noon.jpg and 08-stands-noon.jpg upper frame; stock Clouds also visible in 01, 02, 04, 05, 06) : Oversaturated default Roblox blue sky gradient and unmistakable procedural Studio cloud puffs.
- Default blocky Roblox avatar look (01-dock-dawn.jpg, 02-dock-golden.jpg, and 08-stands-noon.jpg center on the dock) : Standard blocky character wearing casual catalog clothes (Santa hat, black hoodie, red plaid pants) and classic Roblox face, clashing with the rustic outdoor world.
- Plain white untextured float block (01-dock-dawn.jpg and 02-dock-golden.jpg right side of dock; 06-logs-dawn.jpg center-left by dock; 07-overview-golden.jpg right of dock) : Reads as a bare white SmoothPlastic rectangular part sitting in the water next to the textured wooden dock.
- Simple SmoothPlastic red-and-white buoy (03-dockend-noon.jpg center of lake) : Clean, untextured primitive cylinder and dome shapes that look like stock Roblox parts.

Action taken: (fill in: what we changed, or why we didn't)
