--!strict
-- Runs the clock. Lighting.ClockTime replicates to every client on its own, and so does the
-- look LookPresets writes to Lighting and its effects (L5a), so every player sees the same light.
-- Weather (L6a): with Config.WEATHER_ON, the kind WeatherService publishes as the Workspace
-- attribute "Weather" is laid on top of the time-of-day look. A change never snaps: the old
-- kind's layer blends into the new one over BLEND_SECONDS real seconds.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local LookPresets = require(Shared.LookPresets)

local DayNight = {}

local HOURS_PER_SECOND = 24 / Config.DAY_LENGTH
local LOOK_EVERY = 0.25 -- real seconds between look updates (0.006 game hours)
local BLEND_SECONDS = 20 -- real seconds for one weather kind to blend into the next

-- The weather blend: `from` kind into `to` kind, `amount` (0..1, linear) of the way.
local blend = { from = "Clear", to = "Clear", amount = 1 }

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

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
	if want ~= blend.to then
		-- Start from whichever kind shows most right now (changes are game hours apart, so a
		-- change in the middle of a blend is rare; the small jump then is accepted).
		blend.from = if blend.amount >= 0.5 then blend.to else blend.from
		blend.to = want
		blend.amount = 0
	end
	blend.amount = math.min(1, blend.amount + dt / BLEND_SECONDS)
end

local function applyLook()
	if Config.WEATHER_ON then
		LookPresets.apply(Lighting.ClockTime, blend.to, smooth(blend.amount), blend.from)
	else
		LookPresets.apply(Lighting.ClockTime)
	end
end

function DayNight.start()
	Lighting.ClockTime = Config.START_CLOCK
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
