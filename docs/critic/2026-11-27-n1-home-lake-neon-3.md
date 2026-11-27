# Critic: n1-home-lake (review, gemini-4-neon)

Date: 2026-11-27 17:01. Rubric: `look`.

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

**Score: 6.5/10**

The main lake already has genuine charm and believable fishing spots: the weathered dock planks, golden-hour cattail cove, misty dawn timber, and firefly-lit night water feel calm, readable, and inviting. What holds the game back right now is a severe golden-hour light blowout in the aerial overview and a sharp drop in quality in the Cedar Creek, riffle, and pool areas, where flat-shaded low-poly rocks, smooth cone trees, and straight boxy terrain banks break the Real-ish material style.

| Point | Score |
|---|---|
| composition | 6.5 |
| light | 6.5 |
| water | 7 |
| mood | 7 |
| want_to_fish | 7 |
| phone_readability | 6.5 |
| broken_or_ugly | 5 |

Top fixes:
1. Fix the golden-hour light blowout and vertical glare seam in 07-overview-golden.jpg by lowering Atmosphere.Glare and Atmosphere.Density, reducing SunRaysEffect.Intensity and BloomEffect.Intensity, and removing or fixing whatever large transparent part or lighting boundary is creating the sharp vertical orange wall across the left side of the lake.
2. Bring the Cedar Creek riffle and pool areas (09-riffle-dawn.jpg, 10-pool-golden.jpg, 11-gate-noon.jpg, 12-pool-night.jpg) up to the main lake's material standard: replace the smooth flat-shaded boulder in 09 and the smooth cone/blob trees in 08, 09, and 11 with textured stone rocks (like 05-weedbed-golden.jpg) and matching textured conifers; use Terrain Smooth and Erode brushes to break up the straight rectangular pool banks (10, 12) and widen the trench-like riffle (09) with river cobbles and subtle whitewater ripples; straighten the tilted lamp post on the pool bank and disable CastShadow on its lamp housing to remove the sharp rectangular shadow box in 12-pool-night.jpg.
3. Dress the bare foreground approaches and clean up minor visual distractions: paint a worn dirt/gravel trail across the empty grass between the stalls in 01-dock-dawn.jpg and 02-dock-golden.jpg with small props (bench, tackle crate, grass tufts); clear the cattails blocking the chalkboard sign in 08-stands-noon.jpg and enlarge its text so it reads on a phone; swap the spiky star-burst firefly ParticleEmitter texture in 04-dockend-night.jpg and 12-pool-night.jpg for a smaller, soft round glow dot.

Strengths:
- Excellent Real-ish wood and stone materials on the main lake, especially the weathered dock planks, nail heads, log pilings, and cleat in 08-stands-noon.jpg and the mossy shoreline boulders in 05-weedbed-golden.jpg.
- Clear, purposeful fishing habitats that reward real fishing knowledge: the shallow cattail weedbed with lily pads (05-weedbed-golden.jpg), submerged fallen logs (06-logs-dawn.jpg), open-water buoy near the bridge channel (03-dockend-noon.jpg), and wooden boat slips.
- Strong dawn and golden-hour atmosphere on the main lake (01-dock-dawn.jpg, 02-dock-golden.jpg, 05-weedbed-golden.jpg) with soft distance haze, warm-cool sky contrast, and inviting water reflections.
- Chunky, high-contrast landmarks like the Bait and Tackle stall, Sell Fish stall, dock, and Cedar Creek archway (08-stands-noon.jpg, 11-gate-noon.jpg) that read clearly as silhouettes even when scaled down for a phone.

Broken or ugly:
- 07-overview-golden.jpg: Massive orange glare blowout and a hard vertical light seam cutting straight down through the left side of the lake, washing out half the scene.
- 10-pool-golden.jpg and 12-pool-night.jpg: The pool has unnatural razor-straight artificial banks and corners, and the brown lamp post on the right bank is awkwardly tilted (~20 degrees) while casting a hard boxy dark shadow patch on the sand at night.
- 09-riffle-dawn.jpg: Flat-shaded low-poly grey boulder and smooth cone pines clash sharply with the textured rocks and conifers on the main lake, and the riffle reads as a narrow straight drainage ditch rather than a natural stream.
- 08-stands-noon.jpg: Smooth low-poly green trees behind the Your Pond sign clash with the detailed pines elsewhere; cattails directly overlap and obscure the green chalkboard sign.
- 06-logs-dawn.jpg: A dark tree trunk and branch clip awkwardly into the far-left and top-right corners of the camera view, and the submerged logs end in abrupt flat cylinders.
- 04-dockend-night.jpg: Oversized spiky star-shaped firefly sprite in the lower-left foreground looks like a stock sparkle decal rather than a real firefly.

Action taken: (fill in: what we changed, or why we didn't)
