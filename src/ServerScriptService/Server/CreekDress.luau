--!strict
-- Cedar Creek's dress (leg 3, N3), from the pure plan in Shared/CreekPlan. Run in Edit after
-- WaterLook.apply, Scenery.apply, BankDress.apply, CreekSwap.apply and MaterialKit.apply; safe to
-- run again (it reverts first). `require` is cached across execute_luau calls, so require a clone:
--
--   local m = game.ServerScriptService.Server.CreekDress:Clone(); m.Parent = game.ServerScriptService.Server
--   local r = require(m).apply(workspace.Lake); m:Destroy(); return r
--   (revert: the same with .revert(workspace.Lake))
--
-- What it does:
--  1. Reshapes the creek's terrain inside CreekPlan.REGION only (columns within CreekPlan.TOUCH
--     of the drawn water; never a column holding footpath gravel, slot 24): rounded joins between
--     the stretches, the pool's scoured west corners, gravel bars, raised cut banks, and paints
--     slots 28 to 31 (creek pebble, creek bed, wet slate, moss) and lake mud in the pool's deep.
--     Every voxel of the region is recorded first (Lake.CreekDress.TerrainRecord); revert writes
--     them back. Rerun WaterLook or the wet band after a revert, not between apply and revert.
--  2. Places the plan's cedars, shore pines, ferns, roots, bank moss mats and the mossy log from
--     ServerStorage.Art (a missing model is skipped and counted).
--  3. Lays a MossMat on top of each creek boulder above the water (RockLarge, RockMedium and any
--     visible gray-box Boulder) and gives the rock's meshes the WetSlate variant when it exists.
--  4. N3 review 1 (the advisor): paints the moss (slot 31) on out into the backing forest
--     (CreekPlan.mossBand, to D 30, over grass-like slots only) and re-lays the bank path and the
--     walk to the gate as slot 14 (FootpathGravel), giving the old path parts the FootpathGravel
--     variant too. Each voxel it repaints is recorded (Lake.CreekDress.SlotRecords) and put back
--     by revert. It also places shot 09's frame cedars, the backing forest, the emergent
--     wet-slate rocks on the riffle (RockMedium, its top just out of the water) and, when
--     CreekPlan.TUNING.boughsPer is above 0, CedarBough sprays hung from the riffle's cedars
--     (inside each cedar's model, so the phone tier hides them together; skipped while the model
--     is not in ServerStorage.Art).
-- Slots 28 to 31 get MaterialKit's variant when it is in MaterialService, else the plain base
-- material with a palette tint (FALLBACK), so the creek reads right before the maps are uploaded.
-- Everything new is in Lake.CreekDress: anchored, no collision, queries or touches.
local ServerStorage = game:GetService("ServerStorage")
local MaterialService = game:GetService("MaterialService")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CreekPlan = require(Shared:WaitForChild("CreekPlan"))
local Scatter = require(Shared:WaitForChild("Scatter"))
local MaterialKit = require(script.Parent:WaitForChild("MaterialKit"))

local CreekDress = {}

CreekDress.FOLDER = "CreekDress"
CreekDress.FOOTPATH_SLOT = 24
local CELL = CreekPlan.CELL
local ORIG_MAT = "CreekDressOrigMaterial"
local ORIG_VARIANT = "CreekDressOrigVariant"

-- Palette tints for slots 28 to 31 while their variant is not uploaded (plan: moss 78,104,52,
-- wet slate 70,78,84; the pebbles a warm grey, darker under the water).
CreekDress.FALLBACK = {
	[28] = Color3.fromRGB(150, 138, 116),
	[29] = Color3.fromRGB(96, 88, 70),
	[30] = Color3.fromRGB(70, 78, 84),
	[31] = Color3.fromRGB(78, 104, 52),
} :: { [number]: Color3 }

local VARIANT_BY_SUFFIX = {
	bark = { variant = "Bark", base = Enum.Material.Wood },
	leaf = { variant = "LeafNeedle", base = Enum.Material.LeafyGrass },
	stone = { variant = "ShoreStone", base = Enum.Material.Slate },
}

-- Which CollectionService tag the phone tier (ClientModules/FoliageTier) reads for a group.
local TAGS = { Trees = "FoliageTree", Ferns = "FoliageUnder", Roots = "FoliageUnder" } :: { [string]: string }

local function artModel(name: string): Model?
	local art = ServerStorage:FindFirstChild("Art")
	local m = art and art:FindFirstChild(name)
	return if m and m:IsA("Model") then m else nil
end

-- The kit model: its `_lite` copy when there is one (ShorePine2), as CreekSwap does; else the
-- full one from ServerStorage.Art, else from Lake.Art (the rocks live there).
local lakeArt: Instance? = nil
local function template(name: string): (Model?, boolean)
	local lite = artModel(name .. "_lite")
	if lite then
		return lite, true
	end
	local m = artModel(name)
	if not m and lakeArt then
		local found = (lakeArt :: Instance):FindFirstChild(name)
		m = if found and found:IsA("Model") then found else nil
	end
	return m, false
end

---------------------------------------------------------------------------------------------
-- Terrain
---------------------------------------------------------------------------------------------

local function region(): Region3
	local R = CreekPlan.REGION
	return Region3.new(Vector3.new(R.x1, R.y1, R.z1), Vector3.new(R.x2, R.y2, R.z2)):ExpandToGrid(CELL)
end

local MATERIAL_BY_VALUE: { [number]: Enum.Material } = {}
for _, m in Enum.Material:GetEnumItems() do
	MATERIAL_BY_VALUE[m.Value] = m :: any
end

-- x outermost, then y, then z (the order ReadVoxelChannels' arrays are walked in).
local function encode(arr: any, size: Vector3, fmt: string, f: (any) -> number): string
	local out = table.create(size.X * size.Y * size.Z)
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				out[#out + 1] = string.format(fmt, f(arr[x][y][z]))
			end
		end
	end
	return table.concat(out)
end

local function decode(data: string, size: Vector3, width: number, f: (number) -> any): any?
	if #data ~= size.X * size.Y * size.Z * width then
		return nil
	end
	local arr = table.create(size.X)
	local i = 0
	for x = 1, size.X do
		local col = table.create(size.Y)
		for y = 1, size.Y do
			local row = table.create(size.Z)
			for z = 1, size.Z do
				row[z] = f(tonumber(string.sub(data, i + 1, i + width), 16) :: number)
				i += width
			end
			col[y] = row
		end
		arr[x] = col
	end
	return arr
end

local function q(v: number): number
	return math.floor(math.clamp(v, 0, 1) * 255 + 0.5)
end

-- Slots 28 to 31: our variant when it exists, else the plain base with the palette tint.
local function ensureSlots(): number
	local n = 0
	for _, s in MaterialKit.SLOTS do
		if s.slot >= 28 and s.slot <= 31 then
			if MaterialService:FindFirstChild(s.variant) then
				workspace.Terrain:SetMaterialSlot(s.slot, s.base, s.variant, s.tint)
			else
				workspace.Terrain:SetMaterialSlot(s.slot, s.base, "", CreekDress.FALLBACK[s.slot] or s.tint)
			end
			n += 1
		end
	end
	return n
end

type TerrainCounts = { columns: number, skippedPath: number, painted: number }

local function reshape(folder: Folder): TerrainCounts
	local t = workspace.Terrain
	local reg = region()
	local lo = reg.CFrame.Position - reg.Size / 2
	local ch = t:ReadVoxelChannels(reg, CELL, { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" }) :: any
	local idxCh = t:ReadVoxelChannels(reg, CELL, { "SolidMaterialIndex" }) :: any
	local size = ch.Size :: Vector3
	local mats, occ, liq, idx = ch.SolidMaterial, ch.SolidOccupancy, ch.LiquidOccupancy, idxCh.SolidMaterialIndex

	-- The record, before anything changes.
	local rec = Instance.new("Folder")
	rec.Name = "TerrainRecord"
	rec:SetAttribute("Lo", reg.CFrame.Position - reg.Size / 2)
	rec:SetAttribute("Hi", reg.CFrame.Position + reg.Size / 2)
	for name, data in {
		Mat = encode(mats, size, "%04x", function(m: any): number
			return m.Value
		end),
		Occ = encode(occ, size, "%02x", q),
		Liq = encode(liq, size, "%02x", q),
		Idx = encode(idx, size, "%02x", function(v: any): number
			return v
		end),
	} do
		local sv = Instance.new("StringValue")
		sv.Name = name
		sv.Value = data
		sv.Parent = rec
	end
	rec.Parent = folder

	local counts: TerrainCounts = { columns = 0, skippedPath = 0, painted = 0 }
	local paint: { { x: number, z: number, slot: number, h: number } } = {}
	for ix = 1, size.X do
		local cx = lo.X + (ix - 0.5) * CELL
		for iz = 1, size.Z do
			local cz = lo.Z + (iz - 0.5) * CELL
			local D = CreekPlan.D(cx, cz)
			if D < CreekPlan.TOUCH then
				local path = false
				local existing = lo.Y
				local topMat: Enum.Material = Enum.Material.Ground
				for iy = 1, size.Y do
					if idx[ix][iy][iz] == CreekDress.FOOTPATH_SLOT and occ[ix][iy][iz] > 0 then
						path = true
					end
					if occ[ix][iy][iz] > 0 then
						existing = lo.Y + (iy - 1) * CELL + occ[ix][iy][iz] * CELL
						topMat = mats[ix][iy][iz]
					end
				end
				if path then
					counts.skippedPath += 1
				else
					local h = CreekPlan.blend(CreekPlan.height(cx, cz, D), existing, D)
					for iy = 1, size.Y do
						local y0 = lo.Y + (iy - 1) * CELL
						local o = math.clamp((h - y0) / CELL, 0, 1)
						if o > 0 and occ[ix][iy][iz] <= 0 then
							mats[ix][iy][iz] = topMat -- new ground takes the column's top material
						elseif o <= 0 then
							mats[ix][iy][iz] = Enum.Material.Air
						end
						occ[ix][iy][iz] = o
						liq[ix][iy][iz] = if o < 1 and y0 + CELL <= 0.01 then 1 else 0 -- the surface is y 0
					end
					counts.columns += 1
					local slot = CreekPlan.slotAt(cx, cz, h, D)
					if slot then
						table.insert(paint, { x = ix, z = iz, slot = slot, h = h })
					end
				end
			end
		end
	end
	t:WriteVoxelChannels(reg, CELL, { SolidMaterial = mats, SolidOccupancy = occ, LiquidOccupancy = liq })

	-- Paint by slot index: the solid cells in the top 5 studs of each painted column.
	local after = t:ReadVoxelChannels(reg, CELL, { "SolidMaterialIndex", "SolidOccupancy" }) :: any
	local idx2, occ2 = after.SolidMaterialIndex, after.SolidOccupancy
	for _, p in paint do
		for iy = 1, size.Y do
			local y0 = lo.Y + (iy - 1) * CELL
			if occ2[p.x][iy][p.z] > 0 and y0 + CELL > p.h - 5 then
				idx2[p.x][iy][p.z] = p.slot
				counts.painted += 1
			end
		end
	end
	t:WriteVoxelChannels(reg, CELL, { SolidMaterialIndex = idx2 })
	return counts
end

-- Writes the record back. False when it does not match its region.
local function restoreTerrain(folder: Instance): boolean
	local rec = folder:FindFirstChild("TerrainRecord")
	if not rec then
		return false
	end
	local lo, hi = rec:GetAttribute("Lo"), rec:GetAttribute("Hi")
	if typeof(lo) ~= "Vector3" or typeof(hi) ~= "Vector3" then
		warn("[CreekDress] terrain record has no region; terrain left as it is")
		return false
	end
	local reg = Region3.new(lo :: Vector3, hi :: Vector3):ExpandToGrid(CELL)
	local size = (reg.Size / CELL) :: Vector3
	local function value(name: string): string
		local v = rec:FindFirstChild(name)
		return if v and v:IsA("StringValue") then v.Value else ""
	end
	local mats = decode(value("Mat"), size, 4, function(n: number): any
		return MATERIAL_BY_VALUE[n] or Enum.Material.Air
	end)
	local occ = decode(value("Occ"), size, 2, function(n: number): any
		return n / 255
	end)
	local liq = decode(value("Liq"), size, 2, function(n: number): any
		return n / 255
	end)
	local idx = decode(value("Idx"), size, 2, function(n: number): any
		return n
	end)
	if not (mats and occ and liq and idx) then
		warn("[CreekDress] terrain record does not match its region; terrain left as it is")
		return false
	end
	local t = workspace.Terrain
	t:WriteVoxelChannels(reg, CELL, { SolidMaterial = mats, SolidOccupancy = occ, LiquidOccupancy = liq })
	t:WriteVoxelChannels(reg, CELL, { SolidMaterialIndex = idx })
	return true
end

-- Repaints slot indexes inside lo..hi: `decide(x, z, slot)` gives a column's solid voxel its new
-- slot (nil: leave it). `depth` studs under the column's top are considered (math.huge: all of
-- it). Every change is recorded in folder.SlotRecords.<name> ("ix,iy,iz,old;") for revert.
local function repaint(folder: Folder, name: string, lo: Vector3, hi: Vector3, depth: number, decide: (number, number, number) -> number?): number
	local t = workspace.Terrain
	local reg = Region3.new(lo, hi):ExpandToGrid(CELL)
	local base = reg.CFrame.Position - reg.Size / 2
	local ch = t:ReadVoxelChannels(reg, CELL, { "SolidMaterialIndex", "SolidOccupancy" }) :: any
	local idx, occ = ch.SolidMaterialIndex, ch.SolidOccupancy
	local size = ch.Size :: Vector3
	local rec: { string } = {}
	for ix = 1, size.X do
		local cx = base.X + (ix - 0.5) * CELL
		for iz = 1, size.Z do
			local cz = base.Z + (iz - 0.5) * CELL
			local top = -math.huge
			for iy = 1, size.Y do
				if occ[ix][iy][iz] > 0 then
					top = base.Y + (iy - 1) * CELL + occ[ix][iy][iz] * CELL
				end
			end
			if top > -math.huge then
				for iy = 1, size.Y do
					local y0 = base.Y + (iy - 1) * CELL
					if occ[ix][iy][iz] > 0 and y0 + CELL > top - depth then
						local old = idx[ix][iy][iz]
						local new = decide(cx, cz, old)
						if new and new ~= old then
							idx[ix][iy][iz] = new
							table.insert(rec, string.format("%d,%d,%d,%d", ix, iy, iz, old))
						end
					end
				end
			end
		end
	end
	if #rec > 0 then
		t:WriteVoxelChannels(reg, CELL, { SolidMaterialIndex = idx })
	end
	local records = folder:FindFirstChild("SlotRecords") or Instance.new("Folder")
	records.Name = "SlotRecords"
	records.Parent = folder
	local sv = Instance.new("StringValue")
	sv.Name = name
	sv.Value = table.concat(rec, ";")
	sv:SetAttribute("Lo", lo)
	sv:SetAttribute("Hi", hi)
	sv:SetAttribute("Order", #records:GetChildren())
	sv.Parent = records
	return #rec
end

-- Puts the recorded slots back, the last repaint first.
local function restoreSlots(folder: Instance): number
	local records = folder:FindFirstChild("SlotRecords")
	if not records then
		return 0
	end
	local list = records:GetChildren()
	table.sort(list, function(a: Instance, b: Instance): boolean
		return ((a:GetAttribute("Order") or 0) :: number) > ((b:GetAttribute("Order") or 0) :: number)
	end)
	local n = 0
	local t = workspace.Terrain
	for _, sv in list do
		local lo, hi = sv:GetAttribute("Lo"), sv:GetAttribute("Hi")
		if sv:IsA("StringValue") and sv.Value ~= "" and typeof(lo) == "Vector3" and typeof(hi) == "Vector3" then
			local reg = Region3.new(lo :: Vector3, hi :: Vector3):ExpandToGrid(CELL)
			local idx = (t:ReadVoxelChannels(reg, CELL, { "SolidMaterialIndex" }) :: any).SolidMaterialIndex
			for _, e in string.split(sv.Value, ";") do
				local p = string.split(e, ",")
				local ix, iy, iz, old = tonumber(p[1]), tonumber(p[2]), tonumber(p[3]), tonumber(p[4])
				if ix and iy and iz and old then
					idx[ix][iy][iz] = old
					n += 1
				end
			end
			t:WriteVoxelChannels(reg, CELL, { SolidMaterialIndex = idx })
		end
	end
	return n
end

-- N3 review 1: the moss band into the backing forest, and the creek paths as slot 14.
local function paintBands(folder: Folder): (number, number)
	local M = CreekPlan.MOSS_REGION
	local moss = repaint(folder, "Moss", Vector3.new(M.x1, -16, M.z1), Vector3.new(M.x2, 40, M.z2), 5, function(x: number, z: number, slot: number): number?
		if CreekPlan.MOSS_OVER[slot] and CreekPlan.mossBand(x, z, CreekPlan.D(x, z)) then
			return CreekPlan.SLOT.MOSS
		end
		return nil
	end)
	local x1, x2, z1, z2 = math.huge, -math.huge, math.huge, -math.huge
	for _, b in CreekPlan.PATH_BOXES do
		x1, x2, z1, z2 = math.min(x1, b.x1), math.max(x2, b.x2), math.min(z1, b.z1), math.max(z2, b.z2)
	end
	local path = repaint(folder, "Path", Vector3.new(x1, -16, z1), Vector3.new(x2, 16, z2), math.huge, function(x: number, z: number, slot: number): number?
		if slot ~= CreekDress.FOOTPATH_SLOT then
			return nil
		end
		for _, b in CreekPlan.PATH_BOXES do
			if Scatter.inBox(b, x, z) then
				return CreekPlan.PATH_SLOT
			end
		end
		return nil
	end)
	return moss, path
end

---------------------------------------------------------------------------------------------
-- Props
---------------------------------------------------------------------------------------------

local function groundY(params: RaycastParams, x: number, z: number): number?
	local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -160, 0), params)
	return if hit then hit.Position.Y else nil
end

local function dressParts(m: Model, shadow: boolean)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = shadow
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
end

local function inCreekBox(p: Vector3): boolean
	local b = Scatter.CREEK_BOX
	return p.X >= b.x1 and p.X <= b.x2 and p.Z >= b.z1 and p.Z <= b.z2
end

local function visible(m: Instance): boolean
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			return true
		end
	end
	return false
end

-- The creek's boulders: RockLarge and RockMedium copies in the creek box (not ours, not
-- CreekSwap's) and any visible gray-box Boulder part. Each with its bounding box.
local function boulders(lake: Instance, own: Instance): { { root: Instance, cf: CFrame, size: Vector3 } }
	local out = {}
	for _, d in lake:GetDescendants() do
		if d:IsDescendantOf(own) then
			continue
		end
		if d:IsA("Model") and (d.Name == "RockLarge" or d.Name == "RockMedium") and inCreekBox(d:GetPivot().Position) and visible(d) then
			local cf, size = d:GetBoundingBox()
			table.insert(out, { root = d :: Instance, cf = cf, size = size })
		elseif d:IsA("BasePart") and string.match(d.Name, "^Boulder%d+$") and d.Transparency < 1 and inCreekBox(d.Position) then
			table.insert(out, { root = d :: Instance, cf = d.CFrame, size = d.Size })
		end
	end
	return out
end

local function wetSlate(root: Instance): number
	if not MaterialService:FindFirstChild("WetSlate") then
		return 0
	end
	local parts: { BasePart } = {}
	if root:IsA("BasePart") then
		table.insert(parts, root)
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	for _, p in parts do
		if p:GetAttribute(ORIG_MAT) == nil then
			p:SetAttribute(ORIG_MAT, p.Material.Name)
			p:SetAttribute(ORIG_VARIANT, p.MaterialVariant)
		end
		p.Material = Enum.Material.Slate
		p.MaterialVariant = "WetSlate"
	end
	return #parts
end

export type Result = {
	slots: number,
	columns: number, -- terrain columns reshaped
	skippedPath: number, -- columns left alone because they hold footpath gravel
	painted: number, -- voxels painted with a creek slot
	placed: { [string]: number },
	missing: { string }, -- kit models not in ServerStorage.Art (skipped)
	missingCount: number,
	noGround: number,
	lite: number,
	rockMats: number, -- moss mats laid on boulders
	rocksSlate: number, -- rock parts given the WetSlate variant
	triangles: number, -- the plan's estimate (CreekPlan.plan(...).triangles)
	coverage: number, -- share of the riffle and run water under a crown (CreekPlan.coverage)
	riffleCoverage: number, -- share of the riffle's water under a crown or a bough (N3 review 1)
	mossPainted: number, -- voxels of the moss band past D 7 (N3 review 1)
	pathPainted: number, -- path voxels re-laid as slot 14
	pathParts: number, -- old path parts given the FootpathGravel variant
	boughs: number, -- CedarBough sprays hung
	emergent: number, -- wet-slate rocks placed on the riffle
}

export type RevertResult = { terrain: boolean, rocks: number, slots: number }

function CreekDress.revert(lake: Instance): RevertResult
	local folder = lake:FindFirstChild(CreekDress.FOLDER)
	local terrain = false
	local slots = 0
	if folder then
		slots = restoreSlots(folder) -- the moss band and the paths first, then the region's record
		terrain = restoreTerrain(folder)
		folder:Destroy()
	end
	local rocks = 0
	for _, d in lake:GetDescendants() do
		if d:IsA("BasePart") then
			local m = d:GetAttribute(ORIG_MAT)
			if type(m) == "string" then
				d.Material = (Enum.Material :: any)[m]
				d.MaterialVariant = (d:GetAttribute(ORIG_VARIANT) :: string?) or ""
				d:SetAttribute(ORIG_MAT, nil)
				d:SetAttribute(ORIG_VARIANT, nil)
				rocks += 1
			end
		end
	end
	return { terrain = terrain, rocks = rocks, slots = slots }
end

-- The old straight creek paths (WorldBuilder's PathToCreek and BankPath, Sand): FootpathGravel
-- like the re-laid paths (N3 review 1). Revert puts their material back (ORIG_MAT).
local function skinPaths(lake: Instance): number
	if not MaterialService:FindFirstChild("FootpathGravel") then
		return 0
	end
	local creek = lake:FindFirstChild("CedarCreek")
	local n = 0
	for _, name in { "PathToCreek", "BankPath" } do
		local p = creek and creek:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			if p:GetAttribute(ORIG_MAT) == nil then
				p:SetAttribute(ORIG_MAT, p.Material.Name)
				p:SetAttribute(ORIG_VARIANT, p.MaterialVariant)
			end
			p.Material = Enum.Material.Ground
			p.MaterialVariant = "FootpathGravel"
			n += 1
		end
	end
	return n
end

function CreekDress.apply(lake: Instance, seed: number?): Result
	if lake:FindFirstChild(CreekDress.FOLDER) then
		CreekDress.revert(lake)
	end
	local s = seed or CreekPlan.SEED
	local folder = Instance.new("Folder")
	folder.Name = CreekDress.FOLDER
	folder:SetAttribute("Seed", s)
	folder.Parent = lake

	lakeArt = lake:FindFirstChild("Art")
	local slots = ensureSlots()
	local tc = reshape(folder)
	local mossPainted, pathPainted = paintBands(folder)

	local plan = CreekPlan.plan(s)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = true

	local groups: { [string]: Folder } = {}
	local function groupFolder(name: string): Folder
		local g = groups[name]
		if not g then
			g = Instance.new("Folder")
			g.Name = name
			g.Parent = folder
			groups[name] = g
		end
		return g :: Folder
	end

	local res: Result = {
		slots = slots,
		columns = tc.columns,
		skippedPath = tc.skippedPath,
		painted = tc.painted,
		placed = {},
		missing = {},
		missingCount = 0,
		noGround = 0,
		lite = 0,
		rockMats = 0,
		rocksSlate = 0,
		triangles = plan.triangles,
		coverage = plan.coverage,
		riffleCoverage = plan.riffleCoverage,
		mossPainted = mossPainted,
		pathPainted = pathPainted,
		pathParts = skinPaths(lake),
		boughs = 0,
		emergent = 0,
	}
	local missingSet: { [string]: boolean } = {}
	local alt: { [string]: number } = {}

	local function place(model: string, group: string, cf: CFrame, scale: number, shadow: boolean, parent: Instance?): Model?
		local tpl, isLite = template(model)
		if not tpl then
			if not missingSet[model] then
				missingSet[model] = true
				table.insert(res.missing, model)
			end
			res.missingCount += 1
			return nil
		end
		local m = tpl:Clone()
		m.Name = model
		m:ScaleTo(scale)
		m:PivotTo(cf)
		dressParts(m, shadow)
		local tag = TAGS[group]
		if tag then
			CollectionService:AddTag(m, tag)
			local c = (alt[tag] or 0) + 1
			alt[tag] = c
			m:SetAttribute("FoliageAlt", c % 2)
		end
		m.Parent = parent or groupFolder(group)
		res.placed[model] = (res.placed[model] or 0) + 1
		if isLite then
			res.lite += 1
		end
		return m
	end

	local placedAt: { [number]: Model } = {}
	for i, it in plan.items do
		local bury = (CreekPlan.KIT[it.model] or 0) * it.scale
		local y: number?
		if it.model == "CedarBough" then
			-- Hung from its cedar, inside the cedar's model (pivot at the bough's base, spray
			-- along its -X; skipped with its tree, or while the model is not in Art).
			local tree = it.parent and placedAt[it.parent]
			local g = tree and groundY(params, it.footX :: number, it.footZ :: number)
			if tree and g then
				local cf = CFrame.new(it.x, g + (it.lift :: number), it.z) * CFrame.Angles(0, it.yaw, 0)
				if place(it.model, it.group, cf, it.scale, it.shadow, tree) then
					res.boughs += 1
				end
			end
			continue
		elseif it.group == "Rocks" then
			-- An emergent rock: its top just out of the water (y 0), wet slate all over.
			local m = place(it.model, it.group, CFrame.new(it.x, 0, it.z) * CFrame.Angles(0, it.yaw, 0), it.scale, it.shadow)
			if m then
				local cf, size = m:GetBoundingBox()
				local top = 0.3 + 0.2 * (it.r or 1)
				m:PivotTo(m:GetPivot() + Vector3.new(0, top - (cf.Position.Y + size.Y / 2), 0))
				wetSlate(m)
				res.emergent += 1
			end
			continue
		elseif it.ends then
			local e = it.ends
			local g1, g2 = groundY(params, e[1], e[2]), groundY(params, e[3], e[4])
			y = if g1 and g2 then (g1 + g2) / 2 - bury else nil
		elseif it.lipX and it.lipZ then
			local g = groundY(params, it.lipX, it.lipZ)
			y = if g then g - bury else nil
		else
			local g = groundY(params, it.x, it.z)
			y = if g then g - bury else nil
			if g and it.tilt then
				-- A bank tree leans out over the water (its -X) about the trunk's foot on the ground.
				local foot = CFrame.new(it.x, g, it.z) * CFrame.Angles(0, it.yaw, 0) * CFrame.Angles(0, 0, it.tilt)
				local m = place(it.model, it.group, foot * CFrame.new(0, -bury, 0), it.scale, it.shadow)
				if m then
					placedAt[i] = m
				end
				continue
			end
		end
		if y == nil then
			res.noGround += 1
		else
			local m = place(it.model, it.group, CFrame.new(it.x, y, it.z) * CFrame.Angles(0, it.yaw, 0), it.scale, it.shadow)
			if m then
				placedAt[i] = m
			end
		end
	end

	-- Moss on the boulders, and wet slate on their sides.
	local rng = Scatter.rng(s + 9)
	local mossTpl = template("MossMat")
	for _, b in boulders(lake, folder) do
		local top = b.cf.Position.Y + b.size.Y / 2
		if top > 0.3 then -- above the water
			if mossTpl then
				local ext = mossTpl:GetExtentsSize()
				local sc = math.clamp(math.min(b.size.X / ext.X, b.size.Z / ext.Z) * 0.8, 0.25, 1.6)
				local y = top - CreekPlan.KIT.MossMat * sc - 0.1 - 0.12 * b.size.Y
				local yaw = Scatter.range(rng, 0, 2 * math.pi)
				if place("MossMat", "Moss", CFrame.new(b.cf.Position.X, y, b.cf.Position.Z) * CFrame.Angles(0, yaw, 0), sc, false) then
					res.rockMats += 1
				end
			else
				res.missingCount += 1
			end
		end
		res.rocksSlate += wetSlate(b.root)
	end
	return res
end

return CreekDress
