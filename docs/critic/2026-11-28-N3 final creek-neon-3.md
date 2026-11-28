# Critic: N3 final creek (review, gemini-4-neon)

Date: 2026-11-28 03:38. Rubric: `look`.

Files shown:
- `09-riffle-dawn.jpg`
- `10-pool-golden.jpg`
- `11-gate-noon.jpg`
- `12-pool-night.jpg`

**Score: 6/10**

Cedar Creek has a genuinely inviting woodland trout-stream identity, and the golden-hour pool (10-pool-golden.jpg) already looks like a spot you want to cast a line. What holds the scenes back is overly crushed dark shadows across every time of day, blocky rectangular foam strips in the dawn riffle, a night lantern that casts no actual light, and a fence-like row of identical hooked-tip pine trees across the pond.

| Point | Score |
|---|---|
| composition | 7 |
| light | 5 |
| water | 6 |
| mood | 7 |
| want_to_fish | 7 |
| phone_readability | 5 |
| broken_or_ugly | 5 |

Top fixes:
1. Lift the crushed shadows and light up the night lanterns: raise Lighting.OutdoorAmbient and Lighting.EnvironmentDiffuseScale so the creek bed in 09-riffle-dawn.jpg, the wooden arch and tree undersides in 11-gate-noon.jpg, and the pond in 12-pool-night.jpg stay readable on desktop and small phones. Put a warm amber PointLight inside every lantern so the night bank, cattails, and water catch warm glow, and darken or warm the sand path color so it stops reading like snow at night.
2. Fix the blocky white-water streaks in 09-riffle-dawn.jpg: replace the hard-edged rectangular foam decals or beams with soft, feathered alpha textures whose Beam Transparency fades smoothly at both ends, and tuck subtle foam ParticleEmitters directly downstream of each rock so the rapids blend naturally into the creek.
3. Break up the cloned pine line across the pond in 10-pool-golden.jpg and 12-pool-night.jpg: edit or vary the identical curved hook tips on those trees, mix in 2 to 3 pine variants with wider scale and Y-rotation randomness, stagger their distance from the water, and add small ferns, pebbles, and grass clusters along the bare dirt-to-grass border in 11-gate-noon.jpg.

Strengths:
- 10-pool-golden.jpg nails the golden-hour water reflections with sun peeking through the trees, visible sandy shallows, cattails, and a fallen log along the far bank.
- The rustic Cedar Creek arch in 11-gate-noon.jpg and the tiny glowing fireflies drifting over the dark water in 12-pool-night.jpg give the location real charm and memorable mood.
- 09-riffle-dawn.jpg has strong composition, framing the rocky creek inside a wooded tunnel that leads toward misty dawn hills.
- Chunky bark textures, cattails, and simple boulder shapes fit the Real-ish art style well without needing high polygon counts.

Broken or ugly:
- 09-riffle-dawn.jpg: large, sharp-edged rectangular patches of white streaks in the bottom-right foreground and mid-stream look pasted on rather than blended white-water.
- 12-pool-night.jpg: the lantern on the right bank has a lit pane but casts zero light onto the ground, cattails, or water surface.
- 12-pool-night.jpg: the light-colored path on the right bank reflects night ambient light as pale blue-grey, reading like snow next to dark green grass.
- 10-pool-golden.jpg and 12-pool-night.jpg: the pine trees across the far bank all have the exact same quirky curved tip and similar spacing, reading as obvious clones.
- 11-gate-noon.jpg and 09-riffle-dawn.jpg: shadows under the pine canopy and across the Cedar Creek timber frame crush almost to pure black, hurting visibility (no HUD/UI was present in these stills to evaluate).

Action taken: (fill in: what we changed, or why we didn't)
