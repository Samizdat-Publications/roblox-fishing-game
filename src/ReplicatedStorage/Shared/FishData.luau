--!strict
-- The lake's fish. Each factor table says how much a spot, time of day or bait suits the fish
-- (1 = perfect, 0 = never). A missing spot or bait means never.
-- Weight in kg = weightCoef * length_cm ^ 3 (close to real length and weight curves).

export type FightProfile = {
	zone: number, -- catch zone size as a share of the bar
	speed: number, -- how fast the fish moves along the bar
	dart: number, -- how often per second it picks a new spot
	range: number, -- how far it darts
	sink: number, -- pull toward the bottom (0 to 1)
	heavy: number, -- how much it fights your lift (0 to 1)
	gain: number, -- progress per second while inside the zone
	loss: number, -- progress lost per second outside it
}

export type Species = {
	id: string,
	name: string,
	spots: { [string]: number },
	periods: { [string]: number },
	baits: { [string]: number },
	rarity: number,
	minCm: number,
	maxCm: number,
	weightCoef: number,
	basePrice: number,
	fight: FightProfile,
	habit: string,
	fightNote: string,
}

local list: { Species } = {
	{
		id = "Bluegill",
		name = "Bluegill",
		spots = { Dock = 1, WeedBed = 0.6 },
		periods = { Dawn = 0.5, Day = 1, Dusk = 0.4, Night = 0.05 },
		baits = { Worm = 1, Cricket = 0.9 },
		rarity = 1,
		minCm = 12,
		maxCm = 25,
		weightCoef = 1.9e-5,
		basePrice = 4,
		fight = { zone = 0.30, speed = 0.9, dart = 1.6, range = 0.35, sink = 0, heavy = 0, gain = 0.30, loss = 0.18 },
		habit = "Hangs around the dock in daylight. Small hooks, worms or crickets.",
		fightNote = "Quick little tugs.",
	},
	{
		id = "Pumpkinseed",
		name = "Pumpkinseed",
		spots = { WeedBed = 1, Dock = 0.5 },
		periods = { Dawn = 0.6, Day = 1, Dusk = 0.3, Night = 0.05 },
		baits = { Cricket = 1, Worm = 0.6 },
		rarity = 0.8,
		minCm = 10,
		maxCm = 22,
		weightCoef = 1.8e-5,
		basePrice = 4,
		fight = { zone = 0.32, speed = 0.8, dart = 1.5, range = 0.3, sink = 0, heavy = 0, gain = 0.32, loss = 0.16 },
		habit = "Lives in the weed bed. Crickets work best.",
		fightNote = "Zippy but small.",
	},
	{
		id = "YellowPerch",
		name = "Yellow Perch",
		spots = { OpenWater = 1, Dock = 0.5 },
		periods = { Dawn = 1, Day = 0.5, Dusk = 0.3, Night = 0.05 },
		baits = { Minnow = 1, Worm = 0.6 },
		rarity = 0.7,
		minCm = 15,
		maxCm = 32,
		weightCoef = 1.28e-5,
		basePrice = 8,
		fight = { zone = 0.28, speed = 0.6, dart = 1.0, range = 0.3, sink = 0.1, heavy = 0.1, gain = 0.28, loss = 0.16 },
		habit = "Schools in open water, best in the morning. Minnows.",
		fightNote = "Steady and stubborn.",
	},
	{
		id = "BlackCrappie",
		name = "Black Crappie",
		spots = { Logs = 1, Dock = 0.6 },
		periods = { Dawn = 0.3, Day = 0.15, Dusk = 1, Night = 0.8 },
		baits = { Minnow = 1, Worm = 0.2 },
		rarity = 0.7,
		minCm = 15,
		maxCm = 35,
		weightCoef = 1.6e-5,
		basePrice = 11,
		fight = { zone = 0.26, speed = 0.8, dart = 1.4, range = 0.4, sink = 0.1, heavy = 0.1, gain = 0.26, loss = 0.20 },
		habit = "Hides in fallen logs, feeds at dusk and after dark. Minnows.",
		fightNote = "Darts around, soft mouth.",
	},
	{
		id = "LargemouthBass",
		name = "Largemouth Bass",
		spots = { WeedBed = 1, Logs = 1, Dock = 0.3 },
		periods = { Dawn = 1, Day = 0.25, Dusk = 1, Night = 0.2 },
		baits = { PlasticWorm = 1, Spinner = 0.8, Minnow = 0.6, Worm = 0.15 },
		rarity = 0.6,
		minCm = 25,
		maxCm = 60,
		weightCoef = 1.56e-5,
		basePrice = 26,
		fight = { zone = 0.25, speed = 1.4, dart = 0.8, range = 0.7, sink = 0.2, heavy = 0.3, gain = 0.22, loss = 0.20 },
		habit = "Ambushes from weeds and logs at dawn and dusk. Plastic worms and spinners.",
		fightNote = "Big runs, then rests.",
	},
	{
		id = "ChannelCatfish",
		name = "Channel Catfish",
		spots = { DeepHole = 1, Logs = 0.2 },
		periods = { Dawn = 0.2, Day = 0.03, Dusk = 0.6, Night = 1 },
		baits = { Stinkbait = 1, Worm = 0.4, Minnow = 0.3 },
		rarity = 0.6,
		minCm = 35,
		maxCm = 90,
		weightCoef = 1.08e-5,
		basePrice = 32,
		fight = { zone = 0.26, speed = 0.5, dart = 0.6, range = 0.5, sink = 0.6, heavy = 0.6, gain = 0.16, loss = 0.14 },
		habit = "Cruises the deep hole at night. Follows its nose to stinkbait.",
		fightNote = "Heavy, keeps pulling down.",
	},
	{
		id = "CommonCarp",
		name = "Common Carp",
		spots = { OpenWater = 1, DeepHole = 0.5 },
		periods = { Dawn = 0.5, Day = 1, Dusk = 0.5, Night = 0.1 },
		baits = { Worm = 0.6, Stinkbait = 0.6 },
		rarity = 0.4,
		minCm = 35,
		maxCm = 80,
		weightCoef = 1.5e-5,
		basePrice = 24,
		fight = { zone = 0.27, speed = 0.6, dart = 0.7, range = 0.6, sink = 0.4, heavy = 0.5, gain = 0.15, loss = 0.12 },
		habit = "Roots along the bottom of open water in daylight. Worms or stinkbait.",
		fightNote = "Long, slow, strong.",
	},
	{
		id = "NorthernPike",
		name = "Northern Pike",
		spots = { WeedBed = 0.8, OpenWater = 0.6 },
		periods = { Dawn = 0.7, Day = 1, Dusk = 0.4, Night = 0.05 },
		baits = { Spinner = 1, Minnow = 0.7 },
		rarity = 0.15,
		minCm = 45,
		maxCm = 110,
		weightCoef = 7.3e-6,
		basePrice = 60,
		fight = { zone = 0.22, speed = 1.8, dart = 1.2, range = 0.8, sink = 0.2, heavy = 0.3, gain = 0.20, loss = 0.24 },
		habit = "Rare hunter on the weed edge and open water by day. Chases spinners.",
		fightNote = "Wild, fast runs.",
	},
}

local byId: { [string]: Species } = {}
for _, s in list do
	byId[s.id] = s
end

return {
	list = list,
	byId = byId,
}
