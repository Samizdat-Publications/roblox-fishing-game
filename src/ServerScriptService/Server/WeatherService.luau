--!strict
-- Runs the weather (Shared/Weather.luau, docs/WEATHER.md). Each game day plays the real
-- date's plan (one forecast for every server, L6d); the current weather, wind and moon are published as Workspace attributes so
-- every client draws the same sky and reads the same forecast. The server alone decides.
-- UNVERIFIED in Studio: written 2026-11-26 in the cloud. The look is not drawn here: DayNight
-- lays LookPresets.WEATHER over the time-of-day look from the "Weather" attribute (L6a), and
-- the client's WeatherFX draws the rain.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weather = require(Shared.Weather)
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config)
local Today = require(script.Parent.Today)

local WeatherService = {}

-- The plan comes from the real date (Weather.planForDate, L6d), the same on every server;
-- every game day of that date plays it. `day` counts game days on this server, for the moon.
local day = 0
local date = Today.day()
local plan: Weather.DayPlan = Weather.planForDate(date)
local current: Weather.Now = Weather.at(plan, Lighting.ClockTime, Weather.moonOf(0))

local function publish(announce: boolean)
	local k = Weather.byId[current.weather] or Weather.byId.Clear
	workspace:SetAttribute("Weather", current.weather)
	workspace:SetAttribute("WeatherName", k.name)
	workspace:SetAttribute("WindFrom", current.wind)
	workspace:SetAttribute("Moon", current.moon)
	workspace:SetAttribute("Forecast", Weather.forecast(plan, current.moon))
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

-- Wind (leg 3, N1, Config.WIND_ON): workspace.GlobalWind from the weather showing now
-- (Weather.windFor), eased over Weather.WIND_BLEND_SECONDS. Set here on the server so it
-- replicates and every player sees the same grass, clouds and particles move.
local WIND_EVERY = 0.2 -- real seconds between GlobalWind writes while it changes

local function startWind()
	local now = WeatherService.now()
	local first = Weather.windFor(now.weather, now.wind)
	local wind: Weather.WindBlend = { from = first, to = first, amount = 1 }
	workspace.GlobalWind = first
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since < WIND_EVERY then
			return
		end
		local n = WeatherService.now()
		local target = Weather.windFor(n.weather, n.wind)
		if wind.amount >= 1 and target == wind.to then
			since = 0
			return -- settled: nothing to write
		end
		local v = Weather.stepWind(wind, target, since)
		since = 0
		workspace.GlobalWind = v
	end)
end

function WeatherService.start()
	local lastClock = Lighting.ClockTime
	local timer = 0
	publish(false)
	if Config.WIND_ON then
		startWind()
	end
	-- Studio-only test hook: set workspace attribute DebugWeather to a kind id to force it
	-- (scripts run from the Studio tools live in their own VM and can't call force directly).
	-- While it holds a valid kind, every refresh below keeps that kind (Weather.heldPlan);
	-- set it to nil to go back to the date's plan right away. A live server never reads it.
	if RunService:IsStudio() then
		local holding = false
		local function fromAttribute()
			local kind = workspace:GetAttribute("DebugWeather")
			if type(kind) == "string" and Weather.byId[kind] then
				holding = true
				WeatherService.force(kind)
				print(string.format("[Weather] forced %s (Studio test, held until DebugWeather is cleared)", kind))
			elseif kind == nil and holding then
				holding = false
				plan = Weather.planForDate(date)
				current = Weather.at(plan, Lighting.ClockTime, Weather.moonOf(day))
				publish(true)
				print("[Weather] hold cleared: back to the date's plan")
			end
		end
		workspace:GetAttributeChangedSignal("DebugWeather"):Connect(fromAttribute)
		fromAttribute() -- already set before Play started
	end
	RunService.Heartbeat:Connect(function(dt)
		timer += dt
		if timer < 1 then
			return
		end
		timer = 0
		local clock = Lighting.ClockTime
		local today = Today.day()
		if clock < lastClock or today ~= date then -- past game midnight or a new real date: the date's plan
			if clock < lastClock then
				day += 1
			end
			date = today
			-- In Studio a DebugWeather kind holds through the refresh (Weather.heldPlan), so the
			-- look harness's Clear survives the UTC date roll and game midnight. Never live.
			plan = Weather.heldPlan(Weather.planForDate(date), workspace:GetAttribute("DebugWeather"), RunService:IsStudio(), day, plan.wind)
			if clock >= lastClock then
				publish(false) -- a new date mid game day: the forecast changes even if the sky doesn't yet
			end
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
