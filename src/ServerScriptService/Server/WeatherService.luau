--!strict
-- Runs the weather (Shared/Weather.luau, docs/WEATHER.md). Each game day gets a plan at
-- midnight; the current weather, wind and moon are published as Workspace attributes so
-- every client draws the same sky and reads the same forecast. The server alone decides.
-- UNVERIFIED in Studio: written 2026-11-26 in the cloud. The look (fog, cloud, rain) is a
-- first guess at Atmosphere and Lighting values and needs tuning with the critic.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weather = require(Shared.Weather)
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config)

local WeatherService = {}

local seed = os.time() % 100000
local day = 0
local plan: Weather.DayPlan = Weather.planDay(0, seed, nil)
local current: Weather.Now = Weather.at(plan, Lighting.ClockTime, Weather.moonOf(0))

-- The look of each kind: Atmosphere density and haze, and how bright the sun is.
local LOOKS = {
	Clear = { density = 0.3, haze = 0, brightness = 2 },
	Overcast = { density = 0.4, haze = 2.2, brightness = 1.3 },
	Fog = { density = 0.62, haze = 3, brightness = 1.2 },
	Wind = { density = 0.3, haze = 0.5, brightness = 2 },
	PreStorm = { density = 0.45, haze = 2, brightness = 1.2 },
	Storm = { density = 0.55, haze = 3, brightness = 0.7 },
	ColdFront = { density = 0.25, haze = 0, brightness = 2.4 },
}

local function atmosphere(): Atmosphere
	local a = Lighting:FindFirstChildOfClass("Atmosphere")
	if not a then
		a = Instance.new("Atmosphere")
		a.Parent = Lighting
	end
	return a :: Atmosphere
end

local function publish(announce: boolean)
	local k = Weather.byId[current.weather] or Weather.byId.Clear
	workspace:SetAttribute("Weather", current.weather)
	workspace:SetAttribute("WeatherName", k.name)
	workspace:SetAttribute("WindFrom", current.wind)
	workspace:SetAttribute("Moon", current.moon)
	workspace:SetAttribute("Forecast", Weather.forecast(plan, current.moon))
	local look = LOOKS[current.weather] or LOOKS.Clear
	local a = atmosphere()
	a.Density = look.density
	a.Haze = look.haze
	Lighting.Brightness = look.brightness
	if announce then
		local text = if current.weather == plan.kind or current.weather == "Clear" then Weather.forecast(plan, current.moon) else k.forecast
		for _, p in Players:GetPlayers() do
			Remotes.event("Toast"):FireClient(p, text)
		end
	end
end

-- The weather right now, for the bite rules.
local CALM: Weather.Now = { weather = "Clear", moon = 0 } -- weather switched off

function WeatherService.now(): Weather.Now
	return if Config.WEATHER_ON then current else CALM
end

function WeatherService.isStorm(): boolean
	return Config.WEATHER_ON and current.weather == "Storm"
end

-- For testing in Studio: force a kind for the rest of the day.
function WeatherService.force(kind: string, wind: string?)
	plan = { day = day, kind = kind, wind = wind }
	current = Weather.at(plan, Lighting.ClockTime, Weather.moonOf(day))
	publish(true)
end

function WeatherService.start()
	local lastClock = Lighting.ClockTime
	local timer = 0
	publish(false)
	RunService.Heartbeat:Connect(function(dt)
		timer += dt
		if timer < 1 then
			return
		end
		timer = 0
		local clock = Lighting.ClockTime
		if clock < lastClock then -- past midnight: a new day and its plan
			day += 1
			plan = Weather.planDay(day, seed, plan)
		end
		lastClock = clock
		local nextNow = Weather.at(plan, clock, Weather.moonOf(day))
		if nextNow.weather ~= current.weather or nextNow.moon ~= current.moon then
			current = nextNow
			publish(true)
		end
	end)
	print(string.format("[Weather] started: %s", Weather.forecast(plan, current.moon)))
end

return WeatherService
