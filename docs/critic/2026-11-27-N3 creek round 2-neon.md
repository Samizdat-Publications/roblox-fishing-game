# Critic: N3 creek round 2 (review, gemini-4-neon)

Date: 2026-11-27 23:59. Rubric: `look`.

Files shown:
- `09-riffle-dawn.jpg`
- `10-pool-golden.jpg`
- `11-gate-noon.jpg`
- `12-pool-night.jpg`

**Score: 5.5/10**

The golden-hour pool and chunky pine tree assets show real promise for a cozy, Real-ish fishing world, but the scenes are currently held back by harsh noon lighting, an unlit night lantern, noisy opaque water that hides riverbed structure, bare shorelines, and blocked framing at the dawn riffle.

| Point | Score |
|---|---|
| composition | 5 |
| light | 5.5 |
| water | 5 |
| mood | 6 |
| want_to_fish | 5 |
| phone_readability | 5 |
| broken_or_ugly | 6 |

Top fixes:
1. Tune Terrain Water settings for clarity and calm readability: lower WaterWaveSize and WaterReflectance, raise WaterTransparency, and sculpt visible rocks/gravel on the riverbed below so the pool stops looking like marbled oil in 10-pool-golden.jpg or gray surface scum in 12-pool-night.jpg, letting players read depth and fish-holding structure.
2. Overhaul night and noon Lighting plus add real light to lanterns: place a warm amber PointLight (with Shadows enabled) inside the shore lantern in 12-pool-night.jpg so it lights the bank and water edge, gently lift night Ambient/moonlight so the far bank is readable on phones, and in 11-gate-noon.jpg mute Terrain Grass MaterialColor (less lime-green) while adding soft Atmosphere haze so midday stops looking flat and stock.
3. Open sightlines and dress the fishing banks with inviting props: in 09-riffle-dawn.jpg remove or shift the two foreground pines and widen the shallow cobble stream so players actually see a fishable riffle, and along the wide empty sandbank in 10-pool-golden.jpg and 12-pool-night.jpg break up the smooth slope with flat standing stones, a simple weathered wood dock or log seat, overhanging reeds, and shoreline shrubs.

Strengths:
- 10-pool-golden.jpg captures genuine evening mood, with warm sunbeams filtering through the pines and catching the bark and distant grass.
- The chunky pine trees across all four shots have believable bark and foliage textures that fit the Real-ish art direction well.
- 09-riffle-dawn.jpg has a pleasant, calm pastel pink-and-blue horizon haze and soft directional dawn light on the trunks.
- Details like the fallen log across the far bank of the pool and the faint fireflies in 12-pool-night.jpg are great touches that hint at real fishing structure and atmosphere.

Broken or ugly:
- 12-pool-night.jpg: The lantern on the right bank has a bright pale-yellow glass face but emits zero light onto its wooden post, the sandbank, or the water.
- 09-riffle-dawn.jpg: Two huge pine trunks fill the middle of the frame and block the view of the stream, leaving only a tiny sliver of water in the bottom-right corner.
- 10-pool-golden.jpg and 12-pool-night.jpg: Small isolated blobs of gray cobblestone terrain poke awkwardly out of the muddy far shore, and the wide right-hand sandbank looks overly smooth and bare (turning a flat snowy gray at night).
- 09-riffle-dawn.jpg: Patchy pale gray-white terrain bleeds through the green grass in the bottom-left corner.
- 11-gate-noon.jpg: Bright lime-green terrain grass clashes harshly against the dark pines, and the thin white 'Cedar Creek' sign lettering will be too small to read clearly on a phone screen.

Action taken: (fill in: what we changed, or why we didn't)
