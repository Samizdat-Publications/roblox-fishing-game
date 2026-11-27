--!strict
-- Boats in the world. Each owner's chosen boat waits at a slip by the dock; the owner takes
-- the helm with a "Drive" prompt (anyone may "Ride" in a Deep-V's second seat). Every frame
-- the server reads the helm seat's throttle and steer, runs BoatLogic.step and sets the
-- movers; every half second it checks where the boat went (BoatRules.check). Docking,
-- empty boats and leaving all send the boat back to its slip.
-- Rules live in the pure modules BoatData, BoatLogic and BoatRules (tested outside Studio).
-- Written 2026-11-26 in the cloud; the dinghy proven in Studio 11/27/2026 (L7). The Deep-V's
-- two seats and the fish finder still wait for a two-player playtest.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local BoatData = require(Shared.BoatData)
local BoatLogic = require(Shared.BoatLogic)
local BoatRules = require(Shared.BoatRules)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local WeatherService = require(script.Parent.WeatherService)

local BoatService = {}

local CHECK_EVERY = 0.5 -- seconds between the server's position checks
local EMPTY_RETURN = 60 -- an empty boat away from its slip goes back after this long
local HINT_GAP = 3 -- seconds between repeats of the same hint to one player

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
	movers: Movers,
	wake: ParticleEmitter,
	motion: BoatLogic.Motion,
	yaw: number, -- heading in radians around +Y; the AlignOrientation holds the hull to it
	lastGood: Vector3,
	checkTimer: number,
	emptyFor: number,
	docked: boolean,
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

-- A gray-box boat, bow toward -Z of the hull. The art models in art/models replace the
-- visible pieces later (boat plan Task 2); the hull part stays as the physics body.
local function buildModel(owner: Player, b: BoatData.Boat, at: CFrame): (Model, BasePart, VehicleSeat, Seat?)
	local model = Instance.new("Model")
	model.Name = owner.Name .. "_" .. b.id
	local hullHeight = if b.id == "DeepV" then 1.6 else 1.2
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
	if b.id == "Dinghy" then
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
		helm = seat(model, hull, "VehicleSeat", "Helm", CFrame.new(0, hullHeight / 2 + 0.35, b.length / 2 - 1.6)) :: VehicleSeat
	else
		-- Deep-V: white hull, a console amidships with the helm behind it, a seat up front.
		piece(model, hull, "Deck", Vector3.new(b.width - 0.6, 0.2, b.length - 0.6), CFrame.new(0, hullHeight / 2 + 0.05, 0), Color3.fromRGB(200, 200, 195))
		piece(model, hull, "Bow", Vector3.new(b.width * 0.7, hullHeight, 2), CFrame.new(0, 0, -b.length / 2 - 0.6), b.color)
		piece(model, hull, "Gunwale", Vector3.new(0.4, 1, b.length), CFrame.new(-b.width / 2 + 0.2, hullHeight / 2 + 0.5, 0), Color3.fromRGB(40, 70, 120))
		piece(model, hull, "Gunwale", Vector3.new(0.4, 1, b.length), CFrame.new(b.width / 2 - 0.2, hullHeight / 2 + 0.5, 0), Color3.fromRGB(40, 70, 120))
		piece(model, hull, "Console", Vector3.new(2.4, 2.4, 1.4), CFrame.new(0, hullHeight / 2 + 1.2, 0.5), Color3.fromRGB(220, 220, 215))
		piece(model, hull, "Outboard", Vector3.new(1.2, 3, 1.2), CFrame.new(0, hullHeight / 2 + 0.4, b.length / 2 + 0.5), Color3.fromRGB(40, 40, 45))
		helm = seat(model, hull, "VehicleSeat", "Helm", CFrame.new(0, hullHeight / 2 + 0.35, 2.6)) :: VehicleSeat
		nav = seat(model, hull, "Seat", "Navigator", CFrame.new(0, hullHeight / 2 + 0.35, -b.length / 2 + 3)) :: Seat
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

	-- One constraint holds the hull upright and on its heading; the server turns the heading
	-- each frame (so nothing fights it, and a bump that tilts the hull rights itself).
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.AlignType = Enum.AlignType.AllAxes
	ao.Attachment0 = center
	ao.CFrame = CFrame.fromOrientation(0, 0, 0)
	ao.MaxTorque = 1e6
	ao.Responsiveness = 30
	ao.Parent = hull

	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = center
	ap.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	ap.MaxAxesForce = Vector3.new(0, 1e6, 0) -- holds the water line only
	ap.Position = hull.Position
	ap.Responsiveness = 25
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
	boat.emptyFor = 0
	boat.tiePrompt.Enabled = false
end

local function castOff(boat: Boat)
	-- Leave the slip: unanchor, and keep the server as the physics owner (fully authoritative).
	if boat.docked then
		boat.docked = false
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
	local boat: Boat = {
		owner = player,
		id = id,
		slip = slip,
		model = model,
		hull = hull,
		helm = helm,
		nav = nav,
		drivePrompt = prompt(helm, "DrivePrompt", "Drive", b.name),
		ridePrompt = if nav then prompt(nav, "RidePrompt", "Ride", player.DisplayName .. "'s " .. b.name) else nil,
		tiePrompt = prompt(helm, "TiePrompt", "Tie up", "Boat slip " .. slip),
		movers = makeMovers(hull),
		wake = makeWake(hull),
		motion = { speed = 0, yawRate = 0 },
		yaw = 0,
		lastGood = hull.Position,
		checkTimer = 0,
		emptyFor = 0,
		docked = true,
	}
	-- E (gamepad X) like every other prompt: F and the gamepad's face buttons reel in a fight.
	boat.tiePrompt.Enabled = false
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
		if hum and hum.Health > 0 and not hum.Sit then
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
			if hum and hum.Health > 0 and not hum.Sit then
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

-- Every frame: input to motion to movers, then the half-second checks.
local function step(dt: number)
	for player, boat in boats do
		if boat.docked or not boat.hull.Parent then
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
		local okCrew, crewMsg = BoatLogic.canDrive(boat.id, n)
		if not okCrew then
			if (throttle ~= 0 or steer ~= 0) and crewMsg then
				hint(player, crewMsg)
			end
			throttle, steer = 0, 0
		end
		boat.motion = BoatLogic.step(boat.motion, boat.id, throttle, steer, dt)
		local pos = boat.hull.Position
		local vx, vz = BoatRules.planeVelocity(boat.hull.CFrame.LookVector, boat.motion.speed)
		local dx, dz = BoatRules.drift(boat.id, pos, n)
		boat.movers.lv.PlaneVelocity = Vector2.new(vx + dx, vz + dz)
		boat.yaw += BoatRules.spinY(boat.motion.yawRate) * dt
		boat.movers.ao.CFrame = CFrame.fromOrientation(0, boat.yaw, 0)
		boat.movers.ap.Position = Vector3.new(pos.X, BoatRules.WATER_Y + boat.hull.Size.Y / 2 - 0.4, pos.Z)
		boat.wake.Rate = 40 * math.clamp(math.abs(boat.motion.speed) / BoatData.byId[boat.id].maxSpeed, 0, 1)

		boat.checkTimer += dt
		if boat.checkTimer >= CHECK_EVERY then
			local verdict, at = BoatRules.check(boat.id, boat.lastGood, pos, boat.checkTimer)
			boat.checkTimer = 0
			if verdict == "back" and at then
				local look = boat.hull.CFrame.LookVector
				moveTo(boat, CFrame.lookAt(at, at + Vector3.new(look.X, 0, look.Z)))
				local driver = occupantPlayer(boat.helm)
				if driver then
					hint(driver, "The boat can't go there.")
				end
			elseif verdict == "turn" and at then
				moveTo(boat, CFrame.lookAt(at, at + Vector3.new(0, 0, 1))) -- facing home, south
				local _, msg = BoatLogic.canEnterBlueWater(boat.id)
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

	Remotes.event("ChooseBoat").OnServerEvent:Connect(function(player: Player, boatId: any)
		local data = PlayerData.get(player)
		if not data or type(boatId) ~= "string" or not BoatLogic.owns(data, boatId) or data.boat == boatId then
			return
		end
		local current = boats[player]
		if current and (current.helm.Occupant or (current.nav and current.nav.Occupant)) then
			hint(player, "Tie up your boat before switching.")
			return
		end
		data.boat = boatId
		PlayerData.changed(player)
		spawnFor(player)
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
	RunService.Heartbeat:Connect(step)
end

return BoatService
