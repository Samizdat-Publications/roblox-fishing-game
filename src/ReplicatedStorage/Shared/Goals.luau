--!strict
-- Daily goals: three small goals a day that point players at something new to try (a
-- species, a spot at the right time, a rarer fish) and pay a few coins. Everyone gets the
-- same goals on the same day, so friends can chase them together, but a goal never asks
-- for water the player can't reach yet (Cedar Creek needs the Creek Pass).
-- Pure logic: the server calls ensure, onCatch and onSell; the client only shows them.
-- UNVERIFIED in Studio: written 2026-11-26 in the cloud.
local Shared = script.Parent
local FishData = require(Shared.FishData)
local Rarity = require(Shared.Rarity)
local Units = require(Shared.Units)

local Goals = {}

export type Goal = {
	id: string, -- unique for the day, "easy", "medium" or "hard"
	kind: string, -- "catchAny", "catchBait", "sell", "catchSpecies", "catchSize", "catchTier", "catchAt", "catchFrenzy"
	text: string, -- what the player reads
	target: number,
	progress: number,
	reward: number,
	done: boolean,
	species: string?,
	tier: string?,
	spot: string?,
	period: string?,
	bait: string?,
	cm: number?, -- catchSize: at least this long
}

export type State = { day: number, list: { Goal } }

Goals.REWARDS = { easy = 25, medium = 60, hard = 120 }

local LAKE_SPOTS = { "Dock", "WeedBed", "Logs", "DeepHole" }
local CREEK_SPOTS = { "Riffle", "Rocks", "Pool" }
local BOAT_SPOTS = { "Basin", "IslandPoint" } -- dinghy water; blue water needs a crew, so no goal sends you there
local SPOT_TEXT = {
	Dock = "the dock",
	WeedBed = "the weed bed",
	Logs = "the fallen logs",
	DeepHole = "the deep hole",
	Riffle = "the riffle",
	Rocks = "the creek rocks",
	Pool = "the deep pool",
	Basin = "the Big Lake basin",
	IslandPoint = "the island point",
}
-- Live baits the shop always sells, for "catch on" goals.
local BAIT_TEXT = { Worm = "worms", Cricket = "crickets", Minnow = "minnows" }
local BAIT_IDS = { "Cricket", "Minnow", "Worm" }
-- A size goal asks for a fish in the top third of its species' size range: about one
-- catch in four of that species is long enough.
Goals.SIZE_SHARE = 0.65
local PERIOD_TEXT = { Dawn = "at dawn", Day = "during the day", Dusk = "at dusk", Night = "at night" }

-- The day number used for goals (UTC days since 1970). Roblox servers all agree on os.time.
function Goals.dayOf(unixTime: number): number
	return math.floor(unixTime / 86400)
end

local function reachable(spots: { [string]: number }, creek: boolean, boat: boolean?): boolean
	for spot, w in spots do
		if w > 0 and (table.find(LAKE_SPOTS, spot) or (creek and table.find(CREEK_SPOTS, spot)) or (boat and table.find(BOAT_SPOTS, spot))) then
			return true
		end
	end
	return false
end

-- The best spot and time for a species, for the hint in a goal's text.
local function bestOf(t: { [string]: number }): string?
	local best, bw = nil, 0
	for k, w in t do
		if w > bw or (w == bw and best and k < best) then
			best, bw = k, w
		end
	end
	return best
end

-- Pick deterministically from a sorted list.
local function pick<T>(list: { T }, rng: Random): T
	return list[rng:NextInteger(1, #list)]
end

-- The day's three goals for a player who can (or can't yet) reach the creek, and who does
-- (or doesn't) own a boat for the Big Lake. Everyone with the same access gets the same goals.
function Goals.forDay(day: number, creek: boolean, boat: boolean?): { Goal }
	local rng = Random.new(day * 7919 + (if creek then 1 else 0) + (if boat then 2 else 0))
	local list: { Goal } = {}

	-- Easy: catch some fish, sell some, or catch some on one bait.
	local r = rng:NextNumber()
	if r < 0.5 then
		local n = pick({ 5, 6, 8 }, rng)
		table.insert(list, { id = "easy", kind = "catchAny", text = string.format("Catch %d fish", n), target = n, progress = 0, reward = Goals.REWARDS.easy, done = false })
	elseif r < 0.75 then
		local n = pick({ 60, 80, 100 }, rng)
		table.insert(list, { id = "easy", kind = "sell", text = string.format("Sell fish worth %d coins", n), target = n, progress = 0, reward = Goals.REWARDS.easy, done = false })
	else
		local bait = pick(BAIT_IDS, rng)
		local n = pick({ 3, 4, 5 }, rng)
		table.insert(list, { id = "easy", kind = "catchBait", text = string.format("Catch %d fish on %s", n, BAIT_TEXT[bait]), target = n, progress = 0, reward = Goals.REWARDS.easy, done = false, bait = bait })
	end

	-- Medium: a few of one Common or Uncommon species, or one good-sized one, with a hint.
	local plain = {}
	for _, s in FishData.list do
		local rank = Rarity.rank[Rarity.of(s)] or 1
		if rank <= 2 and reachable(s.spots, creek, boat) then
			table.insert(plain, s)
		end
	end
	table.sort(plain, function(a, b)
		return a.id < b.id
	end)
	local sp = pick(plain, rng)
	-- The hint names the best spot this player can reach (not blue water they can't fish yet).
	local open: { [string]: number } = {}
	for spot, w in sp.spots do
		if SPOT_TEXT[spot] and (table.find(LAKE_SPOTS, spot) or (creek and table.find(CREEK_SPOTS, spot)) or (boat and table.find(BOAT_SPOTS, spot))) then
			open[spot] = w
		end
	end
	local where = SPOT_TEXT[bestOf(open) or ""] or "around the lake"
	if rng:NextNumber() < 0.6 then
		local n = pick({ 2, 3 }, rng)
		table.insert(list, {
			id = "medium",
			kind = "catchSpecies",
			text = string.format("Catch %d %s (try %s)", n, sp.name, where),
			target = n,
			progress = 0,
			reward = Goals.REWARDS.medium,
			done = false,
			species = sp.id,
		})
	else
		local cm = math.floor(sp.minCm + (sp.maxCm - sp.minCm) * Goals.SIZE_SHARE + 0.5)
		table.insert(list, {
			id = "medium",
			kind = "catchSize",
			text = string.format("Catch a %s at least %s long (try %s)", sp.name, Units.atLeast(cm), where),
			target = 1,
			progress = 0,
			reward = Goals.REWARDS.medium,
			done = false,
			species = sp.id,
			cm = cm,
		})
	end

	-- Hard: a Rare or better fish, a fish from a given spot at a given time, or fish caught
	-- during a feeding frenzy (being there and noticing the birds is the skill).
	r = rng:NextNumber()
	if r < 0.35 then
		table.insert(list, { id = "hard", kind = "catchTier", text = "Catch a Rare fish or better", target = 1, progress = 0, reward = Goals.REWARDS.hard, done = false, tier = "Rare" })
	elseif r < 0.75 then
		local spots = table.clone(LAKE_SPOTS)
		for _, extra in { if creek then CREEK_SPOTS else {}, if boat then BOAT_SPOTS else {} } do
			for _, sname in extra do
				table.insert(spots, sname)
			end
		end
		local spot = pick(spots, rng)
		-- Only times when something there actually bites.
		local periods = {}
		for _, period in { "Dawn", "Day", "Dusk", "Night" } do
			for _, s in FishData.list do
				if (s.spots[spot] or 0) > 0 and (s.periods[period] or 0) >= 0.5 then
					table.insert(periods, period)
					break
				end
			end
		end
		local period = pick(periods, rng)
		local n = pick({ 2, 3 }, rng)
		table.insert(list, {
			id = "hard",
			kind = "catchAt",
			text = string.format("Catch %d fish at %s %s", n, SPOT_TEXT[spot], PERIOD_TEXT[period]),
			target = n,
			progress = 0,
			reward = Goals.REWARDS.hard,
			done = false,
			spot = spot,
			period = period,
		})
	else
		table.insert(list, { id = "hard", kind = "catchFrenzy", text = "Catch 2 fish during a feeding frenzy (watch for diving birds)", target = 2, progress = 0, reward = Goals.REWARDS.hard, done = false })
	end
	return list
end

-- Make sure the saved goals are today's (a new day brings new goals).
function Goals.ensure(state: any, day: number, creek: boolean, boat: boolean?): State
	if type(state) ~= "table" or state.day ~= day or type(state.list) ~= "table" then
		return { day = day, list = Goals.forDay(day, creek, boat) }
	end
	return state
end

local function advance(g: Goal, by: number, done: { Goal })
	if g.done then
		return
	end
	g.progress = math.min(g.target, g.progress + by)
	if g.progress >= g.target then
		g.done = true
		table.insert(done, g)
	end
end

-- After a catch: returns the goals this catch finished (the server pays their rewards).
-- `frenzy` is true when a feeding frenzy was on at the spot (the server knows; never saved).
function Goals.onCatch(state: State, fish: { id: string, spot: string, period: string, bait: string?, cm: number? }, frenzy: boolean?): { Goal }
	local done = {}
	local species = FishData.byId[fish.id]
	for _, g in state.list do
		if g.kind == "catchAny" then
			advance(g, 1, done)
		elseif g.kind == "catchSpecies" and g.species == fish.id then
			advance(g, 1, done)
		elseif g.kind == "catchTier" and species and (Rarity.rank[Rarity.of(species)] or 1) >= (Rarity.rank[g.tier or "Rare"] or 3) then
			advance(g, 1, done)
		elseif g.kind == "catchAt" and g.spot == fish.spot and g.period == fish.period then
			advance(g, 1, done)
		elseif g.kind == "catchBait" and g.bait == fish.bait then
			advance(g, 1, done)
		elseif g.kind == "catchSize" and g.species == fish.id and (fish.cm or 0) >= (g.cm or math.huge) then
			advance(g, 1, done)
		elseif g.kind == "catchFrenzy" and frenzy then
			advance(g, 1, done)
		end
	end
	return done
end

-- After selling: coins earned count toward a "sell" goal.
function Goals.onSell(state: State, coins: number): { Goal }
	local done = {}
	for _, g in state.list do
		if g.kind == "sell" then
			advance(g, coins, done)
		end
	end
	return done
end

return Goals
