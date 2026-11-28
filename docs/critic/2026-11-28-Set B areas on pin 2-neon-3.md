# Critic: Set B areas on pin 2 (review, gemini-4-neon)

Date: 2026-11-28 03:39. Rubric: `look`.

Files shown:
- `b01-bridge-dawn.jpg`
- `b02-basin-boat-noon.jpg`
- `b03-lighthouse-golden.jpg`
- `b04-buoys-dusk.jpg`
- `b05-bluewater-noon.jpg`
- `b06-marina-night.jpg`

**Score: 5.5/10**

The lake already shows promising Real-ish bones - especially the golden-hour reed island in b03 and the misty channel framing in b01 - with chunky trees and lily pads that genuinely feel like fishable cover. However, the scene is held back by harsh default noon lighting, pitch-dark night and dusk shots that lose readability, blotchy Roblox water reflections, bare shorelines, and obvious placeholder geometry like plain orange cylinder buoys and floating bridge rails.

| Point | Score |
|---|---|
| composition | 6 |
| light | 5 |
| water | 5 |
| mood | 5.5 |
| want_to_fish | 6 |
| phone_readability | 5 |
| broken_or_ugly | 4 |

Top fixes:
1. Fix Lighting and Atmosphere across times of day (especially b04, b06, and b01): raise Lighting.OutdoorAmbient and Lighting.Ambient at night/dusk to a readable cool slate-blue so trees and water do not crush to pure black on phones, add a warm horizon Atmosphere.Decay gradient for dusk and dawn, and place warm PointLight lanterns on the bridge, shoreline, and marina docks so night spots feel cozy and legible.
2. Replace placeholder props and finish the bridge (b01, b02, b04, b05): swap the plain smooth orange cylinder buoys for proper multi-part buoy models with weathered paint, a white reflective band, metal hardware, and a small blinking light at night; on the b01 bridge, add vertical railing posts connecting the floating top rails to the deck, add WoodPlanks material detail and ramp rails, and soften the boxy straight canal banks with rocks and boulders.
3. Tune Terrain Water settings and break up empty shorelines (b01–b06): reduce Terrain.WaterReflectance and gently dial back WaterWaveSize so reflections stop forming harsh dark oil-slick contour blotches in b01, b03, b04, and b06, and dress the uniform sand strip and smooth bare hills in b02 and b05 with rock clusters, fallen logs, varied shrub sizes, and denser layered tree backdrops instead of evenly dotted reed tufts.

Strengths:
- Chunky pine and birch trees, cattails, and pink-flowered lily pads (b01, b03) fit the Real-ish style well and create believable fish-holding cover that makes a player want to cast near the edges.
- Golden hour in b03-lighthouse-golden.jpg has genuine mood, with warm sun peeking through the island trees, nice rim light along the left grassy hill, and sparkling water highlights.
- b01-bridge-dawn.jpg has strong composition with a clear leading line down the canal under the bridge into a misty, layered distant lake.
- Shallow sandy transitions near the beach in b02-basin-boat-noon.jpg and b05-bluewater-noon.jpg give the water pleasant clarity near shore.

Broken or ugly:
- b01-bridge-dawn.jpg: The bridge railings are two thin horizontal bars floating above the deck with no vertical posts along the main span and an awkward disconnect at the right post; the canal banks also look unnaturally squared-off with blocky brown end boards.
- b02-basin-boat-noon.jpg, b04-buoys-dusk.jpg, b05-bluewater-noon.jpg: The buoys are plain untextured orange cylinders that look like temporary dev blocks, and in b04 they read as flat glowing orange against pitch-black water.
- b04-buoys-dusk.jpg and b06-marina-night.jpg: Both scenes are far too dark to read cleanly (especially on a phone screen), with crushed near-black water and noisy high-contrast specular swirls.
- b03-lighthouse-golden.jpg and b06-marina-night.jpg: Neither shot shows its namesake landmark clearly - b03 is blocked dead-center by a dark clump of reeds with no lighthouse visible, and b06 shows dark trees and empty water with no readable foreground marina or docks.

Action taken: (fill in: what we changed, or why we didn't)
