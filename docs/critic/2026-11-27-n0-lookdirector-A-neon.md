# Critic: n0-lookdirector-A (review, gemini-4-neon)

Date: 2026-11-27 15:26. Rubric: `look`.

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

**Score: 6/10**

You already have real fishing-game instincts here: the weedbed with lily pads, submerged logs, and dock-to-bridge sightline genuinely look like places where fish hide, and dawn/golden hour reflections on the water are lovely. Right now, though, three things hold it back from feeling like a memorable, Real-ish lake: key props (dock, stands, logs, boulders) are still flat SmoothPlastic instead of true wood and stone, the main lake and creek pool have noticeably boxy rectangular shorelines with floating/raised sand paths, and large floating BillboardGui labels plus daytime-lit lamps and giant starburst fireflies break the calm mood.

| Point | Score |
|---|---|
| composition | 6 |
| light | 7 |
| water | 7 |
| mood | 6 |
| want_to_fish | 7 |
| phone_readability | 5 |
| broken_or_ugly | 5 |

Top fixes:
1. Replace SmoothPlastic on all hero props with true Roblox materials: apply WoodPlanks or Wood (with slightly varied muted browns) to the dock planks, pilings, Sell Fish and Bait and Tackle stands, and fallen logs (06-logs-dawn.jpg, 08-stands-noon.jpg), and swap the flat grey faceted boulders at the riffle and pool (09-riffle-dawn.jpg, 10-pool-golden.jpg) to Rock or Slate material so they match the realistic terrain grass.
2. Break up the rectangular shorelines and path edges: use Terrain Sculpt/Smooth to carve natural curves, coves, and varied banks into the boxy main lake (07-overview-golden.jpg), straight creek ditch (09-riffle-dawn.jpg), and pool (10-pool-golden.jpg), and replace the stepped floating sand path Parts (06-logs-dawn.jpg) and raised sand ridge (11-gate-noon.jpg) with flush Terrain Sand/Ground paint blended into the grass.
3. Clean up world labels and lighting extremes: swap the oversized dark-pill BillboardGuis (01-dock-dawn.jpg, 08-stands-noon.jpg, 11-gate-noon.jpg) for in-world SurfaceGui painted wooden signs on the stands/gate and proximity prompts for boat slips so they stop clipping off-screen and crowding phones; lower golden-hour BloomEffect.Intensity and Atmosphere.Glare (07-overview-golden.jpg, 10-pool-golden.jpg); script streetlamps to turn off during daytime (08-stands-noon.jpg, 11-gate-noon.jpg) and cast warm PointLights on the dock/bridge at night; and shrink the night firefly ParticleEmitter texture from giant starbursts (04-dockend-night.jpg) to tiny soft glowing circles.

Strengths:
- Thoughtful, believable fishing habitats: the cattail weedbed with lily pads (05-weedbed-golden.jpg), submerged fallen logs (06-logs-dawn.jpg), bridge channel (03-dockend-noon.jpg), and creek pool (10-pool-golden.jpg) immediately make you want to pick a spot and cast.
- Dawn and golden-hour lighting at eye level (01-dock-dawn.jpg, 02-dock-golden.jpg, 05-weedbed-golden.jpg) creates warm sky gradients, soft horizon haze, and inviting water reflections.
- Strong chunky silhouettes on the bridge, trees, and stands - and the Cedar Creek wooden archway (11-gate-noon.jpg) proves how well real Wood material fits this chunky style.
- Clean screen space with no noisy HUD clutter covering the view of the water.

Broken or ugly:
- 04-dockend-night.jpg: Oversized green spiky starburst firefly particles right in front of the camera look like glitched default sparkles and break the night mood.
- 06-logs-dawn.jpg: The curved sand walkway is a flat Part with visible faceted straight segments and a lip sticking out above the grass terrain.
- 08-stands-noon.jpg: A cluster of cattails is planted directly in front of the green notice board by Bait and Tackle, blocking the board text.
- 01-dock-dawn.jpg and 02-dock-golden.jpg: Floating BillboardGui titles clip off both sides of the screen ('| Fish' and 'Bait and T'), while 'Boat slips', 'Slip 3', and 'Slip 4' stack directly over the player avatar.
- 08-stands-noon.jpg, 11-gate-noon.jpg, and 06-logs-dawn.jpg: White Neon lamp globes are switched on brightly during midday and dawn.
- 07-overview-golden.jpg and 10-pool-golden.jpg: Golden-hour Bloom and Atmosphere glare blow out the top of the frame into a harsh, flat yellow-orange wash.
- 09-riffle-dawn.jpg and 10-pool-golden.jpg: Flat-shaded SmoothPlastic boulders clash sharply against the detailed terrain grass and a single textured rock sitting on top of them.
- 11-gate-noon.jpg: The sand path forms an abrupt, raised ridge sitting on top of flat green grass with no edge blending.

Action taken: (fill in: what we changed, or why we didn't)
