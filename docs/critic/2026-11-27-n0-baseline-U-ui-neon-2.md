# Critic: n0-baseline-U-ui (review, gemini-4-neon)

Date: 2026-11-27 15:37. Rubric: `ui`.

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

The interface is functional, clean, and thoughtfully adapted for mobile controls (stripping keyboard hints on 667), with strong copywriting that already feels warm and knowledgeable. However, visually it is 100% a flat dark Roblox simulator kit rather than the target warm-paper field guide and leather/brass tackle box, and the 667 phone layout has several modal overlaps, cramped text wrapping, low-contrast labels, and sub-14px text that need fixing.

| Point | Score |
|---|---|
| readability | 7 |
| hierarchy | 6 |
| consistency | 7 |
| handmade_feel | 2 |
| contrast | 5 |
| touch_targets | 6 |
| phone_readability | 5 |
| broken_or_ugly | 5 |

Top fixes:
1. Reskin all screens (u01-hud, u02-shop, u03-journal, u04-card-rare, u05-fight, u06-bench at both 1280 and 667) from dark slate boxes (#18222D) to the field-guide and tackle-box style: use warm cream paper 9-slice ImageLabels (#F5ECD7) with dark sepia ink text (#2B2118) for the Journal cards, Catch card, and top bar; canvas/leather panels (#5C4433 / #D8CCB2 with stitched border) for Bait and Tackle and the Bait bench; brass (#C89B3C fill, #7A5A1C UIStroke, #1F170E text) for buy/action buttons, coins, and tags; pair a serif font (Enum.Font.Antique or custom Serif) for titles, a clean rounded sans (Enum.Font.Nunito or Fredoka) for stats/body, and a handwriting font (Enum.Font.PatrickHand or Kalam) for fish notes and bait tips; render rarity as an ink-stamp or ribbon tag instead of neon blue/green text.
2. Fix phone overlaps, cramped wrapping, and sub-14px text (u01-hud-667, u02-shop-667, u03-journal-667, u05-fight-667, u06-bench-667, plus u03-journal-1280 and u06-bench-1280): hide the left HUD buttons and bottom cast prompt whenever any modal opens so they stop clipping behind u02-shop-667 and u03-journal-667 and stop bleeding through u03-journal-1280; shorten '12:00 PM Day, Foggy morning' to '12:00 PM · Foggy' (TextWrapped = false) or raise the top bar height to 44px on 667 so it stays on one line; move the u03-journal species/rod summary onto its own full-width subtitle row at >=14px; raise 'point'/'bend'/'shank', 'or hold 1 s', and 'Line 8 lb' to at least TextSize = 14 on 667; increase the 'Skip' button height in u06-bench-667 to 44px; center the u06-bench frame at AnchorPoint (0.5, 0.5), Position UDim2.fromScale(0.5, 0.52) on both 1280 and 667.
3. Rebalance layout and contrast on the Catch card, Fight screen, and Bait bench (u04-card-rare, u05-fight, u06-bench at 1280 and 667): on u04-card-rare, remove the empty dead space under the floating 'RARE' pill by placing a fish illustration/silhouette (72x72 on 667, 96x96 on 1280) on the left, left-aligning the species title with an inline 'RARE' ink stamp, removing the duplicate 'Rare.' from the stats text, and highlighting '38 coins' in a brass badge; on u05-fight, shrink the oversized 'REELING!' panel into a compact 36px bottom reminder bar, turn 'Drag: Medium' into an obvious 44px-tall button, and boost contrast on 'Big runs, then rests.' and 'Line 8 lb'; on u06-bench, replace the dotted pink-circle worm with a drawn worm ImageLabel and add a Close button.

Strengths:
- Good cross-device copy adaptation: keyboard shortcuts like '(J)' on Journal and '(Q)' on Drag are removed on -667 captures, and the fight prompt switches from 'Hold the mouse anywhere, or Space.' to 'Hold anywhere on the screen.'
- The 3D water, shoreline, and red bobber remain clearly visible on the HUD (u01-hud), catch card (u04-card-rare), and fight screen (u05-fight) at both 1280 and 667.
- Strong mechanical clarity on the reeling mini-game (u05-fight): the green target zone, orange marker, and yellow progress bar read immediately at a glance.
- Consistent layout geometry and spacing across screens, with genuinely charming, informative field-guide writing ('Everything eats a worm. Panfish love them.', 'Hides in fallen logs, feeds at dusk and after dark.').
- Primary action buttons on the HUD left column and Shop buy rows are generously sized and well spaced on both desktop and phone.

Broken or ugly:
- u02-shop-667 and u03-journal-667: The left HUD buttons ('Bait: Worms', 'Journal', 'Goals 1/3') stay visible behind the modal and get sliced in half by the modal's left edge.
- u01-hud-667 through u06-bench-667: The top bar text '12:00 PM Day, Foggy morning' wraps onto two cramped lines that press right against the top and bottom borders of the bar.
- u03-journal-1280: The world HUD cast hint ('Face the water. Hold click and let go to cast.') faintly bleeds through the translucent Journal modal between the fish cards.
- u06-bench-1280 and u06-bench-667: The entire Bait the Hook modal is noticeably shifted off-center to the left, and the worm graphic reads as placeholder art (a trail of disconnected pink dots).
- u03-journal-667, u05-fight-667, and u06-bench-667: Multiple text elements fall well below 14px on phone, including the Journal header stats (~9px), 'point'/'bend'/'shank' and 'or hold 1 s' (~9-10px), and 'Line 8 lb' (~10px); the 'Skip' button in u06-bench-667 is under 30px tall.
- u04-card-rare-1280 and u04-card-rare-667: The right third of the card is an empty dark void beneath the floating 'RARE' pill, and 'Rare.' is duplicated in the body text.
- u03-journal-1280 and u03-journal-667: The three bottom buttons ('Reel assist', 'Quick Bait', 'Tackle Box') are left-aligned, leaving an awkward empty gap on the bottom right, and blue 'Rare' fish names have poor contrast on the dark card background.
- u02-shop-1280: The 'Owned' button on the Spinner row is dark navy on dark navy with almost invisible edges, and the row description clips mid-line at the bottom of the scroll frame.

Action taken: (fill in: what we changed, or why we didn't)
