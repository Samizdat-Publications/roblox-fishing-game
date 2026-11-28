# Critic: n1-round4-lake-identity (review, gemini-4-neon)

Date: 2026-11-27 19:19. Rubric: `identity`.

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

The game already has the heart of its own calm, Real-ish fishing identity - the weathered wood dock, timber stalls, dark cove boulders, and golden-hour atmosphere look genuinely handcrafted and free of typical Roblox clutter. However, two styles are currently fighting each other: realistic PBR wood and stone sit directly on top of unmodified stock Roblox terrain and alongside untextured SmoothPlastic low-poly trees, so in flat daylight the world snaps back to reading as default Roblox.

| Point | Score |
|---|---|
| materials | 6 |
| signature | 5 |
| cohesion | 5 |
| stock_free | 5 |
| identity | 5.5 |

Top fixes:
1. Override stock Terrain Grass, Ground, Sand, and Mud via MaterialService MaterialVariants across the dock approach (01-dock-dawn.jpg, 02-dock-golden.jpg), shoreline behind the dock (08-stands-noon.jpg), cove beach (05-weedbed-golden.jpg), and surrounding hills (07-overview-golden.jpg) with muted olive-sage grass, warmer packed-dirt/pebble path, and finer damp shoreline silt, breaking up jagged voxel borders with edging stones or timber curbing.
2. Replace the untextured SmoothPlastic low-poly pine and leafy trees (03-dockend-noon.jpg, 05-weedbed-golden.jpg, 07-overview-golden.jpg, 08-stands-noon.jpg) and smooth tapered cove logs (06-logs-dawn.jpg) with bark-textured meshes and textured foliage cards or painterly clusters so the forest and snags match the realistic wood on the dock.
3. Replace the default blue sky and procedural Roblox Clouds in 01-dock-dawn.jpg, the flat featureless grey overcast in 03-dockend-noon.jpg and 08-stands-noon.jpg, and the inverted night sky gradient in 04-dockend-night.jpg with custom Sky textures and tuned Atmosphere presets so daylight and night feel as distinctive as golden hour.

Strengths:
- The weathered dock planks and end-grain log pilings in 08-stands-noon.jpg and the timber siding on both stalls in 01-dock-dawn.jpg and 08-stands-noon.jpg convincingly read as real wood and nail the Real-ish brief.
- The dark textured foreground boulders paired with cattails and lily pads in 05-weedbed-golden.jpg create a believable, fishing-specific shoreline vignette.
- Golden-hour and misty dawn lighting in 02-dock-golden.jpg, 05-weedbed-golden.jpg, 06-logs-dawn.jpg, and 07-overview-golden.jpg - along with subtle fireflies and the lit channel buoy in 04-dockend-night.jpg - establish a calm, restrained mood with zero floating nameplates or neon clutter.
- The symmetrical view between the two stalls down the lantern-lit dock toward the bridge and distant hill in 01-dock-dawn.jpg and 02-dock-golden.jpg gives the hub a clear, inviting focal composition.

Broken or ugly:
- 04-dockend-night.jpg: The night sky has an unnatural inverted gradient - darkest right behind the treeline and noticeably brighter slate-blue higher up.
- 07-overview-golden.jpg: Faint straight diagonal terrain strips are visible across the lakebed beneath the water surface.
- 03-dockend-noon.jpg: The channel banks directly beneath the distant bridge terminate in abrupt, boxy green terrain cut-outs.

Reads as stock Roblox:
- Stock Roblox Terrain Grass and Ground/Gravel path (01-dock-dawn.jpg and 02-dock-golden.jpg lower half; 07-overview-golden.jpg looping shore path and hills; 08-stands-noon.jpg midground behind dock): Uses unmodified default smooth terrain textures with unmistakable jagged voxel-blend edges and bright lime-green patches sitting abruptly against brown soil in daylight.
- Stock Roblox Terrain Sand and Mud shoreline (05-weedbed-golden.jpg lower foreground and right bank; 08-stands-noon.jpg left and right shore edges): Shows the recognizable repeating ripple pattern of default Roblox Sand and flat default Mud right beside custom textured boulders and weathered wood.
- Low-poly SmoothPlastic pine and deciduous trees (03-dockend-noon.jpg treeline; 05-weedbed-golden.jpg far-left pine and background; 07-overview-golden.jpg foreground corners and woods; 08-stands-noon.jpg background pines and left leafy clusters): Faceted, flat-shaded meshes with no bark or needle texture that read as standard Roblox stylized/toolbox trees and clash with the photo-textured dock timber.
- Smooth tapered sunken logs (06-logs-dawn.jpg center cove; 07-overview-golden.jpg right side of main pond): Simple tapered cylinders with tiny cone-stub branches and flat solid-tan cut ends that read as bare primitive/SmoothPlastic meshes rather than bark-covered fallen timber.
- Default daylight blue sky with procedural Clouds (01-dock-dawn.jpg upper half) and flat grey overcast sky (03-dockend-noon.jpg and 08-stands-noon.jpg upper half): 01-dock-dawn.jpg displays Roblox's recognizable default sky and built-in Clouds object, while noon shots flatten into a featureless default grey blanket with no custom sky depth.

Action taken: (fill in: what we changed, or why we didn't)
