--!strict
-- Coming back tomorrow (leg plan L6, "Living lake"): the Today on the Lake chalkboard, the
-- fish of the day, the Legendary rumour, the shopkeeper's daily tackle box and the "While You
-- Were Away" pond card. The rule: come back because something is waiting or different, never
-- because you'd lose something. No streaks, no countdowns, nothing counts up, nothing for sale.
-- Everything here is picked from the real date's day number (Goals.dayOf), so every server
-- shows the same board on the same day. Pure logic, no Roblox services.
-- UNVERIFIED in Studio: written 2026-11-27 (L6d).
local Shared = script.Parent
local FishData = require(Shared.FishData)
local FishLogic = require(Shared.FishLogic)
local BaitData = require(Shared.BaitData)
local Rarity = require(Shared.Rarity)
local Units = require(Shared.Units)

local Daily = {}

-- The fish of the day bites a little more readily: its bite weight is multiplied by this
-- (tools/econ/sim.py reads it: --fish-of-day).
Daily.FISH_OF_DAY_BOOST = 1.3

local LAKE_SPOTS = { Dock = true, WeedBed = true, Logs = true, DeepHole = true, OpenWater = true }
local CREEK_SPOTS = FishLogic.CREEK_SPOTS

-- A 32-bit integer hash, the same on every server and in Lune (no Random: Lune's stand-in
-- draws different numbers from Roblox's).
local function mul32(a: number, b: number): number
	local hi, lo = a // 65536, a % 65536
	return ((hi * b) % 65536 * 65536 + lo * b) % 4294967296
end

local function mix(n: number): number
	local x = math.floor(n) % 4294967296
	x = bit32.bxor(x, bit32.rshift(x, 16))
	x = mul32(x, 0x85EBCA6B)
	x = bit32.bxor(x, bit32.rshift(x, 13))
	x = mul32(x, 0xC2B2AE35)
	x = bit32.bxor(x, bit32.rshift(x, 16))
	return x
end

-- 1..n for a day and a salt (each pick uses its own salt so they don't move together).
local function pick(day: number, salt: number, n: number): number
	return mix(day * 7 + salt * 1000003) % n + 1
end
Daily._pick = pick -- for the specs

local function inWater(s: FishData.Species, bigLake: boolean?): boolean
	for spot, w in s.spots do
		if w > 0 and (LAKE_SPOTS[spot] or CREEK_SPOTS[spot] or (bigLake and not LAKE_SPOTS[spot] and not CREEK_SPOTS[spot])) then
			return true
		end
	end
	return false
end

local function sortedById(list: { FishData.Species }): { FishData.Species }
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

-- Common and Uncommon fish of the lake and creek (never the Big Lake, never weather-only).
function Daily.fishOfDayChoices(): { FishData.Species }
	local out = {}
	for _, s in FishData.list do
		local rank = Rarity.rank[Rarity.of(s)] or 1
		if rank <= 2 and not s.weather and inWater(s, false) then
			table.insert(out, s)
		end
	end
	return sortedById(out)
end

function Daily.fishOfDay(day: number): string
	local list = Daily.fishOfDayChoices()
	return list[pick(day, 1, #list)].id
end

-- The fish of the day's bite weight times FISH_OF_DAY_BOOST, re-sorted heaviest first. Only
-- that species changes, and only where it already bites: it never makes a new fish bite.
function Daily.boost(weights: { FishLogic.Weight }, speciesId: string?): { FishLogic.Weight }
	if not speciesId then
		return weights
	end
	local out: { FishLogic.Weight } = {}
	local changed = false
	for _, x in weights do
		if x.id == speciesId then
			table.insert(out, { id = x.id, w = x.w * Daily.FISH_OF_DAY_BOOST })
			changed = true
		else
			table.insert(out, x)
		end
	end
	if changed then
		table.sort(out, function(a, b)
			return a.w > b.w
		end)
	end
	return out
end

-- The Legendaries a rumour can be about: lake and creek ones, plus the Big Lake's when it's open.
function Daily.legendaries(bigLake: boolean?): { FishData.Species }
	local out = {}
	for _, s in FishData.list do
		if Rarity.of(s) == "Legendary" and inWater(s, bigLake) then
			table.insert(out, s)
		end
	end
	return sortedById(out)
end

local function best(t: { [string]: number }, allowed: ((string) -> boolean)?): string?
	local key, bw = nil, 0
	for k, w in t do
		if (not allowed or allowed(k)) and (w > bw or (w == bw and key ~= nil and k < key)) then
			key, bw = k, w
		end
	end
	return key
end

local TIME_TEXT = { Dawn = "at first light", Day = "in broad daylight", Dusk = "around sunset", Night = "after dark" }
local BAIT_TEXT = { Worm = "worms", Cricket = "crickets", Minnow = "minnows", Stinkbait = "stinkbait", Spinner = "a flashy spinner", PlasticWorm = "a plastic worm" }

export type Rumour = { species: string, kind: string, hint: string, text: string }

-- Hearsay about one Legendary, true to its habits (best spot, time or bait), never a promise.
function Daily.rumour(day: number, bigLake: boolean?): Rumour
	local list = Daily.legendaries(bigLake)
	local s = list[pick(day, 2, #list)]
	local kinds = { "spot", "time", "bait" }
	local kind = kinds[pick(day, 3, #kinds)]
	local hint, text
	if kind == "spot" then
		hint = best(s.spots, function(k)
			return FishLogic.SPOT_NAMES[k] ~= nil and (bigLake == true or LAKE_SPOTS[k] == true or CREEK_SPOTS[k] == true)
		end) or "DeepHole"
		text = string.format("Folks say a %s has been seen around %s. Maybe it's true!", s.name, FishLogic.SPOT_NAMES[hint])
	elseif kind == "time" then
		hint = best(s.periods) or "Night"
		text = string.format("Old-timers swear the %s feeds best %s. Could be a fish story.", s.name, TIME_TEXT[hint])
	else
		hint = best(s.baits, function(k)
			return BAIT_TEXT[k] ~= nil
		end) or "Worm"
		text = string.format("Someone at the shop says the %s can't resist %s. Worth a try?", s.name, BAIT_TEXT[hint])
	end
	return { species = s.id, kind = kind, hint = hint, text = text }
end

local WEEKDAYS = { "Thursday", "Friday", "Saturday", "Sunday", "Monday", "Tuesday", "Wednesday" } -- day 0 was a Thursday

function Daily.weekday(day: number): string
	return WEEKDAYS[day % 7 + 1]
end

export type Board = { weekday: string, weather: string, fish: string, fishNote: string, rumour: string }

-- Everything the chalkboard says today. `forecast` is Weather.forecast for the date's plan.
function Daily.board(day: number, forecast: string, bigLake: boolean?): Board
	local fish = FishData.byId[Daily.fishOfDay(day)]
	return {
		weekday = Daily.weekday(day),
		weather = forecast,
		fish = fish.name,
		fishNote = "Biting a little more than usual today! " .. fish.habit,
		rumour = Daily.rumour(day, bigLake).text,
	}
end

----------------------------------------------------------------------------------------
-- The shopkeeper's tackle box: one small gift per real day. Missing days loses nothing and
-- nothing counts up; the save keeps only the last day a gift was taken (giftDay).

export type Gift = { bait: string, count: number, text: string }

-- Each worth 20 to 40 coins at shop prices (count * price / pack).
Daily.GIFTS = {
	{ bait = "Worm", count = 30, text = "30 worms" },
	{ bait = "Cricket", count = 20, text = "20 crickets" },
	{ bait = "Minnow", count = 15, text = "15 minnows" },
	{ bait = "Stinkbait", count = 15, text = "15 gobs of stinkbait" },
} :: { Gift }

local GIFT_LINES = {
	"Fresh this morning. Good luck out there!",
	"On the house. Bring me back a good story!",
	"Saw you eyeing these. Go on, take them.",
	"The fish have been hungry today. Use them well!",
}

Daily.GIFT_REFUSAL = "Come back tomorrow, I'll have something for you."

function Daily.giftFor(day: number): Gift
	return Daily.GIFTS[pick(day, 4, #Daily.GIFTS)]
end

function Daily.giftWorth(g: Gift): number
	local b = BaitData.byId[g.bait]
	return g.count * b.price / b.pack
end

-- Hands over today's gift if it hasn't been taken today. Returns (given, message).
function Daily.claimGift(data: any, day: number): (boolean, string)
	local last = if type(data.giftDay) == "number" then data.giftDay else 0
	if last >= day then
		return false, Daily.GIFT_REFUSAL
	end
	local g = Daily.giftFor(day)
	data.bait[g.bait] = (data.bait[g.bait] or 0) + g.count
	data.giftDay = day
	return true, string.format('The shopkeeper hands you a tackle box: %s! "%s"', g.text, GIFT_LINES[pick(day, 5, #GIFT_LINES)])
end

----------------------------------------------------------------------------------------
-- While You Were Away: what the pond did while the player was offline.

export type AwayReport = { title: string, lines: { string }, hint: string }

Daily.AWAY_MAX_LINES = 5

-- `before` is the pond's fish ({ id, name, cm }) as saved; `after` the same list once the
-- offline time has run (born fish are appended at the end, as PondLogic.tick does); `born`
-- the names PondLogic.tick returned. Nil when nothing a player would notice changed.
function Daily.awayReport(before: { any }, after: { any }, born: { string }): AwayReport?
	local lines: { string } = {}
	local grew = 0
	for i, b in before do
		local a = after[i]
		if a and a.id == b.id and Units.length(a.cm) ~= Units.length(b.cm) and a.cm > b.cm then
			grew += 1
			if #lines < Daily.AWAY_MAX_LINES - 1 then
				table.insert(lines, string.format("Your %s grew from %s to %s.", b.name, Units.length(b.cm), Units.length(a.cm)))
			end
		end
	end
	if grew > #lines then
		local more = grew - #lines
		table.insert(lines, if more == 1 then "One more fish grew too." else string.format("%d more fish grew too.", more))
	end
	local counts: { [string]: number } = {}
	local order: { string } = {}
	for _, name in born do
		if not counts[name] then
			table.insert(order, name)
		end
		counts[name] = (counts[name] or 0) + 1
	end
	for _, name in order do
		local n = counts[name]
		table.insert(lines, if n == 1 then string.format("A baby %s was born!", name) else string.format("%d baby %s were born!", n, name))
	end
	if #lines == 0 then
		return nil
	end
	return {
		title = "While You Were Away",
		lines = lines,
		hint = if #born > 0 then "Go see the babies at your pond, just past the bait shop." else "Go see them at your pond, just past the bait shop.",
	}
end

return Daily
