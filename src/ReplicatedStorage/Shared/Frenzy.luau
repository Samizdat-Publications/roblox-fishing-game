--!strict
-- Feeding frenzies (docs/DIRECTION.md section 3): now and then a school boils at the surface
-- of one spot and bites come back to back for about a minute. Only real schooling fish do
-- it, mostly at dawn and dusk and in the rush before a storm, and it's announced by sight
-- and sound (birds diving, the water boiling), so being there and noticing is the skill.
-- Never sold or summoned. Pure logic. UNVERIFIED in Studio: written 2026-11-26 in the cloud.
local Shared = script.Parent
local FishLogic = require(Shared.FishLogic)

local Frenzy = {}

Frenzy.DURATION = 60 -- real seconds
Frenzy.BITE_SPEED = 0.25 -- bite delays are a quarter as long
Frenzy.SCHOOL_BOOST = 3 -- schooling fish weigh three times as much during a frenzy
-- Expected frenzies per game day (16 real minutes) on a clear day; dawn, dusk and the
-- pre-storm rush make them likelier (see chancePerSecond).
Frenzy.PER_DAY = 1.2

-- Which fish school at each spot (real schooling species).
Frenzy.SCHOOLS = {
	Dock = { "Bluegill", "Pumpkinseed" },
	OpenWater = { "YellowPerch" },
	Logs = { "BlackCrappie" },
	Riffle = { "CreekChub" },
	Basin = { "WhiteBass" },
	DropOff = { "LakeWhitefish" },
} :: { [string]: { string } }

Frenzy.SIGNS = {
	Dock = "Bluegills are boiling around the dock!",
	OpenWater = "Birds are diving over open water: a school of perch is feeding!",
	Logs = "Crappie are swarming the fallen logs!",
	Riffle = "Creek chubs are jumping in the riffle!",
	Basin = "Gulls are diving in the open basin: white bass are chasing bait!",
	DropOff = "Whitefish are dimpling the surface over the drop-off!",
} :: { [string]: string }

local PERIOD_BOOST = { Dawn = 2, Day = 0.6, Dusk = 2, Night = 0.3 }

-- Chance per real second that a frenzy starts now (the server rolls once a second).
function Frenzy.chancePerSecond(period: string, weather: string?, dayLength: number): number
	local base = Frenzy.PER_DAY / dayLength
	local m = PERIOD_BOOST[period] or 1
	if weather == "PreStorm" then
		m *= 3
	elseif weather == "Storm" or weather == "ColdFront" then
		m *= 0.2
	end
	return base * m
end

-- Spots where a frenzy can happen now: a schooling fish there is actually active at this
-- time (bites on some bait). `allowed` limits it to spots the players can reach.
function Frenzy.candidates(period: string, now: any, allowed: { [string]: boolean }?): { string }
	local out = {}
	for spot, school in Frenzy.SCHOOLS do
		if allowed and not allowed[spot] then
			continue
		end
		local active = false
		for _, bait in { "Worm", "Cricket", "Minnow", "Spinner" } do
			for _, w in FishLogic.biteWeights(spot, period, bait, now) do
				if table.find(school, w.id) then
					active = true
				end
			end
		end
		if active then
			table.insert(out, spot)
		end
	end
	table.sort(out)
	return out
end

-- Bite weights during a frenzy at this spot: the schooling fish weigh more; nobody new
-- appears (a fish still only takes the baits it takes).
function Frenzy.weights(weights: { FishLogic.Weight }, spot: string): { FishLogic.Weight }
	local school = Frenzy.SCHOOLS[spot]
	if not school then
		return weights
	end
	local out = {}
	for _, w in weights do
		local mult = if table.find(school, w.id) then Frenzy.SCHOOL_BOOST else 1
		table.insert(out, { id = w.id, w = w.w * mult })
	end
	table.sort(out, function(a, b)
		return a.w > b.w
	end)
	return out
end

return Frenzy
