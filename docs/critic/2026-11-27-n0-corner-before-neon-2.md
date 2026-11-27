# Critic: n0-corner-before (review, gemini-4-neon)

Date: 2026-11-27 15:35. Rubric: `look`.

Files shown:
- `01-dock-dawn.jpg`
- `02-dock-golden.jpg`
- `08-stands-noon.jpg`

**Score: 6.5/10**

The dawn and golden-hour views down the dock have genuine atmosphere and a strong, inviting composition that makes you want to cast a line. However, the midday reverse view exposes flat, untextured SmoothPlastic surfaces on the dock and stands, murky pale water, glowing daytime streetlamps, overlapping shoreline signs, and oversized floating UI labels that undercut the Real-ish lake mood.

| Point | Score |
|---|---|
| composition | 7.5 |
| light | 7 |
| water | 6.5 |
| mood | 7 |
| want_to_fish | 7 |
| phone_readability | 5 |
| broken_or_ugly | 6 |

Top fixes:
1. Switch the dock planks, pilings, and stall walls from SmoothPlastic to WoodPlanks and Wood materials with subtle plank colour variation, replace the bright yellow slip blocks with subtle weathered cleats or ropes, and move stand and slip labels onto physical SurfaceGui wooden signs (or cap BillboardGui MaxDistance and shrink them) so dark floating boxes stop cluttering the view.
2. Deepen Terrain.WaterColor from pale murky beige to a richer natural lake teal-green and tune WaterTransparency and WaterReflectance for midday clarity in 08-stands-noon.jpg, while scripting the shore lamp orbs to turn off their Neon glow and lights during daytime.
3. Separate the overlapping green chalkboard and brown trophy board on the left shore in 08-stands-noon.jpg, clear the cattails blocking the chalkboard, and add a layered backdrop of trees, shrubs, and rocks behind the stands so the shore view matches the richness of the lake horizon.

Strengths:
- Strong framing in 01-dock-dawn.jpg and 02-dock-golden.jpg: the two stands, cattails, dock lamps, and distant bridge lead the eye cleanly out across the lake toward layered hills.
- Lovely dawn and golden-hour lighting and Atmosphere haze, with soft lavender mist in 01-dock-dawn.jpg and warm sunset reflections dancing across the water ripples in 02-dock-golden.jpg.
- Good silhouette readability on desktop for the main vista, player avatar, stalls, and shoreline plants.

Broken or ugly:
- In 08-stands-noon.jpg, the green chalkboard is placed directly in front of the brown trophy board ('Tr...'), blocking its right half, and a clump of cattails sits right in front of the chalkboard obscuring its text.
- In 08-stands-noon.jpg, the white glowing streetlamp orbs beside the Bait and Tackle and Sell Fish stands are lit up in bright midday sunlight.
- In 01-dock-dawn.jpg and 02-dock-golden.jpg, the floating 'Boat slips', 'Slip 3', and 'Slip 4' BillboardGuis pile on top of each other right beside the player and orange boat, while 'Sell Fish' and 'Bait and Tackle' clip off the left and right edges of the screen.
- In 08-stands-noon.jpg, the dock planks, pilings, stalls, and bright yellow slip markers read as flat untextured plastic rather than wood, clashing with the realistic terrain grass and water.
- In 08-stands-noon.jpg, the horizon behind the stands is a flat, bare strip of grass with minimal trees, looking unfinished compared to the lake backdrop.

Action taken: (fill in: what we changed, or why we didn't)
