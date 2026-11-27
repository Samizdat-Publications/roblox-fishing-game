--!strict
-- Fireflies on summer nights (L5 "life", 11/27/2026): small warm green-gold sparks that drift
-- low over the ground and the shallows around you, blinking on and off. They come out as the
-- night look comes in (LookPresets.night) and stay home in a storm or before one. Local only,
-- like the rain: one invisible box follows the camera at ground height with one
-- ParticleEmitter, so they cost the same anywhere on the map.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LookPresets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LookPresets"))

local Fireflies = {}

local TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local RATE = 18 -- sparks a second at full night, round the camera
local AREA = 48 -- studs square round the camera
local HEIGHT = 3 -- the box is this tall...
local LOW = 1.6 -- ...with its bottom this far over the ground's top (y = 1)
local GROUND_TOP = 1
local NO_FLIES = { Storm = true, PreStorm = true } :: { [string]: boolean }
local EVERY = 0.5 -- seconds between checks of the clock and weather

local part: Part? = nil
local emitter: ParticleEmitter? = nil

local function build(): ParticleEmitter
	local p = Instance.new("Part")
	p.Name = "Fireflies"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(AREA, HEIGHT, AREA)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparks"
	e.Texture = TEXTURE
	e.Rate = 0
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Speed = NumberRange.new(0.2, 0.7)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(3, 6)
	e.Acceleration = Vector3.new(0, 0.05, 0)
	e.Drag = 0.4
	e.RotSpeed = NumberRange.new(-30, 30)
	e.Size = NumberSequence.new(0.35)
	e.Color = ColorSequence.new(Color3.fromRGB(214, 255, 120))
	-- Two slow blinks over a life: dark, glow, dark, glow, dark.
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.05),
		NumberSequenceKeypoint.new(0.3, 1),
		NumberSequenceKeypoint.new(0.55, 1),
		NumberSequenceKeypoint.new(0.7, 0.05),
		NumberSequenceKeypoint.new(0.85, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.LightEmission = 1
	e.LightInfluence = 0 -- they make their own light
	e.Parent = p
	p.Parent = workspace.CurrentCamera
	part = p
	return e
end

-- How many sparks a second for this clock and weather (0 by day and in storms).
function Fireflies.rate(clock: number, weather: string?): number
	if weather and NO_FLIES[weather] then
		return 0
	end
	local night = LookPresets.night(clock)
	return if night > 0.4 then RATE * night else 0
end

local function refresh()
	local w = workspace:GetAttribute("Weather")
	local rate = Fireflies.rate(Lighting.ClockTime, if type(w) == "string" then w else nil)
	if rate > 0 and not emitter then
		emitter = build()
	end
	if emitter then
		emitter.Rate = rate
	end
end

function Fireflies.start()
	task.spawn(function()
		while true do
			refresh()
			task.wait(EVERY)
		end
	end)
	RunService.RenderStepped:Connect(function()
		local p, cam = part, workspace.CurrentCamera
		if p and cam then
			if p.Parent ~= cam then
				p.Parent = cam -- the camera can be replaced on respawn
			end
			local at = cam.CFrame.Position
			p.CFrame = CFrame.new(at.X, GROUND_TOP + LOW + HEIGHT / 2, at.Z)
		end
	end)
end

return Fireflies
