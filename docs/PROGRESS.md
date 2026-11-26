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
- Still to do in L0: the baseline shots, look score and frame budget (needs the Fishing Game place open in Studio), and the 29 model imports another session is doing.
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

### Test first in Studio
1. Push `src/` into Studio and run `TestRunner.runAll`: everything passes.
2. Play: no errors in the server output at start (BigLake built, weather started, goals filled).
3. Catch card shows tier colours; set the player attribute `DebugSizeClass` to `monster` and land one (banner, server message, journal count, stinger).
4. Goals panel and journal (26 cards, rumours, still scrolls on a phone).
5. Give coins, buy the dinghy: it waits at slip 1; E to drive (keyboard, touch, gamepad; try it in a local server too, the controls travel through a remote); the buoy line turns it back; cast while stopped in the basin; F to tie up.
6. Command bar: `require(game.ServerScriptService.Server.WeatherService).force("Fog")` and `require(game.ServerScriptService.Server.FrenzyService).start("Dock")`.
7. Two-player local server: the Deep-V won't move alone, moves with a rider, the fish finder shows only for the navigator, a blue-water catch lands in both journals.

## What works now
A full loop on keyboard and mouse, touch and gamepad: cast from the dock or shore, wait for a bite, hook it, fight it on the bar (hold or click anywhere), land it, sell at the Fish Buyer, buy bait at Bait and Tackle, fill the journal, raise fish in your home pond, buy better rods, and unlock Cedar Creek. Eleven species follow real habits (spot, time of day, bait), fish shadows show where they're active, the day runs 16 minutes, and progress saves to Roblox.

## What's left (next version, after Stewart and Liam playtest)
- More tuning once Stewart and Liam have played more (prices, fight lengths).
- Later versions from `DESIGN.md`: a boat (next), weather, co-op, art pass. (Home pond, rods and Cedar Creek are in.)
- Pond ideas for later: upgrades for more space, feeding to speed growth, rare color variants from breeding.
- The test save on Stewart's account has 21 coins and 14 fish from Claude's playtests. Ask Claude to wipe it if you want a fresh start.

## Waiting on Stewart
- **Voice chat off:** in Studio, File, Experience Settings, Communication, turn Enable Voice Chat off.
- **Rating:** Creator Dashboard, the Fishing Game experience, Publish settings, Content ratings: redo the questionnaire and check it comes out Minimal or Mild.
- **Open the place on your own phone** once now and once after the beauty pass (L5), to check the frame rate on a real device.
- **Before L7:** give Liam's Roblox account access to the place, for the two-person boat.
- Playtest it: open Fishing Game in Studio and press Play (F5).
- Optional, speeds up Claude's builds: in Studio, Assistant Settings, MCP Permissions, Connect to the internet, add `localhost:8765` to the HTTP domain allow list.
- Done already: the place is saved to Roblox and Studio API access is on.
