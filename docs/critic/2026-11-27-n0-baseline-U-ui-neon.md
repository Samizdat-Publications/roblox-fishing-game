# Critic: n0-baseline-U-ui (review, gemini-4-neon)

Date: 2026-11-27 15:36. Rubric: `ui`.

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

**Score: 4.5/10**

The interface works well as a clean, functional wireframe with sensible screen layouts and strong desktop legibility on primary actions, especially during the reeling fight where the bobber stays clearly visible. However, it completely misses the target field-guide and tackle-box visual identity - every screen uses flat dark navy rounded boxes, default sans-serif text, and bright gamer-UI button colours - and the 667x375 phone captures suffer from modal overlaps over HUD buttons, cramped two-line wrapping in the top bar, undersized tap targets, and several labels shrinking well below 14 pixels.

| Point | Score |
|---|---|
| readability | 7 |
| hierarchy | 6 |
| consistency | 7 |
| handmade_feel | 1 |
| contrast | 5 |
| touch_targets | 5 |
| phone_readability | 4 |
| broken_or_ugly | 4 |

Top fixes:
1. Reskin all panels, typography, and rarity indicators to the field-guide and tackle-box style (all screens u01 to u06, both 1280 and 667): replace the dark navy rounded Frames and default Gotham/BuilderSans text with warm cream paper cards (#F4ECDC) and dark sepia ink (#2B2118) for Fish Journal (u03) and Catch Cards (u04), weathered leather/canvas panels (#3D2B1F and #D9CBAE) for Bait and Tackle (u02) and Bait Bench (u06), and brushed brass (#C59B42 with dark ink text) for primary buttons, tags, and coins. Use a serif font (Merriweather or Baskerville) for titles, a clean rounded sans (Nunito) for body text, and a handwriting face (Kalam) for flavour notes and tips. On the u04 Catch Card, replace the bright blue RARE pill and empty right-hand void with a fish illustration/ViewportFrame plus a stamped ink rarity badge, and remove the duplicate word Rare. from the body text.
2. Fix phone overlaps, cramped top-bar wrapping, sub-14px text, and undersized touch targets (u01, u02, u03, u05, u06 at 667x375): hide the left HUD buttons (Bait, Journal, Goals) whenever Bait and Tackle (u02) or Fish Journal (u03) is open so they no longer sit clipped behind the modals; shorten the phone top-bar weather string (for example 12:00 PM - Foggy) and raise the top bar height to 38px so it never wraps into two cramped lines; raise all secondary TextSize values to at least 14px on 667 (fixing the ~9-11px Journal header stats, Shop/Journal descriptions, Line 8 lb, Big runs, then rests., point/bend/shank, or hold 1 s, and Tip text); increase the Close buttons (u02, u03), Journal bottom buttons (Reel assist, Quick Bait, Tackle Box in u03), and Skip button (u06) to at least 44px tall.
3. Fix modal centering, bottom padding, bleed-through, and low-contrast labels (u01, u03, u05, u06 at 1280 and 667): center the Bait the hook panel (u06) with AnchorPoint (0.5, 0.5) and Position UDim2.fromScale(0.5, 0.52) instead of leaving it shifted left, and add 12px bottom UIPadding so the Tip line no longer touches the bottom border; hide the bottom cast prompt (Face the water...) when Fish Journal (u03-1280) is open so it stops showing faintly through the translucent panel, and add a subtle backdrop behind that prompt on u01-1280 so it stays readable over water glare; increase contrast to at least 4.5:1 on muted labels like Bag: 4 fish (56), Line 8 lb (u05), item descriptions (u02, u03), and the blue Rare species headers (u03).

Strengths:
- Reeling fight layout (u05-fight-1280 and u05-fight-667) cleanly hides the left HUD stack and frames the red-and-white bobber in the open center gap between the tension bar and the REELING prompt.
- Input prompts adapt properly between desktop and phone: Journal (J), Drag: Medium (Q), and Hold the mouse anywhere, or Space on -1280 switch cleanly to Journal, Drag: Medium, and Hold anywhere on the screen on -667.
- Core interactive lists like Bait and Tackle (u02) and Fish Journal (u03) are logically organized with clear scanning columns and helpful fishing-knowledge copy.
- Primary action buttons on the left HUD (u01), shop buy buttons (u02), and hook-size selectors (u06) are generously sized and easy to spot on desktop.

Broken or ugly:
- u02-shop-667 and u03-journal-667: The Shop and Fish Journal modals overlap the left-side HUD stack, slicing Bait: Worms x23 down to Bait: Worms and leaving Journal and Goals 1/3 peeking out from behind the panel edge.
- u01 to u06 at 667: The top HUD bar text 12:00 PM Day, Foggy morning wraps onto two lines with zero vertical breathing room, pushing morning right onto the bottom border of the pill.
- u06-bench-1280 and u06-bench-667: The Bait the hook modal is noticeably off-center to the left (especially obvious on 1280), and the bottom Tip: Thread it on... line is pressed flush against the bottom edge of the panel.
- u03-journal-1280: The HUD cast prompt (Face the water. Hold click and let go to cast.) bleeds faintly through the semi-transparent Journal background between the second and third rows of fish cards.
- u04-card-rare-1280 and u04-card-rare-667: Large empty space underneath the floating RARE pill makes the catch card look half-empty/unfinished, and the text redundantly repeats Rare. next to the RARE badge.
- u03-journal-667 and u06-bench-667: Header stats (14 of 26 species found...), timing labels (point, bend, shank), or hold 1 s, and Line 8 lb (u05-fight-667) drop to roughly 9-11px and are hard to read on a phone.
- u02-shop-667, u03-journal-667, and u06-bench-667: The red Close buttons (~28px tall), Journal bottom toggle buttons (~32px tall), and Bait Bench Skip button (~26px tall) fall below the 44px phone touch-target size.

Action taken: (fill in: what we changed, or why we didn't)
