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
require(Server.BobberGlow).markers() -- the deep hole's buoy glows at night
require(Server.FishModels).start() -- fish models players' screens can mount (the trophy wall)
if Config.WEATHER_ON then
	require(Server.WeatherService).start() -- weather (UNVERIFIED in Studio, 2026-11-26)
end
require(Server.PlayerData).start()
require(Server.RodService).start()
require(Server.FishingService).start()
require(Server.RiseService).start() -- rises: a fish breaks the surface (L2b, UNVERIFIED in Studio)
require(Server.Chalkboard).start() -- Today on the Lake board and the tackle box crate (L6d); before EconomyService, which hooks the crate's prompt
require(Server.EconomyService).start()
require(Server.PondService).start()
require(Server.GoalService).start() -- daily goals; does nothing while GOALS_ON is off
require(Server.BoatService).start() -- boats; only refuses buying while boats are off
require(Server.Boathouse).start() -- the boathouse and sales mooring (N4): stored away while BOATHOUSE_ON is off
if Config.FRENZIES_ON then
	require(Server.FrenzyService).run() -- feeding frenzies (UNVERIFIED in Studio, 2026-11-26)
end
print("[Main] Fishing game server started")
