# Critic: n1-round5-lake-identity (review, gemini-4-neon)

Date: 2026-11-27 20:00. Rubric: `identity`.

Files shown:
- `01-dock-dawn.jpg`
- `02-dock-golden.jpg`
- `03-dockend-noon.jpg`
- `04-dockend-night.jpg`
- `05-weedbed-golden.jpg`
- `06-logs-dawn.jpg`
- `07-overview-golden.jpg`
- `08-stands-noon.jpg`

**Score: 5.5/10**

The game already has genuine pockets of its own Real-ish identity - especially the richly weathered plank dock in 08-stands-noon.jpg, the wooden market stalls, the boulders, and the warm golden-hour atmosphere in 02-dock-golden.jpg and 05-weedbed-golden.jpg. However, the biggest pixel areas in almost every frame are still unmistakably stock Roblox: default Terrain Grass, Sand, and Mud, smooth sculpted horizon hills, and uncustomized sky/Atmosphere presets. Replacing those terrain materials and skies will shift the game from looking like a dressed-up Roblox place into looking unmistakably like itself.

| Point | Score |
|---|---|
| materials | 6 |
| signature | 5 |
| cohesion | 5 |
| stock_free | 5 |
| identity | 5.5 |

Top fixes:
1. Override default Roblox Terrain Grass, Sand, Mud, and Ground in MaterialService with custom MaterialVariants (muted lakeside grass, fine damp shore pebbles/gravel, dark earthy mud) across the shoreline and hub path (01-dock-dawn.jpg, 05-weedbed-golden.jpg, 08-stands-noon.jpg), and line the water-to-grass border with scattered small stones and roots to break up the blobby voxel transitions.
2. Replace the stock Sky, Clouds, and flat Atmosphere lighting across all times of day with custom skyboxes and matched Atmosphere colors: add a textured overcast cloud deck for noon (03-dockend-noon.jpg, 08-stands-noon.jpg), a deep starry sky with a subtle moon for night (04-dockend-night.jpg), and a matching warm golden skybox for 07-overview-golden.jpg so the grey upper sky band and oversized sun glare disappear.
3. Apply textured SurfaceAppearance or MaterialVariant finishes (subtle needle/leaf grain and weathered woven canvas) to the matte SmoothPlastic-reading tree canopies (08-stands-noon.jpg background, 07-overview-golden.jpg bottom-left) and the striped stall awnings (08-stands-noon.jpg), and break up the bare dome-shaped terrain hills on the horizon in 07-overview-golden.jpg with distant tree lines or rougher rock ridges.

Strengths:
- The weathered wood dock in 08-stands-noon.jpg (varied planks, nail heads, rough log pilings with end-grain rings) hits the Real-ish art target dead on and looks completely custom.
- The weathered vertical plank siding on both lakeside stalls (01-dock-dawn.jpg, 02-dock-golden.jpg, 08-stands-noon.jpg) and the rough foreground boulders in 05-weedbed-golden.jpg read convincingly as real wood and stone.
- Golden-hour lighting and low mist in 02-dock-golden.jpg and 05-weedbed-golden.jpg create a calm, believable lakeside mood that hides a lot of material seams and sells the fishing fantasy.
- Custom chunky lakeside props - cattail clusters (05-weedbed-golden.jpg, 06-logs-dawn.jpg), submerged snag logs (06-logs-dawn.jpg), and soft glowing fireflies (04-dockend-night.jpg) - give the pond real fishing-spot character.

Broken or ugly:
- In 07-overview-golden.jpg (upper third), the golden Atmosphere haze stops abruptly below a harsh flat dark-grey sky band, breaking the sunset lighting from elevated angles.
- In 04-dockend-night.jpg (upper half), the night Atmosphere renders a dark indigo stripe right along the horizon beneath a much brighter royal-blue upper sky, creating an inverted lighting gradient behind the trees.

Reads as stock Roblox:
- Default Terrain Grass, Ground, and Mud surfaces (08-stands-noon.jpg mid-ground shoreline; 01-dock-dawn.jpg and 02-dock-golden.jpg foreground; 06-logs-dawn.jpg shore): Stock bright-green grass and smooth brown/grey dirt with blobby voxel-blended edges read immediately as default Roblox Terrain Editor, clashing hard with the detailed weathered wood dock.
- Default Terrain Sand ripples (05-weedbed-golden.jpg bottom-left and bottom-center): The repeating wavy ripple pattern is the stock Roblox Terrain Sand texture, very recognizable in raking golden light.
- Smooth voxel terrain hills (07-overview-golden.jpg upper third across the entire horizon): Bare, rounded dome-shaped mounds along the skyline look unmistakably like default Roblox Terrain Sculpt/Grow hills.
- Default Roblox Clouds and daytime sky (01-dock-dawn.jpg upper half): Reads directly as the stock Roblox dynamic Clouds instance over the default blue skybox.
- Flat overcast Atmosphere sky (03-dockend-noon.jpg and 08-stands-noon.jpg upper half): A completely featureless solid grey sky with no cloud detail feels like a default Roblox overcast lighting setup.
- Default night Atmosphere gradient (04-dockend-night.jpg upper half): Bright blue upper sky fading into a dark horizon band with no stars or moon reads as uncustomized Roblox night Atmosphere.
- Default sun bloom and grey upper sky band (07-overview-golden.jpg top-left corner and upper band): Oversized stock Roblox sun halo in the top-left and a flat grey default sky showing above the golden haze.
- SmoothPlastic-reading tree canopies (08-stands-noon.jpg background behind stalls; 07-overview-golden.jpg bottom-left): Although the chunky silhouettes are custom, the untextured flat green facets on the pine layers and round broadleaf crowns read as smooth plastic next to the realistic dock wood.
- SmoothPlastic-reading striped stall awnings (08-stands-noon.jpg on both lakeside stands): Flat, clean untextured blue/white and yellow/white stripes lack canvas or painted-wood texture compared to the weathered planks directly beneath them.

Action taken: (fill in: what we changed, or why we didn't)
