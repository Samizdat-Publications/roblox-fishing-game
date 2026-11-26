--!strict
-- Journal rumours: a fish you haven't caught yet still has a card with its tier and, once
-- you've caught enough fish overall, a rumour about where and when to find it. Rarer fish
-- need more catches before anyone talks about them. Mythics' rumours name their weather.
-- Pure logic. UNVERIFIED in Studio: written 2026-11-26 in the cloud.
local Shared = script.Parent
local FishLogic = require(Shared.FishLogic)
local Rarity = require(Shared.Rarity)
local Weather = require(Shared.Weather)
local BaitData = require(Shared.BaitData)
local Config = require(Shared.Config)

local Journal = {}

-- Catches needed (all species together) before a rumour about a tier is heard.
Journal.RUMOUR_AFTER = { Common = 0, Uncommon = 5, Rare = 15, Epic = 30, Legendary = 60, Mythic = 100, Godlike = 250 }

-- After this many more catches past a tier's first rumour, the old-timers also name a bait.
Journal.BAIT_TIP_AFTER = 10

local PERIOD_TEXT = { Dawn = "at dawn", Day = "by day", Dusk = "at dusk", Night = "at night" }
local WEATHER_TEXT = { Storm = "in a thunderstorm", Fog = "on a foggy morning", PreStorm = "just before a storm", Overcast = "on a cloudy day", Wind = "on a windy day", ColdFront = "after a cold front" }

local function best(t: { [string]: number }): string?
	local key, bw = nil, 0
	for k, w in t do
		if w > bw or (w == bw and key and k < key) then
			key, bw = k, w
		end
	end
	return key
end

-- The rumour for a species you haven't caught, or nil if nobody's talking yet.
function Journal.rumour(species: any, totalCaught: number): string?
	local tier = Rarity.of(species)
	if totalCaught < (Journal.RUMOUR_AFTER[tier] or 0) then
		return nil
	end
	local spot = best(species.spots)
	local period = best(species.periods)
	local where = FishLogic.SPOT_NAMES[spot or ""] or "somewhere out there"
	local text = string.format("Rumour: something bites at %s %s", where, PERIOD_TEXT[period or ""] or "")
	if species.weather then
		local w = best(species.weather)
		text ..= ", but only " .. (WEATHER_TEXT[w or ""] or "in strange weather")
	end
	text ..= "."
	-- Keep fishing and the rumour gets sharper: which bait it takes.
	if totalCaught >= (Journal.RUMOUR_AFTER[tier] or 0) + Journal.BAIT_TIP_AFTER then
		local bait = BaitData.byId[best(species.baits) or ""]
		if bait then
			text ..= string.format(" Old-timers swear by %s.", string.lower(bait.name))
		end
	end
	return text
end

-- Big Lake water, reached only by boat.
Journal.BOAT_SPOTS = { Basin = true, IslandPoint = true, DropOff = true }

-- Whether the journal shows this species: always once caught, otherwise only when the
-- player's world has its water (Big Lake fish stay hidden while boats are switched off,
-- so no rumour sends a kid looking for a lake that isn't there).
function Journal.listed(species: any, caught: boolean?): boolean
	if caught or Config.boatsOn() then
		return true
	end
	for spot, w in species.spots do
		if w > 0 and not Journal.BOAT_SPOTS[spot] then
			return true
		end
	end
	return false
end

-- How many more catches until the next rumour is heard (0 when every rumour is out).
function Journal.nextRumourIn(totalCaught: number): number
	local nextAt = math.huge
	for _, n in Journal.RUMOUR_AFTER do
		if n > totalCaught then
			nextAt = math.min(nextAt, n)
		end
	end
	return if nextAt == math.huge then 0 else nextAt - totalCaught
end

local _ = Weather -- weather ids above match Weather.luau's kinds
return Journal
