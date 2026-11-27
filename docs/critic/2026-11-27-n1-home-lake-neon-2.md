# Critic: n1-home-lake (review, gemini-4-neon)

Date: 2026-11-27 17:00. Rubric: `look`.

Files shown:
- `01-dock-dawn.jpg`
- `02-dock-golden.jpg`
- `03-dockend-noon.jpg`
- `04-dockend-night.jpg`
- `05-weedbed-golden.jpg`
- `06-logs-dawn.jpg`
- `07-overview-golden.jpg`
- `08-stands-noon.jpg`
- `09-riffle-dawn.jpg`
- `10-pool-golden.jpg`
- `11-gate-noon.jpg`
- `12-pool-night.jpg`

**Score: 6.5/10**

The main lake already shows real heart and a strong Real-ish identity - especially at dawn and golden hour, where the weathered wooden dock planks (08-stands-noon.jpg), mossy shoreline boulders and cattail weedbed (05-weedbed-golden.jpg), and misty sunken logs (06-logs-dawn.jpg) genuinely make you want to cast a line. However, the polish drops sharply in three places: golden-hour glare blows out the aerial view with a harsh vertical light cutoff (07-overview-golden.jpg), noon lighting turns the grass flat and lime-green with pitch-black tree shadows (03-dockend-noon.jpg, 11-gate-noon.jpg), and the Cedar Creek area (09-riffle-dawn.jpg through 12-pool-night.jpg) looks much more prototyped, with boxy pool banks, untextured smooth grey rocks, and tilted placeholder lamp posts.

| Point | Score |
|---|---|
| composition | 7 |
| light | 6 |
| water | 6 |
| mood | 7 |
| want_to_fish | 7 |
| phone_readability | 7 |
| broken_or_ugly | 5 |

Top fixes:
1. Tune Lighting, SunRays, Atmosphere, and Terrain Grass colours: lower SunRaysEffect.Intensity and Atmosphere.Glare at golden hour to eliminate the orange washout and vertical glare wall in 07-overview-golden.jpg; at noon (03, 08, 11), add light Atmosphere.Haze (0.3-0.5), lift OutdoorAmbient slightly so tree undersides in 11-gate-noon.jpg are not pitch black, and mute Terrain Grass and LeafyGrass colours toward natural olive tones.
2. Bring Cedar Creek (09-12) up to the main lake's material and terrain standard: use Terrain Sculpt/Erode to break up the rectangular swimming-pool edges in 10-pool-golden.jpg and widen the narrow trench in 09-riffle-dawn.jpg with rocky banks and foam/ripple decals; swap the smooth untextured grey rock mound in 09 for the textured boulders used in 05-weedbed-golden.jpg; replace the leaning cylinder-and-sphere lamp posts (10, 11, 12) with the dock's framed lanterns; and lower Terrain.WaterWaveSize slightly with a deeper, warmer tint in small pools.
3. Clean up framing, treeline depth, and sign clearance around the main dock: remove or shift the cattail clump blocking the green chalkboard sign in 08-stands-noon.jpg, thicken the sparse treeline behind the stands (08) and along the far shore (03) so empty horizon does not show through, and break up the bare grass expanse between the two stands (01, 02) with a worn dirt/gravel path and small dockside props like crates, a bench, or a bait barrel.

Strengths:
- 05-weedbed-golden.jpg is a standout shot: the textured shoreline rocks catching orange light, clustered cattails, lily pads, and warm water reflections immediately read as a real, tempting fishing spot.
- 01-dock-dawn.jpg and 02-dock-golden.jpg have strong, inviting framing down the dock toward the bridge and distant hill, with genuinely lovely lavender dawn mist and amber-teal golden-hour skies.
- The weathered wooden planks, nails, and stump bollards on the dock in 08-stands-noon.jpg nail the chunky Real-ish material goal, and the Bait and Tackle and Sell Fish signs are bold and easy to read even at phone size.
- 06-logs-dawn.jpg and 04-dockend-night.jpg establish distinct moods and readable fishing structure - submerged logs in morning haze and a lit buoy with fireflies at night.

Broken or ugly:
- 07-overview-golden.jpg: Severe golden-hour glare washes out the center of the lake into flat orange haze, with a sharp vertical light-cutoff edge running down the upper-left side of the water.
- 10-pool-golden.jpg and 12-pool-night.jpg: The lamp post on the right bank is tilted at an awkward angle and casts a crisp, unnatural rectangular dark shadow directly beneath its base at night (12).
- 08-stands-noon.jpg: A cluster of cattails sits directly in front of the green chalkboard sign on the left shore, obscuring its text.
- 09-riffle-dawn.jpg: The rock mound under the three pines uses smooth, untextured faceted grey geometry and flat cone trees that clash starkly with the textured stone and wood at the lake, and the riffle water barely shows inside a dry-looking ditch.
- 06-logs-dawn.jpg: A sharp dark branch triangle pokes into the upper-right corner of the frame, and the shore transitions abruptly from dark mud to grey gravel.

Action taken: (fill in: what we changed, or why we didn't)
