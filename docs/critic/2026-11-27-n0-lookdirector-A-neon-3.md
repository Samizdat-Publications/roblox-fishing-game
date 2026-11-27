# Critic: n0-lookdirector-A (review, gemini-4-neon)

Date: 2026-11-27 15:28. Rubric: `look`.

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

A genuinely promising lakeside fishing world whose dawn and golden-hour views (especially the weedbed in 05-weedbed-golden.jpg and the dock in 02-dock-golden.jpg) already spark the urge to cast a line. What holds it back from its Real-ish vision is a material clash (SmoothPlastic dock planks, stalls, logs, and boulders sitting next to textured terrain), ruler-straight rectangular shorelines exposed in 07-overview-golden.jpg and 10-pool-golden.jpg, floating BillboardGui label clutter, and a few lighting and path-seam rough edges.

| Point | Score |
|---|---|
| composition | 6 |
| light | 6 |
| water | 7 |
| mood | 6 |
| want_to_fish | 7 |
| phone_readability | 5 |
| broken_or_ugly | 5 |

Top fixes:
1. Upgrade SmoothPlastic props to real materials and flush out the paths: switch the dock planks, pilings, stalls (08-stands-noon.jpg), and submerged logs (06-logs-dawn.jpg) to WoodPlanks/Wood (or a weathered bark MaterialVariant), and set the creek and pool boulders (09-riffle-dawn.jpg, 10-pool-golden.jpg) to Rock/Slate so wood reads as wood and stone as stone. Replace the floating segmented path slabs in 06-logs-dawn.jpg and flatten the raised sand mound in 11-gate-noon.jpg using Terrain Paint and Smooth so walkways sit flush with the grass.
2. Replace floating BillboardGui pills with diegetic signs and clear blocked boards: remove the oversized dark-pill BillboardGuis on Sell Fish, Bait and Tackle, Cedar Creek, Boat slips, and Slip 2/3/4 that clip off-screen in 01-dock-dawn.jpg and clutter 08-stands-noon.jpg. Put SurfaceGui text directly onto the Cedar Creek arch beam and stall eaves, paint small slip numbers on the dock posts (relying on ProximityPrompts when close), and pull the cattails away from the green chalkboard and trophy board in 08-stands-noon.jpg so both are unobstructed.
3. Break up the rectangular shorelines and tune Lighting and night particles: use Terrain Add/Erode to curve the straight, pool-like banks of the main lake (07-overview-golden.jpg) and side pool (10-pool-golden.jpg) into natural coves and points. In Lighting, dial down golden-hour Bloom.Intensity and Atmosphere.Glare so 07-overview-golden.jpg and 10-pool-golden.jpg stop blowing out, add subtle Atmosphere.Density (~0.25) at noon so 03-dockend-noon.jpg and 08-stands-noon.jpg have aerial depth, script lampposts to turn off their Neon/PointLight during daytime (08-stands-noon.jpg, 11-gate-noon.jpg), and replace the giant starburst firefly ParticleEmitter in 04-dockend-night.jpg with small, soft warm-yellow glowing dots.

Strengths:
- Clear, purposeful fishing structure across spots: the cattails and lily pads in 05-weedbed-golden.jpg, submerged logs in 06-logs-dawn.jpg, bridge channel in 03-dockend-noon.jpg, and secluded pool in 10-pool-golden.jpg immediately suggest different fish and tactics.
- Strong dawn and golden-hour atmosphere in 01-dock-dawn.jpg, 02-dock-golden.jpg, and 05-weedbed-golden.jpg, where soft pastel and amber horizon haze reflects warmly across the rippled terrain water.
- Good framing from the main shore toward the water: looking down the dock toward the distant bridge and hills in 01-dock-dawn.jpg and 02-dock-golden.jpg creates an inviting focal line.
- The Cedar Creek wooden arch and fence in 11-gate-noon.jpg show proper wood grain, proving the chunky Real-ish material style works well when applied.

Broken or ugly:
- In 06-logs-dawn.jpg, the curved sandy path is built from flat parts sitting on top of the grass terrain, leaving an obvious thick segmented lip sticking up along the foreground edge.
- In 08-stands-noon.jpg, cattails grow directly in front of the green chalkboard sign, obscuring its text, and the brown fish board behind it is partially blocked.
- In 08-stands-noon.jpg and 11-gate-noon.jpg, the white neon lamppost bulbs are switched on during bright noon daylight.
- In 01-dock-dawn.jpg and 02-dock-golden.jpg, the oversized BillboardGui labels for Sell Fish and Bait and Tackle clip off the left and right edges of the screen.
- In 11-gate-noon.jpg, the terrain sand path bulges into a raised, pillowy ridge above the surrounding grass rather than sitting level.
- In 04-dockend-night.jpg, the firefly particle sprite near the camera on the right and left renders as a huge, jarring green starburst.
- In 07-overview-golden.jpg and 10-pool-golden.jpg, golden-hour bloom and glare wash out the upper sky and distant hills into an overexposed yellow-white haze.

Action taken: (fill in: what we changed, or why we didn't)
