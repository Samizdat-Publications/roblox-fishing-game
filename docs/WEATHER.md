# Weather that fishes like the real thing

Written overnight 2026-11-26. A spec only: nothing is built, nothing is tested. Design item 3 in `DESIGN.md` ("weather that acts like the real thing").

## Rules for every kind of weather

- **It changes which fish bite where, not how lucky you are.** Each kind multiplies the same bite weights the game already uses (spot x time x bait x rarity), per spot and per species. Reading the weather is one more piece of real fishing knowledge, like bait and time of day.
- **Everyone on a server shares it.** The server picks it; the client only draws it.
- **It is free to read.** A barometer and a chalkboard forecast at Bait and Tackle, plus signs in the world (sky, wind, waves, sound). There is never a way to buy, call, skip or extend weather: no totems, no potions, no Robux, no "weather boost" in any shop. That is the line other fishing games cross, and we don't.
- **It nudges, never blocks.** No weather makes a spot useless for the whole day; the worst is a slow bite with a hint that says why.
- **Kids can tell it's happening.** Every kind has at least two signs a player can see or hear, and the journal explains it after the first time ("Cold front: fish went deep and quiet").

How it fits the bite timer: today the bite delay barely depends on how much fish want a combo (see `docs/ECONOMY.md`, finding 2), so multiplying weights would mostly change *which* fish bite, not *how fast*. With proposed change 1 (bite time = 3 s / total weight), weather also speeds up or slows down the bite, which is how it feels on a real lake. Build weather after that decision.

## The kinds

### Overcast (low light)
- **Real fishing:** cloud cover dims the water, so fish that hunt in low light (bass, walleye, crappie, pike) leave cover and feed longer into the day, and move shallower.
- **In game:** by day, low-light hunters bite as if it were dawn; shallow spots (weed bed, dock, riffle) up, deep spots (deep hole, pool) slightly down. Panfish unchanged.
- **How often:** about 1 day in 4, the whole game day.
- **Signs:** gray sky with no sun, no shadows, softer light; fish shadows show up in shallow spots at noon.
- **Never:** it doesn't raise rarity; a pike is still a pike.

### Cold front (bluebird day)
- **Real fishing:** after a front passes, the sky goes clear and bright, pressure rises fast, and fish go deep, tight to cover and slow to bite.
- **In game:** everything bites about half as much; deep spots lose the least (deep hole, pool, drop-off). Panfish under the dock still bite a little (shade).
- **How often:** about 1 day in 10, always the day after a storm.
- **Signs:** barometer needle jumps up ("Rising fast"), bright hard-blue sky, a cool north wind, fewer fish shadows. The "nothing biting" hint adds: "A cold front came through. Try deep water and go slow."
- **Never:** it doesn't stop fishing. Bites slow to the 20 to 40 second range, never zero.

### Before a storm (feeding rush)
- **Real fishing:** as pressure falls ahead of a storm, fish often feed hard for an hour or two.
- **In game:** for 2 game hours (80 real seconds) before the storm, every fish bites about 60 percent more, predators most (bass, pike, catfish, walleye, white bass). Then the storm: bites drop to about 60 percent, and lightning means the safe thing is off the water.
- **How often:** about 1 day in 7. The forecast board says "Storm this afternoon" at dawn.
- **Signs:** barometer falling, dark clouds building on one side of the sky, wind picks up and swings, distant thunder, then rain.
- **Safety:** during lightning, boats can't leave the slip and a toast says "Lightning! Fishing from shore is safer." (It teaches a real rule.) Casting from the dock still works.
- **Never:** the rush isn't sold or summoned. You get it by watching the sky and being there.

### Wind on a point
- **Real fishing:** wind pushes plankton and baitfish onto the shore it blows toward, and predators follow; the windy side beats the calm side.
- **In game:** the wind has a direction. Spots on the downwind side (the shore the wind blows toward) get predators up about 40 percent; the upwind, calm side down about 20 percent. Lake: the weed bed is the west side, the logs the east; the Big Lake's island point is the classic windy point.
- **How often:** a light breeze most days (no effect); a real wind about 1 day in 3, from a random side.
- **Signs:** waves and whitecaps on the downwind side, reeds and the stand awnings lean, a wind sock on the dock end, louder wind and water sounds. The forecast board says "Wind from the west".
- **Never:** wind doesn't push the bobber away or ruin casts. It's information, not a hassle.

### Fog
- **Real fishing:** calm, cool mornings bring fog; fish feel hidden and the dawn bite lasts longer.
- **In game:** on a foggy day, the dawn bite (dawn factors) runs until the fog lifts, about 2 game hours after dawn ends.
- **How often:** about 1 dawn in 5, only on calm days.
- **Signs:** thick fog over the water, lamps stay on, muffled sounds, the bobber's light matters.
- **Never:** fog never hides the catch bar or the UI.

### Full moon
- **Real fishing:** bright moonlit nights help night feeders (walleye, catfish, crappie) hunt; the next dawn is often slower because fish fed all night.
- **In game:** an 8 game day moon cycle. On the full moon night, night feeders bite about 30 percent more; the following dawn, about 15 percent less for everyone.
- **How often:** 1 night in 8 (the moon cycle is shown on the forecast board as a little calendar).
- **Signs:** a big bright moon, brighter night light, silver reflections on the water.
- **Never:** no "blood moon" or event fish you can only get by paying.

## Data table for tomorrow's session

In the style of `FishData.luau`. Multipliers default to 1; `spots` and `species` multiply that spot's or species' bite weight; `asPeriod` makes listed species use another period's factor; `hours` is game hours (40 real seconds each).

```lua
--!strict
-- Weather kinds. Multipliers act on FishLogic bite weights; missing entries mean 1.
-- The server picks one kind per game day at dawn (by chance), storms bring a pre-storm
-- rush first, and a cold front always follows a storm.
export type Weather = {
	id: string,
	name: string,
	chance: number, -- share of days (picked at dawn); 0 for kinds that only follow another
	hours: number, -- how long it lasts in game hours
	all: number?, -- every bite
	spots: { [string]: number }?,
	species: { [string]: number }?,
	asPeriod: { from: string, to: string, species: { string } }?,
	forecast: string, -- chalkboard text at Bait and Tackle
	journal: string, -- explained in the journal the first time
}

local LOW_LIGHT = { "LargemouthBass", "Walleye", "BlackCrappie", "NorthernPike", "SmallmouthBass" }
local PREDATORS = { LargemouthBass = 1.4, NorthernPike = 1.4, Walleye = 1.4, SmallmouthBass = 1.4, WhiteBass = 1.4, Muskellunge = 1.4 }

local list: { Weather } = {
	{
		id = "Clear", name = "Clear", chance = 0.33, hours = 24,
		forecast = "Clear and calm.",
		journal = "Clear days: fish follow their usual habits.",
	},
	{
		id = "Overcast", name = "Overcast", chance = 0.25, hours = 24,
		spots = { WeedBed = 1.3, Dock = 1.2, Riffle = 1.2, Rocks = 1.1, DeepHole = 0.85, Pool = 0.85, DropOff = 0.85 },
		asPeriod = { from = "Day", to = "Dawn", species = LOW_LIGHT },
		forecast = "Cloudy all day. Bass and walleye won't mind.",
		journal = "Overcast: low light keeps hunters feeding in the shallows all day.",
	},
	{
		id = "Fog", name = "Foggy morning", chance = 0.15, hours = 5, -- dawn plus 2 hours
		asPeriod = { from = "Day", to = "Dawn", species = LOW_LIGHT },
		forecast = "Fog at dawn, clearing by mid-morning.",
		journal = "Fog: fish feel hidden, so the morning bite lasts longer.",
	},
	{
		id = "Wind", name = "Windy", chance = 0.15, hours = 24,
		species = PREDATORS, -- applied only to the downwind side's spots; the upwind side gets 0.8
		forecast = "Wind from the %s. Fish the shore it blows toward.",
		journal = "Wind: it pushes baitfish onto the downwind shore, and hunters follow.",
	},
	{
		id = "PreStorm", name = "Storm coming", chance = 0.12, hours = 2,
		all = 1.3, species = { LargemouthBass = 1.6, NorthernPike = 1.6, ChannelCatfish = 1.6, Walleye = 1.6, WhiteBass = 1.6 },
		forecast = "Storm this afternoon. Fish feed hard before it hits.",
		journal = "Falling pressure before a storm: one of the best bites there is.",
	},
	{
		id = "Storm", name = "Thunderstorm", chance = 0, hours = 3, -- always follows PreStorm
		all = 0.6,
		forecast = "Thunderstorm. Stay off the water when there's lightning.",
		journal = "Storm: fish slow down, and lightning means boats stay in.",
	},
	{
		id = "ColdFront", name = "Cold front", chance = 0, hours = 24, -- always the day after a Storm
		all = 0.5, spots = { DeepHole = 1.6, Pool = 1.6, DropOff = 1.6, Dock = 1.2 },
		forecast = "Cold front: bright, breezy and slow. Go deep.",
		journal = "Cold front: rising pressure sends fish deep and makes them picky.",
	},
}

-- The moon runs on its own 8 day cycle and stacks with the day's weather.
local MOON = {
	cycleDays = 8,
	fullNight = { species = { Walleye = 1.3, ChannelCatfish = 1.3, BlackCrappie = 1.3 } },
	afterFullDawn = { all = 0.85 },
}
```

Notes for building it:
- Apply weather inside `FishLogic.biteWeights` (pass the weather in), so the shadows, hints and catches all agree. Add unit tests in the existing spec style: overcast day makes a bass top the weed bed at noon on a plastic worm; a cold front halves every weight except deep spots; the rush never changes which bait a fish accepts.
- Hints should mention the weather when it's the reason ("Cold front. Try deep water and go slow").
- The `Wind` entry needs a direction picked per day and a list of which spots are on which side; the Big Lake's island point should count as downwind for every direction except one.
- Keep the probabilities in the table so they can be tuned like prices. The economy sim (`tools/econ/sim.py`) can take a weather mix later to check it doesn't swing income more than about 20 percent either way over a session.
