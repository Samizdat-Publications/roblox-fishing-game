--!strict
-- The home pond on the server: ticks each player's pond on load (time away, capped) and
-- every few seconds while they play, and handles Keep, Sell and Release.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PondLogic = require(Shared.PondLogic)
local Remotes = require(Shared.Remotes)

local Server = script.Parent
local PlayerData = require(Server.PlayerData)

local PondService = {}

local rng = Random.new()
local started: { [Player]: boolean } = {}

local function sizes(pond: any): { number }
	local out = {}
	for i, f in pond.fish do
		out[i] = f.cm
	end
	return out
end

-- Advance one player's pond by `seconds`; returns how many fish grew and the names born.
local function advance(data: any, seconds: number): (number, { string })
	local before = sizes(data.pond)
	local born = PondLogic.tick(data.pond, seconds, rng)
	local grew = 0
	for i, cm in before do
		local f = data.pond.fish[i]
		if f and f.cm > cm + 0.05 then
			grew += 1
		end
	end
	return grew, born
end

local function summary(grew: number, born: { string }, prefix: string): string?
	local parts = {}
	if grew > 0 then
		table.insert(parts, string.format("%d fish grew", grew))
	end
	local counts: { [string]: number } = {}
	local order: { string } = {}
	for _, name in born do
		if not counts[name] then
			table.insert(order, name)
		end
		counts[name] = (counts[name] or 0) + 1
	end
	for _, name in order do
		local n = counts[name]
		table.insert(parts, if n == 1 then "a baby " .. name .. " was born" else string.format("%d baby %s were born", n, name))
	end
	if #parts == 0 then
		return nil
	end
	return prefix .. table.concat(parts, ", ") .. "."
end

local function onLoaded(player: Player, data: any)
	if started[player] then
		return
	end
	started[player] = true
	local now = os.time()
	if data.pond.lastTick == 0 then
		data.pond.lastTick = now -- first visit: nothing to catch up on
		return
	end
	local away = now - data.pond.lastTick
	data.pond.lastTick = now
	local grew, born = advance(data, away)
	local text = summary(grew, born, "Your pond while you were away: ")
	if text then
		Remotes.event("Toast"):FireClient(player, text)
		print(string.format("[Pond] %s away %d s: %s", player.Name, away, text))
		PlayerData.changed(player)
	end
end

function PondService.start()
	PlayerData.onLoad(onLoaded)
	for _, p in Players:GetPlayers() do
		local data = PlayerData.get(p)
		if data then
			onLoaded(p, data)
		end
	end
	Players.PlayerRemoving:Connect(function(p)
		started[p] = nil
	end)

	Remotes.func("PondAction").OnServerInvoke = function(player: Player, action: any, index: any)
		local data = PlayerData.get(player)
		if not data then
			return false, "Still loading, try again in a moment."
		end
		local ok, msg
		if action == "keep" then
			ok, msg = PondLogic.keep(data, index)
		elseif action == "sell" then
			ok, msg = PondLogic.sell(data, index)
		elseif action == "release" then
			ok, msg = PondLogic.release(data, index)
		else
			return false, "Unknown pond action."
		end
		if ok then
			print(string.format("[Pond] %s %s: %s", player.Name, tostring(action), msg))
			PlayerData.changed(player)
		end
		return ok, msg
	end

	-- Live ticking, plus a Studio-only fast-forward for playtests (DebugPondHours on the Player).
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local due = os.clock() - last >= Config.POND_TICK
			if due then
				last = os.clock()
			end
			for _, p in Players:GetPlayers() do
				local data = PlayerData.get(p)
				if data and started[p] then
					local hours = p:GetAttribute("DebugPondHours")
					if RunService:IsStudio() and type(hours) == "number" then
						p:SetAttribute("DebugPondHours", nil)
						local grew, born = advance(data, hours * 3600)
						local text = summary(grew, born, string.format("Your pond after %g hours: ", hours))
						print("[Pond] debug fast-forward " .. p.Name .. ": " .. tostring(text))
						if text then
							Remotes.event("Toast"):FireClient(p, text)
						end
						PlayerData.changed(p)
					elseif due then
						local now = os.time()
						local grew, born = advance(data, now - data.pond.lastTick)
						data.pond.lastTick = now
						local text = summary(grew, born, "Your pond: ")
						if #born > 0 and text then
							Remotes.event("Toast"):FireClient(p, text)
						end
						if grew > 0 or #born > 0 then
							PlayerData.changed(p)
						end
					end
				end
			end
		end
	end)
	print("[Pond] ready")
end

return PondService
