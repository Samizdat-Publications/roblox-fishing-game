--!strict
-- Runs the clock. Lighting.ClockTime replicates to every client on its own, and so does the
-- look LookPresets writes to Lighting and its effects (L5a), so every player sees the same light.
-- Weather (L6a): with Config.WEATHER_ON, the kind WeatherService publishes as the Workspace
-- attribute "Weather" is laid on top of the time-of-day look. A change never snaps: the old
-- kind's layer blends into the new one over BLEND_SECONDS real seconds.
-- N0: with Config.LOOK_DIRECTOR_ON the server still runs the clock and the weather blend but
-- writes nothing to Lighting; it sets the Workspace attribute LookOnClient and each client
-- writes the look locally (ClientModules/LookDirector, same blend from LookPresets).
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local LookPresets = require(Shared.LookPresets)

local DayNight = {}

local HOURS_PER_SECOND = 24 / Config.DAY_LENGTH
local LOOK_EVERY = 0.25 -- real seconds between look updates (0.006 game hours)
-- The weather blend: `from` kind into `to` kind, `amount` (0..1, linear) of the way, over
-- LookPresets.BLEND_SECONDS (20) real seconds. The stepping lives in LookPresets so the
-- clients (LookDirector) blend exactly the same way.
local blend: LookPresets.Blend = { from = "Clear", to = "Clear", amount = 1 }
local smooth = LookPresets.smooth

-- The kind to show now: nil while weather is switched off, else the published kind.
local function wanted(): string?
	if not Config.WEATHER_ON then
		return nil
	end
	local w = workspace:GetAttribute("Weather")
	return if type(w) == "string" and LookPresets.WEATHER[w] then w else "Clear"
end

local function stepWeather(dt: number)
	local want = wanted()
	if want == nil then
		return
	end
	LookPresets.stepBlend(blend, want, dt)
end

local function applyLook()
	if Config.LOOK_DIRECTOR_ON then
		return -- each client writes the look (LookDirector)
	end
	if Config.WEATHER_ON then
		LookPresets.apply(Lighting.ClockTime, blend.to, smooth(blend.amount), blend.from)
	else
		LookPresets.apply(Lighting.ClockTime)
	end
end

function DayNight.start()
	Lighting.ClockTime = Config.START_CLOCK
	if Config.LOOK_DIRECTOR_ON then
		workspace:SetAttribute("LookOnClient", true)
	end
	applyLook()
	local sinceLook = 0
	RunService.Heartbeat:Connect(function(dt)
		Lighting.ClockTime = (Lighting.ClockTime + dt * HOURS_PER_SECOND) % 24
		sinceLook += dt
		if sinceLook >= LOOK_EVERY then
			stepWeather(sinceLook)
			sinceLook = 0
			applyLook()
		end
	end)
	print(string.format("[DayNight] started at %.1f, one day = %d s", Config.START_CLOCK, Config.DAY_LENGTH))
end

-- For testing: jump to a time of day.
function DayNight.set(clock: number)
	Lighting.ClockTime = clock % 24
	applyLook()
end

return DayNight
