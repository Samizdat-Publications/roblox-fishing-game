--!strict
-- Real-ish water (L5a): clear teal terrain water with gentle waves, and depth that reads by
-- colour: light sand in the shallows round the shore, mud on the lake bed, near-black over
-- the deep hole. Run once in Edit (it is saved in the place); safe to run again.
--
--   require(game.ServerScriptService.Server.WaterLook).apply(workspace.Lake)
--
-- What it touches: Terrain water inside the WaterMap water boxes (bed up to the surface),
-- Terrain's water settings, the colour and material of the lake and creek bed parts (the
-- originals are kept as attributes, see revert), and a folder Lake.WaterLook of decoration
-- parts (no collision, no queries, no touches). The flat Water parts stay exactly where
-- they are, only invisible: casts, zones and every other fishing rule read their boxes.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local WaterMap = require(Shared:WaitForChild("WaterMap"))

local WaterLook = {}

local FOLDER = "WaterLook"
local CELL = 4 -- terrain voxels are 4 studs

WaterLook.TERRAIN = {
	WaterColor = Color3.fromRGB(24, 92, 112), -- teal, darkening with depth
	WaterTransparency = 0.72, -- clear enough to see the sand shelf and the bed
	WaterReflectance = 0.5,
	WaterWaveSize = 0.12, -- gentle
	WaterWaveSpeed = 8,
}

local SAND = Color3.fromRGB(198, 182, 134)
local BED = Color3.fromRGB(96, 88, 66)
local DEEP_EDGE = Color3.fromRGB(58, 60, 50)
local DEEP = Color3.fromRGB(26, 34, 36)

-- Bed parts to tint: path under Lake, colour, material.
local TINTS: { { path: string, color: Color3, material: Enum.Material } } = {
	{ path = "Floor", color = BED, material = Enum.Material.Mud },
	{ path = "DeepHoleFloor", color = DEEP, material = Enum.Material.Mud },
	{ path = "CedarCreek.RiffleBed", color = Color3.fromRGB(140, 126, 100), material = Enum.Material.Pebble },
	{ path = "CedarCreek.RocksBed", color = Color3.fromRGB(96, 92, 80), material = Enum.Material.Slate },
	{ path = "CedarCreek.PoolBed", color = Color3.fromRGB(30, 38, 40), material = Enum.Material.Mud },
}

-- The flat water parts made invisible (they stay for casts).
local WATER_PARTS = { "Water", "CedarCreek.CreekWater.RiffleWater", "CedarCreek.CreekWater.RocksWater", "CedarCreek.CreekWater.PoolWater" }

local function find(root: Instance, path: string): Instance?
	local node: Instance? = root
	for _, step in string.split(path, ".") do
		node = node and node:FindFirstChild(step)
	end
	return node
end

local function deco(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A tilted slab from `shore` (high) down to `inner` (low), `width` wide, its top on the line.
local function slope(parent: Instance, name: string, shore: Vector3, inner: Vector3, width: number)
	local thick = 0.6
	local down = Vector3.new(0, thick / 2, 0)
	local a, b = shore - down, inner - down
	local len = (a - b).Magnitude + 1
	deco(parent, name, Vector3.new(width, thick, len), CFrame.lookAt((a + b) / 2, a), SAND, Enum.Material.Sand)
end

-- Bed height under each water box: the lake's Floor top, or the creek stretch's bed.
local function bedOf(lake: Model, index: number): number
	if index == 1 then
		local floor = lake:FindFirstChild("Floor")
		if floor and floor:IsA("BasePart") then
			return floor.Position.Y + floor.Size.Y / 2
		end
		return -6
	end
	return WaterMap.CREEK[index - 1].bed
end

-- Applies the water look. Returns counts for the log.
function WaterLook.apply(lake: Model): { filled: number, tinted: number, shelves: number }
	local terrain = workspace.Terrain
	for k, v in WaterLook.TERRAIN do
		(terrain :: any)[k] = v
	end

	-- Terrain water from the bed (rounded down to whole cells) up to the surface: the top of
	-- the Water part where it exists, else the box top. Filling water over water changes nothing.
	local filled = 0
	for i, box in WaterMap.waters() do
		local surface = box.cframe.Position.Y + box.size.Y / 2
		local partPath = WATER_PARTS[i]
		local part = partPath and find(lake, partPath)
		if part and part:IsA("BasePart") then
			surface = part.Position.Y + part.Size.Y / 2
		end
		local bottom = math.floor(bedOf(lake, i) / CELL) * CELL
		local h = surface - bottom
		if h > 0 then
			local c = box.cframe.Position
			terrain:FillBlock(CFrame.new(c.X, bottom + h / 2, c.Z), Vector3.new(box.size.X, h, box.size.Z), Enum.Material.Water)
			filled += 1
		end
	end

	-- The flat water parts: invisible, otherwise untouched.
	for _, path in WATER_PARTS do
		local p = find(lake, path)
		if p and p:IsA("BasePart") then
			p.Transparency = 1
		end
	end

	-- Bed colours (originals kept once, for revert).
	local tinted = 0
	for _, t in TINTS do
		local p = find(lake, t.path)
		if p and p:IsA("BasePart") then
			if p:GetAttribute("OrigColor") == nil then
				p:SetAttribute("OrigColor", p.Color)
				p:SetAttribute("OrigMaterial", p.Material.Name)
			end
			p.Color = t.color
			p.Material = t.material
			tinted += 1
		end
	end

	-- Decoration, rebuilt from scratch each run.
	local old = lake:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	local size = WaterMap.WATER_SIZE
	local hx, hz = size.X / 2, size.Z / 2
	local surfaceY = WaterMap.WATER_CF.Position.Y + size.Y / 2
	local floorY = bedOf(lake, 1)
	local SHELF = 16 -- studs from the shore to where the shelf meets the bed
	local shoreY = surfaceY - 0.7 -- the shallowest sand sits under 0.7 studs of water
	slope(folder, "ShelfSouth", Vector3.new(0, shoreY, hz), Vector3.new(0, floorY, hz - SHELF), size.X)
	slope(folder, "ShelfNorth", Vector3.new(0, shoreY, -hz), Vector3.new(0, floorY, -hz + SHELF), size.X)
	slope(folder, "ShelfEast", Vector3.new(hx, shoreY, 0), Vector3.new(hx - SHELF, floorY, 0), size.Z)
	slope(folder, "ShelfWest", Vector3.new(-hx, shoreY, 0), Vector3.new(-hx + SHELF, floorY, 0), size.Z)
	-- A darker ring round the deep hole so the bed darkens towards it, not in one step.
	local hole = lake:FindFirstChild("DeepHoleFloor")
	if hole and hole:IsA("BasePart") then
		local top = hole.Position.Y + hole.Size.Y / 2
		deco(folder, "DeepHoleEdge", Vector3.new(hole.Size.X + 20, 0.2, hole.Size.Z + 16), CFrame.new(hole.Position.X, top - 0.35, hole.Position.Z), DEEP_EDGE, Enum.Material.Mud)
	end
	folder.Parent = lake

	return { filled = filled, tinted = tinted, shelves = 4 }
end

-- Puts the bed parts back as they were and removes the decoration. Terrain water and its
-- settings stay (the gray box used terrain water too).
function WaterLook.revert(lake: Model)
	for _, t in TINTS do
		local p = find(lake, t.path)
		if p and p:IsA("BasePart") then
			local color = p:GetAttribute("OrigColor")
			local material = p:GetAttribute("OrigMaterial")
			if typeof(color) == "Color3" then
				p.Color = color
			end
			if type(material) == "string" then
				p.Material = (Enum.Material :: any)[material]
			end
			p:SetAttribute("OrigColor", nil)
			p:SetAttribute("OrigMaterial", nil)
		end
	end
	local old = lake:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
end

return WaterLook
