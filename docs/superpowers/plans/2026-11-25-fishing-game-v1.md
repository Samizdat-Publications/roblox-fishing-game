# Fishing Game v1 (M0 to M6) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A playable gray-box Roblox fishing game where bait, spot and time of day decide what bites, with a bar-fight minigame, sell stand, bait shop, journal and saving, on keyboard and mouse, touch and gamepad.

**Architecture:** All game rules live in pure ModuleScripts in `ReplicatedStorage.Shared` (data tables plus deterministic logic) so they can be unit tested in Edit mode through `execute_luau`. Thin server services in `ServerScriptService.Server` own state, remotes, saving and the world; one client controller in `StarterPlayerScripts` owns input and a code-built UI. The client never decides a fish, a size, a price or a coin total; it only plays the fight and reports the outcome, which the server sanity-checks against the fight's minimum duration.

**Tech Stack:** Roblox Studio, strictly typed-ish Luau (`--!strict` where practical), Studio MCP server (`Roblox_Studio`), a tiny local sync (Python manifest builder plus `python -m http.server`) that a Luau snippet pulls from through `execute_luau`; `multi_edit` is the fallback push path.

**Spec:** `docs/DESIGN.md` (approved 2026-11-25), milestones in `docs/PLAN.md`.

## Global Constraints

- No em dashes in any player-facing text, docs or commit messages.
- Server-authoritative economy: the client never decides catches, coins or prices.
- No Robux items, no trading, no custom chat. Rating target Minimal or Mild.
- Original names and gray-box geometry only; real lake species are fine, no other game's lists or UI.
- Every control works on keyboard and mouse, touch and gamepad.
- DataStores fall back to memory when Studio API access is off, and say so in the output log.
- Source of truth is `src/`; never leave a script edited only in Studio.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; push to `origin main` after each milestone.

## Review Focus

1. Player with zero bait and too few coins to buy any: the shop must give a free handful of worms so nobody is soft-locked (test in Task 5).
2. Cast that lands on land or past the lake edge: server rejects it with a friendly hint, state returns to Idle (test in Task 3 via `FishLogic.isOnWater`).
3. Spot, time and bait combo with no matching fish: no bite ever comes; after the wait the player gets a hint, not silence (test in Task 2: empty weights; Task 6 handles the hint).
4. Client sends `FightResult(true)` instantly or while not fighting: server treats it as an escape and pays nothing (test in Task 3: `FightModel.minSeconds`).
5. Player leaves mid-fight or mid-cast: server cleans up the bobber and state without errors, and data still saves (checked in the M5 playtest log).

## File Structure

```
tools/sync/build_manifest.py      builds build/manifest.json from src/ (path, className, source)
tools/sync/sync.luau              snippet pasted into execute_luau: fetch manifest, create or update scripts
src/ReplicatedStorage/Shared/
  Config.luau        tunables: day length, cast range, start coins, bite timing, fight constants
  FishData.luau      8 species: habits, sizes, prices, fight profile
  BaitData.luau      6 baits: kind (live or lure), pack size, price, display name
  FishLogic.luau     periodFromClock, spotAt, biteWeights, pickSpecies, rollSize, priceFor, isOnWater, biteDelay
  FightModel.luau    deterministic bar-fight sim: new, step, minSeconds
  Inventory.luau     buy, consumeBait, hasBait, sellAll, recordCatch, freeWormsIfStuck, snapshot
  Remotes.luau       names and a get(name) helper (server creates, client waits)
src/ServerScriptService/
  Main.server.luau   boot: build world if missing, start services
  Server/WorldBuilder.luau   gray-box lake, zones, stands, spawn
  Server/DayNight.luau       advances Lighting.ClockTime
  Server/PlayerData.luau     load/save with DataStore or memory fallback, autosave
  Server/FishingService.luau per-player cast/bite/fight state machine, bobber and line
  Server/EconomyService.luau sell prompt, buy remote, equip remote, state push
  Server/RodService.luau     welds a gray rod to each character
  Tests/TestRunner.luau      tiny assert runner
  Tests/*.spec.luau          FishLogic, FightModel, Inventory specs
src/StarterPlayer/StarterPlayerScripts/
  Client.client.luau          boot: UI + controller
  ClientModules/UI.luau       code-built ScreenGui: HUD, minigame, shop, journal, toasts
  ClientModules/Controller.luau input (ContextActionService), fishing client states, fight loop
```

Shared spot names: `Dock`, `WeedBed`, `Logs`, `DeepHole`, `OpenWater`. Periods: `Dawn` (5 to 8), `Day` (8 to 17), `Dusk` (17 to 20), `Night` (20 to 5). Bait ids: `Worm`, `Cricket`, `Minnow`, `Stinkbait`, `Spinner`, `PlasticWorm`.

---

### Task 1 (M0): Pipeline and sync

**Files:** Create `tools/sync/build_manifest.py`, `tools/sync/sync.luau`, `src/ServerScriptService/Tests/TestRunner.luau`; modify `.gitignore` (add `build/`).

**Interfaces:** Produces the push path every later task uses: run `python tools/sync/build_manifest.py`, keep `python -m http.server 8765` running in the repo root, paste `sync.luau` into `execute_luau` (Edit). Mapping: `X.server.luau` to Script, `X.client.luau` to LocalScript, `X.luau` to ModuleScript, folders to Folder, first path segment is the service. `TestRunner.run(specs: {ModuleScript}) -> (passed: number, failed: {string})`.

- [ ] `list_roblox_studios` gives the studio id; a place is open.
- [ ] Round trip: create `ServerScriptService.PipelineCheck` (prints `PIPELINE_OK`), read it back, start play, see `PIPELINE_OK` in console, stop, delete it.
- [ ] Sync: manifest push creates `ServerScriptService.Tests.TestRunner`; second push updates without duplicates. If localhost HTTP is blocked, fall back to `multi_edit` and record it in `DECISIONS.md`.
- [ ] `save_place` (record NeedsUserAction under Waiting on Stewart if the place was never saved). Log in PROGRESS, commit, push.

### Task 2 (M3 data, built early): Shared data and FishLogic

**Files:** Create `Config.luau`, `FishData.luau`, `BaitData.luau`, `FishLogic.luau`, `Tests/FishLogic.spec.luau`.

**Interfaces:**
- `FishData.list: {Species}`, `FishData.byId: {[string]: Species}`; Species = `{id, name, spots: {[Spot]: number}, periods: {[Period]: number}, baits: {[BaitId]: number}, rarity: number, minCm, maxCm, weightCoef (kg = coef * cm^3), basePrice, fight: FightProfile, habit: string}`.
- `BaitData.list`, `BaitData.byId`; Bait = `{id, name, kind: "live"|"lure", pack: number, price: number, blurb}`.
- `FishLogic.periodFromClock(clock: number) -> Period`
- `FishLogic.biteWeights(spot, period, baitId) -> {{id: string, w: number}}` (product of rarity, spot, period and bait factors; zero factors excluded)
- `FishLogic.pickSpecies(weights, rng: Random) -> string?`
- `FishLogic.biteDelay(weights, rng) -> number?` (nil when no weights; total weight shortens the wait between `Config.BITE_MIN` 3 s and `Config.BITE_MAX` 14 s)
- `FishLogic.rollSize(species, rng) -> (lengthCm: number, weightKg: number)`
- `FishLogic.priceFor(species, weightKg) -> number` (integer, at least 1)
- `FishLogic.spotAt(pos: Vector3, zones: {{name, cframe, size}}) -> Spot` (first containing zone, else `OpenWater`)
- `FishLogic.isOnWater(pos, waterCFrame, waterSize) -> boolean` (XZ inside the water box)

Species (habit, spots, periods, baits): Bluegill (Dock, WeedBed; Day; Worm, Cricket), Pumpkinseed (WeedBed, Dock; Day, Dawn; Cricket, Worm), Yellow Perch (OpenWater, Dock; Dawn, Day; Minnow, Worm), Black Crappie (Logs, Dock; Dusk, Night; Minnow), Largemouth Bass (WeedBed, Logs; Dawn, Dusk; PlasticWorm, Spinner, Minnow), Channel Catfish (DeepHole; Night, Dusk; Stinkbait, Worm), Common Carp (OpenWater, DeepHole; Day; Worm, Stinkbait), Northern Pike (WeedBed, OpenWater; Day, Dawn; Spinner, Minnow; rare).

- [ ] Spec asserts: `periodFromClock(6)=="Dawn"`, `12=="Day"`, `18.5=="Dusk"`, `23=="Night"`, `2=="Night"`; top of `biteWeights("Dock","Day","Worm")` is Bluegill; top of `("DeepHole","Night","Stinkbait")` is Channel Catfish; top of `("WeedBed","Dawn","PlasticWorm")` is Largemouth Bass; `("Dock","Day","Stinkbait")` has no Bass; `biteWeights("Logs","Day","Stinkbait")` is empty and `biteDelay` of it is nil; 200 `rollSize` draws stay inside min and max; `priceFor` grows with weight; `isOnWater` false for a point 5 studs past the edge.
- [ ] Implement, run via TestRunner in Edit, all pass. Commit.

### Task 3 (M2 core): FightModel

**Files:** Create `FightModel.luau`, `Tests/FightModel.spec.luau`.

**Interfaces:** FightProfile = `{zone, speed, dart, range, sink, heavy, gain, loss}`. `FightModel.new(profile, assist: boolean, seed: number) -> State`; `FightModel.step(state, dt, holding: boolean) -> "won"|"lost"|nil`; `FightModel.minSeconds(profile, assist) -> number` (start progress `Config.FIGHT_START` 0.35 to 1 at full gain). State exposes `fishPos`, `zonePos`, `zoneSize`, `progress` (all 0 to 1) for the UI.

- [ ] Spec asserts: a tracking bot (hold when zone below fish) wins every species within 60 s of 1/30 s steps, assist off; a bot that never holds loses Bluegill; with assist on, a noisy bot (wrong input 25% of steps) wins Bluegill; `minSeconds` is positive and less than the tracking bot's win time; same seed gives the same result twice.
- [ ] Implement, tests pass, commit.

### Task 4 (M1): World, day and night

**Files:** Create `Server/WorldBuilder.luau`, `Server/DayNight.luau`, `Main.server.luau`.

**Interfaces:** `WorldBuilder.build(): Model` builds `Workspace.Lake` (Water part 220 x 160 centered at origin, top at y 0; ground ring top at y 1; dock at x 0 from z 80 out to z 35; zones folder `Lake.Zones` with invisible boxes named by spot; weed bed west-south, logs east-south, deep hole center-north z -50 to 0; shore path; `Lake.SellStand` and `Lake.ShopStand` with ProximityPrompts named `SellPrompt` and `ShopPrompt`; SpawnLocation on the dock). `WorldBuilder.zones() -> {{name, cframe, size}}`, `WorldBuilder.water() -> (CFrame, Vector3)`. `DayNight.start()` starts at clock 7, `Config.DAY_LENGTH` 960 s per full day.

- [ ] Build once in Edit through `execute_luau` so the geometry is saved in the place; Main rebuilds only if `Workspace.Lake` is missing.
- [ ] Playtest: spawn on the dock, screenshot the lake, clock advances in the console. Log, save, commit, push (M1).

### Task 5 (M2 to M5 server): Inventory, data and services

**Files:** Create `Inventory.luau`, `Tests/Inventory.spec.luau`, `Remotes.luau`, `Server/PlayerData.luau`, `Server/FishingService.luau`, `Server/EconomyService.luau`, `Server/RodService.luau`.

**Interfaces:**
- Data = `{v=1, coins, bait: {[BaitId]: number}, lures: {[BaitId]: true}, equipped: BaitId, bag: {Fish}, journal: {entries: {Fish}, bests: {[speciesId]: Fish}, counts: {[speciesId]: number}}, assist: boolean}`; Fish = `{id, name, cm, kg, price, bait, spot, period, at}`.
- `Inventory.new() -> Data` (30 coins, 15 worms, equipped Worm, assist true); `buy(data, baitId) -> (ok, msg)`; `hasBait(data, id)`; `consumeBait(data, id)` (lures never consumed); `sellAll(data) -> (coins, count)`; `recordCatch(data, fish) -> isNewBest`; `freeWormsIfStuck(data) -> boolean` (no live bait, no lure, coins below cheapest pack: give 5 worms); `snapshot(data) -> table` (what the client sees).
- Remotes (in `ReplicatedStorage.Remotes`): RE `Cast(dir: Vector3, power: number)`, RE `Hook()`, RE `FightResult(won: boolean)`, RE `CancelCast()`, RE `FishingEvent(kind, payload)` server to client with kinds `Landed`, `Bite`, `Missed`, `Hooked`, `Caught`, `Escaped`, `Reset`, `Hint`; RE `State(snapshot)`; RF `RequestState()`; RF `Buy(baitId) -> (ok, msg)`; RE `Equip(baitId)`; RE `SetAssist(on)`.
- `PlayerData.get(player) -> Data?`, `PlayerData.changed(player)` (pushes State), memory fallback logs `[PlayerData] DataStore unavailable ... progress will not save`.
- Fishing states per player: Idle, Waiting (bobber out), Bite (hook window `Config.HOOK_WINDOW` 1.6 s), Fighting. Bait is consumed on hook. Cast range 8 + power * 32 studs from the character, flat camera direction.

- [ ] Inventory spec: buy with too few coins fails; buying a lure twice fails; buying worms adds the pack; `consumeBait` leaves lures; `sellAll` empties the bag and sums prices; `recordCatch` flags a heavier fish as a new best and a lighter one not; `freeWormsIfStuck` fires only when stuck.
- [ ] Implement services; tests pass; commit.

### Task 6 (M2 to M5 client): Controller and UI

**Files:** Create `Client.client.luau`, `ClientModules/UI.luau`, `ClientModules/Controller.luau`.

**Interfaces:** One `Fish` action bound through ContextActionService to MouseButton1, ButtonR2 and a touch button: hold to charge and release to cast; press during a bite to hook; hold during the fight to lift the zone; press while waiting to reel in. `J` or ButtonY opens the journal, `B` or ButtonX cycles bait, the shop opens from `ShopPrompt` (client side), Escape or ButtonB closes panels. UI: top bar with coins, clock and period, bait button; power meter; vertical fight bar with fish marker, green zone and progress; shop list; journal grid of 8 species with bests, hints after first catch; toasts.

- [ ] M2 playtest: cast from the dock, bite, hook, win a fight, see the catch toast and the fish in the log.
- [ ] M3 playtest: force clock and bait through `execute_luau` (Server) to catch Catfish at night in the deep hole and Bass at dawn in the weeds.
- [ ] M4 playtest: sell at the stand (coins rise), buy minnows, equip, catch changes.
- [ ] M5 playtest: journal shows bests; stop and restart play, data persists or memory fallback is logged.
- [ ] Each milestone: log, save, commit, push.

### Task 7 (M6): Controls and polish

- [ ] Device emulator (phone): HUD readable, touch Fish button present and works through the full loop.
- [ ] Gamepad: R2 casts and fights, Y journal, X bait, shop navigable with GuiService selection.
- [ ] Cheap sounds (cast, bite, catch) from default Roblox sound ids if insertable; otherwise skip and note.
- [ ] Final PROGRESS: what works, what's left, Waiting on Stewart. Save, commit, push.
