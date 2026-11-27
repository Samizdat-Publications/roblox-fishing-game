--!strict
-- Daily goals on the server: keeps each player's goals current for the day, moves them
-- forward on catches and sales, and pays the reward the moment a goal is done.
-- The rules are in Shared/Goals.luau (tested outside Studio).
-- UNVERIFIED in Studio: written 2026-11-26 in the cloud.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Goals = require(Shared.Goals)
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config)

local RunService = game:GetService("RunService")

local GoalService = {}

local TURNOVER_CHECK = if RunService:IsStudio() then 5 else 60 -- seconds between new-day checks

-- Now, in seconds, with the Studio-only DebugDayOffset hook (shared with the weather, the
-- chalkboard and the shopkeeper's gift in Server/Today.luau).
local now = require(script.Parent.Today).now

local function current(data: any): Goals.State
	data.goals = Goals.ensure(data.goals, Goals.dayOf(now()), data.creekPass == true, next(data.boats or {}) ~= nil)
	return data.goals
end

local function pay(player: Player, data: any, done: { Goals.Goal })
	for _, g in done do
		data.coins += g.reward
		print(string.format("[Goals] %s finished \"%s\" (+%d coins)", player.Name, g.text, g.reward))
		Remotes.event("Toast"):FireClient(player, string.format("Goal done: %s! +%d coins", g.text, g.reward))
		Remotes.event("FishingEvent"):FireClient(player, "Goal", {}) -- for the goal sound (UNVERIFIED in Studio)
	end
end

-- Call after a catch is recorded. Returns true when a goal paid out.
function GoalService.onCatch(player: Player, data: any, fish: any, frenzy: boolean?): boolean
	if not Config.GOALS_ON then
		return false
	end
	local done = Goals.onCatch(current(data), fish, frenzy)
	pay(player, data, done)
	return #done > 0
end

-- Call after selling, with the coins the sale earned.
function GoalService.onSell(player: Player, data: any, coins: number): boolean
	if not Config.GOALS_ON then
		return false
	end
	local done = Goals.onSell(current(data), coins)
	pay(player, data, done)
	return #done > 0
end

-- Today's goals, for the snapshot (refreshes them when the day has turned).
function GoalService.today(data: any): Goals.State
	return current(data)
end

function GoalService.start()
	if not Config.GOALS_ON then
		return -- switched off: no goals are made, so the Goals button stays hidden
	end
	local PlayerData = require(script.Parent.PlayerData)
	PlayerData.onLoad(function(p, data)
		current(data)
		PlayerData.changed(p)
	end)
	-- Someone playing across midnight gets the new day's goals within a minute, not only at
	-- their next catch or sale (found in the L6c playtest).
	task.spawn(function()
		while true do
			task.wait(TURNOVER_CHECK)
			local today = Goals.dayOf(now())
			for _, p in game:GetService("Players"):GetPlayers() do
				local data = PlayerData.get(p)
				if data and (type(data.goals) ~= "table" or data.goals.day ~= today) then
					current(data)
					PlayerData.changed(p)
				end
			end
		end
	end)
end

return GoalService
