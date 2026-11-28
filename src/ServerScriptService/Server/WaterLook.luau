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
local Shore = require(Shared:WaitForChild("Shore"))
local ShoreEdge = require(Shared:WaitForChild("ShoreEdge"))
local BoatRules = require(Shared:WaitForChild("BoatRules"))

local WaterLook = {}

local FOLDER = "WaterLook"
local CELL = 4 -- terrain voxels are 4 studs

WaterLook.TERRAIN = {
	-- L5c: greener and a little less clear (the critic read 24, 92, 112 at 0.72 as a swimming
	-- pool at noon: bright sand seen through very clear water).
	-- L5d: deeper again and less mirror-like (still read as cyan at noon from the dock).
	WaterColor = Color3.fromRGB(26, 66, 62),
	-- N1 (11/27/2026): 0.42, so less of the bed shows through the shallows (they read pale beige).
	WaterTransparency = 0.42,
	WaterReflectance = 0.35,
	WaterWaveSize = 0.12, -- gentle
	WaterWaveSpeed = 8,
	-- 11/27/2026: shorter grass blades (Roblox default 0.7) so the meadows by the lake don't
	-- wall off the water from a low camera.
	GrassLength = 0.45,
}

-- N1 (11/27/2026): darker (was 198, 182, 134). The noon shallows read pale beige (181, 182, 156)
-- because this bed sand showed through the water. Slot 6 (Sand) is also the dry beach sand.
local SAND = Color3.fromRGB(150, 138, 104)
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

-- The flat bed parts, hidden under terrain beds (L5b for the lake, L5c for the creek): they
-- sat in the water as slabs with straight edges. Nothing in the game reads them.
local HIDDEN_BEDS = { "Floor", "DeepHoleFloor", "CedarCreek.RiffleBed", "CedarCreek.RocksBed", "CedarCreek.PoolBed" }

-- One sloping shelf along a side of a box centred at `c` (half sizes hx, hz): from `bed` at
-- `width` studs in, up to `top` at the edge. A terrain wedge rises toward its local +Z.
local YAW = { S = 0, N = math.pi, E = math.pi / 2, W = -math.pi / 2 }
local function shelfWedge(t: Terrain, side: string, c: Vector3, hx: number, hz: number, bed: number, top: number, width: number, material: Enum.Material)
	local drop = top - bed
	if drop <= 0.2 or width <= 0 then
		return
	end
	local y = bed + drop / 2
	local inset = width / 2
	local pos, len
	if side == "S" then
		pos, len = Vector3.new(c.X, y, c.Z + hz - inset), hx * 2
	elseif side == "N" then
		pos, len = Vector3.new(c.X, y, c.Z - hz + inset), hx * 2
	elseif side == "E" then
		pos, len = Vector3.new(c.X + hx - inset, y, c.Z), hz * 2
	else
		pos, len = Vector3.new(c.X - hx + inset, y, c.Z), hz * 2
	end
	t:FillWedge(CFrame.new(pos) * CFrame.Angles(0, YAW[side], 0), Vector3.new(len, drop, width), material)
end

-- The lake's shore in terrain (L5d), from the same Shore.depth the fishing rules use: rounded
-- corners and points of land rise out of the water as grass with a sandy edge, and every bank
-- slopes into sand shallows. Written voxel by voxel with solid and liquid occupancy, so the
-- shore is smooth and the water fills right up to it.
WaterLook.SHALLOWS = 20 -- studs of sloping sand off a bank (the same as SHELF below, so no step)
local GRASS_FROM = 1.5 -- studs into the land where sand gives way to grass

-- Height of the ground at this signed distance to land (nil: leave the bed as it is), for a
-- bed at `bed` that the shallows reach after `shallows` studs (the lake's by default).
function WaterLook.shoreHeight(d: number, bed: number?, shallows: number?): number?
	local top = -WaterLook.SHORE_DEPTH
	local b = bed or WaterLook.BED_TOP
	local s = shallows or WaterLook.SHALLOWS
	if d <= -s then
		return nil
	elseif d < 0 then
		return top + (d / s) * (top - b)
	end
	return math.min(1, top + d * 0.6) -- up the bank to the ground's top (y = 1)
end

-- One shaped water area (Shore.AREAS), written voxel by voxel. On the creek the sloping
-- bank is grass and stone, not sand.
local function shoreArea(t: Terrain, a: Shore.Area)
	local lake = a.name == "Lake"
	local y1, y2 = math.min(-12, a.bed - 4), 4
	local region = Region3.new(Vector3.new(a.x1, y1, a.z1), Vector3.new(a.x2, y2, a.z2)):ExpandToGrid(CELL)
	local lo = region.CFrame.Position - region.Size / 2
	local ch = t:ReadVoxelChannels(region, CELL, { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" }) :: any
	local mats, solid, liquid = ch.SolidMaterial, ch.SolidOccupancy, ch.LiquidOccupancy
	local nx, ny, nz = #mats, #mats[1], #mats[1][1]
	for ix = 1, nx do
		local cx = lo.X + (ix - 0.5) * CELL
		for iz = 1, nz do
			local cz = lo.Z + (iz - 0.5) * CELL
			local d = Shore.depthIn(a, cx, cz)
			local inside = cx >= a.x1 and cx <= a.x2 and cz >= a.z1 and cz <= a.z2
			local h = if inside then (if lake then WaterLook.shoreHeight(d) else WaterLook.shoreHeight(d, a.bed, a.shallows)) else nil
			if h then
				local material = if d >= GRASS_FROM then Enum.Material.Grass
					elseif lake then Enum.Material.Sand
					else Enum.Material.Mud
				for iy = 1, ny do
					local y0 = lo.Y + (iy - 1) * CELL
					local s = math.clamp((h - y0) / CELL, 0, 1)
					mats[ix][iy][iz] = if s > 0 then material else Enum.Material.Air
					solid[ix][iy][iz] = s
					liquid[ix][iy][iz] = if y0 + CELL <= 0.01 then 1 else 0 -- the water's surface is y = 0
				end
			end
		end
	end
	t:WriteVoxelChannels(region, CELL, { SolidMaterial = mats, SolidOccupancy = solid, LiquidOccupancy = liquid })
end

-- Cedar Creek's banks were grass parts with straight vertical edges (the "trench" the critic
-- kept naming). L5e: the parts are hidden and stop colliding, and terrain grass fills the same
-- boxes to the same height, so the terrain shore can slope and curve into the water.
local function creekBanks(lake: Model)
	local creek = lake:FindFirstChild("CedarCreek")
	if not creek then
		return
	end
	local t = workspace.Terrain
	for _, p in creek:GetChildren() do
		if p:IsA("BasePart") and p.Name == "Bank" then
			if p:GetAttribute("OrigTransparency") == nil then
				p:SetAttribute("OrigTransparency", p.Transparency)
				p:SetAttribute("OrigCollide", p.CanCollide)
			end
			p.Transparency = 1
			p.CanCollide = false
			p.CanQuery = false
			t:FillBlock(p.CFrame, p.Size, Enum.Material.Grass)
		end
	end
	-- The creek's paths sit on that grass now: sand under them, so terrain grass blades don't
	-- grow up through the path.
	for _, name in { "BankPath", "PathToCreek" } do
		local path = creek:FindFirstChild(name)
		if path and path:IsA("BasePart") then
			local top = path.Position.Y - path.Size.Y / 2
			t:FillBlock(CFrame.new(path.Position.X, top - 4, path.Position.Z), Vector3.new(path.Size.X, 8, path.Size.Z), Enum.Material.Sand)
		end
	end
end

-- A strip of meadow along the creek (11/27/2026): grass with no blades (LeafyGrass) within
-- CREEK_MEADOW studs of the creek's water, so the narrow creek shows from the bank path. With
-- blades, the critic's riffle shot was all grass and no water.
WaterLook.CREEK_MEADOW = 14
local function creekMeadow(t: Terrain)
	for _, a in Shore.areas() do
		if a.name ~= "Lake" and not a.own then -- N5: BigWaterBuild writes its own areas
			local m = WaterLook.CREEK_MEADOW
			local region = Region3.new(Vector3.new(a.x1 - m, -4, a.z1 - m), Vector3.new(a.x2 + m, 12, a.z2 + m)):ExpandToGrid(CELL)
			local lo = region.CFrame.Position - region.Size / 2
			local ch = t:ReadVoxelChannels(region, CELL, { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" }) :: any
			local mats = ch.SolidMaterial
			for ix = 1, #mats do
				local cx = lo.X + (ix - 0.5) * CELL
				for iz = 1, #mats[1][1] do
					local cz = lo.Z + (iz - 0.5) * CELL
					local near = false
					for _, b in Shore.areas() do
						if b.name ~= "Lake" and not b.own and Shore.depthIn(b, cx, cz) < m then
							near = true
							break
						end
					end
					if near then
						for iy = 1, #mats[1] do
							if mats[ix][iy][iz] == Enum.Material.Grass then
								mats[ix][iy][iz] = Enum.Material.LeafyGrass
							end
						end
					end
				end
			end
			t:WriteVoxelChannels(region, CELL, { SolidMaterial = mats, SolidOccupancy = ch.SolidOccupancy, LiquidOccupancy = ch.LiquidOccupancy })
		end
	end
end

-- Every shaped water area: the lake (L5d) and the creek's three stretches (L5e).
local function shoreTerrain(lake: Model)
	local t = workspace.Terrain
	creekBanks(lake)
	for _, a in Shore.areas() do
		if not a.own then -- N5: the big water's terrain is BigWaterBuild's
			shoreArea(t, a)
		end
	end
	creekMeadow(t)
end

-- The home lawns as terrain (leg 3, N1). The lawns round the lake were five big Grass parts
-- (GroundSouth, GroundEast, GroundWest and GroundNorth's two halves round the channel) whose
-- faces stood at the waterline as a ruler-straight ledge. lawnsToTerrain fills each part's box
-- with terrain Grass (slot 2, our meadow), shapes the bank so it slopes into the water along a
-- waterline that wanders a couple of studs in and out of Shore's line (ShoreEdge, so no plain
-- bank runs straight past 30 studs), and hides the parts. Walking height is unchanged (top y 1).
-- Nothing casts against the parts (casts, zones and the landing ring are math on WaterMap and
-- Shore), so they stop colliding, querying and touching; they stay in the place for the revert.
WaterLook.LAWN_TOP = 1
WaterLook.LAWN_HIDDEN_TOP = 0.5 -- the revert lowers lawn terrain under the parts' tops (no z-fight)
local LAND_DONE = 3.5 -- past this depth to land the bank is flat ground at LAWN_TOP

type Rect = { x1: number, x2: number, z1: number, z2: number }

local function rectOfPart(p: BasePart): Rect
	local c, s = p.Position, p.Size
	return { x1 = c.X - s.X / 2, x2 = c.X + s.X / 2, z1 = c.Z - s.Z / 2, z2 = c.Z + s.Z / 2 }
end

local function inRect(r: Rect, x: number, z: number, pad: number?): boolean
	local k = pad or 0
	return x >= r.x1 - k and x <= r.x2 + k and z >= r.z1 - k and z <= r.z2 + k
end

local function lawnParts(lake: Instance): { BasePart }
	local out = {}
	for _, p in lake:GetChildren() do
		if p:IsA("BasePart") and string.match(p.Name, "^Ground") then
			table.insert(out, p)
		end
	end
	return out
end

local function areaNamed(name: string): Shore.Area?
	for _, a in Shore.areas() do
		if a.name == name then
			return a
		end
	end
	return nil
end

-- Parts that sit flat on the lawn (paths, path bends, the pond's floor, the stands' counters):
-- bladeless LeafyGrass under them, so terrain grass blades don't grow up through them.
local function flatOnLawn(lake: Instance): { BasePart }
	local out = {}
	for _, p in lake:GetChildren() do
		if p:IsA("BasePart") and string.match(p.Name, "^Path") then
			table.insert(out, p)
		end
	end
	local scenery = lake:FindFirstChild("Scenery")
	local bends = scenery and scenery:FindFirstChild("PathBends")
	for _, p in (if bends then bends:GetChildren() else {}) do
		if p:IsA("BasePart") then
			table.insert(out, p)
		end
	end
	local pond = lake:FindFirstChild("HomePond")
	local bottom = pond and pond:FindFirstChild("Bottom")
	if bottom and bottom:IsA("BasePart") then
		table.insert(out, bottom)
	end
	for _, name in { "SellStand", "ShopStand" } do
		local m = lake:FindFirstChild(name)
		local counter = m and m:FindFirstChild("Counter")
		if counter and counter:IsA("BasePart") then
			table.insert(out, counter)
		end
	end
	return out
end

-- Rewrites the bank round the home lake, voxel by voxel: inside the lake box out to the edge of
-- the shallows, and every lawn column near the water (the Big Lake's south bank too, where
-- GroundNorth meets it). `on` false draws Shore's straight line again (the revert) and drops
-- every lawn column to LAWN_HIDDEN_TOP so the restored parts hide it.
local function rimPass(lake: Instance, on: boolean): number
	local t = workspace.Terrain
	local area = areaNamed("Lake")
	if not area then
		return 0
	end
	local big = areaNamed("BigLake")
	local box: Rect = { x1 = area.x1, x2 = area.x2, z1 = area.z1, z2 = area.z2 }
	local lawns: { Rect } = {}
	local lo3, hi3 = Vector3.new(box.x1, -12, box.z1), Vector3.new(box.x2, 4, box.z2)
	for _, p in lawnParts(lake) do
		local r = rectOfPart(p)
		table.insert(lawns, r)
		lo3 = Vector3.new(math.min(lo3.X, r.x1), -12, math.min(lo3.Z, r.z1))
		hi3 = Vector3.new(math.max(hi3.X, r.x2), 4, math.max(hi3.Z, r.z2))
	end
	local cb = BoatRules.CHANNEL
	local channel: Rect = {
		x1 = cb.cframe.Position.X - cb.size.X / 2,
		x2 = cb.cframe.Position.X + cb.size.X / 2,
		z1 = cb.cframe.Position.Z - cb.size.Z / 2,
		z2 = cb.cframe.Position.Z + cb.size.Z / 2,
	}
	local bigRect: Rect? = if big then { x1 = big.x1, x2 = big.x2, z1 = big.z1, z2 = big.z2 } else nil
	local region = Region3.new(lo3, hi3):ExpandToGrid(CELL)
	local lo = region.CFrame.Position - region.Size / 2
	local ch = t:ReadVoxelChannels(region, CELL, { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" }) :: any
	local mats, solid, liquid = ch.SolidMaterial, ch.SolidOccupancy, ch.LiquidOccupancy
	local nx, ny, nz = #mats, #mats[1], #mats[1][1]
	local written = 0
	for ix = 1, nx do
		local cx = lo.X + (ix - 0.5) * CELL
		for iz = 1, nz do
			local cz = lo.Z + (iz - 0.5) * CELL
			local inLake = inRect(box, cx, cz)
			local inLawn = false
			for _, r in lawns do
				if inRect(r, cx, cz) then
					inLawn = true
					break
				end
			end
			local skip = not (inLake or inLawn)
				or inRect(channel, cx, cz, 2) -- BoatWorld's channel
				or (math.abs(cx) <= 19 and cz <= box.z1 + 20) -- the channel's mouth keeps what BoatWorld cut
				or (bigRect ~= nil and inRect(bigRect, cx, cz)) -- BoatWorld's Big Lake
			if not skip then
				local d = ShoreEdge.depth(area, cx, cz, on)
				if big and not inLake then
					-- Distance to the Big Lake's water from its south bank (BoatWorld measures it so).
					local ex, ez = math.clamp(cx, big.x1, big.x2), math.clamp(cz, big.z1, big.z2)
					d = math.min(d, math.max(Shore.depthIn(big, ex, ez), 0) + math.sqrt((cx - ex) ^ 2 + (cz - ez) ^ 2))
				end
				local h: number? = nil
				if inLake then
					if d > -WaterLook.SHALLOWS and d < LAND_DONE + 4 then
						h = WaterLook.shoreHeight(d)
					end
				elseif not on then
					h = math.min(WaterLook.LAWN_HIDDEN_TOP, WaterLook.shoreHeight(d) or WaterLook.LAWN_TOP)
				elseif d < LAND_DONE then
					h = WaterLook.shoreHeight(d)
				end
				if h then
					local leafy = false
					for iy = 1, ny do
						if mats[ix][iy][iz] == Enum.Material.LeafyGrass then
							leafy = true
						end
					end
					local material = if d < GRASS_FROM then Enum.Material.Sand
						elseif leafy and not inLake then Enum.Material.LeafyGrass
						else Enum.Material.Grass
					for iy = 1, ny do
						local y0 = lo.Y + (iy - 1) * CELL
						local s = math.clamp((h - y0) / CELL, 0, 1)
						mats[ix][iy][iz] = if s > 0 then material else Enum.Material.Air
						solid[ix][iy][iz] = s
						liquid[ix][iy][iz] = if y0 + CELL <= 0.01 then 1 else 0 -- the water's surface is y = 0
					end
					written += 1
				end
			end
		end
	end
	t:WriteVoxelChannels(region, CELL, { SolidMaterial = mats, SolidOccupancy = solid, LiquidOccupancy = liquid })
	return written
end

-- The lawns to terrain (run in Edit; safe to run again). Returns counts for the log.
--   require(game.ServerScriptService.Server.WaterLook).lawnsToTerrain(workspace.Lake)
function WaterLook.lawnsToTerrain(lake: Model): { lawns: number, underlays: number, columns: number }
	local t = workspace.Terrain
	local parts = lawnParts(lake)
	for _, p in parts do
		if p:GetAttribute("LawnOrigTransparency") == nil then
			p:SetAttribute("LawnOrigTransparency", p.Transparency)
			p:SetAttribute("LawnOrigCollide", p.CanCollide)
			p:SetAttribute("LawnOrigQuery", p.CanQuery)
			p:SetAttribute("LawnOrigTouch", p.CanTouch)
		end
		-- The box down to the part's bottom, top at y 1 like the part's.
		local bottom = p.Position.Y - p.Size.Y / 2
		local top = WaterLook.LAWN_TOP
		t:FillBlock(CFrame.new(p.Position.X, (bottom + top) / 2, p.Position.Z), Vector3.new(p.Size.X, top - bottom, p.Size.Z), Enum.Material.Grass)
	end
	local flat = flatOnLawn(lake)
	for _, p in flat do
		local top = WaterLook.LAWN_TOP
		t:FillBlock(CFrame.new(p.Position.X, top - 4, p.Position.Z) * p.CFrame.Rotation, Vector3.new(p.Size.X, 8, p.Size.Z), Enum.Material.LeafyGrass)
	end
	local columns = rimPass(lake, true)
	for _, p in parts do
		p.Transparency = 1
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	lake:SetAttribute("LawnsTerrain", true)
	return { lawns = #parts, underlays = #flat, columns = columns }
end

-- Puts the lawn parts back and draws Shore's straight bank again, with the lawn terrain lowered
-- under the parts' tops so they hide it. The terrain grass stays (hidden).
function WaterLook.lawnsToTerrainRevert(lake: Model): number
	local n = 0
	for _, p in lawnParts(lake) do
		local was = p:GetAttribute("LawnOrigTransparency")
		if type(was) == "number" then
			p.Transparency = was
			p.CanCollide = p:GetAttribute("LawnOrigCollide") ~= false
			p.CanQuery = p:GetAttribute("LawnOrigQuery") ~= false
			p.CanTouch = p:GetAttribute("LawnOrigTouch") ~= false
			for _, k in { "LawnOrigTransparency", "LawnOrigCollide", "LawnOrigQuery", "LawnOrigTouch" } do
				p:SetAttribute(k, nil)
			end
			n += 1
		end
	end
	rimPass(lake, false)
	lake:SetAttribute("LawnsTerrain", nil)
	return n
end

-- Just the water settings and the bed's sand colour, without rebuilding the bed (apply does both).
--   require(game.ServerScriptService.Server.WaterLook).tune()
function WaterLook.tune()
	local terrain = workspace.Terrain
	for k, v in WaterLook.TERRAIN do
		(terrain :: any)[k] = v
	end
	terrain:SetMaterialColor(Enum.Material.Sand, SAND)
end

-- The creek's beds in terrain (L5c): each stretch gets a bed and shelving sides, so the pool is
-- a bowl, not a box. A side that opens into the next stretch rises only to that stretch's bed
-- (`top`), so the water still runs through. Sides with no `top` rise to the shallows.
type CreekBed = { material: Enum.Material, color: Color3, shelf: number, sides: { { side: string, top: number? } } }
local CREEK_BEDS: { [string]: CreekBed } = {
	Riffle = { material = Enum.Material.Limestone, color = Color3.fromRGB(140, 126, 100), shelf = 0, sides = {} },
	Rocks = {
		material = Enum.Material.Slate,
		color = Color3.fromRGB(96, 92, 80),
		shelf = 5,
		sides = { { side = "W" }, { side = "E" }, { side = "S", top = -1.5 } }, -- south (+z) meets the riffle
	},
	Pool = {
		material = Enum.Material.Ground,
		color = Color3.fromRGB(44, 46, 40),
		shelf = 10,
		sides = { { side = "W" }, { side = "E" }, { side = "N" }, { side = "S", top = -4 } }, -- south (+z) meets the rocky run
	},
}

local function creekBed(surfaceY: number)
	local t = workspace.Terrain
	local shore = surfaceY - WaterLook.SHORE_DEPTH
	for _, c in WaterMap.CREEK do
		local spec = CREEK_BEDS[c.name]
		if spec then
			t:SetMaterialColor(spec.material, spec.color)
			local center = Vector3.new((c.x1 + c.x2) / 2, 0, (c.z1 + c.z2) / 2)
			local hx, hz = (c.x2 - c.x1) / 2, (c.z2 - c.z1) / 2
			t:FillBlock(CFrame.new(center.X, c.bed - 3, center.Z), Vector3.new(hx * 2, 6, hz * 2), spec.material)
			for _, s in spec.sides do
				shelfWedge(t, s.side, center, hx, hz, c.bed, s.top or shore, spec.shelf, spec.material)
			end
		end
	end
end

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
	local top = surfaceY - WaterLook.SHORE_DEPTH
	for _, side in { "S", "N", "E", "W" } do
		shelfWedge(t, side, c, hx, hz, bed, top, WaterLook.SHELF, Enum.Material.Sand)
	end
	creekBed(surfaceY)
	shoreTerrain(lake)
	-- Lawns already terrain (N1): shoreTerrain just drew the straight bank, so draw the wandering one.
	if lake:GetAttribute("LawnsTerrain") then
		rimPass(lake, true)
	end
	-- Hide the old flat bed parts (kept, so revert can show them again).
	for _, name in HIDDEN_BEDS do
		local p = find(lake, name)
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
	local creek = lake:FindFirstChild("CedarCreek")
	for _, p in (if creek then creek:GetChildren() else {}) do
		local was = p:GetAttribute("OrigTransparency")
		if p:IsA("BasePart") and p.Name == "Bank" and type(was) == "number" then
			p.Transparency = was
			p.CanCollide = p:GetAttribute("OrigCollide") ~= false
			p.CanQuery = true
			p:SetAttribute("OrigTransparency", nil)
			p:SetAttribute("OrigCollide", nil)
		end
	end
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
		local p = find(lake, name)
		local was = p and p:GetAttribute("OrigTransparency")
		if p and p:IsA("BasePart") and type(was) == "number" then
			p.Transparency = was
			p:SetAttribute("OrigTransparency", nil)
		end
	end
end

return WaterLook
