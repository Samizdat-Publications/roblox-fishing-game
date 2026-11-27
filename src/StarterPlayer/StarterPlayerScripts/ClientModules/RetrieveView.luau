--!strict
-- Working a lure (L4c), drawn on this player's screen only. The Controller feeds it the same
-- presses it streams to the server, and it runs the same model (Shared/Retrieve) right away,
-- so the lure moves the moment you press; the server scores the same timeline a moment later.
--
--   * The line runs straight from the rod tip to the lure.
--   * A spinner glints just under the surface, deeper when it's left to sink.
--   * A plastic worm is out of sight on the bottom: the line goes into the water above it, with
--     a faint ripple where it enters, and a little one each time it hops.
--   * By the rod, a small speed meter for the spinner: too slow, just right, too fast.
--   * The rod tip bends a little with the reel, twitches with each hop, and thumps on a strike.
--
-- Nothing here collides or decides anything: strikes come from the server ("Bite").
-- UNVERIFIED in Studio (written 2026-11-27).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Retrieve = require(Shared.Retrieve)
local BaitData = require(Shared.BaitData)
local CastLogic = require(Shared.CastLogic)

local RiseRipples = require(script.Parent.RiseRipples)
local RodFeel = require(script.Parent.RodFeel)

local RetrieveView = {}

local LINE_COLOR = Color3.fromRGB(235, 235, 235)
local SPIN_UNDER = 0.3 -- studs under the surface while it runs
local SPIN_DEEPEST = 1.6 -- drawn no deeper than this (it stays visible, dimmer)
local ENTRY_RIPPLE_EVERY = 1.6 -- seconds between the faint ripples where the worm's line goes in
local METER_W = 116
local SLOW_COLOR = Color3.fromRGB(120, 150, 200)
local RIGHT_COLOR = Color3.fromRGB(110, 210, 120)
local FAST_COLOR = Color3.fromRGB(235, 110, 90)

type View = {
	state: Retrieve.State,
	startedAt: number,
	lure: string,
	anchor: Part, -- the line's end: the spinner itself, or the worm's entry point
	blade: Part?, -- the spinner's flash
	beam: Beam?,
	meter: BillboardGui?,
	marker: Frame?,
	label: TextLabel?,
	lastRipple: number,
	thumpUntil: number,
}

local view: View? = nil

local function rodTip(): Attachment?
	local char = Players.LocalPlayer.Character
	local rod = char and char:FindFirstChild("Rod")
	local tip = rod and rod:FindFirstChild("RodTip")
	return if tip and tip:IsA("Attachment") then tip else nil
end

local function part(name: string, size: Vector3, color: Color3): Part
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
	return p
end

local function makeMeter(tip: Attachment): (BillboardGui, Frame, TextLabel)
	local g = Instance.new("BillboardGui")
	g.Name = "ReelMeter"
	g.Adornee = tip
	g.Size = UDim2.fromOffset(METER_W + 8, 40)
	g.StudsOffset = Vector3.new(0, 1.3, 0)
	g.AlwaysOnTop = true
	g.LightInfluence = 0
	g.ResetOnSpawn = false
	local label = Instance.new("TextLabel")
	label.Name = "Say"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 20)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = ""
	label.Parent = g
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromOffset(4, 24)
	bar.Size = UDim2.fromOffset(METER_W, 10)
	bar.BackgroundColor3 = Color3.fromRGB(25, 30, 35)
	bar.BackgroundTransparency = 0.25
	bar.BorderSizePixel = 0
	bar.Parent = g
	local function zone(from: number, to: number, color: Color3)
		local z = Instance.new("Frame")
		z.BackgroundColor3 = color
		z.BackgroundTransparency = 0.35
		z.BorderSizePixel = 0
		z.Position = UDim2.fromScale(from / Retrieve.SPIN_MAX, 0)
		z.Size = UDim2.fromScale((to - from) / Retrieve.SPIN_MAX, 1)
		z.Parent = bar
	end
	zone(0, Retrieve.BAND_LO, SLOW_COLOR)
	zone(Retrieve.BAND_LO, Retrieve.BAND_HI, RIGHT_COLOR)
	zone(Retrieve.BAND_HI, Retrieve.SPIN_MAX, FAST_COLOR)
	local marker = Instance.new("Frame")
	marker.Name = "Speed"
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromScale(0, 0.5)
	marker.Size = UDim2.fromOffset(4, 16)
	marker.BackgroundColor3 = Color3.new(1, 1, 1)
	marker.BorderSizePixel = 0
	marker.Parent = bar
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return g, marker, label
end

-- The server says the lure landed (payload of "Landed" with `retrieve`). Starts the clock the
-- presses are stamped with.
function RetrieveView.start(payload: any)
	RetrieveView.stop()
	local lure = payload.retrieve :: string
	local land = payload.pos :: Vector3
	local origin = (if typeof(payload.origin) == "Vector3" then payload.origin else land) :: Vector3
	local color = BaitData.byId[lure] and BaitData.byId[lure].color or Color3.fromRGB(230, 200, 60)
	local folder = workspace
	local anchor: Part
	local blade: Part? = nil
	if lure == "Spinner" then
		anchor = part("WorkedLure", Vector3.new(0.12, 0.12, 0.32), color)
		anchor.Material = Enum.Material.Metal
		local b = part("Blade", Vector3.new(0.05, 0.22, 0.14), Color3.fromRGB(255, 250, 225))
		b.Material = Enum.Material.Neon
		b.Parent = anchor
		blade = b
	else
		-- The worm stays out of sight; this is only where the line goes into the water.
		anchor = part("LineEntry", Vector3.one * 0.05, LINE_COLOR)
		anchor.Transparency = 1
	end
	local att = Instance.new("Attachment")
	att.Parent = anchor
	local beam: Beam? = nil
	local tip = rodTip()
	if tip then
		local bm = Instance.new("Beam")
		bm.Name = "Line"
		bm.Attachment0 = tip
		bm.Attachment1 = att
		bm.Width0 = 0.04
		bm.Width1 = 0.03
		bm.Color = ColorSequence.new(LINE_COLOR)
		bm.FaceCamera = true
		bm.Segments = 2 -- straight and tight: you're working it
		bm.Parent = anchor
		beam = bm
	end
	local meter: BillboardGui?, marker: Frame?, label: TextLabel? = nil, nil, nil
	if lure == "Spinner" and tip then
		meter, marker, label = makeMeter(tip)
	end
	anchor.Position = Vector3.new(land.X, CastLogic.LAND_Y - SPIN_UNDER, land.Z)
	anchor.Parent = folder
	view = {
		state = Retrieve.new(lure, payload.grade, land, origin),
		startedAt = os.clock(),
		lure = lure,
		anchor = anchor,
		blade = blade,
		beam = beam,
		meter = meter,
		marker = marker,
		label = label,
		lastRipple = os.clock(),
		thumpUntil = 0,
	}
end

function RetrieveView.active(): boolean
	return view ~= nil
end

-- Seconds since the lure landed, on this screen's clock (what the presses are stamped with).
function RetrieveView.elapsed(): number
	local v = view
	return if v then os.clock() - v.startedAt else 0
end

-- The lure has come back to the caster in this screen's model (the server ends the cast a
-- moment later).
function RetrieveView.finished(): boolean
	local v = view
	return v ~= nil and v.state.done
end

-- The model, for the Controller's own checks (accepting a press before sending it).
function RetrieveView.lure(): string?
	local v = view
	return if v then v.lure else nil
end

function RetrieveView.press(t: number)
	local v = view
	if v then
		Retrieve.press(v.state, t)
	end
end

function RetrieveView.release(t: number)
	local v = view
	if not v then
		return
	end
	local before = v.state.traveled
	Retrieve.release(v.state, t)
	if v.lure == "PlasticWorm" and v.state.traveled > before then
		-- A hop: the tip twitches and the line's entry point dimples.
		RodFeel.setBend(12)
		v.thumpUntil = os.clock() + 0.12
		RiseRipples.show(Retrieve.position(v.state), 0.35, 1)
		v.lastRipple = os.clock()
	end
end

-- A strike (the server's "Bite" with `lure`): the lure jumps to where the server had it and
-- the rod tip thumps down.
function RetrieveView.strike(pos: Vector3?)
	local v = view
	RodFeel.setBend(32)
	if v then
		v.thumpUntil = math.huge -- held bent until the hook press (the fight or goIdle takes over)
		if pos then
			v.anchor.Position = Vector3.new(pos.X, v.anchor.Position.Y, pos.Z)
			RiseRipples.show(pos, 0.8, 2)
		end
		if v.meter then
			v.meter.Enabled = false
		end
	end
end

function RetrieveView.stop()
	local v = view
	view = nil
	if v then
		v.anchor:Destroy()
		if v.meter then
			v.meter:Destroy()
		end
	end
end

-- Every frame while working the lure. `inFlight`: the cast is still flying (CastFlight), so the
-- lure and its line wait for the splashdown.
function RetrieveView.step(_dt: number, inFlight: boolean?)
	local v = view
	if not v then
		return
	end
	local hide = if inFlight then 1 else 0
	v.anchor.LocalTransparencyModifier = hide
	if v.blade then
		(v.blade :: Part).LocalTransparencyModifier = hide
	end
	if v.beam then
		(v.beam :: Beam).Enabled = not inFlight
	end
	local now = os.clock()
	if v.thumpUntil == math.huge then
		return -- struck: hold the picture until the hook press
	end
	Retrieve.advance(v.state, now - v.startedAt)
	local st = v.state
	local p = Retrieve.position(st)
	if v.lure == "Spinner" then
		local depth = SPIN_UNDER + math.min(st.depth, SPIN_DEEPEST - SPIN_UNDER)
		local heading = CFrame.lookAt(Vector3.zero, st.toward)
		v.anchor.CFrame = CFrame.new(p.X, CastLogic.LAND_Y - depth, p.Z) * heading
		local blade = v.blade
		if blade then
			-- The blade spins faster the faster you reel, and flashes as it turns.
			local spin = now * (4 + st.speed * 5)
			blade.CFrame = v.anchor.CFrame * CFrame.new(0, 0, -0.08) * CFrame.Angles(0, 0, spin)
			local flash = 0.5 + 0.5 * math.sin(spin * 2)
			blade.Transparency = if st.speed > 0.3 then 0.55 - 0.45 * flash else 0.6
			blade.Transparency += math.clamp(st.depth - SPIN_UNDER, 0, 1) * 0.3
		end
		if v.marker and v.label then
			local marker = v.marker :: Frame
			local label = v.label :: TextLabel
			marker.Position = UDim2.fromScale(math.clamp(st.speed / Retrieve.SPIN_MAX, 0, 1), 0.5)
			local band = Retrieve.band(st.speed)
			label.Text = if band == "slow" then "Too slow" elseif band == "fast" then "Too fast" else "Just right"
			label.TextColor3 = if band == "slow" then SLOW_COLOR elseif band == "fast" then FAST_COLOR else RIGHT_COLOR
		end
		if now > v.thumpUntil then
			RodFeel.setBend(st.speed * 2.2)
		end
	else
		v.anchor.Position = Vector3.new(p.X, CastLogic.LAND_Y, p.Z)
		if now > v.thumpUntil then
			RodFeel.setBend(if st.held then 8 else 2)
		end
		if now - v.lastRipple > ENTRY_RIPPLE_EVERY then
			v.lastRipple = now
			RiseRipples.show(p, 0.25, 1)
		end
	end
end

return RetrieveView
