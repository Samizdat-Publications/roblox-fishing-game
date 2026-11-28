--!strict
-- Big water (leg 3, N5): the plan for the Big Lake at its new size, behind Config.BIG_WATER_ON.
--
-- The basin stays as it was (x -200..200, z -290..-140, its lighthouse island and its south bank).
-- Past the buoy line (z -290) the blue water opens out to x -450..450 and runs north to z -1150,
-- where an invisible wall stops boats and swimmers; the water goes on to a far bank at z -1260
-- (the North Reach, looked at, never reached) and ridgelines stand in the haze beyond it, on the
-- north and west only: the east side stays open for a future channel to the sea (the Narrows, about
-- z -600 on the east shore, docs/DIRECTION.md section 6). Lily Cove is a shallow weedy cove off the
-- basin's west bank (paddle only), so the canoe reaches it without crossing the buoy line.
--
-- Everything here is numbers and pure math (no Roblox services), so the Lune specs check it:
-- the shape (Shore reads AREAS when the switch is on), the rock islets on the route to the island,
-- the keep-clears (the N6 island at x 100, z -950; the sea channel; the route), the terrain column
-- the Edit-mode builder (Server/BigWaterBuild) writes, the buoys, the bell buoy, the marina and the
-- path to it (placement only: their art comes from the modeler), the walls, the far ridgelines and
-- the seeded tree and reed spots. Shore and BoatRules are required lazily (they require this).
local BigWater = {}

export type Rect = { x1: number, x2: number, z1: number, z2: number }
export type Circle = { name: string, x: number, z: number, r: number }
export type Islet = { name: string, x: number, z: number, r: number, h: number, pine: boolean }
export type Headland = { name: string, x: number, z: number, r: number, areas: { string } }

BigWater.BUOY_Z = -290 -- BoatRules.BUOY_Z (the spec checks they agree)
BigWater.NORTH_LIMIT = -1150 -- the invisible wall: no boat, cast or swimmer past it
BigWater.CROSS_BAND = 40 -- studs over which crossing the buoy line is felt (LookPresets.AREA_BAND)

-- The water boxes the rules read (BoatRules makes Boxes of these).
BigWater.BASIN = { x1 = -200, x2 = 200, z1 = -290, z2 = -140 } :: Rect
BigWater.BLUE = { x1 = -450, x2 = 450, z1 = BigWater.NORTH_LIMIT, z2 = -290 } :: Rect
BigWater.COVE = { x1 = -285, x2 = -200, z1 = -262, z2 = -196 } :: Rect
-- The cove and the basin share x -200 from z -262 to -196 (both edges open there); two soft points,
-- in both areas, pinch that into a mouth about 26 studs wide (z -242..-216).
BigWater.COVE_MOUTH = { from = -262, to = -196 }
-- Drawn water only, past the wall: the rules never count it as water.
BigWater.REACH = { x1 = -450, x2 = 450, z1 = -1260, z2 = BigWater.NORTH_LIMIT } :: Rect

-- Where the terrain is cleared and rewritten (water, banks and a ring of hills), studs. Its south
-- edge stops one stud short of the basin's south bank: the land south of it is the home world's.
BigWater.CLEAR = { x1 = -480, x2 = 480, z1 = -1300, z2 = -140 } :: Rect
BigWater.CELL = 4
BigWater.CHUNK = 64 -- cells per side of one terrain write (256 studs)
BigWater.Y_LO, BigWater.Y_HI = -32, 12 -- the band the column writes; above it is cleared to air
BigWater.CLEAR_TOP = 160 -- old hills are cleared up to here

-- Keep-clears. The N6 island (not built here): nothing within ISLAND_RESERVE.r of its centre.
BigWater.ISLAND_RESERVE = { name = "Island", x = 100, z = -950, r = 140 } :: Circle
-- The future channel to the sea through the east shore (the Narrows: a 120 stud gap about z -600,
-- leg 4 draft), with 20 studs of margin: no headland, islet, hill, ridge or tree in it, and the bank
-- there stays low, so a later cut is one terrain write.
BigWater.SEA_RESERVE = { x1 = 400, x2 = 760, z1 = -680, z2 = -520 } :: Rect
BigWater.SEA_BANK_TOP = 2.5

-- The marina (placement only; the pier and its lantern are the modeler's): on the basin's south
-- shore east of the channel, a pier running north from the bank with four slips on its east side,
-- boats bow east like the home dock's. The lantern at the pier's end is the light you steer home by.
BigWater.MARINA = {
	root = Vector3.new(70, 0, -138), -- where the pier leaves the bank
	tip = Vector3.new(70, 0, -192), -- its far end
	width = 4,
	deckY = 1.5,
	slipZs = { -154, -164, -174, -184 },
	slipGap = 2.5, -- studs between the pier's edge and a boat's stern
	lantern = Vector3.new(70, 6, -193),
}

-- The route to the island: from the pier's end to the island's middle (about 760 studs; 29 s at the
-- Deep-V's 26 studs a second). Islets keep ROUTE_CLEAR studs of water either side of it.
BigWater.ROUTE = { from = Vector3.new(70, 0, -192), to = Vector3.new(100, 0, -950) }
BigWater.ROUTE_CLEAR = 25

-- The walk to the marina: from the foot of the footbridge's east ramp (x 27 on the shore path,
-- z -85) over the ground between the lakes to the pier's root. Gravel, PATH_WIDTH studs wide.
BigWater.PATH = {
	Vector3.new(27, 0, -85),
	Vector3.new(38, 0, -96),
	Vector3.new(50, 0, -110),
	Vector3.new(61, 0, -124),
	Vector3.new(68, 0, -134),
	Vector3.new(70, 0, -138),
}
BigWater.PATH_WIDTH = 5
BigWater.PATH_SLOT = 24 -- the N1 footpath gravel slot (MaterialKit.SLOTS)

-- Rocky headlands on the banks: land circles centred on or just past the bank line. The two elbows
-- round the corners where the basin opens into the blue water and are in both areas, so the shore
-- is the same from either side of the buoy line. EastHead, ReedPoint and the island's three circles
-- are the basin's own from L7, unchanged.
BigWater.HEADLANDS = {
	{ name = "WestElbow", x = -218, z = -300, r = 34, areas = { "BigLake", "BlueWater" } },
	{ name = "EastElbow", x = 222, z = -296, r = 36, areas = { "BigLake", "BlueWater" } },
	{ name = "EastHead", x = 214, z = -205, r = 38, areas = { "BigLake" } },
	{ name = "WestCape", x = -462, z = -560, r = 48, areas = { "BlueWater" } },
	{ name = "WestBluff", x = -458, z = -860, r = 40, areas = { "BlueWater" } },
	{ name = "NorthWestHead", x = -440, z = -1080, r = 44, areas = { "BlueWater" } },
	{ name = "EastBluff", x = 458, z = -420, r = 38, areas = { "BlueWater" } },
	{ name = "EastCape", x = 462, z = -820, r = 46, areas = { "BlueWater" } },
	{ name = "NorthEastHead", x = 446, z = -1060, r = 36, areas = { "BlueWater" } },
} :: { Headland }

-- The basin's soft points (sand and reeds, not rock), as L7 had them.
BigWater.BASIN_POINTS = {
	{ name = "ReedPoint", x = -120, z = -134, r = 18 },
	{ name = "IslandWest", x = -97, z = -241, r = 14 },
	{ name = "IslandEast", x = -82, z = -236, r = 11 },
	{ name = "IslandTip", x = -72, z = -239, r = 6 },
} :: { Circle }
BigWater.LIGHTHOUSE_ISLAND = { x1 = -111, x2 = -66, z1 = -255, z2 = -225 } :: Rect -- BoatRules.ISLAND

-- The cove's mouth points (in the basin and the cove), and the cove's own weedy points.
BigWater.MOUTH_POINTS = {
	{ name = "CoveMouthNorth", x = -205, z = -258, r = 16 },
	{ name = "CoveMouthSouth", x = -205, z = -200, r = 16 },
} :: { Circle }
BigWater.COVE_POINTS = {
	{ name = "CoveNorth", x = -262, z = -198, r = 12 },
	{ name = "CoveWest", x = -288, z = -232, r = 10 },
} :: { Circle }

-- Rock islets in the blue water: granite domes h studs high, on the way from the marina to the island
-- and round it. A pine on the bigger ones. Specs: spacing, bank and reserve clearances, the route.
BigWater.ISLETS = {
	{ name = "Islet1", x = 25, z = -400, r = 9, h = 4, pine = false },
	{ name = "Islet2", x = 150, z = -470, r = 12, h = 6, pine = true },
	{ name = "Islet3", x = 20, z = -575, r = 10, h = 5, pine = false },
	{ name = "Islet4", x = 175, z = -660, r = 14, h = 7, pine = true },
	{ name = "Islet5", x = 35, z = -760, r = 8, h = 3, pine = false },
	{ name = "Islet6", x = -60, z = -1000, r = 12, h = 6, pine = true },
	{ name = "Islet7", x = 275, z = -880, r = 11, h = 5, pine = false },
	{ name = "Islet8", x = -170, z = -820, r = 10, h = 4, pine = false },
	{ name = "Islet9", x = -250, z = -520, r = 13, h = 7, pine = true },
	{ name = "Islet10", x = 300, z = -430, r = 10, h = 5, pine = false },
} :: { Islet }
BigWater.ISLET_SPACING = 60 -- centre to centre, at least
BigWater.ISLET_BANK_CLEAR = 40 -- studs of water between an islet and any bank or headland
BigWater.ISLET_BUOY_CLEAR = 60 -- and between an islet's edge and the buoy line

-- The bell buoy, just off the route (pass it close on the way out), and the gulls: perches on three
-- islets and a loose flock circling over the bell buoy. Art and birds are the modeler's.
BigWater.BELL_BUOY = Vector3.new(104, 0, -520)
BigWater.GULLS = {
	perches = { "Islet2", "Islet4", "Islet7" },
	circle = { x = 104, z = -520, r = 30, y = 18 },
}

-- The bed (depths below the water line, studs). The basin keeps L7's 7 deep with sand shelves and
-- the weedy shallows off the island point; past the buoy line it drops over DROP studs to the blue
-- water's 24 (the drop-off), eases to 16 under the North Reach, and Lily Cove is 3 deep.
BigWater.BASIN_DEPTH = 7
BigWater.BLUE_DEPTH = 24
BigWater.REACH_DEPTH = 16
BigWater.COVE_DEPTH = 3
BigWater.DROP = { from = 6, run = 40 } -- starts 6 studs past the line, 40 studs long
BigWater.SLOPE = { basin = 0.38, blue = 0.3, cove = 0.3 } -- studs of depth per stud from shore

-- Terrain material slots (Server/BigWaterBuild sets 33 to 35 when the variants exist; the others
-- are MaterialKit's, already remapped). Granite has no family of its own yet: the shore-stone
-- ground maps tinted cool grey stand in until one is made.
BigWater.SLOTS = {
	granite = { slot = 33, base = "Rock", variant = "ShoreStoneGround", tint = { 150, 146, 140 } },
	deepBed = { slot = 34, base = "Basalt", variant = "DeepBed", tint = { 255, 255, 255 } },
	gravel = { slot = 35, base = "Ground", variant = "FootpathGravel", tint = { 140, 136, 128 } },
}
-- Stock slot index of each base, so the builder can repaint by index (MaterialKit.STOCK_TINTS).
BigWater.STOCK_INDEX = { Rock = 8, Basalt = 13, Ground = 14 }

-- The Shore areas for the bigger lake (Shore.areas() swaps them in for L7's "BigLake" when the
-- switch is on). `own` tells WaterLook to leave their terrain to BigWaterBuild; `corners` rounds
-- each corner by its own radius ({x1z1, x2z1, x1z2, x2z2}).
local function pointsFor(areaName: string): { Circle }
	local out = {}
	for _, h in BigWater.HEADLANDS do
		if table.find(h.areas, areaName) then
			table.insert(out, { name = h.name, x = h.x, z = h.z, r = h.r })
		end
	end
	return out
end

function BigWater.areas(): { any }
	local basinPoints = pointsFor("BigLake")
	for _, p in BigWater.BASIN_POINTS do
		table.insert(basinPoints, p)
	end
	local covePoints = table.clone(BigWater.COVE_POINTS)
	for _, p in BigWater.MOUTH_POINTS do
		table.insert(basinPoints, p)
		table.insert(covePoints, p)
	end
	local bluePoints = pointsFor("BlueWater")
	for _, i in BigWater.ISLETS do
		table.insert(bluePoints, { name = i.name, x = i.x, z = i.z, r = i.r })
	end
	local b, u, c, n = BigWater.BASIN, BigWater.BLUE, BigWater.COVE, BigWater.REACH
	return {
		{
			name = "BigLake", -- the basin keeps L7's name (WaterLook's south bank reads it)
			x1 = b.x1, x2 = b.x2, z1 = b.z1, z2 = b.z2,
			banks = true,
			open = {
				{ edge = "z2", from = -15, to = 15 }, -- the channel
				{ edge = "z1", from = b.x1, to = b.x2 }, -- the buoy line: blue water beyond
				{ edge = "x1", from = BigWater.COVE_MOUTH.from, to = BigWater.COVE_MOUTH.to }, -- Lily Cove
			},
			corner = 60, corners = { 0, 0, 60, 60 },
			points = basinPoints, bed = -BigWater.BASIN_DEPTH, shallows = 18, own = "BigWater",
		},
		{
			name = "BlueWater",
			x1 = u.x1, x2 = u.x2, z1 = u.z1, z2 = u.z2,
			banks = true,
			open = {
				{ edge = "z2", from = b.x1, to = b.x2 }, -- the basin
				{ edge = "z1", from = u.x1, to = u.x2 }, -- the North Reach
			},
			corner = 80, corners = { 0, 0, 80, 80 },
			points = bluePoints, bed = -BigWater.BLUE_DEPTH, shallows = 60, own = "BigWater",
		},
		{
			name = "LilyCove",
			x1 = c.x1, x2 = c.x2, z1 = c.z1, z2 = c.z2,
			banks = true,
			open = { { edge = "x2", from = BigWater.COVE_MOUTH.from, to = BigWater.COVE_MOUTH.to } },
			corner = 14, corners = { 14, 0, 14, 0 }, -- square where it opens onto the basin
			points = covePoints, bed = -BigWater.COVE_DEPTH, shallows = 10, own = "BigWater",
		},
		{
			name = "NorthReach",
			x1 = n.x1, x2 = n.x2, z1 = n.z1, z2 = n.z2,
			banks = true,
			open = { { edge = "z2", from = n.x1, to = n.x2 } },
			corner = 70, corners = { 70, 70, 0, 0 },
			points = {}, bed = -BigWater.REACH_DEPTH, shallows = 40, own = "BigWater",
		},
	}
end

local AREAS_CACHE: { any }? = nil
local function ownAreas(): { any }
	if not AREAS_CACHE then
		AREAS_CACHE = BigWater.areas()
	end
	return AREAS_CACHE :: { any }
end
BigWater.ownAreas = ownAreas

local function inRect(r: Rect, x: number, z: number, pad: number?): boolean
	local k = pad or 0
	return x >= r.x1 - k and x <= r.x2 + k and z >= r.z1 - k and z <= r.z2 + k
end
BigWater.inRect = inRect

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Shore is required here, not at the top: Shore requires this module.
local function shore(): any
	return require(script.Parent.Shore)
end

-- The big-water area a point is in (the basin first, as Shore.areaAt picks), or nil.
function BigWater.areaAt(x: number, z: number): any?
	for _, a in ownAreas() do
		if inRect(a, x, z) then
			return a
		end
	end
	return nil
end

-- Signed distance to land on the bigger lake's own shape, like Shore.depth: positive on land (how
-- far in), negative over water. Off every big-water area it is the distance to the nearest of their
-- water plus that edge's own depth (how BoatWorld measured its banks), so the banks rise smoothly.
function BigWater.depth(x: number, z: number): number
	local S = shore()
	local a = BigWater.areaAt(x, z)
	if a then
		return S.depthIn(a, x, z)
	end
	local best = math.huge
	for _, b in ownAreas() do
		local ex, ez = math.clamp(x, b.x1, b.x2), math.clamp(z, b.z1, b.z2)
		local d = math.max(S.depthIn(b, ex, ez), 0) + math.sqrt((x - ex) ^ 2 + (z - ez) ^ 2)
		best = math.min(best, d)
	end
	return best
end

-- The islet or headland whose land this is (nil on plain bank or water), with how far into it.
function BigWater.featureAt(x: number, z: number): (string?, any?, number)
	local bestKind, best, bestD = nil, nil, -math.huge
	for _, i in BigWater.ISLETS do
		local d = i.r - math.sqrt((x - i.x) ^ 2 + (z - i.z) ^ 2)
		if d > bestD then
			bestKind, best, bestD = "islet", i, d
		end
	end
	for _, h in BigWater.HEADLANDS do
		local d = h.r - math.sqrt((x - h.x) ^ 2 + (z - h.z) ^ 2)
		if d > bestD then
			bestKind, best, bestD = "headland", h, d
		end
	end
	if bestD < 0 then
		return nil, nil, bestD
	end
	return bestKind, best, bestD
end

-- How deep the bed may get at this z past the buoy line: 7 in the basin, the drop-off to 24 over
-- DROP.run studs, then 24, easing to 16 under the North Reach.
function BigWater.floorAt(z: number): number
	local drop = smooth((BigWater.BUOY_Z - BigWater.DROP.from - z) / BigWater.DROP.run)
	local deep = BigWater.BASIN_DEPTH + (BigWater.BLUE_DEPTH - BigWater.BASIN_DEPTH) * drop
	local north = smooth((BigWater.NORTH_LIMIT + 50 - z) / 80)
	return deep + (BigWater.REACH_DEPTH - deep) * north
end

function BigWater.inSeaReserve(x: number, z: number, pad: number?): boolean
	return inRect(BigWater.SEA_RESERVE, x, z, pad)
end

-- One terrain column: the top of the solid ground (y), its material (a stock Enum.Material name),
-- and the slot to repaint it with (nil: the stock material's own slot). Water fills to y 0 above it.
export type Column = { top: number, material: string, slot: number? }

function BigWater.column(x: number, z: number): Column
	local d = BigWater.depth(x, z)
	local a = BigWater.areaAt(x, z)
	local S = BigWater.SLOTS
	if d >= 0 then
		local kind, f, fd = BigWater.featureAt(x, z)
		if kind == "islet" then
			-- A granite dome: a stud up for every stud in, to its height.
			return { top = math.min(-0.6 + fd * 1.0, f.h), material = "Rock", slot = S.granite.slot }
		end
		local bankTop = if BigWater.inSeaReserve(x, z) then BigWater.SEA_BANK_TOP else 5
		local plain = if d < 8 then -0.6 + d * 0.3 else math.min(1.8 + (d - 8) * 0.1, bankTop)
		if kind == "headland" then
			-- Rocky noses: steeper out of the water and up to 3 above the bank behind, granite to 14
			-- studs in, then grass on the headland's back. At the circle's edge it is the plain bank.
			local top = math.min(-0.6 + d * 0.55, plain + math.min(fd * 0.25, 3))
			if d < 14 then
				return { top = top, material = "Rock", slot = S.granite.slot }
			end
			return { top = top, material = "Grass", slot = nil }
		end
		if d < 8 then
			local top = -0.6 + d * 0.3
			-- Gravel beaches on every third 120 stud stretch of the far banks, sand elsewhere.
			local far = z < BigWater.BUOY_Z and math.floor(z / 120) % 3 == 0
			if d < 4 then
				return if far then { top = top, material = "Ground", slot = S.gravel.slot } else { top = top, material = "Sand", slot = nil }
			end
			return { top = top, material = "Grass", slot = nil }
		end
		return { top = math.min(1.8 + (d - 8) * 0.1, bankTop), material = "Grass", slot = nil }
	end
	-- Over water.
	local depth
	local name = if a then a.name else "BlueWater"
	if name == "LilyCove" then
		depth = math.min(BigWater.COVE_DEPTH, 0.4 + -d * BigWater.SLOPE.cove)
		return { top = -depth, material = if depth < 1 then "Sand" else "Mud", slot = nil }
	elseif name == "BigLake" then
		depth = math.min(BigWater.BASIN_DEPTH, 0.6 + -d * BigWater.SLOPE.basin)
		local isl = BigWater.LIGHTHOUSE_ISLAND
		local weedy = x > isl.x2 - 4 and x < isl.x2 + 26 and z > isl.z1 - 4 and z < isl.z2 + 4
		if weedy then
			depth = math.min(depth, 3.5)
		end
		return { top = -depth, material = if depth < 3 then "Sand" else "Mud", slot = nil }
	end
	depth = math.min(BigWater.floorAt(z), 0.6 + -d * BigWater.SLOPE.blue)
	-- A granite skirt round each islet and headland nose, down to 6 deep.
	local kind, _, fd = BigWater.featureAt(x, z)
	if kind and fd > -12 and depth < 6 then
		return { top = -depth, material = "Rock", slot = S.granite.slot }
	end
	if depth < 3 then
		return { top = -depth, material = "Sand", slot = nil }
	elseif depth < 12 then
		return { top = -depth, material = "Mud", slot = nil }
	end
	return { top = -depth, material = "Basalt", slot = S.deepBed.slot }
end

-- The terrain writes, in order: CHUNK by CHUNK cells over CLEAR, each a Rect in studs.
function BigWater.chunks(): { Rect }
	local out = {}
	local step = BigWater.CHUNK * BigWater.CELL
	local c = BigWater.CLEAR
	local z = c.z1
	while z < c.z2 do
		local x = c.x1
		while x < c.x2 do
			table.insert(out, { x1 = x, x2 = math.min(x + step, c.x2), z1 = z, z2 = math.min(z + step, c.z2) })
			x += step
		end
		z += step
	end
	return out
end

-- Crossing the buoy line: 0 south of the band, 1 north of it, smooth over CROSS_BAND studs centred
-- on the line (the same band LookPresets blends the basin and blue water presets over).
function BigWater.crossing(z: number): number
	local half = BigWater.CROSS_BAND / 2
	return smooth((BigWater.BUOY_Z + half - z) / BigWater.CROSS_BAND)
end

-- The swell and wind multipliers for the crossing: the bob doubles (BoatFeel.BOB_BLUE) and the
-- wind comes up by WIND_GAIN. A client that may write wind locally scales it by windGain.
BigWater.WIND_GAIN = 1.8
function BigWater.windGain(z: number): number
	return 1 + (BigWater.WIND_GAIN - 1) * BigWater.crossing(z)
end

-- The buoy line (placement; the red and green buoys are the modeler's): one every BUOY_STEP studs
-- across the basin's mouth, on water only. Red to the west of where the route crosses the line and
-- green to the east (red right returning, heading home south), so the route runs through a gate.
-- The gate's two buoys carry the "Blue water ahead" board.
BigWater.BUOY_STEP = 40
export type Buoy = { name: string, x: number, z: number, color: string, sign: boolean }

function BigWater.routeX(z: number): number
	local a, b = BigWater.ROUTE.from, BigWater.ROUTE.to
	local t = (z - a.Z) / (b.Z - a.Z)
	return a.X + (b.X - a.X) * t
end

function BigWater.buoys(): { Buoy }
	local out = {}
	local gateX = BigWater.routeX(BigWater.BUOY_Z)
	local x = BigWater.BASIN.x1 + 20
	local i = 0
	local S = shore()
	while x <= BigWater.BASIN.x2 - 20 do
		local a = BigWater.areaAt(x, BigWater.BUOY_Z)
		if a and S.depthIn(a, x, BigWater.BUOY_Z) < -3 then
			i += 1
			table.insert(out, { name = "Buoy" .. i, x = x, z = BigWater.BUOY_Z, color = if x < gateX then "Red" else "Green", sign = false })
		end
		x += BigWater.BUOY_STEP
	end
	-- The gate: the last red and the first green.
	for k = 1, #out - 1 do
		if out[k].color == "Red" and out[k + 1].color == "Green" then
			out[k].sign = true
			out[k + 1].sign = true
		end
	end
	return out
end

-- The marina slips: where a boat of this length and width sits at slip i (stern at the pier's edge
-- plus slipGap, bow east). Pure numbers; BoatRules turns them into CFrames.
function BigWater.marinaSlip(i: number, length: number): Vector3
	local m = BigWater.MARINA
	local z = assert(m.slipZs[i], "no such marina slip")
	return Vector3.new(m.root.X + m.width / 2 + m.slipGap + length / 2, 0, z)
end

-- Distance from (x, z) to the walking path's centre line.
function BigWater.pathDist(x: number, z: number): number
	local best = math.huge
	for k = 1, #BigWater.PATH - 1 do
		local a, b = BigWater.PATH[k], BigWater.PATH[k + 1]
		local dx, dz = b.X - a.X, b.Z - a.Z
		local len2 = dx * dx + dz * dz
		local t = if len2 > 0 then math.clamp(((x - a.X) * dx + (z - a.Z) * dz) / len2, 0, 1) else 0
		best = math.min(best, math.sqrt((x - a.X - dx * t) ^ 2 + (z - a.Z - dz * t) ^ 2))
	end
	return best
end

-- Invisible walls (x1, x2, z1, z2), 3 studs outside the water on land, and the north wall across the
-- water at the limit. The basin's west wall stops at Lily Cove, whose own walls go round it. The old BoatWorld walls
-- West, East and North are replaced; its SouthEast wall stays.
export type Wall = { name: string, x1: number, x2: number, z1: number, z2: number }
function BigWater.walls(): { Wall }
	local u, b, c, m = BigWater.BLUE, BigWater.BASIN, BigWater.COVE, BigWater.COVE_MOUTH
	local n = BigWater.NORTH_LIMIT
	return {
		{ name = "BigNorth", x1 = u.x1 - 5, x2 = u.x2 + 5, z1 = n - 2, z2 = n - 1 },
		{ name = "BigWest", x1 = u.x1 - 4, x2 = u.x1 - 3, z1 = n - 2, z2 = u.z2 + 4 },
		{ name = "BigEast", x1 = u.x2 + 3, x2 = u.x2 + 4, z1 = n - 2, z2 = u.z2 + 4 },
		{ name = "WingWest", x1 = u.x1 - 4, x2 = b.x1 - 3, z1 = u.z2 + 3, z2 = u.z2 + 4 },
		{ name = "WingEast", x1 = b.x2 + 3, x2 = u.x2 + 4, z1 = u.z2 + 3, z2 = u.z2 + 4 },
		{ name = "BasinWestNorth", x1 = b.x1 - 3, x2 = b.x1 - 2, z1 = u.z2 + 3, z2 = m.from - 3 },
		{ name = "BasinWestSouth", x1 = b.x1 - 3, x2 = b.x1 - 2, z1 = m.to + 3, z2 = b.z2 },
		{ name = "BasinEast", x1 = b.x2 + 2, x2 = b.x2 + 3, z1 = u.z2 + 3, z2 = b.z2 - 1.5 },
		{ name = "CoveWest", x1 = c.x1 - 4, x2 = c.x1 - 3, z1 = c.z1 - 4, z2 = c.z2 + 4 },
		{ name = "CoveNorth", x1 = c.x1 - 4, x2 = c.x2 - 2, z1 = c.z1 - 4, z2 = c.z1 - 3 },
		{ name = "CoveSouth", x1 = c.x1 - 4, x2 = c.x2 - 2, z1 = c.z2 + 3, z2 = c.z2 + 4 },
	}
end

-- A small seeded random (32-bit xorshift), the same in Lune and Studio.
local TWO32 = 4294967296
local function rng(seed: number): { s: number }
	local s = bit32.bxor(math.floor(math.abs(seed)) % TWO32, 0x9E3779B9)
	if s == 0 then
		s = 2463534242
	end
	return { s = s }
end
local function nextNum(r: { s: number }, lo: number, hi: number): number
	local x = r.s
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	r.s = x
	return lo + (hi - lo) * (x / TWO32)
end

-- The far ridgelines in the haze (cheap far geometry, always loaded): peaks to the north and the
-- west only, the east left open for the sea. Each peak is one block turned on its corner and half
-- buried, so it shows as a triangle; widths and heights vary, two rows to the north.
export type Peak = { x: number, z: number, h: number, w: number, tilt: number, row: number, facing: string }
function BigWater.ridges(seed: number?): { Peak }
	local r = rng(seed or 20261209)
	local out = {}
	local function row(rowN: number, axis: string, fixed: number, from: number, to: number, step: number, hLo: number, hHi: number)
		local v = from
		while v <= to do
			local h = nextNum(r, hLo, hHi)
			local p = {
				x = if axis == "x" then v + nextNum(r, -40, 40) else fixed + nextNum(r, -60, 60),
				z = if axis == "x" then fixed + nextNum(r, -60, 60) else v + nextNum(r, -40, 40),
				h = h,
				w = h * nextNum(r, 2.0, 3.0), -- at least twice the height, so the turned block's middle is buried
				tilt = nextNum(r, 38, 52),
				row = rowN,
				facing = if axis == "x" then "south" else "east",
			}
			table.insert(out, p)
			v += step
		end
	end
	row(1, "x", -1700, -1300, 1300, 190, 110, 190) -- north, near
	row(2, "x", -2050, -1500, 1500, 240, 170, 260) -- north, far and taller
	row(1, "z", -1250, -1500, -300, 190, 100, 180) -- west
	return out
end

-- Flat far land under the ridges (parts, below the terrain's top where both exist), so no void
-- shows past the banks. Each under 2048 studs a side.
function BigWater.farLand(): { Rect }
	return {
		{ x1 = -1600, x2 = 0, z1 = -2200, z2 = -1300 },
		{ x1 = 0, x2 = 1600, z1 = -2200, z2 = -1300 },
		{ x1 = -1600, x2 = -480, z1 = -1300, z2 = -140 },
		{ x1 = 480, x2 = 1600, z1 = -1300, z2 = -140 },
	}
end

-- A ring of low hills just outside the walls hides the edge of the rewrite (as BoatWorld did): x, z,
-- radius, height. None in the sea reserve, none on the south edge (the home world).
export type Hill = { x: number, z: number, r: number, h: number }
function BigWater.hills(seed: number?): { Hill }
	local r = rng(seed or 20261208)
	local c = BigWater.CLEAR
	local out = {}
	local function add(x: number, z: number)
		local rad = nextNum(r, 26, 38)
		local hx, hz = x + nextNum(r, -6, 6), z + nextNum(r, -6, 6)
		if not BigWater.inSeaReserve(hx, hz, rad) then
			table.insert(out, { x = hx, z = hz, r = rad, h = nextNum(r, 9, 18) })
		end
	end
	local x = c.x1
	while x <= c.x2 do
		add(x, c.z1)
		x += 34
	end
	local z = c.z1
	while z <= c.z2 - 120 do
		add(c.x1, z)
		add(c.x2, z)
		z += 34
	end
	return out
end

-- Seeded tree spots on the banks, the headlands' backs and the bigger islets (the builder plants
-- Art pines and leafy trees there): on land 10 to 45 studs from the water, never in the sea reserve,
-- the island reserve or on the path, MIN_TREE_GAP apart.
BigWater.MIN_TREE_GAP = 8
export type Spot = { x: number, z: number, scale: number, yaw: number, kind: string }
function BigWater.treeSpots(seed: number?): { Spot }
	local r = rng(seed or 20261210)
	local out: { Spot } = {}
	local function free(x: number, z: number): boolean
		for _, s in out do
			if (s.x - x) ^ 2 + (s.z - z) ^ 2 < BigWater.MIN_TREE_GAP ^ 2 then
				return false
			end
		end
		return true
	end
	local function try(x: number, z: number, kind: string)
		local d = BigWater.depth(x, z)
		local ir = BigWater.ISLAND_RESERVE
		local nearIsland = (x - ir.x) ^ 2 + (z - ir.z) ^ 2 < (ir.r + 10) ^ 2
		if d >= 10 and d <= 45 and not BigWater.inSeaReserve(x, z, 10) and not nearIsland
			and inRect(BigWater.CLEAR, x, z, -8) and BigWater.pathDist(x, z) > 6 and free(x, z) then
			table.insert(out, { x = x, z = z, scale = nextNum(r, 0.85, 1.3), yaw = nextNum(r, 0, 2 * math.pi), kind = kind })
		end
	end
	local u, b = BigWater.BLUE, BigWater.BASIN
	-- West and east banks of the blue water, in clumps.
	for _ = 1, 60 do
		local side = if nextNum(r, 0, 1) < 0.5 then -1 else 1
		local cx = (if side < 0 then u.x1 else u.x2) + side * nextNum(r, 12, 34)
		local cz = nextNum(r, u.z1 + 20, u.z2 - 40)
		for _ = 1, 4 do
			try(cx + nextNum(r, -9, 9), cz + nextNum(r, -9, 9), "bank")
		end
	end
	-- The North Reach's far bank and the wings' south banks.
	for _ = 1, 30 do
		local cx, cz = nextNum(r, u.x1, u.x2), BigWater.REACH.z1 - nextNum(r, 12, 30)
		for _ = 1, 4 do
			try(cx + nextNum(r, -9, 9), cz + nextNum(r, -9, 9), "bank")
		end
	end
	for _ = 1, 16 do
		local side = if nextNum(r, 0, 1) < 0.5 then -1 else 1
		local cx = side * nextNum(r, b.x2 + 40, u.x2 - 20)
		local cz = u.z2 + nextNum(r, 12, 30)
		for _ = 1, 4 do
			try(cx + nextNum(r, -9, 9), cz + nextNum(r, -9, 9), "bank")
		end
	end
	-- The headlands' backs.
	for _, h in BigWater.HEADLANDS do
		for _ = 1, math.floor(h.r / 5) do
			try(h.x + nextNum(r, -h.r * 0.6, h.r * 0.6), h.z + nextNum(r, -h.r * 0.6, h.r * 0.6), "headland")
		end
	end
	-- One wind-shaped pine on each bigger islet (on its crown, so the depth rule above is skipped).
	for _, i in BigWater.ISLETS do
		if i.pine then
			table.insert(out, { x = i.x + nextNum(r, -2, 2), z = i.z + nextNum(r, -2, 2), scale = nextNum(r, 0.8, 1.0), yaw = nextNum(r, 0, 2 * math.pi), kind = "islet" })
		end
	end
	return out
end

-- Reeds and lily pads in Lily Cove's shallows (0.8 to 6 studs out from its shore).
function BigWater.coveWeeds(seed: number?): { Spot }
	local r = rng(seed or 20261211)
	local out: { Spot } = {}
	local c = BigWater.COVE
	local tries = 0
	while #out < 48 and tries < 2000 do
		tries += 1
		local x, z = nextNum(r, c.x1, c.x2), nextNum(r, c.z1, c.z2)
		local d = BigWater.depth(x, z)
		if d < -0.8 and d > -6 then
			table.insert(out, { x = x, z = z, scale = nextNum(r, 0.8, 1.3), yaw = nextNum(r, 0, 2 * math.pi), kind = if nextNum(r, 0, 1) < 0.65 then "reeds" else "lily" })
		end
	end
	return out
end

-- The fishing spots the bigger lake changes (BoatRules applies them to its ZONES with the switch on;
-- BigWaterBuild makes the zone parts from the same list): the drop-off becomes all the blue water,
-- and Lily Cove fishes as the basin (its own fish are not planned yet).
function BigWater.zoneChanges(): { replace: { [string]: Rect }, add: { { name: string, rect: Rect } } }
	return {
		replace = { DropOff = BigWater.BLUE },
		add = { { name = "Basin", rect = BigWater.COVE } },
	}
end

-- Is this point past the north wall (still drawn water, never boat water)?
function BigWater.pastNorthWall(x: number, z: number): boolean
	return z < BigWater.NORTH_LIMIT and x >= BigWater.REACH.x1 and x <= BigWater.REACH.x2 and z >= BigWater.REACH.z1
end
BigWater.EDGE_TEXT = "That's as far as the lake goes. Turn the boat."

-- Rough budgets for docs/PERF.md (pure arithmetic; the real numbers come from the probe).
function BigWater.voxelCount(): { columns: number, written: number, cleared: number }
	local c = BigWater.CLEAR
	local cols = ((c.x2 - c.x1) / BigWater.CELL) * ((c.z2 - c.z1) / BigWater.CELL)
	local band = (BigWater.Y_HI - BigWater.Y_LO) / BigWater.CELL
	local above = (BigWater.CLEAR_TOP - BigWater.Y_HI) / BigWater.CELL
	return { columns = cols, written = cols * band, cleared = cols * above }
end

return BigWater
