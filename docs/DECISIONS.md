# Decisions

Notable design and build calls, newest last.

## 2026-11-25

- **Rules live in pure shared modules.** Fish habits, bite odds, sizes, prices, the fight and the inventory are plain Luau modules in `ReplicatedStorage.Shared` with no Roblox service calls, so they can be unit tested in Edit mode. Server services are thin wrappers around them.
- **The fight runs on the client, the server checks it.** The bar minigame needs instant response, so the client simulates it with the same `FightModel` and a server-given seed. The server picks the species, rolls the size and price only after a win, and refuses wins that arrive faster than the fastest possible fight (`FightModel.minSeconds`). The client can never pick a fish, a size or a coin amount.
- **One button for everything.** Hold and release to cast, press on a bite to hook, hold to reel, press while waiting to reel in. Mouse button 1 (or F), gamepad R2, and an on-screen Fish button on touch. Journal is J or gamepad Y; bait cycles with B or D-pad right; panels close with gamepad B or Backspace. Stand prompts use E or gamepad X.
- **Cast aims where the camera looks**, flattened to the ground, 8 to 40 studs depending on charge. Works the same on every device.
- **Live bait is used when a fish takes it, lures are kept.** Spinner and plastic worm are bought once. A missed hook does not cost bait, and another bite can come.
- **Nobody gets stuck.** With no bait, no lure and less than the cheapest pack, the shopkeeper gives 5 free worms.
- **Bite speed rewards knowledge.** A spot, time and bait that suit a fish make it bite in about 3 to 5 seconds; a weak match takes up to 14; a combo nothing wants gets a hint after 12 seconds instead of silence.
- **Water is terrain water** (swimmable, so a player who falls in can get out), with an invisible part marking the lake bounds for cast checks. Zones are invisible boxes named by spot.
- **Day length is 16 real minutes**, starting at 7 AM (dawn), so dawn and dusk each last about 2 minutes.
- **Reel assist starts on** (bigger catch zone, slower loss). It can be turned off in the journal.
- **Species reveal on catch.** The fight shows only a hint ("Heavy, keeps pulling down"); the name and journal habit appear when the fish is landed. The journal shows a species' habits only after the first catch, so players learn by fishing.
- **Sync path:** `tools/sync/build_manifest.py` writes `build/manifest.json`; a local `python -m http.server 8765` serves it and `tools/sync/sync.luau`, run through `execute_luau`, creates or updates the scripts. Fallback is `multi_edit`.
- **Studio-only test hook:** the client hooks and reels by itself (through the same input handler) when the player has a `DebugAutoFish` attribute and the game runs in Studio, so automated playtests can land fish. It does nothing in a live game.
- **Own touch button instead of the ContextActionService one.** The built-in touch button came out 45 px and on top of Roblox's jump button on small phones. A 110 px Fish button left of jump, driven by the same handler, is easier for kids' thumbs.
- **Fight bar sits left of center** so a thumb on the Fish button never covers it, and panels shrink to fit short phone screens.
- **Landscape only.** The game sets the screen to landscape; fishing reads better sideways.
- **Pushing code without localhost.** After a Studio update the Assistant blocks localhost HTTP unless the user allow-lists it, so changes go in with `multi_edit` and `tools/sync/verify.py` checks Studio against `src/` by checksum.
- **Pike made a little gentler** (zone 0.24, speed 1.5, loss 0.20) after the unit test showed a perfect player could still lose one.

## 2026-11-25 (evening)

- **Input wins the fight.** The catch zone now aims for a steady climb speed while held (1.25 bar heights a second) and falls at 0.85 when released, reaching those speeds in about a tenth of a second; each fresh click or tap sets an immediate climb. Clicking and holding both work. Species differ by how the fish moves, how long it takes to land, and a small slowdown for heavy fish (up to 12 percent).
- **During a bite or fight, the whole screen is the button.** Input comes from UserInputService, ignoring whether the UI handled it, so no panel or button can steal a reel. Panels are locked and the character stands still for the duration.
- **No accidental recast.** After a fight the button must be released and 0.8 s pass before the next cast.
- **Data version 2** turns reel assist back on for older saves (a test had switched it off on Stewart's save).
- **Pushing code:** `tools/sync/push_snippet.py` builds a paste-ready Luau snippet for whole files when the localhost sync is blocked; `multi_edit` for small edits; `tools/sync/verify.py` confirms the result.
- **Stewart's direction (2026-11-25 evening):** Liam fills in the planner later; until then Claude makes the design calls for looks and fun and logs them here.
- **Home pond rules:** 6 fish, only from your own catches (no buying fish); growth closes 30 percent of the gap to full size per hour; two grown fish of a kind (60 percent of the way to full size) have a 25 percent chance of a baby every 30 minutes; time away counts up to 8 hours. Pond fish sell at their grown size, which makes the pond a slow, steady money-maker without beating active fishing.
- **Pond fish are per player:** the pond is shared scenery, but each player sees only their own fish in it (drawn on their own screen).
- **Rods include the reel** (one item, not two) to keep the shop simple for kids. Three tiers: Willow (free), Fiberglass (120), Graphite (350). Bonuses are cast distance, catch zone size and, for Graphite, less pull from heavy fish; they never change which fish bite, so knowledge still beats gear.
