--!strict
-- Home pond rules: live fish kept from the bag grow toward full size and breed over real
-- time. Offline time counts, capped, so a week away is worth the same as a night away.
local Shared = script.Parent
local Config = require(Shared.Config)
local FishData = require(Shared.FishData)
local FishLogic = require(Shared.FishLogic)
local Rarity = require(Shared.Rarity)
local Units = require(Shared.Units)

export type PondFish = {
	id: string,
	name: string,
	cm: number,
	kg: number,
	price: number,
	bornHere: boolean,
}

export type Pond = {
	fish: { PondFish },
	lastTick: number,
	capacity: number,
	breedTimer: number?,
}

local PondLogic = {}

-- Grow one fish by `hours` of pond time and refresh its weight and price.
function PondLogic.grow(f: PondFish, species: FishData.Species, hours: number)
	if hours > 0 and f.cm < species.maxCm then
		local gap = species.maxCm - f.cm
		f.cm = species.maxCm - gap * math.exp(-Config.POND_GROW_RATE * hours)
	end
	-- A trophy or monster can already be past maxCm: it never shrinks back down.
	f.cm = math.min(math.floor(f.cm * 10 + 0.5) / 10, math.max(species.maxCm, f.cm))
	local kg = species.weightCoef * f.cm * f.cm * f.cm
	f.kg = math.max(0.01, math.floor(kg * 100 + 0.5) / 100)
	f.price = FishLogic.priceFor(species, f.kg)
end

local function isGrown(f: PondFish, s: FishData.Species): boolean
	return f.cm >= s.minCm + 0.6 * (s.maxCm - s.minCm)
end

local function rollBreeding(pond: Pond, rng: Random, born: { string })
	local grown: { [string]: number } = {}
	for _, f in pond.fish do
		local s = FishData.byId[f.id]
		if s and isGrown(f, s) then
			grown[f.id] = (grown[f.id] or 0) + 1
		end
	end
	for _, s in FishData.list do -- fixed order keeps results repeatable for a seed
		-- Legendary fish and rarer never breed in a home pond: they stay a story, not a farm.
		local breeds = (Rarity.rank[Rarity.of(s)] or 1) < (Rarity.rank.Legendary :: number)
		if breeds and (grown[s.id] or 0) >= 2 and #pond.fish < pond.capacity and rng:NextNumber() < Config.POND_BREED_CHANCE then
			local young: PondFish = { id = s.id, name = s.name, cm = s.minCm, kg = 0, price = 0, bornHere = true }
			PondLogic.grow(young, s, 0)
			table.insert(pond.fish, young)
			table.insert(born, s.name)
		end
	end
end

-- Advance the pond by `seconds` (clamped to 0 .. the offline cap). Returns names of fish born.
function PondLogic.tick(pond: Pond, seconds: number, rng: Random): { string }
	local born: { string } = {}
	local remaining = math.clamp(seconds, 0, Config.POND_OFFLINE_CAP)
	pond.breedTimer = pond.breedTimer or 0
	while remaining > 0 do
		local step = math.min(remaining, Config.POND_BREED_EVERY - (pond.breedTimer :: number))
		for _, f in pond.fish do
			local s = FishData.byId[f.id]
			if s then
				PondLogic.grow(f, s, step / 3600)
			end
		end
		pond.breedTimer = (pond.breedTimer :: number) + step
		remaining -= step
		if (pond.breedTimer :: number) >= Config.POND_BREED_EVERY then
			pond.breedTimer = 0
			rollBreeding(pond, rng, born)
		end
	end
	return born
end

local function validIndex(list: { any }, i: any): boolean
	return type(i) == "number" and i == math.floor(i) and i >= 1 and i <= #list
end

-- Move a fish from the bag into the pond.
function PondLogic.keep(data: any, bagIndex: any): (boolean, string)
	if not validIndex(data.bag, bagIndex) then
		return false, "That fish isn't in your bag any more."
	end
	local pond: Pond = data.pond
	if #pond.fish >= pond.capacity then
		return false, string.format("Your pond is full (%d fish). Sell or release one first.", pond.capacity)
	end
	local catch = table.remove(data.bag, bagIndex)
	local s = FishData.byId[catch.id]
	local f: PondFish = { id = catch.id, name = catch.name, cm = catch.cm, kg = catch.kg, price = catch.price, bornHere = false }
	if s then
		f.name = s.name
		PondLogic.grow(f, s, 0)
	end
	table.insert(pond.fish, f)
	return true, "Your " .. f.name .. " is swimming in your pond."
end

-- Sell one pond fish at its current size.
function PondLogic.sell(data: any, pondIndex: any): (boolean, string, number)
	local pond: Pond = data.pond
	if not validIndex(pond.fish, pondIndex) then
		return false, "That fish isn't in your pond any more.", 0
	end
	local f = table.remove(pond.fish, pondIndex) :: PondFish
	data.coins += f.price
	return true, string.format("Sold your %s (%s) for %d coins.", f.name, Units.length(f.cm), f.price), f.price
end

-- Let a pond fish go.
function PondLogic.release(data: any, pondIndex: any): (boolean, string)
	local pond: Pond = data.pond
	if not validIndex(pond.fish, pondIndex) then
		return false, "That fish isn't in your pond any more."
	end
	local f = table.remove(pond.fish, pondIndex) :: PondFish
	return true, "You let the " .. f.name .. " go. It swims off into the lake."
end

return PondLogic
