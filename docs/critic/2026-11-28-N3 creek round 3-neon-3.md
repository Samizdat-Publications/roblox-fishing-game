# Critic: N3 creek round 3 (review, gemini-4-neon)

Date: 2026-11-28 01:06. Rubric: `look`.

Files shown:
- `09-riffle-dawn.jpg`
- `10-pool-golden.jpg`
- `11-gate-noon.jpg`
- `12-pool-night.jpg`

**Score: 5.5/10**

Cedar Creek already has genuine atmosphere and a charming chunky Real-ish style, especially in the golden-hour sky and the firefly-lit night pool, but murky swirling water, broken square whitewater patches in the riffle, and crushed black shadows at dawn and night hold it back from feeling truly inviting to fish or readable on a phone.

| Point | Score |
|---|---|
| composition | 7 |
| light | 6 |
| water | 3 |
| mood | 7 |
| want_to_fish | 5 |
| phone_readability | 5 |
| broken_or_ugly | 4 |

Top fixes:
1. Fix the water material and replace the broken riffle foam: remove the sharp-edged square whitewater decals/planes in 09-riffle-dawn.jpg (and the stray white streak on the far left of 12-pool-night.jpg) and replace them with soft-feathered ParticleEmitters or curved Beam trails; in Workspace.Terrain, lower WaterWaveSize (around 0.05 to 0.12) and WaterWaveSpeed to eliminate the swirling mud/oil look in 10-pool-golden.jpg, shift WaterColor from muddy brown to a cleaner dark slate-green, and raise WaterTransparency (0.6 to 0.75) and WaterReflectance (0.6 to 0.8) so sky reflections and creek-bed stones read clearly.
2. Lift crushed shadows for dawn and night readability and fix the blown-out path: raise Lighting.OutdoorAmbient and Lighting.Ambient with a cool blue-slate tint in 09-riffle-dawn.jpg and 12-pool-night.jpg so water edges, banks, and trees stay visible on a small phone screen; swap the pale smooth grey path on the right of 10-pool-golden.jpg and 12-pool-night.jpg for a darker, rougher dirt or gravel material and dial back the lantern PointLight brightness so the path stops blowing out to stark white at night.
3. Add natural variation and readable fishing structure: vary the height, scale, and rotation of the identical curled-tip pine trees lined up across the far bank in 10-pool-golden.jpg; mount the lantern directly onto the right Cedar Creek archway post in 11-gate-noon.jpg instead of using a redundant second post right beside it; add denser grass tufts across the bare green foreground in 11-gate-noon.jpg; and place half-submerged logs, boulders, and overhanging branches along the pool edges so players can read real fish-holding spots.

Strengths:
- Strong time-of-day mood across the four shots, especially the low sun peeking through the pine trunks in 10-pool-golden.jpg and the warm lantern glow with floating fireflies in 12-pool-night.jpg.
- Clear, memorable sense of place at the Cedar Creek timber archway in 11-gate-noon.jpg, with crisp, high-contrast sign lettering that reads easily.
- Chunky bark, wood, cobblestone, and pine silhouettes fit the Real-ish art direction well without looking like flat vertex-coloured blocks.
- Good wide sightlines toward the water in 10-pool-golden.jpg and 12-pool-night.jpg, with the distant fallen log and cattails giving natural visual anchors.

Broken or ugly:
- 09-riffle-dawn.jpg: Overlapping rectangular whitewater planes/decals sit right in the center of the creek with plainly visible straight square edges.
- 12-pool-night.jpg: A stray bright blue-white water foam streak is clipped awkwardly on the far-left edge of the dark water.
- 11-gate-noon.jpg: A standalone wooden lantern post is jammed inches away from the right post of the Cedar Creek gate instead of hanging the lantern off the gate itself.
- 10-pool-golden.jpg and 12-pool-night.jpg: The water surface reads like murky swirling brown mud/oil rather than clear stream water, and the smooth pale path along the right bank creates a harsh seam that blows out bright white under the night lantern.
- 09-riffle-dawn.jpg: A large mossy rock/bush sits awkwardly in the bottom-center foreground blocking the view of the stream edge.

Action taken: (fill in: what we changed, or why we didn't)
