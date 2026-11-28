# Critic: N4 feel dinghy dusk (review, gemini-4-neon)

Date: 2026-11-28 05:58. Rubric: `playtest`.

Files shown:
- `dinghy-dusk.mp4`
- `01.jpg`
- `04.jpg`

**Score: 6.5/10**

The sunset lake stills (01.jpg, 04.jpg at 5:23 PM) are genuinely lovely - warm wood materials, believable blue-gold water, and a clean handcrafted parchment UI that makes this feel like a real place you want to fish. However, the 6:23 PM dusk clip (dinghy-dusk.mp4) pulls the presentation down sharply: the water turns harsh, pitch-black, and noisy, the dinghy clips against the dock (00:04), and a confusing 'A log is in the way. Turn the boat.' warning pops up with no visible log (00:08–00:09). Because this footage only shows boating and no casting, waiting, bite, or catch sequence, suspense and catch reveal could not be judged.

| Point | Score |
|---|---|
| composition_light_water_mood | 6.5 |
| want_to_fish | 7 |
| phone_readability | 6 |
| clarity | 5 |
| broken_or_ugly | 5 |

Top fixes:
1. Rework dusk lighting and water readability (dinghy-dusk.mp4, 00:00–00:09): lift twilight ambient blue on the water and shoreline, reduce water wave contrast/specular glare so dusk water stops reading like noisy black-and-white oil, and soften the overly bright neon red/green boat light reflections.
2. Fix boat obstacle detection and dock collisions (dinghy-dusk.mp4, 00:04 and 00:08–00:09): make sure whatever triggers 'A log is in the way. Turn the boat.' is clearly visible above the waterline (or remove the false-positive trigger if it is hitting an invisible/dock collider), and tighten hull collision so the dinghy bumps cleanly off dock pilings instead of clipping into the planks.
3. Make the bottom instruction bar context-aware and fix canoe leg clipping (01.jpg, 04.jpg, dinghy-dusk.mp4): hide or replace 'Face the water. Hold click and let go to cast.' with boat/exit controls while driving (and use touch-friendly phrasing on mobile), and adjust the seated avatar height/pose in the canoe so legs do not poke through the bottom hull.

Strengths:
- Sunset composition, light, and water in 01.jpg and 04.jpg (5:23 PM) look genuinely inviting, with warm golden sun over pine silhouettes, rich teal-and-gold reflections, reeds, and a distant wooden bridge.
- Handcrafted parchment-and-wood HUD (coin counter, day/night dial, fish creel, and left-side wooden-post buttons for Worms, Journal, and Goals) feels warm, thematic, and uncluttered.
- Real-ish materials read well in daylight: the ribbed wooden canoe, weathered dock planks, and 'Boat slips' wooden sign in 01.jpg look distinctly like wood rather than flat plastic.
- Diegetic lake details - the glowing dock lanterns, red channel buoy, and '350' boat slip price sign - help sell the lake as a grounded fishing destination.

Broken or ugly:
- dinghy-dusk.mp4 (00:08–00:09): 'A log is in the way. Turn the boat.' appears at the top of the screen while no log is visible anywhere in the water around the dinghy.
- dinghy-dusk.mp4 (00:04): The inflatable dinghy drives into and clips against the wooden dock planks right under the lantern post.
- 01.jpg and 04.jpg: The seated player's lower legs/feet visibly clip through the bottom hull of the wooden canoe into the water.
- dinghy-dusk.mp4 (00:00–00:09): Dusk water renders as high-contrast pitch-black with harsh white specular noise, hurting mood and hiding dark obstacles.
- dinghy-dusk.mp4 (00:00–00:09), 01.jpg, 04.jpg: The bottom prompt 'Face the water. Hold click and let go to cast.' remains stuck on screen while actively driving a boat and even when already facing open water.

Action taken: (fill in: what we changed, or why we didn't)
