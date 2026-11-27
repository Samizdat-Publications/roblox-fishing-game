# Critic: n1-round1-lake (review, gemini-4-neon)

Date: 2026-11-27 18:13. Rubric: `look`.

Files shown:
- `01-dock-dawn.jpg`
- `02-dock-golden.jpg`
- `03-dockend-noon.jpg`
- `04-dockend-night.jpg`
- `05-weedbed-golden.jpg`
- `06-logs-dawn.jpg`
- `07-overview-golden.jpg`
- `08-stands-noon.jpg`

**Score: 7.3/10**

This lake already feels like a real place you want to fish, with strong angling structure (weedbeds, sunken logs, dock pilings, bridge channel) and genuinely atmospheric dawn, golden hour, and night lighting from ground level. The biggest things holding it back are blown-out orange glare during golden hour from higher angles, empty bare grass around the shop stands, and a few clashing low-poly assets like faceted trees and boxy cattail stems.

| Point | Score |
|---|---|
| composition | 7 |
| light | 7 |
| water | 8 |
| mood | 8 |
| want_to_fish | 8 |
| phone_readability | 7 |
| broken_or_ugly | 6 |

Top fixes:
1. Tame Golden Hour glare and soften Noon lighting: lower SunRaysEffect.Intensity (to around 0.05-0.1) and Atmosphere.Glare/Haze during golden hour so looking toward the sun or from above (07-overview-golden.jpg) does not wash out into an opaque orange wall; for noon (03-dockend-noon.jpg, 08-stands-noon.jpg), add light Atmosphere.Density (around 0.2-0.25) and a subtle warm ColorCorrection tint so midday feels less stark.
2. Dress the bare lawn and unify foliage style: replace the flat-shaded faceted green trees on the left of 08-stands-noon.jpg with textured trees matching the shoreline pines, add a worn dirt path, bushes, wooden bench, and tackle crates to break up the empty green yard in 01, 02, and 08, and replace the chunky rectangular cattail stems in 05-weedbed-golden.jpg with thinner tapered blades.
3. Polish night fireflies, duplicate logs, and far-shore variety: swap the sharp starburst texture on the firefly ParticleEmitter in 04-dockend-night.jpg for a soft warm radial glow and slightly raise cool blue OutdoorAmbient so the far treeline reads on small phones; rotate, rescale, or half-bury one of the two identical submerged logs in 06-logs-dawn.jpg; clump the evenly spaced pines along the far shore in 03-dockend-noon.jpg with shoreline boulders and overhanging shrubs.

Strengths:
- Distinct, believable fishing spots: the cattail and lilypad cove (05-weedbed-golden.jpg), submerged deadfall logs (06-logs-dawn.jpg), weathered dock pilings (08-stands-noon.jpg), and buoy channel (03-dockend-noon.jpg) immediately give players real fishing targets.
- Strong ground-level mood across times of day: misty cool dawn (01-dock-dawn.jpg, 06-logs-dawn.jpg), warm golden reflections on the water (02-dock-golden.jpg, 05-weedbed-golden.jpg), and calm night lighting with the buoy glow reflecting on dark ripples (04-dockend-night.jpg).
- Excellent material work on the wooden dock in 08-stands-noon.jpg: uneven weathered planks, nail detail, and bark-textured stump pilings hit the Real-ish style target.
- Clear sightline framing from between the stands down the dock toward the buoy, bridge, and distant hill (01-dock-dawn.jpg, 02-dock-golden.jpg).

Broken or ugly:
- 07-overview-golden.jpg has a harsh, blinding sheet of orange sun-ray glare that completely washes out the upper half of the lake.
- 08-stands-noon.jpg shows flat-shaded, faceted geometric deciduous trees on the far left that clash with the Real-ish textured wood, rocks, and pine trees.
- 05-weedbed-golden.jpg has noticeably thick, rectangular block cattail stems right in the foreground next to smooth sculpted rocks and sand.
- 04-dockend-night.jpg uses a sharp multi-point starburst sprite for fireflies, especially distracting on the large one near the bottom-left.
- 06-logs-dawn.jpg shows two nearly identical submerged log meshes placed almost parallel, plus dark tree geometry clipping awkwardly into the left and top-right edges of the view.
- 08-stands-noon.jpg has the green information board partly blocked by foreground cattails, and the dark blue Bait and Tackle sign sits dimly in shadow, hurting small-screen legibility.

Action taken: (fill in: what we changed, or why we didn't)
