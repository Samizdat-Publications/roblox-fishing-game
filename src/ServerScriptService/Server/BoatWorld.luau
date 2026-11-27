--!strict
-- The Big Lake (L7): the boat slips by the dock, a channel cut through the north shore with a
-- footbridge for the shore path, and the Big Lake beyond it: terrain water with sand shelves
-- and a mud bed, a dark bed under the blue water past the line of orange buoys, a wooded
-- island with a weedy point, and a ring of low hills and trees round its banks.
-- The numbers come from BoatRules so the server's checks and the world agree.
--
-- Run once in Edit, after Scenery.apply (that one fills the land north of the lake with grass,
-- so running it again means running this again too). It is saved in the place; safe to run
-- again. Main only builds it at runtime if Workspace.BigLake is missing.
--
--   require(game.ServerScriptService.Server.BoatWorld).build()
--
-- What it touches outside its own model: Terrain over the Big Lake and its banks; Scenery
-- decoration that stood where the water now is; the Scenery north wall (split at the channel);
-- and the lake's GroundNorth and PathNorth parts (split round the channel).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoatRules = require(Shared.BoatRules)
local Shore = require(Shared.Shore)

local BoatWorld = {}

local SEED = 20261207
local GROUND_TOP = 1 -- the land's top, like Scenery
local PAD = 40 -- how far past the water the old land is cleared and rebuilt
local NEAR_DEPTH, FAR_DEPTH = 7, 14
local CELL = 4 -- terrain voxels are 4 studs

local COLORS = {
	wood = Color3.fromRGB(124, 92, 60),
	darkWood = Color3.fromRGB(88, 62, 40),
	buoy = Color3.fromRGB(240, 130, 30),
	sign = Color3.fromRGB(30, 30, 35),
	blueBed = Color3.fromRGB(34, 44, 58), -- Basalt: only the blue water's bed uses it
}

type Rect = { x1: number, x2: number, z1: number, z2: number }

local function rectOf(b: BoatRules.Box): Rect
	local c, s = b.cframe.Position, b.size
	return { x1 = c.X - s.X / 2, x2 = c.X + s.X / 2, z1 = c.Z - s.Z / 2, z2 = c.Z + s.Z / 2 }
end

local function inRect(r: Rect, x: number, z: number, pad: number): boolean
	return x >= r.x1 - pad and x <= r.x2 + pad and z >= r.z1 - pad and z <= r.z2 + pad
end

local function fill(r: Rect, y1: number, y2: number, material: Enum.Material)
	workspace.Terrain:FillBlock(
		CFrame.new((r.x1 + r.x2) / 2, (y1 + y2) / 2, (r.z1 + r.z2) / 2),
		Vector3.new(r.x2 - r.x1, y2 - y1, r.z2 - r.z1),
		material
	)
end

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

-- An invisible wall, like Scenery's: walkers and swimmers stay inside the world.
local function wall(parent: Instance, name: string, x1: number, x2: number, z1: number, z2: number)
	part(parent, name, Vector3.new(math.max(x2 - x1, 1), 80, math.max(z2 - z1, 1)), CFrame.new((x1 + x2) / 2, 38, (z1 + z2) / 2), Color3.new(1, 1, 1), {
		Transparency = 1,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
end

-- A sign sized in studs (width x height), so it stays small up close (like the lake's signs).
local function sign(adornee: BasePart, text: string, height: number, maxDistance: number, width: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromScale(width, width * 0.24)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = maxDistance
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

local function art(name: string): Model?
	local lake = workspace:FindFirstChild("Lake")
	local folder = lake and lake:FindFirstChild("Art")
	local m = folder and folder:FindFirstChild(name)
	return if m and m:IsA("Model") then m else nil
end

-- A copy of an Art model, decoration only (as Scenery places them).
local function place(template: Model?, parent: Instance, base: Vector3, scale: number, yaw: number, shadow: boolean): Model?
	if not template then
		return nil
	end
	local m = template:Clone()
	m:ScaleTo(scale)
	m:PivotTo(CFrame.new(base) * CFrame.Angles(0, yaw, 0))
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = shadow
		end
	end
	m.Parent = parent
	return m
end

-- The ground's height at (x, z): terrain only.
local function groundAt(x: number, z: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = true
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -260, 0), params)
	return hit and hit.Position.Y or nil
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
		local marker = part(slips, "Slip" .. i, Vector3.new(1, 0.2, 2), CFrame.new(3.4, 1.55, z), COLORS.buoy, { CanCollide = false, CanQuery = false })
		marker:SetAttribute("SlipIndex", i)
		sign(marker, "Slip " .. i, 1.6, 60, 2.4)
	end
	local board = part(slips, "BoatSlipsSign", Vector3.new(0.4, 3, 5), CFrame.new(3.8, 3.2, zs[1] - gap / 2 - 1), COLORS.wood, { Material = Enum.Material.WoodPlanks })
	sign(board, "Boat slips", 2.6, 140, 5)
	slips.Parent = parent
end

-- Splits a ground or path part round x -half..half (only the first time: once split, the
-- pieces have their own names).
local function splitPart(lake: Instance, name: string, half: number, gapExtra: number)
	local p = lake:FindFirstChild(name) :: BasePart?
	if not p then
		return
	end
	local x1, x2 = p.Position.X - p.Size.X / 2, p.Position.X + p.Size.X / 2
	local cut1, cut2 = -half - gapExtra, half + gapExtra
	for _, piece in { { suffix = "West", a = x1, b = cut1 }, { suffix = "East", a = cut2, b = x2 } } do
		if piece.b > piece.a then
			local q = p:Clone()
			q.Name = name .. piece.suffix
			q.Size = Vector3.new(piece.b - piece.a, p.Size.Y, p.Size.Z)
			q.CFrame = CFrame.new((piece.a + piece.b) / 2, p.Position.Y, p.Position.Z)
			for _, k in { "OrigSize" } do
				q:SetAttribute(k, nil)
			end
			q.Parent = lake
		end
	end
	p:Destroy()
end

-- The channel north through GroundNorth: split the ground and the shore path round it and
-- put a footbridge over it, high enough for a boat to pass under.
local function buildChannel(lake: Instance, parent: Instance)
	local c = rectOf(BoatRules.CHANNEL)
	local half = (c.x2 - c.x1) / 2
	local path = lake:FindFirstChild("PathNorth") :: BasePart?
	local pathZ = if path then path.Position.Z else -85
	splitPart(lake, "GroundNorth", half, 0)
	splitPart(lake, "PathNorth", half, 10) -- room for the bridge's ramps

	-- Water 7 deep with a sandy bed 4 down, joining the lake to the Big Lake.
	fill(c, -NEAR_DEPTH, GROUND_TOP + 6, Enum.Material.Air)
	fill(c, -NEAR_DEPTH, 0, Enum.Material.Water)
	fill(c, -NEAR_DEPTH - 6, -4, Enum.Material.Sand)

	local channel = Instance.new("Model")
	channel.Name = "Channel"
	-- Timber banking on both sides, so the cut through the ground reads as built.
	for _, sx in { -1, 1 } do
		part(channel, "Bank", Vector3.new(0.6, 3, c.z2 - c.z1 - 2), CFrame.new(sx * (half - 0.3), -0.2, (c.z1 + c.z2) / 2), COLORS.darkWood, { Material = Enum.Material.WoodPlanks })
	end
	-- Footbridge: deck at y 7 across the channel, ramps down to the path on each side.
	local deckY = 7
	part(channel, "BridgeDeck", Vector3.new(2 * half + 2, 0.6, 6), CFrame.new(0, deckY, pathZ), COLORS.wood, { Material = Enum.Material.WoodPlanks })
	for _, sx in { -1, 1 } do
		local run = 10
		local rise = deckY - 1.1
		local len = math.sqrt(run * run + rise * rise)
		local mid = Vector3.new(sx * (half + 1 + run / 2), (deckY + 1.1) / 2, pathZ)
		part(channel, "BridgeRamp", Vector3.new(len, 0.6, 6), CFrame.new(mid) * CFrame.Angles(0, 0, -sx * math.atan2(rise, run)), COLORS.wood, { Material = Enum.Material.WoodPlanks })
		part(channel, "Pile", Vector3.new(0.8, deckY + 8, 0.8), CFrame.new(sx * (half + 0.6), (deckY - 8) / 2, pathZ - 3), COLORS.darkWood, { Material = Enum.Material.Wood })
		part(channel, "Pile", Vector3.new(0.8, deckY + 8, 0.8), CFrame.new(sx * (half + 0.6), (deckY - 8) / 2, pathZ + 3), COLORS.darkWood, { Material = Enum.Material.Wood })
	end
	for _, dz in { -3, 3 } do
		part(channel, "Rail", Vector3.new(2 * half + 2, 0.3, 0.3), CFrame.new(0, deckY + 1.4, pathZ + dz), COLORS.darkWood, { Material = Enum.Material.Wood })
	end
	channel.Parent = parent
end

-- The old Scenery north wall had no gap; split it at the channel.
local function splitNorthWall(lake: Instance)
	local scenery = lake:FindFirstChild("Scenery")
	local walls = scenery and scenery:FindFirstChild("Walls")
	local north = walls and walls:FindFirstChild("North") :: BasePart?
	if not (walls and north) then
		return
	end
	local c = rectOf(BoatRules.CHANNEL)
	local x1, x2 = north.Position.X - north.Size.X / 2, north.Position.X + north.Size.X / 2
	for _, piece in { { name = "NorthWest", a = x1, b = c.x1 - 1 }, { name = "NorthEast", a = c.x2 + 1, b = x2 } } do
		local q = north:Clone()
		q.Name = piece.name
		q.Size = Vector3.new(piece.b - piece.a, north.Size.Y, north.Size.Z)
		q.CFrame = CFrame.new((piece.a + piece.b) / 2, north.Position.Y, north.Position.Z)
		q.Parent = walls
	end
	north:Destroy()
end

-- Scenery decoration (trees, reeds) that stood where the water and the channel now are.
local function clearScenery(lake: Instance, big: Rect)
	local scenery = lake:FindFirstChild("Scenery")
	if not scenery then
		return 0
	end
	local channel = rectOf(BoatRules.CHANNEL)
	local n = 0
	for _, d in scenery:GetDescendants() do
		if d:IsA("Model") and d.Parent and d.Parent:IsA("Folder") then
			local p = d:GetPivot().Position
			if (p.Z < big.z2 - 1 and inRect(big, p.X, p.Z, PAD)) or inRect(channel, p.X, p.Z, 3) then
				d:Destroy()
				n += 1
			end
		end
	end
	return n
end

-- Terrain: the lake bed, the water, the shallows and beaches, and a ring of low hills that
-- hides where the old land was cut.
local function buildTerrain(big: Rect, island: Rect, rng: Random)
	local t = workspace.Terrain
	t:SetMaterialColor(Enum.Material.Basalt, COLORS.blueBed)
	local buoyZ = BoatRules.BUOY_Z
	local cleared: Rect = { x1 = big.x1 - PAD, x2 = big.x2 + PAD, z1 = big.z1 - PAD, z2 = big.z2 - 1 }
	-- 1. Clear the old land and its hills, then lay flat ground back.
	fill(cleared, -30, 150, Enum.Material.Air)
	task.wait()
	fill(cleared, -26, GROUND_TOP, Enum.Material.Grass)
	task.wait()
	-- 2. The lake itself, voxel by voxel from Shore's outline: the water to y = 0, a bed that
	-- slopes from the sand at the banks down to mud 7 deep (14 past the buoys, on a dark bed),
	-- shallows off the island point for its weeds, the island and headlands as land, and a
	-- sandy beach a few studs up the far banks (outside the box, measured from its edge).
	local area = assert(Shore.areaAt(0, (big.z1 + big.z2) / 2), "Shore has no BigLake area")
	local BEACH = 8
	local region = Region3.new(Vector3.new(big.x1 - BEACH, -28, big.z1 - BEACH), Vector3.new(big.x2 + BEACH, 4, big.z2)):ExpandToGrid(CELL)
	local lo = region.CFrame.Position - region.Size / 2
	local ch = t:ReadVoxelChannels(region, CELL, { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" }) :: any
	local mats, solid, liquid = ch.SolidMaterial, ch.SolidOccupancy, ch.LiquidOccupancy
	local nx, ny, nz = #mats, #mats[1], #mats[1][1]
	for ix = 1, nx do
		local cx = lo.X + (ix - 0.5) * CELL
		for iz = 1, nz do
			local cz = lo.Z + (iz - 0.5) * CELL
			local d
			if inRect(big, cx, cz, 0) then
				d = Shore.depthIn(area, cx, cz)
			else
				local ex, ez = math.clamp(cx, big.x1, big.x2), math.clamp(cz, big.z1, big.z2)
				d = math.max(Shore.depthIn(area, ex, ez), 0) + math.sqrt((cx - ex) ^ 2 + (cz - ez) ^ 2)
			end
			local h, material
			if d >= 0 then
				h = math.min(GROUND_TOP, -0.6 + d * 0.5)
				material = if d >= 3 then Enum.Material.Grass else Enum.Material.Sand
			else
				-- 7 deep in the near half, easing to 14 over the 24 studs past the buoy line.
				local blue = math.clamp((buoyZ + 6 - cz) / 24, 0, 1)
				local depth = math.min(NEAR_DEPTH + (FAR_DEPTH - NEAR_DEPTH) * blue, 0.6 + -d * 0.38)
				local weedy = cx > island.x2 - 4 and cx < island.x2 + 26 and cz > island.z1 - 4 and cz < island.z2 + 4
				if weedy then
					depth = math.min(depth, 3.5)
				end
				h = -depth
				material = if depth < 3 then Enum.Material.Sand
					elseif weedy or blue < 0.5 or depth < 9 then Enum.Material.Mud
					else Enum.Material.Basalt
			end
			for iy = 1, ny do
				local y0 = lo.Y + (iy - 1) * CELL
				local s = math.clamp((h - y0) / CELL, 0, 1)
				mats[ix][iy][iz] = if s > 0 then material else Enum.Material.Air
				solid[ix][iy][iz] = s
				liquid[ix][iy][iz] = if y0 + CELL <= 0.01 then 1 else 0 -- the water's surface is y = 0
			end
		end
	end
	t:WriteVoxelChannels(region, CELL, { SolidMaterial = mats, SolidOccupancy = solid, LiquidOccupancy = liquid })
	task.wait()
	-- 3. A ring of low hills round the cleared edge, so the cut never shows.
	local function hill(x: number, z: number)
		local r = rng:NextNumber(26, 38)
		local h = rng:NextNumber(9, 18)
		t:FillBall(Vector3.new(x, GROUND_TOP + h - r, z), r, Enum.Material.Grass)
	end
	local x = cleared.x1
	while x <= cleared.x2 do
		hill(x + rng:NextNumber(-6, 6), cleared.z1 + rng:NextNumber(-6, 6))
		x += 34
	end
	local z = cleared.z1
	while z <= cleared.z2 do
		hill(cleared.x1 + rng:NextNumber(-6, 6), z)
		hill(cleared.x2 + rng:NextNumber(-6, 6), z)
		z += 34
	end
	hill(cleared.x2, cleared.z2)
	hill(cleared.x1, cleared.z2)
end

-- Trees in clumps on the banks, the headlands and the island; reeds, lily pads and rocks in
-- the shallows along the shore; the weeds off the island point. Shore says where land is.
local function dress(parent: Instance, big: Rect, island: Rect, rng: Random)
	local area = assert(Shore.areaAt(0, (big.z1 + big.z2) / 2), "Shore has no BigLake area")
	local function landDepth(x: number, z: number): number
		-- Inside the Big Lake's box Shore knows; outside it everything is land.
		return if inRect(big, x, z, 0) then Shore.depthIn(area, x, z) else 99
	end
	local folder = Instance.new("Folder")
	folder.Name = "Dressing"
	local kinds = { "PineTall", "PineTall", "PineShort", "LeafyTree", "LeafyTree", "PineShort" }
	local trees = 0
	local function clump(cx: number, cz: number, n: number, spread: number, minLand: number, scale: number)
		for _ = 1, n do
			local tx, tz = cx + rng:NextNumber(-spread, spread), cz + rng:NextNumber(-spread, spread)
			local inBeach = not inRect(big, tx, tz, 0) and inRect(big, tx, tz, 7)
			if landDepth(tx, tz) >= minLand and not inBeach then
				local y = groundAt(tx, tz)
				if y and y > 0.4 then
					place(art(kinds[rng:NextInteger(1, #kinds)]), folder, Vector3.new(tx, y - 0.3, tz), rng:NextNumber(0.8, 1.25) * scale, rng:NextNumber(0, 2 * math.pi), true)
					trees += 1
				end
			end
		end
	end
	-- Clumps on the far banks, between the beach and the hills behind.
	for _ = 1, 24 do
		local side = rng:NextInteger(1, 3)
		if side == 1 then
			clump(big.x1 - rng:NextNumber(12, 34), rng:NextNumber(big.z1, big.z2 - 10), rng:NextInteger(3, 7), 9, 4, 1)
		elseif side == 2 then
			clump(big.x2 + rng:NextNumber(12, 34), rng:NextNumber(big.z1, big.z2 - 10), rng:NextInteger(3, 7), 9, 4, 1)
		else
			clump(rng:NextNumber(big.x1, big.x2), big.z1 - rng:NextNumber(12, 34), rng:NextInteger(3, 7), 9, 4, 1)
		end
	end
	-- A stand on each headland, and the island's trees on its west half (the point stays open).
	for _, p in area.points do
		if string.sub(p.name, 1, 6) ~= "Island" then
			clump(p.x, p.z, math.floor(p.r / 4), p.r * 0.55, 4, 1)
		end
	end
	clump((island.x1 + island.x2) / 2 - 8, (island.z1 + island.z2) / 2, 11, 9, 3, 0.95)

	-- Reeds, lily pads and rocks: a random spot near the box edges (or the island), kept only
	-- where Shore puts it in the shallows.
	local reeds, lily = art("Reeds"), art("LilyPads")
	local rocks = { art("RockSmall"), art("RockMedium") }
	local function shallowSpot(nearIsland: boolean): Vector3?
		for _ = 1, 30 do
			local x, z
			if nearIsland then
				x, z = rng:NextNumber(island.x1 - 6, island.x2 + 4), rng:NextNumber(island.z1 - 6, island.z2 + 6)
			else
				local side = rng:NextInteger(1, 4)
				local inward = rng:NextNumber(0, 40) -- far enough in to reach a headland's nose
				if side == 1 then
					x, z = big.x1 + inward, rng:NextNumber(big.z1, big.z2)
				elseif side == 2 then
					x, z = big.x2 - inward, rng:NextNumber(big.z1, big.z2)
				elseif side == 3 then
					x, z = rng:NextNumber(big.x1, big.x2), big.z1 + inward
				else
					x, z = rng:NextNumber(big.x1, big.x2), big.z2 - inward
				end
			end
			local d = landDepth(x, z)
			local mouth = math.abs(x) < 26 and z > big.z2 - 20 -- keep the channel mouth open
			if d < -0.8 and d > -6 and not mouth then
				return Vector3.new(x, 0, z)
			end
		end
		return nil
	end
	local shore = 0
	for i = 1, 110 do
		local p = shallowSpot(i > 86)
		if p then
			local roll = rng:NextNumber()
			if roll < 0.6 then
				place(reeds, folder, Vector3.new(p.X, -1.2, p.Z), rng:NextNumber(0.7, 1.2), rng:NextNumber(0, 2 * math.pi), false)
			elseif roll < 0.8 then
				place(lily, folder, Vector3.new(p.X, -0.3, p.Z), rng:NextNumber(0.8, 1.3), rng:NextNumber(0, 2 * math.pi), false)
			else
				place(rocks[rng:NextInteger(1, #rocks)], folder, Vector3.new(p.X, -0.6, p.Z), rng:NextNumber(0.8, 1.4), rng:NextNumber(0, 2 * math.pi), true)
			end
			shore += 1
		end
	end
	-- The weedy point: reeds and lily pads thick in the shallows off the island's east tip.
	local weeds = Instance.new("Folder")
	weeds.Name = "PointWeeds"
	local placed = 0
	for _ = 1, 120 do
		if placed >= 36 then
			break
		end
		local wx = island.x2 + rng:NextNumber(-3, 24)
		local wz = rng:NextNumber(island.z1 - 2, island.z2 + 2)
		if landDepth(wx, wz) < -0.8 then
			placed += 1
			if rng:NextNumber() < 0.7 then
				place(reeds, weeds, Vector3.new(wx, -1.2, wz), rng:NextNumber(0.8, 1.3), rng:NextNumber(0, 2 * math.pi), false)
			else
				place(lily, weeds, Vector3.new(wx, -0.3, wz), rng:NextNumber(0.9, 1.4), rng:NextNumber(0, 2 * math.pi), false)
			end
		end
	end
	weeds.Parent = folder
	folder.Parent = parent
	return trees, shore + placed
end

local function buildBigLake(parent: Instance, rng: Random)
	local big = rectOf(BoatRules.BIG_LAKE)
	local island = rectOf(BoatRules.ISLAND)
	buildTerrain(big, island, rng)

	-- Boxes the rules read (the terrain is only the look).
	local marker = part(parent, "Water", BoatRules.BIG_LAKE.size, BoatRules.BIG_LAKE.cframe, Color3.new(1, 1, 1), {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	marker:SetAttribute("IsWater", true)
	local blue = part(parent, "BlueWater", BoatRules.BLUE_WATER.size, BoatRules.BLUE_WATER.cframe, Color3.new(1, 1, 1), {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	blue:SetAttribute("BlueWater", true)

	-- Walls round the banks: a swimmer can't climb out into the land past the Big Lake (or walk
	-- round the creek gate). The south side is the lake's north ground and its own wall.
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	wall(walls, "West", big.x1 - 3, big.x1 - 2, big.z1 - 3, big.z2)
	wall(walls, "East", big.x2 + 2, big.x2 + 3, big.z1 - 3, big.z2)
	wall(walls, "North", big.x1 - 3, big.x2 + 3, big.z1 - 3, big.z1 - 2)
	wall(walls, "SouthEast", 160, big.x2 + 3, big.z2 - 1.5, big.z2 - 0.5) -- past the old world's corner
	walls.Parent = parent

	-- The buoy line: orange buoys every 20 studs, and a sign on the middle one.
	local buoys = Instance.new("Folder")
	buoys.Name = "BuoyLine"
	local x = big.x1 + 10
	local i = 0
	while x < big.x2 do
		if Shore.isLand(Vector3.new(x, 0, BoatRules.BUOY_Z)) then
			x += 20
			continue
		end
		i += 1
		local b = part(buoys, "Buoy" .. i, Vector3.new(2.4, 1.8, 1.8), CFrame.new(x, 0.4, BoatRules.BUOY_Z) * CFrame.Angles(0, 0, math.rad(90)), COLORS.buoy, {
			CanCollide = false,
			CanQuery = false,
			Material = Enum.Material.Plastic,
		})
		b.Shape = Enum.PartType.Cylinder
		if math.abs(x) < 10 then
			sign(b, "Blue water ahead: big boats only", 3.5, 160, 12)
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

function BoatWorld.build(): { [string]: number }
	local old = workspace:FindFirstChild("BigLake")
	if old then
		old:Destroy()
	end
	local rng = Random.new(SEED)
	local model = Instance.new("Model")
	model.Name = "BigLake"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local lake = workspace:FindFirstChild("Lake")
	local big = rectOf(BoatRules.BIG_LAKE)
	local removed = if lake then clearScenery(lake, big) else 0
	buildBigLake(model, rng) -- first: it clears terrain past its edges
	local trees, shore = dress(model, big, rectOf(BoatRules.ISLAND), rng)
	if lake then
		buildSlips(lake)
		buildChannel(lake, model)
		splitNorthWall(lake)
	else
		warn("[BoatWorld] Workspace.Lake missing; build it first")
	end
	model.Parent = workspace
	return { removedScenery = removed, trees = trees, shore = shore }
end

return BoatWorld
