--!strict
-- What happens on the water while you wait (L4), drawn on this player's screen only.
--
--   * The fish's shadow: when the server says a fish is coming ("Approach") a dark, soft,
--     fish-shaped shadow the length of that fish swims in from 10 to 14 studs out, circles
--     the bobber, and noses the bait. Big fish are bigger and slower. On "Leave" it turns
--     and swims off (fast when spooked); on a nibble it pecks; on "Bite" it darts in.
--   * The twitch: a quick tap jiggles the bobber, with a small ripple and a quiet tick.
--   * Long waits: after Approach.WAIT_EVENT_AFTER seconds with no fish coming, one small
--     thing happens nearby (a dimple of a rise, a dragonfly on the bobber, a far-off jump, a
--     turtle's head), and very rarely a huge shadow passes under the bobber and doesn't bite.
--
-- Nothing here collides, is hit by raycasts, or changes the game: the server decides fish.
-- UNVERIFIED in Studio (written 2026-11-26).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Approach = require(Shared.Approach)
local FishLogic = require(Shared.FishLogic)
local WaterMap = require(Shared.WaterMap)

local RiseRipples = require(script.Parent.RiseRipples)
local SoundFX = require(script.Parent.SoundFX)

local WaitScene = {}

-- The shadow
local SHADOW_Y = -0.5 -- just under the surface
local SHADOW_COLOR = Color3.fromRGB(14, 24, 34)
local SHADOW_ALPHA = 0.5 -- how dark at full strength (1 - Transparency)
local WIDTH_SHARE = 0.32 -- body width as a share of its length
local SWIM_FROM_MIN = 10 -- studs out where it starts...
local SWIM_FROM_MAX = 14
local SWIM_SPEED = 5 -- studs per second for a medium fish
local SPEED_BY_SIZE: { [string]: number } = { small = 1.35, medium = 1, large = 0.65 }
local CIRCLE_MIN = 1.6 -- the smallest circle around the bobber (studs)
local CIRCLE_SHARE = 0.7 -- circle radius as a share of the fish's length
local NOSE_TIME = 0.9 -- seconds before the strike it noses the bait
local TURN_RATE = 6 -- how quickly it turns toward where it's going
local WAG_RATE = 7 -- tail beats per second (radians), slower for big fish
local FADE_IN = 0.6
local PECK_TIME = 0.2
local DART_SPEED = 30
local BITE_FADE = 0.5
local LEAVE_TIME = 2.2
local SPOOK_SPEED = 3 -- a spooked fish bolts this many times faster
local LEAVE_DIST = 14
local HUGE_LENGTH = 15
local HUGE_PASS_TIME = 7
local HUGE_PASS_DIST = 24

-- Long-wait events
local RISE_FROM, RISE_TO = 12, 22
local JUMP_FROM, JUMP_TO = 22, 32
local TURTLE_FROM, TURTLE_TO = 5, 9
local DRAGONFLY_STAY = 3
local TURTLE_STAY = 2.5

type Shadow = {
	body: Part,
	tail: Part,
	len: number,
	pos: Vector3,
	heading: Vector3,
	speedMul: number,
	mode: string, -- in, circle, nose, dart, leave, pass, gone
	born: number,
	biteAt: number, -- os.clock() of the expected strike
	angle: number,
	spin: number, -- +1 or -1, which way it circles
	radius: number,
	peckUntil: number,
	fadeFrom: number, -- os.clock() a fade-out started (0 for none)
	fadeTime: number,
	target: Vector3?, -- for leave and pass
	passFrom: Vector3?,
}

local rng = Random.new()
local waters = WaterMap.castWaters()
local folder: Folder? = nil
local fish: Shadow? = nil -- the fish coming for the bait
local extras: { Shadow } = {} -- shadows on their way out, and the huge one
local bobberAt: Vector3? = nil
local quietSince = 0 -- last time a fish came, left or the bobber landed
local busyUntil = 0 -- a long-wait event is playing
local waiting = false
local dragonfly: Model? = nil

local function getFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "WaitScene"
	f.Parent = workspace
	folder = f
	return f
end

local function ghostPart(name: string, size: Vector3, color: Color3, ball: boolean): Part
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
	return p
end

local function bobberPart(): BasePart?
	local b = workspace:FindFirstChild("Bobber_" .. Players.LocalPlayer.Name)
	return if b and b:IsA("BasePart") then b else nil
end

local function bobberPos(): Vector3?
	local b = bobberPart()
	if b then
		return b.Position
	end
	return bobberAt
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- A point on the water `rMin` to `rMax` studs from `center`, preferring the side away from
-- the player (out over the lake). Nil if none is found.
local function waterPointNear(center: Vector3, rMin: number, rMax: number): Vector3?
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local away = if root then flat(center - root.Position) else Vector3.new(0, 0, -1)
	local base = if away.Magnitude > 0.01 then math.atan2(away.Z, away.X) else 0
	for i = 1, 16 do
		local spread = if i <= 8 then math.rad(100) else math.pi
		local a = base + rng:NextNumber(-spread, spread)
		local r = rng:NextNumber(rMin, rMax)
		local p = Vector3.new(center.X + math.cos(a) * r, SHADOW_Y, center.Z + math.sin(a) * r)
		if FishLogic.isOnWaterAny(p, waters) then
			return p
		end
	end
	return nil
end

local function newShadow(len: number, speedMul: number, at: Vector3, heading: Vector3): Shadow
	local f = getFolder()
	local body = ghostPart("FishShadow", Vector3.new(len * WIDTH_SHARE, 0.08, len), SHADOW_COLOR, true)
	body.Transparency = 1
	body.Parent = f
	local tail = ghostPart("FishShadowTail", Vector3.new(len * 0.3, 0.06, len * 0.3), SHADOW_COLOR, true)
	tail.Transparency = 1
	tail.Parent = f
	local now = os.clock()
	return {
		body = body,
		tail = tail,
		len = len,
		pos = at,
		heading = if heading.Magnitude > 0.01 then heading.Unit else Vector3.new(0, 0, -1),
		speedMul = speedMul,
		mode = "in",
		born = now,
		biteAt = now + 3,
		angle = 0,
		spin = if rng:NextNumber() < 0.5 then 1 else -1,
		radius = math.max(CIRCLE_MIN, len * CIRCLE_SHARE),
		peckUntil = 0,
		fadeFrom = 0,
		fadeTime = 1,
		target = nil,
		passFrom = nil,
	}
end

local function destroyShadow(s: Shadow)
	s.mode = "gone"
	s.body:Destroy()
	s.tail:Destroy()
end

local function startFade(s: Shadow, secs: number)
	if s.fadeFrom == 0 then
		s.fadeFrom = os.clock()
		s.fadeTime = secs
	end
end

-- Moves the shadow toward `goal` at up to `speed`, turning to face where it swims.
local function swimToward(s: Shadow, goal: Vector3, speed: number, dt: number)
	local d = flat(goal - s.pos)
	local dist = d.Magnitude
	if dist > 1e-3 then
		local stepLen = math.min(dist, speed * dt)
		s.pos += d.Unit * stepLen
		local a = 1 - math.exp(-TURN_RATE * dt)
		local h = s.heading:Lerp(d.Unit, a)
		if h.Magnitude > 0.01 then
			s.heading = h.Unit
		end
	end
end

local function faceToward(s: Shadow, point: Vector3, dt: number)
	local d = flat(point - s.pos)
	if d.Magnitude > 0.05 then
		local a = 1 - math.exp(-TURN_RATE * dt)
		local h = s.heading:Lerp(d.Unit, a)
		if h.Magnitude > 0.01 then
			s.heading = h.Unit
		end
	end
end

local function drawShadow(s: Shadow, now: number)
	local alpha = math.clamp((now - s.born) / FADE_IN, 0, 1)
	if s.fadeFrom > 0 then
		alpha *= 1 - math.clamp((now - s.fadeFrom) / s.fadeTime, 0, 1)
	end
	local transparency = 1 - SHADOW_ALPHA * alpha
	local at = Vector3.new(s.pos.X, SHADOW_Y, s.pos.Z)
	local cf = CFrame.lookAt(at, at + s.heading)
	s.body.CFrame = cf
	s.body.Transparency = transparency
	local wag = math.sin(now * WAG_RATE * s.speedMul) * 0.45
	s.tail.CFrame = cf * CFrame.new(0, 0, s.len * 0.55) * CFrame.Angles(0, wag, 0)
	s.tail.Transparency = transparency
end

local function stepShadow(s: Shadow, now: number, dt: number)
	local bobber = bobberPos() or s.pos
	local base = SWIM_SPEED * s.speedMul
	if s.mode == "in" then
		local fromBobber = flat(s.pos - bobber)
		local dir = if fromBobber.Magnitude > 0.01 then fromBobber.Unit else Vector3.new(1, 0, 0)
		local entry = bobber + dir * s.radius
		-- Arrive in time to circle at least a little before nosing the bait.
		local timeLeft = math.max((s.biteAt - NOSE_TIME - now) * 0.55, 0.25)
		local need = flat(entry - s.pos).Magnitude / timeLeft
		swimToward(s, entry, math.max(base, need), dt)
		if flat(entry - s.pos).Magnitude < 0.4 then
			s.mode = "circle"
			s.angle = math.atan2(dir.Z, dir.X)
		end
	elseif s.mode == "circle" then
		s.angle += s.spin * (base * 0.8 / s.radius) * dt
		local goal = bobber + Vector3.new(math.cos(s.angle), 0, math.sin(s.angle)) * s.radius
		swimToward(s, goal, base * 1.6, dt)
		if now >= s.biteAt - NOSE_TIME then
			s.mode = "nose"
		end
	elseif s.mode == "nose" then
		local fromBobber = flat(s.pos - bobber)
		local dir = if fromBobber.Magnitude > 0.01 then fromBobber.Unit else -s.heading
		local gap = if now < s.peckUntil then s.len * 0.2 else s.len * 0.5 + 0.25
		local wiggle = math.sin(now * 5) * 0.08
		swimToward(s, bobber + dir * (gap + wiggle), base * 0.8, dt)
		faceToward(s, bobber, dt)
	elseif s.mode == "dart" then
		swimToward(s, bobber, DART_SPEED, dt)
		startFade(s, BITE_FADE)
	elseif s.mode == "leave" or s.mode == "pass" then
		local goal = s.target or s.pos
		-- Leaving covers LEAVE_DIST while it fades (a spooked fish fades, and so bolts, faster).
		local speed = if s.mode == "pass" then HUGE_PASS_DIST * 2 / HUGE_PASS_TIME else LEAVE_DIST / s.fadeTime
		swimToward(s, goal, speed, dt)
		if s.mode == "pass" and flat(goal - s.pos).Magnitude < HUGE_PASS_DIST * 0.35 then
			startFade(s, HUGE_PASS_TIME * 0.3)
		end
	end
	drawShadow(s, now)
	if s.fadeFrom > 0 and now - s.fadeFrom >= s.fadeTime then
		destroyShadow(s)
	end
end

-- The fish turns and swims away (spooked: it bolts).
local function sendAway(s: Shadow, spooked: boolean)
	local bobber = bobberPos() or s.pos
	local away = flat(s.pos - bobber)
	if away.Magnitude < 0.01 then
		away = -s.heading
	end
	local turn = rng:NextNumber(-0.6, 0.6)
	local dir = CFrame.Angles(0, turn, 0):VectorToWorldSpace(away.Unit)
	s.mode = "leave"
	s.target = s.pos + dir * LEAVE_DIST
	startFade(s, if spooked then LEAVE_TIME / SPOOK_SPEED else LEAVE_TIME)
	table.insert(extras, s)
end

local function clearFish()
	if fish then
		destroyShadow(fish)
		fish = nil
	end
end

local function flyOffDragonfly()
	local d = dragonfly
	dragonfly = nil
	if not d then
		return
	end
	task.spawn(function()
		local start = d:GetPivot()
		local dir = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
		dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.new(1, 0, 0)
		for i = 1, 30 do
			if not d.Parent then
				return
			end
			local k = i / 30
			d:PivotTo(start + dir * (k * 8) + Vector3.new(0, k * 3, 0))
			task.wait(1 / 30)
		end
		d:Destroy()
	end)
end

-- Everything goes: a new cast, the line in, a fish on.
function WaitScene.clear()
	clearFish()
	for _, s in extras do
		if s.mode ~= "gone" then
			destroyShadow(s)
		end
	end
	table.clear(extras)
	if dragonfly then
		dragonfly:Destroy()
		dragonfly = nil
	end
	waiting = false
end

----------------------------------------------------------------------------------------
-- Long-wait events

local function eventRise(center: Vector3)
	local p = waterPointNear(center, RISE_FROM, RISE_TO)
	if p then
		-- A small dimple (one small ring), so it never reads as a real rise you can cast to.
		RiseRipples.show(p, 0.45, 1)
		SoundFX.event("WaitEvent", { kind = "rise" })
	end
end

local function eventJump(center: Vector3)
	local p = waterPointNear(center, JUMP_FROM, JUMP_TO)
	if not p then
		return
	end
	local dir = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
	dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.new(1, 0, 0)
	local leap = ghostPart("LeapingFish", Vector3.new(0.28, 0.28, 0.95), Color3.fromRGB(150, 160, 165), true)
	leap.Parent = getFolder()
	busyUntil = os.clock() + 1.5
	RiseRipples.show(p, 0.5, 2)
	task.spawn(function()
		local dur = 0.65
		local t0 = os.clock()
		while os.clock() - t0 < dur and leap.Parent do
			local k = (os.clock() - t0) / dur
			local at = p + dir * (k * 2) + Vector3.new(0, 0.2 + math.sin(k * math.pi) * 1.6, 0)
			local pitch = (0.5 - k) * 2.2
			leap.CFrame = CFrame.lookAt(at, at + dir) * CFrame.Angles(pitch, 0, 0)
			task.wait()
		end
		leap:Destroy()
		RiseRipples.show(p + dir * 2, 0.6, 2)
		SoundFX.event("WaitEvent", { kind = "jump" })
	end)
end

local function eventTurtle(center: Vector3)
	local p = waterPointNear(center, TURTLE_FROM, TURTLE_TO)
	if not p then
		return
	end
	local head = ghostPart("TurtleHead", Vector3.new(0.32, 0.32, 0.4), Color3.fromRGB(70, 82, 48), true)
	head.Parent = getFolder()
	busyUntil = os.clock() + TURTLE_STAY + 1.5
	local function at(y: number)
		head.CFrame = CFrame.lookAt(Vector3.new(p.X, y, p.Z), Vector3.new(center.X, y, center.Z))
	end
	at(-0.3)
	RiseRipples.show(p, 0.3, 1)
	SoundFX.event("WaitEvent", { kind = "turtle" })
	task.spawn(function()
		for i = 1, 20 do
			at(-0.3 + 0.62 * (i / 20))
			task.wait(0.03)
		end
		task.wait(TURTLE_STAY)
		for i = 1, 20 do
			if not head.Parent then
				return
			end
			at(0.32 - 0.62 * (i / 20))
			task.wait(0.03)
		end
		head:Destroy()
	end)
end

local function makeDragonfly(): Model
	local m = Instance.new("Model")
	m.Name = "Dragonfly"
	local body = ghostPart("Body", Vector3.new(0.06, 0.06, 0.46), Color3.fromRGB(35, 110, 130), false)
	body.Parent = m
	m.PrimaryPart = body
	for _, side in { -1, 1 } do
		for _, z in { -0.06, 0.06 } do
			local wing = ghostPart("Wing", Vector3.new(0.42, 0.01, 0.08), Color3.fromRGB(230, 240, 245), false)
			wing.Transparency = 0.55
			wing.CFrame = body.CFrame * CFrame.new(side * 0.22, 0.02, z)
			wing.Parent = m
		end
	end
	return m
end

local function eventDragonfly()
	local b = bobberPart()
	if not b or dragonfly then
		return
	end
	local m = makeDragonfly()
	m.Parent = getFolder()
	dragonfly = m
	busyUntil = os.clock() + DRAGONFLY_STAY + 2.5
	local yaw = rng:NextNumber(0, math.pi * 2)
	task.spawn(function()
		local from = b.Position + Vector3.new(math.cos(yaw) * 6, 2.5, math.sin(yaw) * 6)
		for i = 1, 36 do
			if dragonfly ~= m or not b.Parent then
				return
			end
			local k = i / 36
			local land = b.Position + Vector3.new(0, b.Size.Y / 2 + 0.05, 0)
			local at = from:Lerp(land, k * k * (3 - 2 * k)) + Vector3.new(0, math.sin(i * 1.7) * 0.05, 0)
			m:PivotTo(CFrame.lookAt(at, at + Vector3.new(math.cos(yaw + math.pi), 0, math.sin(yaw + math.pi))))
			task.wait(1 / 30)
		end
		local t0 = os.clock()
		while os.clock() - t0 < DRAGONFLY_STAY do
			if dragonfly ~= m or not b.Parent then
				return
			end
			local land = b.Position + Vector3.new(0, b.Size.Y / 2 + 0.05, 0)
			m:PivotTo(CFrame.new(land) * CFrame.Angles(0, yaw, 0))
			task.wait(1 / 30)
		end
		if dragonfly == m then
			flyOffDragonfly()
		end
	end)
end

local function eventHugeShadow(center: Vector3)
	local dir = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
	dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.new(1, 0, 0)
	local from = Vector3.new(center.X, SHADOW_Y, center.Z) - dir * HUGE_PASS_DIST
	local s = newShadow(HUGE_LENGTH, 0.45, from, dir)
	s.mode = "pass"
	s.target = Vector3.new(center.X, SHADOW_Y, center.Z) + dir * HUGE_PASS_DIST
	s.passFrom = from
	table.insert(extras, s)
	busyUntil = os.clock() + HUGE_PASS_TIME
	print("[WaitScene] a huge shadow passes under the bobber")
end

local function longWaitEvent()
	local center = bobberPos()
	if not center then
		return
	end
	if rng:NextNumber() < Approach.HUGE_SHADOW_CHANCE then
		eventHugeShadow(center)
		return
	end
	local pick = rng:NextInteger(1, 4)
	if pick == 1 then
		eventRise(center)
	elseif pick == 2 then
		eventDragonfly()
	elseif pick == 3 then
		eventJump(center)
	else
		eventTurtle(center)
	end
end

----------------------------------------------------------------------------------------

-- A quick tap while waiting: the bobber bobs, a small ripple, a quiet tick.
function WaitScene.twitch()
	local b = bobberPart()
	SoundFX.event("Twitch")
	if not b then
		return
	end
	local base = b.Position
	RiseRipples.show(base, 0.35, 1)
	if dragonfly then
		flyOffDragonfly()
	end
	task.spawn(function()
		local last = base
		for i = 1, 8 do
			if not b.Parent or b.Position ~= last then
				return -- the server moved it (a dip): leave it be
			end
			local k = i / 8
			last = base - Vector3.new(0, math.sin(k * math.pi) * 0.22, 0)
			b.Position = last
			task.wait(1 / 32)
		end
		if b.Parent and b.Position == last then
			b.Position = base
		end
	end)
end

-- Server fishing events (from the Controller).
function WaitScene.event(kind: string, payload: any)
	local now = os.clock()
	if kind == "Landed" then
		WaitScene.clear()
		waiting = true
		bobberAt = if payload and typeof(payload.pos) == "Vector3" then payload.pos else nil
		quietSince = now
		if bobberAt then
			RiseRipples.show(bobberAt, 0.6, 2)
		end
	elseif kind == "Approach" then
		clearFish()
		if dragonfly then
			flyOffDragonfly() -- something's coming
		end
		local center = (if payload and typeof(payload.pos) == "Vector3" then payload.pos else nil) or bobberPos()
		if not center then
			return
		end
		bobberAt = center
		local len = if payload and type(payload.length) == "number" then payload.length else 2
		local size = if payload and type(payload.size) == "string" then payload.size else "medium"
		local biteIn = if payload and type(payload.biteIn) == "number" then payload.biteIn else 3
		local start = waterPointNear(center, SWIM_FROM_MIN, SWIM_FROM_MAX)
			or Vector3.new(center.X + SWIM_FROM_MIN, SHADOW_Y, center.Z)
		local s = newShadow(len, SPEED_BY_SIZE[size] or 1, start, flat(center - start))
		s.biteAt = now + biteIn
		fish = s
		print(string.format("[WaitScene] shadow: %s, %.2f studs, strike in %.1fs", size, len, biteIn))
	elseif kind == "Hush" then
		local s = fish
		if s then
			s.biteAt = math.min(s.biteAt, now + Approach.HUSH_TIME)
			if s.mode == "circle" then
				s.mode = "nose"
			end
		end
	elseif kind == "Dip" then
		local s = fish
		if s then
			s.mode = "nose"
			s.peckUntil = now + PECK_TIME
		end
	elseif kind == "Bite" then
		local s = fish
		if s then
			s.mode = "dart"
			table.insert(extras, s)
			fish = nil
		end
		local b = bobberPos()
		if b then
			RiseRipples.show(b, 0.8, 2)
		end
		quietSince = now
	elseif kind == "Leave" then
		local s = fish
		fish = nil
		if s then
			sendAway(s, payload ~= nil and payload.spooked == true)
		end
		quietSince = now
	elseif kind == "Missed" then
		quietSince = now
	elseif kind == "Reset" or kind == "Hooked" or kind == "Caught" or kind == "Escaped" or kind == "Snag" or kind == "Freed" or kind == "Snapped" then
		WaitScene.clear()
	end
end

-- Every frame, with the Controller's state.
function WaitScene.step(state: string, dt: number)
	local now = os.clock()
	if fish then
		stepShadow(fish, now, dt)
	end
	for i = #extras, 1, -1 do
		local s = extras[i]
		if s.mode == "gone" then
			table.remove(extras, i)
		else
			stepShadow(s, now, dt)
		end
	end
	if state ~= "Waiting" then
		if (state == "Idle" or state == "Fighting") and (fish or dragonfly or #extras > 0) then
			WaitScene.clear()
		end
		return
	end
	if waiting and not fish and now >= busyUntil and now - quietSince >= Approach.WAIT_EVENT_AFTER then
		quietSince = now
		longWaitEvent()
	end
end

return WaitScene
