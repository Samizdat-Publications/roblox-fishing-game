# Critic: n0-baseline-B-identity (review, gemini-4-neon)

Date: 2026-11-27 15:33. Rubric: `identity`.

Files shown:
- `b01-bridge-dawn.jpg`
- `b02-basin-boat-noon.jpg`
- `b03-lighthouse-golden.jpg`
- `b04-buoys-dusk.jpg`
- `b05-bluewater-noon.jpg`
- `b06-marina-night.jpg`

**Score: 3/10**

Right now these shots read strongly as a stock Roblox Terrain world populated with flat SmoothPlastic primitives rather than a distinct Real-ish fishing game. The biggest culprits are the default Roblox skybox, stock Terrain grass/sand/water, raw orange cylinder buoys, and flat-shaded low-poly trees that clash with the realistic terrain. The dawn haze in b01 and golden-hour sun rays in b03 hint at a lovely calm fishing mood, so replacing the stock sky, terrain MaterialVariants, and SmoothPlastic props will immediately transform the identity.

| Point | Score |
|---|---|
| materials | 3 |
| signature | 2 |
| cohesion | 4 |
| stock_free | 2 |
| identity | 3 |

Top fixes:
1. Replace the default Skybox and stock Terrain materials across all shots (b01 through b06): install a custom Sky asset with Atmosphere haze, override Terrain Grass and Sand via MaterialService MaterialVariants with cohesive real-ish textures, and tune Terrain WaterColor, WaterTransparency, and WaterWaveSize so the water looks calmer and less like stock marbled Roblox water.
2. Replace the flat SmoothPlastic foliage (trees across b01-b06, blocky cattails and octagonal lily pads in b01-b03) with chunky Real-ish meshes that carry real bark, pine-needle, and leaf SurfaceAppearance or MaterialVariant textures so foliage stops looking like simulator toys sitting on realistic terrain.
3. Replace the raw orange SmoothPlastic cylinder buoys (b05-bluewater-noon.jpg lower-right, b04-buoys-dusk.jpg center) and basic plank bridge (b01-bridge-dawn.jpg center) with real-ish nautical landmarks: weathered painted metal/plastic buoys with proper tapered shapes and dusk beacon lights, and a bridge built from weathered wood planks, stone abutments, and connected railing posts.

Strengths:
- Golden-hour lighting and sun rays cutting through the cattails in b03-lighthouse-golden.jpg create a genuine, atmospheric fishing-spot mood.
- Soft dawn atmospheric haze over the canal in b01-bridge-dawn.jpg conveys calm early-morning stillness that fits the game's tone.
- The underlying world layout already offers varied, believable fishing spots - a canal bridge, shallow reed beds, an island cove, and open water - across a full day-night cycle.

Broken or ugly:
- b01-bridge-dawn.jpg (center): The bridge's two upper horizontal wooden railings are floating in mid-air with no vertical posts connecting them to the bridge deck.
- b03-lighthouse-golden.jpg (center): The lighthouse landmark is completely obscured behind the dense wall of cattails and trees on the island, hiding the focal point of the vista.
- b06-marina-night.jpg (entire midground): The shoreline, bridge, and pier drop into near-black silhouettes with almost no local dock or marina lighting, making the scene unreadable on a small phone screen.

Reads as stock Roblox:
- Default Roblox Skybox and clouds in b01-bridge-dawn.jpg (upper half), b02-basin-boat-noon.jpg (upper half), b05-bluewater-noon.jpg (upper half), b04-buoys-dusk.jpg (upper half), and b06-marina-night.jpg (upper half): Displays the immediately recognizable default Roblox bright blue sky, blurry white cloud patch, and standard night starfield.
- Default Roblox Terrain Water in b01-bridge-dawn.jpg through b06-marina-night.jpg (foreground and midground water): Shows the unmistakable stock swirling/marbled Roblox Terrain water normal pattern and reflectance.
- Default Roblox Terrain Grass, Grass Decoration blades, and Terrain Sand in b01-bridge-dawn.jpg (left/right banks), b02-basin-boat-noon.jpg (island and hills), b03-lighthouse-golden.jpg (background hills), b05-bluewater-noon.jpg (beach and hills), and b06-marina-night.jpg (shoreline): Uses untuned stock Terrain grass and sand textures with default green blades.
- Orange SmoothPlastic cylinder buoys in b05-bluewater-noon.jpg (lower-right foreground), b04-buoys-dusk.jpg (line down center), and b02-basin-boat-noon.jpg (far-right edge): Raw untextured Roblox Cylinder parts with SmoothPlastic material, razor-sharp edges, and no nautical geometry or markings.
- Low-poly SmoothPlastic trees in b01-bridge-dawn.jpg (left bank), b02-basin-boat-noon.jpg (island and hills), b03-lighthouse-golden.jpg (center behind reeds), b04-buoys-dusk.jpg (horizon), b05-bluewater-noon.jpg (hills), and b06-marina-night.jpg (midground): Generic Roblox simulator-style faceted SmoothPlastic blob trees and stacked-cone pines with flat untextured surfaces.
- SmoothPlastic lily pads, lotus flowers, and cattails in b03-lighthouse-golden.jpg (foreground center and lower-right), b01-bridge-dawn.jpg (lower-right and lower-left), and b02-basin-boat-noon.jpg (center-right shoreline): Built from flat untextured SmoothPlastic octagons, faceted pink blossoms, flat strips, and plain brown cylinders.
- Basic block/plank bridge in b01-bridge-dawn.jpg (center) and b06-marina-night.jpg (center midground): Simple rectangular Roblox parts and tilted ramp blocks with uniform stock brown wood texture and detached floating rails.

Action taken: (fill in: what we changed, or why we didn't)
