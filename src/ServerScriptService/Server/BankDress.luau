--!strict
-- The home lake's dress pass (leg 3, N1). Places the bank kit (ServerStorage.Art: reeds, shore
-- stones, leaning birches, shore pines, ferns, bushes, driftwood) by the seeded plan in
-- Shared/Scatter, paints forest floor under the treeline (terrain slot 25) and re-lays the lake
-- loop and the two creek paths as wandering gravel (terrain slot 24), hiding the old straight
-- path parts. Run in Edit after WaterLook.lawnsToTerrain, MaterialKit.paintLawns and
-- MaterialKit.apply (those rewrite the same voxels), and after any Scenery.apply; safe to run
-- again (it reverts first).
--
--   require(game.ServerScriptService.Server.BankDress).apply(workspace.Lake)
--   require(game.ServerScriptService.Server.BankDress).revert(workspace.Lake)
--
-- N1 round 2 (the advisor's ruling after review 1) adds:
--  * the old props retired in frame: the old Reeds copies round the home lake (WorldBuilder's
--    weed-bed scatter in Lake.Art and the Scenery shore's) are hidden and kit reeds stand over
--    the weed bed instead; every old Art copy (lily pads, rocks, logs, the pond rim) gets its
--    family variant (MaterialKit.skinPlaced);
--  * a second row of 80 far pines 34 to 60 studs back, 40 more on the hills, no shadows, and the
--    hills under them painted with the green forest floor (terrain slot 27);
--  * the walk from the back lawn to the dock head (gravel, slot 24), tall meadow-grass blobs on
--    the lawn (slot 2, with blades) and a pine, bush and fern group at each outer lawn corner;
--  * the old Scenery trees swapped: kit trees (ShorePine1 and the birches, 40 at most) within
--    120 studs of the lake loop, far trees (FarPine1/2, FarLeafy1/2) 1:1 everywhere else. An old
--    tree is only hidden once its replacement is placed, so a missing model leaves it standing;
--  * `_lite` kit models used wherever ServerStorage.Art has them, and every placed copy tagged
--    for the client's phone tier (FoliageUnder, FoliageReed, FoliageStone, FoliageTree; see
--    ClientModules/FoliageTier), with a FoliageAlt attribute (0 or 1) for "every second one".
--
-- Everything placed is decoration: anchored, no collision, no queries, no touches. Casting,
-- zones and prompts are maths on WaterMap and Shore, so nothing about play changes. Ground height
-- comes from a raycast against terrain only. What it changes outside Lake.BankKit is recorded
-- and put back by revert: the old path parts (Transparency, CanCollide), the old LeafyTree,
-- Reeds and tree copies (Transparency), and every voxel it repainted (the original slot of each
-- voxel in the paint region is kept in Lake.BankKit.TerrainRecord, and of each hill patch in
-- Lake.BankKit.HillRecords). The variants MaterialKit.skinPlaced gives the old Art copies are
-- MaterialKit's to undo (MaterialKit.undress(workspace.Lake)).
local ServerStorage = game:GetService("ServerStorage")
local MaterialService = game:GetService("MaterialService")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Scatter = require(Shared:WaitForChild("Scatter"))
local MaterialKit = require(script.Parent:WaitForChild("MaterialKit"))
local Scenery = require(script.Parent:WaitForChild("Scenery"))

local BankDress = {}

BankDress.SEED = 20261129
BankDress.FOLDER = "BankKit"
BankDress.FOOTPATH_SLOT = 24
BankDress.FOREST_SLOT = 25
BankDress.HILL_SLOT = 27 -- the green forest floor on the hills (MaterialKit.SLOTS)
BankDress.MEADOW_SLOT = 2 -- the stock Grass slot (MeadowGrass, with blades)
local CELL = 4

-- The old trees: kit trees within this far of the lake loop (it runs 5 studs off the rounded
-- box), at most NEAR_CAP of them; far trees 1:1 everywhere else.
BankDress.NEAR = 120
BankDress.NEAR_CAP = 40

-- The paint region: the lake loop, the treeline band, the far row and its forest floor, the
-- walk and the lawn's meadow, and the creek paths (N1 round 2: was x -212..160, z -128..96).
BankDress.REGION_LO = Vector3.new(-212, -8, -150)
BankDress.REGION_HI = Vector3.new(180, 8, 140)

-- Terrain slots each paint may cover (2 Grass/meadow, 14 Ground, 19 LeafyGrass, 26 the bladeless
-- lawn, 6 Sand only well away from water: the creek paths' sand underlays).
local SAND, LAWN = 6, 26
local FOREST_OVER = { [2] = true, [19] = true, [LAWN] = true }
local PATH_OVER = { [2] = true, [14] = true, [19] = true, [LAWN] = true, [25] = true }
local MEADOW_OVER = { [LAWN] = true }
local DRY = 2 -- studs from any water before a footpath cell is painted

-- Family variants for kit meshes that arrive without one (art/models/manifest.json, by suffix).
local VARIANT_BY_SUFFIX = {
	bark = { variant = "Bark", base = Enum.Material.Wood },
	leaf = { variant = "LeafNeedle", base = Enum.Material.LeafyGrass },
	stone = { variant = "ShoreStone", base = Enum.Material.Slate },
}

local HIDDEN_ATTR = "BankDressOrigTransparency"
local COLLIDE_ATTR = "BankDressOrigCollide"

-- The home lake's bounds, for "round the home lake" (the creek, west of x -160, is left alone).
local function homeLake(p: Vector3): boolean
	return math.abs(p.X) <= 160 and math.abs(p.Z) <= 140
end

local function artModel(name: string): Model?
	local art = ServerStorage:FindFirstChild("Art")
	local m = art and art:FindFirstChild(name)
	return if m and m:IsA("Model") then m else nil
end

-- The kit model for `name`: its `_lite` copy when ServerStorage.Art has one, else the full one
-- (from ServerStorage.Art, else Lake.Art). Second result: true when it is the lite copy.
local function template(lake: Instance, name: string): (Model?, boolean)
	local lite = artModel(name .. "_lite")
	if lite then
		return lite, true
	end
	local m = artModel(name)
	if not m then
		local local_ = lake:FindFirstChild("Art")
		local found = local_ and local_:FindFirstChild(name)
		m = if found and found:IsA("Model") then found else nil
	end
	return m, false
end

local function groundY(params: RaycastParams, x: number, z: number): number?
	local hit = workspace:Raycast(Vector3.new(x, 160, z), Vector3.new(0, -320, 0), params)
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
		if d:IsA("Model") and d.Name == "LeafyTree" and homeLake(d:GetPivot().Position) then
			table.insert(out, d)
		end
	end
	return out
end

-- The old Reeds copies round the home lake: WorldBuilder's weed-bed scatter (Lake.Art) and the
-- Scenery shore's bank reeds. The creek pool's reeds stay.
local function oldReeds(lake: Instance): { Model }
	local out: { Model } = {}
	for _, name in { "Art", "Scenery" } do
		local root = lake:FindFirstChild(name)
		if root then
			for _, d in root:GetDescendants() do
				if d:IsA("Model") and d.Name == "Reeds" and homeLake(d:GetPivot().Position) then
					table.insert(out, d)
				end
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

local function hideModel(m: Model)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			hidePart(d, false)
		end
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

local function hexRecord(idx: any, size: Vector3): string
	local record = table.create(size.X * size.Y * size.Z)
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				record[#record + 1] = string.format("%02x", idx[x][y][z])
			end
		end
	end
	return table.concat(record)
end

-- Repaints the region's voxels: forest floor under the treeline, meadow blobs on the lawn, then
-- the footpaths over both. Returns the voxel counts and the record of every voxel's original slot
-- (two hex digits each, x outermost, then y, then z: the order ReadVoxelChannels' arrays are
-- walked in).
local function paint(plan: Scatter.Plan, seed: number): (number, number, number, string, Region3)
	local t = workspace.Terrain
	local region = Region3.new(BankDress.REGION_LO, BankDress.REGION_HI):ExpandToGrid(CELL)
	local lo = region.CFrame.Position - region.Size / 2
	local ch = t:ReadVoxelChannels(region, CELL, { "SolidMaterialIndex", "SolidOccupancy" }) :: any
	local idx, occ = ch.SolidMaterialIndex, ch.SolidOccupancy
	local size = ch.Size :: Vector3
	local record = hexRecord(idx, size)
	local paths = Scatter.pathCells(plan.routes, CELL, seed)
	local forest = Scatter.blobCells(plan.forest, CELL, seed)
	local meadow = Scatter.blobCells(plan.meadow, CELL, seed + 1)
	local ix0, iz0 = math.floor(lo.X / CELL + 0.5), math.floor(lo.Z / CELL + 0.5)
	local nPath, nForest, nMeadow = 0, 0, 0
	for x = 1, size.X do
		local ix = ix0 + x - 1
		local cx = (ix + 0.5) * CELL
		for z = 1, size.Z do
			local iz = iz0 + z - 1
			local cz = (iz + 0.5) * CELL
			local k = Scatter.key(ix, iz)
			local onPath = paths[k] == true and Scatter.dry(cx, cz, DRY)
			local inForest = forest[k] == true
			local inMeadow = meadow[k] == true
			if onPath then
				-- Only the surface: the top solid voxel, and the one under it when the top is a thin
				-- skin. (Before 11/27/2026 the whole column was painted, so on a bank every voxel down
				-- to the water turned to gravel and showed in the slope beside the path: shot 06's
				-- gravel bank.)
				local top = 0
				for y = size.Y, 1, -1 do
					if occ[x][y][z] > 0 then
						top = y
						break
					end
				end
				local depth = if top > 1 and occ[x][top][z] < 0.5 then 1 else 0
				for y = top, math.max(1, top - depth), -1 do
					local s = idx[x][y][z]
					if top > 0 and (PATH_OVER[s] or (s == SAND and Scatter.dry(cx, cz, 3))) then
						idx[x][y][z] = BankDress.FOOTPATH_SLOT
						nPath += 1
					end
				end
			elseif inForest or inMeadow then
				for y = 1, size.Y do
					local s = idx[x][y][z]
					if occ[x][y][z] > 0 then
						if inForest and FOREST_OVER[s] then
							idx[x][y][z] = BankDress.FOREST_SLOT
							nForest += 1
						elseif inMeadow and MEADOW_OVER[s] then
							idx[x][y][z] = BankDress.MEADOW_SLOT
							nMeadow += 1
						end
					end
				end
			end
		end
	end
	t:WriteVoxelChannels(region, CELL, { SolidMaterialIndex = idx })
	return nPath, nForest, nMeadow, record, region
end

-- Paints one hill patch (the green forest floor) round a blob whose ground is at `g`, and keeps
-- its record (a StringValue with the region in Lo and Hi) in `records`.
local function paintHill(b: Scatter.Blob, g: number, seed: number, records: Folder): number
	local t = workspace.Terrain
	local R = b.r * 1.3 + CELL
	local region = Region3.new(Vector3.new(b.x - R, g - 12, b.z - R), Vector3.new(b.x + R, g + 8, b.z + R)):ExpandToGrid(CELL)
	local lo = region.CFrame.Position - region.Size / 2
	local ch = t:ReadVoxelChannels(region, CELL, { "SolidMaterialIndex", "SolidOccupancy" }) :: any
	local idx, occ = ch.SolidMaterialIndex, ch.SolidOccupancy
	local size = ch.Size :: Vector3
	local record = hexRecord(idx, size)
	local cells = Scatter.blobCells({ b }, CELL, seed + 2)
	local ix0, iz0 = math.floor(lo.X / CELL + 0.5), math.floor(lo.Z / CELL + 0.5)
	local n = 0
	for x = 1, size.X do
		for z = 1, size.Z do
			if cells[Scatter.key(ix0 + x - 1, iz0 + z - 1)] then
				for y = 1, size.Y do
					if occ[x][y][z] > 0 and FOREST_OVER[idx[x][y][z]] then
						idx[x][y][z] = BankDress.HILL_SLOT
						n += 1
					end
				end
			end
		end
	end
	if n > 0 then
		t:WriteVoxelChannels(region, CELL, { SolidMaterialIndex = idx })
		local rec = Instance.new("StringValue")
		rec.Name = string.format("%04d", #records:GetChildren() + 1)
		rec.Value = record
		rec:SetAttribute("Lo", lo)
		rec:SetAttribute("Hi", region.CFrame.Position + region.Size / 2)
		rec.Parent = records
	end
	return n
end

-- Puts back every voxel in a record's region that still holds one of `slots`, from the record.
local function restore(rec: StringValue, slots: { [number]: boolean }): number
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
		warn("[BankDress] terrain record " .. rec.Name .. " does not match its region; terrain left as it is")
		return 0
	end
	local n, i = 0, 0
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				i += 1
				local s = idx[x][y][z]
				if slots[s] then
					local was = tonumber(string.sub(data, i * 2 - 1, i * 2), 16) :: number
					if was ~= s then
						idx[x][y][z] = was
						n += 1
					end
				end
			end
		end
	end
	if n > 0 then
		t:WriteVoxelChannels(region, CELL, { SolidMaterialIndex = idx })
	end
	return n
end

-- Undoes the hill patches (newest first, so overlapping patches end on the true original), then
-- the main region.
local function unpaint(folder: Instance): number
	local n = 0
	local hills = folder:FindFirstChild("HillRecords")
	if hills then
		local list = hills:GetChildren()
		table.sort(list, function(a, b)
			return a.Name > b.Name
		end)
		for _, rec in list do
			if rec:IsA("StringValue") then
				n += restore(rec, { [BankDress.HILL_SLOT] = true })
			end
		end
	end
	local rec = folder:FindFirstChild("TerrainRecord")
	if rec and rec:IsA("StringValue") then
		n += restore(rec, { [BankDress.FOOTPATH_SLOT] = true, [BankDress.FOREST_SLOT] = true, [BankDress.MEADOW_SLOT] = true })
	end
	return n
end

export type Result = {
	placed: { [string]: number },
	groups: { [string]: number },
	total: number,
	missing: { string },
	lite: number, -- copies placed from a `_lite` model
	noGround: number,
	pathsHidden: number,
	leafyHidden: number,
	reedsHidden: number,
	artSkinned: number,
	swapKit: number, -- old trees replaced by kit trees (near the lake)
	swapFar: number, -- old trees replaced 1:1 by far trees
	swapDropped: number, -- old trees hidden without a copy (a new tree, the path or a shot camera's keep-clear is there)
	swapMissing: number, -- old trees left standing: their replacement model is not in ServerStorage.Art
	swapNoGround: number,
	hillPines: number,
	footpathVoxels: number,
	forestVoxels: number,
	meadowVoxels: number,
	hillVoxels: number,
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
	local T: { [string]: any } = table.clone(Scatter.TUNING)
	for k, v in tuning or {} do
		T[k] = v
	end
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
	local nPath, nForest, nMeadow, record, region = paint(plan, s)
	local rec = Instance.new("StringValue")
	rec.Name = "TerrainRecord"
	rec.Value = record
	rec:SetAttribute("Lo", region.CFrame.Position - region.Size / 2)
	rec:SetAttribute("Hi", region.CFrame.Position + region.Size / 2)
	rec.Parent = folder
	local hillRecords = Instance.new("Folder")
	hillRecords.Name = "HillRecords"
	hillRecords.Parent = folder

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = true
	local wetParams = RaycastParams.new()
	wetParams.FilterType = Enum.RaycastFilterType.Include
	wetParams.FilterDescendantsInstances = { workspace.Terrain }
	wetParams.IgnoreWater = false
	-- Ground height for the hill pines: nil over water.
	local function dryHeight(x: number, z: number): number?
		local hit = workspace:Raycast(Vector3.new(x, 160, z), Vector3.new(0, -320, 0), wetParams)
		if not hit or hit.Material == Enum.Material.Water then
			return nil
		end
		return hit.Position.Y
	end

	local placed: { [string]: number } = {}
	local groupCounts: { [string]: number } = {}
	local missingSet: { [string]: boolean } = {}
	local altCount: { [string]: number } = {}
	local noGround, total, liteCount = 0, 0, 0

	-- Places one item; returns the copy (nil if its model is missing or there is no ground).
	local function placeItem(it: Scatter.Item, countMissing: boolean): Model?
		local tpl, isLite = template(lake, it.model)
		if not tpl then
			if countMissing then
				missingSet[it.model] = true
			end
			return nil
		end
		local bury = (Scatter.KIT[it.model] or 0) * it.scale
		local y: number
		if it.water then
			y = 0 - bury -- the water's surface is y 0
		else
			local g = groundY(params, it.x, it.z)
			if not g then
				noGround += 1
				return nil
			end
			y = g - bury
		end
		local m = tpl:Clone()
		m.Name = it.model -- the lite copy keeps the kit name, so audits and tags read the same
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
		local tag = Scatter.TAGS[it.group]
		if tag then
			CollectionService:AddTag(m, tag)
			local c = (altCount[tag] or 0) + 1
			altCount[tag] = c
			m:SetAttribute("FoliageAlt", c % 2)
		end
		m.Parent = groupFolder(it.group)
		placed[it.model] = (placed[it.model] or 0) + 1
		groupCounts[it.group] = (groupCounts[it.group] or 0) + 1
		total += 1
		if isLite then
			liteCount += 1
		end
		return m
	end

	for _, it in plan.items do
		placeItem(it, true)
	end

	-- The hill pines and the green forest floor under them.
	local hillItems, hillBlobs = Scatter.hillPines(s, dryHeight, tuning)
	local nHill, nHillVox = 0, 0
	for i, it in hillItems do
		if placeItem(it, true) then
			nHill += 1
			local g = groundY(params, it.x, it.z)
			if g then
				nHillVox += paintHill(hillBlobs[i], g, s, hillRecords)
			end
		end
	end

	-- The old straight paths, the old leafy bushes and the old reeds round the lake: hidden,
	-- kept for revert. The reeds only once the kit reeds exist.
	local parts = pathParts(lake)
	for _, p in parts do
		hidePart(p, true)
	end
	local leafy = oldLeafy(lake)
	local skipTree: { [Model]: boolean } = {}
	for _, m in leafy do
		hideModel(m)
		skipTree[m] = true
	end
	local reeds: { Model } = {}
	if template(lake, "ReedClump1") or template(lake, "ReedClump2") then
		reeds = oldReeds(lake)
		for _, m in reeds do
			hideModel(m)
		end
	end
	local skinned = 0
	for _, name in { "Art", "Scenery" } do
		local root = lake:FindFirstChild(name)
		if root then
			skinned += MaterialKit.skinPlaced(root)
		end
	end

	-- The old Scenery trees, nearest the lake first: kit trees near the loop (40 at most), far
	-- trees 1:1 everywhere else. A tree is hidden only once its replacement stands.
	local pidx = Scatter.pathIndex(plan.routes)
	local standing: { Scatter.Pt } = {}
	for _, it in plan.items do
		if Scatter.TAGS[it.group] == "FoliageTree" then
			table.insert(standing, { x = it.x, z = it.z })
		end
	end
	for _, it in hillItems do
		table.insert(standing, { x = it.x, z = it.z })
	end
	type Old = { m: Model, x: number, z: number, d: number, kind: string, h: number }
	local olds: { Old } = {}
	for _, m in Scenery.oldTrees(lake) do
		if not skipTree[m] then
			local p = m:GetPivot().Position
			table.insert(olds, { m = m, x = p.X, z = p.Z, d = Scatter.roundBox(p.X, p.Z), kind = Scenery.OLD_TREES[m.Name], h = m:GetExtentsSize().Y })
		end
	end
	table.sort(olds, function(a, b)
		return a.d < b.d
	end)
	local rt = Scatter.rng(s + 18)
	local swapKit, swapFar, swapDropped, swapMissing, swapNoGround = 0, 0, 0, 0, 0
	local function scaleFor(model: string, h: number, lo: number, hi: number): number?
		local tpl = template(lake, model)
		if not tpl then
			return nil
		end
		local th = tpl:GetExtentsSize().Y
		return if th > 0 then math.clamp(h / th, lo, hi) else 1
	end
	for _, o in olds do
		local near = o.d - 5 <= BankDress.NEAR and homeLake(Vector3.new(o.x, 0, o.z))
		local yaw = Scatter.range(rt, 0, 2 * math.pi)
		local u = Scatter.next(rt)
		local it: Scatter.Item? = nil
		if near and swapKit < BankDress.NEAR_CAP then
			if Scatter.kept(o.x, o.z, 1) or not Scatter.shotClear(o.x, o.z, true) or Scatter.pathEdge(pidx, o.x, o.z) <= 1.5 or not Scatter.farEnough(standing, o.x, o.z, 4) then
				hideModel(o.m) -- a new tree or the walk stands here now
				swapDropped += 1
				continue
			end
			if o.kind == "pine" then
				local sc = scaleFor("ShorePine1", o.h, 0.8, 1.3)
				if sc then
					it = { model = "ShorePine1", group = "TreeSwap", x = o.x, z = o.z, yaw = yaw, scale = sc, water = false, shadow = false }
				end
			else
				local model = if u < 0.5 then "BirchLean1" else "BirchLean2"
				local sc = scaleFor(model, o.h, 0.85, 1.2)
				if sc then
					local wx, wz = Scatter.toWater(o.x, o.z)
					it = { model = model, group = "TreeSwap", x = o.x, z = o.z, yaw = Scatter.yawMinusX(wx, wz) + (u - 0.5), scale = sc, water = false, shadow = false }
				end
			end
		elseif not Scatter.shotClear(o.x, o.z, true) then
			hideModel(o.m) -- it stands in a shot camera's keep-clear (Scatter.SHOT_CAMS)
			swapDropped += 1
			continue
		else
			local model = if o.kind == "pine" then (if u < 0.5 then "FarPine1" else "FarPine2") else (if u < 0.5 then "FarLeafy1" else "FarLeafy2")
			local sc = scaleFor(model, o.h, 0.6, 2.5)
			if sc then
				it = { model = model, group = "TreeSwap", x = o.x, z = o.z, yaw = yaw, scale = sc, water = false, shadow = false }
			end
		end
		if not it then
			swapMissing += 1
			continue
		end
		local item = it :: Scatter.Item
		local kit = item.model == "ShorePine1" or item.model == "BirchLean1" or item.model == "BirchLean2"
		if kit then
			local dock = math.sqrt((o.x - Scatter.DOCK.x) ^ 2 + (o.z - Scatter.DOCK.z) ^ 2)
			item.shadow = dock < T.shadowDist
		end
		local before = noGround
		local m = placeItem(item, false)
		if not m then
			if noGround > before then
				swapNoGround += 1
			end
			continue
		end
		hideModel(o.m)
		table.insert(standing, { x = o.x, z = o.z })
		if kit then
			swapKit += 1
		else
			swapFar += 1
			-- Far trees on a hill near the lake get the green forest floor too.
			local g = groundY(params, o.x, o.z)
			if g and g >= T.hillMinHeight and o.d <= T.hillBand[2] then
				nHillVox += paintHill({ x = o.x, z = o.z, r = Scatter.range(rt, 7, 10) }, g, s, hillRecords)
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
		warn("[BankDress] not in ServerStorage.Art (skipped): " .. table.concat(missing, ", "))
	end
	return {
		placed = placed,
		groups = groupCounts,
		total = total,
		missing = missing,
		lite = liteCount,
		noGround = noGround,
		pathsHidden = #parts,
		leafyHidden = #leafy,
		reedsHidden = #reeds,
		artSkinned = skinned,
		swapKit = swapKit,
		swapFar = swapFar,
		swapDropped = swapDropped,
		swapMissing = swapMissing,
		swapNoGround = swapNoGround,
		hillPines = nHill,
		footpathVoxels = nPath,
		forestVoxels = nForest,
		meadowVoxels = nMeadow,
		hillVoxels = nHillVox,
	}
end

return BankDress
