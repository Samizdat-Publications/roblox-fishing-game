--!strict
-- Daily goals on the server: keeps each player's goals current for the day, moves them
-- forward on catches and sales, and pays the reward the moment a goal is done.
-- The rules are in Shared/Goals.luau (tested outside Studio).
-- UNVERIFIED in Studio: written 2026-11-26 in the cloud.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Goals = require(Shared.Goals)
local Remotes = require(Shared.Remotes)

local GoalService = {}

local function current(data: any): Goals.State
	data.goals = Goals.ensure(data.goals, Goals.dayOf(os.time()), data.creekPass == true)
	return data.goals
end

local function pay(player: Player, data: any, done: { Goals.Goal })
	for _, g in done do
		data.coins += g.reward
		print(string.format("[Goals] %s finished \"%s\" (+%d coins)", player.Name, g.text, g.reward))
		Remotes.event("Toast"):FireClient(player, string.format("Goal done: %s! +%d coins", g.text, g.reward))
	end
end

-- Call after a catch is recorded. Returns true when a goal paid out.
function GoalService.onCatch(player: Player, data: any, fish: any): boolean
	local done = Goals.onCatch(current(data), fish)
	pay(player, data, done)
	return #done > 0
end

-- Call after selling, with the coins the sale earned.
function GoalService.onSell(player: Player, data: any, coins: number): boolean
	local done = Goals.onSell(current(data), coins)
	pay(player, data, done)
	return #done > 0
end

-- Today's goals, for the snapshot (refreshes them when the day has turned).
function GoalService.today(data: any): Goals.State
	return current(data)
end

function GoalService.start()
	local PlayerData = require(script.Parent.PlayerData)
	PlayerData.onLoad(function(p, data)
		current(data)
		PlayerData.changed(p)
	end)
end

return GoalService
