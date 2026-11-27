--!strict
-- Cover and snags (L2b, "reasons to aim"). Fish hold tight to logs, the dock, the weed bed
-- and the creek boulders: a cast that lands just off one of them (within COVER_RANGE studs of
-- its edge, not on it) gets bites sooner and more of the cover-loving fish. Land right ON a
-- log, or deep in the weed bed's core, and the hook snags: wiggle it free or lose the line.
-- Shared by the server (which decides) and the client (which turns the ring amber).
-- Positions are flat (x, z) and come from WorldBuilder's real coordinates; keep them in step.
-- Pure data and math, no Roblox services. UNVERIFIED in Studio (written 2026-11-26).
local Cover = {}

Cover.COVER_RANGE = 4 -- studs from a cover edge that still counts as "tight to cover"
Cover.COVER_DELAY = 1 -- bite delay multiplier when tight to cover (1: cover brings better fish, not faster bites; the two stacked broke the economy)
Cover.COVER_WEIGHT = 1.25 -- weight multiplier for cover-loving species when tight to cover
Cover.SNAG_MARGIN = 0.3 -- a landing this close to a log (or on it) snags: the bobber hits the wood

-- Fish that hold on cover.
Cover.COVER_SPECIES = {
	LargemouthBass = true,
	BlackCrappie = true,
	NorthernPike = true,
	Bowfin = true,
	SmallmouthBass = true,
	RockBass = true,
	ChannelCatfish = true,
}

-- Rigged weedless: never snags in the weed bed (still snags on logs).
Cover.WEEDLESS = { PlasticWorm = true }

-- Snags.
Cover.SNAG_WIGGLES = 4 -- presses that free a snag...
Cover.SNAG_TIME = 8 -- ...within this many seconds, or the line snaps
Cover.SNAG_BAIT_LOSS = 0.35 -- chance live bait comes back gone when you wiggle free (lures never)
Cover.WIGGLE_GAP = 0.12 -- presses closer together than this are ignored

export type Feature = {
	kind: string, -- "Log", "Dock", "Weeds", "Boulder"
	cframe: CFrame, -- flat: y is 0, only yaw
	half: Vector3?, -- box half sizes on x and z (y unused)
	radius: number?, -- circles (boulders)
	snag: boolean,
	margin: number, -- how far outside the shape still snags (logs)
}

local function box(kind: string, x: number, z: number, yaw: number, hx: number, hz: number, snag: boolean, margin: number): Feature
	return {
		kind = kind,
		cframe = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0),
		half = Vector3.new(hx, 0, hz),
		snag = snag,
		margin = margin,
	}
end

local function circle(kind: string, x: number, z: number, r: number): Feature
	return { kind = kind, cframe = CFrame.new(x, 0, z), radius = r, snag = false, margin = 0 }
end

-- WorldBuilder: logs are 22 x 2.2 x 2.2 cylinders along their X, at these spots and yaws.
local LOGS = {
	{ 70, 55, 0.5 },
	{ 90, 40, -0.3 },
	{ 62, 28, 1.1 },
	{ 96, 62, 0.9 },
	{ 80, 20, -0.8 },
}
-- WorldBuilder: boulders in the creek's rocky run, { x, z, radius }.
local BOULDERS = {
	{ -233, -2, 3.5 },
	{ -226, 8, 3 },
	{ -236, 18, 2.6 },
	{ -228, 25, 3.2 },
	{ -231, 0, 2 },
}
-- The weed bed's thick core: the middle of the reed clumps (WorldBuilder scatters them over
-- x -78 +- 24, z 38 +- 27). Its edge is cover; inside it snags anything not weedless.
Cover.WEED_CORE = { x = -78, z = 38, hx = 14, hz = 16 }

Cover.features = {} :: { Feature }
for _, l in LOGS do
	table.insert(Cover.features, box("Log", l[1], l[2], l[3], 11, 1.1, true, Cover.SNAG_MARGIN))
end
-- The dock: the deck (x -4..4, z 35..81) and the wider end deck (x -8..8, z 34..42).
table.insert(Cover.features, box("Dock", 0, 58, 0, 4, 23, false, 0))
table.insert(Cover.features, box("Dock", 0, 38, 0, 8, 4, false, 0))
table.insert(Cover.features, box("Weeds", Cover.WEED_CORE.x, Cover.WEED_CORE.z, 0, Cover.WEED_CORE.hx, Cover.WEED_CORE.hz, true, 0))
for _, b in BOULDERS do
	table.insert(Cover.features, circle("Boulder", b[1], b[2], b[3]))
end

-- Flat distance from a point to the feature's edge; 0 when the point is on (inside) it.
function Cover.edgeDistance(f: Feature, point: Vector3): number
	local p = f.cframe:PointToObjectSpace(Vector3.new(point.X, 0, point.Z))
	if f.radius then
		return math.max(Vector3.new(p.X, 0, p.Z).Magnitude - f.radius, 0)
	end
	local half = f.half :: Vector3
	local dx = math.max(math.abs(p.X) - half.X, 0)
	local dz = math.max(math.abs(p.Z) - half.Z, 0)
	return math.sqrt(dx * dx + dz * dz)
end

-- The nearest cover feature within COVER_RANGE: its kind and the distance to its edge
-- (0 when on it). Nil when no cover is that close.
function Cover.coverAt(point: Vector3): (string?, number?)
	local bestKind: string? = nil
	local bestD = math.huge
	for _, f in Cover.features do
		local d = Cover.edgeDistance(f, point)
		if d < bestD then
			bestD, bestKind = d, f.kind
		end
	end
	if bestKind and bestD <= Cover.COVER_RANGE then
		return bestKind, bestD
	end
	return nil, nil
end

-- True when a cast landing here snags: on a log (or touching it), or in the weed core with
-- bait that isn't weedless.
function Cover.snagAt(point: Vector3, baitId: string?): boolean
	for _, f in Cover.features do
		if f.snag and Cover.edgeDistance(f, point) <= f.margin then
			if not (f.kind == "Weeds" and Cover.WEEDLESS[baitId or ""]) then
				return true
			end
		end
	end
	return false
end

-- True when a landing here is tight to cover: within COVER_RANGE of an edge but not on the
-- cover and not snagged. A weedless lure inside the weed core counts too (that's where it
-- is made to go).
function Cover.tightAt(point: Vector3, baitId: string?): boolean
	if Cover.snagAt(point, baitId) then
		return false
	end
	for _, f in Cover.features do
		local d = Cover.edgeDistance(f, point)
		if d <= Cover.COVER_RANGE then
			if d > f.margin then
				return true
			elseif f.kind == "Weeds" and Cover.WEEDLESS[baitId or ""] then
				return true
			end
		end
	end
	return false
end

-- True when a point is on top of any cover (a rise never comes up there).
function Cover.onCover(point: Vector3): boolean
	for _, f in Cover.features do
		if Cover.edgeDistance(f, point) <= f.margin then
			return true
		end
	end
	return false
end

-- Bite weights for a cast tight to cover: cover-loving fish weigh COVER_WEIGHT times more.
-- Returns the list unchanged when not tight. Heaviest first, like FishLogic.biteWeights.
function Cover.applyCover(weights: { { id: string, w: number } }, tight: boolean): { { id: string, w: number } }
	if not tight then
		return weights
	end
	local out = {}
	for _, x in weights do
		table.insert(out, { id = x.id, w = if Cover.COVER_SPECIES[x.id] then x.w * Cover.COVER_WEIGHT else x.w })
	end
	table.sort(out, function(a, b)
		return a.w > b.w
	end)
	return out
end

-- The bite delay for a cast tight to cover.
function Cover.adjustDelay(delay: number, tight: boolean): number
	return if tight then delay * Cover.COVER_DELAY else delay
end

-- A snag in progress.
export type Snag = { start: number, last: number, count: number }

function Cover.newSnag(now: number): Snag
	return { start = now, last = -math.huge, count = 0 }
end

-- One press of the cast button while snagged. Returns "expired" (too late, the line snaps),
-- "ignored" (too soon after the last press), "counted" or "freed".
function Cover.wiggle(s: Snag, now: number): string
	if now - s.start > Cover.SNAG_TIME then
		return "expired"
	end
	if now - s.last < Cover.WIGGLE_GAP then
		return "ignored"
	end
	s.last = now
	s.count += 1
	if s.count >= Cover.SNAG_WIGGLES then
		return "freed"
	end
	return "counted"
end

-- Does the snag cost the bait? A lure never; live bait always when the line snaps, and with
-- chance SNAG_BAIT_LOSS when wiggled free. `roll` is a server random number in 0..1.
function Cover.losesBait(kind: string?, freed: boolean, roll: number): boolean
	if kind ~= "live" then
		return false
	end
	if not freed then
		return true
	end
	return roll < Cover.SNAG_BAIT_LOSS
end

return Cover
