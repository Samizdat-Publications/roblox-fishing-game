# Texture sources

Every map in this folder comes from a public domain (CC0) photo scan or from our own code. Nothing here needs credit, but we keep the list so any map can be traced and rebuilt.

- ambientCG licence: CC0 1.0, https://docs.ambientcg.com/license/
- Poly Haven licence: CC0 1.0, https://polyhaven.com/license
- Raw downloads are not in the repo. They live in `artifacts/textures_src/` (git-ignored). `python art/scripts/texture_pipeline.py --all --fetch` downloads any that are missing, from the URLs in `art/scripts/texture_families.json`.
- Downloaded 11/27/2026, the 1K JPG sets.

## What the pipeline does to every source

`art/scripts/texture_pipeline.py`, same steps for every family: checks that the scan tiles (and fixes it with an offset-and-blend if it does not, or if it was cropped), sizes it (1024 terrain, 512 props), multiplies a little of the scan's AO into the colour, softens the fine noise and flattens large blotches, pulls the mean colour exactly onto the palette target while capping brightness and hue variation, writes a grey "neutral" copy with a mean of 0.80, softens and re-normalizes the normal map (OpenGL), and moves the roughness to the family's target. The exact numbers for each family are in its `<family>.json`.

Four N1 families also get a layer made by our own code inside the same script (all of it tiles): painted_wood is cut into boards with grooves and worn paint beside them, tin_roof gets rust runs, aluminium gets a few shallow dents and a metalness map, and leaf_needle has no scan at all.

## Families

| Family | Source | Page | Licence | What was done to it |
|---|---|---|---|---|
| weathered_plank | Poly Haven "Wood Planks Grey" (`wood_planks_grey`) | https://polyhaven.com/a/wood_planks_grey | CC0 | Sized to 512. Pulled to dock timber 122,104,86. Blotches flattened by half, bright chips soft-clipped (despeckle 1.8), hue variation cut to a quarter. Roughness mean 0.80. Six boards per tile, running along V. |
| rope | ambientCG "Rope 001" | https://ambientcg.com/a/Rope001 | CC0 | Sized to 512. Pulled to light hemp 176,152,112. Strand contrast capped at 10 percent. Roughness mean 0.82. |
| canvas | ambientCG "Fabric 036" | https://ambientcg.com/a/Fabric036 | CC0 | Middle half of the scan (so the weave is twice as big and reads from farther off), made to tile again by offset-and-blend, sized to 512. Pulled to khaki off-white 198,188,160. Contrast capped at 5 percent. Roughness mean 0.88. |
| meadow_grass | ambientCG "Grass 004" | https://ambientcg.com/a/Grass004 | CC0 | Sized to 1024. Pulled to meadow 104,122,62. Fine noise softened 60 percent, large blotches flattened 60 percent, brightness variation capped at 7.5 percent, hue variation cut to 30 percent (no yellow or pale specks left). Normal flattened to 0.6. Roughness mean 0.86 (the scan's own roughness was far too glossy). |
| wet_sand | ambientCG "Ground 061" | https://ambientcg.com/a/Ground061 | CC0 | Sized to 1024. Pulled to dark wet sand 110,96,74 (our pick, darker than the dry sand to come). Very calm colour, faint ripples kept and lifted a little (contrast 1.5, normal 1.2). Roughness mean 0.35 for the wet sheen. |
| shore_stone | ambientCG "Rock 030" | https://ambientcg.com/a/Rock030 | CC0 | Sized to 512. Pulled to grey-brown 118,112,102. Fine noise softened 60 percent, white veins soft-clipped (despeckle 2.0), contrast capped at 9 percent. Normal 0.85. Roughness mean 0.72. |
| fish_skin | Ours, procedural: `art/scripts/fish_skin.py` | (none) | Ours | Overlapping scales from a height field: 12 by 6 scales per tile, each tilted up to its free edge. Normal map from the height, creases as AO, low roughness (mean 0.30) for a wet look. Colour is neutral on purpose, so the fish keep their vertex colours. The colour map is a silver-grey 150,156,150 version for anything that wants scales without vertex colours. |
| forest_floor | Poly Haven "Forrest Ground 03" (`forrest_ground_03`, their spelling) | https://polyhaven.com/a/forrest_ground_03 | CC0 | Sized to 1024. Pulled to forest floor 92,72,48. Fine noise softened 60 percent, large blotches flattened 60 percent, brightness variation capped at 9 percent (7.7 after), hue variation cut to 30 percent. Normal 0.7. Roughness mean 0.90. |
| lake_mud | Poly Haven "Brown Mud" (`brown_mud`) | https://polyhaven.com/a/brown_mud | CC0 | Sized to 1024. Pulled to dark olive brown 70,62,46. Fine noise softened 70 percent, blotches flattened 60 percent, brightness variation capped at 7 percent, hue variation cut to 20 percent. Normal 0.6. Roughness mean 0.60. |
| footpath_gravel | Poly Haven "Gravel Floor 02" (`gravel_floor_02`) | https://polyhaven.com/a/gravel_floor_02 | CC0 | Sized to 1024. Pulled to grey-brown 140,128,108. Fine noise softened 60 percent, blotches flattened 60 percent, pale stones soft-clipped (despeckle 2.0), brightness variation capped at 8 percent. Normal 0.8. Roughness mean 0.88. |
| shore_sand | ambientCG "Ground 060" | https://ambientcg.com/a/Ground060 | CC0 | Sized to 1024. Pulled to warm pale sand 186,170,128. Very calm (brightness variation 1.6 percent), blotches flattened 60 percent, hue variation cut to 25 percent. Normal 0.6 so the pock marks stay soft. Roughness mean 0.90. |
| deep_bed | Poly Haven "Dense Sand" (`dense_sand`) | https://polyhaven.com/a/dense_sand | CC0 | Sized to 1024. Pulled to very dark green-grey 40,46,40. Fine noise softened 80 percent, blotches flattened 70 percent, brightness variation 3 percent, hue variation cut to 15 percent. Normal 0.5. Roughness mean 0.70. |
| bark | ambientCG "Bark 012" | https://ambientcg.com/a/Bark012 | CC0 | Sized to 512. Pulled to pine bark 104,82,62. Blotches flattened by half, brightness variation capped at 14 percent (the furrows need it), hue variation cut to a quarter. Normal at full strength. Roughness mean 0.90. Furrows run along V. |
| leaf_needle | Ours, procedural: `gen_leaf_needle` in `art/scripts/texture_pipeline.py` | (none) | Ours | Three layers of soft leaf shapes laid in sprays, back to front; lower layers darker, gaps in shade, big light and dark masses on top. Normal from the height, shade as AO, roughness mean 0.80 with the leaf tops a little glossier. Near-grey on purpose, so the canopy keeps its vertex colours. The colour map is a pine green 62,92,48 version. |
| tin_roof | Poly Haven "Corrugated Iron" (`corrugated_iron`) plus our rust runs | https://polyhaven.com/a/corrugated_iron | CC0, rust ours | Sized to 512. Pulled to galvanised grey 150,152,150. Half of the scan's AO baked in so the ribs still read when the normal map is far away. Blotches flattened 70 percent. Rust runs added by code down V: brown 124,78,48 in the colour map, darker in the neutral map, rougher in the roughness map. Roughness mean 0.50. |
| painted_wood | ambientCG "Painted Wood 008A" plus our boards and wear | https://ambientcg.com/a/PaintedWood008A | CC0, boards ours | Turned a quarter so the grain runs along V, sized to 512. Pulled to off-white paint 196,190,176. Cut into four boards by code: each board gets its own stretch of the scan and a small tone step, a dark groove sits between boards, and the paint wears thin beside the grooves (darker, rougher, grain showing; toward bare wood 158,146,128 in the colour map). Roughness mean 0.60. |
| aluminium | ambientCG "Metal 009" plus our dents | https://ambientcg.com/a/Metal009 | CC0, dents ours | Sized to 512. Pulled to pale aluminium 176,180,184. Very calm colour (2 percent). A few shallow dents and a faint wave pressed into the normal map by code. Roughness mean 0.42, the brushed lines kept. Metalness map from the scan, mean 0.90, a touch lower where the surface is rougher. |

## Candidates tried and set aside

| Family | Candidate | Why not |
|---|---|---|
| weathered_plank | Poly Haven `weathered_planks` (https://polyhaven.com/a/weathered_planks) | Good weathering, but nine narrow boards per tile and a few pale chips that repeat. Second choice. |
| weathered_plank | ambientCG Planks021 (https://ambientcg.com/a/Planks021) | Clean new decking with big grain. Reads well but not weathered. Keep in mind for "rough timber" or painted wood. |
| weathered_plank | ambientCG Planks039, Wood080, Planks012 | Planks039: three huge stained boards, the stains repeat. Wood080: boards too small, turns to noise. Planks012: staggered floor pattern, reads as parquet. |
| rope | ambientCG Rope003, Rope002 | Finer fibre noise and a green cast in the grooves (003); steel cable look (002). |
| canvas | ambientCG Fabric061, Fabric030 | 061: a regular coarse weave that will shimmer at distance. 030: no visible structure once pulled to the palette. |
| meadow_grass | ambientCG Grass001, Grass005 | 001: dark tufts make it mossy and blotchy. 005: a mown lawn, no blades to read. |
| wet_sand | ambientCG Ground094A, Ground054 | 094A: strong tide ripples, handsome but busy in a narrow band (good later for a beach). 054: pocked and glinty, the bobber gets lost. |
| shore_stone | ambientCG Rock020, Rock058 | 020: smoother and calmer, a fair second choice for rounded stones, but large blotches repeat on flat ground. 058: orange veins. |
| forest_floor | Poly Haven `forest_leaves_03` (https://polyhaven.com/a/forest_leaves_03) | Good leaf litter and the second choice (use it for a broadleaf wood), but its normal map is busy and the home lake is a pine lake. |
| forest_floor | Poly Haven `forest_ground_04`, ambientCG Ground023 | 04: twigs and clods that repeat. 023: big pale leaf blotches. |
| lake_mud | Poly Haven `dirt`, ambientCG Ground036 | `dirt`: so calm that nothing is left but soft blotches that repeat. 036: straw and twigs, glinty roughness. |
| footpath_gravel | ambientCG Gravel041, Gravel040 | 041: handsome round pebbles and the second choice, but bigger and busier at 10 studs (keep in mind for creek pebble). 040: mixed sharp stones, noisy. |
| footpath_gravel | Poly Haven `gravelly_sand` (https://polyhaven.com/a/gravelly_sand) | More dirt than gravel, and a wave pattern shows when it repeats. |
| shore_sand | Poly Haven `aerial_beach_01`, ambientCG Ground059, Ground033 | `aerial_beach_01`: fine wind ripples in the normal map, the second choice, but faint bands show when it repeats. 059: hard-edged ripple plates. 033: dark blotches. |
| deep_bed | ambientCG Ground099, Poly Haven `damp_sand` | 099: soft bands that repeat. `damp_sand`: fine, a little more relief than a deep bed needs; the second choice. |
| bark | ambientCG Bark014, Poly Haven `bark_willow_02`, `chinese_cedar_bark` | 014: flatter, with knots that repeat. `bark_willow_02`: strong grain but vertical stripes repeat. `chinese_cedar_bark`: one big knot per tile. |
| leaf_needle | ambientCG Moss002, Moss004 | Moss cushions: soft round lumps and no leaf shapes. Judged on the maps only, not rendered on a canopy. |
| tin_roof | Poly Haven `worn_corrugated_iron`, `corrugated_iron_02`, ambientCG CorrugatedSteel005 | `worn_corrugated_iron`: flaking paint all over, far more than a little rust, and busy. `corrugated_iron_02`: ribs too fine, they would shimmer. 005: stain blotches that repeat. |
| painted_wood | ambientCG Planks010, PaintedWood008B | Planks010: fifteen narrow lap boards per tile and one butt joint that repeats. 008B: paint mostly gone, reads as bare stained wood. |
| painted_wood | Poly Haven `distressed_painted_planks`, `white_planks_clean` | `distressed`: one large peeled patch that repeats. `white_planks_clean`: no wear at all. |
| aluminium | ambientCG Metal011, Metal051B | 011: smudges that repeat as a row of marks. 051B: hammered facets, not a boat skin. |

## Hero sets (maps baked for one model)

- DockHero (`art/scripts/dock_hero.py`, 11/27/2026): Poly Haven "Wood Planks Grey" (`wood_planks_grey`, https://polyhaven.com/a/wood_planks_grey, CC0), the same scan as weathered_plank, used raw at 1K: one scanned board per deck board, pulled to dock timber 122,104,86, with posts and stringers from the same scan pulled darker (94,80,66). Nail heads, worn edges, end grain, the wet band on the posts, rope, iron, zinc and the lantern glass are our own code. The baked atlas is embedded in `art/models/DockHero.glb`.
