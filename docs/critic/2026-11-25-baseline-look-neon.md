# Critic: baseline-look (review, gemini-4-neon)

Date: 2026-11-25 21:33. Rubric: `look`.

Files shown:
- `2026-11-25-m1-lake-overview.jpg`
- `2026-11-25-m1-spawn-dock.jpg`
- `2026-11-25-polish-night-after.jpg`
- `2026-11-25-creek-riffle.jpg`
- `2026-11-25-pond-full.jpg`
- `2026-11-25-rods-in-hand.jpg`

**Score: 3/10**

A solid, clearly organized gray-box baseline with readable fishing zones and a clean mobile-friendly HUD, but it currently looks like a flat swimming pool on an empty green baseplate with default lighting, boxy shorelines, and a few obvious placeholder artifacts.

| Point | Score |
|---|---|
| composition | 2.5 |
| light | 2 |
| water | 2.5 |
| mood | 1.5 |
| want_to_fish | 3 |
| phone_readability | 6.5 |
| broken_or_ugly | 4 |

Top fixes:
1. Add an Atmosphere object, a custom Sky, and time-of-day lighting presets in Roblox Lighting (with Lighting.Technology set to ShadowMap or Future): add warm golden-peach sun tint, soft distance haze, and lower sun angles so 7:14 AM Dawn actually feels like dawn instead of flat overcast noon, and swap the harsh blue-white night dock PointLights for softer warm amber lights.
2. Break up the 90-degree square lake, straight creek trench, and empty horizon by building chunky low-poly hills, angled shoreline banks, and grouped multi-tone trees and boulders around the perimeter so the world no longer drops off into blank sky.
3. Tune the lake and creek water away from bright swimming-pool blue toward a natural muted teal-blue with better depth contrast (lighter shallow edges, darker deep center) and softer wave/reflectance settings, and hide the default SpawnLocation decal and oversized BillboardGui signs.

Strengths:
- The HUD (top status pill showing coins, time, and bag plus the left-hand Bait and Journal buttons) is clean, high-contrast, and uncluttered, which will read well on a small phone.
- Fishing spots are already easy to read from the overview: reeds on the left, sunken logs on the right, a stepped rocky creek, and a personal pond.
- The personal pond in pond-full.jpg uses darker translucent water so you can actually see your caught fish swimming beneath the surface.
- The night dock lanterns in polish-night-after.jpg establish a good focal point and warm up the wooden planks nicely.

Broken or ugly:
- The default gray Roblox SpawnLocation pad with its black sun decal sits right on the dock in m1-spawn-dock.jpg (remove the Decal and set Transparency to 1).
- The yellow rod in rods-in-hand.jpg is a thick, untapered yellow stick that looks like a pool noodle or lightsaber rather than a fishing rod.
- World-space labels (Your Pond in pond-full.jpg and Sell Fish in rods-in-hand.jpg) are huge and overlap the player character or get cut off by the screen edge.
- The bottom prompt says Hold click and let go to cast and the button reads Journal (J), which assumes a PC mouse and keyboard rather than phone touch controls.
- The brown sunken logs in pond-full.jpg look awkwardly detached against the flat water surface, and the creek in creek-riffle.jpg has harsh 90-degree stair-step walls with an abrupt drop-off at the world edge.

Action taken: baseline only; this score (3/10) sets the starting point for the beauty pass in `docs/DIRECTION.md`. Two of the "broken" notes are out of date: the spawn pad's decal was removed in M1 and the stills are older, and the cast prompt and Journal button already change per device ("Hold the Fish button", "Journal (Y)"); the stills were taken on a PC. The rest (lighting, horizon, water colour, boxy creek walls, huge signs, the thick yellow rod) go into the beauty pass.
