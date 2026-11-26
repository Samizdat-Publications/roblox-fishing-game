-- Server boot. Order matters: remotes, world, data, then the services that use them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
Remotes.setup()

local Server = script.Parent:WaitForChild("Server")
local WorldBuilder = require(Server.WorldBuilder)
if not workspace:FindFirstChild("Lake") then
	warn("[Main] Workspace.Lake missing, building it now")
	WorldBuilder.build()
end

require(Server.DayNight).start()
require(Server.PlayerData).start()
require(Server.RodService).start()
require(Server.FishingService).start()
require(Server.EconomyService).start()
require(Server.PondService).start()
require(Server.GoalService).start() -- daily goals (UNVERIFIED in Studio, 2026-11-26)
print("[Main] Fishing game server started")
