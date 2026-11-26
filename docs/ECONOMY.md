# Economy check

Written overnight 2026-11-26 by Claude in the cloud. **Unverified in game**: these are simulation results, not playtests.

**Applied 2026-11-26:** Stewart approved all of the changes below ("Apply all of the above and apply them now"), and they are now in the game's code on the overnight branch, still to be playtested in Studio. One differs from the wording he approved: the idle rule (change 6) gives 2.5 seconds, not 1, and is explained there. `tools/econ/sim.py` now reads the new numbers; "Results with today's numbers" below is the before picture.

The simulation is `tools/econ/sim.py` (run `python3 tools/econ/sim.py`, about two minutes; `--quick` for a fast check). It reads the real numbers straight from `src/ReplicatedStorage/Shared` (fish, bait, rods, `Config`), copies the bite, size, price, fight and pond rules into Python, and plays three kinds of player through 25 minute sessions, one a day, 60 times each. The full output of the last run is in `tools/econ/last-run.md`.

- **Smart:** fishes the best spot and bait for the time of day, buys a lure when it pays for itself, keeps fish in the home pond.
- **Dock and worms:** stands on the dock with worms the whole time. This is probably what a new kid does first.
- **Random:** wanders to random spots with random bait.

All three buy the Fiberglass Rod, then the Creek Pass, then the Graphite Rod as soon as they can afford each one. Fights are played by a bot with kid reflexes (reacts 0.3 s late, loses focus now and then) with reel assist on.

## Results with today's numbers

| Player | Coins per minute, first session | Fiberglass Rod (120) | then Creek Pass (250) | then Graphite Rod (350) |
|---|---|---|---|---|
| Smart | 161 | 3 min | 6 min | 9 min |
| Smart, no pond | 176 | 1 min | 4 min | 7 min |
| Dock and worms | 28 | 4 min | 14 min | 29 min |
| Random | 59 | 2 min | 7 min | 13 min |

Times are minutes of play, median of 60 runs.

## What this means for a kid playing 20 to 30 minutes

1. **Too fast for anyone who knows a spot.** A player who has found one good spot buys everything in the shop inside 10 minutes, in the first session. After that there is nothing to save for until the boat exists.
2. **The time of day barely matters for big fish.** This is the biggest finding, and it cuts against the game's main idea. When only one kind of fish wants a spot and bait, it still bites within about 11 seconds, however unlikely it is, because the bite timer only looks at how well the best combo matches, capped at 11 s. Examples from the sim:
   - A Northern Pike (worth about 65) bites a spinner in open water every 11 to 14 seconds **at any hour, even at night**. That one combo pays about 190 coins a minute, more than anything else in the game.
   - A Channel Catfish bites stinkbait at the logs **at noon** about as fast as at night.
   So "the right spot at the right time" only matters for which panfish you get, not for the money.
3. **The price gap between panfish and big fish is very wide.** A bluegill averages about 4 coins and a catfish 35, but the catfish takes only about twice as long to catch. Worms at the dock, the most natural thing to do, earns about a sixth of what a big-fish spot earns.
4. **Fights are always won with reel assist on.** The kid-reflex bot landed 100 percent of every species, in 2 to 5 seconds. That is fine for an 11 year old, but it means **better rods make no money difference**: their value is the longer cast and the nicer feel, not more fish. (Real kids may do worse than the bot; Stewart's first playtest found fights hard before the fix.)
   - **Doing nothing at all lands about half the fish.** A bot that never touches the button landed 40 to 69 percent of fish with reel assist on (catfish 69, walleye 64, carp 63): the catch zone rests at the bottom of the bar, and heavy fish that sink sit inside it. Found while running the existing tests outside Studio, where "doing nothing loses a bluegill" passes in Studio only because of its fixed seed. A kid could set the rod down and still fill the bag.
5. **Bait is nearly free** for a smart player (about 1 percent of income) and about 12 percent for the dock kid. That's fine; bait isn't meant to be a money sink.
6. **The pond is generous.** A full pond pays a smart player about 540 coins a day, more than three minutes of top fishing, for one visit. Holding fish in the pond also slows the first purchases a little (3 min vs 1 min to the Fiberglass Rod), because those fish are not sold right away.

## Proposed changes

Six changes, in order of importance. Tomorrow's session applies only the ones Stewart approves.

### 1. Bite time follows how much the fish want it (the big one)

Today: bite delay = 11 s minus up to 8 s for a strong match, so even the weakest combo bites in about 11 s.
Proposed: bite delay = 3 s divided by the total match, between 3 s and 40 s. A combo that would take longer than 40 s counts as "nothing wants this here" and gets the existing hint after 10 s instead.

- Why: it makes the time of day and the right bait matter for every fish, which is the whole point of the game. The pike becomes the rare daytime prize it was meant to be (about one every 33 s in open water by day, nothing at night), and the catfish goes back to being a night fish.
- Strong matches stay as fast as now (3 s at the dock by day on worms). Only weak matches slow down. Worms at the dock at night go from about 10 s to about 21 s a bite, which nudges kids to try the deep hole.
- Where: `FishLogic.biteDelay` and `FishLogic.biteWeights` (drop combos under 3/40 = 0.075 total), plus `Config.BITE_SLOWEST = 40`. `Config.BITE_MAX` stops being used.
- Test to update: `FishLogic.spec.luau` line 39 uses open water at night on worms as its "weak but still bites" example. Under this rule that combo is below the floor and returns nil, so the test needs a different weak combo (for example the dock at night on worms, total 0.145, about 21 s).

### 2. Narrow the price gap

| Fish | Base price now | Proposed |
|---|---|---|
| Bluegill | 4 | 6 |
| Pumpkinseed | 4 | 6 |
| Yellow Perch | 8 | 10 |
| Black Crappie | 11 | 12 |
| Largemouth Bass | 26 | 20 |
| Channel Catfish | 32 | 24 |
| Common Carp | 24 | 18 |
| Northern Pike | 60 | 45 |
| Rainbow Trout | 22 | 18 |
| Smallmouth Bass | 28 | 22 |
| Walleye | 36 | 26 |

- Why: panfish are what kids catch first and most. Paying a little more for them makes the dock feel worthwhile, and paying a little less for big fish keeps the smart player about 2.5 times ahead of the dock kid instead of 6 times. Big fish still pay 3 to 7 times a bluegill, and trophy sizes still pay much more (price grows with weight).
- Where: `basePrice` in `FishData.luau`.

### 3. Raise the three goals

| Item | Now | Proposed |
|---|---|---|
| Fiberglass Rod | 120 | 150 |
| Creek Pass | 250 | 500 |
| Graphite Rod | 350 | 900 |

- Why: with changes 1 and 2, this gives the dock kid a first rod within about 4 minutes (a quick early win), the Creek Pass near the end of the first session, and the Graphite Rod in the third session. A smart player still gets everything in about one session, which leaves room for the boat to be the next big goal.
- Where: `price` in `RodData.luau` and `Config.CREEK_PASS_PRICE`.

### 4. Lures cost 100 each

Spinner 60 to 100, Plastic Worm 80 to 100.

- Why: a lure is bought once and kept forever, and today it pays itself back in about two minutes. At 100 it's a small goal of its own, still worth it within a few minutes for a player who knows where to use it.
- Where: `price` in `BaitData.luau`.

### 5. Leave the pond, bait, bag size and fights alone for now

- The pond pays about 220 coins a day with the new prices (down from 540 because fish are worth less), roughly 3 minutes of top fishing or 7 minutes at the dock. That matches the design note: "a slow, steady money-maker without beating active fishing".
- Fights: worth a look after Liam plays. If he lands everything without trying, the fix is in the fight (for example, assist on only for the first 20 catches), not in prices.

### 6. A fish only comes in while you're reeling

Today progress fills whenever the fish is inside the catch zone, even if the player hasn't touched anything.
Proposed: progress fills only if the player has pressed or held recently. Missing the fish still loses progress as now.

- Why: it keeps "you caught it" true, stops idle catching, and costs an active kid nothing.
- **As applied:** `Config.FIGHT_IDLE_GRACE = 2.5` seconds, not 1. With 1 second the tests showed a real problem: when a heavy fish sits at the bottom of the bar, the right play is to let go and keep the zone at the bottom, and a 1 second rule punished that. Now nothing fills until the player first presses; after 2.5 seconds without a press the line goes slack and progress drains slowly even inside the zone; one tap fixes it. `FightModel.slack(state)` tells the UI when to show a "Keep reeling!" cue (the UI part is for tomorrow's Studio session).
- Where: `FightModel.step` and its spec; the server's `minSeconds` check is unchanged.

## Results with the changes (now the game's numbers)

| Player | Coins per minute, first session | Fiberglass Rod (150) | then Creek Pass (500) | then Graphite Rod (900) |
|---|---|---|---|---|
| Smart | 79 | 4 min | 11 min | 22 min |
| Smart, no pond | 87 | 2 min | 9 min | 20 min |
| Dock and worms | 31 | 4 min | 22 min | 54 min |
| Random | 32 | 4 min | 19 min | 50 min |

Rerun after applying all six (including the slack-line rule): a bot that never touches the button now lands 0 percent of fish, and the kid-reflex bot still lands 100 percent.

Best spot by time of day, with the changes (coins per minute, Willow Rod): dawn weed bed on minnows (90), day weed bed on minnows (72) or the creek rocks on crickets (103), dusk deep hole on stinkbait (90) or the creek pool on minnows (129), night deep hole on stinkbait (110). Every period now has a different best answer, and the creek is the reward for buying the pass.

For the boat plan: a boat priced around 1,500 to 2,000 would be the next goal after the Graphite Rod (about 1 to 2 sessions for a smart player, 3 to 4 at the dock).

## What the simulation leaves out (and so is unverified)

- How fast real players react and how often they miss a hook (assumed 85 to 92 percent hooked).
- Walking: distances are measured off `WorldBuilder.luau` at 16 studs a second, with a few seconds for each shop or sell menu.
- Cast reach: the sim assumes every spot can be reached from its shore.
- When players sell: the sim sells when the bag is full or when the bag would pay for the next goal.
- Exact random numbers: Python's random numbers, not Roblox's `Random`, so single runs differ but averages should match.

## 2026-11-26 (second overnight run): new species, trophies and monsters

Re-run with nine new species (six reachable today: Bowfin, Lake Sturgeon, Creek Chub, Rock Bass, Brook Trout, Brown Trout), trophy and monster catches (2 and 0.2 percent, rolled at the hook, harder fights), the full 60 runs per player type. Unverified in Studio; numbers come from `tools/econ/sim.py`.

| Player | coins/min before | with new fish, no size classes | with new fish and size classes |
|---|---|---|---|
| smart | 78.9 | 87.6 | 90.7 |
| smart, no pond | 87.0 | 96.9 | 101.3 |
| dock and worms | 30.5 | 31.0 | 31.4 |
| random | 31.8 | 35.9 | 36.2 |

- Trophies and monsters add about 3 to 4 percent; the new fish add about 11 percent for a smart player and almost nothing at the dock.
- The smart player lands at +15 percent, right on the rarity plan's limit. Most of it is the Legendary fish, which reward knowing the right spot, time and bait. To get there the first try was cut: Lake Sturgeon rarity 0.05 to 0.03 and base price 160 to 80, Brown Trout 0.06 to 0.04 and 70 to 50, Bowfin 45 to 30 (the first try put a smart player at 104 coins a minute).
- The dock kid's curve hasn't moved: Fiberglass Rod in 4 minutes, Creek Pass in 22, Graphite Rod in 54.
- Not modeled yet: daily goals (25, 60 and 120 coins a day, about 2 minutes of a smart player's fishing and 7 of the dock kid's, so they help the slower player most). Big Lake fish are left out until the Big Lake exists.
- Compare with sizes off: `python3 tools/econ/sim.py --no-size-classes`.

### Weather, frenzies and Mythics (same night)

- `python3 tools/econ/sim.py --weather` plays with the day plans from `Weather.luau` (a Python port; keep the two in step). Over whole careers it lands within about 2 percent of clear-weather play (smart 87 vs 89 coins a minute, dock 30.7 vs 31.4), so weather reshuffles where to fish more than it changes income.
- Best possible rate for a smart player with every lure, by weather held all day: overcast, fog and wind within 2 percent of clear; the pre-storm rush +13 percent; storm and cold front -15 percent. In the game the rush and the storm last only a few hours of a storm day, so a session swings less than that. Inside the 20 percent the weather spec allows.
- A player who doesn't adapt feels it more: a cold front halves most spots (deep water holds up), which is the lesson it teaches.
- Mythics bite only in their weather (storm, fog, the pre-storm rush), at rarity 0.03; the simulation includes them when `--weather` is on.
- Feeding frenzies aren't simulated yet. Expected about 1.2 a game day, a minute each, only for Common and Uncommon schooling fish: a nice burst for whoever is there, small next to a session's income.

## Daily goals and feeding frenzies (2026-11-26, second overnight run, unverified in Studio)

From `python3 tools/econ/loop.py`, which reuses the simulator's rules and reads `Frenzy.luau` and `Goals.luau`.

**Daily goals** pay 205 coins a day when all three are done. Against one 25 minute session that is about a quarter more for a new player (dock and worms: 785 coins a session, +26 percent) and under a tenth more for an expert (2,405 coins, +9 percent). So goals mostly help new players catch up, which is what they're for; they're capped per day, so grinding doesn't multiply them. If a new player's first days feel too fast in playtests, trim the hard goal first.

**Frenzies** last 60 s, bites come 4 times as fast and the school fish weigh 3 times as much. Best case, for a kid already standing at the spot:

| Spot | Time | Bait | coins/min normally | during a frenzy | extra per frenzy |
|---|---|---|---|---|---|
| Dock | Night | Minnow | 43.0 | 75.6 | 33 |
| Open water | Dusk | Worm | 40.2 | 86.1 | 46 |
| Fallen logs | Night | Worm | 37.9 | 93.9 | 56 |
| Riffle | Day | Minnow | 45.8 | 97.3 | 52 |

About 1.2 frenzies happen per 16 minute game day, so a 25 minute session sees roughly two, and walking there eats part of each minute. That is at most about 100 coins a session (+4 percent for an expert, about +12 percent for a kid who chases them). Frenzies are an exciting moment, not an income source, and the numbers say they can stay as they are.
