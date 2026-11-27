--!strict
-- What a fight looks like on the water (L4b), drawn on this screen only, so a kid learns to
-- read the fish before it moves on the bar:
--   * the line shifts white, orange, red with tension, and the rod tip bends with it
--   * each fight style's tell (Shared/FightFeel.TELLS), shown TELL_LEAD seconds before the
--     big move reaches the bar (FightModel winds the move up first):
--       runner  the drag screams, the line pulls hard to one side, a V wake on the water
--       jumper  the fish breaks the surface in a leap, with a splash
--       diver   the rod tip dips, the line goes steep, a low creak
--       shaker  the bobber spot thrashes with spray
--       tugger  quick small twitches of the line
--       steady  a slow steady pull
-- The bobber is the server's (pulled under at the hook); this moves it locally, the server
-- never moves it during a fight. Nothing here collides or changes the fight.
-- UNVERIFIED in Studio (written 2026-11-26).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FightModel = require(Shared.FightModel)
local FightFeel = require(Shared.FightFeel)

local RiseRipples = require(script.Parent.RiseRipples)
local SoundFX = require(script.Parent.SoundFX)
local RodFeel = require(script.Parent.RodFeel)

local FightTells = {}

local UNDER_Y = -0.7 -- the hooked bobber's height (FishingService.setBobberY(-1))
local SURFACE_Y = 0.22
local WANDER = 1.2 -- studs the bobber wanders sideways with the fish's bar position
local RUN_SIDE = 4.5 -- studs a run drags the line to one side
local DIVE_DEPTH = 1.6 -- extra studs a dive pulls the bobber down
local TWITCH_SIZE = 0.35
local TWITCH_DECAY = 18 -- per second
local STEADY_RATE = 0.8 -- how slowly a steady fish's pull follows it (per second)
local FOLLOW_RATE = 6
local TENSION_RATE = 8
local WAKE_LEN = 3.2
local WAKE_ANGLE = math.rad(28)
local SPRAY_COUNT = 26

type Fight = {
	style: string,
	land: Vector3,
	side: Vector3, -- flat, across the line
	out: Vector3, -- flat, from the player out to the bobber
	tension: number,
	offset: Vector3, -- the bobber's current local offset from its hooked spot
	runSide: number, -- -1 or 1: which way the current run drags
	twitch: number,
	twitchSign: number,
	lastTells: number,
	lastDarts: number,
	topOffset: Vector3?,
	wake: { Part },
	sprayPart: Part?,
	defaultCurve: number?,
}

local current: Fight? = nil
local folder: Folder? = nil
local rng = Random.new()

local function getFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "FightTells"
	f.Parent = workspace
	folder = f
	return f
end

local function ghost(name: string, size: Vector3, color: Color3, ball: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if ball then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	end
	p.Parent = getFolder()
	return p
end

local function bobber(): BasePart?
	local b = workspace:FindFirstChild("Bobber_" .. Players.LocalPlayer.Name)
	return if b and b:IsA("BasePart") then b else nil
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- A fish leaps clear of the water near `at`, with a splash going in and coming out.
local function breach(at: Vector3, dir: Vector3, len: number)
	local fish = ghost("LeapingFish", Vector3.new(len * 0.3, len * 0.3, len), Color3.fromRGB(150, 165, 150), true)
	RiseRipples.show(at, 0.7, 2)
	task.spawn(function()
		local dur = 0.6
		local t0 = os.clock()
		while os.clock() - t0 < dur and fish.Parent do
			local k = (os.clock() - t0) / dur
			local p = at + dir * (k * 2.4) + Vector3.new(0, 0.1 + math.sin(k * math.pi) * 2.2, 0)
			fish.CFrame = CFrame.lookAt(p, p + dir) * CFrame.Angles((0.5 - k) * 2.4, 0, 0)
			task.wait()
		end
		fish:Destroy()
		RiseRipples.show(at + dir * 2.4, 0.8, 2)
	end)
end

local function spray(f: Fight, at: Vector3)
	local p = f.sprayPart
	if not p or not p.Parent then
		local part = ghost("Spray", Vector3.new(0.2, 0.2, 0.2), Color3.new(1, 1, 1), false)
		part.Transparency = 1
		local e = Instance.new("ParticleEmitter")
		e.Name = "Spray"
		e.Rate = 0
		e.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.05) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(0.4, 0.75)
		e.Speed = NumberRange.new(7, 12)
		e.SpreadAngle = Vector2.new(35, 35)
		e.Acceleration = Vector3.new(0, -32, 0)
		e.EmissionDirection = Enum.NormalId.Top
		e.Parent = part
		f.sprayPart = part
		p = part
	end
	local part = p :: Part
	part.Position = at
	local e = part:FindFirstChild("Spray") :: ParticleEmitter?
	if e then
		e:Emit(SPRAY_COUNT)
	end
	RiseRipples.show(at, 0.7, 3)
end

local function setWake(f: Fight, at: Vector3, heading: Vector3, alpha: number)
	if #f.wake == 0 then
		for i = 1, 2 do
			f.wake[i] = ghost("Wake", Vector3.new(0.22, 0.05, WAKE_LEN), Color3.fromRGB(235, 245, 255), false)
		end
	end
	local dir = if heading.Magnitude > 0.01 then heading.Unit else f.side
	for i, w in f.wake do
		local turn = CFrame.Angles(0, if i == 1 then WAKE_ANGLE else -WAKE_ANGLE, 0)
		local back = turn:VectorToWorldSpace(-dir)
		local mid = Vector3.new(at.X, SURFACE_Y, at.Z) + back * (WAKE_LEN / 2)
		w.CFrame = CFrame.lookAt(mid, mid + back)
		w.Transparency = 1 - 0.6 * alpha
	end
end

local function clearEffects(f: Fight)
	for _, w in f.wake do
		w:Destroy()
	end
	table.clear(f.wake)
	local p = f.sprayPart
	if p then
		task.delay(1, function()
			p:Destroy() -- let the last spray fall first
		end)
		f.sprayPart = nil
	end
end

-- A fish is on: `style` from its fight profile, `land` where the bobber went in.
function FightTells.begin(style: string?, land: Vector3?)
	FightTells.stop()
	local b = bobber()
	local at = land or (if b then b.Position else nil)
	if not at then
		return
	end
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local out = if root then flat(at - root.Position) else Vector3.new(0, 0, -1)
	out = if out.Magnitude > 0.01 then out.Unit else Vector3.new(0, 0, -1)
	local topOffset: Vector3? = nil
	local top = b and b:FindFirstChild("Top")
	if b and top and top:IsA("BasePart") then
		topOffset = top.Position - b.Position
	end
	local beam = b and b:FindFirstChild("Line")
	current = {
		style = style or "tugger",
		land = Vector3.new(at.X, UNDER_Y, at.Z),
		side = Vector3.new(-out.Z, 0, out.X),
		out = out,
		tension = 0,
		offset = Vector3.zero,
		runSide = 1,
		twitch = 0,
		twitchSign = 1,
		lastTells = 0,
		lastDarts = 0,
		topOffset = topOffset,
		wake = {},
		sprayPart = nil,
		defaultCurve = if beam and beam:IsA("Beam") then beam.CurveSize1 else nil,
	}
end

-- The fight is over (won, lost or cancelled).
function FightTells.stop()
	local f = current
	current = nil
	RodFeel.setBend(0)
	if f then
		clearEffects(f)
	end
end

-- Every frame of the fight, after FightModel.step.
function FightTells.step(s: FightModel.State, dt: number)
	local f = current
	if not f then
		return
	end
	local move, _left = FightModel.tell(s)
	local warned = move -- a big move is winding up
	local running = if s.mode == "run" or s.mode == "jump" or s.mode == "dive" then s.mode else nil
	local active = warned or running
	local tellKind = FightFeel.tellFor(f.style, active)

	-- A new warning: the tell's one-off parts (sound, splash, spray).
	if s.tells > f.lastTells then
		f.lastTells = s.tells
		local kind = FightFeel.tellFor(f.style, move)
		if kind then
			SoundFX.tell(kind)
			local b = bobber()
			local at = if b then Vector3.new(b.Position.X, SURFACE_Y, b.Position.Z) else Vector3.new(f.land.X, SURFACE_Y, f.land.Z)
			if kind == "breach" then
				local dir = f.side * (if rng:NextNumber() < 0.5 then 1 else -1)
				breach(at + f.out * 1.5, dir, 1.6)
			elseif kind == "thrash" then
				spray(f, at)
			end
			if kind == "drag" or kind == "thrash" then
				f.runSide = if rng:NextNumber() < 0.5 then 1 else -1
			end
		end
	end
	-- An ordinary dart: a tugger's twitch.
	if s.darts > f.lastDarts then
		f.lastDarts = s.darts
		if f.style == "tugger" then
			f.twitch = TWITCH_SIZE
			f.twitchSign = -f.twitchSign
		end
	end
	f.twitch *= math.exp(-TWITCH_DECAY * dt)

	-- Where the bobber should be: wandering with the fish, dragged by a run, pulled down by a dive.
	local lateral = (s.fishPos - 0.5) * 2 * WANDER
	local down = 0
	local rate = FOLLOW_RATE
	if tellKind == "drag" or tellKind == "thrash" then
		lateral = f.runSide * RUN_SIDE * (if running then 1 else 0.5)
		rate = if running then 3 else 2
	elseif tellKind == "dive" then
		down = DIVE_DEPTH * (if running then 1 else 0.6)
		rate = 5
	elseif f.style == "steady" then
		rate = STEADY_RATE
	end
	local goal = f.side * lateral - Vector3.new(0, down, 0)
	if f.style == "shaker" then
		goal += f.side * (math.sin(os.clock() * 24) * 0.25) -- head shakes
	end
	if f.style == "steady" then
		goal += f.out * (math.sin(os.clock() * 0.9) * 0.8) -- a slow pull, out and back
	end
	f.offset = f.offset:Lerp(goal, 1 - math.exp(-rate * dt))
	local b = bobber()
	if b then
		-- A tugger's twitch is a quick jerk on top (not smoothed, so it reads as a twitch).
		local pos = f.land + f.offset + (f.side + Vector3.new(0, 0.6, 0)) * (f.twitch * f.twitchSign)
		b.Position = pos
		local top = b:FindFirstChild("Top")
		if top and top:IsA("BasePart") and f.topOffset then
			top.Position = pos + f.topOffset
		end
		-- The line: colour and a touch thicker with tension; straight and steep on a dive.
		local target = FightFeel.tension(s)
		f.tension += (target - f.tension) * (1 - math.exp(-TENSION_RATE * dt))
		local beam = b:FindFirstChild("Line")
		if beam and beam:IsA("Beam") then
			beam.Color = ColorSequence.new(FightFeel.lineColor(f.tension))
			local w = 0.04 + 0.025 * f.tension
			beam.Width0 = w
			beam.Width1 = w
			if f.defaultCurve then
				beam.CurveSize1 = if tellKind == "dive" then 0 else (f.defaultCurve :: number) * (1 - f.tension * 0.6)
			end
		end
		-- A run's V wake behind the fish as it drags the line.
		if tellKind == "drag" then
			setWake(f, pos, f.side * f.runSide, if running then 1 else 0.5)
		elseif #f.wake > 0 then
			for _, w in f.wake do
				w.Transparency = math.min(1, w.Transparency + dt * 2.5)
			end
		end
	else
		local target = FightFeel.tension(s)
		f.tension += (target - f.tension) * (1 - math.exp(-TENSION_RATE * dt))
	end
	RodFeel.setBend(FightFeel.rodBend(f.tension, tellKind == "dive"))
end

return FightTells
