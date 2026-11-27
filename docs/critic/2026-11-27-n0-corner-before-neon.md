# Critic: n0-corner-before (review, gemini-4-neon)

Date: 2026-11-27 15:34. Rubric: `look`.

Files shown:
- `01-dock-dawn.jpg`
- `02-dock-golden.jpg`
- `08-stands-noon.jpg`

**Score: 7/10**

The lake vista at dawn and golden hour already has genuine charm and makes you want to cast a line, with atmospheric layered hills, warm reflections, and a strong framed walk down the dock. What holds the scene back right now is the foreground craft and UI clutter: the dock planks and stalls read like smooth plastic rather than real wood, floating labels clip off-screen and stack over the player, cattails block the shoreline signs, and the noon shore view looks flat and bare compared to the lake view.

| Point | Score |
|---|---|
| composition | 7 |
| light | 8 |
| water | 7 |
| mood | 7 |
| want_to_fish | 8 |
| phone_readability | 5 |
| broken_or_ugly | 6 |

Top fixes:
1. Switch the dock planks, pilings, and both stall bodies from smooth flat brown to Roblox WoodPlanks and Wood materials with subtle colour variation per plank, and replace the bright orange plastic slip pads on the dock edge with wooden cleats or painted stencil markings so the foreground matches the Real-ish art direction.
2. Overhaul the floating BillboardGuis: move 'Sell Fish' and 'Bait and Tackle' onto physical painted wooden signs on the stall roofs so they stop clipping off the edges of the viewport ('l Fish', 'Bait and T'), and give 'Boat slips' and 'Slip 2/3/4' a short MaxDistance or proximity fade so labels stop piling up over the player's avatar.
3. Clean up the shoreline composition and noon look seen in 08-stands-noon.jpg: relocate the cattails that are blocking the green chalkboard and brown fish sign, add trees and shrubs behind the 'Sell Fish' stall to close off the empty grass horizon, turn off the glowing white lamp bulbs during daytime, and tweak Terrain WaterColor and WaterTransparency toward a slightly cooler, clearer lake blue-green so noon water looks less muddy.

Strengths:
- Golden hour (02-dock-golden.jpg) and dawn (01-dock-dawn.jpg) lighting look genuinely lovely, with soft atmospheric haze separating the distant tree silhouettes and mountain ridges.
- Framing the wooden dock between the two stalls and flanking cattails creates a strong, inviting sightline straight out to the water and distant bridge.
- Water reflections and gentle ripples look natural and calming at dawn and sunset, catching both the cool blue sky and warm amber glow cleanly.
- The overall layout around the dock, boat slips, pond, and two stalls feels cozy and immediately communicates a clear fishing-hub loop.

Broken or ugly:
- In 08-stands-noon.jpg, a clump of cattails grows directly in front of the green chalkboard and overlaps the brown fish board beside 'Bait and Tackle', making the text unreadable.
- In 01-dock-dawn.jpg and 02-dock-golden.jpg, the 'Sell Fish' and 'Bait and Tackle' BillboardGuis stay oversized and clip off the left and right edges of the screen, while 'Boat slips', 'Slip 3', and 'Slip 4' stack awkwardly on top of the player.
- In 08-stands-noon.jpg, the lamps next to both stalls are glowing bright white in broad midday sunlight.
- The faceted geometric low-poly tree on the far left next to 'Your Pond' clashes visually with the realistic terrain grass, sky, and water.
- The horizon behind the 'Sell Fish' stall in 08-stands-noon.jpg ends abruptly as a flat empty grass line with no background treeline or hills.

Action taken: (fill in: what we changed, or why we didn't)
