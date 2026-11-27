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
require(modules:WaitForChild("WeatherFX")).start() -- rain in storms (L6a)
require(modules:WaitForChild("Fireflies")).start() -- fireflies on clear nights (L5 life)
if Config.PAINTED_SIGNS_ON then
	require(modules:WaitForChild("Lanterns")).start() -- sign lanterns lit at night (N2)
end
require(modules:WaitForChild("BoatClient")).start() -- UNVERIFIED in Studio (2026-11-26)
require(modules:WaitForChild("AwayCard")).start() -- "While You Were Away" pond card (L6d, UNVERIFIED in Studio)
print("[Client] fishing controller started")
