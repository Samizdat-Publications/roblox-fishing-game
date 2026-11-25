# Progress

## 2026-11-25

- Design approved (`DESIGN.md`). Build plan written (`PLAN.md`); task plan in `docs/superpowers/plans/2026-11-25-fishing-game-v1.md`.
- Roblox Studio installed; Studio MCP server enabled and registered with Claude Code for this folder (`Roblox_Studio`).
- The place is the Roblox experience **Fishing Game** (place id 90333988052712, Team Create on). Studio API access is on, so the DataStore works in Studio.

### M0 Pipeline: done
- Studio connected. Round trip proven: created `ServerScriptService.PipelineCheck` with `multi_edit`, read it back, saw `PIPELINE_OK` in a playtest log, deleted it.
- All of `src/` pushed into Studio (22 scripts). 23 Edit-mode unit tests pass (`ServerScriptService.Tests`, run with `TestRunner.runAll`).
- Push path: `multi_edit` per script. The faster localhost sync (`tools/sync/`) worked until a Studio update started blocking localhost (see Waiting on Stewart). `tools/sync/checksums.luau` plus `tools/sync/verify.py` confirm Studio matches `src/` byte for byte (last check: all match).

### M1 Gray-box lake: done
- `WorldBuilder.build()` run in Edit, so the lake is saved in the place: terrain water 220 x 160, dock from the south shore to z 35, weed bed (south-west), five fallen logs (south-east), deep hole with a red buoy (north of the dock), shore path loop, Sell Fish and Bait and Tackle stands, spawn on the dock.
- Playtest: spawned on the dock at (0, 4.9, 74) with a rod in hand; overview screenshot shows every feature; clock went 7.144 to 7.177 in 2 s (16 minute day), HUD shows "7:14 AM Dawn".

### M2 Cast and catch: done
- Playtest: real mouse hold and release cast the line ("Waiting for a bite at the dock..."), bobber and line visible.
- Bite came about 1.4 s later at dawn on worms. A real click after the bite arrived too late (MCP tool latency is longer than the hook window) and the game correctly said "Too slow! It spat the hook." Hooking was then driven through the same input handler by the Studio-only `DebugAutoFish` test hook.
- The fight was finished with the real mouse button held: caught a Pumpkinseed, 19.2 cm, 0.13 kg, worth 6 coins. Catch card, bag (1 fish, 6), worm count (15 to 14) all updated; server log: `caught Pumpkinseed 19.2 cm 0.13 kg worth 6 at Dock (Dawn, Worm)`.
- A cast aimed at the shore is refused: "That landed on dry ground. Face the water and cast."
- Hook window raised from 1.6 s to 2 s to be kinder to kids and touch players.

### M3 Real fish habits: done
- 8 species in `FishData.luau`, each with spots, times, baits, size range, price and its own fight. Unit tests check the key rules.
- Playtest (one session, fishing through the real remotes with the Studio auto-reel hook):
  - Dock, dawn, worms: Yellow Perch, Bluegill, Yellow Perch, Bluegill, Pumpkinseed.
  - Deep hole from the dock end, 10 PM, stinkbait: Channel Catfish three times (2.49, 1.52, 3.96 kg).
  - Weed bed from the south-west shore, 5:51 AM, minnows: Largemouth Bass three times (0.73, 1.21, 1.70 kg).
  - Weed bed, dawn, stinkbait: no bite; after 12 s the hint "Nothing wants stinkbait at the weed bed right now. Try another bait, another spot, or another time of day." showed on screen.
- Night screenshot: dark sky, stars, HUD "10:54 PM Night".

### M4 Money and shop: done
- Walked to the Fish Buyer and pressed E: "Sold 6 fish for 27 coins." (30 to 57 coins; server log matches).
- Walked to Bait and Tackle, pressed E, the shop opened; clicked Buy on Stinkbait and Minnows: 57 to 41 to 21 coins, "You have 10" for each.
- Backspace closed the shop; the B key cycled bait to stinkbait. Equipped bait changed the catch as above.
- Free worms when broke: covered by unit tests and the cast path; not forced in a playtest.

### M5 Journal and saving: done
- J opened the Fish Journal: 5 of 8 species found, 12 fish caught; each card shows count, best weight and length, bait and spot, and the habit line after the first catch; uncaught species show "???". The Reel assist button toggled On to Off.
- Studio API access is on, so the DataStore is live: stopping play logged `saved ProBabyTurtle`; restarting loaded `21 coins, 12 caught`, bag 6 fish (173), Minnows x7.
- Memory fallback checked earlier in an unsaved place: `DataStore unavailable (...). Using memory only; progress will not save.`

### M6 Controls and polish: done
- Phone (Device Simulator, Samsung Galaxy A06, 705 x 338, the smallest phone in the list): the first pass found the Roblox touch button tiny (45 px) and sitting on the jump button, the fight panel overlapping the top bar, its help text cut off, and the journal taller than the screen. Fixed: a big 110 px Fish button left of jump (hold and release like a mouse), fight panel moved left of center and shortened, side buttons hidden during a fight, panels shrink to fit. Second pass: touch hold and release cast ("Waiting for a bite at the dock..."), touch hold lifted the catch zone, journal fits, fight panel clears the top bar (y 39 vs 37), status says "Hold the Fish button".
- Gamepad (key codes through the input tool, plus the Xbox One screen in the simulator): D-pad right cycled bait, R2 hold and release cast, R2 press reeled back in, Y opened the journal, B closed it; on the console screen the hint reads "Hold R2 and let go to cast" and the Journal button shows (Y).
- Keyboard and mouse regression after the changes: mouse cast, fight, Pumpkinseed landed, no errors in the log. 23 unit tests pass; Studio matches `src/` (checksums all match).
- Sounds: cast, splash, bite, catch and click use Roblox's built-in sounds; all five load.
- The game is locked to landscape (fishing plays sideways).
- Studio reset to the default viewport after testing.

## What works now
A full loop on keyboard and mouse, touch and gamepad: cast from the dock or shore, wait for a bite, hook it, fight it on the bar, land it, sell at the Fish Buyer, buy bait at Bait and Tackle, and fill the journal. Eight species follow real habits (spot, time of day, bait), the day runs 16 minutes, and progress saves to Roblox.

## What's left (next version, after Stewart and Liam playtest)
- Tuning from real play: bite times, fight difficulty, prices, how dark night is.
- Visible fish and nicer water, a better rod pose (the rod points almost straight up), names on the stands' prompts.
- Later versions from `DESIGN.md`: home pond, better rods and a boat, a second fishing spot, weather, co-op, art pass.
- The test save on Stewart's account has 21 coins and 14 fish from Claude's playtests. Ask Claude to wipe it if you want a fresh start.

## Waiting on Stewart
- Playtest it: open Fishing Game in Studio and press Play (F5).
- Optional, speeds up Claude's builds: in Studio, Assistant Settings, MCP Permissions, Connect to the internet, add `localhost:8765` to the HTTP domain allow list.
- Done already: the place is saved to Roblox and Studio API access is on.
