--!strict
-- Gray-box lake. Run build() once in Edit so the geometry is saved in the place;
-- Main only calls it when Workspace.Lake is missing.
--
-- Layout (studs, y up, water surface at y = 0):
--   Lake 220 x 160 centered on the origin. Ground ring top at y = 1.
--   South shore (z = +80) has the dock, spawn, sell stand and shop.
--   Weed bed in the south-west, fallen logs in the south-east, deep hole north of the dock.
local WorldBuilder = {}

local WATER_SIZE = Vector3.new(220, 1, 160)
local WATER_CF = CFrame.new(0, -0.5, 0)

-- Zone boxes (first match wins, so the dock is listed first).
local ZONES = {
	{ name = "Dock", center = Vector3.new(0, 0, 57), size = Vector3.new(30, 10, 46) },
	{ name = "WeedBed", center = Vector3.new(-78, 0, 38), size = Vector3.new(56, 10, 64) },
	{ name = "Logs", center = Vector3.new(78, 0, 42), size = Vector3.new(56, 10, 60) },
	{ name = "DeepHole", center = Vector3.new(0, 0, -22), size = Vector3.new(60, 10, 56) },
}

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

local function sign(parent: Instance, adornee: BasePart, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 400
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	label.BackgroundTransparency = 0.3
	label.TextColor3 = color
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
	sign(m, counter, title, color)
	m.PrimaryPart = counter
	m.Parent = parent
end

function WorldBuilder.zones(): { { name: string, cframe: CFrame, size: Vector3 } }
	local out = {}
	for _, z in ZONES do
		table.insert(out, { name = z.name, cframe = CFrame.new(z.center), size = z.size })
	end
	return out
end

function WorldBuilder.water(): (CFrame, Vector3)
	return WATER_CF, WATER_SIZE
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
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		bulb.Shape = Enum.PartType.Ball
		local light = Instance.new("PointLight")
		light.Range = 28
		light.Brightness = 1.6
		light.Color = Color3.fromRGB(255, 225, 170)
		light.Shadows = false
		light.Parent = bulb
	end
	lamps.Parent = lake

	lake.Parent = workspace
	return lake
end

return WorldBuilder
