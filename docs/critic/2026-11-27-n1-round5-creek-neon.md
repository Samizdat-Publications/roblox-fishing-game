# Critic: n1-round5-creek (review, gemini-4-neon)

Date: 2026-11-27 20:08. Rubric: `look`.

Files shown:
- `09-riffle-dawn.jpg`
- `10-pool-golden.jpg`
- `11-gate-noon.jpg`
- `12-pool-night.jpg`

**Score: 5.5/10**

The game already has genuine calm, rural charm - especially the golden-hour pool and the firefly-lit night bank - but blotchy water reflections, an overly dark noon lighting preset, and sparse, trench-like shorelines keep it from feeling like a believable, fishable creek yet.

| Point | Score |
|---|---|
| composition | 6 |
| light | 5.5 |
| water | 4 |
| mood | 6.5 |
| want_to_fish | 5.5 |
| phone_readability | 6.5 |
| broken_or_ugly | 5 |

Top fixes:
1. Fix the water surface artifacts and widen the riffle: increase water depth and tune Terrain.WaterTransparency, WaterReflectance, WaterWaveSize, and WaterWaveSpeed to eliminate the flat grey and oil-slick reflection blotches visible in 10-pool-golden.jpg and 12-pool-night.jpg; widen the stream in 09-riffle-dawn.jpg from a steep narrow trench into a broader cobble-and-gravel riffle with river rocks and subtle foam/ripple particles.
2. Overhaul the noon lighting preset and smooth the night horizon: in 11-gate-noon.jpg, raise Lighting.Brightness, lift OutdoorAmbient so the pine trees stop crushing to black, and use a bright daylight Skybox with crisp directional shadows; in 12-pool-night.jpg, soften Atmosphere.Haze and Decay/Color so the dark horizontal band along the skyline disappears.
3. Add real fishing structure and shoreline transition props: break up the bare flat far bank in 10-pool-golden.jpg and 12-pool-night.jpg and the empty green foreground bank in 09-riffle-dawn.jpg with gravel bars, half-submerged boulders, fallen logs, lily pads, overhanging trees, and mixed shore materials (pebbles, wet mud, reeds) so players can visually read where fish hold.

Strengths:
- Strong golden-hour and night atmosphere in 10-pool-golden.jpg and 12-pool-night.jpg, with warm sun reflections, a glowing rustic lantern on the sandy bank, and gentle fireflies over the water.
- Soft lavender-blue dawn mist in 09-riffle-dawn.jpg creates a peaceful early-morning mood and gives the rocky pine hillock a nice layered silhouette.
- Clean, readable shapes (pines, cattails, wooden gate, lantern posts) fit the Real-ish style well without noisy clutter, making the overall world silhouette easy to read on both desktop and phone.

Broken or ugly:
- Large flat, hard-edged grey reflection blobs on the water in 12-pool-night.jpg that read like ice patches rather than dark night water, plus mottled oil-slick blotches on the left side of 10-pool-golden.jpg and inside the stream in 09-riffle-dawn.jpg.
- 11-gate-noon.jpg does not read as noon at all - it is dark, overcast, and gloomy with nearly pitch-black pine foliage and missing midday shadows.
- Harsh dark blue horizontal band sitting along the horizon behind the hills in 12-pool-night.jpg.
- Steep, jagged voxel-looking bank cuts with dark shadow seams along the far edge of the pool (10-pool-golden.jpg, 12-pool-night.jpg) and a sharp bare-grass-to-tall-grass seam in the foreground of 09-riffle-dawn.jpg.
- The Cedar Creek wooden sign in 11-gate-noon.jpg has small, low-contrast serif lettering that will be hard to read on a phone screen.

Action taken: (fill in: what we changed, or why we didn't)
