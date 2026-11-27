# Critic: n0-baseline-U-ui (review, gemini-4-neon)

Date: 2026-11-27 15:38. Rubric: `ui`.

Files shown:
- `u01-hud-1280.jpg`
- `u01-hud-667.jpg`
- `u02-shop-1280.jpg`
- `u02-shop-667.jpg`
- `u03-journal-1280.jpg`
- `u03-journal-667.jpg`
- `u04-card-rare-1280.jpg`
- `u04-card-rare-667.jpg`
- `u05-fight-1280.jpg`
- `u05-fight-667.jpg`
- `u06-bench-1280.jpg`
- `u06-bench-667.jpg`

**Score: 5/10**

The interface is clean, functional, and generally legible as an early wireframe, especially on desktop, and the fight HUD keeps the bobber nicely centered in view. However, it currently looks 100% like a flat dark-mode stock Roblox simulator kit rather than the target handmade field-guide and tackle-box aesthetic, and the 667x375 phone layout has real usability bugs: modal windows overlap and slice off the left HUD buttons, the top weather/time bar wraps onto two cramped lines, scrollbars disappear, and several helper labels drop below 14px with low grey-on-dark contrast.

| Point | Score |
|---|---|
| readability | 7 |
| hierarchy | 6 |
| consistency | 7 |
| handmade_feel | 2 |
| contrast | 5 |
| touch_targets | 7 |
| phone_readability | 5 |
| broken_or_ugly | 5 |

Top fixes:
1. Reskin all screens (u01-hud through u06-bench at both -1280 and -667) from dark simulator boxes to the field-guide and tackle-box palette: change journal species cards (u03-journal), catch cards (u04-card-rare), and tip boxes to warm cream paper (#F4ECD8 fill or 9-slice paper ImageLabel with #C2B295 UIStroke) and dark ink text (#2A2017 primary, #574838 secondary for >4.5:1 contrast); style modal shells (u02-shop, u03-journal, u06-bench) as leather/canvas (#3D2E22 or #D8CCB4 9-slice images); replace bright blue/red/grey buttons with brass (#C69C45 fill, #78591E 2px UIStroke, #1E160D text); set titles to a serif font (Merriweather or Antique), body text to a rounded sans (Nunito or BuilderSans), and notes/tips to a handwriting font (Kalam); replace rarity text colours and blue strokes on u03-journal and u04-card-rare with a tilted ink-stamp ImageLabel or corner ribbon.
2. Fix modal overlaps, centering, and top-bar wrapping on -667 and -1280: hide the left HUD button stack (Bait, Journal, Goals) and the bottom cast hint whenever u02-shop, u03-journal, or u06-bench is open so they stop clipping behind modals on u02-shop-667 and u03-journal-667 and stop bleeding through the translucent panel on u03-journal-1280; on u01-hud-667 (all -667 screens), shorten the middle status text to '12:00 PM · Foggy' or widen the pill to UDim2.new(0.88, 0, 0, 38) with TextWrapped = false so it never wraps onto two tight lines; center u06-bench on both -1280 and -667 with AnchorPoint = Vector2.new(0.5, 0.5) and Position = UDim2.fromScale(0.5, 0.52).
3. Fix sub-14px text, missing phone scrollbars, and lopsided layouts on -667 and -1280: on u03-journal-667, move the tiny '14 of 26 species found...' line onto a dedicated full-width subheader at TextSize = 14, and set ScrollBarThickness = 8 with ScrollBarImageTransparency = 0 on both u02-shop-667 and u03-journal-667; on u06-bench-667, raise 'point/bend/shank', 'or hold 1 s', and 'Tip:' to TextSize = 14, resize the Skip button to at least 44px tall, and add 10px bottom UIPadding; on u04-card-rare (-1280 and -667), let body text span the full card width below the title and rarity stamp (removing the dead right column and duplicate 'Rare.' prefix) and call out '38 coins' in a brass tag; on u05-fight (-1280 and -667), shrink the dominant 'REELING!' box to a compact 220x48px prompt and bump 'Big runs, then rests.' and 'Line 8 lb' to TextSize = 14 with higher contrast.

Strengths:
- Desktop core readability is solid: main headings, coin counts, shop prices, and reeling gauges read clearly at a glance on 1280x720.
- The reeling minigame layout (u05-fight-1280 and u05-fight-667) cleanly frames the bobber in the middle of the screen without blocking the water action.
- Primary interactive controls (left HUD buttons on u01-hud, blue purchase buttons on u02-shop, and hook size buttons on u06-bench) are generously sized for thumb taps even on the 667x375 phone captures.
- The UI is internally consistent across screens in spacing, corner radii, and button placement, giving a clean structural base to reskin.

Broken or ugly:
- u02-shop-667 and u03-journal-667: Open modals overlap and cut off the right side of the left HUD buttons ('Bait: Worms x23' is clipped to 'Bait: Worms').
- u01-hud-667 (and all -667 screens): Top status bar text '12:00 PM Day, Foggy morning' wraps onto two lines inside a short pill, nearly touching the bottom border.
- u03-journal-1280: The world prompt 'Face the water. Hold click and let go to cast.' is faintly visible bleeding through the semi-transparent Journal background between card rows.
- u02-shop-667 and u03-journal-667: Scrollbars disappear on the phone layout even though cards (Yellow Perch, Black Crappie) are cut off at the bottom, removing any cue that the list scrolls.
- u06-bench-1280 and u06-bench-667: The entire 'Bait the hook' modal is misaligned noticeably to the left of screen center, and the worm graphic made of separated pink dots looks like a rough placeholder.
- u03-journal-667 and u06-bench-667: Secondary text ('14 of 26 species found...', 'point/bend/shank', 'or hold 1 s', and the bottom tip) renders well below 14px and is hard to read on a phone.
- u04-card-rare-1280 and u04-card-rare-667: Awkward two-column split leaves a large empty void underneath the 'RARE' badge while repeating 'Rare.' at the start of the description.

Action taken: (fill in: what we changed, or why we didn't)
