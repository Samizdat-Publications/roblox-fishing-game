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
local Retrieve = require(Shared.Retrieve)

local Server = script.Parent
local PlayerData = require(Server.PlayerData)
local RodService = require(Server.RodService)
local GoalService = require(Server.GoalService)
local WeatherService = require(Server.WeatherService)
local Weather = require(Shared.Weather)
local Frenzy = require(Shared.Frenzy)
local Daily = require(Shared.Daily)
local Today = require(Server.Today)
local FrenzyService = require(Server.FrenzyService)
local Teamwork = require(Shared.Teamwork)
local BoatService = require(Server.BoatService)
local RiseService = require(Server.RiseService)
local BobberGlow = require(Server.BobberGlow)
-- Leg 3, N4: the quiet approach, the landing net and playing together (each behind its switch).
local Quiet = require(Shared.Quiet)
local Net = require(Shared.Net)
local Coop = require(Shared.Coop)

local FishingService = {}

-- The bait on the hook (L3): which bait, the hook size it's on and how well it went on.
-- Live bait stays on through missed bites and lost fights' casts until a fish takes it, a
-- snag strips it, or the player re-baits. A lure (L3b) is tied once and stays tied until
-- the line snaps (a snag that snaps, or a fight that breaks off) or the player switches;
-- its `hook` is unused (lures carry their own).
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

-- A lure being worked back (L4c, Config.LURE_RETRIEVE_ON): the client streams its presses and
-- the server runs them through Shared/Retrieve a little behind its own clock (Retrieve.LAG),
-- rolling strikes from the good seconds. Nothing the client says is a strike.
type Run = {
	state: Retrieve.State,
	startedAt: number, -- os.clock() of the landing
	presses: { Retrieve.Press }, -- the accepted timeline (seconds after the landing)
	events: { { kind: string, t: number } }, -- accepted, waiting to be scored
	scoredTo: number, -- the model has run this far (seconds after the landing)
	lastGood: number, -- good seconds already rolled for a strike
	delay: number?, -- the bobber's bite delay for this cast (nil: nothing here wants it)
	fromRise: boolean,
	tokens: number, -- rate limit for Reel messages
	tokensAt: number,
	refused: number, -- events refused this cast
}

-- A net chance on this angler's fish (Net, NET_ON): the "Net it" prompt on the angler, when it
-- opened (the fish surfaces on a beat from then) and each helper's last miss.
type NetChance = {
	prompt: ProximityPrompt,
	openedAt: number,
	helpers: { [Player]: Net.Helper },
	up: boolean, -- the prompt's text says the fish is up
}

type Session = {
	owner: Player,
	phase: string, -- Idle, Waiting, Retrieving, Snagged, Bite, Fighting
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
	fightCheck: FightModel.Check?, -- how to judge the fight's end (L4d)
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
	retrieve: Run?, -- a lure being worked back (L4c)
	quiet: boolean?, -- this cast came after a quiet arrival (N4)
	onBoat: boolean?, -- this cast was made from a boat (N4, for the quiet tally)
	progress: number, -- the fight's progress as the angler's screen last reported it (N4, NET_ON)
	progressAt: number, -- os.clock() of that report
	fightFrom: number, -- the fight's starting progress (Net.maxProgress)
	net: NetChance?, -- the "Net it" prompt on this angler (N4)
	pair: Coop.Pair?, -- a Double Hookup this fight is part of (N4)
}

local RIG_MIN_GAP = 0.5 -- seconds between Rig messages the server will look at
local ASSIST_OFF_TEXT = "Reel assist is off now. Turn it back on in the journal any time."
local RIG_LATENCY = 0.5 -- slack when checking a bench run against the server's clock
local REEL_RATE = 20 -- Reel messages a second the server will look at (L4c)...
local REEL_BURST = 12 -- ...with this many in a burst
local REEL_REFUSE_MAX = 30 -- a cast with this many refused presses is ended

local sessions: { [Player]: Session } = {}
local quietTally: { [Player]: Quiet.Tally } = {} -- quiet against normal arrivals, for the playtest log (N4)
local creekBuddies: { [Player]: boolean } = {} -- near a Creek Pass holder right now (N4, BUDDY_LOAN_ON)
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
			owner = player,
			phase = "Idle",
			token = 0,
			fightStart = 0,
			progress = 0,
			progressAt = 0,
			fightFrom = Config.FIGHT_START,
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

-- The rod and braided line this player fishes with right now: their own, or (BUDDY_LOAN_ON) the
-- owner's when they ride as a passenger in someone else's boat and the owner's is better.
local function tackleFor(player: Player, data: Inventory.Data): (string, boolean)
	if Config.BUDDY_LOAN_ON then
		local owner = BoatService.ownerIfPassenger(player)
		local od = owner and PlayerData.get(owner)
		if od then
			return Coop.loanTackle(data.rod, data.braid == true, od.rod, od.braid == true)
		end
	end
	return data.rod, data.braid == true
end

local closeNet: (Session) -> ()
local pairDone: (Player, Session, string, number) -> ()

local function cleanup(s: Session)
	if s.net then
		closeNet(s)
	end
	if s.pair then
		pairDone(s.owner, s, "lost", 0) -- a fight that ended any way but landed
	end
	s.progress = 0
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
	s.retrieve = nil
end

-- The bait or lure on the hook for a cast with `baitId`, or nil (nothing on, or a stale rig).
local function rigFor(s: Session, baitId: string?): Rig?
	local bait = BaitData.byId[baitId or ""]
	local r = s.rig
	if bait and r and r.bait == bait.id then
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

-- The live bait came off (a fish took it, or a snag stripped it), or the lure's line snapped:
-- the next cast opens the bench.
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
	BobberGlow.watch(b) -- the warm night tip and light, fading with the night look (L5a)
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

-- The fish that bites: by the bite weights, or in Studio the DebugSpecies attribute (any
-- species id) when something would bite at all, to test a fish on demand (L4d).
local function pickFish(player: Player, s: Session): string?
	local id = FishLogic.pickSpecies(s.weights or {}, rng)
	local forced = if RunService:IsStudio() then player:GetAttribute("DebugSpecies") else nil
	if id and type(forced) == "string" and FishData.byId[forced] then
		return forced
	end
	return id
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
	local speciesId = pickFish(player, s)
	local species = speciesId and FishData.byId[speciesId]
	if not species then
		return
	end
	local cm, kg, class = rollComing(player, species)
	-- The quiet approach's playtest log: is the fish coming in wary, after which arrival?
	if Config.QUIET_APPROACH_ON and s.onBoat then
		local tally = quietTally[player] or Quiet.newTally()
		quietTally[player] = tally
		Quiet.countBite(tally, s.quiet == true, Quiet.isWary(species))
		print(string.format("[Quiet] %s: %s coming (%s) after a %s arrival. %s", player.Name, species.id, if Quiet.isWary(species) then "wary" else "not wary", if s.quiet then "quiet" else "normal", Quiet.tallyText(tally)))
	end
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

-- The bite delay for this cast with every multiplier: cover, a frenzy, how the bait went on,
-- and a claimed rise (first bite only). Nil when nothing here wants this bait. A worked lure
-- (L4c) uses the same delay for its strike hazard.
local function castDelay(s: Session): (number?, boolean)
	local delay = FishLogic.biteDelay(s.weights or {}, rng)
	if delay then
		delay = Cover.adjustDelay(delay, s.tight == true) -- fish hold tight to cover
	end
	if delay and FrenzyService.at(s.spot) then
		delay *= Frenzy.BITE_SPEED -- the school is boiling: bites come back to back
	end
	local rig = rigFor(s, s.bait)
	if delay and rig then
		-- Well-baited hooks get bit sooner (L3); Okay is x1. Lures use their own table (L3b).
		delay *= BaitRig.biteMult(rig.grade, BaitData.byId[rig.bait].kind == "lure")
	end
	-- Chum off the bow (CHUM_ON): bites come a quarter sooner for everyone aboard.
	if delay and Config.CHUM_ON and BoatService.chumFor(s.owner) then
		delay *= Coop.CHUM_BITE
	end
	local fromRise = false
	if delay and s.fastBite then
		delay = s.fastBite -- cast onto a rise: that fish takes it right away (first bite only)
		fromRise = true
	end
	s.fastBite = nil
	return delay, fromRise
end

function scheduleBite(player: Player, s: Session)
	local token = s.token
	s.waitGen += 1
	local gen = s.waitGen
	s.coming = nil
	local delay, fromRise = castDelay(s)
	local rig = rigFor(s, s.bait)
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

-- The hook is stuck on a log or in the weeds (L2b): wiggle it free within SNAG_TIME or the
-- line snaps. A worked lure left to sink onto cover (L4c) comes here too.
local function startSnag(player: Player, s: Session, pos: Vector3)
	s.phase = "Snagged"
	s.retrieve = nil
	s.snag = Cover.newSnag(os.clock())
	send(player, "Snag", { pos = pos })
	local token = s.token
	task.delay(Cover.SNAG_TIME, function()
		if s.token == token and s.phase == "Snagged" then
			local bait = BaitData.byId[s.bait or ""]
			local now = PlayerData.get(player)
			local lure = bait ~= nil and bait.kind == "lure"
			if now and Cover.losesBait(bait and bait.kind, false, 1) then
				Inventory.consumeBait(now, s.bait or "")
				PlayerData.changed(player)
				if rigFor(s, s.bait) then
					emptyHook(player, s)
				end
			elseif lure and rigFor(s, s.bait) then
				emptyHook(player, s) -- the lure is saved (never lost) but has to be tied on again
			end
			cleanup(s)
			send(player, "Snapped", { text = if lure then "The line snapped on the snag. Tie your lure back on." else "The line snapped on the snag." })
		end
	end)
end

----------------------------------------------------------------------------------------
-- Working a lure (L4c, behind Config.LURE_RETRIEVE_ON)

-- A fish hits the worked lure: picked and sized now by the same bite weights as a bobber
-- bite, then the normal hook window. A missed strike ends the cast (the lure is kept).
local function lureStrike(player: Player, s: Session, r: Run)
	local speciesId = pickFish(player, s)
	local species = speciesId and FishData.byId[speciesId]
	if not species then
		return
	end
	local cm, kg, class = rollComing(player, species)
	local pattern = FishLogic.bitePattern(species)
	local pos = Retrieve.position(r.state)
	s.retrieve = nil
	s.species = species.id
	s.catch = { cm = cm, kg = kg, class = class }
	s.land = pos -- the boat's line check follows the fish
	s.phase = "Bite"
	print(string.format(
		"[Fishing] %s: %s struck the %s after %.1fs (%.1fs good, %.1f studs in), %.1f cm %s",
		player.Name,
		species.id,
		s.bait or "lure",
		r.state.t,
		r.state.good,
		r.state.traveled,
		cm,
		class
	))
	send(player, "Bite", { style = pattern.style, lure = true, pos = pos })
	local token = s.token
	task.delay(pattern.hookWindow, function()
		if s.token == token and s.phase == "Bite" then
			print(string.format("[Fishing] %s missed the strike: %s let go", player.Name, species.id))
			send(player, "Missed", { text = "Too slow! It let go of the lure. Cast again.", ended = true })
			reset(player, s)
		end
	end)
end

-- The lure came back to your feet (or ran out of time) with no strike: the cast just ends.
local function lureBack(player: Player, s: Session, r: Run)
	print(string.format(
		"[Fishing] %s: the %s came back with no strike (%.1fs, %.1fs good of it)",
		player.Name,
		s.bait or "lure",
		r.state.t,
		r.state.good
	))
	if not r.delay then
		send(player, "Hint", { text = nothingHint(player, s) })
	end
	send(player, "Retrieved", { pos = Retrieve.position(r.state) })
	reset(player, s)
end

-- Run the model on to `upTo` (seconds after the landing), applying accepted presses in order.
local function scoreRun(r: Run, upTo: number)
	while #r.events > 0 and r.events[1].t <= upTo do
		local e = table.remove(r.events, 1) :: { kind: string, t: number }
		if e.kind == "down" then
			Retrieve.press(r.state, e.t)
		else
			Retrieve.release(r.state, e.t)
		end
	end
	Retrieve.advance(r.state, upTo)
	r.scoredTo = math.max(r.scoredTo, upTo)
end

-- The server's clock for one worked lure: every TICK, score up to LAG behind real time and
-- roll for a strike on the new good seconds.
local function runRetrieve(player: Player, s: Session)
	local token = s.token
	task.spawn(function()
		while true do
			task.wait(Retrieve.TICK)
			local r = s.retrieve
			if s.token ~= token or s.phase ~= "Retrieving" or not r then
				return
			end
			local upTo = os.clock() - r.startedAt - Retrieve.LAG
			if upTo > r.scoredTo then
				scoreRun(r, upTo)
				local st = r.state
				local fresh = st.good - r.lastGood
				r.lastGood = st.good
				local pos = Retrieve.position(st)
				if st.snagged then
					print(string.format("[Fishing] %s: the %s sank onto cover and snagged at %.1fs", player.Name, s.bait or "lure", st.t))
					startSnag(player, s, pos)
					return
				elseif rng:NextNumber() < Retrieve.strikeChance(fresh, r.delay, st.lure) then
					lureStrike(player, s, r)
					if s.phase ~= "Retrieving" then
						return
					end
				elseif st.done or not FishLogic.isOnWaterAny(pos, waters) then
					lureBack(player, s, r)
					return
				end
			end
		end
	end)
end

-- The lure landed: start working it back. Its strike hazard comes from the same bite delay a
-- bobber would get here (castDelay), so worked well it strikes as soon on average.
local function startRetrieve(player: Player, s: Session, landing: Vector3, origin: Vector3, grade: string)
	local baitId = s.bait :: string
	local delay, fromRise = castDelay(s)
	local now = os.clock()
	local run: Run = {
		state = Retrieve.new(baitId, grade, landing, origin),
		startedAt = now,
		presses = {},
		events = {},
		scoredTo = 0,
		lastGood = 0,
		delay = delay,
		fromRise = fromRise,
		tokens = REEL_BURST,
		tokensAt = now,
		refused = 0,
	}
	s.phase = "Retrieving"
	s.retrieve = run
	print(string.format(
		"[Fishing] %s working a %s (%s) at %s, %.1f studs out, strike delay %s%s",
		player.Name,
		baitId,
		grade,
		s.spot or "?",
		run.state.length,
		if delay then string.format("%.1fs", delay) else "none (nothing here wants it)",
		if fromRise then ", on a rise" else ""
	))
	send(player, "Landed", {
		pos = landing,
		spot = s.spot,
		spotName = FishLogic.SPOT_NAMES[s.spot :: string],
		bait = baitId,
		tight = s.tight,
		rise = fromRise,
		retrieve = baitId,
		origin = origin,
		grade = grade,
	})
	runRetrieve(player, s)
end

-- One press or let-go of the button while working a lure, `t` seconds after it landed (the
-- client's clock). Refused when it couldn't be real. A press stamped before what the server
-- has already scored counts from there, so nothing that already happened is rewritten.
local function onReel(player: Player, kind: any, t: any)
	local s = session(player)
	local r = s.retrieve
	if s.phase ~= "Retrieving" or not r then
		return
	end
	local now = os.clock()
	r.tokens = math.min(REEL_BURST, r.tokens + (now - r.tokensAt) * REEL_RATE)
	r.tokensAt = now
	if r.tokens < 1 then
		return
	end
	r.tokens -= 1
	local elapsed = now - r.startedAt
	local why: string? = nil
	local at = 0
	if type(t) ~= "number" or t ~= t then
		why = "bad time"
	elseif t > elapsed + Retrieve.FUTURE_SLACK then
		why = "stamped in the future"
	else
		at = math.max(t :: number, r.scoredTo)
		why = Retrieve.acceptEvent(r.presses, kind, at)
	end
	if why then
		r.refused += 1
		if r.refused == 1 or r.refused % 10 == 0 then
			warn(string.format("[Fishing] %s's reel press refused (%s), %d this cast", player.Name, why, r.refused))
		end
		if r.refused >= REEL_REFUSE_MAX then
			reset(player, s)
		end
		return
	end
	Retrieve.addEvent(r.presses, kind :: string, at)
	table.insert(r.events, { kind = kind :: string, t = at })
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
	-- A spinner knot tied Okay casts a little shorter (L3b); not rigged yet means Okay.
	local tied = rigFor(s, baitId)
	local castScale = BaitRig.castScale(baitId, if tied then tied.grade else "Okay")
	local origin = hrp.Position
	local castRod = tackleFor(player, data)
	local landing = CastLogic.landing(origin, flat, p, castRod, baitId, castScale)
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
	-- A creek buddy (BUDDY_LOAN_ON) near a Creek Pass holder may fish the creek with them.
	local creekOk = data.creekPass or (Config.BUDDY_LOAN_ON and creekBuddies[player] == true)
	if FishLogic.CREEK_SPOTS[FishLogic.spotAt(landing, zones)] and not creekOk then
		send(player, "Hint", { text = "Cedar Creek needs a Creek Pass. Get one at the gate on the west path." })
		return
	end

	cleanup(s)
	s.land = landing
	s.spot = FishLogic.spotAt(landing, zones)
	s.period = FishLogic.periodFromClock(Lighting.ClockTime)
	s.bait = baitId
	-- A worked lure has no bobber (L4c): the client draws the lure and its line.
	local retrieve = Config.LURE_RETRIEVE_ON and Retrieve.isLure(baitId)
	if not retrieve then
		s.bobber = makeBobber(player, landing)
	end
	-- Live bait goes on the hook now if the bench wasn't used (Quick Bait, a skip, or a bait
	-- switch the client didn't bench): Okay, exactly the game before L3. A lure is tied on
	-- Okay the same way (L3b); hook size doesn't matter for a lure.
	local current = rigFor(s, baitId)
	local isLive = BaitData.byId[baitId].kind == "live"
	if (isLive and (not current or current.hook ~= data.hook)) or (not isLive and not current) then
		s.rig = { bait = baitId, hook = data.hook, grade = "Okay" }
		sendRig(player, s)
	end
	local rigGrade = (s.rig :: Rig).grade

	-- Right on a log, or deep in the weed bed with bait that isn't rigged weedless (only a
	-- Perfect plastic worm is): snagged (L2b, L3b). Each press of the cast button sends a
	-- Wiggle; SNAG_WIGGLES of them in SNAG_TIME free it.
	if Cover.snagAt(landing, baitId, rigGrade) then
		startSnag(player, s, landing)
		return
	end

	s.phase = "Waiting"
	s.tight = Cover.tightAt(landing, baitId, rigGrade)
	s.weights = FishLogic.biteWeights(s.spot :: string, s.period :: string, baitId, WeatherService.now())
	s.weights = Cover.applyCover(s.weights :: { FishLogic.Weight }, s.tight == true)
	if FrenzyService.at(s.spot) then
		s.weights = Frenzy.weights(s.weights :: { FishLogic.Weight }, s.spot :: string)
	end
	-- The fish of the day (the chalkboard, L6d) bites a little more readily, where it already bites.
	s.weights = Daily.boost(s.weights :: { FishLogic.Weight }, Daily.fishOfDay(Today.day()))
	-- Quiet approach (N4): after a quiet arrival, wary fish are 1.25 times as likely here for a
	-- minute. Every cast from a boat is logged, so a playtest can compare 30 casts each way.
	s.quiet, s.onBoat = false, false
	if Config.QUIET_APPROACH_ON then
		local quiet, onBoat = BoatService.quietFor(player)
		s.onBoat = onBoat
		if onBoat then
			s.quiet = quiet
			local plain = Quiet.waryShare(s.weights :: { FishLogic.Weight }, FishData.byId)
			if quiet then
				s.weights = Quiet.boost(s.weights :: { FishLogic.Weight }, FishData.byId)
			end
			local tally = quietTally[player] or Quiet.newTally()
			quietTally[player] = tally
			Quiet.countCast(tally, quiet)
			print(string.format("[Quiet] %s cast at %s after a %s arrival: wary share %.0f%% (%.0f%% without the bonus). %s", player.Name, tostring(s.spot), if quiet then "quiet" else "normal", Quiet.waryShare(s.weights :: { FishLogic.Weight }, FishData.byId) * 100, plain * 100, Quiet.tallyText(tally)))
		end
	end
	-- A cast onto an open rise claims it: a quick bite, if anything here wants this bait.
	if #(s.weights :: { FishLogic.Weight }) > 0 and RiseService.claim(player, landing) then
		s.fastBite = Rises.biteDelay(rng)
	end
	if retrieve then
		startRetrieve(player, s, landing, hrp.Position, rigGrade)
		return
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
-- Okay). A skip (hold, or the Skip button) is Okay too, and just sets the hook size. Lures
-- (L3b) come through here too; their bench doesn't change the hook size the client sends.
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
	if s.phase ~= "Idle" or not bait or not BaitRig.recipeFor(bait.id) or not Inventory.hasBait(data, bait.id) then
		-- Only the hook size changes (the Tackle Box, or mid-cast). A live rig on the old size
		-- comes off at the next cast (see onCast).
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
	local live = rig ~= nil and BaitData.byId[rig.bait].kind == "live"
	if rig and rng:NextNumber() < BaitRig.missChance(rig.hook, species.mouth, live) then
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
	-- The fish takes the live bait. A Perfect bait has an even chance of staying on (L3). A
	-- lure is never used up and stays tied (L3b).
	local kept = false
	if rig and live then
		kept = BaitRig.survives(rig.grade, rng:NextNumber())
	end
	if not kept then
		Inventory.consumeBait(data, s.bait or "")
	end
	PlayerData.changed(player)
	local start = BaitRig.fightStart(if rig then rig.grade else nil)
	if rig and live and not kept then
		emptyHook(player, s)
	elseif rig and live and kept then
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
	-- Line and drag (L4d): the fish's weight over this rod's line rating (plus braided line if
	-- owned). A passenger may fish with the boat owner's tackle (BUDDY_LOAN_ON, N4).
	local rodId, braid = tackleFor(player, data)
	local load = RodData.lineLoad(kg, rodId, braid)
	s.fightCheck = FightModel.checkFor(profile, start, load)
	s.fightFrom = start
	s.progress = start
	s.progressAt = os.clock()
	local lineLb = RodData.lineLbFor(rodId, braid)
	if rodId ~= data.rod or braid ~= (data.braid == true) then
		print(string.format("[Coop] %s fishes with the boat owner's %s%s", player.Name, rodId, if braid then " and braided line" else ""))
	end
	print(string.format("[Fishing] %s hooked %s, fight starts at %.2f (%s), %.1f lb on %d lb line%s: load %.2f", player.Name, species.id, start, if rig then rig.grade else "lure", kg / 0.45359237, lineLb, if braid then " (braided)" else "", load))
	setBobberY(s, -1)
	local token = s.token
	send(player, "Hooked", {
		fight = RodData.applyFight(profile, rodId),
		assist = data.assist,
		seed = rng:NextInteger(1, 1e6),
		start = start,
		load = load, -- L4d: fish weight over line rating, for strain
		lineLb = lineLb,
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
	-- Double Hookup (DOUBLE_HOOKUP_ON, N4): someone within 15 studs is fighting a fish too.
	if Config.DOUBLE_HOOKUP_ON then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		for other, os2 in sessions do
			local oroot = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if other ~= player and os2.phase == "Fighting" and os2.pair == nil and root and oroot then
				local gap = Vector3.new(root.Position.X - oroot.Position.X, 0, root.Position.Z - oroot.Position.Z).Magnitude
				if gap <= Coop.DOUBLE_RANGE then
					local pair = Coop.newPair(player, other)
					s.pair = pair
					os2.pair = pair
					print(string.format("[Coop] Double Hookup: %s and %s (%.0f studs apart)", player.Name, other.Name, gap))
					for _, p in { player, other } do
						send(p, "DoubleHookup", { with = (if p == player then other else player).DisplayName })
						toast(p, "Double Hookup! Land them both for a bonus.")
					end
					break
				end
			end
		end
	end
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

local landCatch: (Player, Session, Player?) -> ()

-- `claim`: "won", "lost" or "snapped" (true from older clients means won). `report` (L4d):
-- { tight = the drag was Tight at some point, drag = the drag at the end }.
local function onFightResult(player: Player, claim: any, report: any)
	local s = session(player)
	local data = PlayerData.get(player)
	if s.phase ~= "Fighting" or not data or not s.species then
		return
	end
	local elapsed = os.clock() - s.fightStart
	local species = FishData.byId[s.species :: string]
	local check = s.fightCheck or FightModel.checkFor(species.fight, nil, 0)
	local outcome, refused = FightModel.judge(check, claim, report, elapsed)
	if refused then
		warn(string.format("[Fishing] %s: %s; counted as escape", player.Name, refused))
	end
	if outcome ~= "won" then
		-- The line broke: a lure (L3b) is saved but has to be tied on again.
		local lureRig = rigFor(s, s.bait)
		local lure = lureRig ~= nil and BaitData.byId[lureRig.bait].kind == "lure"
		local tie = if lure then " Tie your lure back on." else ""
		if outcome == "snapped" then
			-- Line and drag (L4d): reeled too hard through a big move.
			local drag = if type(report) == "table" then tostring(report.drag) else "?"
			print(string.format("[Fishing] %s snapped the line on %s after %.1fs (load %.2f, %s drag)", player.Name, species.id, elapsed, check.load, drag))
			send(player, "Escaped", { text = "Snap! The line broke. Ease off when a big fish runs." .. tie, snapped = true, lineSnap = true })
		else
			send(player, "Escaped", { text = "It got away! " .. species.fightNote .. tie, snapped = true })
		end
		if lure then
			emptyHook(player, s)
		end
		cleanup(s)
		return
	end
	landCatch(player, s, nil)
end

-- A helper's share of someone else's catch: an assist in their journal, the bonus (if any) in
-- their coins, and a toast. Used by landCatch and by the Studio-only test angler (DebugCoop).
local function creditHelper(helper: Player, anglerName: string, anglerShown: string, fish: Inventory.Fish, speciesName: string, how: string, bonus: number)
	local hd = PlayerData.get(helper)
	if not hd then
		return
	end
	Inventory.recordAssist(hd, fish, bonus, how, os.time())
	PlayerData.changed(helper)
	print(string.format("[Coop] %s assisted %s (%s) on a %s worth %d: +%d coins", helper.Name, anglerName, how, fish.name, fish.price, bonus))
	if bonus > 0 then
		toast(helper, string.format("Assist! You helped %s land a %s. +%d coins.", anglerShown, speciesName, bonus))
	else
		toast(helper, string.format("Assist! You helped %s land a %s.", anglerShown, speciesName))
	end
end

-- Land the fish on the line: the angler's own win (the client's fight, judged above), or a
-- helper's net (NET_ON, N4: `netter`). Pays the angler, any helpers, and a Double Hookup.
function landCatch(player: Player, s: Session, netter: Player?)
	local data = PlayerData.get(player)
	local species = s.species and FishData.byId[s.species :: string]
	if not data or not species then
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
	-- Team catch on the Deep-V in blue water. With ASSIST_BONUS_ON (N4) the angler keeps the full
	-- price and each mate gets an assist and 10 percent; off, both journals and an even split
	-- as before. UNVERIFIED in Studio (boat plan Task 8, 2026-11-26).
	local boatId, mates, aboard, blue = BoatService.crewOf(player)
	local team = Teamwork.isTeamCatch(boatId, blue, aboard)
	local helpers: { { p: Player, how: string } } = {}
	if team then
		for _, mate in mates do
			table.insert(helpers, { p = mate, how = if mate == netter then "net" else "crew" })
		end
	end
	if netter and not (team and table.find(mates, netter)) then
		table.insert(helpers, { p = netter, how = "net" })
	end
	local function assist(helper: Player, how: string, bonus: number)
		creditHelper(helper, player.Name, player.DisplayName, fish, species.name, how, bonus)
	end
	if Config.ASSIST_BONUS_ON then
		for _, h in helpers do
			assist(h.p, h.how, Coop.assistBonus(fish.price))
		end
	else
		-- The net still goes in the helper's journal; only a team catch pays, split as in L7.
		if netter and not (team and table.find(mates, netter)) then
			assist(netter, "net", 0)
		end
	end
	if team and not Config.ASSIST_BONUS_ON then
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
	print(string.format("[Fishing] %s caught %s %.1f cm %.2f kg worth %d at %s (%s, %s)%s", player.Name, fish.name, cm, kg, fish.price, fish.spot, fish.period, fish.bait, if netter then ", netted by " .. netter.Name else ""))
	send(player, "Caught", { fish = fish, best = best, first = first, habit = species.habit, tier = Rarity.of(species), sizeClass = class, netter = if netter then netter.DisplayName else nil })
	if netter then
		toast(player, string.format("%s netted it for you!", netter.DisplayName))
	end
	-- Double Hookup (N4): this side landed; the bonus pays once the other side is done too.
	if s.pair then
		pairDone(player, s, "won", fish.price)
	end
	-- Reel assist turns itself off after the first few catches, once (L4b). UNVERIFIED in Studio.
	if Inventory.assistAfterCatch(data) then
		task.delay(1.5, function()
			if player.Parent then
				toast(player, ASSIST_OFF_TEXT)
			end
		end)
	end
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
	if s.phase == "Waiting" or s.phase == "Bite" or s.phase == "Retrieving" then
		reset(player, s)
	elseif s.phase == "Fighting" then
		send(player, "Escaped", { text = "You let it go." })
		cleanup(s)
	end
end

-- The landing net (NET_ON, N4) -------------------------------------------------------------

function closeNet(s: Session)
	local n = s.net
	s.net = nil
	if n then
		n.prompt:Destroy()
	end
end

-- Double Hookup (N4): one side's fight is over. Pays both once both are done and both landed.
function pairDone(player: Player, s: Session, outcome: string, price: number)
	local pair = s.pair
	s.pair = nil
	if not pair then
		return
	end
	local pay = Coop.pairResult(pair, player, outcome, price)
	if not pay then
		return -- the other one is still fighting
	end
	for p, bonus in pay do
		local d = PlayerData.get(p)
		if d and bonus > 0 then
			d.coins += bonus
			d.doubleHauls += 1
			print(string.format("[Coop] Double Haul for %s: +%d coins", p.Name, bonus))
			send(p, "DoubleHaul", { bonus = bonus })
			toast(p, string.format("Double Haul! You both landed one. +%d coins.", bonus))
			PlayerData.changed(p)
		end
	end
end

-- A helper pressed "Net it" on this angler's fish. The server decides: in reach, the angler
-- still fighting, the helper's hands free, and the fish up at the surface.
local function onNetPress(helper: Player, angler: Player)
	local s = sessions[angler]
	if helper == angler or not s or s.phase ~= "Fighting" or not s.net then
		return
	end
	local hs = sessions[helper]
	if hs and hs.phase == "Fighting" then
		toast(helper, "Your hands are full with your own fish!")
		return
	end
	local hr = helper.Character and helper.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local ar = angler.Character and angler.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hr or not ar or not Net.inReach(hr.Position, ar.Position) then
		return
	end
	local n = s.net :: NetChance
	local h = n.helpers[helper] or {}
	n.helpers[helper] = h
	local result = Net.press(h, n.openedAt, os.clock())
	print(string.format("[Net] %s pressed on %s's %s: %s", helper.Name, angler.Name, tostring(s.species), result))
	if result == "landed" then
		landCatch(angler, s, helper)
	elseif result == "missed" then
		toast(helper, "Missed! It went back down. Try again in 2 seconds.")
	else
		toast(helper, "Get the net ready...")
	end
end

-- The "Net it" prompt on an angler's root. anglerId is the angler's UserId: their own screen
-- hides it (BoatClient). 0 for the Studio test angler (DebugCoop).
local function newNetPrompt(root: BasePart, anglerId: number, onPress: (Player) -> ()): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = "NetPrompt"
	p.ActionText = "Net it"
	p.ObjectText = "Wait for it to surface"
	p.HoldDuration = 0
	p.MaxActivationDistance = Net.RANGE
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p:SetAttribute("AnglerId", anglerId)
	p.Parent = root
	p.Triggered:Connect(onPress)
	return p
end

-- Say on the prompt whether the fish is up right now.
local function showSurfacing(n: NetChance, now: number)
	local up = Net.surfacing(n.openedAt, now)
	if up ~= n.up then
		n.up = up
		n.prompt.ObjectText = if up then "It's up! Net it now" else "Wait for it to surface"
	end
end

local function openNet(player: Player, s: Session)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local p = newNetPrompt(root, player.UserId, function(who: Player)
		onNetPress(who, player)
	end)
	s.net = { prompt = p, openedAt = os.clock(), helpers = {}, up = false }
	print(string.format("[Net] %s's %s is at %.0f%%: the net is out", player.Name, tostring(s.species), s.progress * 100))
end

-- The angler's screen reports the fight's progress (NET_ON). Believed only as fast as the fish
-- could really be won (Net.acceptProgress).
local function onFightProgress(player: Player, progress: any)
	if not Config.NET_ON then
		return
	end
	local s = sessions[player]
	local check = s and s.fightCheck
	if not s or s.phase ~= "Fighting" or not check then
		return
	end
	local now = os.clock()
	if now - s.progressAt < 0.1 then
		return -- about four a second is plenty
	end
	local p = Net.acceptProgress(progress, s.fightFrom, check.minSecsTight, now - s.fightStart)
	if p then
		s.progress = p
		s.progressAt = now
	end
end

-- Studio-only test anglers (DebugCoop) ------------------------------------------------------
-- A Humanoid rig standing in for a second player: it "has a fish on" at a set fight progress
-- (the DebugFightProgress attribute on the rig, the same attribute a real angler's Studio test
-- uses), so one real player can check "Net it" and the assist alone. Never in a live game:
-- debugHookDummy refuses outside Studio, so dummyFights stays empty there.
type DummyFight = {
	model: Model,
	species: string,
	net: NetChance?,
}
local dummyFights: { [Model]: DummyFight } = {}

local function dummyRoot(model: Model): BasePart?
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function endDummy(d: DummyFight)
	dummyFights[d.model] = nil
	local n = d.net
	d.net = nil
	if n then
		n.prompt:Destroy()
	end
end

-- The helper netted the test angler's fish: the helper's side of landCatch (the journal assist
-- and bonus, as for a net on a real angler outside a team catch). The rig gets DebugLanded.
local function landDummy(d: DummyFight, helper: Player)
	local species = FishData.byId[d.species]
	if not species then
		endDummy(d)
		return
	end
	local cm, kg = FishLogic.rollSize(species, rng)
	local fish: Inventory.Fish = {
		id = species.id,
		name = species.name,
		cm = cm,
		kg = kg,
		price = FishLogic.priceFor(species, kg),
		bait = "",
		spot = "OpenWater",
		period = "Day",
		at = os.time(),
	}
	local bonus = if Config.ASSIST_BONUS_ON then Coop.assistBonus(fish.price) else 0
	creditHelper(helper, d.model.Name, d.model.Name, fish, species.name, "net", bonus)
	print(string.format("[DebugCoop] %s netted %s's %s, %.1f cm worth %d: +%d", helper.Name, d.model.Name, fish.name, cm, fish.price, bonus))
	d.model:SetAttribute("DebugLanded", fish.name)
	d.model:SetAttribute("DebugFightProgress", nil)
	endDummy(d)
end

-- A press of "Net it" on the test angler: the same server checks as onNetPress.
local function onDummyNetPress(helper: Player, d: DummyFight): string
	local n = d.net
	if not n then
		return "closed"
	end
	local hs = sessions[helper]
	if hs and hs.phase == "Fighting" then
		toast(helper, "Your hands are full with your own fish!")
		return "busy"
	end
	local hr = helper.Character and helper.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local ar = dummyRoot(d.model)
	if not hr or not ar or not Net.inReach(hr.Position, ar.Position) then
		return "far"
	end
	local h = n.helpers[helper] or {}
	n.helpers[helper] = h
	local result = Net.press(h, n.openedAt, os.clock())
	print(string.format("[Net] %s pressed on %s's %s: %s", helper.Name, d.model.Name, d.species, result))
	if result == "landed" then
		landDummy(d, helper)
	elseif result == "missed" then
		toast(helper, "Missed! It went back down. Try again in 2 seconds.")
	else
		toast(helper, "Get the net ready...")
	end
	return result
end

local function dummyTick(now: number)
	for model, d in dummyFights do
		local root = dummyRoot(model)
		if not model.Parent or not root then
			endDummy(d)
			continue
		end
		local prog = model:GetAttribute("DebugFightProgress")
		local open = Config.NET_ON and type(prog) == "number" and Net.open(d.net ~= nil, prog)
		if open and not d.net then
			local p = newNetPrompt(root, 0, function(who: Player)
				onDummyNetPress(who, d)
			end)
			d.net = { prompt = p, openedAt = now, helpers = {}, up = false }
			print(string.format("[Net] %s's %s is at %.0f%%: the net is out", model.Name, d.species, (prog :: number) * 100))
		elseif not open and d.net then
			local n = d.net :: NetChance
			d.net = nil
			n.prompt:Destroy()
		end
		local n = d.net
		if n then
			showSurfacing(n, now)
		end
	end
end

-- Studio only: give this rig (a Model with a Humanoid and a HumanoidRootPart) a hooked fish at
-- this fight progress (0 to 1). False outside Studio, or for a bad rig or species.
function FishingService.debugHookDummy(model: Model, speciesId: string?, progress: number): boolean
	if not RunService:IsStudio() or not dummyRoot(model) then
		return false
	end
	local id = speciesId or "Bluegill"
	if not FishData.byId[id] then
		return false
	end
	local old = dummyFights[model]
	if old then
		endDummy(old)
	end
	model:SetAttribute("DebugLanded", nil)
	model:SetAttribute("DebugFightProgress", progress)
	dummyFights[model] = { model = model, species = id }
	return true
end

-- Studio only: the test angler's net chance as the server sees it.
function FishingService.debugDummyState(model: Model): { [string]: any }?
	if not RunService:IsStudio() then
		return nil
	end
	local d = dummyFights[model]
	local n = d and d.net
	return {
		hooked = d ~= nil,
		species = if d then d.species else nil,
		progress = model:GetAttribute("DebugFightProgress"),
		open = n ~= nil,
		up = if n then (Net.surfacing(n.openedAt, os.clock())) else false,
		text = if n then n.prompt.ObjectText else nil,
		landed = model:GetAttribute("DebugLanded"),
	}
end

-- Studio only: press "Net it" on the test angler for this helper, through the same server
-- checks as the prompt: "landed", "missed", "wait", "far", "busy" or "closed". With waitUp, it
-- first waits (up to 10 s) until the fish is up: a timed press. Without, it presses at once.
function FishingService.debugNetPress(helper: Player, model: Model, waitUp: boolean?): string?
	if not RunService:IsStudio() then
		return nil
	end
	local d = dummyFights[model]
	if not d then
		return "closed"
	end
	if waitUp then
		local deadline = os.clock() + 10
		while os.clock() < deadline do
			local n = d.net
			if n and Net.surfacing(n.openedAt, os.clock()) then
				break
			end
			task.wait(0.05)
		end
	end
	return onDummyNetPress(helper, d)
end

-- Studio only: take the test angler's fish away (the rig stays).
function FishingService.debugEndDummy(model: Model)
	local d = dummyFights[model]
	if d then
		endDummy(d)
	end
	if RunService:IsStudio() then
		model:SetAttribute("DebugFightProgress", nil)
	end
end

-- Ten times a second: open and close each angler's net chance, and say when the fish is up.
local function netTick()
	local now = os.clock()
	for player, s in sessions do
		if not (Config.NET_ON and s.phase == "Fighting") then
			if s.net then
				closeNet(s)
			end
			continue
		end
		local prog = s.progress
		local fresh = now - s.progressAt <= 1.5 -- no word from the angler's screen for a while: no net
		local forced = if RunService:IsStudio() then player:GetAttribute("DebugFightProgress") else nil
		if type(forced) == "number" then
			prog, fresh = forced, true -- Studio only: a test dummy's fish at a set progress
		end
		local open = fresh and Net.open(s.net ~= nil, prog)
		if open and not s.net then
			s.progress = prog
			openNet(player, s)
		elseif not open and s.net then
			closeNet(s)
		end
		local n = s.net
		if n then
			showSurfacing(n, now)
		end
	end
	if next(dummyFights) ~= nil then
		dummyTick(now) -- Studio-only test anglers (empty in a live game)
	end
end

-- Creek buddies (BUDDY_LOAN_ON): once a second, who is within 20 studs of a Creek Pass holder.
-- The attribute opens the gate on that player's screen; the cast check reads the same table.
local function creekBuddyTick()
	local holders = {}
	for _, p in Players:GetPlayers() do
		local d = PlayerData.get(p)
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if d and d.creekPass and r then
			table.insert(holders, r.Position)
		end
	end
	for _, p in Players:GetPlayers() do
		local d = PlayerData.get(p)
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local buddy = d ~= nil and not d.creekPass and r ~= nil and Coop.creekBuddy(r.Position, holders)
		if buddy ~= (creekBuddies[p] == true) then
			creekBuddies[p] = if buddy then true else nil
			p:SetAttribute("CreekBuddy", buddy)
			if buddy then
				toast(p, "You're with a Creek Pass holder: the creek gate lets you through.")
			end
		end
	end
end

-- For tests: force the next bite to come right away.
function FishingService.debugState(player: Player): any
	local s = session(player)
	local r = s.rig
	local run = s.retrieve
	return {
		retrieve = if run
			then {
				t = run.state.t,
				good = run.state.good,
				traveled = run.state.traveled,
				length = run.state.length,
				speed = run.state.speed,
				depth = run.state.depth,
				presses = #run.presses,
				refused = run.refused,
				delay = run.delay,
			}
			else nil,
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
	Remotes.event("Reel").OnServerEvent:Connect(onReel)
	Remotes.event("FightProgress").OnServerEvent:Connect(onFightProgress)
	Players.PlayerRemoving:Connect(function(player)
		local s = sessions[player]
		if s then
			cleanup(s)
			sessions[player] = nil
		end
		quietTally[player] = nil
		creekBuddies[player] = nil
	end)
	-- The net (NET_ON) and the creek buddy (BUDDY_LOAN_ON), N4.
	task.spawn(function()
		local sinceBuddy = 0
		while true do
			task.wait(0.1)
			netTick()
			sinceBuddy += 0.1
			if sinceBuddy >= 1 then
				sinceBuddy = 0
				if Config.BUDDY_LOAN_ON then
					creekBuddyTick()
				end
			end
		end
	end)
	-- Fishing from a boat: twice a second, a line that the boat ran away from comes free.
	-- UNVERIFIED in Studio (2026-11-26).
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, s in sessions do
				if s.land and (s.phase == "Waiting" or s.phase == "Retrieving" or s.phase == "Snagged" or s.phase == "Bite" or s.phase == "Fighting") then
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
