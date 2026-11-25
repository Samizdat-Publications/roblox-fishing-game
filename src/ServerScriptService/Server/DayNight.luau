--!strict
-- Runs the clock. Lighting.ClockTime replicates to every client on its own.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local DayNight = {}

local HOURS_PER_SECOND = 24 / Config.DAY_LENGTH

function DayNight.start()
	Lighting.ClockTime = Config.START_CLOCK
	Lighting.Brightness = 2
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 110, 120)
	RunService.Heartbeat:Connect(function(dt)
		Lighting.ClockTime = (Lighting.ClockTime + dt * HOURS_PER_SECOND) % 24
	end)
	print(string.format("[DayNight] started at %.1f, one day = %d s", Config.START_CLOCK, Config.DAY_LENGTH))
end

-- For testing: jump to a time of day.
function DayNight.set(clock: number)
	Lighting.ClockTime = clock % 24
end

return DayNight
