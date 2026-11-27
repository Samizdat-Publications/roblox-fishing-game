--!strict
-- Weather that fishes like the real thing (docs/WEATHER.md). Each game day gets a plan at
-- dawn: clear, overcast, a foggy morning, a windy day (with a direction) or a storm day (a
-- feeding rush before the storm, then the storm); a cold front always follows a storm day.
-- The moon runs on its own 8 day cycle. Weather only multiplies the bite weights the game
-- already uses, per spot and species, so reading it is one more piece of fishing knowledge.
-- Nothing ever sells, calls, skips or extends weather.
-- Pure logic, no Roblox services. UNVERIFIED in Studio: written 2026-11-26 in the cloud.
local Weather = {}

export type Kind = {
	id: string,
	name: string,
	chance: number, -- share of days, picked at dawn; 0 for kinds that only follow another
	all: number?,
	spots: { [string]: number }?,
	species: { [string]: number }?,
	dawnFor: { [string]: boolean }?, -- these species bite by day as if it were dawn
	forecast: string,
	journal: string,
}

-- Low-light hunters: overcast and fog keep them feeding by day.
local LOW_LIGHT = { LargemouthBass = true, Walleye = true, BlackCrappie = true, NorthernPike = true, SmallmouthBass = true, Bowfin = true, Muskellunge = true }
local PREDATORS = { LargemouthBass = 1.4, NorthernPike = 1.4, Walleye = 1.4, SmallmouthBass = 1.4, WhiteBass = 1.4, Muskellunge = 1.4, Bowfin = 1.4 }

Weather.list = {
	{
		id = "Clear",
		name = "Clear",
		chance = 0.33,
		forecast = "Clear and calm.",
		journal = "Clear days: fish follow their usual habits.",
	},
	{
		id = "Overcast",
		name = "Overcast",
		chance = 0.25,
		spots = { WeedBed = 1.3, Dock = 1.2, Riffle = 1.2, Rocks = 1.1, DeepHole = 0.85, Pool = 0.85, DropOff = 0.85 },
		dawnFor = LOW_LIGHT,
		forecast = "Cloudy all day. Bass and walleye won't mind.",
		journal = "Overcast: low light keeps hunters feeding in the shallows all day.",
	},
	{
		id = "Fog",
		name = "Foggy morning",
		chance = 0.15,
		dawnFor = LOW_LIGHT,
		forecast = "Fog at dawn, clearing by mid-morning.",
		journal = "Fog: fish feel hidden, so the morning bite lasts longer.",
	},
	{
		id = "Wind",
		name = "Windy",
		chance = 0.15,
		species = PREDATORS, -- on the downwind side only; the upwind side gets UPWIND
		forecast = "Wind from the %s. Fish the shore it blows toward.",
		journal = "Wind: it pushes baitfish onto the downwind shore, and hunters follow.",
	},
	{
		id = "PreStorm",
		name = "Storm coming",
		chance = 0.12, -- a storm day: the rush, then the storm
		all = 1.3,
		species = { LargemouthBass = 1.6, NorthernPike = 1.6, ChannelCatfish = 1.6, Walleye = 1.6, WhiteBass = 1.6 },
		forecast = "Storm this afternoon. Fish feed hard before it hits.",
		journal = "Falling pressure before a storm: one of the best bites there is.",
	},
	{
		id = "Storm",
		name = "Thunderstorm",
		chance = 0,
		all = 0.6,
		forecast = "Thunderstorm. Stay off the water when there's lightning.",
		journal = "Storm: fish slow down, and lightning means boats stay in.",
	},
	{
		id = "ColdFront",
		name = "Cold front",
		chance = 0,
		all = 0.5,
		spots = { DeepHole = 1.6, Pool = 1.6, DropOff = 1.6, Dock = 1.2 },
		forecast = "Cold front: bright, breezy and slow. Go deep.",
		journal = "Cold front: rising pressure sends fish deep and makes them picky.",
	},
} :: { Kind }

Weather.byId = {} :: { [string]: Kind }
for _, k in Weather.list do
	Weather.byId[k.id] = k
end

-- Hours (game clock) for the parts of a day that don't last all day.
Weather.FOG_UNTIL = 10 -- fog lifts two hours after dawn ends at 8
Weather.RUSH_FROM, Weather.STORM_FROM, Weather.STORM_UNTIL = 13, 15, 18

-- Wind: which side of the water each spot is on. The wind blows toward the side opposite
-- where it comes from; that downwind side gets the hunters.
Weather.DIRECTIONS = { "north", "east", "south", "west" }
local OPPOSITE = { north = "south", south = "north", east = "west", west = "east" }
local SPOT_SIDE = { WeedBed = "west", Logs = "east", Dock = "south", DeepHole = "north", Basin = "south" }
Weather.UPWIND = 0.8

-- The moon: 8 day cycle; phase 4 is full. Night feeders love a full moon; the next dawn is slow.
Weather.MOON_DAYS = 8
Weather.FULL = 4
local MOON_NIGHT = { Walleye = 1.3, ChannelCatfish = 1.3, BlackCrappie = 1.3, Burbot = 1.3 }
Weather.AFTER_FULL_DAWN = 0.85

export type DayPlan = { day: number, kind: string, wind: string? }
export type Now = { weather: string, wind: string?, moon: number }

-- The plan for a game day. Deterministic from the day number and a server seed; the day
-- after a storm day is always a cold front.
function Weather.planDay(day: number, seed: number, previous: DayPlan?): DayPlan
	if previous and previous.kind == "PreStorm" then
		return { day = day, kind = "ColdFront" }
	end
	-- Mix the day and seed so neighbouring days don't start from neighbouring seeds.
	local rng = Random.new((day * 2654435761 + seed * 40503) % 2147483647)
	rng:NextNumber()
	local r = rng:NextNumber()
	local acc = 0
	for _, k in Weather.list do
		acc += k.chance
		if k.chance > 0 and r < acc then
			if k.id == "Wind" then
				return { day = day, kind = "Wind", wind = Weather.DIRECTIONS[rng:NextInteger(1, 4)] }
			end
			return { day = day, kind = k.id }
		end
	end
	return { day = day, kind = "Clear" }
end

-- One forecast for every server by real date (L6d): the date's day number (Goals.dayOf)
-- picks the plan with a fixed seed, so "storm this afternoon" on the chalkboard is true on
-- every server, and every game day of that date plays it (fog each morning, the storm each
-- afternoon). The day after a storm date is a cold front: the chain starts a few dates back
-- so yesterday's plan is known without a save.
Weather.DATE_SEED = 1977
Weather.DATE_LOOKBACK = 8

function Weather.planForDate(date: number): DayPlan
	local plan: DayPlan? = nil
	for d = date - Weather.DATE_LOOKBACK, date do
		plan = Weather.planDay(d, Weather.DATE_SEED, plan)
	end
	return plan :: DayPlan
end

-- What the weather is at this hour of a planned day (fog lifts; a storm day goes rush,
-- storm, then clear).
function Weather.at(plan: DayPlan, clock: number, moon: number): Now
	local c = clock % 24
	local id = plan.kind
	if id == "Fog" and (c >= Weather.FOG_UNTIL or c < 5) then
		id = "Clear"
	elseif id == "PreStorm" then
		if c >= Weather.STORM_FROM and c < Weather.STORM_UNTIL then
			id = "Storm"
		elseif c < Weather.RUSH_FROM or c >= Weather.STORM_UNTIL then
			id = "Clear"
		end
	end
	return { weather = id, wind = plan.wind, moon = moon }
end

function Weather.moonOf(day: number): number
	return day % Weather.MOON_DAYS
end

-- The period a species bites by in this weather (overcast and fog make day feel like dawn
-- for low-light hunters).
function Weather.periodFor(now: Now?, speciesId: string, period: string): string
	local k = now and Weather.byId[now.weather]
	if k and k.dawnFor and k.dawnFor[speciesId] and period == "Day" then
		return "Dawn"
	end
	return period
end

-- The multiplier on one species' bite weight at a spot and period.
function Weather.multiplier(now: Now?, speciesId: string, spot: string, period: string): number
	if not now then
		return 1
	end
	local m = 1
	local k = Weather.byId[now.weather]
	if k then
		m *= k.all or 1
		if k.spots then
			m *= k.spots[spot] or 1
		end
		if k.id == "Wind" and now.wind then
			local downwind = OPPOSITE[now.wind]
			local side = SPOT_SIDE[spot]
			if spot == "IslandPoint" then
				side = if now.wind == "east" then "upwind" else downwind
			end
			if side == downwind then
				m *= PREDATORS[speciesId] or 1
			elseif side == now.wind or side == "upwind" then
				m *= Weather.UPWIND
			end
		elseif k.species then
			m *= k.species[speciesId] or 1
		end
	end
	if now.moon == Weather.FULL and period == "Night" then
		m *= MOON_NIGHT[speciesId] or 1
	elseif now.moon == Weather.FULL + 1 and period == "Dawn" then
		m *= Weather.AFTER_FULL_DAWN
	end
	return m
end

-- The chalkboard line at Bait and Tackle.
function Weather.forecast(plan: DayPlan, moon: number): string
	local k = Weather.byId[plan.kind] or Weather.byId.Clear
	local text = if plan.wind then string.format(k.forecast, plan.wind) else k.forecast
	if moon == Weather.FULL then -- pass -1 to leave the moon out (the chalkboard: moons are per server)
		text ..= " Full moon tonight."
	end
	return text
end

-- Wind you can see (leg 3, N1 "Life"): workspace.GlobalWind by weather kind, so grass,
-- clouds and particles move. Speeds in studs per second. A kind with no direction of its own
-- (only Wind days carry one, the "WindFrom" attribute) blows from WIND_DEFAULT_FROM.
-- Directions: north is -Z and east is +X (the deep hole, "north" in SPOT_SIDE, is at z -25).
-- GlobalWind points where the air goes, so wind from the west blows toward +X.
-- stylua: ignore
Weather.WIND_SPEED = {
	Clear = 4,      -- a light breeze
	Overcast = 6,
	Fog = 0.5,      -- still air, that is why the fog sits
	Wind = 14,      -- a windy day
	PreStorm = 10,  -- gusting up before the storm
	Storm = 22,
	ColdFront = 12, -- bright and breezy
} :: { [string]: number }
Weather.WIND_DEFAULT_FROM = "west" -- prevailing westerly
Weather.WIND_BLEND_SECONDS = 20 -- the same 20 s the look takes to change weather

local BEARING = {
	north = 0, northeast = 45, east = 90, southeast = 135,
	south = 180, southwest = 225, west = 270, northwest = 315,
}

-- Compass bearing (degrees, 0 = north, 90 = east) for a WindFrom value: a compass word, an
-- angle (number or numeric string), else nil.
function Weather.bearingOf(from: any): number?
	if type(from) == "number" then
		return from % 360
	elseif type(from) == "string" then
		local b = BEARING[string.lower(from)]
		if b then
			return b
		end
		local n = tonumber(from)
		if n then
			return n % 360
		end
	end
	return nil
end

-- GlobalWind for this weather kind and direction (unknown kind: Clear's breeze).
function Weather.windFor(kind: string?, from: any): Vector3
	local speed = (if kind then Weather.WIND_SPEED[kind] else nil) or Weather.WIND_SPEED.Clear
	local b = Weather.bearingOf(from) or (BEARING[Weather.WIND_DEFAULT_FROM] :: number)
	local r = math.rad(b)
	-- The from-direction is (sin b, 0, -cos b); the air moves the other way.
	return Vector3.new(-math.sin(r) * speed, 0, math.cos(r) * speed)
end

-- The wind blend: `from` vector into `to`, `amount` (0..1, linear) of the way, eased.
export type WindBlend = { from: Vector3, to: Vector3, amount: number }

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerpV(a: Vector3, b: Vector3, t: number): Vector3
	return Vector3.new(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
end

-- The wind showing now for a blend.
function Weather.windNow(b: WindBlend): Vector3
	return lerpV(b.from, b.to, smooth(b.amount))
end

-- Moves the blend on by dt seconds toward `target` (mutates b) and returns the wind to show.
-- A new target starts from whatever shows now, so a change mid-blend never jumps.
function Weather.stepWind(b: WindBlend, target: Vector3, dt: number): Vector3
	if target ~= b.to then
		b.from = Weather.windNow(b)
		b.to = target
		b.amount = 0
	end
	b.amount = math.min(1, b.amount + dt / Weather.WIND_BLEND_SECONDS)
	return Weather.windNow(b)
end

-- A hint line when nothing bites, naming the weather when it's the reason.
function Weather.hint(now: Now?): string?
	local id = now and now.weather
	if id == "ColdFront" then
		return "A cold front came through. Try deep water and go slow."
	elseif id == "Storm" then
		return "The storm has the fish sulking. Wait it out or try the dock."
	end
	return nil
end

return Weather
