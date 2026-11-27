# Critic: n0-baseline-A-q21 (review, gemini-4-neon)

Date: 2026-11-27 15:20. Rubric: `look`.

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

**Score: 6.0/10**

There is a genuinely inviting fishing heart here - especially the weedbed at golden hour (05-weedbed-golden.jpg) and the sunken logs at dawn (06-logs-dawn.jpg), which already read like real spots where fish hold. What holds the world back from its Real-ish target is the rigid rectangular shape of the lake and creek pool, flat plastic-looking materials on key wood and stone props, oversized floating BillboardGui labels cluttering the view, and uneven lighting where night is nearly unreadable and golden hour blooms out.

| Point | Score |
|---|---|
| composition | 6 |
| light | 6.5 |
| water | 6.5 |
| mood | 6 |
| want_to_fish | 7 |
| phone_readability | 5 |
| broken_or_ugly | 5 |

Top fixes:
1. Break up the artificial rectangular lake and pool geometry (07-overview-golden.jpg, 10-pool-golden.jpg) using Roblox Terrain Sculpt and Smooth to add irregular coves, points, and gradual banks; replace the segmented flat-part sand path jutting over the grass (06-logs-dawn.jpg) and the bulging sand ridge (11-gate-noon.jpg) with smoothly painted Terrain Sand/Ground/Mud, and line the straight ditch in 09-riffle-dawn.jpg with boulders and subtle whitewater foam particles.
2. Bring props up to the Real-ish material bar and clear the UI clutter: assign true Wood/WoodPlanks and Rock/Slate materials (or PBR SurfaceAppearances) to the dock planks, stalls, sunken logs (01, 06, 08), and smooth faceted boulders (09-riffle-dawn.jpg, 10-pool-golden.jpg); replace the giant dark-pill BillboardGuis (Sell Fish, Bait and Tackle, Cedar Creek, Slip 2/3/4) with SurfaceGui wooden signs on the stalls/arch and small piling numbers or proximity-only prompts; move the cattails blocking the green chalkboard in 08-stands-noon.jpg.
3. Balance Lighting, Atmosphere, and lamps across times of day: dial back BloomEffect.Intensity and Atmosphere.Glare at golden hour to stop the yellow-white washout in 07-overview-golden.jpg and 10-pool-golden.jpg; raise night OutdoorAmbient slightly with cool moonlight and add warm PointLight lanterns to the dock, bridge, and buoy so 04-dockend-night.jpg and 12-pool-night.jpg stay readable on a phone; add light haze to soften harsh noon (03, 08, 11); and script the stall/path lamps to turn off during daytime (06, 08, 11).

Strengths:
- Dawn and golden hour skies and water reflections look genuinely peaceful and memorable, especially looking out from the dock (01-dock-dawn.jpg, 02-dock-golden.jpg) and across the cattails and lily pads (05-weedbed-golden.jpg).
- Real fishing structure is already being built into the map - cattail weedbeds with lily pads (05-weedbed-golden.jpg), half-submerged logs (06-logs-dawn.jpg), a buoyed channel under a bridge (03-dockend-noon.jpg), and a creek riffle (09-riffle-dawn.jpg) - giving players clear visual cues for where to cast.
- Foreground-to-background layering works well on the ground in 05-weedbed-golden.jpg and 02-dock-golden.jpg, where distant misty hills and the bridge silhouette give the lake a convincing sense of scale.
- Subtle fireflies near the shore at night (04-dockend-night.jpg, 12-pool-night.jpg) add a nice touch of life.

Broken or ugly:
- 06-logs-dawn.jpg: Curved shoreline sand path is built from flat segmented parts with jagged polygonal edges sticking out above the grass and harsh terrain seams.
- 08-stands-noon.jpg: Cattails are placed directly in front of the green chalkboard sign next to Bait and Tackle, blocking the text.
- 06-logs-dawn.jpg, 08-stands-noon.jpg, 11-gate-noon.jpg: Bright white neon lamp globes remain switched on in broad daylight and high noon.
- 07-overview-golden.jpg and 10-pool-golden.jpg: Lake and pool shorelines are rigid rectangles with sharp corners, and golden-hour bloom/glare washes out the sky and left terrain.
- 01-dock-dawn.jpg, 02-dock-golden.jpg, 08-stands-noon.jpg: Oversized floating dark-pill BillboardGuis clip off screen edges (| Fish, Bait and T) and stack awkwardly around the player (Boat slips, Slip 2, Slip 3, Slip 4).
- 09-riffle-dawn.jpg: Faceted smooth grey boulders and smooth cone pines lack rock/foliage texture, clashing with textured terrain, and the riffle reads like a straight grassy ditch.
- 11-gate-noon.jpg: Sand path bulges upward like a raised tube resting on flat grass.
- 04-dockend-night.jpg and 12-pool-night.jpg: Water and distant banks drop to near-black with almost no warm light anchors, making shorelines hard to read on a small screen.
- 03-dockend-noon.jpg: Dark angled wedge structures under the bridge abutments look awkwardly clipped into the water.

Action taken: (fill in: what we changed, or why we didn't)
