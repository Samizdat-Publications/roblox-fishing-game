--!strict
-- Pure rules for the sound pass (docs/DIRECTION.md section 2): which ambience plays how loud
-- for the clock and where the player stands, and which cue goes with which moment. No
-- instances here, so the rules are unit tested; SoundFX (client) plays the result.
local SoundMix = {}

-- Lake ambience periods in game hours, each fading in and out over FADE hours at its edges.
-- Dawn 5 to 8, day 8 to 18, dusk 18 to 20.5, night 20.5 to 5 (wraps past midnight).
local FADE = 0.75
local PERIODS = {
	{ id = "amb-lake-dawn", from = 5, to = 8 },
	{ id = "amb-lake-day", from = 8, to = 18 },
	{ id = "amb-lake-dusk", from = 18, to = 20.5 },
	{ id = "amb-lake-night", from = 20.5, to = 29 },
}

-- How much one period wants to play at this clock: 1 inside it, falling to 0 FADE hours
-- outside its edges. Distances go round the clock, so night can wrap past midnight.
local function raw(clock: number, from: number, to: number): number
	if (clock - from) % 24 <= to - from then
		return 1
	end
	local outside = math.min((from - clock) % 24, (clock - to) % 24)
	return math.max(0, 1 - outside / FADE)
end

-- Volumes (0..1, summing to 1) for the four lake ambiences at this clock time.
function SoundMix.lakeWeights(clock: number): { [string]: number }
	clock = clock % 24
	local out: { [string]: number } = {}
	local total = 0
	for _, p in PERIODS do
		local w = raw(clock, p.from, p.to)
		out[p.id] = w
		total += w
	end
	for id, w in out do
		out[id] = if total > 0 then w / total else 0
	end
	return out
end

-- Cedar Creek runs north-south along x = -230 from z = -70 to z = 75.
SoundMix.CREEK_X = -230
SoundMix.CREEK_Z_MIN = -70
SoundMix.CREEK_Z_MAX = 75
local CREEK_NEAR = 25 -- full volume within this many studs of the water's centre line
local CREEK_FAR = 110 -- silent beyond this

function SoundMix.creekDistance(x: number, z: number): number
	local dz = 0
	if z < SoundMix.CREEK_Z_MIN then
		dz = SoundMix.CREEK_Z_MIN - z
	elseif z > SoundMix.CREEK_Z_MAX then
		dz = z - SoundMix.CREEK_Z_MAX
	end
	local dx = x - SoundMix.CREEK_X
	return math.sqrt(dx * dx + dz * dz)
end

-- 0..1: running water gets louder as you walk closer (smoothstep between FAR and NEAR).
function SoundMix.creekLevel(distance: number): number
	local t = math.clamp((CREEK_FAR - distance) / (CREEK_FAR - CREEK_NEAR), 0, 1)
	return t * t * (3 - 2 * t)
end

-- The lake fades down (not out) while the creek is loud, so the two places sound different.
function SoundMix.lakeLevel(creekLevel: number): number
	return 1 - 0.75 * creekLevel
end

local BITE_CUES = {
	nibble = "bite-tap",
	tap = "bite-tap",
	slam = "bite-slam",
	pull = "bite-deep-pull",
}

-- The sound for the real bite, by bite style (FishLogic.bitePattern). The small dips before
-- a nibbler's bite play "bite-nibble".
function SoundMix.biteCue(style: string?): string
	return BITE_CUES[style or ""] or "bite-slam"
end

local STINGERS = {
	Common = "sting-common",
	Uncommon = "sting-uncommon",
	Rare = "sting-rare",
	Epic = "sting-epic",
	Legendary = "sting-legendary",
	Mythic = "sting-mythic",
	Godlike = "sting-godlike",
}

-- The catch stinger for a rarity tier; anything unknown (or no tier yet) is Common.
function SoundMix.stingerFor(tier: string?): string
	return STINGERS[tier or ""] or "sting-common"
end

SoundMix.BIG_SPLASH_KG = 1.5

function SoundMix.splashFor(kg: number): string
	return if kg >= SoundMix.BIG_SPLASH_KG then "splash-big" else "splash-small"
end

-- Heavy fighters (catfish, carp, pike, walleye...) bring in the tension music layer.
function SoundMix.isBigFight(fight: { heavy: number? }?): boolean
	return fight ~= nil and (fight.heavy or 0) >= 0.3
end

-- Reel click pitch: rises as the fish gets close to breaking free (low progress, fish out
-- of the zone), from 1.0 calm to 1.35 at the edge.
function SoundMix.reelPitch(progress: number, inside: boolean): number
	local danger = math.clamp((0.35 - progress) / 0.35, 0, 1)
	if inside then
		danger *= 0.4
	end
	return 1 + 0.35 * danger
end

-- Second overnight run (2026-11-26, cloud, UNVERIFIED in Studio): rules for the sounds
-- prompted in audio/sounds-next.json. Each is skipped by SoundFX until it's uploaded.

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- 0..1: how far into the Big Lake you are. The channel through the north shore starts at
-- z = -78; the open Big Lake at z = -140. Off the map sideways it's silent.
function SoundMix.bigLakeLevel(x: number, z: number): number
	if math.abs(x) > 210 then
		return 0
	end
	return smooth((-100 - z) / 50)
end

-- 0..1: the blue water past the buoy line at z = -290 (the deep, open sound).
SoundMix.BUOY_Z = -290
function SoundMix.blueLevel(x: number, z: number): number
	if math.abs(x) > 210 then
		return 0
	end
	return smooth((SoundMix.BUOY_Z + 10 - z) / 40)
end

-- The home lake steps back out on the Big Lake (it's far behind you).
function SoundMix.homeLakeLevel(bigLevel: number): number
	return 1 - 0.85 * bigLevel
end

-- Motor volumes and pitch for a boat at this speed: an idle putter at rest that gives way
-- to a running drone, which rises in pitch with speed.
export type Motor = { idle: number, run: number, pitch: number }
function SoundMix.motor(speed: number, maxSpeed: number): Motor
	local t = if maxSpeed > 0 then math.clamp(speed / maxSpeed, 0, 1) else 0
	return {
		idle = 0.35 * (1 - smooth(t * 3)),
		run = if t > 0.03 then 0.2 + 0.5 * t else 0,
		pitch = 0.8 + 0.5 * t,
	}
end

function SoundMix.motorName(boatId: string?): string
	return if boatId == "DeepV" then "motor-deepv-run" else "motor-dinghy-run"
end

-- Weather sounds: a rain loop level, and the gaps (seconds, min and max) between thunder
-- rolls and wind gusts. nil means none in this weather.
export type WeatherSound = { rain: number, thunder: { number }?, gust: { number }? }
local WEATHER_SOUNDS: { [string]: WeatherSound } = {
	Storm = { rain = 0.7, thunder = { 12, 30 } },
	PreStorm = { rain = 0, thunder = { 45, 90 } }, -- far off: the storm is coming
	Wind = { rain = 0, gust = { 10, 22 } },
	ColdFront = { rain = 0, gust = { 25, 50 } },
}
function SoundMix.weather(id: string?): WeatherSound
	return WEATHER_SOUNDS[id or ""] or { rain = 0 }
end

-- 0..1: the boil of a feeding frenzy, loud close by and gone beyond 120 studs.
function SoundMix.frenzyLevel(distance: number): number
	return smooth((120 - distance) / 95)
end

-- The catch stinger, with trophy and monster ones when uploaded (`has` says which are).
function SoundMix.catchStinger(tier: string?, sizeClass: string?, has: (string) -> boolean): string
	if (sizeClass == "monster" or sizeClass == "trophy") and has("sting-" .. sizeClass) then
		return "sting-" .. sizeClass
	end
	return SoundMix.stingerFor(tier)
end

return SoundMix
