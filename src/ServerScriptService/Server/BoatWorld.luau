--!strict
-- Gray-box geometry for boats: the four boat slips by the dock, a channel cut through the
-- north shore with a footbridge for the shore path, and the Big Lake beyond it (its island,
-- the line of orange buoys and the deeper blue water). The numbers come from BoatRules so
-- the server's checks and the world agree. Like WorldBuilder: run build() once in Edit so
-- it's saved in the place; Main only builds it when Workspace.BigLake is missing.
-- UNVERIFIED in Studio: written 2026-11-26 in the cloud (boat plan Tasks 2, 5 and 7).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoatRules = require(Shared.BoatRules)

local BoatWorld = {}

local COLORS = {
	ground = Color3.fromRGB(106, 127, 63),
	cliff = Color3.fromRGB(120, 112, 100),
	path = Color3.fromRGB(196, 170, 120),
	wood = Color3.fromRGB(124, 92, 60),
	darkWood = Color3.fromRGB(88, 62, 40),
	floor = Color3.fromRGB(110, 100, 80),
	deepFloor = Color3.fromRGB(30, 40, 60),
	buoy = Color3.fromRGB(240, 130, 30),
	weed = Color3.fromRGB(60, 120, 50),
	leaves = Color3.fromRGB(45, 95, 50),
	sign = Color3.fromRGB(30, 30, 35),
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

local function sign(adornee: BasePart, text: string, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromOffset(220, 50)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 90
	gui.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = COLORS.sign
	label.BackgroundTransparency = 0.3
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = label
	gui.Parent = adornee
end

-- Boat slips: mooring posts between the four slips and a sign on the deck.
local function buildSlips(parent: Instance)
	local old = parent:FindFirstChild("BoatSlips")
	if old then
		old:Destroy()
	end
	local slips = Instance.new("Model")
	slips.Name = "BoatSlips"
	local zs = BoatRules.SLIP_ZS
	local gap = zs[2] - zs[1]
	local edges = { zs[1] - gap / 2 }
	for _, z in zs do
		table.insert(edges, z + gap / 2)
	end
	for i, z in edges do
		part(slips, "Post" .. i, Vector3.new(0.8, 6, 0.8), CFrame.new(BoatRules.SLIP_X_EDGE + 0.5, -1, z), COLORS.darkWood, { Material = Enum.Material.Wood })
		part(slips, "FarPost" .. i, Vector3.new(0.8, 6, 0.8), CFrame.new(BoatRules.SLIP_X_EDGE + 18, -1, z), COLORS.darkWood, { Material = Enum.Material.Wood })
	end
	for i, z in zs do
		local marker = part(slips, "Slip" .. i, Vector3.new(1, 0.2, 2), CFrame.new(3.4, 1.55, z), COLORS.buoy, { CanCollide = false })
		marker:SetAttribute("SlipIndex", i)
		sign(marker, "Slip " .. i, 2.5)
	end
	local board = part(slips, "BoatSlipsSign", Vector3.new(0.4, 3, 5), CFrame.new(3.8, 3.2, zs[1] - gap / 2 - 1), COLORS.wood, { Material = Enum.Material.WoodPlanks })
	sign(board, "Boat slips", 3)
	slips.Parent = parent
end

-- The channel north through GroundNorth: split the ground and the shore path around it and
-- put a footbridge over it, high enough for a boat to pass under.
local function buildChannel(lake: Instance, parent: Instance)
	local c = BoatRules.CHANNEL
	local half = c.size.X / 2
	local cz = c.cframe.Position.Z
	local ground = lake:FindFirstChild("GroundNorth") :: BasePart?
	local path = lake:FindFirstChild("PathNorth") :: BasePart?
	if ground then
		local gy, gz, gd, gw = ground.Position.Y, ground.Position.Z, ground.Size.Z, ground.Size.X
		local side = (gw / 2) - half
		part(lake, "GroundNorthWest", Vector3.new(side, ground.Size.Y, gd), CFrame.new(-half - side / 2, gy, gz), ground.Color, { Material = ground.Material })
		part(lake, "GroundNorthEast", Vector3.new(side, ground.Size.Y, gd), CFrame.new(half + side / 2, gy, gz), ground.Color, { Material = ground.Material })
		ground:Destroy()
	end
	local pathZ = -85
	if path then
		pathZ = path.Position.Z
		local pw = path.Size.X
		local side = (pw / 2) - half - 10 -- leaves room for the ramps
		part(lake, "PathNorthWest", Vector3.new(side, path.Size.Y, path.Size.Z), CFrame.new(-half - 10 - side / 2, path.Position.Y, pathZ), path.Color, { Material = path.Material })
		part(lake, "PathNorthEast", Vector3.new(side, path.Size.Y, path.Size.Z), CFrame.new(half + 10 + side / 2, path.Position.Y, pathZ), path.Color, { Material = path.Material })
		path:Destroy()
	end

	local channel = Instance.new("Model")
	channel.Name = "Channel"
	local terrain = workspace.Terrain
	terrain:FillBlock(CFrame.new(0, -3.5, cz), Vector3.new(c.size.X, 7, c.size.Z), Enum.Material.Water)
	part(channel, "ChannelFloor", Vector3.new(c.size.X, 1, c.size.Z), CFrame.new(0, -7.5, cz), COLORS.floor)

	-- Footbridge: deck at y 7 across the channel, ramps down to the path on each side.
	local deckY = 7
	part(channel, "BridgeDeck", Vector3.new(c.size.X + 2, 0.6, 6), CFrame.new(0, deckY, pathZ), COLORS.wood, { Material = Enum.Material.WoodPlanks })
	for _, sx in { -1, 1 } do
		local run = 10
		local rise = deckY - 1.1
		local len = math.sqrt(run * run + rise * rise)
		local mid = Vector3.new(sx * (half + 1 + run / 2), (deckY + 1.1) / 2, pathZ)
		part(channel, "BridgeRamp", Vector3.new(len, 0.6, 6), CFrame.new(mid) * CFrame.Angles(0, 0, -sx * math.atan2(rise, run)), COLORS.wood, { Material = Enum.Material.WoodPlanks })
		for _, dz in { -3, 3 } do
			part(channel, "Rail", Vector3.new(c.size.X + 2, 1, 0.3), CFrame.new(0, deckY + 1.2, pathZ + dz), COLORS.darkWood)
			part(channel, "Pile", Vector3.new(0.8, deckY + 7, 0.8), CFrame.new(sx * (half + 0.6), (deckY - 7) / 2, pathZ + dz), COLORS.darkWood)
		end
	end
	channel.Parent = parent
end

local function buildBigLake(parent: Instance)
	local big = BoatRules.BIG_LAKE
	local bp, bs = big.cframe.Position, big.size
	local x1, x2 = bp.X - bs.X / 2, bp.X + bs.X / 2
	local z1, z2 = bp.Z - bs.Z / 2, bp.Z + bs.Z / 2 -- z1 is the far (north) edge
	local buoyZ = BoatRules.BUOY_Z
	local terrain = workspace.Terrain

	-- Water: 7 deep on the near (dinghy) side, 14 deep past the buoys.
	terrain:FillBlock(CFrame.new(bp.X, -8, bp.Z), Vector3.new(bs.X + 20, 18, bs.Z + 20), Enum.Material.Air)
	local nearDepth, farDepth = 7, 14
	terrain:FillBlock(CFrame.new(bp.X, -nearDepth / 2, (buoyZ + z2) / 2), Vector3.new(bs.X, nearDepth, z2 - buoyZ), Enum.Material.Water)
	terrain:FillBlock(CFrame.new(bp.X, -farDepth / 2, (z1 + buoyZ) / 2), Vector3.new(bs.X, farDepth, buoyZ - z1), Enum.Material.Water)
	part(parent, "NearFloor", Vector3.new(bs.X, 1, z2 - buoyZ), CFrame.new(bp.X, -nearDepth - 0.5, (buoyZ + z2) / 2), COLORS.floor)
	part(parent, "BlueWaterFloor", Vector3.new(bs.X, 1, buoyZ - z1), CFrame.new(bp.X, -farDepth - 0.5, (z1 + buoyZ) / 2), COLORS.deepFloor, { Material = Enum.Material.Slate })
	local marker = part(parent, "Water", Vector3.new(bs.X, 1, bs.Z), big.cframe, COLORS.floor, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	marker:SetAttribute("IsWater", true)
	local blue = part(parent, "BlueWater", BoatRules.BLUE_WATER.size, BoatRules.BLUE_WATER.cframe, COLORS.deepFloor, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	blue:SetAttribute("BlueWater", true)

	-- Shores: tall cliffs on the far sides, so the Big Lake is boat-only. The south shore is
	-- the north ground of the lake; a fence keeps walkers from hopping in there.
	local h = 30
	part(parent, "CliffWest", Vector3.new(30, h, bs.Z + 60), CFrame.new(x1 - 15, h / 2 - 8, bp.Z - 30), COLORS.cliff, { Material = Enum.Material.Rock })
	part(parent, "CliffEast", Vector3.new(30, h, bs.Z + 60), CFrame.new(x2 + 15, h / 2 - 8, bp.Z - 30), COLORS.cliff, { Material = Enum.Material.Rock })
	part(parent, "CliffNorth", Vector3.new(bs.X + 60, h, 30), CFrame.new(bp.X, h / 2 - 8, z1 - 15), COLORS.cliff, { Material = Enum.Material.Rock })
	-- Fill the corners between the lake's north ground (x -160..160) and the cliffs.
	part(parent, "GroundCornerWest", Vector3.new(40, 8, 60), CFrame.new(x1 + 20, -3, z2 + 30), COLORS.ground, { Material = Enum.Material.Grass })
	part(parent, "GroundCornerEast", Vector3.new(40, 8, 60), CFrame.new(x2 - 20, -3, z2 + 30), COLORS.ground, { Material = Enum.Material.Grass })
	local half = BoatRules.CHANNEL.size.X / 2
	for _, sx in { -1, 1 } do
		local len = (bs.X / 2) - half - 1
		part(parent, "ShoreFence", Vector3.new(len, 5, 0.6), CFrame.new(sx * (half + 1 + len / 2), 3.5, z2 - 0.5), COLORS.wood, { Material = Enum.Material.WoodPlanks })
	end

	-- The island, with a few trees and weeds off its east point.
	local isl = BoatRules.ISLAND
	local ip, is = isl.cframe.Position, isl.size
	part(parent, "Island", Vector3.new(is.X, 16, is.Z), CFrame.new(ip.X, -6, ip.Z), COLORS.ground, { Material = Enum.Material.Grass })
	local rng = Random.new(26)
	for i = 1, 5 do
		local tx = ip.X + rng:NextNumber(-is.X / 2 + 4, is.X / 2 - 4)
		local tz = ip.Z + rng:NextNumber(-is.Z / 2 + 4, is.Z / 2 - 4)
		part(parent, "IslandTrunk" .. i, Vector3.new(1.4, 9, 1.4), CFrame.new(tx, 6.5, tz), COLORS.darkWood, { Material = Enum.Material.Wood })
		part(parent, "IslandCrown" .. i, Vector3.new(7, 8, 7), CFrame.new(tx, 13, tz), COLORS.leaves, { Material = Enum.Material.Grass })
	end
	local weeds = Instance.new("Folder")
	weeds.Name = "PointWeeds"
	for i = 1, 40 do
		local wx = ip.X + is.X / 2 + rng:NextNumber(2, 26)
		local wz = ip.Z + rng:NextNumber(-14, 14)
		local wh = rng:NextNumber(3, 6)
		part(weeds, "Weed" .. i, Vector3.new(0.6, wh, 0.6), CFrame.new(wx, -nearDepth + wh / 2 + 0.5, wz), COLORS.weed, { CanCollide = false, CanQuery = false })
	end
	weeds.Parent = parent

	-- The buoy line: orange buoys every 20 studs, and a sign on the middle one.
	local buoys = Instance.new("Folder")
	buoys.Name = "BuoyLine"
	local x = x1 + 10
	local i = 0
	while x < x2 do
		i += 1
		local b = part(buoys, "Buoy" .. i, Vector3.new(2.4, 1.8, 1.8), CFrame.new(x, 0.5, buoyZ) * CFrame.Angles(0, 0, math.rad(90)), COLORS.buoy, { CanCollide = false })
		b.Shape = Enum.PartType.Cylinder
		if math.abs(x) < 10 then
			sign(b, "Blue water ahead: Deep-V Boat only", 4)
		end
		x += 20
	end
	buoys.Parent = parent

	-- Zones, like the lake's, so the server can name where a bobber landed.
	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	for _, z in BoatRules.ZONES do
		part(zones, z.name, z.size, z.cframe, Color3.new(1, 1, 1), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	end
	zones.Parent = parent
end

function BoatWorld.build(): Model
	local old = workspace:FindFirstChild("BigLake")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "BigLake"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	buildBigLake(model) -- first: it clears terrain a little past its edges
	local lake = workspace:FindFirstChild("Lake")
	if lake then
		buildSlips(lake)
		buildChannel(lake, model)
	else
		warn("[BoatWorld] Workspace.Lake missing; build it first")
	end
	model.Parent = workspace
	return model
end

return BoatWorld
