--!strict
-- Real-ish water (L5a): clear teal terrain water with gentle waves, and depth that reads by
-- colour: light sand in the shallows round the shore, mud on the lake bed, near-black over
-- the deep hole. Run once in Edit (it is saved in the place); safe to run again.
--
--   require(game.ServerScriptService.Server.WaterLook).apply(workspace.Lake)
--
-- What it touches: Terrain water inside the WaterMap water boxes (bed up to the surface),
-- Terrain's water settings, the colour and material of the creek bed parts (the originals are
-- kept as attributes, see revert), and since L5b a terrain lake bed (mud, sand shelves, a
-- stepped deep hole) that hides the lake's flat Floor parts. The flat Water parts stay exactly
-- where they are, only invisible: casts, zones and every other fishing rule read their boxes.
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

-- Bed parts to tint: path under Lake, colour, material.
local TINTS: { { path: string, color: Color3, material: Enum.Material } } = {
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

-- The lake's own bed parts. L5b hides them under a terrain bed (they sat in the water as flat
-- slabs with straight edges); nothing in the game reads them.
local HIDDEN_BEDS = { "Floor", "DeepHoleFloor" }

-- The lake bed in terrain (L5b). The old tilted shelf parts showed their straight edges through
-- the water as seams; terrain sand slopes smooth into a mud bed instead, and the deep hole is a
-- real two-step bowl. Whole-voxel heights (multiples of 4) so the bed and the water meet cleanly.
WaterLook.BED_TOP = -8 -- top of the mud bed
WaterLook.SHELF = 20 -- studs from the bank to where the sand meets the bed
WaterLook.SHORE_DEPTH = 0.7 -- the shallowest sand sits under this much water
local HOLE_OUTER = Vector3.new(60, 0, 50) -- first step of the deep hole, 4 studs deeper
local HOLE_INNER = Vector3.new(40, 0, 30) -- second step, 8 studs deeper

local function terrainBed(lake: Model, surfaceY: number)
	local t = workspace.Terrain
	t:SetMaterialColor(Enum.Material.Sand, SAND)
	t:SetMaterialColor(Enum.Material.Mud, BED)
	local size = WaterMap.WATER_SIZE
	local c = WaterMap.WATER_CF.Position
	local bed = WaterLook.BED_TOP
	-- Mud from bed - 8 up to the bed (it was air under the water before).
	t:FillBlock(CFrame.new(c.X, bed - 4, c.Z), Vector3.new(size.X, 8, size.Z), Enum.Material.Mud)
	-- The deep hole: two steps of water cut into the mud, mud under the deepest step.
	local hole = lake:FindFirstChild("DeepHoleFloor")
	local hc = if hole and hole:IsA("BasePart") then hole.Position else Vector3.new(c.X, 0, c.Z - 25)
	t:FillBlock(CFrame.new(hc.X, bed - 2, hc.Z), Vector3.new(HOLE_OUTER.X, 4, HOLE_OUTER.Z), Enum.Material.Water)
	t:FillBlock(CFrame.new(hc.X, bed - 6, hc.Z), Vector3.new(HOLE_INNER.X, 4, HOLE_INNER.Z), Enum.Material.Water)
	t:FillBlock(CFrame.new(hc.X, bed - 10, hc.Z), Vector3.new(HOLE_INNER.X, 4, HOLE_INNER.Z), Enum.Material.Mud)
	-- Sand shelves, high side (a terrain wedge's local +Z) at the bank.
	local hx, hz = size.X / 2, size.Z / 2
	local shelf = WaterLook.SHELF
	local drop = (surfaceY - WaterLook.SHORE_DEPTH) - bed
	local y = bed + drop / 2
	local inset = shelf / 2
	t:FillWedge(CFrame.new(c.X, y, c.Z + hz - inset), Vector3.new(size.X, drop, shelf), Enum.Material.Sand)
	t:FillWedge(CFrame.new(c.X, y, c.Z - hz + inset) * CFrame.Angles(0, math.pi, 0), Vector3.new(size.X, drop, shelf), Enum.Material.Sand)
	t:FillWedge(CFrame.new(c.X + hx - inset, y, c.Z) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(size.Z, drop, shelf), Enum.Material.Sand)
	t:FillWedge(CFrame.new(c.X - hx + inset, y, c.Z) * CFrame.Angles(0, -math.pi / 2, 0), Vector3.new(size.Z, drop, shelf), Enum.Material.Sand)
	-- Hide the old flat bed parts (kept, so revert can show them again).
	for _, name in HIDDEN_BEDS do
		local p = lake:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			if p:GetAttribute("OrigTransparency") == nil then
				p:SetAttribute("OrigTransparency", p.Transparency)
			end
			p.Transparency = 1
		end
	end
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

	-- The bed: terrain since L5b. The old decoration folder (tilted shelf parts) goes.
	local old = lake:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	local size = WaterMap.WATER_SIZE
	terrainBed(lake, WaterMap.WATER_CF.Position.Y + size.Y / 2)

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
	for _, name in HIDDEN_BEDS do
		local p = lake:FindFirstChild(name)
		local was = p and p:GetAttribute("OrigTransparency")
		if p and p:IsA("BasePart") and type(was) == "number" then
			p.Transparency = was
			p:SetAttribute("OrigTransparency", nil)
		end
	end
end

return WaterLook
