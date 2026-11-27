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
- Studio API access is on, so the DataStore is live: stopping play logged the save for the test account; restarting loaded `21 coins, 12 caught`, bag 6 fish (173), Minnows x7.
- Memory fallback checked earlier in an unsaved place: `DataStore unavailable (...). Using memory only; progress will not save.`

### M6 Controls and polish: done
- Phone (Device Simulator, Samsung Galaxy A06, 705 x 338, the smallest phone in the list): the first pass found the Roblox touch button tiny (45 px) and sitting on the jump button, the fight panel overlapping the top bar, its help text cut off, and the journal taller than the screen. Fixed: a big 110 px Fish button left of jump (hold and release like a mouse), fight panel moved left of center and shortened, side buttons hidden during a fight, panels shrink to fit. Second pass: touch hold and release cast ("Waiting for a bite at the dock..."), touch hold lifted the catch zone, journal fits, fight panel clears the top bar (y 39 vs 37), status says "Hold the Fish button".
- Gamepad (key codes through the input tool, plus the Xbox One screen in the simulator): D-pad right cycled bait, R2 hold and release cast, R2 press reeled back in, Y opened the journal, B closed it; on the console screen the hint reads "Hold R2 and let go to cast" and the Journal button shows (Y).
- Keyboard and mouse regression after the changes: mouse cast, fight, Pumpkinseed landed, no errors in the log. 23 unit tests pass; Studio matches `src/` (checksums all match).
- Sounds: cast, splash, bite, catch and click use Roblox's built-in sounds; all five load.
- The game is locked to landscape (fishing plays sideways).
- Studio reset to the default viewport after testing.

## 2026-11-25 (evening): fixes from Stewart's first playtest

Stewart: "several occasions where no matter how hard I clicked it didn't move that much, also clicking certain parts of the screen cause you to lose the fish, make it more clear where you should be clicking."

### Root causes (measured, not guessed)
1. **Clicks did almost nothing.** The catch zone only rose while the button was held and had to build speed from zero. Measured: 2 s of quick clicks lifted it 0.00 to 0.04 of the bar; even half a second of holding lifted it only 0.19 to 0.25.
2. **Some screen spots ate the clicks.** Clicking the left-side Journal button (or pressing J) opened the journal mid-fight, and while any panel was open the game ignored every fishing click, so the fish swam off. Reproduced in a playtest: with the journal open, clicks on open water and on the fight bar did not reach the game.
3. **Reel assist was off on Stewart's save.** Claude switched it off during the M5 journal test and it saved, so Stewart played the harder mode.

### Fixes
- New fight model: holding drives the zone to a steady climb within a fraction of a second, every fresh click or tap starts it climbing at once, and the motion is computed exactly so frame rate doesn't matter. Heavy fish only slow the climb a little. Now: half a second of holding lifts the zone 0.52 to 0.59 of the bar; 2 s of quick clicks lifts it 0.29 to 0.42. Species still differ (catfish take almost twice as long to land as bluegill). Fights start a bit easier (progress starts at 40%).
- From the bite to the end of the fight, a click or touch anywhere on screen reels, read straight from the input service so nothing under the cursor can swallow it. Space, F, gamepad R2, A and R1 reel too. Panels can't open, the side buttons hide, and the character stands still (so jump keys reel instead of jumping).
- Clear prompts: a big "HOLD TO REEL" box beside the bar with how to do it on this device ("Hold the mouse anywhere, or Space", "Hold anywhere on the screen", "Hold R2 or A"); it turns green and says "REELING!" while you hold. A cue rides beside the catch zone: "HOLD" (fish above), "LET GO" (fish below), "Nice!" (fish inside). The zone gets a white outline while held; on touch the Fish button becomes a gold REEL button that turns green when pressed.
- No stray recasts or cancels: after a fight the button must be let go and 0.8 s must pass before it can cast again; a press in the first 0.6 s after the bobber lands doesn't reel it back in; if the server never answers a hook or result, the client returns to idle after 4 s instead of getting stuck.
- Saves from before this change get reel assist turned back on (data version 2).

### Verified in playtests
- Unit tests: 29 pass, including new ones: holding half a second lifts at least a third of the bar for every species, quick clicks lift at least a quarter, 15 vs 120 fps differ by under 0.04, a player who only clicks lands panfish, a player who reacts a quarter second late lands bluegill with assist, species still differ, old saves get assist back.
- Mouse: four quick clicks on the spot where the Journal button sits lifted the zone 0.20 to 0.66; holding over the top bar took it to the top, with "REELING!", the outline and "Nice!" on screen. A Yellow Perch was landed; letting go of the button afterwards did not recast. Mid-fight J and B did nothing, Space reeled, the character had walk speed 0 and jump 0, and both came back (16 and 50) after a Bluegill was landed.
- Gamepad codes: R2 hold lifted the zone 0.21 to 0.79 in half a second; A taps lifted it too.
- Touch (phone simulator): a touch near the top of the screen, away from any button, lifted the zone 0.20 to the top in about 0.6 s; the button turned into a green REEL button; the jump button hid during the fight.
- Stewart's save loaded with reel assist back on.

### Polish pass (same evening)
- **Tuning:** weak combos now bite within 11 s instead of 14; "nothing here" hint after 10 s instead of 12. Prices left as they are until real play says otherwise.
- **Night you can fish in:** brighter night ambient, lamp posts at the dock end and both stands, and a small light on the bobber. Night screenshot: the dock end sits in a pool of lamp light.
- **Visible fish:** dark fish shadows cruise under the surface, and how many each spot shows follows the real bite rules. Measured in play: at dawn dock 4, weed bed 3, logs 2, deep hole 1; at 10 PM weed bed 0, logs 3, deep hole 2, dock 2. So reading the water now teaches where to fish.
- **Catch on the line:** a landed fish hangs from the rod tip for about 2.5 s, colored by species and sized by length, with a little wiggle (screenshot: a yellow perch). The catch card moved right of center so it doesn't cover the fish.
- **Rod pose:** the rod now points forward and about 35 degrees up from the character's facing, instead of nearly straight up.
- **Signs:** the stand signs read from 400 studs instead of 120. The lake model always loads in full (it's small), which also fixed the fish shadows missing from the spots on first load.
- **Nicer water:** a little more wave, reflection and clarity.

### Home pond (next version, item 1 from DESIGN.md): done
Plan: `docs/superpowers/plans/2026-11-25-home-pond.md`. Stewart said to make the design calls ourselves for now (Liam fills in the planner later).
- A stone-rimmed pond on the grass east of the stands with a "Your Pond" sign. Walk up and press E (gamepad X) to open the Pond panel.
- Keep up to 6 fish from your bag. They grow toward full size (30 percent of the remaining gap each hour) and two grown fish of a kind can have babies. Time away counts, up to 8 hours. Sell a pond fish at its current, bigger size, or let it go.
- Each player sees their own pond fish swimming, colored by species and sized by length.
- Old saves get an empty pond (data version 3).
- Verified: 38 unit tests pass (9 new pond tests: growth math, size cap, negative time, a week away equals 8 hours, breeding needs two grown fish and never overfills, keep refuses when full, sell pays once, old saves upgrade). Playtest: E opened the panel; Keep on a 47.8 cm and a 42.7 cm bass moved them into the pond (bag 14 to 12) and both swam there; a Studio-only 3 hour fast-forward grew them to 55.8 and 54.1 cm (worth 50 and 46, up from 34 and 26) and bred young bass up to the 6 fish limit; Sell paid 50 coins (21 to 71); after a restart the pond still had all 5 fish; gamepad X opened and B closed the panel.
- Tuned after the playtest: breeding chance halved (four babies in three hours was too fast), birth messages grouped ("4 baby Largemouth Bass were born"), and the panel always opens scrolled to the top.

### Rods (next version, item 2, part 1): done
Plan: `docs/superpowers/plans/2026-11-25-rods-and-creek.md`.
- Three rods in Bait and Tackle under a new Rods heading: Willow Rod (everyone starts with it), Fiberglass Rod (120 coins: casts 8 studs further, catch zone 15 percent bigger), Graphite Rod (350 coins: 16 studs further, zone 30 percent bigger, heavy fish pull half as hard). Buying equips it; owned rods switch with "Use this rod". The rod in hand changes color and length.
- Data version 4 gives older saves the Willow Rod.
- Verified: 40 unit tests pass (new: buy, equip, refusals, the fight help is applied to a copy, v3 saves upgrade). Playtest: sold the bag (to 261 coins), the shop showed Willow "In your hands", Fiberglass 120 and Graphite greyed out; clicking Fiberglass paid 120 (to 141) and put a yellow 6.6 stud rod in hand. Full-power casts from the same spot: Willow 40.0 studs, Fiberglass 48.0; the same fish's catch zone went from 0.280 to 0.322 of the bar.

### Cedar Creek (next version, item 2, part 2): done
- A stream west of the lake, behind a tall fence with a red gate on the west path. Hold E (gamepad X) at the gate post to buy a Creek Pass for 250 coins (a one second hold, so nobody buys it by accident). The gate opens only for players who own a pass; casts into the creek without one are refused with a hint.
- Three stretches, each its own spot with a new real fish: the riffle (fast shallow water with pebbles) for Rainbow Trout at dawn and in daylight on crickets or a spinner; the rocks (boulders mid-stream) for Smallmouth Bass by day on a spinner, crickets or minnows; the deep pool for Walleye at dusk and after dark on minnows. Creek fish never bite in the lake and lake fish never bite in the creek. Pines, a bank path and a gate lamp.
- Verified: 42 unit tests pass (new: each creek fish tops its spot, none of them bite anywhere in the lake, creek water counts as water and its banks don't). Playtest: walking at the closed gate stopped at it and pathfinding found no route; holding E with 141 coins said "A Creek Pass costs 250 coins. You have 141."; after selling, holding E paid 250 (254 to 4) and the gate went see-through; walked in. Riffle at 6:12 AM on crickets: three rainbow trout (37.2, 35.8, 40.6 cm). Pool at 9:30 PM on minnows: three walleye (57.0, 70.0, 65.4 cm, up to 72 coins). Rocks at noon on minnows: two smallmouth bass. The journal now shows 11 species.
- Found and fixed in the playtest: the riffle's water didn't show (Roblox terrain works in 4 stud cells and a 1.5 stud fill was too thin), and clear shallow water over a gray bed looked dry. The water now fills whole cells and the streambed is blue-gray.

## Overnight, unverified (2026-11-26, Claude in the cloud)

Nothing below has been seen in Studio. All of it is on the branch `claude/overnight-duet-kpkf6f` in draft pull request #1; `main` and the place are unchanged.

### Finished
- **Economy check** (`docs/ECONOMY.md`, `tools/econ/sim.py`): before the changes, a player who knows one good spot buys every shop item inside 10 minutes; worms at the dock earns about a sixth of a big-fish spot; a rare fish that is the only taker bites as fast as a common one, so time of day barely matters for money; with reel assist on, doing nothing at all lands about half the fish. Stewart approved all six and they are now applied in the shared modules (see "Applied after Stewart's go-ahead" below).
- **Boat plan** (`docs/superpowers/plans/2026-11-26-boat.md`): six tasks, each with its Studio playtest. Pure modules with tests, not used by the game yet: `BoatData.luau`, `BoatLogic.luau`, `BigLakeFishData.luau` (white bass, lake trout, muskellunge), `BoatLogic.spec.luau`, `BigLakeFish.spec.luau`.
- **Art pass** (`art/`): 32 models built by script in Blender 5.1.2: dock, both stands, pond rim, three logs, buoy, reeds, lily pads, two pines, a leafy tree, three rocks, all 11 fish, three rods, the bobber, and a Jon Boat for the boat plan. Each is one mesh with vertex colours (no textures), at most about 1,400 triangles, sized in studs to drop onto its gray-box part. Previews and `art/previews/contact-sheet.png`; sizes, triangles and what each replaces in `art/README.md`.
- **Weather spec** (`docs/WEATHER.md`): six kinds that change bites like real weather, how to read each, what is never sold, and a data table.
- **Tests outside Studio**: `lune run tools/test/run.luau` runs every spec with Lune (56 pass and 1 is skipped because it depends on Roblox's exact random draws). `.github/workflows/checks.yml` runs them on every pull request and every push to main; StyLua and Selene report only.

### Applied after Stewart's go-ahead (same night)
- **Economy changes in the code**: bite time rule (`FishLogic.biteDelay`, `Config.BITE_SLOWEST = 40`), new fish, rod, bait and Creek Pass prices, and the slack-line rule in `FightModel` (2.5 s, see `docs/DECISIONS.md`). The simulator now reads these values from the code; results are in `docs/ECONOMY.md`. The creek gate's sign text comes from `Config.CREEK_PASS_PRICE`, but the gate in the place still needs rebuilding in Studio to show 500.
- **Boats reordered** to Stewart's order: first the one-person Inflatable Dinghy (1,200 coins, can't enter blue water), then the two-person Deep-V (4,000 coins, needs two aboard, the only way into the blue-water drop-off). `BoatData`, `BoatLogic.canDrive` and `canEnterBlueWater`, the boat plan (Phase 1 dinghy, Phase 2 Deep-V) and the roadmap in `docs/DESIGN.md`.
- **Fish feel different** (core mechanics, part 1): every species has a fight style and a bite style. Fight styles in `FightModel`: panfish dart (tugger), perch and walleye wander slowly (steady), largemouth make long runs then rest (runner), trout and smallmouth leap to the top (jumper), catfish and carp keep pulling down (diver), pike and muskie shake hard on top of wild runs (shaker). Bite styles in `FishLogic.bitePattern`: panfish nibble the bobber twice first, perch and trout tap lightly, bass and pike slam it under, catfish and carp pull it slowly down with a longer hook window. Tests check that each style shows up, a tracking player still lands every fish, kids with assist still land panfish, and idling never lands anything. The server and client still show one plain bite; wiring the bite patterns into the bobber and the hook window is for the next Studio session. The economy simulator does not model the styles yet.
- Tests: 68 pass outside Studio.

### Half done
- Models are not imported. The `.glb` files should drop in, but vertex colours and scale need a first look in Studio.
- The format check would change 15 existing files (StyLua wraps lines over 120 characters). Nothing was reformatted.
- Selene's first run on GitHub found 1 error and 3 warnings, all in existing client code: two identical `goIdle()` branches in `Controller.luau` (lines 432 and 436, harmless but could be one branch) and three `UDim2.new` calls in `UI.luau` that could be `UDim2.fromScale`. The new files are clean. First GitHub run: unit tests passed, both report-only checks ran.

### Test first in Studio tomorrow
1. Run `TestRunner.runAll` in Studio: all 68 existing and new tests should pass there too.
2. Import `art/models/Dock.glb` with the 3D Importer (Scale Unit Stud, Merge Meshes on, Upload to Roblox off): check its size against the gray-box dock and that the colours show.
3. Import one fish (`Bluegill.glb`) and one stand, same checks.
4. Fight a trout, a bass, a catfish and a pike with DebugAutoFish off: each should move differently on the bar.
5. Then pick up the boat plan at Task 1 (the dinghy).

### Questions for Stewart (answered 2026-11-26, see `docs/DECISIONS.md`)
- Boat prices: keep the dinghy at 1,200 and the Deep-V at 4,000, retune after playtests.
- StyLua: reformat once after PR #1 is merged, in its own commit, then make the format check enforcing.
- Art look: Duet's chunky low-poly, flat-colour style is the house style (palette in `art/scripts/palette.py`, rules in `art/README.md`).
- Still open: do the six fight styles feel right once you play them? Each has one or two numbers to tune.

## 2026-11-26: PR #1 verified in Studio and merged

- Pushed every PR file into Studio; checksums match `src/` and 69 tests pass in Studio (68 from the PR plus one new one for the slack cue). The creek gate was rebuilt and now reads "Cedar Creek, 500 coins".
- Bites: at the dock at dawn on worms the bobber dipped and the fish took it in 3 to 4 s (a bluegill nibbled twice first, perch tapped). Stinkbait at the dock by day gave the "nothing wants it" hint after 10 s. Pressing during a nibble now says "Too early, that was just a nibble."
- Slack line: hooking a fish and then doing nothing loses it in 2.5 to 4.8 s; normal play lands it. The "KEEP REELING!" warning showed the moment a fish was hooked, before the player could react, so it now waits for the first press (before that the bar says "HOLD TO REEL").
- Fight styles, traced from the fish marker in the game: largemouth bass (weed bed, dawn, minnows) runs back and forth fast and stays up; northern pike (weed bed, noon, spinner) makes the biggest single jumps of all (more than twice the bass's) and spends most of the fight deep; channel catfish (deep hole, night, stinkbait) moves slowly, smoothly and low, no jumps at all; rainbow trout (riffle, dawn, crickets) sits low and then shoots up in sudden leaps. All four move differently.
- Shop prices match the new data (worms 8, crickets 12, minnows 20, stinkbait 16, lures 100). Touch and gamepad: the input code is untouched by the PR and the slack rule treats holding and tapping the same on every device.
- **Bug found and fixed:** with the Graphite Rod even the softest cast flew 24 studs, clean over the 12 stud riffle, so trout were impossible to reach from the bank. A rod's extra reach now grows with cast power, so a soft cast stays short with any rod.
- **Models not imported yet:** uploading the dock, stand and fish to Roblox needs an approved upload folder in Studio (see Waiting on Stewart). The scopes are already granted.

## 2026-11-26: Sound pass

- All 27 ElevenLabs sounds are on Roblox (asset ids in `audio/README.md` and `src/ReplicatedStorage/Shared/SoundIds.luau`), uploaded through Open Cloud once Stewart approved the upload folder. A few were still in Roblox's moderation review at upload, but all 27 loaded and played in the playtest.
- New: `Shared/SoundMix.luau` (the rules, with 4 tests), `ClientModules/SoundFX.luau` (plays them). The server now tells the client about each nibble dip so it can be heard.
- What you hear: the lake's ambience crossfades with the clock (birds at dawn, wind by day, a loon at dusk, frogs and crickets at night); the creek's running water rises as you walk toward it and the lake steps back. While the line is in, everything quiets a little and the bobber ticks; each bite style has its own cue (tap, slam, a deep pull for catfish and carp) with a crisp snap on top. Reel clicks while you reel, rising in pitch when the fish is close to breaking free; the drag zips when it runs, it thrashes when it jumps, the line strains when you're about to lose it; heavy fish bring in a low tension music layer. A catch ends on a splash sized by weight, a stinger by rarity (all Common until the rarity tiers from PR #2 land) and a discovery chime for a first-ever species. A calm theme plays now and then, only after 10 s with no line in.
- Verified: 73 tests pass in Studio and with Lune; checksums match. Playtest logs showed every cue at the right moment (dawn dock: tap, reel, splash, stinger; night deep hole: deep pull, tension music up to 0.8 and back to 0, big splash; creek: creek ambience at full and lake dawn at a quarter; a trout left to run: drag, thrash, line strain, small splash as it got away).
- Critic (Gemini Neon, `sound` rubric, clips with audio): 6/10 on the first pass (heavy cast splash, quiet bites, late chime, theme cut off), 7/10 after fixes. Reports and actions in `docs/critic/`.

## 2026-11-26: First models in the game

- The dock, the Bait and Tackle stand and the bluegill from the art pass are in the game, uploaded to Roblox (asset ids in `art/README.md`) and kept in `ServerStorage.Art`.
- `WorldBuilder.dress()` lays the models over the gray box and hides the parts they replace; the gray-box parts stay solid but invisible, so walking, casting, the shop prompt and the fishing zones are unchanged. A landed bluegill now hangs on the line as the real model, sized to its length; other fish keep the old shape until their models go in.
- Found on the first import: Roblox showed the vertex colours far too dark (Blender writes them in linear light). `art/scripts/roblox_colors.py` converts them; the first bluegill upload is unused. Also, the dock came in back to front and the fish head points along -X in Roblox; both are handled in code and noted in `art/README.md`.
- Verified in a playtest: spawned on the dock, walked to the end (feet at 1.5, the deck top), cast from the end and landed a carp, opened Bait and Tackle with E at the new stand, landed a bluegill and it hung as the model. The invisible spawn pad sat 0.4 above the new deck, so it no longer collides and players stand on the deck. 73 tests pass; checksums match.

## 2026-11-26: Leg plan and L0 (steady ground)

- Fable 5.2 reviewed the project and wrote the leg plan for 11/27 to 12/17/2026: `docs/superpowers/plans/2026-11-26-next-leg.md`, readable at https://claude.ai/artifact/3F2bNUEujyw3c92QDYqWox. Order: L0 steady ground, L1 rare fish (PR #2 landed), L2 the cast, L3 bait the hook, L4 the wait, L5 postcard lake, L6 living lake, L7 the dinghy. Every milestone from L1 on ends with a Liam session.
- L0 harness: the fixed 12 shots, contact sheet, critic score history, frame-time probe, em dash lint and the gate (`python tools/check.py`: 73 specs, lint, economy run, all pass). Routing and agent files recorded (`docs/ROUTING.md`, `.claude/agents/`).
- Baseline taken 11/26/2026 in Studio Play: all 12 fixed shots (`docs/critic/2026-11-26-baseline-l0-sheet.jpg`), Neon look score **2.5/10** in all three runs (composition 3, light 2, water 1, mood 2, want to fish 3, phone readability 3, broken or ugly 2; reports `docs/critic/2026-11-26-baseline-l0-neon*.md`). Frame budget in `docs/PERF.md`: render CPU about 4 to 6 ms and GPU 6 to 9 ms per frame on this PC.
- What the baseline shows, for L5: the lake water reads as flat sand or concrete with a floating dark slab over the deep hole; the creek riffle slab ends in mid air over a pit; dawn (clock 6.6) looks like noon and the dusk shots (18.4, inside the game's Dusk period) are already starry night; dock lamps glow at noon; the edge of the world is a flat grass box over void; signs stack across the lake and clip into posts. The shots stay where they are: L5 makes 18.4 look golden rather than moving the shot.
- **Correction (11/26/2026, later):** this 2.5/10 baseline was shot while the whole gray-box Lake model sat 6 west, 10 up and 55 north of its terrain water and of the fixed coordinates the game uses, so some of what it shows (water reading as sand or concrete, the dark slab floating over the deep hole) was that displacement, not the look. The lake was moved back, `tools/shots/shots.json` was shifted by the same amount so each shot frames the same place, and the baseline was re-shot with all 32 models in: **Neon 3/10** (runs 3.0, 3, 3.5; sheet `docs/critic/2026-11-26-baseline-l0-models-sheet.jpg`, reports `docs/critic/2026-11-26-baseline-l0-models-neon*.md`). It credits the models and the readable fishing spots; it marks down the straight pool-like banks, the creek riffle spilling into the void, signs clipping through roofs and stacking across the lake, dawn that looks like midday, golden hour that looks like night, and pool-cyan water. This is the baseline L5 is measured against.
- Harness fixes found while shooting: Edit mode holds only part of the world (the builder adds the rest at run time), so shots are taken during Play on the Client with the clock and camera pinned each frame (`shots.py snippet pin`). The first shot positions were guessed and missed the lake; `shots.json` now uses positions measured in the built world. `capture-studio.ps1` picks the Fishing Game window when several Studios are open. Studio holds a background window at 15 fps, so `probe.luau` reads render CPU and GPU time instead.
- Still to do in L0: the 29 model imports another session is doing.
- Found: the repo folder `C:\Users\stewa\Documents\Claude\Roblox` is checked out on an old commit of the PR #2 branch with main's newer files untracked, and another session works in it. L0 work was done in a separate worktree and pushed to main. Put the folder back on main when no other session is using it: everything in it is either already on main or older than main.

## Overnight 2, unverified (2026-11-26, Claude in the cloud)

Nothing below has been seen in Studio. It is all on `claude/overnight-duet-kpkf6f` in draft pull request #2, with main (sound pass included) merged in; `main` and the place are unchanged. Compiles (`lune run tools/test/syntax.luau`, 57 files) and 135 tests pass with Lune. Full list and open design questions: `docs/OVERNIGHT-SUMMARY-2026-11-26.md`.

### Built
- **Rarity:** seven tiers on every fish with colours on the catch card and journal; trophy (2 percent) and monster (0.2 percent) catches rolled on the server at the hook, with harder fights, warnings, banners, a server message for monsters and journal counts. The sound pass's stingers now get real tiers.
- **Fish:** 15 new species (26 in all), three of them Mythics tied to weather (Albino Catfish in storms, Golden Trout in fog, Tiger Muskie in the pre-storm rush). Blender models for all 15 plus the Dinghy and Deep-V.
- **Loop:** three daily goals (paid on the server, Goals panel), journal rumours for uncaught fish, weather with an 8 day moon (changes bites, clock and shop forecast, boats stay in during lightning), feeding frenzies about once a game day, no breeding of Legendary or rarer fish in the pond.
- **Boats:** Dinghy (1,200) and Deep-V (4,000) in the shop, four slips by the dock, driving with the normal movement controls, the Big Lake through a north channel (island, buoy line, blue water), casting from a boat, team catches split on the Deep-V, a fish finder for the navigator.
- **Sound:** 25 more prompts in `audio/sounds-next.json`, joined to `SoundIds.luau` with empty ids; `SoundFX` plays 20 of them once uploaded (rules and tests in `SoundMix`).
- **Economy:** expert +15 percent, dock kid unchanged, weather averages within 2 percent (`docs/ECONOMY.md`).
- **Read-through fixes** after an independent review of the new server scripts: one AlignOrientation holds the boat's heading, boats sit at the water line, seats only by prompt, only the helm casts off, the storm check applies near the slip, no buying a boat while aboard, a mate with a full bag gets paid their share.

### Second round (same night)
- Economy check of the full loop with boats (`sim.py --boats`) and of goals and frenzies (`loop.py`); numbers in `docs/ECONOMY.md`. No prices changed.
- Daily goals: eight kinds now (new: catch on a bait, a good-sized fish, fish during a frenzy, Big Lake spots for boat owners).
- Journal rumours name a bait after ten more catches; gulls circle and dive over a frenzy.
- Second read-through fixes: helm controls now reach the server through a `BoatInput` remote; riders always land on the dock; a boat that runs from its bobber loses the line; blue-water casts need the full crew; a save that couldn't be read is never overwritten.

### Switches (leg plan L0, done on this branch 2026-11-26)
- `Config.WEATHER_ON`, `FRENZIES_ON`, `GOALS_ON`, `BIG_LAKE_ON` and `BOATS_ON`, all `false`, read in `Main.server.luau`. Off means: weather reports clear skies (weather-only fish don't bite), no frenzies, no goals and no Goals button, no Big Lake build (and no casting toward it), the shop hides boats and the server refuses buying one. Boats need the Big Lake switch too. Rarity, trophies and monsters, the 26 species and the journal are always on. `Switches.spec` checks the defaults; `python tools/check.py` passes (137 specs).

### Test first in Studio
1. Push `src/` into Studio and run `TestRunner.runAll`: everything passes.
2. Play with every switch off: nothing new shows but tiers, trophies, the 26-card journal; no errors. Then turn on one switch at a time for steps 4 to 7 (Big Lake and boats together).
3. Catch card shows tier colours; set the player attribute `DebugSizeClass` to `monster` and land one (banner, server message, journal count, stinger).
4. Goals panel and journal (26 cards, rumours, still scrolls on a phone).
5. Give coins, buy the dinghy: it waits at slip 1; E to drive (keyboard, touch, gamepad; try it in a local server too, the controls travel through a remote); the buoy line turns it back; cast while stopped in the basin; F to tie up.
6. Command bar: `require(game.ServerScriptService.Server.WeatherService).force("Fog")` and `require(game.ServerScriptService.Server.FrenzyService).start("Dock")`.
7. Two-player local server: the Deep-V won't move alone, moves with a rider, the fish finder shows only for the navigator, a blue-water catch lands in both journals.

## 2026-11-26: All the art models in the game

- The other 29 models are uploaded (ids in `art/README.md`) and in `ServerStorage.Art`; 69 copies dress the world: the Fish Buyer stand, the stone pond rim, five logs, the buoy, 18 reed clumps and 7 lily pads at the weed bed, 7 leafy trees on the shore, 8 pines and 19 rocks at the creek, plus the dock and Bait and Tackle from before. The bobber on every cast is the new model, and every species hangs on the line as its own model, sized to the catch. The rods and the boat are uploaded but not placed yet (the rods in hand are still the gray box).
- `WorldBuilder.dress` now takes many places per model: an exact spot, a spot scattered with a fixed seed, or fitted over a gray-box part (centred or standing on it, optionally scaled to its width).
- **Found and fixed:** the whole gray-box Lake had been moved by 6 studs west, 10 up and 55 north (most likely an accidental drag in Studio while it was selected), away from its terrain water and from the fixed coordinates the fishing code uses. It is back where the code expects it (ground top at y = 1); logged in `DECISIONS.md`.
- Verified in a playtest: spawn feet on the deck (1.50), a night cast from the dock end showed the new bobber pulled under by a catfish bite, the catfish hung as its model (6.8 studs), selling at the new Fish Buyer paid out (5 fish, 110 coins), the pond panel opened at the new rim, and the riffle gave a rainbow trout that hung as its model. 73 tests pass in Studio and with Lune; checksums match.

## 2026-11-26: L1 rare fish, first Studio pass (switches off)

- PR #2 (the second overnight run) is merged onto main with weather, frenzies, goals, the Big Lake and boats all switched off in `Config`. Pushed every script into Studio; checksums match `src/` byte for byte; 143 tests pass in Studio and with Lune. Place saved as version 44.
- Sizes now read in inches and pounds everywhere a player sees them (catch card, journal, pond, sell message, size goals, the monster announcement): `Shared/Units.luau`, with `Config.UNITS = "imperial"`; the data and saves stay metric. Switch back with `Config.UNITS = "metric"`.
- Verified in a playtest: no errors at server start; the old save loaded (492 coins, 56 caught) and kept counting (59). A Common Carp on worms at the deep hole showed "Uncommon. 22.9 in, 6 lb 8 oz" with the name in the Uncommon green (95, 200, 110). Forced trophy (`DebugSizeClass`): "This one feels big!" at the hook, landed, "TROPHY! Common Carp", 31.5 in, 16.9 lb, personal best. Forced monster: the server message "landed a MONSTER Common Carp: 43 in, 41.7 lb!", the banner and the card. The journal shows Common grey, Uncommon green, Rare blue, Epic purple, Legendary gold and Mythic pink; uncaught Mythics read "Catch more fish to hear rumours about this one", not broken.
- **Bug found and fixed:** with boats switched off, the journal still listed the seven Big Lake fish and their rumours sent players to "the blue-water drop-off" and "the open basin", which don't exist yet. `Journal.listed` now hides a species until its water can be reached (or once it has been caught); the journal reads "10 of 19 species found" and every rumour points at home water.
- Still to do in L1: a Lake Sturgeon at the deep hole in its real conditions, the journal on the smallest phone (the simulated mouse wheel zoomed the camera instead of scrolling the journal; check with a real wheel), the 15 new fish models (they hang as the old shape until then), a Neon reveal clip, the StyLua reformat, and Liam's 20 minutes.
- Look mockups for the beauty pass: five looks (Golden Afternoon, Bright Summer Day, Misty Dawn, Moonlit Night, Autumn Lake) from the all-models stills, page https://claude.ai/artifact/DjMRLNSn6t91zKmR93sGr6 (source `planner/looks.html`, images `docs/looks/`, script `tools/looks/mockup.py`). They were made in the old flat low-poly style before Stewart picked Real-ish, so treat them as light and time-of-day moods, not materials.

## 2026-11-27 (night): L2b, reasons to aim

- **Snags:** land on a fallen log, or in the thick of the weed bed with anything but a plastic worm, and you're stuck. The ring warns first: amber and "(snag)" over a log. Four taps wiggle it free (a live bait is lost about a third of the time); wait 8 s and the line snaps (live bait lost, a lure never). Verified: a cast onto Log1 snagged, four wiggles gave "Wiggled free!", and another left alone gave "The line snapped on the snag."
- **Rises:** a fish dimples the surface somewhere every 14 to 26 s (ripples everyone sees). Land within 5 studs inside 8 s and the fish comes in 1.5 to 3.5 s. Verified on three real rises: the fish showed 2.8 to 3.0 s after landing (a bluegill nibbles twice first, so the bite itself came at about 4 s).
- **Cover:** within 4 studs of a log, the dock, the weed edge or a creek boulder, cover-loving fish (bass, crappie, pike, bowfin, rock bass, catfish) are 1.25 times as likely. Bites aren't faster there (my retune: the builder's x0.75 delay on top of x1.5 weight gave a smart player +60 to 72 percent).
- **Hint:** when nothing wants your bait it names a better choice, for example "Try minnows here, or stinkbait at the deep hole." (`Shared/Advice.luau`).
- **Save migration test:** every save version from v2 up loads with coins, journal, pond and bag intact, whatever the feature switches say (`Tests/Migration.spec`). Found: a save with no version number skips the "reel assist back on" step; only early test saves had none.
- Economy (sim, rises one player can reach every 90 to 150 s): smart 84.0 coins a minute (was 70.0), Graphite at 22 min (was 24); smart without a pond 98.9 (86.2), 18 min (20); dock kid 31.2 (31.4), 53 min; random 30.2 (31.0). Aiming well pays 15 to 20 percent.
- 189 tests pass in Studio and with Lune; all 15 changed or new scripts match by checksum. Place version 52. Still: `docs/making-of/stills/2026-11-27-ring-at-the-logs.jpg`.

## 2026-11-27 (night): L2a, the cast ring

- While you hold, a ring travels out and back on the water at 16 studs a second with a dotted arc from the rod tip and a label naming the spot (red "Dry ground" over land). Let go when it sits where you want. The power bar still moves with it. Still: `docs/making-of/stills/2026-11-27-cast-ring.jpg`.
- One shared `Shared/CastLogic.luau` does the math for both the ring and the server; `Shared/WaterMap.luau` now holds the water and zone boxes so the client sees the same water. A near miss within 3 studs of the bank slides onto the water. Lures cast farther: spinner 1.25x, plastic worm 1.1x, minnow 1.05x on the reach part; a soft cast is still 8 studs.
- Verified in Studio: 20 casts (4 directions, 5 powers) landed exactly on the client's predicted point (0.00 studs off); a deliberately wrong prediction was ignored and the server used its own. 156 tests pass in Studio and with Lune; checksums match. Place version 48.
- Found and fixed in the playtest: the ring sat behind the player's head (the camera aims through the character), so the character now fades while aiming; adornments under the camera and an AlwaysOnTop label didn't render, so the ring lives in a client-only workspace folder and the label hangs off the ring.
- Not yet checked: touch and gamepad (same charge path as the mouse), the 4-stud accuracy trial by hand, the smallest phone. Next: L2b (rises, cover, snags, the specific "nothing wants this" hint, the save-migration test).

## Overnight plan (11/26 to 11/27/2026, until at least 11am)

Stewart: keep working all night, make your own calls, stop only for real blockers; full sim but beatable by a 13-year-old who knows a little about fishing. One orchestrating session (this one) with builder agents for code; the orchestrator pushes to Studio, playtests, takes stills and commits after each step. Order:

1. L2a: the cast ring, arc and shared `CastLogic` (in progress).
2. L2b: rises, cover and snags; economy re-run.
3. L3: the bait bench as a real rigging minigame (bait choice, hook size, hooking it right).
4. L4: the wait and the reel, full-sim feel (bobber camera, fish shadow, twitch, drag and line tension).
5. L1 leftover: the 15 new fish models.
6. Morning report at the top of this file by 11am.

## Paused here (2026-11-26 evening, L1 and the looks)

- Done: L1 first Studio pass (place version 44, saved, Edit mode, no playtest running); all scripts match `src/`; 143 tests pass. Five look mockups in the old low-poly style are live on the looks page; Stewart's seasons and frozen-lake direction is recorded.
- In progress: the Real-ish remake of the looks. Golden Afternoon is done (`docs/looks/realish/golden/`); the rest were rendering when the laptop slept.
- Next step, exactly: `python tools/looks/mockup.py gen --style realish` (it skips finished images; six looks including Frozen Winter), then `python tools/looks/mockup.py critic --style realish`, then rebuild `planner/looks.json` with a `sets` object (`realish` and `lowpoly`, each with `pick` and `looks`, each look with a `dir`), republish `planner/looks.html` to https://claude.ai/artifact/DjMRLNSn6t91zKmR93sGr6 and commit. After that: the L1 rarity retune against `docs/RARITY-DIRECTION.md` and an economy re-run.

## 2026-11-26 (night): L1 rarity retune and Real-ish looks

- Rarity retune to `docs/RARITY-DIRECTION.md`: odds follow the tier, value follows rarity. A smart player now lands about one Legendary every two sessions (was two a session) and one Epic a session; the dock kid's catch is 84% Common and their income unchanged. Table and calls in `docs/ECONOMY.md` and `DECISIONS.md`. Pushed to Studio (57 data lines, two specs), checksums match, 143 tests pass in Studio and with Lune; a real catch read "Uncommon. 23.7 in, 7 lb 3 oz. Worth 19 coins". Place saved as version 46.
- The sim gained `--tiers` (catches by tier and Legendaries per session).
- Six Real-ish looks (day cycle plus autumn and frozen winter), approved by Stewart as a set: https://claude.ai/artifact/DjMRLNSn6t91zKmR93sGr6.

## What works now
A full loop on keyboard and mouse, touch and gamepad: cast from the dock or shore, wait for a bite, hook it, fight it on the bar (hold or click anywhere), land it, sell at the Fish Buyer, buy bait at Bait and Tackle, fill the journal, raise fish in your home pond, buy better rods, and unlock Cedar Creek. Eleven species follow real habits (spot, time of day, bait), fish shadows show where they're active, the day runs 16 minutes, and progress saves to Roblox.

## What's left (next version, after Stewart and Liam playtest)
- More tuning once Stewart and Liam have played more (prices, fight lengths).
- Later versions from `DESIGN.md`: a boat (next), weather, co-op, art pass. (Home pond, rods and Cedar Creek are in.)
- Pond ideas for later: upgrades for more space, feeding to speed growth, rare color variants from breeding.
- The test save on Stewart's account has 21 coins and 14 fish from Claude's playtests. Ask Claude to wipe it if you want a fresh start.

## Waiting on Stewart
- **ID verification (planned 11/27):** verify the Roblox account Studio uploads with (playtests spawn as ProBabyTurtle) to lift the audio cap from 100 to 2,000 uploads per 30 days. Figure out which account owns the Fishing Game first; Roblox moves games only into a group, and uploaded sounds and models stay with the account that uploaded them.
- **Voice chat off:** in Studio, File, Experience Settings, Communication, turn Enable Voice Chat off.
- **Rating:** Creator Dashboard, the Fishing Game experience, Publish settings, Content ratings: redo the questionnaire and check it comes out Minimal or Mild.
- **Open the place on your own phone** once now and once after the beauty pass (L5), to check the frame rate on a real device.
- **Before L7:** give Liam's Roblox account access to the place, for the two-person boat.
- Playtest it: open Fishing Game in Studio and press Play (F5).
- Optional, speeds up Claude's builds: in Studio, Assistant Settings, MCP Permissions, Connect to the internet, add `localhost:8765` to the HTTP domain allow list.
- Done already: the place is saved to Roblox and Studio API access is on.
