--!strict
-- Pure fishing rules: what bites where and when, how long it takes, how big and how much.
local Shared = script.Parent
local Config = require(Shared.Config)
local FishData = require(Shared.FishData)

local FishLogic = {}

FishLogic.SPOT_NAMES = {
	Dock = "the dock",
	WeedBed = "the weed bed",
	Logs = "the fallen logs",
	DeepHole = "the deep hole",
	OpenWater = "open water",
}

export type Weight = { id: string, w: number }
export type Zone = { name: string, cframe: CFrame, size: Vector3 }

function FishLogic.periodFromClock(clock: number): string
	local c = clock % 24
	if c >= 5 and c < 8 then
		return "Dawn"
	elseif c >= 8 and c < 17 then
		return "Day"
	elseif c >= 17 and c < 20 then
		return "Dusk"
	end
	return "Night"
end

-- Candidates for a bite, heaviest weight first. Empty when nothing here wants this bait now.
function FishLogic.biteWeights(spot: string, period: string, baitId: string): { Weight }
	local out: { Weight } = {}
	for _, s in FishData.list do
		local w = s.rarity * (s.spots[spot] or 0) * (s.periods[period] or 0) * (s.baits[baitId] or 0)
		if w > 0 then
			table.insert(out, { id = s.id, w = w })
		end
	end
	table.sort(out, function(a, b)
		return a.w > b.w
	end)
	return out
end

local function total(weights: { Weight }): number
	local t = 0
	for _, x in weights do
		t += x.w
	end
	return t
end

function FishLogic.pickSpecies(weights: { Weight }, rng: Random): string?
	local t = total(weights)
	if t <= 0 then
		return nil
	end
	local r = rng:NextNumber() * t
	for _, x in weights do
		r -= x.w
		if r <= 0 then
			return x.id
		end
	end
	return weights[#weights].id
end

-- Seconds until a bite. A strong match (total weight near 1) bites fast, a weak one slow.
function FishLogic.biteDelay(weights: { Weight }, rng: Random): number?
	local t = total(weights)
	if t <= 0 then
		return nil
	end
	local quality = math.clamp(t, 0, 1)
	local base = Config.BITE_MAX - (Config.BITE_MAX - Config.BITE_MIN) * quality
	return base * (0.75 + rng:NextNumber() * 0.5)
end

function FishLogic.rollSize(species: FishData.Species, rng: Random): (number, number)
	-- Average of two draws: most fish are mid-sized, trophies are rare.
	local u = (rng:NextNumber() + rng:NextNumber()) / 2
	if rng:NextNumber() < 0.05 then
		u = 0.85 + rng:NextNumber() * 0.15 -- the occasional big one
	end
	local cm = species.minCm + (species.maxCm - species.minCm) * u
	cm = math.floor(cm * 10 + 0.5) / 10
	local kg = species.weightCoef * cm * cm * cm
	kg = math.floor(kg * 100 + 0.5) / 100
	if kg < 0.01 then
		kg = 0.01
	end
	return cm, kg
end

function FishLogic.priceFor(species: FishData.Species, kg: number): number
	local mid = (species.minCm + species.maxCm) / 2
	local avgKg = species.weightCoef * mid * mid * mid
	local p = species.basePrice * (kg / avgKg) ^ 0.8
	return math.max(1, math.floor(p + 0.5))
end

local function inBox(pos: Vector3, cf: CFrame, size: Vector3): boolean
	local p = cf:PointToObjectSpace(pos)
	return math.abs(p.X) <= size.X / 2 and math.abs(p.Z) <= size.Z / 2
end

function FishLogic.spotAt(pos: Vector3, zones: { Zone }): string
	for _, z in zones do
		if inBox(pos, z.cframe, z.size) then
			return z.name
		end
	end
	return "OpenWater"
end

function FishLogic.isOnWater(pos: Vector3, waterCFrame: CFrame, waterSize: Vector3): boolean
	return inBox(pos, waterCFrame, waterSize)
end

return FishLogic
