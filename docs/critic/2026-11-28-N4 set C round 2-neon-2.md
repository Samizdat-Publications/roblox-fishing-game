# Critic: N4 set C round 2 (review, gemini-4-neon)

Date: 2026-11-28 07:08. Rubric: `look`.

Files shown:
- `c01-canoe-golden.jpg`
- `c02-slips-boathouse-noon.jpg`
- `c03-dinghy-wake-dawn.jpg`

**Score: 6.5/10**

This lakeside hub already has real fishing-camp charm - the weathered boathouse with its hanging canoe, warm dock lanterns, cattails, and misty dawn haze feel genuinely inviting. What holds it back right now is overly choppy, oil-slick water reflections, crushed dark shadows at golden hour contrasted with flat noon lighting, a noticeably undersized dinghy, and a few jarring placeholder-looking props like the giant Boat slips sign and bright orange dock pads.

| Point | Score |
|---|---|
| composition | 6 |
| light | 6.5 |
| water | 5.5 |
| mood | 7 |
| want_to_fish | 7 |
| phone_readability | 6 |
| broken_or_ugly | 6 |

Top fixes:
1. Calm the Terrain water settings and add shallow clarity: reduce Terrain.WaterWaveSize (to around 0.05-0.12) and Terrain.WaterReflectance (to around 0.35-0.5), raise Terrain.WaterTransparency (around 0.45-0.65), and slope a textured sand-and-rock lakebed under the shore so the lake stops looking like swirling oil in c01-canoe-golden.jpg and lets players read shallows and pilings.
2. Balance golden-hour shadows and add midday atmospheric depth: raise Lighting.EnvironmentDiffuseScale or Ambient slightly with a soft sky tint so the pines and under-dock shadows in c01-canoe-golden.jpg stop crushing to flat black, and add a subtle Atmosphere (Density ~0.25-0.32, soft Haze) plus a slightly lower sun angle to c02-slips-boathouse-noon.jpg so noon has depth like your dawn shot.
3. Scale up the inflatable dinghy and ground the dock signage: scale the orange dinghy in c03-dinghy-wake-dawn.jpg up by roughly 35-50% so the player avatar sits comfortably inside it rather than overflowing it, replace the oversized flat blue Boat slips billboard with a smaller weathered wood post sign, and swap the bright flat orange slip pads on the dock in c01-canoe-golden.jpg for subtle cleats, coiled rope, or weathered planks.

Strengths:
- Strong Real-ish lakeside camp materials: the weathered timber boathouse with hanging canoe, oars, and life ring in c02-slips-boathouse-noon.jpg and the striped stall awnings read clearly as wood and fabric.
- Lovely misty dawn atmosphere in c03-dinghy-wake-dawn.jpg, where the cool blue haze softens the far pine shoreline and reeds into a memorable early-morning fishing mood.
- Great fishing-focused worldbuilding along the shore: the Today on the Lake chalkboard, Trophy Wall, Bait and Tackle, Sell Fish, and numbered boat slips immediately communicate a thoughtful fishing game.
- Warm glowing dock lanterns and sunlit grass in c01-canoe-golden.jpg add cozy focal points that draw the eye back to camp.

Broken or ugly:
- Undersized orange dinghy in c03-dinghy-wake-dawn.jpg: the blocky avatar fills almost the entire boat, making it look like a toy raft rather than a fishing boat.
- Bright flat orange square pads sitting on the wooden boat-slip deck in c01-canoe-golden.jpg and c02-slips-boathouse-noon.jpg clash with the weathered wood planks like placeholder trigger zones.
- Oversized dark-blue Boat slips billboard on the dock in c01-canoe-golden.jpg dominates the right side of the frame and awkwardly tangents with the lantern post directly behind its top-left corner.
- Row of bare wooden pilings marching straight out into the water in front of Bait and Tackle in c02-slips-boathouse-noon.jpg with no dock planks or rope looks unfinished.
- Heavy swirling, high-contrast oil-slick reflections on the foreground water in c01-canoe-golden.jpg and c03-dinghy-wake-dawn.jpg.
- Single-row, evenly spaced pine treeline behind the stalls in c02-slips-boathouse-noon.jpg creates a flat picket-fence horizon, and small text on the Trophy Wall and Today on the Lake chalkboard will be unreadable on a phone at this viewing distance.

Action taken: (fill in: what we changed, or why we didn't)
