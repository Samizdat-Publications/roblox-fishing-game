--!strict
-- Pure fishing rules: what bites where and when, how long it takes, how big and how much.
local Shared = script.Parent
local Config = require(Shared.Config)
local FishData = require(Shared.FishData)
local Rarity = require(Shared.Rarity)

local FishLogic = {}

FishLogic.SPOT_NAMES = {
	Dock = "the dock",
	WeedBed = "the weed bed",
	Logs = "the fallen logs",
	DeepHole = "the deep hole",
	OpenWater = "open water",
	Riffle = "the riffle",
	Rocks = "the creek rocks",
	Pool = "the deep pool",
	Basin = "the open basin", -- the Big Lake (boat plan Task 5)
	IslandPoint = "the island point",
	DropOff = "the blue-water drop-off",
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
	-- Combos so weak they'd take longer than BITE_SLOWEST count as "nothing wants this".
	local t = 0
	for _, x in out do
		t += x.w
	end
	if t < Config.BITE_MIN / Config.BITE_SLOWEST then
		return {}
	end
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

-- Seconds until a bite: BITE_MIN divided by how much the fish here want this (the total
-- weight), from BITE_MIN to BITE_SLOWEST. So a rare fish that is the only taker is slow to
-- bite, and the right time and bait matter for every fish, not just which one you get.
function FishLogic.biteDelay(weights: { Weight }, rng: Random): number?
	local t = total(weights)
	if t <= 0 then
		return nil
	end
	local base = math.clamp(Config.BITE_MIN / t, Config.BITE_MIN, Config.BITE_SLOWEST)
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

-- One catch: its size class first ("normal", "trophy" or "monster"), then its length and
-- weight. Server only (the rng must be the server's). A Monster can be longer than maxCm.
-- UNVERIFIED in Studio (added 2026-11-26, rarity plan Task 1).
function FishLogic.rollCatch(species: FishData.Species, rng: Random): (number, number, string)
	local roll = rng:NextNumber()
	local range = nil
	local class = "normal"
	if roll < Rarity.MONSTER_CHANCE then
		class, range = "monster", Rarity.MONSTER_LENGTH
	elseif roll < Rarity.MONSTER_CHANCE + Rarity.TROPHY_CHANCE then
		class, range = "trophy", Rarity.TROPHY_LENGTH
	end
	if not range then
		local cm, kg = FishLogic.rollSize(species, rng)
		return cm, kg, class
	end
	local cm = species.maxCm * (range[1] + (range[2] - range[1]) * rng:NextNumber())
	cm = math.floor(cm * 10 + 0.5) / 10
	local kg = species.weightCoef * cm * cm * cm
	kg = math.max(0.01, math.floor(kg * 100 + 0.5) / 100)
	return cm, kg, class
end

-- The fight for a catch of this size class: big ones gain slower and pull harder.
function FishLogic.fightFor(profile: FishData.FightProfile, sizeClass: string): FishData.FightProfile
	local adj = Rarity.FIGHT[sizeClass] or Rarity.FIGHT.normal
	local p = table.clone(profile)
	p.gain = profile.gain * adj.gain
	p.heavy = math.min(Rarity.HEAVY_CAP, profile.heavy + adj.heavy)
	return p
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

-- True when the point is over any of the water boxes (the lake and the creek's stretches).
function FishLogic.isOnWaterAny(pos: Vector3, boxes: { { cframe: CFrame, size: Vector3 } }): boolean
	for _, b in boxes do
		if inBox(pos, b.cframe, b.size) then
			return true
		end
	end
	return false
end

-- How a fish takes the bait, so the bobber tells you what's down there before you see it.
-- predips: small dips before the real bite; depth: how far the bobber goes under (studs);
-- hookWindow: seconds to press after the real bite (never under Config.HOOK_WINDOW - 0.2,
-- so younger players still make it). FishingService plays it at every bite (verified in a
-- Studio playtest 2026-11-26).
export type BitePattern = { style: string, predips: number, dipGap: number, depth: number, hookWindow: number }

local BITE_PATTERNS: { [string]: BitePattern } = {
	nibble = { style = "nibble", predips = 2, dipGap = 0.45, depth = 0.35, hookWindow = Config.HOOK_WINDOW },
	tap = { style = "tap", predips = 0, dipGap = 0, depth = 0.3, hookWindow = Config.HOOK_WINDOW - 0.2 },
	slam = { style = "slam", predips = 0, dipGap = 0, depth = 1.0, hookWindow = Config.HOOK_WINDOW },
	pull = { style = "pull", predips = 0, dipGap = 0, depth = 0.8, hookWindow = Config.HOOK_WINDOW + 0.6 },
}

function FishLogic.bitePattern(species: FishData.Species): BitePattern
	return BITE_PATTERNS[species.bite or "slam"] or BITE_PATTERNS.slam
end

-- Spots that need the Creek Pass.
FishLogic.CREEK_SPOTS = { Riffle = true, Rocks = true, Pool = true }

return FishLogic
