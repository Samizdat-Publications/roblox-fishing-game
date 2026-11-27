--!strict
-- The "nothing wants this" hint (L2b): when nothing here wants your bait right now, name a
-- better choice instead of generic advice, so a kid doesn't read the quiet as a broken timer.
-- "Nothing wants worms at the deep hole right now. Try minnows here, or worms at the dock."
-- Pure rules, no Roblox services. UNVERIFIED in Studio (written 2026-11-26).
local Shared = script.Parent
local Config = require(Shared.Config)
local BaitData = require(Shared.BaitData)
local FishLogic = require(Shared.FishLogic)
local Weather = require(Shared.Weather)

local Advice = {}

Advice.LAKE_SPOTS = { "Dock", "WeedBed", "Logs", "DeepHole" }
Advice.CREEK_SPOTS = { "Riffle", "Rocks", "Pool" }

-- How much the fish at this spot want this bait now (0 when nothing does).
function Advice.total(spot: string, period: string, baitId: string, now: Weather.Now?): number
	local t = 0
	for _, x in FishLogic.biteWeights(spot, period, baitId, now) do
		t += x.w
	end
	return t
end

-- Spots this player can fish: the lake always, the creek with the Creek Pass, the Big Lake's
-- dinghy water with any boat (when boats are on) and the blue water with the Deep-V.
function Advice.reachableSpots(creekPass: boolean, boats: { [string]: boolean }?): { string }
	local out = table.clone(Advice.LAKE_SPOTS)
	if creekPass then
		for _, s in Advice.CREEK_SPOTS do
			table.insert(out, s)
		end
	end
	if Config.boatsOn() and boats and next(boats) ~= nil then
		table.insert(out, "Basin")
		table.insert(out, "IslandPoint")
		if boats.DeepV then
			table.insert(out, "DropOff")
		end
	end
	return out
end

-- The owned bait (not `except`) the fish here want most now, or nil.
function Advice.bestBait(spot: string, period: string, owned: { string }, except: string, now: Weather.Now?): string?
	local best: string?, bestT = nil, 0
	for _, id in owned do
		if id ~= except then
			local t = Advice.total(spot, period, id, now)
			if t > bestT then
				best, bestT = id, t
			end
		end
	end
	return best
end

-- The reachable spot (not `except`) where fish want this bait most now, or nil.
function Advice.bestSpot(baitId: string, period: string, spots: { string }, except: string, now: Weather.Now?): string?
	local best: string?, bestT = nil, 0
	for _, s in spots do
		if s ~= except then
			local t = Advice.total(s, period, baitId, now)
			if t > bestT then
				best, bestT = s, t
			end
		end
	end
	return best
end

-- "worms", "minnows", "a spinner".
function Advice.baitWords(id: string): string
	local b = BaitData.byId[id]
	if not b then
		return "that"
	end
	if b.kind == "lure" then
		return "a " .. b.name:lower()
	end
	return b.name:lower()
end

local function at(spot: string): string
	local name = FishLogic.SPOT_NAMES[spot] or "here"
	if spot == "OpenWater" then
		return "in " .. name
	end
	return "at " .. name
end

-- The hint. owned: bait ids the player has now (Inventory.usable); spots: reachableSpots.
function Advice.nothingText(spot: string, period: string, baitId: string, owned: { string }, spots: { string }, now: Weather.Now?): string
	local head = string.format("Nothing wants %s %s right now.", Advice.baitWords(baitId), at(spot))
	local bait = Advice.bestBait(spot, period, owned, baitId, now)
	local where = Advice.bestSpot(baitId, period, spots, spot, now)
	if bait and where then
		return string.format("%s Try %s here, or %s %s.", head, Advice.baitWords(bait), Advice.baitWords(baitId), at(where))
	elseif bait then
		return string.format("%s Try %s here.", head, Advice.baitWords(bait))
	elseif where then
		return string.format("%s Try %s %s.", head, Advice.baitWords(baitId), at(where))
	end
	return head .. " Try again at another time of day."
end

return Advice
