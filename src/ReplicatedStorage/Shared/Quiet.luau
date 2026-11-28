--!strict
-- Quiet approach (leg 3, N4, Config.QUIET_APPROACH_ON). Arrive at a spot under paddle, or with
-- the motor at idle for the last 25 studs, and wary fish are 1.25 times as likely to bite for
-- the first minute you fish there. Arriving under power is simply normal: no penalty anywhere.
--
-- "Motor off" counts a motor at a quarter throttle or less: a dinghy cut to nothing coasts only
-- about 6 studs (BoatLogic.step's easing), so a true drift could never cover 25. Logged as an
-- assumption in docs/DECISIONS.md (11/27/2026).
--
-- Wary fish: trout, muskie, pike and sturgeon, and anything Rare or better marked `wary`.
-- Pure: the server keeps one State per boat and steps it with the boat (BoatService).
local Shared = script.Parent
local BoatData = require(Shared.BoatData)
local Rarity = require(Shared.Rarity)

local Quiet = {}

Quiet.DISTANCE = 25 -- studs of quiet travel that make an arrival quiet
Quiet.WINDOW = 60 -- seconds the arrival's bonus lasts
Quiet.WARY_MULT = 1.25
Quiet.IDLE_THROTTLE = 0.25 -- a motor at this throttle or less counts as off
Quiet.SPOT_RADIUS = 20 -- move farther than this from where you stopped and it's a new approach
Quiet.MIN_TRIP = 25 -- a stop after less travel than this is a nudge, not an arrival

local WARY_IDS: { [string]: boolean } = {
	NorthernPike = true,
	Muskellunge = true,
	TigerMuskie = true,
	LakeSturgeon = true,
}

local TIER_RANK: { [string]: number } = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Godlike = 7,
}

function Quiet.isWary(species: any): boolean
	if type(species) ~= "table" or type(species.id) ~= "string" then
		return false
	end
	if WARY_IDS[species.id] or string.find(species.id, "Trout", 1, true) ~= nil then
		return true
	end
	return species.wary == true and (TIER_RANK[Rarity.of(species)] or 0) >= TIER_RANK.Rare
end

export type State = {
	quietRun: number, -- studs travelled quietly since the last loud stud
	trip: number, -- studs travelled since the boat last stopped
	stopped: boolean,
	arrivedAt: number?, -- clock of the last arrival
	arrivedPos: Vector3?,
	quiet: boolean, -- was that arrival quiet?
}

function Quiet.new(): State
	return { quietRun = 0, trip = 0, stopped = true, arrivedAt = nil, arrivedPos = nil, quiet = false }
end

-- Is the boat moving quietly right now: paddled, or a motor at idle or less?
function Quiet.quietMove(boatId: string, throttle: number): boolean
	local b = BoatData.byId[boatId]
	if not b then
		return false
	end
	return b.quiet or math.abs(throttle) <= Quiet.IDLE_THROTTLE
end

-- Step one boat: `dist` studs travelled since the last step at `speed`, the helm's throttle.
-- Stopping (slow enough to cast) after a real trip is an arrival; it is quiet when the last
-- DISTANCE studs were quiet.
function Quiet.step(st: State, boatId: string, throttle: number, speed: number, dist: number, pos: Vector3, now: number)
	local b = BoatData.byId[boatId]
	if not b then
		return
	end
	if math.abs(speed) > b.castSpeed then
		st.stopped = false
		st.trip += dist
		if Quiet.quietMove(boatId, throttle) then
			st.quietRun += dist
		else
			st.quietRun = 0
		end
		return
	end
	-- Slow enough to cast. Gliding in at idle still counts toward the quiet run.
	st.trip += dist
	if Quiet.quietMove(boatId, throttle) then
		st.quietRun += dist
	else
		st.quietRun = 0
	end
	if not st.stopped then
		st.stopped = true
		if st.trip >= Quiet.MIN_TRIP then
			st.arrivedAt = now
			st.arrivedPos = pos
			st.quiet = st.quietRun >= Quiet.DISTANCE
		end
		st.trip = 0
	end
end

-- Does a cast now, from a boat at `pos`, get the quiet bonus?
function Quiet.active(st: State, now: number, pos: Vector3): boolean
	if not st.quiet or not st.arrivedAt or not st.arrivedPos then
		return false
	end
	if now - st.arrivedAt > Quiet.WINDOW then
		return false
	end
	local a = st.arrivedPos :: Vector3
	return Vector3.new(pos.X - a.X, 0, pos.Z - a.Z).Magnitude <= Quiet.SPOT_RADIUS
end

-- Bite weights with wary fish 1.25 times as likely (like Daily.boost: the others unchanged).
function Quiet.boost(weights: { { id: string, w: number } }, byId: { [string]: any }): { { id: string, w: number } }
	local out = {}
	for _, x in weights do
		local w = if Quiet.isWary(byId[x.id]) then x.w * Quiet.WARY_MULT else x.w
		table.insert(out, { id = x.id, w = w })
	end
	table.sort(out, function(a, b)
		return a.w > b.w
	end)
	return out
end

-- The share of these weights that is wary fish (0 to 1), for the playtest log.
function Quiet.waryShare(weights: { { id: string, w: number } }, byId: { [string]: any }): number
	local total, wary = 0, 0
	for _, x in weights do
		total += x.w
		if Quiet.isWary(byId[x.id]) then
			wary += x.w
		end
	end
	return if total > 0 then wary / total else 0
end

-- A running tally of casts and wary bites, quiet against normal arrivals, for the log.
export type Tally = { quietCasts: number, quietWary: number, quietBites: number, loudCasts: number, loudWary: number, loudBites: number }

function Quiet.newTally(): Tally
	return { quietCasts = 0, quietWary = 0, quietBites = 0, loudCasts = 0, loudWary = 0, loudBites = 0 }
end

function Quiet.countCast(t: Tally, quiet: boolean)
	if quiet then
		t.quietCasts += 1
	else
		t.loudCasts += 1
	end
end

function Quiet.countBite(t: Tally, quiet: boolean, wary: boolean)
	if quiet then
		t.quietBites += 1
		t.quietWary += if wary then 1 else 0
	else
		t.loudBites += 1
		t.loudWary += if wary then 1 else 0
	end
end

function Quiet.tallyText(t: Tally): string
	local function pct(a: number, b: number): string
		return if b > 0 then string.format("%d%%", math.floor(a / b * 100 + 0.5)) else "n/a"
	end
	return string.format(
		"quiet arrivals: %d casts, %d bites, %d wary (%s); normal arrivals: %d casts, %d bites, %d wary (%s)",
		t.quietCasts,
		t.quietBites,
		t.quietWary,
		pct(t.quietWary, t.quietBites),
		t.loudCasts,
		t.loudBites,
		t.loudWary,
		pct(t.loudWary, t.loudBites)
	)
end

return Quiet
