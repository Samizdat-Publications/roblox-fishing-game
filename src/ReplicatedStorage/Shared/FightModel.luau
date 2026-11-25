--!strict
-- The reel-in minigame as a deterministic simulation. The client steps it every frame
-- and draws it; tests step it with bots. Positions run 0 (bottom) to 1 (top).
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
}

local FightModel = {}

function FightModel.new(profile: FishData.FightProfile, assist: boolean, seed: number): State
	local rng = Random.new(seed)
	return {
		profile = profile,
		rng = rng,
		fishPos = 0.5,
		fishTarget = 0.5,
		zonePos = 0.3,
		zoneVel = 0,
		zoneSize = profile.zone * (if assist then Config.ASSIST_ZONE else 1),
		gain = profile.gain,
		loss = profile.loss * (if assist then Config.ASSIST_LOSS else 1),
		progress = Config.FIGHT_START,
		t = 0,
	}
end

-- Advance by dt seconds. Returns "won", "lost" or nil while the fight goes on.
function FightModel.step(s: State, dt: number, holding: boolean): string?
	local p = s.profile
	s.t += dt

	-- Player's catch zone: lift while holding, fall otherwise. Heavy fish fight the lift.
	local lift = Config.FIGHT_LIFT * (1 - p.heavy * 0.4)
	local accel = if holding then lift else -Config.FIGHT_GRAVITY
	s.zoneVel += accel * dt
	s.zoneVel -= s.zoneVel * math.min(1, Config.FIGHT_DAMPING * dt)
	s.zonePos += s.zoneVel * dt
	local half = s.zoneSize / 2
	if s.zonePos < half then
		s.zonePos = half
		s.zoneVel = 0
	elseif s.zonePos > 1 - half then
		s.zonePos = 1 - half
		s.zoneVel = 0
	end

	-- Fish: picks a new target now and then, sinkers prefer the bottom.
	if s.rng:NextNumber() < p.dart * dt then
		local offset = (s.rng:NextNumber() * 2 - 1) * p.range - p.sink * p.range * 0.5
		s.fishTarget = math.clamp(s.fishPos + offset, 0.05, 0.95)
	end
	local d = s.fishTarget - s.fishPos
	local maxMove = p.speed * dt
	if math.abs(d) <= maxMove then
		s.fishPos = s.fishTarget
	else
		s.fishPos += math.sign(d) * maxMove
	end

	-- Progress fills while the fish is in the zone.
	if math.abs(s.fishPos - s.zonePos) <= half then
		s.progress += s.gain * dt
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

-- The fastest a fight can possibly be won. The server rejects wins that come sooner.
function FightModel.minSeconds(profile: FishData.FightProfile, _assist: boolean): number
	return (1 - Config.FIGHT_START) / profile.gain
end

return FightModel
