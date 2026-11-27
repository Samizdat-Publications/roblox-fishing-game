# Critic: n0-baseline-A-q21 (review, gemini-4-neon)

Date: 2026-11-27 15:21. Rubric: `look`.

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

**Score: 5.5/10**

The fishing spots already have a promising foundation - eye-level dawn and golden-hour views over the dock and cattail weedbed feel genuinely peaceful, and the mix of habitats (weedbeds, fallen logs, bridge channel, creek pool) signals a real fishing game. However, the overview and closer shots expose three big issues holding the look back: rigid rectangular shorelines that read like man-made basins, SmoothPlastic dock/stand/log/rock props that clash with the Real-ish wood-and-stone goal, and uneven lighting plus oversized floating UI labels that hurt mood and small-screen readability.

| Point | Score |
|---|---|
| composition | 6 |
| light | 6 |
| water | 6 |
| mood | 5 |
| want_to_fish | 6 |
| phone_readability | 5 |
| broken_or_ugly | 5 |

Top fixes:
1. Reshape the rectangular shorelines and flush the paths into Terrain: sculpt irregular coves, points, and gentle curves into the Terrain banks of the main lake (07-overview-golden.jpg) and Cedar Creek pool (10-pool-golden.jpg) to eliminate 90-degree corners, and replace the raised segmented path parts (06-logs-dawn.jpg) and mounded sand berm (11-gate-noon.jpg) with flat Terrain-painted dirt/sand paths blended smoothly into the grass.
2. Apply true wood and stone materials to key props: switch the SmoothPlastic dock planks, pilings, Bait and Tackle / Sell Fish stands, and fallen logs (01, 06, 08) to WoodPlanks or Wood (with subtle colour variation per plank/log), and change the untextured grey creek boulders (09-riffle-dawn.jpg, 10-pool-golden.jpg) to Rock or Slate so they match the textured terrain and fulfill the Real-ish art style.
3. Rebalance extreme lighting, daytime lamps, and floating labels: lower golden-hour Atmosphere Glare/Haze and BloomEffect Intensity so 07 and 10 stop washing out in orange glare; turn off lamp-post neon globes during daylight (08, 11) and add warm amber PointLights along the dock, bridge, and creek bank so night scenes (04, 12) remain readable on phones; and replace or proximity-fade the oversized BillboardGuis ('Sell Fish', 'Bait and Tackle', 'Slip 2/3/4') while moving the cattails blocking the chalkboard in 08-stands-noon.jpg.

Strengths:
- Eye-level dawn and golden-hour framing (01-dock-dawn.jpg, 02-dock-golden.jpg, 05-weedbed-golden.jpg) produces soft horizon haze, warm sky reflections on the water, and an inviting view out toward the bridge and hills.
- Real fishing structure is clearly readable across locations - cattails and lily pads in 05-weedbed-golden.jpg, submerged fallen logs in 06-logs-dawn.jpg, a buoyed bridge channel in 03-dockend-noon.jpg, and a creek riffle and pool in 09-riffle-dawn.jpg and 10-pool-golden.jpg.
- Glowing fireflies over the night shoreline (04-dockend-night.jpg, 12-pool-night.jpg) add a charming, memorable touch of lakeside life.
- Chunky, uncluttered silhouettes for the dock, bridge, stands, and Cedar Creek archway make the layout easy to scan at desktop and phone sizes.

Broken or ugly:
- 08-stands-noon.jpg: Tall cattails grow directly in front of the green chalkboard sign, blocking its text, and a second brown fish sign behind it is partially clipped/obscured.
- 06-logs-dawn.jpg: The curved sand walkway is built from flat segmented parts whose sharp, raised edges and seams stick out awkwardly above the grass.
- 11-gate-noon.jpg: The sand path rises like a thick speedbump/berm above flat grass, and terrain grass blades abruptly start only behind the fence line.
- 08-stands-noon.jpg and 11-gate-noon.jpg: Lamp posts glow bright white neon in broad daylight at noon.
- 01-dock-dawn.jpg and 02-dock-golden.jpg: Oversized 'Sell Fish' and 'Bait and Tackle' BillboardGuis clip off the left and right edges of the screen.
- 07-overview-golden.jpg and 10-pool-golden.jpg: Both the main lake and Cedar Creek pool have rigid rectangular edges and 90-degree corners that read like artificial concrete basins rather than natural water bodies.
- 01, 02, 06, 08, 09, 10: Dock planks, market stands, submerged logs, and creek rocks appear as flat untextured SmoothPlastic instead of wood or stone.

Action taken: (fill in: what we changed, or why we didn't)
