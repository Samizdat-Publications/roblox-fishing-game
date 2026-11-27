# Critic: n1-round3-lake (review, gemini-4-neon)

Date: 2026-11-27 18:25. Rubric: `look`.

Files shown:
- `01-dock-dawn.jpg`
- `02-dock-golden.jpg`
- `03-dockend-noon.jpg`
- `04-dockend-night.jpg`
- `05-weedbed-golden.jpg`
- `06-logs-dawn.jpg`
- `07-overview-golden.jpg`
- `08-stands-noon.jpg`

**Score: 7/10**

This already feels like a real fishing lake with distinct, readable spots (cattail cove, sunken logs, central dock, and a bridge channel to a bigger lake) and a charming Real-ish aesthetic that shines at golden hour and dawn. The weathered dock planks and the golden-hour weedbed cove are genuinely inviting. What holds it back right now are a noticeable horizontal lighting seam across the night water, harsh flat midday lighting, overblown aerial golden-hour glare, and several bare shorelines and placeholder-looking props.

| Point | Score |
|---|---|
| composition | 7.5 |
| light | 7 |
| water | 7 |
| mood | 7.5 |
| want_to_fish | 8 |
| phone_readability | 7 |
| broken_or_ugly | 6 |

Top fixes:
1. Fix the night water seam and tune water/glare settings: eliminate the sharp horizontal reflection/lighting band cutting across the lower third of the water in 04-dockend-night.jpg (check Terrain WaterReflectance, Lighting.EnvironmentSpecularScale, skybox horizon seam, or underwater terrain bounds), lower night WaterReflectance and WaveSize so ripples stop reading as noisy grey-on-black patches, and reduce Atmosphere.Glare and BloomEffect.Intensity at golden hour so elevated views like 07-overview-golden.jpg do not blow out into solid yellow fog.
2. Fill out bare shorelines, thin treelines, and harsh noon lighting: thicken the single-row pine treeline across the lake (03-dockend-noon.jpg) and behind the stands (08-stands-noon.jpg) into staggered multi-depth clusters, smooth out the blocky symmetrical green wedges under the bridge (03-dockend-noon.jpg), add rocks, reeds, and darker wet-shore terrain transitions along the bare dirt banks (06-logs-dawn.jpg, 08-stands-noon.jpg), and add subtle Atmosphere.Haze (around 1.0 to 1.5) plus warmer soft ColorCorrection at noon so midday feels natural instead of default Roblox bright blue and green.
3. Upgrade rough props and unreadable in-world text: replace the smooth flat-ended cylinder logs and the faceted low-poly bush on bare gravel in 06-logs-dawn.jpg with bark-textured broken logs and softer foliage; replace the blobby deciduous trees on the left of 08-stands-noon.jpg so they match the pines; remove or integrate the awkward standalone brown boards sitting in the grass behind the stands (07-overview-golden.jpg); and make the tiny-text chalkboard next to Bait and Tackle (08-stands-noon.jpg) open a clean ScreenGui on interact since it cannot be read from the dock or on a phone.

Strengths:
- Strong fishing-spot identity and layout (07-overview-golden.jpg): distinct habitats like the cattail-and-lilypad cove, sunken logs, dock pilings, and bridge channel to a larger lake make the world feel designed around real fishing knowledge.
- Standout golden-hour mood and framing in 05-weedbed-golden.jpg and 02-dock-golden.jpg: the foreground rocks, cattails, lily pads, rippled sand, and warm reflections across the cove immediately make you want to cast a line.
- True-to-style materials on the hero structures (08-stands-noon.jpg): the uneven weathered dock planks with nail heads, bark-textured round pilings, metal cleats, and weathered wood stands with clear Bait and Tackle and Sell Fish signs nail the chunky Real-ish look.
- Clear central sightlines from the path between the two stands straight down the dock to the bridge and distant mountain peak (01-dock-dawn.jpg, 02-dock-golden.jpg).
- Thoughtful nighttime details in 04-dockend-night.jpg like the subtle floating fireflies and the glowing beacon on the red-and-white channel buoy.

Broken or ugly:
- 04-dockend-night.jpg: Sharp horizontal seam/band cutting straight across the entire lower third of the water surface, plus high-contrast grey ripple noise against pitch-black water.
- 07-overview-golden.jpg: Excessive golden-hour glare/haze completely washes out the upper sky and distant hills; freestanding flat brown wall/boards sit awkwardly in the open grass behind the stands.
- 03-dockend-noon.jpg: Two abrupt, symmetrical green terrain wedges/ramps flanking the channel under the bridge look artificial and unfinished.
- 06-logs-dawn.jpg: Low-poly faceted dark-green bush sits awkwardly on bare grey gravel in the right foreground; sunken logs look like smooth unweathered cylinders with flat tan ends; a jagged tree branch pokes awkwardly into the top-right corner.
- 08-stands-noon.jpg: Chalkboard guide text next to Bait and Tackle is far too small to read from normal viewing distance (and unreadable on phones); smooth rounded deciduous trees on the left clash stylistically with the detailed weathered dock and layered pines; a lone short wooden piling stub sits awkwardly in the dry dirt on the left bank.

Action taken: (fill in: what we changed, or why we didn't)
