# Overnight summary, 2026-11-26 (second cloud run)

Input for tomorrow's master plan. Everything here is on draft pull request #2 (branch `claude/overnight-duet-kpkf6f`), written in the cloud **without Studio**: it compiles, 135 tests pass outside Studio, and none of it has been played. `main` is unchanged; main's sound pass is merged into the branch.

## What was built

### Fish and rarity (docs/DIRECTION.md section 3, rarity plan Tasks 1 to 3)
- **Seven rarity tiers** on every fish (`Rarity.luau`), with colours on the catch card, its border and the journal.
- **Trophy (2 percent) and monster (0.2 percent) catches,** rolled on the server at the hook, with harder fights, a "This one feels big!" or "Something HUGE" warning, a TROPHY or MONSTER banner, a server-wide message for monsters, and trophy and monster counts in the journal.
- **Nine new species and three Mythics,** so every place has 6 to 10 species and a Legendary:
  - Lake: Bowfin (Epic), Lake Sturgeon (Legendary), Albino Catfish (Mythic, storm nights).
  - Creek: Creek Chub, Rock Bass, Brook Trout (Rare), Brown Trout (Legendary), Golden Trout (Mythic, foggy dawns).
  - Big Lake: Lake Whitefish, Freshwater Drum, Burbot (Epic), Tiger Muskie (Mythic, the pre-storm rush), plus the earlier White Bass, Lake Trout and Muskellunge.
  - 26 species in all. Each has real habits, a fight style, a bite style and a journal line.
- **Models** (ready for the same upload path as the dock and bluegill: `python art/scripts/roblox_colors.py <Name>` converts each one cleanly, checked on Bowfin and DeepV; a species with no uploaded model keeps the old shape on the line) for all 15 newer fish and both boats (Blender by script, house style, under 1,000 triangles each). Contact sheet: `art/previews/contact-sheet.png`.

### The loop
- **Daily goals:** three a day (easy, medium, hard), the same for everyone, never asking for water you can't reach, paid on the server, shown in a Goals panel.
- **Journal rumours:** uncaught fish show their tier and, after enough catches, a rumour of where, when and in what weather to look.
- **Weather** (docs/WEATHER.md): clear, overcast, foggy mornings, wind with a direction, storm days (a feeding rush, then the storm), cold fronts after storms, and an 8 day moon. It changes which fish bite where; the clock shows it, the shop shows the forecast, the fish shadows follow it, and boats stay in during lightning.
- **Feeding frenzies:** about once a game day a school boils at one spot for a minute and bites come back to back, announced to everyone and drawn with splashes and extra shadows.
- **Home pond:** Legendary and rarer fish don't breed (no sturgeon farms); a monster keeps its size.

### Boats (boat plan Tasks 1 to 8, all in code)
- **Inflatable Dinghy (1,200) and Deep-V (4,000)** in the shop. The chosen boat waits at one of four slips by the dock. Its owner takes the helm with a Drive prompt, steers with the normal movement controls, and ties up at the slip.
- The server drives the boat with constraint movers and checks it every half second: off the water or a teleport puts it back; a dinghy at the buoy line is turned back.
- **The Big Lake:** a channel through the north shore (with a footbridge for the path), the island, the buoy line and the deeper blue water. Casting there needs a boat; blue water needs the Deep-V with two aboard.
- **Teamwork:** blue-water catches on the Deep-V go to both journals with the coins split, and only the navigator sees the fish finder.

### Sound, economy, tooling
- **25 more sound prompts** (`audio/sounds-next.json`), added to the sound pass's `Shared/SoundIds.luau` with empty ids; `SoundFX` already plays 20 of them once uploaded (Big Lake and blue-water ambience, motors by speed, rain, thunder and gusts, the frenzy boil, a monster foghorn, trophy and monster stingers, coins, goals, a line snap); see `audio/README.md`.
- **Economy** (`docs/ECONOMY.md`): after tuning the new Legendaries down, an expert earns 15 percent more than before (the plan's limit) and the dock kid the same. Weather averages within 2 percent of clear days (`python3 tools/econ/sim.py --weather`). Daily goals add about a quarter to a new player's session and under a tenth to an expert's; a frenzy adds 33 to 56 coins if you're there (`python3 tools/econ/loop.py`).
- **A read-through of the new server scripts** by a second reviewer found 12 real problems (boat heading fighting itself, boats not at the water line, seats grabbing anyone who bumped them, riders casting off, a full bag losing a team share, and more); all fixed.
- **A compile check for every script** (`lune run tools/test/syntax.luau`), also on GitHub.

### Second round (after the first report, same night)
- **The full loop with boats in the economy check** (`python3 tools/econ/sim.py --boats`): the dinghy is a side step (a little better by day and at dusk, weaker at dawn and night; the burbot now comes into the basin at night so there's something to catch), blue water pays about a quarter more per person, and the dinghy arrives sooner than the boat plan aimed for (half a session after the Graphite Rod for a smart player). Prices left at 1,200 and 4,000 as Stewart decided; 1,800 would put the dinghy on the plan.
- **Goals and frenzies in the economy check** (`python3 tools/econ/loop.py`): goals add about a quarter to a new player's session and under a tenth to an expert's; a frenzy adds 33 to 56 coins if you're there.
- **More kinds of daily goals:** catch on a given bait, catch a good-sized fish of a species, catch 2 fish during a feeding frenzy, and Big Lake spots for boat owners. Hints only name spots the player can reach.
- **Journal rumours get sharper:** ten catches after a tier's first rumour, it names a bait ("Old-timers swear by stinkbait").
- **Frenzies are easier to spot:** gulls circle and dive over the boil (local, visual only), and the boil's position is shared so the gulls and the sound line up with it.
- **20 new sounds hooked up** to play once uploaded (Big Lake and blue-water ambience, motors by speed, rain, thunder, gusts, frenzy boil, a monster foghorn, coins, goals, a line snap).
- **A second independent read-through** found that a server-owned boat never gets the helm's controls from a VehicleSeat, so the client now sends them through a `BoatInput` remote (the most important thing to check in Studio). Also fixed: characters get their own physics back when they stand up, riders are put on the dock whenever a boat goes home or is removed, a boat that runs from its bobber loses the line, casting into blue water needs the full crew, no boat is built for a player who left while loading, and a save that couldn't be read is never written over.

## Test first in Studio
1. `TestRunner.runAll`: everything passes.
2. Play: the server output shows no errors at start (BigLake built, weather started, goals filled in).
3. Fish a few minutes: the catch card shows the tier colour; set the player attribute `DebugSizeClass` to `monster` and land one (banner, server message, journal count).
4. Open Goals and the journal (26 cards, rumours on the uncaught ones, it still scrolls on a phone).
5. Buy the dinghy (give coins in Studio): it waits at slip 1; press E, drive with WASD (test in a local server with a player, not only solo Play, since the controls now travel through a remote), a thumbstick and a gamepad; drive at the buoy line; cast while stopped in the basin; tie up with F.
6. Watch a frenzy: gulls should circle and dive over the boil, and a frenzy goal should count catches made during it. Force weather from the command bar (`require(game.ServerScriptService.Server.WeatherService).force("Fog")`) and a frenzy (`require(game.ServerScriptService.Server.FrenzyService).start("Dock")`).
7. Two-player local server: the Deep-V won't move alone, does with a rider, the fish finder shows for the navigator only, a blue-water catch lands in both journals.

## Open design questions for the master plan
- **Godlike fish:** none yet. The direction says one or two hidden across the game. What are they, and how are they found? A good one for Liam.
- **Is +15 percent for experts the right ceiling,** or should Legendaries pay less and stay a trophy-and-story reward?
- **Daily goal rewards:** flat 25, 60 and 120 coins, eight kinds now. Streak bonuses? (Careful: streaks can feel like pressure for a kid.)
- **Dinghy price:** 1,200 lands sooner than the boat plan aimed for; try 1,800 after playtests?
- **Weather sharing:** each server has its own weather. Should every server share one forecast so a "storm tonight" is something friends plan around?
- **Boats:** one boat at the slip per owner and four slips. Enough? Should a dinghy owner be able to borrow a friend's Deep-V seat as navigator (allowed now), and should the Deep-V helm need its owner?
- **Frenzies:** only Common and Uncommon schooling fish. Should rarer fish ever school (white bass are already Uncommon)?
- **New lures** for the new species (a crankbait for walleye and pike, a jig for crappie and smallmouth) to deepen bait choice?
- **The Big Lake** is gray box and built at server start. It needs a beauty pass (DIRECTION section 1) and a decision on whether to build it in Edit so it's saved in the place.
- **Sounds:** which of the 25 new prompts to generate first, and the uploads (only Stewart's account can upload).
