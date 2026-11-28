--!strict
-- The shore (L5d, creek added L5e). The water boxes stay rectangles, but the shore inside them
-- isn't: the lake's four corners are rounded and a few grassy points jut out into it (land you
-- can walk out on and fish from), and Cedar Creek's pool has rounded corners and its banks
-- jut in here and there so the riffle and the rocky run meander. Every rule that asks "is
-- this water?" goes through FishLogic.isOnWaterAny, which asks Shore.isLand first, so casts,
-- the landing ring, rises and fish shadows all see the same shore. WaterLook draws it in
-- terrain from the same numbers (Shore.depth), so what you see is what the rules use.
--
-- Pure data and math, no Roblox services: runs in the Lune tests.
local Shore = {}
local Config = require(script.Parent.Config)
local BigWater = require(script.Parent.BigWater) -- N5's bigger lake (data only; it requires Shore lazily)

export type Point = { name: string, x: number, z: number, r: number }
-- A stretch of one edge that isn't shore (where two creek stretches join): edge "x1", "x2",
-- "z1" or "z2", open from `from` to `to` along it.
export type Open = { edge: string, from: number, to: number }
export type Area = {
	name: string,
	x1: number,
	x2: number,
	z1: number,
	z2: number,
	banks: boolean, -- the rectangle's own edges are shore, except the open stretches
	open: { Open },
	corner: number, -- radius of the rounded corners (0: none)
	points: { Point },
	bed: number, -- the bed's height, where the shallows bottom out
	shallows: number, -- studs of sloping bed off a shore
	-- N5 (big water), optional: each corner's own radius { x1z1, x2z1, x1z2, x2z2 } in place of
	-- `corner`, and `own` naming the builder that writes this area's terrain (WaterLook skips it).
	corners: { number }?,
	own: string?,
}

-- The lake's water rectangle (WaterMap.WATER_SIZE centred on the origin).
Shore.LAKE = { x1 = -110, x2 = 110, z1 = -80, z2 = 80 }

-- Rounded corners: each corner of the lake becomes a quarter circle this big.
Shore.CORNER_R = 30

-- Points of land on the lake: a circle centred just past the bank line, so a rounded nose
-- juts in. Clear of the dock (x -15..15 on the south bank), the weed bed, the logs, the deep
-- hole and the boat channel cut through the north bank (x -15..15).
Shore.POINTS = {
	{ name = "BirchPoint", x = -42, z = -85, r = 17 }, -- north bank, west of the channel
	{ name = "PinePoint", x = 58, z = -87, r = 21 }, -- north bank, east
	{ name = "EastPoint", x = 115, z = -22, r = 17 }, -- east bank
	{ name = "WestPoint", x = -115, z = -42, r = 15 }, -- west bank
	{ name = "PondPoint", x = 40, z = 86, r = 14 }, -- south bank, east of the dock
} :: { Point }

-- Every shaped water area. The creek's numbers follow WaterMap.CREEK (Riffle x -236..-224,
-- z 30..75; Rocks x -240..-220, z -10..30; Pool x -252..-208, z -70..-10). Bank bulges keep
-- at least 8 studs of water across the riffle and 12 across the run.
Shore.AREAS = {
	{
		name = "Lake",
		x1 = Shore.LAKE.x1, x2 = Shore.LAKE.x2, z1 = Shore.LAKE.z1, z2 = Shore.LAKE.z2,
		banks = true, open = {}, corner = Shore.CORNER_R, points = Shore.POINTS,
		bed = -8, shallows = 20,
	},
	{
		name = "Riffle", x1 = -236, x2 = -224, z1 = 30, z2 = 75,
		banks = true, open = { { edge = "z1", from = -236, to = -224 } }, -- runs into the rocky run
		corner = 0, bed = -1.5, shallows = 3,
		points = {
			{ name = "RiffleWestA", x = -237.5, z = 41, r = 4.5 },
			{ name = "RiffleEast", x = -222.5, z = 55, r = 4.5 },
			{ name = "RiffleWestB", x = -237.5, z = 68, r = 4.5 },
		},
	},
	{
		name = "Rocks", x1 = -240, x2 = -220, z1 = -10, z2 = 30,
		banks = true,
		open = {
			{ edge = "z2", from = -236, to = -224 }, -- the riffle comes in
			{ edge = "z1", from = -240, to = -220 }, -- it opens into the pool
		},
		corner = 0, bed = -4, shallows = 4,
		points = {
			{ name = "RocksWest", x = -242, z = 6, r = 6 },
			{ name = "RocksEast", x = -218, z = 22, r = 5.5 },
		},
	},
	{
		name = "Pool", x1 = -252, x2 = -208, z1 = -70, z2 = -10,
		banks = true, open = { { edge = "z2", from = -240, to = -220 } }, -- the rocky run comes in
		corner = 12, bed = -9, shallows = 6,
		points = {
			{ name = "PoolWest", x = -255, z = -42, r = 8 },
		},
	},
	-- The Big Lake (L7), BoatRules.BIG_LAKE: rounded corners, three headlands, a point off the
	-- south bank, and the island as three overlapping circles whose small east tip is the weedy
	-- island point. The channel comes in through the middle of the south bank (x -15..15).
	{
		name = "BigLake", x1 = -200, x2 = 200, z1 = -440, z2 = -140,
		banks = true, open = { { edge = "z2", from = -15, to = 15 } },
		corner = 60, bed = -7, shallows = 18,
		points = {
			{ name = "WestHead", x = -212, z = -335, r = 36 },
			{ name = "EastHead", x = 214, z = -205, r = 38 },
			{ name = "NorthHead", x = 70, z = -452, r = 34 },
			{ name = "ReedPoint", x = -120, z = -134, r = 18 },
			{ name = "IslandWest", x = -97, z = -241, r = 14 },
			{ name = "IslandEast", x = -82, z = -236, r = 11 },
			{ name = "IslandTip", x = -72, z = -239, r = 6 },
		},
	},
} :: { Area }

-- The areas in use: AREAS, or with Config.BIG_WATER_ON (N5) the same list with L7's BigLake swapped
-- for the bigger lake's basin, blue water, Lily Cove and North Reach (BigWater.areas). Read at call
-- time, so a spec can flip the switch.
local BIG_AREAS: { Area }? = nil
function Shore.areas(): { Area }
	if not Config.BIG_WATER_ON then
		return Shore.AREAS
	end
	if not BIG_AREAS then
		local out: { Area } = {}
		for _, a in Shore.AREAS do
			if a.name ~= "BigLake" then
				table.insert(out, a)
			end
		end
		for _, a in BigWater.ownAreas() do
			table.insert(out, a :: Area)
		end
		BIG_AREAS = out
	end
	return BIG_AREAS :: { Area }
end

-- The area this point lies in, if any.
function Shore.areaAt(x: number, z: number): Area?
	for _, a in Shore.areas() do
		if x >= a.x1 and x <= a.x2 and z >= a.z1 and z <= a.z2 then
			return a
		end
	end
	return nil
end

-- Signed distance to land within one area: positive inside land (how far in), negative over
-- water (how far from the shore).
local function isOpen(a: Area, edge: string, along: number): boolean
	for _, o in a.open do
		if o.edge == edge and along >= o.from and along <= o.to then
			return true
		end
	end
	return false
end

function Shore.depthIn(a: Area, x: number, z: number): number
	local d = -math.huge
	if a.banks then
		-- The nearest bank edge, skipping the open stretches where water runs on.
		local nearest = math.huge
		if not isOpen(a, "x1", z) then
			nearest = math.min(nearest, x - a.x1)
		end
		if not isOpen(a, "x2", z) then
			nearest = math.min(nearest, a.x2 - x)
		end
		if not isOpen(a, "z1", x) then
			nearest = math.min(nearest, z - a.z1)
		end
		if not isOpen(a, "z2", x) then
			nearest = math.min(nearest, a.z2 - z)
		end
		d = -nearest
	end
	if a.corner > 0 or a.corners then
		for i, c in { { a.x1, a.z1, 1, 1 }, { a.x2, a.z1, -1, 1 }, { a.x1, a.z2, 1, -1 }, { a.x2, a.z2, -1, -1 } } do
			local r = if a.corners then a.corners[i] else a.corner
			local cx, cz, sx, sz = c[1], c[2], c[3], c[4]
			local u, v = (x - cx) * sx, (z - cz) * sz -- 0..r inside the corner square
			if r > 0 and u >= 0 and u <= r and v >= 0 and v <= r then
				local du, dv = r - u, r - v -- from the circle's centre
				d = math.max(d, math.sqrt(du * du + dv * dv) - r)
			end
		end
	end
	for _, p in a.points do
		local dx, dz = x - p.x, z - p.z
		d = math.max(d, p.r - math.sqrt(dx * dx + dz * dz))
	end
	return d
end

-- Signed distance to land at (x, z) in whichever shaped area it lies in; -math.huge outside
-- every area (the shore isn't this module's business there).
function Shore.depth(x: number, z: number): number
	local a = Shore.areaAt(x, z)
	return if a then Shore.depthIn(a, x, z) else -math.huge
end

-- True when this point, inside a water box, is land (a rounded corner, a point, a bank bulge).
function Shore.isLand(pos: Vector3): boolean
	return Shore.depth(pos.X, pos.Z) > 0
end

return Shore
