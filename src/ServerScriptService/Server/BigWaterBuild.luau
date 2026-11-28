--!strict
-- Big water (leg 3, N5): writes the bigger Big Lake into the place, in Edit, from Shared/BigWater's
-- plan. Run each step from execute_luau after saving the place (the save is the real undo; this
-- module also keeps its own backup so `revert` puts things back without reopening the file):
--
--   local B = require(game.ServerScriptService.Server.BigWaterBuild:Clone()) -- a clone: require caches
--   B.check()        -- dry run: what it will touch, nothing written
--   B.backup()       -- terrain copies (TerrainRegions) of everything it writes, in ServerStorage
--   B.clearDecor()   -- stashes decoration that stood where the new water and banks go
--   B.terrain(1, 10) -- the terrain, chunk by chunk (20 chunks; run 1..10 then 11..20)
--   B.terrain(11, 20)
--   B.hills()        -- a ring of low hills round the rewrite's edge
--   B.markers()      -- rules boxes, zones, walls, the buoy line, the bell buoy, marina anchors, path
--   B.far()          -- ridgelines in the haze and the far land under them (always loaded)
--   B.dress()        -- pines on the banks, headlands and bigger islets; reeds in Lily Cove
--   B.revert()       -- everything back: the terrain pasted from the backup, stashed things restored
--
-- Then Config.BIG_WATER_ON = true in src, pushed with the Shared modules, a playtest, and a save.
-- Never run BoatWorld.build() after this: it rebuilds L7's smaller lake over it.
--
-- What it touches outside its own folders: Terrain over BigWater.CLEAR (and a 48 stud margin, the
-- hills) and along the marina path; workspace.BigLake's Walls (West, East, North), BuoyLine, Zones,
-- Water and BlueWater (stashed and replaced); decoration Models in workspace.Lake and
-- workspace.BigLake.Dressing that stood on the new water or banks (stashed).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local MaterialService = game:GetService("MaterialService")
local CollectionService = game:GetService("CollectionService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigWater = require(Shared:WaitForChild("BigWater"))
local BoatRules = require(Shared:WaitForChild("BoatRules"))
local Config = require(Shared:WaitForChild("Config"))
local Signs = require(script.Parent.Signs)

local BigWaterBuild = {}

local CELL = BigWater.CELL
local GROUND_TOP = 1
local BACKUP = "BigWaterBackup"
local MARGIN = 48 -- the hills reach this far past CLEAR
local MARK = "BigWater" -- attribute on everything this module makes, so revert finds it

type Rect = BigWater.Rect

local COLORS = {
	red = Color3.fromRGB(184, 46, 40),
	green = Color3.fromRGB(40, 116, 66),
	white = Color3.fromRGB(236, 232, 222),
	rowNear = Color3.fromRGB(128, 142, 156),
	rowFar = Color3.fromRGB(152, 166, 180),
	west = Color3.fromRGB(136, 150, 160),
	farLand = Color3.fromRGB(86, 104, 74),
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

local HIDDEN = { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
local DECOR = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }

local function marked<T>(inst: T): T
	(inst :: any):SetAttribute(MARK, true)
	return inst
end

local function backupFolder(): Folder
	local f = ServerStorage:FindFirstChild(BACKUP)
	if not f then
		f = Instance.new("Folder")
		f.Name = BACKUP
		f.Parent = ServerStorage
	end
	for _, name in { "Terrain", "Stash" } do
		if not f:FindFirstChild(name) then
			local sub = Instance.new("Folder")
			sub.Name = name
			sub.Parent = f
		end
	end
	return f :: Folder
end

-- Moves an instance into the backup's Stash, remembering where it came from.
local function stash(inst: Instance, why: string)
	local from = Instance.new("ObjectValue")
	from.Name = "From"
	from.Value = inst.Parent
	from.Parent = inst
	inst:SetAttribute("StashedBy", why)
	inst.Parent = backupFolder():FindFirstChild("Stash")
end

-- The rects the backup covers: CLEAR plus the hills' margin (not south: the home world), tiled
-- like the terrain writes, and the marina path's box.
local function backupRects(): { Rect }
	local c = BigWater.CLEAR
	local big = { x1 = c.x1 - MARGIN, x2 = c.x2 + MARGIN, z1 = c.z1 - MARGIN, z2 = c.z2 }
	local step = BigWater.CHUNK * CELL
	local out = {}
	local z = big.z1
	while z < big.z2 do
		local x = big.x1
		while x < big.x2 do
			table.insert(out, { x1 = x, x2 = math.min(x + step, big.x2), z1 = z, z2 = math.min(z + step, big.z2) })
			x += step
		end
		z += step
	end
	local lo, hi = Vector3.new(math.huge, 0, math.huge), Vector3.new(-math.huge, 0, -math.huge)
	for _, p in BigWater.PATH do
		lo = Vector3.new(math.min(lo.X, p.X), 0, math.min(lo.Z, p.Z))
		hi = Vector3.new(math.max(hi.X, p.X), 0, math.max(hi.Z, p.Z))
	end
	local pad = BigWater.PATH_WIDTH + CELL
	local function snap(v: number, up: boolean): number
		return (if up then math.ceil(v / CELL) else math.floor(v / CELL)) * CELL
	end
	table.insert(out, { x1 = snap(lo.X - pad, false), x2 = snap(hi.X + pad, true), z1 = snap(lo.Z - pad, false), z2 = snap(hi.Z + pad, true) })
	return out
end

local BACKUP_Y1, BACKUP_Y2 = -40, BigWater.CLEAR_TOP

local function art(name: string): Model?
	local lake = workspace:FindFirstChild("Lake")
	local folder = lake and lake:FindFirstChild("Art")
	local m = folder and folder:FindFirstChild(name)
	return if m and m:IsA("Model") then m else nil
end

-- A dry run: what each step will touch.
function BigWaterBuild.check(): { [string]: any }
	local n = BigWater.voxelCount()
	local slots = {}
	for key, s in BigWater.SLOTS do
		slots[key] = MaterialService:FindFirstChild(s.variant) ~= nil
	end
	local backup = ServerStorage:FindFirstChild(BACKUP)
	return {
		switchOn = Config.BIG_WATER_ON,
		chunks = #BigWater.chunks(),
		columns = n.columns,
		voxelsWritten = n.written,
		voxelsCleared = n.cleared,
		backupRegions = #backupRects(),
		backupExists = backup ~= nil and #(backup:FindFirstChild("Terrain") :: Instance):GetChildren() > 0,
		bigLake = workspace:FindFirstChild("BigLake") ~= nil,
		artFolder = art("PineTall") ~= nil,
		slotsReady = slots,
		islets = #BigWater.ISLETS,
		buoys = #BigWater.buoys(),
		trees = #BigWater.treeSpots(),
		ridges = #BigWater.ridges(),
	}
end

-- 1. Terrain copies of everything this module writes. Refuses to run twice (the first copy is
-- the one that matters); dropBackup() clears it once the build is accepted.
function BigWaterBuild.backup(): number
	local f = backupFolder()
	local terr = f:FindFirstChild("Terrain") :: Folder
	if #terr:GetChildren() > 0 then
		warn("[BigWaterBuild] a terrain backup already exists; drop it first (dropBackup) to take a new one")
		return 0
	end
	local t = workspace.Terrain
	local n = 0
	for i, r in backupRects() do
		-- One cell of overlap on the high side whether CopyRegion's max is inclusive or not;
		-- overlapping cells hold the same original data, so pasting them twice is harmless.
		local lo = Vector3int16.new(r.x1 // CELL, BACKUP_Y1 // CELL, r.z1 // CELL)
		local hi = Vector3int16.new(r.x2 // CELL, BACKUP_Y2 // CELL, r.z2 // CELL)
		local copy = t:CopyRegion(Region3int16.new(lo, hi))
		copy.Name = "R" .. i
		copy:SetAttribute("Corner", Vector3.new(lo.X, lo.Y, lo.Z))
		copy.Parent = terr
		n += 1
		task.wait()
	end
	return n
end

function BigWaterBuild.dropBackup()
	local f = ServerStorage:FindFirstChild(BACKUP)
	local terr = f and f:FindFirstChild("Terrain")
	if terr then
		terr:ClearAllChildren()
	end
end

-- Basin decoration that stays: the basin's own banks and island, on ground the plan keeps.
local function keepsDecor(p: Vector3): boolean
	return math.abs(p.X) <= 245 and p.Z >= BigWater.BUOY_Z and BigWater.depth(p.X, p.Z) >= 2
end

-- 2. Decoration Models (a Model whose parent is a Folder, as BoatWorld.clearScenery counts them)
-- that stood on the new water or banks go into the stash. Lake.Art (the templates) is never touched.
function BigWaterBuild.clearDecor(): number
	local c = BigWater.CLEAR
	local n = 0
	local roots: { Instance } = {}
	local lake = workspace:FindFirstChild("Lake")
	if lake then
		table.insert(roots, lake)
	end
	local big = workspace:FindFirstChild("BigLake")
	local dressing = big and big:FindFirstChild("Dressing")
	if dressing then
		table.insert(roots, dressing)
	end
	local art = lake and lake:FindFirstChild("Art")
	for _, root in roots do
		for _, d in root:GetDescendants() do
			if d:IsA("Model") and d.Parent and d.Parent:IsA("Folder") and not (art and d:IsDescendantOf(art)) then
				local p = d:GetPivot().Position
				local inside = BigWater.inRect(c, p.X, p.Z, MARGIN) and p.Z < c.z2 - 1
				local onPath = BigWater.pathDist(p.X, p.Z) < BigWater.PATH_WIDTH / 2 + 3
				if (inside and not keepsDecor(p)) or onPath then
					stash(d, "clearDecor")
					n += 1
				end
			end
		end
	end
	return n
end

-- The slots 33 to 35, set when their variants are in MaterialService. Returns the ready ones.
local function ensureSlots(): { [number]: number }
	local ready: { [number]: number } = {} -- stock index -> our slot
	for _, s in BigWater.SLOTS do
		if MaterialService:FindFirstChild(s.variant) then
			local base = (Enum.Material :: any)[s.base] :: Enum.Material
			workspace.Terrain:SetMaterialSlot(s.slot, base, s.variant, Color3.fromRGB(s.tint[1], s.tint[2], s.tint[3]))
			ready[BigWater.STOCK_INDEX[s.base]] = s.slot
		end
	end
	return ready
end

-- 3. The terrain, chunk by chunk: clears the old hills above the band, then writes every column
-- of the band from BigWater.column (the water to y 0 over it), then repaints our slots.
function BigWaterBuild.terrain(first: number?, last: number?): { [string]: number }
	local t = workspace.Terrain
	local chunks = BigWater.chunks()
	local a, b = first or 1, math.min(last or #chunks, #chunks)
	local ready = ensureSlots()
	local written, painted = 0, 0
	for i = a, b do
		local k = chunks[i]
		t:FillBlock(
			CFrame.new((k.x1 + k.x2) / 2, (BigWater.Y_HI + BigWater.CLEAR_TOP) / 2, (k.z1 + k.z2) / 2),
			Vector3.new(k.x2 - k.x1, BigWater.CLEAR_TOP - BigWater.Y_HI, k.z2 - k.z1),
			Enum.Material.Air
		)
		local region = Region3.new(Vector3.new(k.x1, BigWater.Y_LO, k.z1), Vector3.new(k.x2, BigWater.Y_HI, k.z2)):ExpandToGrid(CELL)
		local lo = region.CFrame.Position - region.Size / 2
		local ch = t:ReadVoxelChannels(region, CELL, { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" }) :: any
		local mats, solid, liquid = ch.SolidMaterial, ch.SolidOccupancy, ch.LiquidOccupancy
		local nx, ny, nz = #mats, #mats[1], #mats[1][1]
		local slotOf: { [number]: { [number]: number? } } = {}
		for ix = 1, nx do
			local cx = lo.X + (ix - 0.5) * CELL
			slotOf[ix] = {}
			for iz = 1, nz do
				local cz = lo.Z + (iz - 0.5) * CELL
				local col = BigWater.column(cx, cz)
				local material = (Enum.Material :: any)[col.material] :: Enum.Material
				slotOf[ix][iz] = col.slot
				for iy = 1, ny do
					local y0 = lo.Y + (iy - 1) * CELL
					local s = math.clamp((col.top - y0) / CELL, 0, 1)
					mats[ix][iy][iz] = if s > 0 then material else Enum.Material.Air
					solid[ix][iy][iz] = s
					liquid[ix][iy][iz] = if y0 + CELL <= 0.01 then 1 else 0 -- the water's surface is y 0
				end
			end
		end
		t:WriteVoxelChannels(region, CELL, { SolidMaterial = mats, SolidOccupancy = solid, LiquidOccupancy = liquid })
		written += nx * ny * nz
		if next(ready) then
			local idxCh = t:ReadVoxelChannels(region, CELL, { "SolidMaterialIndex" }) :: any
			local idx = idxCh.SolidMaterialIndex
			for ix = 1, nx do
				for iz = 1, nz do
					local want = slotOf[ix][iz]
					if want then
						for iy = 1, ny do
							local cur = idx[ix][iy][iz]
							if ready[cur] == want then
								idx[ix][iy][iz] = want
								painted += 1
							end
						end
					end
				end
			end
			t:WriteVoxelChannels(region, CELL, { SolidMaterialIndex = idx })
		end
		task.wait()
	end
	return { chunks = b - a + 1, voxels = written, painted = painted }
end

-- 4. The ring of low hills just past the walls.
function BigWaterBuild.hills(): number
	local t = workspace.Terrain
	local n = 0
	for _, h in BigWater.hills() do
		t:FillBall(Vector3.new(h.x, GROUND_TOP + h.h - h.r, h.z), h.r, Enum.Material.Grass)
		n += 1
	end
	return n
end

local function rectPart(parent: Instance, name: string, r: Rect, attr: string): Part
	local p = part(parent, name, Vector3.new(r.x2 - r.x1, 1, r.z2 - r.z1), CFrame.new((r.x1 + r.x2) / 2, -0.5, (r.z1 + r.z2) / 2), Color3.new(1, 1, 1), HIDDEN)
	p:SetAttribute(attr, true)
	return marked(p)
end

local function buoyPlaceholder(parent: Instance, name: string, x: number, z: number, color: Color3, slot: string): Part
	-- Gray-box until the modeler's buoys arrive: an upright drum with a white band.
	local up = CFrame.Angles(0, 0, math.rad(90))
	local b = part(parent, name, Vector3.new(2.6, 1.8, 1.8), CFrame.new(x, 0.6, z) * up, color, { Shape = Enum.PartType.Cylinder, CanCollide = false, CanQuery = false, Material = Enum.Material.Plastic })
	part(b, "Band", Vector3.new(0.3, 1.85, 1.85), CFrame.new(x, 1.3, z) * up, COLORS.white, { Shape = Enum.PartType.Cylinder, CanCollide = false, CanQuery = false, CanTouch = false, Material = Enum.Material.Plastic })
	b:SetAttribute("ArtSlot", slot)
	return marked(b)
end

-- The gravel path from the footbridge to the pier: terrain grass and lawn cells within half the
-- path's width of its centre line take the footpath slot.
local function paintPath(): number
	local t = workspace.Terrain
	local rects = backupRects()
	local r = rects[#rects]
	local region = Region3.new(Vector3.new(r.x1, -8, r.z1), Vector3.new(r.x2, 8, r.z2)):ExpandToGrid(CELL)
	local lo = region.CFrame.Position - region.Size / 2
	local ch = t:ReadVoxelChannels(region, CELL, { "SolidMaterialIndex" }) :: any
	local idx = ch.SolidMaterialIndex
	local n = 0
	local GRASSY = { [2] = true, [19] = true, [25] = true, [26] = true, [27] = true }
	for ix = 1, #idx do
		local cx = lo.X + (ix - 0.5) * CELL
		for iz = 1, #idx[1][1] do
			local cz = lo.Z + (iz - 0.5) * CELL
			if BigWater.pathDist(cx, cz) <= BigWater.PATH_WIDTH / 2 + 0.5 then
				for iy = 1, #idx[1] do
					if GRASSY[idx[ix][iy][iz]] then
						idx[ix][iy][iz] = BigWater.PATH_SLOT
						n += 1
					end
				end
			end
		end
	end
	t:WriteVoxelChannels(region, CELL, { SolidMaterialIndex = idx })
	return n
end

-- 5. What the rules and the art read: the water boxes, the zones, the walls, the buoy line, the
-- bell buoy, the marina's anchors, the gull perches and the path.
function BigWaterBuild.markers(): { [string]: number }
	local big = workspace:FindFirstChild("BigLake")
	if not big then
		error("[BigWaterBuild] workspace.BigLake is missing: build L7's lake first (BoatWorld.build)")
	end
	local out: { [string]: number } = {}
	-- Old pieces into the stash.
	local walls = big:FindFirstChild("Walls")
	if walls then
		for _, name in { "West", "East", "North" } do
			local w = walls:FindFirstChild(name)
			if w then
				stash(w, "markers")
			end
		end
	end
	for _, name in { "BuoyLine", "Zones", "Water", "BlueWater" } do
		for _, old in big:GetChildren() do
			if old.Name == name then
				if old:GetAttribute(MARK) then
					old:Destroy() -- ours, from an earlier run
				else
					stash(old, "markers")
				end
			end
		end
	end
	local folder = big:FindFirstChild("BigWater") or marked(Instance.new("Folder"))
	folder.Name = "BigWater"
	folder.Parent = big
	for _, c in folder:GetChildren() do
		if c.Name ~= "Dressing" then
			c:Destroy() -- safe to run again
		end
	end

	-- Water boxes the rules read (the terrain is only the look).
	rectPart(big, "Water", BigWater.BASIN, "IsWater")
	local blue = rectPart(big, "BlueWater", BigWater.BLUE, "BlueWater")
	blue:SetAttribute("IsWater", true)
	rectPart(folder, "LilyCove", BigWater.COVE, "IsWater")

	-- Zones, by the same list BoatRules uses with the switch on.
	local zones = marked(Instance.new("Folder"))
	zones.Name = "Zones"
	for _, z in BoatRules.bigWaterZones() do
		marked(part(zones, z.name, z.size, z.cframe, Color3.new(1, 1, 1), HIDDEN))
	end
	zones.Parent = big
	out.zones = #zones:GetChildren()

	-- Walls.
	local wf = Instance.new("Folder")
	wf.Name = "Walls"
	for _, w in BigWater.walls() do
		part(wf, w.name, Vector3.new(w.x2 - w.x1, 80, w.z2 - w.z1), CFrame.new((w.x1 + w.x2) / 2, 38, (w.z1 + w.z2) / 2), Color3.new(1, 1, 1), { Transparency = 1, CanQuery = false, CanTouch = false, CastShadow = false })
	end
	wf.Parent = folder
	out.walls = #wf:GetChildren()

	-- The buoy line and its gate boards.
	local line = marked(Instance.new("Folder"))
	line.Name = "BuoyLine"
	local signs = Signs.folder(folder)
	for _, b in BigWater.buoys() do
		local p = buoyPlaceholder(line, b.name, b.x, b.z, if b.color == "Red" then COLORS.red else COLORS.green, "ChannelBuoy" .. b.color) -- the modeler's sets
		if b.sign then
			local w, h = 8, 2.4
			local ground = p.Position.Y + p.Size.X / 2
			local centre = Vector3.new(b.x, ground + 1.2 + h / 2, b.z)
			local board = Signs.board({
				name = "BlueWaterSign",
				text = "Blue water ahead: big boats only",
				width = w,
				height = h,
				cframe = CFrame.lookAt(centre, centre + Vector3.new(0, 0, 1)),
				paint = Signs.PAINT.pale,
				twoSided = true,
				hang = "post",
				ground = ground,
			})
			board.Parent = signs
		end
	end
	line.Parent = big
	out.buoys = #line:GetChildren()

	-- The bell buoy (a safe-water mark: red and white) and the gull perches.
	local bell = BigWater.BELL_BUOY
	local bb = buoyPlaceholder(folder, "BellBuoy", bell.X, bell.Z, COLORS.red, "BellBuoy")
	bb.Size = Vector3.new(3.4, 2.6, 2.6)
	local perches = Instance.new("Folder")
	perches.Name = "GullPerches"
	for _, name in BigWater.GULLS.perches do
		for _, i in BigWater.ISLETS do
			if i.name == name then
				local a = part(perches, name, Vector3.new(1, 1, 1), CFrame.new(i.x, i.h + 0.5, i.z), Color3.new(1, 1, 1), HIDDEN)
				a:SetAttribute("ArtSlot", "GullPerch")
			end
		end
	end
	local g = BigWater.GULLS.circle
	local flock = part(perches, "GullFlock", Vector3.new(1, 1, 1), CFrame.new(g.x, g.y, g.z), Color3.new(1, 1, 1), HIDDEN)
	flock:SetAttribute("ArtSlot", "GullFlock")
	flock:SetAttribute("Radius", g.r)
	perches.Parent = folder

	-- The marina: anchors where the modeler's pier, slips and lantern go.
	local m = BigWater.MARINA
	local marina = Instance.new("Folder")
	marina.Name = "Marina"
	local len = (m.tip - m.root).Magnitude
	local mid = (m.root + m.tip) / 2
	local pier = part(marina, "PierSlot", Vector3.new(m.width, 0.6, len), CFrame.new(mid.X, m.deckY, mid.Z), Color3.new(1, 1, 1), HIDDEN)
	pier:SetAttribute("ArtSlot", "MarinaPier")
	local lamp = part(marina, "LanternSlot", Vector3.new(1, 1, 1), CFrame.new(m.lantern), Color3.new(1, 1, 1), HIDDEN)
	lamp:SetAttribute("ArtSlot", "MarinaLantern")
	for i = 1, #m.slipZs do
		local c = BigWater.marinaSlip(i, 16)
		local s = part(marina, "Slip" .. i, Vector3.new(1, 0.2, 2), CFrame.new(m.root.X + m.width / 2 + 0.6, m.deckY, c.Z), Color3.new(1, 1, 1), HIDDEN)
		s:SetAttribute("SlipIndex", i)
		s:SetAttribute("Marina", true)
	end
	marina.Parent = folder

	out.pathCells = paintPath()
	return out
end

-- 6. The ridgelines in the haze and the flat far land under them: plain parts, no shadows, no
-- collision, in their own always-loaded model.
function BigWaterBuild.far(): number
	local old = workspace:FindFirstChild("BigWaterFar")
	if old then
		old:Destroy()
	end
	local model = marked(Instance.new("Model"))
	model.Name = "BigWaterFar"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local n = 0
	for i, p in BigWater.ridges() do
		-- A square block turned on its corner, its middle at ground level minus the overshoot, so
		-- the top half shows as a peak p.h high and p.w wide; the tilt makes it lean.
		local th = math.rad(p.tilt)
		local side = p.w / (math.sin(th) + math.cos(th))
		local cy = GROUND_TOP + p.h - p.w / 2
		local depth = 120
		local color = if p.facing == "east" then COLORS.west elseif p.row == 1 then COLORS.rowNear else COLORS.rowFar
		if p.facing == "south" then
			part(model, "Ridge" .. i, Vector3.new(side, side, depth), CFrame.new(p.x, cy, p.z) * CFrame.Angles(0, 0, th), color, DECOR)
		else
			part(model, "Ridge" .. i, Vector3.new(depth, side, side), CFrame.new(p.x, cy, p.z) * CFrame.Angles(th, 0, 0), color, DECOR)
		end
		n += 1
	end
	for i, r in BigWater.farLand() do
		part(model, "FarLand" .. i, Vector3.new(r.x2 - r.x1, 4, r.z2 - r.z1), CFrame.new((r.x1 + r.x2) / 2, -2.5, (r.z1 + r.z2) / 2), COLORS.farLand, DECOR)
		n += 1
	end
	model.Parent = workspace
	return n
end

local function groundAt(x: number, z: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = true
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -260, 0), params)
	return hit and hit.Position.Y or nil
end

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

-- 7. Pines and leafy trees on the banks, the headlands' backs and the bigger islets; reeds and
-- lily pads in Lily Cove. Tagged for the phone tier (ClientModules/FoliageTier).
function BigWaterBuild.dress(): { [string]: number }
	local big = workspace:FindFirstChild("BigLake")
	if not big then
		error("[BigWaterBuild] workspace.BigLake is missing")
	end
	local folder = big:FindFirstChild("BigWater") or marked(Instance.new("Folder"))
	folder.Name = "BigWater"
	folder.Parent = big
	local old = folder:FindFirstChild("Dressing")
	if old then
		old:Destroy()
	end
	local dressing = Instance.new("Folder")
	dressing.Name = "Dressing"
	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = dressing
	local weeds = Instance.new("Folder")
	weeds.Name = "CoveWeeds"
	weeds.Parent = dressing
	local kinds = {
		bank = { "PineTall", "PineTall", "PineShort", "LeafyTree", "PineShort" },
		headland = { "PineShort", "PineTall", "PineShort" },
		islet = { "PineShort" },
	}
	local nTrees, nWeeds = 0, 0
	for i, s in BigWater.treeSpots() do
		local list = kinds[s.kind] or kinds.bank
		local y = groundAt(s.x, s.z)
		if y and y > 0.4 then
			local name = list[(i % #list) + 1]
			local m = place(art(name), trees, Vector3.new(s.x, y - 0.3, s.z), s.scale, s.yaw, true)
			if m then
				CollectionService:AddTag(m, "FoliageTree")
				m:SetAttribute("FoliageAlt", i % 2)
				nTrees += 1
			end
		end
	end
	for i, s in BigWater.coveWeeds() do
		local isReed = s.kind == "reeds"
		local m = place(art(if isReed then "Reeds" else "LilyPads"), weeds, Vector3.new(s.x, if isReed then -1.2 else -0.3, s.z), s.scale, s.yaw, false)
		if m then
			CollectionService:AddTag(m, "FoliageReed")
			m:SetAttribute("FoliageAlt", i % 2)
			nWeeds += 1
		end
	end
	dressing.Parent = folder
	return { trees = nTrees, weeds = nWeeds }
end

-- 8. Everything back as it was: our pieces removed, the stash restored, the terrain pasted back.
function BigWaterBuild.revert(): { [string]: number }
	local out = { removed = 0, restored = 0, pasted = 0 }
	local far = workspace:FindFirstChild("BigWaterFar")
	if far then
		far:Destroy()
		out.removed += 1
	end
	local big = workspace:FindFirstChild("BigLake")
	if big then
		for _, c in big:GetChildren() do
			if c:GetAttribute(MARK) then
				c:Destroy()
				out.removed += 1
			end
		end
	end
	local f = ServerStorage:FindFirstChild(BACKUP)
	local st = f and f:FindFirstChild("Stash")
	if st then
		for _, inst in st:GetChildren() do
			local from = inst:FindFirstChild("From") :: ObjectValue?
			if from and from.Value then
				inst.Parent = from.Value
				inst:SetAttribute("StashedBy", nil)
				from:Destroy()
				out.restored += 1
			else
				warn("[BigWaterBuild] no home for stashed " .. inst.Name)
			end
		end
	end
	local terr = f and f:FindFirstChild("Terrain")
	if terr then
		for _, copy in terr:GetChildren() do
			local corner = copy:GetAttribute("Corner")
			if copy:IsA("TerrainRegion") and typeof(corner) == "Vector3" then
				workspace.Terrain:PasteRegion(copy, Vector3int16.new(corner.X, corner.Y, corner.Z), true)
				out.pasted += 1
				task.wait()
			end
		end
	end
	return out
end

return BigWaterBuild
