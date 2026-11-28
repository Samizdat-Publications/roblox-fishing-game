--!strict
-- Cedar Creek's dress (leg 3, N3): the pure maths behind Server/CreekDress and
-- ClientModules/WhiteWater. No Roblox services; its own seeded random numbers (Scatter), so Lune
-- and Studio plan the same creek from the same seed and the specs check the real thing.
--
-- What it plans:
--  * the creek's drawn shape (CreekPlan.D, a signed distance, negative over water): the three
--    stretches' water boxes joined with smooth fillets (no 90 degree corners where the riffle
--    meets the rocky run and the run meets the pool), a pool whose far side bulges at its two
--    west corners like a scoured bend, and Shore's points of land (the meanders) kept as land.
--    Every point the fishing rules call water (WaterMap.CREEK boxes, Shore.isLand) is drawn as
--    water, with margin; the drawn water reaches at most a few studs past the rules' edge.
--  * the ground under and round it (CreekPlan.height): beds deepening from the riffle to the
--    pool (deepest on the pool's outside, the west), low wet gravel bars along the riffle (widest
--    at the meanders' noses), cut banks raised a little on the outside bends with roots showing,
--    and which terrain slot each column gets (CreekPlan.slotAt): creek pebble, creek bed, wet
--    slate, moss.
--  * the dressing (CreekPlan.plan): cedars and shore pines lining both banks 3 to 8 studs back so
--    the crowns lean in over the water, fern clumps, roots on the cut banks, moss mats on the bank
--    tops and a mossy log across the pool's south-west corner, all clear of the cast lanes, the
--    bank path, the walk to the gate, the gate itself and the fixed shot cameras.
--  * the white water (CreekPlan.foam): foam strips over the riffle and below the boulders, and
--    where the spray goes.
--  * N3 review 1 (the advisor): a backing forest behind both banks, shot 09's two frame cedars,
--    CedarBough sprays from the riffle's cedars (held at 0 per tree: TUNING.boughsPer, BOUGHS_ON),
--    ten emergent wet-slate rocks on the riffle with foam trails, the moss band to D 30 and the
--    creek paths as slot 14. Held numbers: REVIEW1_FOAM (with WhiteWater.REVIEW1).
local Shore = require(script.Parent.Shore)
local WaterMap = require(script.Parent.WaterMap)
local Scatter = require(script.Parent.Scatter)

local CreekPlan = {}

CreekPlan.SEED = 20261202
CreekPlan.CELL = 4

-- The terrain CreekDress may rewrite (whole 4 stud cells): the creek's water and banks, short of
-- the bank path (x -206..-200, wandering to about -208), the creek head's rocks (z 76 on) and
-- anything past them. Columns more than TOUCH studs from the drawn water are left alone inside it.
CreekPlan.REGION = { x1 = -268, x2 = -208, y1 = -16, y2 = 8, z1 = -84, z2 = 72 }
CreekPlan.TOUCH = 11
CreekPlan.BLEND = { 7, 11 } -- studs from the water over which the new ground eases into the old

-- Where props may stand at all (round the creek look zone, LookPresets creek x -260..-160). N3
-- review 1 (the advisor): out to x -300 on the west and -172 on the east for the backing forest.
CreekPlan.PROPS = { x1 = -300, x2 = -172, z1 = -82, z2 = 76 }

-- N3 review 1, held (the captures were taken in the phone simulator): the advisor's foam numbers
-- (CreekPlan.FOAM_REVIEW1, WhiteWater.REVIEW1) go live when this is true. One edit after a clean
-- desktop capture.
CreekPlan.REVIEW1_FOAM = false
CreekPlan.FOAM = { riffleW = { 0.7, 1.4 } }
CreekPlan.FOAM_REVIEW1 = { riffleW = { 1.6, 3.0 } }
function CreekPlan.foamTuning(): { riffleW: { number } }
	return if CreekPlan.REVIEW1_FOAM then CreekPlan.FOAM_REVIEW1 else CreekPlan.FOAM
end

---------------------------------------------------------------------------------------------
-- Small maths
---------------------------------------------------------------------------------------------

local function smooth(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end
CreekPlan.smooth = smooth

-- Polynomial smooth minimum (a fillet about k studs across where two shapes meet).
local function smin(a: number, b: number, k: number): number
	local h = math.clamp(0.5 + 0.5 * (b - a) / k, 0, 1)
	return b + (a - b) * h - k * h * (1 - h)
end
local function smax(a: number, b: number, k: number): number
	return -smin(-a, -b, k)
end

-- Signed distance to a rounded rectangle (negative inside).
local function sdRoundRect(x: number, z: number, x1: number, x2: number, z1: number, z2: number, r: number): number
	local cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
	local hx, hz = (x2 - x1) / 2 - r, (z2 - z1) / 2 - r
	local qx, qz = math.abs(x - cx) - hx, math.abs(z - cz) - hz
	local ox, oz = math.max(qx, 0), math.max(qz, 0)
	return math.sqrt(ox * ox + oz * oz) + math.min(math.max(qx, qz), 0) - r
end

local function segDist(x: number, z: number, ax: number, az: number, bx: number, bz: number): number
	local dx, dz = bx - ax, bz - az
	local l2 = dx * dx + dz * dz
	local t = if l2 > 0 then math.clamp(((x - ax) * dx + (z - az) * dz) / l2, 0, 1) else 0
	return math.sqrt((x - ax - dx * t) ^ 2 + (z - az - dz * t) ^ 2)
end
CreekPlan.segDist = segDist

---------------------------------------------------------------------------------------------
-- The rules' water and the drawn shape
---------------------------------------------------------------------------------------------

local CREEK_AREAS: { Shore.Area } = {}
for _, a in Shore.AREAS do
	if a.name == "Riffle" or a.name == "Rocks" or a.name == "Pool" then
		table.insert(CREEK_AREAS, a)
	end
end

-- True where a cast may land in the creek: inside one of WaterMap.CREEK's boxes and not on
-- Shore's land (FishLogic.isOnWaterAny asks the same two things).
function CreekPlan.ruleWater(x: number, z: number): boolean
	for _, c in WaterMap.CREEK do
		if x >= c.x1 and x <= c.x2 and z >= c.z1 and z <= c.z2 then
			return Shore.depth(x, z) <= 0
		end
	end
	return false
end

-- The drawn shape. Each stretch is a rounded box a little larger than its water box (so its
-- corners can round without losing any of the rules' water), joined to the next with a fillet;
-- two bulges round the pool's west corners; Shore's points cut back in, shrunk a little.
CreekPlan.SHAPE = {
	stretches = {
		{ name = "Riffle", x1 = -237.2, x2 = -222.8, z1 = 26, z2 = 82, r = 3 },
		{ name = "Rocks", x1 = -241.8, x2 = -218.2, z1 = -13, z2 = 32, r = 5 },
		{ name = "Pool", x1 = -252.9, x2 = -207.1, z1 = -70.9, z2 = -9.1, r = 12 },
	},
	joinK = 9, -- the fillets where the stretches meet
	bulges = {
		{ name = "PoolNW", x = -250, z = -22, r = 6.5 },
		{ name = "PoolSW", x = -244, z = -62, r = 7.5 },
	},
	bulgeK = 6,
	pointShrink = 0.9, -- studs off each point's radius, so its land never pokes into the rules' water
	pointK = 2.4,
}

-- Signed distance to the drawn waterline: negative over the drawn water, positive on land.
function CreekPlan.D(x: number, z: number): number
	local S = CreekPlan.SHAPE
	local d = math.huge
	for i, s in S.stretches do
		local ds = sdRoundRect(x, z, s.x1, s.x2, s.z1, s.z2, s.r)
		d = if i == 1 then ds else smin(d, ds, S.joinK)
	end
	for _, b in S.bulges do
		local db = math.sqrt((x - b.x) ^ 2 + (z - b.z) ^ 2) - b.r
		d = smin(d, db, S.bulgeK)
	end
	for _, a in CREEK_AREAS do
		for _, p in a.points do
			local dp = math.sqrt((x - p.x) ^ 2 + (z - p.z) ^ 2) - (p.r - S.pointShrink)
			d = smax(d, -dp, S.pointK)
		end
	end
	return d
end

-- The way to the drawn water from (x, z) (unit x, z; downhill on D).
function CreekPlan.toWater(x: number, z: number): (number, number)
	local h = 0.5
	local gx = CreekPlan.D(x + h, z) - CreekPlan.D(x - h, z)
	local gz = CreekPlan.D(x, z + h) - CreekPlan.D(x, z - h)
	local l = math.sqrt(gx * gx + gz * gz)
	if l < 1e-6 then
		return (if x < -230 then 1 else -1), 0
	end
	return -gx / l, -gz / l
end

---------------------------------------------------------------------------------------------
-- The ground
---------------------------------------------------------------------------------------------

-- How much of each stretch (x, z) belongs to: riffle, rocky run, pool (they sum to 1).
function CreekPlan.weights(z: number): (number, number, number)
	local riffle = smooth(24, 34, z)
	local pool = smooth(-4, -16, z)
	return riffle, math.max(0, 1 - riffle - pool), pool
end

local RIFFLE_POINTS: { Shore.Point } = {}
for _, a in CREEK_AREAS do
	if a.name == "Riffle" then
		RIFFLE_POINTS = a.points
	end
end

-- Width of the low wet gravel along the water here: widest at the riffle's meander noses (the
-- inside of each bend), a strip on the rocky run, a bar on the pool's inside (east) half, none
-- under the pool's west cut bank.
function CreekPlan.gravelWidth(x: number, z: number): number
	local riffle, rocks, pool = CreekPlan.weights(z)
	local near = 0
	for _, p in RIFFLE_POINTS do
		local d = math.sqrt((x - p.x) ^ 2 + (z - p.z) ^ 2)
		near = math.max(near, 1 - smooth(p.r, p.r + 7, d))
	end
	return riffle * (1.5 + 2.5 * near) + rocks * 1.0 + pool * 1.5 * smooth(-246, -222, x)
end

-- 0..1: how much this bank is a cut bank (the outside of a bend: the pool's west and south-west,
-- a little on the rocky run's west).
function CreekPlan.cut(x: number, z: number): number
	local _, rocks, pool = CreekPlan.weights(z)
	return pool * (1 - smooth(-246, -228, x)) + rocks * 0.6 * (1 - smooth(-238, -230, x))
end

-- The planned ground height at (x, z), before it eases into the old ground (CreekPlan.blend).
-- Over the drawn water it is always at least 0.6 under the surface (y 0).
function CreekPlan.height(x: number, z: number, dIn: number?): number
	local D = dIn or CreekPlan.D(x, z)
	local riffle, rocks, pool = CreekPlan.weights(z)
	if D < 0 then
		local bed = riffle * -1.6 + rocks * -4.2 + pool * (-9.6 + 2.8 * smooth(-250, -212, x))
		local slope = riffle * 0.9 + rocks * 1.1 + pool * (0.5 + 1.3 * (1 - smooth(-248, -216, x)))
		return math.max(bed, -(0.6 + slope * -D))
	end
	local g = CreekPlan.gravelWidth(x, z)
	local c = CreekPlan.cut(x, z)
	if D < g then
		return 0.1 + 0.08 * D -- wet gravel just out of the water
	end
	local top = 1 + 1.3 * c * smooth(0.5, 2.5, D) * (1 - smooth(7, 11, D))
	local base = if g > 0.05 then 0.1 + 0.08 * g else -0.3
	local s = 0.45 + 1.5 * c
	return math.min(top, base + s * (D - g))
end

-- The final height of a column: the plan near the water, easing into the old ground (`existing`)
-- between BLEND[1] and BLEND[2] studs from it.
function CreekPlan.blend(planned: number, existing: number, D: number): number
	local w = smooth(CreekPlan.BLEND[1], CreekPlan.BLEND[2], D)
	return planned + (existing - planned) * w
end

-- Terrain slots (MaterialKit.SLOTS 28 to 31, and the lake mud slot 12).
CreekPlan.SLOT = { PEBBLE = 28, BED = 29, SLATE = 30, MOSS = 31, MUD = 12 }

-- Which slot the top of a column gets (nil: leave its slot as it is).
function CreekPlan.slotAt(x: number, z: number, h: number, D: number): number?
	local riffle, rocks, pool = CreekPlan.weights(z)
	local S = CreekPlan.SLOT
	if h < 0 and D < 0.5 then
		if pool > 0.5 and h < -7 then
			return S.MUD -- the deep of the pool
		elseif riffle > 0.5 and D >= -0.5 then
			return S.PEBBLE -- the riffle's cobbles at its very edge
		end
		return S.BED -- pebbles under clear water (N3 review 1: the riffle's bed too, not the dry bar slot)
	end
	if D >= 7 then
		return nil -- CreekDress paints the moss band past this (CreekPlan.mossBand)
	end
	local g = CreekPlan.gravelWidth(x, z)
	local c = CreekPlan.cut(x, z)
	if D < g + 0.3 then
		return S.PEBBLE -- the gravel bars
	elseif D < 2 and c > 0.4 then
		return if pool > 0.5 then S.MUD else S.SLATE -- the cut bank's face
	elseif D < 2 and rocks > 0.5 then
		return S.SLATE
	end
	return S.MOSS -- the bank tops under the canopy
end

-- N3 review 1: the moss (slot 31) reaches into the backing forest, out to MOSS_D studs from the
-- drawn water, everywhere but the bank path, the walk to the gate and the gate. CreekDress paints
-- it over grass-like slots only (MOSS_OVER), never over the path's gravel.
CreekPlan.MOSS_D = 30
CreekPlan.MOSS_REGION = { x1 = -300, x2 = -172, z1 = -84, z2 = 80 }
CreekPlan.MOSS_OVER = { [2] = true, [19] = true, [25] = true, [26] = true, [27] = true } :: { [number]: boolean }
function CreekPlan.mossBand(x: number, z: number, D: number): boolean
	return D >= 7 and D < CreekPlan.MOSS_D and not CreekPlan.kept(x, z, 1)
end

-- N3 review 1: the bank path and the walk to the gate are re-laid as slot 14 (FootpathGravel,
-- as the home lake's stock-ground paths). CreekDress repaints their slot 24 voxels inside these
-- boxes, and gives the old path parts the FootpathGravel variant.
CreekPlan.PATH_SLOT = 14
CreekPlan.PATH_BOXES = {
	{ name = "BankPath", x1 = -212, x2 = -194, z1 = -80, z2 = 80 },
	{ name = "GateWalk", x1 = -212, x2 = -120, z1 = -10, z2 = 10 }, -- short of the lake's PathWest (x -118 on)
} :: { Scatter.Box }

---------------------------------------------------------------------------------------------
-- Keep-clears
---------------------------------------------------------------------------------------------

-- Where people stand and cast: from the bank path to the pool's deep middle, from either bank to
-- the rocky run and the riffle, and from the head of the pool (shots 10 and 12 stand there).
-- Nothing stands in a lane or within LANE_FOOT of its shore end.
export type Lane = { name: string, x1: number, z1: number, x2: number, z2: number, r: number }
CreekPlan.LANE_FOOT = 4
CreekPlan.LANES = {
	{ name = "PoolFromPath", x1 = -204, z1 = -40, x2 = -232, z2 = -40, r = 5 }, -- to the deep spot
	{ name = "PoolFromPathSouth", x1 = -204, z1 = -58, x2 = -232, z2 = -44, r = 4 },
	{ name = "PoolFromPathNorth", x1 = -204, z1 = -20, x2 = -232, z2 = -36, r = 4 },
	{ name = "PoolFromHead", x1 = -212, z1 = -6, x2 = -230, z2 = -30, r = 4 },
	{ name = "RocksFromEast", x1 = -208, z1 = 10, x2 = -230, z2 = 10, r = 4 },
	{ name = "RocksFromWest", x1 = -252, z1 = 12, x2 = -230, z2 = 10, r = 4 },
	{ name = "RiffleFromEast", x1 = -210, z1 = 50, x2 = -230, z2 = 52, r = 4 },
	{ name = "RiffleFromWest", x1 = -250, z1 = 54, x2 = -230, z2 = 52, r = 4 },
} :: { Lane }

-- Boxes nothing new stands in: the bank path (x -203, wandering 2 studs and up to 6.5 wide), the
-- walk from the gate to the path, the gate itself and the pool lantern.
CreekPlan.KEEP_BOXES = {
	{ name = "BankPath", x1 = -209.5, x2 = -196.5, z1 = -76, z2 = 76 },
	{ name = "GateWalk", x1 = -210, x2 = -150, z1 = -7, z2 = 7 },
	{ name = "CreekGate", x1 = -172, x2 = -150, z1 = -12, z2 = 12 },
} :: { Scatter.Box }
CreekPlan.KEEP_CIRCLES = {
	{ name = "PoolLantern", x = -205, z = -52, r = 3 },
} :: { Scatter.Circle }

-- The creek's old trees (WorldBuilder's eight gray-box trunks, now CreekSwap's pines): new trees
-- keep TREE_GAP from them and from each other.
CreekPlan.OLD_TREES = {
	{ x = -265, z = 40 },
	{ x = -270, z = -20 },
	{ x = -262, z = -55 },
	{ x = -195, z = 55 },
	{ x = -190, z = -40 },
	{ x = -285, z = 10 },
	{ x = -200, z = 10 },
	{ x = -275, z = 65 },
}

function CreekPlan.laneDist(l: Lane, x: number, z: number): number
	return segDist(x, z, l.x1, l.z1, l.x2, l.z2)
end

function CreekPlan.inLane(x: number, z: number, pad: number?): boolean
	local k = pad or 0
	for _, l in CreekPlan.LANES do
		if CreekPlan.laneDist(l, x, z) <= l.r + k then
			return true
		end
		if (x - l.x1) ^ 2 + (z - l.z1) ^ 2 <= (CreekPlan.LANE_FOOT + k) ^ 2 then
			return true
		end
	end
	return false
end

function CreekPlan.kept(x: number, z: number, pad: number?): boolean
	for _, b in CreekPlan.KEEP_BOXES do
		if Scatter.inBox(b, x, z, pad) then
			return true
		end
	end
	for _, c in CreekPlan.KEEP_CIRCLES do
		local k = c.r + (pad or 0)
		if (x - c.x) ^ 2 + (z - c.z) ^ 2 <= k * k then
			return true
		end
	end
	return false
end

-- True when something can stand at (x, z): inside the props box, out of every keep-clear, every
-- lane and every shot camera's view (Scatter.shotClear; `tree` uses the canopy-sized clearance).
-- `model` (a tree's kit name): a cedar gets shot 09's looser clearance (CreekPlan.treeShotClear).
function CreekPlan.clear(x: number, z: number, tree: boolean, model: string?): boolean
	local P = CreekPlan.PROPS
	if x < P.x1 or x > P.x2 or z < P.z1 or z > P.z2 then
		return false
	end
	if CreekPlan.kept(x, z) or CreekPlan.inLane(x, z) then
		return false
	end
	if tree then
		return CreekPlan.treeShotClear(x, z, model)
	end
	return Scatter.shotClear(x, z, false)
end

-- N3 review 1 (the advisor): shot 09 looks down the riffle between its bank trees, so cedars may
-- stand nearer its camera than Scatter's tree clearance allows: SHOT09 eye and line radii, cedars
-- only. Every other shot, and every other tree, keeps Scatter's (Scatter.SHOT_EYE_R_TREE,
-- SHOT_LINE_R). The same test as Scatter.shotClear, per camera.
CreekPlan.SHOT09 = { id = "09-riffle-dawn", eyeR = 10, lineR = 5 }

local function camClear(c: Scatter.ShotCam, x: number, z: number, H: number, R: number, lineR: number): boolean
	local ex, ey, ez = c.eye[1], c.eye[2], c.eye[3]
	local h2 = (x - ex) ^ 2 + (z - ez) ^ 2
	local dy = math.max(0, ey - H, -ey)
	if h2 + dy * dy < R * R then
		return false
	end
	local lx, ly, lz = c.look[1] - ex, c.look[2] - ey, c.look[3] - ez
	local len = math.sqrt(lx * lx + ly * ly + lz * lz)
	local f = math.min(1, Scatter.SHOT_LINE / len)
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
		if segDist(x, z, ax, az, bx, bz) < lineR then
			return false
		end
	end
	return true
end

function CreekPlan.treeShotClear(x: number, z: number, model: string?): boolean
	for _, c in Scatter.SHOT_CAMS do
		local loose = model == "Cedar" and c.id == CreekPlan.SHOT09.id
		local R = if loose then CreekPlan.SHOT09.eyeR else Scatter.SHOT_EYE_R_TREE
		local lineR = if loose then CreekPlan.SHOT09.lineR else Scatter.SHOT_LINE_R
		if not camClear(c, x, z, Scatter.TREE_H, R, lineR) then
			return false
		end
	end
	return true
end

-- The camera of a fixed shot (Scatter.SHOT_CAMS), by the start of its id.
function CreekPlan.shotCam(prefix: string): Scatter.ShotCam?
	for _, c in Scatter.SHOT_CAMS do
		if string.sub(c.id, 1, #prefix) == prefix then
			return c
		end
	end
	return nil
end

---------------------------------------------------------------------------------------------
-- The dressing
---------------------------------------------------------------------------------------------

-- Pivot depth under the ground line at scale 1 (art/models/manifest.json, `bury`).
CreekPlan.KIT = {
	Cedar = 1.02,
	ShorePine1 = 1.01,
	ShorePine2 = 1.01,
	CreekFern1 = 0.2,
	CreekFern2 = 1.23,
	CreekRoots = 3.52,
	MossMat = 0.48,
	MossyLog = 0.27,
	CedarBough = 0, -- hangs from its trunk (pivot at the bough's base, assumed; CreekDress sets the height)
} :: { [string]: number }

-- Triangles per copy (manifest model_triangles; ShorePine2 places its lite copy, as CreekSwap does).
CreekPlan.TRIS = {
	Cedar = 1272,
	ShorePine1 = 588,
	ShorePine2 = 697,
	CreekFern1 = 470,
	CreekFern2 = 422,
	CreekRoots = 540,
	MossMat = 216,
	MossyLog = 1152,
	CedarBough = 250, -- the modeler's target (N3 review 1)
	RockMedium = 100,
} :: { [string]: number }
CreekPlan.ROCK_MATS = 9 -- moss mats CreekDress lays on the creek's boulders (5 in the run, 4 at the head)
-- Triangles added in the creek's views. N3 review 1 ruled 120k (BUDGET_RULED), but the ruled
-- counts (60 backing trees, 70 percent cedar at 1272 each, and fewer ShorePine2) measure about
-- 149k, 157k with the boughs on: BUDGET holds the measured plan until the orchestrator settles it.
CreekPlan.BUDGET_RULED = 120000
CreekPlan.BUDGET = 160000
CreekPlan.CEDAR_H = 18 -- a cedar's height over its ground line at scale 1 (manifest height_above_ground 17.99)

-- A crown, for the canopy check: radius at scale 1, how far it reaches toward the water (the
-- cedar's nodding leader, the pine's long limbs), and the height of its middle (a tilted trunk
-- carries the crown out by sin(tilt) times this).
CreekPlan.CROWN = {
	Cedar = { r = 4.4, lean = 1.2, h = 10 },
	ShorePine1 = { r = 5.5, lean = 0.5, h = 14 },
	ShorePine2 = { r = 6.0, lean = 2.0, h = 11 },
} :: { [string]: { r: number, lean: number, h: number } }

-- How many of each, and where. The main session tunes these against the frame budget.
CreekPlan.TUNING = {
	trees = 48, -- cedars and shore pines lining both banks
	treeBand = { 1, 9 }, -- studs back from the drawn water (N3 review 1: was 2 to 6)
	nearBand = 4, -- most trunks stand at 1 to this, so the crowns reach over the water
	nearShare = 0.6, -- N3 review 1 (was 0.85)
	runShare = 0.45, -- share of trunk tries along the riffle and the rocky run (z -12 to 74)
	treeGap = 4.5, -- between trunks (the crowns overlap)
	poolEastBand = { 10, 17 }, -- the pool's east side: past the bank path
	poolEastTrees = 4,
	riffleShorePine2 = 0.15, -- share of ShorePine2 on the riffle and run (N3 review 1: was 0.55; fewer "pancake" pines)
	runShorePine1 = 0.2, -- share of ShorePine1 on the rocky run and the pool
	cedarScale = { 1.2, 1.5 }, -- N3 review (the kit note says 0.7 to 1.1; bigger to close the canopy)
	tilt = { 4, 10 }, -- degrees the bank trees lean out over the water, about the trunk foot
	pineScale = { 0.95, 1.2 },
	fernClumps = 7,
	fernPer = { 2, 4 },
	fernBand = { 1.2, 6.5 },
	lipFerns = 6, -- CreekFern2 on cut bank lips and the run's banks
	roots = 6,
	bankMats = 6,
	shadowDist = 120, -- trees further than this from the creek's water cast no shadow
	-- N3 review 1: depth behind the banks. A backing forest, 70 percent cedar (the rest ShorePine1).
	backWest = 40, -- west of the creek, D 8 to 30, x from PROPS.x1
	backWestBand = { 8, 30 },
	backWestX = -238, -- west of the riffle's west edge
	backEast = 20, -- east of the bank path
	backEastX = { -196, -172 },
	backGap = 6.5,
	backCedar = 0.7,
	backCedarScale = { 1.0, 1.4 },
	-- N3 review 1: two frame cedars on shot 09's thirds (CreekPlan.FRAME_CEDARS) and CedarBough
	-- sprays from the bank cedars along the riffle. Boughs are OFF (0) until real foliage shadows
	-- are seen on the desktop; BOUGHS_ON is the advisor's count.
	boughsPer = 0,
	boughHeight = { 0.55, 0.85 }, -- share of the cedar's height the bough hangs from
	boughSpread = 0.6, -- radians between a cedar's two boughs, about its turn toward the water
	-- N3 review 1: emergent wet-slate rocks on the riffle, each trailing foam.
	rocks = 10,
	rockR = { 1, 2 },
	rockZ = { 36, 70 },
}
CreekPlan.BOUGHS_ON = 2 -- the advisor's boughs per bank cedar along the riffle (TUNING.boughsPer)
CreekPlan.BOUGH_REACH = 10 -- studs a bough's spray reaches out over the water (12 long, drooping)
CreekPlan.BOUGH_R = 2.5 -- its half width, for the coverage check
CreekPlan.ROCK_EXTENT = 4.7 -- RockMedium's mean width at scale 1 (manifest 5.27 by 4.16)

-- Two cedars placed by hand (N3 review 1) whose trunks frame shot 09 on its thirds. Their
-- foliage must stay in the top quarter of 09's frame (the spec projects it).
CreekPlan.FRAME_CEDARS = {
	{ x = -218.5, z = 37, scale = 1.5 },
	{ x = -211, z = 40.5, scale = 1.5 },
}

export type Item = {
	model: string,
	group: string, -- Trees, Ferns, Roots, Moss, Log
	x: number,
	z: number,
	yaw: number,
	scale: number,
	shadow: boolean,
	tilt: number?, -- radians the model leans toward its -X, about its foot (trees)
	lipX: number?, -- roots: where to read the bank lip's height (the pivot sits bury under it)
	lipZ: number?,
	ends: { number }?, -- the log: x1, z1, x2, z2 of its two bank ends (heights read there)
	row: string?, -- trees: "bank" (the row along the water), "frame" (shot 09's), "poolEast", "back"
	parent: number?, -- boughs: the index (in items) of the cedar it hangs from
	footX: number?, -- boughs: the cedar's foot, where the ground is read
	footZ: number?,
	lift: number?, -- boughs: height of the bough's base over that ground
	r: number?, -- rocks: radius
}

export type Plan = {
	items: { Item },
	counts: { [string]: number },
	triangles: number,
	coverage: number,
	riffleCoverage: number, -- N3 review 1: share of the riffle's water under crowns or boughs
}

local TAU = 2 * math.pi

-- Shore points' noses are land but sit inside the water boxes: gravel only, no trunks.
local function trunkOk(x: number, z: number, band: { number }, gap: number, placed: { any }, model: string?): boolean
	if not CreekPlan.clear(x, z, true, model) then
		return false
	end
	local D = CreekPlan.D(x, z)
	if D < band[1] or D > band[2] then
		return false
	end
	for _, a in CREEK_AREAS do
		for _, p in a.points do
			if (x - p.x) ^ 2 + (z - p.z) ^ 2 <= (p.r + 1) ^ 2 then
				return false -- a spot's shore point (fished from, and gravel)
			end
		end
	end
	return Scatter.farEnough(placed, x, z, gap) and Scatter.farEnough(CreekPlan.OLD_TREES, x, z, gap + 1)
end

local function shadowAt(x: number, z: number): boolean
	return Scatter.creekWaterDist(x, z) <= CreekPlan.TUNING.shadowDist
end

-- Fraction of the drawn water of the riffle, the rocky run and the pool (every 2 studs) that
-- lies under some crown: the dappled canopy. `middle` true: only along the creek's middle line.
local function crownsOf(items: { Item }): { { x: number, z: number, r: number } }
	local crowns = {}
	for _, it in items do
		local c = CreekPlan.CROWN[it.model]
		if c then
			local lx, lz = -math.cos(it.yaw), math.sin(it.yaw) -- the model's -X after the yaw
			local reach = (c.lean + math.sin(it.tilt or 0) * c.h) * it.scale
			table.insert(crowns, { x = it.x + lx * reach, z = it.z + lz * reach, r = c.r * it.scale })
		end
	end
	return crowns
end

-- A bough's shade: a capsule from its base out BOUGH_REACH along its -X, BOUGH_R wide.
local function boughsOf(items: { Item }): { { ax: number, az: number, bx: number, bz: number, r: number } }
	local out = {}
	for _, it in items do
		if it.model == "CedarBough" then
			local lx, lz = -math.cos(it.yaw), math.sin(it.yaw)
			local reach = CreekPlan.BOUGH_REACH * it.scale
			table.insert(out, { ax = it.x, az = it.z, bx = it.x + lx * reach, bz = it.z + lz * reach, r = CreekPlan.BOUGH_R * it.scale })
		end
	end
	return out
end

-- N3 review 1: the share of the riffle's drawn water (z 30 to 76, every stud) under a crown or a
-- bough. The advisor's target is 0.6 with the boughs on.
function CreekPlan.riffleCoverage(items: { Item }): number
	local crowns, boughs = crownsOf(items), boughsOf(items)
	local hit, n = 0, 0
	for z = 30, 76 do
		for x = -242, -218 do
			if CreekPlan.D(x, z) < 0 then
				n += 1
				local under = false
				for _, c in crowns do
					if (x - c.x) ^ 2 + (z - c.z) ^ 2 <= c.r * c.r then
						under = true
						break
					end
				end
				if not under then
					for _, b in boughs do
						if segDist(x, z, b.ax, b.az, b.bx, b.bz) <= b.r then
							under = true
							break
						end
					end
				end
				if under then
					hit += 1
				end
			end
		end
	end
	return if n > 0 then hit / n else 0
end

function CreekPlan.coverage(items: { Item }, middle: boolean?): number
	local hit, n = 0, 0
	local crowns = crownsOf(items)
	for z = -72, 72, 2 do
		for x = -258, -208, 2 do
			if (if middle then x == -230 else CreekPlan.D(x, z) < 0) then
				n += 1
				for _, c in crowns do
					if (x - c.x) ^ 2 + (z - c.z) ^ 2 <= c.r * c.r then
						hit += 1
						break
					end
				end
			end
		end
	end
	return if n > 0 then hit / n else 0
end

function CreekPlan.plan(seed: number?, tuning: { [string]: any }?): Plan
	local s = seed or CreekPlan.SEED
	local T = table.clone(CreekPlan.TUNING) :: any
	if tuning then
		for k, v in tuning do
			T[k] = v
		end
	end
	local items: { Item } = {}
	local P = CreekPlan.PROPS

	local function add(model: string, group: string, x: number, z: number, yaw: number, scale: number, shadow: boolean): Item
		local it: Item = { model = model, group = group, x = x, z = z, yaw = yaw, scale = scale, shadow = shadow }
		table.insert(items, it)
		return it
	end
	local function towardWater(r: Scatter.Rng, x: number, z: number, wobble: number): number
		local dx, dz = CreekPlan.toWater(x, z)
		return Scatter.yawMinusX(dx, dz) + Scatter.range(r, -wobble, wobble)
	end

	-- 0. Shot 09's two frame cedars (placed by hand; upright, turned to the water).
	local trunks: { any } = {}
	for _, f in CreekPlan.FRAME_CEDARS do
		local dx, dz = CreekPlan.toWater(f.x, f.z)
		local it = add("Cedar", "Trees", f.x, f.z, Scatter.yawMinusX(dx, dz), f.scale, shadowAt(f.x, f.z))
		it.row = "frame"
		table.insert(trunks, { x = f.x, z = f.z })
	end

	-- 1. Trees along both banks, nearer the water more often (the crowns must reach over it).
	local rt = Scatter.rng(s + 1)
	local band = T.treeBand
	local tries = 0
	local bank = 0
	while bank < T.trees and tries < 30000 do
		tries += 1
		local x = Scatter.range(rt, -270, -209)
		local z = if Scatter.next(rt) < T.runShare then Scatter.range(rt, -12, 74) else Scatter.range(rt, -76, 74)
		local u = Scatter.next(rt)
		local pick = Scatter.next(rt)
		local model = if z > -8
			then (if pick < T.riffleShorePine2 then "ShorePine2" else "Cedar")
			else (if pick < T.runShorePine1 then "ShorePine1" else "Cedar")
		if trunkOk(x, z, band, T.treeGap, trunks, model) then
			local D = CreekPlan.D(x, z)
			if (D <= T.nearBand) == (u < T.nearShare) then
				table.insert(trunks, { x = x, z = z })
				bank += 1
				local sc = if model == "Cedar" then Scatter.range(rt, T.cedarScale[1], T.cedarScale[2]) else Scatter.range(rt, T.pineScale[1], T.pineScale[2])
				local it = add(model, "Trees", x, z, towardWater(rt, x, z, 0.25), sc, shadowAt(x, z))
				it.tilt = math.rad(Scatter.range(rt, T.tilt[1], T.tilt[2]))
				it.row = "bank"
			end
		end
	end
	-- The pool's east side, past the bank path (no room between the path and the water).
	local east = 0
	tries = 0
	while east < T.poolEastTrees and tries < 2000 do
		tries += 1
		local x = Scatter.range(rt, -197, -186)
		local z = Scatter.range(rt, -72, -12)
		if trunkOk(x, z, T.poolEastBand, T.treeGap, trunks) then
			table.insert(trunks, { x = x, z = z })
			local it = add("Cedar", "Trees", x, z, towardWater(rt, x, z, 0.3), Scatter.range(rt, 1.05, T.cedarScale[2]), shadowAt(x, z))
			it.row = "poolEast"
			east += 1
		end
	end

	-- 1b. The backing forest (N3 review 1): depth behind both banks, upright, 70 percent cedar.
	local rb = Scatter.rng(s + 11)
	local function backRow(want: number, drawX: () -> number, ok: (number, number, number) -> boolean)
		local n = 0
		local t = 0
		while n < want and t < 20000 do
			t += 1
			local x = drawX()
			local z = Scatter.range(rb, P.z1, P.z2)
			local model = if Scatter.next(rb) < T.backCedar then "Cedar" else "ShorePine1"
			local D = CreekPlan.D(x, z)
			if ok(x, z, D) and trunkOk(x, z, { -math.huge, math.huge }, T.backGap, trunks, model) then
				table.insert(trunks, { x = x, z = z })
				local sc = if model == "Cedar" then Scatter.range(rb, T.backCedarScale[1], T.backCedarScale[2]) else Scatter.range(rb, T.pineScale[1], T.pineScale[2])
				local it = add(model, "Trees", x, z, Scatter.range(rb, 0, TAU), sc, shadowAt(x, z))
				it.row = "back"
				n += 1
			end
		end
	end
	backRow(T.backWest, function()
		return Scatter.range(rb, P.x1, T.backWestX)
	end, function(x: number, _z: number, D: number): boolean
		return x <= T.backWestX and D >= T.backWestBand[1] and D <= T.backWestBand[2]
	end)
	backRow(T.backEast, function()
		return Scatter.range(rb, T.backEastX[1], T.backEastX[2])
	end, function(x: number, _z: number, D: number): boolean
		return x >= T.backEastX[1] and x <= T.backEastX[2] and D >= T.backWestBand[1]
	end)

	-- 1c. CedarBough sprays (N3 review 1): boughsPer from each bank and frame cedar along the
	-- riffle, hung at 55 to 85 percent of the tree's height and pointing out over the water.
	if T.boughsPer > 0 then
		local rbo = Scatter.rng(s + 12)
		local count = #items
		for i = 1, count do
			local tree = items[i]
			if tree.model == "Cedar" and (tree.row == "bank" or tree.row == "frame") and CreekPlan.weights(tree.z) > 0.5 then
				local H = CreekPlan.CEDAR_H * tree.scale
				local lean = tree.tilt or 0
				local lx, lz = -math.cos(tree.yaw), math.sin(tree.yaw) -- the trunk leans toward its -X
				for k = 1, T.boughsPer do
					local h = H * Scatter.range(rbo, T.boughHeight[1], T.boughHeight[2])
					local off = (k - (T.boughsPer + 1) / 2) * T.boughSpread + Scatter.range(rbo, -0.12, 0.12)
					local bx, bz = tree.x + lx * math.sin(lean) * h, tree.z + lz * math.sin(lean) * h
					local b = add("CedarBough", "Boughs", bx, bz, tree.yaw + off, 1, tree.shadow)
					b.parent = i
					b.footX, b.footZ = tree.x, tree.z
					b.lift = math.cos(lean) * h
				end
			end
		end
	end

	-- 1d. Emergent wet-slate rocks on the riffle (N3 review 1), each trailing foam (CreekPlan.foam).
	for _, rk in CreekPlan.emergentRocks(s, T) do
		local it = add("RockMedium", "Rocks", rk.x, rk.z, rk.yaw, rk.r * 2 / CreekPlan.ROCK_EXTENT, true)
		it.r = rk.r
	end

	-- 2. Fern clumps on the bank tops.
	local rf = Scatter.rng(s + 2)
	local fernBand = T.fernBand
	local function fernOk(x: number, z: number): boolean
		if not CreekPlan.clear(x, z, false) then
			return false
		end
		local D = CreekPlan.D(x, z)
		return D >= math.max(fernBand[1], CreekPlan.gravelWidth(x, z) + 0.5) and D <= fernBand[2] and Scatter.farEnough(trunks, x, z, 1.5)
	end
	local centres = Scatter.poisson(rf, T.fernClumps, 9, 4000, function(r: Scatter.Rng)
		return Scatter.range(r, P.x1, -209), Scatter.range(r, -76, 74)
	end, fernOk)
	local ferns = Scatter.cluster(rf, centres, T.fernPer, { 1.5, 3.5 }, 1.6, fernOk)
	for _, f in ferns do
		add("CreekFern1", "Ferns", f.x, f.z, Scatter.range(rf, 0, TAU), Scatter.range(rf, 0.8, 1.3), false)
	end
	-- CreekFern2 on the lips of the cut banks and the rocky run, fronds spilling toward the water.
	local lips = Scatter.poisson(rf, T.lipFerns, 7, 4000, function(r: Scatter.Rng)
		return Scatter.range(r, -262, -214), Scatter.range(r, -72, 30)
	end, function(x: number, z: number): boolean
		local D = CreekPlan.D(x, z)
		local _, rocks = CreekPlan.weights(z)
		return CreekPlan.clear(x, z, false) and D >= 0.4 and D <= 1.4 and (CreekPlan.cut(x, z) > 0.3 or rocks > 0.5) and D > CreekPlan.gravelWidth(x, z)
	end, ferns)
	for _, f in lips do
		add("CreekFern2", "Ferns", f.x, f.z, towardWater(rf, f.x, f.z, 0.3), Scatter.range(rf, 0.9, 1.2), false)
	end

	-- 3. Roots on the cut banks: the back (+X) where the bank meets the water, roots toward it.
	local rr = Scatter.rng(s + 3)
	local roots = Scatter.poisson(rr, T.roots, 8, 4000, function(r: Scatter.Rng)
		return Scatter.range(r, -264, -220), Scatter.range(r, -74, 24)
	end, function(x: number, z: number): boolean
		local D = CreekPlan.D(x, z)
		return CreekPlan.clear(x, z, false) and math.abs(D) <= 0.6 and CreekPlan.cut(x, z) > 0.4
	end)
	for _, p in roots do
		local dx, dz = CreekPlan.toWater(p.x, p.z)
		local D = CreekPlan.D(p.x, p.z)
		local sc = Scatter.range(rr, 0.85, 1.15)
		-- The waterline under this point, then the pivot half the model's depth toward the water.
		local wx, wz = p.x + dx * D, p.z + dz * D
		local it = add("CreekRoots", "Roots", wx + dx * 1.35 * sc, wz + dz * 1.35 * sc, Scatter.yawMinusX(dx, dz) + Scatter.range(rr, -0.2, 0.2), sc, false)
		it.lipX, it.lipZ = wx - dx * 2, wz - dz * 2
	end

	-- 4. Moss mats on the bank tops, near the trunks (under the canopy).
	local rm = Scatter.rng(s + 4)
	local mats = Scatter.poisson(rm, T.bankMats, 10, 4000, function(r: Scatter.Rng)
		return Scatter.range(r, P.x1, -209), Scatter.range(r, -76, 74)
	end, function(x: number, z: number): boolean
		local D = CreekPlan.D(x, z)
		return CreekPlan.clear(x, z, false) and D >= 2.5 and D <= 7 and not Scatter.farEnough(trunks, x, z, 6) and Scatter.farEnough(trunks, x, z, 1.8)
	end, ferns)
	for _, m in mats do
		add("MossMat", "Moss", m.x, m.z, Scatter.range(rm, 0, TAU), Scatter.range(rm, 0.6, 0.95), false)
	end

	-- 5. The mossy log across the pool's south-west corner: both ends on the bank, its middle over
	-- the water, out of every cast lane. Root plate (+X) on the west bank.
	local log = CreekPlan.logPlacement(s)
	if log then
		local it = add("MossyLog", "Log", log.x, log.z, log.yaw, 1, true)
		it.ends = { log.x1, log.z1, log.x2, log.z2 }
	end

	local counts: { [string]: number } = {}
	local tris = CreekPlan.ROCK_MATS * CreekPlan.TRIS.MossMat
	for _, it in items do
		counts[it.model] = (counts[it.model] or 0) + 1
		tris += CreekPlan.TRIS[it.model] or 0
	end
	return { items = items, counts = counts, triangles = tris, coverage = CreekPlan.coverage(items), riffleCoverage = CreekPlan.riffleCoverage(items) }
end

-- N3 review 1: emergent rocks on the riffle (radius rockR, z rockZ), wholly over the drawn water
-- (half a stud in), off every cast lane by their radius, and apart from each other and the old
-- boulders. Same seed, same rocks: CreekPlan.plan places them and CreekPlan.foam trails foam
-- below them.
export type Rock = { x: number, z: number, r: number, yaw: number }
function CreekPlan.emergentRocks(seed: number?, tuning: { [string]: any }?): { Rock }
	local T = tuning or CreekPlan.TUNING :: any
	local r = Scatter.rng((seed or CreekPlan.SEED) + 13)
	local out: { Rock } = {}
	local tries = 0
	while #out < T.rocks and tries < 4000 do
		tries += 1
		local x = Scatter.range(r, -238, -222)
		local z = Scatter.range(r, T.rockZ[1], T.rockZ[2])
		local rad = Scatter.range(r, T.rockR[1], T.rockR[2])
		local yaw = Scatter.range(r, 0, TAU)
		local ok = CreekPlan.D(x, z) <= -(rad + 0.5) and not CreekPlan.inLane(x, z, rad)
		if ok then
			for _, o in out do
				if (x - o.x) ^ 2 + (z - o.z) ^ 2 < (rad + o.r + 2) ^ 2 then
					ok = false
					break
				end
			end
		end
		if ok then
			for _, b in CreekPlan.BOULDERS do
				if (x - b[1]) ^ 2 + (z - b[2]) ^ 2 < (rad + b[3] + 2) ^ 2 then
					ok = false
				end
			end
		end
		if ok then
			table.insert(out, { x = x, z = z, r = rad, yaw = yaw })
		end
	end
	return out
end

-- The log: centre, yaw and its two ends. Searches centres round the pool's south-west corner and
-- every 7.5 degrees, and keeps the one whose middle is deepest over the water (ties: the seed).
CreekPlan.LOG_HALF = 13.15 -- half its length at scale 1 (manifest: 26.3 studs)
CreekPlan.LOG_HALF_WIDTH = 3.3
function CreekPlan.logPlacement(seed: number): { x: number, z: number, yaw: number, x1: number, z1: number, x2: number, z2: number }?
	local r = Scatter.rng(seed + 5)
	local best, bestScore = nil, math.huge
	local L = CreekPlan.LOG_HALF
	for cx = -254, -238, 2 do
		for cz = -72, -56, 2 do
			local jitter = Scatter.next(r) * 0.01
			for k = 0, 23 do
				local a = k * math.pi / 24
				local ux, uz = math.cos(a), math.sin(a)
				local x1, z1 = cx - ux * (L - 1.5), cz - uz * (L - 1.5)
				local x2, z2 = cx + ux * (L - 1.5), cz + uz * (L - 1.5)
				local dMid = CreekPlan.D(cx, cz)
				if dMid <= -1.5 and CreekPlan.D(x1, z1) >= 0.5 and CreekPlan.D(x2, z2) >= 0.5 then
					local ok = true
					for _, l in CreekPlan.LANES do
						-- the log's axis against the lane's segment, sampled along the log
						for t = -1, 1, 0.125 do
							local px, pz = cx + ux * L * t, cz + uz * L * t
							if CreekPlan.laneDist(l, px, pz) < l.r + CreekPlan.LOG_HALF_WIDTH then
								ok = false
							end
						end
					end
					for t = -1, 1, 0.25 do
						local px, pz = cx + ux * L * t, cz + uz * L * t
						if CreekPlan.kept(px, pz) or not Scatter.shotClear(px, pz, false) then
							ok = false
						end
					end
					if ok then
						local score = math.abs(dMid + 3) + jitter
						if score < bestScore then
							bestScore = score
							-- (ex1, ez1) the east end, (ex2, ez2) the west end; the model's +X (the root
							-- plate) points from the middle toward the west end.
							local ex1, ez1, ex2, ez2 = x1, z1, x2, z2
							if ex2 > ex1 then
								ex1, ez1, ex2, ez2 = x2, z2, x1, z1
							end
							local yaw = Scatter.yawAlongX(ex2 - ex1, ez2 - ez1)
							best = { x = cx, z = cz, yaw = yaw, x1 = ex1, z1 = ez1, x2 = ex2, z2 = ez2 }
						end
					end
				end
			end
		end
	end
	return best
end

---------------------------------------------------------------------------------------------
-- White water (ClientModules/WhiteWater)
---------------------------------------------------------------------------------------------

-- The rocky run's boulders (WorldBuilder.buildCreek: x, z, radius). Mirrors that table.
CreekPlan.BOULDERS = {
	{ -233, -2, 3.5 },
	{ -226, 8, 3 },
	{ -236, 18, 2.6 },
	{ -228, 25, 3.2 },
	{ -231, 0, 2 },
}

-- Where the spray rises: the riffle's head and where it drops into the rocky run.
CreekPlan.SPRAY = {
	{ x = -230, z = 72, w = 8 },
	{ x = -230, z = 31, w = 10 },
}

export type Strip = { x: number, z: number, len: number, w: number, yaw: number, speed: number }

-- Foam strips: x, z the middle, `len` along the flow and `w` across, `yaw` turns the strip's
-- length (its local Z) onto the flow, `speed` the scroll in studs a second. The water runs from
-- the riffle's head (z 75) down to the pool (-z).
function CreekPlan.foam(seed: number?): { Strip }
	local r = Scatter.rng((seed or CreekPlan.SEED) + 7)
	local out: { Strip } = {}
	local function strip(x: number, z: number, len: number, w: number, angle: number, speed: number)
		-- every corner of the strip must be over the drawn water, at least 0.4 in
		local fx, fz = math.sin(angle), -math.cos(angle) -- unit along the flow
		local px, pz = -fz, fx
		for _, c in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 }, { 0, 0 } } do
			local cx = x + fx * len / 2 * c[1] + px * w / 2 * c[2]
			local cz = z + fz * len / 2 * c[1] + pz * w / 2 * c[2]
			if CreekPlan.D(cx, cz) > -0.4 then
				return
			end
		end
		table.insert(out, { x = x, z = z, len = len, w = w, yaw = angle, speed = speed })
	end
	-- The riffle: a broken line of streaks down the chute, thicker at the head and the bends.
	local W = CreekPlan.foamTuning().riffleW
	local z = 71
	while z > 34 do
		local n = if z > 64 then 3 else 2
		for _ = 1, n do
			strip(Scatter.range(r, -233, -227), z, Scatter.range(r, 3, 6), Scatter.range(r, W[1], W[2]), Scatter.range(r, -0.18, 0.18), Scatter.range(r, 3, 5))
		end
		z -= Scatter.range(r, 3, 4.5)
	end
	-- The tongue where the riffle drops into the rocky run: wide and across the flow.
	for _ = 1, 4 do
		strip(Scatter.range(r, -234, -226), Scatter.range(r, 28, 32), Scatter.range(r, 1.5, 2.5), Scatter.range(r, 3, 5), Scatter.range(r, -0.3, 0.3), Scatter.range(r, 2, 3))
	end
	-- A pair of trails below each boulder.
	for _, b in CreekPlan.BOULDERS do
		for side = -1, 1, 2 do
			local len = Scatter.range(r, 3, 5)
			strip(b[1] + side * b[3] * 0.6, b[2] - b[3] - len / 2, len, Scatter.range(r, 0.6, 1.1), Scatter.range(r, -0.15, 0.15) + side * 0.12, Scatter.range(r, 2, 3.5))
		end
	end
	-- One trail below each emergent rock on the riffle (N3 review 1).
	for _, k in CreekPlan.emergentRocks(seed) do
		local len = Scatter.range(r, 2.5, 4)
		strip(k.x + Scatter.range(r, -0.3, 0.3), k.z - k.r - len / 2, len, Scatter.range(r, 0.5, 0.9) * k.r, Scatter.range(r, -0.12, 0.12), Scatter.range(r, 3, 4.5))
	end
	return out
end

return CreekPlan
