# Critic: n0-baseline-A-q21-identity (review, gemini-4-neon)

Date: 2026-11-27 15:25. Rubric: `identity`.

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

The warm golden-hour and dawn atmosphere gives a glimpse of the calm fishing world you are aiming for, but once you look at noon lighting or close-up surfaces, almost every major element reads as stock Roblox. The biggest gap against your Real-ish art direction is that docks, stalls, logs, boulders, and trees are untextured SmoothPlastic and flat-shaded low-poly shapes sitting inside default Roblox terrain, default skyboxes, and stock floating dark rounded BillboardGuis.

| Point | Score |
|---|---|
| materials | 3 |
| signature | 3 |
| cohesion | 4 |
| stock_free | 2 |
| identity | 3 |

Top fixes:
1. Replace SmoothPlastic and flat-shaded assets with custom PBR MaterialVariants: put weathered plank wood on the dock, pilings, and both stalls (08-stands-noon.jpg), rough bark on the water logs (06-logs-dawn.jpg), matte striped canvas on the stall awnings, and mossy stone MaterialVariant on less-faceted rock meshes (09-riffle-dawn.jpg), while swapping the stacked-cone and blob SmoothPlastic trees for textured-bark trees with layered foliage.
2. Remove every floating dark rounded BillboardGui label (Sell Fish, Bait and Tackle, Slip 2/3/4, Boat slips, Your Pond, Cedar Creek in 01-dock-dawn.jpg, 08-stands-noon.jpg, and 11-gate-noon.jpg) and replace them with physical painted wooden signs using SurfaceGuis on the stall roofs, the Cedar Creek archway beam, and small numbered dock posts, set in one consistent readable game font such as RobotoSlab or Merriweather.
3. Replace the default Roblox Sky across all times of day (most glaring in 03-dockend-noon.jpg, 08-stands-noon.jpg, and 11-gate-noon.jpg) with a custom skybox plus a Roblox Clouds instance, override Terrain Grass and Sand with cohesive custom MaterialVariants, and blend the raised segmented sand-part walkway (06-logs-dawn.jpg) and rigid rectangular pond edges (07-overview-golden.jpg, 10-pool-golden.jpg) into natural curved terrain banks.

Strengths:
- Dawn and golden-hour Atmosphere lighting in 02-dock-golden.jpg, 05-weedbed-golden.jpg, and 10-pool-golden.jpg creates genuine warmth, haze, and tranquil water reflections.
- Thoughtful diegetic details are already started, such as the green chalkboard and fish plaques by Your Pond and the hanging fish scale inside Sell Fish in 08-stands-noon.jpg, the rod rack on Bait and Tackle in 01-dock-dawn.jpg, lily pads in 05-weedbed-golden.jpg, and night fireflies in 04-dockend-night.jpg.
- Clear sightlines from the shore down the dock toward the bridge and hills in 01-dock-dawn.jpg and 02-dock-golden.jpg establish an inviting, readable fishing layout.

Broken or ugly:
- BillboardGui labels in 01-dock-dawn.jpg and 02-dock-golden.jpg clip awkwardly at the left and right screen edges ('l Fish' and 'Bait and T') and stack on top of each other over the dock and player ('Boat slips', 'Slip 3', 'Slip 4').
- Lamp post white Neon globes stay switched on during bright midday in 08-stands-noon.jpg and 11-gate-noon.jpg.
- Cattails in 08-stands-noon.jpg (mid-left) grow directly in front of the green chalkboard and fish trophy board, partially blocking the text.
- In 06-logs-dawn.jpg (foreground), the segmented Sand-material path parts protrude above the terrain grass with exposed flat block edges and polygonal corners.
- In 09-riffle-dawn.jpg (center), a patch of textured Terrain rock pokes out through the top of the flat-shaded grey SmoothPlastic boulder pile.

Reads as stock Roblox:
- Default Roblox daytime and nighttime skybox (03-dockend-noon.jpg, 08-stands-noon.jpg, 11-gate-noon.jpg upper half; 04-dockend-night.jpg and 12-pool-night.jpg sky): Shows the unmistakable default blurry white cloud formations on bright cyan daytime sky and stock starry night sky.
- Floating dark rounded BillboardGui labels (01-dock-dawn.jpg and 02-dock-golden.jpg edges and dock center; 06-logs-dawn.jpg left and center; 08-stands-noon.jpg across stands, pond, and dock; 11-gate-noon.jpg over the gate): Stock semi-transparent dark charcoal rounded boxes using default bold sans-serif text ('Sell Fish', 'Bait and Tackle', 'Slip 2/3/4', 'Boat slips', 'Your Pond', 'Cedar Creek').
- SmoothPlastic dock planks, octagonal pilings, and bright orange slip markers (08-stands-noon.jpg foreground center; 01-dock-dawn.jpg center): Completely flat, glossy untextured brown and orange SmoothPlastic parts with no wood grain or weathering.
- SmoothPlastic market stalls and striped awnings (01-dock-dawn.jpg and 02-dock-golden.jpg left and right foreground; 08-stands-noon.jpg midground): Plain flat-colored brown panels and untextured yellow/white and blue/white SmoothPlastic roofs.
- Faceted flat-shaded SmoothPlastic boulders (09-riffle-dawn.jpg center pile; 10-pool-golden.jpg and 12-pool-night.jpg right bank): Untextured grey low-poly meshes with flat triangle shading that look like plastic polygons rather than stone.
- Low-poly SmoothPlastic stacked-cone pines and faceted blob trees (08-stands-noon.jpg far left; 09-riffle-dawn.jpg center hill and background; 10-pool-golden.jpg background left; 11-gate-noon.jpg behind fence; 05-weedbed-golden.jpg mid-left): Generic Roblox simulator-style flat-colored SmoothPlastic tree shapes instead of textured bark and believable foliage.
- SmoothPlastic fallen logs and blocky cattails (06-logs-dawn.jpg center water; 05-weedbed-golden.jpg foreground left): Logs are plain untextured brown cylinders with sharp flat cut ends, and cattails are rectangular untextured green and brown plastic prisms.
- Stock Roblox Terrain Grass, Grass Decoration blades, Sand, and Terrain Water (visible across all 12 shots, clearest in 03-dockend-noon.jpg, 09-riffle-dawn.jpg, 10-pool-golden.jpg, and 11-gate-noon.jpg): Unmodified default Roblox terrain textures, uniform default blade grass, and standard swirly terrain water reflections.
- Segmented Sand-material walkway parts (06-logs-dawn.jpg foreground bottom; 07-overview-golden.jpg circling the pond): Flat rectangular parts using the stock Roblox Sand material laid over grass with visible straight-edged seams.
- Stock Wood-material fence and Cedar Creek gate arch (11-gate-noon.jpg center and left/right): Plain rectangular blocks using the default Roblox Wood texture.
- Neon white sphere lamp posts (08-stands-noon.jpg beside both stalls; 11-gate-noon.jpg right of gate; 06-logs-dawn.jpg mid-left): Basic brown poles topped with untextured glowing stock Neon white balls.

Action taken: (fill in: what we changed, or why we didn't)
