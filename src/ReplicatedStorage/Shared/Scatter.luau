--!strict
-- Seeded placement maths for the home lake's dress pass (leg 3, N1, BankDress). Pure: no Roblox
-- services and its own random numbers (a 32-bit xorshift), so Lune and Studio draw the same
-- layout from the same seed and the specs check the real thing.
--
-- What it plans (Scatter.homeLake(seed)):
--  * the bank kit round the drawn waterline: reeds in clusters (the weed bed, the bends, the far
--    shore; never near the dock), stones in small groups at the waterline, 3 to 5 birches on the
--    points of land leaning out over the water, driftwood here and there, a little undergrowth
--    on the far bank's lip;
--  * a pine treeline with undergrowth behind the path on the north, east and west sides (13 to
--    34 studs back from the bank, a birch mixed in now and then), Poisson-disc spaced with a
--    slow density mask so it clumps and thins instead of standing in rows;
--  * forest-floor blobs under every treeline tree;
--  * the wandering footpaths: the lake loop and the two creek paths on their old routes, with a
--    seeded sideways wobble (2 studs at most), a width of 5 to 7 studs, and no straight run.
-- Everything keeps clear of the dock and slips, the stands, the pond, the chalkboard, the trophy
-- wall, the channel and its footbridge, the creek gate and every fishing spot's cast lane.
local Shore = require(script.Parent.Shore)
local ShoreEdge = require(script.Parent.ShoreEdge)

local Scatter = {}

local TWO32 = 4294967296
local TAU = 2 * math.pi

---------------------------------------------------------------------------------------------
-- Random numbers and noise
---------------------------------------------------------------------------------------------

export type Rng = { s: number }

local function xorshift(x: number): number
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	return x
end

function Scatter.rng(seed: number): Rng
	local s = bit32.bxor(math.floor(math.abs(seed)) % TWO32, 0x9E3779B9)
	if s == 0 then
		s = 2463534242
	end
	for _ = 1, 4 do
		s = xorshift(s)
	end
	return { s = s }
end

-- 0 <= n < 1.
function Scatter.next(r: Rng): number
	r.s = xorshift(r.s)
	return r.s / TWO32
end

function Scatter.range(r: Rng, lo: number, hi: number): number
	return lo + (hi - lo) * Scatter.next(r)
end

function Scatter.int(r: Rng, lo: number, hi: number): number
	return math.min(hi, lo + math.floor(Scatter.next(r) * (hi - lo + 1)))
end

-- A fixed 0..1 value for one lattice point.
function Scatter.hash(ix: number, iz: number, seed: number): number
	local a = (math.floor(ix) * 73856093) % TWO32
	local b = (math.floor(iz) * 19349663) % TWO32
	local h = bit32.bxor(a, b, math.floor(math.abs(seed)) % TWO32, 0x2545F491)
	if h == 0 then
		h = 0x6C8E9CF5
	end
	h = xorshift(xorshift(xorshift(h)))
	return h / TWO32
end

-- Smooth value noise, 0..1, features about `scale` studs across.
function Scatter.noise(x: number, z: number, scale: number, seed: number): number
	local fx, fz = x / scale, z / scale
	local ix, iz = math.floor(fx), math.floor(fz)
	local tx, tz = fx - ix, fz - iz
	tx = tx * tx * (3 - 2 * tx)
	tz = tz * tz * (3 - 2 * tz)
	local a, b = Scatter.hash(ix, iz, seed), Scatter.hash(ix + 1, iz, seed)
	local c, d = Scatter.hash(ix, iz + 1, seed), Scatter.hash(ix + 1, iz + 1, seed)
	local top = a + (b - a) * tx
	local bottom = c + (d - c) * tx
	return top + (bottom - top) * tz
end

---------------------------------------------------------------------------------------------
-- Scatter: Poisson-disc darts and clusters
---------------------------------------------------------------------------------------------

export type Pt = { x: number, z: number }

local function farEnough(list: { any }, x: number, z: number, d: number): boolean
	local d2 = d * d
	for _, p in list do
		local dx, dz = p.x - x, p.z - z
		if dx * dx + dz * dz < d2 then
			return false
		end
	end
	return true
end
Scatter.farEnough = farEnough

-- Dart throwing: up to `n` points, none closer than `minDist` to another (or to any point in
-- `others`), each one `accept`ed (which may draw from `r` for a density mask).
function Scatter.poisson(r: Rng, n: number, minDist: number, tries: number, sample: (Rng) -> (number, number), accept: (number, number) -> boolean, others: { any }?): { Pt }
	local out: { Pt } = {}
	for _ = 1, tries do
		if #out >= n then
			break
		end
		local x, z = sample(r)
		if accept(x, z) and farEnough(out, x, z, minDist) and (others == nil or farEnough(others, x, z, minDist)) then
			table.insert(out, { x = x, z = z })
		end
	end
	return out
end

-- Members round each centre: per[1]..per[2] of them inside a radius of radius[1]..radius[2],
-- denser toward the middle, none closer than `minDist` to another.
function Scatter.cluster(r: Rng, centres: { Pt }, per: { number }, radius: { number }, minDist: number, accept: (number, number) -> boolean): { Pt }
	local out: { Pt } = {}
	for _, c in centres do
		local n = Scatter.int(r, per[1], per[2])
		local R = Scatter.range(r, radius[1], radius[2])
		local placed, k = 0, 0
		while placed < n and k < n * 14 do
			k += 1
			local a = Scatter.range(r, 0, TAU)
			local d = R * Scatter.next(r)
			local x, z = c.x + math.cos(a) * d, c.z + math.sin(a) * d
			if accept(x, z) and farEnough(out, x, z, minDist) then
				table.insert(out, { x = x, z = z })
				placed += 1
			end
		end
	end
	return out
end

-- Nearest-neighbour distance of every point.
function Scatter.nearest(points: { any }): { number }
	local out = {}
	for i, p in points do
		local best = math.huge
		for j, q in points do
			if i ~= j then
				local dx, dz = p.x - q.x, p.z - q.z
				best = math.min(best, dx * dx + dz * dz)
			end
		end
		table.insert(out, math.sqrt(best))
	end
	return out
end

function Scatter.minSpacing(points: { any }): number
	local m = math.huge
	for _, d in Scatter.nearest(points) do
		m = math.min(m, d)
	end
	return m
end

-- Coefficient of variation (standard deviation over mean). A grid gives 0.
function Scatter.cv(values: { number }): number
	if #values < 2 then
		return 0
	end
	local sum = 0
	for _, v in values do
		sum += v
	end
	local mean = sum / #values
	local var = 0
	for _, v in values do
		var += (v - mean) ^ 2
	end
	return math.sqrt(var / #values) / mean
end

---------------------------------------------------------------------------------------------
-- Wandering paths
---------------------------------------------------------------------------------------------

export type Sample = { x: number, z: number, w: number, s: number, off: number }
export type Route = { name: string, samples: { Sample } }
export type WanderOpts = {
	amp: number, -- the wobble's reach, studs (2)
	bias: number?, -- a steady sideways shift (along the left-hand normal)
	pins: { Pt }?, -- places the wobble fades to nothing (bridge feet, the gate)
	pinEnds: boolean?,
	pinFade: number?, -- studs over which the wobble fades in round a pin
	pinWidth: number?, -- the widest the path may be at a pin
	wMin: number,
	wMax: number,
}

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- A polyline at about 1 stud steps through straight lines and arcs. Each piece is
-- { "line", x1, z1, x2, z2 } or { "arc", cx, cz, r, a1, a2 } (angles: x = cos, z = sin).
function Scatter.polyline(pieces: { { any } }): { Pt }
	local out: { Pt } = {}
	local last: Pt? = nil
	for _, p in pieces do
		if p[1] == "line" then
			local x1, z1, x2, z2 = p[2], p[3], p[4], p[5]
			local n = math.max(1, math.ceil(math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)))
			for i = 0, n do
				table.insert(out, { x = x1 + (x2 - x1) * i / n, z = z1 + (z2 - z1) * i / n })
			end
		else
			local cx, cz, rr, a1, a2 = p[2], p[3], p[4], p[5], p[6]
			local n = math.max(1, math.ceil(rr * math.abs(a2 - a1)))
			for i = 0, n do
				local a = a1 + (a2 - a1) * i / n
				table.insert(out, { x = cx + rr * math.cos(a), z = cz + rr * math.sin(a) })
			end
		end
	end
	-- Drop the repeated joints.
	local clean: { Pt } = {}
	for _, q in out do
		if not last or (q.x - last.x) ^ 2 + (q.z - last.z) ^ 2 > 0.01 then
			table.insert(clean, q)
			last = q
		end
	end
	return clean
end

-- Three slow sines with seeded wavelengths and phases, -1..1. The longest has a wavelength under
-- 26 studs and carries most of the swing, so every 30 stud stretch bends.
local function waveFn(r: Rng, l1: { number }, l2: { number }, l3: { number }): (number) -> number
	local w1, w2, w3 = Scatter.range(r, l1[1], l1[2]), Scatter.range(r, l2[1], l2[2]), Scatter.range(r, l3[1], l3[2])
	local p1, p2, p3 = Scatter.range(r, 0, TAU), Scatter.range(r, 0, TAU), Scatter.range(r, 0, TAU)
	return function(s: number): number
		return 0.6 * math.sin(TAU * s / w1 + p1) + 0.27 * math.sin(TAU * s / w2 + p2) + 0.13 * math.sin(TAU * s / w3 + p3)
	end
end

-- The route's base line wobbled sideways and given a width at every sample.
function Scatter.wander(name: string, base: { Pt }, r: Rng, o: WanderOpts): Route
	local wob = waveFn(r, { 20, 26 }, { 34, 44 }, { 11, 15 })
	local wid = waveFn(r, { 28, 40 }, { 15, 21 }, { 50, 64 })
	local fade = o.pinFade or 9
	local pins: { Pt } = table.clone(o.pins or {})
	if o.pinEnds then
		table.insert(pins, base[1])
		table.insert(pins, base[#base])
	end
	local samples: { Sample } = {}
	local s = 0
	for i, p in base do
		if i > 1 then
			local q = base[i - 1]
			s += math.sqrt((p.x - q.x) ^ 2 + (p.z - q.z) ^ 2)
		end
		local a, b = base[math.max(1, i - 1)], base[math.min(#base, i + 1)]
		local tx, tz = b.x - a.x, b.z - a.z
		local tl = math.sqrt(tx * tx + tz * tz)
		tx, tz = tx / tl, tz / tl
		local nx, nz = -tz, tx -- left-hand normal
		local k = 1
		for _, pin in pins do
			local d = math.sqrt((p.x - pin.x) ^ 2 + (p.z - pin.z) ^ 2)
			k = math.min(k, smooth(d / fade))
		end
		local off = math.clamp((o.bias or 0) + o.amp * wob(s), -o.amp, o.amp) * k
		local w = (o.wMin + o.wMax) / 2 + (o.wMax - o.wMin) / 2 * wid(s)
		if k < 1 and o.pinWidth then
			w = math.min(w, o.pinWidth + (w - o.pinWidth) * k)
		end
		table.insert(samples, { x = p.x + nx * off, z = p.z + nz * off, w = w, s = s, off = off })
	end
	return { name = name, samples = samples }
end

-- The flattest stretch of `run` studs along a route: the smallest, over every stretch that long,
-- of the furthest any sample strays from the straight chord across it. 0 means a ruler line.
function Scatter.flattest(samples: { Sample }, run: number): number
	local worst = math.huge
	local j = 1
	for i = 1, #samples do
		while j <= #samples and samples[j].s - samples[i].s < run do
			j += 1
		end
		if j > #samples then
			break
		end
		local a, b = samples[i], samples[j]
		local cx, cz = b.x - a.x, b.z - a.z
		local cl = math.sqrt(cx * cx + cz * cz)
		local dev = 0
		for k = i + 1, j - 1 do
			local q = samples[k]
			dev = math.max(dev, math.abs((q.x - a.x) * cz - (q.z - a.z) * cx) / cl)
		end
		worst = math.min(worst, dev)
	end
	return worst
end

-- A lookup of route samples in 8 stud buckets, for "how far is the nearest path edge?".
export type PathIndex = { [number]: { Sample } }
local BUCKET = 8

function Scatter.key(ix: number, iz: number): number
	return (ix + 4096) * 8192 + (iz + 4096)
end

function Scatter.unkey(k: number): (number, number)
	local ix = math.floor(k / 8192)
	return ix - 4096, k - ix * 8192 - 4096
end

function Scatter.pathIndex(routes: { Route }): PathIndex
	local idx: PathIndex = {}
	for _, rt in routes do
		for _, q in rt.samples do
			local k = Scatter.key(math.floor(q.x / BUCKET), math.floor(q.z / BUCKET))
			local list = idx[k]
			if not list then
				list = {}
				idx[k] = list
			end
			table.insert(list, q)
		end
	end
	return idx
end

-- Distance from (x, z) to the nearest path's edge (negative on the path); math.huge when no path
-- is within 16 studs.
function Scatter.pathEdge(idx: PathIndex, x: number, z: number): number
	local bx, bz = math.floor(x / BUCKET), math.floor(z / BUCKET)
	local best = math.huge
	for ix = bx - 2, bx + 2 do
		for iz = bz - 2, bz + 2 do
			local list = idx[Scatter.key(ix, iz)]
			if list then
				for _, q in list do
					local d = math.sqrt((q.x - x) ^ 2 + (q.z - z) ^ 2) - q.w / 2
					if d < best then
						best = d
					end
				end
			end
		end
	end
	return best
end

-- Terrain cells (4 studs) to paint as path: every cell whose centre is on the path, and a
-- dithered fringe `soft` studs wide past its edge so the edge is not a ruler line.
function Scatter.pathCells(routes: { Route }, cell: number, seed: number, soft: number?): { [number]: boolean }
	local sf = soft or 1.5
	local excess: { [number]: number } = {}
	for _, rt in routes do
		for _, q in rt.samples do
			local R = q.w / 2 + sf
			for ix = math.floor((q.x - R) / cell), math.floor((q.x + R) / cell) do
				for iz = math.floor((q.z - R) / cell), math.floor((q.z + R) / cell) do
					local cx, cz = (ix + 0.5) * cell, (iz + 0.5) * cell
					local e = math.sqrt((cx - q.x) ^ 2 + (cz - q.z) ^ 2) - q.w / 2
					local k = Scatter.key(ix, iz)
					if e < (excess[k] or math.huge) then
						excess[k] = e
					end
				end
			end
		end
	end
	local set: { [number]: boolean } = {}
	for k, e in excess do
		local ix, iz = Scatter.unkey(k)
		if e <= 0 or (e < sf and Scatter.hash(ix, iz, seed + 7) > e / sf) then
			set[k] = true
		end
	end
	return set
end

export type Blob = { x: number, z: number, r: number }

-- Terrain cells under soft-edged blobs: each blob's radius swells and shrinks with slow noise
-- (0.7 to 1.3 of its own), so the patches have ragged, organic edges and run together.
function Scatter.blobCells(blobs: { Blob }, cell: number, seed: number): { [number]: boolean }
	local set: { [number]: boolean } = {}
	for _, b in blobs do
		local R = b.r * 1.3
		for ix = math.floor((b.x - R) / cell), math.floor((b.x + R) / cell) do
			for iz = math.floor((b.z - R) / cell), math.floor((b.z + R) / cell) do
				local cx, cz = (ix + 0.5) * cell, (iz + 0.5) * cell
				local edge = b.r * (0.7 + 0.6 * Scatter.noise(cx, cz, 9, seed + 3))
				if (cx - b.x) ^ 2 + (cz - b.z) ^ 2 <= edge * edge then
					set[Scatter.key(ix, iz)] = true
				end
			end
		end
	end
	return set
end

---------------------------------------------------------------------------------------------
-- The home lake
---------------------------------------------------------------------------------------------

local function areaNamed(name: string): Shore.Area
	for _, a in Shore.AREAS do
		if a.name == name then
			return a
		end
	end
	error("Shore has no area " .. name)
end
local LAKE = areaNamed("Lake")

-- Pivot depth under the ground line at scale 1 (art/models/manifest.json, `bury`).
Scatter.KIT = {
	ReedClump1 = 1.01,
	ReedClump2 = 1.01,
	ShoreStones1 = 0.4,
	ShoreStones2 = 0.4,
	DriftwoodBranch = 0.12,
	DriftwoodLog = 0.28,
	DriftwoodStump = 0.44,
	BirchLean1 = 1.35,
	BirchLean2 = 1.24,
	ShorePine1 = 1.01,
	ShorePine2 = 1.01,
	Fern1 = 0.2,
	Fern2 = 0.2,
	Bush1 = 0.13,
	Bush2 = 0.17,
} :: { [string]: number }

-- The dock's middle, for "near the dock" and "far from it".
Scatter.DOCK = { x = 0, z = 57 }

-- Kept clear of every placed model (x1, x2, z1, z2 and circles).
export type Box = { name: string, x1: number, x2: number, z1: number, z2: number }
export type Circle = { name: string, x: number, z: number, r: number }
Scatter.KEEP_BOXES = {
	{ name = "Dock", x1 = -14, x2 = 14, z1 = 28, z2 = 92 }, -- deck x -8..8, z 34..81, the spawn at z 74
	{ name = "Slips", x1 = 3, x2 = 26, z1 = 40, z2 = 82 }, -- BoatRules slips (x 5..23, z 47..74)
	{ name = "Stands", x1 = -32, x2 = 32, z1 = 86, z2 = 106 }, -- both stands at x +-18, z 96, and the lamps at +-24
	{ name = "Chalkboard", x1 = 24, x2 = 40, z1 = 88, z2 = 100 }, -- Chalkboard (30, 94) and its crate (35, 94)
	{ name = "TrophyWall", x1 = 38, x2 = 62, z1 = 112, z2 = 123 }, -- behind the pond at z 117.5
	{ name = "Channel", x1 = -30, x2 = 30, z1 = -146, z2 = -74 }, -- the cut (x -15..15) and the footbridge's ramps (to x +-26)
	{ name = "CreekGate", x1 = -172, x2 = -108, z1 = -12, z2 = 12 }, -- the walk to the gate (x -162)
} :: { Box }
Scatter.KEEP_CIRCLES = {
	{ name = "Pond", x = 50, z = 106, r = 14 }, -- the round pond (r 8) and its stones
} :: { Circle }

-- Cast lanes: from where people stand toward each spot. No reeds, stones or driftwood in a lane
-- or within LANE_FOOT studs of its shore end.
export type Lane = { name: string, x1: number, z1: number, x2: number, z2: number, r: number }
Scatter.LANE_FOOT = 6
Scatter.LANES = {
	{ name = "WeedBedWest", x1 = -111, z1 = 38, x2 = -94, z2 = 38, r = 4 },
	{ name = "WeedBedSouth", x1 = -78, z1 = 81, x2 = -78, z2 = 64, r = 4 },
	{ name = "LogsEast", x1 = 111, z1 = 42, x2 = 94, z2 = 42, r = 4 },
	{ name = "LogsSouth", x1 = 78, z1 = 81, x2 = 78, z2 = 64, r = 4 },
	{ name = "DockEnd", x1 = 0, z1 = 34, x2 = 0, z2 = 16, r = 8 }, -- toward the deep hole
} :: { Lane }
-- Each point of land is fished from its nose.
for _, p in Shore.POINTS do
	local nx, nz = 0, 0
	if math.abs(p.z) > 80 then
		nz = if p.z > 0 then -1 else 1
	else
		nx = if p.x > 0 then -1 else 1
	end
	local tip = p.r - ShoreEdge.WATERLINE_D
	table.insert(Scatter.LANES, {
		name = p.name,
		x1 = p.x + nx * (tip - 2),
		z1 = p.z + nz * (tip - 2),
		x2 = p.x + nx * (tip + 12),
		z2 = p.z + nz * (tip + 12),
		r = 4,
	})
end

-- How much of each kind, and where. The main session tunes these against the frame budget.
Scatter.TUNING = {
	reedClusters = 12,
	reedPer = { 3, 6 },
	reedSpacing = 2.4,
	stoneGroups = 14,
	stonePer = { 2, 4 },
	stoneSpacing = 1.6,
	birches = { 3, 5 }, -- leaning out from the points of land
	driftwood = 8,
	lipClusters = 7, -- undergrowth on the far bank's lip
	treeMinDist = 8,
	treeMax = 140,
	treeBand = { 13, 34 }, -- studs back from the bank (the path's outer edge is at most 10.5)
	birchMix = 0.1,
	underPer = { 0, 3 },
	underSpacing = 2,
	farDist = 165, -- trees past this far from the dock thin out...
	farKeep = 0.7, -- ...to this share
	shadowDist = 150, -- and cast no shadow past this
}

export type Item = {
	model: string,
	group: string, -- Reeds, Stones, Birches, Driftwood, Lip, Treeline, Undergrowth
	x: number,
	z: number,
	yaw: number,
	scale: number,
	water: boolean, -- true: stands in the water (pivot from the surface, y 0), else on the terrain
	shadow: boolean,
}

export type Plan = {
	items: { Item },
	routes: { Route },
	forest: { Blob },
	counts: { [string]: number },
}

-- Signed distance to the drawn waterline (ShoreEdge): positive on land. Shore's depth is only
-- true inside the lake's box (outside a corner it measures to the nearer edge line), so out
-- there the distance to the rounded box, less the most the drawn line wanders out, is the floor.
function Scatter.waterline(x: number, z: number): number
	local d = ShoreEdge.depth(LAKE, x, z) - ShoreEdge.WATERLINE_D
	if x < LAKE.x1 or x > LAKE.x2 or z < LAKE.z1 or z > LAKE.z2 then
		d = math.max(d, Scatter.roundBox(x, z) - ShoreEdge.OUT_MAX)
	end
	return d
end

-- Distance outside the lake's rounded box (corners of radius CORNER_R), ignoring points of land:
-- the lake loop path runs along its 5 stud line. Positive on land.
function Scatter.roundBox(x: number, z: number): number
	local r = Shore.CORNER_R
	local hx, hz = (LAKE.x2 - LAKE.x1) / 2 - r, (LAKE.z2 - LAKE.z1) / 2 - r
	local qx, qz = math.abs(x) - hx, math.abs(z) - hz
	local ox, oz = math.max(qx, 0), math.max(qz, 0)
	return math.sqrt(ox * ox + oz * oz) + math.min(math.max(qx, qz), 0) - r
end

-- The way to the water from here (unit x, z).
function Scatter.toWater(x: number, z: number): (number, number)
	local h = 0.5
	local gx = Scatter.waterline(x + h, z) - Scatter.waterline(x - h, z)
	local gz = Scatter.waterline(x, z + h) - Scatter.waterline(x, z - h)
	local l = math.sqrt(gx * gx + gz * gz)
	if l < 1e-6 then
		return -x / math.max(1, math.abs(x) + math.abs(z)), -z / math.max(1, math.abs(x) + math.abs(z))
	end
	return -gx / l, -gz / l
end

-- Yaw that turns a model's -X (a birch's lean) toward (dx, dz); and one that lays its X along it.
function Scatter.yawMinusX(dx: number, dz: number): number
	return math.atan2(dz, -dx)
end
function Scatter.yawAlongX(dx: number, dz: number): number
	return math.atan2(-dz, dx)
end

function Scatter.inBox(b: Box, x: number, z: number, pad: number?): boolean
	local k = pad or 0
	return x >= b.x1 - k and x <= b.x2 + k and z >= b.z1 - k and z <= b.z2 + k
end

function Scatter.kept(x: number, z: number, pad: number?): boolean
	for _, b in Scatter.KEEP_BOXES do
		if Scatter.inBox(b, x, z, pad) then
			return true
		end
	end
	for _, c in Scatter.KEEP_CIRCLES do
		local k = c.r + (pad or 0)
		if (x - c.x) ^ 2 + (z - c.z) ^ 2 <= k * k then
			return true
		end
	end
	return false
end

-- Distance from (x, z) to a lane's centre segment.
function Scatter.laneDist(l: Lane, x: number, z: number): number
	local dx, dz = l.x2 - l.x1, l.z2 - l.z1
	local t = math.clamp(((x - l.x1) * dx + (z - l.z1) * dz) / (dx * dx + dz * dz), 0, 1)
	return math.sqrt((x - l.x1 - dx * t) ^ 2 + (z - l.z1 - dz * t) ^ 2)
end

function Scatter.inLane(x: number, z: number): boolean
	for _, l in Scatter.LANES do
		if Scatter.laneDist(l, x, z) <= l.r then
			return true
		end
		if (x - l.x1) ^ 2 + (z - l.z1) ^ 2 <= Scatter.LANE_FOOT ^ 2 then
			return true
		end
	end
	return false
end

-- Which stretch of shore (x, z) faces: "south" (the near shore, dock side), "north", "east",
-- "west", or a corner "ne", "nw", "se", "sw".
function Scatter.side(x: number, z: number): string
	local cx = Shore.LAKE.x2 - Shore.CORNER_R
	local cz = Shore.LAKE.z2 - Shore.CORNER_R
	local ns = if z > cz then "s" elseif z < -cz then "n" else ""
	local ew = if x > cx then "e" elseif x < -cx then "w" else ""
	if ns ~= "" and ew ~= "" then
		return ns .. ew
	end
	return if ns == "s" then "south" elseif ns == "n" then "north" elseif ew == "e" then "east" elseif ew == "w" then "west" else "middle"
end

-- True when (x, z) sits more than `margin` studs from every lake and creek water (dry ground).
function Scatter.dry(x: number, z: number, margin: number): boolean
	for _, name in { "Lake", "Riffle", "Rocks", "Pool" } do
		local a = areaNamed(name)
		if x >= a.x1 - 12 and x <= a.x2 + 12 and z >= a.z1 - 12 and z <= a.z2 + 12 then
			if Shore.depthIn(a, x, z) < margin then
				return false
			end
		end
	end
	return true
end

-- The footpaths' routes (the old parts' centrelines): the lake loop, 5 studs off the rounded
-- box, open across the channel between the footbridge's ramp feet (x +-26); the path west to
-- the creek through the gate; and the creek's bank path.
function Scatter.homeRoutes(seed: number): { Route }
	local r = Scatter.rng(seed + 101)
	local cx, cz = Shore.LAKE.x2 - Shore.CORNER_R, Shore.LAKE.z2 - Shore.CORNER_R -- 80, 50
	local R = Shore.CORNER_R + 5 -- 35
	local ex, ez = cx + R, cz + R -- 115, 85
	local h = math.pi / 2
	local ring = Scatter.polyline({
		{ "line", 26, -ez, cx, -ez },
		{ "arc", cx, -cz, R, -h, 0 },
		{ "line", ex, -cz, ex, cz },
		{ "arc", cx, cz, R, 0, h },
		{ "line", cx, ez, -cx, ez },
		{ "arc", -cx, cz, R, h, 2 * h },
		{ "line", -ex, cz, -ex, -cz },
		{ "arc", -cx, -cz, R, 2 * h, 3 * h },
		{ "line", -cx, -ez, -26, -ez },
	})
	local link = Scatter.polyline({ { "line", -ex, 0, -203, 0 } })
	local bank = Scatter.polyline({ { "line", -203, -70, -203, 70 } })
	return {
		Scatter.wander("LakeLoop", ring, r, { amp = 2, pinEnds = true, pinFade = 9, pinWidth = 6, wMin = 5, wMax = 7 }),
		Scatter.wander("PathToCreek", link, r, { amp = 2, pins = { { x = -162, z = 0 } }, pinFade = 9, pinWidth = 5.5, wMin = 5, wMax = 7 }),
		-- Its left-hand normal points west, at the pool 5 studs away: lean the wobble east.
		Scatter.wander("BankPath", bank, r, { amp = 2, bias = -0.7, wMin = 5, wMax = 6.5 }),
	}
end

-- The whole plan for one seed.
function Scatter.homeLake(seed: number, tuning: { [string]: any }?): Plan
	local T: { [string]: any } = table.clone(Scatter.TUNING)
	for k, v in tuning or {} do
		T[k] = v
	end
	local items: { Item } = {}
	local counts: { [string]: number } = {}
	local function add(it: Item)
		table.insert(items, it)
		counts[it.model] = (counts[it.model] or 0) + 1
	end
	local function pick(r: Rng, a: string, b: string): string
		return if Scatter.next(r) < 0.5 then a else b
	end
	local function dockDist(x: number, z: number): number
		return math.sqrt((x - Scatter.DOCK.x) ^ 2 + (z - Scatter.DOCK.z) ^ 2)
	end
	local routes = Scatter.homeRoutes(seed)
	local pidx = Scatter.pathIndex(routes)
	local function shoreSample(r: Rng): (number, number)
		return Scatter.range(r, -124, 124), Scatter.range(r, -94, 94)
	end
	local function free(x: number, z: number, pad: number?): boolean
		return not Scatter.kept(x, z, pad)
	end

	-- 1. Reeds, in clusters in the shallows. Heavy at the weed bed (the west bank and the
	-- south-west bend), lighter on the bends and the far shore, none along the dock's stretch.
	local rr = Scatter.rng(seed + 1)
	local function reedWeight(x: number, z: number): number
		local side = Scatter.side(x, z)
		if (side == "west" and z > 0) or side == "sw" then
			return 1
		elseif side == "south" then
			return if math.abs(x) < 50 then 0 else 0.25
		elseif side == "ne" or side == "nw" or side == "se" then
			return 0.7
		elseif side == "east" and z > 0 then
			return 0.3 -- the fallen logs are the cover there
		end
		return 0.5
	end
	local reedCentres = Scatter.poisson(rr, T.reedClusters, 18, 4000, shoreSample, function(x, z)
		local w = Scatter.waterline(x, z)
		return w >= -5 and w <= -1.5 and free(x, z, 4) and not Scatter.inLane(x, z) and Scatter.next(rr) < reedWeight(x, z)
	end)
	local reeds = Scatter.cluster(rr, reedCentres, T.reedPer, { 3, 6 }, T.reedSpacing, function(x, z)
		local w = Scatter.waterline(x, z)
		return w >= -6 and w <= -0.8 and free(x, z, 2) and not Scatter.inLane(x, z)
	end)
	for _, p in reeds do
		add({ model = pick(rr, "ReedClump1", "ReedClump2"), group = "Reeds", x = p.x, z = p.z, yaw = Scatter.range(rr, 0, TAU), scale = Scatter.range(rr, 0.8, 1.2), water = true, shadow = false })
	end

	-- 2. Stones in small groups at the waterline, half sunk; fewer along the near shore.
	local rs = Scatter.rng(seed + 2)
	local stoneCentres = Scatter.poisson(rs, T.stoneGroups, 16, 4000, shoreSample, function(x, z)
		local w = Scatter.waterline(x, z)
		local near = Scatter.side(x, z) == "south"
		return math.abs(w) <= 0.5 and free(x, z, 3) and not Scatter.inLane(x, z) and Scatter.next(rs) < (if near then 0.35 else 1)
	end)
	local stones = Scatter.cluster(rs, stoneCentres, T.stonePer, { 1.2, 2.8 }, T.stoneSpacing, function(x, z)
		local w = Scatter.waterline(x, z)
		return w >= -0.9 and w <= 0.5 and free(x, z, 1) and not Scatter.inLane(x, z)
	end)
	for _, p in stones do
		add({ model = pick(rs, "ShoreStones1", "ShoreStones2"), group = "Stones", x = p.x, z = p.z, yaw = Scatter.range(rs, 0, TAU), scale = Scatter.range(rs, 0.7, 1.4), water = false, shadow = false })
	end

	-- 3. Birches leaning out over the water from the points of land, 1 to 3 studs back from the
	-- water, to one side of the nose (the nose is someone's cast).
	local rb = Scatter.rng(seed + 3)
	local slots: { { p: Shore.Point, side: number } } = {}
	for _, p in Shore.POINTS do
		if p.name == "BirchPoint" then
			table.insert(slots, { p = p, side = 1 })
			table.insert(slots, { p = p, side = -1 })
		elseif p.name ~= "PondPoint" then -- the near shore stays open
			table.insert(slots, { p = p, side = if Scatter.next(rb) < 0.5 then 1 else -1 })
		end
	end
	for i = #slots, 2, -1 do
		local j = Scatter.int(rb, 1, i)
		slots[i], slots[j] = slots[j], slots[i]
	end
	local wantBirches = Scatter.int(rb, T.birches[1], T.birches[2])
	local birches: { Pt } = {}
	for _, sl in slots do
		if #birches >= wantBirches then
			break
		end
		local p = sl.p
		local nx, nz = 0, 0
		if math.abs(p.z) > 80 then
			nz = if p.z > 0 then -1 else 1
		else
			nx = if p.x > 0 then -1 else 1
		end
		local nose = math.atan2(nz, nx)
		for _ = 1, 30 do
			local a = nose + sl.side * Scatter.range(rb, math.rad(32), math.rad(62))
			local rho = p.r - ShoreEdge.WATERLINE_D - Scatter.range(rb, 1, 3)
			local x, z = p.x + math.cos(a) * rho, p.z + math.sin(a) * rho
			local w = Scatter.waterline(x, z)
			if w >= 1 and w <= 3 and Scatter.pathEdge(pidx, x, z) > 1.5 and free(x, z, 2) and farEnough(birches, x, z, 10) then
				local wx, wz = math.cos(a), math.sin(a) -- straight out from the point
				table.insert(birches, { x = x, z = z })
				add({ model = pick(rb, "BirchLean1", "BirchLean2"), group = "Birches", x = x, z = z, yaw = Scatter.yawMinusX(wx, wz) + Scatter.range(rb, -0.25, 0.25), scale = Scatter.range(rb, 0.9, 1.15), water = false, shadow = true })
				break
			end
		end
	end

	-- 4. Driftwood here and there at the waterline: branches and logs along the shore or poking
	-- into the water, stumps just up the bank.
	local rd = Scatter.rng(seed + 4)
	local drift = Scatter.poisson(rd, T.driftwood, 14, 4000, shoreSample, function(x, z)
		local w = Scatter.waterline(x, z)
		local near = Scatter.side(x, z) == "south"
		return w >= -1 and w <= 1.4 and free(x, z, 3) and not Scatter.inLane(x, z) and Scatter.pathEdge(pidx, x, z) > 0.5 and Scatter.next(rd) < (if near then 0.3 else 1)
	end, birches)
	for _, p in drift do
		local wx, wz = Scatter.toWater(p.x, p.z)
		local u = Scatter.next(rd)
		local model = if u < 0.4 then "DriftwoodBranch" elseif u < 0.75 then "DriftwoodLog" else "DriftwoodStump"
		local yaw
		if model ~= "DriftwoodStump" and Scatter.next(rd) < 0.3 then
			yaw = Scatter.yawAlongX(wx, wz) + Scatter.range(rd, -0.4, 0.4) -- one end in the water
		else
			yaw = Scatter.yawAlongX(-wz, wx) + Scatter.range(rd, -0.6, 0.6) -- along the shore
		end
		add({ model = model, group = "Driftwood", x = p.x, z = p.z, yaw = yaw, scale = Scatter.range(rd, 0.8, 1.2), water = false, shadow = false })
	end

	-- 5. A little undergrowth on the far bank's lip, between the water and the path.
	local rl = Scatter.rng(seed + 5)
	local function farLip(x: number, z: number): boolean
		local side = Scatter.side(x, z)
		return side == "north" or side == "ne" or side == "nw" or ((side == "east" or side == "west") and z < 10)
	end
	local lipCentres = Scatter.poisson(rl, T.lipClusters, 20, 4000, shoreSample, function(x, z)
		local w = Scatter.waterline(x, z)
		return w >= 0.6 and w <= 2.2 and farLip(x, z) and free(x, z, 3) and not Scatter.inLane(x, z) and Scatter.pathEdge(pidx, x, z) > 0.6
	end)
	local lip = Scatter.cluster(rl, lipCentres, { 2, 3 }, { 2, 4 }, 2.2, function(x, z)
		local w = Scatter.waterline(x, z)
		return w >= 0.6 and w <= 2.4 and free(x, z, 1) and not Scatter.inLane(x, z) and Scatter.pathEdge(pidx, x, z) > 0.6 and farEnough(birches, x, z, 2.5)
	end)
	for _, p in lip do
		local fern = Scatter.next(rl) < 0.6
		add({ model = if fern then pick(rl, "Fern1", "Fern2") else pick(rl, "Bush1", "Bush2"), group = "Lip", x = p.x, z = p.z, yaw = Scatter.range(rl, 0, TAU), scale = Scatter.range(rl, 0.8, 1.2), water = false, shadow = false })
	end

	-- 6. The treeline: pines (a birch now and then) behind the path on the north, east and west,
	-- Poisson-spaced under a slow density mask so stands and gaps come and go.
	local rt = Scatter.rng(seed + 6)
	local band = T.treeBand
	local function treeSide(x: number, z: number): boolean
		local side = Scatter.side(x, z)
		if side == "south" or side == "middle" then
			return false
		elseif side == "se" or side == "sw" then
			return z < 72
		end
		return true
	end
	local trees = Scatter.poisson(rt, T.treeMax, T.treeMinDist, 9000, function(r: Rng)
		return Scatter.range(r, -152, 152), Scatter.range(r, -126, 76)
	end, function(x, z)
		local d = Scatter.roundBox(x, z)
		if d < band[1] or d > band[2] or not treeSide(x, z) or not free(x, z, 3) then
			return false
		end
		if Scatter.pathEdge(pidx, x, z) <= 2.5 then
			return false
		end
		local mask = 0.3 + 0.7 * Scatter.noise(x, z, 30, seed + 11)
		if dockDist(x, z) > T.farDist then
			mask *= T.farKeep
		end
		return Scatter.next(rt) < mask
	end, birches)
	local forest: { Blob } = {}
	local under: { Pt } = {}
	for _, p in trees do
		local shadow = dockDist(p.x, p.z) < T.shadowDist
		if Scatter.next(rt) < T.birchMix then
			local wx, wz = Scatter.toWater(p.x, p.z)
			add({ model = pick(rt, "BirchLean1", "BirchLean2"), group = "Treeline", x = p.x, z = p.z, yaw = Scatter.yawMinusX(wx, wz) + Scatter.range(rt, -0.5, 0.5), scale = Scatter.range(rt, 0.85, 1.15), water = false, shadow = shadow })
		else
			add({ model = pick(rt, "ShorePine1", "ShorePine2"), group = "Treeline", x = p.x, z = p.z, yaw = Scatter.range(rt, 0, TAU), scale = Scatter.range(rt, 0.8, 1.2), water = false, shadow = shadow })
		end
		table.insert(forest, { x = p.x, z = p.z, r = Scatter.range(rt, 6, 9) })
		-- 7. Undergrowth at its foot.
		local n = Scatter.int(rt, T.underPer[1], T.underPer[2])
		local placed, k = 0, 0
		while placed < n and k < 12 do
			k += 1
			local a = Scatter.range(rt, 0, TAU)
			local d = Scatter.range(rt, 2.5, 6)
			local x, z = p.x + math.cos(a) * d, p.z + math.sin(a) * d
			if Scatter.roundBox(x, z) >= 9 and Scatter.pathEdge(pidx, x, z) > 0.8 and free(x, z, 1) and farEnough(under, x, z, T.underSpacing) and farEnough(trees, x, z, 2) then
				local u = Scatter.next(rt)
				local model = if u < 0.55 then pick(rt, "Fern1", "Fern2") elseif u < 0.9 then pick(rt, "Bush1", "Bush2") else "DriftwoodStump"
				table.insert(under, { x = x, z = z })
				add({ model = model, group = "Undergrowth", x = x, z = z, yaw = Scatter.range(rt, 0, TAU), scale = Scatter.range(rt, 0.8, 1.25), water = false, shadow = false })
				placed += 1
			end
		end
	end

	return { items = items, routes = routes, forest = forest, counts = counts }
end

return Scatter
