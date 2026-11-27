# Critic: n0-baseline-A-q21-identity (review, gemini-4-neon)

Date: 2026-11-27 15:23. Rubric: `identity`.

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

**Score: 3/10**

Right now the game reads much closer to a default Roblox template than its own world, even though the dawn, golden-hour, and firefly night moods show real promise. Nearly every foreground surface is either unmodified stock Roblox terrain/water/sky or flat untextured SmoothPlastic props, topped with stock dark rounded floating BillboardGui labels. Replacing SmoothPlastic with real wood, stone, and fabric materials, turning floating labels into physical wooden signs, and swapping the default skybox and terrain palette will transform it into the Real-ish fishing game you are aiming for.

| Point | Score |
|---|---|
| materials | 3 |
| signature | 2 |
| cohesion | 3 |
| stock_free | 2 |
| identity | 3 |

Top fixes:
1. Replace SmoothPlastic on all built and natural props with real PBR materials (MaterialVariant or SurfaceAppearance): apply weathered wood grain to the dock planks, posts, and stalls (01, 02, 08), canvas Fabric to the stall awnings (08), rough bark and textured foliage to the trees and submerged logs (06, 08, 09, 11), matte organic textures to the cattails (05), and rocky stone PBR material to the faceted boulders at the riffle and pool (09, 10).
2. Remove all floating dark rounded BillboardGui labels ('Sell Fish', 'Bait and Tackle', 'Boat slips', 'Slip 2/3/4', 'Your Pond', 'Cedar Creek' in 01, 02, 06, 08, 11) and replace them with physical wooden signs mounted directly on the stalls, dock posts, and Cedar Creek archway using SurfaceGui and a distinct warm serif or hand-painted font.
3. Replace the default Roblox Sky cubemap (visible in 01-05, 08, 09, 11) with a custom horizon skybox and Clouds instance, override stock Terrain Grass/LeafyGrass/Sand with cohesive muted lakeside MaterialVariants, tune Terrain water color/transparency and tone down golden-hour Bloom glare (07), and swap the flat sand-part perimeter path (06, 07) and bright midday Neon lamp balls (08, 11) for natural dirt/gravel trails and lanterns that only light up at dusk and night.

Strengths:
- Dawn and golden-hour atmosphere lighting in 02-dock-golden.jpg, 05-weedbed-golden.jpg, and 06-logs-dawn.jpg creates a genuinely calm, inviting lakeside mood, and the subtle green fireflies in 04-dockend-night.jpg and 12-pool-night.jpg are a lovely atmospheric touch.
- Distinct fishing habitats are readable in the layout (weedbed in 05-weedbed-golden.jpg, submerged logs in 06-logs-dawn.jpg, bridge channel in 03-dockend-noon.jpg, riffle in 09-riffle-dawn.jpg, and creek pool in 10-pool-golden.jpg), which supports real fishing-knowledge gameplay.
- The Cedar Creek archway and split-rail fence in 11-gate-noon.jpg already use textured wood instead of flat plastic, pointing in the right direction for the Real-ish style.

Broken or ugly:
- In 08-stands-noon.jpg (mid-left), the cattails planted along the bank directly block and obscure the wooden information/chalkboard sign behind them.
- In 01-dock-dawn.jpg and 02-dock-golden.jpg, the floating 'Sell Fish' and 'Bait and Tackle' BillboardGui labels clip off the left and right edges of the screen ('l Fish', 'Bait and T'), while 'Boat slips', 'Slip 3', and 'Slip 4' stack right over the player character.
- In 08-stands-noon.jpg (beside both stands) and 11-gate-noon.jpg (right of the Cedar Creek gate), the white Neon lamp spheres remain fully lit at midday.
- In 06-logs-dawn.jpg (foreground), the segmented sand-material path parts stick out above the grass terrain with sharp polygonal edges and visible seams.
- In 07-overview-golden.jpg, golden-hour bloom and haze overexpose the upper half and lake surface into a bright orange washout that reduces readability.

Reads as stock Roblox:
- Default Roblox Skybox and clouds (01-dock-dawn.jpg, 02-dock-golden.jpg, 03-dockend-noon.jpg, 04-dockend-night.jpg, 05-weedbed-golden.jpg, 08-stands-noon.jpg, 09-riffle-dawn.jpg, 11-gate-noon.jpg, upper half of frame): The exact default Roblox cloud cubemap pattern (notably the cloud cluster in the upper right) is unchanged across dawn, noon, golden hour, and night.
- Stock Roblox Terrain Water (03-dockend-noon.jpg, 04-dockend-night.jpg, 05-weedbed-golden.jpg, 06-logs-dawn.jpg, 08-stands-noon.jpg, 10-pool-golden.jpg, 12-pool-night.jpg, water surfaces): Unmistakable stock Roblox swirling terrain water normal map and specular shimmer, especially prominent up close at noon and golden hour.
- Stock Roblox Terrain Grass, LeafyGrass, Sand, and Terrain Decoration grass blades (01-dock-dawn.jpg foreground, 06-logs-dawn.jpg foreground, 09-riffle-dawn.jpg foreground/hills, 10-pool-golden.jpg right bank and hills, 11-gate-noon.jpg lawn and raised sand path): Default unmodified Roblox terrain material textures and uniform grass blade decoration immediately read as default Studio terrain.
- Floating always-on-top BillboardGui labels (01-dock-dawn.jpg and 02-dock-golden.jpg edges and center, 06-logs-dawn.jpg left/center, 08-stands-noon.jpg across dock and stalls, 11-gate-noon.jpg above gate): Stock dark translucent rounded pills with default sans-serif font ('Slip 2', 'Slip 3', 'Slip 4', 'Boat slips', 'Sell Fish', 'Bait and Tackle', 'Your Pond', 'Cedar Creek') floating in mid-air.
- SmoothPlastic dock planks, posts, and yellow slip markers (01-dock-dawn.jpg center, 08-stands-noon.jpg lower and center foreground): Flat solid-brown and bright-yellow untextured plastic bricks with zero wood grain or weathering.
- SmoothPlastic shop stalls and striped awnings (01-dock-dawn.jpg and 02-dock-golden.jpg left/right edges, 08-stands-noon.jpg midground left and right): Plain flat-colored SmoothPlastic blocks instead of textured timber walls and canvas fabric awnings.
- Low-poly faceted SmoothPlastic pine and deciduous trees (03-dockend-noon.jpg shoreline, 05-weedbed-golden.jpg far left, 06-logs-dawn.jpg left, 08-stands-noon.jpg far left, 09-riffle-dawn.jpg center and right, 10-pool-golden.jpg center-left, 11-gate-noon.jpg midground): Generic untextured stacked-cone pines and faceted polygon canopies straight out of typical low-poly Roblox simulators, clashing with realistic terrain textures.
- Faceted SmoothPlastic grey rocks (09-riffle-dawn.jpg center mound, 10-pool-golden.jpg and 12-pool-night.jpg right shoreline): Flat-shaded smooth grey geometric boulders with no stone texture sitting directly on textured terrain.
- Untextured SmoothPlastic cattails and floating logs (05-weedbed-golden.jpg foreground left/center, 06-logs-dawn.jpg center water, 08-stands-noon.jpg left of dock): Plain SmoothPlastic rectangular prisms for reeds/cattails and flat-capped smooth brown cylinders for logs, with no plant or bark texture.
- Segmented flat path parts with stock Sand material (06-logs-dawn.jpg foreground across frame, 07-overview-golden.jpg around pond perimeter): Flat polygonal Part slabs textured with default Roblox Sand cutting abruptly across the terrain grass.
- Glowing white Neon sphere street lamps (06-logs-dawn.jpg left, 08-stands-noon.jpg next to stands, 11-gate-noon.jpg right of archway): Simple default Neon white balls perched on plain poles, glowing at full brightness even at noon.
- Default blocky Roblox character avatar (01-dock-dawn.jpg, 02-dock-golden.jpg, 08-stands-noon.jpg center): Standard blocky Roblox avatar look in casual holiday clothing (Santa hat, plaid pants) rather than a game-grounded fisher silhouette.

Action taken: (fill in: what we changed, or why we didn't)
