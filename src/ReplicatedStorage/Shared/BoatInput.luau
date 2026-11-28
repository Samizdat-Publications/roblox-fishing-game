--!strict
-- When the helm's client sends its controls to the server (the N4 playtest, 11/28/2026).
-- It used to send every 0.1 s, which put up to 100 ms between the key and the server on top of
-- the network. Now a change goes out the frame it happens; a held key is repeated every
-- HEARTBEAT so the server (BoatService's INPUT_FRESH) knows it is still held. Stick values are
-- rounded to STEP so a thumbstick moving slowly doesn't send every frame.
-- Pure, no Roblox services: runs in the Lune tests.
local BoatInput = {}

BoatInput.HEARTBEAT = 0.1 -- seconds between repeats while a control is held
BoatInput.STEP = 0.1 -- controls are sent rounded to this

export type State = {
	throttle: number, -- what was last sent
	steer: number,
	at: number, -- when it was sent (os.clock)
	atHelm: boolean, -- whether the player was at the helm last frame
}

function BoatInput.new(): State
	return { throttle = 0, steer = 0, at = -math.huge, atHelm = false }
end

local function round(x: number): number
	if x ~= x then
		return 0
	end
	return math.clamp(math.floor(x / BoatInput.STEP + 0.5) * BoatInput.STEP, -1, 1)
end

-- Called every frame. Returns whether to send now, and the throttle and steer to send.
-- Leaving the helm sends one last 0, 0 (letting go).
function BoatInput.decide(s: State, atHelm: boolean, throttle: number, steer: number, now: number): (boolean, number, number)
	if not atHelm then
		local was = s.atHelm
		s.atHelm = false
		if was then
			s.throttle, s.steer, s.at = 0, 0, now
			return true, 0, 0
		end
		return false, 0, 0
	end
	local th, st = round(throttle), round(steer)
	local changed = not s.atHelm or th ~= s.throttle or st ~= s.steer
	local held = (th ~= 0 or st ~= 0) and now - s.at >= BoatInput.HEARTBEAT
	s.atHelm = true
	if changed or held then
		s.throttle, s.steer, s.at = th, st, now
		return true, th, st
	end
	return false, th, st
end

return BoatInput
