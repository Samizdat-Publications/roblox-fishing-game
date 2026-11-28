-- Client boot.
local modules = script.Parent:WaitForChild("ClientModules")
local Controller = require(modules:WaitForChild("Controller"))
Controller.start()
task.spawn(function()
	require(modules:WaitForChild("FishShadows")).start()
end)
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
if Config.LOOK_DIRECTOR_ON then
	require(modules:WaitForChild("LookDirector")).start() -- the look on this screen (N0)
end
if Config.FOLIAGE_TIER_ON then
	require(modules:WaitForChild("FoliageTier")).start() -- lighter foliage on the phone tier (N1)
end
require(modules:WaitForChild("WeatherFX")).start() -- rain in storms (L6a)
require(modules:WaitForChild("Fireflies")).start() -- fireflies on clear nights (L5 life)
if Config.PAINTED_SIGNS_ON then
	require(modules:WaitForChild("Lanterns")).start() -- sign lanterns lit at night (N2)
end
if Config.WHITE_WATER_ON then
	require(modules:WaitForChild("WhiteWater")).start() -- foam and spray on the creek's riffle (N3)
end
require(modules:WaitForChild("BoatClient")).start() -- UNVERIFIED in Studio (2026-11-26)
if Config.BOAT_FEEL_ON and Config.boatsOn() then
	-- How a boat feels (N4): art, trim, lean, bob, wake, lights, horn, poses, camera; touch buttons.
	require(modules:WaitForChild("BoatFeelClient")).start()
	local UI = require(modules:WaitForChild("UI"))
	require(modules:WaitForChild("BoatTouch")).start(UI.isPanelOpen)
end
require(modules:WaitForChild("AwayCard")).start() -- "While You Were Away" pond card (L6d, UNVERIFIED in Studio)
print("[Client] fishing controller started")
