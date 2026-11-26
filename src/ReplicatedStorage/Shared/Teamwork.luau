--!strict
-- Rewards for going out together on the Deep-V (boat plan Task 8): fish landed in blue
-- water with a full crew are team catches (both journals, coins split evenly), and only the
-- navigator sees the fish finder. Pure logic. UNVERIFIED in Studio: 2026-11-26 in the cloud.
local Shared = script.Parent
local BoatData = require(Shared.BoatData)
local FishData = require(Shared.FishData)
local FishLogic = require(Shared.FishLogic)
local Rarity = require(Shared.Rarity)

local Teamwork = {}

-- Is this catch a team catch? Only from a boat that needs a crew, with the crew aboard,
-- in blue water.
function Teamwork.isTeamCatch(boatId: string?, inBlueWater: boolean, aboard: number): boolean
	local b = boatId and BoatData.byId[boatId]
	return b ~= nil and b.crew > 1 and aboard >= b.crew and inBlueWater
end

-- Split a catch's price between the crew: even shares, any odd coin to the one who landed it.
function Teamwork.split(price: number, crew: number): { number }
	crew = math.max(1, math.floor(crew))
	local each = math.floor(price / crew)
	local out = table.create(crew, each)
	out[1] += price - each * crew
	return out
end

export type Mark = { tier: string, size: string }

-- What the fish finder shows under the boat: up to four marks, the likeliest first, each
-- with its rarity colour and a rough size, without naming the fish (that's still the fun).
function Teamwork.finder(spot: string, period: string, now: any): { Mark }
	local weights: { [string]: number } = {}
	for _, bait in { "Worm", "Cricket", "Minnow", "Stinkbait", "Spinner", "PlasticWorm" } do
		for _, w in FishLogic.biteWeights(spot, period, bait, now) do
			weights[w.id] = math.max(weights[w.id] or 0, w.w)
		end
	end
	local list = {}
	local total = 0
	for id, w in weights do
		table.insert(list, { id = id, w = w })
		total += w
	end
	table.sort(list, function(a, b)
		return if a.w == b.w then a.id < b.id else a.w > b.w
	end)
	local count = math.clamp(math.floor(total * 4 + 0.5), if #list > 0 then 1 else 0, 4)
	local marks = {}
	for i = 1, math.min(count, #list) do
		local s = FishData.byId[list[i].id]
		local mid = (s.minCm + s.maxCm) / 2
		local size = if mid >= 60 then "large" elseif mid >= 30 then "medium" else "small"
		table.insert(marks, { tier = Rarity.of(s), size = size })
	end
	return marks
end

return Teamwork
