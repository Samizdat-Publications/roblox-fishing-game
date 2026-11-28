# Critic: n1-round5-lake (review, gemini-4-neon)

Date: 2026-11-27 19:55. Rubric: `look`.

Files shown:
- `01-dock-dawn.jpg`
- `02-dock-golden.jpg`
- `03-dockend-noon.jpg`
- `04-dockend-night.jpg`
- `05-weedbed-golden.jpg`
- `06-logs-dawn.jpg`
- `07-overview-golden.jpg`
- `08-stands-noon.jpg`

**Score: 7.4/10**

This already looks like a real fishing lake with distinct, readable fish-holding habitats and a genuinely cozy Real-ish aesthetic. The weedbed at golden hour (05-weedbed-golden.jpg), the misty log cove at dawn (06-logs-dawn.jpg), and the weathered dock planks (08-stands-noon.jpg) nail the chunky-shapes-with-real-materials target. The biggest thing holding the scene back is inconsistent Lighting, Skybox, and Atmosphere tuning: noon looks weirdly flat and gloomy overcast, while night and the golden-hour overview show harsh horizon-band artifacts.

| Point | Score |
|---|---|
| composition | 8 |
| light | 6 |
| water | 7.5 |
| mood | 8 |
| want_to_fish | 8.5 |
| phone_readability | 7 |
| broken_or_ugly | 7 |

Top fixes:
1. Fix Lighting, Atmosphere, and Skyboxes for Noon, Night, and Golden Hour: give Noon (03-dockend-noon.jpg, 08-stands-noon.jpg) a blue sky with soft clouds like 01-dock-dawn.jpg, higher Lighting.Brightness, crisp sun shadows, and lighter haze so the lake sparkles instead of looking overcast and flat; at Night (04-dockend-night.jpg) and Golden Hour (07-overview-golden.jpg), match Atmosphere.Color and Atmosphere.Decay to the Skybox horizon, adjust Atmosphere.Offset to remove the dark horizon band, and add stars and a moon to the night Sky.
2. Add warm practical lighting and shoreline dressing around the dock and stalls: give the dock lanterns and stall lamps warm PointLights with glowing glass so 02-dock-golden.jpg and 04-dockend-night.jpg feel alive and inviting, and break up the bare grass/dirt approach and blank stall backs in 01-dock-dawn.jpg and 02-dock-golden.jpg with leaning fishing rods, wooden crates, buckets, rocks, and small bushes.
3. Clean up shoreline edges, cattail placement, and signboards: move the dry-sand cattails on the left of 05-weedbed-golden.jpg slightly into the shallow water and sink their bases into the terrain; soften the patchy brown-to-green shoreline paint edges in 08-stands-noon.jpg with rocks and reeds; separate the overlapping green chalkboard and brown sign in 08-stands-noon.jpg and make daily lake info either much larger or an interactive pop-up so phone players can read it.

Strengths:
- Strong fishing-spot readability: the lily-pad weedbed (05-weedbed-golden.jpg), sunken logs cove (06-logs-dawn.jpg), bridge channel with buoy (03-dockend-noon.jpg), and central dock (07-overview-golden.jpg) all immediately tell a player where different fish might hold.
- Excellent Real-ish materials on the hero props, especially the weathered nailed dock planks, cut-log pilings, and metal cleat in 08-stands-noon.jpg, plus the mossy boulders and rippled wet sand in 05-weedbed-golden.jpg.
- Lovely calm atmosphere in the best lighting states: warm raking sunset light and shallow-water clarity in 05-weedbed-golden.jpg, soft purple morning mist in 06-logs-dawn.jpg, and glowing fireflies with the lit buoy reflection in 04-dockend-night.jpg.
- Clean, inviting lake composition in 01-dock-dawn.jpg and 07-overview-golden.jpg, with the bridge channel opening to a second body of water that builds curiosity.
- Crisp, high-contrast shop signage on the Bait and Tackle and Sell Fish stalls in 08-stands-noon.jpg that will read effortlessly on both desktop and small phones.

Broken or ugly:
- 04-dockend-night.jpg: A harsh dark-navy horizontal band sits directly behind the treeline below a noticeably brighter blue sky, caused by an Atmosphere and Skybox color mismatch.
- 07-overview-golden.jpg: A flat dark-grey sky band cuts sharply across the horizon right above the sunlit golden haze hills, and the sun glare in the top-left corner is overly large and blown out.
- 05-weedbed-golden.jpg: Several foreground cattails on the left grow out of dry sand with flat, visibly cut-off bases.
- 08-stands-noon.jpg: The green chalkboard overlaps and partially hides the brown signboard next to it, and its white text is too tiny to read from the dock or on a phone.
- 06-logs-dawn.jpg: A sharp, flat-looking pine branch pokes awkwardly into the top-right edge of the frame.

Action taken: (fill in: what we changed, or why we didn't)
