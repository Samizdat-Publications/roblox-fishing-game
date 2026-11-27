--!strict
-- Pure player-data rules: coins, bait, the fish bag and the journal. The server owns the
-- data table and calls these; nothing here touches Roblox services.
local Shared = script.Parent
local Config = require(Shared.Config)
local BaitData = require(Shared.BaitData)
local RodData = require(Shared.RodData)
local BaitRig = require(Shared.BaitRig)

export type Fish = {
	id: string,
	name: string,
	cm: number,
	kg: number,
	price: number,
	bait: string,
	spot: string,
	period: string,
	at: number,
	sizeClass: string?, -- "trophy" or "monster"; nil for a normal catch (see Rarity.sizeClassOf)
}

export type Data = {
	v: number,
	coins: number,
	bait: { [string]: number },
	lures: { [string]: boolean },
	equipped: string,
	bag: { Fish },
	journal: {
		entries: { Fish },
		bests: { [string]: Fish },
		counts: { [string]: number },
	},
	assist: boolean,
	totalCaught: number,
	pond: any,
	rods: { [string]: boolean },
	rod: string,
	creekPass: boolean,
	boats: { [string]: boolean }, -- v5: boats owned (BoatLogic.buy fills this in)
	boat: string, -- v5: the boat waiting at your slip ("" for none yet)
	goals: any, -- v6: today's daily goals (Goals.State); filled in by GoalService
	hook: string, -- v7: the hook size tied on for live bait (BaitRig.HOOKS)
	quickBait: boolean, -- v7: skip the bait bench (always Okay)
	tackle: { best: { [string]: string }, perfects: number }, -- v7: Tackle Box, best grade per bait
	assistSet: boolean, -- v8: the player turned reel assist on or off by hand (it then never changes by itself)
}

local Inventory = {}

function Inventory.new(): Data
	return {
		v = 8,
		coins = Config.START_COINS,
		bait = { Worm = Config.START_WORMS },
		lures = {},
		equipped = "Worm",
		bag = {},
		journal = { entries = {}, bests = {}, counts = {} },
		assist = true,
		totalCaught = 0,
		pond = { fish = {}, lastTick = 0, capacity = Config.POND_CAPACITY, breedTimer = 0 },
		rods = { Willow = true },
		rod = "Willow",
		creekPass = false,
		boats = {},
		boat = "",
		goals = {},
		hook = BaitRig.DEFAULT_HOOK,
		quickBait = false,
		tackle = { best = {}, perfects = 0 },
		assistSet = false,
	}
end

-- Fill in anything missing from an older or partial save.
function Inventory.reconcile(saved: any): Data
	local fresh = Inventory.new()
	if type(saved) ~= "table" then
		return fresh
	end
	for k, v in fresh :: any do
		if saved[k] == nil then
			saved[k] = v
		end
	end
	for k, v in fresh.journal :: any do
		if saved.journal[k] == nil then
			saved.journal[k] = v
		end
	end
	-- v2: reel assist back on for everyone (early test saves had it switched off).
	if (saved.v or 1) < 2 then
		saved.assist = true
		saved.v = 2
	end
	-- v3: the home pond (the empty pond itself is filled in from the fresh data above).
	if saved.v < 3 then
		saved.v = 3
	end
	-- v4: rods and the Creek Pass (filled in from the fresh data above).
	if saved.v < 4 then
		saved.v = 4
	end
	-- v5: boats (filled in from the fresh data above). UNVERIFIED in Studio (2026-11-26).
	if saved.v < 5 then
		saved.v = 5
	end
	-- v6: daily goals (an empty table; GoalService fills in today's). UNVERIFIED in Studio.
	if saved.v < 6 then
		saved.v = 6
	end
	-- v7: hook size, Quick Bait and the Tackle Box (L3). UNVERIFIED in Studio.
	if type(saved.tackle) ~= "table" then
		saved.tackle = { best = {}, perfects = 0 }
	end
	if type(saved.tackle.best) ~= "table" then
		saved.tackle.best = {}
	end
	if type(saved.tackle.perfects) ~= "number" then
		saved.tackle.perfects = 0
	end
	if not BaitRig.isHook(saved.hook) then
		saved.hook = BaitRig.DEFAULT_HOOK
	end
	if saved.v < 7 then
		saved.v = 7
	end
	-- v8: reel assist turns itself off after the first catches (L4b), unless set by hand. A
	-- save with assist off got there by hand (v2 put it back on for everyone), so it counts as
	-- set; a save with it on may be the default, so the auto-off still applies to it.
	if saved.v < 8 then
		saved.assistSet = saved.assist == false
		saved.v = 8
	end
	if type(saved.assistSet) ~= "boolean" then
		saved.assistSet = false
	end
	return saved
end

-- The player flipped the reel assist toggle: their choice sticks from now on.
function Inventory.setAssist(data: Data, on: boolean)
	data.assist = on
	data.assistSet = true
end

-- After a catch is recorded: reel assist turns itself off once the player has landed
-- Config.ASSIST_CATCHES fish, if they never set it by hand. Returns true the one time it
-- turns off (the server tells the player then).
function Inventory.assistAfterCatch(data: Data): boolean
	if data.assist and not data.assistSet and data.totalCaught >= Config.ASSIST_CATCHES then
		data.assist = false
		return true
	end
	return false
end

function Inventory.hasBait(data: Data, id: string): boolean
	local b = BaitData.byId[id]
	if not b then
		return false
	end
	if b.kind == "lure" then
		return data.lures[id] == true
	end
	return (data.bait[id] or 0) > 0
end

function Inventory.buy(data: Data, id: string): (boolean, string)
	local b = BaitData.byId[id]
	if not b then
		return false, "That isn't for sale."
	end
	if b.kind == "lure" and data.lures[id] then
		return false, "You already own a " .. b.name .. "."
	end
	if data.coins < b.price then
		return false, "Not enough coins. You need " .. b.price .. "."
	end
	data.coins -= b.price
	if b.kind == "lure" then
		data.lures[id] = true
		return true, "Bought a " .. b.name .. ". It's yours to keep."
	end
	data.bait[id] = (data.bait[id] or 0) + b.pack
	return true, "Bought " .. b.pack .. " " .. b.name .. "."
end

function Inventory.buyRod(data: Data, id: string): (boolean, string)
	local r = RodData.byId[id]
	if not r or r.price <= 0 then
		return false, "That rod isn't for sale."
	end
	if data.rods[id] then
		return false, "You already own the " .. r.name .. "."
	end
	if data.coins < r.price then
		return false, "Not enough coins. You need " .. r.price .. "."
	end
	data.coins -= r.price
	data.rods[id] = true
	data.rod = id
	return true, "Bought the " .. r.name .. ". It's in your hands."
end

function Inventory.equipRod(data: Data, id: string): boolean
	if data.rods[id] and RodData.byId[id] then
		data.rod = id
		return true
	end
	return false
end

-- Called when a fish takes the bait. Lures are never used up.
function Inventory.consumeBait(data: Data, id: string)
	local b = BaitData.byId[id]
	if b and b.kind == "live" and (data.bait[id] or 0) > 0 then
		data.bait[id] -= 1
	end
end

function Inventory.equip(data: Data, id: string): boolean
	if Inventory.hasBait(data, id) then
		data.equipped = id
		return true
	end
	return false
end

-- Ids of bait the player can use right now, in shop order.
function Inventory.usable(data: Data): { string }
	local out = {}
	for _, b in BaitData.list do
		if Inventory.hasBait(data, b.id) then
			table.insert(out, b.id)
		end
	end
	return out
end

function Inventory.sellAll(data: Data): (number, number)
	local coins, count = 0, 0
	for _, f in data.bag do
		coins += f.price
		count += 1
	end
	data.bag = {}
	data.coins += coins
	return coins, count
end

function Inventory.bagFull(data: Data): boolean
	return #data.bag >= Config.BAG_LIMIT
end

-- Adds a catch to the bag and journal. Returns true for a new personal best (by weight).
function Inventory.recordCatch(data: Data, fish: Fish): boolean
	table.insert(data.bag, fish)
	local j = data.journal
	table.insert(j.entries, fish)
	while #j.entries > Config.JOURNAL_KEEP do
		table.remove(j.entries, 1)
	end
	j.counts[fish.id] = (j.counts[fish.id] or 0) + 1
	-- Trophies and monsters per species, for the journal (UNVERIFIED in Studio, 2026-11-26).
	if fish.sizeClass == "trophy" or fish.sizeClass == "monster" then
		local key = if fish.sizeClass == "monster" then "monsters" else "trophies"
		local t = (j :: any)[key] or {}
		t[fish.id] = (t[fish.id] or 0) + 1;
		(j :: any)[key] = t
	end
	data.totalCaught += 1
	local best = j.bests[fish.id]
	if not best or fish.kg > best.kg then
		j.bests[fish.id] = fish
		return true
	end
	return false
end

-- Nobody gets stuck: no bait, no lure and too poor to buy a pack means free worms.
function Inventory.freeWormsIfStuck(data: Data): boolean
	if #Inventory.usable(data) > 0 then
		return false
	end
	local cheapest = math.huge
	for _, b in BaitData.list do
		cheapest = math.min(cheapest, b.price)
	end
	if data.coins >= cheapest then
		return false
	end
	data.bait.Worm = (data.bait.Worm or 0) + Config.FREE_WORMS
	data.equipped = "Worm"
	return true
end

-- What the client is allowed to see.
function Inventory.snapshot(data: Data): any
	return {
		coins = data.coins,
		bait = table.clone(data.bait),
		lures = table.clone(data.lures),
		equipped = data.equipped,
		bagCount = #data.bag,
		bagValue = (function()
			local t = 0
			for _, f in data.bag do
				t += f.price
			end
			return t
		end)(),
		bests = data.journal.bests,
		counts = data.journal.counts,
		trophies = (data.journal :: any).trophies or {},
		monsters = (data.journal :: any).monsters or {},
		recent = { table.unpack(data.journal.entries, math.max(1, #data.journal.entries - 9)) },
		assist = data.assist,
		hook = data.hook,
		quickBait = data.quickBait,
		tackle = { best = table.clone(data.tackle.best), perfects = data.tackle.perfects },
		totalCaught = data.totalCaught,
		pond = { fish = data.pond.fish, capacity = data.pond.capacity },
		rods = table.clone(data.rods),
		rod = data.rod,
		creekPass = data.creekPass,
		boats = table.clone(data.boats),
		boat = data.boat,
		goals = (function()
			local out = {}
			local list = type(data.goals) == "table" and data.goals.list or {}
			for i, g in list do
				out[i] = { text = g.text, progress = g.progress, target = g.target, reward = g.reward, done = g.done }
			end
			return out
		end)(),
		bag = (function()
			local out = {}
			for i, f in data.bag do
				out[i] = { id = f.id, name = f.name, cm = f.cm, kg = f.kg, price = f.price }
			end
			return out
		end)(),
	}
end

return Inventory
