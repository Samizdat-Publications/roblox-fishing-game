--!strict
-- Loads and saves each player's data. Uses a DataStore when it can; otherwise keeps data in
-- memory for the session and says so in the output log (Studio API access off, or unsaved place).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Inventory = require(Shared.Inventory)
local Remotes = require(Shared.Remotes)

local PlayerData = {}

local store: DataStore? = nil
local memoryOnly = false
local memory: { [number]: any } = {} -- survives respawns in a session when there is no DataStore
local loaded: { [Player]: Inventory.Data } = {}
-- Players whose save couldn't be read: they play on fresh data, but it's never saved over
-- their real save. UNVERIFIED in Studio (2026-11-26).
local noSave: { [Player]: boolean } = {}
local loadListeners: { (Player, Inventory.Data) -> () } = {}

local function key(player: Player): string
	return "u_" .. player.UserId
end

local function openStore()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if not ok then
		memoryOnly = true
		warn("[PlayerData] DataStore unavailable (" .. tostring(result) .. "). Using memory only; progress will not save.")
		return
	end
	store = result
	-- A cheap read proves API access is on.
	local readOk, readErr = pcall(function()
		return (result :: DataStore):GetAsync("probe")
	end)
	if not readOk then
		memoryOnly = true
		store = nil
		warn("[PlayerData] DataStore unavailable (" .. tostring(readErr) .. "). Using memory only; progress will not save. In Studio: Game Settings, Security, Enable Studio Access to API Services.")
	else
		print("[PlayerData] DataStore ready (" .. Config.DATASTORE_NAME .. ")")
	end
end

function PlayerData.isMemoryOnly(): boolean
	return memoryOnly
end

function PlayerData.get(player: Player): Inventory.Data?
	return loaded[player]
end

function PlayerData.changed(player: Player)
	local data = loaded[player]
	if data then
		Remotes.event("State"):FireClient(player, Inventory.snapshot(data))
	end
end

local function load(player: Player)
	local saved: any = nil
	local readOk = true
	if store and not memoryOnly then
		readOk = false
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return (store :: DataStore):GetAsync(key(player))
			end)
			if ok then
				saved = result
				readOk = true
				break
			end
			warn("[PlayerData] load attempt " .. attempt .. " failed: " .. tostring(result))
			task.wait(1)
		end
	else
		saved = memory[player.UserId]
	end
	if not player.Parent then
		return -- left while loading: nothing to set up (and nothing to save)
	end
	if not readOk then
		noSave[player] = true
		Remotes.event("Toast"):FireClient(player, "Your saved progress couldn't be loaded right now. Rejoin to try again; nothing here will be saved.")
	end
	local data = Inventory.reconcile(saved)
	loaded[player] = data
	print(string.format("[PlayerData] %s loaded: %d coins, %d caught%s", player.Name, data.coins, data.totalCaught, if memoryOnly then " (memory)" else ""))
	for _, fn in loadListeners do
		task.spawn(fn, player, data)
	end
	PlayerData.changed(player)
end

-- Run `fn(player, data)` right after each player's data loads.
function PlayerData.onLoad(fn: (Player, Inventory.Data) -> ())
	table.insert(loadListeners, fn)
	-- Players who loaded before this listener was added (memory-only mode loads without
	-- waiting) still get it. UNVERIFIED in Studio (2026-11-26).
	for p, data in loaded do
		task.spawn(fn, p, data)
	end
end

local function save(player: Player)
	local data = loaded[player]
	if not data or noSave[player] then
		return
	end
	memory[player.UserId] = data
	if not store or memoryOnly then
		return
	end
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(key(player), data)
	end)
	if ok then
		print("[PlayerData] saved " .. player.Name)
	else
		warn("[PlayerData] save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

function PlayerData.saveNow(player: Player)
	save(player)
end

-- Studio only (N4 review 3, the quiet approach check): stop this player's data saving for the
-- rest of the session (the same noSave flag a failed load sets), so a test run of many casts can
-- never touch a real save. Does nothing outside Studio. Returns whether it took.
function PlayerData.debugNoSave(player: Player): boolean
	if not RunService:IsStudio() then
		return false
	end
	noSave[player] = true
	print("[PlayerData] " .. player.Name .. ": saving off for this Studio session (debugNoSave)")
	return true
end

function PlayerData.start()
	openStore()
	Remotes.func("RequestState").OnServerInvoke = function(player)
		local data = loaded[player]
		return if data then Inventory.snapshot(data) else nil
	end
	Players.PlayerAdded:Connect(load)
	for _, p in Players:GetPlayers() do
		task.spawn(load, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		loaded[player] = nil
		noSave[player] = nil
	end)
	game:BindToClose(function()
		for _, p in Players:GetPlayers() do
			save(p)
		end
		if RunService:IsStudio() then
			task.wait(1)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_SECONDS)
			for _, p in Players:GetPlayers() do
				save(p)
			end
		end
	end)
end

return PlayerData
