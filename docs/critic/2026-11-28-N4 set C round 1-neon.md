# Critic: N4 set C round 1 (review, gemini-4-neon)

Date: 2026-11-28 05:51. Rubric: `look`.

Files shown:
- `c01-canoe-golden.jpg`
- `c02-slips-boathouse-noon.jpg`
- `c03-dinghy-wake-dawn.jpg`

**Score: 6.5/10**

The cozy Northwoods lake mood and Real-ish materials already shine - especially the weathered dock planks, cedar-strip canoe, rustic stalls, and soft dawn mist - making this a place you genuinely want to explore and fish. What holds it back right now are a few noticeable placement glitches (a clipping Boat slips sign, a hovering dinghy with a detached bow light), overly glossy oil-slick water reflections with little shallow-water clarity, and a flat noon lighting pass.

| Point | Score |
|---|---|
| composition | 6 |
| light | 7 |
| water | 6 |
| mood | 7 |
| want_to_fish | 7 |
| phone_readability | 6 |
| broken_or_ugly | 6 |

Top fixes:
1. Fix boat seating and clipping props: lower the orange dinghy in c03-dinghy-wake-dawn.jpg (and slightly settle the canoe in c01-canoe-golden.jpg) via buoyancy height or pivot offset so the hulls sit in the water instead of hovering above their reflections, weld the detached red bow light back onto the dinghy hull, and resize or reposition the Boat slips sign so the dock piling stops clipping across the word slips.
2. Tune Terrain Water for softer reflections and shallow clarity: lower WaterReflectance and slightly reduce WaterWaveSize to break up the dark, oil-slick reflection bands seen in c01 and c03, and raise WaterTransparency so players can read shallow sand, rocks, and depth drop-offs near the docks and shoreline.
3. Improve midday lighting and lakeside grounding in c02-slips-boathouse-noon.jpg: add subtle daytime Atmosphere density and haze to give depth to the distant hills, add a warm low-intensity PointLight or higher EnvironmentDiffuseScale inside the boathouse so it stops reading as a dark hole, and soften the abrupt sand-to-grass shoreline edge with extra rocks, drift logs, and shoreline weeds.

Strengths:
- The cedar-strip canoe (c01-canoe-golden.jpg, c02-slips-boathouse-noon.jpg) and weathered timber dock planks nail the Real-ish style with believable wood grain, warm highlights, and strong silhouettes.
- Golden hour (c01-canoe-golden.jpg) and dawn (c03-dinghy-wake-dawn.jpg) establish a memorable, peaceful lake atmosphere - especially the pale blue-pink haze separating the distant pine treeline in c03.
- World-building props like the Sell Fish and Bait and Tackle stalls, boathouse with oars and life ring, cattails, Trophy Wall, and Today on the Lake chalkboard directly support the fishing-knowledge theme.
- Chunky silhouettes for boats, stalls, pines, and pilings remain recognizable even when scaled down toward phone size.

Broken or ugly:
- In c01-canoe-golden.jpg and c03-dinghy-wake-dawn.jpg, a dark vertical dock piling clips directly across the front of the Boat slips sign, blocking the letter s in slips.
- In c03-dinghy-wake-dawn.jpg, the red navigation light on the bow of the orange dinghy is floating in mid-air detached from the boat.
- In c03-dinghy-wake-dawn.jpg, the orange dinghy hovers slightly above the water surface with a visible gap above its reflection and an outboard lower unit barely touching the water; the canoe bow in c01-canoe-golden.jpg also feels perched high with no waterline contact.
- In c03-dinghy-wake-dawn.jpg, the far-right bridge reads as unfinished skeletal rails compared to the solid timber docks and boathouse.
- In c02-slips-boathouse-noon.jpg, an interior boathouse sign reading BO... is awkwardly cut off behind the doorframe, and the grass-to-sand terrain transitions look abruptly blotchy.

Action taken: (fill in: what we changed, or why we didn't)
