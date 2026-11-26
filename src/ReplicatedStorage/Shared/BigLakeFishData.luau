--!strict
-- The Big Lake's fish, reached only by boat. Same shape as FishData entries.
-- UNVERIFIED: written overnight 2026-11-26 without Studio. Kept out of FishData.list on
-- purpose so the journal doesn't show three fish nobody can catch yet; the boat plan
-- (docs/superpowers/plans/2026-11-26-boat.md, Task 5) appends these to FishData.list once
-- the Big Lake's zones exist. The basin and island point are dinghy water; the drop-off is
-- in the blue water, reachable only on the two-person Deep-V boat.
local Shared = script.Parent
local FishData = require(Shared.FishData)

local list: { FishData.Species } = {
	{
		id = "WhiteBass",
		name = "White Bass",
		spots = { Basin = 1, DropOff = 0.4 },
		periods = { Dawn = 0.8, Day = 0.6, Dusk = 1, Night = 0.1 },
		baits = { Spinner = 1, Minnow = 0.9 },
		rarity = 0.9,
		minCm = 20,
		maxCm = 40,
		weightCoef = 1.3e-5,
		basePrice = 14,
		color = Color3.fromRGB(200, 205, 212),
		fight = { zone = 0.27, speed = 1.1, dart = 1.6, range = 0.4, sink = 0.1, heavy = 0.2, gain = 0.26, loss = 0.18, style = "tugger" },
		habit = "Schools in the open basin and chases baitfish at the surface, best at dusk. Spinners and minnows.",
		fightNote = "Quick, silvery dashes.",
		bite = "slam",
	},
	{
		id = "LakeTrout",
		name = "Lake Trout",
		spots = { DropOff = 1, Basin = 0.3 },
		periods = { Dawn = 1, Day = 0.7, Dusk = 0.5, Night = 0.1 },
		baits = { Minnow = 1, Spinner = 0.5 },
		rarity = 0.6,
		minCm = 40,
		maxCm = 90,
		weightCoef = 1.02e-5,
		basePrice = 40,
		color = Color3.fromRGB(95, 110, 100),
		fight = { zone = 0.25, speed = 0.6, dart = 0.6, range = 0.5, sink = 0.7, heavy = 0.6, gain = 0.15, loss = 0.13, style = "diver" },
		habit = "Lives deep and cold along the drop-off. Best early in the day on minnows.",
		fightNote = "Deep, heavy head shakes.",
		bite = "tap",
	},
	{
		id = "Muskellunge",
		name = "Muskellunge",
		spots = { IslandPoint = 1, DropOff = 0.3 },
		periods = { Dawn = 0.5, Day = 0.8, Dusk = 1, Night = 0.1 },
		baits = { Spinner = 1, Minnow = 0.6 },
		rarity = 0.12,
		minCm = 60,
		maxCm = 130,
		weightCoef = 8.3e-6,
		basePrice = 90,
		color = Color3.fromRGB(150, 140, 90),
		fight = { zone = 0.23, speed = 1.5, dart = 1.0, range = 0.9, sink = 0.2, heavy = 0.5, gain = 0.16, loss = 0.18, style = "shaker" },
		habit = "The rare giant of the weedy island point. Follows a spinner for ages, then strikes at dusk.",
		fightNote = "Huge, wild runs.",
		bite = "slam",
	},
}

-- Spot names for the journal and hints (merge into FishLogic.SPOT_NAMES with the fish).
local spotNames = {
	Basin = "the open basin",
	DropOff = "the blue-water drop-off",
	IslandPoint = "the island point",
}

local byId: { [string]: FishData.Species } = {}
for _, s in list do
	byId[s.id] = s
end

return {
	list = list,
	byId = byId,
	spotNames = spotNames,
}
