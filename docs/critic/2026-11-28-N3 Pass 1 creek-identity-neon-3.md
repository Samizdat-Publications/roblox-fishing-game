# Critic: N3 Pass 1 creek-identity (review, gemini-4-neon)

Date: 2026-11-28 02:12. Rubric: `identity`.

Files shown:
- `09-riffle-dawn.jpg`
- `10-pool-golden.jpg`
- `11-gate-noon.jpg`
- `12-pool-night.jpg`

**Score: 3.5/10**

The lighting moods across dawn, golden hour, and night show real care and hint at the calm fishing-spot atmosphere you want, especially with the cattails and fireflies around the pool. However, the environments still read strongly as default Roblox rather than a bespoke Real-ish world: default Smooth Terrain (bright lime grass, flat brown mud, and pale sand), default Roblox skies and clouds, untextured triangulated bushes, bare Neon-cube lanterns, and clashing low-poly tree sets dominate every shot. On top of that, hard-edged square whitewater tiles sit visibly on the dawn riffle, and there are no fishing-specific landmarks or rustic craft details yet to give the game an unmistakable visual signature.

| Point | Score |
|---|---|
| materials | 3.5 |
| signature | 3 |
| cohesion | 4 |
| stock_free | 3 |
| identity | 3.5 |

Top fixes:
1. Replace default Roblox Terrain materials with custom PBR MaterialVariants in MaterialService across all banks and paths (11-gate-noon.jpg, 10-pool-golden.jpg, 12-pool-night.jpg, 09-riffle-dawn.jpg): swap bright stock Grass, Mud/Ground, and pale Sand for muted mossy turf, pebbled loamy dirt, and dark wet river gravel/silt so the ground stops reading as default Smooth Terrain and stops glowing like snow under the night lantern.
2. Replace the default Roblox Skybox and Clouds with custom atmospheric Skyboxes tuned per time of day, and unify all trees and shrubs into one Real-ish asset family (all four files): retire both the uniform knob-tipped pines across the pool (10-pool-golden.jpg, 12-pool-night.jpg) and the untextured SmoothPlastic-looking triangulated bushes (11-gate-noon.jpg) in favour of varied, textured cedar/pine trees and matte textured ferns/undergrowth.
3. Replace the bare Neon-cube lanterns, sharp-edged block fencing, and square riffle overlays with crafted Real-ish creek props and soft-edged water VFX: build a signature iron-and-glass lantern hanging from chamfered weathered timber posts (10-pool-golden.jpg, 11-gate-noon.jpg, 12-pool-night.jpg), add mossy bank boulders or a worn timber fishing spot as a recognizable landmark, and replace the hard-edged rectangular ripple planes in 09-riffle-dawn.jpg with soft-feathered alpha-masked foam decals or beams wrapped tightly around the stream rocks.

Strengths:
- Distinct time-of-day moods across the four stills: hazy dawn in 09-riffle-dawn.jpg, warm sunbeams breaking through trunks in 10-pool-golden.jpg, and quiet fireflies hovering over the dark bank in 12-pool-night.jpg.
- Inviting shoreline framing in 10-pool-golden.jpg and 12-pool-night.jpg, where the curved bank and cattails naturally guide the eye out over the fishing pool.
- Clean, uncluttered world presentation with no floating name labels or noisy visual clutter distracting from the landscape.

Broken or ugly:
- 09-riffle-dawn.jpg (bottom-right to center stream): whitewater ripple overlays appear as sharp-edged rectangular texture tiles with visible 90-degree seams floating on top of the stream.
- 12-pool-night.jpg (bottom-right shoreline): the lantern light blows out the pale sand bank into a flat white patch that reads like snow rather than night-lit river sand.
- 09-riffle-dawn.jpg (foreground left and center banks): lighting under the canopy crushes the ground, foliage, and stream boulders nearly to pure black, which will lose readability on a small phone screen.
- 10-pool-golden.jpg and 12-pool-night.jpg (far shoreline): every pine tree across the pond has an identical bent teardrop knob at the very top and stands at nearly uniform height, and on the far left of 12-pool-night.jpg the flat terrain horizon cuts off abruptly behind the trunks.

Reads as stock Roblox:
- Default Roblox Terrain Grass and Ground/Mud (11-gate-noon.jpg, entire foreground; 09-riffle-dawn.jpg, left bank): Bright yellow-green smooth grass airbrushed into flat brown mud reads immediately as uncustomized Roblox Smooth Terrain.
- Default Roblox Terrain Sand (10-pool-golden.jpg and 12-pool-night.jpg, bottom-right shoreline): Smooth pale stock beach sand blending softly into green grass, blowing out to flat white under the night lantern.
- Default Roblox Skybox and dynamic Clouds (11-gate-noon.jpg, 10-pool-golden.jpg, 12-pool-night.jpg, upper frame): Unmistakable default saturated blue noon sky, standard sun flare, dark blue night sky, and wispy stock Roblox clouds.
- Bare Neon/SmoothPlastic block lanterns (11-gate-noon.jpg, right of gate; 10-pool-golden.jpg and 12-pool-night.jpg, right bank): Constructed from plain rectangular post parts and an unframed solid glowing yellow cube with no glass housing or metalwork.
- Untextured triangulated low-poly bushes and leaf clumps (11-gate-noon.jpg, foreground center-left and right; 10-pool-golden.jpg and 12-pool-night.jpg, bottom-right bank): Sharp flat-shaded green facets that read as default Plastic/SmoothPlastic rather than real matte foliage.
- Basic block-and-rail fence and gate timber with stock Wood material (11-gate-noon.jpg, midground left to right): Sharp-edged rectangular Studio parts wrapped in default Roblox Wood grain with no bevels, joints, or weathering.

Action taken: (fill in: what we changed, or why we didn't)
