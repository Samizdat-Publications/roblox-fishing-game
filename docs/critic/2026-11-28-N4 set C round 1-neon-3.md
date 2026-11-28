# Critic: N4 set C round 1 (review, gemini-4-neon)

Date: 2026-11-28 05:53. Rubric: `look`.

Files shown:
- `c01-canoe-golden.jpg`
- `c02-slips-boathouse-noon.jpg`
- `c03-dinghy-wake-dawn.jpg`

**Score: 6.5/10**

This lake hub has genuine warmth, standout boat models, and a memorable misty dawn in c03-dinghy-wake-dawn.jpg, fitting the Real-ish goal well. It is held back by boats sitting too high on overly oily water reflections, a handful of noticeable placement glitches (a floating bow light and a piling blocking the Boat slips sign), flat noon lighting in c02-slips-boathouse-noon.jpg, and tiny world text that will not survive a phone screen.

| Point | Score |
|---|---|
| composition | 6 |
| light | 7 |
| water | 5 |
| mood | 7 |
| want_to_fish | 7 |
| phone_readability | 5 |
| broken_or_ugly | 4 |

Top fixes:
1. Seat the boats deeper in the water and calm Terrain Water reflections: lower the canoe (c01) and dinghy (c03) slightly so their hulls break the waterline instead of hovering, replace the thin straight wake streak in c03 with a wider flat V-shaped surface wake, and lower Terrain.WaterReflectance and WaterWaveSize to stop the harsh oily marbling under the hulls.
2. Fix broken prop and sign placements: re-attach the floating red bow light onto the dinghy tube in c03 (and swap red to port/left, green to starboard/right), move or resize the bulky grey Boat slips sign so the dock piling no longer blocks the word 'slips' (c01, c03), and adjust the clipped sign inside the boathouse doorway in c02.
3. Lift noon lighting, background depth, and small-screen sign readability: give c02 crisper directional sunlight and shadows to match its blue sky, add subtle Atmosphere haze in c01/c02 so dark background pines separate from the shore, plant trees on the bare green hill on the left of c02, and enlarge text and contrast on the Today on the Lake chalkboard, Trophy Wall, and slip price signs ('850', '1,200').

Strengths:
- The cedar-strip canoe (c01, c02) and ribbed orange inflatable dinghy with outboard motor (c03) have great chunky-real silhouettes, warm materials, and strong color contrast against the water.
- Dawn mood in c03-dinghy-wake-dawn.jpg is lovely: soft pastel Atmosphere haze, layered pine silhouettes, and warm glowing dock lanterns genuinely feel like an early morning launch.
- Weathered wooden dock planks, shoreline cattails, and readable hub stalls (Sell Fish, Bait and Tackle, boathouse) build a cozy, inviting fishing village.

Broken or ugly:
- c03-dinghy-wake-dawn.jpg: The red navigation light sphere is floating detached in mid-air off the front-right tip of the dinghy bow.
- c01-canoe-golden.jpg and c03-dinghy-wake-dawn.jpg: A vertical dock piling sits directly in front of the Boat slips sign, blocking the word 'slips'.
- c01-canoe-golden.jpg and c03-dinghy-wake-dawn.jpg: Both the canoe and the orange dinghy ride too high on top of the water with no waterline contact, making them look slightly hovered, and the dinghy wake is a faint thin streak rather than a surface V-wake.
- c01-canoe-golden.jpg and c03-dinghy-wake-dawn.jpg: High-contrast wavy reflections turn the water directly beneath the hulls into dark, oily orange-and-blue marbling.
- c02-slips-boathouse-noon.jpg: A white sign ('BO...') inside the boathouse doorway is partially clipped/blocked by the wall, and the bare terrain hill on the far left looks unfinished.
- c03-dinghy-wake-dawn.jpg: The distant bridge on the right has overly thin, floating-looking horizontal railings over steep blocky ramps.

Action taken: (fill in: what we changed, or why we didn't)
