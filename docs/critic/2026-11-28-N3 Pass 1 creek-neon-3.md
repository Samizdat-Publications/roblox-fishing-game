# Critic: N3 Pass 1 creek (review, gemini-4-neon)

Date: 2026-11-28 02:08. Rubric: `look`.

Files shown:
- `09-riffle-dawn.jpg`
- `10-pool-golden.jpg`
- `11-gate-noon.jpg`
- `12-pool-night.jpg`

**Score: 5.5/10**

Cedar Creek already has real heart and a memorable woodland fishing mood - especially the misty dawn meadow, the glowing lakeside lantern with fireflies at night, and the welcoming wooden entrance gate. However, the scene is currently held back by broken hard-edged rectangular water tiles on the dawn riffle, overly crushed near-black shadows that hurt phone readability, and a repetitive row of awkward knob-tipped trees across the pool.

| Point | Score |
|---|---|
| composition | 7 |
| light | 5 |
| water | 4 |
| mood | 7 |
| want_to_fish | 7 |
| phone_readability | 5 |
| broken_or_ugly | 4 |

Top fixes:
1. Fix the riffle whitewater in 09-riffle-dawn.jpg: remove the flat rectangular textured parts or decals that show sharp square seams across the stream, and replace them with sculpted rocks poking through Terrain Water plus soft, feathered-alpha foam meshes or beams wrapped tightly around individual boulders.
2. Lift crushed shadows and balance lighting across times of day: increase Lighting.OutdoorAmbient and EnvironmentDiffuseScale (soft blue-violet at dawn/night, warm tint at golden hour) so banks and trunks stay readable on small phone screens; warm up the directional Sunlight/Atmosphere in 10-pool-golden.jpg so golden hour actually glows warm; and darken the dirt path texture/colour on the right bank so it does not turn snow-white under night lighting in 12-pool-night.jpg.
3. Fix the repetitive treeline across the pool in 10-pool-golden.jpg and 12-pool-night.jpg: replace or rework the rounded pine model with the weird curled teardrop tips, mix in the much stronger pointed conifers from 11-gate-noon.jpg, and randomize tree height, rotation, and gaps so the far horizon looks natural.

Strengths:
- Memorable atmosphere and sense of place: the misty blue-purple dawn haze in 09-riffle-dawn.jpg and the warm lantern paired with fireflies in 12-pool-night.jpg immediately feel calm and inviting.
- Strong fishing-spot framing: both the tree-lined creek in 09-riffle-dawn.jpg and the reed-edged pool with a far-bank log in 10-pool-golden.jpg look like genuine places where fish would hold.
- Good Real-ish material feel in 11-gate-noon.jpg: the chunky wood posts, coarse bark on the foreground trunks, and crisp 'Cedar Creek' gate sign read cleanly and fit the art direction well.

Broken or ugly:
- 09-riffle-dawn.jpg: Hard-edged rectangular planes/decals used for creek ripples are blatantly visible as overlapping bright squares on the water surface, alongside stray white dot particles near the bottom right.
- 10-pool-golden.jpg and 12-pool-night.jpg: Nearly every tree lining the far bank of the pool has the exact same bulbous, hooked tip poking straight out of the top, creating a distracting repeated silhouette.
- 12-pool-night.jpg: The dirt path on the right bank renders bright white under the lantern and night lighting so it looks like snow against green grass, while the cloud reflection in the center of the water reads like a flat milky-grey blotch.
- 09-riffle-dawn.jpg, 11-gate-noon.jpg, and 12-pool-night.jpg: Shadows under the tree canopy crush into near-black, hiding bank edges and tree detail (especially problematic on phones).

Action taken: (fill in: what we changed, or why we didn't)
