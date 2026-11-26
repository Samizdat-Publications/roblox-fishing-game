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

local Goals = {}

export type Goal = {
	id: string, -- unique for the day, "easy", "medium" or "hard"
	kind: string, -- "catchAny", "catchSpecies", "catchTier", "catchAt", "sell"
	text: string, -- what the player reads
	target: number,
	progress: number,
	reward: number,
	done: boolean,
	species: string?,
	tier: string?,
	spot: string?,
	period: string?,
}

export type State = { day: number, list: { Goal } }

Goals.REWARDS = { easy = 25, medium = 60, hard = 120 }

local LAKE_SPOTS = { "Dock", "WeedBed", "Logs", "DeepHole" }
local CREEK_SPOTS = { "Riffle", "Rocks", "Pool" }
local SPOT_TEXT = {
	Dock = "the dock",
	WeedBed = "the weed bed",
	Logs = "the fallen logs",
	DeepHole = "the deep hole",
	Riffle = "the riffle",
	Rocks = "the creek rocks",
	Pool = "the deep pool",
}
local PERIOD_TEXT = { Dawn = "at dawn", Day = "during the day", Dusk = "at dusk", Night = "at night" }

-- The day number used for goals (UTC days since 1970). Roblox servers all agree on os.time.
function Goals.dayOf(unixTime: number): number
	return math.floor(unixTime / 86400)
end

local function reachable(spots: { [string]: number }, creek: boolean): boolean
	for spot, w in spots do
		if w > 0 and (table.find(LAKE_SPOTS, spot) or (creek and table.find(CREEK_SPOTS, spot))) then
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

-- The day's three goals for a player who can (or can't yet) reach the creek.
function Goals.forDay(day: number, creek: boolean): { Goal }
	local rng = Random.new(day * 7919 + (if creek then 1 else 0))
	local list: { Goal } = {}

	-- Easy: catch some fish, or sell some.
	if rng:NextNumber() < 0.7 then
		local n = pick({ 5, 6, 8 }, rng)
		table.insert(list, { id = "easy", kind = "catchAny", text = string.format("Catch %d fish", n), target = n, progress = 0, reward = Goals.REWARDS.easy, done = false })
	else
		local n = pick({ 60, 80, 100 }, rng)
		table.insert(list, { id = "easy", kind = "sell", text = string.format("Sell fish worth %d coins", n), target = n, progress = 0, reward = Goals.REWARDS.easy, done = false })
	end

	-- Medium: catch a few of one Common or Uncommon species, with a hint where to look.
	local plain = {}
	for _, s in FishData.list do
		local r = Rarity.rank[Rarity.of(s)] or 1
		if r <= 2 and reachable(s.spots, creek) then
			table.insert(plain, s)
		end
	end
	table.sort(plain, function(a, b)
		return a.id < b.id
	end)
	local sp = pick(plain, rng)
	local n = pick({ 2, 3 }, rng)
	local where = bestOf(sp.spots)
	table.insert(list, {
		id = "medium",
		kind = "catchSpecies",
		text = string.format("Catch %d %s (try %s)", n, sp.name, SPOT_TEXT[where or ""] or "around the lake"),
		target = n,
		progress = 0,
		reward = Goals.REWARDS.medium,
		done = false,
		species = sp.id,
	})

	-- Hard: a Rare or better fish, or a fish from a given spot at a given time.
	if rng:NextNumber() < 0.5 then
		table.insert(list, { id = "hard", kind = "catchTier", text = "Catch a Rare fish or better", target = 1, progress = 0, reward = Goals.REWARDS.hard, done = false, tier = "Rare" })
	else
		local spots = table.clone(LAKE_SPOTS)
		if creek then
			for _, s in CREEK_SPOTS do
				table.insert(spots, s)
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
	end
	return list
end

-- Make sure the saved goals are today's (a new day brings new goals).
function Goals.ensure(state: any, day: number, creek: boolean): State
	if type(state) ~= "table" or state.day ~= day or type(state.list) ~= "table" then
		return { day = day, list = Goals.forDay(day, creek) }
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
function Goals.onCatch(state: State, fish: { id: string, spot: string, period: string }): { Goal }
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
