--!strict
-- Rain you can see (L6a). While the Workspace attribute "Weather" (WeatherService) is Storm,
-- rain streaks fall around the camera; in PreStorm, a few drops. Local only: an invisible
-- anchored part follows the camera and carries one ParticleEmitter, so it costs the same
-- anywhere on the map. The light and fog of the weather come from the server (DayNight).
local RunService = game:GetService("RunService")

local WeatherFX = {}

-- Built-in texture (already used by FrenzyService), stretched along its fall into a streak.
local TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local RATE = { Storm = 400, PreStorm = 30 } :: { [string]: number } -- particles per second
local ABOVE = 22 -- studs above the camera the rain starts
local AREA = 40 -- studs square the rain covers round the camera (70 was too sparse to see)

local emitter: ParticleEmitter? = nil
local part: Part? = nil

local function build(): ParticleEmitter
	local p = Instance.new("Part")
	p.Name = "WeatherFXRain"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(AREA, 1, AREA)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Rain"
	e.Texture = TEXTURE
	e.Rate = 0
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Speed = NumberRange.new(55, 65)
	e.SpreadAngle = Vector2.new(3, 3)
	e.Lifetime = NumberRange.new(0.6, 0.75)
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Size = NumberSequence.new(0.35) -- 0.12 and 0.24 were too fine to see
	e.Squash = NumberSequence.new(-3) -- negative stretches along the fall (positive drew sideways streaks in Studio)
	e.Color = ColorSequence.new(Color3.fromRGB(200, 212, 226))
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.2),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	e.LightEmission = 0.2
	e.LightInfluence = 0.5 -- a storm's dim light shouldn't hide its own rain
	e.Parent = p
	p.Parent = workspace.CurrentCamera
	part = p
	return e
end

local function refresh()
	local w = workspace:GetAttribute("Weather")
	local rate = if type(w) == "string" then RATE[w] or 0 else 0
	if rate > 0 and not emitter then
		emitter = build()
	end
	if emitter then
		emitter.Rate = rate
	end
end

function WeatherFX.start()
	workspace:GetAttributeChangedSignal("Weather"):Connect(refresh)
	refresh()
	RunService.RenderStepped:Connect(function()
		local p, cam = part, workspace.CurrentCamera
		if p and cam then
			if p.Parent ~= cam then
				p.Parent = cam -- the camera can be replaced on respawn
			end
			p.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, ABOVE, 0))
		end
	end)
end

return WeatherFX
