# Critic: n0-corner-before (review, gemini-4-neon)

Date: 2026-11-27 15:36. Rubric: `look`.

Files shown:
- `01-dock-dawn.jpg`
- `02-dock-golden.jpg`
- `08-stands-noon.jpg`

**Score: 6.5/10**

The dawn and golden-hour views looking out over the lake are genuinely lovely, with strong framing down the dock toward the distant bridge, misty hills, and shimmering water. Looking back toward the shore at noon breaks that spell: the shallow water turns muddy beige, the stall and dock wood reads flat, glowing lamps stay on in daylight, and big floating BillboardGui labels and bright orange slip pads make the landing feel more like a tycoon hub than a real lakeside fishing spot.

| Point | Score |
|---|---|
| composition | 7.5 |
| light | 7 |
| water | 6 |
| mood | 7 |
| want_to_fish | 7 |
| phone_readability | 5.5 |
| broken_or_ugly | 5.5 |

Top fixes:
1. Replace the floating BillboardGuis ('Sell Fish', 'Bait and Tackle', 'Slip 2/3/4', 'Boat slips') and bright orange dock pads with in-world details: mount wooden SurfaceGui signs directly onto the stall roofs, swap the orange pads for wooden cleats or painted slip numbers on the planks, and show interaction labels only via proximity (short MaxDistance or ProximityPrompt) so text never overlaps or clips at screen edges.
2. Upgrade midday water, lighting, and wood materials in 08-stands-noon.jpg to match the quality of golden hour: tint Terrain WaterColor to a richer blue-green with moderate WaterTransparency (around 0.4 to 0.6) so shallows do not look muddy beige, apply true grained Wood/WoodPlanks MaterialVariants with slight plank colour variation on the dock and stalls, add gentle midday Atmosphere haze, and turn off the lamp post Neon/PointLight glow during daytime.
3. Fix the shore clutter and empty inland backdrop in 08-stands-noon.jpg: relocate the cattails that block the green chalkboard and space the chalkboard apart from the brown fish board ('Tr...') behind it, swap the stark faceted low-poly tree by 'Your Pond' for a softer tree style matching the lake treeline, and add a line of pines, rocks, or a wooden fence behind the stalls so the horizon behind the stands feels grounded.

Strengths:
- Strong lead-in composition in 01-dock-dawn.jpg and 02-dock-golden.jpg: the two stalls frame the wooden dock, drawing the eye straight out to the distant bridge and layered hills.
- Atmospheric dawn and golden-hour lighting in 01-dock-dawn.jpg and 02-dock-golden.jpg, with soft haze separating the distant treeline and warm sunset reflections rippling across the lake.
- Nice shoreline details like the cattail clusters flanking the dock, the rod rack beside the Bait and Tackle stall, the hanging scale inside Sell Fish, and the docked orange boat that hint at a lived-in fishing landing.

Broken or ugly:
- In 08-stands-noon.jpg, cattails grow directly in front of the green chalkboard sign, blocking its text, and the chalkboard overlaps and hides most of the brown fish board behind it.
- In 08-stands-noon.jpg, the white glowing lamp post globes beside both stalls remain lit at bright noon.
- In 01-dock-dawn.jpg and 02-dock-golden.jpg, the 'Boat slips', 'Slip 3', and 'Slip 4' BillboardGuis stack and overlap next to the avatar while 'Sell Fish' and 'Bait and Tackle' clip off the left and right edges of the screen.
- In 08-stands-noon.jpg, the 'Bait and Tackle' text crowds and nearly overflows the edges of its dark rounded background pill.
- In 08-stands-noon.jpg, the bright yellow-orange flat blocks along the left dock edge read like unfinished studio trigger pads rather than real dock fixtures.

Action taken: (fill in: what we changed, or why we didn't)
