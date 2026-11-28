--!strict
-- Studio-only helpers for the N4 two-player checks that one real player can't make alone
-- (11/28/2026). A test rig (a Humanoid dummy) stands in for the second player:
--
--  * angler: a dummy holding a hooked fish at a set fight progress (the DebugFightProgress
--    attribute, as a real angler's Studio test uses). The real player walks within 10 studs and
--    should see "Net it" at 70 percent; a press while the fish is up lands it, and the real
--    player's journal gets the assist (10 percent of the fish's price with ASSIST_BONUS_ON).
--  * seat: a dummy in the second seat of the real player's boat (a crew of two for the Deep-V,
--    a bow paddler for the canoe, a passenger for the dinghy).
--
-- Does nothing in a live game: start() returns at once outside Studio, and every function here
-- (and the Studio hooks in FishingService and BoatService) checks RunService:IsStudio().
--
-- Called from a Studio test (execute_luau in Play, on the server) through a BindableFunction,
-- so it reaches the running game's own copy of the services whatever context the test runs in:
--   local F = game:GetService("ServerStorage"):WaitForChild("DebugCoop")
--   F:Invoke("angler", Vector3.new(0, 4, 40), 0.7)          -- a dummy at the dock end at 70 percent
--   F:Invoke("state")                                       -- { open, up, text, landed, ... }
--   F:Invoke("press", "PlayerName", true)                   -- a timed press for that player
--   F:Invoke("assists", "PlayerName")                       -- { count, coins, last }
--   F:Invoke("seat", "PlayerName")                          -- a dummy in their boat's second seat
--   F:Invoke("clear")                                       -- removes every dummy
-- docs/DECISIONS.md ("Studio test helper for the N4 two-player checks") has the full check.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Server = script.Parent
local FishingService = require(Server.FishingService)
local BoatService = require(Server.BoatService)
local PlayerData = require(Server.PlayerData)

local DebugCoop = {}

local FOLDER = "DebugCoop" -- workspace folder for the rigs, and the BindableFunction's name

local function folder(): Folder
	local f = workspace:FindFirstChild(FOLDER) :: Folder?
	if not f then
		local made = Instance.new("Folder")
		made.Name = FOLDER
		made.Parent = workspace
		f = made
	end
	return f :: Folder
end

-- A plain blocky rig, if the avatar loader can't make one (no network in a local test).
local function blockRig(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Parent = m
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Color = Color3.fromRGB(70, 110, 160)
	torso.Parent = m
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.Color = Color3.fromRGB(240, 200, 160)
	head.Parent = m
	head.CFrame = root.CFrame * CFrame.new(0, 1.5, 0)
	for _, p in { torso, head } do
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = root
	end
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.Parent = m
	m.PrimaryPart = root
	return m
end

local function newRig(name: string): Model
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	local m = if ok and rig then rig else blockRig(name)
	m.Name = name
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayName = name
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	end
	return m
end

local function playerNamed(name: any): Player?
	if typeof(name) == "Instance" and name:IsA("Player") then
		return name
	end
	if type(name) == "string" then
		return Players:FindFirstChild(name) :: Player?
	end
	local all = Players:GetPlayers()
	return all[1] -- nil name: the only player in a solo test
end

local angler: Model? = nil

-- A dummy angler standing at `at` (its feet), facing `faceTo` if given, with a hooked fish at
-- `progress` (0 to 1, default 0.7). Replaces the last one. Returns the rig.
function DebugCoop.spawnAngler(at: Vector3, progress: number?, speciesId: string?, faceTo: Vector3?): Model?
	if not RunService:IsStudio() then
		return nil
	end
	if angler then
		FishingService.debugEndDummy(angler)
		angler:Destroy()
	end
	local m = newRig("TestAngler")
	local root = m:FindFirstChild("HumanoidRootPart") :: BasePart
	local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	local up = (hum and hum.HipHeight or 2) + root.Size.Y / 2
	local p = at + Vector3.new(0, up, 0)
	local look = if faceTo then Vector3.new(faceTo.X, p.Y, faceTo.Z) else p + Vector3.new(0, 0, -1)
	m:PivotTo(CFrame.lookAt(p, look))
	root.Anchored = true -- it stands still while "fighting"
	m.Parent = folder()
	angler = m
	FishingService.debugHookDummy(m, speciesId, progress or 0.7)
	return m
end

-- Move the dummy's fish to a new fight progress (below 0.66 the net goes away again).
function DebugCoop.setProgress(progress: number)
	if RunService:IsStudio() and angler then
		angler:SetAttribute("DebugFightProgress", progress)
	end
end

function DebugCoop.state(): { [string]: any }?
	if not RunService:IsStudio() or not angler then
		return nil
	end
	return FishingService.debugDummyState(angler)
end

-- Press "Net it" on the dummy for this player (the server's own checks). waitUp: wait for the
-- fish to surface first (a timed press); otherwise press now (a press while it is down misses).
function DebugCoop.pressNet(player: Player, waitUp: boolean?): string?
	if not RunService:IsStudio() or not angler then
		return nil
	end
	return FishingService.debugNetPress(player, angler, waitUp)
end

-- What the player's journal says about assists: the count, the coins and the latest entry.
function DebugCoop.assists(player: Player): { [string]: any }?
	if not RunService:IsStudio() then
		return nil
	end
	local d = PlayerData.get(player)
	local a = d and (d :: any).assists
	if not a then
		return nil
	end
	return { count = a.count, coins = a.coins, last = a.recent[#a.recent] }
end

-- A dummy in the second seat of this player's boat. Returns the rig, or nil and why.
function DebugCoop.seatInBoat(owner: Player): (Model?, string?)
	if not RunService:IsStudio() then
		return nil, "Studio only"
	end
	local m = newRig("TestCrew")
	m.Parent = folder()
	local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	local ok, why = BoatService.debugSeatSecond(owner, hum)
	if not ok then
		m:Destroy()
		return nil, why
	end
	return m, nil
end

-- Remove every dummy (and the angler's fish).
function DebugCoop.clear()
	if angler then
		FishingService.debugEndDummy(angler)
		angler = nil
	end
	local f = workspace:FindFirstChild(FOLDER)
	if f then
		f:Destroy()
	end
end

-- The entry point for tests: ServerStorage.DebugCoop:Invoke(command, ...).
local function invoke(cmd: string, a: any, b: any, c: any, d: any): any
	if cmd == "angler" then
		local m = DebugCoop.spawnAngler(a :: Vector3, b, c, d)
		return if m then m:GetFullName() else nil
	elseif cmd == "progress" then
		DebugCoop.setProgress(a :: number)
		return true
	elseif cmd == "state" then
		return DebugCoop.state()
	elseif cmd == "press" then
		local p = playerNamed(a)
		return if p then DebugCoop.pressNet(p, b == true) else "no such player"
	elseif cmd == "assists" then
		local p = playerNamed(a)
		return if p then DebugCoop.assists(p) else nil
	elseif cmd == "seat" then
		local p = playerNamed(a)
		if not p then
			return "no such player"
		end
		local m, why = DebugCoop.seatInBoat(p)
		return if m then m:GetFullName() else why
	elseif cmd == "clear" then
		DebugCoop.clear()
		return true
	end
	return "unknown command: " .. tostring(cmd)
end

-- Main calls this. Outside Studio it does nothing at all.
function DebugCoop.start()
	if not RunService:IsStudio() then
		return
	end
	local old = ServerStorage:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	local f = Instance.new("BindableFunction")
	f.Name = FOLDER
	f.OnInvoke = invoke
	f.Parent = ServerStorage
	print("[DebugCoop] ready (Studio only): ServerStorage.DebugCoop:Invoke(...)")
end

return DebugCoop
