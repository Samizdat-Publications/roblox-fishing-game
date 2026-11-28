# Critic: n1-round4-lake (review, gemini-4-neon)

Date: 2026-11-27 19:17. Rubric: `look`.

Files shown:
- `01-dock-dawn.jpg`
- `02-dock-golden.jpg`
- `03-dockend-noon.jpg`
- `04-dockend-night.jpg`
- `05-weedbed-golden.jpg`
- `06-logs-dawn.jpg`
- `07-overview-golden.jpg`
- `08-stands-noon.jpg`

**Score: 7.3/10**

This already feels like a real, memorable lake with distinct fishing structure - weedbeds, submerged logs, a weathered timber dock, and a channel opening to deeper water - and it nails the Real-ish chunky-shapes-plus-true-materials look, especially in the dawn and golden-hour shoreline views. What holds it back right now is uneven Lighting and Atmosphere across times of day (a flat, dreary overcast noon and an unnatural bright-blue night sky with a dark horizon band), plus a few harsh underwater terrain seams and tiny unreadable signs.

| Point | Score |
|---|---|
| composition | 8 |
| light | 6 |
| water | 7 |
| mood | 8 |
| want_to_fish | 8.5 |
| phone_readability | 7 |
| broken_or_ugly | 6.5 |

Top fixes:
1. Rework the noon and night Lighting and Atmosphere presets: for noon (03-dockend-noon.jpg, 08-stands-noon.jpg), replace the flat grey Sky with a crisp daylight sky and clouds, raise Lighting.Brightness (around 2.5 to 3) with clear GlobalShadows, and lower Atmosphere.Density/Haze so sun hits the water and dock; for night (04-dockend-night.jpg), switch to a dark starry Sky and lower Atmosphere.Color, Atmosphere.Decay, and OutdoorAmbient so the sky is dark overhead and the inverted dark horizon band disappears.
2. Smooth the underwater terrain and bridge channel cuts: use Terrain Smooth and Erode across the lakebed to remove the straight diagonal bands visible through the water in 07-overview-golden.jpg and the abrupt horizontal light/depth seam cutting across the foreground water in 04-dockend-night.jpg, and dress the boxy vertical channel banks under the bridge (03-dockend-noon.jpg) with rocks, timber retaining walls, or gentler slopes.
3. Bring true low-angle golden sunlight to ground level and tighten shoreline/signage polish: in golden hour (02-dock-golden.jpg), adjust ClockTime or GeographicLatitude and boost warm ColorShift_Top plus subtle SunRaysEffect so warm directional light rakes across the stalls and grass instead of flat mauve shadow; tuck rocks or wet-sand/grass clumps around the flat-bottomed cattails sitting on dry sand (05-weedbed-golden.jpg), and enlarge the green chalkboard text or move tips to an interactable UI so it reads clearly on desktop and phone (08-stands-noon.jpg).

Strengths:
- Strong fishing readability: distinct real-world spots like the cattail-and-lilypad cove in 05-weedbed-golden.jpg, the submerged logs in 06-logs-dawn.jpg, the buoyed channel in 03-dockend-noon.jpg, and the numbered dock pilings in 08-stands-noon.jpg immediately make you want to pick a bait and cast.
- Great Real-ish material work on the dock and stalls: the weathered, varied planks, chunky log bollards, metal cleats, and stained wood siding in 01-dock-dawn.jpg and 08-stands-noon.jpg read authentically as timber without needing high-poly clutter.
- Inviting framing and sightlines: walking down the gravel path between the two stands in 01-dock-dawn.jpg frames the pier, distant bridge, and mountain peak cleanly, and the misty lavender cove in 06-logs-dawn.jpg and warm reflections in 05-weedbed-golden.jpg have genuine calm lake mood.
- Thoughtful atmospheric touches like glowing dock lanterns at dusk (02-dock-golden.jpg), gentle fireflies and a lit buoy at night (04-dockend-night.jpg), and multi-lake depth visible from the overview (07-overview-golden.jpg).

Broken or ugly:
- 04-dockend-night.jpg: A sharp, straight horizontal band/seam cuts all the way across the lower third of the water, and the night sky has an unnatural inverted gradient (bright royal blue overhead with a darker band hugging the horizon).
- 07-overview-golden.jpg: Straight pinkish-grey diagonal stripes/seams are visible across the water in both the main lake and the upper lake, reading like unsmoothed underwater terrain strips.
- 03-dockend-noon.jpg: The channel opening under the bridge has stark, blocky rectangular terrain walls with grass overhanging sheer vertical cuts.
- 05-weedbed-golden.jpg: Several foreground cattails on the left stick straight out of dry sand with flat rectangular leaf edges and no base clump, and the Boat Slips sign on the right is partially blocked by reeds.
- 08-stands-noon.jpg: A lone wooden piling on the left shore sits embedded in dry sand away from the water, and the green chalkboard (Tips of the Lake) text is too small and low-contrast to read from the dock.
- 06-logs-dawn.jpg: A dark tree branch pokes awkwardly into the upper-right corner of the frame, and the fallen logs have perfectly flat machine-cut cylinder ends that clash slightly with the natural cove.

Action taken: (fill in: what we changed, or why we didn't)
