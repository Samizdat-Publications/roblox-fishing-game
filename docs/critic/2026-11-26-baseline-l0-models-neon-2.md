# Critic: baseline-l0-models (review, gemini-4-neon)

Date: 2026-11-26 17:39. Rubric: `look`.

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

Aligning the lake with its terrain water and bringing in all 32 chunky low-poly models gives the game a real, readable layout with distinct fishing spots (dock, weedbed, sunken logs, deep buoy, creek). However, because the terrain is still cut as flat 90-degree rectangles over an empty horizon, the 3D labels clip through structures and pile up at a distance, and lighting/water are still unstyled defaults (with golden hour currently looking like deep night), the scene reads as an early gray-box test map rather than a calm lakeside you want to sit beside.

| Point | Score |
|---|---|
| composition | 4 |
| light | 2 |
| water | 2.5 |
| mood | 2.5 |
| want_to_fish | 3.5 |
| phone_readability | 3.5 |
| broken_or_ugly | 3 |

Top fixes:
1. Replace the ruler-straight 90-degree lake and creek edges with sculpted, gently sloped Terrain banks, shoreline rocks, and a closed-off creek end (fixing the exposed water cut-off in 09-riffle-dawn.jpg), and ring the outer map with low-poly hills and clustered trees so the flat square world edge and empty two-tree horizon disappear (01, 03, 07).
2. Fix all BillboardGui labels by mounting Sell Fish and Bait and Tackle as SurfaceGuis on the signboards already built atop the stalls (or raising them cleanly above the roofs/wall), switching their Size from pixel Offset to world-space Studs, and setting MaxDistance around 45-60 studs so they stop clipping through posts/walls (08, 11) and stacking into an unreadable jumble across the lake (06, 07).
3. Configure real time-of-day Lighting and Atmosphere: move dawn and golden hour ClockTime to true low-sun angles (currently dawn looks like flat noon in 01/06 and golden hour is dark purple night in 02/05/10), enable GlobalShadows with horizon haze, darken and soften Terrain WaterColor/WaterReflectance out of swimming-pool cyan, and lower the dock PointLight range/brightness with warm amber tint to remove the glowing cyan discs on the water (02, 04, 05, 07).

Strengths:
- The chunky low-poly models have a cohesive, charming look that will read cleanly on phones - especially the striped Sell Fish and Bait and Tackle stalls with the little gold fish and rod rack (08-stands-noon.jpg), the wooden dock, and the stone-rimmed Your Pond.
- Distinct fishing spots are already legible from the shoreline: the cattail and lily-pad weedbed (05-weedbed-golden.jpg), sunken logs (06-logs-dawn.jpg), central red-and-white buoy (03-dockend-noon.jpg), and creek riffle/pool clearly signal where different fish might live.
- Framing the dock straight between the two shops in 01-dock-dawn.jpg and looking back toward the stalls from the dock in 08-stands-noon.jpg gives players an intuitive home base and clear sightline to the water.

Broken or ugly:
- In 09-riffle-dawn.jpg, the foreground end of Cedar Creek is cut open to the void, exposing the raw transparent block of Roblox terrain water hanging under a floating rocky slab.
- In 08-stands-noon.jpg, 07-overview-golden.jpg, and 11-gate-noon.jpg, the BillboardGui text for Bait and Tackle, Sell Fish, and Cedar Creek clips straight through the wooden stall posts and the Cedar Creek plank wall (and the white lamp orb overlaps the letter k in 11-gate-noon.jpg).
- In 06-logs-dawn.jpg, the distant pixel-sized BillboardGuis stay huge and stack on top of one another into unreadable overlapping text ('our Pond | Tacklesh').
- In 02-dock-golden.jpg, 05-weedbed-golden.jpg, 07-overview-golden.jpg, and 10-pool-golden.jpg, the 'golden' time preset is actually dark purple night with stars and a giant moon instead of golden hour, while 'dawn' (01, 06, 09) looks like midday noon.
- In 02-dock-golden.jpg, 04-dockend-night.jpg, 05-weedbed-golden.jpg, and 07-overview-golden.jpg, the dock lantern PointLights paint harsh, glowing pale-cyan discs onto the water, and the stall lights cast hard yellow circles on the grass.
- In 03-dockend-noon.jpg, a sharp horizontal seam/color band cuts across the middle of the lake water.
- In 07-overview-golden.jpg and 09-riffle-dawn.jpg, the flat square edges of the map end abruptly against an empty void, and in 11-gate-noon.jpg the Cedar Creek entrance is a plain flat plank wall with a raw rectangular gap.

Action taken: recorded as the L0 baseline with all 32 models in, on the real lake (sheet `docs/critic/2026-11-26-baseline-l0-models-sheet.jpg`). Nothing changed for it: shoreline shape, sealing the riffle's open end, the sign clipping and stacking, time-of-day light, water colour and lamp light are L5 (postcard lake) work in `docs/superpowers/plans/2026-11-26-next-leg.md`.
