# Critic: N3 creek round 3 (review, gemini-4-neon)

Date: 2026-11-28 01:05. Rubric: `look`.

Files shown:
- `09-riffle-dawn.jpg`
- `10-pool-golden.jpg`
- `11-gate-noon.jpg`
- `12-pool-night.jpg`

**Score: 5.5/10**

Cedar Creek already has genuine heart and a memorable backwoods atmosphere - especially the golden-hour sun through the pines and the firefly-lit night pool - and the wooden entrance gate nails your Real-ish art style. Right now, though, the water looks like thick muddy swirls in the pool and uses visibly square decals in the dawn riffle, while dawn and night crush too dark to read clearly on a phone.

| Point | Score |
|---|---|
| composition | 6 |
| light | 6 |
| water | 3 |
| mood | 7 |
| want_to_fish | 6 |
| phone_readability | 5 |
| broken_or_ugly | 5 |

Top fixes:
1. Overhaul the water appearance and replace the square riffle textures: in 09-riffle-dawn.jpg, swap the hard-edged rectangular white foam planes for soft feathered foam particles or a tapered curved mesh/beam that blends into the stream; in 10-pool-golden.jpg and 12-pool-night.jpg, shift Terrain.WaterColor toward a cooler dark blue-green, raise WaterTransparency and WaterReflectance so the sky catches the surface, and reduce WaterWaveSize so it stops looking like swirling brown mud or oil.
2. Lift shadow readability for desktop and phone: in 09-riffle-dawn.jpg and 12-pool-night.jpg, raise Lighting.OutdoorAmbient slightly with a cool blue-slate tint and add a gentle Atmosphere haze (soft lavender-blue for dawn, subtle deep blue for night) so dark trees, banks, and water edges separate cleanly instead of crushing into black; also remove or soften the stray warm spotlight patch hitting the single right-hand tree trunk in 09-riffle-dawn.jpg.
3. Fix the harsh path material, flat noon grass, and cloned pine silhouettes: repaint the pale grey-white path along the right bank in 10-pool-golden.jpg and 12-pool-night.jpg with Ground, Mud, or gravel-toned Rock so it stops reading like snow or pavement; in 11-gate-noon.jpg, spread Terrain.Decoration grass across the bare foreground and slightly tone down the Grass MaterialColor saturation; rotate and vary scale on the pine trees in 10-pool-golden.jpg and trim the identical vertical tip-tufts repeating across the treeline.

Strengths:
- 10-pool-golden.jpg has genuinely lovely golden-hour lighting, with the low sun breaking cleanly between the pine trunks and a soft, believable sky.
- 12-pool-night.jpg builds a cozy, memorable fishing mood: the warm lantern spilling across the reeds and shallow bank plus subtle fireflies over the pool make you want to cast a line.
- 11-gate-noon.jpg nails the Real-ish look on the Cedar Creek archway - chunky timber, believable wood grain, and crisp lettering that reads easily even on a small screen.
- Grounded shoreline touches like the cattails, submerged moss patches, and the fallen log across the far end of the pool give the creek a real sense of place.

Broken or ugly:
- 09-riffle-dawn.jpg: Two or three sharp-edged rectangular white riffle textures sit visibly on top of the dark creek surface, breaking the illusion of flowing water.
- 09-riffle-dawn.jpg: An isolated bright orange light patch hits one tree trunk and ground spot on the right while the rest of the dawn woods remain uniformly dim.
- 10-pool-golden.jpg and 12-pool-night.jpg: The trail on the right uses a very pale grey-tan material with jagged edges that looks like concrete in daylight and almost glows like snow at night.
- 10-pool-golden.jpg: Repeated identical pine meshes along the far bank show cloned teardrop-shaped vertical tufts sticking straight up from almost every tree peak.
- 11-gate-noon.jpg: The lantern post is placed tightly against the right pillar of the Cedar Creek gate, making that corner look slightly cramped.

Action taken: (fill in: what we changed, or why we didn't)
