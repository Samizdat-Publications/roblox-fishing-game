# Critic: N3 Pass 1 creek (review, gemini-4-neon)

Date: 2026-11-28 02:07. Rubric: `look`.

Files shown:
- `09-riffle-dawn.jpg`
- `10-pool-golden.jpg`
- `11-gate-noon.jpg`
- `12-pool-night.jpg`

**Score: 6/10**

Cedar Creek already has a memorable woodland identity - especially the night pool with fireflies and lantern light - and strong fishing-spot framing. What holds it back right now are a few glaring visual snags: hard-edged rectangular whitewater tiles in the dawn riffle, overly dark crushed shadows across most shots (which will hurt phone readability), and a row of identical bulbous-tipped trees along the pool horizon.

| Point | Score |
|---|---|
| composition | 7 |
| light | 6 |
| water | 5 |
| mood | 7 |
| want_to_fish | 6 |
| phone_readability | 5 |
| broken_or_ugly | 4 |

Top fixes:
1. Fix the riffle whitewater in 09-riffle-dawn.jpg: remove the hard-edged rectangular ripple decals/parts sitting on the creek and replace them with feathered, soft-edged foam ParticleEmitters or tapered Beams hugging the stream boulders over continuous Roblox Terrain Water.
2. Lift crushed shadow lighting and tame the night bank colour: increase Lighting.OutdoorAmbient and Lighting.EnvironmentDiffuseScale (plus a gentle dawn/night Atmosphere haze) so the riffle banks in 09-riffle-dawn.jpg and far treeline in 10-pool-golden.jpg and 12-pool-night.jpg stay readable on phones; in 12-pool-night.jpg, darken the sand/dirt terrain colour and soften the lantern PointLight brightness so the right path stops blowing out to stark white snow.
3. Replace the repeating bulbous-tipped trees along the far bank in 10-pool-golden.jpg and unify ground detail: swap out those crooked knob-topped tree meshes (or mix in the cleaner conifers from 11-gate-noon.jpg with varied heights, Y-rotations, and spacing) and spread Terrain.Decoration grass more evenly along the foreground of 11-gate-noon.jpg to cover the blurry bare grass texture.

Strengths:
- Strong atmosphere in 12-pool-night.jpg: the warm lantern glow hitting the cattails and ripples, soft fireflies over the dark water, and moody sky create a cozy, memorable spot you actually want to fish.
- Clear fishing-spot composition in 10-pool-golden.jpg and 12-pool-night.jpg, with an open right bank to cast from, reeds framing the shoreline, and a fallen log across the back that naturally reads as fish cover.
- Crisp, readable landmark in 11-gate-noon.jpg: the wooden Cedar Creek gate has solid wood-bark materials and high-contrast lettering that stays legible at small sizes.
- Inviting golden-hour sky and water reflections in 10-pool-golden.jpg, with sunlight breaking through the left trees and glancing across the pool.

Broken or ugly:
- 09-riffle-dawn.jpg: obvious rectangular whitewater tiles/decals with straight hard box edges overlapping down the middle and bottom-right of the stream.
- 10-pool-golden.jpg: a picket-fence row of identical pine trees along the far shoreline with awkward, crooked bulbous tips sticking up against the sky.
- 12-pool-night.jpg: the dirt path on the right bank turns stark white and snow-like under the lantern and night lighting.
- 11-gate-noon.jpg: inconsistent tree styles between the sharp-tiered gate conifers and the rounded pool pines, plus blurry flat green terrain next to one isolated tuft of 3D grass in the bottom-left.

Action taken: (fill in: what we changed, or why we didn't)
