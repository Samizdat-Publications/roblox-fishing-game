# Prime shots (set P)

Stewart, 11/28/2026: "Find early on a few very scenic places to take camera shots with good quality (the correct) lenses so we can get a steady shot of improvements from the same shots over time, and add new prime shots as we build new areas or features. Will improve the quality of the making of artifact."

Set P is a set of fixed beauty shots for the making-of page. They are re-taken at every milestone from the same camera, lens and time of day, so the page shows the same frame getting better. They are not critic test shots: `score` refuses set P. Picked by the Fable advisor on 11/28/2026 from the source numbers and existing frames; each gets one sighting pass in Studio (nudge at most 3 studs) and is then frozen. Shots marked `pending` are placeholders until their area is built.

## Capture rules

- Clear weather held on the server, recorded per shot.
- Desktop tier only: no Device Simulator, touch false, quality level 21.
- HUD, top bar and cursor hidden; the avatar hidden unless the shot is about one.
- Capture unscaled, PNG or JPEG 95; centre crop to 16:9 and resize (Lanczos) to 1280 x 720; keep the raw.
- One exposure, no retouching; the same clock, eye, look and fov at every milestone.
- `fov` is the vertical angle of the delivered 16:9 frame; `lens_mm = 10.125 / tan(fov / 2)` (35 mm full-frame equivalent). The camera's FieldOfView is set so the 16:9 crop has that angle whatever the window shape: `cropH = min(H, W * 9 / 16)`, `FieldOfView = 2 * atan(tan(fov / 2) * H / cropH)`.
- If the top bar cannot be hidden, shrink `cropH` by 120 px (same formula).
- A wide 2.39:1 banner, when wanted, is cut from the 16:9 master.

## Harness problems found while picking them

1. One global lens: every shot used FieldOfView 70 (vertical), which at 16:9 is about a 14.5 mm lens.
2. The pin may fight the look: the capture pin re-applied the plain time-of-day preset every frame, while LookDirector writes the graded and area look at 10 Hz, so many rendered frames may have been ungraded (read from source, to be confirmed in Studio). If so, sets A and B scores are rebaselined after the fix.
3. The top bar and cursor were in every frame.
4. The avatar was in some frames.
5. Captures were soft (1280 wide, JPEG 85) and the viewport shape drifted between runs, which changed the framing.

## The shots

| id | Place | Clock | Lens | What |
|---|---|---|---|---|
| p01-lake-high-golden | lake | 17.4 | 24 mm (fov 45.7) | The only high view: pond, stands, dock, the Big Lake band |
| p02-dock-dawn | lake | 6.4 | 28 mm (39.8) | Down the planks to the lit dock-end lanterns in dawn mist |
| p03-weedbed-golden | lake | 17.4 | 35 mm (32.3) | Low among the cattails, across the weed bed |
| p04-channel-golden-tele | lake | 17.4 | 85 mm (13.6) | The buoy, the footbridge and the Big Lake through the gap |
| p05-sellstand-morning | lake | 9.6 | 50 mm (22.9) | The Sell Fish stand, three-quarter view, neutral daylight |
| p06-stands-bluehour | lake | 18.7 | 28 mm (39.8) | Both stands and their lanterns at blue hour |
| p07-riffle-morning | creek | 9.6 | 35 mm (32.3) | Up the riffle between the frame cedars |
| p08-pool-golden | creek | 17.4 | 28 mm (39.8) | The deep pool, mossy log, lantern |
| p09-boathouse-canoe-golden | lake | 17.4 | 35 mm (32.3) | Pending N4: the slips, the canoe and the boathouse |
| p10-buoyline-dusk | biglake | 18.7 | 85 mm (13.6) | Pending N5: over the buoy line to the island beacon |
| p11-island-aurora | biglake | 22.0 | 24 mm (45.7) | Pending N6: the bent pine and beacon under the aurora |
| p12-trophy-case-bluehour | lake | 18.7 | 35 mm (32.3) | Pending N7: across the pond to the lit trophy case |

## Entries (for tools/shots/shots.json)

```json
[
  {"id": "p01-lake-high-golden", "set": "P", "group": "lake", "place": "lake", "clock": 17.4, "eye": [78, 46, 172], "look": [7, 0, 13], "fov": 45.7, "lens_mm": 24, "what": "The only high view: pond bottom right, stands lower left, dock to centre, Big Lake band under a 19 percent sky", "why": "One frame where N1 ground and trees, N4 boathouse, N5 Big Lake and the N6 island silhouette all appear. Sun 48 degrees left, out of frame."},
  {"id": "p02-dock-dawn", "set": "P", "group": "lake", "place": "lake", "clock": 6.4, "eye": [-2.4, 6, 76], "look": [2, 3.4, 30], "fov": 39.8, "lens_mm": 28, "what": "Down the planks to the lit dock-end lanterns in dawn mist, slips on the right", "why": "Plank and nail detail under raking light, mirror water, mist; canoe and dinghy arrive on the right in N4. Lanterns are on before 6.5."},
  {"id": "p03-weedbed-golden", "set": "P", "group": "lake", "place": "lake", "clock": 17.4, "eye": [-94, 4.6, 87], "look": [-88, 1.5, 27], "fov": 32.3, "lens_mm": 35, "what": "Low among the cattails, north across the weed bed", "why": "Shot 05's bank at kneeling height: bank kit, wet band, reeds, lilies, far treeline and haze. Side-back light from the left."},
  {"id": "p04-channel-golden-tele", "set": "P", "group": "lake", "place": "lake", "clock": 17.4, "eye": [0, 6, 37], "look": [0, 3.5, -85], "fov": 13.6, "lens_mm": 85, "what": "From the dock end: the red buoy, the footbridge, the Big Lake and ridges through the gap", "why": "Compressed layers; today's bare dome behind the bridge becomes headlands and hazed ridgelines in N5. Shot 03's eye and line."},
  {"id": "p05-sellstand-morning", "set": "P", "group": "lake", "place": "lake", "clock": 9.6, "eye": [-3, 6, 66], "look": [-18, 6.2, 96], "fov": 22.9, "lens_mm": 50, "what": "Sell Fish stand, three-quarter view from the dock", "why": "Neutral daylight material reference: planks, awning cloth, painted board, roof. Sun behind left at 50 degrees."},
  {"id": "p06-stands-bluehour", "set": "P", "group": "lake", "place": "lake", "clock": 18.7, "eye": [0, 6, 50], "look": [0, 4.2, 96], "fov": 39.8, "lens_mm": 28, "what": "Both stands and their lanterns, symmetrical, from the dock at blue hour", "why": "Lantern light and shadows, lit sign boards, navy sky. Shot 08's eye."},
  {"id": "p07-riffle-morning", "set": "P", "group": "creek", "place": "creek", "clock": 9.6, "eye": [-230.5, 3.4, 19], "look": [-230, 0.5, 70], "fov": 32.3, "lens_mm": 35, "what": "Up the riffle between the two frame cedars, foam at the bottom edge", "why": "Dappled light, white water, moss, pebbles under clear water."},
  {"id": "p08-pool-golden", "set": "P", "group": "creek", "place": "creek", "clock": 17.4, "eye": [-213, 5, -5], "look": [-225, 2.4, -53], "fov": 39.8, "lens_mm": 28, "what": "The deep pool: mossy log left third, lantern right, tree shadows raking across", "why": "Enclosed canopy, dark water, cut banks and roots."},
  {"id": "p09-boathouse-canoe-golden", "set": "P", "group": "boats", "place": "lake", "pending": "N4", "clock": 17.4, "eye": [6, 5.5, 39], "look": [15, 1.5, 62], "fov": 32.3, "lens_mm": 35, "what": "From the dock end down the slips: canoe in slip 1, boathouse and tackle shop behind", "why": "Varnished cedar in three-quarter light. Finalise when the boathouse is placed."},
  {"id": "p10-buoyline-dusk", "set": "P", "group": "biglake", "place": "biglake", "pending": "N5", "clock": 18.7, "eye": [38, 3, -230], "look": [100, 4, -950], "fov": 13.6, "lens_mm": 85, "what": "Boat height, north over the buoy line to the island beacon", "why": "Navy swell, real buoys, beacon on the horizon. Put the bell buoy on the left third."},
  {"id": "p11-island-aurora", "set": "P", "group": "island", "place": "biglake", "pending": "N6", "clock": 22.0, "eye": [55, 3, -860], "look": [100, 28, -955], "fov": 45.7, "lens_mm": 24, "what": "From a boat: bent pine and beacon under the aurora, horizon 78 percent down", "why": "Sky event plus granite and reflections. Needs a forced-aurora debug switch and streaming around the eye."},
  {"id": "p12-trophy-case-bluehour", "set": "P", "group": "lake", "place": "lake", "pending": "N7", "clock": 18.7, "eye": [41, 5.2, 94], "look": [50, 5, 118], "fov": 32.3, "lens_mm": 35, "what": "Across the pond to the lit trophy case", "why": "Glass, brass and lantern glow in the pond. Needs the twelve-fish test save loaded."}
]
```

Note: p07 and p08 use the creek eyes of round 3. If the creek cameras move again in N3 (Neon's Pass 1), sight these two again before freezing.
