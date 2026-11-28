--!strict
-- Playing together (leg 3, N4): the money on a shared catch, the Double Hookup, the buddy
-- tackle loan and the creek buddy, and chum from the second seat. Pure rules; FishingService
-- and BoatService apply them. Each has its Config switch (Config.luau, "The fleet").
local Shared = script.Parent
local RodData = require(Shared.RodData)
local Teamwork = require(Shared.Teamwork)

local Coop = {}

-- Shared catches (Config.ASSIST_BONUS_ON). The even split is gone: once a boat works with one
-- player, a split makes two players worse off than one. The angler keeps the full price; each
-- helper gets an assist in their journal and 10 percent of the price on top.
Coop.ASSIST_SHARE = 0.10

function Coop.assistBonus(price: number): number
	if type(price) ~= "number" or price <= 0 then
		return 0
	end
	return math.max(1, math.floor(price * Coop.ASSIST_SHARE + 0.5))
end

-- What a shared catch pays: the angler's coins and each helper's coins. assistOn picks the new
-- rule; off, a Deep-V team catch is split evenly (Teamwork.split) as in L7.
function Coop.shareCatch(price: number, helpers: number, assistOn: boolean): (number, { number })
	helpers = math.max(0, math.floor(helpers))
	if assistOn then
		return price, table.create(helpers, Coop.assistBonus(price))
	end
	local shares = Teamwork.split(price, 1 + helpers)
	local out = {}
	for i = 2, #shares do
		table.insert(out, shares[i])
	end
	return shares[1], out
end

-- Double Hookup (Config.DOUBLE_HOOKUP_ON): two players within 15 studs fighting at once. If
-- both land their fish, each gets 10 percent of their own fish's price on top and a Double
-- Haul stamp in the journal.
Coop.DOUBLE_RANGE = 15
Coop.DOUBLE_BONUS = 0.10 -- 25 percent (Gemini) broke the leg budget in the sim: 11/28/2026

export type Pair = { a: any, b: any, result: { [any]: string }, price: { [any]: number } }

function Coop.newPair(a: any, b: any): Pair
	return { a = a, b = b, result = {}, price = {} }
end

function Coop.doubleBonus(price: number): number
	if type(price) ~= "number" or price <= 0 then
		return 0
	end
	return math.max(1, math.floor(price * Coop.DOUBLE_BONUS + 0.5))
end

-- One side's fight ended ("won" with the fish's price, or anything else). Returns nil while the
-- other is still fighting; once both are done, a table of bonus coins by player (empty unless
-- both won).
function Coop.pairResult(pair: Pair, who: any, outcome: string, price: number?): { [any]: number }?
	if who ~= pair.a and who ~= pair.b then
		return nil
	end
	if pair.result[who] then
		return nil -- already counted
	end
	pair.result[who] = outcome
	pair.price[who] = price or 0
	if not (pair.result[pair.a] and pair.result[pair.b]) then
		return nil
	end
	if pair.result[pair.a] == "won" and pair.result[pair.b] == "won" then
		return {
			[pair.a] = Coop.doubleBonus(pair.price[pair.a]),
			[pair.b] = Coop.doubleBonus(pair.price[pair.b]),
		}
	end
	return {}
end

-- Buddy tackle loan (Config.BUDDY_LOAN_ON): a passenger on someone else's boat fishes with the
-- owner's rod and braided line for the trip, when those beat their own (never worse). Nothing
-- changes hands: it's only the line rating and the rod's reach and feel while aboard.
function Coop.loanTackle(ownRod: string, ownBraid: boolean, ownerRod: string?, ownerBraid: boolean?): (string, boolean)
	local rod, braid = ownRod, ownBraid
	if ownerRod and RodData.byId[ownerRod] then
		local mine = RodData.lineLbFor(ownRod, ownBraid)
		local theirs = RodData.lineLbFor(ownerRod, ownerBraid == true)
		if theirs > mine then
			rod, braid = ownerRod, ownerBraid == true
		end
	end
	return rod, braid
end

-- The creek buddy: within this many studs of a Creek Pass holder, the gate lets you through
-- and you may fish the creek.
Coop.CREEK_BUDDY_RANGE = 20

function Coop.creekBuddy(myPos: Vector3, holderPositions: { Vector3 }): boolean
	for _, p in holderPositions do
		if Vector3.new(myPos.X - p.X, 0, myPos.Z - p.Z).Magnitude <= Coop.CREEK_BUDDY_RANGE then
			return true
		end
	end
	return false
end

-- Bow chumming (Config.CHUM_ON): the second seat tosses chum, a 25 second boil ahead of the bow
-- that cuts bite waits by a quarter for everyone aboard, then 90 seconds before the next.
Coop.CHUM_COOLDOWN = 90
Coop.CHUM_LASTS = 25
Coop.CHUM_BITE = 0.75
Coop.CHUM_AHEAD = 8 -- studs past the bow where the boil is

function Coop.chumReady(lastAt: number?, now: number): boolean
	return lastAt == nil or now - lastAt >= Coop.CHUM_COOLDOWN
end

function Coop.chumActive(lastAt: number?, now: number): boolean
	return lastAt ~= nil and now - lastAt >= 0 and now - lastAt < Coop.CHUM_LASTS
end

-- Seconds until the next toss (0 when ready).
function Coop.chumWait(lastAt: number?, now: number): number
	if lastAt == nil then
		return 0
	end
	return math.max(0, Coop.CHUM_COOLDOWN - (now - lastAt))
end

return Coop
