# Roblox Fishing Game: Technical & Design Review Package

- **Repository:** [Samizdat-Publications/roblox-fishing-game](https://github.com/Samizdat-Publications/roblox-fishing-game)
- **Audit Date:** 11/26/2026
- **Core Hook:** Real fishing knowledge (`spot x time x bait x weather x rarity`) drives bites, paired with a Fish Journal and offline-growing Home Pond.

## Direct Verdict

The core premise is a standout for a game you are building with Liam. Real spot/time/bait weighting in `FishLogic.luau`, persistent PBs in the Fish Journal, and an offline-growing Home Pond (`PondLogic.luau`) give this real depth compared to generic Roblox clicker-fishing simulators.

Three issues currently hold the live experience back:
1. **Five major systems are switched off:** `WEATHER_ON`, `FRENZIES_ON`, `GOALS_ON`, `BIG_LAKE_ON`, and `BOATS_ON` are all `false` in `Config.luau`, and several overnight modules are marked `-- UNVERIFIED in Studio`.
2. **Flat fight tension & fast gear cap:** Default `assist = true` plus `FIGHT_START = 0.4` and `FIGHT_IDLE_GRACE = 2.5s` makes fights feel automatic, while smart anglers earn 161 coins/min and cap out all active upgrades (~1,550 coins total) in roughly 10 minutes.
3. **Static lighting & gray-box water:** `DayNight.luau` never changes mood colors across Dawn/Day/Dusk/Night even though time of day drives the bite math, and `WorldBuilder.luau` still uses a rectangular `220x160` water box.

---

## 1. Feature-Gate & Studio Verification Audit

| Flag / Module | Current State | Status in Code | Gameplay Impact |
| :--- | :--- | :--- | :--- |
| `WEATHER_ON = false` (`WeatherService.luau`) | Disabled | Unverified ("first guess" Atmosphere values) | Removes weather multipliers and Mythic weather catches; lake mood stays static. |
| `GOALS_ON = false` (`GoalService.luau`) | Disabled | Disabled in `Config.luau` | Missing short-term quests that naturally teach spot/time/bait knowledge. |
| `FRENZIES_ON = false` (`FrenzyService.luau`) | Disabled | Disabled in `Config.luau` | Missing burst events that pull players off the dock and break routine casting. |
| `BIG_LAKE_ON = false` / `BOATS_ON = false` | Disabled | `BoatLogic.luau` & Big Lake zones unverified | Cuts off the mid-to-late-game coin sink (boats + `Basin`, `IslandPoint`, `DropOff`). |
| `FishLogic.rollCatch` (`normal`/`trophy`/`monster`) | Active | Marked unverified in Studio (11/26/2026) | Huge excitement hook once paired with a visible 3D catch-reveal and sound fanfare. |

---

## 2. Gameplay Loop, Fight Feel & Economy Pacing

1. **Fix over-generous fight assist (`Inventory.luau`, `FightModel.luau`, `Config.luau`):**
   - New players default to `assist = true` (`1.4x` catch zone, `0.6x` loss), on top of `FIGHT_START = 0.4` and `FIGHT_IDLE_GRACE = 2.5s`. Your `docs/ECONOMY.md` simulation already proved doing nothing landed 40-69% of fish.
   - **Fix:** Auto-disable Assist after the first 3 tutorial catches (keeping it as an explicit accessibility toggle in settings), drop `FIGHT_START` to `0.25` on Uncommon+ fish, and tighten `FIGHT_IDLE_GRACE` to `1.2s`. Differentiate the 6 fight styles (`tugger`, `steady`, `runner`, `jumper`, `diver`, `shaker`) with distinct visual/audio tells (drag scream on `runner`, surface breach splash on `jumper`).
2. **Turn `"nothing wants this here"` into an actionable hint (`FishLogic.luau`, `UI.luau`):**
   - Waiting 10 seconds (`NOTHING_WAIT = 10`) to see `"nothing wants this here"` enforces real fishing rules, but without a clue it feels like a broken timer to a young player.
   - **Fix:** Attach a 1-line contextual nudge ("Too bright in Open Water at midday: try Weed Bed or Logs") and flip `GOALS_ON = true` first so goals guide Liam through Dawn/Dusk periods and new baits.
3. **Close the 10-minute progression cliff (`RodData.luau`, `Config.luau`, `docs/ECONOMY.md`):**
   - Smart anglers earn 161 coins/min (vs. 59/min random and 28/min dock-and-worms). Even after raising rods in `RodData.luau` from 120/350 to 150/900 coins, the entire active cap (Fiberglass 150c + Creek Pass 500c + Graphite 900c = 1,550c) clears in ~10 minutes.
   - **Fix:** Add one mid-tier rod or specialty lure tier around 350-400 coins, make higher-tier lure wear or snagging give bait costs real weight (currently ~1% of smart income), and re-run `tools/econ/sim.py` against the updated `RodData.luau` prices before tuning Big Lake boats.
4. **Tie the Home Pond back to active fishing (`PondLogic.luau`):**
   - Asymptotic growth (`0.3567/hr`), breeding (`25%` every 1,800s, `< 6` cap, 8h offline cap), and ~540 coins/day is a great return-tomorrow loop, but passive pond cash can overshadow casual dock play.
   - **Fix:** Require feeding pond fish with cheap bait or caught minnows to trigger breeding rolls, and reward raising a bred fish to Trophy size with a Journal badge rather than just raw coins.

---

## 3. Graphics, Time-of-Day Mood & Readable Water Structure

1. **Keyframe Dawn, Day, Dusk, and Night lighting (`DayNight.luau`):**
   - `DayNight.luau` (27 lines) advances `ClockTime` across a 16-minute day (`DAY_LENGTH = 960`), but locks `Brightness = 2`, `OutdoorAmbient = (110, 110, 120)`, and `Ambient = (60, 60, 75)` with no `Sky`, `Clouds`, `SunRaysEffect`, `BloomEffect`, or `ColorCorrectionEffect`.
   - **Fix:** Lerp 4 distinct lighting presets so players immediately feel Dawn (warm gold tint + low `SunRays` + soft mist), Day (crisp clear water), Dusk (amber-copper low sun + water specular `Bloom`), and Night (deep indigo `OutdoorAmbient = (40, 52, 78)` + warm glowing dock lamps + fireflies).
2. **Replace the `220x160` rectangular gray-box shoreline (`WorldBuilder.luau`):**
   - A rectangular `Terrain:FillBlock` inside a flat `y = 1` ring reads as a pool rather than a lake.
   - **Fix:** Carve two coves and a peninsula into the shoreline, vary underwater bed depth from `y = -3` near the dock down to `y = -18` at `DeepHole` (so Roblox Terrain water naturally darkens over deep water), and place unmistakable landmarks over every `FishLogic` spot (lily pads/reeds on `WeedBed`, mossy sunken timber on `Logs`, boulders/foam ripples on Cedar Creek's `Riffle`).
3. **Add tactile client fishing "juice" (`Controller.luau`, `SoundFX.luau`, `UI.luau`):**
   - Layer a curved `Beam` fishing line whose color shifts white -> amber -> red with tension, expanding bobber ripple rings on cast/bite, a bending rod tip driven by fish pull, and a 2-second 3D "hold up your catch" camera zoom + sparkle burst on `"trophy"` and `"monster"` catches.

---

## 4. Repo Hygiene & Save Migration Risks

- **No Rojo `default.project.json`:** Unlike Dead Calm's `rokit.toml` + `default.project.json` + Lune CI pipeline, this repo mirrors Studio folders manually under `src/`. Add `default.project.json` so Studio and GitHub stay synced during overnight Claude Code sessions.
- **Save schema jump (`v=2` in `docs/PROGRESS.md` vs. `v=6` in `Inventory.luau`):** Add an explicit backward-compatibility migration unit test in `ServerScriptService/Tests/` covering `v=2` through `v=6` so Liam's saved coins, journal, and home pond never wipe when `GOALS_ON` or `BOATS_ON` flip true.
- **Fog white-out risk in `WeatherService.luau`:** `Fog` uses `Atmosphere.Density = 0.62` and `Haze = 3`, which can obscure a bobber at max cast distance (56 studs with Graphite Rod). Cap fog density at `0.45` and sync Wind/Cold Front with `Terrain.WaterWaveSize` and `Clouds.Cover`.

---

## 5. Prioritized Upgrade Roadmap

| Priority | Target File(s) | Concrete Action |
| :--- | :--- | :--- |
| **P0 (Now)** | `DayNight.luau`, `WorldBuilder.luau` | Add 4-period Dawn/Day/Dusk/Night lighting lerp; sculpt coves + deep bathymetry; place clear props over every `FishLogic` spot. |
| **P0 (Now)** | `Config.luau`, `FightModel.luau`, `Inventory.luau` | Auto-disable Assist after 3 catches, tighten `FIGHT_IDLE_GRACE` to `1.2s`, and add contextual spot/time hints on `NOTHING_WAIT`. |
| **P1 (Unblock)** | `Config.luau`, `GoalService.luau`, `WeatherService.luau` | Studio-verify and flip ON `GOALS_ON` first, then `WEATHER_ON` (capped fog + wave/cloud sync) and `FRENZIES_ON`. |
| **P1 (Juice)** | `Controller.luau`, `UI.luau`, `SoundFX.luau` | Add bobber ripples, tension-tinted `Beam` line, per-style fight VFX, and Trophy/Monster catch-reveal fanfare. |
| **P2 (Scale)** | Root + `BoatLogic.luau` + `Tests/` | Add `default.project.json`, write `Inventory` v2-to-v6 migration test, re-run `sim.py`, then verify and enable `BIG_LAKE_ON` + `BOATS_ON`. |
