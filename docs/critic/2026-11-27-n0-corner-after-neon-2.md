# Critic: n0-corner-after (review, gemini-4-neon)

Date: 2026-11-27 15:37. Rubric: `look`.

Files shown:
- `01-dock-dawn.jpg`
- `02-dock-golden.jpg`
- `08-stands-noon.jpg`

**Score: 7/10**

Dawn and golden hour already feel like a genuine, peaceful lake you want to cast a line into, and the weathered timber dock and shop stands nail the chunky Real-ish art style. Midday lags behind with harsher flat lighting, muddy-looking shallow water, a hard straight grass bank, and a few placement clashes like cattails blocking an info board and lamps glowing at noon.

| Point | Score |
|---|---|
| composition | 7.5 |
| light | 7 |
| water | 6.5 |
| mood | 7.5 |
| want_to_fish | 8 |
| phone_readability | 7 |
| broken_or_ugly | 6 |

Top fixes:
1. Soften the shoreline, foreground grass, and noon water: replace the ruler-straight vertical grass wall right of the dock (08-stands-noon.jpg) with a sloped mud/rock bank and Terrain Decoration grass, deepen Terrain.WaterColor toward a natural lake blue-green with lower WaterTransparency (around 0.35 to 0.5) so midday shallows stop reading as pale beige sand, and break up the empty green foreground in 01-dock-dawn.jpg and 02-dock-golden.jpg with a worn path, pebbles, and a couple of dockside props like crates or a bait barrel.
2. Unify lighting across all times of day: add light midday Atmosphere haze (Density ~0.25) and slightly warmer sunlit fill in 08-stands-noon.jpg so noon keeps the depth of dawn, script the stand lanterns and pole lights to turn off during daylight hours, and lower BloomEffect Intensity (or raise Threshold) during golden hour (02-dock-golden.jpg) so the sun glare stops washing out the left stand roof and distant shore.
3. Clean up prop placement and material consistency: move the cattail clump in 08-stands-noon.jpg out from directly in front of the green info chalkboard (and enlarge board text for phone readability), replace the flat-shaded faceted tree on the far left (08-stands-noon.jpg) and bright flat-orange boat beside the dock (01-dock-dawn.jpg, 02-dock-golden.jpg) with textured materials matching the weathered wood dock, and vary the size and spacing of the symmetrical cattail clusters flanking the pier.

Strengths:
- The dock in 08-stands-noon.jpg hits the Real-ish look dead-on, with varied weathered planks, bark-textured round pilings, cleats, and numbered spots (2 and 3).
- Dawn (01-dock-dawn.jpg) and golden hour (02-dock-golden.jpg) build a memorable, calm lakeside mood with misty Atmosphere haze, layered hills, and a distant bridge silhouette.
- Framing the dock between the two wooden stands creates a clear, welcoming line straight to the water.
- The Bait and Tackle and Sell Fish banners use large, high-contrast serif lettering on dark wood-framed stands that will stay readable even on a small phone screen.
- Water reflections and gentle ripples at dawn and golden hour look tranquil and genuinely inviting to fish.

Broken or ugly:
- In 08-stands-noon.jpg, the cattail clump on the left sits directly in front of the green info board, obstructing the text.
- In 08-stands-noon.jpg, the lamp posts beside both stands are glowing bright white with bloom in the middle of sunny noon.
- In 08-stands-noon.jpg, the grassy shoreline to the right of the dock ends in a sharp, ruler-straight vertical turf wall dropping into the water.
- In 08-stands-noon.jpg, the faceted low-poly tree on the far left uses flat geometric shading that clashes with the textured wood on the dock and stands.
- In 01-dock-dawn.jpg and 02-dock-golden.jpg, the bright orange boat next to the dock reads as flat plastic next to the weathered wood pier.
- In 02-dock-golden.jpg, strong sun bloom blows out the left horizon and bleeds over the roof edge of the left stand.

Action taken: (fill in: what we changed, or why we didn't)
