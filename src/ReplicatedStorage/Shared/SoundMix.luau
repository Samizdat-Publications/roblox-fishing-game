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

return SoundMix
