--!strict
-- The reel-in minigame as a deterministic simulation. The client steps it every frame
-- and draws it; tests step it with bots. Positions run 0 (bottom) to 1 (top).
--
-- Feel: the player's input always wins. Holding drives the catch zone up at a steady
-- climb speed within a fraction of a second, and every fresh press (a click or tap) gives
-- an instant kick upward, so clicking works as well as holding. Heavy fish only slow the
-- climb a little; species differ mostly in how the fish moves and how fast you land it.
--
-- Fight styles (FightProfile.style), so each kind of fish feels like itself:
--   tugger  quick little darts (panfish)
--   steady  slow, short wanders (perch, walleye)
--   runner  now and then a long run to one end of the bar, then a rest (largemouth bass)
--   jumper  sudden leaps to the top, then a drop (trout, smallmouth)
--   diver   keeps pulling for the bottom, with the odd surge up (catfish, carp)
--   shaker  fast head shakes on top of wild runs (pike, muskie)
-- Verified in a Studio playtest 2026-11-26 (bass, pike, catfish and trout traces); the tests
-- check each style's shape and that a tracking player still lands every species.
local Shared = script.Parent
local Config = require(Shared.Config)
local FishData = require(Shared.FishData)

export type State = {
	profile: FishData.FightProfile,
	rng: Random,
	fishPos: number,
	fishTarget: number,
	zonePos: number,
	zoneVel: number,
	zoneSize: number,
	gain: number,
	loss: number,
	progress: number,
	t: number,
	idle: number, -- seconds since the player last pressed or held
	mode: string, -- "normal", or a style move in progress: "run", "rest", "jump"
	modeTimer: number,
}

local MODE_SPEED = { normal = 1, run = 1.7, rest = 0.45, jump = 2.2 }
local SHAKE_SIZE = 0.045 -- how far a shaker's head shakes move it on the bar
local SHAKE_RATE = 24 -- radians per second

local FightModel = {}

function FightModel.new(profile: FishData.FightProfile, assist: boolean, seed: number): State
	local rng = Random.new(seed)
	return {
		profile = profile,
		rng = rng,
		fishPos = 0.5,
		fishTarget = 0.5,
		zonePos = 0.4,
		zoneVel = 0,
		zoneSize = profile.zone * (if assist then Config.ASSIST_ZONE else 1),
		gain = profile.gain,
		loss = profile.loss * (if assist then Config.ASSIST_LOSS else 1),
		progress = Config.FIGHT_START,
		t = 0,
		idle = math.huge, -- nothing counts until the player first presses or holds
		mode = "normal",
		modeTimer = 0,
	}
end

local function climbFactor(p: FishData.FightProfile): number
	return 1 - p.heavy * 0.2
end

-- A fresh press (mouse down, tap, trigger pull): the zone starts climbing at once.
-- It sets a minimum speed rather than adding, so mashing can't fling the zone.
function FightModel.press(s: State)
	s.idle = 0
	s.zoneVel = math.max(s.zoneVel, Config.PRESS_KICK * climbFactor(s.profile))
end

-- Advance by dt seconds. Returns "won", "lost" or nil while the fight goes on.
function FightModel.step(s: State, dt: number, holding: boolean): string?
	local p = s.profile
	s.t += dt
	s.idle = if holding then 0 else s.idle + dt

	-- Zone: velocity eases toward the target speed; position integrates that curve exactly,
	-- so the result is the same at 15 or 120 frames per second.
	local target = if holding then Config.ZONE_UP_SPEED * climbFactor(p) else -Config.ZONE_DOWN_SPEED
	local k = Config.ZONE_RESPONSE
	local decay = math.exp(-k * dt)
	local v0 = s.zoneVel
	s.zonePos += target * dt + (v0 - target) * (1 - decay) / k
	s.zoneVel = target + (v0 - target) * decay
	local half = s.zoneSize / 2
	if s.zonePos < half then
		s.zonePos = half
		s.zoneVel = math.max(s.zoneVel, 0)
	elseif s.zonePos > 1 - half then
		s.zonePos = 1 - half
		s.zoneVel = math.min(s.zoneVel, 0)
	end

	-- Fish: picks a new target now and then, sinkers prefer the bottom; its style adds moves.
	local style = p.style or "tugger"
	if s.mode ~= "normal" then
		s.modeTimer -= dt
		if s.modeTimer <= 0 then
			if s.mode == "run" then
				s.mode, s.modeTimer = "rest", 1.0 -- tired after a run
			elseif s.mode == "jump" then
				s.mode = "normal"
				s.fishTarget = math.clamp(s.fishPos - 0.3, 0.05, 0.95) -- splash back down
			else
				s.mode = "normal"
			end
		end
	end
	if s.mode == "normal" and s.rng:NextNumber() < p.dart * dt then
		local offset = (s.rng:NextNumber() * 2 - 1) * p.range - p.sink * p.range * 0.5
		if style == "steady" then
			offset *= 0.6
		elseif style == "diver" then
			offset = if s.rng:NextNumber() < 0.15 then p.range else offset - p.range * 0.35 -- a surge, or more down
		end
		s.fishTarget = math.clamp(s.fishPos + offset, 0.05, 0.95)
		if (style == "runner" or style == "shaker") and s.rng:NextNumber() < 0.35 then
			s.fishTarget = if s.fishPos > 0.5 then 0.08 else 0.92 -- a long run to the far end
			s.mode, s.modeTimer = "run", 1.0
		end
	end
	if style == "jumper" and s.mode == "normal" and s.rng:NextNumber() < 0.2 * dt then
		s.fishTarget = 0.95
		s.mode, s.modeTimer = "jump", 0.9
	end
	local d = s.fishTarget - s.fishPos
	local maxMove = p.speed * MODE_SPEED[s.mode] * dt
	if math.abs(d) <= maxMove then
		s.fishPos = s.fishTarget
	else
		s.fishPos += math.sign(d) * maxMove
	end
	if style == "shaker" then
		local shake = SHAKE_SIZE * (math.sin(s.t * SHAKE_RATE) - math.sin((s.t - dt) * SHAKE_RATE))
		s.fishPos = math.clamp(s.fishPos + shake, 0.02, 0.98)
	end

	-- Progress fills while the fish is in the zone and the line is tight: the player has
	-- pressed or held within FIGHT_IDLE_GRACE. Leave it longer and the line goes slack, so
	-- the fish slowly works free even inside the zone. (A player resting the zone at the
	-- bottom for a sinking fish just taps now and then; the client should show a cue.)
	if math.abs(s.fishPos - s.zonePos) <= half then
		if s.idle <= Config.FIGHT_IDLE_GRACE then
			s.progress += s.gain * dt
		else
			s.progress -= s.loss * 0.5 * dt
		end
	else
		s.progress -= s.loss * dt
	end
	if s.progress >= 1 then
		s.progress = 1
		return "won"
	elseif s.progress <= 0 then
		s.progress = 0
		return "lost"
	end
	return nil
end

-- True while the line has gone slack (no press or hold for FIGHT_IDLE_GRACE since the last
-- one): the UI should say "Keep reeling!" so the player knows to tap. Before the very first
-- press the hook prompt already says what to do, so the cue stays quiet.
function FightModel.slack(s: State): boolean
	return s.idle ~= math.huge and s.idle > Config.FIGHT_IDLE_GRACE
end

-- True while the fish sits inside the catch zone (the UI turns the zone green).
function FightModel.inside(s: State): boolean
	return math.abs(s.fishPos - s.zonePos) <= s.zoneSize / 2
end

-- The fastest a fight can possibly be won. The server rejects wins that come sooner.
function FightModel.minSeconds(profile: FishData.FightProfile, _assist: boolean): number
	return (1 - Config.FIGHT_START) / profile.gain
end

return FightModel
