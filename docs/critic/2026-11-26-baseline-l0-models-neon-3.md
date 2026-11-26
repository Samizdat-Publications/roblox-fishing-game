# Critic: baseline-l0-models (review, gemini-4-neon)

Date: 2026-11-26 17:41. Rubric: `look`.

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

**Score: 3.5/10**

A clear step up from the misaligned gray-box baseline: the 32 chunky low-poly models sit cleanly on the real lake, and the layout already reads as a real fishing game with distinct spots (dock, buoy, cattail weedbed, sunken logs, creek riffle, and pool). Right now, though, the map still looks like a flat rectangular swimming pool floating in a void, floating text labels clip through buildings and pile up across the lake, the riffle ends in an open floating water block, and the unlit baseline lighting turns golden hour into starry night with harsh glowing-pool dock lights.

| Point | Score |
|---|---|
| composition | 4 |
| light | 2.5 |
| water | 3 |
| mood | 3 |
| want_to_fish | 4 |
| phone_readability | 3 |
| broken_or_ugly | 3 |

Top fixes:
1. Break up the rectangular swimming-pool edges and empty horizon: use Roblox Terrain Sculpt/Smooth to curve the lake and Cedar Creek shorelines into natural slopes, add a layered treeline and low hills around the far bank and outer map edges so the world does not end in a flat void (03-dockend-noon.jpg, 07-overview-golden.jpg), and close off the broken trench end of the creek in 09-riffle-dawn.jpg with sloped terrain and boulders.
2. Fix every clipping and overlapping sign: move 'Sell Fish' and 'Bait and Tackle' onto SurfaceGuis mounted directly on the blank wooden roof signboards already built on the stands (08-stands-noon.jpg), raise 'Cedar Creek' above a proper wooden archway or fence instead of clipping into the solid plank wall (11-gate-noon.jpg), and set BillboardGui.MaxDistance to around 50 studs so labels stop stacking into unreadable clutter across the lake (06-logs-dawn.jpg).
3. Tune Lighting, Atmosphere, Water, and PointLights for L5: set the golden-hour ClockTime earlier (around 17.5 to 18.0 instead of starry night in 02, 05, 07, and 10), add an Atmosphere with warm dawn/dusk haze and a cloudy Sky, shift Terrain.WaterColor to a deeper muted lake green-blue, and lower the dock lantern PointLight Range (around 18 studs) with a warm amber color so they stop bleaching half the lake into a bright cyan disc (02, 04, 05, 07).

Strengths:
- The chunky low-poly props have real charm and clear silhouettes that fit the target art style: the staggered dock planks and posts, striped market awnings with the gold fish roof ornament, rod rack, stone-rimmed Your Pond (08-stands-noon.jpg), cattail clumps with red lily pads (05-weedbed-golden.jpg), and sunken logs (06-logs-dawn.jpg) all read cleanly.
- The framing from between the two stands straight down the dock to the water (01-dock-dawn.jpg) and looking back from the dock at the shopfront row (08-stands-noon.jpg) gives a strong, welcoming home-base layout.
- Distinct fishing habitats are already readable in the scene (weedbed in 05, timber logs in 06, open buoy water in 03, creek riffle and pool in 09 and 10), which directly supports the game's core idea of reading spots.

Broken or ugly:
- 09-riffle-dawn.jpg: At the bottom-left end of the creek trench, the terrain water terminates in a hanging translucent cube floating over a flat gray void beneath a hovering rock ledge.
- 08-stands-noon.jpg, 07-overview-golden.jpg, 01-dock-dawn.jpg, and 11-gate-noon.jpg: BillboardGui labels sit inside 3D geometry, slicing through the stand pillars and awnings ('B a t and Ta ckle', 'S ell Fis h') and getting hidden behind the Cedar Creek wall and lamppost orb.
- 06-logs-dawn.jpg: Without MaxDistance limits, the far-side BillboardGuis stack on top of each other ('Your Pond', 'Tackle', 'sh', 'Cedar Creek') into unreadable text soup.
- 02-dock-golden.jpg, 05-weedbed-golden.jpg, 07-overview-golden.jpg, and 10-pool-golden.jpg: The 'golden' time preset is actually night/late twilight with stars and a giant moon, and the dock lamps cast an unnatural, harsh pale-cyan circular glow across half the lake (also severe in 04-dockend-night.jpg).
- 07-overview-golden.jpg: The flat square map abruptly drops off into an empty dark void on all sides.
- 11-gate-noon.jpg: The Cedar Creek divider is a tall, solid fortress-like plank wall with an uneven gap and mismatched posts rather than a rustic lakeside fence or trailhead gate.

Action taken: recorded as the L0 baseline with all 32 models in, on the real lake (sheet `docs/critic/2026-11-26-baseline-l0-models-sheet.jpg`). Nothing changed for it: shoreline shape, sealing the riffle's open end, the sign clipping and stacking, time-of-day light, water colour and lamp light are L5 (postcard lake) work in `docs/superpowers/plans/2026-11-26-next-leg.md`.
