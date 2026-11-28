--!strict
-- The boathouse and the sales mooring (leg 3, N4, Config.BOATHOUSE_ON). Where everything goes is
-- in Shared/BoathousePlan (pure, with its spec); this builds it from the art in ServerStorage.Art.
--
-- Run once in Edit; it is saved in the place; safe to run again (it rebuilds Workspace.Boathouse):
--
--   require(game.ServerScriptService.Server.Boathouse).build()
--
-- and to take it all out again (bank reeds and stones it moved aside come back):
--
--   require(game.ServerScriptService.Server.Boathouse).remove()
--
-- What it makes, in Workspace.Boathouse:
--   * the Boathouse art on the east flank of PondPoint, with invisible floor, walls and counter to
--     walk on and bump into (the art itself never collides), a plank apron along its open front
--     and a walkway down its east side to the shore, on piles;
--   * a day fill PointLight in the middle of the shed (N4 review 1);
--   * the Cedar Canoe on the lower rack berth, and lantern glass in the bracket on the front
--     post with a warm PointLight tagged "Lantern" (ClientModules/Lanterns lights it at night);
--   * "Boats" painted on the shop board (Signs), with the BoatShopPrompt that opens the boat
--     shop, and a painted "Your boat" board on the east wall with the BoatChoicePrompt;
--   * the sales mooring off the dock end: per boat a MooringFloat, the boat's hero model afloat
--     beside it, and a PriceBoard with the price painted on (or "Coming soon").
-- Bank dressing (BankKit, Scenery) standing inside any of it is moved to
-- ServerStorage.BoathouseHidden, and remove() puts it back.
--
-- At run time (start, from Main): with the switch off the whole set is stored away in
-- ServerStorage and the bank dressing comes back, so the game plays exactly as before; with it on,
-- the price boards are repainted from the live switches (the canoe says "Coming soon" until
-- CANOE_ON). UNVERIFIED in Studio (11/28/2026): written outside Studio, needs its Edit run.
local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local BoatFeel = require(Shared.BoatFeel)
local Plan = require(Shared.BoathousePlan)
local Signs = require(script.Parent.Signs)

local Boathouse = {}

local NAME = "Boathouse"
local HIDDEN = "BoathouseHidden" -- ServerStorage: bank dressing moved out of the way
local STORED = "BoathouseOff" -- ServerStorage: the whole set while the switch is off

local PLANK = Color3.fromRGB(124, 96, 70)
local PILE = Color3.fromRGB(88, 62, 40)
local LANTERN = { color = Color3.fromRGB(255, 190, 120), range = 18, brightness = 2 } -- WorldBuilder.LANTERN

-- Families by the art's part names (art/README.md): applied only where the composed copy has none.
local FAMILY_OF = { _wood = "WeatheredPlank", _tin = "TinRoofRust", _paint = "PaintedWood" }

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end

-- Invisible and solid: walking and bumping only (no casts, no touches).
local function solid(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	return part(parent, name, size, cf, { Transparency = 1, CanCollide = true, CanQuery = false, CanTouch = false, CastShadow = false })
end

local function weathered(p: BasePart)
	local v = MaterialService:FindFirstChild("WeatheredPlank")
	if v and v:IsA("MaterialVariant") then
		p.Material = v.BaseMaterial
		p.MaterialVariant = v.Name
	end
end

-- A plain copy of ServerStorage.Art.<name>, anchored; nil (and noted) when it is missing.
local function art(name: string, missing: { string }, collide: boolean): Model?
	local folder = ServerStorage:FindFirstChild("Art")
	local src = folder and folder:FindFirstChild(name)
	if not src or not src:IsA("Model") then
		table.insert(missing, name)
		return nil
	end
	local m = src:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("PackageLink") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = collide
			d.CanQuery = false
			d.CanTouch = false
			if d:IsA("MeshPart") and d.MaterialVariant == "" then
				for suffix, family in FAMILY_OF do
					local v = MaterialService:FindFirstChild(family)
					if string.sub(d.Name, -#suffix) == suffix and v and v:IsA("MaterialVariant") then
						d.Material = v.BaseMaterial
						d.MaterialVariant = family
					end
				end
			end
		end
	end
	return m
end

local function inRect(r: Plan.Rect, x: number, z: number, pad: number): boolean
	return x >= r.x1 - pad and x <= r.x2 + pad and z >= r.z1 - pad and z <= r.z2 + pad
end

-- Every rectangle the set stands in (shed with its roof, apron, walkway, mooring stations).
local function rects(): { Plan.Rect }
	local out = table.clone(Plan.footprint())
	table.insert(out, Plan.roofRect())
	for _, s in Plan.mooring() do
		table.insert(out, s.rect)
	end
	return out
end

-- Moves bank dressing (models and loose parts filed in folders under Lake.BankKit and
-- Lake.Scenery) that stands inside the set to ServerStorage.BoathouseHidden. Returns how many.
local function hideDressing(): number
	local lake = workspace:FindFirstChild("Lake")
	if not lake then
		return 0
	end
	local store = ServerStorage:FindFirstChild(HIDDEN) or Instance.new("Folder")
	store.Name = HIDDEN
	store.Parent = ServerStorage
	local all = rects()
	local n = 0
	for _, rootName in { "BankKit", "Scenery" } do
		local root = lake:FindFirstChild(rootName)
		if root then
			for _, d in root:GetDescendants() do
				local parent = d.Parent
				local filed = parent ~= nil and parent:IsA("Folder")
				local pos: Vector3? = nil
				if filed and d:IsA("Model") then
					pos = d:GetPivot().Position
				elseif filed and d:IsA("BasePart") and not d.CanCollide then
					pos = d.Position
				end
				if pos and pos.Y < 8 then
					for _, r in all do
						if inRect(r, pos.X, pos.Z, 1) then
							local was = Instance.new("ObjectValue")
							was.Name = "BoathouseWasIn"
							was.Value = parent
							was.Parent = d
							d.Parent = store
							n += 1
							break
						end
					end
				end
			end
		end
	end
	return n
end

-- Puts the dressing hideDressing moved back where it was. Returns how many.
local function restoreDressing(): number
	local store = ServerStorage:FindFirstChild(HIDDEN)
	if not store then
		return 0
	end
	local n = 0
	for _, d in store:GetChildren() do
		local was = d:FindFirstChild("BoathouseWasIn")
		if was and was:IsA("ObjectValue") and was.Value then
			d.Parent = was.Value
			was:Destroy()
			n += 1
		end
	end
	if #store:GetChildren() == 0 then
		store:Destroy()
	end
	return n
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

-- The painted price on one station's board (rebuilt each time, so it follows the switches).
local function paintPrice(station: Instance, s: Plan.Station)
	local old = station:FindFirstChild("Price")
	if old then
		old:Destroy()
	end
	local sign = Signs.board({
		name = "Price",
		text = s.text,
		width = Plan.PRICE_FACE_SIZE.w,
		height = Plan.PRICE_FACE_SIZE.h,
		cframe = s.face,
		paint = Signs.PAINT.pond,
		bare = true,
	})
	sign.Parent = station
end

local function buildShed(root: Model, missing: { string }): number
	local cf = Plan.cframe()
	local shed = art("Boathouse", missing, false)
	if shed then
		shed.Name = "Shed"
		shed:PivotTo(cf)
		shed.Parent = root
	end

	-- What you walk on and bump into (the art never collides).
	local col = Instance.new("Folder")
	col.Name = "Collision"
	col.Parent = root
	local b = Plan.BODY
	local deck = Plan.DECK_TOP
	local h = 7
	solid(col, "Floor", Vector3.new(b.halfX * 2, deck, b.front + b.back), cf * CFrame.new(0, deck / 2, 0))
	solid(col, "WallWest", Vector3.new(0.5, h, b.front + b.back), cf * CFrame.new(-b.halfX + 0.25, deck + h / 2, 0))
	solid(col, "WallEast", Vector3.new(0.5, h, b.front + b.back), cf * CFrame.new(b.halfX - 0.25, deck + h / 2, 0))
	solid(col, "WallBack", Vector3.new(b.halfX * 2, h, 0.5), cf * CFrame.new(0, deck + h / 2, b.back - 0.25))
	local c = Plan.COUNTER
	solid(col, "Counter", Vector3.new(4.2, c.Y - deck, 0.9), cf * CFrame.new(c.X, (c.Y + deck) / 2, c.Z))

	-- The apron, the walkway and the piles under everything over the water.
	local decks = Instance.new("Folder")
	decks.Name = "Decks"
	decks.Parent = root
	for _, r in { Plan.APRON, Plan.WALKWAY } do
		local p = part(decks, r.name, Vector3.new(r.x2 - r.x1, 0.6, r.z2 - r.z1), CFrame.new((r.x1 + r.x2) / 2, Plan.DECK_Y - 0.3, (r.z1 + r.z2) / 2), {
			Color = PLANK,
			Material = Enum.Material.WoodPlanks,
			CanQuery = true,
			CanTouch = false,
		})
		weathered(p)
	end
	local shedFrontZ = Plan.PIVOT.Z - b.front
	for i, at in Plan.piles() do
		-- Under the shed the pile meets the shed's base; under the planks, the planks' underside.
		local top = if math.abs(at.z - shedFrontZ) < 1 and at.x > Plan.APRON.x1 - 1 and at.x < Plan.PIVOT.X + b.halfX then Plan.PIVOT.Y else Plan.DECK_Y - 0.6
		local len = top - Plan.PILE_BOTTOM
		local p = part(decks, "Pile" .. i, Vector3.new(Plan.PILE, len, Plan.PILE), CFrame.new(at.x, Plan.PILE_BOTTOM + len / 2, at.z), {
			Color = PILE,
			Material = Enum.Material.Wood,
			CanQuery = false,
			CanTouch = false,
		})
		weathered(p)
	end

	-- The canoe on the lower berth.
	local canoe = art(BoatFeel.ART.Canoe.hero, missing, false)
	if canoe then
		canoe.Name = "RackCanoe"
		canoe:PivotTo(Plan.rackCanoe())
		canoe.Parent = root
	end

	-- The lantern glass in the bracket on the front right-hand post, lit at night by the client.
	local glass = part(root, "LanternGlass", Plan.LANTERN_SIZE, CFrame.new(Plan.lantern()), {
		Color = LANTERN.color,
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	local light = Instance.new("PointLight")
	light.Name = "LanternLight"
	light.Color = LANTERN.color
	light.Range = LANTERN.range
	light.Brightness = LANTERN.brightness
	light.Shadows = false
	light.Enabled = false
	light.Parent = glass
	CollectionService:AddTag(light, Signs.LANTERN_TAG)

	-- The day fill (N4 review 1): a soft light in the middle of the shed, always on.
	local fillHost = part(root, "FillLight", Vector3.new(0.2, 0.2, 0.2), CFrame.new(Plan.world(Plan.FILL.at)), {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	local fill = Instance.new("PointLight")
	fill.Name = "DayFill"
	fill.Color = Color3.fromRGB(255, 240, 220)
	fill.Brightness = Plan.FILL.brightness
	fill.Range = Plan.FILL.range
	fill.Shadows = false
	fill.Enabled = true
	fill.Parent = fillHost

	-- The shop board: "Boats" painted on the art's own board, and the prompt there.
	local signs = Instance.new("Folder")
	signs.Name = "PaintedSigns"
	signs.Parent = root
	local size = Plan.SHOP_BOARD_SIZE
	local boats = Signs.board({
		name = "BoatsSign",
		text = "Boats",
		width = size.w,
		height = size.h,
		cframe = Plan.shopBoard(),
		paint = Signs.PAINT.pond,
		bare = true,
	})
	boats.Parent = signs
	local hit = part(root, "ShopBoard", Vector3.new(size.w, size.h, 0.2), Plan.shopBoard(), {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	prompt(hit, "BoatShopPrompt", "Boats", "Boathouse")

	-- "Your boat" on the east wall, over the walkway.
	local csize = Plan.CHOICE_BOARD_SIZE
	local choice = Signs.board({
		name = "YourBoatBoard",
		text = "Your boat",
		width = csize.w,
		height = csize.h,
		thickness = 0.2,
		cframe = Plan.choiceBoard(),
		paint = Signs.PAINT.slips,
	})
	choice.Parent = signs
	prompt(choice.PrimaryPart :: BasePart, "BoatChoicePrompt", "Choose", "Your boat")
	return 1
end

local function buildMooring(root: Model, missing: { string }): number
	local mooring = Instance.new("Model")
	mooring.Name = "Mooring"
	mooring.Parent = root
	local n = 0
	for _, s in Plan.mooring() do
		local station = Instance.new("Model")
		station.Name = "Station_" .. s.id
		station:SetAttribute("BoatId", s.id)
		station.Parent = mooring
		local float = art("MooringFloat", missing, true)
		if float then
			float.Name = "Float"
			float:PivotTo(s.float)
			float.Parent = station
		else
			-- A plain plank float, so the board still has something to stand on.
			local p = part(station, "Float", Vector3.new(Plan.FLOAT_SIZE.X, 0.6, Plan.FLOAT_SIZE.Z), s.float * CFrame.new(0, Plan.FLOAT_DECK - 0.3, 0), {
				Color = PLANK,
				Material = Enum.Material.WoodPlanks,
				CanQuery = false,
				CanTouch = false,
			})
			weathered(p)
		end
		local board = art("PriceBoard", missing, false)
		if board then
			board.Name = "PriceBoard"
			board:PivotTo(s.board)
			board.Parent = station
		end
		local boatName = BoatFeel.modelFor(s.id, nil) -- the hero model (no tier swap for still boats yet)
		local boat = boatName and art(boatName, missing, true)
		if boat then
			boat.Name = "Boat"
			boat:PivotTo(s.boat)
			boat.Parent = station
		end
		paintPrice(station, s)
		n += 1
	end
	return n
end

export type BuildResult = { stations: number, hidden: number, missing: { string } }

-- Builds (or rebuilds) Workspace.Boathouse. Run in Edit, then save the place.
function Boathouse.build(): BuildResult
	Boathouse.remove()
	local root = Instance.new("Model")
	root.Name = NAME
	root.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- small; its prompts must always be there
	local missing: { string } = {}
	buildShed(root, missing)
	local stations = buildMooring(root, missing)
	root.Parent = workspace
	local hidden = hideDressing()
	if #missing > 0 then
		warn("[Boathouse] not in ServerStorage.Art, left out: " .. table.concat(missing, ", "))
	end
	print(string.format("[Boathouse] built: %d mooring stations, %d bank pieces moved aside, %d art missing", stations, hidden, #missing))
	return { stations = stations, hidden = hidden, missing = missing }
end

-- Takes the set out and puts the bank dressing back. Returns how many pieces came back.
function Boathouse.remove(): number
	for _, where in { workspace, ServerStorage } do
		for _, name in { NAME, STORED } do
			local old = where:FindFirstChild(name)
			if old and old:IsA("Model") then
				old:Destroy()
			end
		end
	end
	return restoreDressing()
end

-- Repaints every price board from the live switches. Returns how many.
function Boathouse.paintBoards(root: Instance): number
	local mooring = root:FindFirstChild("Mooring")
	if not mooring then
		return 0
	end
	local n = 0
	for _, s in Plan.mooring() do
		local station = mooring:FindFirstChild("Station_" .. s.id)
		if station then
			paintPrice(station, s)
			n += 1
		end
	end
	return n
end

-- At run time (Main): off, the set goes to ServerStorage and the bank dressing comes back (this
-- server only; nothing is saved); on, the price boards follow the switches.
function Boathouse.start()
	local root = workspace:FindFirstChild(NAME)
	if not (Config.BOATHOUSE_ON and Config.boatsOn()) then
		if root then
			root.Name = STORED
			root.Parent = ServerStorage
			restoreDressing()
		end
		return
	end
	if not root then
		warn("[Boathouse] BOATHOUSE_ON but Workspace.Boathouse is missing: run Boathouse.build() in Edit")
		return
	end
	Boathouse.paintBoards(root)
end

return Boathouse
