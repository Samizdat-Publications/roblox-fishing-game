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
--
-- Tells (L4b): a big move (a runner's or shaker's run, a jumper's leap, a diver's dive) winds
-- up for Config.TELL_LEAD seconds before it shows on the bar, so the client can warn on the
-- water (drag scream, splash, rod dip) and the player can get ready. FightModel.tell says
-- which move is coming and how soon; `tells` counts them and `darts` counts ordinary darts
-- (a tugger's twitch), so the client can spot a new one. UNVERIFIED in Studio (2026-11-26).
--
-- Line and drag (L4d): the drag setting ("Light", "Medium", "Tight") can change any time
-- (FightModel.setDrag). Medium is the fight exactly as it was before L4d: same steps for the
-- same seed and inputs (FightModel.spec checks a recorded trace). Tight fills progress faster
-- (Config.DRAG_TIGHT_GAIN); Light fills slower and a running fish takes line (DRAG_LIGHT_TAKE).
-- `load` is the fish's weight over the line's rating (RodData.lineLoad). Reeling through a
-- big move (from its tell until it ends) builds `strain` when the load is past the drag's
-- free share; strain at 1 snaps the line and step returns "snapped". Light never snaps.
-- Numbers in Config (DRAG_*, STRAIN_*). UNVERIFIED in Studio (2026-11-27).
local Shared = script.Parent
local Config = require(Shared.Config)
local FishData = require(Shared.FishData)

export type Drag = "Light" | "Medium" | "Tight"

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
	mode: string, -- "normal", or a style move in progress: "run", "rest", "jump", "dive"
	modeTimer: number,
	pending: string?, -- a big move winding up ("run", "jump", "dive"); it starts when pendingTimer runs out
	pendingTimer: number,
	pendingTarget: number, -- where a dive is headed (runs and jumps pick their end when they start)
	tells: number, -- big moves warned so far
	darts: number, -- ordinary darts so far
	drag: Drag, -- L4d
	load: number, -- the fish's weight over the line's rating; 0 never strains the line
	strain: number, -- 0 to 1; the line snaps at 1
	usedTight: boolean, -- the drag was Tight at some point (the server checks a win's time against Tight's minimum)
	tapTimer: number, -- a fresh press counts as reeling (for strain) this many seconds more
}

local MODE_SPEED = { normal = 1, run = 1.7, rest = 0.45, jump = 2.2, dive = 1.5 }
local MODE_TIME = { run = 1.0, jump = 0.9, dive = 0.8 } -- seconds each big move lasts
local DIVE_DROP = 0.2 -- a diver's dart this far down (bar heights) is a dive, warned like a run
local SHAKE_SIZE = 0.045 -- how far a shaker's head shakes move it on the bar
local SHAKE_RATE = 24 -- radians per second

local FightModel = {}

-- The drag settings in the order the drag button cycles them (L4d).
local DRAGS: { Drag } = { "Light", "Medium", "Tight" }
FightModel.DRAGS = DRAGS

-- Each drag's progress fill multiplier, line taken per second while a big move runs, and its
-- strain rule (strain rises at rise x (load - free) per second, see Config).
local DRAG: { [string]: { gain: number, take: number, free: number, rise: number } } = {
	Light = { gain = Config.DRAG_LIGHT_GAIN, take = Config.DRAG_LIGHT_TAKE, free = math.huge, rise = 0 },
	Medium = { gain = 1, take = 0, free = Config.STRAIN_FREE_MEDIUM, rise = Config.STRAIN_RISE_MEDIUM },
	Tight = { gain = Config.DRAG_TIGHT_GAIN, take = 0, free = Config.STRAIN_FREE_TIGHT, rise = Config.STRAIN_RISE_TIGHT },
}

-- Fight styles that make big moves (runs, jumps, dives). Only these can snap a line.
local BIG_MOVE_STYLES: { [string]: boolean } = { runner = true, jumper = true, diver = true, shaker = true }
FightModel.BIG_MOVE_STYLES = BIG_MOVE_STYLES

function FightModel.isDrag(d: any): boolean
	return type(d) == "string" and DRAG[d] ~= nil
end

-- The next drag setting after `d`: Light, Medium, Tight, then back to Light.
function FightModel.nextDrag(d: Drag): Drag
	local i = table.find(DRAGS, d) or 2
	return DRAGS[(i % #DRAGS) + 1]
end

-- Strain per second while reeling through a big move with this load and drag (0: never).
function FightModel.strainRise(load: number, drag: Drag): number
	local d = DRAG[drag] or DRAG.Medium
	if d.rise <= 0 or load <= d.free then
		return 0
	end
	return math.min(Config.STRAIN_RISE_MAX, d.rise * (load - d.free))
end

-- `start` is where the progress bar begins: Config.FIGHT_START, or higher for a well-baited
-- hook (BaitRig.fightStart, L3). `load` (L4d): the fish's weight over the line's rating
-- (RodData.lineLoad); nil or 0 never strains the line. `drag`: the setting to start on.
function FightModel.new(profile: FishData.FightProfile, assist: boolean, seed: number, start: number?, load: number?, drag: Drag?): State
	local rng = Random.new(seed)
	local d: Drag = if drag and DRAG[drag] then drag else "Medium"
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
		progress = start or Config.FIGHT_START,
		t = 0,
		idle = math.huge, -- nothing counts until the player first presses or holds
		mode = "normal",
		modeTimer = 0,
		pending = nil,
		pendingTimer = 0,
		pendingTarget = 0.5,
		tells = 0,
		darts = 0,
		drag = d,
		load = math.max(0, load or 0),
		strain = 0,
		usedTight = d == "Tight",
		tapTimer = 0,
	}
end

-- Change the drag at any time during the fight (L4d).
function FightModel.setDrag(s: State, drag: Drag)
	if not DRAG[drag] then
		return
	end
	s.drag = drag
	if drag == "Tight" then
		s.usedTight = true
	end
end

-- True while a big move is winding up (its tell) or running: reeling now builds strain.
function FightModel.bigMove(s: State): boolean
	return s.pending ~= nil or s.mode == "run" or s.mode == "jump" or s.mode == "dive"
end

-- The fish starts winding up for a big move: it shows on the bar TELL_LEAD seconds from now.
local function windUp(s: State, move: string, target: number)
	s.pending = move
	s.pendingTimer = Config.TELL_LEAD
	s.pendingTarget = target
	s.tells += 1
end

local function climbFactor(p: FishData.FightProfile): number
	return 1 - p.heavy * 0.2
end

-- A fresh press (mouse down, tap, trigger pull): the zone starts climbing at once.
-- It sets a minimum speed rather than adding, so mashing can't fling the zone.
function FightModel.press(s: State)
	s.idle = 0
	s.tapTimer = Config.STRAIN_REEL_WINDOW
	s.zoneVel = math.max(s.zoneVel, Config.PRESS_KICK * climbFactor(s.profile))
end

-- Advance by dt seconds. Returns "won", "lost", "snapped" (L4d) or nil while the fight goes on.
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
	-- A wound-up move starts once its warning has run.
	local move = s.pending
	if move then
		s.pendingTimer -= dt
		if s.pendingTimer <= 0 then
			s.pending = nil
			if move == "run" then
				s.fishTarget = if s.fishPos > 0.5 then 0.08 else 0.92 -- a long run to the far end
			elseif move == "jump" then
				s.fishTarget = 0.95
			else
				s.fishTarget = s.pendingTarget
			end
			s.mode, s.modeTimer = move, MODE_TIME[move]
		end
	end
	if s.mode == "normal" and not s.pending and s.rng:NextNumber() < p.dart * dt then
		local offset = (s.rng:NextNumber() * 2 - 1) * p.range - p.sink * p.range * 0.5
		if style == "steady" then
			offset *= 0.6
		elseif style == "diver" then
			offset = if s.rng:NextNumber() < 0.15 then p.range else offset - p.range * 0.35 -- a surge, or more down
		end
		local target = math.clamp(s.fishPos + offset, 0.05, 0.95)
		if (style == "runner" or style == "shaker") and s.rng:NextNumber() < 0.35 then
			windUp(s, "run", target)
		elseif style == "diver" and target < s.fishPos - DIVE_DROP then
			windUp(s, "dive", target)
		else
			s.fishTarget = target
			s.darts += 1
		end
	end
	if style == "jumper" and s.mode == "normal" and not s.pending and s.rng:NextNumber() < 0.2 * dt then
		windUp(s, "jump", 0.95)
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
	-- Drag (L4d): Medium's gain multiplier is exactly 1 and it takes no line, so its steps
	-- are bit-for-bit the fight before L4d.
	local drag = DRAG[s.drag] or DRAG.Medium
	if math.abs(s.fishPos - s.zonePos) <= half then
		if s.idle <= Config.FIGHT_IDLE_GRACE then
			s.progress += s.gain * drag.gain * dt
		else
			s.progress -= s.loss * 0.5 * dt
		end
	else
		s.progress -= s.loss * dt
	end
	if drag.take > 0 and (s.mode == "run" or s.mode == "jump" or s.mode == "dive") then
		s.progress -= drag.take * dt -- light drag: the running fish takes line
	end

	-- Strain (L4d): reeling (holding, or a press in the last STRAIN_REEL_WINDOW, so mashing
	-- counts) through a big move builds it; letting go drops it fast. At 1 the line snaps.
	local reeling = holding or s.tapTimer > 0
	s.tapTimer = math.max(0, s.tapTimer - dt)
	local rise = FightModel.strainRise(s.load, s.drag)
	if reeling and rise > 0 and FightModel.bigMove(s) then
		s.strain += rise * dt
	elseif s.strain > 0 then
		s.strain = math.max(0, s.strain - (if reeling then Config.STRAIN_FALL_REELING else Config.STRAIN_FALL_EASE) * dt)
	end
	if s.strain >= 1 then
		s.strain = 1
		return "snapped"
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

-- The big move the fish is winding up for ("run", "jump", "dive") and the seconds until it
-- shows on the bar, or nil and 0 when none is coming.
function FightModel.tell(s: State): (string?, number)
	if s.pending then
		return s.pending, math.max(s.pendingTimer, 0)
	end
	return nil, 0
end

-- True while the fish sits inside the catch zone (the UI turns the zone green).
function FightModel.inside(s: State): boolean
	return math.abs(s.fishPos - s.zonePos) <= s.zoneSize / 2
end

-- The fastest a fight can possibly be won. The server rejects wins that come sooner. With
-- `drag` "Tight" (L4d) it is shorter: a fight that was Tight at any point is checked
-- against it. Medium and Light (slower) use the Medium time.
function FightModel.minSeconds(profile: FishData.FightProfile, _assist: boolean, start: number?, drag: Drag?): number
	local mult = if drag == "Tight" then DRAG.Tight.gain else 1
	return (1 - (start or Config.FIGHT_START)) / (profile.gain * mult)
end

-- The fastest the line can possibly snap: a big move from the first moment, reeled through.
function FightModel.minSnapSeconds(load: number, drag: Drag): number
	local rise = FightModel.strainRise(load, drag)
	return if rise > 0 then 1 / rise else math.huge
end

-- Can a fight end in a snap the way the client says (L4d)? The fish must make big moves, the
-- drag must be able to snap a fish this heavy for this line, and strain must have had time to
-- build (with the same 10 percent slack the server gives a win's time).
function FightModel.snapPlausible(style: string?, load: number, drag: any, elapsed: number): boolean
	if not FightModel.BIG_MOVE_STYLES[style or "tugger"] or not FightModel.isDrag(drag) then
		return false
	end
	local least = FightModel.minSnapSeconds(load, drag)
	return least < math.huge and elapsed >= least * 0.9
end

-- What the server needs to judge a fight's end, worked out when the fish is hooked.
export type Check = { minSecs: number, minSecsTight: number, style: string, load: number }

function FightModel.checkFor(profile: FishData.FightProfile, start: number?, load: number): Check
	return {
		minSecs = FightModel.minSeconds(profile, false, start),
		minSecsTight = FightModel.minSeconds(profile, false, start, "Tight"),
		style = profile.style or "tugger",
		load = load,
	}
end

-- The server's verdict on how the client says the fight ended (L4d). `claim` is "won",
-- "lost" or "snapped" (true still means won, from older clients); `report` is the client's
-- { tight = used Tight drag at some point, drag = drag at the end }. Returns "won",
-- "snapped" or "lost", and why a claim was refused (nil when it was taken as said).
function FightModel.judge(check: Check, claim: any, report: any, elapsed: number): (string, string?)
	local tight = type(report) == "table" and report.tight == true
	local drag = if type(report) == "table" then report.drag else nil
	if claim == true or claim == "won" then
		local least = if tight then check.minSecsTight else check.minSecs
		if elapsed < least * 0.9 then
			return "lost", string.format("win too fast (%.2fs < %.2fs%s)", elapsed, least, if tight then ", tight drag" else "")
		end
		return "won", nil
	elseif claim == "snapped" then
		if FightModel.snapPlausible(check.style, check.load, drag, elapsed) then
			return "snapped", nil
		end
		return "lost", string.format("snap not possible (%s, load %.2f, drag %s, %.2fs)", check.style, check.load, tostring(drag), elapsed)
	end
	return "lost", nil
end

return FightModel
