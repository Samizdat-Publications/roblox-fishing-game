# Critic: baseline-l0 (review, gemini-4-neon)

Date: 2026-11-26 16:09. Rubric: `look`.

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

**Score: 2.5/10**

This is a clear functional greybox with smart fishing-spot ideas (weedbed, sunken logs, deep hole, creek riffle and pool), but right now it reads like a flat prototype on a square baseplate rather than a calm, inviting place to fish. The biggest issues holding it back are lifeless grey/black water, mis-timed and flat lighting (golden hour looks like night and dawn looks like noon), floating geometry in Cedar Creek, and shop signs clipping into buildings.

| Point | Score |
|---|---|
| composition | 3 |
| light | 2 |
| water | 1 |
| mood | 2 |
| want_to_fish | 3 |
| phone_readability | 3 |
| broken_or_ugly | 2 |

Top fixes:
1. Replace the flat grey pond surface, floating dark-blue deep-spot slab (03-dockend-noon.jpg), and floating riffle plank (09-riffle-dawn.jpg) with styled translucent blue-green water over a sloped lakebed (using either Roblox Terrain Water with subtle WaveSize/Reflectance or layered semi-transparent stylized water parts), seal the gaps in Cedar Creek, and break up the sharp 90-degree grass walls with sloped banks and shoreline rocks.
2. Create distinct Lighting and Atmosphere presets with correct ClockTime values so dawn (~6:15) and golden hour (~17:45) actually have warm low-angle sunlight and haze instead of midday blue (01, 06, 09) or dark starry night (02, 05, 07, 10), add cool moonlight OutdoorAmbient so night shots (05, 10, 12) remain readable on a phone, and turn off the harsh dock and stall PointLights during daylight (01, 03, 06).
3. Fix all BillboardGuis by raising their StudsOffset above roofs and posts so they stop clipping through stands and walls (01, 07, 08, 11) and setting MaxDistance (around 45 to 60 studs) so distant labels stop piling on top of each other (06-logs-dawn.jpg), then ring the map perimeter with chunky low-poly hills and tree lines to hide the bare horizon and floating baseplate edges (03, 07, 09).

Strengths:
- Clear gameplay layout with distinct, readable fishing habitats (dock, weedbed, sunken logs, deep spot, creek riffle and pool) that fit a real-knowledge fishing game.
- The chunky wooden dock planks and the blue-and-white striped Bait and Tackle stand in 08-stands-noon.jpg already show charming low-poly character.
- Looking down the dock between the two stands in 01-dock-dawn.jpg creates a simple, logical focal point toward the water.

Broken or ugly:
- 09-riffle-dawn.jpg: The blue creek water slab is floating in mid-air over an empty gap at the foreground drop-off, and there is a white skybox hole visible at the far end of the creek.
- 03-dockend-noon.jpg and 04-dockend-night.jpg: The deep-water spot is a sharp, flat dark-blue rectangle that looks like a floating mat sitting on top of beige concrete.
- 01-dock-dawn.jpg, 02-dock-golden.jpg, 07-overview-golden.jpg, 08-stands-noon.jpg, and 11-gate-noon.jpg: BillboardGuis for Sell Fish, Bait and Tackle, Your Pond, and Cedar Creek clip directly into wooden posts, canopies, and walls.
- 06-logs-dawn.jpg: Multiple distant BillboardGuis stack and overlap into an unreadable jumble across the horizon.
- 07-overview-golden.jpg and 09-riffle-dawn.jpg: The flat square edge of the world drops straight off into empty void.
- 10-pool-golden.jpg: A strange purple border/gap runs along the waterline against the vertical grass walls, and the pool itself is pitch black.
- 01-dock-dawn.jpg, 03-dockend-noon.jpg, and 06-logs-dawn.jpg: Dock lantern PointLights stay on at full brightness during the day, casting harsh yellow blobs on the water.
- 02-dock-golden.jpg, 05-weedbed-golden.jpg, 07-overview-golden.jpg, and 10-pool-golden.jpg: Golden hour shots are pinned to nighttime/late dusk with stars and a giant moon instead of golden-hour sunlight.

Action taken: (fill in: what we changed, or why we didn't)
