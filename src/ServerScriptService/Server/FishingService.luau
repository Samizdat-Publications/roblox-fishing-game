--!strict
-- Server side of fishing. Owns each player's cast, bite and fight, decides the fish,
-- its size and price, and checks the client's fight result before paying out.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local FishData = require(Shared.FishData)
local BaitData = require(Shared.BaitData)
local FishLogic = require(Shared.FishLogic)
local FightModel = require(Shared.FightModel)
local Units = require(Shared.Units)
local Inventory = require(Shared.Inventory)
local RodData = require(Shared.RodData)
local Rarity = require(Shared.Rarity)
local Remotes = require(Shared.Remotes)
local CastLogic = require(Shared.CastLogic)
local WaterMap = require(Shared.WaterMap)
local Cover = require(Shared.Cover)
local Advice = require(Shared.Advice)
local Rises = require(Shared.Rises)
local BaitRig = require(Shared.BaitRig)
local Approach = require(Shared.Approach)
local BobberCam = require(Shared.BobberCam)

local Server = script.Parent
local PlayerData = require(Server.PlayerData)
local RodService = require(Server.RodService)
local GoalService = require(Server.GoalService)
local WeatherService = require(Server.WeatherService)
local Weather = require(Shared.Weather)
local Frenzy = require(Shared.Frenzy)
local FrenzyService = require(Server.FrenzyService)
local Teamwork = require(Shared.Teamwork)
local BoatService = require(Server.BoatService)
local RiseService = require(Server.RiseService)

local FishingService = {}

-- The live bait on the hook (L3): which bait, the hook size it's on and how well it went on.
-- It stays on through missed bites and lost fights' casts until a fish takes it, a snag
-- strips it, or the player re-baits.
type Rig = { bait: string, hook: string, grade: BaitRig.Grade }

-- The fish coming for the bait (L4): picked and sized when its approach starts, so the
-- client's shadow matches what lands. `biteAt` is os.clock() of the strike (or, for a
-- looker, of the moment it leaves).
type Coming = {
	species: string,
	cm: number,
	kg: number,
	class: string,
	leaves: boolean,
	biteAt: number,
	hushed: boolean, -- the held breath has started (twitches no longer change anything)
	striking: boolean, -- the nibbles and bite are running
}

type Session = {
	phase: string, -- Idle, Waiting, Snagged, Bite, Fighting
	token: number,
	nibbling: boolean?, -- a fish is testing the bait (small dips before the real bite)
	bobber: BasePart?,
	land: Vector3?,
	spot: string?,
	period: string?,
	bait: string?,
	weights: { FishLogic.Weight }?,
	species: string?,
	fightStart: number,
	minSecs: number,
	catch: { cm: number, kg: number, class: string }?, -- rolled when the fish's approach starts (L4)
	coming: Coming?, -- the fish approaching the bait (L4)
	waitGen: number, -- bumps whenever the bite timeline is re-planned (L4), so stale timers stop
	twitches: Approach.Twitches, -- recent twitches, for spooks (L4)
	extraDelay: number, -- added to the next approach after a spook (L4)
	tight: boolean?, -- this cast landed tight to cover (L2b)
	fastBite: number?, -- a claimed rise: the next bite comes this many seconds after the cast (L2b)
	snag: Cover.Snag?, -- a snagged cast being wiggled free (L2b)
	rig: Rig?, -- the bait on the hook (L3); not cleared by cleanup()
	rigEmptyAt: number, -- os.clock() when the hook last went empty (a bench can't start sooner)
	lastRigAt: number, -- os.clock() of the last Rig accepted (rate limit)
}

local RIG_MIN_GAP = 0.5 -- seconds between Rig messages the server will look at
local RIG_LATENCY = 0.5 -- slack when checking a bench run against the server's clock

local sessions: { [Player]: Session } = {}
local rng = Random.new()
-- The lake, the creek and (when it's switched on) the channel and the Big Lake. The client's
-- landing ring reads the same WaterMap. Big Lake part UNVERIFIED in Studio, 2026-11-26.
local zones = WaterMap.castZones()
local waters = WaterMap.castWaters()

local fishingEvent: RemoteEvent
local toastEvent: RemoteEvent

local function session(player: Player): Session
	local s = sessions[player]
	if not s then
		s = {
			phase = "Idle",
			token = 0,
			fightStart = 0,
			minSecs = 0,
			rigEmptyAt = os.clock(),
			lastRigAt = 0,
			waitGen = 0,
			twitches = Approach.newTwitches(),
			extraDelay = 0,
		}
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
	s.tight = nil
	s.fastBite = nil
	s.snag = nil
	s.coming = nil
	s.waitGen += 1
	s.twitches = Approach.newTwitches()
	s.extraDelay = 0
end

-- The bait on the hook for a cast with `baitId`, or nil for a lure (or a stale rig).
local function rigFor(s: Session, baitId: string?): Rig?
	local bait = BaitData.byId[baitId or ""]
	local r = s.rig
	if bait and bait.kind == "live" and r and r.bait == bait.id then
		return r
	end
	return nil
end

local function sendRig(player: Player, s: Session, extra: { [string]: any }?)
	local r = s.rig
	if r then
		local payload: { [string]: any } = { bait = r.bait, hook = r.hook, grade = r.grade }
		for k, v in extra or {} do
			payload[k] = v
		end
		send(player, "Rigged", payload)
	else
		send(player, "RigEmpty")
	end
end

-- The live bait came off (a fish took it, or a snag stripped it): the next cast opens the bench.
local function emptyHook(player: Player, s: Session)
	s.rig = nil
	s.rigEmptyAt = os.clock()
	send(player, "RigEmpty")
end

local function reset(player: Player, s: Session)
	cleanup(s)
	send(player, "Reset")
end

local TOP_RISE = 0.4 * BobberCam.BOBBER_SCALE -- the gray-box bobber's white top sits this far up

local function makeBobber(player: Player, pos: Vector3): BasePart
	local b: BasePart
	local glowOn: BasePart
	local lineY = 0.4
	local art = ServerStorage:FindFirstChild("Art")
	local model = art and art:FindFirstChild("Bobber")
	local mesh = model and model:FindFirstChildWhichIsA("MeshPart", true)
	if mesh then
		-- Our bobber model (art/README.md), riding with its middle on the waterline.
		b = mesh:Clone()
		b:ClearAllChildren()
		b.Name = "Bobber_" .. player.Name
		b.Size = mesh.Size * BobberCam.BOBBER_SCALE -- bigger, so it reads while you wait (L4)
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.Position = pos
		glowOn = b
		lineY = b.Size.Y / 2
	else
		b = Instance.new("Part")
		b.Name = "Bobber_" .. player.Name
		b.Shape = Enum.PartType.Ball
		b.Size = Vector3.one * 0.8 * BobberCam.BOBBER_SCALE
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
		top.Size = Vector3.one * 0.5 * BobberCam.BOBBER_SCALE
		top.Color = Color3.new(1, 1, 1)
		top.Anchored = true
		top.CanCollide = false
		top.CanQuery = false
		top.CanTouch = false
		top.Position = pos + Vector3.new(0, TOP_RISE, 0)
		top.Parent = b
		glowOn = top
	end
	local glow = Instance.new("PointLight") -- so the bobber shows at night
	glow.Range = 7
	glow.Brightness = 1.2
	glow.Color = Color3.fromRGB(255, 240, 220)
	glow.Parent = glowOn
	local att = Instance.new("Attachment")
	att.Name = "LineEnd"
	att.Position = Vector3.new(0, lineY, 0)
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
			top.Position = base + Vector3.new(0, TOP_RISE, 0)
		end
	end
end

local scheduleBite: (Player, Session) -> ()

-- Names a better choice: the best bait you own for this spot now, or the best spot you can
-- reach for this bait now (Shared/Advice.luau).
local function nothingHint(player: Player, s: Session): string
	local now = WeatherService.now()
	local because = Weather.hint(now)
	if because then
		return because
	end
	local data = PlayerData.get(player)
	local owned = if data then Inventory.usable(data) else {}
	local spots = Advice.reachableSpots(data ~= nil and data.creekPass, if data then data.boats else nil)
	return Advice.nothingText(s.spot or "OpenWater", s.period or "Day", s.bait or "", owned, spots, now)
end

-- The size of the fish coming in (server random only): trophies and monsters fight harder
-- and their shadows are bigger. In Studio a DebugSizeClass attribute forces one.
local function rollComing(player: Player, species: FishData.Species): (number, number, string)
	local cm, kg, class = FishLogic.rollCatch(species, rng)
	local forced = if RunService:IsStudio() then player:GetAttribute("DebugSizeClass") else nil
	if forced == "trophy" or forced == "monster" then
		class = forced
		cm = species.maxCm * (if forced == "monster" then 1.35 else 1.0)
		kg = math.floor(species.weightCoef * cm ^ 3 * 100 + 0.5) / 100
	end
	return cm, kg, class
end

local function stale(s: Session, token: number, gen: number): boolean
	return s.token ~= token or s.waitGen ~= gen or s.phase ~= "Waiting"
end

-- The fish takes the bait: nibblers dip the bobber a couple of times first (those dips aren't
-- the bite), slams yank it deep, pulls drag it under slowly and give a little longer to react.
local function strike(player: Player, s: Session, token: number)
	local c = s.coming
	if not c then
		return
	end
	local species = FishData.byId[c.species]
	if not species then
		return
	end
	c.striking = true
	local pattern = FishLogic.bitePattern(species)
	s.nibbling = pattern.predips > 0
	for _ = 1, pattern.predips do
		setBobberY(s, -0.25)
		send(player, "Dip") -- the client plays the nibble sound
		task.wait(0.18)
		if s.token ~= token or s.phase ~= "Waiting" then
			return
		end
		setBobberY(s, 0)
		task.wait(pattern.dipGap)
		if s.token ~= token or s.phase ~= "Waiting" then
			return
		end
	end
	s.nibbling = false
	s.coming = nil
	s.species = c.species
	s.catch = { cm = c.cm, kg = c.kg, class = c.class }
	s.phase = "Bite"
	setBobberY(s, -pattern.depth)
	send(player, "Bite", { style = pattern.style })
	task.delay(pattern.hookWindow, function()
		if s.token == token and s.phase == "Bite" then
			s.phase = "Waiting"
			s.species = nil
			s.catch = nil
			setBobberY(s, 0)
			send(player, "Missed", { text = "Too slow! It spat the hook. Wait for another bite." })
			scheduleBite(player, s)
		end
	end)
end

-- A fish swims off without biting: it looked and left, or a twitch spooked it. A fresh
-- approach (a new fish, a new roll) is planned after the normal delay.
local function leave(player: Player, s: Session, spooked: boolean)
	local c = s.coming
	s.coming = nil
	if spooked then
		s.extraDelay = Approach.SPOOK_DELAY
	end
	print(string.format("[Fishing] %s: the %s %s", player.Name, if c then c.species else "fish", if spooked then "was spooked and swam off" else "looked and left"))
	send(player, "Leave", { spooked = spooked })
	scheduleBite(player, s)
end

-- Runs the coming fish's timeline: the held breath HUSH_TIME before the strike, then the
-- strike (or, for a looker, leaving at the moment it would have bitten). A twitch that moves
-- the strike bumps waitGen and starts this again, so the old timer just stops.
local function runComing(player: Player, s: Session)
	local token, gen = s.token, s.waitGen
	task.spawn(function()
		while true do
			if stale(s, token, gen) then
				return
			end
			local c = s.coming
			if not c then
				return
			end
			local now = os.clock()
			if c.leaves then
				if now >= c.biteAt then
					leave(player, s, false)
					return
				end
				task.wait(c.biteAt - now)
			elseif not c.hushed then
				local hushAt = c.biteAt - Approach.HUSH_TIME
				if now >= hushAt then
					c.hushed = true
					send(player, "Hush") -- the held breath: everything goes quiet
				else
					task.wait(hushAt - now)
				end
			elseif now >= c.biteAt then
				strike(player, s, token)
				return
			else
				task.wait(c.biteAt - now)
			end
		end
	end)
end

-- A fish starts its approach: pick it and size it now, so its shadow matches the catch.
local function startComing(player: Player, s: Session, plan: Approach.Plan, fromRise: boolean)
	local speciesId = FishLogic.pickSpecies(s.weights or {}, rng)
	local species = speciesId and FishData.byId[speciesId]
	if not species then
		return
	end
	local cm, kg, class = rollComing(player, species)
	s.coming = {
		species = species.id,
		cm = cm,
		kg = kg,
		class = class,
		leaves = plan.leaves,
		biteAt = os.clock() + plan.biteIn,
		hushed = false,
		striking = false,
	}
	Approach.onApproach(s.twitches)
	local len = Approach.shadowLength(cm)
	local size = Approach.sizeClass(cm)
	print(string.format(
		"[Fishing] %s: %s approaching, %.1f cm %s (shadow %s, %.2f studs), %s in %.1fs",
		player.Name,
		species.id,
		cm,
		class,
		size,
		len,
		if plan.leaves then "leaves" else "bites",
		plan.biteIn
	))
	send(player, "Approach", {
		size = size,
		length = len,
		pos = s.land,
		biteIn = plan.biteIn,
		swell = Approach.announces(Rarity.of(species), species.mouth),
		rise = fromRise,
	})
	runComing(player, s)
end

function scheduleBite(player: Player, s: Session)
	local token = s.token
	s.waitGen += 1
	local gen = s.waitGen
	s.coming = nil
	local delay = FishLogic.biteDelay(s.weights or {}, rng)
	if delay then
		delay = Cover.adjustDelay(delay, s.tight == true) -- fish hold tight to cover
	end
	if delay and FrenzyService.at(s.spot) then
		delay *= Frenzy.BITE_SPEED -- the school is boiling: bites come back to back
	end
	local rig = rigFor(s, s.bait)
	if delay and rig then
		delay *= BaitRig.biteMult(rig.grade) -- well-baited hooks get bit sooner (L3); Okay is x1
	end
	local fromRise = false
	if delay and s.fastBite then
		delay = s.fastBite -- cast onto a rise: that fish takes it right away (first bite only)
		fromRise = true
	end
	s.fastBite = nil
	if not delay then
		task.delay(Config.NOTHING_WAIT, function()
			if s.token == token and s.phase == "Waiting" then
				send(player, "Hint", { text = nothingHint(player, s) })
				reset(player, s)
			end
		end)
		return
	end
	-- Each attempt waits a scaled delay and a quarter of fish look and leave, so the average
	-- wait is the old one (Shared/Approach.luau). After a spook the next one waits longer.
	local attempt = Approach.attemptDelay(delay, fromRise) + s.extraDelay
	s.extraDelay = 0
	local plan = Approach.plan(attempt, rng, fromRise)
	print(string.format(
		"[Fishing] %s bite in %.1fs (%s, %s), approach in %.1fs%s",
		player.Name,
		attempt,
		s.bait or "?",
		if rig then rig.grade else "lure",
		plan.approachIn,
		if plan.leaves then ", a looker" else ""
	))
	task.delay(plan.approachIn, function()
		if not stale(s, token, gen) then
			startComing(player, s, plan, fromRise)
		end
	end)
end

-- A quick tap while waiting (L4): the client jiggles the bait at once; here the fish reacts.
local function onTwitch(player: Player)
	local s = session(player)
	if s.phase ~= "Waiting" or s.nibbling then
		return
	end
	local now = os.clock()
	local c = s.coming
	local open = c ~= nil and not c.hushed and not c.striking and now < c.biteAt - Approach.HUSH_TIME
	local kind, sooner = Approach.twitch(s.twitches, now, open, rng)
	if kind == "spook" then
		leave(player, s, true)
	elseif kind == "sooner" and c then
		local wasLooker = c.leaves
		if wasLooker and rng:NextNumber() >= Approach.TWITCH_KEEP then
			print(string.format("[Fishing] %s twitched: %s wasn't fooled and is still leaving", player.Name, c.species))
			return
		end
		c.leaves = false
		local before = c.biteAt
		c.biteAt = Approach.soonerBiteAt(c.biteAt, now, sooner)
		print(string.format(
			"[Fishing] %s twitched: %s%s, bite %.1fs sooner (in %.1fs)",
			player.Name,
			c.species,
			if wasLooker then " stays (was leaving)" else " likes it",
			before - c.biteAt,
			c.biteAt - now
		))
		s.waitGen += 1
		runComing(player, s)
	end
end

local function onCast(player: Player, dir: any, power: any, clientLanding: any)
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
	local p = math.clamp(power, 0, 1)
	-- Shared with the client's landing ring (CastLogic), so the ring shows where this lands.
	-- The rod's and lure's extra reach grows with power, so a soft cast stays short with any
	-- rod (the creek is only 12 studs wide).
	local origin = hrp.Position
	local landing = CastLogic.landing(origin, flat, p, data.rod, baitId)
	if landing then
		landing = CastLogic.assist(landing, origin, waters, FishLogic.isOnWaterAny)
	end
	if not landing then
		send(player, "Hint", { text = "That landed on dry ground. Face the water and cast." })
		return
	end
	-- The client sends the point its ring showed. Use it when it is close to ours, so lag
	-- or a slightly different frame never moves the bobber away from the ring.
	if typeof(clientLanding) == "Vector3" then
		local c = clientLanding :: Vector3
		local finite = c.X == c.X and c.Z == c.Z and math.abs(c.X) < 1e6 and math.abs(c.Z) < 1e6
		if finite and CastLogic.flatDistance(c, landing) <= CastLogic.ACCEPT then
			local cl = Vector3.new(c.X, CastLogic.LAND_Y, c.Z)
			if FishLogic.isOnWaterAny(cl, waters) then
				landing = cl
			end
		end
	end
	local boatOk, boatMsg = BoatService.castCheck(player, landing)
	if not boatOk then
		send(player, "Hint", { text = boatMsg or "You can't cast there from here." })
		return
	end
	if FishLogic.CREEK_SPOTS[FishLogic.spotAt(landing, zones)] and not data.creekPass then
		send(player, "Hint", { text = "Cedar Creek needs a Creek Pass. Get one at the gate on the west path." })
		return
	end

	cleanup(s)
	s.land = landing
	s.spot = FishLogic.spotAt(landing, zones)
	s.period = FishLogic.periodFromClock(Lighting.ClockTime)
	s.bait = baitId
	s.bobber = makeBobber(player, landing)
	-- Live bait goes on the hook now if the bench wasn't used (Quick Bait, a skip, or a bait
	-- switch the client didn't bench): Okay, exactly the game before L3.
	local current = rigFor(s, baitId)
	if BaitData.byId[baitId].kind == "live" and (not current or current.hook ~= data.hook) then
		s.rig = { bait = baitId, hook = data.hook, grade = "Okay" }
		sendRig(player, s)
	end

	-- Right on a log, or deep in the weed bed with bait that isn't weedless: snagged (L2b).
	-- Each press of the cast button sends a Wiggle; SNAG_WIGGLES of them in SNAG_TIME free it.
	if Cover.snagAt(landing, baitId) then
		s.phase = "Snagged"
		s.snag = Cover.newSnag(os.clock())
		send(player, "Snag", { pos = landing })
		local token = s.token
		task.delay(Cover.SNAG_TIME, function()
			if s.token == token and s.phase == "Snagged" then
				local bait = BaitData.byId[s.bait or ""]
				local now = PlayerData.get(player)
				if now and Cover.losesBait(bait and bait.kind, false, 1) then
					Inventory.consumeBait(now, s.bait or "")
					PlayerData.changed(player)
					if rigFor(s, s.bait) then
						emptyHook(player, s)
					end
				end
				cleanup(s)
				send(player, "Snapped", { text = "The line snapped on the snag." })
			end
		end)
		return
	end

	s.phase = "Waiting"
	s.tight = Cover.tightAt(landing, baitId)
	s.weights = FishLogic.biteWeights(s.spot :: string, s.period :: string, baitId, WeatherService.now())
	s.weights = Cover.applyCover(s.weights :: { FishLogic.Weight }, s.tight == true)
	if FrenzyService.at(s.spot) then
		s.weights = Frenzy.weights(s.weights :: { FishLogic.Weight }, s.spot :: string)
	end
	-- A cast onto an open rise claims it: a quick bite, if anything here wants this bait.
	if #(s.weights :: { FishLogic.Weight }) > 0 and RiseService.claim(player, landing) then
		s.fastBite = Rises.biteDelay(rng)
	end
	send(player, "Landed", {
		pos = landing,
		spot = s.spot,
		spotName = FishLogic.SPOT_NAMES[s.spot :: string],
		bait = baitId,
		tight = s.tight,
		rise = s.fastBite ~= nil,
	})
	scheduleBite(player, s)
end

-- One press of the cast button while snagged.
local function onWiggle(player: Player)
	local s = session(player)
	local data = PlayerData.get(player)
	if s.phase ~= "Snagged" or not s.snag or not data then
		return
	end
	local snag = s.snag :: Cover.Snag
	local result = Cover.wiggle(snag, os.clock())
	if result == "counted" then
		send(player, "Wiggled", { count = snag.count, need = Cover.SNAG_WIGGLES })
	elseif result == "freed" then
		local bait = BaitData.byId[s.bait or ""]
		local lost = Cover.losesBait(bait and bait.kind, true, rng:NextNumber())
		if lost then
			Inventory.consumeBait(data, s.bait or "")
			PlayerData.changed(player)
			if rigFor(s, s.bait) then
				emptyHook(player, s)
			end
		end
		cleanup(s)
		send(player, "Freed", {
			text = if lost then "Wiggled free, but the bait came off on the snag." else "Wiggled free!",
			lost = lost,
		})
	end
	-- "ignored" (too fast) and "expired" (the snap timer handles it) do nothing.
end

-- The bait bench's result (L3). The client sends its presses; the server grades them again
-- with the same BaitRig rules and refuses a timeline no real player could make (refused is
-- Okay). A skip (hold, or the Skip button) is Okay too, and just sets the hook size.
local function onRig(player: Player, baitId: any, hook: any, timeline: any, skipped: any)
	local s = session(player)
	local data = PlayerData.get(player)
	local now = os.clock()
	if not data or now - s.lastRigAt < RIG_MIN_GAP then
		return
	end
	if not BaitRig.isHook(hook) then
		return
	end
	s.lastRigAt = now
	data.hook = hook :: string
	local bait = type(baitId) == "string" and BaitData.byId[baitId] or nil
	if s.phase ~= "Idle" or not bait or bait.kind ~= "live" or not Inventory.hasBait(data, bait.id) then
		-- Only the hook size changes (the Tackle Box, a lure, or mid-cast). A rig on the old
		-- size comes off at the next cast (see onCast).
		PlayerData.changed(player)
		return
	end
	local grade: BaitRig.Grade = "Okay"
	local refused: string? = nil
	if skipped ~= true then
		local firstTime = data.tackle.best[bait.id] == nil
		grade, refused = BaitRig.grade(bait.id, timeline, firstTime)
		-- The bench can't have taken longer than the time since the hook went empty.
		if not refused and type(timeline) == "table" and #timeline > 0 then
			local last = timeline[#timeline]
			if type(last) == "table" and type(last.up) == "number" and last.up > now - s.rigEmptyAt + RIG_LATENCY then
				refused = "longer than the hook has been empty"
				grade = "Okay"
			end
		end
		if refused then
			warn(string.format("[Fishing] %s's %s bench refused (%s); counted as Okay", player.Name, bait.id, refused))
		else
			BaitRig.record(data.tackle, bait.id, grade)
		end
	end
	s.rig = { bait = bait.id, hook = hook :: string, grade = grade }
	s.rigEmptyAt = now
	print(string.format("[Fishing] %s baited %s on a %s hook: %s%s", player.Name, bait.id, hook, grade, if skipped == true then " (skipped)" else ""))
	sendRig(player, s, { refused = refused ~= nil, skipped = skipped == true })
	PlayerData.changed(player)
end

local function onHook(player: Player)
	local s = session(player)
	local data = PlayerData.get(player)
	if s.phase ~= "Bite" or not s.species or not data then
		return
	end
	local species = FishData.byId[s.species :: string]
	-- A hook that doesn't fit the fish's mouth can fail to set (L3). The fish swims off with
	-- the bait still on the hook, like a slow strike: wait for another bite.
	local rig = rigFor(s, s.bait)
	if rig and rng:NextNumber() < BaitRig.missChance(rig.hook, species.mouth, true) then
		s.token += 1 -- the bite's hook-window timer belongs to the fish that just left
		s.phase = "Waiting"
		s.species = nil
		s.catch = nil
		setBobberY(s, 0)
		print(string.format("[Fishing] %s: %s spat a %s hook", player.Name, species.id, rig.hook))
		send(player, "Missed", { text = BaitRig.spitText(rig.hook, species.mouth, species.name), hookSize = true })
		scheduleBite(player, s)
		return
	end
	-- The fish takes the live bait. A Perfect bait has an even chance of staying on (L3).
	local kept = false
	if rig then
		kept = BaitRig.survives(rig.grade, rng:NextNumber())
	end
	if not kept then
		Inventory.consumeBait(data, s.bait or "")
	end
	PlayerData.changed(player)
	local start = BaitRig.fightStart(if rig then rig.grade else nil)
	if rig and not kept then
		emptyHook(player, s)
	elseif rig and kept then
		sendRig(player, s, { kept = true })
	end
	s.phase = "Fighting"
	s.fightStart = os.clock()
	-- The fish was picked and sized when its approach started (L4), so the shadow matched it.
	local rolled = s.catch
	local cm, kg, class
	if rolled then
		cm, kg, class = rolled.cm, rolled.kg, rolled.class
	else
		cm, kg, class = rollComing(player, species)
	end
	s.catch = { cm = cm, kg = kg, class = class }
	print(string.format("[Fishing] %s hooked size: %s %.1f cm %s, its shadow was %.2f studs", player.Name, species.id, cm, class, Approach.shadowLength(cm)))
	local profile = FishLogic.fightFor(species.fight, class)
	s.minSecs = FightModel.minSeconds(profile, data.assist, start)
	print(string.format("[Fishing] %s hooked %s, fight starts at %.2f (%s)", player.Name, species.id, start, if rig then rig.grade else "lure"))
	setBobberY(s, -1)
	local token = s.token
	send(player, "Hooked", {
		fight = RodData.applyFight(profile, data.rod),
		assist = data.assist,
		seed = rng:NextInteger(1, 1e6),
		start = start,
		note = species.fightNote,
		sizeClass = class,
		tier = Rarity.of(species),
	})
	task.delay(Config.FIGHT_MAX_SECONDS, function()
		if s.token == token and s.phase == "Fighting" then
			send(player, "Escaped", { text = "The line went slack. It got away." })
			cleanup(s)
		end
	end)
end

-- The species' own model from ServerStorage.Art (art/README.md), stretched to this fish's
-- length, or nil for species that only have a Blender preview so far.
local function artFish(species: FishData.Species, len: number): BasePart?
	local art = ServerStorage:FindFirstChild("Art")
	local source = art and art:FindFirstChild(species.id)
	local mesh = source and source:FindFirstChildWhichIsA("MeshPart", true)
	if not mesh then
		return nil
	end
	local part = mesh:Clone()
	part:ClearAllChildren()
	part.Name = "Body"
	part.Size = mesh.Size * (len / mesh.Size.X) -- the model's length runs along X
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

-- Hold the landed fish up on the line for a moment (everyone nearby sees it).
local function showCatch(player: Player, species: FishData.Species, cm: number)
	local tip = RodService.tip(player)
	if not tip then
		return
	end
	local len = Approach.shadowLength(cm) -- studs; the same length as its shadow was (L4)
	local m = Instance.new("Model")
	m.Name = "CaughtFish_" .. player.Name
	local top = tip.WorldPosition - Vector3.new(0, 1, 0)
	local body: BasePart
	local hang = CFrame.identity
	local mouth = Vector3.new(0, len / 2, 0)
	local model = artFish(species, len)
	if model then
		-- After Roblox's import the model's head points along -X (Blender's +X): turn it
		-- nose-up, hanging from its mouth.
		body = model
		hang = CFrame.Angles(0, 0, math.rad(-90))
		mouth = Vector3.new(-len / 2, 0, 0)
		body.CFrame = CFrame.new(top - Vector3.new(0, len / 2, 0)) * hang
		body.Parent = m
	else
		body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(len * 0.18, len, len * 0.38)
		body.CFrame = CFrame.new(top - Vector3.new(0, len / 2, 0))
		body.Color = species.color
		body.Material = Enum.Material.SmoothPlastic
		body.Anchored = true
		body.CanCollide = false
		body.CanQuery = false
		body.CanTouch = false
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = body
		body.Parent = m
		local tail = Instance.new("WedgePart")
		tail.Name = "Tail"
		tail.Size = Vector3.new(len * 0.06, len * 0.3, len * 0.36)
		tail.CFrame = CFrame.new(top - Vector3.new(0, len + len * 0.12, 0)) * CFrame.Angles(math.rad(180), 0, 0)
		tail.Color = species.color
		tail.Anchored = true
		tail.CanCollide = false
		tail.CanQuery = false
		tail.CanTouch = false
		tail.Parent = m
	end
	local a = Instance.new("Attachment")
	a.Position = mouth
	a.Parent = body
	local line = Instance.new("Beam")
	line.Attachment0 = tip
	line.Attachment1 = a
	line.Width0 = 0.04
	line.Width1 = 0.04
	line.Color = ColorSequence.new(Color3.fromRGB(235, 235, 235))
	line.FaceCamera = true
	line.Parent = body
	m.Parent = workspace
	task.spawn(function()
		for i = 1, 25 do -- a little wiggle
			local swing = math.sin(i * 0.9) * math.rad(12)
			body.CFrame = CFrame.new(top - Vector3.new(0, len / 2, 0)) * CFrame.Angles(0, 0, swing) * hang
			task.wait(0.1)
		end
		m:Destroy()
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
		send(player, "Escaped", { text = "It got away! " .. species.fightNote, snapped = true })
		cleanup(s)
		return
	end
	local rolled = s.catch
	local cm, kg, class = 0, 0, "normal"
	if rolled then
		cm, kg, class = rolled.cm, rolled.kg, rolled.class
	else
		cm, kg = FishLogic.rollSize(species, rng)
	end
	s.catch = nil
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
		sizeClass = if class ~= "normal" then class else nil,
	}
	-- Team catch on the Deep-V in blue water: both journals, the coins split evenly.
	-- UNVERIFIED in Studio (boat plan Task 8, 2026-11-26).
	local boatId, mates, aboard, blue = BoatService.crewOf(player)
	if Teamwork.isTeamCatch(boatId, blue, aboard) then
		local shares = Teamwork.split(fish.price, 1 + #mates)
		fish.price = shares[1]
		for i, mate in mates do
			local mateData = PlayerData.get(mate)
			if mateData then
				local copy = table.clone(fish)
				copy.price = shares[i + 1]
				local full = Inventory.bagFull(mateData)
				Inventory.recordCatch(mateData, copy)
				if full then
					-- No room in their bag: the journal still gets it, the share is paid now.
					table.remove(mateData.bag)
					mateData.coins += copy.price
				end
				GoalService.onCatch(mate, mateData, copy, FrenzyService.at(fish.spot))
				PlayerData.changed(mate)
				toast(mate, string.format("Team catch! %s landed a %s. Your share: %d coins.", player.DisplayName, species.name, copy.price))
			end
		end
	end
	local first = (data.journal.counts[species.id] or 0) == 0
	local best = Inventory.recordCatch(data, fish)
	GoalService.onCatch(player, data, fish, FrenzyService.at(fish.spot))
	print(string.format("[Fishing] %s caught %s %.1f cm %.2f kg worth %d at %s (%s, %s)", player.Name, fish.name, cm, kg, fish.price, fish.spot, fish.period, fish.bait))
	send(player, "Caught", { fish = fish, best = best, first = first, habit = species.habit, tier = Rarity.of(species), sizeClass = class })
	if class == "monster" then
		for _, p in Players:GetPlayers() do
			toast(p, string.format("%s landed a MONSTER %s: %s, %s!", player.DisplayName, species.name, Units.length(cm, 0), Units.weight(kg)))
			if p ~= player then
				send(p, "Announce", { sound = "server-horn" }) -- a foghorn for everyone else (UNVERIFIED in Studio)
			end
		end
	end
	cleanup(s)
	showCatch(player, species, cm)
	PlayerData.changed(player)
end

local function onCancel(player: Player)
	local s = session(player)
	if s.phase == "Snagged" then
		return -- wiggle it free, or wait for the line to snap
	end
	if s.phase == "Waiting" and s.nibbling then
		-- Striking at a nibble: too early, but the fish is still there.
		send(player, "Hint", { text = "Too early, that was just a nibble. Wait for the bobber to go under." })
		return
	end
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
	local r = s.rig
	return {
		phase = s.phase,
		spot = s.spot,
		period = s.period,
		bait = s.bait,
		species = s.species,
		tight = s.tight,
		coming = if s.coming then { species = s.coming.species, cm = s.coming.cm, leaves = s.coming.leaves } else nil,
		rig = if r then { bait = r.bait, hook = r.hook, grade = r.grade } else nil,
	}
end

function FishingService.start()
	fishingEvent = Remotes.event("FishingEvent")
	toastEvent = Remotes.event("Toast")
	Remotes.event("Cast").OnServerEvent:Connect(onCast)
	Remotes.event("Hook").OnServerEvent:Connect(onHook)
	Remotes.event("FightResult").OnServerEvent:Connect(onFightResult)
	Remotes.event("CancelCast").OnServerEvent:Connect(onCancel)
	Remotes.event("Wiggle").OnServerEvent:Connect(onWiggle)
	Remotes.event("Twitch").OnServerEvent:Connect(onTwitch)
	Remotes.event("Rig").OnServerEvent:Connect(onRig)
	Players.PlayerRemoving:Connect(function(player)
		local s = sessions[player]
		if s then
			cleanup(s)
			sessions[player] = nil
		end
	end)
	-- Fishing from a boat: twice a second, a line that the boat ran away from comes free.
	-- UNVERIFIED in Studio (2026-11-26).
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, s in sessions do
				if s.land and (s.phase == "Waiting" or s.phase == "Snagged" or s.phase == "Bite" or s.phase == "Fighting") then
					local ok, msg = BoatService.lineCheck(player, s.land)
					if not ok then
						local fighting = s.phase == "Fighting"
						cleanup(s)
						if fighting then
							send(player, "Escaped", { text = msg or "The line came free." })
						else
							send(player, "Hint", { text = msg or "The line came free." })
							send(player, "Reset")
						end
					end
				end
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		session(player) -- starts the clock the first bait bench is checked against (L3)
		player.CharacterRemoving:Connect(function()
			local s = sessions[player]
			if s and s.phase ~= "Idle" then
				reset(player, s)
			end
		end)
	end)
	for _, player in Players:GetPlayers() do
		session(player)
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
