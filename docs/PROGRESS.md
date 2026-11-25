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

## What's next
- M3 real fish habits playtest (night catfish in the deep hole, dawn bass in the weeds), M4 money and shop, M5 journal and saving, M6 controls and polish.

## Waiting on Stewart
- Optional, speeds up Claude's builds: in Studio, Assistant Settings, MCP Permissions, Connect to the internet, add `localhost:8765` to the HTTP domain allow list.
