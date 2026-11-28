# Critic: N4 set C round 2 (review, gemini-4-neon)

Date: 2026-11-28 07:09. Rubric: `look`.

Files shown:
- `c01-canoe-golden.jpg`
- `c02-slips-boathouse-noon.jpg`
- `c03-dinghy-wake-dawn.jpg`

**Score: 7/10**

A charming, genuinely inviting lakeside hub with real fishing atmosphere - especially in the misty dawn shot - held back mainly by an undersized dinghy, flat noon lighting, oily golden-hour water reflections, and a few chunky/placeholder-looking dock props.

| Point | Score |
|---|---|
| composition | 7 |
| light | 7 |
| water | 7 |
| mood | 8 |
| want_to_fish | 8 |
| phone_readability | 7 |
| broken_or_ugly | 6 |

Top fixes:
1. Scale up the inflatable dinghy by roughly 1.3x to 1.5x and lower/reposition the Seat CFrame so a standard Roblox avatar sits comfortably inside without crowding or clipping the rubber tubes (c03-dinghy-wake-dawn.jpg), and add a subtle white water-contact ring or trailing wake beam/particles.
2. Improve Atmosphere and water settings across times of day: add light bluish haze (Atmosphere Density around 0.25 to 0.3) to noon (c02) so it stops looking flat, raise OutdoorAmbient or EnvironmentDiffuseScale slightly at golden hour (c01) so pine foliage stays dark green instead of crushing to black, and dial back Terrain WaterWaveSize/WaterReflectance while nudging WaterTransparency up near shore so golden-hour water looks less oily and shows the shallow sandy lakebed.
3. Clean up the dock props and shoreline backdrop: replace the flat bright-orange rectangular pads on the boat-slip dock with subtle wooden cleats or dark rubber bumpers, shrink the oversized Boat slips sign (c01) and move it away from the lantern post behind it, tie the bare center pilings (c02) together with sagging mooring ropes or finger planks, and vary the scale, rotation, and depth of the pine treeline behind the stalls so it stops reading like a single flat row.

Strengths:
- The dawn shot (c03-dinghy-wake-dawn.jpg) nails an authentic 6 AM lake mood with soft blue mist, distant tree silhouettes, and warm glowing dock lanterns.
- The shoreline hub in c02-slips-boathouse-noon.jpg tells a clear story with strong Real-ish craft: the weathered wood boathouse with a hanging canoe and oars, cattails along the sandy bank, Trophy Wall, Today on the Lake chalkboard, and distinct Bait and Tackle and Sell Fish stalls.
- Warm side-lighting in c01-canoe-golden.jpg brings out the wood grain on the dock pilings and planks and makes the orange dinghy pop nicely.
- Primary stall signs (Boats, Sell Fish, Boat slips) use high-contrast light text on dark boards that stay legible at desktop scale and shrink down well.

Broken or ugly:
- In c03-dinghy-wake-dawn.jpg, the inflatable dinghy is noticeably too small for the Roblox avatar, making the player fill the entire boat and crowd/clip against the tubes.
- Flat bright-orange pads sitting on the wooden boat-slip dock (visible across c01, c02, and c03) look like untextured dev or spawn pads rather than natural wood or mooring gear.
- The Boat slips sign in c01-canoe-golden.jpg is oversized and boxy compared to the stalls, with a dock lantern awkwardly poking out right behind its top-left corner.
- The standalone line of bare pilings in the center of c02-slips-boathouse-noon.jpg has no planks, ropes, or buoys, making it look unfinished.
- Water reflections in c01-canoe-golden.jpg look overly swirled and oily in the foreground, and the boat in c03-dinghy-wake-dawn.jpg shows almost no visible hull wake or shoreline contact foam.

Action taken: (fill in: what we changed, or why we didn't)
