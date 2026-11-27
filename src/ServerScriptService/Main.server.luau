-- Server boot. Order matters: remotes, world, data, then the services that use them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
Remotes.setup()

local Config = require(Shared.Config)
local Server = script.Parent:WaitForChild("Server")
local WorldBuilder = require(Server.WorldBuilder)
if not workspace:FindFirstChild("Lake") then
	warn("[Main] Workspace.Lake missing, building it now")
	WorldBuilder.build()
end

-- Boat slips, the channel and the Big Lake (UNVERIFIED in Studio, 2026-11-26). Each
-- feature from the second overnight run has its switch in Config.
if Config.BIG_LAKE_ON and not workspace:FindFirstChild("BigLake") then
	require(Server.BoatWorld).build()
end

require(Server.DayNight).start()
if Config.WEATHER_ON then
	require(Server.WeatherService).start() -- weather (UNVERIFIED in Studio, 2026-11-26)
end
require(Server.PlayerData).start()
require(Server.RodService).start()
require(Server.FishingService).start()
require(Server.RiseService).start() -- rises: a fish breaks the surface (L2b, UNVERIFIED in Studio)
require(Server.EconomyService).start()
require(Server.PondService).start()
require(Server.GoalService).start() -- daily goals; does nothing while GOALS_ON is off
require(Server.BoatService).start() -- boats; only refuses buying while boats are off
if Config.FRENZIES_ON then
	require(Server.FrenzyService).run() -- feeding frenzies (UNVERIFIED in Studio, 2026-11-26)
end
print("[Main] Fishing game server started")
