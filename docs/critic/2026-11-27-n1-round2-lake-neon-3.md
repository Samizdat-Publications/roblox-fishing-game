# Critic: n1-round2-lake (review, gemini-4-neon)

Date: 2026-11-27 18:07. Rubric: `look`.

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

A genuinely promising Real-ish fishing pond with strong spot variety (weedbed, sunken logs, dock, bridge channel), lovely dawn and golden-hour lighting, and standout timber craftsmanship on the main dock. It is held back mainly by a harsh horizontal lighting artifact on the night water, over-exposed golden-hour haze in the overview, an empty backdrop behind the shops, and a few rough props and tiny signs that will struggle on smaller screens.

| Point | Score |
|---|---|
| composition | 7.5 |
| light | 7 |
| water | 6.5 |
| mood | 7.5 |
| want_to_fish | 8 |
| phone_readability | 6.5 |
| broken_or_ugly | 6 |

Top fixes:
1. Fix the night water seam and golden-hour blowout in Lighting: track down and remove the horizontal dark cutoff band across the water in 04-dockend-night.jpg (check wide-range PointLights/SpotLights on the dock or lantern posts, ShadowSoftness/shadow cascade range, and WaterReflectance), and reduce SunRaysEffect.Intensity, BloomEffect.Intensity, and Atmosphere.Glare at golden hour so high angles like 07-overview-golden.jpg do not wash out into flat orange.
2. Dress the bare backdrop behind the shops and roughen the uniform shoreline: add dense trees, low hills, split-rail fencing, bushes, and dockside props (buckets, crates, rod racks) behind Bait and Tackle and Sell Fish (07-overview-golden.jpg, 08-stands-noon.jpg) so the world does not drop off to bare grass, and break up the smooth tan shore rim and symmetrical pine gap across the bridge (01-dock-dawn.jpg, 03-dockend-noon.jpg, 08-stands-noon.jpg) with rocks, uneven banks, and shore reeds.
3. Make in-world signs readable and upgrade the few standout rough props: separate the overlapping boards next to Bait and Tackle (08-stands-noon.jpg) and either enlarge/simplify the chalkboard text or pair it with a clean interactive UI popup for phone readability; replace the bright untextured white slab beside the dock (01-dock-dawn.jpg, 02-dock-golden.jpg) with weathered dock wood; and add gnarly roots, moss, or lily clusters around the flat-cut sunken logs (06-logs-dawn.jpg) so they match the quality of the weedbed.

Strengths:
- The weedbed spot (05-weedbed-golden.jpg) is a highlight: foreground boulders, layered cattails, lily pads, and warm golden sky reflections create an immediately memorable, cast-worthy fishing spot.
- The weathered dock planks, nail heads, cleats, and bark-wrapped pilings (08-stands-noon.jpg) nail the chunky Real-ish material style.
- Time-of-day shifts give the pond distinct moods - cool misty calm at dawn (01-dock-dawn.jpg, 06-logs-dawn.jpg), warm sunset colour at golden hour (02-dock-golden.jpg, 05-weedbed-golden.jpg), and fireflies over dark water at night (04-dockend-night.jpg).
- Distinct fishing structure - reeds, submerged timber, deep open water around the buoy, and the bridge channel - visually communicates real fishing spots without needing heavy UI clutter.
- The approach path framed by the two stalls leading out to the dock, bridge, and distant peak (02-dock-golden.jpg) gives a clear, inviting arrival view.

Broken or ugly:
- Sharp horizontal dark band cutting straight across the water surface in 04-dockend-night.jpg, likely a lighting range, reflection, or shadow cascade cutoff.
- Heavy golden-hour glare/bloom in 07-overview-golden.jpg blows out the upper sky, hills, and water contrast.
- The green chalkboard next to Bait and Tackle partially blocks a second dark sign board behind it (08-stands-noon.jpg), and its tiny white text is barely legible on desktop and unreadable on a phone.
- A lone brown freestanding board/wall sits awkwardly out in the empty grass behind the shops in 07-overview-golden.jpg.
- A bright white rectangular float/slip beside the right side of the dock (01-dock-dawn.jpg, 02-dock-golden.jpg, 06-logs-dawn.jpg) reads as an untextured block against the weathered timber.
- High-contrast marbled specular noise on the night water (04-dockend-night.jpg) will make reading a small bobber or line ripple difficult.
- In 08-stands-noon.jpg, a short plank overlaps unevenly on the lower-left dock edge, patchy green grass blobs sit harshly on smooth tan shore terrain, and the puffy deciduous trees on the far left clash with the crisper pine style.
- In 06-logs-dawn.jpg, a sharp dark tree branch pokes awkwardly into the top-right corner and the sunken logs have very abrupt flat-cut ends and stiff peg branches.

Action taken: (fill in: what we changed, or why we didn't)
