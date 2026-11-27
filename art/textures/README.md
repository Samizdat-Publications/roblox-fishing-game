# Material families

The first seven Real-ish material families (N0, 11/27/2026). Each folder holds the maps for one Roblox `MaterialVariant`. Where each came from is in [SOURCES.md](SOURCES.md). The look is judged on the sheet:

![Material sheet](sheet-n0.png)

Rows on the sheet: sphere with the colour map; the thing the family is for; the same thing 30 studs away with a bobber for scale; sphere with the neutral map times a sample colour; the thing with the neutral map times a second colour.

## Files per family

| File | What it is | Goes in |
|---|---|---|
| `<family>_color.png` | Final colour, pulled to the palette | `ColorMap`, with the part colour white (or a terrain slot with a white tint) |
| `<family>_neutral.png` | Grey copy, mean 0.80 | `ColorMap` on meshes that keep their vertex colours (Layer B), or a terrain slot coloured by its tint |
| `<family>_normal.png` | Normal map, OpenGL | `NormalMap` |
| `<family>_rough.png` | Roughness, white is rough | `RoughnessMap` |
| `<family>_tile3.jpg` | 3 by 3 tiled preview, colour left and neutral right | Seam check only, do not upload |
| `<family>.json` | Source, settings and measured numbers | Record only |

Use the colour map or the neutral map, not both: the part's colour multiplies whichever one is in `ColorMap`. The neutral map darkens the part's own colour by about a fifth, so pick vertex colours a touch lighter than the colour you want to see.

## Asset ids

Uploads are permanent, so each map goes up once and its id is written here.

| Family | Kind | Size | Studs per tile | Colour id | Normal id | Rough id | Neutral id |
|---|---|---|---|---|---|---|---|
| weathered_plank | prop | 512 | 8 | 137142375088861 | 105890202267685 | 117284029037170 | 80741058595109 |
| rope | prop | 512 | 2 | n/a | 95650373015874 | 105660536950018 | 135935120374206 |
| canvas | prop | 512 | 3 | n/a | 86505477991598 | 124626230291622 | 118947593138172 |
| meadow_grass | terrain | 1024 | 16 | 101241396464400 | 99613738695349 | 138017832448140 | n/a |
| wet_sand | terrain | 1024 | 16 | 135696601239441 | 138574749553165 | 96601916018034 | n/a |
| shore_stone | prop and terrain | 512 | 8 (12 on terrain) | 77321670500551 | 111500464538293 | 80673120127218 | 89874330433856 |
| fish_skin | prop | 512 | 1 | n/a | 81839350043697 | 86528045576678 | 71877620575284 |

n/a means that map was not uploaded (not needed for that family). Colour id is the palette colour map; rope, canvas and fish_skin use the neutral map only. Machine-readable copy: `ids.json`.

## Notes for whoever applies them

- **Studs per tile** are starting values from the sheet, where one unit is one stud. weathered_plank at 8 gives boards about 1.3 studs wide. fish_skin at 1 gives scales about a sixth of a stud; go to 0.75 for small fish if the scales look too big on them.
- **weathered_plank**: the boards run along the map's V direction. On a flat part check which way they run and turn the part or use `MaterialPattern` if they run the wrong way.
- **fish_skin**: the free edge of each scale points toward the map's -U. Family materials are box-mapped on meshes, so check the first fish in Studio to see which way the scales lie.
- **meadow_grass**: the colour map's mean is exactly 104,122,62 with little hue variation, so grass blades that take their colour from it come out the meadow green. For autumn, use the neutral map with the slot tint.
- **wet_sand**: roughness 0.35 is what makes it read as wet. If it glares at noon, raise it with `python art/scripts/texture_pipeline.py wet_sand --set rough_mean=0.45`.
- The mean colour of every colour map is its palette target to within one step of 255. The neutral maps are pure grey with a mean of 0.80.

## Rebuild

```powershell
cd "C:\Users\stewa\Documents\Claude\Roblox"; python art\scripts\texture_pipeline.py --all --fetch; python art\scripts\material_sheet.py
```

One family: `python art\scripts\texture_pipeline.py weathered_plank`. Try another source: `python art\scripts\texture_pipeline.py --candidates weathered_plank` (writes to `artifacts\textures_candidates\`). Add a family: add it to `art\scripts\texture_families.json` (source, size, target colour, studs per tile) and run it. The sheet needs Blender 5.1 at its default install path, or set the `BLENDER` environment variable.
