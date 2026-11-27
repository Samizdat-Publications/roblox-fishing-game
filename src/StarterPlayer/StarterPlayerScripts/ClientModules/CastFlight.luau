--!strict
-- The cast's flight (L4b), drawn on this screen only: when the rod's whip lets go, a bobber
-- flies from the rod tip to the landing along the landing ring's arc (CastLogic.arcPoint)
-- over CastLogic.FLIGHT_TIME, trailing the line, then lands with a plop and a ripple.
--
-- The server puts the real bobber on the water as soon as the cast arrives; until this
-- flight lands, the real one (and its line) is hidden for this player so only the flying
-- one shows. The Controller corrects the landing to the server's point ("Landed"), and ends
-- the flight early if a bite or a cancel comes first. UNVERIFIED in Studio (2026-11-26).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CastLogic = require(Shared.CastLogic)
local BobberCam = require(Shared.BobberCam)

local RiseRipples = require(script.Parent.RiseRipples)
local SoundFX = require(script.Parent.SoundFX)
local RodFeel = require(script.Parent.RodFeel)

local CastFlight = {}

local GHOST_SIZE = 0.8 * BobberCam.BOBBER_SCALE -- the gray-box bobber's size (FishingService)
local GHOST_COLOR = Color3.fromRGB(230, 60, 50)
local LINE_COLOR = Color3.fromRGB(235, 235, 235)

type Flight = {
	from: Vector3?, -- the rod tip when the bobber leaves it (set at release)
	to: Vector3,
	releaseAt: number,
	ghost: Part?,
	lure: Color3?, -- a worked lure flies instead of the bobber (L4c): small, in its colour
	beam: Beam?,
	conn: RBXScriptConnection?,
}

local flight: Flight? = nil
local hiddenParts: { BasePart } = {}
local hiddenBeams: { Beam } = {}
local hiddenLights: { Light } = {}

local function realBobber(): BasePart?
	local b = workspace:FindFirstChild("Bobber_" .. Players.LocalPlayer.Name)
	return if b and b:IsA("BasePart") then b else nil
end

-- Hide (or show again) the server's bobber and its line, for this player only.
local function hideReal(on: boolean)
	if on then
		local b = realBobber()
		if b and not table.find(hiddenParts, b) then
			for _, d in { b :: Instance, table.unpack(b:GetDescendants()) } do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 1
					table.insert(hiddenParts, d)
				elseif d:IsA("Beam") and d.Enabled then
					d.Enabled = false
					table.insert(hiddenBeams, d)
				elseif d:IsA("Light") and d.Enabled then
					d.Enabled = false -- the night glow waits for the touchdown too
					table.insert(hiddenLights, d)
				end
			end
		end
	else
		for _, p in hiddenParts do
			if p.Parent then
				p.LocalTransparencyModifier = 0
			end
		end
		for _, beam in hiddenBeams do
			if beam.Parent then
				beam.Enabled = true
			end
		end
		for _, light in hiddenLights do
			if light.Parent then
				light.Enabled = true
			end
		end
		table.clear(hiddenParts)
		table.clear(hiddenBeams)
		table.clear(hiddenLights)
	end
end

local function makeGhost(lure: Color3?): (Part, Beam?)
	local g = Instance.new("Part")
	g.Name = "FlyingBobber"
	g.Shape = Enum.PartType.Ball
	g.Size = Vector3.one * (if lure then 0.3 else GHOST_SIZE)
	g.Color = lure or GHOST_COLOR
	g.Material = Enum.Material.SmoothPlastic
	g.Anchored = true
	g.CanCollide = false
	g.CanQuery = false
	g.CanTouch = false
	g.CastShadow = false
	local att = Instance.new("Attachment")
	att.Parent = g
	local beam: Beam? = nil
	local char = Players.LocalPlayer.Character
	local rod = char and char:FindFirstChild("Rod")
	local tip = rod and rod:FindFirstChild("RodTip")
	if tip and tip:IsA("Attachment") then
		local b = Instance.new("Beam")
		b.Attachment0 = tip
		b.Attachment1 = att
		b.Width0 = 0.04
		b.Width1 = 0.04
		b.Color = ColorSequence.new(LINE_COLOR)
		b.FaceCamera = true
		b.Segments = 8
		b.Parent = g
		beam = b
	end
	g.Parent = workspace
	return g, beam
end

local function stop(splash: boolean)
	local f = flight
	if not f then
		return
	end
	flight = nil
	if f.conn then
		f.conn:Disconnect()
	end
	if f.ghost then
		f.ghost:Destroy()
	end
	hideReal(false)
	if splash then
		RiseRipples.show(f.to, 0.6, 2)
		SoundFX.event("Touchdown")
	end
end

local function step()
	local f = flight
	if not f then
		return
	end
	hideReal(true) -- the server's bobber may arrive mid-flight
	local now = os.clock()
	if now < f.releaseAt then
		return -- still in the back swing
	end
	if not f.ghost then
		f.from = RodFeel.tipPosition() or f.to + Vector3.new(0, 4, 0)
		f.ghost, f.beam = makeGhost(f.lure)
	end
	local k = (now - f.releaseAt) / CastLogic.FLIGHT_TIME
	if k >= 1 then
		stop(true)
		return
	end
	local g = f.ghost :: Part
	g.Position = CastLogic.arcPoint(f.from :: Vector3, f.to, k)
end

-- The cast was let go toward `landing`; the bobber leaves the rod tip `releaseIn` seconds
-- from now (the end of the whip). `lure` (L4c): a worked lure flies, in this colour.
function CastFlight.start(landing: Vector3, releaseIn: number, lure: Color3?)
	stop(false)
	local f: Flight = {
		from = nil,
		to = landing,
		releaseAt = os.clock() + releaseIn,
		ghost = nil,
		lure = lure,
		beam = nil,
		conn = nil,
	}
	flight = f
	f.conn = RunService.RenderStepped:Connect(step)
end

-- The server's landing point (it can differ from the client's by up to CastLogic.ACCEPT).
function CastFlight.land(pos: Vector3)
	local f = flight
	if f then
		f.to = Vector3.new(pos.X, CastLogic.LAND_Y, pos.Z)
	end
end

function CastFlight.flying(): boolean
	return flight ~= nil
end

-- Land right now (a bite came first): plop and ripple where it was headed.
function CastFlight.finish()
	stop(true)
end

-- The cast didn't happen (dry ground, a cancel): the flying bobber just goes.
function CastFlight.cancel()
	stop(false)
end

return CastFlight
