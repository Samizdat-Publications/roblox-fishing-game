--!strict
-- Runs feeding frenzies (Shared/Frenzy.luau): rolls once a second, starts one at a spot
-- where a school is active, shows it (boiling water and splashes, a message to everyone)
-- and ends it after a minute. FishingService asks FrenzyService.at(spot) when a cast lands.
-- UNVERIFIED in Studio: written 2026-11-26 in the cloud; the boil effect is a first guess.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local FishLogic = require(Shared.FishLogic)
local Frenzy = require(Shared.Frenzy)
local Remotes = require(Shared.Remotes)

local Server = script.Parent
local WeatherService = require(Server.WeatherService)

local FrenzyService = {}

local active: { spot: string, endsAt: number, effect: Instance? }? = nil
local rng = Random.new()

-- Where to show the boil for each spot (centres of the zones; open water off the logs).
local SHOW_AT = {
	Dock = Vector3.new(0, 0, 36),
	OpenWater = Vector3.new(50, 0, -50),
	Logs = Vector3.new(78, 0, 42),
	Riffle = Vector3.new(-230, 0, 52), -- was -45, the creek pool's centre (L6b fix)
	Basin = Vector3.new(60, 0, -200),
	DropOff = Vector3.new(0, 0, -350),
}

local function boil(at: Vector3): Instance
	local p = Instance.new("Part")
	p.Name = "FrenzyBoil"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(24, 0.2, 24)
	p.Position = at + Vector3.new(0, 0.2, 0)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(230, 245, 255))
	e.Size = NumberSequence.new(1.2, 0)
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Rate = 60
	e.Speed = NumberRange.new(6, 12)
	e.SpreadAngle = Vector2.new(25, 25)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -30, 0)
	e.Parent = p
	p.Parent = workspace
	return p
end

local function reachable(): { [string]: boolean }
	-- Big Lake spots only when the Big Lake exists; the creek always (anyone can see it).
	local ok = { Dock = true, OpenWater = true, Logs = true, Riffle = true }
	if workspace:FindFirstChild("BigLake") then
		ok.Basin = true
		ok.DropOff = true
	end
	return ok
end

-- The frenzy at this spot, if one is on.
function FrenzyService.at(spot: string?): boolean
	return active ~= nil and spot ~= nil and active.spot == spot and os.clock() < active.endsAt
end

local function stop()
	if active and active.effect then
		active.effect:Destroy()
	end
	active = nil
	workspace:SetAttribute("Frenzy", nil)
	workspace:SetAttribute("FrenzyAt", nil)
end

-- For testing in Studio: start one now at a spot.
function FrenzyService.start(spot: string)
	stop()
	active = { spot = spot, endsAt = os.clock() + Frenzy.DURATION, effect = boil(SHOW_AT[spot] or Vector3.zero) }
	workspace:SetAttribute("FrenzyAt", SHOW_AT[spot]) -- where the boil is, for the gulls and the sound
	workspace:SetAttribute("Frenzy", spot)
	for _, p in Players:GetPlayers() do
		Remotes.event("Toast"):FireClient(p, Frenzy.SIGNS[spot] or "Fish are feeding like crazy somewhere!")
		Remotes.event("FishingEvent"):FireClient(p, "FrenzyStart", { spot = spot })
	end
	print("[Frenzy] at " .. spot)
end

function FrenzyService.run()
	local timer = 0
	-- Studio-only test hook: set workspace attribute DebugFrenzy to a spot name to start one
	-- there (scripts run from the Studio tools live in their own VM).
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("DebugFrenzy"):Connect(function()
			local spot = workspace:GetAttribute("DebugFrenzy")
			if type(spot) == "string" and SHOW_AT[spot] then
				FrenzyService.start(spot)
			end
		end)
	end
	RunService.Heartbeat:Connect(function(dt)
		timer += dt
		if timer < 1 then
			return
		end
		timer -= 1
		if active then
			if os.clock() >= active.endsAt then
				stop()
			end
			return
		end
		local period = FishLogic.periodFromClock(Lighting.ClockTime)
		local now = WeatherService.now()
		if rng:NextNumber() < Frenzy.chancePerSecond(period, now.weather, Config.DAY_LENGTH) then
			local spots = Frenzy.candidates(period, now, reachable())
			if #spots > 0 then
				FrenzyService.start(spots[rng:NextInteger(1, #spots)])
			end
		end
	end)
end

return FrenzyService
