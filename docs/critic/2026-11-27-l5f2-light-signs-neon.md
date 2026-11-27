# Critic: l5f2-light-signs (review, gemini-4-neon)

Date: 2026-11-27 03:24. Rubric: `look`.

Files shown:
- `01-dock-dawn.jpg`
- `02-dock-golden.jpg`
- `03-dockend-noon.jpg`
- `04-dockend-night.jpg`
- `05-weedbed-golden.jpg`
- `06-logs-dawn.jpg`
- `07-overview-golden.jpg`
- `08-stands-noon.jpg`
- `09-riffle-dawn.jpg`
- `10-pool-golden.jpg`
- `11-gate-noon.jpg`
- `12-pool-night.jpg`

**Score: 6.9/10**

Strong lighting progress with distinct cool lavender dawns, warm golden hours, and clean noon skies, plus recognizable fishing habitats like the weedbed and sunken logs. The main holdbacks are lifeless night water with harsh lamp blobs, low-contrast and clipped floating signs, and overly straight, park-like shorelines around the pond and creek.

| Point | Score |
|---|---|
| composition | 6.5 |
| light | 7.5 |
| water | 6.5 |
| mood | 7 |
| want_to_fish | 7.5 |
| phone_readability | 6 |
| broken_or_ugly | 7 |

Top fixes:
1. Bring night water to life (04-dockend-night.jpg, 12-pool-night.jpg): angle moonlight onto the water and raise Lighting.OutdoorAmbient and Terrain.WaterReflectance slightly so waves catch silver highlights instead of turning pitch black, dim and warm the dock and pool PointLights to remove the flat greenish puddle glow, and add a subtle luminous tip to the bobber at night.
2. Fix BillboardGui signs for phone readability and depth (01-dock-dawn.jpg, 06-logs-dawn.jpg, 08-stands-noon.jpg): change Bait and Tackle text from dark blue to bright light-blue or white for high contrast, add a dark pill background behind Your Pond, switch to stud-based Size with a MaxDistance around 60 to 80 studs, and disable AlwaysOnTop so signs do not clip off-screen up close or cut sharply through dawn mist.
3. Naturalize the pond perimeter and creek banks (07-overview-golden.jpg, 09-riffle-dawn.jpg, 10-pool-golden.jpg): break up the racetrack-like path around the main pond and the bare straight sand slope at the creek pool by painting irregular grass and mud patches over the sand, placing shore rocks and reeds along the bank, adding shallow boulders and foam decals to the creek riffle, and thickening the tree clumps on the bare distant hills.

Strengths:
- Cool lavender dawn (01-dock-dawn.jpg, 06-logs-dawn.jpg) and warm peachy golden hour (02-dock-golden.jpg, 05-weedbed-golden.jpg) now have clearly distinct, memorable moods, and noon (03-dockend-noon.jpg) is clean with no orange blotches.
- Fishing spots read like real fish-holding structure: the lily-pad weedbed (05-weedbed-golden.jpg), partially submerged logs (06-logs-dawn.jpg), and rocky pine mound (09-riffle-dawn.jpg) immediately make you want to pick a bait and cast.
- The round stone-ringed Your Pond with visible swimming fish (07-overview-golden.jpg, 08-stands-noon.jpg) and the chunky wooden dock planks add genuine charm.
- The open Cedar Creek archway (11-gate-noon.jpg) reads cleanly without awkward gate posts blocking the path.

Broken or ugly:
- Dark horizontal striping or z-fighting artifacts appear on the brown vertical posts of both stalls in 01-dock-dawn.jpg and 02-dock-golden.jpg.
- Cattails grow directly in front of the green chalkboard in 08-stands-noon.jpg, blocking the writing.
- AlwaysOnTop BillboardGui signs clip off the left and right edges when near the stalls (01-dock-dawn.jpg, 02-dock-golden.jpg), and a stray green letter clips at the far-left edge in 06-logs-dawn.jpg.
- Bait and Tackle uses low-contrast dark blue text on a dark translucent pill (08-stands-noon.jpg), which will be hard to read on a small phone.
- Night water in 04-dockend-night.jpg and 12-pool-night.jpg looks flat and pitch black except for harsh greenish circular light blobs from nearby lamps.
- The creek in 09-riffle-dawn.jpg reads like a flat straight blue ribbon in a uniform trench, and the right shoreline in 10-pool-golden.jpg is a bare, artificial-looking sand ramp.

Action taken: Not yet: night water and bobber, sign fade distance, creek pool bank, lake path width. Logged in PROGRESS as the next asks.
