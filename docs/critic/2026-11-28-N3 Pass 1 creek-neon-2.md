# Critic: N3 Pass 1 creek (review, gemini-4-neon)

Date: 2026-11-28 02:07. Rubric: `look`.

Files shown:
- `09-riffle-dawn.jpg`
- `10-pool-golden.jpg`
- `11-gate-noon.jpg`
- `12-pool-night.jpg`

**Score: 5.5/10**

Cedar Creek already has real charm and genuine night-fishing atmosphere - especially the firefly-lit pool and the welcoming wooden gate - but two glaring visual issues (hard-edged rectangular foam tiles on the dawn creek and a copy-pasted wall of knobby-topped pines behind the pool) plus heavily crushed dark shadows hold the scenes back, especially for phone readability.

| Point | Score |
|---|---|
| composition | 7 |
| light | 5 |
| water | 4 |
| mood | 7 |
| want_to_fish | 6 |
| phone_readability | 5 |
| broken_or_ugly | 4 |

Top fixes:
1. Replace the rectangular white-water foam tiles in 09-riffle-dawn.jpg with soft, alpha-feathered Beams or ParticleEmitters around the rocks (plus tuned Terrain water wave/flow settings) so no hard 90-degree texture edges appear on the stream.
2. Lift crushed shadows across all Lighting presets by raising OutdoorAmbient, Ambient, and EnvironmentDiffuseScale (with warm dawn/golden Atmosphere haze and ColorShift_Top) so tree trunks, banks, and creek rocks stay readable on desktop and small phones; at night (12-pool-night.jpg), dim and warm the lantern light so the sand path does not blow out to stark white.
3. Fix the odd curling knob on top of the pine tree mesh in 10-pool-golden.jpg and break up the picket-fence treeline by randomizing tree scale, Y-rotation, and placement depth while mixing in 2–3 tree silhouettes and shoreline boulders.

Strengths:
- 12-pool-night.jpg has a memorable, calm-but-tense mood: the hovering fireflies, dark moonlit clouds, cattails, and warm lantern reflection along the right water edge make you want to cast a line.
- Clear, inviting composition in 10-pool-golden.jpg and 12-pool-night.jpg with foreground reeds, an open casting lane across the pool, and a fallen log framing the far bank.
- 11-gate-noon.jpg creates a strong sense of arrival - the 'Cedar Creek' wooden archway is crisp and legible, and the chunky bark on the left foreground trunks fits the Real-ish style well.
- Good atmospheric instincts in 09-riffle-dawn.jpg (misty background meadow through the trees) and 10-pool-golden.jpg (diagonal sunbeam slicing across the pool).

Broken or ugly:
- 09-riffle-dawn.jpg: White riffle foam patches in the foreground and middle creek have obvious straight, hard-edged square/rectangular tile borders floating on the water.
- 10-pool-golden.jpg: Nearly every pine tree along the far bank has a strange curling bulb/hook sticking off the top and is repeated at identical rotation and height like a flat wall.
- 12-pool-night.jpg: The lantern light blows out the right-hand dirt path to bright snow-white, and the sky reflection in the center of the dark pool reads like a flat grey paint blotch or oil slick.
- 09-riffle-dawn.jpg, 10-pool-golden.jpg, and 11-gate-noon.jpg: Shadows under the trees and along the banks crush nearly to pure black, making terrain and rocks hard to read; 09-riffle-dawn.jpg also has an isolated bright warm light patch on the far-right dirt bank.
- 11-gate-noon.jpg: Foreground bushes look like jagged crumpled low-poly shards compared to the cleaner wood and bark materials, and the bright green lawn lacks grass blades except for one tiny cluster on the bottom left.

Action taken: (fill in: what we changed, or why we didn't)
