# Fishing game: design

Approved by Stewart on 2026-11-25. Working title: "Fishing Game" (Liam names it later).

## Intent

Stewart and his son Liam (11, turns 12 on 2026-12-11) want a Roblox game they can play together and eventually publish. Liam is into fishing. Stewart builds the first version alone, with Claude doing the building, before Liam joins as creative director. Long term the game ships with lots of their own models (Blender, Meshy, downloads).

Stewart is not trying to learn to code. Claude builds; Stewart steers and playtests.

## The game

A fishing game with a garden-game style economy: catch fish, earn coins, buy better bait, lures, rods and boats, unlock new water. What makes it different (see `RESEARCH.md`): real fishing knowledge actually matters. The right bait, spot and time of day change what bites, the way they do on a real lake.

## Goals for the first version (M1 to M5 in `PLAN.md`)

- **One lake that plays well, built with plain gray blocks.** Structure players can read: a dock, a weed bed, fallen logs, a deep hole, open water.
- **Catching:** aim and cast to a spot, wait for a bite, reel in with a bar minigame. It starts easy, has an optional assist, and each species fights differently (quick bluegill tugs, bass runs, heavy catfish pulls).
- **Real fish habits:** 6 to 8 real lake fish. Where they hold, when they bite, what bait they want. Example: bluegill by the dock on worms, bass by weeds and logs at dawn and dusk, catfish in the deep hole at night on stinkbait. A day and night cycle drives it.
- **Economy:** sell stand for coins; a bait and tackle shop (worms, crickets, minnows, stinkbait, a spinner, a plastic worm). The best bait is the right bait, not the most expensive one.
- **Fish journal:** every catch logged with species, length, weight, bait, spot and time; personal bests per species.
- **Saving:** coins, bait inventory and journal persist across sessions.
- **Works on keyboard and mouse, touch and gamepad** from the start.

## Later versions (in order)

1. Home pond: keep live fish; they grow and breed while you're away, with a cap on offline growth. (Done.)
2. Better rods and reels and a second fishing spot to unlock. (Done: three rods, Cedar Creek.)
3. Core fishing mechanics: every species bites and fights in its own way. (Stewart, 2026-11-26: "get the fishing core mechanics (different for different fish etc)" first.)
4. A single-player boat: an inflatable dinghy that reaches the Big Lake.
5. A boat that needs two players to pilot, and rewards them by reaching the deep "blue water" (for when Liam plays).
6. Weather that acts like the real thing, special fish versions.
7. Art pass: replace gray blocks with their own models (Blender, Meshy, Creator Store). A first set of 32 models exists in `art/`.

## Non-goals and anti-goals

- No Robux items, no pay-for-luck, no flashing shops. If money comes later, cosmetics only.
- No player trading early (scam problem in other games).
- No public release yet. New games launch to 16+ only under 2026 Roblox rules anyway.
- No custom chat. Roblox's built-in chat only (age and parent settings apply).
- No copying other games' names, art, fish lists or UI. General ideas (rarity, a fish book, a bar minigame) are fine.
- No real place names, family names or the real ranch.
- Anti-goal: a minigame that's too hard at the start (Stardew's mistake) or so easy it becomes auto-clicking.
- Anti-goal: updates that make earlier progress feel useless (Fisch's Second Sea).

## Constraints

- Roblox Studio, Luau, built through Roblox's official Studio MCP server (configured for Claude Code in this folder as `Roblox_Studio`, local scope).
- Rating target Minimal or Mild.
- Server-authoritative economy: the client never decides catches, coins or prices.
- DataStores need "Enable Studio Access to API Services" (Game Settings, Security), which only Stewart can turn on, and the place must be saved to Roblox. Until then saving must fall back gracefully (in-memory) and say so in the output log.

## Approaches considered

1. **Claude builds systems, Stewart builds world and models, small scripts as lessons.** Offered; Stewart declined (not interested in learning to code).
2. **Stewart writes all the code with Claude as tutor.** Declined for the same reason.
3. **Claude builds everything; Stewart steers and playtests.** Chosen.

Toolchain: code is authored as files in this repo (`src/`) and pushed into Studio through the MCP server; Studio's Script Sync (beta) can later make the sync two-way, which needs Stewart to right-click the containers in Studio once. Rojo is held in reserve.

## Left to the builder

Module layout, remotes, the exact minigame tuning, fish stats, prices, UI layout and gray-box geometry, as long as they serve the goals above. Record notable calls in `DECISIONS.md`.
