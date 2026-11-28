# Critic: N4 set C round 3 (review, gemini-4-neon)

Date: 2026-11-28 08:11. Rubric: `look`.

Files shown:
- `c01-canoe-golden.jpg`
- `c02-slips-boathouse-noon.jpg`
- `c03-dinghy-wake-dawn.jpg`

**Score: 7.5/10**

This already feels like a real, cozy northern fishing lake rather than a generic Roblox map. The chunky wooden canoe, orange dinghy, rustic dock planks, and especially the misty dawn and golden-hour lighting give it genuine charm and make you want to cast a line. The biggest things holding it back right now are flat midday lighting in the hub view, oily high-contrast water reflections at golden hour, harsh sand-to-water shoreline seams, and a few cramped or tiny in-world signs that will struggle on smaller screens.

| Point | Score |
|---|---|
| composition | 7 |
| light | 8 |
| water | 7 |
| mood | 8 |
| want_to_fish | 8 |
| phone_readability | 6 |
| broken_or_ugly | 7 |

Top fixes:
1. Improve noon lighting and shadowed darks: in c02-slips-boathouse-noon.jpg, add a light Atmosphere haze (pale blue-grey, low density around 0.2) to separate the background pine trees from the shops, place a soft warm PointLight inside the dark boathouse, and slightly raise OutdoorAmbient or EnvironmentDiffuseScale in both noon and golden hour (c01-canoe-golden.jpg) so pine shadows do not crush to flat black.
2. Clean up sign clutter and readability for desktop and phone: in c03-dinghy-wake-dawn.jpg, remove the cramped 350, 1,200, and Coming soon signs jammed onto the tiny platform in the water (space moored boats farther apart and show prices via a clean proximity prompt or spaced dock posts), brighten the shadowed Bait and Tackle sign text in c02-slips-boathouse-noon.jpg, and ensure players can click the Trophy Wall and Today on the Lake chalkboard to open a readable UI popup.
3. Tune water reflections and shoreline edges: slightly lower Terrain.WaterReflectance and nudge WaterTransparency up in the shallows so c01-canoe-golden.jpg loses the oily black-and-orange reflection blotches, and paint a darker wet-sand or pebble strip with extra shore rocks and reeds along the flat beach edge in c02-slips-boathouse-noon.jpg (while either adding planks/ropes to or removing the four bare pilings in the middle).

Strengths:
- Strong time-of-day atmosphere: the warm golden sunlight in c01-canoe-golden.jpg and the misty pink-and-blue dawn haze with the distant bridge in c03-dinghy-wake-dawn.jpg immediately sell the calm fishing mood.
- Great Real-ish boat and dock craft: the ribbed wooden canoe, orange inflatable dinghy with rope trim and outboard motor, weathered dock pilings, and glowing lanterns read clearly as real wood, rubber, and metal.
- Distinct hub landmarks in c02-slips-boathouse-noon.jpg: the timber boathouse with life ring and oars, color-coded shop awnings, and lakeside cattails make the shore feel purposeful and memorable.
- The white wake trail and soft sky reflections around the dinghy in c03-dinghy-wake-dawn.jpg make heading out onto open water feel alive and inviting.

Broken or ugly:
- In c03-dinghy-wake-dawn.jpg, the black outboard motor tiller arm pokes straight into the seated player's back instead of lining up with a hand.
- In c03-dinghy-wake-dawn.jpg, the 350, 1,200, and Coming soon signs are crammed together on a tiny floating post, and the wooden canoe and orange dinghy behind them sit so close they look stacked or overlapping.
- In c02-slips-boathouse-noon.jpg, four bare wooden pilings walk out into the water between the chalkboard and the boats with no dock planks or mooring lines, looking unfinished.
- In c01-canoe-golden.jpg, heavy water reflections break up into blotchy, oily dark patches in the foreground, and the shadowed pines on the left and right edges lose almost all detail to pure black.
- In c02-slips-boathouse-noon.jpg, the text on the Trophy Wall and green Today on the Lake chalkboard is unreadable at normal viewing distance and will be completely illegible on a phone, and the Bait and Tackle sign is very dark under its awning.

Action taken: (fill in: what we changed, or why we didn't)
