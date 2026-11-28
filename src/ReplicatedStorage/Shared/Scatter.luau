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
--    seeded sideways wobble (2 studs at most), a width of 5 to 7 studs, and no straight run;
--    and (N1 round 2) a gravel walk from the back lawn between the stands to the dock head;
--  * (N1 round 2) kit reeds over the weed bed (in place of the old Reeds copies), a second row of
--    far pines 34 to 60 studs back from the bank (no shadows), meadow-grass blobs on the south
--    lawn and a pine, bush and fern group at each outer south lawn corner. Pines on the hills
--    come from Scatter.hillPines, which takes the ground height as a function.
-- Everything keeps clear of the dock and slips, the stands, the pond, the chalkboard, the trophy
-- wall, the channel and its footbridge, the creek gate and every fishing spot's cast lane, and
-- (11/27/2026) of the fixed shot cameras (Scatter.SHOT_CAMS, mirroring tools/shots/shots.json).
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

-- `thin`: paint only the one cell under the centreline here (a single row of voxels).
export type Sample = { x: number, z: number, w: number, s: number, off: number, thin: boolean? }
export type Route = { name: string, samples: { Sample } }
export type WanderOpts = {
	amp: number, -- the wobble's reach, studs (2)
	thin: boolean?, -- paint as a single row of cells (Scatter.pathCells)
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

-- A Catmull-Rom curve through `pts` at about 1 stud steps (it passes through every point).
function Scatter.spline(pts: { Pt }): { Pt }
	local out: { Pt } = {}
	for i = 1, #pts - 1 do
		local p0, p1, p2, p3 = pts[math.max(1, i - 1)], pts[i], pts[i + 1], pts[math.min(#pts, i + 2)]
		local n = math.max(1, math.ceil(math.sqrt((p2.x - p1.x) ^ 2 + (p2.z - p1.z) ^ 2)))
		for k = (if i == 1 then 0 else 1), n do
			local t = k / n
			local t2, t3 = t * t, t * t * t
			local function f(a: number, b: number, c: number, d: number): number
				return 0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
			end
			table.insert(out, { x = f(p0.x, p1.x, p2.x, p3.x), z = f(p0.z, p1.z, p2.z, p3.z) })
		end
	end
	return out
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
		table.insert(samples, { x = p.x + nx * off, z = p.z + nz * off, w = w, s = s, off = off, thin = o.thin })
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

-- Terrain cells (`cell` studs, 4) to paint as path. A cell is painted when its centre lies within
-- half the path's width of the nearest centreline sample, or on a dithered fringe up to `soft`
-- (1.5) studs past that when the cell's seeded hash says so, and never further than just under
-- one cell (PATH_REACH) from the centreline. Then, across the route (along the grid step nearest
-- its normal), any run of more than 2 cells of one route loses the cells furthest from the
-- centreline: a 4 stud voxel grid cannot draw a 6 stud path smoothly, so the path is 1 or 2
-- cells that wander. (Before 11/27/2026 the fringe ran to 5 studs from the centreline, which put
-- 3 or 4 cells across a diagonal stretch and read as a 15 to 20 stud swath.) Samples marked
-- `thin` paint only the cell under the centreline, joined edge to edge: a single row. Every
-- route goes into the one set, so where routes meet nothing is painted twice.
Scatter.PATH_REACH = 0.975 -- of a cell: the furthest a painted cell's centre is from the centreline
local CROSS_STEPS = { { 1, 0 }, { 0, 1 }, { 1, 1 }, { 1, -1 } }
function Scatter.pathCells(routes: { Route }, cell: number, seed: number, soft: number?): { [number]: boolean }
	local sf = soft or 1.5
	local cap = cell * Scatter.PATH_REACH
	local excess: { [number]: number } = {} -- least (distance - half width) over every sample
	local dist: { [number]: number } = {} -- least distance to any centreline sample
	local owner: { [number]: number } = {} -- the route of that nearest sample
	local normal: { [number]: { number } } = {} -- and its unit normal
	local thinSet: { [number]: boolean } = {}
	for ri, rt in routes do
		local prev: { x: number, z: number, ix: number, iz: number }? = nil
		local ss = rt.samples
		for i, q in ss do
			if q.thin then
				local ix, iz = math.floor(q.x / cell), math.floor(q.z / cell)
				local p = prev
				if p then
					local px, pz = p.ix, p.iz
					-- Keep the last cell's column (row) while the line is within a stud of it, so a centreline
					-- running along a cell edge (the walk at x 0) does not flicker into two rows.
					if math.abs(q.x - (px + 0.5) * cell) <= cell / 2 + 1 then
						ix = px
					end
					if math.abs(q.z - (pz + 0.5) * cell) <= cell / 2 + 1 then
						iz = pz
					end
					if px ~= ix and pz ~= iz then
						-- A diagonal step: fill the corner nearer the step's middle, so the row joins
						-- edge to edge.
						local mx, mz = (p.x + q.x) / 2, (p.z + q.z) / 2
						local ax, az = (ix + 0.5) * cell, (pz + 0.5) * cell
						local bx, bz = (px + 0.5) * cell, (iz + 0.5) * cell
						if (ax - mx) ^ 2 + (az - mz) ^ 2 <= (bx - mx) ^ 2 + (bz - mz) ^ 2 then
							thinSet[Scatter.key(ix, pz)] = true
						else
							thinSet[Scatter.key(px, iz)] = true
						end
					end
				end
				thinSet[Scatter.key(ix, iz)] = true
				prev = { x = q.x, z = q.z, ix = ix, iz = iz }
			else
				prev = nil
				local a, b = ss[math.max(1, i - 1)], ss[math.min(#ss, i + 1)]
				local tx, tz = b.x - a.x, b.z - a.z
				local tl = math.max(1e-9, math.sqrt(tx * tx + tz * tz))
				local R = math.min(q.w / 2 + sf, cap)
				for ix = math.floor((q.x - R) / cell), math.floor((q.x + R) / cell) do
					for iz = math.floor((q.z - R) / cell), math.floor((q.z + R) / cell) do
						local cx, cz = (ix + 0.5) * cell, (iz + 0.5) * cell
						local d = math.sqrt((cx - q.x) ^ 2 + (cz - q.z) ^ 2)
						local k = Scatter.key(ix, iz)
						if d - q.w / 2 < (excess[k] or math.huge) then
							excess[k] = d - q.w / 2
						end
						if d < (dist[k] or math.huge) then
							dist[k] = d
							owner[k] = ri
							normal[k] = { -tz / tl, tx / tl }
						end
					end
				end
			end
		end
	end
	local set: { [number]: boolean } = {}
	local band: { number } = {}
	for k, e in excess do
		local ix, iz = Scatter.unkey(k)
		if dist[k] < cap and (e <= 0 or (e < sf and Scatter.hash(ix, iz, seed + 7) > e / sf)) then
			set[k] = true
			if not thinSet[k] then
				table.insert(band, k)
			end
		end
	end
	-- At most 2 cells across: walk each band cell's run along its cross step (cells of the same
	-- route only, so where routes meet both stay whole) and drop the furthest until 2 are left.
	table.sort(band)
	local function prunable(k: number, ri: number): boolean
		return set[k] == true and not thinSet[k] and owner[k] == ri
	end
	for _, k in band do
		while set[k] do
			local ix, iz = Scatter.unkey(k)
			local n = normal[k]
			local sx, sz, best = 1, 0, -1
			for _, st in CROSS_STEPS do
				local c = math.abs(st[1] * n[1] + st[2] * n[2]) / (if st[1] ~= 0 and st[2] ~= 0 then math.sqrt(2) else 1)
				if c > best then
					sx, sz, best = st[1], st[2], c
				end
			end
			local run = { k }
			for _, dir in { 1, -1 } do
				local j = 1
				while true do
					local k2 = Scatter.key(ix + sx * dir * j, iz + sz * dir * j)
					if not prunable(k2, owner[k]) then
						break
					end
					table.insert(run, k2)
					j += 1
				end
			end
			if #run <= 2 then
				break
			end
			local far = run[1]
			for _, k2 in run do
				if dist[k2] > dist[far] or (dist[k2] == dist[far] and k2 > far) then
					far = k2
				end
			end
			set[far] = nil
		end
	end
	for k in thinSet do
		set[k] = true
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

-- The terrain grid BankDress paints on (studs per voxel).
local PAINT_CELL = 4
Scatter.PAINT_CELL = PAINT_CELL

-- True when (x, z), or any point `r` studs from it in the four grid directions and the four
-- diagonals, falls in a cell of `cells`.
function Scatter.onCells(cells: { [number]: boolean }, x: number, z: number, r: number, cell: number): boolean
	local d = r * 0.7071
	for _, o in { { 0, 0 }, { r, 0 }, { -r, 0 }, { 0, r }, { 0, -r }, { d, d }, { d, -d }, { -d, d }, { -d, -d } } do
		if cells[Scatter.key(math.floor((x + o[1]) / cell), math.floor((z + o[2]) / cell))] then
			return true
		end
	end
	return false
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
	-- N1 round 2 (coming): the far pines and far leafy trees, about 1.0 deep.
	FarPine1 = 1.0,
	FarPine2 = 1.0,
	FarLeafy1 = 1.0,
	FarLeafy2 = 1.0,
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
	-- N1 round 2: the bank between the dock head and the chalkboard stays open (cattails there
	-- hid the chalkboard from the dock in shot 08).
	{ name = "DockHeadChalk", x1 = -16, x2 = 46, z1 = 72, z2 = 100 },
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
	-- N1 round 4 (the advisor, review 2: the bare sand ring): reeds 12 to 26, stones 14 to 30,
	-- the lip 7 to 20, driftwood 8 to 12, and the treeline from 6 studs back (was 13).
	reedClusters = 26,
	reedPer = { 3, 6 },
	reedSpacing = 2.4,
	stoneGroups = 30,
	stonePer = { 2, 4 },
	stoneSpacing = 1.6,
	birches = { 3, 5 }, -- leaning out from the points of land
	driftwood = 12,
	lipClusters = 20, -- undergrowth on the far bank's lip
	treeMinDist = 8,
	treeMax = 140,
	treeBand = { 6, 34 }, -- studs back from the bank (the path's outer edge is at most 10.5)
	-- N1 round 4: a front row of trees 2 to 6 studs back from the water on the treeline sides,
	-- lite and far models (ShorePine2's lite copy and the far leafy trees), clear of the path.
	frontRow = 30,
	frontBand = { 2, 6 }, -- studs back from the drawn waterline (Scatter.waterline)
	frontMinDist = 6,
	frontFallback = { 1, 3.5 }, -- studs from the path's edge, land side, where the strip is too narrow
	frontKitShare = 0, -- share of ShorePine2 (lite, 697 triangles); the rest far leafy 60%, far pine 40%
	-- N1 round 4: behind the stands (z 96), far pines and a few kit pines 30 to 70 studs south,
	-- so the sky never meets a bare hill in shot 08.
	backFar = 25,
	backKit = 6,
	backZ = { 126, 166 },
	backX = { -75, 75 },
	backMinDist = 7,
	-- N1 round 4: ground. Sand more than sandKeep studs from the water on the treeline sides goes
	-- to meadow (forest floor in a blob); the green hill floor (slot 27) runs northFloor studs back
	-- behind the north shore.
	sandKeep = 4,
	sandReach = 30, -- only within this far of the water (the home lake's beach ring)
	northFloor = { 6, 70 },
	birchMix = 0.1,
	underPer = { 0, 3 },
	underSpacing = 2,
	farDist = 165, -- trees past this far from the dock thin out...
	farKeep = 0.7, -- ...to this share
	shadowDist = 110, -- and cast no shadow past this (N1 round 2: was 150)
	-- N1 round 2.
	weedClusters = 4, -- kit reeds over the weed bed (they replace the old Reeds copies)
	weedPer = { 3, 5 },
	farRow = 80, -- the second row of far pines (FarPine1/2), no shadows
	farBand = { 34, 60 }, -- studs back from the bank (Scatter.roundBox)
	farMinDist = 7,
	farZMin = -134, -- clear of the Big Lake's south shore (z -140)
	farXMin = -170, -- clear of the creek
	hillPines = 40, -- far pines on the hills round the world
	hillBand = { 60, 300 },
	hillMinHeight = 4, -- ground at least this high counts as a hill (the flat land's top is 1)
	hillMinDist = 8,
	meadowBlobs = { 6, 8 }, -- tall meadow grass (terrain slot 2, with blades) on the south lawn
	meadowR = { 5, 8 },
}

export type Item = {
	model: string,
	group: string, -- Reeds, Stones, Birches, Driftwood, Lip, Treeline, Undergrowth, FarRow,
	-- HillPines, CornerTree, CornerUnder, FrontRow, BackRow, Seams (and BankDress's TreeSwap)
	x: number,
	z: number,
	yaw: number,
	scale: number,
	water: boolean, -- true: stands in the water (pivot from the surface, y 0), else on the terrain
	shadow: boolean,
	sink: number?, -- studs more to bury it (Scatter.seatReeds: a reed clump on ground above the water)
}

export type Plan = {
	items: { Item },
	routes: { Route },
	forest: { Blob },
	meadow: { Blob }, -- tall meadow grass on the lawn (terrain slot 2)
	counts: { [string]: number },
}

-- Which CollectionService tag the client's phone tier (ClientModules/FoliageTier) reads for a
-- group; nil for none (driftwood).
Scatter.TAGS = {
	Reeds = "FoliageReed",
	Stones = "FoliageStone",
	Lip = "FoliageUnder",
	Undergrowth = "FoliageUnder",
	CornerUnder = "FoliageUnder",
	Seams = "FoliageUnder", -- the seam plants and stones (Scatter.seams), stones too
	Birches = "FoliageTree",
	Treeline = "FoliageTree",
	FarRow = "FoliageTree",
	HillPines = "FoliageTree",
	CornerTree = "FoliageTree",
	TreeSwap = "FoliageTree",
	FrontRow = "FoliageTree",
	BackRow = "FoliageTree",
	CrestPines = "FoliageTree", -- far pines on the horizon's hill crests (Scatter.crestPines)
	FootReeds = "FoliageReed", -- either side of the dock foot (N1 close-out)
	FootStones = "FoliageStone",
} :: { [string]: string }

-- True for the far models (FarPine1/2, FarLeafy1/2): the phone tier hides every second one
-- nearer than the kit trees (ClientModules/FoliageTier, FoliageFar).
function Scatter.isFar(model: string): boolean
	return string.sub(model, 1, 3) == "Far"
end

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

-- (N1 close-out) The bank's modelled ground height over the water's surface (y 0) at (x, z):
-- WaterLook's bank rises ShoreEdge.SLOPE studs per stud from the drawn waterline. Negative under
-- the water. Only near the waterline is it the real ground (the land tops out at y 1).
function Scatter.bankHeight(x: number, z: number): number
	return Scatter.waterline(x, z) * ShoreEdge.SLOPE
end
-- A reed clump stands no more than this over the water (the advisor, N1 review 3: cattails on dry
-- sand with their bases cut off in shot 05).
Scatter.REED_DRY = 0.3
-- The wet sand band reaches this far over the water (MaterialKit.WET_ABOVE).
Scatter.WET_ABOVE = 1.5
-- The sand at the dock foot (shot 08's lime grass blobs: meadow baked onto the shore sand there).
Scatter.DOCK_FOOT = { name = "DockFoot", x1 = -22, x2 = 22, z1 = 75, z2 = 92 }

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

-- The fixed shot cameras. This table MIRRORS tools/shots/shots.json (sets A and B, each shot's
-- `eye` and `look`; shots that share a camera are listed once): change both together. Nothing
-- stands within SHOT_EYE_R of an eye (a sphere), and no tree within SHOT_LINE_R of the first
-- SHOT_LINE studs of the line from the eye toward its look (a capsule). Props may stand
-- anywhere outside the spheres.
export type ShotCam = { id: string, eye: { number }, look: { number } }
Scatter.SHOT_CAMS = {
	{ id = "01-dock-dawn, 02-dock-golden", eye = { 0, 8, 117 }, look = { 0, 0, 25 } },
	{ id = "03-dockend-noon, 04-dockend-night", eye = { 0, 6, 37 }, look = { 0, 0, -55 } },
	{ id = "05-weedbed-golden", eye = { -94, 7, 87 }, look = { -77, -1, 38 } },
	{ id = "06-logs-dawn", eye = { 126, 7, 65 }, look = { 76, -1, 46 } },
	{ id = "07-overview-golden", eye = { 86, 80, 165 }, look = { 0, 0, 0 } },
	{ id = "08-stands-noon", eye = { 0, 6, 50 }, look = { 11, 4, 100 } },
	-- Neon's N3 review, Pass 1 (11/28/2026): 09 low at the riffle mouth looking up the chute, 10
	-- and 12 from the pool's east bank edge, 11 down the gravel walk toward the gate.
	{ id = "09-riffle-dawn", eye = { -223.5, 4.5, 25 }, look = { -231, 1.5, 68 } },
	{ id = "10-pool-golden, 12-pool-night", eye = { -210, 5.2, -16 }, look = { -236, 0.5, -54 } },
	{ id = "11-gate-noon", eye = { -140, 5.5, 8 }, look = { -166, 3.8, -1 } },
	{ id = "b01-bridge-dawn", eye = { 12, 5, -48 }, look = { 0, 5, -95 } },
	{ id = "b02-basin-boat-noon", eye = { -20, 4, -180 }, look = { -90, 3, -245 } },
	{ id = "b03-lighthouse-golden", eye = { -32, 5, -224 }, look = { -72, 2, -239 } },
	{ id = "b04-buoys-dusk", eye = { 52, 4, -282 }, look = { -80, 0, -292 } },
	{ id = "b05-bluewater-noon", eye = { 24, 5, -280 }, look = { 50, 0, -420 } },
	{ id = "b06-marina-night", eye = { 80, 7, -205 }, look = { 40, 2, -140 } },
	-- Set P, the making-of's prime shots (docs/looks/prime-shots.md, 11/28/2026): the three with
	-- eyes of their own (the others reuse set A eyes: p03 is 05's bank, p04 03's, p06 08's and
	-- p08 10's since Neon's N3 review, Pass 1; p07 has its own since N3 review 3).
	{ id = "p01-lake-high-golden", eye = { 78, 46, 172 }, look = { 7, 0, 13 } },
	{ id = "p02-dock-dawn", eye = { -2.4, 6, 76 }, look = { 2, 3.4, 30 } },
	{ id = "p05-sellstand-morning", eye = { -3, 6, 66 }, look = { -18, 6.2, 96 } },
	-- N3 review 3 (final, 11/28/2026): p07 low in the riffle looking up the chute, its own eye.
	{ id = "p07-riffle-morning", eye = { -229.5, 2.8, 27 }, look = { -230.5, 1.6, 60 } },
} :: { ShotCam }
Scatter.SHOT_EYE_R = 8
-- N1 round 4 (the advisor, review 2): a tree's keep-clear counts its canopy, not just its trunk
-- (a pine 9 studs off 06's line still filled the frame), so trees keep 16 from an eye and 9 from
-- the line. Props keep SHOT_EYE_R.
Scatter.SHOT_EYE_R_TREE = 16
Scatter.SHOT_LINE = 25
Scatter.SHOT_LINE_R = 9
-- How tall a placed thing is taken to be, from y 0 (the water; the ground is y 1): trees and the
-- rest.
Scatter.TREE_H = 40
Scatter.PROP_H = 4

-- Distance in x, z from (x, z) to the segment (ax, az)-(bx, bz).
local function segDist(x: number, z: number, ax: number, az: number, bx: number, bz: number): number
	local dx, dz = bx - ax, bz - az
	local l2 = dx * dx + dz * dz
	local t = if l2 > 0 then math.clamp(((x - ax) * dx + (z - az) * dz) / l2, 0, 1) else 0
	return math.sqrt((x - ax - dx * t) ^ 2 + (z - az - dz * t) ^ 2)
end

-- True when something standing at (x, z) (a tree when `tree`) keeps clear of every shot camera:
-- its upright (y 0 to its height) stays SHOT_EYE_R (a tree: SHOT_EYE_R_TREE) from each eye, and a
-- tree's stays SHOT_LINE_R from the first SHOT_LINE studs of each eye-to-look line.
function Scatter.shotClear(x: number, z: number, tree: boolean): boolean
	local H = if tree then Scatter.TREE_H else Scatter.PROP_H
	local R = if tree then Scatter.SHOT_EYE_R_TREE else Scatter.SHOT_EYE_R
	for _, c in Scatter.SHOT_CAMS do
		local ex, ey, ez = c.eye[1], c.eye[2], c.eye[3]
		local h2 = (x - ex) ^ 2 + (z - ez) ^ 2
		local dy = math.max(0, ey - H, -ey)
		if h2 + dy * dy < R * R then
			return false
		end
		if tree then
			local lx, ly, lz = c.look[1] - ex, c.look[2] - ey, c.look[3] - ez
			local len = math.sqrt(lx * lx + ly * ly + lz * lz)
			local f = math.min(1, Scatter.SHOT_LINE / len)
			-- The part of the first SHOT_LINE studs whose height is within the tree's (0 to H): the
			-- line is straight, so that is one stretch t0..t1 of it.
			local y0, y1 = ey, ey + ly * f
			local t0, t1 = 0, 1
			if y1 ~= y0 then
				local ta, tb = (0 - y0) / (y1 - y0), (H - y0) / (y1 - y0)
				t0, t1 = math.max(0, math.min(ta, tb)), math.min(1, math.max(ta, tb))
			elseif y0 < 0 or y0 > H then
				t0, t1 = 1, 0
			end
			if t0 <= t1 then
				local ax, az = ex + lx * f * t0, ez + lz * f * t0
				local bx, bz = ex + lx * f * t1, ez + lz * f * t1
				if segDist(x, z, ax, az, bx, bz) < Scatter.SHOT_LINE_R then
					return false
				end
			end
		end
	end
	return true
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

-- The treeline's sides: north, east and west, and the south corners only up to z 72 (the near
-- shore, the dock's, stays open).
function Scatter.treeSide(x: number, z: number): boolean
	local side = Scatter.side(x, z)
	if side == "south" or side == "middle" then
		return false
	elseif side == "se" or side == "sw" then
		return z < 72
	end
	return true
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
	local routes = {
		Scatter.wander("LakeLoop", ring, r, { amp = 2, pinEnds = true, pinFade = 9, pinWidth = 6, wMin = 5, wMax = 7 }),
		Scatter.wander("PathToCreek", link, r, { amp = 2, pins = { { x = -162, z = 0 } }, pinFade = 9, pinWidth = 5.5, wMin = 5, wMax = 7 }),
		-- Its left-hand normal points west, at the pool 5 studs away: lean the wobble east.
		Scatter.wander("BankPath", bank, r, { amp = 2, bias = -0.7, wMin = 5, wMax = 6.5 }),
	}
	-- N1 round 2: the walk from the back lawn, between the two stands (x +-18), to the dock head,
	-- where it meets the loop (z 85). Its own stream, so the three routes above do not move.
	-- (11/27/2026) It is painted as a single row of cells (thin), so it reads as a footworn track
	-- across the lawn and not a second road; it joins the loop's band at the dock head.
	local rw = Scatter.rng(seed + 102)
	table.insert(routes, Scatter.wander("StandsWalk", Scatter.spline(Scatter.WALK), rw, { amp = 2, thin = true, pins = { { x = 0, z = 97 }, { x = 0, z = 86 } }, pinFade = 9, pinWidth = 6, wMin = 5, wMax = 7 }))
	return routes
end

-- The walk's control points (back lawn to the dock head): it bends one way, then the other, so
-- no 30 stud stretch runs straight, but keeps close to north-south (11/27/2026: it started at
-- x -12 and swung 18 studs across the lawn, a broad diagonal in shots 01 and 02).
Scatter.WALK = {
	{ x = -5, z = 136 },
	{ x = -1, z = 126 },
	{ x = 4, z = 117 },
	{ x = 3, z = 107 },
	{ x = 0, z = 97 },
	{ x = 0, z = 86 },
} :: { Pt }

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
	-- (N1 round 4) The painted gravel itself: nothing on land stands on a path cell (a bush stood
	-- on the gravel in shot 06; the cells reach past the path's drawn edge).
	local pcells = Scatter.pathCells(routes, PAINT_CELL, seed)
	local function offPath(x: number, z: number, r: number): boolean
		return not Scatter.onCells(pcells, x, z, r, PAINT_CELL)
	end
	local function shoreSample(r: Rng): (number, number)
		return Scatter.range(r, -124, 124), Scatter.range(r, -94, 94)
	end
	-- Darts for the shore bands (N1 round 4: was 4000, which capped the stones at about 14 groups
	-- whatever the tuning asked for; the bands are a stud or two wide).
	local SHORE_TRIES = 16000
	local function free(x: number, z: number, pad: number?): boolean
		-- (11/27/2026) and out of every shot camera's sphere (Scatter.shotClear).
		return not Scatter.kept(x, z, pad) and Scatter.shotClear(x, z, false)
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
	local reedCentres = Scatter.poisson(rr, T.reedClusters, 18, SHORE_TRIES, shoreSample, function(x, z)
		local w = Scatter.waterline(x, z)
		return w >= -5 and w <= -1.5 and free(x, z, 4) and not Scatter.inLane(x, z) and Scatter.next(rr) < reedWeight(x, z)
	end)
	local reeds = Scatter.cluster(rr, reedCentres, T.reedPer, { 3, 6 }, T.reedSpacing, function(x, z)
		local w = Scatter.waterline(x, z)
		return w >= -6 and w <= -0.8 and Scatter.bankHeight(x, z) <= Scatter.REED_DRY and free(x, z, 2) and not Scatter.inLane(x, z)
	end)
	for _, p in reeds do
		add({ model = pick(rr, "ReedClump1", "ReedClump2"), group = "Reeds", x = p.x, z = p.z, yaw = Scatter.range(rr, 0, TAU), scale = Scatter.range(rr, 0.8, 1.2), water = true, shadow = false })
	end

	-- 1b. Kit reeds over the weed bed (N1 round 2), where the old Reeds copies stood (x -102..-54,
	-- z 11..65), in a few clumps clear of its two cast lanes.
	local rw = Scatter.rng(seed + 12)
	local function weedOk(x: number, z: number): boolean
		return Scatter.waterline(x, z) <= -3 and Scatter.bankHeight(x, z) <= Scatter.REED_DRY and free(x, z, 2) and not Scatter.inLane(x, z)
	end
	local weedCentres = Scatter.poisson(rw, T.weedClusters, 12, 2000, function(r: Rng)
		return Scatter.range(r, -98, -60), Scatter.range(r, 18, 58)
	end, weedOk)
	local weed = Scatter.cluster(rw, weedCentres, T.weedPer, { 3, 6 }, T.reedSpacing, function(x, z)
		return weedOk(x, z) and farEnough(reeds, x, z, T.reedSpacing)
	end)
	for _, p in weed do
		table.insert(reeds, p)
		add({ model = pick(rw, "ReedClump1", "ReedClump2"), group = "Reeds", x = p.x, z = p.z, yaw = Scatter.range(rw, 0, TAU), scale = Scatter.range(rw, 0.8, 1.2), water = true, shadow = false })
	end

	-- 2. Stones in small groups at the waterline, half sunk; fewer along the near shore.
	local rs = Scatter.rng(seed + 2)
	local stoneCentres = Scatter.poisson(rs, T.stoneGroups, 16, SHORE_TRIES, shoreSample, function(x, z)
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
			if w >= 1 and w <= 3 and Scatter.pathEdge(pidx, x, z) > 1.5 and offPath(x, z, 1) and free(x, z, 2) and Scatter.shotClear(x, z, true) and farEnough(birches, x, z, 10) then
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
	local drift = Scatter.poisson(rd, T.driftwood, 14, SHORE_TRIES, shoreSample, function(x, z)
		local w = Scatter.waterline(x, z)
		local near = Scatter.side(x, z) == "south"
		return w >= -1 and w <= 1.4 and free(x, z, 3) and not Scatter.inLane(x, z) and Scatter.pathEdge(pidx, x, z) > 0.5 and offPath(x, z, 1.2) and Scatter.next(rd) < (if near then 0.3 else 1)
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
	local lipCentres = Scatter.poisson(rl, T.lipClusters, 20, SHORE_TRIES, shoreSample, function(x, z)
		local w = Scatter.waterline(x, z)
		return w >= 0.6 and w <= 2.2 and farLip(x, z) and free(x, z, 3) and not Scatter.inLane(x, z) and Scatter.pathEdge(pidx, x, z) > 0.6 and offPath(x, z, 1.2)
	end)
	local lip = Scatter.cluster(rl, lipCentres, { 2, 3 }, { 2, 4 }, 2.2, function(x, z)
		local w = Scatter.waterline(x, z)
		return w >= 0.6 and w <= 2.4 and free(x, z, 1) and not Scatter.inLane(x, z) and Scatter.pathEdge(pidx, x, z) > 0.6 and offPath(x, z, 1.2) and farEnough(birches, x, z, 2.5)
	end)
	for _, p in lip do
		local fern = Scatter.next(rl) < 0.6
		add({ model = if fern then pick(rl, "Fern1", "Fern2") else pick(rl, "Bush1", "Bush2"), group = "Lip", x = p.x, z = p.z, yaw = Scatter.range(rl, 0, TAU), scale = Scatter.range(rl, 0.8, 1.2), water = false, shadow = false })
	end

	-- 6. The treeline: pines (a birch now and then) behind the path on the north, east and west,
	-- Poisson-spaced under a slow density mask so stands and gaps come and go.
	local rt = Scatter.rng(seed + 6)
	local band = T.treeBand
	local treeSide = Scatter.treeSide
	local trees = Scatter.poisson(rt, T.treeMax, T.treeMinDist, 9000, function(r: Rng)
		return Scatter.range(r, -152, 152), Scatter.range(r, -126, 76)
	end, function(x, z)
		local d = Scatter.roundBox(x, z)
		if d < band[1] or d > band[2] or not treeSide(x, z) or not free(x, z, 3) or not Scatter.shotClear(x, z, true) then
			return false
		end
		if Scatter.pathEdge(pidx, x, z) <= 2.5 or not offPath(x, z, 1.5) then
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
			if Scatter.roundBox(x, z) >= 9 and Scatter.pathEdge(pidx, x, z) > 0.8 and offPath(x, z, 1.2) and free(x, z, 1) and farEnough(under, x, z, T.underSpacing) and farEnough(trees, x, z, 2) then
				local u = Scatter.next(rt)
				local model = if u < 0.55 then pick(rt, "Fern1", "Fern2") elseif u < 0.9 then pick(rt, "Bush1", "Bush2") else "DriftwoodStump"
				table.insert(under, { x = x, z = z })
				add({ model = model, group = "Undergrowth", x = x, z = z, yaw = Scatter.range(rt, 0, TAU), scale = Scatter.range(rt, 0.8, 1.25), water = false, shadow = false })
				placed += 1
			end
		end
	end

	-- 8. The second row (N1 round 2): far pines 34 to 60 studs back from the bank on the treeline
	-- sides, clumped by a slow mask like the treeline's, never casting a shadow.
	local rf = Scatter.rng(seed + 13)
	local fb = T.farBand
	local far = Scatter.poisson(rf, T.farRow, T.farMinDist, 12000, function(r: Rng)
		return Scatter.range(r, -175, 175), Scatter.range(r, -146, 76)
	end, function(x, z)
		local d = Scatter.roundBox(x, z)
		if d < fb[1] or d > fb[2] or z < T.farZMin or x < T.farXMin or not treeSide(x, z) or not free(x, z, 3) or not Scatter.shotClear(x, z, true) then
			return false
		end
		if Scatter.pathEdge(pidx, x, z) <= 2.5 or not offPath(x, z, 1.5) or not farEnough(trees, x, z, 5) then
			return false
		end
		return Scatter.next(rf) < 0.35 + 0.65 * Scatter.noise(x, z, 34, seed + 14)
	end, birches)
	for _, p in far do
		add({ model = pick(rf, "FarPine1", "FarPine2"), group = "FarRow", x = p.x, z = p.z, yaw = Scatter.range(rf, 0, TAU), scale = Scatter.range(rf, 0.9, 1.3), water = false, shadow = false })
		table.insert(forest, { x = p.x, z = p.z, r = Scatter.range(rf, 6, 9) })
	end

	-- 9. The south lawn (N1 round 2): tall meadow-grass blobs away from the walk and the keep
	-- boxes, and a pine, bush and fern group at each outer corner.
	local rm = Scatter.rng(seed + 15)
	local meadow: { Blob } = {}
	local wantMeadow = Scatter.int(rm, T.meadowBlobs[1], T.meadowBlobs[2])
	for _ = 1, 4000 do
		if #meadow >= wantMeadow then
			break
		end
		local x, z = Scatter.range(rm, -100, 100), Scatter.range(rm, 92, 134)
		local rad = Scatter.range(rm, T.meadowR[1], T.meadowR[2])
		local reach = rad * 1.3 -- blobCells swells an edge to 1.3 of the radius at most
		local ok = Scatter.roundBox(x, z) >= 12 + reach and not Scatter.kept(x, z, reach + 2) and Scatter.pathEdge(pidx, x, z) > reach + 2
		if ok then
			for _, b in meadow do
				if (b.x - x) ^ 2 + (b.z - z) ^ 2 < (b.r + rad + 10) ^ 2 then
					ok = false
					break
				end
			end
		end
		if ok then
			table.insert(meadow, { x = x, z = z, r = rad })
		end
	end
	local rc = Scatter.rng(seed + 16)
	local cornerPts: { Pt } = {}
	for _, cx in { -100, 100 } do
		local centre = { x = cx + Scatter.range(rc, -4, 4), z = 118 + Scatter.range(rc, -4, 4) }
		local function ok(x: number, z: number, gap: number): boolean
			return free(x, z, 2) and Scatter.pathEdge(pidx, x, z) > 1.5 and offPath(x, z, 1.5) and Scatter.roundBox(x, z) >= 10 and farEnough(cornerPts, x, z, gap)
		end
		if ok(centre.x, centre.z, 0) and Scatter.shotClear(centre.x, centre.z, true) then
			table.insert(cornerPts, centre)
			add({ model = pick(rc, "ShorePine1", "ShorePine2"), group = "CornerTree", x = centre.x, z = centre.z, yaw = Scatter.range(rc, 0, TAU), scale = Scatter.range(rc, 0.85, 1.1), water = false, shadow = dockDist(centre.x, centre.z) < T.shadowDist })
		end
		local want = Scatter.int(rc, 5, 7)
		local placed, k = 0, 0
		while placed < want and k < 60 do
			k += 1
			local a = Scatter.range(rc, 0, TAU)
			local d = Scatter.range(rc, 3, 8)
			local x, z = centre.x + math.cos(a) * d, centre.z + math.sin(a) * d
			if ok(x, z, 2.2) then
				table.insert(cornerPts, { x = x, z = z })
				local fern = Scatter.next(rc) < 0.5
				add({ model = if fern then pick(rc, "Fern1", "Fern2") else pick(rc, "Bush1", "Bush2"), group = "CornerUnder", x = x, z = z, yaw = Scatter.range(rc, 0, TAU), scale = Scatter.range(rc, 0.85, 1.3), water = false, shadow = false })
				placed += 1
			end
		end
	end

	-- 10. The front row (N1 round 4): trees 2 to 6 studs back from the water on the treeline
	-- sides, so the bank is not a bare sand ring with the woods starting 13 back. Far models by
	-- default (the overview's triangle budget, 40k for all of round 4; frontKitShare brings in
	-- ShorePine2's lite copy). Out of the cast lanes (with a 2 stud margin), the keep-clears, the
	-- shot cameras and off the path's gravel.
	local rfr = Scatter.rng(seed + 19)
	local fbd = T.frontBand
	local frontOthers: { Pt } = table.clone(birches)
	for _, p in trees do
		table.insert(frontOthers, p)
	end
	local function frontOk(x: number, z: number): boolean
		if not treeSide(x, z) or not free(x, z, 3) or not Scatter.shotClear(x, z, true) then
			return false
		end
		for _, l in Scatter.LANES do
			if Scatter.laneDist(l, x, z) <= l.r + 2 or (x - l.x1) ^ 2 + (z - l.z1) ^ 2 <= (Scatter.LANE_FOOT + 2) ^ 2 then
				return false
			end
		end
		return offPath(x, z, 1.5)
	end
	local front = Scatter.poisson(rfr, T.frontRow, T.frontMinDist, SHORE_TRIES, shoreSample, function(x, z)
		local w = Scatter.waterline(x, z)
		return w >= fbd[1] and w <= fbd[2] and Scatter.pathEdge(pidx, x, z) > 1 and frontOk(x, z)
	end, frontOthers)
	-- The lake loop runs 5 studs off the bank, so the strip between the water and the gravel is
	-- mostly too narrow for a tree (about 7 fit). The rest stand just behind the path, frontFallback
	-- studs from its edge on the land side, still in front of the treeline.
	if #front < T.frontRow then
		local fbk = T.frontFallback
		local more = Scatter.poisson(rfr, T.frontRow - #front, T.frontMinDist, SHORE_TRIES, function(r: Rng)
			return Scatter.range(r, -132, 132), Scatter.range(r, -102, 102)
		end, function(x, z)
			local e = Scatter.pathEdge(pidx, x, z)
			return Scatter.roundBox(x, z) > 5 and e > fbk[1] and e <= fbk[2] and frontOk(x, z) and farEnough(front, x, z, T.frontMinDist)
		end, frontOthers)
		for _, p in more do
			table.insert(front, p)
		end
	end
	for _, p in front do
		local u = Scatter.next(rfr)
		if u < T.frontKitShare then
			local shadow = dockDist(p.x, p.z) < T.shadowDist
			add({ model = "ShorePine2", group = "FrontRow", x = p.x, z = p.z, yaw = Scatter.range(rfr, 0, TAU), scale = Scatter.range(rfr, 0.8, 1.05), water = false, shadow = shadow })
		elseif u < T.frontKitShare + (1 - T.frontKitShare) * 0.6 then
			add({ model = pick(rfr, "FarLeafy1", "FarLeafy2"), group = "FrontRow", x = p.x, z = p.z, yaw = Scatter.range(rfr, 0, TAU), scale = Scatter.range(rfr, 0.8, 1.1), water = false, shadow = false })
		else
			add({ model = pick(rfr, "FarPine1", "FarPine2"), group = "FrontRow", x = p.x, z = p.z, yaw = Scatter.range(rfr, 0, TAU), scale = Scatter.range(rfr, 0.8, 1.1), water = false, shadow = false })
		end
	end

	-- 11. Behind the stands (N1 round 4): a few kit pines in the first 14 studs of the band and far
	-- pines through all of it (30 to 70 studs south of the stands), so the sky in shot 08 meets
	-- trees, not a bare hill. Clear of the walk, the corner groups and the shot cameras.
	local rbk = Scatter.rng(seed + 20)
	local bz, bx = T.backZ, T.backX
	local function backOk(x: number, z: number): boolean
		return free(x, z, 3) and Scatter.shotClear(x, z, true) and Scatter.pathEdge(pidx, x, z) > 2.5 and offPath(x, z, 1.5) and farEnough(cornerPts, x, z, 4)
	end
	local backKit = Scatter.poisson(rbk, T.backKit, T.backMinDist + 3, 3000, function(r: Rng)
		return Scatter.range(r, bx[1], bx[2]), Scatter.range(r, bz[1], bz[1] + 14)
	end, backOk)
	for _, p in backKit do
		add({ model = pick(rbk, "ShorePine1", "ShorePine2"), group = "BackRow", x = p.x, z = p.z, yaw = Scatter.range(rbk, 0, TAU), scale = Scatter.range(rbk, 0.9, 1.15), water = false, shadow = dockDist(p.x, p.z) < T.shadowDist })
	end
	local backFar = Scatter.poisson(rbk, T.backFar, T.backMinDist, 6000, function(r: Rng)
		return Scatter.range(r, bx[1], bx[2]), Scatter.range(r, bz[1], bz[2])
	end, function(x, z)
		return backOk(x, z) and Scatter.next(rbk) < 0.45 + 0.55 * Scatter.noise(x, z, 26, seed + 21)
	end, backKit)
	for _, p in backFar do
		add({ model = pick(rbk, "FarPine1", "FarPine2"), group = "BackRow", x = p.x, z = p.z, yaw = Scatter.range(rbk, 0, TAU), scale = Scatter.range(rbk, 1.0, 1.4), water = false, shadow = false })
	end

	-- 12. The dock foot (N1 close-out, the advisor's review 3): a few shore stones and one reed
	-- clump each side of where the dock meets the bank, inside the dock head's keep-out (which
	-- only has to keep the chalkboard in sight from the dock) but clear of the deck, the slips
	-- (x 6 to 22), the stands, the cast lanes, the paths and shot 08's sight line to the chalkboard.
	local rdf = Scatter.rng(seed + 22)
	local sight: Lane = { name = "ChalkSight", x1 = 0, z1 = 50, x2 = 30, z2 = 94, r = 3 }
	local footPts: { Pt } = {}
	local function footOk(x: number, z: number, reed: boolean): boolean
		for _, b in Scatter.KEEP_BOXES do
			if b.name ~= "DockHeadChalk" and Scatter.inBox(b, x, z, 1) then
				return false
			end
		end
		if math.abs(x) < 10 or (x >= 5 and x <= 23) or Scatter.inLane(x, z) or not Scatter.shotClear(x, z, false) then
			return false
		end
		if Scatter.laneDist(sight, x, z) <= (if reed then 4 else 2) then
			return false
		end
		return offPath(x, z, 1.2) and farEnough(footPts, x, z, if reed then 3 else 1.6) and farEnough(reeds, x, z, T.reedSpacing) and farEnough(stones, x, z, T.stoneSpacing)
	end
	for _, xr in { { -26, -15 }, { 27, 36 } } do
		local function sample(r: Rng): (number, number)
			return Scatter.range(r, xr[1], xr[2]), Scatter.range(r, 68, 90)
		end
		local nStones = Scatter.int(rdf, 2, 3)
		local got = 0
		for _ = 1, 3000 do
			if got >= nStones then
				break
			end
			local x, z = sample(rdf)
			local w = Scatter.waterline(x, z)
			if w >= -0.9 and w <= 0.6 and footOk(x, z, false) then
				table.insert(footPts, { x = x, z = z })
				add({ model = pick(rdf, "ShoreStones1", "ShoreStones2"), group = "FootStones", x = x, z = z, yaw = Scatter.range(rdf, 0, TAU), scale = Scatter.range(rdf, 0.7, 1.2), water = false, shadow = false })
				got += 1
			end
		end
		for _ = 1, 6000 do
			local x, z = sample(rdf)
			local w = Scatter.waterline(x, z)
			if w >= -3 and w <= -0.8 and Scatter.bankHeight(x, z) <= Scatter.REED_DRY and footOk(x, z, true) then
				table.insert(footPts, { x = x, z = z })
				add({ model = pick(rdf, "ReedClump1", "ReedClump2"), group = "FootReeds", x = x, z = z, yaw = Scatter.range(rdf, 0, TAU), scale = Scatter.range(rdf, 0.8, 1.05), water = true, shadow = false })
				break
			end
		end
	end

	return { items = items, routes = routes, forest = forest, meadow = meadow, counts = counts }
end

-- The Big Lake (BoatRules.BIG_LAKE, x -200..200, z -440..-140) and the 45 studs round it that
-- BoatWorld dresses itself.
function Scatter.inBigLake(x: number, z: number): boolean
	return x >= -245 and x <= 245 and z >= -485 and z <= -95
end

-- Far pines on the hills round the world (N1 round 2). `height(x, z)` is the ground's height
-- there (nil for water or nothing): Studio passes a terrain raycast, the specs a fake hill.
-- Points 60 to 300 studs out from the lake (Scatter.roundBox) on ground at least hillMinHeight
-- high, clear of the Big Lake and its banks, Poisson-spaced. Also returns a blob under each, for
-- the hill forest floor.
function Scatter.hillPines(seed: number, height: (number, number) -> number?, tuning: { [string]: any }?, others: { any }?): ({ Item }, { Blob })
	local T: { [string]: any } = table.clone(Scatter.TUNING)
	for k, v in tuning or {} do
		T[k] = v
	end
	local r = Scatter.rng(seed + 17)
	local hb = T.hillBand
	local items: { Item } = {}
	local blobs: { Blob } = {}
	local pts = Scatter.poisson(r, T.hillPines, T.hillMinDist, 6000, function(rr: Rng)
		return Scatter.range(rr, -420, 420), Scatter.range(rr, -400, 420)
	end, function(x, z)
		local d = Scatter.roundBox(x, z)
		if d < hb[1] or d > hb[2] or Scatter.inBigLake(x, z) or not Scatter.shotClear(x, z, true) then
			return false
		end
		local h = height(x, z)
		return h ~= nil and h >= T.hillMinHeight
	end, others)
	for _, p in pts do
		table.insert(items, { model = if Scatter.next(r) < 0.5 then "FarPine1" else "FarPine2", group = "HillPines", x = p.x, z = p.z, yaw = Scatter.range(r, 0, TAU), scale = Scatter.range(r, 1.0, 1.5), water = false, shadow = false })
		table.insert(blobs, { x = p.x, z = p.z, r = Scatter.range(r, 8, 12) })
	end
	return items, blobs
end

---------------------------------------------------------------------------------------------
-- Crest pines (N1 close-out, the advisor's review 3): the plan's wrong-list has "a horizon where
-- sky meets a bare green hill". Shot 03 sees one through the channel to the north, shot 08 at
-- both edges (south-east and south-west of the stands). For each such view, rays from the shot's
-- eye across the bearing fan where the bare crest shows find the horizon (the ground point with
-- the highest elevation angle from the eye, over `height`, the same ground function hillPines
-- takes); far pines stand in seeded clumps along that crest line.
---------------------------------------------------------------------------------------------

-- Bearings in degrees: 0 is +z (south), 90 is +x (east), 180 is -z (north).
export type CrestView = { id: string, eye: { number }, fan: { number } }
Scatter.CREST_VIEWS = {
	{ id = "03 north, through the channel", eye = { 0, 6, 37 }, fan = { 166, 194 } },
	{ id = "08 left edge, south-east", eye = { 0, 6, 50 }, fan = { 34, 62 } },
	{ id = "08 right edge, south-west", eye = { 0, 6, 50 }, fan = { -38, -18 } },
} :: { CrestView }
Scatter.CREST_TUNING = {
	crestPer = { 12, 18 }, -- pines per crest line
	crestClumps = { 3, 4 },
	crestNear = 110, -- studs from the eye before a sample can be the horizon (the back row's band)
	crestFar = 720,
	crestStep = 4, -- studs between samples along a ray
	crestRay = 1, -- degrees between rays
	crestMinDist = 5, -- studs between crest pines
	crestBehind = { -1, 6 }, -- studs past the crest along the ray (behind it, so the tops break the sky)
	crestSide = 5, -- studs either side of the ray
	crestScale = { 0.9, 1.3 },
}

export type CrestPoint = { x: number, z: number, h: number, d: number, a: number }

-- The horizon along one ray from `eye` at bearing `a` degrees: the sample with the highest
-- elevation angle (nil when no sample has ground). Samples on the Big Lake and its banks are
-- skipped (the far ground beyond is what shows).
function Scatter.horizon(eye: { number }, a: number, height: (number, number) -> number?, T: { [string]: any }): CrestPoint?
	local dx, dz = math.sin(math.rad(a)), math.cos(math.rad(a))
	local best: CrestPoint? = nil
	local bestE = -math.huge
	local d = T.crestNear
	while d <= T.crestFar do
		local x, z = eye[1] + dx * d, eye[3] + dz * d
		if not Scatter.inBigLake(x, z) then
			local h = height(x, z)
			if h then
				local e = (h - eye[2]) / d
				if e > bestE then
					bestE = e
					best = { x = x, z = z, h = h, d = d, a = a }
				end
			end
		end
		d += T.crestStep
	end
	return best
end

-- The crest pines for every view. Second result: per view id, how many rays found a hill crest
-- (ground at least hillMinHeight) and how many pines stand on it.
function Scatter.crestPines(seed: number, height: (number, number) -> number?, tuning: { [string]: any }?): ({ Item }, { [string]: { rays: number, pines: number } })
	local T: { [string]: any } = table.clone(Scatter.TUNING)
	for k, v in Scatter.CREST_TUNING do
		T[k] = v
	end
	for k, v in tuning or {} do
		T[k] = v
	end
	local r = Scatter.rng(seed + 23)
	local items: { Item } = {}
	local placed: { Pt } = {}
	local info: { [string]: { rays: number, pines: number } } = {}
	for _, v in Scatter.CREST_VIEWS do
		local line: { CrestPoint } = {}
		local a = v.fan[1]
		while a <= v.fan[2] + 1e-9 do
			local c = Scatter.horizon(v.eye, a, height, T)
			if c and c.h >= T.hillMinHeight then
				table.insert(line, c)
			end
			a += T.crestRay
		end
		local n = 0
		if #line >= 3 then
			local want = Scatter.int(r, T.crestPer[1], T.crestPer[2])
			local clumps = Scatter.int(r, T.crestClumps[1], T.crestClumps[2])
			local per = math.ceil(want / clumps)
			-- Clump centres spread along the line: one in each equal share of it, at a seeded spot.
			for ci = 1, clumps do
				local lo = math.floor((ci - 1) * #line / clumps) + 1
				local hi = math.max(lo, math.floor(ci * #line / clumps))
				local centre = Scatter.int(r, lo, hi)
				local got, k = 0, 0
				while got < per and n < want and k < per * 30 do
					k += 1
					local i = math.clamp(centre + Scatter.int(r, -2, 2), 1, #line)
					local c = line[i]
					local rx, rz = math.sin(math.rad(c.a)), math.cos(math.rad(c.a))
					local back = Scatter.range(r, T.crestBehind[1], T.crestBehind[2])
					local side = Scatter.range(r, -T.crestSide, T.crestSide)
					local x, z = c.x + rx * back + rz * side, c.z + rz * back - rx * side
					local h = height(x, z)
					if h and h >= T.hillMinHeight and not Scatter.inBigLake(x, z) and Scatter.shotClear(x, z, true) and farEnough(placed, x, z, T.crestMinDist) then
						table.insert(placed, { x = x, z = z })
						table.insert(items, { model = if Scatter.next(r) < 0.5 then "FarPine1" else "FarPine2", group = "CrestPines", x = x, z = z, yaw = Scatter.range(r, 0, TAU), scale = Scatter.range(r, T.crestScale[1], T.crestScale[2]), water = false, shadow = false })
						got += 1
						n += 1
					end
				end
			end
		end
		info[v.id] = { rays = #line, pines = n }
	end
	return items, info
end

---------------------------------------------------------------------------------------------
-- Reed seating (N1 close-out, the advisor's review 3): cattails stood on dry sand with their
-- bases cut off (shot 05). `height(x, z)` is the real ground under the water (Studio: a terrain
-- raycast that ignores water). A ReedClump whose ground is more than REED_DRY over the water
-- moves toward the water into the wet band (within 3 studs of the drawn waterline, in the water,
-- on ground no higher than REED_DRY) when a clear spot is there, else sinks REED_SINK more.
---------------------------------------------------------------------------------------------

Scatter.REED_SINK = 0.5
Scatter.REED_BAND = 3 -- studs into the water from the drawn waterline a moved reed may stand

function Scatter.isReed(model: string): boolean
	return string.sub(model, 1, 9) == "ReedClump"
end

-- Moves or sinks the reed clumps in `items` in place. Returns how many moved and how many sank.
function Scatter.seatReeds(items: { Item }, height: (number, number) -> number?): (number, number)
	local reeds: { Item } = {}
	for _, it in items do
		if Scatter.isReed(it.model) then
			table.insert(reeds, it)
		end
	end
	local moved, sunk = 0, 0
	for _, it in reeds do
		local g = height(it.x, it.z)
		if g and g > Scatter.REED_DRY then
			local wx, wz = Scatter.toWater(it.x, it.z)
			local done = false
			for step = 1, 24 do
				local d = step * 0.5
				for _, side in { 0, 0.6, -0.6, 1.2, -1.2 } do
					local x, z = it.x + wx * d - wz * side, it.z + wz * d + wx * side
					local w = Scatter.waterline(x, z)
					local h = height(x, z)
					if w < 0 and w >= -Scatter.REED_BAND and h and h <= Scatter.REED_DRY and not Scatter.kept(x, z, 1) and not Scatter.inLane(x, z) and Scatter.shotClear(x, z, false) then
						local clear = true
						for _, o in reeds do
							if o ~= it and (o.x - x) ^ 2 + (o.z - z) ^ 2 < 1.2 * 1.2 then
								clear = false
								break
							end
						end
						if clear then
							it.x, it.z = x, z
							it.water = true
							done = true
							break
						end
					end
				end
				if done then
					break
				end
			end
			if done then
				moved += 1
			else
				it.sink = (it.sink or 0) + Scatter.REED_SINK
				sunk += 1
			end
		end
	end
	return moved, sunk
end

---------------------------------------------------------------------------------------------
-- Ground paint (BankDress), pure over the arrays Terrain:ReadVoxelChannels gives, so the specs
-- run the same paint, clean and check on a simulated grid.
---------------------------------------------------------------------------------------------

-- idx[x][y][z] material slot, occ[x][y][z] occupancy (both 1-based, x outermost); column x, z
-- covers the cell ix0 + x - 1, iz0 + z - 1 (`cell` studs square).
export type Grid = { idx: any, occ: any, nx: number, ny: number, nz: number, ix0: number, iz0: number, cell: number }

Scatter.SLOT = { MEADOW = 2, SAND = 6, WET_SAND = 23, FOOTPATH = 24, FOREST = 25, LAWN = 26, HILL = 27 }
Scatter.PATH_DRY = 2 -- studs from any water before a footpath cell is painted
-- What each paint may cover (2 Grass/meadow, 14 Ground, 19 LeafyGrass, 26 the bladeless lawn;
-- the footpath also forest floor, and sand away from the water).
local GROUND_OVER = { [2] = true, [19] = true, [26] = true }
local PATH_OVER = { [2] = true, [14] = true, [19] = true, [26] = true, [25] = true }
Scatter.GROUND_OVER = GROUND_OVER
Scatter.PATH_OVER = PATH_OVER

-- The top solid voxel of a column (0 for none) and how many under it the path paints too (1 when
-- the top is a thin skin, else 0).
function Scatter.surface(g: Grid, x: number, z: number): (number, number)
	for y = g.ny, 1, -1 do
		if g.occ[x][y][z] > 0 then
			return y, if y > 1 and g.occ[x][y][z] < 0.5 then 1 else 0
		end
	end
	return 0, 0
end

-- (N1 round 4) Sand to repaint: on the treeline sides, more than sandKeep studs from the water and
-- within sandReach of it, away from the keep-clears (the channel), the Big Lake's banks and any
-- creek water. The bare 10 stud beach ring in the overview.
function Scatter.sandOff(x: number, z: number, T: { [string]: any }): boolean
	local w = Scatter.waterline(x, z)
	return w > T.sandKeep and w <= T.sandReach and Scatter.treeSide(x, z) and not Scatter.kept(x, z) and not Scatter.inBigLake(x, z) and Scatter.dry(x, z, T.sandKeep)
end

-- (N1 round 4) The green floor (slot 27) behind the north shore: northFloor studs back, not past
-- the far row's south limit (the Big Lake's bank).
function Scatter.northFloor(x: number, z: number, T: { [string]: any }): boolean
	local side = Scatter.side(x, z)
	if side ~= "north" and side ~= "ne" and side ~= "nw" then
		return false
	end
	local w = Scatter.waterline(x, z)
	return w >= T.northFloor[1] and w <= T.northFloor[2] and z >= T.farZMin
end

export type PaintCounts = { path: number, forest: number, meadow: number, sand: number, north: number, dockSand: number }

-- Paints the grid for a plan: the footpaths (surface only), then off the paths forest floor
-- under the trees, meadow blobs on the lawn, the green floor behind the north shore, and the sand
-- ring's far side as meadow.
function Scatter.paintGrid(g: Grid, plan: Plan, seed: number, tuning: { [string]: any }?): PaintCounts
	local T: { [string]: any } = table.clone(Scatter.TUNING)
	for k, v in tuning or {} do
		T[k] = v
	end
	local S = Scatter.SLOT
	local paths = Scatter.pathCells(plan.routes, g.cell, seed)
	local forest = Scatter.blobCells(plan.forest, g.cell, seed)
	local meadow = Scatter.blobCells(plan.meadow, g.cell, seed + 1)
	local c: PaintCounts = { path = 0, forest = 0, meadow = 0, sand = 0, north = 0, dockSand = 0 }
	local idx, occ = g.idx, g.occ
	for x = 1, g.nx do
		local cx = (g.ix0 + x - 1 + 0.5) * g.cell
		for z = 1, g.nz do
			local cz = (g.iz0 + z - 1 + 0.5) * g.cell
			local k = Scatter.key(g.ix0 + x - 1, g.iz0 + z - 1)
			if paths[k] == true and Scatter.dry(cx, cz, Scatter.PATH_DRY) then
				-- Only the surface: the top solid voxel, and the one under it when the top is a thin
				-- skin. (Before 11/27/2026 the whole column was painted: shot 06's gravel bank.)
				local top, depth = Scatter.surface(g, x, z)
				for y = top, math.max(1, top - depth), -1 do
					local s = idx[x][y][z]
					if top > 0 and (PATH_OVER[s] or (s == S.SAND and Scatter.dry(cx, cz, 3))) then
						idx[x][y][z] = S.FOOTPATH
						c.path += 1
					end
				end
			else
				local inForest, inMeadow = forest[k] == true, meadow[k] == true
				local sandOff = Scatter.sandOff(cx, cz, T)
				local north = Scatter.northFloor(cx, cz, T)
				if Scatter.inBox(Scatter.DOCK_FOOT, cx, cz) then
					-- (N1 close-out) The dock foot is shore sand: meadow there (shot 08's lime blobs) goes
					-- back to wet sand in the wet band and dry sand above it.
					local sand = if Scatter.bankHeight(cx, cz) <= Scatter.WET_ABOVE then S.WET_SAND else S.SAND
					for y = 1, g.ny do
						if occ[x][y][z] > 0 and idx[x][y][z] == S.MEADOW then
							idx[x][y][z] = sand
							c.dockSand += 1
						end
					end
				elseif inForest or inMeadow or sandOff or north then
					for y = 1, g.ny do
						if occ[x][y][z] > 0 then
							local s = idx[x][y][z]
							local ground = GROUND_OVER[s] or (s == S.SAND and sandOff)
							if inForest and ground then
								idx[x][y][z] = S.FOREST
								c.forest += 1
							elseif inMeadow and s == S.LAWN then
								idx[x][y][z] = S.MEADOW
								c.meadow += 1
							elseif north and ground then
								idx[x][y][z] = S.HILL
								c.north += 1
							elseif s == S.SAND and sandOff then
								idx[x][y][z] = S.MEADOW
								c.sand += 1
							end
						end
					end
				end
			end
		end
	end
	return c
end

export type CleanOpts = {
	paths: { [number]: boolean }, -- the footpath cells (Scatter.pathCells) of the plan about to be applied
	forest: { [number]: boolean }?, -- its forest-floor cells (used only when not unbake)
	lawn: (number, number) -> boolean, -- true on the south lawn (the old GroundSouth box)
	unbake: boolean, -- see Scatter.cleanGrid
}
export type CleanCounts = { outside: number, deep: number, forest: number, lawnMeadow: number }

-- (N1 round 4) Undoes paint that got baked into BankDress's terrain record (the record was taken
-- again over round 2's paint, so revert only puts back what it holds):
--  * every footpath voxel (24) outside `paths` goes back to the lawn (26) on the south lawn, else
--    to meadow (2); with `unbake` false, to forest floor (25) inside `forest` instead of meadow
--    (the advisor's literal rule).
-- With `unbake` (the default in BankDress) also:
--  * footpath voxels inside `paths` below the surface the path paints (the old whole-column
--    paint: shot 06's gravel bank) take the solid material under them;
--  * every forest-floor voxel (25, a slot only BankDress paints) goes to the lawn or meadow;
--  * every meadow voxel (2) on the south lawn goes back to the lawn (MaterialKit.paintLawns turned
--    all of it to 26 there, so any 2 is BankDress's meadow blobs).
-- The next apply paints the current plan over clean ground, so its record holds no paint and a
-- revert after it leaves no slot 24 or 25 at all.
function Scatter.cleanGrid(g: Grid, o: CleanOpts): CleanCounts
	local S = Scatter.SLOT
	local c: CleanCounts = { outside = 0, deep = 0, forest = 0, lawnMeadow = 0 }
	local idx, occ = g.idx, g.occ
	for x = 1, g.nx do
		local cx = (g.ix0 + x - 1 + 0.5) * g.cell
		for z = 1, g.nz do
			local cz = (g.iz0 + z - 1 + 0.5) * g.cell
			local k = Scatter.key(g.ix0 + x - 1, g.iz0 + z - 1)
			local lawn = o.lawn(cx, cz)
			local inPath = o.paths[k] == true
			local target = if lawn then S.LAWN elseif not o.unbake and o.forest and o.forest[k] then S.FOREST else S.MEADOW
			local top, depth = Scatter.surface(g, x, z)
			local keepLo = if inPath and top > 0 then math.max(1, top - depth) else math.huge
			local under: number? = nil -- the last solid, non-gravel material below, walking up
			for y = 1, g.ny do
				local s = idx[x][y][z]
				if s == S.FOOTPATH then
					if not inPath then
						idx[x][y][z] = target
						c.outside += 1
					elseif o.unbake and y < keepLo then
						idx[x][y][z] = under or target
						c.deep += 1
					end
				elseif o.unbake and s == S.FOREST then
					idx[x][y][z] = if lawn then S.LAWN else S.MEADOW
					c.forest += 1
				elseif o.unbake and lawn and s == S.MEADOW then
					idx[x][y][z] = S.LAWN
					c.lawnMeadow += 1
				end
				if occ[x][y][z] > 0 and idx[x][y][z] ~= S.FOOTPATH then
					under = idx[x][y][z]
				end
			end
		end
	end
	return c
end

-- How many voxels hold `slot` in columns outside `except` (every column when nil).
function Scatter.countSlot(g: Grid, slot: number, except: { [number]: boolean }?): number
	local n = 0
	for x = 1, g.nx do
		for z = 1, g.nz do
			if not (except and except[Scatter.key(g.ix0 + x - 1, g.iz0 + z - 1)]) then
				for y = 1, g.ny do
					if g.idx[x][y][z] == slot then
						n += 1
					end
				end
			end
		end
	end
	return n
end

---------------------------------------------------------------------------------------------
-- Seams (N1, Gemini's review 1.2): low plants and flat stones along the borders between ground
-- slots, so the 4 stud voxel paint's stair-step edges and the abrupt end of the grass blades are
-- broken up by geometry. Pure over the painted Scatter.Grid (BankDress passes the grid it just
-- painted, wet sand from WaterLook included).
---------------------------------------------------------------------------------------------

-- Triangles per seam model as BankDress places it (the `_lite` copies of the ferns and bushes;
-- the shore stones have no lite copy). art/models/manifest.json.
Scatter.SEAM_TRIS = {
	Fern1 = 155,
	Fern2 = 137,
	Bush1 = 286,
	Bush2 = 304,
	ShoreStones1 = 668,
	ShoreStones2 = 588,
} :: { [string]: number }

Scatter.SEAM_TUNING = {
	seamTris = 15000, -- the whole rule's triangle budget
	seamCentres = 48, -- cluster centres at most
	seamGap = 10, -- studs between centres
	seamPer = { 2, 5 }, -- members per cluster
	seamR = 6, -- a cluster's reach along the seam, studs
	seamSpacing = 1.8, -- studs between members
	seamNoise = 26, -- the density mask's feature size, studs
	seamMask = 0.4, -- the mask must be at least this for a centre
	seamClear = 1.6, -- studs from any other placed item
}

-- What a pair of surface slots is, as a seam: "gravel" (footpath 24 with lawn 26, meadow 2 or
-- leafy grass 19), "forest" (forest floor 25 or the hill floor 27 with meadow or lawn), "sand"
-- (dry sand 6 with wet sand 23, meadow or lawn), or nil. Second result: which of the two is the
-- soft side (1 or 2) where plants stand: never the gravel or the wet sand; 0 when either will do.
local MEADOWS = { [2] = true, [19] = true, [26] = true }
function Scatter.seamKind(a: number, b: number): (string?, number)
	local function one(p: number, q: number): (string?, number)
		if p == 24 and MEADOWS[q] then
			return "gravel", 2
		elseif (p == 25 or p == 27) and MEADOWS[q] then
			return "forest", 0
		elseif p == 6 and q == 23 then
			return "sand", 1
		elseif p == 6 and MEADOWS[q] then
			return "sand", 2
		end
		return nil, 0
	end
	local k, s = one(a, b)
	if k then
		return k, s
	end
	k, s = one(b, a)
	if k then
		return k, if s == 0 then 0 else 3 - s
	end
	return nil, 0
end

-- One border between two 4-neighbour columns: (x, z) the middle of their shared edge; (nx, nz)
-- the unit step across it toward the soft side.
export type SeamEdge = { x: number, z: number, kind: string, nx: number, nz: number }

-- Every border between two columns whose surface slots make a seam (Scatter.seamKind), each
-- edge once, in grid order.
function Scatter.seamEdges(g: Grid, seed: number?): { SeamEdge }
	local sd = seed or 0
	local surf: { { number } } = {}
	for x = 1, g.nx do
		surf[x] = {}
		for z = 1, g.nz do
			local top = Scatter.surface(g, x, z)
			surf[x][z] = if top > 0 then g.idx[x][top][z] else 0
		end
	end
	local out: { SeamEdge } = {}
	for x = 1, g.nx do
		for z = 1, g.nz do
			local a = surf[x][z]
			if a > 0 then
				for _, st in { { 1, 0 }, { 0, 1 } } do
					local x2, z2 = x + st[1], z + st[2]
					if x2 <= g.nx and z2 <= g.nz then
						local b = surf[x2][z2]
						if b > 0 and b ~= a then
							local kind, soft = Scatter.seamKind(a, b)
							if kind then
								local ix, iz = g.ix0 + x - 1, g.iz0 + z - 1
								local mx, mz = (ix + 0.5 + st[1] / 2) * g.cell, (iz + 0.5 + st[2] / 2) * g.cell
								if soft == 0 then
									soft = if Scatter.hash(ix * 2 + st[1], iz * 2 + st[2], sd + 43) < 0.5 then 1 else 2
								end
								local sign = if soft == 2 then 1 else -1
								table.insert(out, { x = mx, z = mz, kind = kind, nx = st[1] * sign, nz = st[2] * sign })
							end
						end
					end
				end
			end
		end
	end
	return out
end

-- The seam plants and stones for a painted grid: cluster centres picked from the seam edges
-- under a slow noise mask (so they clump and leave gaps), 2 to 5 members each along the nearby
-- seams, on the soft side (stones straddle the line). Ferns mostly, bushes sparingly, flat shore
-- stones (0.5 to 0.8) mostly on the sand seams. Out of the paths' cells, the cast lanes, the
-- keep-clears, the shot cameras' spheres, the water, and clear of every land item in `plan`.
-- Stops at the triangle budget (Scatter.SEAM_TRIS). Group "Seams". Second result: how many seam
-- edges there were and the triangles placed.
function Scatter.seams(g: Grid, plan: Plan, seed: number, tuning: { [string]: any }?): ({ Item }, { edges: number, tris: number })
	local T: { [string]: any } = table.clone(Scatter.SEAM_TUNING)
	for k, v in tuning or {} do
		T[k] = v
	end
	local edges = Scatter.seamEdges(g, seed)
	local pcells = Scatter.pathCells(plan.routes, g.cell, seed)
	local others: { Pt } = {}
	for _, it in plan.items do
		if not it.water then
			table.insert(others, { x = it.x, z = it.z })
		end
	end
	local r = Scatter.rng(seed + 40)
	-- The edges in 8 stud buckets, for a cluster's neighbours.
	local buckets: { [number]: { number } } = {}
	for i, e in edges do
		local k = Scatter.key(math.floor(e.x / 8), math.floor(e.z / 8))
		local list = buckets[k]
		if not list then
			list = {}
			buckets[k] = list
		end
		table.insert(list, i)
	end
	local order = table.create(#edges)
	for i = 1, #edges do
		order[i] = i
	end
	for i = #order, 2, -1 do
		local j = Scatter.int(r, 1, i)
		order[i], order[j] = order[j], order[i]
	end
	local weight = { gravel = 1, forest = 0.8, sand = 0.9 } :: { [string]: number }
	local centres: { Pt } = {}
	local centreEdges: { SeamEdge } = {}
	for _, i in order do
		if #centres >= T.seamCentres then
			break
		end
		local e = edges[i]
		local mask = Scatter.noise(e.x, e.z, T.seamNoise, seed + 41)
		if mask >= T.seamMask and Scatter.next(r) < weight[e.kind] and farEnough(centres, e.x, e.z, T.seamGap) and not Scatter.kept(e.x, e.z, 2) then
			table.insert(centres, { x = e.x, z = e.z })
			table.insert(centreEdges, e)
		end
	end
	local items: { Item } = {}
	local placed: { Pt } = {}
	local tris = 0
	local function ok(x: number, z: number, stone: boolean): boolean
		if Scatter.kept(x, z, 1) or not Scatter.shotClear(x, z, false) or Scatter.inLane(x, z) then
			return false
		end
		if Scatter.onCells(pcells, x, z, 0.6, g.cell) then
			return false
		end
		if Scatter.waterline(x, z) < (if stone then -0.3 else 0.6) or not Scatter.dry(x, z, if stone then 0 else 0.5) then
			return false
		end
		return farEnough(others, x, z, T.seamClear) and farEnough(placed, x, z, T.seamSpacing)
	end
	for ci, c in centres do
		local e0 = centreEdges[ci]
		-- The nearby edges (same kind first, so a cluster follows its own seam), shuffled.
		local near: { number } = {}
		local bx, bz = math.floor(c.x / 8), math.floor(c.z / 8)
		for ix = bx - 1, bx + 1 do
			for iz = bz - 1, bz + 1 do
				for _, i in buckets[Scatter.key(ix, iz)] or {} do
					local e = edges[i]
					if e.kind == e0.kind and (e.x - c.x) ^ 2 + (e.z - c.z) ^ 2 <= T.seamR * T.seamR then
						table.insert(near, i)
					end
				end
			end
		end
		table.sort(near)
		for i = #near, 2, -1 do
			local j = Scatter.int(r, 1, i)
			near[i], near[j] = near[j], near[i]
		end
		local want = Scatter.int(r, T.seamPer[1], T.seamPer[2])
		local got = 0
		for _, i in near do
			if got >= want then
				break
			end
			local e = edges[i]
			local u = Scatter.next(r)
			local model: string
			if e.kind == "sand" then
				model = if u < 0.45 then (if Scatter.next(r) < 0.5 then "ShoreStones1" else "ShoreStones2") elseif u < 0.55 then (if Scatter.next(r) < 0.5 then "Bush1" else "Bush2") else (if Scatter.next(r) < 0.5 then "Fern1" else "Fern2")
			elseif e.kind == "gravel" then
				model = if u < 0.08 then (if Scatter.next(r) < 0.5 then "ShoreStones1" else "ShoreStones2") elseif u < 0.2 then (if Scatter.next(r) < 0.5 then "Bush1" else "Bush2") else (if Scatter.next(r) < 0.5 then "Fern1" else "Fern2")
			else
				model = if u < 0.18 then (if Scatter.next(r) < 0.5 then "Bush1" else "Bush2") else (if Scatter.next(r) < 0.5 then "Fern1" else "Fern2")
			end
			local stone = string.sub(model, 1, 5) == "Shore"
			local along = Scatter.range(r, -1.8, 1.8)
			local across = if stone then Scatter.range(r, -0.6, 0.6) else Scatter.range(r, 0.5, 1.6)
			-- (nx, nz) is axis-aligned, so (nz, nx) runs along the edge.
			local x = e.x + e.nx * across + e.nz * along
			local z = e.z + e.nz * across + e.nx * along
			local cost = Scatter.SEAM_TRIS[model]
			if tris + cost <= T.seamTris and ok(x, z, stone) then
				local scale = if stone then Scatter.range(r, 0.5, 0.8) elseif string.sub(model, 1, 4) == "Bush" then Scatter.range(r, 0.6, 0.9) else Scatter.range(r, 0.7, 1.1)
				table.insert(items, { model = model, group = "Seams", x = x, z = z, yaw = Scatter.range(r, 0, TAU), scale = scale, water = false, shadow = false })
				table.insert(placed, { x = x, z = z })
				tris += cost
				got += 1
			end
		end
	end
	return items, { edges = #edges, tris = tris }
end

---------------------------------------------------------------------------------------------
-- Cedar Creek's stock pines (N1, Gemini's review 1.3; CreekSwap places them): which kit or far
-- pine replaces an old cone pine.
---------------------------------------------------------------------------------------------

-- The creek area whose old cone pines CreekSwap swaps (the art copies over the creek's gray-box
-- trunks are swapped wherever they stand).
Scatter.CREEK_BOX = { x1 = -270, x2 = -150, z1 = -100, z2 = 100 }
Scatter.CREEK_FAR = 25 -- studs from the creek's water past which a far pine stands in

-- Distance in x, z to the nearest creek water rectangle (Riffle, Rocks, Pool); 0 inside one.
function Scatter.creekWaterDist(x: number, z: number): number
	local best = math.huge
	for _, name in { "Riffle", "Rocks", "Pool" } do
		local a = areaNamed(name)
		local dx = math.max(a.x1 - x, 0, x - a.x2)
		local dz = math.max(a.z1 - z, 0, z - a.z2)
		best = math.min(best, math.sqrt(dx * dx + dz * dz))
	end
	return best
end

-- The replacement for an old pine at (x, z), `u` a 0..1 draw: ShorePine1 or ShorePine2 within
-- CREEK_FAR of the water, FarPine1 or FarPine2 past it.
function Scatter.creekPine(x: number, z: number, u: number): string
	if Scatter.creekWaterDist(x, z) > Scatter.CREEK_FAR then
		return if u < 0.5 then "FarPine1" else "FarPine2"
	end
	return if u < 0.5 then "ShorePine1" else "ShorePine2"
end

return Scatter
