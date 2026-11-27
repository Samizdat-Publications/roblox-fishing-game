# Texture sources

Every map in this folder comes from a public domain (CC0) photo scan or from our own code. Nothing here needs credit, but we keep the list so any map can be traced and rebuilt.

- ambientCG licence: CC0 1.0, https://docs.ambientcg.com/license/
- Poly Haven licence: CC0 1.0, https://polyhaven.com/license
- Raw downloads are not in the repo. They live in `artifacts/textures_src/` (git-ignored). `python art/scripts/texture_pipeline.py --all --fetch` downloads any that are missing, from the URLs in `art/scripts/texture_families.json`.
- Downloaded 11/27/2026, the 1K JPG sets.

## What the pipeline does to every source

`art/scripts/texture_pipeline.py`, same steps for every family: checks that the scan tiles (and fixes it with an offset-and-blend if it does not, or if it was cropped), sizes it (1024 terrain, 512 props), multiplies a little of the scan's AO into the colour, softens the fine noise and flattens large blotches, pulls the mean colour exactly onto the palette target while capping brightness and hue variation, writes a grey "neutral" copy with a mean of 0.80, softens and re-normalizes the normal map (OpenGL), and moves the roughness to the family's target. The exact numbers for each family are in its `<family>.json`.

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

## Hero sets (maps baked for one model)

- DockHero (`art/scripts/dock_hero.py`, 11/27/2026): Poly Haven "Wood Planks Grey" (`wood_planks_grey`, https://polyhaven.com/a/wood_planks_grey, CC0), the same scan as weathered_plank, used raw at 1K: one scanned board per deck board, pulled to dock timber 122,104,86, with posts and stringers from the same scan pulled darker (94,80,66). Nail heads, worn edges, end grain, the wet band on the posts, rope, iron, zinc and the lantern glass are our own code. The baked atlas is embedded in `art/models/DockHero.glb`.
