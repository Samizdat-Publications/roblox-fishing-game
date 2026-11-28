# Critic: n1-round4-lake-identity (review, gemini-4-neon)

Date: 2026-11-27 19:22. Rubric: `identity`.

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

The hero wood-and-stone assets - especially the weathered timber dock in 08-stands-noon.jpg, the barnwood stalls, and the mossy boulders in 05-weedbed-golden.jpg - already capture the Real-ish target style well, but the surrounding landscape still reads strongly as default Roblox. Stock Terrain grass, sand, mud, and pebble, a forest of flat low-poly SmoothPlastic trees, plain cylinder logs, and default/flat skies dominate wide shots and clash with the high-craft dock and rocks.

| Point | Score |
|---|---|
| materials | 5 |
| signature | 4.5 |
| cohesion | 4 |
| stock_free | 4 |
| identity | 4.5 |

Top fixes:
1. Replace default Terrain Grass, Sand, Mud, and Pebble/Ground with custom PBR MaterialVariants in MaterialService (desaturated forest-floor grass, packed gravel/dirt trail, damp lakeside pebbles) across the entire shore and meadow in 01-dock-dawn.jpg, 05-weedbed-golden.jpg, 07-overview-golden.jpg, and 08-stands-noon.jpg, and add rock riprap or timber retaining walls to hide the boxy vertical terrain canal banks under the bridge in 03-dockend-noon.jpg.
2. Replace the flat low-poly SmoothPlastic pine and deciduous trees ringing the lake in 03-dockend-noon.jpg, 05-weedbed-golden.jpg, 07-overview-golden.jpg, and 08-stands-noon.jpg with chunky, simple-shaped trees using real bark PBR textures and textured foliage clusters, and swap the plain dark-cylinder sunken logs in 06-logs-dawn.jpg and 07-overview-golden.jpg for weathered bark logs matching the dock bollards in 08-stands-noon.jpg.
3. Replace the default Sky and procedural Clouds in 01-dock-dawn.jpg and the flat grey overcast sky in 03-dockend-noon.jpg with custom natural skyboxes, dial back Bloom/SunRays glare at golden hour in 07-overview-golden.jpg so the horizon keeps warm detail instead of blowing out to white, and fix the night sky/Atmosphere settings in 04-dockend-night.jpg so the upper sky is dark and starry instead of bright blue above a black horizon band.

Strengths:
- The dock in 08-stands-noon.jpg nails the Real-ish goal: weathered plank grain, rough-cut log bollards with end-grain rings, and metal cleats read convincingly as real wood and hardware.
- The mossy shoreline boulders and lily-pad weedbed cove in 05-weedbed-golden.jpg read as genuine stone and a readable, inviting fishing spot.
- The two weathered-plank stalls framing the approach to the lantern-lit dock in 01-dock-dawn.jpg and 02-dock-golden.jpg give the hub a clear, calm composition with no cluttered floating name labels or stock UI boxes.
- Distinct time-of-day moods - including the glowing dock lanterns at golden hour in 02-dock-golden.jpg and drifting fireflies at night in 04-dockend-night.jpg - already convey a calm fishing atmosphere.

Broken or ugly:
- 04-dockend-night.jpg (upper half and lower third): the night sky is inverted - bright periwinkle blue overhead fading to a pitch-dark band at the horizon - and a harsh straight horizontal dark band cuts across the lower foreground.
- 07-overview-golden.jpg (top half): golden-hour bloom and sun glare blow out the entire horizon and upper-left sky to flat white-yellow, washing out the distant hills.
- 07-overview-golden.jpg (center lake): two straight, unnatural-looking diagonal light-pinkish strips show through the lakebed like terrain sculpting seams.

Reads as stock Roblox:
- Default Terrain Grass and pebble/ground path (01-dock-dawn.jpg and 02-dock-golden.jpg, bottom half of frame; 07-overview-golden.jpg, surrounding plain and path loop).: Uses stock Roblox Terrain textures with the unmistakable blobby voxel blending along the path edges.
- Default Terrain Sand, Mud, and Grass shoreline (05-weedbed-golden.jpg, foreground and right shore; 08-stands-noon.jpg, banks left and right of the dock).: Shows stock Roblox rippled Sand, flat brown Mud, and bright-green Grass patches sitting sharply next to each other.
- Default Roblox sky and procedural Clouds (01-dock-dawn.jpg, upper half of frame).: Reads immediately as the stock Roblox blue skybox and soft white procedural Clouds instance.
- Low-poly SmoothPlastic pine and deciduous trees (03-dockend-noon.jpg, 05-weedbed-golden.jpg, and 08-stands-noon.jpg treeline; 07-overview-golden.jpg foreground left and bottom).: Faceted cone pines and round-blob canopies with flat, untextured plastic-looking surfaces that resemble common Roblox toolbox low-poly trees and clash with the textured wood dock and rocks.
- Plain cylinder sunken logs (06-logs-dawn.jpg, center water; 07-overview-golden.jpg, lower-right water).: Read as smooth dark-brown untextured Roblox cylinders with flat circular end-caps and tiny cone stubs rather than weathered timber.
- Red-and-white channel buoy (03-dockend-noon.jpg and 04-dockend-night.jpg, center water).: Built from plain, flat-shaded SmoothPlastic cylinder and cone primitives with no surface wear or material grain.
- Squared-off green terrain canal banks under the bridge (03-dockend-noon.jpg, center).: Sharp vertical green terrain walls dropping abruptly into the water read as raw default Roblox Terrain sculpting.
- Bare Neon sphere post lamps and smooth plastic-slat awnings (08-stands-noon.jpg, Bait and Tackle and Sell Fish stalls).: Plain glowing spheres on poles without lantern frames and untextured flat-shaded awning bars read as default Roblox Neon and SmoothPlastic parts.

Action taken: (fill in: what we changed, or why we didn't)
