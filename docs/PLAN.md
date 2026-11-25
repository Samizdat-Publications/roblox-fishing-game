# Build plan

Milestones for the first version. Each one ends with a playtest through the Studio MCP server (start play, drive the character, screenshot, read the output log) and a commit.

| # | Milestone | Done when |
|---|---|---|
| M0 | Pipeline | Studio connected, a test script round-trips (create, read, run in a playtest, read the log, delete), `src/` layout pushed into Studio, place saved |
| M1 | Gray-box lake | Lake with dock, weed bed, logs, deep hole, open water, shore path, sell stand and shop stand; spawn on the dock; day and night cycle running |
| M2 | Cast and catch | Aim and cast to a spot, bite after a wait, bar minigame with an optional assist; one species catchable end to end on keyboard and mouse |
| M3 | Real fish habits | 6 to 8 species with spot, time and bait rules; each fights differently; length and weight per catch |
| M4 | Money and shop | Sell stand pays coins (server-side); bait and tackle shop; equipped bait changes what bites |
| M5 | Journal and saving | Journal UI with personal bests; coins, bait and journal save and load (falls back to memory when Studio API access is off) |
| M6 | Controls and polish | Full loop on touch and gamepad; HUD readable on phone in the device emulator; sounds where cheap |

Later versions (pond, boat, weather, co-op, art pass) get planned after M6 and a playtest with Stewart.

## Status

See `PROGRESS.md`.
