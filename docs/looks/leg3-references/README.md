# Leg 3 Visual Reference Pack (N1 to N7)

Generated 11/27/2026 to complement `docs/looks/realish/` (which only covers the 11/26 home lake and old open-ditch creek stills). Use these references alongside the RGB palette table in `docs/superpowers/plans/2026-11-27-leg-3.md` and `Shared/UIStyle.luau`.

Every image targets the **Real-ish Roblox house style**: chunky, simple 3D shapes with realistic PBR materials (`MaterialVariant` families and `SurfaceAppearance` hero sets), warm atmospheric light, and high phone readability.

---

## Reference Map by Milestone & Critic Shot Set

| File | Milestone(s) | Shot Set(s) | Primary Purpose & Targets |
| :--- | :--- | :--- | :--- |
| `n2-ui-field-guide-catch-card.jpg` | `N2` | `Set U` (6 screens) | Field Guide and Tackle Box UI (`UIStyle.luau`). Cream paper (`236,226,200`), espresso ink (`38,34,30`), ruled catch plate with hanging brass weight tag (`176,136,72`), stamped rarity seal (`250,175,40` Legendary), canvas (`200,184,146`) and leather (`92,56,34`) tackle box panels, wood-and-brass fight bar (`58,108,138` water track, `150,178,118` sage zone), 4 px square-ish corners, phone-readable contrast. |
| `n3-cedar-creek-dappled-riffle.jpg` | `N3` | `Set A` (creek 09-12) | Enclosed woodland stream replacing the 90-degree voxel pool and straight ditch flagged in `n1-round2`. Closed cedar/pine canopy, dappled morning light, clear tea water (`64,84,58`) over river pebbles, mossy slate boulders (`70,78,84` and `78,104,52`), cut banks with roots and ferns, white-water riffle, natural rounded pool with fallen log, and wooden post lanterns replacing Neon-ball poles. |
| `n4-cedar-canoe-and-boathouse-golden.jpg` | `N4` | `Set C` (boats) | Cedar-strip canoe (varnished cedar ribs, cane seats, wooden paddles) and re-skinned off-white Inflatable Dinghy (`226,220,204` hypalon tubes, slatted wood floor, tiller outboard) moored at the weathered silver-brown dock slips (`122,104,86`), open tin-roof Boathouse shed with canoe rack, and sales mooring with painted wooden price boards (`350`, `1,200`) at Golden Hour. |
| `n5-big-lake-deepv-buoy-line-dusk.jpg` | `N5` | `Set B` & `Set C` | 16-stud white gelcoat Deep-V (`235,235,230`) with center console, windshield, port/starboard running lights, stern light, and console fish finder crossing red (`178,44,36`) and green (`34,110,70`) navigation bell buoys into dark navy Blue Water (`16,38,66`) with rolling swells, gulls, rocky granite headlands, and a distant island beacon at Blue Hour / Dusk. |
| `n6-granite-island-bent-pine-aurora.jpg` | `N6` | `Set D` (island) | First Granite Island recipe: pink granite (`176,142,132`), sage and rust-orange lichen (`150,160,120` and `204,130,48`), juniper (`52,84,66`), red heath (`120,54,48`), cold dark water (`22,60,84`), weathered landing pier with beacon lantern, single wind-bent pine landmark silhouette, and green/violet Aurora Borealis ribbons over a clear navy (never black) sky. |
| `n1-n7-home-lake-shoreline-and-trophy-case.jpg` | `N1` & `N7` | `Set A` (lake) | Voxel-seam-free shoreline transitions (`BankDress.luau` / `Scatter.luau` placing ferns, pebbles, and cattails over `FootpathGravel` and `MeadowGrass` borders), dark wet sand edge, mossy stone-rimmed Home Pond with visible 3D fish, and the `N7` glass-fronted timber Trophy Case shed lit warmly inside (concept shows a 3x3 layout; `N7` places 12 mounts inside the case). |

---

## How `Opus 5.5`, `fable-advisor`, and `modeler` Should Use This Pack

1. **Unpack into `docs/looks/leg3-references/`** in the main repo checkout (do not replace `docs/looks/realish/`, which stays the time-of-day baseline).
2. **`modeler` (Fable):** Reference `n2`, `n4`, `n5`, and `n6` for silhouette proportions, PBR surface contrast, and material splits (wood vs. canvas vs. metal vs. gelcoat vs. granite/lichen) before generating hero sets and panel nine-slices.
3. **`fable-advisor`:** Compare Studio captures for `Set U`, `Set A` creek, `Set B`, `Set C`, and `Set D` against these target frames during each milestone's look gate, alongside the critic median score and `tools/shots/audit.luau` counts.
4. **Remember the house constraint:** These images are visual targets for light, palette, silhouettes, and composition. Never copy photorealistic fine clutter or add high-poly foliage that breaks the frame budgets in `docs/PERF.md`.
