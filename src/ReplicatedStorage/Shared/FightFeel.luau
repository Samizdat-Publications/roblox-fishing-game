--!strict
-- How a fight looks and sounds (L4b), as pure rules the client draws and the tests check:
--   * tension: how hard the fish pulls against you, 0 (easy) to 1 (about to get away)
--   * the line's colour from tension: white, then orange, then red
--   * how far the rod tip bends with tension
--   * each fight style's tell: what the player sees and hears on the water, and which sound
--   * the cast's back swing and forward whip (rod pitch over time)
-- No Roblox services; the client modules (Controller, RodFeel, FightTells) do the drawing.
-- UNVERIFIED in Studio (written 2026-11-26).
local FightFeel = {}

-- Tension rule. Inside the catch zone the line is taut but easy (IN_ZONE). Outside it the
-- pull jumps to OUT_ZONE and climbs to 1 as the gap to the zone grows to GAP_FULL bar
-- heights. A big move in progress (run, jump, dive) adds MOVE_PULL. Separately, as progress
-- falls toward escaping (below ESCAPE_WARN) tension rises toward 1 whatever the zone does,
-- so the line glows red just before a fish gets away. The larger of the two wins.
FightFeel.IN_ZONE = 0.15
FightFeel.OUT_ZONE = 0.45
FightFeel.GAP_FULL = 0.3
FightFeel.MOVE_PULL = 0.15
FightFeel.ESCAPE_WARN = 0.3

-- Line colour stops: white up to WHITE_UNTIL, white to orange by ORANGE_AT, orange to red by RED_AT.
FightFeel.WHITE = Color3.fromRGB(235, 235, 235)
FightFeel.ORANGE = Color3.fromRGB(255, 150, 40)
FightFeel.RED = Color3.fromRGB(235, 45, 35)
FightFeel.WHITE_UNTIL = 0.3
FightFeel.ORANGE_AT = 0.6
FightFeel.RED_AT = 0.9

-- Rod bend: total tip droop in degrees, from a fish on but resting to full tension.
FightFeel.BEND_MIN = 6
FightFeel.BEND_MAX = 38
FightFeel.DIVE_DIP = 18 -- extra droop while a diver's dive is warned or running

-- The cast swing: back to SWING_BACK degrees in BACK_TIME, whip forward to SWING_WHIP degrees
-- (past rest, pointing at the water) in WHIP_TIME, then settle to rest in SETTLE_TIME.
FightFeel.SWING_BACK = 55
FightFeel.SWING_WHIP = -22
FightFeel.BACK_TIME = 0.16
FightFeel.WHIP_TIME = 0.12
FightFeel.SETTLE_TIME = 0.3

-- A fight state as FightModel keeps it (only the fields read here).
type FightLike = {
	fishPos: number,
	zonePos: number,
	zoneSize: number,
	progress: number,
	mode: string,
}

function FightFeel.tension(s: FightLike): number
	local gap = math.abs(s.fishPos - s.zonePos) - s.zoneSize / 2
	local pull
	if gap <= 0 then
		pull = FightFeel.IN_ZONE
	else
		pull = FightFeel.OUT_ZONE + (1 - FightFeel.OUT_ZONE) * math.clamp(gap / FightFeel.GAP_FULL, 0, 1)
	end
	if s.mode == "run" or s.mode == "jump" or s.mode == "dive" then
		pull += FightFeel.MOVE_PULL
	end
	local escape = math.clamp((FightFeel.ESCAPE_WARN - s.progress) / FightFeel.ESCAPE_WARN, 0, 1)
	return math.clamp(math.max(pull, escape), 0, 1)
end

function FightFeel.lineColor(tension: number): Color3
	local t = math.clamp(tension, 0, 1)
	if t <= FightFeel.WHITE_UNTIL then
		return FightFeel.WHITE
	elseif t <= FightFeel.ORANGE_AT then
		return FightFeel.WHITE:Lerp(FightFeel.ORANGE, (t - FightFeel.WHITE_UNTIL) / (FightFeel.ORANGE_AT - FightFeel.WHITE_UNTIL))
	elseif t <= FightFeel.RED_AT then
		return FightFeel.ORANGE:Lerp(FightFeel.RED, (t - FightFeel.ORANGE_AT) / (FightFeel.RED_AT - FightFeel.ORANGE_AT))
	end
	return FightFeel.RED
end

-- Degrees the rod tip droops at this tension (diving: a diver's dive is coming or running).
function FightFeel.rodBend(tension: number, diving: boolean?): number
	local b = FightFeel.BEND_MIN + (FightFeel.BEND_MAX - FightFeel.BEND_MIN) * math.clamp(tension, 0, 1)
	return b + (if diving then FightFeel.DIVE_DIP else 0)
end

-- Each fight style's tell. `move` is the big move FightModel is winding up (FightModel.tell),
-- or nil for the small ongoing ones. Returns the tell's name, or nil when the style has none.
--   drag    runner's run: the drag screams, the line pulls hard to one side, a V wake
--   breach  jumper's leap: the fish breaks the surface with a splash
--   dive    diver's dive: the rod tip dips, the line goes steep, a low creak
--   thrash  shaker's run: the bobber spot thrashes with spray
--   twitch  tugger's dart: quick small twitches of the line
--   pull    steady: a slow steady pull
FightFeel.TELLS = {
	runner = { run = "drag" },
	jumper = { jump = "breach" },
	diver = { dive = "dive" },
	shaker = { run = "thrash" },
	tugger = { dart = "twitch" },
	steady = { dart = "pull" },
} :: { [string]: { [string]: string } }

function FightFeel.tellFor(style: string?, move: string?): string?
	local byMove = FightFeel.TELLS[style or "tugger"]
	if not byMove then
		return nil
	end
	return byMove[move or "dart"]
end

-- The sound for each tell (existing sounds only: uploads are capped). `volume` scales the
-- sound's base level; `speed` its pitch. Twitch and pull are quiet, line-only tells.
FightFeel.TELL_SOUNDS = {
	drag = { name = "drag-zip", volume = 1, speed = 1 },
	breach = { name = "thrash-splash", volume = 1, speed = 1 },
	dive = { name = "line-creak", volume = 1, speed = 0.7 }, -- line-strain, quiet and low
	thrash = { name = "thrash-splash", volume = 1, speed = 1.15 },
} :: { [string]: { name: string, volume: number, speed: number } }

-- The cast swing: the rod's pitch offset in degrees (positive is back over the shoulder) `t`
-- seconds after release, 0 before and after.
function FightFeel.swingPitch(t: number): number
	local back, whip, settle = FightFeel.BACK_TIME, FightFeel.WHIP_TIME, FightFeel.SETTLE_TIME
	if t <= 0 then
		return 0
	elseif t < back then
		local k = t / back
		return FightFeel.SWING_BACK * (1 - (1 - k) * (1 - k)) -- quick out, easing at the top
	elseif t < back + whip then
		local k = (t - back) / whip
		return FightFeel.SWING_BACK + (FightFeel.SWING_WHIP - FightFeel.SWING_BACK) * (k * k) -- accelerating whip
	elseif t < back + whip + settle then
		local k = (t - back - whip) / settle
		return FightFeel.SWING_WHIP * (1 - (k * k * (3 - 2 * k)))
	end
	return 0
end

-- Seconds the whole swing takes; the line leaves the rod tip at the end of the whip.
function FightFeel.swingTime(): number
	return FightFeel.BACK_TIME + FightFeel.WHIP_TIME + FightFeel.SETTLE_TIME
end

function FightFeel.releaseTime(): number
	return FightFeel.BACK_TIME + FightFeel.WHIP_TIME
end

return FightFeel
