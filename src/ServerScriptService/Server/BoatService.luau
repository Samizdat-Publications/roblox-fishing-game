--!strict
-- Boats in the world. Each owner's chosen boat waits at a slip by the dock; the owner takes
-- the helm with a "Drive" prompt (anyone may "Ride" in a Deep-V's second seat). Every frame
-- the server reads the helm seat's throttle and steer, runs BoatLogic.step and sets the
-- movers; every half second it checks where the boat went (BoatRules.check). Docking,
-- empty boats and leaving all send the boat back to its slip.
-- Rules live in the pure modules BoatData, BoatLogic and BoatRules (tested outside Studio).
-- Written 2026-11-26 in the cloud; the dinghy proven in Studio 11/27/2026 (L7). The Deep-V's
-- two seats and the fish finder still wait for a two-player playtest.
--
-- Leg 3, N4, the fleet (Config.CANOE_ON): the Cedar Canoe (two paddlers, 7 or 11 studs a
-- second), the dinghy's passenger seat, landing on a shore ("Land here") and re-boarding there,
-- each boat kept to its own waters. Every boat tracks its last arrival for the quiet approach
-- (Shared/Quiet, QUIET_APPROACH_ON), the second seat of a canoe or dinghy can toss chum
-- (CHUM_ON), and the journal's "Send my boat home" calls the SendBoatHome remote.
-- UNVERIFIED in Studio (11/27/2026) until the N4 playtest.
--
-- After the N4 playtest (11/28/2026): the hull is held rigidly level at its water line (it rode
-- up logs and banks to 28 degrees), the server looks ahead and stops a boat with water to spare
-- before a shore, a log or the dock (BoatRules.stopAhead plus a ray for anything else solid),
-- the step runs just before physics so a new turn moves the hull on the next step, and "Drive"
-- hangs from the hull's middle. UNVERIFIED in Studio until the re-test.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local BoatData = require(Shared.BoatData)
local BoatLogic = require(Shared.BoatLogic)
local BoatRules = require(Shared.BoatRules)
local BoatFeel = require(Shared.BoatFeel)
local Quiet = require(Shared.Quiet)
local Coop = require(Shared.Coop)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local WeatherService = require(script.Parent.WeatherService)

local BoatService = {}

local CHECK_EVERY = 0.5 -- seconds between the server's position checks
local EMPTY_RETURN = 60 -- an empty boat away from its slip goes back after this long
local HINT_GAP = 3 -- seconds between repeats of the same hint to one player
local STOP_QUIET = 0.75 -- seconds of free movement before a new stop may toast again
local BEACH_KEEP = 80 -- a landed boat waits for its owner while they are within this many studs
local SEND_HOME_GAP = 2 -- seconds between "Send my boat home" presses the server looks at

type Movers = {
	lv: LinearVelocity,
	ao: AlignOrientation,
	ap: AlignPosition,
}

type Boat = {
	owner: Player,
	id: string,
	slip: number,
	model: Model,
	hull: BasePart,
	helm: VehicleSeat,
	nav: Seat?,
	drivePrompt: ProximityPrompt,
	ridePrompt: ProximityPrompt?,
	tiePrompt: ProximityPrompt,
	beachPrompt: ProximityPrompt, -- "Land here" (the fleet): owner at the helm, slow, bow on a shore
	chumPrompt: ProximityPrompt?, -- "Toss chum" on the second seat (CHUM_ON, canoe and dinghy)
	movers: Movers,
	wake: ParticleEmitter,
	motion: BoatLogic.Motion,
	yaw: number, -- heading in radians around +Y; the AlignOrientation holds the hull to it
	lastGood: Vector3,
	checkTimer: number,
	emptyFor: number,
	docked: boolean,
	beached: boolean, -- landed on a shore (anchored where it is, not at its slip)
	quiet: Quiet.State, -- its last arrival, for the quiet approach
	throttle: number, -- the helm's throttle this frame
	chumAt: number?, -- os.clock() of the last toss
	stopToasted: boolean, -- a stop's toast was sent; no more until the boat has moved freely again
	freeFor: number, -- seconds the boat has moved with nothing in the way
	debugRun: { throttle: number, stopX: number }?, -- Studio only: a scripted straight run (shot c03)
	runLog: { { number } }?, -- Studio only: { unix ms, hull x } every 0.05 s of the run
	runLogAt: number?,
}

local boats: { [Player]: Boat } = {}
local lastHint: { [Player]: { [string]: number } } = {}
local toastEvent: RemoteEvent? = nil

local function hint(player: Player, text: string)
	local t = os.clock()
	local seen = lastHint[player] or {}
	lastHint[player] = seen
	if seen[text] and t - seen[text] < HINT_GAP then
		return
	end
	seen[text] = t
	if toastEvent then
		toastEvent:FireClient(player, text)
	end
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function piece(model: Model, hull: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.Massless = true
	p.CFrame = hull.CFrame * offset
	p.Parent = model
	weld(hull, p)
	return p
end

local function seat(model: Model, hull: BasePart, class: string, name: string, offset: CFrame): BasePart
	local s = Instance.new(class) :: any
	s.Name = name
	s.Size = Vector3.new(2, 0.4, 2)
	s.Color = Color3.fromRGB(60, 60, 65)
	s.TopSurface = Enum.SurfaceType.Smooth
	s.CanCollide = false
	s.CanTouch = false -- only the prompts seat people (no sitting by bumping into it)
	s.Massless = true
	if class == "VehicleSeat" then
		-- Read for input only: its own drive works through hinge motors, which a hull hasn't.
		s.MaxSpeed = 0
		s.Torque = 0
		s.TurnSpeed = 0
		s.HeadsUpDisplay = false
	end
	s.CFrame = hull.CFrame * offset
	s.Parent = model
	weld(hull, s)
	return s
end

local function prompt(parent: BasePart, name: string, action: string, object: string): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.Parent = parent
	return p
end

-- "Drive" hangs from the middle of the hull, not the helm seat, and reaches past either end, so
-- an owner on the shore beside a landed boat (or on the dock) can take it from the bow side.
-- The N4 playtest: from 5.6 studs the first E did nothing, because the bow seat's own prompt
-- (Ride or Paddle, also on E) was nearer and the owner's screen picked that one. BoatClient now
-- hides that prompt from the owner. UNVERIFIED in Studio (11/28/2026).
local function drivePromptOn(hull: BasePart, b: BoatData.Boat): ProximityPrompt
	local board = Instance.new("Attachment")
	board.Name = "Board"
	board.Position = Vector3.new(0, hull.Size.Y / 2 + 0.5, 0)
	board.Parent = hull
	local p = prompt(hull, "DrivePrompt", "Drive", b.name)
	p.MaxActivationDistance = math.max(10, b.length / 2 + 6)
	p.Parent = board
	return p
end

-- Where a seat goes, relative to the hull's centre. With the feel layer on (BOAT_FEEL_ON) a seat
-- named in BoatFeel.ART[id].seats sits where its art model's seat is (given as the seat top over
-- the waterline; the hull's centre is hullHeight / 2 - 0.4 above the water, the seat 0.4 thick).
local function seatAt(b: BoatData.Boat, name: string, hullHeight: number, default: CFrame): CFrame
	local art = if Config.BOAT_FEEL_ON then BoatFeel.ART[b.id] else nil
	local top = art and art.seats and art.seats[name]
	if not top then
		return default
	end
	return CFrame.new(top.X, top.Y - 0.2 - (hullHeight / 2 - 0.4), top.Z)
end

-- A gray-box boat, bow toward -Z of the hull. The art models in art/models replace the
-- visible pieces later (boat plan Task 2); the hull part stays as the physics body.
local function buildModel(owner: Player, b: BoatData.Boat, at: CFrame): (Model, BasePart, VehicleSeat, Seat?)
	local model = Instance.new("Model")
	model.Name = owner.Name .. "_" .. b.id
	local hullHeight = if b.id == "DeepV" then 1.6 elseif b.id == "Canoe" then 1.0 else 1.2
	local hull = Instance.new("Part")
	hull.Name = "Hull"
	hull.Size = Vector3.new(b.width, hullHeight, b.length)
	hull.Color = b.color
	hull.Material = Enum.Material.SmoothPlastic
	hull.TopSurface = Enum.SurfaceType.Smooth
	hull.BottomSurface = Enum.SurfaceType.Smooth
	hull.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.3, 0.1)
	-- The hull leads the assembly a seated character joins; otherwise the (heavier) character
	-- became the root and sitting down dragged the boat onto the dock (11/27/2026 playtest).
	hull.RootPriority = 127
	hull.CFrame = at * CFrame.new(0, hullHeight / 2 - 0.4, 0) -- sits a little into the water
	hull.Anchored = true
	hull.Parent = model
	model.PrimaryPart = hull

	local helm: VehicleSeat
	local nav: Seat? = nil
	local second = BoatData.secondSeat(b) -- "Bow", "Passenger" or "Navigator", or none
	if b.id == "Canoe" then
		-- Gray box until the canoe model is made: cedar sides, two cane thwart seats, the helm
		-- (the stern paddler, who steers) at the back and the bow paddler up front.
		local cane = Color3.fromRGB(196, 170, 112)
		for _, sx in { -1, 1 } do
			piece(model, hull, "Gunwale", Vector3.new(0.3, 0.5, b.length - 0.6), CFrame.new(sx * (b.width / 2 - 0.15), hullHeight / 2 + 0.25, 0), b.color:Lerp(Color3.new(0, 0, 0), 0.25))
		end
		piece(model, hull, "BowStem", Vector3.new(b.width * 0.6, hullHeight + 0.4, 1), CFrame.new(0, 0.2, -b.length / 2 - 0.3), b.color)
		piece(model, hull, "SternStem", Vector3.new(b.width * 0.6, hullHeight + 0.4, 1), CFrame.new(0, 0.2, b.length / 2 + 0.3), b.color)
		piece(model, hull, "SternThwart", Vector3.new(b.width - 0.4, 0.2, 1.2), CFrame.new(0, hullHeight / 2 + 0.1, b.length / 2 - 2), cane)
		piece(model, hull, "BowThwart", Vector3.new(b.width - 0.4, 0.2, 1.2), CFrame.new(0, hullHeight / 2 + 0.1, -b.length / 2 + 2.5), cane)
		helm = seat(model, hull, "VehicleSeat", "Helm", seatAt(b, "Helm", hullHeight, CFrame.new(0, hullHeight / 2 + 0.35, b.length / 2 - 2))) :: VehicleSeat
		if second then
			nav = seat(model, hull, "Seat", second, seatAt(b, second, hullHeight, CFrame.new(0, hullHeight / 2 + 0.35, -b.length / 2 + 2.5))) :: Seat
		end
	elseif b.id == "Dinghy" then
		-- Round orange tubes on the sides and bow, a wooden floor, a tiny outboard at the stern.
		local tube = math.min(1.2, b.width * 0.3)
		local side = b.width / 2 - tube / 2
		local sideTube = CFrame.Angles(0, math.rad(90), 0)
		for _, sx in { -1, 1 } do
			piece(model, hull, "Tube", Vector3.new(b.length - tube, tube, tube), CFrame.new(sx * side, hullHeight / 2, 0) * sideTube, b.color, Enum.PartType.Cylinder)
		end
		piece(model, hull, "BowTube", Vector3.new(b.width, tube, tube), CFrame.new(0, hullHeight / 2, -b.length / 2 + tube / 2), b.color, Enum.PartType.Cylinder)
		piece(model, hull, "Floor", Vector3.new(b.width - tube * 2, 0.2, b.length - tube * 1.5), CFrame.new(0, hullHeight / 2 + 0.05, 0.2), Color3.fromRGB(150, 115, 75))
		piece(model, hull, "Outboard", Vector3.new(0.8, 2, 0.8), CFrame.new(0, hullHeight / 2 + 0.3, b.length / 2 + 0.3), Color3.fromRGB(40, 40, 45))
		helm = seat(model, hull, "VehicleSeat", "Helm", seatAt(b, "Helm", hullHeight, CFrame.new(0, hullHeight / 2 + 0.35, b.length / 2 - 1.6))) :: VehicleSeat
		if second then
			-- The passenger sits up by the bow tube (the fleet, CANOE_ON).
			nav = seat(model, hull, "Seat", second, seatAt(b, second, hullHeight, CFrame.new(0, hullHeight / 2 + 0.35, -b.length / 2 + 2))) :: Seat
		end
	else
		-- Deep-V: white hull, a console amidships with the helm behind it, a seat up front.
		piece(model, hull, "Deck", Vector3.new(b.width - 0.6, 0.2, b.length - 0.6), CFrame.new(0, hullHeight / 2 + 0.05, 0), Color3.fromRGB(200, 200, 195))
		piece(model, hull, "Bow", Vector3.new(b.width * 0.7, hullHeight, 2), CFrame.new(0, 0, -b.length / 2 - 0.6), b.color)
		piece(model, hull, "Gunwale", Vector3.new(0.4, 1, b.length), CFrame.new(-b.width / 2 + 0.2, hullHeight / 2 + 0.5, 0), Color3.fromRGB(40, 70, 120))
		piece(model, hull, "Gunwale", Vector3.new(0.4, 1, b.length), CFrame.new(b.width / 2 - 0.2, hullHeight / 2 + 0.5, 0), Color3.fromRGB(40, 70, 120))
		piece(model, hull, "Console", Vector3.new(2.4, 2.4, 1.4), CFrame.new(0, hullHeight / 2 + 1.2, 0.5), Color3.fromRGB(220, 220, 215))
		piece(model, hull, "Outboard", Vector3.new(1.2, 3, 1.2), CFrame.new(0, hullHeight / 2 + 0.4, b.length / 2 + 0.5), Color3.fromRGB(40, 40, 45))
		helm = seat(model, hull, "VehicleSeat", "Helm", CFrame.new(0, hullHeight / 2 + 0.35, 2.6)) :: VehicleSeat
		nav = seat(model, hull, "Seat", second or "Navigator", CFrame.new(0, hullHeight / 2 + 0.35, -b.length / 2 + 3)) :: Seat
	end

	model:SetAttribute("BoatId", b.id)
	model:SetAttribute("OwnerId", owner.UserId)
	return model, hull, helm, nav
end

-- A little white water behind the stern while the boat moves (step sets its rate by speed).
local function makeWake(hull: BasePart): ParticleEmitter
	local at = Instance.new("Attachment")
	at.Name = "Stern"
	at.Position = Vector3.new(0, -hull.Size.Y / 2 + 0.5, hull.Size.Z / 2 + 0.6)
	at.Parent = hull
	local e = Instance.new("ParticleEmitter")
	e.Name = "Wake"
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(240, 248, 255))
	e.LightEmission = 0.2
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3.2) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.9, 1.4)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(35, 5)
	e.EmissionDirection = Enum.NormalId.Back
	e.Rotation = NumberRange.new(0, 360)
	e.Rate = 0
	e.Parent = at
	return e
end

local function makeMovers(hull: BasePart): Movers
	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Parent = hull

	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = center
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	lv.PlaneVelocity = Vector2.zero
	lv.MaxForce = 1e6
	lv.Parent = hull

	-- One constraint holds the hull level and on its heading; the server turns the heading each
	-- frame. Rigid since the N4 playtest (11/28/2026): with a soft one a log or a bank tipped the
	-- hull up to 28 degrees and the dock leaned it 2. Only the heading ever changes.
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.AlignType = Enum.AlignType.AllAxes
	ao.Attachment0 = center
	ao.CFrame = CFrame.fromOrientation(0, 0, 0)
	ao.RigidityEnabled = true
	ao.MaxTorque = math.huge
	ao.Responsiveness = 200
	ao.Parent = hull

	-- The water line, held hard on Y only (X and Z belong to the LinearVelocity). Was 1e6 at
	-- responsiveness 25, which let the hull bob 0.2 studs at the dock and climb a bank.
	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = center
	ap.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	ap.MaxAxesForce = Vector3.new(0, 1e9, 0)
	ap.Position = hull.Position
	ap.Responsiveness = 200
	ap.Parent = hull

	return { lv = lv, ao = ao, ap = ap }
end

-- The helm's controls, sent by the driver's client. A VehicleSeat only copies its Throttle and
-- Steer to the server when the driver's client owns the boat's physics, and here the server
-- does, so the client sends them itself. UNVERIFIED in Studio (2026-11-26).
local inputs: { [Player]: { throttle: number, steer: number, at: number } } = {}
local INPUT_FRESH = 0.5 -- seconds; older input counts as letting go

local function occupantPlayer(s: BasePart?): Player?
	local occ = s and (s :: any).Occupant :: Humanoid?
	return if occ then Players:GetPlayerFromCharacter(occ.Parent) else nil
end

local function aboard(boat: Boat): number
	local n = 0
	if boat.helm.Occupant then
		n += 1
	end
	if boat.nav and boat.nav.Occupant then
		n += 1
	end
	return n
end

local function unseat(s: BasePart?)
	if not s then
		return
	end
	local w = s:FindFirstChild("SeatWeld")
	if w then
		w:Destroy()
	end
end

local function stop(boat: Boat)
	boat.motion = { speed = 0, yawRate = 0 }
	boat.throttle = 0
	boat.wake.Rate = 0
	boat.movers.lv.PlaneVelocity = Vector2.zero
	boat.hull.AssemblyLinearVelocity = Vector3.zero
	boat.hull.AssemblyAngularVelocity = Vector3.zero
end

-- Move the boat so its water line sits at cf (cf's Y is ignored: always the water level).
local function moveTo(boat: Boat, cf: CFrame)
	local flat = CFrame.new(cf.Position.X, BoatRules.WATER_Y, cf.Position.Z) * cf.Rotation
	boat.model:PivotTo(flat * CFrame.new(0, boat.hull.Size.Y / 2 - 0.4, 0))
	local look = cf.LookVector
	boat.yaw = math.atan2(-look.X, -look.Z)
	boat.movers.ao.CFrame = CFrame.fromOrientation(0, boat.yaw, 0)
	stop(boat)
end

-- Stand whoever is aboard on the dock beside the boat's slip (never left in open water).
-- The move is made again just before the rider's client gets its character back: handing it
-- over at once let the client's last position (in the boat) win (11/27/2026 playtest).
local HANDBACK = 0.4 -- seconds the server keeps a rider's character after they get up
local function landRiders(boat: Boat, riders: { Player })
	for i, r in riders do
		local root = r.Character and r.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local at = CFrame.new(2, 4.5, BoatRules.SLIP_ZS[boat.slip] + (i - 1) * 2) * CFrame.Angles(0, math.rad(90), 0)
			pcall(function()
				root:SetNetworkOwner(nil)
			end)
			root.CFrame = at
			root.AssemblyLinearVelocity = Vector3.zero
			task.delay(HANDBACK - 0.1, function()
				if root.Parent then
					root.CFrame = at
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end)
		end
	end
end

local function ridersOf(boat: Boat): { Player }
	local out = {}
	for _, s in { boat.helm, boat.nav } do
		local p = occupantPlayer(s :: any)
		if p then
			table.insert(out, p)
		end
	end
	return out
end

-- Back to the slip, tied up (anchored) and empty; anyone aboard goes to the dock.
local function returnToSlip(boat: Boat)
	local riders = ridersOf(boat)
	unseat(boat.helm)
	unseat(boat.nav)
	boat.hull.Anchored = true
	moveTo(boat, BoatRules.slipCFrame(boat.slip, boat.id))
	landRiders(boat, riders)
	boat.lastGood = boat.hull.Position
	boat.docked = true
	boat.beached = false
	boat.quiet = Quiet.new()
	boat.emptyFor = 0
	boat.tiePrompt.Enabled = false
	boat.beachPrompt.Enabled = false
	boat.debugRun = nil
end

-- Where someone stands on a shore at (x, z): the ground under it (terrain or a part), never
-- the boats or a character. Falls back to a little above the water.
local function groundAt(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = {}
	for _, b in boats do
		table.insert(skip, b.model)
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	params.FilterDescendantsInstances = skip
	params.IgnoreWater = true
	local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -160, 0), params)
	return if hit then hit.Position.Y else BoatRules.WATER_Y + 1
end

-- Is the real ground at this point dry (the terrain at or above the water line)? The look-ahead
-- stop can halt a boat where the terrain bank rises, a few studs before the map's water boxes
-- end, so "Land here" asks the terrain too (BoatRules.beachAt, 11/28/2026).
local DRY_SLACK = 0.05 -- terrain this little under the water line still counts as the bank
local dryParams = RaycastParams.new()
dryParams.FilterType = Enum.RaycastFilterType.Include
dryParams.IgnoreWater = true
local function terrainDry(p: Vector3): boolean
	dryParams.FilterDescendantsInstances = { workspace.Terrain }
	local top = BoatRules.WATER_Y + 20
	local hit = workspace:Raycast(Vector3.new(p.X, top, p.Z), Vector3.new(0, -40, 0), dryParams)
	return hit ~= nil and hit.Position.Y >= BoatRules.WATER_Y - DRY_SLACK
end

-- Land on a shore (the fleet): the boat stays where it is, tied to the bank (anchored), and
-- everyone aboard steps off onto dry land ahead of the bow. Its owner re-boards with "Drive".
local function beach(boat: Boat, ashore: Vector3)
	local riders = ridersOf(boat)
	unseat(boat.helm)
	unseat(boat.nav)
	stop(boat)
	boat.hull.Anchored = true
	boat.beached = true
	boat.emptyFor = 0
	boat.lastGood = boat.hull.Position
	boat.tiePrompt.Enabled = false
	boat.beachPrompt.Enabled = false
	local side = boat.hull.CFrame.RightVector
	for i, r in riders do
		local root = r.Character and r.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local spot = ashore + side * ((i - 1) * 2.5)
			local y = groundAt(spot.X, spot.Z) + 3.5
			local at = CFrame.lookAt(Vector3.new(spot.X, y, spot.Z), Vector3.new(boat.hull.Position.X, y, boat.hull.Position.Z))
			pcall(function()
				root:SetNetworkOwner(nil)
			end)
			root.CFrame = at
			root.AssemblyLinearVelocity = Vector3.zero
			task.delay(HANDBACK - 0.1, function()
				if root.Parent then
					root.CFrame = at
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end)
		end
	end
	print(string.format("[Boats] %s's %s landed at (%.0f, %.0f)", boat.owner.Name, boat.id, boat.hull.Position.X, boat.hull.Position.Z))
end

local function castOff(boat: Boat)
	-- Leave the slip (or the shore it landed on): unanchor, and keep the server as the physics
	-- owner (fully authoritative).
	if boat.docked or boat.beached then
		boat.docked = false
		boat.beached = false
		boat.hull.Anchored = false
		pcall(function()
			boat.hull:SetNetworkOwner(nil)
		end)
	end
end

local function despawn(player: Player)
	local boat = boats[player]
	if boat then
		local riders = ridersOf(boat)
		unseat(boat.helm)
		unseat(boat.nav)
		landRiders(boat, riders)
		boat.model:Destroy()
		boats[player] = nil
	end
end

local spawnFor: (Player) -> ()
local waitingForSlip: { [Player]: boolean } = {}

local function takenSlips(): { [number]: boolean }
	local taken = {}
	for _, b in boats do
		taken[b.slip] = true
	end
	return taken
end

-- Give boats to owners still waiting for a free slip.
local function fillWaiting()
	for _, p in Players:GetPlayers() do
		local data = PlayerData.get(p)
		if p.Parent and data and not boats[p] and data.boat ~= "" then
			spawnFor(p)
		end
	end
end

function spawnFor(player: Player)
	local data = PlayerData.get(player)
	if not data or not player.Parent then
		return
	end
	local id = data.boat
	if id == "" or not BoatLogic.owns(data, id) or not BoatData.byId[id] then
		return
	end
	local slip = if boats[player] then boats[player].slip else BoatRules.nextFreeSlip(takenSlips())
	despawn(player)
	if not slip then
		if not waitingForSlip[player] then
			waitingForSlip[player] = true -- say it once, not every time someone leaves
			hint(player, "Every boat slip is busy right now. Your boat will be there when one frees up.")
		end
		return
	end
	waitingForSlip[player] = nil
	local b = BoatData.byId[id]
	local model, hull, helm, nav = buildModel(player, b, BoatRules.slipCFrame(slip, id))
	-- The second seat's prompt: paddle in the canoe's bow, ride in the dinghy or the Deep-V.
	local rideAction = if b.paddle then "Paddle" else "Ride"
	local chumPrompt: ProximityPrompt? = nil
	if nav and Config.CHUM_ON and b.chum then
		chumPrompt = prompt(nav, "ChumPrompt", "Toss chum", b.name)
		chumPrompt.MaxActivationDistance = 3 -- only whoever sits in that seat is close enough
		chumPrompt.Enabled = false
	end
	local boat: Boat = {
		owner = player,
		id = id,
		slip = slip,
		model = model,
		hull = hull,
		helm = helm,
		nav = nav,
		drivePrompt = drivePromptOn(hull, b),
		ridePrompt = if nav then prompt(nav, "RidePrompt", rideAction, player.DisplayName .. "'s " .. b.name) else nil,
		tiePrompt = prompt(helm, "TiePrompt", "Tie up", "Boat slip " .. slip),
		beachPrompt = prompt(helm, "BeachPrompt", "Land here", b.name),
		chumPrompt = chumPrompt,
		movers = makeMovers(hull),
		wake = makeWake(hull),
		motion = { speed = 0, yawRate = 0 },
		yaw = 0,
		lastGood = hull.Position,
		checkTimer = 0,
		emptyFor = 0,
		docked = true,
		beached = false,
		quiet = Quiet.new(),
		throttle = 0,
		chumAt = nil,
		stopToasted = false,
		freeFor = 0,
		debugRun = nil,
		runLog = nil,
		runLogAt = nil,
	}
	-- E (gamepad X) like every other prompt: F and the gamepad's face buttons reel in a fight.
	boat.tiePrompt.Enabled = false
	boat.beachPrompt.Enabled = false
	boats[player] = boat

	-- Only the owner may take the helm. The client hides the prompt from everyone else too.
	boat.drivePrompt.Triggered:Connect(function(who: Player)
		if who ~= player or helm.Occupant then
			return
		end
		local slipPos = BoatRules.slipCFrame(boat.slip, boat.id).Position
		if WeatherService.isStorm() and (boat.docked or BoatLogic.canDock(boat.hull.Position, slipPos, boat.motion.speed)) then
			hint(who, "Lightning! Fishing from shore is safer. Boats stay in until the storm passes.")
			return
		end
		local hum = who.Character and who.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and hum.SeatPart == nil then
			-- Put them at the helm first, so sitting from a few studs off (a landed boat, from
			-- the shore) never has to drag the character across.
			local root = who.Character and who.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				root.CFrame = helm.CFrame * CFrame.new(0, 2.5, 0)
				root.AssemblyLinearVelocity = Vector3.zero
			end
			castOff(boat)
			helm:Sit(hum)
		end
	end)
	if nav and boat.ridePrompt then
		boat.ridePrompt.Triggered:Connect(function(who: Player)
			if nav.Occupant then
				return
			end
			local hum = who.Character and who.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and hum.SeatPart == nil then
				nav:Sit(hum) -- a rider doesn't cast off: only the helm does
			end
		end)
	end
	boat.tiePrompt.Triggered:Connect(function(who: Player)
		if who ~= player or occupantPlayer(helm) ~= player or not boat.tiePrompt.Enabled then
			return
		end
		returnToSlip(boat) -- stands everyone who was aboard on the dock beside the slip
	end)
	-- Land on a shore (the fleet): checked again here, on the server's own numbers.
	boat.beachPrompt.Triggered:Connect(function(who: Player)
		if who ~= player or occupantPlayer(helm) ~= player or boat.docked or boat.beached then
			return
		end
		local ashore = BoatRules.beachAt(boat.id, boat.hull.Position, boat.hull.CFrame.LookVector, boat.motion.speed, terrainDry)
		if not ashore then
			hint(who, "Point the bow at the shore and slow right down to land.")
			return
		end
		beach(boat, ashore)
	end)
	-- Chum from the second seat (CHUM_ON): a boil ahead of the bow, quicker bites for everyone aboard.
	if chumPrompt and nav then
		chumPrompt.Triggered:Connect(function(who: Player)
			if occupantPlayer(nav) ~= who then
				return
			end
			local now = os.clock()
			if not Coop.chumReady(boat.chumAt, now) then
				hint(who, string.format("The chum bucket needs %d more seconds.", math.ceil(Coop.chumWait(boat.chumAt, now))))
				return
			end
			boat.chumAt = now
			local look = boat.hull.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
			local at = Vector3.new(boat.hull.Position.X, BoatRules.WATER_Y, boat.hull.Position.Z) + flat * (b.length / 2 + Coop.CHUM_AHEAD)
			local boil = Instance.new("Part")
			boil.Name = "ChumBoil"
			boil.Anchored = true
			boil.CanCollide = false
			boil.CanQuery = false
			boil.CanTouch = false
			boil.Transparency = 1
			boil.Size = Vector3.new(6, 0.2, 6)
			boil.CFrame = CFrame.new(at)
			local fizz = Instance.new("ParticleEmitter")
			fizz.Texture = "rbxasset://textures/particles/smoke_main.dds"
			fizz.Color = ColorSequence.new(Color3.fromRGB(235, 240, 230))
			fizz.Size = NumberSequence.new(0.6, 1.6)
			fizz.Transparency = NumberSequence.new(0.4, 1)
			fizz.Lifetime = NumberRange.new(0.6, 1.1)
			fizz.Speed = NumberRange.new(1, 2.5)
			fizz.SpreadAngle = Vector2.new(60, 60)
			fizz.EmissionDirection = Enum.NormalId.Top
			fizz.Rate = 18
			fizz.Parent = boil
			boil.Parent = workspace
			game:GetService("Debris"):AddItem(boil, Coop.CHUM_LASTS)
			print(string.format("[Boats] %s tossed chum off %s's %s", who.Name, player.Name, boat.id))
			for _, r in ridersOf(boat) do
				hint(r, "Chum in the water! Bites come quicker for 25 seconds.")
			end
		end)
	end

	local function onSeatChanged(s: BasePart, prompt: ProximityPrompt?, ownerOnly: boolean)
		local died: RBXScriptConnection? = nil
		local last: Humanoid? = nil
		(s :: any):GetPropertyChangedSignal("Occupant"):Connect(function()
			local occ = (s :: any).Occupant :: Humanoid?
			-- Whoever just got up walks on their own again: hand their character back to them.
			if last and last ~= occ then
				-- Dying or resetting at the helm sends the boat home. The seat empties (the death
				-- breaks the seat weld) before Died reaches the handler below, so check here too.
				if ownerOnly and (last.Health <= 0 or last.Parent == nil) then
					task.delay(1, function()
						if boats[player] == boat and not helm.Occupant then
							returnToSlip(boat)
						end
					end)
				end
				local leaver = Players:GetPlayerFromCharacter(last.Parent)
				local root = last.Parent and last.Parent:FindFirstChild("HumanoidRootPart") :: BasePart?
				if leaver and root then
					task.delay(HANDBACK, function()
						if root.Parent then
							pcall(function()
								root:SetNetworkOwner(leaver)
							end)
						end
					end)
				end
			end
			last = occ
			if died then
				died:Disconnect() -- only the current occupant's death counts
				died = nil
			end
			-- A seat weld joins the character to the boat and leaving splits it off again:
			-- keep the server as the boat's physics owner either way.
			if not boat.docked then
				pcall(function()
					boat.hull:SetNetworkOwner(nil)
				end)
			end
			if prompt then
				prompt.Enabled = occ == nil
			end
			if not occ then
				return
			end
			local who = Players:GetPlayerFromCharacter(occ.Parent)
			-- Seats also take whoever bumps into them: send anyone who isn't allowed off.
			if ownerOnly and who ~= player then
				unseat(s)
				if who then
					hint(who, "Only " .. player.DisplayName .. " can drive this boat.")
				end
				return
			end
			if ownerOnly then
				castOff(boat)
			end
			boat.emptyFor = 0
			-- Dying or resetting at the helm sends the boat home.
			died = occ.Died:Connect(function()
				if boats[player] == boat and ownerOnly then
					task.delay(1, function()
						if boats[player] == boat and not helm.Occupant then
							returnToSlip(boat)
						end
					end)
				end
			end)
			if ownerOnly then
				local ok, msg = BoatLogic.canDrive(boat.id, aboard(boat))
				if not ok and msg then
					hint(player, msg)
				end
			end
		end)
	end
	onSeatChanged(helm, boat.drivePrompt, true)
	if nav then
		onSeatChanged(nav, boat.ridePrompt, false)
	end

	model.Parent = workspace
	returnToSlip(boat)
end

-- Anything solid the hull would hit at these points, between its keel and a little over its top:
-- the bed or a bank rising out of the shallows, a part such as a still boat at the mooring.
-- Parts that don't collide (reeds) and the water are ignored; the bridge is above the hull.
local KEEL_CLEAR = 0.15 -- studs below the hull's bottom that still count as hitting it
-- Returns "shore" for the terrain, "thing" for a part, nil when clear.
local function solidAhead(boat: Boat, probes: { Vector3 }, params: RaycastParams): string?
	local bottom = BoatRules.WATER_Y - 0.4 -- the hull sits 0.4 into the water
	local top = bottom + boat.hull.Size.Y + 0.3
	for _, p in probes do
		local hit = workspace:Raycast(Vector3.new(p.X, top, p.Z), Vector3.new(0, bottom - KEEL_CLEAR - top, 0), params)
		if hit then
			return if hit.Instance:IsA("Terrain") then "shore" else "thing"
		end
	end
	return nil
end

-- The hull is never tilted or off its water line: if anything has nudged it (a bump from
-- another boat, a character climbing in), set it straight at once.
local LEVEL_UP = math.cos(math.rad(1)) -- more than 1 degree off upright
local LEVEL_DY = 0.15 -- or this many studs off its water line
local function keepLevel(boat: Boat)
	local cf = boat.hull.CFrame
	local waterLine = BoatRules.WATER_Y + boat.hull.Size.Y / 2 - 0.4
	if cf.UpVector.Y >= LEVEL_UP and math.abs(cf.Position.Y - waterLine) <= LEVEL_DY then
		return
	end
	local v = boat.hull.AssemblyLinearVelocity
	boat.model:PivotTo(CFrame.new(cf.Position.X, waterLine, cf.Position.Z) * CFrame.fromOrientation(0, boat.yaw, 0))
	boat.hull.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
	boat.hull.AssemblyAngularVelocity = Vector3.zero
end

-- Every frame, just before physics (so a new turn from the driver moves the hull on the very
-- next step): input to motion to movers, then the half-second checks.
local function step(dt: number)
	-- One ray filter for the look ahead this frame: every character and each boat's own model
	-- (added per boat below). Other boats stay in, so two boats stop nose to nose.
	local chars: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(chars, p.Character)
		end
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true
	rayParams.RespectCanCollide = true
	for player, boat in boats do
		if boat.docked or boat.beached or not boat.hull.Parent then
			continue
		end
		local n = aboard(boat)
		local throttle, steer = 0, 0
		if boat.helm.Occupant then
			local driver = occupantPlayer(boat.helm)
			local inp = driver and inputs[driver]
			if inp and os.clock() - inp.at < INPUT_FRESH then
				throttle, steer = inp.throttle, inp.steer
			else
				-- Fallback (e.g. a solo Studio test, where the seat's own values may arrive).
				throttle, steer = boat.helm.ThrottleFloat, boat.helm.SteerFloat
				if throttle == 0 and steer == 0 then
					throttle, steer = boat.helm.Throttle, boat.helm.Steer
				end
			end
		end
		-- Studio only (shot c03): a scripted run holds the throttle, straight, until stopX.
		local run = boat.debugRun
		if run then
			throttle, steer = run.throttle, 0
			if boat.hull.Position.X >= run.stopX then
				run.throttle = 0
			end
		end
		local okCrew, crewMsg = BoatLogic.canDrive(boat.id, n)
		if not okCrew then
			if (throttle ~= 0 or steer ~= 0) and crewMsg then
				hint(player, crewMsg)
			end
			throttle, steer = 0, 0
		end
		boat.throttle = throttle
		-- A paddled boat goes faster with both seats paddling (the canoe, 7 to 11).
		local paddlers = if Config.CANOE_ON then BoatLogic.paddlers(boat.id, n) else 1
		boat.motion = BoatLogic.step(boat.motion, boat.id, throttle, steer, dt, paddlers)
		keepLevel(boat)
		local pos = boat.hull.Position
		local look = CFrame.fromOrientation(0, boat.yaw, 0).LookVector
		-- Look ahead (the N4 playtest): stop with water to spare before a shore, a log, the dock,
		-- water this boat may not use or anything else solid. Steering still works when stopped,
		-- and backing away is never blocked by what is ahead.
		local blocked, why = BoatRules.stopAhead(boat.id, pos, look, boat.motion.speed)
		if not blocked and boat.motion.speed ~= 0 then
			local skip = table.clone(chars)
			table.insert(skip, boat.model)
			rayParams.FilterDescendantsInstances = skip
			local solid = solidAhead(boat, BoatRules.probes(boat.id, pos, look, boat.motion.speed), rayParams)
			if solid then
				blocked, why = solid, BoatRules.stopText(boat.id, solid, nil)
			end
		end
		local pushing = (boat.motion.speed > 0 and throttle > 0) or (boat.motion.speed < 0 and throttle < 0)
		if blocked then
			boat.motion = { speed = 0, yawRate = boat.motion.yawRate }
		end
		-- The whole hull (N4 review 1): the next pose's 8-point footprint against the dock, logs, the
		-- shore and anything solid, the move and the turn apart (BoatRules.poseCheck).
		local spin = BoatRules.spinY(boat.motion.yawRate)
		if boat.motion.speed ~= 0 or spin ~= 0 then
			local skip = table.clone(chars)
			table.insert(skip, boat.model)
			rayParams.FilterDescendantsInstances = skip
			local function solidAt(p: Vector3): string?
				return solidAhead(boat, { p }, rayParams)
			end
			local moveOk, turnOk, thing = BoatRules.poseCheck(boat.id, pos, boat.yaw, boat.motion.speed, spin, solidAt)
			if not moveOk or not turnOk then
				boat.motion = { speed = if moveOk then boat.motion.speed else 0, yawRate = if turnOk then boat.motion.yawRate else 0 }
				if not blocked and thing then
					blocked, why = thing, BoatRules.stopText(boat.id, thing, nil)
				end
				if not turnOk and steer ~= 0 then
					pushing = true
				end
			end
		end
		-- One toast per stop (two stacked toasts were seen): the first stop says why, and nothing
		-- more is said until the boat has moved freely for STOP_QUIET seconds.
		if blocked then
			boat.freeFor = 0
			local driver = occupantPlayer(boat.helm)
			if pushing and driver and why and not boat.stopToasted then
				boat.stopToasted = true
				hint(driver, why)
			end
		elseif boat.motion.speed ~= 0 then
			boat.freeFor += dt
			if boat.freeFor >= STOP_QUIET then
				boat.stopToasted = false
			end
		end
		Quiet.step(boat.quiet, boat.id, throttle, boat.motion.speed, math.abs(boat.motion.speed) * dt, pos, os.clock())
		local vx, vz = BoatRules.planeVelocity(look, boat.motion.speed)
		local dx, dz = BoatRules.drift(boat.id, pos, n)
		boat.movers.lv.PlaneVelocity = Vector2.new(vx + dx, vz + dz)
		boat.yaw += BoatRules.spinY(boat.motion.yawRate) * dt
		boat.movers.ao.CFrame = CFrame.fromOrientation(0, boat.yaw, 0)
		boat.movers.ap.Position = Vector3.new(pos.X, BoatRules.WATER_Y + boat.hull.Size.Y / 2 - 0.4, pos.Z)
		boat.wake.Rate = 40 * math.clamp(math.abs(boat.motion.speed) / BoatLogic.fastest(boat.id), 0, 1)
		if boat.runLog then
			local t = os.clock()
			if not boat.runLogAt or t - (boat.runLogAt :: number) >= 0.05 then
				boat.runLogAt = t
				table.insert(boat.runLog :: { { number } }, { DateTime.now().UnixTimestampMillis, math.round(pos.X * 100) / 100 })
			end
		end

		boat.checkTimer += dt
		if boat.checkTimer >= CHECK_EVERY then
			local verdict, at, why = BoatRules.check(boat.id, boat.lastGood, pos, boat.checkTimer)
			boat.checkTimer = 0
			if verdict == "back" and at then
				local look = boat.hull.CFrame.LookVector
				moveTo(boat, CFrame.lookAt(at, at + Vector3.new(look.X, 0, look.Z)))
				local driver = occupantPlayer(boat.helm)
				if driver then
					hint(driver, why or "The boat can't go there.")
				end
			elseif verdict == "turn" and at then
				moveTo(boat, CFrame.lookAt(at, at + Vector3.new(0, 0, 1))) -- facing home, south
				local msg = why
				local driver = occupantPlayer(boat.helm)
				if driver and msg then
					hint(driver, msg)
				end
				boat.lastGood = at
			else
				boat.lastGood = pos
			end
		end

		-- Tie up when close to your own slip and slow.
		local slipPos = BoatRules.slipCFrame(boat.slip, boat.id).Position
		boat.tiePrompt.Enabled = boat.helm.Occupant ~= nil and BoatLogic.canDock(pos, slipPos, boat.motion.speed)
		-- Land on a shore (the fleet): slow, bow on a bank, and not right at your own slip.
		boat.beachPrompt.Enabled = boat.helm.Occupant ~= nil
			and not boat.tiePrompt.Enabled
			and BoatRules.beachAt(boat.id, pos, boat.hull.CFrame.LookVector, boat.motion.speed, terrainDry) ~= nil

		-- Empty boats away from the slip go home on their own.
		if n == 0 then
			boat.emptyFor += dt
			if boat.emptyFor >= EMPTY_RETURN then
				returnToSlip(boat)
			end
		else
			boat.emptyFor = 0
		end
	end
	-- Landed boats wait for their owner while they are near; left alone, they go home too.
	for player, boat in boats do
		if boat.beached and boat.hull.Parent then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local near = root ~= nil and (root.Position - boat.hull.Position).Magnitude <= BEACH_KEEP
			if aboard(boat) > 0 or near then
				boat.emptyFor = 0
			else
				boat.emptyFor += dt
				if boat.emptyFor >= EMPTY_RETURN then
					print(string.format("[Boats] %s's %s was left on the shore and went home", player.Name, boat.id))
					returnToSlip(boat)
				end
			end
		end
	end
	-- The chum prompt shows to the second seat while the bucket is ready.
	local now = os.clock()
	for _, boat in boats do
		if boat.chumPrompt then
			boat.chumPrompt.Enabled = boat.nav ~= nil and boat.nav.Occupant ~= nil and not boat.docked and Coop.chumReady(boat.chumAt, now)
		end
	end
end

-- Studio only (DebugCoop): sit this Humanoid (a test rig) in the second seat of this owner's
-- boat, so a one-player test has a crew of two. False, with why, when it can't.
function BoatService.debugSeatSecond(owner: Player, hum: Humanoid): (boolean, string?)
	if not RunService:IsStudio() then
		return false, "Studio only"
	end
	local boat = boats[owner]
	if not boat then
		return false, "no boat"
	end
	local nav = boat.nav
	if not nav then
		return false, "this boat has no second seat"
	end
	if nav.Occupant then
		return false, "the second seat is taken"
	end
	local root = hum.Parent and hum.Parent:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = false
		root.CFrame = nav.CFrame + Vector3.new(0, 2.5, 0)
	end
	nav:Sit(hum)
	return true, nil
end

-- Studio only (shot c03, tools/shots): a scripted straight run. Puts this owner's boat at
-- (startX, z) heading east, seats the owner at the helm, and holds full throttle (no steer) until
-- the hull passes stopX, then lets it coast. Logs the hull's x every 0.05 s with the clock in unix
-- milliseconds (debugRunLog), so a capture's file time tells where the boat was. False and why
-- when it can't.
function BoatService.debugRun(owner: Player, z: number, startX: number, stopX: number): (boolean, string?)
	if not RunService:IsStudio() then
		return false, "Studio only"
	end
	local boat = boats[owner]
	if not boat then
		return false, "no boat"
	end
	local hum = owner.Character and owner.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return false, "no character"
	end
	if hum.SeatPart and hum.SeatPart ~= boat.helm then
		hum.Sit = false
		task.wait(0.2)
	end
	castOff(boat)
	local at = Vector3.new(startX, BoatRules.WATER_Y, z)
	moveTo(boat, CFrame.lookAt(at, at + Vector3.new(1, 0, 0)))
	boat.lastGood = boat.hull.Position
	if hum.SeatPart ~= boat.helm then
		local root = owner.Character and owner.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.CFrame = boat.helm.CFrame * CFrame.new(0, 2.5, 0)
			root.AssemblyLinearVelocity = Vector3.zero
		end
		boat.helm:Sit(hum)
		task.wait(0.3)
	end
	boat.stopToasted = false
	boat.runLog = {}
	boat.runLogAt = nil
	boat.debugRun = { throttle = 1, stopX = stopX }
	return true, nil
end

-- Studio only: ends a scripted run (the helm's own input takes over again).
function BoatService.debugEndRun(owner: Player)
	local boat = boats[owner]
	if boat then
		boat.debugRun = nil
	end
end

-- Studio only: the run's log as "unixms:x,..." and the hull's x now.
function BoatService.debugRunLog(owner: Player): (string?, number?)
	local boat = boats[owner]
	if not boat or not boat.runLog then
		return nil, nil
	end
	local parts = {}
	for _, e in boat.runLog :: { { number } } do
		table.insert(parts, string.format("%d:%.2f", e[1], e[2]))
	end
	return table.concat(parts, ","), boat.hull.Position.X
end

-- For FishingService: the boat this player sits in (as driver or rider), and its speed.
function BoatService.seatedIn(player: Player): (string?, number)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local part = hum and hum.SeatPart
	if not part then
		return nil, 0
	end
	for _, boat in boats do
		if part == boat.helm or part == boat.nav then
			return boat.id, math.abs(boat.motion.speed)
		end
	end
	return nil, 0
end

-- The boat this player sits in (as driver or rider), or nil.
local function boatOf(player: Player): Boat?
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local part = hum and hum.SeatPart
	if not part then
		return nil
	end
	for _, boat in boats do
		if part == boat.helm or part == boat.nav then
			return boat
		end
	end
	return nil
end

-- Quiet approach (Shared/Quiet): does a cast from this player's seat get the bonus now?
-- Also whether they are on a boat at all (for the playtest log).
function BoatService.quietFor(player: Player): (boolean, boolean)
	local boat = boatOf(player)
	if not boat then
		return false, false
	end
	return Quiet.active(boat.quiet, os.clock(), boat.hull.Position), true
end

-- Chum (Coop): is a boil going for the boat this player sits in?
function BoatService.chumFor(player: Player): boolean
	local boat = boatOf(player)
	return boat ~= nil and Config.CHUM_ON and Coop.chumActive(boat.chumAt, os.clock())
end

-- Buddy loan (Coop): the owner of the boat this player rides in as a passenger, or nil when
-- they sit in their own boat or none.
function BoatService.ownerIfPassenger(player: Player): Player?
	local boat = boatOf(player)
	if boat and boat.owner ~= player then
		return boat.owner
	end
	return nil
end

-- For team catches: the boat this player sits in, the others aboard, how many are aboard,
-- and whether it's in blue water.
function BoatService.crewOf(player: Player): (string?, { Player }, number, boolean)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local part = hum and hum.SeatPart
	if part then
		for _, boat in boats do
			if part == boat.helm or part == boat.nav then
				local mates = {}
				for _, s in { boat.helm, boat.nav } do
					local p = occupantPlayer(s :: any)
					if p and p ~= player then
						table.insert(mates, p)
					end
				end
				return boat.id, mates, aboard(boat), BoatRules.inBlueWater(boat.hull.Position)
			end
		end
	end
	return nil, {}, 0, false
end

-- Extra casting rules on the water (BoatRules.castCheck with this player's seat).
function BoatService.castCheck(player: Player, landing: Vector3): (boolean, string?)
	local id, speed = BoatService.seatedIn(player)
	local ok, msg = BoatRules.castCheck(landing, id, speed)
	if ok and id and BoatRules.inBlueWater(landing) then
		-- Blue water takes the full crew aboard, casting into it from the buoy line too.
		local _, _, aboardNow = BoatService.crewOf(player)
		local b = BoatData.byId[id]
		if b and aboardNow < b.crew then
			return false, "Blue water takes a full crew. Bring a friend as navigator."
		end
	end
	return ok, msg
end

-- While a line is in from a boat: is it still fine? A boat that speeds up or runs far from
-- the bobber loses the line. Far means 15 studs past the longest cast any rod and bait can
-- make (it was a flat 60, and a Graphite spinner cast lands 65 out: the 11/27/2026 playtest).
local function longestCast(): number
	local CastLogic = require(Shared.CastLogic)
	local best = 0
	for _, rod in require(Shared.RodData).list do
		for _, bait in require(Shared.BaitData).list do
			best = math.max(best, CastLogic.distance(1, rod.id, bait.id))
		end
	end
	return best
end
BoatService.MAX_LINE = longestCast() + 15
function BoatService.lineCheck(player: Player, bobber: Vector3): (boolean, string?)
	local id, speed = BoatService.seatedIn(player)
	if not id then
		return true, nil
	end
	if not BoatLogic.canCast(speed, id) then
		return false, "The boat moved off and the line came free. Stop the boat to fish."
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(bobber.X, 0, bobber.Z)).Magnitude > BoatService.MAX_LINE then
		return false, "The boat drifted too far and the line came free."
	end
	return true, nil
end

function BoatService.start()
	if not Config.boatsOn() then
		-- Switched off (Config.BOATS_ON / BIG_LAKE_ON): answer the shop so it never waits.
		Remotes.func("BuyBoat").OnServerInvoke = function()
			return false, "Boats are coming soon."
		end
		return
	end
	toastEvent = Remotes.event("Toast")

	-- The feel layer (BOAT_FEEL_ON): the client draws each boat's art model, but ServerStorage
	-- never reaches a client, so the boat models and paddles go to ReplicatedStorage.BoatArt.
	if Config.BOAT_FEEL_ON then
		local art = game:GetService("ServerStorage"):FindFirstChild("Art")
		local out = ReplicatedStorage:FindFirstChild("BoatArt") or Instance.new("Folder")
		out.Name = "BoatArt"
		local missing = {}
		for _, name in BoatFeel.artNames() do
			local src = art and art:FindFirstChild(name)
			if src and not out:FindFirstChild(name) then
				src:Clone().Parent = out
			elseif not src then
				table.insert(missing, name)
			end
		end
		out.Parent = ReplicatedStorage
		if #missing > 0 then
			warn("[Boats] not in ServerStorage.Art, drawn as the gray box: " .. table.concat(missing, ", "))
		end

		-- The horn: the driver hears their own at once (no round trip); everyone else hears it
		-- from here, at that boat's hull.
		local lastHorn: { [Player]: number } = {}
		local horn = Remotes.event("BoatHorn")
		horn.OnServerEvent:Connect(function(player: Player)
			local now = os.clock()
			if not BoatFeel.hornReady(lastHorn[player], now) then
				return
			end
			for _, boat in boats do
				if occupantPlayer(boat.helm) == player then
					lastHorn[player] = now
					for _, other in Players:GetPlayers() do
						if other ~= player then
							horn:FireClient(other, boat.hull)
						end
					end
					return
				end
			end
		end)
		Players.PlayerRemoving:Connect(function(p)
			lastHorn[p] = nil
		end)
	end

	Remotes.func("BuyBoat").OnServerInvoke = function(player: Player, boatId: any)
		local data = PlayerData.get(player)
		if not data or type(boatId) ~= "string" then
			return false, "That boat isn't for sale."
		end
		local current = boats[player]
		if current and not current.docked and (current.helm.Occupant or (current.nav and current.nav.Occupant)) then
			return false, "Tie up your boat before buying another."
		end
		local ok, msg = BoatLogic.buy(data, boatId)
		if ok then
			data.boat = boatId -- the new boat waits at your slip
			print(string.format("[Boats] %s bought %s (now %d coins)", player.Name, boatId, data.coins))
			PlayerData.changed(player)
			spawnFor(player)
		end
		return ok, msg
	end

	-- The helm's controls from the driver's client: numbers only, clamped, newest wins.
	Remotes.event("BoatInput").OnServerEvent:Connect(function(player: Player, throttle: any, steer: any)
		if type(throttle) ~= "number" or type(steer) ~= "number" or throttle ~= throttle or steer ~= steer then
			return
		end
		inputs[player] = { throttle = math.clamp(throttle, -1, 1), steer = math.clamp(steer, -1, 1), at = os.clock() }
	end)

	-- "Send my boat home" from the journal: back to its slip, tied up, anyone aboard to the dock.
	local lastSendHome: { [Player]: number } = {}
	Remotes.event("SendBoatHome").OnServerEvent:Connect(function(player: Player)
		local now = os.clock()
		if lastSendHome[player] and now - lastSendHome[player] < SEND_HOME_GAP then
			return
		end
		lastSendHome[player] = now
		local boat = boats[player]
		if not boat then
			hint(player, "You don't have a boat yet.")
			return
		end
		if boat.docked then
			hint(player, "Your boat is already tied up at the slip.")
			return
		end
		print(string.format("[Boats] %s sent their %s home", player.Name, boat.id))
		returnToSlip(boat)
		hint(player, "Your boat is heading home. It'll be waiting at the slip.")
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastSendHome[p] = nil
	end)

	-- Which owned boat waits at your slip: the shop's "Use this boat" and, with BOATHOUSE_ON, the
	-- boathouse's "Your boat" board. The rule is BoatLogic.choose (it saves data.boat); this adds
	-- that nobody may be aboard the current boat. With the boathouse on, the player hears why.
	Remotes.event("ChooseBoat").OnServerEvent:Connect(function(player: Player, boatId: any)
		local data = PlayerData.get(player)
		if not data or type(boatId) ~= "string" then
			return
		end
		local current = boats[player]
		if BoatLogic.owns(data, boatId) and data.boat ~= boatId and current and (current.helm.Occupant or (current.nav and current.nav.Occupant)) then
			hint(player, "Tie up your boat before switching.")
			return
		end
		local ok, msg = BoatLogic.choose(data, boatId)
		if not ok then
			if Config.BOATHOUSE_ON then
				hint(player, msg)
			end
			return
		end
		print(string.format("[Boats] %s chose the %s for their slip", player.Name, boatId))
		PlayerData.changed(player)
		spawnFor(player)
		if Config.BOATHOUSE_ON then
			hint(player, msg)
		end
	end)

	-- The fish finder: only the navigator of a boat sees what's under it (boat plan Task 8).
	local Teamwork = require(Shared.Teamwork)
	local FishLogic = require(Shared.FishLogic)
	local WorldBuilder = require(script.Parent.WorldBuilder)
	local zones = WorldBuilder.zones()
	for _, z in BoatRules.ZONES do
		table.insert(zones, z)
	end
	Remotes.func("FishFinder").OnServerInvoke = function(player: Player)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local part = hum and hum.SeatPart
		for _, boat in boats do
			if part ~= nil and part == boat.nav then
				local spot = FishLogic.spotAt(boat.hull.Position, zones)
				local period = FishLogic.periodFromClock(game:GetService("Lighting").ClockTime)
				return Teamwork.finder(spot, period, WeatherService.now())
			end
		end
		return nil
	end

	PlayerData.onLoad(function(p)
		spawnFor(p)
	end)
	Players.PlayerRemoving:Connect(function(p)
		despawn(p)
		lastHint[p] = nil
		inputs[p] = nil
		waitingForSlip[p] = nil
		task.defer(fillWaiting) -- after the leaving player is gone, so their boat isn't rebuilt
	end)
	RunService.PreSimulation:Connect(step)
end

return BoatService
