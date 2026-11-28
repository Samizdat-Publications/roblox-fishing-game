--!strict
-- How a boat feels (leg 3, N4, Config.BOAT_FEEL_ON): the numbers and the pure maths behind the
-- client's feel layer (ClientModules/BoatFeelClient). The server's hull stays flat and exact;
-- everything here is drawn on each screen, on the art model, so feel can never fight the rules.
-- See docs/superpowers/plans/2026-11-27-leg-3.md, "How a boat should feel".
--
-- Pure: no Roblox services, no instances. Angles are degrees unless a name says radians.
-- Boat space: bow toward -Z, starboard +X, y up, y = 0 on the waterline.
-- Signs: pitch > 0 lifts the bow (a turn about +X); roll > 0 lifts the starboard side (a turn
-- about +Z), so roll < 0 is starboard down; a right turn has a negative yaw rate (about +Y).
-- Written 11/28/2026 in a worktree. UNVERIFIED in Studio.
local BoatFeel = {}

export type Floor = {
	y: number, -- height of the lowest inside floor above the waterline, drawn level
	halfW: number, -- half its width (studs)
	halfL: number, -- half its length
	rocker: number, -- how fast the floor rises toward the ends: y + rocker * z^2
}

export type Art = {
	hero: string, -- model name in ServerStorage.Art (copied to ReplicatedStorage.BoatArt): desktop tier
	plain: string, -- the phone tier's twin (the same model until one is made)
	lift: number, -- y of the model's pivot above the waterline (negative: below)
	yaw: number, -- degrees to turn the model about +Y so its bow points along -Z
	trimPivotZ: number, -- the bow lifts about this point (the stern), so trim never sinks it
	floor: Floor,
	bow: Vector3, -- where spray starts and the wake's arms begin
	stern: Vector3, -- where the wash churns
	halfBeam: number, -- the wake's arms start this far out from the keel
	lights: { red: Vector3, green: Vector3, white: Vector3 },
	seats: { [string]: Vector3 }?, -- seat tops to put the server's seats at (BoatService), by seat name
	paddle: { hero: string, plain: string, hand: Vector3 }?, -- the paddle model, and where the lower hand holds it
}

-- One table of art names, so a new model (the dinghy re-skin) drops in by changing one entry.
-- Canoe numbers are from art/README.md, "The Cedar Canoe". The dinghy entry is written against
-- the current Dinghy model (art/scripts/boats.py: floor top 0.25 above the tubes' bottom, whose
-- pivot is the bottom of the bounding box, the motor's skeg, 0.525 below that). The Deep-V is not
-- for sale; its numbers are a first guess.
BoatFeel.ART = {
	Canoe = {
		hero = "CedarCanoe",
		plain = "CedarCanoePlain",
		lift = 0, -- the canoe's pivot is on the waterline
		yaw = 0,
		trimPivotZ = 6.2,
		-- Bottom boards amidships 0.22 above the waterline; the rocker is a guess (0.47 at the seats' ends).
		floor = { y = 0.22, halfW = 0.5, halfL = 5, rocker = 0.01 },
		bow = Vector3.new(0, 0.05, -6.0),
		stern = Vector3.new(0, 0.05, 6.0),
		halfBeam = 0.9,
		-- On the stem heads' inner faces, just under the 1.75 tips.
		lights = { red = Vector3.new(-0.18, 1.45, -5.9), green = Vector3.new(0.18, 1.45, -5.9), white = Vector3.new(0, 1.45, 5.9) },
		seats = { Helm = Vector3.new(0, 0.64, 3.0), Bow = Vector3.new(0, 0.64, -2.3) },
		paddle = { hero = "CanoePaddle", plain = "CanoePaddlePlain", hand = Vector3.new(0, 0, -2.2) },
	},
	Dinghy = {
		hero = "Dinghy", -- the re-skin's hero set replaces this name
		plain = "Dinghy",
		lift = -0.575, -- floor top 0.20 above the water, the tubes' bottoms 0.05 under
		yaw = 0,
		trimPivotZ = 4.3,
		floor = { y = 0.2, halfW = 1.4, halfL = 3.3, rocker = 0 },
		bow = Vector3.new(0, 0.1, -4.1),
		stern = Vector3.new(0, 0.05, 4.6),
		halfBeam = 1.7,
		lights = { red = Vector3.new(-0.6, 1.25, -3.9), green = Vector3.new(0.6, 1.25, -3.9), white = Vector3.new(0, 1.9, 4.5) },
		seats = { Helm = Vector3.new(0, 0.8, 2.1) }, -- on the bench (the passenger keeps the server's seat)
	},
	DeepV = {
		hero = "DeepV",
		plain = "DeepV",
		lift = -0.6,
		yaw = 0,
		trimPivotZ = 8.5,
		floor = { y = 0.5, halfW = 2.8, halfL = 7, rocker = 0 },
		bow = Vector3.new(0, 0.3, -8.6),
		stern = Vector3.new(0, 0.05, 8.6),
		halfBeam = 3.0,
		lights = { red = Vector3.new(-0.9, 2.4, -7.6), green = Vector3.new(0.9, 2.4, -7.6), white = Vector3.new(0, 3.6, 8.0) },
	},
} :: { [string]: Art }

-- Every model name the client may draw (the server copies these to ReplicatedStorage.BoatArt).
function BoatFeel.artNames(): { string }
	local seen: { [string]: boolean } = {}
	local out: { string } = {}
	local function add(n: string)
		if not seen[n] then
			seen[n] = true
			table.insert(out, n)
		end
	end
	for _, id in { "Canoe", "Dinghy", "DeepV" } do
		local a = BoatFeel.ART[id]
		add(a.hero)
		add(a.plain)
		if a.paddle then
			add(a.paddle.hero)
			add(a.paddle.plain)
		end
	end
	return out
end

-- The model this tier draws ("phone" or anything else for the desktop).
function BoatFeel.modelFor(boatId: string, tier: string?): string?
	local a = BoatFeel.ART[boatId]
	if not a then
		return nil
	end
	return if tier == "phone" then a.plain else a.hero
end

----------------------------------------------------------------------------------------
-- Trim and lean

-- Per kind of hull: motor boats rise onto the plane; the canoe is a displacement hull and only
-- lifts a little (its 0.22 stud draft leaves no room for more; see floorDip).
BoatFeel.TRIM = {
	motor = { peak = 6, plane = 2.5, start = 0.1, peakAt = 0.45, planeAt = 0.85 },
	paddle = { peak = 1.5, plane = 1.0, start = 0.1, peakAt = 0.45, planeAt = 0.85 },
}
BoatFeel.LEAN_MAX = { motor = 8, paddle = 3 } -- degrees into a turn at full steer
BoatFeel.LEAN_FULL_SPEED = 0.5 -- the lean is full from this share of top speed up
BoatFeel.STROKE_ROLL = 1.0 -- degrees the canoe rolls toward each stroke

local function smooth(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

local function kindOf(boatId: string): string
	return if boatId == "Canoe" then "paddle" else "motor"
end
BoatFeel.kindOf = kindOf

-- Bow-up degrees at this share of top speed (0 to 1): nothing below 10 percent, up to the peak
-- as it passes 40 percent, settling to the plane figure by 85 percent.
function BoatFeel.trim(boatId: string, speedFrac: number): number
	local c = BoatFeel.TRIM[kindOf(boatId)]
	local s = math.clamp(math.abs(speedFrac), 0, 1)
	if s <= c.peakAt then
		return c.peak * smooth(c.start, c.peakAt, s)
	end
	return c.peak + (c.plane - c.peak) * smooth(c.peakAt, c.planeAt, s)
end

-- Roll into a turn. turn: -1 (hard left) to 1 (hard right); right turns put the starboard side
-- down (a negative roll). Grows with speed up to LEAN_FULL_SPEED.
function BoatFeel.lean(boatId: string, turn: number, speedFrac: number): number
	local full = math.clamp(math.abs(speedFrac) / BoatFeel.LEAN_FULL_SPEED, 0, 1)
	return -math.clamp(turn, -1, 1) * BoatFeel.LEAN_MAX[kindOf(boatId)] * full
end

-- The turn (-1 to 1) from the hull's yaw rate in radians a second (negative turning right) and
-- the boat's top turn rate in degrees a second.
function BoatFeel.turnFromYawRate(yawRate: number, turnRateDeg: number): number
	if turnRateDeg <= 0 then
		return 0
	end
	return math.clamp(-math.deg(yawRate) / turnRateDeg, -1, 1)
end

----------------------------------------------------------------------------------------
-- Bob

-- At rest, with the waves. The canoe's is capped so the drawn floor never dips more than 0.2
-- studs (CANOE_DIP_MAX; its inside floor is only 0.22 above the waterline).
BoatFeel.BOB = {
	motor = { heave = 0.15, pitch = 1.5, roll = 1.5 },
	paddle = { heave = 0.12, pitch = 0.6, roll = 1.0 },
}
BoatFeel.BOB_BLUE = 2 -- twice the bob in blue water
BoatFeel.BOB_AT_SPEED = 0.5 -- share of the bob left at full speed (the hull cuts through)
BoatFeel.BOB_PERIOD = { heave = 2.8, pitch = 3.4, roll = 2.3 } -- seconds
BoatFeel.CANOE_DIP_MAX = 0.2
BoatFeel.FLOOR_MIN = 0.02 -- the drawn floor is always kept this far above the water

export type Bob = { heave: number, pitch: number, roll: number }

-- The bob at time t (seconds), for this share of top speed. phase staggers boats.
function BoatFeel.bob(boatId: string, t: number, speedFrac: number, blue: boolean, phase: number?): Bob
	local c = BoatFeel.BOB[kindOf(boatId)]
	local k = (1 - (1 - BoatFeel.BOB_AT_SPEED) * math.clamp(math.abs(speedFrac), 0, 1)) * (if blue then BoatFeel.BOB_BLUE else 1)
	local p = phase or 0
	local P = BoatFeel.BOB_PERIOD
	local tau = 2 * math.pi
	return {
		heave = c.heave * k * math.sin(tau * t / P.heave + p),
		pitch = c.pitch * k * math.sin(tau * t / P.pitch + p * 1.7 + 0.8),
		roll = c.roll * k * math.sin(tau * t / P.roll + p * 0.6 + 2.1),
	}
end

-- The lowest point of the drawn inside floor, in studs above the water, for a pose. The pose is
-- applied as the client draws it: trim about the stern (trimPivotZ), then the bob's pitch about
-- the middle, then roll about the keel, then heave.
function BoatFeel.floorLow(a: Art, heave: number, trimDeg: number, pitchDeg: number, rollDeg: number): number
	local f = a.floor
	local ct, st = math.cos(math.rad(trimDeg)), math.sin(math.rad(trimDeg))
	local cp, sp = math.cos(math.rad(pitchDeg)), math.sin(math.rad(pitchDeg))
	local cr, sr = math.cos(math.rad(rollDeg)), math.sin(math.rad(rollDeg))
	local low = math.huge
	for iz = -4, 4 do
		local z = f.halfL * iz / 4
		for _, x in { -f.halfW, 0, f.halfW } do
			local y = f.y + f.rocker * z * z
			-- trim about the stern
			local zr = z - a.trimPivotZ
			local y1 = y * ct - zr * st
			local z1 = y * st + zr * ct + a.trimPivotZ
			-- bob pitch about the middle
			local y2 = y1 * cp - z1 * sp
			-- roll about the keel
			local y3 = x * sr + y2 * cr
			low = math.min(low, y3 + heave)
		end
	end
	return low
end

-- How far the drawn floor has dropped from where it sits level (0 when nothing went lower).
function BoatFeel.floorDip(a: Art, heave: number, trimDeg: number, pitchDeg: number, rollDeg: number): number
	return math.max(0, BoatFeel.floorLow(a, 0, 0, 0, 0) - BoatFeel.floorLow(a, heave, trimDeg, pitchDeg, rollDeg))
end

-- The heave to draw: as asked, raised just enough that the floor stays FLOOR_MIN above the water
-- (a hard lean on the dinghy lifts the hull a little rather than flooding it on screen).
function BoatFeel.settle(a: Art, heave: number, trimDeg: number, pitchDeg: number, rollDeg: number): number
	local low = BoatFeel.floorLow(a, heave, trimDeg, pitchDeg, rollDeg)
	if low < BoatFeel.FLOOR_MIN then
		return heave + (BoatFeel.FLOOR_MIN - low)
	end
	return heave
end

----------------------------------------------------------------------------------------
-- Paddling (the canoe)

BoatFeel.STROKE_SECONDS = 1.2 -- one stroke at full speed
BoatFeel.STROKE_SLOWEST = 0.5 -- share of the full stroke rate when barely moving
BoatFeel.PADDLE_MIN_SPEED = 0.5 -- studs a second: slower than this, nobody paddles
BoatFeel.PULL = 0.35 -- share of a stroke the blade is in the water

-- Strokes a second at this share of top speed (0 when stopped).
function BoatFeel.strokeRate(speed: number, top: number): number
	if math.abs(speed) < BoatFeel.PADDLE_MIN_SPEED or top <= 0 then
		return 0
	end
	local s = math.clamp(math.abs(speed) / top, 0, 1)
	return (BoatFeel.STROKE_SLOWEST + (1 - BoatFeel.STROKE_SLOWEST) * s) / BoatFeel.STROKE_SECONDS
end

-- The canoe's roll toward the stroke side (side 1 starboard, -1 port) at stroke phase 0 to 1:
-- the starboard side dips while the blade pulls on the starboard side.
function BoatFeel.strokeRoll(phase: number, side: number): number
	local p = phase % 1
	if p >= BoatFeel.PULL then
		return 0
	end
	return -side * BoatFeel.STROKE_ROLL * math.sin(math.pi * p / BoatFeel.PULL)
end

-- The paddle shaft's direction, grip to blade, in boat space (a unit vector): in the pull the
-- blade is down in the water and sweeps from ahead of the paddler to behind; in the recovery it
-- comes out low and swings forward again.
function BoatFeel.paddleDir(phase: number, side: number): Vector3
	local p = phase % 1
	local v: Vector3
	if p < BoatFeel.PULL then
		local u = p / BoatFeel.PULL
		v = Vector3.new(side * 0.55, -1, -0.7 + 1.2 * u)
	else
		local u = (p - BoatFeel.PULL) / (1 - BoatFeel.PULL)
		v = Vector3.new(side * 0.9, -0.35, 0.5 - 1.2 * u)
	end
	return v.Unit
end

-- The simple arm pose for paddling (a first pose, not an animation): degrees each shoulder is
-- raised forward. The lower hand (on the stroke side) reaches forward and pulls back; the upper
-- hand stays high over the grip.
function BoatFeel.paddleArms(phase: number): (number, number)
	local p = phase % 1
	local reach
	if p < BoatFeel.PULL then
		reach = 1 - p / BoatFeel.PULL
	else
		reach = (p - BoatFeel.PULL) / (1 - BoatFeel.PULL)
	end
	local lower = 25 + 50 * reach
	local upper = 80 + 30 * reach
	return lower, upper
end

-- Holding a rod in a seat: the rod arm forward and a little up, the other resting.
BoatFeel.ROD_ARM = 40
BoatFeel.ROD_ELBOW = 30

----------------------------------------------------------------------------------------
-- Wake

BoatFeel.KELVIN = math.tan(math.rad(19.47)) -- the wake's arms spread at this share of the speed
BoatFeel.WAKE = {
	motor = { from = 0.08, life = 1.6, every = 0.1, w0 = 0.6, w1 = 1.2, w1Speed = 2.6, alpha0 = 0.35, alphaSlow = 0.4 },
	paddle = { from = 0.08, life = 1.2, every = 0.12, w0 = 0.12, w1 = 0.4, w1Speed = 0.2, alpha0 = 0.55, alphaSlow = 0.25 },
}
BoatFeel.WAKE_PHONE = { life = 0.6, every = 2 } -- the phone tier: 60 percent of the life, half as many pieces
BoatFeel.SPRAY_FROM = 0.6 -- spray at the bow above this share of top speed (motor boats only)
BoatFeel.SPRAY_RATE = 30 -- particles a second at full speed (desktop)
BoatFeel.WASH_RATE = 25 -- the stern's churn, particles a second at full speed (desktop)
BoatFeel.PHONE_RATE = 0.4 -- the phone tier's share of each particle rate
BoatFeel.SWIRLS = 2 -- swirl rings per paddle stroke
BoatFeel.SWIRL_LIFE = 1.6
BoatFeel.SWIRL_SIZE = { 0.3, 1.4 }

-- How many wake pieces each arm keeps on this tier.
function BoatFeel.wakePieces(boatId: string, tier: string?): number
	local w = BoatFeel.WAKE[kindOf(boatId)]
	local life, every = w.life, w.every
	if tier == "phone" then
		life *= BoatFeel.WAKE_PHONE.life
		every *= BoatFeel.WAKE_PHONE.every
	end
	return math.max(2, math.ceil(life / every))
end

-- One wake piece's width and transparency at `age` seconds, left by a boat at speedFrac.
-- nil once it has faded out (or when the boat was too slow to leave one).
function BoatFeel.wakePiece(boatId: string, age: number, speedFrac: number, tier: string?): (number?, number?)
	local w = BoatFeel.WAKE[kindOf(boatId)]
	local life = w.life * (if tier == "phone" then BoatFeel.WAKE_PHONE.life else 1)
	local s = math.clamp(math.abs(speedFrac), 0, 1)
	if s < w.from or age >= life or age < 0 then
		return nil, nil
	end
	local k = age / life
	local wEnd = w.w1 + w.w1Speed * s
	local width = w.w0 + (wEnd - w.w0) * k
	local a0 = w.alpha0 + w.alphaSlow * (1 - s)
	local alpha = a0 + (1 - a0) * k
	return width, alpha
end

-- How far a wake piece has spread out from where it was left, after `age` seconds at speed.
function BoatFeel.wakeSpread(speed: number, age: number): number
	return math.abs(speed) * BoatFeel.KELVIN * math.max(0, age)
end

-- Particle rates at this share of top speed: bow spray (motor boats over 60 percent) and wash.
function BoatFeel.sprayRate(boatId: string, speedFrac: number, tier: string?): number
	if kindOf(boatId) ~= "motor" then
		return 0
	end
	local s = math.clamp(math.abs(speedFrac), 0, 1)
	if s <= BoatFeel.SPRAY_FROM then
		return 0
	end
	local r = BoatFeel.SPRAY_RATE * (s - BoatFeel.SPRAY_FROM) / (1 - BoatFeel.SPRAY_FROM)
	return if tier == "phone" then r * BoatFeel.PHONE_RATE else r
end

function BoatFeel.washRate(boatId: string, speedFrac: number, tier: string?): number
	local s = math.clamp(math.abs(speedFrac), 0, 1)
	local r = BoatFeel.WASH_RATE * s * (if kindOf(boatId) == "paddle" then 0.3 else 1)
	return if tier == "phone" then r * BoatFeel.PHONE_RATE else r
end

----------------------------------------------------------------------------------------
-- Camera

BoatFeel.CAMERA = { back = 4, up = 1.5, fov = 6, tauUp = 0.8, tauDown = 1.2 }

-- Eases `current` toward `target`: up with time constant tauUp, down with tauDown (seconds).
function BoatFeel.approach(current: number, target: number, dt: number, tauUp: number, tauDown: number): number
	local tau = if target > current then tauUp else tauDown
	if tau <= 0 then
		return target
	end
	return current + (target - current) * (1 - math.exp(-dt / tau))
end

-- How far the camera moves back and up, and the field of view added, at this eased share of
-- top speed (0 to 1).
function BoatFeel.cameraFor(w: number): (number, number, number)
	local k = math.clamp(w, 0, 1)
	local c = BoatFeel.CAMERA
	return c.back * k, c.up * k, c.fov * k
end

----------------------------------------------------------------------------------------
-- Lights, horn and sounds

BoatFeel.LIGHT = { range = 8, brightness = 1.2 }
BoatFeel.LIGHT_COLORS = {
	red = Color3.fromRGB(255, 40, 30),
	green = Color3.fromRGB(40, 255, 90),
	white = Color3.fromRGB(255, 244, 220),
}
BoatFeel.HORN_SOUND = "server-horn" -- the stand-in in SoundSheets (no upload)
BoatFeel.HORN_GAP = 1.5 -- seconds between horns
BoatFeel.DIP_SOUND = "bobber-plop" -- a slowed, quiet plop for each paddle dip
BoatFeel.DIP_SPEED = 0.75
BoatFeel.DIP_VOLUME = 0.3

-- May this player sound the horn again (last: os.clock() of the last one, or nil)?
function BoatFeel.hornReady(last: number?, now: number): boolean
	return last == nil or now - last >= BoatFeel.HORN_GAP
end

return BoatFeel
