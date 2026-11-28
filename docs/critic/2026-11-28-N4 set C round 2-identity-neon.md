# Critic: N4 set C round 2-identity (review, gemini-4-neon)

Date: 2026-11-28 07:10. Rubric: `identity`.

Files shown:
- `c01-canoe-golden.jpg`
- `c02-slips-boathouse-noon.jpg`
- `c03-dinghy-wake-dawn.jpg`

**Score: 5.5/10**

Golden hour (c01-canoe-golden.jpg) and misty dawn (c03-dinghy-wake-dawn.jpg) show real promise, with weathered timber structures and believable lakeside mood that clearly aim beyond a default Roblox look. However, noon lighting (c02-slips-boathouse-noon.jpg) exposes a stark material split: handcrafted weathered-wood buildings sit directly against flat-shaded low-poly SmoothPlastic trees, default Roblox terrain blends, stock clouds, and untextured plastic prop details.

| Point | Score |
|---|---|
| materials | 6 |
| signature | 5.5 |
| cohesion | 5.5 |
| stock_free | 5 |
| identity | 5.5 |

Top fixes:
1. Replace the flat-shaded SmoothPlastic pine and deciduous trees across the entire background treeline (c01-canoe-golden.jpg, c02-slips-boathouse-noon.jpg, c03-dinghy-wake-dawn.jpg) with textured bark-and-foliage models using matte MaterialVariants so the forest matches the weathered wood of the boathouse and dock.
2. Override the stock Roblox Terrain Grass, Sand, and Mud textures along the shoreline and hills (c01-canoe-golden.jpg midground bank, c02-slips-boathouse-noon.jpg beach and green mounds) with custom MaterialVariants (pebbly lake sand, damp dark earth, muted meadow grass) and swap the flat dark shoreline rocks for textured mossy stone.
3. Eliminate the remaining SmoothPlastic and Neon prop surfaces: replace the bright orange rectangular pads on the pier (c01, c02, c03) with weathered wood or matte rubber cleats, apply a matte canvas Fabric MaterialVariant to the striped stall awnings (c01, c02), swap the flat Neon lantern cubes (c01, c03) for textured glass lanterns with warm PointLights, and add custom Atmosphere haze and skybox toning to noon (c02) so midday matches the depth of dawn and golden hour.

Strengths:
- The boathouse in c02-slips-boathouse-noon.jpg (left) has strong handmade character, with weathered wood planks, a recessed canoe, oars, and a lifebuoy that read as real timber and craft.
- The dock planks and pilings across all three shots use convincing dark weathered wood grain that anchors the lakefront and catches low-angle light well.
- Atmospheric lighting in c01-canoe-golden.jpg (warm golden sun) and c03-dinghy-wake-dawn.jpg (cool blue morning mist) creates genuine lakeside calm and pushes the game toward its own mood.
- The lakeside layout (boathouse, Bait and Tackle, Sell Fish, timber boat slips, and bright orange inflatable dinghy) already forms a readable, cozy fishing-camp silhouette.

Reads as stock Roblox:
- Faceted low-poly pine and leafy trees (c01-canoe-golden.jpg background treeline, c02-slips-boathouse-noon.jpg behind the boathouse and stalls, c03-dinghy-wake-dawn.jpg far shore): Flat-shaded, untextured SmoothPlastic foliage that reads as generic low-poly Roblox trees and clashes with the textured wood buildings.
- Shoreline sand, mud, and rounded green hills (c02-slips-boathouse-noon.jpg midground shore and background hills, c01-canoe-golden.jpg bank behind the dock): Unmistakable default Roblox Terrain Sand, Mud, and Grass material blends on smooth voxel mounds.
- Midday sky and clouds (c02-slips-boathouse-noon.jpg upper frame, c01-canoe-golden.jpg top center): Default Roblox blue sky gradient with the standard wispy Clouds layer, especially flat and recognizable at noon.
- Bright orange rectangular pads along the dock edge (c01-canoe-golden.jpg behind the dinghy, c02-slips-boathouse-noon.jpg right pier, c03-dinghy-wake-dawn.jpg left pier): Plain, untextured SmoothPlastic blocks sitting directly on weathered timber planks.
- Striped awnings on the shoreline stalls (c02-slips-boathouse-noon.jpg center-right Bait and Tackle and right Sell Fish stalls, c01-canoe-golden.jpg left-background stall): Rigid, untextured SmoothPlastic strips rather than matte woven canvas or fabric.
- Dark grey shoreline boulders (c01-canoe-golden.jpg center shoreline, c02-slips-boathouse-noon.jpg center and right shoreline): Generic dark low-poly smooth rock lumps with little natural stone grain or color variation.
- Glowing lantern cores on posts (c01-canoe-golden.jpg upper right and beside left stall, c03-dinghy-wake-dawn.jpg top center behind dock): Flat glowing Roblox Neon cubes lacking glass panes or warm lamp detail.

Action taken: (fill in: what we changed, or why we didn't)
