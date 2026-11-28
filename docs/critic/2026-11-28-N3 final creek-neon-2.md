# Critic: N3 final creek (review, gemini-4-neon)

Date: 2026-11-28 03:38. Rubric: `look`.

Files shown:
- `09-riffle-dawn.jpg`
- `10-pool-golden.jpg`
- `11-gate-noon.jpg`
- `12-pool-night.jpg`

**Score: 5.5/10**

Cedar Creek has a genuinely charming Pacific Northwest mood - the golden-hour pool water, carved-bark timber gate, distant dawn mist, and night fireflies all show real care and make it feel like a spot worth remembering. However, overly crushed dark shadows hurt readability (especially on a phone), the dawn riffle is broken by blocky rectangular whitewater strips, the night lantern casts no light, and a row of cloned trees with odd drooping tips distracts across the far bank of the pool.

| Point | Score |
|---|---|
| composition | 7 |
| light | 5 |
| water | 5 |
| mood | 7 |
| want_to_fish | 6 |
| phone_readability | 4 |
| broken_or_ugly | 4 |

Top fixes:
1. Lift crushed shadow levels and add real lantern lighting: raise Lighting.OutdoorAmbient and EnvironmentDiffuseScale (soft cool blue-grey at dawn and night, gentle warm fill at noon and golden hour) so trees, the Cedar Creek sign, and shorelines stay readable on phones, and place warm amber PointLights inside the lanterns (scripted off at noon, on at dusk/night) so the lakeside lantern in 12-pool-night.jpg casts cozy light onto the post, path, cattails, and water.
2. Replace the blocky whitewater strips in 09-riffle-dawn.jpg: remove the hard-edged rectangular foam textures/beams on the creek and swap in soft-feathered alpha foam textures or narrow curving Beams with a Transparency NumberSequence that fades cleanly to 1 at both ends, tucked closely behind each boulder, while increasing water clarity/reflectivity so the creek reads as flowing water.
3. Fix the cloned treeline across the far bank of the pool in 10-pool-golden.jpg and 12-pool-night.jpg: remodel or remove the tree variant with the awkward drooping loop/hook tip, and vary tree heights, Y-rotations, and species mix (blending the sharper spruce trees from the left background and gate) so the horizon reads like a natural forest instead of a repeating row.

Strengths:
- The golden-hour pool water in 10-pool-golden.jpg looks inviting and alive, with natural reflections of the warm sky, subtle algae/weed tones near the left bank, and believable ripples.
- The Cedar Creek wooden arch gate and chunky carved-bark tree trunks in 11-gate-noon.jpg fit the Real-ish art style well and establish a memorable fishing location.
- Strong mood and fishing-spot storytelling: the fallen log and cattails around the pool, the soft lavender dawn mist in the background of 09-riffle-dawn.jpg, and fireflies drifting over the night water in 12-pool-night.jpg.
- Clear sightlines toward fishable structure - around stream rocks in the riffle, along the right-hand cattails, and toward the far-bank log in the pool.

Broken or ugly:
- In 09-riffle-dawn.jpg, the whitewater foam strips on the stream have harsh, blocky rectangular edges - most glaring in the lower-right foreground - that clearly sit like flat stickers on top of the water.
- In 10-pool-golden.jpg and 12-pool-night.jpg, the far treeline lines up 6 to 8 nearly identical copies of a tree with a strange drooping hook/blob on top, creating an unnatural picket-fence silhouette.
- In 12-pool-night.jpg, the right-side lantern glass is glowing bright white/pale yellow while casting zero light onto its own wooden post, the path, or the nearby water; meanwhile in 11-gate-noon.jpg, the gate lantern is visibly lit during bright midday.
- In 12-pool-night.jpg, the pale sand/dirt path on the right bank turns an unnatural icy grey-white under night lighting, reading almost like snow next to the dark grass.

Action taken: (fill in: what we changed, or why we didn't)
