# Critic: rare-reveal (review, gemini-4-neon)

Date: 2026-11-27 03:48. Rubric: `playtest`.

Files shown:
- `2026-11-27-rare-reveal.mp4`

**Score: 6.5/10**

The golden-hour dock atmosphere, water light, and fishing audio (splash, reel clicks, drag whine, and catch chime) already feel genuinely peaceful and inviting. The main things holding this clip back are UI collisions and a contradictory prompt during the fight (00:09), plus a Rare catch card (00:11-00:16) whose 3D fish is too dark and small to feel like a celebratory reveal.

| Point | Score |
|---|---|
| composition_light_water_mood | 8 |
| want_to_fish | 8 |
| phone_readability | 5 |
| suspense | 6 |
| reveal | 5 |
| clarity | 6 |
| broken_or_ugly | 5 |

Top fixes:
1. Fix the reeling UI overlap and contradictory instruction (00:06-00:10): move floating callouts like Nice! and LET GO into a dedicated uncluttered spot above the tension bar so they never clip behind the Drag: Medium [Q] box, and swap the right-side prompt from HOLD TO REEL to LET GO when the fish runs (00:09) so both prompts agree.
2. Punch up the Rare catch reveal (00:11-00:16): add brighter key and rim lighting inside the fish ViewportFrame so the largemouth bass does not read as a dark silhouette, enlarge the turning fish preview with a brighter high-contrast blue sweep/glow behind it, and style RARE as a distinct blue badge rather than plain white sentence text.
3. Tighten the waiting camera and small-screen readability: shift the cast camera (00:03-00:05) slightly higher or over the shoulder so the player hat does not dominate the foreground, ensure the fishing line visibly connects to the bobber with a brief dip/ripple telegraph before the bite splash (00:06), and increase text size and contrast on secondary labels (Bag count, Line 15 lb, catch card stats) for small phones.

Strengths:
- Warm dusk lighting, peach-to-blue sky gradient, atmospheric haze on the distant tree line, and shimmering teal water make the dock immediately somewhere you want to fish (00:00-00:18).
- Audio design sells the loop well: calm lakeside ambience and birdsong while waiting (00:03-00:05), a punchy bite splash (00:06), tactile reel clicks (00:07-00:08), tense high-pitched drag whine during the run (00:08-00:09), and a pleasant harp/marimba chord on catch (00:11).
- Core state flow is clean and easy to follow from casting to twitching/reeling to updated bait and bag counts (Worms x30 to x29, Bag 23 to 24 fish at 00:11).

Broken or ugly:
- At 00:09, the blue LET GO cue spawns partially obscured behind the top edge of the Drag: Medium [Q] panel while the right-hand prompt still says HOLD TO REEL, giving two conflicting instructions at the same time.
- At 00:06 and 00:10, green Nice! floating text overlaps the player character and gets clipped behind the Drag: Medium [Q] panel.
- At 00:11-00:16, the 3D largemouth bass inside the catch card viewport is severely under-lit against a dark blue-grey box, making the fish hard to see and the tier-colour sweep barely noticeable.
- At 00:03-00:05, the waiting camera pitches directly over the top of the avatar's Santa hat (showing a distracting hollow rim in the lower center), and the bent rod/line near the right dock post does not cleanly visually track out to the distant red bobber.

Action taken: The fish window is bigger and lit from the camera side, a tier badge (RARE on a blue pill) sits over it, the cue stays above the drag box and the big prompt agrees with it (LET GO / LET IT DROP when the fish is below the zone). Re-scored: 7 (rare-reveal-2).
