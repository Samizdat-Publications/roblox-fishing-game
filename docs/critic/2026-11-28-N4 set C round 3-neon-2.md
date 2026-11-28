# Critic: N4 set C round 3 (review, gemini-4-neon)

Date: 2026-11-28 08:12. Rubric: `look`.

Files shown:
- `c01-canoe-golden.jpg`
- `c02-slips-boathouse-noon.jpg`
- `c03-dinghy-wake-dawn.jpg`

**Score: 7/10**

This lake hub already has genuine Northwoods charm: the handcrafted slatted canoe, detailed orange dinghy with its wake, weathered boathouse, and misty dawn lighting (c03) immediately make you want to launch and fish. Right now the biggest immersion-breakers are an obvious boat-clipping bug at the slips, overly dark oily reflections at golden hour (c01), flat midday lighting and a straight-line 'strip mall' shoreline layout at noon (c02), and low-contrast or tiny world signage that will blur out on a phone.

| Point | Score |
|---|---|
| composition | 7 |
| light | 7 |
| water | 7 |
| mood | 8 |
| want_to_fish | 8 |
| phone_readability | 6 |
| broken_or_ugly | 5 |

Top fixes:
1. Separate the boat slip spawns and clean up stray props: move the wooden canoe, orange dinghy, and white motorboat into distinct, wider dock slips so they stop clipping through each other (seen in c02 and c03), remove the 'Coming soon' sign and space out the '350' and '1,200' slip markers, and either finish or remove the four bare pilings jutting out of the water in the center of c02.
2. Balance Lighting and Atmosphere across times of day: in c01 (golden hour), lift Lighting.OutdoorAmbient slightly with a cool muted blue-teal and soften shadow darkness so the pine trees and under-dock areas do not crush to pure black; in c02 (noon), add a touch of Atmosphere.Density haze, slight warm sun tint, and a more angled sun so midday has depth instead of looking flat.
3. Tame golden-hour water reflections and improve sign legibility for desktop and phone: reduce Terrain Water reflectance contrast or tweak WaterWaveSize and WaterTransparency so c01 reads as gentle lake ripples instead of dark oily blotches; increase text brightness on the shaded 'Bait and Tackle' sign, move the lantern post away from behind the 'Boat slips' sign border, and enlarge text on the 'Today on the Lake' chalkboard and 'Trophy Wall' so they are readable from the dock and on phones.

Strengths:
- The boats are standout Real-ish assets: the varnished slatted wooden canoe in c01-canoe-golden.jpg and the orange inflatable dinghy with rope detailing, outboard motor, and wake trail in c03-dinghy-wake-dawn.jpg look tactile and inviting.
- Dawn lighting and atmospheric haze in c03-dinghy-wake-dawn.jpg create a genuinely calm, memorable early-morning lake mood with nicely layered pine silhouettes.
- Warm golden-hour light in c01-canoe-golden.jpg highlights the wood grain on the dock planks, canoe ribs, and Sell Fish stall.
- Strong environmental storytelling in c02-slips-boathouse-noon.jpg, especially the weathered boathouse with a racked canoe, hanging oars, and life preserver ring.

Broken or ugly:
- In c02-slips-boathouse-noon.jpg (right) and c03-dinghy-wake-dawn.jpg (background right), the orange inflatable dinghy and the wooden canoe are clipping directly through each other in the same slip.
- In c02-slips-boathouse-noon.jpg (center), four bare wooden pilings stick straight out of the water with no dock or rope, and in c03-dinghy-wake-dawn.jpg a lone piling sits right in the dinghy's wake path.
- In c03-dinghy-wake-dawn.jpg (background right), the '350', '1,200', and 'Coming soon' signs are jammed tightly together on tiny stubs in front of overlapping boats, and the distant bridge reads as a plain paper-thin grey slab.
- In c01-canoe-golden.jpg (right), the lantern post behind the 'Boat slips' sign visually collides with the top edge of the sign.

Action taken: (fill in: what we changed, or why we didn't)
