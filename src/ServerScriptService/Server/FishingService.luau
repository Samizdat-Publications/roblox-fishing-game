--!strict
-- Server side of fishing. Owns each player's cast, bite and fight, decides the fish,
-- its size and price, and checks the client's fight result before paying out.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local FishData = require(Shared.FishData)
local BaitData = require(Shared.BaitData)
local FishLogic = require(Shared.FishLogic)
local FightModel = require(Shared.FightModel)
local Inventory = require(Shared.Inventory)
local Remotes = require(Shared.Remotes)

local Server = script.Parent
local PlayerData = require(Server.PlayerData)
local WorldBuilder = require(Server.WorldBuilder)
local RodService = require(Server.RodService)

local FishingService = {}

type Session = {
	phase: string, -- Idle, Waiting, Bite, Fighting
	token: number,
	bobber: BasePart?,
	land: Vector3?,
	spot: string?,
	period: string?,
	bait: string?,
	weights: { FishLogic.Weight }?,
	species: string?,
	fightStart: number,
	minSecs: number,
}

local sessions: { [Player]: Session } = {}
local rng = Random.new()
local zones = WorldBuilder.zones()
local waterCF, waterSize = WorldBuilder.water()

local fishingEvent: RemoteEvent
local toastEvent: RemoteEvent

local function session(player: Player): Session
	local s = sessions[player]
	if not s then
		s = { phase = "Idle", token = 0, fightStart = 0, minSecs = 0 }
		sessions[player] = s
	end
	return s
end

local function send(player: Player, kind: string, payload: any?)
	fishingEvent:FireClient(player, kind, payload or {})
end

local function toast(player: Player, text: string)
	toastEvent:FireClient(player, text)
end

local function cleanup(s: Session)
	s.token += 1
	if s.bobber then
		s.bobber:Destroy()
		s.bobber = nil
	end
	s.phase = "Idle"
	s.species = nil
	s.weights = nil
end

local function reset(player: Player, s: Session)
	cleanup(s)
	send(player, "Reset")
end

local function makeBobber(player: Player, pos: Vector3): BasePart
	local b = Instance.new("Part")
	b.Name = "Bobber_" .. player.Name
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.new(0.8, 0.8, 0.8)
	b.Color = Color3.fromRGB(230, 60, 50)
	b.Material = Enum.Material.SmoothPlastic
	b.Anchored = true
	b.CanCollide = false
	b.CanQuery = false
	b.CanTouch = false
	b.Position = pos
	local top = Instance.new("Part")
	top.Name = "Top"
	top.Shape = Enum.PartType.Ball
	top.Size = Vector3.new(0.5, 0.5, 0.5)
	top.Color = Color3.new(1, 1, 1)
	top.Anchored = true
	top.CanCollide = false
	top.CanQuery = false
	top.CanTouch = false
	top.Position = pos + Vector3.new(0, 0.4, 0)
	top.Parent = b
	local att = Instance.new("Attachment")
	att.Name = "LineEnd"
	att.Position = Vector3.new(0, 0.4, 0)
	att.Parent = b
	local tip = RodService.tip(player)
	if tip then
		local beam = Instance.new("Beam")
		beam.Name = "Line"
		beam.Attachment0 = tip
		beam.Attachment1 = att
		beam.Width0 = 0.04
		beam.Width1 = 0.04
		beam.Color = ColorSequence.new(Color3.fromRGB(235, 235, 235))
		beam.FaceCamera = true
		beam.CurveSize0 = 0
		beam.CurveSize1 = -2
		beam.Segments = 12
		beam.Parent = b
	end
	b.Parent = workspace
	return b
end

local function setBobberY(s: Session, dy: number)
	local b = s.bobber
	if b and s.land then
		local base = Vector3.new(s.land.X, 0.3 + dy, s.land.Z)
		b.Position = base
		local top = b:FindFirstChild("Top") :: BasePart?
		if top then
			top.Position = base + Vector3.new(0, 0.4, 0)
		end
	end
end

local scheduleBite: (Player, Session) -> ()

local function nothingHint(s: Session): string
	local bait = BaitData.byId[s.bait or ""]
	local where = FishLogic.SPOT_NAMES[s.spot or "OpenWater"] or "here"
	return string.format("Nothing wants %s at %s right now. Try another bait, another spot, or another time of day.", bait and bait.name:lower() or "that", where)
end

function scheduleBite(player: Player, s: Session)
	local token = s.token
	local delay = FishLogic.biteDelay(s.weights or {}, rng)
	if not delay then
		task.delay(Config.NOTHING_WAIT, function()
			if s.token == token and s.phase == "Waiting" then
				send(player, "Hint", { text = nothingHint(s) })
				reset(player, s)
			end
		end)
		return
	end
	task.delay(delay, function()
		if s.token ~= token or s.phase ~= "Waiting" then
			return
		end
		s.species = FishLogic.pickSpecies(s.weights or {}, rng)
		s.phase = "Bite"
		setBobberY(s, -0.6)
		send(player, "Bite")
		task.delay(Config.HOOK_WINDOW, function()
			if s.token == token and s.phase == "Bite" then
				s.phase = "Waiting"
				setBobberY(s, 0)
				send(player, "Missed", { text = "Too slow! It spat the hook. Wait for another bite." })
				scheduleBite(player, s)
			end
		end)
	end)
end

local function onCast(player: Player, dir: any, power: any)
	local s = session(player)
	local data = PlayerData.get(player)
	if s.phase ~= "Idle" or not data then
		return
	end
	if typeof(dir) ~= "Vector3" or type(power) ~= "number" or power ~= power then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		return
	end
	if hum:GetState() == Enum.HumanoidStateType.Swimming then
		send(player, "Hint", { text = "Climb out of the water to cast." })
		return
	end
	if Inventory.bagFull(data) then
		send(player, "Hint", { text = "Your bag is full. Sell your fish at the Fish Buyer." })
		return
	end
	local baitId = data.equipped
	if not Inventory.hasBait(data, baitId) then
		local usable = Inventory.usable(data)
		if #usable > 0 then
			data.equipped = usable[1]
			baitId = usable[1]
			toast(player, "Out of that bait. Switched to " .. BaitData.byId[baitId].name .. ".")
			PlayerData.changed(player)
		elseif Inventory.freeWormsIfStuck(data) then
			baitId = "Worm"
			toast(player, "Out of bait and coins, so the shopkeeper tossed you " .. Config.FREE_WORMS .. " free worms.")
			PlayerData.changed(player)
		else
			send(player, "Hint", { text = "You're out of bait. Visit Bait and Tackle." })
			return
		end
	end

	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.01 then
		flat = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	flat = flat.Unit
	local p = math.clamp(power, 0, 1)
	local dist = Config.CAST_MIN + p * Config.CAST_RANGE
	local landing = hrp.Position + flat * dist
	landing = Vector3.new(landing.X, 0.3, landing.Z)
	if not FishLogic.isOnWater(landing, waterCF, waterSize) then
		send(player, "Hint", { text = "That landed on dry ground. Face the water and cast." })
		return
	end

	cleanup(s)
	s.phase = "Waiting"
	s.land = landing
	s.spot = FishLogic.spotAt(landing, zones)
	s.period = FishLogic.periodFromClock(Lighting.ClockTime)
	s.bait = baitId
	s.weights = FishLogic.biteWeights(s.spot :: string, s.period :: string, baitId)
	s.bobber = makeBobber(player, landing)
	send(player, "Landed", {
		pos = landing,
		spot = s.spot,
		spotName = FishLogic.SPOT_NAMES[s.spot :: string],
		bait = baitId,
	})
	scheduleBite(player, s)
end

local function onHook(player: Player)
	local s = session(player)
	local data = PlayerData.get(player)
	if s.phase ~= "Bite" or not s.species or not data then
		return
	end
	local species = FishData.byId[s.species :: string]
	Inventory.consumeBait(data, s.bait or "")
	PlayerData.changed(player)
	s.phase = "Fighting"
	s.fightStart = os.clock()
	s.minSecs = FightModel.minSeconds(species.fight, data.assist)
	setBobberY(s, -1)
	local token = s.token
	send(player, "Hooked", {
		fight = species.fight,
		assist = data.assist,
		seed = rng:NextInteger(1, 1e6),
		note = species.fightNote,
	})
	task.delay(Config.FIGHT_MAX_SECONDS, function()
		if s.token == token and s.phase == "Fighting" then
			send(player, "Escaped", { text = "The line went slack. It got away." })
			cleanup(s)
		end
	end)
end

local function onFightResult(player: Player, won: any)
	local s = session(player)
	local data = PlayerData.get(player)
	if s.phase ~= "Fighting" or not data or not s.species then
		return
	end
	local elapsed = os.clock() - s.fightStart
	local species = FishData.byId[s.species :: string]
	if won ~= true or elapsed < s.minSecs * 0.9 then
		if won == true then
			warn(string.format("[Fishing] %s reported a win too fast (%.2fs < %.2fs); counted as escape", player.Name, elapsed, s.minSecs))
		end
		send(player, "Escaped", { text = "It got away! " .. species.fightNote })
		cleanup(s)
		return
	end
	local cm, kg = FishLogic.rollSize(species, rng)
	local fish: Inventory.Fish = {
		id = species.id,
		name = species.name,
		cm = cm,
		kg = kg,
		price = FishLogic.priceFor(species, kg),
		bait = s.bait or "",
		spot = s.spot or "OpenWater",
		period = s.period or "Day",
		at = os.time(),
	}
	local first = (data.journal.counts[species.id] or 0) == 0
	local best = Inventory.recordCatch(data, fish)
	print(string.format("[Fishing] %s caught %s %.1f cm %.2f kg worth %d at %s (%s, %s)", player.Name, fish.name, cm, kg, fish.price, fish.spot, fish.period, fish.bait))
	send(player, "Caught", { fish = fish, best = best, first = first, habit = species.habit })
	cleanup(s)
	PlayerData.changed(player)
end

local function onCancel(player: Player)
	local s = session(player)
	if s.phase == "Waiting" or s.phase == "Bite" then
		reset(player, s)
	elseif s.phase == "Fighting" then
		send(player, "Escaped", { text = "You let it go." })
		cleanup(s)
	end
end

-- For tests: force the next bite to come right away.
function FishingService.debugState(player: Player): any
	local s = session(player)
	return { phase = s.phase, spot = s.spot, period = s.period, bait = s.bait, species = s.species }
end

function FishingService.start()
	fishingEvent = Remotes.event("FishingEvent")
	toastEvent = Remotes.event("Toast")
	Remotes.event("Cast").OnServerEvent:Connect(onCast)
	Remotes.event("Hook").OnServerEvent:Connect(onHook)
	Remotes.event("FightResult").OnServerEvent:Connect(onFightResult)
	Remotes.event("CancelCast").OnServerEvent:Connect(onCancel)
	Players.PlayerRemoving:Connect(function(player)
		local s = sessions[player]
		if s then
			cleanup(s)
			sessions[player] = nil
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(function()
			local s = sessions[player]
			if s and s.phase ~= "Idle" then
				reset(player, s)
			end
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterRemoving:Connect(function()
			local s = sessions[player]
			if s and s.phase ~= "Idle" then
				reset(player, s)
			end
		end)
	end
	print("[Fishing] ready")
end

return FishingService
