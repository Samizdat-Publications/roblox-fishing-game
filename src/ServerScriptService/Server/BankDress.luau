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
--
-- N1 round 4 (the advisor's ruling after review 2):
--  * the gravel was baked in: the terrain record had been taken again over round 2's paint, so
--    revert put the old gravel back as if it were the original ground. BankDress.cleanGravel
--    (once) clears it, `apply` refuses to paint while gravel lies outside the current paths (a
--    baked record), the kit folder is parented before anything is placed (so a failed apply still
--    leaves its record), and `revert` reports `gravelOutside` (the main session asserts 0);
--  * the paint itself lives in Scatter.paintGrid (pure, so the specs run it): it also repaints the
--    sand ring's far side as meadow and lays the green floor (slot 27) behind the north shore;
--  * the old trees swap by distance to the dock: kit trees within 90 studs (40 at most);
--  * far models carry a FoliageFar attribute, with their own FoliageAlt count, for the phone tier.
--
--   require(game.ServerScriptService.Server.BankDress).cleanGravel(workspace.Lake)
--   require(game.ServerScriptService.Server.BankDress).undoClean() -- right after, if needed
--
-- Gemini's review 1.2 (11/27/2026): a group "Seams" of low ferns, a few low bushes and flat shore
-- stones along the borders between ground slots (gravel, forest floor, meadow, sand, wet sand),
-- from the painted grid (Scatter.seams), about 15k triangles, tagged FoliageUnder.
--
-- N1 close-out (the advisor's review 3): far pines along the bare hill crests on shots 03 and 08's
-- horizons (Scatter.crestPines, group CrestPines, no shadows); the dock foot's meadow repainted to
-- sand, with a few stones and a reed clump each side (FootStones, FootReeds); every reed clump on
-- ground more than 0.3 over the water moved into the wet band or sunk 0.5 more (Scatter.seatReeds).
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

-- The old trees: kit trees within this far of the dock (N1 round 4: was 120 from the lake loop;
-- the blob trees left of the pond in shot 08 stayed far models), nearest first, at most NEAR_CAP
-- of them; far trees 1:1 everywhere else.
BankDress.NEAR = 90
BankDress.NEAR_CAP = 40

-- The paint region: the lake loop, the treeline band, the far row and its forest floor, the
-- walk and the lawn's meadow, and the creek paths (N1 round 2: was x -212..160, z -128..96).
BankDress.REGION_LO = Vector3.new(-212, -8, -150)
BankDress.REGION_HI = Vector3.new(180, 8, 140)

-- Terrain slots the hill patches may cover (2 Grass/meadow, 19 LeafyGrass, 26 the bladeless
-- lawn). The main paint's rules are Scatter.paintGrid's.
local FOREST_OVER = Scatter.GROUND_OVER

-- The south lawn for cleanGravel: the old GroundSouth part's box (x -160..160, z 80..140), read
-- from Lake.GroundSouth when it is there.
BankDress.LAWN_LO = Vector3.new(-160, 0, 85)
BankDress.LAWN_HI = Vector3.new(160, 0, 145)
BankDress.CLEAN_RECORD = "BankDressCleanRecord" -- in ServerStorage: the ground before cleanGravel

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

-- Every voxel's slot, two hex digits each, x outermost, then y, then z (the order
-- ReadVoxelChannels' arrays are walked in).
local function hexRecord(idx: any, nx: number, ny: number, nz: number): string
	local record = table.create(nx * ny * nz)
	for x = 1, nx do
		for y = 1, ny do
			for z = 1, nz do
				record[#record + 1] = string.format("%02x", idx[x][y][z])
			end
		end
	end
	return table.concat(record)
end

-- The paint region's voxels as a Scatter.Grid.
local function readGrid(): (Scatter.Grid, Region3)
	local region = Region3.new(BankDress.REGION_LO, BankDress.REGION_HI):ExpandToGrid(CELL)
	local lo = region.CFrame.Position - region.Size / 2
	local ch = workspace.Terrain:ReadVoxelChannels(region, CELL, { "SolidMaterialIndex", "SolidOccupancy" }) :: any
	local size = ch.Size :: Vector3
	local g: Scatter.Grid = {
		idx = ch.SolidMaterialIndex,
		occ = ch.SolidOccupancy,
		nx = size.X,
		ny = size.Y,
		nz = size.Z,
		ix0 = math.floor(lo.X / CELL + 0.5),
		iz0 = math.floor(lo.Z / CELL + 0.5),
		cell = CELL,
	}
	return g, region
end

-- Repaints the region's voxels (Scatter.paintGrid: footpaths, forest floor, meadow blobs, the
-- green floor behind the north shore, the sand ring's far side). Returns the counts and the
-- record of every voxel's original slot, and the painted grid (for the seams).
local function paint(plan: Scatter.Plan, seed: number, tuning: { [string]: any }?): (Scatter.PaintCounts, string, Region3, Scatter.Grid)
	local g, region = readGrid()
	local record = hexRecord(g.idx, g.nx, g.ny, g.nz)
	local counts = Scatter.paintGrid(g, plan, seed, tuning)
	workspace.Terrain:WriteVoxelChannels(region, CELL, { SolidMaterialIndex = g.idx })
	return counts, record, region, g
end

-- Slot 24 voxels in the paint region outside the footpath cells of `seed`'s plan.
function BankDress.gravelOutsidePaths(seed: number?): number
	local s = seed or BankDress.SEED
	local g = readGrid()
	return Scatter.countSlot(g, BankDress.FOOTPATH_SLOT, Scatter.pathCells(Scatter.homeRoutes(s), CELL, s))
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
	local record = hexRecord(idx, size.X, size.Y, size.Z)
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

-- Puts back every voxel in a record's region that still holds one of `slots` (every voxel when
-- nil), from the record. Second result: false when the record does not match its region.
local function restore(rec: StringValue, slots: { [number]: boolean }?): (number, boolean)
	local lo, hi = rec:GetAttribute("Lo"), rec:GetAttribute("Hi")
	if typeof(lo) ~= "Vector3" or typeof(hi) ~= "Vector3" then
		warn("[BankDress] terrain record " .. rec.Name .. " has no region; terrain left as it is")
		return 0, false
	end
	local t = workspace.Terrain
	local region = Region3.new(lo :: Vector3, hi :: Vector3):ExpandToGrid(CELL)
	local ch = t:ReadVoxelChannels(region, CELL, { "SolidMaterialIndex" }) :: any
	local idx = ch.SolidMaterialIndex
	local size = ch.Size :: Vector3
	local data = rec.Value
	if #data ~= size.X * size.Y * size.Z * 2 then
		warn("[BankDress] terrain record " .. rec.Name .. " does not match its region; terrain left as it is")
		return 0, false
	end
	local n, i = 0, 0
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				i += 1
				local s = idx[x][y][z]
				if slots == nil or slots[s] then
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
	return n, true
end

-- The slots the main paint writes (footpath, forest floor, meadow, the north shore's green floor,
-- and since the N1 close-out dry and wet sand: the dock foot's meadow goes back to sand). A revert
-- puts back any voxel of these slots that differs from the record, so a WaterLook or wet band rerun
-- after apply is undone there too: rerun those after a revert, not between apply and revert.
local MAIN_SLOTS = {
	[BankDress.FOOTPATH_SLOT] = true,
	[BankDress.FOREST_SLOT] = true,
	[BankDress.MEADOW_SLOT] = true,
	[BankDress.HILL_SLOT] = true,
	[Scatter.SLOT.SAND] = true,
	[Scatter.SLOT.WET_SAND] = true,
}

-- Undoes the hill patches (newest first, so overlapping patches end on the true original), then
-- the main region. Second result: false when any record failed to match.
local function unpaint(folder: Instance): (number, boolean)
	local n, ok = 0, true
	local hills = folder:FindFirstChild("HillRecords")
	if hills then
		local list = hills:GetChildren()
		table.sort(list, function(a, b)
			return a.Name > b.Name
		end)
		for _, rec in list do
			if rec:IsA("StringValue") then
				local m, good = restore(rec, { [BankDress.HILL_SLOT] = true })
				n += m
				ok = ok and good
			end
		end
	end
	local rec = folder:FindFirstChild("TerrainRecord")
	if rec and rec:IsA("StringValue") then
		local m, good = restore(rec, MAIN_SLOTS)
		n += m
		ok = ok and good
	else
		warn("[BankDress] the kit folder has no TerrainRecord")
		ok = false
	end
	return n, ok
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
	sandVoxels: number, -- the sand ring's far side, repainted meadow (N1 round 4)
	northVoxels: number, -- the green floor behind the north shore (N1 round 4)
	farTagged: number, -- copies of far models (FoliageFar)
	seamEdges: number, -- borders between ground slots in the painted grid (Scatter.seams)
	seamItems: number, -- seam plants and stones placed (group Seams)
	seamTris: number, -- their planned triangles (Scatter.SEAM_TRIS; the budget is 15k)
	crestPines: number, -- far pines on the shots' horizon crests (Scatter.crestPines)
	crestRays: { [string]: number }, -- per crest view, the rays that found a hill crest
	reedsMoved: number, -- reed clumps on dry ground moved into the wet band (Scatter.seatReeds)
	reedsSunk: number, -- and those sunk REED_SINK more instead
	dockSandVoxels: number, -- the dock foot's meadow voxels put back to sand
}

export type RevertResult = {
	voxels: number,
	unhidden: number,
	ok: boolean, -- false: a terrain record did not match; the kit folder is left in place
	gravelOutside: number, -- slot 24 voxels in the paint region outside the paths (must be 0)
}

-- Takes the dress pass off. When a terrain record does not match its region, nothing more is
-- touched (the kit folder and the hidden parts stay, so the records are not lost) and `ok` is
-- false. `gravelOutside` is counted for the seed the kit was applied with.
function BankDress.revert(lake: Instance): RevertResult
	local folder = lake:FindFirstChild(BankDress.FOLDER)
	local voxels, ok = 0, true
	local seed = BankDress.SEED
	if folder then
		local fs = folder:GetAttribute("Seed")
		if type(fs) == "number" then
			seed = fs
		end
		voxels, ok = unpaint(folder)
		if ok then
			folder:Destroy()
		else
			warn("[BankDress] revert: a terrain record did not match; the kit folder is kept")
		end
	end
	local unhidden = if ok then unhide(lake) else 0
	return { voxels = voxels, unhidden = unhidden, ok = ok, gravelOutside = BankDress.gravelOutsidePaths(seed) }
end

-- The south lawn test for cleanGravel: inside the old GroundSouth part's box.
local function lawnTest(lake: Instance): (number, number) -> boolean
	local lo, hi = BankDress.LAWN_LO, BankDress.LAWN_HI
	local p = lake:FindFirstChild("GroundSouth")
	if p and p:IsA("BasePart") then
		lo = p.Position - p.Size / 2
		hi = p.Position + p.Size / 2
	end
	return function(x: number, z: number): boolean
		return x >= lo.X and x <= hi.X and z >= lo.Z and z <= hi.Z
	end
end

export type CleanResult = {
	outside: number, -- slot 24 outside the paths, back to lawn or meadow
	deep: number, -- slot 24 under a path's surface (unbake)
	forest: number, -- slot 25 anywhere in the region (unbake)
	lawnMeadow: number, -- slot 2 on the south lawn, back to lawn (unbake)
	left: number, -- slot 24 still outside the paths afterwards (0)
	reverted: boolean, -- the kit was on and was taken off first
}

-- (N1 round 4, run once) Clears the paint baked into the ground by the round 2 record. Takes the
-- kit off first if it is on (refuses if that revert fails). Every slot 24 voxel in the paint
-- region outside `seed`'s footpath cells goes back to the lawn (26) on the south lawn, else to
-- meadow (2). With `unbake` (default true) it also clears the gravel under the paths' surface,
-- every forest-floor voxel (25) and the meadow (2) on the south lawn, all of which only BankDress
-- paints, so the next apply records clean ground; with `unbake` false it follows the advisor's
-- rule to the letter (25 inside the forest blobs, nothing else). The ground before it is kept in
-- ServerStorage.BankDressCleanRecord: BankDress.undoClean() right after puts it back.
function BankDress.cleanGravel(lake: Instance, seed: number?, unbake: boolean?): CleanResult
	local s = seed or BankDress.SEED
	local reverted = false
	if lake:FindFirstChild(BankDress.FOLDER) then
		local r = BankDress.revert(lake)
		if not r.ok then
			error("[BankDress] cleanGravel: the revert failed (a terrain record does not match); nothing cleaned")
		end
		reverted = true
	end
	local deep = unbake ~= false
	local g, region = readGrid()
	local old = ServerStorage:FindFirstChild(BankDress.CLEAN_RECORD)
	if old then
		old:Destroy()
	end
	local rec = Instance.new("StringValue")
	rec.Name = BankDress.CLEAN_RECORD
	rec.Value = hexRecord(g.idx, g.nx, g.ny, g.nz)
	rec:SetAttribute("Lo", region.CFrame.Position - region.Size / 2)
	rec:SetAttribute("Hi", region.CFrame.Position + region.Size / 2)
	rec.Parent = ServerStorage
	local paths = Scatter.pathCells(Scatter.homeRoutes(s), CELL, s)
	local forest = if deep then nil else Scatter.blobCells(Scatter.homeLake(s).forest, CELL, s)
	local c = Scatter.cleanGrid(g, { paths = paths, forest = forest, lawn = lawnTest(lake), unbake = deep })
	workspace.Terrain:WriteVoxelChannels(region, CELL, { SolidMaterialIndex = g.idx })
	return {
		outside = c.outside,
		deep = c.deep,
		forest = c.forest,
		lawnMeadow = c.lawnMeadow,
		left = Scatter.countSlot(g, BankDress.FOOTPATH_SLOT, paths),
		reverted = reverted,
	}
end

-- Puts the ground back as it was before the last cleanGravel (only right after it: it restores
-- every voxel of the region from the record). Returns the voxels changed.
function BankDress.undoClean(): number
	local rec = ServerStorage:FindFirstChild(BankDress.CLEAN_RECORD)
	if not (rec and rec:IsA("StringValue")) then
		return 0
	end
	return (restore(rec, nil))
end

-- Paints and places the dress pass. If the kit is already on, it is reverted first, and apply
-- stops with an error if that revert fails or if slot 24 gravel lies outside this seed's paths
-- afterwards (a baked terrain record: run BankDress.cleanGravel first), so a record is never
-- taken over paint.
function BankDress.apply(lake: Instance, seed: number?, tuning: { [string]: any }?): Result
	local s = seed or BankDress.SEED
	if lake:FindFirstChild(BankDress.FOLDER) then
		local r = BankDress.revert(lake)
		if not r.ok then
			error("[BankDress] apply: the revert failed (a terrain record does not match); nothing applied")
		end
	end
	local left = BankDress.gravelOutsidePaths(s)
	if left > 0 then
		error(string.format("[BankDress] apply: %d footpath voxels (slot 24) lie outside this seed's paths, so the ground holds baked paint; run BankDress.cleanGravel(workspace.Lake) first", left))
	end
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
	local pc, record, region, painted = paint(plan, s, tuning)
	local rec = Instance.new("StringValue")
	rec.Name = "TerrainRecord"
	rec.Value = record
	rec:SetAttribute("Lo", region.CFrame.Position - region.Size / 2)
	rec:SetAttribute("Hi", region.CFrame.Position + region.Size / 2)
	rec.Parent = folder
	local hillRecords = Instance.new("Folder")
	hillRecords.Name = "HillRecords"
	hillRecords.Parent = folder
	-- (N1 round 4) In the world before anything else can fail, so the record is never lost (a
	-- lost record is how paint gets baked in: the next apply takes the painted ground as original).
	folder.Parent = lake

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
	local noGround, total, liteCount, farTagged = 0, 0, 0, 0

	-- Places one item; returns the copy (nil if its model is missing or there is no ground).
	local function placeItem(it: Scatter.Item, countMissing: boolean): Model?
		local tpl, isLite = template(lake, it.model)
		if not tpl then
			if countMissing then
				missingSet[it.model] = true
			end
			return nil
		end
		local bury = (Scatter.KIT[it.model] or 0) * it.scale + (it.sink or 0)
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
			-- Far models count their own every-second, so the phone tier drops half of them.
			local far = Scatter.isFar(it.model)
			local key = if far then tag .. ":far" else tag
			local c = (altCount[key] or 0) + 1
			altCount[key] = c
			m:SetAttribute("FoliageAlt", c % 2)
			if far then
				m:SetAttribute("FoliageFar", true)
				farTagged += 1
			end
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

	-- (N1 close-out) Reed clumps on ground more than Scatter.REED_DRY over the water move into the
	-- wet band or sink a little more (shot 05's cattails on dry sand).
	local reedsMoved, reedsSunk = Scatter.seatReeds(plan.items, function(x: number, z: number): number?
		return groundY(params, x, z)
	end)
	for _, it in plan.items do
		placeItem(it, true)
	end

	-- (Gemini's review 1.2) Ferns, a few low bushes and flat stones along the borders between
	-- ground slots, read from the grid just painted. Tagged FoliageUnder (Scatter.TAGS.Seams).
	local seamItems, seamInfo = Scatter.seams(painted, plan, s, tuning)
	local nSeams = 0
	for _, it in seamItems do
		if placeItem(it, true) then
			nSeams += 1
		end
	end

	-- (N1 close-out) Far pines along the bare hill crests on the shots' horizons (03 north, 08 at
	-- both edges). No shadows, tagged FoliageTree and FoliageFar like every far model.
	local crestItems, crestInfo = Scatter.crestPines(s, dryHeight, tuning)
	local nCrest = 0
	local crestRays: { [string]: number } = {}
	for id, ci in crestInfo do
		crestRays[id] = ci.rays
	end
	for _, it in crestItems do
		if placeItem(it, true) then
			nCrest += 1
		end
	end

	-- The hill pines and the green forest floor under them (kept clear of the crest pines).
	local hillItems, hillBlobs = Scatter.hillPines(s, dryHeight, tuning, crestItems)
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

	-- The old Scenery trees, nearest the dock first (N1 round 4: was nearest the lake): kit trees
	-- within NEAR of the dock (40 at most), far trees 1:1 everywhere else. A tree is hidden only
	-- once its replacement stands.
	local pidx = Scatter.pathIndex(plan.routes)
	local pcells = Scatter.pathCells(plan.routes, CELL, s)
	local standing: { Scatter.Pt } = {}
	for _, it in plan.items do
		if Scatter.TAGS[it.group] == "FoliageTree" then
			table.insert(standing, { x = it.x, z = it.z })
		end
	end
	for _, it in hillItems do
		table.insert(standing, { x = it.x, z = it.z })
	end
	for _, it in crestItems do
		table.insert(standing, { x = it.x, z = it.z })
	end
	-- d: distance to the dock (the order and the kit test); rb: to the lake's rounded box (the
	-- hill floor test).
	type Old = { m: Model, x: number, z: number, d: number, rb: number, kind: string, h: number }
	local olds: { Old } = {}
	for _, m in Scenery.oldTrees(lake) do
		if not skipTree[m] then
			local p = m:GetPivot().Position
			local dock = math.sqrt((p.X - Scatter.DOCK.x) ^ 2 + (p.Z - Scatter.DOCK.z) ^ 2)
			table.insert(olds, { m = m, x = p.X, z = p.Z, d = dock, rb = Scatter.roundBox(p.X, p.Z), kind = Scenery.OLD_TREES[m.Name], h = m:GetExtentsSize().Y })
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
		local near = o.d <= BankDress.NEAR and homeLake(Vector3.new(o.x, 0, o.z))
		local yaw = Scatter.range(rt, 0, 2 * math.pi)
		local u = Scatter.next(rt)
		local it: Scatter.Item? = nil
		if near and swapKit < BankDress.NEAR_CAP then
			if Scatter.kept(o.x, o.z, 1) or not Scatter.shotClear(o.x, o.z, true) or Scatter.pathEdge(pidx, o.x, o.z) <= 1.5 or Scatter.onCells(pcells, o.x, o.z, 1.5, CELL) or not Scatter.farEnough(standing, o.x, o.z, 4) then
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
			if g and g >= T.hillMinHeight and o.rb <= T.hillBand[2] then
				nHillVox += paintHill({ x = o.x, z = o.z, r = Scatter.range(rt, 7, 10) }, g, s, hillRecords)
			end
		end
	end

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
		footpathVoxels = pc.path,
		forestVoxels = pc.forest,
		meadowVoxels = pc.meadow,
		hillVoxels = nHillVox,
		sandVoxels = pc.sand,
		northVoxels = pc.north,
		farTagged = farTagged,
		seamEdges = seamInfo.edges,
		seamItems = nSeams,
		seamTris = seamInfo.tris,
		crestPines = nCrest,
		crestRays = crestRays,
		reedsMoved = reedsMoved,
		reedsSunk = reedsSunk,
		dockSandVoxels = pc.dockSand,
	}
end

return BankDress
