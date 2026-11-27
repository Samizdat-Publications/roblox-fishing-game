--!strict
-- Runs the clock. Lighting.ClockTime replicates to every client on its own, and so does the
-- look LookPresets writes to Lighting and its effects (L5a), so every player sees the same light.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local LookPresets = require(Shared.LookPresets)

local DayNight = {}

local HOURS_PER_SECOND = 24 / Config.DAY_LENGTH
local LOOK_EVERY = 0.25 -- real seconds between look updates (0.006 game hours)

function DayNight.start()
	Lighting.ClockTime = Config.START_CLOCK
	LookPresets.apply(Lighting.ClockTime)
	local sinceLook = 0
	RunService.Heartbeat:Connect(function(dt)
		Lighting.ClockTime = (Lighting.ClockTime + dt * HOURS_PER_SECOND) % 24
		sinceLook += dt
		if sinceLook >= LOOK_EVERY then
			sinceLook = 0
			LookPresets.apply(Lighting.ClockTime)
		end
	end)
	print(string.format("[DayNight] started at %.1f, one day = %d s", Config.START_CLOCK, Config.DAY_LENGTH))
end

-- For testing: jump to a time of day.
function DayNight.set(clock: number)
	Lighting.ClockTime = clock % 24
	LookPresets.apply(Lighting.ClockTime)
end

return DayNight
