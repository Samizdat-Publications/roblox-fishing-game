--!strict
-- How a boat feels, on this screen (leg 3, N4, Config.BOAT_FEEL_ON). The numbers and the pure
-- maths are in Shared/BoatFeel (and its spec); this module draws them.
--
--  * Art: each boat's art model (BoatFeel.ART: hero on the desktop tier, plain on the phone tier,
--    copied by the server to ReplicatedStorage.BoatArt) is drawn over the server's hull, and the
--    gray box is hidden on this screen only (LocalTransparencyModifier). A missing model leaves
--    the gray box showing. The art hangs from one anchored, invisible root moved every frame to
--    the hull's level waterline frame, so it is exactly where the hull is and can never push it.
--  * Trim, lean and bob are drawn on the art only; the server's hull never tilts.
--  * The wake: two soft arms of foam Beams from the stern's quarters that spread at the Kelvin
--    angle, fade in at the stern, widen and fade out, their edges soft (the foam map's faded rows)
--    and their streaks drifting outward (11/28/2026, the creek's white-water method; it was a
--    chain of flat textured parts that read as a hard white bar with square tiles). Soft puffs of
--    wash at the stern; spray at the bow above 60 percent (motor boats); the canoe's is a
--    hairline with two soft swirl rings per paddle stroke. Lighter on the phone tier. Since N4
--    review 1 a point is left every 3 studs travelled, the foam tile is 3 studs, and each beam
--    runs from its older point, so the foam reads as one continuous band.
--  * Lights: red and green at the bow, white at the stern, on from dusk (SignLayout.lanternsOn,
--    as the sign lanterns). No PointLights on the phone tier, the lamps glow only. Each lamp sits
--    in a dark housing; the side lights are soft (0.35, range 4), the stern light 0.8, range 7.
--  * The horn on H (gamepad DPadUp, the touch Horn button): heard here at once, and by everyone
--    else through the BoatHorn remote. A paddle dip at each stroke.
--  * Poses for everyone seated in a boat (each screen poses every boat it draws): paddling in
--    the canoe while it moves (a simple arm pose, the paddle in the lower hand, sides changing
--    each stroke) and holding the rod forward in a seat. Sitting itself is Roblox's sit, with the
--    R15 knees straightened so no leg pokes through the floor.
--  * The camera eases back and up with speed and widens up to 6 degrees, and comes back when slow;
--    a spherecast keeps the moved eye 0.5 short of anything solid behind it.
-- The helm's input is untouched (BoatClient sends it as before), so nothing here adds lag.
-- Written 11/28/2026 in a worktree. UNVERIFIED in Studio.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoatData = require(Shared.BoatData)
local BoatLogic = require(Shared.BoatLogic)
local BoatRules = require(Shared.BoatRules)
local BoatFeel = require(Shared.BoatFeel)
local SignLayout = require(Shared.SignLayout)
local SoundIds = require(Shared.SoundIds)
local SoundSheets = require(Shared.SoundSheets)
local Remotes = require(Shared.Remotes)
local WhiteWater = require(script.Parent.WhiteWater) -- its foam and spray maps only

local BoatFeelClient = {}

local LIGHT_EVERY = 0.5 -- seconds between dusk checks
local WAKE_Y = BoatFeel.WAKE_Y

type Piece = { pos: Vector3, out: Vector3, born: number, speed: number, frac: number }
type Arm = { pieces: { Piece }, atts: { Attachment }, beams: { Beam }, last: Vector3? }
type Stroke = { phase: number, side: number, paddle: Instance?, wasPull: boolean }
type Rig = {
	r15: boolean,
	rs: Motor6D?,
	ls: Motor6D?,
	re: Motor6D?,
	le: Motor6D?,
	rk: Motor6D?, -- R15 knees (nil on R6)
	lk: Motor6D?,
	legs: { BasePart }, -- R15 upper and lower legs and feet, for the floor check
	knee: number?, -- degrees the knees are straightened in this seat
	kneeSeat: Instance?, -- the seat that was worked out for
	kneeBase: { [Motor6D]: CFrame }?, -- each knee's pose before the turn, and what was written
	kneeWrote: { [Motor6D]: CFrame }?,
}
type Feel = {
	model: Model,
	hull: BasePart,
	id: string,
	art: BoatFeel.Art,
	tier: string,
	root: BasePart,
	drawn: Instance?,
	hidden: { [BasePart]: boolean },
	folder: Folder,
	arms: { Arm },
	wakeHolder: BasePart?,
	spray: { ParticleEmitter },
	wash: ParticleEmitter,
	swirl: ParticleEmitter,
	swirlAt: Attachment,
	lamps: { [string]: BasePart },
	housings: { BasePart },
	lights: { PointLight },
	horn: Sound?,
	dip: Sound?,
	trimW: number, -- eased share of top speed for the trim
	lean: number, -- eased degrees
	lastYaw: number?,
	yawRate: number,
	phase: number, -- this boat's bob phase
	strokes: { [Humanoid]: Stroke },
	conns: { RBXScriptConnection },
}

local feels: { [Model]: Feel } = {}
local rigs: { [Model]: Rig } = setmetatable({}, { __mode = "k" }) :: any
local started = false
local lit = false
local camW = 0
local baseFov: number? = nil
local lastHorn: number? = nil
local worldFolder: Folder? = nil

local function tier(): string
	local p = Players.LocalPlayer
	return if p and p:GetAttribute("LookTierActive") == "phone" then "phone" else "desktop"
end

local function asset(id: number?): string
	return if id then "rbxassetid://" .. tostring(id) else ""
end

local function quiet(p: BasePart)
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
end

local function weldTo(root: BasePart, p: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
end

-- A sound from the game's list (its upload, a sheet cue or a stand-in), positional at `parent`.
local function sound(name: string, parent: Instance, volume: number, speed: number?): Sound?
	local r = SoundSheets.resolve(name, SoundIds)
	if not r then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = r.id
	s.Volume = volume * r.volume
	s.PlaybackSpeed = r.speed * (speed or 1)
	if r.start and r.length then
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(r.start, r.start + r.length)
		s:SetAttribute("RegionStart", r.start)
	end
	s.RollOffMinDistance = 10
	s.RollOffMaxDistance = 300
	s.Parent = parent
	return s
end

local function playSound(s: Sound?)
	if s then
		s.TimePosition = (s:GetAttribute("RegionStart") :: number?) or 0
		s:Play()
	end
end

-- The hull's level waterline frame: the hull's heading only, on the waterline under its centre.
local function waterFrame(hull: BasePart): CFrame
	local look = hull.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	local y = hull.Position.Y - (hull.Size.Y / 2 - 0.4) -- BoatService sits the hull 0.4 into the water
	local at = Vector3.new(hull.Position.X, y, hull.Position.Z)
	return CFrame.lookAt(at, at + flat.Unit)
end

local function emitter(parent: Instance, textureId: number?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	if textureId then
		e.Texture = asset(textureId)
	end
	e.Color = ColorSequence.new(WhiteWater.FOAM_COLOR)
	e.LightEmission = 0.1
	e.LightInfluence = 1
	e.Rate = 0
	e.Parent = parent
	return e
end

----------------------------------------------------------------------------------------
-- Building one boat's feel

local function hideGrayBox(f: Feel)
	for _, d in f.model:GetDescendants() do
		if d:IsA("BasePart") then
			f.hidden[d] = true
			d.LocalTransparencyModifier = 1
		elseif d:IsA("ParticleEmitter") and d.Name == "Wake" then
			d.Enabled = false -- the server's old puff; this module draws the wake
		end
	end
end

local function showGrayBox(f: Feel)
	for p in f.hidden do
		if p.Parent then
			p.LocalTransparencyModifier = 0
		end
	end
	table.clear(f.hidden)
	for _, d in f.model:GetDescendants() do
		if d:IsA("ParticleEmitter") and d.Name == "Wake" then
			d.Enabled = true
		end
	end
end

local function buildArt(f: Feel)
	if f.drawn then
		f.drawn:Destroy()
		f.drawn = nil
	end
	local store = ReplicatedStorage:FindFirstChild("BoatArt")
	local name = BoatFeel.modelFor(f.id, f.tier)
	local src = store and name and store:FindFirstChild(name)
	if not src then
		showGrayBox(f)
		return
	end
	local copy = src:Clone()
	local place = f.root.CFrame * CFrame.new(0, f.art.lift, 0) * CFrame.Angles(0, math.rad(f.art.yaw), 0)
	if copy:IsA("Model") then
		copy:PivotTo(place)
	elseif copy:IsA("BasePart") then
		copy.CFrame = place
	end
	local parts: { BasePart } = {}
	if copy:IsA("BasePart") then
		table.insert(parts, copy)
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	for _, p in parts do
		quiet(p)
		weldTo(f.root, p)
	end
	copy.Parent = f.folder
	f.drawn = copy
	hideGrayBox(f)
end

local function buildLights(f: Feel)
	for _, l in f.lights do
		l:Destroy()
	end
	table.clear(f.lights)
	for key, p in f.lamps do
		p:Destroy()
		f.lamps[key] = nil
	end
	for _, h in f.housings do
		h:Destroy()
	end
	table.clear(f.housings)
	local H = BoatFeel.LAMP_HOUSING
	for key, pos in f.art.lights :: any do
		-- The dark cup the lamp sits in: a flat cylinder (axis turned upright), its top at the
		-- ball's middle (N4 review 1).
		local housing = Instance.new("Part")
		housing.Name = "LampHousing_" .. key
		housing.Shape = Enum.PartType.Cylinder
		housing.Size = Vector3.new(H.height, H.diameter, H.diameter)
		housing.Color = H.color
		housing.Material = Enum.Material.SmoothPlastic
		housing.CastShadow = false
		quiet(housing)
		housing.CFrame = f.root.CFrame * CFrame.new(pos - Vector3.new(0, H.height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		weldTo(f.root, housing)
		housing.Parent = f.folder
		table.insert(f.housings, housing)
		local lamp = Instance.new("Part")
		lamp.Name = "Lamp_" .. key
		lamp.Shape = Enum.PartType.Ball
		lamp.Size = Vector3.new(0.16, 0.16, 0.16)
		lamp.Color = BoatFeel.LIGHT_COLORS[key]
		lamp.Material = Enum.Material.SmoothPlastic
		lamp.CastShadow = false
		quiet(lamp)
		lamp.CFrame = f.root.CFrame * CFrame.new(pos)
		weldTo(f.root, lamp)
		lamp.Parent = f.folder
		f.lamps[key] = lamp
		if f.tier ~= "phone" then
			local l = Instance.new("PointLight")
			l.Color = BoatFeel.LIGHT_COLORS[key]
			l.Range = BoatFeel.LIGHT[key].range
			l.Brightness = BoatFeel.LIGHT[key].brightness
			l.Shadows = false
			l.Enabled = false
			l.Parent = lamp
			table.insert(f.lights, l)
		end
	end
end

local function setLit(f: Feel, on: boolean)
	for _, lamp in f.lamps do
		lamp.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		lamp.Transparency = if on then 0 else 0.3
	end
	for _, l in f.lights do
		l.Enabled = on
	end
end

-- One arm is a chain of attachments on an invisible anchored holder at the world origin (so an
-- attachment's CFrame is its world CFrame): the first is the live point at the stern, the rest
-- the points the arm has left. Beam k joins attachment k + 1 (the older point, its Attachment0)
-- to attachment k (N4 review 1: the foam tile then starts at the older end of every beam and,
-- with points WAKE.step apart and TextureLength the same, runs on unbroken).
local function buildWake(f: Feel)
	if f.wakeHolder then
		f.wakeHolder:Destroy()
	end
	table.clear(f.arms)
	local holder = Instance.new("Part")
	holder.Name = "WakeHolder"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new()
	holder.Parent = f.folder
	f.wakeHolder = holder
	local n = BoatFeel.wakePieces(f.id, f.tier, BoatLogic.fastest(f.id))
	local foam = WhiteWater.TEXTURES.foam
	for side = 1, 2 do
		local arm: Arm = { pieces = {}, atts = {}, beams = {} }
		for i = 1, n + 1 do
			local at = Instance.new("Attachment")
			at.Name = "Wake" .. side .. "_" .. i
			at.Parent = holder
			table.insert(arm.atts, at)
		end
		for i = 1, n do
			local beam = Instance.new("Beam")
			beam.Name = "Wake" .. side .. "_" .. i
			beam.Attachment0 = arm.atts[i + 1]
			beam.Attachment1 = arm.atts[i]
			beam.FaceCamera = false
			beam.Segments = 2
			beam.CurveSize0 = 0
			beam.CurveSize1 = 0
			beam.Color = ColorSequence.new(WhiteWater.FOAM_COLOR)
			beam.LightInfluence = 1 -- lit like the water round it, so it never glows at dawn or night
			beam.LightEmission = 0
			beam.ZOffset = BoatFeel.WAKE_ZOFFSET
			if foam then
				beam.Texture = asset(foam)
				beam.TextureMode = Enum.TextureMode.Wrap
				beam.TextureLength = BoatFeel.WAKE_TEX.length
			else
				beam.Texture = ""
			end
			beam.Enabled = false
			beam.Parent = holder
			table.insert(arm.beams, beam)
		end
		table.insert(f.arms, arm)
	end
end

local function buildFx(f: Feel)
	-- Spray at the bow's shoulders (motor boats, over 60 percent).
	for _, e in f.spray do
		(e.Parent :: Instance):Destroy()
	end
	table.clear(f.spray)
	for _, old in { f.wash, f.swirl } do
		if old and old.Parent then
			(old.Parent :: Instance):Destroy() -- a rebuild (the tier changed): its attachment goes too
		end
	end
	if BoatFeel.kindOf(f.id) == "motor" then
		for _, sx in { -1, 1 } do
			local at = Instance.new("Attachment")
			at.Name = "Spray"
			at.Position = f.art.bow + Vector3.new(sx * f.art.halfBeam * 0.6, 0.1, 0.8)
			-- tipped out over the side and a little forward
			at.Orientation = Vector3.new(-20, 0, -sx * 35)
			at.Parent = f.root
			local e = emitter(at, WhiteWater.TEXTURES.spray)
			e.EmissionDirection = Enum.NormalId.Top
			e.Speed = NumberRange.new(3, 6)
			e.SpreadAngle = Vector2.new(20, 20)
			e.Lifetime = NumberRange.new(0.4, 0.8)
			e.Acceleration = Vector3.new(0, -18, 0)
			e.Drag = 1
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.9) })
			e.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.12, 0.5),
				NumberSequenceKeypoint.new(1, 1),
			})
			table.insert(f.spray, e)
		end
	end
	-- Wash: soft puffs churned up at the stern, lying on the water (the spray map: round and soft,
	-- where the foam map's square tiles showed their edges).
	local washAt = Instance.new("Attachment")
	washAt.Name = "Wash"
	washAt.Position = f.art.stern + Vector3.new(0, WAKE_Y, 0.4)
	washAt.Parent = f.root
	local wash = emitter(washAt, WhiteWater.TEXTURES.spray)
	wash.LightEmission = 0
	wash.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	wash.EmissionDirection = Enum.NormalId.Top
	wash.Speed = NumberRange.new(0.05)
	wash.SpreadAngle = Vector2.new(0, 0)
	wash.Lifetime = NumberRange.new(BoatFeel.WASH.life[1], BoatFeel.WASH.life[2])
	wash.Rotation = NumberRange.new(0, 360)
	wash.RotSpeed = NumberRange.new(-30, 30)
	local big = if BoatFeel.kindOf(f.id) == "paddle" then 0.4 else 1
	local W = BoatFeel.WASH
	wash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, W.size[1] * big), NumberSequenceKeypoint.new(1, W.size[2] * big) })
	wash.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), -- fades in: no puff pops on at full strength
		NumberSequenceKeypoint.new(0.2, W.transparency[1]),
		NumberSequenceKeypoint.new(1, W.transparency[2]),
	})
	f.wash = wash
	-- Swirl rings: emitted where a paddle stroke ends.
	local swirlAt = Instance.new("Attachment")
	swirlAt.Name = "Swirl"
	swirlAt.Parent = f.root
	local swirl = emitter(swirlAt, WhiteWater.TEXTURES.spray)
	swirl.LightEmission = 0
	swirl.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	swirl.EmissionDirection = Enum.NormalId.Top
	swirl.Speed = NumberRange.new(0.05)
	swirl.SpreadAngle = Vector2.new(0, 0)
	swirl.Lifetime = NumberRange.new(BoatFeel.SWIRL_LIFE)
	swirl.Rotation = NumberRange.new(0, 360)
	swirl.RotSpeed = NumberRange.new(60, 120)
	swirl.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, BoatFeel.SWIRL_SIZE[1]), NumberSequenceKeypoint.new(1, BoatFeel.SWIRL_SIZE[2]) })
	swirl.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, BoatFeel.SWIRL_TRANSPARENCY[1]),
		NumberSequenceKeypoint.new(1, BoatFeel.SWIRL_TRANSPARENCY[2]),
	})
	swirl.LockedToPart = false
	f.swirl = swirl
	f.swirlAt = swirlAt
end

local function buildSounds(f: Feel)
	if f.horn then
		f.horn:Destroy()
	end
	if f.dip then
		f.dip:Destroy()
	end
	f.horn = sound(BoatFeel.HORN_SOUND, f.root, 1)
	f.dip = if f.art.paddle then sound(BoatFeel.DIP_SOUND, f.root, BoatFeel.DIP_VOLUME, BoatFeel.DIP_SPEED) else nil
end

local function dropStroke(f: Feel, hum: Humanoid)
	local st = f.strokes[hum]
	if st and st.paddle then
		st.paddle:Destroy()
	end
	f.strokes[hum] = nil
	local char = hum.Parent
	local rod = char and char:FindFirstChild("Rod")
	if rod then
		for _, d in rod:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 0
			end
		end
	end
end

local function teardown(model: Model)
	local f = feels[model]
	if not f then
		return
	end
	feels[model] = nil
	for _, c in f.conns do
		c:Disconnect()
	end
	for hum in f.strokes do
		dropStroke(f, hum)
	end
	showGrayBox(f)
	f.folder:Destroy()
end

local function rebuild(f: Feel)
	f.tier = tier()
	buildArt(f)
	buildLights(f)
	setLit(f, lit)
	buildWake(f)
	buildFx(f)
	buildSounds(f)
end

local function setup(model: Model)
	if feels[model] then
		return
	end
	local id = model:GetAttribute("BoatId")
	if type(id) ~= "string" or not BoatFeel.ART[id] or not BoatData.byId[id] then
		return
	end
	local hull = model:WaitForChild("Hull", 10) :: BasePart?
	if not hull or not model.Parent or feels[model] then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = model.Name
	folder.Parent = worldFolder
	local root = Instance.new("Part")
	root.Name = "FeelRoot"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.CFrame = waterFrame(hull)
	root.Parent = folder
	local f: Feel = {
		model = model,
		hull = hull,
		id = id,
		art = BoatFeel.ART[id],
		tier = tier(),
		root = root,
		drawn = nil,
		hidden = {},
		folder = folder,
		arms = {},
		wakeHolder = nil,
		spray = {},
		wash = nil :: any,
		swirl = nil :: any,
		swirlAt = nil :: any,
		lamps = {},
		housings = {},
		lights = {},
		horn = nil,
		dip = nil,
		trimW = 0,
		lean = 0,
		lastYaw = nil,
		yawRate = 0,
		phase = ((model:GetAttribute("OwnerId") :: number?) or 0) % 7,
		strokes = {},
		conns = {},
	}
	feels[model] = f
	rebuild(f)
	table.insert(f.conns, model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			teardown(model)
		end
	end))
	table.insert(f.conns, model.DescendantAdded:Connect(function(d)
		if f.drawn and d:IsA("BasePart") then
			f.hidden[d] = true
			d.LocalTransparencyModifier = 1
		end
	end))
	table.insert(f.conns, hull.AncestryChanged:Connect(function()
		if not hull:IsDescendantOf(workspace) then
			teardown(model) -- streamed out; it is set up again when it comes back
		end
	end))
end

----------------------------------------------------------------------------------------
-- Every frame

local function seatedBoat(): (Feel?, BasePart?)
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if not seat then
		return nil, nil
	end
	local model = seat:FindFirstAncestorOfClass("Model")
	return if model then feels[model] else nil, seat
end

-- Is this boat sitting on a shore (anchored and not at a slip)? Then it does not bob.
local function ashore(f: Feel): boolean
	if not f.hull.Anchored then
		return false
	end
	local pos = f.hull.Position
	for i = 1, #BoatRules.SLIP_ZS do
		local slip = BoatRules.slipCFrame(i, f.id).Position
		if (Vector3.new(pos.X - slip.X, 0, pos.Z - slip.Z)).Magnitude < 3 then
			return false
		end
	end
	return true
end

local function occupants(f: Feel): { [Humanoid]: string }
	local out: { [Humanoid]: string } = {}
	for _, d in f.model:GetChildren() do
		if d:IsA("Seat") or d:IsA("VehicleSeat") then
			local occ = (d :: any).Occupant :: Humanoid?
			if occ then
				out[occ] = d.Name
			end
		end
	end
	return out
end

-- The attachment frame at a point on an arm: X along the arm, and the face normal as the wake's
-- own setting says (BoatFeel.WAKE_BEAM_NORMAL: "Y" points the attachment's Y straight up, so the
-- beam lies flat on the water; N4 review 1, apart from the creek's FOAM_BEAM_NORMAL).
local function wakeFrame(pos: Vector3, along: Vector3): CFrame
	local right, up = BoatFeel.wakeAxes(along)
	return CFrame.fromMatrix(pos, right, up)
end

local function updateWake(f: Feel, frame: CFrame, speed: number, frac: number, dt: number, now: number)
	local w = BoatFeel.WAKE[BoatFeel.kindOf(f.id)]
	local step = BoatFeel.wakeStep(f.id, f.tier)
	local n = #f.arms > 0 and #f.arms[1].beams or 0
	local life = BoatFeel.WAKE[BoatFeel.kindOf(f.id)].life * (if f.tier == "phone" then BoatFeel.WAKE_PHONE.life else 1)
	local y = BoatRules.WATER_Y + WAKE_Y
	-- The foam drifts away from the boat; each beam's Attachment0 is its older point, so minus.
	local texSpeed = -BoatFeel.wakeTextureSpeed(frac)
	for i, arm in f.arms do
		local sx = if i == 1 then -1 else 1
		local st = frame:PointToWorldSpace(BoatFeel.wakeStart(f.art, sx))
		local head = Vector3.new(st.X, y, st.Z)
		-- A point every `step` studs the stern travels (N4 review 1; it was every 0.12 s), laid
		-- exactly `step` apart along the stern's path so each beam shows one whole foam tile.
		if math.abs(frac) >= w.from and arm.last then
			local drops, last = BoatFeel.wakeDrops(arm.last :: Vector3, head, step)
			arm.last = last
			for _, at in drops do
				table.insert(arm.pieces, 1, { pos = at, out = frame.RightVector * sx, born = now, speed = speed, frac = frac })
			end
		else
			arm.last = head -- slow or just started: the next point is a step from here
		end
		while #arm.pieces > n or (#arm.pieces > 0 and now - arm.pieces[#arm.pieces].born >= life) do
			table.remove(arm.pieces)
		end
		-- The points, newest first: the live one at the stern (age 0, so clear), then those left
		-- behind, each spread out at the Kelvin angle since it was left.
		local pts: { Vector3 } = { head }
		local ws: { [number]: number? } = {}
		local ts: { number } = { 1 }
		ws[1] = (BoatFeel.wakePiece(f.id, 0, frac, f.tier))
		for _, pc in arm.pieces do
			local age = now - pc.born
			local wd, tr = BoatFeel.wakePiece(f.id, age, pc.frac, f.tier)
			table.insert(pts, pc.pos + pc.out * BoatFeel.wakeSpread(pc.speed, age))
			ws[#pts] = wd
			table.insert(ts, tr or 1)
		end
		for k, att in arm.atts do
			local p = pts[k]
			if p then
				local after, before = pts[k + 1], pts[k - 1]
				local along = if after then after - p elseif before then p - before else -frame.LookVector
				att.CFrame = wakeFrame(p, along)
			end
		end
		for k, beam in arm.beams do
			-- Attachment0 is the older point (k + 1), Attachment1 the newer (k).
			local wNew, wOld = ws[k], ws[k + 1]
			local a, b = pts[k], pts[k + 1]
			if wNew and wOld and a and b and (a - b).Magnitude > 0.05 then
				beam.Width0 = wOld
				beam.Width1 = wNew
				beam.Transparency = NumberSequence.new(ts[k + 1], ts[k])
				beam.TextureSpeed = texSpeed
				beam.Enabled = true
			else
				beam.Enabled = false
			end
		end
	end
	for _, e in f.spray do
		e.Rate = BoatFeel.sprayRate(f.id, frac, f.tier)
	end
	f.wash.Rate = BoatFeel.washRate(f.id, frac, f.tier)
end

local function swirlsAt(f: Feel, pos: Vector3)
	local frame = f.root.CFrame
	for i = 1, BoatFeel.SWIRLS do
		local p = pos + frame.LookVector * ((i - 1.5) * 0.45)
		f.swirlAt.WorldPosition = Vector3.new(p.X, BoatRules.WATER_Y + WAKE_Y, p.Z)
		f.swirl:Emit(1)
	end
end

local function stepFeel(f: Feel, dt: number, now: number, localHum: Humanoid?)
	if not f.hull.Parent then
		return
	end
	local frame = waterFrame(f.hull)
	local look = frame.LookVector
	local v = f.hull.AssemblyLinearVelocity
	local flatV = Vector3.new(v.X, 0, v.Z)
	local speed = flatV.Magnitude * (if flatV:Dot(look) < 0 then -1 else 1)
	local top = BoatLogic.fastest(f.id)
	local frac = if top > 0 then math.clamp(speed / top, -1, 1) else 0

	-- The heading's turn rate, smoothed (radians a second, negative turning right).
	local yaw = math.atan2(-look.X, -look.Z)
	if f.lastYaw and dt > 0 then
		local d = yaw - f.lastYaw
		d = (d + math.pi) % (2 * math.pi) - math.pi
		f.yawRate += (d / dt - f.yawRate) * (1 - math.exp(-dt / 0.15))
	end
	f.lastYaw = yaw

	-- The turn: the driver on this screen leans at once from their own stick (no round trip);
	-- everyone else's boat leans from how its heading is turning.
	local who = occupants(f)
	local turn = BoatFeel.turnFromYawRate(f.yawRate, BoatData.byId[f.id].turnRate)
	if localHum and who[localHum] == "Helm" then
		local helm = f.model:FindFirstChild("Helm") :: VehicleSeat?
		if helm then
			local steer = helm.SteerFloat
			if steer == 0 then
				steer = helm.Steer
			end
			turn = math.clamp(steer, -1, 1)
		end
	end

	f.trimW = BoatFeel.approach(f.trimW, math.abs(frac), dt, 0.5, 0.7)
	local trim = BoatFeel.trim(f.id, f.trimW)
	f.lean = BoatFeel.approach(f.lean, BoatFeel.lean(f.id, turn, math.abs(frac)), dt, 0.25, 0.25)
	local onShore = ashore(f)
	local blue = BoatRules.inBlueWater(f.hull.Position)
	local bob = if onShore then { heave = 0, pitch = 0, roll = 0 } else BoatFeel.bob(f.id, now, frac, blue, f.phase)

	-- Paddling: everyone seated in a paddled boat strokes while it moves.
	local strokeRoll = 0
	local paddled = f.art.paddle ~= nil
	local rate = if paddled then BoatFeel.strokeRate(speed, top) else 0
	for hum, seatName in who do
		if rate > 0 then
			local st = f.strokes[hum]
			if not st then
				st = { phase = if seatName == "Helm" then 0 else 0.5, side = if seatName == "Helm" then 1 else -1, paddle = nil, wasPull = false }
				f.strokes[hum] = st
			end
			local s = st :: Stroke
			s.phase += rate * dt
			if s.phase >= 1 then
				s.phase -= 1
				s.side = -s.side -- the other side each stroke
				playSound(f.dip)
			end
			local pull = s.phase < BoatFeel.PULL
			if s.wasPull and not pull then
				-- the blade leaves the water: two swirl rings where it was
				local char = hum.Parent
				local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					local side = frame.RightVector * (s.side * (f.art.halfBeam + 0.5))
					swirlsAt(f, hrp.Position + side + look * -0.6)
				end
			end
			s.wasPull = pull
			strokeRoll += BoatFeel.strokeRoll(s.phase, s.side)
		elseif f.strokes[hum] then
			dropStroke(f, hum)
		end
	end
	for hum in f.strokes do
		if not who[hum] then
			dropStroke(f, hum)
		end
	end
	strokeRoll = math.clamp(strokeRoll, -BoatFeel.STROKE_ROLL, BoatFeel.STROKE_ROLL)

	local roll = f.lean + bob.roll + strokeRoll
	local heave = BoatFeel.settle(f.art, bob.heave, trim, bob.pitch, roll)
	local pz = f.art.trimPivotZ
	local pose = CFrame.new(0, heave, 0)
		* CFrame.Angles(0, 0, math.rad(roll))
		* CFrame.Angles(math.rad(bob.pitch), 0, 0)
		* CFrame.new(0, 0, pz)
		* CFrame.Angles(math.rad(trim), 0, 0)
		* CFrame.new(0, 0, -pz)
	f.root.CFrame = frame * pose

	updateWake(f, frame, speed, frac, dt, now)
end

-- The paddles, after the arms are posed: each sits in its paddler's lower hand.
local function placePaddles(f: Feel)
	local p = f.art.paddle
	if not p then
		return
	end
	local frame = f.root.CFrame
	for hum, st in f.strokes do
		local char = hum.Parent :: Model?
		if not char then
			continue
		end
		if not st.paddle then
			local store = ReplicatedStorage:FindFirstChild("BoatArt")
			local src = store and store:FindFirstChild(if f.tier == "phone" then p.plain else p.hero)
			if not src then
				continue
			end
			local copy = src:Clone()
			for _, d in copy:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
				end
			end
			if copy:IsA("BasePart") then
				copy.Anchored = true
				copy.CanCollide = false
				copy.CanQuery = false
				copy.CanTouch = false
			end
			copy.Parent = f.folder
			st.paddle = copy
			-- the rod goes out of sight while paddling
			local rod = char:FindFirstChild("Rod")
			if rod then
				for _, d in rod:GetDescendants() do
					if d:IsA("BasePart") then
						d.LocalTransparencyModifier = 1
					end
				end
			end
		end
		local right = st.side > 0
		local hand = char:FindFirstChild(if right then "RightHand" else "LeftHand") :: BasePart?
		local handPos: Vector3? = nil
		if hand then
			handPos = hand.Position
		else
			local arm = char:FindFirstChild(if right then "Right Arm" else "Left Arm") :: BasePart?
			if arm then
				handPos = (arm.CFrame * CFrame.new(0, -arm.Size.Y / 2, 0)).Position
			end
		end
		if not handPos then
			continue
		end
		local dir = frame:VectorToWorldSpace(BoatFeel.paddleDir(st.phase, st.side))
		local grip = (handPos :: Vector3) + dir * p.hand.Z -- hand.Z is negative: the grip is up the shaft
		local pull = st.phase % 1 < BoatFeel.PULL
		-- in the pull the blade faces aft (it pushes water); in the recovery it lies flat
		local upHint = if pull then frame.LookVector else frame.UpVector
		local cf = CFrame.lookAt(grip, handPos :: Vector3, upHint)
		local paddle = st.paddle :: Instance
		if paddle:IsA("Model") then
			paddle:PivotTo(cf)
		elseif paddle:IsA("BasePart") then
			paddle.CFrame = cf
		end
	end
end

----------------------------------------------------------------------------------------
-- Poses (Motor6D.Transform, set after the Animator each frame, so Roblox's sit stays)

local function rigOf(char: Model): Rig?
	local r = rigs[char]
	if r and r.rs and r.rs.Parent then
		return r
	end
	local function m(partName: string, jointName: string): Motor6D?
		local part = char:FindFirstChild(partName)
		local j = part and part:FindFirstChild(jointName)
		return if j and j:IsA("Motor6D") then j else nil
	end
	local rs = m("RightUpperArm", "RightShoulder")
	if rs then
		local legs: { BasePart } = {}
		for _, n in { "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" } do
			local part = char:FindFirstChild(n)
			if part and part:IsA("BasePart") then
				table.insert(legs, part)
			end
		end
		r = {
			r15 = true,
			rs = rs,
			ls = m("LeftUpperArm", "LeftShoulder"),
			re = m("RightLowerArm", "RightElbow"),
			le = m("LeftLowerArm", "LeftElbow"),
			rk = m("RightLowerLeg", "RightKnee"),
			lk = m("LeftLowerLeg", "LeftKnee"),
			legs = legs,
		}
	else
		local rs6 = m("Torso", "Right Shoulder")
		if not rs6 then
			return nil
		end
		r = { r15 = false, rs = rs6, ls = m("Torso", "Left Shoulder"), re = nil, le = nil, legs = {} }
	end
	rigs[char] = r :: Rig
	return r
end

-- Raise an arm forward by `deg` (R15 shoulders turn about X; R6 shoulders are turned a quarter
-- round, so forward is about Z, opposite ways for the two arms).
local function armForward(r: Rig, motor: Motor6D?, deg: number, isRight: boolean)
	if not motor then
		return
	end
	if r.r15 then
		motor.Transform = CFrame.Angles(math.rad(deg), 0, 0)
	else
		motor.Transform = CFrame.Angles(0, 0, math.rad(if isRight then deg else -deg))
	end
end

local function elbow(motor: Motor6D?, deg: number)
	if motor then
		motor.Transform = CFrame.Angles(math.rad(deg), 0, 0)
	end
end

-- The lowest point of a part (its box's lowest corner), in world y.
local function partLow(p: BasePart): number
	local cf, sz = p.CFrame, p.Size
	local r = cf.RightVector
	local u = cf.UpVector
	local b = -cf.LookVector
	return cf.Position.Y - (math.abs(r.Y) * sz.X + math.abs(u.Y) * sz.Y + math.abs(b.Y) * sz.Z) / 2
end

-- N4 review 1: straighten the R15 knees so no leg sits under the boat's floor. Starts at the pure
-- estimate (BoatFeel.kneeStraighten: from 70 degrees up) for this seat, then, if a leg part is still
-- under the drawn floor (checked on the parts as last drawn), 5 more each frame up to KNEE_MAX.
-- Composed onto the sit animation's own knee pose (the Animator writes it each frame before
-- PreSimulation), so Roblox's sit stays.
local function straightenKnees(f: Feel, hum: Humanoid, seatName: string, r: Rig)
	if not r.r15 or not (r.rk or r.lk) then
		return
	end
	local seatPart = hum.SeatPart
	if r.kneeSeat ~= seatPart or r.knee == nil then
		local top: number
		local listed = f.art.seats and (f.art.seats :: any)[seatName] :: Vector3?
		if listed then
			top = listed.Y
		elseif seatPart then
			top = seatPart.Position.Y + seatPart.Size.Y / 2 - BoatRules.WATER_Y
		else
			top = f.art.floor.y + 0.5
		end
		r.knee = BoatFeel.kneeStraighten(top, f.art.floor.y)
		r.kneeSeat = seatPart
	end
	local floorY = f.root.Position.Y + f.art.floor.y
	for _, leg in r.legs do
		if leg.Parent and partLow(leg) < floorY - 0.02 then
			r.knee = math.min((r.knee :: number) + BoatFeel.KNEE_STEP, BoatFeel.KNEE_MAX)
			break
		end
	end
	local turn = CFrame.Angles(math.rad(r.knee :: number), 0, 0)
	local bases: { [Motor6D]: CFrame } = r.kneeBase or {}
	local wrotes: { [Motor6D]: CFrame } = r.kneeWrote or {}
	r.kneeBase = bases
	r.kneeWrote = wrotes
	for _, k in { r.rk, r.lk } do
		if k then
			-- If the Animator did not write this knee since our last frame (no track on it), start
			-- from the pose it had then, so the turn never piles up frame after frame.
			local base = k.Transform
			local wrote = wrotes[k]
			if wrote and base:FuzzyEq(wrote, 1e-5) then
				base = bases[k] or base
			end
			bases[k] = base
			local out = base * turn
			k.Transform = out
			wrotes[k] = out
		end
	end
end

local function poseAll()
	for _, f in feels do
		for hum, seatName in occupants(f) do
			local char = hum.Parent :: Model?
			if not char then
				continue
			end
			local r = rigOf(char)
			if not r then
				continue
			end
			straightenKnees(f, hum, seatName, r)
			local st = f.strokes[hum]
			if st then
				local lower, upper = BoatFeel.paddleArms(st.phase)
				local right = st.side > 0
				armForward(r, r.rs, if right then lower else upper, true)
				armForward(r, r.ls, if right then upper else lower, false)
				elbow(r.re, 20)
				elbow(r.le, 20)
			elseif char:FindFirstChild("Rod") then
				armForward(r, r.rs, BoatFeel.ROD_ARM, true)
				elbow(r.re, BoatFeel.ROD_ELBOW)
			end
		end
	end
end

----------------------------------------------------------------------------------------
-- Camera

local CAM_RADIUS = 0.4 -- the spherecast's radius
local CAM_STOP = 0.5 -- studs short of a hit the eye stops

-- What the speed camera's spherecast ignores: every character, every boat model and the art drawn
-- over them, and anything that does not collide (reeds, leaves) or is water.
local function camParams(): RaycastParams
	local skip: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	for m, f in feels do
		table.insert(skip, m)
		table.insert(skip, f.folder)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = skip
	params.IgnoreWater = true
	params.RespectCanCollide = true
	return params
end

local function cameraStep(dt: number)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local f = seatedBoat()
	local target = 0
	if f then
		local v = f.hull.AssemblyLinearVelocity
		local top = BoatLogic.fastest(f.id)
		target = if top > 0 then math.clamp(Vector3.new(v.X, 0, v.Z).Magnitude / top, 0, 1) else 0
	end
	camW = BoatFeel.approach(camW, target, dt, BoatFeel.CAMERA.tauUp, BoatFeel.CAMERA.tauDown)
	local custom = cam.CameraType == Enum.CameraType.Custom
	if camW < 0.002 or not custom then
		if baseFov then
			if custom then
				cam.FieldOfView = baseFov
			end
			baseFov = nil
		end
		return
	end
	local back, up, fov = BoatFeel.cameraFor(camW)
	-- Only from behind the player (not in first person, where moving back would show the head).
	if (cam.CFrame.Position - cam.Focus.Position).Magnitude > 2 then
		local eye = cam.CFrame.Position + cam.CFrame.LookVector * -back + Vector3.new(0, up, 0)
		-- N4 review 1: never through a wall or a bank. Spherecast from the Focus to the moved eye
		-- and stop CAM_STOP short of whatever it hits (the boats, the characters and water ignored).
		local from = cam.Focus.Position
		local toEye = eye - from
		if toEye.Magnitude > 1e-3 then
			local hit = workspace:Spherecast(from, CAM_RADIUS, toEye, camParams())
			if hit then
				eye = from + toEye.Unit * math.max(0, hit.Distance - CAM_STOP)
			end
		end
		cam.CFrame = CFrame.new(eye) * cam.CFrame.Rotation
	end
	if not baseFov then
		baseFov = cam.FieldOfView
	end
	cam.FieldOfView = (baseFov :: number) + fov
end

----------------------------------------------------------------------------------------
-- Horn

-- The boat you are at the helm of on this screen, or nil.
function BoatFeelClient.myHelmBoat(): Model?
	local f, seat = seatedBoat()
	if f and seat and seat.Name == "Helm" then
		return f.model
	end
	return nil
end

-- The boat you sit in (any seat), or nil.
function BoatFeelClient.myBoat(): Model?
	local f = seatedBoat()
	return if f then f.model else nil
end

function BoatFeelClient.horn()
	local model = BoatFeelClient.myHelmBoat()
	local f = model and feels[model]
	local now = os.clock()
	if not f or not BoatFeel.hornReady(lastHorn, now) then
		return
	end
	lastHorn = now
	playSound(f.horn)
	Remotes.event("BoatHorn"):FireServer()
end

----------------------------------------------------------------------------------------

local function watchModel(m: Instance)
	if m:IsA("Model") and m:GetAttribute("BoatId") ~= nil then
		task.spawn(setup, m)
	end
end

function BoatFeelClient.start()
	if started then
		return
	end
	started = true
	local wf = Instance.new("Folder")
	wf.Name = "BoatFeel"
	wf.Parent = workspace
	worldFolder = wf

	workspace.ChildAdded:Connect(watchModel)
	for _, m in workspace:GetChildren() do
		watchModel(m)
	end
	-- A boat whose hull streamed out and back in is set up again.
	task.spawn(function()
		while true do
			task.wait(2)
			for _, m in workspace:GetChildren() do
				if m:IsA("Model") and not feels[m] and m:GetAttribute("BoatId") ~= nil and m:FindFirstChild("Hull") then
					task.spawn(setup, m)
				end
			end
		end
	end)

	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("LookTierActive"):Connect(function()
		for _, f in feels do
			for hum in f.strokes do
				dropStroke(f, hum)
			end
			rebuild(f)
		end
	end)

	-- Lights on from dusk, as the sign lanterns.
	lit = SignLayout.lanternsOn(Lighting.ClockTime)
	task.spawn(function()
		while true do
			task.wait(LIGHT_EVERY)
			local on = SignLayout.lanternsOn(Lighting.ClockTime)
			if on ~= lit then
				lit = on
				for _, f in feels do
					setLit(f, on)
				end
			end
		end
	end)

	RunService.PreSimulation:Connect(poseAll)
	RunService:BindToRenderStep("BoatFeel", Enum.RenderPriority.Camera.Value - 1, function(dt: number)
		local now = os.clock()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		for _, f in feels do
			stepFeel(f, dt, now, hum)
			placePaddles(f)
		end
	end)
	RunService:BindToRenderStep("BoatFeelCam", Enum.RenderPriority.Camera.Value + 2, cameraStep)

	-- H is also the bait bench's hook key (Controller binds it through ContextActionService, which
	-- can mark it processed), so only typing in a text box stops the horn.
	UserInputService.InputBegan:Connect(function(input: InputObject, _processed: boolean)
		if UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.H or input.KeyCode == Enum.KeyCode.DPadUp then
			BoatFeelClient.horn()
		end
	end)
	Remotes.event("BoatHorn").OnClientEvent:Connect(function(hull: any)
		if typeof(hull) ~= "Instance" then
			return
		end
		local model = (hull :: Instance):FindFirstAncestorOfClass("Model")
		local f = model and feels[model]
		if f then
			playSound(f.horn)
		end
	end)
end

return BoatFeelClient
