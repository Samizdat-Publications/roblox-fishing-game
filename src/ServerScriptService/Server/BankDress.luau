--!strict
-- The home lake's dress pass (leg 3, N1). Places the bank kit (ServerStorage.Art: reeds, shore
-- stones, leaning birches, shore pines, ferns, bushes, driftwood) by the seeded plan in
-- Shared/Scatter, paints forest floor under the treeline (terrain slot 25) and re-lays the lake
-- loop and the two creek paths as wandering gravel (terrain slot 24), hiding the old straight
-- path parts. Run in Edit after WaterLook.lawnsToTerrain, MaterialKit.paintLawns and
-- MaterialKit.apply (those rewrite the same voxels); safe to run again (it reverts first).
--
--   require(game.ServerScriptService.Server.BankDress).apply(workspace.Lake)
--   require(game.ServerScriptService.Server.BankDress).revert(workspace.Lake)
--
-- Everything placed is decoration: anchored, no collision, no queries, no touches. Casting,
-- zones and prompts are maths on WaterMap and Shore, so nothing about play changes. Ground height
-- comes from a raycast against terrain only. What it changes outside Lake.BankKit is recorded
-- and put back by revert: the old path parts (Transparency, CanCollide), the old LeafyTree copies
-- round the lake in Scenery.Shore (Transparency), and every voxel it repainted (the original
-- slot of each voxel in the paint region is kept in Lake.BankKit.TerrainRecord).
local ServerStorage = game:GetService("ServerStorage")
local MaterialService = game:GetService("MaterialService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Scatter = require(Shared:WaitForChild("Scatter"))

local BankDress = {}

BankDress.SEED = 20261129
BankDress.FOLDER = "BankKit"
BankDress.FOOTPATH_SLOT = 24
BankDress.FOREST_SLOT = 25
local CELL = 4

-- The paint region: the lake loop, the treeline band and its forest floor, and the creek paths.
BankDress.REGION_LO = Vector3.new(-212, -8, -128)
BankDress.REGION_HI = Vector3.new(160, 8, 96)

-- Terrain slots each paint may cover (2 Grass/meadow, 14 Ground, 19 LeafyGrass, 26 the bladeless
-- lawn, 6 Sand only well away from water: the creek paths' sand underlays).
local SAND, LAWN = 6, 26
local FOREST_OVER = { [2] = true, [19] = true, [LAWN] = true }
local PATH_OVER = { [2] = true, [14] = true, [19] = true, [LAWN] = true, [25] = true }
local DRY = 2 -- studs from any water before a footpath cell is painted

-- Family variants for kit meshes that arrive without one (art/models/manifest.json, by suffix).
local VARIANT_BY_SUFFIX = {
	bark = { variant = "Bark", base = Enum.Material.Wood },
	leaf = { variant = "LeafNeedle", base = Enum.Material.LeafyGrass },
	stone = { variant = "ShoreStone", base = Enum.Material.Slate },
}

local HIDDEN_ATTR = "BankDressOrigTransparency"
local COLLIDE_ATTR = "BankDressOrigCollide"

local function template(lake: Instance, name: string): Model?
	local art = ServerStorage:FindFirstChild("Art")
	local m = art and art:FindFirstChild(name)
	if not (m and m:IsA("Model")) then
		local local_ = lake:FindFirstChild("Art")
		m = local_ and local_:FindFirstChild(name)
	end
	return if m and m:IsA("Model") then m else nil
end

local function groundY(params: RaycastParams, x: number, z: number): number?
	local hit = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -240, 0), params)
	return if hit then hit.Position.Y else nil
end

-- The old straight paths: the lake's Path* parts (PathSouth, PathEast, PathWest, PathNorthWest
-- and PathNorthEast round the channel), Scenery's corner bends and the creek's two paths.
local function pathParts(lake: Instance): { BasePart }
	local out: { BasePart } = {}
	for _, p in lake:GetChildren() do
		if p:IsA("BasePart") and string.match(p.Name, "^Path") then
			table.insert(out, p)
		end
	end
	local scenery = lake:FindFirstChild("Scenery")
	local bends = scenery and scenery:FindFirstChild("PathBends")
	if bends then
		for _, p in bends:GetChildren() do
			if p:IsA("BasePart") then
				table.insert(out, p)
			end
		end
	end
	local creek = lake:FindFirstChild("CedarCreek")
	for _, name in { "PathToCreek", "BankPath" } do
		local p = creek and creek:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			table.insert(out, p)
		end
	end
	return out
end

-- The old LeafyTree copies round the home lake (bank bushes, the trees on the points and the
-- bank planting in Scenery.Shore); the creek's bank bushes (west of x -160) stay.
local function oldLeafy(lake: Instance): { Model }
	local out: { Model } = {}
	local scenery = lake:FindFirstChild("Scenery")
	local shore = scenery and scenery:FindFirstChild("Shore")
	if not shore then
		return out
	end
	for _, d in shore:GetDescendants() do
		if d:IsA("Model") and d.Name == "LeafyTree" then
			local p = d:GetPivot().Position
			if math.abs(p.X) <= 160 and math.abs(p.Z) <= 140 then
				table.insert(out, d)
			end
		end
	end
	return out
end

local function hidePart(p: BasePart, collide: boolean)
	if p:GetAttribute(HIDDEN_ATTR) == nil then
		p:SetAttribute(HIDDEN_ATTR, p.Transparency)
		if collide then
			p:SetAttribute(COLLIDE_ATTR, p.CanCollide)
		end
	end
	p.Transparency = 1
	if collide then
		p.CanCollide = false
	end
end

local function unhide(root: Instance): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local t = d:GetAttribute(HIDDEN_ATTR)
			if type(t) == "number" then
				d.Transparency = t
				local c = d:GetAttribute(COLLIDE_ATTR)
				if type(c) == "boolean" then
					d.CanCollide = c
				end
				d:SetAttribute(HIDDEN_ATTR, nil)
				d:SetAttribute(COLLIDE_ATTR, nil)
				n += 1
			end
		end
	end
	return n
end

-- Repaints the region's voxels: forest floor under the treeline, then the footpaths over it.
-- Returns the voxel counts and the record of every voxel's original slot (two hex digits each,
-- x outermost, then y, then z: the order ReadVoxelChannels' arrays are walked in).
local function paint(plan: Scatter.Plan, seed: number): (number, number, string, Region3)
	local t = workspace.Terrain
	local region = Region3.new(BankDress.REGION_LO, BankDress.REGION_HI):ExpandToGrid(CELL)
	local lo = region.CFrame.Position - region.Size / 2
	local ch = t:ReadVoxelChannels(region, CELL, { "SolidMaterialIndex", "SolidOccupancy" }) :: any
	local idx, occ = ch.SolidMaterialIndex, ch.SolidOccupancy
	local size = ch.Size :: Vector3
	local paths = Scatter.pathCells(plan.routes, CELL, seed)
	local forest = Scatter.blobCells(plan.forest, CELL, seed)
	local record = table.create(size.X * size.Y * size.Z)
	local ix0, iz0 = math.floor(lo.X / CELL + 0.5), math.floor(lo.Z / CELL + 0.5)
	local nPath, nForest = 0, 0
	for x = 1, size.X do
		local ix = ix0 + x - 1
		local cx = (ix + 0.5) * CELL
		for y = 1, size.Y do
			for z = 1, size.Z do
				record[#record + 1] = string.format("%02x", idx[x][y][z])
			end
		end
		for z = 1, size.Z do
			local iz = iz0 + z - 1
			local cz = (iz + 0.5) * CELL
			local k = Scatter.key(ix, iz)
			local onPath = paths[k] == true and Scatter.dry(cx, cz, DRY)
			local inForest = forest[k] == true
			if onPath or inForest then
				for y = 1, size.Y do
					local s = idx[x][y][z]
					if occ[x][y][z] > 0 then
						if onPath and (PATH_OVER[s] or (s == SAND and Scatter.dry(cx, cz, 3))) then
							idx[x][y][z] = BankDress.FOOTPATH_SLOT
							nPath += 1
						elseif inForest and not onPath and FOREST_OVER[s] then
							idx[x][y][z] = BankDress.FOREST_SLOT
							nForest += 1
						end
					end
				end
			end
		end
	end
	t:WriteVoxelChannels(region, CELL, { SolidMaterialIndex = idx })
	return nPath, nForest, table.concat(record), region
end

-- Puts back every voxel still holding one of our two slots, from the record.
local function unpaint(folder: Instance): number
	local rec = folder:FindFirstChild("TerrainRecord")
	if not (rec and rec:IsA("StringValue")) then
		return 0
	end
	local lo, hi = rec:GetAttribute("Lo"), rec:GetAttribute("Hi")
	if typeof(lo) ~= "Vector3" or typeof(hi) ~= "Vector3" then
		return 0
	end
	local t = workspace.Terrain
	local region = Region3.new(lo :: Vector3, hi :: Vector3):ExpandToGrid(CELL)
	local ch = t:ReadVoxelChannels(region, CELL, { "SolidMaterialIndex" }) :: any
	local idx = ch.SolidMaterialIndex
	local size = ch.Size :: Vector3
	local data = rec.Value
	if #data ~= size.X * size.Y * size.Z * 2 then
		warn("[BankDress] terrain record does not match its region; terrain left as it is")
		return 0
	end
	local n, i = 0, 0
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				i += 1
				local s = idx[x][y][z]
				if s == BankDress.FOOTPATH_SLOT or s == BankDress.FOREST_SLOT then
					local was = tonumber(string.sub(data, i * 2 - 1, i * 2), 16) :: number
					if was ~= s then
						idx[x][y][z] = was
						n += 1
					end
				end
			end
		end
	end
	t:WriteVoxelChannels(region, CELL, { SolidMaterialIndex = idx })
	return n
end

export type Result = {
	placed: { [string]: number },
	groups: { [string]: number },
	total: number,
	missing: { string },
	noGround: number,
	pathsHidden: number,
	leafyHidden: number,
	footpathVoxels: number,
	forestVoxels: number,
}

function BankDress.revert(lake: Instance): { voxels: number, unhidden: number }
	local folder = lake:FindFirstChild(BankDress.FOLDER)
	local voxels = 0
	if folder then
		voxels = unpaint(folder)
		folder:Destroy()
	end
	local unhidden = unhide(lake)
	return { voxels = voxels, unhidden = unhidden }
end

function BankDress.apply(lake: Instance, seed: number?, tuning: { [string]: any }?): Result
	local s = seed or BankDress.SEED
	BankDress.revert(lake)
	local plan = Scatter.homeLake(s, tuning)

	local folder = Instance.new("Folder")
	folder.Name = BankDress.FOLDER
	folder:SetAttribute("Seed", s)
	local groups: { [string]: Folder } = {}
	local function groupFolder(name: string): Folder
		local f = groups[name]
		if not f then
			f = Instance.new("Folder")
			f.Name = name
			f.Parent = folder
			groups[name] = f
		end
		return f :: Folder
	end

	-- Terrain first, so the ground raycasts read the finished ground (painting moves no surface).
	local nPath, nForest, record, region = paint(plan, s)
	local rec = Instance.new("StringValue")
	rec.Name = "TerrainRecord"
	rec.Value = record
	rec:SetAttribute("Lo", region.CFrame.Position - region.Size / 2)
	rec:SetAttribute("Hi", region.CFrame.Position + region.Size / 2)
	rec.Parent = folder

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = true

	local placed: { [string]: number } = {}
	local groupCounts: { [string]: number } = {}
	local missingSet: { [string]: boolean } = {}
	local noGround = 0
	local total = 0
	for _, it in plan.items do
		local tpl = template(lake, it.model)
		if not tpl then
			missingSet[it.model] = true
			continue
		end
		local bury = (Scatter.KIT[it.model] or 0) * it.scale
		local y: number
		if it.water then
			y = 0 - bury -- the water's surface is y 0
		else
			local g = groundY(params, it.x, it.z)
			if not g then
				noGround += 1
				continue
			end
			y = g - bury
		end
		local m = tpl:Clone()
		m:ScaleTo(it.scale)
		m:PivotTo(CFrame.new(it.x, y, it.z) * CFrame.Angles(0, it.yaw, 0))
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = it.shadow
				if d.MaterialVariant == "" then
					local suffix = string.match(d.Name, "_(%a+)$")
					local v = suffix and VARIANT_BY_SUFFIX[string.lower(suffix)]
					if v and MaterialService:FindFirstChild(v.variant) then
						d.Material = v.base
						d.MaterialVariant = v.variant
					end
				end
			end
		end
		m.Parent = groupFolder(it.group)
		placed[it.model] = (placed[it.model] or 0) + 1
		groupCounts[it.group] = (groupCounts[it.group] or 0) + 1
		total += 1
	end

	-- The old straight paths and the old leafy trees round the lake: hidden, kept for revert.
	local parts = pathParts(lake)
	for _, p in parts do
		hidePart(p, true)
	end
	local leafy = oldLeafy(lake)
	for _, m in leafy do
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				hidePart(d, false)
			end
		end
	end

	folder.Parent = lake
	local missing = {}
	for name in missingSet do
		table.insert(missing, name)
	end
	table.sort(missing)
	if #missing > 0 then
		warn("[BankDress] not in ServerStorage.Art: " .. table.concat(missing, ", "))
	end
	return {
		placed = placed,
		groups = groupCounts,
		total = total,
		missing = missing,
		noGround = noGround,
		pathsHidden = #parts,
		leafyHidden = #leafy,
		footpathVoxels = nPath,
		forestVoxels = nForest,
	}
end

return BankDress
