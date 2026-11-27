# Critic: n0-baseline-B (review, gemini-4-neon)

Date: 2026-11-27 15:29. Rubric: `look`.

Files shown:
- `b01-bridge-dawn.jpg`
- `b02-basin-boat-noon.jpg`
- `b03-lighthouse-golden.jpg`
- `b04-buoys-dusk.jpg`
- `b05-bluewater-noon.jpg`
- `b06-marina-night.jpg`

**Score: 6/10**

The lake already reads like a real fishing destination with distinct habitats - a misty bridge channel, reed-ringed islands, lily pads, and open basin - and the dawn haze and golden-hour sunbeams look genuinely atmospheric. However, floating bridge handrails, raw orange cylinder placeholder buoys, over-dark dusk/night scenes, and flat default-Roblox midday lighting hold the visual polish back from your Real-ish target.

| Point | Score |
|---|---|
| composition | 6 |
| light | 6.5 |
| water | 6.5 |
| mood | 6 |
| want_to_fish | 6.5 |
| phone_readability | 5.5 |
| broken_or_ugly | 4.5 |

Top fixes:
1. Fix the floating bridge railings in b01-bridge-dawn.jpg by adding vertical timber posts and cross-bracing in WoodPlanks material, and replace the raw orange SmoothPlastic cylinder buoys (b02, b04, b05) with multi-part Real-ish buoys featuring weathered Metal/Plastic materials, a reflective stripe, a top cap, and a soft blinking beacon light at dusk/night.
2. Lift dusk and night readability (b04-buoys-dusk.jpg and b06-marina-night.jpg) by raising Lighting.OutdoorAmbient and ColorShift_Top to a soft moonlit slate-blue, tuning Terrain WaterReflectance and WaterTransparency so night water does not turn into dark oily blobs, and adding warm low-range PointLight lanterns on the bridge, marina dock, and lighthouse so landmarks stay legible on small phone screens.
3. Upgrade midday lighting (b02-basin-boat-noon.jpg, b05-bluewater-noon.jpg) and prop materials to match the Real-ish style: add a light Atmosphere haze (Density around 0.25-0.3) so distant hills separate from the foreground, replace SmoothPlastic on tree foliage and foreground lily pads (b03) with textured materials or MaterialVariants, and break up the bare flat beach in b05 with rocks, driftwood, and shoreline reeds.

Strengths:
- Golden-hour lighting in b03-lighthouse-golden.jpg is genuinely memorable, with warm SunRays piercing the cattails and trees and rich gold-and-violet water reflections.
- Dawn atmospheric haze in b01-bridge-dawn.jpg creates soft pastel depth across the distant hills and tiny lighthouse, setting a calm early-morning mood.
- Clear fishing habitat variety across the map - bridge channel (b01), cattail island and lily-pad edges (b02, b03), and open water drop-offs (b04, b05) - immediately makes a player think about where fish would hold.
- Daytime Terrain Water reflections of the cattails and trees in b02-basin-boat-noon.jpg and sun glints in b05-bluewater-noon.jpg look lively and inviting.
- Small atmospheric touches like the fireflies and warm distant cabin glow in b06-marina-night.jpg show strong instinct for quiet lakeside charm.

Broken or ugly:
- Floating bridge handrails in b01-bridge-dawn.jpg: both horizontal railing planks hover completely in mid-air above the bridge deck with no vertical posts supporting them.
- Placeholder orange cylinder buoys in b02-basin-boat-noon.jpg, b04-buoys-dusk.jpg, and especially close-up in b05-bluewater-noon.jpg: untextured flat-capped cylinders that break immersion and look unfinished.
- Abrupt water-surface transition inside the wooden canal in b01-bridge-dawn.jpg, where the channel water looks noticeably stepped and flatter than the foreground ripples.
- Crushed dark exposure in b06-marina-night.jpg and b04-buoys-dusk.jpg, causing the wooden bridge, dock, shoreline trees, and dark water to blend together into hard-to-read silhouettes, especially on a small phone screen.
- Foreground cattails in b03-lighthouse-golden.jpg block the central landmark (presumably the lighthouse referenced in the filename) and reveal chunky flat SmoothPlastic lily pads and geometric pink flowers up close.

Action taken: (fill in: what we changed, or why we didn't)
