--!strict
-- Gray-box lake. Run build() once in Edit so the geometry is saved in the place;
-- Main only calls it when Workspace.Lake is missing.
--
-- Layout (studs, y up, water surface at y = 0):
--   Lake 220 x 160 centered on the origin. Ground ring top at y = 1.
--   South shore (z = +80) has the dock, spawn, sell stand and shop.
--   Weed bed in the south-west, fallen logs in the south-east, deep hole north of the dock.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
-- The water and zone boxes live in Shared/WaterMap so the client's landing ring uses the
-- same map as the server (L2, 2026-11-26).
local WaterMap = require(Shared:WaitForChild("WaterMap"))
local Signs = require(script.Parent.Signs) -- painted boards (leg 3, N2)

local WorldBuilder = {}

local WATER_SIZE = WaterMap.WATER_SIZE
local WATER_CF = WaterMap.WATER_CF

-- Zone boxes (first match wins, so the dock is listed first), creek stretches included.
local ZONES = WaterMap.ZONES

-- Cedar Creek, west of the lake behind a gated fence: three stretches of water, each its own spot.
-- Rectangles in studs (x1, x2, z1, z2) with the bed height under the water.
local CREEK = WaterMap.CREEK

local COLORS = {
	water = Color3.fromRGB(70, 130, 180),
	floor = Color3.fromRGB(110, 100, 80),
	deep = Color3.fromRGB(40, 50, 70),
	ground = Color3.fromRGB(106, 127, 63),
	path = Color3.fromRGB(196, 170, 120),
	wood = Color3.fromRGB(124, 92, 60),
	darkWood = Color3.fromRGB(88, 62, 40),
	weed = Color3.fromRGB(60, 120, 50),
	stand = Color3.fromRGB(163, 162, 165),
	sell = Color3.fromRGB(230, 180, 60),
	shop = Color3.fromRGB(90, 160, 220),
}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
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

-- Lamp globes as lanterns (leg 3, N1; the plan's wrong-list: Neon only on lantern glass, and only
-- lit): warm Glass by day, and a PointLight tagged "Lantern" that ClientModules/Lanterns lights at
-- night only (it turns the glass Neon while lit). Shadows: only the two dock lanterns cast them
-- (dockLanterns sets the SHADOW_ATTR attribute; ClientModules/Lanterns turns every other
-- lantern's shadows off). N1 review 1 (11/27/2026): range 14 to 24, brightness 1.1 to 3.5,
-- because under Realistic the old pools read as small dim dots.
WorldBuilder.LANTERN = {
	color = Color3.fromRGB(255, 190, 120),
	size = 0.7,
	range = 18, -- 24 until 11/27/2026: at 3.5 and 24 the lantern glow reflected as a hard tan band across the night water (shot 04 test: gone with lanterns off)
	brightness = 2.0,
	shadows = false, -- every lantern but the dock's two
	SHADOW_ATTR = "LanternShadows", -- true on a lantern light that may cast shadows
}

-- Makes one globe a lantern, in place: safe to run again.
local function asLantern(glass: BasePart)
	local L = WorldBuilder.LANTERN
	local c = glass.Position
	glass.Material = Enum.Material.Glass
	glass.Color = L.color
	glass.Size = Vector3.new(L.size, L.size, L.size)
	glass.Position = c
	glass.CanCollide = false
	glass.CastShadow = false
	local light = glass:FindFirstChildOfClass("PointLight")
	if not light then
		light = Instance.new("PointLight")
		light.Parent = glass
	end
	local pl = light :: PointLight
	pl.Color = L.color
	pl.Range = L.range
	pl.Brightness = L.brightness
	pl.Shadows = true
	game:GetService("CollectionService"):AddTag(pl, "Lantern")
end

-- Signs are sized in studs (they shrink with distance like a real board), sit above the
-- roof or wall they belong to (`lift` studs over the adornee's centre), and fade out past
-- SIGN_RANGE so they don't pile up on the far shore (L5a critic, 11/26/2026).
local SIGN_RANGE = 90 -- 140 until 11/27/2026; on top, far signs floated over the far trees (90 still reaches the stands and the pond from the dock end)
local function sign(parent: Instance, adornee: BasePart, text: string, color: Color3, lift: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.new(9, 0, 2.2, 0)
	gui.StudsOffset = Vector3.new(0, lift or 4, 0)
	-- On top (11/27/2026): roofs and trees kept slicing the stall and pond signs (the critic named
	-- it in every run). MaxDistance keeps them from showing through the far side of the map.
	gui.AlwaysOnTop = true
	gui.MaxDistance = SIGN_RANGE
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	label.BackgroundTransparency = 0.3
	label.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35) -- lighter, so darker colours read on the dark pill
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = text
	local corner = Instance.new("UICorner")
	corner.Parent = label
	label.Parent = gui
	gui.Parent = parent
end

local function stand(parent: Instance, name: string, pos: Vector3, color: Color3, title: string, promptName: string, action: string, objectText: string)
	local m = Instance.new("Model")
	m.Name = name
	local counter = part(m, "Counter", Vector3.new(10, 3.5, 4), CFrame.new(pos + Vector3.new(0, 1.75, 0)), COLORS.stand)
	part(m, "PostL", Vector3.new(0.6, 6, 0.6), CFrame.new(pos + Vector3.new(-4.7, 6.5, 1.7)), COLORS.wood)
	part(m, "PostR", Vector3.new(0.6, 6, 0.6), CFrame.new(pos + Vector3.new(4.7, 6.5, 1.7)), COLORS.wood)
	part(m, "Roof", Vector3.new(11, 0.6, 5), CFrame.new(pos + Vector3.new(0, 9.7, 0.5)), color)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = promptName
	prompt.ActionText = action
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = counter
	sign(m, counter, title, color, 10) -- above the roof, clear of the posts
	m.PrimaryPart = counter
	m.Parent = parent
end

function WorldBuilder.zones(): { { name: string, cframe: CFrame, size: Vector3 } }
	return WaterMap.zones()
end

-- Every water box a cast may land in: the lake and the creek's three stretches.
function WorldBuilder.waters(): { { cframe: CFrame, size: Vector3 } }
	return WaterMap.waters()
end

function WorldBuilder.water(): (CFrame, Vector3)
	return WATER_CF, WATER_SIZE
end

-- Cedar Creek: banks, beds and terrain water for each stretch, boulders, pebbles, trees,
-- a path from the lake, and a tall fence with a gate (CreekGate) and its prompt (CreekPrompt).
function WorldBuilder.buildCreek(lake: Model)
	local creek = Instance.new("Model")
	creek.Name = "CedarCreek"
	local terrain = workspace.Terrain
	terrain:FillBlock(CFrame.new(-230, -4, 0), Vector3.new(140, 16, 160), Enum.Material.Air)

	-- Banks (top at y = 1) around the three water rectangles.
	local function bank(x1: number, x2: number, z1: number, z2: number)
		part(creek, "Bank", Vector3.new(x2 - x1, 8, z2 - z1), CFrame.new((x1 + x2) / 2, -3, (z1 + z2) / 2), COLORS.ground, { Material = Enum.Material.Grass })
	end
	bank(-300, -252, -80, 80)
	bank(-208, -160, -80, 80)
	bank(-252, -240, -10, 30)
	bank(-220, -208, -10, 30)
	bank(-252, -236, 30, 80)
	bank(-224, -208, 30, 80)
	bank(-252, -208, -80, -70)

	-- Water and beds.
	for _, c in CREEK do
		local w, d = c.x2 - c.x1, c.z2 - c.z1
		local center = Vector3.new((c.x1 + c.x2) / 2, 0, (c.z1 + c.z2) / 2)
		part(creek, c.name .. "Bed", Vector3.new(w, 1, d), CFrame.new(center.X, c.bed - 0.5, center.Z), if c.name == "Pool" then COLORS.deep else Color3.fromRGB(70, 105, 125), { -- blue-gray so clear shallow water reads as water
			Material = if c.name == "Riffle" then Enum.Material.Pebble else Enum.Material.Slate,
		})
		-- Terrain works in 4 stud cells, so fill whole cells down past the bed (the bed part hides
		-- the water below it). A 1.5 stud fill was too thin to show up at all.
		local depth = math.ceil(-c.bed / 4) * 4
		terrain:FillBlock(CFrame.new(center.X, -depth / 2, center.Z), Vector3.new(w, depth, d), Enum.Material.Water)
	end

	-- Boulders in the rocky run, pebbles in the riffle.
	local stone = Color3.fromRGB(125, 125, 120)
	for i, b in { { -233, -2, 3.5 }, { -226, 8, 3 }, { -236, 18, 2.6 }, { -228, 25, 3.2 }, { -231, 0, 2 } } do
		local rock = part(creek, "Boulder" .. i, Vector3.new(b[3] * 2, b[3] * 1.6, b[3] * 2), CFrame.new(b[1], -1.5, b[2]), stone, { Material = Enum.Material.Rock })
		rock.Shape = Enum.PartType.Ball
	end
	local rng = Random.new(5)
	for i = 1, 14 do
		local r = rng:NextNumber(0.6, 1.2)
		local pebble = part(creek, "Pebble" .. i, Vector3.new(r * 2, r * 2, r * 2), CFrame.new(rng:NextNumber(-235, -225), -1.6 + r * 0.6, rng:NextNumber(32, 73)), stone, {
			Material = Enum.Material.Rock,
		})
		pebble.Shape = Enum.PartType.Ball
	end

	-- A few gray-box pines along the banks.
	for i, t in { { -265, 40 }, { -270, -20 }, { -262, -55 }, { -195, 55 }, { -190, -40 }, { -285, 10 }, { -200, 10 }, { -275, 65 } } do
		part(creek, "Trunk" .. i, Vector3.new(1.4, 8, 1.4), CFrame.new(t[1], 5, t[2]), COLORS.darkWood, { Material = Enum.Material.Wood })
		local crown = part(creek, "Crown" .. i, Vector3.new(7, 9, 7), CFrame.new(t[1], 12, t[2]), Color3.fromRGB(45, 95, 50), { Material = Enum.Material.Grass })
		crown.Shape = Enum.PartType.Ball
	end

	-- Path from the lake's west path to the creek, and a bank path inside.
	part(creek, "PathToCreek", Vector3.new(90, 0.2, 6), CFrame.new(-163, 1.1, 0), COLORS.path, { Material = Enum.Material.Sand })
	part(creek, "BankPath", Vector3.new(6, 0.2, 140), CFrame.new(-203, 1.1, 0), COLORS.path, { Material = Enum.Material.Sand })

	-- Fence across the whole west side, with the gate on the path.
	part(creek, "FenceSouth", Vector3.new(1, 8, 76), CFrame.new(-162, 5, 42), COLORS.wood, { Material = Enum.Material.WoodPlanks })
	part(creek, "FenceNorth", Vector3.new(1, 8, 76), CFrame.new(-162, 5, -42), COLORS.wood, { Material = Enum.Material.WoodPlanks })
	local gate = part(creek, "CreekGate", Vector3.new(1, 8, 8), CFrame.new(-162, 5, 0), Color3.fromRGB(150, 60, 45), { Material = Enum.Material.WoodPlanks })
	local post = part(creek, "GatePost", Vector3.new(1.2, 4, 1.2), CFrame.new(-158, 3, 5.5), COLORS.darkWood)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CreekPrompt"
	prompt.ActionText = "Buy Creek Pass"
	prompt.ObjectText = string.format("Cedar Creek, %d coins", Config.CREEK_PASS_PRICE)
	prompt.HoldDuration = 1 -- a hold, so nobody buys it by accident
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = post
	sign(creek, gate, "Cedar Creek", Color3.fromRGB(140, 220, 160), 8.6) -- above the gate arch's beam (Scenery, L5c)
	local lampBulb = part(creek, "GateLamp", Vector3.new(1.2, 1.2, 1.2), CFrame.new(-158, 9, -5.5), Color3.fromRGB(255, 230, 170), {
		CanCollide = false,
	})
	lampBulb.Shape = Enum.PartType.Ball
	part(creek, "GateLampPost", Vector3.new(0.5, 8, 0.5), CFrame.new(-158, 5, -5.5), COLORS.darkWood)
	asLantern(lampBulb) -- was a white Neon globe lit day and night (range 26, brightness 1.6)

	-- Invisible boxes marking the creek's water, used by casts.
	local waterFolder = Instance.new("Folder")
	waterFolder.Name = "CreekWater"
	for _, c in CREEK do
		local w = part(waterFolder, c.name .. "Water", Vector3.new(c.x2 - c.x1, 1, c.z2 - c.z1), CFrame.new((c.x1 + c.x2) / 2, -0.5, (c.z1 + c.z2) / 2), COLORS.water, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
		w:SetAttribute("IsWater", true)
	end
	waterFolder.Parent = creek
	creek.Parent = lake
end

function WorldBuilder.build(): Model
	local old = workspace:FindFirstChild("Lake")
	if old then
		old:Destroy()
	end
	-- Clear the template's baseplate and any spawn pads so everyone starts on the dock.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") then
			d:Destroy()
		end
	end

	local lake = Instance.new("Model")
	lake.Name = "Lake"
	lake.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- small; always fully loaded

	-- Water: terrain water so characters can swim out; an invisible part marks the bounds.
	local terrain = workspace.Terrain
	terrain:FillBlock(CFrame.new(0, -4, 0), Vector3.new(240, 16, 180), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(0, -3.5, 0), Vector3.new(220, 7, 160), Enum.Material.Water)
	terrain.WaterColor = COLORS.water
	terrain.WaterTransparency = 0.6
	terrain.WaterWaveSize = 0.15
	terrain.WaterWaveSpeed = 6
	terrain.WaterReflectance = 0.45
	local water = part(lake, "Water", WATER_SIZE, WATER_CF, COLORS.water, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	water:SetAttribute("IsWater", true)
	part(lake, "Floor", Vector3.new(220, 1, 160), CFrame.new(0, -6.5, 0), COLORS.floor)
	part(lake, "DeepHoleFloor", Vector3.new(50, 1, 40), CFrame.new(0, -6.0, -25), COLORS.deep, { Material = Enum.Material.Slate })

	-- Ground ring (top at y = 1), big enough to walk around the lake
	local g = lake
	part(g, "GroundSouth", Vector3.new(320, 8, 60), CFrame.new(0, -3, 110), COLORS.ground, { Material = Enum.Material.Grass })
	part(g, "GroundNorth", Vector3.new(320, 8, 60), CFrame.new(0, -3, -110), COLORS.ground, { Material = Enum.Material.Grass })
	part(g, "GroundWest", Vector3.new(50, 8, 160), CFrame.new(-135, -3, 0), COLORS.ground, { Material = Enum.Material.Grass })
	part(g, "GroundEast", Vector3.new(50, 8, 160), CFrame.new(135, -3, 0), COLORS.ground, { Material = Enum.Material.Grass })

	-- Shore path loop just off the water's edge
	part(g, "PathSouth", Vector3.new(236, 0.2, 6), CFrame.new(0, 1.1, 85), COLORS.path, { Material = Enum.Material.Sand })
	part(g, "PathNorth", Vector3.new(236, 0.2, 6), CFrame.new(0, 1.1, -85), COLORS.path, { Material = Enum.Material.Sand })
	part(g, "PathWest", Vector3.new(6, 0.2, 164), CFrame.new(-115, 1.1, 0), COLORS.path, { Material = Enum.Material.Sand })
	part(g, "PathEast", Vector3.new(6, 0.2, 164), CFrame.new(115, 1.1, 0), COLORS.path, { Material = Enum.Material.Sand })

	-- Dock: from the south shore out to z = 35
	local dock = Instance.new("Model")
	dock.Name = "Dock"
	part(dock, "Deck", Vector3.new(8, 0.6, 46), CFrame.new(0, 1.2, 58), COLORS.wood, { Material = Enum.Material.WoodPlanks })
	part(dock, "EndDeck", Vector3.new(16, 0.6, 8), CFrame.new(0, 1.2, 38), COLORS.wood, { Material = Enum.Material.WoodPlanks })
	for _, z in { 40, 50, 60, 70, 78 } do
		part(dock, "Post", Vector3.new(0.8, 9, 0.8), CFrame.new(-3.6, -3, z), COLORS.darkWood)
		part(dock, "Post", Vector3.new(0.8, 9, 0.8), CFrame.new(3.6, -3, z), COLORS.darkWood)
	end
	dock.Parent = lake

	-- Weed bed: green stalks poking out of the water
	local weeds = Instance.new("Model")
	weeds.Name = "WeedBed"
	local rng = Random.new(11)
	for _ = 1, 70 do
		local x = -78 + rng:NextNumber(-25, 25)
		local z = 38 + rng:NextNumber(-28, 28)
		local h = rng:NextNumber(4, 8)
		part(weeds, "Weed", Vector3.new(0.6, h, 0.6), CFrame.new(x, -6 + h / 2 + 0.5, z) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), 0, rng:NextNumber(-0.2, 0.2)), COLORS.weed, {
			CanCollide = false,
			Material = Enum.Material.Grass,
		})
	end
	weeds.Parent = lake

	-- Fallen logs: half sunk, angled out from the east-south shore
	local logs = Instance.new("Model")
	logs.Name = "Logs"
	local logSpots = {
		{ Vector3.new(70, -0.4, 55), 0.5 },
		{ Vector3.new(90, -0.8, 40), -0.3 },
		{ Vector3.new(62, -1.2, 28), 1.1 },
		{ Vector3.new(96, -0.6, 62), 0.9 },
		{ Vector3.new(80, -1.6, 20), -0.8 },
	}
	for i, s in logSpots do
		local p = part(logs, "Log" .. i, Vector3.new(22, 2.2, 2.2), CFrame.new(s[1]) * CFrame.Angles(0, s[2], 0.12), COLORS.darkWood, { Material = Enum.Material.Wood })
		p.Shape = Enum.PartType.Cylinder
	end
	logs.Parent = lake

	-- Deep hole marker buoy
	local buoy = part(lake, "DeepHoleBuoy", Vector3.new(1.6, 2.4, 1.6), CFrame.new(0, 0.6, -25), Color3.fromRGB(220, 60, 50), { CanCollide = false })
	buoy.Shape = Enum.PartType.Cylinder
	buoy.CFrame = CFrame.new(0, 0.6, -25) * CFrame.Angles(0, 0, math.rad(90))

	-- Zones (invisible, used by the server to name where a bobber landed)
	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	for _, z in ZONES do
		part(zonesFolder, z.name, z.size, CFrame.new(z.center), Color3.new(1, 1, 1), {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
	end
	zonesFolder.Parent = lake

	-- Stands on the south shore
	stand(lake, "SellStand", Vector3.new(-18, 1, 96), COLORS.sell, "Sell Fish", "SellPrompt", "Sell all fish", "Fish Buyer")
	stand(lake, "ShopStand", Vector3.new(18, 1, 96), COLORS.shop, "Bait and Tackle", "ShopPrompt", "Open shop", "Bait and Tackle")

	-- Home pond on the grass east of the stands: a stone rim, clear water, a sign and a prompt.
	local pond = Instance.new("Model")
	pond.Name = "HomePond"
	local pc = Vector3.new(50, 1, 106)
	local pw, pd = 22, 14
	part(pond, "Bottom", Vector3.new(pw, 0.2, pd), CFrame.new(pc + Vector3.new(0, 0.1, 0)), Color3.fromRGB(60, 70, 60), { Material = Enum.Material.Mud })
	local pondWater = part(pond, "Water", Vector3.new(pw, 1.1, pd), CFrame.new(pc + Vector3.new(0, 0.75, 0)), Color3.fromRGB(80, 150, 190), {
		Transparency = 0.55,
		CanCollide = false,
		CanQuery = false,
		Material = Enum.Material.Glass,
	})
	pondWater:SetAttribute("IsPondWater", true)
	local stone = Color3.fromRGB(140, 140, 135)
	part(pond, "RimN", Vector3.new(pw + 2, 1.6, 1), CFrame.new(pc + Vector3.new(0, 0.8, -pd / 2 - 0.5)), stone, { Material = Enum.Material.Cobblestone })
	part(pond, "RimS", Vector3.new(pw + 2, 1.6, 1), CFrame.new(pc + Vector3.new(0, 0.8, pd / 2 + 0.5)), stone, { Material = Enum.Material.Cobblestone })
	part(pond, "RimW", Vector3.new(1, 1.6, pd), CFrame.new(pc + Vector3.new(-pw / 2 - 0.5, 0.8, 0)), stone, { Material = Enum.Material.Cobblestone })
	part(pond, "RimE", Vector3.new(1, 1.6, pd), CFrame.new(pc + Vector3.new(pw / 2 + 0.5, 0.8, 0)), stone, { Material = Enum.Material.Cobblestone })
	local post = part(pond, "SignPost", Vector3.new(1.2, 3.5, 1.2), CFrame.new(pc + Vector3.new(0, 1.75, -pd / 2 - 2)), COLORS.wood)
	local pondPrompt = Instance.new("ProximityPrompt")
	pondPrompt.Name = "PondPrompt"
	pondPrompt.ActionText = "Check pond"
	pondPrompt.ObjectText = "Your Pond"
	pondPrompt.HoldDuration = 0
	pondPrompt.MaxActivationDistance = 12
	pondPrompt.RequiresLineOfSight = false
	pondPrompt.KeyboardKeyCode = Enum.KeyCode.E
	pondPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	pondPrompt.Parent = post
	sign(pond, post, "Your Pond", Color3.fromRGB(120, 210, 200))
	pond.Parent = lake

	WorldBuilder.buildCreek(lake)

	-- Spawn on the shore end of the dock, facing the water
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "DockSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.CFrame = CFrame.new(0, 1.7, 74) * CFrame.Angles(0, 0, 0)
	spawn.Color = COLORS.wood
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Transparency = 0
	spawn.Duration = 0
	spawn.Neutral = true
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = lake

	-- Lamp posts so the dock and stands are easy to find at night.
	local lamps = Instance.new("Model")
	lamps.Name = "Lamps"
	for i, pos in { Vector3.new(7.5, 1.5, 36), Vector3.new(-7.5, 1.5, 36), Vector3.new(-24, 1, 93), Vector3.new(24, 1, 93) } do
		part(lamps, "Post" .. i, Vector3.new(0.5, 8, 0.5), CFrame.new(pos + Vector3.new(0, 4, 0)), COLORS.darkWood)
		local bulb = part(lamps, "Bulb" .. i, Vector3.new(1.2, 1.2, 1.2), CFrame.new(pos + Vector3.new(0, 8.4, 0)), Color3.fromRGB(255, 230, 170), {
			CanCollide = false,
		})
		bulb.Shape = Enum.PartType.Ball
		-- The light was 28 at 1.6 (a hard cyan disc at night), then 18 at 1.1 (a green wash over the
		-- water in front of the dock), then 11 at 1 lit day and night; N1: a lantern, night only.
		asLantern(bulb)
	end
	lamps.Parent = lake

	WorldBuilder.dress(lake)
	if Config.PAINTED_SIGNS_ON then
		WorldBuilder.paintSigns(lake)
	end
	lake.Parent = workspace
	return lake
end

-- Our own models (art/README.md), laid over the gray box. They live in ServerStorage.Art
-- (uploaded from art/models/roblox/). The gray-box parts stay as invisible collision and
-- cast-check shapes, so walking, casting, prompts and zones work exactly as before; the
-- models never collide, never block a raycast and never fire touches.
--
-- Each place is one of:
--   { cframe = CFrame }                    the model's pivot (bottom centre) goes there
--   { over = "Path.To.Part", anchor = "center" | "bottom", fit = true? }
--       centred on that gray-box part (or standing on its bottom face), turned like it,
--       and with fit, scaled so the model is as wide as the part; with girth, scaled so it
--       is as deep (Z) as the part instead, for a long kit model on a long gray box.
-- An entry's optional `variant` puts one of our MaterialVariants on every MeshPart of each
-- copy (base material and variant name), when MaterialService has that variant.
type Place = { cframe: CFrame?, over: string?, anchor: string?, fit: boolean?, girth: boolean? }
type ArtVariant = { material: Enum.Material, name: string }
type ArtEntry = { name: string, places: { Place }, hide: { string }?, ghost: { string }?, variant: ArtVariant? }

local function at(x: number, y: number, z: number, yaw: number?): Place
	return { cframe = CFrame.new(x, y, z) * CFrame.Angles(0, yaw or 0, 0) }
end

-- count places spread over a rectangle, each with a random turn (same every rebuild).
local function scatter(count: number, seed: number, cx: number, cz: number, hx: number, hz: number, y: number): { Place }
	local rng = Random.new(seed)
	local out = {}
	for _ = 1, count do
		table.insert(out, at(cx + rng:NextNumber(-hx, hx), y, cz + rng:NextNumber(-hz, hz), rng:NextNumber(0, 2 * math.pi)))
	end
	return out
end

local function over(paths: { string }, anchor: string, fit: boolean?, girth: boolean?): { Place }
	local out = {}
	for _, path in paths do
		table.insert(out, { over = path, anchor = anchor, fit = fit, girth = girth })
	end
	return out
end

-- { "CedarCreek.Trunk1", "CedarCreek.Trunk3", ... }
local function paths(prefix: string, numbers: { number }): { string }
	local out = {}
	for _, n in numbers do
		table.insert(out, prefix .. n)
	end
	return out
end

local function join(a: { string }, b: { string }): { string }
	local out = table.clone(a)
	for _, v in b do
		table.insert(out, v)
	end
	return out
end

local TALL_PINES = { 1, 3, 5, 7 }
local SHORT_PINES = { 2, 4, 6, 8 }
local PEBBLES = paths("CedarCreek.Pebble", { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 })
local BIG_BOULDERS = paths("CedarCreek.Boulder", { 1, 2, 4 })
local SMALL_BOULDERS = paths("CedarCreek.Boulder", { 3, 5 })

local ART: { ArtEntry } = {
	{
		name = "Dock",
		places = { { cframe = CFrame.new(0, -7.5, 57.65) * CFrame.Angles(0, math.pi, 0) } }, -- deck top at y = 1.5
		hide = { "Dock", "Lamps.Post1", "Lamps.Post2", "Lamps.Bulb1", "Lamps.Bulb2", "DockSpawn" },
		-- The spawn pad sits 0.4 above the deck; players drop onto the new deck instead.
		ghost = { "DockSpawn" },
	},
	{
		name = "BaitShopStand",
		places = { at(18, 1, 96.5) }, -- open front faces the lake
		hide = { "ShopStand.Counter", "ShopStand.PostL", "ShopStand.PostR", "ShopStand.Roof" },
	},
	{
		name = "FishBuyerStand",
		places = { at(-18, 1, 96.5) },
		hide = { "SellStand.Counter", "SellStand.PostL", "SellStand.PostR", "SellStand.Roof" },
	},
	{
		name = "PondRim",
		places = { at(50, 1, 106) },
		hide = { "HomePond.RimN", "HomePond.RimS", "HomePond.RimW", "HomePond.RimE" },
	},
	-- The fallen logs stay full length: Log1b to Log3b (11/27/2026: torn, water-soaked ends in place
	-- of the flat tan caps; the old Log1 to Log3 stay in ServerStorage.Art as the revert), in the bark family through
	-- MaterialKit.skinArt): the kit driftwood would be about 8.5 studs inside 22 stud gray boxes,
	-- and the snags are the whole box, so casts would snag on open water. A proper long fallen
	-- log model is a follow-up (N3 brings a mossy log). The driftwood option stays in `girth`.
	{ name = "Log1b", places = over({ "Logs.Log1", "Logs.Log4" }, "center"), hide = { "Logs.Log1", "Logs.Log4" }, variant = { material = Enum.Material.Wood, name = "Bark" } },
	{ name = "Log2b", places = over({ "Logs.Log2", "Logs.Log5" }, "center"), hide = { "Logs.Log2", "Logs.Log5" }, variant = { material = Enum.Material.Wood, name = "Bark" } },
	{ name = "Log3b", places = over({ "Logs.Log3" }, "center"), hide = { "Logs.Log3" }, variant = { material = Enum.Material.Wood, name = "Bark" } },
	-- Floats in the deep hole; painted wood family (N1 review 2: it read as stock plastic).
	{ name = "Buoy", places = { at(0, -0.6, -25) }, hide = { "DeepHoleBuoy" }, variant = { material = Enum.Material.WoodPlanks, name = "PaintedWood" } },
	-- Reed clumps replace the weed sticks; lily pads lie on the water round the bed.
	{ name = "Reeds", places = scatter(18, 31, -78, 38, 24, 27, -1.2), hide = { "WeedBed" } },
	{ name = "LilyPads", places = scatter(7, 32, -70, 38, 30, 30, -0.35) },
	-- Creek: tall and short pines on the gray-box trunks (they replace trunk and crown),
	-- and rocks fitted to each stone. The boulders stay solid, so wading still bumps into them.
	{
		name = "PineTall",
		places = over(paths("CedarCreek.Trunk", TALL_PINES), "bottom"),
		hide = join(paths("CedarCreek.Trunk", TALL_PINES), paths("CedarCreek.Crown", TALL_PINES)),
	},
	{
		name = "PineShort",
		places = over(paths("CedarCreek.Trunk", SHORT_PINES), "bottom"),
		hide = join(paths("CedarCreek.Trunk", SHORT_PINES), paths("CedarCreek.Crown", SHORT_PINES)),
	},
	{ name = "RockLarge", places = over(BIG_BOULDERS, "center", true), hide = BIG_BOULDERS },
	{ name = "RockMedium", places = over(SMALL_BOULDERS, "center", true), hide = SMALL_BOULDERS },
	{ name = "RockSmall", places = over(PEBBLES, "center", true), hide = PEBBLES },
	-- Leafy trees on the lake shore, clear of the paths, stands and pond.
	{
		name = "LeafyTree",
		places = { at(-62, 1, 104, 0.4), at(-95, 1, 96, 2.1), at(88, 1, 100, 1.2), at(122, 1, 30, 3.0), at(-124, 1, -20, 0.8), at(70, 1, -96, 2.6), at(-50, 1, -98, 4.0) },
	},
}

-- "Lamps.Post1" -> lake.Lamps.Post1, or nil.
local function find(root: Instance, path: string): Instance?
	local node: Instance? = root
	for _, step in string.split(path, ".") do
		node = node and node:FindFirstChild(step)
	end
	return node
end

local function hideParts(inst: Instance)
	local list = inst:GetDescendants()
	table.insert(list, inst)
	for _, d in list do
		if d:IsA("BasePart") then
			d.Transparency = 1 -- lights inside (the dock-end bulbs) keep shining
		elseif d:IsA("Decal") or d:IsA("Texture") then
			d.Transparency = 1
		end
	end
end

local function prepare(source: Model): Model
	local m = source:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("PackageLink") then
			d:Destroy() -- a plain copy in the world; the package stays in ServerStorage
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	return m
end

-- Puts one copy where the place says. Returns false if its gray-box part is missing.
local function put(m: Model, place: Place, lake: Model): boolean
	if place.cframe then
		m:PivotTo(place.cframe)
		return true
	end
	local part = find(lake, place.over :: string)
	if not (part and part:IsA("BasePart")) then
		return false
	end
	local main = m:FindFirstChildWhichIsA("MeshPart", true)
	if place.girth and main then
		m:ScaleTo(m:GetScale() * part.Size.Z / main.Size.Z)
	elseif place.fit and main then
		m:ScaleTo(m:GetScale() * part.Size.X / main.Size.X)
	end
	local height = if main then main.Size.Y else 0
	if place.anchor == "bottom" then
		-- Stand it upright on the part's bottom face (the trunks are upright).
		m:PivotTo(CFrame.new(part.Position - Vector3.new(0, part.Size.Y / 2, 0)) * part.CFrame.Rotation)
	else
		-- Centre it on the part, turned like the part (the pivot is the model's bottom centre).
		m:PivotTo(part.CFrame * CFrame.new(0, -height / 2, 0))
	end
	return true
end

-- Places every model found in ServerStorage.Art and hides the gray box it replaces.
-- Safe to run again: it rebuilds Lake.Art from scratch. Returns how many copies were placed.
function WorldBuilder.dress(lake: Model): number
	local art = game:GetService("ServerStorage"):FindFirstChild("Art")
	local folder = lake:FindFirstChild("Art")
	if folder then
		folder:Destroy()
	end
	if not art then
		return 0
	end
	folder = Instance.new("Folder")
	folder.Name = "Art"
	local placed = 0
	for _, entry in ART do
		local source = art:FindFirstChild(entry.name)
		local v = entry.variant
		local hasVariant = v ~= nil and game:GetService("MaterialService"):FindFirstChild(v.name) ~= nil
		if source and source:IsA("Model") then
			for _, place in entry.places do
				local m = prepare(source)
				if v and hasVariant then
					for _, d in m:GetDescendants() do
						if d:IsA("MeshPart") and d.Material ~= Enum.Material.Neon then
							d.Material = v.material
							d.MaterialVariant = v.name
						end
					end
				end
				if put(m, place, lake) then
					m.Parent = folder
					placed += 1
				else
					m:Destroy()
				end
			end
			for _, path in entry.hide or {} do
				local node = find(lake, path)
				if node then
					hideParts(node)
				end
			end
			for _, path in entry.ghost or {} do
				local node = find(lake, path)
				if node and node:IsA("BasePart") then
					node.CanCollide = false
				end
			end
		end
	end
	folder.Parent = lake
	WorldBuilder.dockLanterns(lake)
	return placed
end

-- The dock's two lanterns at the lake end (leg 3, N0). The hero dock (DockHero, a SurfaceAppearance
-- set) bakes its lantern frames but not the glow, so the glass is a small Neon part with a warm
-- light that casts shadows (the only lanterns that do: SHADOW_ATTR). Range and brightness come
-- from LANTERN. Tagged "Lantern" so the client lights them only at night
-- (ClientModules/Lanterns). Rebuilt on every dress.
function WorldBuilder.dockLanterns(lake: Model)
	local L = WorldBuilder.LANTERN
	local old = lake:FindFirstChild("DockLanterns")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "DockLanterns"
	for i, x in { 7.5, -7.5 } do
		local glass = Instance.new("Part")
		glass.Name = "Glass" .. i
		glass.Anchored = true
		glass.CanCollide = false
		glass.CanQuery = false
		glass.CanTouch = false
		glass.CastShadow = false
		glass.Size = Vector3.new(0.92, 0.98, 0.92)
		glass.CFrame = CFrame.new(x, 9.7, 36.3)
		glass.Material = Enum.Material.Neon
		glass.Color = L.color
		local light = Instance.new("PointLight")
		light.Color = L.color
		light.Range = L.range
		light.Brightness = L.brightness
		light.Shadows = true
		light:SetAttribute(L.SHADOW_ATTR, true)
		light.Parent = glass
		game:GetService("CollectionService"):AddTag(light, "Lantern")
		glass.Parent = folder
	end
	folder.Parent = lake
end

-- Turns the saved world's white Neon lamp globes into lanterns, in place (N1; safe to run again):
-- the shore lamps (Lamps.Bulb1 to 4), the creek gate lamp and the creek pool's lantern (Scenery).
-- Returns how many globes it converted.
--   require(game.ServerScriptService.Server.WorldBuilder).lanternLamps(workspace.Lake)
function WorldBuilder.lanternLamps(lake: Model): number
	local globes: { BasePart } = {}
	local lamps = lake:FindFirstChild("Lamps")
	for _, p in (if lamps then lamps:GetChildren() else {}) do
		if p:IsA("BasePart") and string.match(p.Name, "^Bulb%d+$") then
			table.insert(globes, p)
		end
	end
	for _, path in { "CedarCreek.GateLamp", "Scenery.PoolLantern.Bulb" } do
		local node = find(lake, path)
		if node and node:IsA("BasePart") then
			table.insert(globes, node)
		end
	end
	local n = 0
	for _, g in globes do
		if g.Transparency >= 1 then
			-- Hidden by the art dress (the old dock-end bulbs under the hero dock, whose own
			-- DockLanterns light the spot): switch the light off rather than stack shadows.
			for _, l in g:GetDescendants() do
				if l:IsA("Light") then
					l.Enabled = false
				end
			end
		else
			asLantern(g)
			n += 1
		end
	end
	return n
end

-- Painted signs (leg 3, N2): boards where a painted board would really hang, in place of the
-- floating BillboardGuis (switched off, not destroyed; unpaintSigns brings them back). All
-- positions come from the parts the old signs belong to, so this works on the saved world.
-- Run in Edit (safe to run again: it rebuilds Lake.PaintedSigns):
--   require(game.ServerScriptService.Server.WorldBuilder).paintSigns(workspace.Lake)
local STANDS = {
	{ model = "SellStand", art = "FishBuyerStand", text = "Sell Fish", paint = Signs.PAINT.sell },
	{ model = "ShopStand", art = "BaitShopStand", text = "Bait and Tackle", paint = Signs.PAINT.shop },
}
local STAND_BOARD = Vector2.new(9, 2) -- width, height (studs): reads from the dock end
-- The art stands (art/scripts/stands.py): the awning's front edge is the model's front (-z,
-- toward the lake); its slats end about 8.45 studs over the base and the scallops hang to 7.75.
local ART_EAVE_ABOVE_BASE = 8.45
local ART_BOARD_TOP_ABOVE_BASE = 7.6 -- under the scallops, so the striped edge still shows
local ART_BOARD_BEHIND_FRONT = 0.35 -- just behind the scallops, under the slats

-- The art copy of a stand nearest its counter, or nil.
local function standArt(lake: Model, name: string, near: Vector3): Model?
	local folder = lake:FindFirstChild("Art")
	if not folder then
		return nil
	end
	local best: Model? = nil
	local bestDist = 12
	for _, m in folder:GetChildren() do
		if m.Name == name and m:IsA("Model") then
			local p = m:GetPivot().Position
			local d = Vector2.new(p.X - near.X, p.Z - near.Z).Magnitude
			if d < bestDist then
				best, bestDist = m, d
			end
		end
	end
	return best
end

-- The first BasePart named `name` anywhere under root within `range` studs of `near`.
local function nearPart(root: Instance, name: string, near: Vector3, range: number): BasePart?
	for _, d in root:GetDescendants() do
		if d.Name == name and d:IsA("BasePart") and (d.Position - near).Magnitude < range then
			return d
		end
	end
	return nil
end

local LAKEWARD = Vector3.new(0, 0, -1) -- the stands' open fronts face the lake (north, -z)

function WorldBuilder.paintSigns(lake: Model): number
	local folder = Signs.folder(lake)
	local made = 0

	-- The two stands: a board hung by chains under the front of the awning, with a lantern.
	for _, s in STANDS do
		local m = lake:FindFirstChild(s.model)
		local gui = Signs.find(m)
		local counter = m and (if gui and gui.Adornee and gui.Adornee:IsA("BasePart") then gui.Adornee else m:FindFirstChild("Counter"))
		local roof = m and m:FindFirstChild("Roof")
		if m and gui and counter and counter:IsA("BasePart") then
			local x = counter.Position.X
			local frontZ, eave, boardTop
			local art = standArt(lake, s.art, counter.Position)
			if art then
				local cf, size = art:GetBoundingBox()
				local base = cf.Position.Y - size.Y / 2
				frontZ = cf.Position.Z - size.Z / 2 + ART_BOARD_BEHIND_FRONT
				eave = base + ART_EAVE_ABOVE_BASE
				boardTop = base + ART_BOARD_TOP_ABOVE_BASE
			elseif roof and roof:IsA("BasePart") then
				frontZ = roof.Position.Z - roof.Size.Z / 2 + 0.2
				eave = roof.Position.Y - roof.Size.Y / 2
				boardTop = eave - 0.6
			else
				frontZ = counter.Position.Z - counter.Size.Z / 2 - 0.5
				eave = counter.Position.Y + 8.2
				boardTop = eave - 0.6
			end
			local centre = Vector3.new(x, boardTop - STAND_BOARD.Y / 2, frontZ)
			local board = Signs.board({
				name = s.model .. "Sign",
				text = s.text,
				width = STAND_BOARD.X,
				height = STAND_BOARD.Y,
				cframe = CFrame.lookAt(centre, centre + LAKEWARD),
				paint = s.paint,
				hang = "eave",
				eave = eave,
				lantern = true,
			})
			board.Parent = folder
			Signs.cover(gui)
			made += 1
		end
	end

	-- The home pond: a small board on two posts in front of the old sign post, facing away from
	-- the water (the side the path comes from).
	local pond = lake:FindFirstChild("HomePond")
	local pondGui = Signs.find(pond)
	if pond and pondGui then
		local post = if pondGui.Adornee and pondGui.Adornee:IsA("BasePart") then pondGui.Adornee else pond:FindFirstChild("SignPost")
		local water = pond:FindFirstChild("Water")
		if post and post:IsA("BasePart") then
			local out = LAKEWARD
			if water and water:IsA("BasePart") then
				local d = post.Position - water.Position
				d = Vector3.new(d.X, 0, d.Z)
				if d.Magnitude > 0.5 then
					out = d.Unit
				end
			end
			local width, height, thick = 4.5, 1.4, 0.3
			local ground = post.Position.Y - post.Size.Y / 2
			local top = post.Position.Y + post.Size.Y / 2 + 0.3
			local half = math.max(post.Size.X, post.Size.Z) / 2
			local flat = Vector3.new(post.Position.X, top - height / 2, post.Position.Z) + out * (half + thick / 2 + 0.02)
			local board = Signs.board({
				name = "PondSign",
				text = "Your Pond",
				width = width,
				height = height,
				thickness = thick,
				cframe = CFrame.lookAt(flat, flat + out),
				paint = Signs.PAINT.pond,
				hang = "posts",
				ground = ground,
			})
			board.Parent = folder
			Signs.cover(pondGui)
			made += 1
		end
	end

	-- Cedar Creek: a two-sided board hung under the gate arch's beam (Scenery's ArchBeam; before
	-- Scenery runs, where that beam goes: 1.75 over the gate's top).
	local creek = lake:FindFirstChild("CedarCreek")
	local creekGui = Signs.find(creek)
	if creek and creekGui then
		local gate = if creekGui.Adornee and creekGui.Adornee:IsA("BasePart") then creekGui.Adornee else creek:FindFirstChild("CreekGate")
		if gate and gate:IsA("BasePart") then
			local beam = nearPart(lake, "ArchBeam", gate.Position, 12)
			local x, z, eave
			if beam then
				x, z, eave = beam.Position.X, beam.Position.Z, beam.Position.Y - beam.Size.Y / 2
			else
				x, z, eave = gate.Position.X, gate.Position.Z, gate.Position.Y + gate.Size.Y / 2 + 1.75
			end
			local width, height = 6, 1.3
			local centre = Vector3.new(x, eave - 0.35 - height / 2, z)
			local board = Signs.board({
				name = "CreekSign",
				text = "Cedar Creek",
				width = width,
				height = height,
				cframe = CFrame.lookAt(centre, centre + Vector3.new(1, 0, 0)), -- front to the lake (east)
				paint = Signs.PAINT.creek,
				twoSided = true,
				hang = "eave",
				eave = eave,
			})
			board.Parent = folder
			Signs.cover(creekGui)
			made += 1
		end
	end
	return made
end

-- Takes the painted boards away and switches the old floating signs back on.
--   require(game.ServerScriptService.Server.WorldBuilder).unpaintSigns(workspace.Lake)
function WorldBuilder.unpaintSigns(lake: Model)
	local folder = lake:FindFirstChild("PaintedSigns")
	if folder then
		folder:Destroy()
	end
	for _, name in { "SellStand", "ShopStand", "HomePond", "CedarCreek" } do
		Signs.uncover(lake:FindFirstChild(name))
	end
end

return WorldBuilder
