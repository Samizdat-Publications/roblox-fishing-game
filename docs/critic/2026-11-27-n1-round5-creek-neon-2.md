# Critic: n1-round5-creek (review, gemini-4-neon)

Date: 2026-11-27 20:09. Rubric: `look`.

Files shown:
- `09-riffle-dawn.jpg`
- `10-pool-golden.jpg`
- `11-gate-noon.jpg`
- `12-pool-night.jpg`

**Score: 6/10**

Cedar Creek already has a warm, memorable atmosphere - especially the golden-hour pool, dawn mist, and night fireflies - and the chunky real-ish art style reads cleanly. However, Roblox Terrain Water reflection/transparency artifacts, dim flat noon lighting, and overly straight bare shorelines currently hold the spots back from feeling like real, inviting places to read the water and fish.

| Point | Score |
|---|---|
| composition | 6 |
| light | 6 |
| water | 4 |
| mood | 7 |
| want_to_fish | 6 |
| phone_readability | 7 |
| broken_or_ugly | 6 |

Top fixes:
1. Tune Terrain Water properties and build out the riffle bed: lower Terrain.WaterReflectance (around 0.25 to 0.4) to remove the blotchy cyan oil-slick patches in 10-pool-golden.jpg and the large flat pale-blue ice-like patches in 12-pool-night.jpg, shift WaterColor to a deeper natural olive-teal/tea tint with WaterTransparency around 0.45 to 0.6, and widen the 09-riffle-dawn.jpg stream while placing submerged river stones and subtle whitewater particle ripples so it reads as a moving stony riffle rather than a mud ditch.
2. Fix Noon lighting and rebalance Night ambient light: in 11-gate-noon.jpg, raise Lighting.Brightness (around 2.5 to 3.5), add a bright daytime skybox with a warm-white sun and crisp GlobalShadows so trees cast real midday shadows instead of looking like dark silhouettes in overcast twilight; in 12-pool-night.jpg, lower OutdoorAmbient and darken the bank sand material so the path does not look pale grey/snowy outside the lantern radius, and add stars to break up the dark horizon band.
3. Break up ruler-straight banks and add fishable structure: sculpt curved, irregular edges along the straight right-hand berm in 10-pool-golden.jpg and 12-pool-night.jpg, cover jagged far-bank voxel cuts and bare grass patches (like the foreground hump in 09-riffle-dawn.jpg) with rocks, ferns, shrubs, and fallen logs/submerged branches that double as real fishing-spot cues, and add denser background treelines to hide the flat empty grass horizon.

Strengths:
- Strong sense of mood and time of day in 10-pool-golden.jpg (warm sun, golden haze, glowing water glints) and 12-pool-night.jpg (cozy lantern glow and fireflies drifting over the pool).
- The chunky real-ish style - wood grain on the Cedar Creek gate and leaning lantern post, sculpted rock outcrop in 09-riffle-dawn.jpg, and crisp tree silhouettes - reads well at a glance and will hold up nicely on both desktop and phone.
- Good natural focal framing in 11-gate-noon.jpg (the gravel path leading through the Cedar Creek wooden archway) and 10-pool-golden.jpg (cattails, lantern, and hills framing the pool).
- Soft lavender-blue dawn fog in 09-riffle-dawn.jpg creates an authentic quiet early-morning creek atmosphere.

Broken or ugly:
- Blotchy cyan contour/oil-slick artifacts on the left side of the water in 10-pool-golden.jpg and huge flat matte pale-blue reflection patches across the pool in 12-pool-night.jpg that look like thin ice or paint.
- 11-gate-noon.jpg is labeled noon but reads as dim, gloomy overcast dusk with near-black pine silhouettes and almost no directional sunlight or ground shadows.
- The stream in 09-riffle-dawn.jpg reads as a narrow straight-walled ditch with an abrupt transition between bare smooth terrain in the foreground and uniform tall Roblox grass on the far bank.
- The right-hand dirt bank in 10-pool-golden.jpg and 12-pool-night.jpg is artificially straight like a man-made canal berm, and the far shoreline shows jagged dark-brown terrain voxel edges.
- The Cedar Creek sign text in 11-gate-noon.jpg is small and low-contrast against the dark wood, which will be hard to read on a small phone screen.

Action taken: (fill in: what we changed, or why we didn't)
