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
	scale: number?, -- Model:ScaleTo this on every copy (about its pivot, on the waterline); nil is 1
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
--
-- N4 review 2 (11/28/2026): the dinghy is drawn 1.375 times its model (`scale`; the avatar's
-- shoulders spanned its whole 4 stud beam), so every dinghy number below is its model's number
-- times DINGHY_SCALE. The lamps themselves are not scaled (0.16 balls in 0.1 housings), so a lamp
-- keeps its own gap to the surface it sits on: its point is the surface point scaled plus the old gap.
local DINGHY_SCALE = 1.375
BoatFeel.DINGHY_SCALE = DINGHY_SCALE
local function ds(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z) * DINGHY_SCALE
end
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
		-- On the stem heads' inner faces, just under the 1.75 tips (checked against the mesh, N4
		-- review 1: each ball touches the stem, 0.02 to 0.05 from its surface).
		lights = { red = Vector3.new(-0.18, 1.45, -5.9), green = Vector3.new(0.18, 1.45, -5.9), white = Vector3.new(0, 1.45, 5.9) },
		seats = { Helm = Vector3.new(0, 0.64, 3.0), Bow = Vector3.new(0, 0.64, -2.3) },
		paddle = { hero = "CanoePaddle", plain = "CanoePaddlePlain", hand = Vector3.new(0, 0, -2.2) },
	},
	Dinghy = {
		-- The re-skin (11/28/2026): pivot on the waterline, bow -Z. Art.DinghyHero and Art.DinghyPlain
		-- carry their outboard as a second part at (0, 1.00, 3.38) (the separate DinghyOutboard models
		-- wait for a tilting motor). Drawn at DINGHY_SCALE (N4 review 2): ScaleTo scales about the
		-- pivot, so the waterline stays put; the tubes then sit 0.30 into the water (was 0.22).
		hero = "DinghyHero",
		plain = "DinghyPlain",
		lift = 0,
		scale = DINGHY_SCALE,
		yaw = 0,
		trimPivotZ = 4.3 * DINGHY_SCALE,
		floor = { y = 0.27 * DINGHY_SCALE, halfW = 1.4 * DINGHY_SCALE, halfL = 3.3 * DINGHY_SCALE, rocker = 0 },
		bow = ds(0, 0.1, -4.1),
		stern = ds(0, 0.05, 4.6),
		halfBeam = 1.7 * DINGHY_SCALE,
		-- N4 review 1 (11/28/2026): the side lights on the tube crown (they floated 0.15 off the bow
		-- at (+-0.6, 1.25, -3.9)), the stern light on the outboard's cowl top (2.18 at z 3.45; it
		-- floated 1.4 behind the motor at (0, 1.9, 4.5)). Measured against the meshes in
		-- art/models (DinghyHero.glb plus DinghyOutboard.glb at its pivot): every lamp's ball is
		-- within 0.05 of the surface (side lights 0.066 from it, the stern light 0.114, its housing
		-- resting on the cowl). N4 review 2: the surfaces scaled, the gaps kept (side lights 0.146
		-- from ball centre to the crown, the stern light 0.11 over the cowl top), so
		-- red/green (+-0.62, 1.788, -4.675) and white (0, 3.1075, 4.744).
		lights = {
			red = Vector3.new(-0.45 * DINGHY_SCALE, 1.194 * DINGHY_SCALE + 0.146, -3.4 * DINGHY_SCALE),
			green = Vector3.new(0.45 * DINGHY_SCALE, 1.194 * DINGHY_SCALE + 0.146, -3.4 * DINGHY_SCALE),
			white = Vector3.new(0, 2.18 * DINGHY_SCALE + 0.11, 3.45 * DINGHY_SCALE),
		},
		seats = { Helm = ds(0, 0.8, 0.7) }, -- on the bench, (0, 1.1, 0.9625) (the passenger keeps the server's seat)
	},
	DeepV = {
		hero = "DeepV",
		plain = "DeepV",
		-- Its pivot is the middle of its bounding box (7.19 x 4.14 x 17.75; Studio measured the
		-- skeg 2.07 under the pivot). From art/models/DeepV.glb: the skeg is 2.07 under the box
		-- middle, the hull's keel 1.94 under, the deck top 0.74 under and the gunwale 0.83 over.
		-- The water line is put 0.5 under the deck top (floor.y below), so the pivot rides 1.24
		-- over the water: keel 0.70 down, gunwale 2.07 up. (Was -0.6, a guess that
		-- sank it to the stripe: the skeg at -2.67 at the mooring, 11/28/2026.)
		lift = 1.24,
		yaw = 0,
		trimPivotZ = 8.5,
		floor = { y = 0.5, halfW = 2.8, halfL = 7, rocker = 0 },
		bow = Vector3.new(0, 0.3, -8.6),
		stern = Vector3.new(0, 0.05, 8.6),
		halfBeam = 3.0,
		-- N4 review 1: on the hull. The side lights sit on the foredeck behind the stem (its top 2.07
		-- at z -7.2 to -7.4), the stern light on the motor's top (2.17 at z 8.2); they floated
		-- 0.24 and 1.36 off it (the old white at y 3.6 was over the model's box).
		lights = { red = Vector3.new(-0.9, 2.18, -7.3), green = Vector3.new(0.9, 2.18, -7.3), white = Vector3.new(0, 2.28, 8.2) },
	},
} :: { [string]: Art }

-- Each boat's drawn art as a box in boat space (min, max), from art/models/manifest.json and the
-- GLBs: the canoe's box (3.18 x 1.97 x 12.52, waterline 0.22 over its keel); the dinghy's hull box
-- (4 x 1.52 x 8, waterline 0.22 over its tubes' bottom) grown to hold its outboard placed at
-- (0, 1.00, 3.38) (the motor reaches y -1.12 to 2.18, z 1.61 to 4.40); the Deep-V's box (7.19 x
-- 4.14 x 17.75) about its pivot, 1.24 over the water (lift). A lamp outside its boat's box floats
-- in the air (the spec checks every lamp's gap to the box is under LAMP_GAP).
BoatFeel.ART_BOX = {
	Canoe = { min = Vector3.new(-1.59, -0.22, -6.258), max = Vector3.new(1.59, 1.747, 6.258) },
	Dinghy = { min = ds(-2, -1.12, -4), max = ds(2, 2.18, 4.4) }, -- 5.5 x 4.54 x 11.55 at DINGHY_SCALE (z -5.5 to 6.05)
	DeepV = { min = Vector3.new(-3.595, -0.83, -8.875), max = Vector3.new(3.595, 3.31, 8.875) },
} :: { [string]: { min: Vector3, max: Vector3 } }
BoatFeel.LAMP_RADIUS = 0.08 -- the lamp ball (0.16 across)
BoatFeel.LAMP_GAP = 0.05

-- How far a lamp's ball is from its boat's box (0 when it touches or is inside it).
function BoatFeel.lampGap(boatId: string, pos: Vector3): number
	local b = BoatFeel.ART_BOX[boatId]
	local dx = math.max(b.min.X - pos.X, 0, pos.X - b.max.X)
	local dy = math.max(b.min.Y - pos.Y, 0, pos.Y - b.max.Y)
	local dz = math.max(b.min.Z - pos.Z, 0, pos.Z - b.max.Z)
	return math.max(0, math.sqrt(dx * dx + dy * dy + dz * dz) - BoatFeel.LAMP_RADIUS)
end

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

-- Legs in a boat (N4 review 1, 11/28/2026): Roblox's sit hangs the shins straight down from the
-- knee, and in the canoe (seat 0.64 over the water, floor 0.22) they poked through the floor.
-- Each R15 knee is straightened from the sit's bend, starting at KNEE_START degrees and going
-- up in KNEE_STEP until no leg part sits under the boat's floor.y (legLow below; the client also
-- checks the real leg parts each frame and straightens further if one is still under).
-- A plain R15 model of a seated leg: the thigh lies level forward from the hip, its middle LEG.half
-- over the seat top; the sit bends the knee LEG.sitBend degrees; the shin and foot hang from the
-- knee, LEG.shin + LEG.foot long and LEG.half thick (R15 blocky: lower leg 1.19, foot 0.3, 1 wide).
BoatFeel.LEG = { half = 0.5, shin = 1.2, foot = 0.3, sitBend = 90 }
BoatFeel.KNEE_START = 70
BoatFeel.KNEE_STEP = 5
BoatFeel.KNEE_MAX = 100 -- past straight by 10, for a sit that bends the knee more than 90

-- The lowest point of the shin and foot (studs, boat space) for a seat top at seatY with the knee
-- straightened by `straighten` degrees from the sit.
function BoatFeel.legLow(seatY: number, straighten: number): number
	local L = BoatFeel.LEG
	local kneeY = seatY + L.half
	local bend = math.rad(math.clamp(L.sitBend - straighten, 0, 180))
	return kneeY - (L.shin + L.foot) * math.sin(bend) - L.half * math.abs(math.cos(bend))
end

-- How far to straighten the knees (degrees) so the legs clear a floor at floorY: from KNEE_START
-- up by KNEE_STEP until legLow is at or over the floor, at most KNEE_MAX.
function BoatFeel.kneeStraighten(seatY: number, floorY: number): number
	local s = BoatFeel.KNEE_START
	while s < BoatFeel.KNEE_MAX and BoatFeel.legLow(seatY, s) < floorY do
		s += BoatFeel.KNEE_STEP
	end
	return math.min(s, BoatFeel.KNEE_MAX)
end

----------------------------------------------------------------------------------------
-- Wake

BoatFeel.KELVIN = math.tan(math.rad(19.47)) -- the wake's arms spread at this share of the speed
-- 11/28/2026, after set C's dawn shot (c03: "a hard, straight, bright white ribbon with
-- rectangular tiles"): the arms are now soft Beams, as the creek's white water was redone
-- (CreekPlan.foamBeams). Each arm is a chain of points left at the stern's quarters; a Beam joins
-- each point to the next, so width and transparency run on without a seam. A point fades in over
-- `fadeIn` seconds (no hard head at the stern), holds its faint peak until `hold` of its life,
-- then fades out; the foam map's faded rows soften both long edges and its streaks scroll slowly
-- away from the boat. On a calm lake a wake is a soft pair of lines, so the peak is faint:
-- `base` is the transparency at the peak at full speed, `baseSlow` more at a crawl.
-- N4 review 1 (11/28/2026): set C's c03 read the wake as a fence of vertical ticks. A point is
-- now left every `step` studs the stern travels (not on a timer), the foam map repeats every
-- WAKE_TEX.length studs (the same 3), and each beam's Attachment0 is the older point, so every
-- beam shows one whole tile and the foam runs on unbroken from beam to beam. The motor wake is
-- brighter and longer (base 0.6 to 0.38, life 2.4 to 3.6, w0 0.35 to 0.5, w1 0.9 to 1.2,
-- w1Speed 1.2 to 1.6). The beams lie flat by their own setting, WAKE_BEAM_NORMAL.
-- N4 review 2 (11/28/2026): the motor wake's peak fainter again (base 0.38 to 0.55); the soft
-- puffs (WAKE_PUFF) carry the white now, and the whole wake fades with the boat (wakeGain).
-- N4 review 3 (11/28/2026, final): review 2 left the wake too faint to see while moving. The
-- motor wake's peak 0.55 to 0.40 and its fade-in 0.25 to 0.10 s (the gain still clears it at rest).
BoatFeel.WAKE = {
	motor = { from = 0.08, life = 3.6, step = 3, w0 = 0.5, w1 = 1.2, w1Speed = 1.6, base = 0.40, baseSlow = 0.2, fadeIn = 0.10, hold = 0.3 },
	paddle = { from = 0.08, life = 1.8, step = 3, w0 = 0.08, w1 = 0.22, w1Speed = 0.12, base = 0.72, baseSlow = 0.15, fadeIn = 0.3, hold = 0.3 },
}
BoatFeel.WAKE_PHONE = { life = 0.6, step = 2 } -- the phone tier: 60 percent of the life, a point every 6 studs (half as many)
-- Which attachment axis is the wake beams' face normal (FaceCamera off). The wake's own setting,
-- apart from CreekPlan.FOAM_BEAM_NORMAL (the creek foam, which Studio showed lying flat with "Y"):
-- "Y" points every wake attachment's Y straight up and lays the width along its Z, so the beam
-- lies flat on the water. If a capture shows the wake on edge, set "Z" (one edit, wake only).
BoatFeel.WAKE_BEAM_NORMAL = "Y"
BoatFeel.WAKE_Y = 0.1 -- the beams' height over the water (y 0, its chop about 0.06), as the creek's
BoatFeel.WAKE_ZOFFSET = 0.05 -- studs toward the camera, so the chop's crests never cut a beam
BoatFeel.WAKE_START = { beam = 0.8, aft = 0.5 } -- an arm starts at this share of halfBeam out, this far forward of the stern
BoatFeel.WAKE_TEX = { length = 3, drift = 0.6 } -- studs per tile of the foam map (= WAKE.step); studs a second it scrolls at full speed
BoatFeel.SPRAY_FROM = 0.6 -- spray at the bow above this share of top speed (motor boats only)
BoatFeel.SPRAY_RATE = 30 -- particles a second at full speed (desktop)
BoatFeel.WASH_RATE = 16 -- the stern's churn, particles a second at full speed (desktop)
-- The wash and the swirl rings are soft round puffs (the spray map) lying on the water, never
-- the foam map's square tiles; each fades in and ends clear.
-- N4 review 3: the wash's peak 0.72 to 0.5 and its life 0.9-1.5 to 0.6-1.0 (brighter, shorter).
BoatFeel.WASH = { life = { 0.6, 1.0 }, size = { 0.6, 2.2 }, transparency = { 0.5, 1 } }
-- How much the scene's light dims the foam (the wake beams and every boat particle). 1 was lit
-- exactly like the water, which hid the white at dusk; 0.75 keeps a little of its own white.
-- Tune between 0.6 and 0.9 (spec); 0 would glow at night.
BoatFeel.FOAM_LIGHT_INFLUENCE = 0.75
BoatFeel.PHONE_RATE = 0.4 -- the phone tier's share of each particle rate
BoatFeel.SWIRLS = 2 -- swirl rings per paddle stroke
BoatFeel.SWIRL_LIFE = 1.6
BoatFeel.SWIRL_SIZE = { 0.3, 1.4 }
BoatFeel.SWIRL_TRANSPARENCY = { 0.65, 1 }

local function wakeLife(boatId: string, tier: string?): number
	return BoatFeel.WAKE[kindOf(boatId)].life * (if tier == "phone" then BoatFeel.WAKE_PHONE.life else 1)
end

-- Studs the stern travels between the points an arm leaves, on this tier.
function BoatFeel.wakeStep(boatId: string, tier: string?): number
	return BoatFeel.WAKE[kindOf(boatId)].step * (if tier == "phone" then BoatFeel.WAKE_PHONE.step else 1)
end

-- How many points each arm keeps on this tier at this top speed (each arm draws this many beams:
-- one from the live point at the stern to the newest, then one between each pair): enough for a
-- whole life at top speed.
function BoatFeel.wakePieces(boatId: string, tier: string?, topSpeed: number): number
	return math.max(2, math.ceil(wakeLife(boatId, tier) * topSpeed / BoatFeel.wakeStep(boatId, tier)))
end

-- Where the next wake points go along the stern's path: from the last point `last` toward the
-- stern's point now `head`, one every `step` studs. Returns the new points (oldest first) and the
-- new last point. Exactly `step` apart, so each beam is one whole tile of the foam map.
function BoatFeel.wakeDrops(last: Vector3, head: Vector3, step: number): ({ Vector3 }, Vector3)
	local out: { Vector3 } = {}
	local d = head - last
	local dist = d.Magnitude
	if step <= 0 or dist < step then
		return out, last
	end
	local dir = d / dist
	local n = math.min(math.floor(dist / step), 32)
	for i = 1, n do
		table.insert(out, last + dir * (step * i))
	end
	return out, last + dir * (step * n)
end

-- A wake attachment's frame axes (rightVector, upVector for CFrame.fromMatrix) at a point whose
-- arm runs along `along`: X level along the arm, and the face normal as WAKE_BEAM_NORMAL says
-- ("Y": the attachment's Y straight up, so the beam lies flat).
function BoatFeel.wakeAxes(along: Vector3): (Vector3, Vector3)
	local fwd = Vector3.new(along.X, 0, along.Z)
	if fwd.Magnitude < 1e-4 then
		fwd = Vector3.new(0, 0, 1)
	end
	fwd = fwd.Unit
	if BoatFeel.WAKE_BEAM_NORMAL == "Z" then
		return fwd, Vector3.new(-fwd.Z, 0, fwd.X) -- Y across the arm, so Z (X cross Y) is vertical
	end
	return fwd, Vector3.yAxis
end

-- One wake point's width and transparency at `age` seconds, left by a boat at speedFrac.
-- Transparency is 1 at age 0 (it fades in at the stern), down to the peak by fadeIn, and back to
-- 1 at the end of its life. nil once it has gone (or when the boat was too slow to leave one).
function BoatFeel.wakePiece(boatId: string, age: number, speedFrac: number, tier: string?): (number?, number?)
	local w = BoatFeel.WAKE[kindOf(boatId)]
	local life = wakeLife(boatId, tier)
	local s = math.clamp(math.abs(speedFrac), 0, 1)
	if s < w.from or age >= life or age < 0 then
		return nil, nil
	end
	local k = age / life
	local wEnd = w.w1 + w.w1Speed * s
	local width = w.w0 + (wEnd - w.w0) * k
	local base = math.min(1, w.base + w.baseSlow * (1 - s))
	local kIn = smooth(0, w.fadeIn, age)
	local kOut = smooth(life * w.hold, life, age)
	local alpha = 1 - (1 - base) * kIn * (1 - kOut)
	return width, alpha
end

-- Where an arm starts, in boat space: at the stern's quarter on this side (1 starboard, -1 port),
-- a little forward of the stern so the hull hides the fade-in.
function BoatFeel.wakeStart(a: Art, side: number): Vector3
	local st = BoatFeel.WAKE_START
	return Vector3.new(side * a.halfBeam * st.beam, 0, a.stern.Z - st.aft)
end

-- How fast the foam map drifts (cycles a second) away from the boat along the arm. Each beam's
-- Attachment0 is the older point, so the client sets the beams' TextureSpeed to minus this.
function BoatFeel.wakeTextureSpeed(speedFrac: number): number
	local t = BoatFeel.WAKE_TEX
	return t.drift * math.clamp(math.abs(speedFrac), 0, 1) / t.length
end

-- N4 review 2 (11/28/2026): the wake lingered on still water after the boat stopped (each point
-- lives out its whole life). Now the whole wake, every beam of both arms, is scaled by a gain that
-- follows the boat's speed: nothing under 8 percent of top speed, full from 33 percent, eased up
-- over 0.25 s and down over 0.3 s, so it is gone (under 0.05) about a second after a stop.
BoatFeel.WAKE_GAIN = { from = 0.08, span = 0.25, tauUp = 0.25, tauDown = 0.3 }

-- The gain the wake heads for at this share of top speed (0 to 1).
function BoatFeel.wakeGainTarget(speedFrac: number): number
	local g = BoatFeel.WAKE_GAIN
	return math.clamp((math.abs(speedFrac) - g.from) / g.span, 0, 1)
end

-- The gain after `dt` seconds, eased from `current` toward the target for this speed.
function BoatFeel.wakeGainStep(current: number, speedFrac: number, dt: number): number
	local g = BoatFeel.WAKE_GAIN
	return BoatFeel.approach(current, BoatFeel.wakeGainTarget(speedFrac), dt, g.tauUp, g.tauDown)
end

-- A beam end's transparency under the gain: 1 - (1 - tr) * gain (clear at gain 0).
function BoatFeel.gained(tr: number, gain: number): number
	return 1 - (1 - tr) * math.clamp(gain, 0, 1)
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

-- N4 review 2 (11/28/2026), motor boats only. Flat puffs of the spray map lying on the water at
-- both wake start points (the arms' heads), so the wake starts soft and white, not as two lines.
-- N4 review 3: peak 0.6 to 0.4, life 1.0-1.5 to 0.7-1.0.
BoatFeel.WAKE_PUFF = { rate = 14, life = { 0.7, 1.0 }, size = { 0.5, 2.2 }, transparency = 0.4 }
-- And a camera-facing spray thrown up and aft off the stern above 30 percent of top speed:
-- `angle` degrees from straight up toward the stern.
BoatFeel.STERN_SPRAY = { from = 0.3, rate = 22, speed = { 2, 4 }, angle = 55, life = { 0.35, 0.6 }, size = { 0.5, 1.3 } }

-- Puffs a second at each wake start point (motor boats; 0 for the canoe).
function BoatFeel.puffRate(boatId: string, speedFrac: number, tier: string?): number
	if kindOf(boatId) ~= "motor" then
		return 0
	end
	local r = BoatFeel.WAKE_PUFF.rate * math.clamp(math.abs(speedFrac), 0, 1)
	return if tier == "phone" then r * BoatFeel.PHONE_RATE else r
end

-- Stern spray particles a second (motor boats over STERN_SPRAY.from; 0 otherwise).
function BoatFeel.sternSprayRate(boatId: string, speedFrac: number, tier: string?): number
	local s = math.clamp(math.abs(speedFrac), 0, 1)
	if kindOf(boatId) ~= "motor" or s <= BoatFeel.STERN_SPRAY.from then
		return 0
	end
	local r = BoatFeel.STERN_SPRAY.rate * s
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

-- N4 review 2 (11/28/2026): in any boat seat the camera may come no nearer than `minZoom` (the
-- Deep-V `minZoomDeepV`) and looks from `offset` over the humanoid's usual focus, so the boat is
-- always in the frame. Put back on every exit (leaving the seat, death, the boat despawning).
BoatFeel.SEAT_CAMERA = { minZoom = 14, minZoomDeepV = 20, offset = Vector3.new(0, 1.5, 0) }

-- Player.CameraMinZoomDistance while seated in this boat.
function BoatFeel.seatMinZoom(boatId: string): number
	local c = BoatFeel.SEAT_CAMERA
	return if boatId == "DeepV" then c.minZoomDeepV else c.minZoom
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

-- N4 review 1 (11/28/2026): the side lights were too strong (1.2, range 8, saturated 255,40,30
-- and 40,255,90) and lit the water round the bow. Now each light has its own numbers, softer
-- colours, and the lamps sit in dark housings.
BoatFeel.LIGHT = {
	red = { brightness = 0.35, range = 4 },
	green = { brightness = 0.35, range = 4 },
	white = { brightness = 0.3, range = 4.5 }, -- N4 review 2: was 0.8, range 7 (its glint on the water read as foam at rest)
}
BoatFeel.LIGHT_COLORS = {
	red = Color3.fromRGB(232, 70, 52),
	green = Color3.fromRGB(70, 200, 120),
	white = Color3.fromRGB(255, 244, 220),
}
-- The housing: a dark cup the lamp ball sits in (a flat cylinder, its top at the ball's middle),
-- so the lamp reads as a fitting on the boat, not a loose glowing bead.
BoatFeel.LAMP_HOUSING = { color = Color3.fromRGB(34, 34, 36), diameter = 0.22, height = 0.1 }
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
