# Critic: baseline-l0-models (review, gemini-4-neon)

Date: 2026-11-26 17:38. Rubric: `look`.

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

**Score: 3.0/10**

Everything is now properly seated on the real lake and the chunky low-poly models (dock, stalls, cattails, sunken logs) clearly communicate real fishing spots. However, the lake and creek still read like ruler-straight rectangular swimming pools cut into a floating grass slab, the 3D floating signs clip through buildings and pile on top of each other, the creek riffle spills off the map into the void, and the time-of-day presets and dock lights look harsh and unnatural ahead of your L5 lighting pass.

| Point | Score |
|---|---|
| composition | 3.5 |
| light | 2.0 |
| water | 2.5 |
| mood | 2.5 |
| want_to_fish | 3.5 |
| phone_readability | 3.0 |
| broken_or_ugly | 2.5 |

Top fixes:
1. Break the 90-degree swimming-pool banks and seal the map edges: use Roblox Terrain Grow/Erode/Smooth brushes to carve natural curves and gentle slopes along the lake and Cedar Creek shorelines (03, 07, 10), block off the open end of the riffle ditch in 09-riffle-dawn.jpg so water does not dangle over the void, and rim the far bank with low-poly hills and clustered trees instead of two identical lone trees.
2. Fix the clipping, overlapping BillboardGui labels: set MaxDistance to around 45-60 studs so distant signs stop mashing together across the water (06-logs-dawn.jpg), and either raise StudsOffset above the roofs and gate or replace them with SurfaceGuis mounted directly on the empty signboards already built on top of the stalls (08-stands-noon.jpg, 11-gate-noon.jpg).
3. Fix time-of-day presets, water colour, and lantern light pools for L5: adjust dawn (01, 06) and golden hour (02, 05, 10) ClockTime so dawn is not midday and golden hour is not purple night (try roughly 6.2 and 17.7 with a warm Atmosphere object), shift Terrain.WaterColor from bright pool cyan to a deeper lake green-blue, and dial down the dock PointLight Range/Brightness with a warm amber tint so it stops blowing out a giant circular spotlight on the water (02, 04, 07).

Strengths:
- Chunky low-poly prop craft is charming and phone-friendly: the staggered dock planks, striped Bait and Sell Fish stalls, rock-ringed pond, cattail clumps, and half-submerged logs all read cleanly at a glance (08-stands-noon.jpg, 05-weedbed-golden.jpg, 06-logs-dawn.jpg).
- Clear fishing-spot variety: players can already read distinct habitats to cast toward - weed bed, sunken logs, open-water buoy, and creek riffle - which supports the game's core fishing-knowledge loop.
- Good arrival framing in 01-dock-dawn.jpg and 08-stands-noon.jpg: walking between the two stalls straight onto the dock creates a welcoming, intuitive hub layout.

Broken or ugly:
- 09-riffle-dawn.jpg: The straight creek trench runs straight off the edge of the terrain, leaving a floating blue water block and stone ledge hanging over the gray void.
- 08-stands-noon.jpg and 11-gate-noon.jpg: BillboardGui signs clip straight through stall awnings, support posts, the Cedar Creek wall ('C-dar Creek'), and a lamppost bulb.
- 06-logs-dawn.jpg: Distance-unclamped BillboardGuis ('Your Pond', 'Bait and Tackle', 'Sell Fish', 'Cedar Creek') overlap into an unreadable pile on the left side of the screen.
- 03-dockend-noon.jpg: A straight horizontal seam/band is visible across the foreground water surface.
- 02-dock-golden.jpg, 04-dockend-night.jpg, 05-weedbed-golden.jpg, and 07-overview-golden.jpg: Dock and stall PointLights project harsh, circular swimming-pool light discs onto the water and grass.
- 01-dock-dawn.jpg, 02-dock-golden.jpg, 05-weedbed-golden.jpg, 06-logs-dawn.jpg, 09-riffle-dawn.jpg, and 10-pool-golden.jpg: Dawn shots look like bright flat noon while golden-hour shots are already dark purple night.
- 07-overview-golden.jpg: The entire world reads as a floating rectangular grass slab with sharp drop-offs into empty void.

Action taken: recorded as the L0 baseline with all 32 models in, on the real lake (sheet `docs/critic/2026-11-26-baseline-l0-models-sheet.jpg`). Nothing changed for it: shoreline shape, sealing the riffle's open end, the sign clipping and stacking, time-of-day light, water colour and lamp light are L5 (postcard lake) work in `docs/superpowers/plans/2026-11-26-next-leg.md`.
