# Critic: N4 set C round 1-identity (review, gemini-4-neon)

Date: 2026-11-28 05:54. Rubric: `identity`.

Files shown:
- `c01-canoe-golden.jpg`
- `c02-slips-boathouse-noon.jpg`
- `c03-dinghy-wake-dawn.jpg`

**Score: 6/10**

The hero boats, weathered dock planks, boathouse, and golden-hour or dawn lighting give this a genuinely appealing Real-ish lakeside identity, but that illusion breaks - especially in flat noon light - where realistic wood sits right next to low-poly SmoothPlastic trees, default smooth terrain, plain square block pilings, and untextured plastic props.

| Point | Score |
|---|---|
| materials | 6 |
| signature | 6 |
| cohesion | 5 |
| stock_free | 5 |
| identity | 6 |

Top fixes:
1. Replace the flat-shaded SmoothPlastic pine and deciduous trees across the entire treeline (c01-canoe-golden.jpg, c02-slips-boathouse-noon.jpg, c03-dinghy-wake-dawn.jpg) with Real-ish trees using bark-textured trunks and textured pine-needle or leaf clusters so the backdrop matches the weathered wood foreground.
2. Override default terrain Sand, Mud, and Grass via MaterialService with custom PBR MaterialVariants (pebbled shoreline gravel, textured soil, deeper mossy grass) and swap the smooth dark shore boulders (c01, c02) for craggy stone-textured rocks to fix the flat noon shoreline in c02-slips-boathouse-noon.jpg.
3. Replace the remaining SmoothPlastic and sharp-block parts: swap the sharp 90-degree square dock posts (c01 foreground bottom-left, c02 center-left in water) for weathered round pilings, apply a matte fabric MaterialVariant to the SmoothPlastic striped stall awnings (c01 upper left, c02 upper right), switch the dinghy outboard motor (c03 center) to matte painted metal with dark housings around the bare Neon bow lights, and rebuild the plain block bridge (c03 right background) with textured timber or steel trusses.

Strengths:
- The cedar-strip canoe (c01-canoe-golden.jpg, c02-slips-boathouse-noon.jpg) and orange inflatable dinghy hull with braided rope (c03-dinghy-wake-dawn.jpg) read as handcrafted custom models with believable materials and strong visual appeal.
- The weathered wooden dock planks, rough-bark pilings, and dark timber boathouse with corrugated roof (c02-slips-boathouse-noon.jpg) nail the Real-ish wood and metal target.
- Atmospheric golden-hour warmth in c01-canoe-golden.jpg and cool misty dawn haze in c03-dinghy-wake-dawn.jpg establish a calm northern-lake mood that immediately distances the game from default Roblox.

Broken or ugly:
- In c03-dinghy-wake-dawn.jpg (center-right on the orange dinghy), the red port navigation light sphere appears to float slightly detached off the front tip of the bow.

Reads as stock Roblox:
- Low-poly pine and deciduous trees (c01-canoe-golden.jpg background, c02-slips-boathouse-noon.jpg upper left and right, c03-dinghy-wake-dawn.jpg treeline).: Chunky geometric shapes with untextured matte SmoothPlastic-looking foliage that read as typical Roblox low-poly asset-pack trees and clash with the textured wood docks.
- Smooth shoreline sand, mud, and bare green terrain hills (c02-slips-boathouse-noon.jpg far-left hill and center-right shoreline, c01-canoe-golden.jpg mid-ground hills).: Apart from the moving grass blades, the ground surfaces read as smooth, low-detail default Roblox terrain Grass and Sand.
- Sharp-edged square dock pilings (c01-canoe-golden.jpg foreground bottom-left and slip posts, c02-slips-boathouse-noon.jpg three vertical posts in the center-left water).: Plain unchamfered 90-degree rectangular Roblox block Parts that stand out against the round bark-textured logs right beside them.
- Striped stall awnings (c01-canoe-golden.jpg upper left, c02-slips-boathouse-noon.jpg upper right).: Crisp, flat-colored SmoothPlastic strips that read as untextured plastic blocks rather than canvas or fabric.
- Outboard motor casing and bow navigation lights on the orange dinghy (c03-dinghy-wake-dawn.jpg center).: The motor is glossy untextured black SmoothPlastic with a plain white band, and the red and green bow lights are bare glowing Neon spheres with no lamp housing.
- Distant bridge structure (c03-dinghy-wake-dawn.jpg right background).: Built from thin, flat, untextured dark grey beams and ramps that read as placeholder Roblox Parts.
- Daytime sky and clouds (c02-slips-boathouse-noon.jpg upper frame).: Reads as the default pale blue Roblox noon sky with standard dynamic clouds, lacking the custom mood of the golden and dawn shots.
- Clustered dark shore rocks (c02-slips-boathouse-noon.jpg center-right shoreline, c01-canoe-golden.jpg center shoreline).: Smooth, bulbous dark grey low-poly blobs that read as generic SmoothPlastic rock props rather than textured stone.

Action taken: (fill in: what we changed, or why we didn't)
