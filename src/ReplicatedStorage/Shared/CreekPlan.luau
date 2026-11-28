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
--  * N3 review 2 (the advisor, 11/28/2026): the held items on (foam, two boughs per riffle cedar);
--    backing trees at D 20 and beyond are far pines; three more rows (the south end, the head
--    hill, behind the gate); no meadow grass inside the creek fence (moss to D 30, the hill
--    forest floor beyond); the creek paths on their own gravel slot (PATH_SLOT); the gate
--    approach's ground; ten wet-slate stones along the pool's east edge.
--  * Neon's N3 review, Pass 1 (11/28/2026): the water deep enough to show over the whole drawn
--    creek (WATER_MIN), the moss to D 52 over a wider box, the gate foreground off meadow grass,
--    the pool's east lip dressed (bigger edge stones, ferns, reeds), bushes under the backing
--    trunks, ferns, bushes and stones along the gate walk and the fence foot, the log moved.
local Shore = require(script.Parent.Shore)
local WaterMap = require(script.Parent.WaterMap)
local Scatter = require(script.Parent.Scatter)

local CreekPlan = {}

CreekPlan.SEED = 20261202
CreekPlan.CELL = 4

-- The terrain CreekDress may rewrite (whole 4 stud cells): the creek's water and banks, short of
-- the bank path (x -206..-200, wandering to about -208), the creek head's rocks (z 76 on) and
-- anything past them. Columns more than TOUCH studs from the drawn water are left alone inside it.
-- Neon Pass 1: z2 72 to 76, so the riffle's last cell before the head rocks (z 76 on) is redrawn too.
CreekPlan.REGION = { x1 = -268, x2 = -208, y1 = -16, y2 = 8, z1 = -84, z2 = 76 }
CreekPlan.TOUCH = 11
CreekPlan.BLEND = { 7, 11 } -- studs from the water over which the new ground eases into the old

-- Where props may stand at all (round the creek look zone, LookPresets creek x -260..-160). N3
-- review 1 (the advisor): out to x -300 on the west and -172 on the east for the backing forest.
-- Neon Pass 1: out to x -138 for the gate walk's undergrowth and stones only (no tree row reaches
-- past -168: backEastX and rowGate keep the trees inside the fence).
CreekPlan.PROPS = { x1 = -300, x2 = -138, z1 = -82, z2 = 76 }
-- N3 review 2: inside the creek fence (WorldBuilder's fence at x -162, the creek's walls round the
-- rest). The new tree rows stand in it and no meadow grass slot stays inside it.
CreekPlan.FENCE = { name = "CreekFence", x1 = -300, x2 = -164, z1 = -112, z2 = 126 }

-- N3 review 1, held (the captures were taken in the phone simulator): the advisor's foam numbers
-- (CreekPlan.FOAM_REVIEW1, WhiteWater.REVIEW1) go live when this is true. One edit after a clean
-- desktop capture.
CreekPlan.REVIEW1_FOAM = true -- N3 review 2 (11/28/2026): on
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
-- Over the drawn water it is always at least WATER_MIN under the surface (y 0).
-- Neon Pass 1 (11/28/2026): terrain works in 4 stud cells and the surface is the top of the cell
-- y -4..0. Where the ground filled more than half that cell (ground above y -2) the cell held
-- less than half water and Roblox drew no water surface: the riffle (bed -1.6) and every shallow
-- edge read as dry stones, and only the deeper water where the riffle drops into the rocky run
-- (z under about 31) showed, as a hard-edged rectangle (round 3's shot 09). The same lesson as
-- WorldBuilder's "a 1.5 stud fill was too thin to show up at all". So every drawn-water column
-- is at least WATER_MIN deep (the top cell at most 0.4 ground), and the riffle's bed is -2.6.
CreekPlan.WATER_MIN = 2.4
CreekPlan.RIFFLE_BED = -2.6
function CreekPlan.height(x: number, z: number, dIn: number?): number
	local D = dIn or CreekPlan.D(x, z)
	local riffle, rocks, pool = CreekPlan.weights(z)
	if D < 0 then
		local bed = riffle * CreekPlan.RIFFLE_BED + rocks * -4.2 + pool * (-9.6 + 2.8 * smooth(-250, -212, x))
		local slope = riffle * 0.9 + rocks * 1.1 + pool * (0.5 + 1.3 * (1 - smooth(-248, -216, x)))
		return math.min(-CreekPlan.WATER_MIN, math.max(bed, -(0.6 + slope * -D)))
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
-- Neon Pass 1 (11/28/2026): to D 52 (was 30) over Neon's box (round 3 used the fence, x -300..-164,
-- z -112..126): behind the pool, behind the riffle head and up to the gate. The keep-clears no
-- longer stop it: MOSS_OVER never holds a gravel slot (14, 24, 32), so the paths stay gravel and
-- the grass beside them (shot 09's foreground) becomes moss.
CreekPlan.MOSS_D = 52
CreekPlan.MOSS_REGION = { name = "MossRegion", x1 = -320, x2 = -152, z1 = -125, z2 = 115 }
CreekPlan.MOSS_OVER = { [2] = true, [19] = true, [25] = true, [26] = true, [27] = true } :: { [number]: boolean }
function CreekPlan.mossBand(_x: number, _z: number, D: number): boolean
	return D >= 7 and D < CreekPlan.MOSS_D
end

-- N3 review 2: no meadow grass slot inside the creek fence. The moss band as before; past it (D 30
-- on), grass (slot 2) becomes the hill forest floor, slot 27. Nil: leave the voxel alone.
CreekPlan.GRASS_SLOT = 2
CreekPlan.FOREST_SLOT = 27
function CreekPlan.inFence(x: number, z: number): boolean
	return Scatter.inBox(CreekPlan.FENCE :: any, x, z)
end
function CreekPlan.fenceSlot(x: number, z: number, D: number, slot: number): number?
	if not CreekPlan.inFence(x, z) then
		-- Neon Pass 1: MOSS_REGION reaches past the fence (west to x -320, east to -152 by the
		-- gate): there the moss band only, nothing else.
		if Scatter.inBox(CreekPlan.MOSS_REGION :: any, x, z) and CreekPlan.MOSS_OVER[slot] and CreekPlan.mossBand(x, z, D) then
			return CreekPlan.SLOT.MOSS
		end
		return nil
	end
	if CreekPlan.MOSS_OVER[slot] and CreekPlan.mossBand(x, z, D) then
		return CreekPlan.SLOT.MOSS
	end
	if slot == CreekPlan.GRASS_SLOT and D >= CreekPlan.MOSS_D then
		return CreekPlan.FOREST_SLOT
	end
	return nil
end

-- N3 review 2: the gate approach, outside the fence on the lake side. Its forest floor (slot 25)
-- becomes the hill forest floor (27), and for WALK_BAND studs each side of the walk (the old
-- PathToCreek, z -3..3) the ground is the mown lawn (26). Nil: leave the voxel alone.
CreekPlan.APPROACH = { name = "GateApproach", x1 = -162, x2 = -118, z1 = -40, z2 = 40 }
CreekPlan.WALK = { z1 = -3, z2 = 3 }
CreekPlan.WALK_BAND = 5
CreekPlan.LAWN_SLOT = 26
local APPROACH_LAWN_OVER = { [2] = true, [19] = true, [25] = true, [27] = true } :: { [number]: boolean }
-- Neon Pass 1 (11/28/2026): in the gate's foreground (shot 11's ground) no meadow grass is left:
-- past the lawn band, grass (slot 2) becomes the hill forest floor too. Beside the walk it is
-- round 3's lawn band (slot 26), as before.
CreekPlan.GATE_FOREGROUND = { name = "GateForeground", x1 = -155, x2 = -120, z1 = -25, z2 = 25 }
-- N3 review 3 (final, 11/28/2026): shot 11's lime lawn was MeadowLawn (slot 26 painted beside
-- the walk, and slot 19 never converted). APPROACH_NO_LAWN on: the walk band becomes the hill
-- forest floor (27) too, and slots 19 and 26 become 27 anywhere in the APPROACH box. The walk's
-- own gravel (14, 24, 32) is never touched.
CreekPlan.APPROACH_NO_LAWN = true
local APPROACH_ALWAYS = { [19] = true, [26] = true } :: { [number]: boolean }
function CreekPlan.approachSlot(x: number, z: number, slot: number): number?
	if not Scatter.inBox(CreekPlan.APPROACH :: any, x, z) then
		return nil
	end
	local W = CreekPlan.WALK
	local nearWalk = z >= W.z1 - CreekPlan.WALK_BAND and z <= W.z2 + CreekPlan.WALK_BAND
	if CreekPlan.APPROACH_NO_LAWN and APPROACH_ALWAYS[slot] then
		return CreekPlan.FOREST_SLOT
	elseif nearWalk and APPROACH_LAWN_OVER[slot] then
		return if CreekPlan.APPROACH_NO_LAWN then CreekPlan.FOREST_SLOT else CreekPlan.LAWN_SLOT
	elseif not nearWalk and slot == 25 then
		return CreekPlan.FOREST_SLOT
	elseif not nearWalk and slot == CreekPlan.GRASS_SLOT and Scatter.inBox(CreekPlan.GATE_FOREGROUND :: any, x, z) then
		return CreekPlan.FOREST_SLOT
	end
	return nil
end

-- N3 review 1: the bank path and the walk to the gate are re-laid as slot 14 (FootpathGravel,
-- as the home lake's stock-ground paths). CreekDress repaints their slot 24 voxels inside these
-- boxes, and gives the old path parts the FootpathGravel variant.
-- N3 review 2: their own slot (MaterialKit.SLOTS 32, FootpathGravel tinted PATH_TINT), and the
-- path parts take the same colour.
CreekPlan.PATH_SLOT = 32
CreekPlan.PATH_TINT = { 120, 110, 92 } -- N3 review 3 (was 150,140,120): the lit path read too pale
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
-- Neon Pass 1 (11/28/2026): along the pool (z -76..-10) the bank path's box stops at x -207 (was
-- -209.5), and the pool's east lip pass (CreekPlan.plan, step 1f) dresses its water edge.
CreekPlan.KEEP_BOXES = {
	{ name = "BankPathPool", x1 = -207, x2 = -196.5, z1 = -76, z2 = -10 },
	{ name = "BankPath", x1 = -209.5, x2 = -196.5, z1 = -10, z2 = 76 },
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
function CreekPlan.clear(x: number, z: number, tree: boolean, model: string?, box: Scatter.Box?): boolean
	local P = box or CreekPlan.PROPS
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
-- N3 review 2: 09's eye moved down into the rocky run (Scatter.SHOT_CAMS); the same radii.
-- Neon Pass 1: 09's eye stands on the run's east bank at the riffle mouth (-223.5, 25), looking
-- up the chute; the same radii (its line runs out over the water).
CreekPlan.SHOT09 = { id = "09-riffle-dawn", eyeR = 10, lineR = 5 }
-- N3 review 3 (final, 11/28/2026): prime shot p07 has its own eye low in the riffle, looking up
-- the chute between the same bank cedars, so its cedars get shot 09's looser radii too
-- (Scatter's 16 and 9 took three riffle cedars and six boughs out of 09's frame).
CreekPlan.LOOSE_CEDAR_SHOTS = { ["09-riffle-dawn"] = true, ["p07-riffle-morning"] = true } :: { [string]: boolean }

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
		local loose = model == "Cedar" and CreekPlan.LOOSE_CEDAR_SHOTS[c.id] == true
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
	FarPine1 = 1.01, -- N3 review 2: the far backing trees (manifest bury 1.01 and 1.05)
	FarPine2 = 1.05,
	-- Neon Pass 1: the bank kit's undergrowth, reeds and stones (manifest bury)
	Fern1 = 0.2,
	Fern2 = 0.2,
	Bush1 = 0.13,
	Bush2 = 0.17,
	ReedClump1 = 1.01,
	ShoreStones1 = 0.4,
	ShoreStones2 = 0.4,
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
	CedarBough = 256, -- as uploaded (42 bark and 214 leaf triangles)
	RockMedium = 100,
	FarPine1 = 158,
	FarPine2 = 158,
	-- Neon Pass 1: CreekDress places the `_lite` copies where they exist (manifest)
	Fern1 = 155,
	Fern2 = 137,
	Bush1 = 286,
	Bush2 = 304,
	ReedClump1 = 410,
	ShoreStones1 = 668,
	ShoreStones2 = 588,
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
	backWest = 64, -- west of the creek, D 8 to 45, x from PROPS.x1 (N3 review 2: was 40, D 8 to 30)
	backWestBand = { 8, 45 },
	backWestX = -238, -- west of the riffle's west edge
	backEast = 28, -- east of the bank path (N3 review 2: was 20)
	backEastX = { -196, -172 },
	backGap = 6.5,
	backCedar = 0.7,
	backCedarScale = { 1.0, 1.4 },
	-- N3 review 2: backing trees at D 20 and beyond are far pines (158 triangles, shadows kept),
	-- and three more rows inside the fence, each { count, x range, z range }.
	backFarD = 20,
	farScale = { 1.0, 1.4 },
	rowSouth = { n = 18, x = { -296, -168 }, z = { -110, -78 } },
	rowHead = { n = 10, x = { -290, -176 }, z = { 88, 124 } },
	rowGate = { n = 10, x = { -200, -168 }, z = { -36, 36 } },
	-- N3 review 3 (final, 11/28/2026): the south row reads as one even wall of far pines, so
	-- southPines of its 18 become ShorePine1 or ShorePine2 (about 2.6k more triangles) and the rest
	-- take a seeded scale in southScale. 0 turns it off.
	southPines = 6,
	southScale = { 0.85, 1.35 },
	-- N3 review 1: two frame cedars on shot 09's thirds (CreekPlan.FRAME_CEDARS) and CedarBough
	-- sprays from the bank cedars along the riffle. Boughs are OFF (0) until real foliage shadows
	-- are seen on the desktop; BOUGHS_ON is the advisor's count.
	boughsPer = 2, -- N3 review 2 (11/28/2026): on, at the advisor's count (BOUGHS_ON)
	boughHeight = { 0.58, 0.85 }, -- share of the cedar's height the bough hangs from (Neon Pass 1: was 0.55)
	boughSpread = 0.6, -- radians between a cedar's two boughs, about its turn toward the water
	-- N3 review 1: emergent wet-slate rocks on the riffle, each trailing foam.
	rocks = 10,
	rockR = { 1, 2 },
	rockZ = { 36, 70 },
	-- N3 review 2: wet-slate stones along the pool's east edge, half in the water.
	-- Neon Pass 1: they are the rocks of the pool's east lip pass, scale 0.45 to 0.85 (radius 1.06
	-- to 2.0; RockMedium is 4.7 wide; round 3: radius 0.8 to 1.4), up to 10. Their stretch runs to
	-- Neon's north end (z -16, was -8) but keeps round 3's south-east corner (z -72, Neon -66):
	-- between the cast lanes, the lantern and shot 10's eye only about 17 studs of the east
	-- waterline are free, too little for 8 stones in Neon's -66..-16 alone. Gap 3.2 (was 3.5):
	-- the bigger stones sit in small clusters.
	edgeStones = 10,
	edgeStoneR = { 1.06, 2.0 },
	edgeStoneZ = { -72, -16 },
	edgeStoneGap = 3.2,
	-- Neon Pass 1: the pool's east lip (x -210..-206, z -66..-16): ferns on its land side, reeds
	-- at the water's edge (the edge stones above are its rocks).
	lipFernsEast = 6,
	lipReeds = 3,
	lipX = { -210, -206 },
	lipZ = { -66, -16 },
	-- Neon Pass 1: bushes under the backing trunks (D 6 to 24), and the gate walk's undergrowth
	-- and stones (its gravel seams and the fence foot; the walk's middle, z -4.5..4.5, stays clear).
	underBushes = 16,
	underD = { 6, 24 },
	gateItems = 14,
	gateStones = 3,
}
CreekPlan.BOUGHS_ON = 2 -- the advisor's boughs per bank cedar along the riffle (TUNING.boughsPer)
CreekPlan.BOUGH_REACH = 10 -- studs a bough's spray reaches out over the water (12 long, drooping)
CreekPlan.BOUGH_R = 2.5 -- its half width, for the coverage check
CreekPlan.ROCK_EXTENT = 4.7 -- RockMedium's mean width at scale 1 (manifest 5.27 by 4.16)

-- Two cedars placed by hand (N3 review 1) whose trunks frame shot 09 on its thirds. Their
-- foliage must stay in the top quarter of 09's frame (the spec projects it).
-- N3 review 2 (the advisor, 11/28/2026): moved for 09's new eye, scale 1.4.
-- Neon Pass 1 (11/28/2026): flanking the riffle's banks for 09's eye at the riffle mouth, scale 1.3.
CreekPlan.FRAME_CEDARS = {
	{ x = -238.5, z = 42, scale = 1.3 },
	{ x = -220.5, z = 40, scale = 1.3 },
}

-- N3 review 2: the creek head's three old pines (Scenery's, swapped to far pines by CreekSwap):
-- the head hill's new row keeps its spacing from them.
CreekPlan.HEAD_PINES = (function()
	local riffle = WaterMap.CREEK[1]
	local cx, top = (riffle.x1 + riffle.x2) / 2, riffle.z2
	return { { x = cx - 12, z = top + 24 }, { x = cx + 10, z = top + 30 }, { x = cx - 2, z = top + 40 } }
end)()

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
	row: string?, -- trees: "bank" (the row along the water), "frame" (shot 09's), "poolEast", "back", and (N3 review 2) "south", "head", "gate"
	parent: number?, -- boughs: the index (in items) of the cedar it hangs from
	footX: number?, -- boughs: the cedar's foot, where the ground is read
	footZ: number?,
	lift: number?, -- boughs: height of the bough's base over that ground
	r: number?, -- rocks: radius
	southPine: boolean?, -- N3 review 3: one of the south row's trees turned into a shore pine
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
local function trunkOk(x: number, z: number, band: { number }, gap: number, placed: { any }, model: string?, box: Scatter.Box?): boolean
	if not CreekPlan.clear(x, z, true, model, box) then
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
	return Scatter.farEnough(placed, x, z, gap) and Scatter.farEnough(CreekPlan.OLD_TREES, x, z, gap + 1) and Scatter.farEnough(CreekPlan.HEAD_PINES, x, z, gap)
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
	-- N3 review 2: at D backFarD and beyond, far pines instead; and three more rows in the fence.
	local rb = Scatter.rng(s + 11)
	local function backRow(want: number, row: string, drawX: () -> number, drawZ: () -> number, ok: (number, number, number) -> boolean, box: Scatter.Box?)
		local n = 0
		local t = 0
		while n < want and t < 20000 do
			t += 1
			local x = drawX()
			local z = drawZ()
			local u = Scatter.next(rb)
			local D = CreekPlan.D(x, z)
			local far = D >= T.backFarD
			local model = if far then (if u < 0.5 then "FarPine1" else "FarPine2") elseif u < T.backCedar then "Cedar" else "ShorePine1"
			if ok(x, z, D) and trunkOk(x, z, { -math.huge, math.huge }, T.backGap, trunks, model, box) then
				table.insert(trunks, { x = x, z = z })
				local lo, hi = T.pineScale[1], T.pineScale[2]
				if far then
					lo, hi = T.farScale[1], T.farScale[2]
				elseif model == "Cedar" then
					lo, hi = T.backCedarScale[1], T.backCedarScale[2]
				end
				local sc = Scatter.range(rb, lo, hi)
				local it = add(model, "Trees", x, z, Scatter.range(rb, 0, TAU), sc, shadowAt(x, z))
				it.row = row
				n += 1
			end
		end
	end
	local function zIn(lo: number, hi: number): () -> number
		return function()
			return Scatter.range(rb, lo, hi)
		end
	end
	backRow(T.backWest, "back", function()
		return Scatter.range(rb, P.x1, T.backWestX)
	end, zIn(P.z1, P.z2), function(x: number, _z: number, D: number): boolean
		return x <= T.backWestX and D >= T.backWestBand[1] and D <= T.backWestBand[2]
	end)
	backRow(T.backEast, "back", function()
		return Scatter.range(rb, T.backEastX[1], T.backEastX[2])
	end, zIn(P.z1, P.z2), function(x: number, _z: number, D: number): boolean
		return x >= T.backEastX[1] and x <= T.backEastX[2] and D >= T.backWestBand[1]
	end)
	local function anywhere(_x: number, _z: number, D: number): boolean
		return D >= T.backWestBand[1]
	end
	for _, r in { { T.rowSouth, "south" }, { T.rowHead, "head" }, { T.rowGate, "gate" } } do
		local spec, row = r[1] :: any, r[2] :: string
		backRow(spec.n, row, function()
			return Scatter.range(rb, spec.x[1], spec.x[2])
		end, zIn(spec.z[1], spec.z[2]), anywhere, CreekPlan.FENCE)
	end
	-- N3 review 3: break up the south row (its own random numbers, so nothing else moves).
	if T.southPines > 0 then
		local rs = Scatter.rng(s + 19)
		local south: { Item } = {}
		for _, it in items do
			if it.row == "south" then
				table.insert(south, it)
			end
		end
		for i = #south, 2, -1 do -- a seeded shuffle, then the first southPines become shore pines
			local j = math.floor(Scatter.range(rs, 1, i + 1 - 1e-9))
			south[i], south[j] = south[j], south[i]
		end
		for i, it in south do
			if i <= T.southPines then
				it.model = if i % 2 == 1 then "ShorePine1" else "ShorePine2"
				it.scale = Scatter.range(rs, T.pineScale[1], T.pineScale[2])
				it.southPine = true
			else
				it.scale = Scatter.range(rs, T.southScale[1], T.southScale[2])
			end
		end
	end

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
					-- Neon Pass 1: a bough that would not reach out over the water is left off (a
					-- frame cedar on a meander's nose, where the water lies on two sides).
					local yaw = tree.yaw + off
					local reach = CreekPlan.D(bx - math.cos(yaw) * 6, bz + math.sin(yaw) * 6) < CreekPlan.D(bx, bz)
					if reach then
						local b = add("CedarBough", "Boughs", bx, bz, yaw, 1, tree.shadow)
						b.parent = i
						b.footX, b.footZ = tree.x, tree.z
						b.lift = math.cos(lean) * h
					end
				end
			end
		end
	end

	-- 1d. Emergent wet-slate rocks on the riffle (N3 review 1), each trailing foam (CreekPlan.foam).
	for _, rk in CreekPlan.emergentRocks(s, T) do
		local it = add("RockMedium", "Rocks", rk.x, rk.z, rk.yaw, rk.r * 2 / CreekPlan.ROCK_EXTENT, true)
		it.r = rk.r
	end

	-- 1e. N3 review 2: wet-slate stones along the pool's east edge, half in the water.
	for _, st in CreekPlan.edgeStones(s, T) do
		local it = add("RockMedium", "EdgeStones", st.x, st.z, st.yaw, st.r * 2 / CreekPlan.ROCK_EXTENT, true)
		it.r = st.r
	end

	-- 1f. Neon Pass 1: the pool's east lip. Ferns on its land side, reeds at the water's edge,
	-- clear of the cast lanes and their feet, the lantern, the shot cameras and the edge stones.
	-- The bank path's keep-clear does not count here (this pass dresses its water edge).
	for _, p in CreekPlan.lipSpots(s, T) do
		local it = add(p.model, "Lip", p.x, p.z, p.yaw, p.scale, false)
		it.row = p.kind
	end

	-- 1g. Neon Pass 1: bushes under the backing trunks (D underD), 2 to 4.5 studs from a trunk.
	local ru = Scatter.rng(s + 16)
	local backTrunks = {}
	for _, it in items do
		if it.group == "Trees" and (it.row == "back" or it.row == "south" or it.row == "head" or it.row == "gate") then
			table.insert(backTrunks, it)
		end
	end
	local bushes: { { x: number, z: number } } = {}
	local tb = 0
	while #bushes < T.underBushes and tb < 6000 and #backTrunks > 0 do
		tb += 1
		local tr = backTrunks[1 + math.floor(Scatter.next(ru) * #backTrunks)]
		local a = Scatter.range(ru, 0, TAU)
		local d = Scatter.range(ru, 2, 4.5)
		local x, z = tr.x + math.cos(a) * d, tr.z + math.sin(a) * d
		local D = CreekPlan.D(x, z)
		if D >= T.underD[1] and D <= T.underD[2] and CreekPlan.clear(x, z, false) and Scatter.farEnough(trunks, x, z, 1.8) and Scatter.farEnough(bushes, x, z, 4) then
			table.insert(bushes, { x = x, z = z })
			add(if Scatter.next(ru) < 0.5 then "Bush1" else "Bush2", "Under", x, z, Scatter.range(ru, 0, TAU), Scatter.range(ru, 0.9, 1.3), false)
		end
	end

	-- 1h. Neon Pass 1: the gate walk's undergrowth and stones, along its gravel seams outside the
	-- gate (x -150..-138, 4.5 to 9.5 studs off its middle) and the fence foot on the lake side
	-- (x -160.5..-156.5, 12.5 to 35 studs off the walk): ferns, bushes and a few shore stones.
	for _, g in CreekPlan.gateSpots(s, T) do
		add(g.model, "Gate", g.x, g.z, g.yaw, g.scale, false)
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

-- N3 review 2: stones along the pool's east edge, its south-east corner included: walking the
-- edge from south to north (z edgeStoneZ, every half stud), the east-most point of the drawn
-- waterline (D -0.4 to 0.4, x -215 on) takes a stone when its middle is out of every cast lane,
-- clear of the pool lantern and the shot cameras, and edgeStoneGap from the last. The bank path's
-- keep-clear reaches the water here, so it does not count. Same seed, same stones (the seed
-- sets each stone's size and turn).
function CreekPlan.edgeStones(seed: number?, tuning: { [string]: any }?): { Rock }
	local T = tuning or CreekPlan.TUNING :: any
	local r = Scatter.rng((seed or CreekPlan.SEED) + 14)
	local out: { Rock } = {}
	local z = T.edgeStoneZ[1]
	while z <= T.edgeStoneZ[2] and #out < T.edgeStones do
		local x = -203
		while x >= -215 and math.abs(CreekPlan.D(x, z)) > 0.4 do
			x -= 0.25
		end
		local ok = x >= -215 and not CreekPlan.inLane(x, z) and Scatter.shotClear(x, z, false)
		for _, c in CreekPlan.KEEP_CIRCLES do
			if (x - c.x) ^ 2 + (z - c.z) ^ 2 <= (c.r + 1) ^ 2 then
				ok = false
			end
		end
		for _, o in out do
			if (x - o.x) ^ 2 + (z - o.z) ^ 2 < T.edgeStoneGap ^ 2 then
				ok = false
			end
		end
		if ok then
			table.insert(out, { x = x, z = z, r = Scatter.range(r, T.edgeStoneR[1], T.edgeStoneR[2]), yaw = Scatter.range(r, 0, TAU) })
		end
		z += 0.5
	end
	return out
end

-- Neon Pass 1 (11/28/2026): the pool's east lip (TUNING lipX, lipZ). lipFernsEast fern clumps on
-- the land side (D 0.3 to 1.4, fronds toward the water) and lipReeds reed clumps at the water's
-- edge (D -1.2 to 0), each out of every cast lane and its foot, clear of the pool lantern and the
-- shot cameras, and apart from the edge stones and each other. Same seed, same spots.
export type Spot = { model: string, kind: string, x: number, z: number, yaw: number, scale: number }
function CreekPlan.lipSpots(seed: number?, tuning: { [string]: any }?): { Spot }
	local T = tuning or CreekPlan.TUNING :: any
	local s = seed or CreekPlan.SEED
	local r = Scatter.rng(s + 15)
	local stones = CreekPlan.edgeStones(s, T)
	local out: { Spot } = {}
	local function ok(x: number, z: number, gap: number): boolean
		if CreekPlan.inLane(x, z) or not Scatter.shotClear(x, z, false) then
			return false
		end
		for _, c in CreekPlan.KEEP_CIRCLES do
			if (x - c.x) ^ 2 + (z - c.z) ^ 2 <= (c.r + 1) ^ 2 then
				return false
			end
		end
		for _, st in stones do
			-- tucked against a stone is fine (most of the free lip is beside them), not inside one
			if (x - st.x) ^ 2 + (z - st.z) ^ 2 < (st.r * 0.75) ^ 2 then
				return false
			end
		end
		for _, o in out do
			if (x - o.x) ^ 2 + (z - o.z) ^ 2 < gap * gap then
				return false
			end
		end
		return true
	end
	for _, want in { { kind = "fern", n = T.lipFernsEast, D = { 0.2, 1.6 }, gap = 2.5 }, { kind = "reed", n = T.lipReeds, D = { -1.2, 0 }, gap = 3 } } do
		local n, tries = 0, 0
		while n < want.n and tries < 4000 do
			tries += 1
			local x = Scatter.range(r, T.lipX[1], T.lipX[2])
			local z = Scatter.range(r, T.lipZ[1], T.lipZ[2])
			local D = CreekPlan.D(x, z)
			if D >= want.D[1] and D <= want.D[2] and ok(x, z, want.gap) then
				n += 1
				local dx, dz = CreekPlan.toWater(x, z)
				local yaw = Scatter.yawMinusX(dx, dz) + Scatter.range(r, -0.3, 0.3)
				if want.kind == "fern" then
					table.insert(out, { model = if n % 2 == 1 then "CreekFern1" else "CreekFern2", kind = "fern", x = x, z = z, yaw = yaw, scale = Scatter.range(r, 0.9, 1.2) })
				else
					table.insert(out, { model = "ReedClump1", kind = "reed", x = x, z = z, yaw = Scatter.range(r, 0, TAU), scale = Scatter.range(r, 0.7, 0.95) })
				end
			end
		end
	end
	return out
end

-- Neon Pass 1 (11/28/2026): the gate walk's dressing (TUNING gateItems, gateStones). Half along
-- the walk's gravel seams outside the gate (x -150..-138, 4.5 to 9.5 studs off its middle, which
-- stays clear), half along the fence foot on the lake side (x -160.5..-156.5, 12.5 to 35 studs
-- off the walk, clear of the gate). Ferns (60 percent) and bushes, and gateStones shore stones;
-- each clear of the keep-clears, the lanes and the shot cameras (CreekPlan.clear) and 2.5 studs
-- from the rest. Same seed, same spots.
CreekPlan.GATE_SEAMS = { x = { -150, -138 }, off = { 4.5, 9.5 } }
CreekPlan.FENCE_FOOT = { x = { -160.5, -156.5 }, off = { 12.5, 35 } }
function CreekPlan.gateSpots(seed: number?, tuning: { [string]: any }?): { Spot }
	local T = tuning or CreekPlan.TUNING :: any
	local r = Scatter.rng((seed or CreekPlan.SEED) + 17)
	local out: { Spot } = {}
	local tries = 0
	while #out < T.gateItems and tries < 6000 do
		tries += 1
		local zone = if #out % 2 == 0 then CreekPlan.GATE_SEAMS else CreekPlan.FENCE_FOOT
		local x = Scatter.range(r, zone.x[1], zone.x[2])
		local off = Scatter.range(r, zone.off[1], zone.off[2])
		local z = if Scatter.next(r) < 0.5 then -off else off
		local ok = CreekPlan.clear(x, z, false)
		for _, o in out do
			if (x - o.x) ^ 2 + (z - o.z) ^ 2 < 2.5 * 2.5 then
				ok = false
			end
		end
		if ok then
			local k = #out + 1
			local u = Scatter.next(r)
			local model: string
			if k % math.max(1, math.floor(T.gateItems / T.gateStones)) == 0 and k <= T.gateItems then
				model = if u < 0.5 then "ShoreStones1" else "ShoreStones2"
			elseif u < 0.6 then
				model = if Scatter.next(r) < 0.5 then "Fern1" else "Fern2"
			else
				model = if Scatter.next(r) < 0.5 then "Bush1" else "Bush2"
			end
			table.insert(out, { model = model, kind = "gate", x = x, z = z, yaw = Scatter.range(r, 0, TAU), scale = Scatter.range(r, 0.85, 1.25) })
		end
	end
	return out
end

-- The log: centre, yaw and its two ends. Searches centres round the pool's south-west corner and
-- every 7.5 degrees, and keeps the one whose middle is deepest over the water (ties: the seed).
CreekPlan.LOG_HALF = 13.15 -- half its length at scale 1 (manifest: 26.3 studs)
CreekPlan.LOG_HALF_WIDTH = 3.3
-- Where its middle is searched for. Neon Pass 1 (11/28/2026): x -250..-234, z -62..-42, so it
-- reads from shots 10 and 12 (round 3: x -254..-238, z -72..-56).
CreekPlan.LOG_SEARCH = { x = { -250, -234 }, z = { -62, -42 } }
-- Neon Pass 1: a lighter bark (138, 122, 104) and moss top (88, 118, 60) for the log, as part
-- colours. HELD (false): a MeshPart's colour multiplies its vertex colours, so these numbers
-- would darken the log (bark about 0.54 of its baked colour), not lighten it. Lightening needs a
-- vertex colour re-bake in art/. CreekDress applies them only when this is true.
CreekPlan.LOG_TINT_ON = false
CreekPlan.LOG_TINT = { bark = { 138, 122, 104 }, leaf = { 88, 118, 60 } }
function CreekPlan.logPlacement(seed: number): { x: number, z: number, yaw: number, x1: number, z1: number, x2: number, z2: number }?
	local r = Scatter.rng(seed + 5)
	local best, bestScore = nil, math.huge
	local L = CreekPlan.LOG_HALF
	local B = CreekPlan.LOG_SEARCH
	for cx = B.x[1], B.x[2], 2 do
		for cz = B.z[1], B.z[2], 2 do
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

-- N3 review 3 (final, 11/28/2026): the foam map (art/textures/white_water) streaks along its U
-- (image X) and fades to nothing on its top and bottom rows (V edges). Round 3 laid U across the
-- strip and scrolled V, so the streaks ran bank to bank in hard rectangles. Now the strip's part
-- has its local +X downstream: a Texture on the Top face runs U along the part's +X and V along
-- its +Z, so U is along the flow, one V tile is exactly the strip's width (the faded rows sit on
-- its long edges), and OffsetStudsU scrolls it. A feature at u sits at X = OffsetStudsU + u *
-- StudsPerTileU, so a growing offset carries the foam toward +X, downstream.
CreekPlan.FOAM_TILE_U = 6 -- studs of flow per tile of the foam map

export type FoamFace = { sizeX: number, sizeZ: number, rx: number, rz: number, tileU: number, tileV: number }

-- How ClientModules/WhiteWater lays one strip: the part's size (X along the flow, Z across),
-- its local +X in world (rx, rz: unit, downstream) and the texture's tiles.
function CreekPlan.foamFace(st: Strip): FoamFace
	return {
		sizeX = st.len,
		sizeZ = st.w,
		rx = math.sin(st.yaw),
		rz = -math.cos(st.yaw),
		tileU = CreekPlan.FOAM_TILE_U,
		tileV = st.w,
	}
end

-- The texture's OffsetStudsU at `clock` seconds for a strip scrolling `speed` studs a second.
function CreekPlan.foamOffsetU(clock: number, speed: number): number
	return (clock * speed) % CreekPlan.FOAM_TILE_U
end

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

---------------------------------------------------------------------------------------------
-- White water, take 2 (11/28/2026, after the N3 final critic): soft beams and pillows
---------------------------------------------------------------------------------------------
-- The critic read the textured strips above as "hard-edged rectangular whitewater foam patches".
-- A flat part has four straight edges and four corners however its map fades, so the foam is now
-- drawn with Beams: each one runs downstream between two attachments, its Transparency fades in
-- at the head and out at the tail (no straight ends), the foam map's faded V rows sit on its two
-- long sides (no straight sides), it tapers (Width0 to Width1) and bends a little (CurveSize0/1
-- with the two attachments turned apart). Several narrow, overlapping beams with seeded offsets
-- make each tongue, so no two match. Behind each emergent rock and boulder a soft pillow of the
-- spray map (a small, slow ParticleEmitter) and a short trail beam starting under the rock.
-- Off (false): ClientModules/WhiteWater draws the old strips (CreekPlan.foam) as before.
CreekPlan.FOAM_BEAMS_ON = true
CreekPlan.FOAM_Y = 0.1 -- every beam's height: over the water (y 0) and its 0.06 chop, ZOffset does the rest
CreekPlan.FOAM_ZOFFSET = 0.05 -- studs toward the camera, so the chop's crests never cut a beam
CreekPlan.FOAM_SEGMENTS = 8
CreekPlan.FOAM_BEAM_MAX = 64 -- budget: beams
CreekPlan.FOAM_PUFF_MAX = 20 -- budget: emitters
CreekPlan.FOAM_PARTICLE_MAX = 100 -- budget: particles alive at once (rate x longest life, summed)
-- Which attachment axis is the ribbon's normal with FaceCamera off. "Y": the attachments' Y
-- (SecondaryAxis) points up and the width lies along their Z, across the flow. If a capture shows
-- the foam standing on edge like a fence, set "Z" (the width then lies along Y, Z points up).
CreekPlan.FOAM_BEAM_NORMAL = "Y"

export type FoamBeam = {
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	yaw0: number, -- the attachments' flow directions (0 is straight down the creek, -z)
	yaw1: number,
	w0: number, -- Width0 (head) and Width1 (tail), studs
	w1: number,
	curve: number, -- CurveSize0 = CurveSize1 (studs along each attachment's flow direction)
	speed: number, -- studs a second downstream
	base: number, -- the transparency in the beam's middle
	fadeIn: number, -- share of the length to fade in over at the head
	fadeOut: number, -- and out over at the tail
	kind: string, -- "riffle", "drop", "boulder", "rock"
}

export type FoamPuff = {
	x: number,
	z: number,
	y: number,
	kind: string, -- "pillow" (behind a rock or boulder) or "spray"
	w: number, -- the emitter's footprint across the flow (spray only; a pillow is a point)
	rate: number,
	life: { number }, -- min, max seconds
	speed: { number },
	size: { number }, -- at birth, at death
	transparency: { number }, -- at birth, at death
	rise: number, -- Acceleration's y
	drift: number, -- Acceleration downstream
}

local function flowDir(yaw: number): (number, number)
	return math.sin(yaw), -math.cos(yaw)
end

-- A point on a beam's curve, t 0 (head, Attachment0) to 1 (tail): Roblox's cubic Bezier with
-- P1 = P0 + dir0 * CurveSize0 and P2 = P3 - dir1 * CurveSize1, all at FOAM_Y.
function CreekPlan.foamBeamPoint(b: FoamBeam, t: number): (number, number, number)
	local d0x, d0z = flowDir(b.yaw0)
	local d1x, d1z = flowDir(b.yaw1)
	local p1x, p1z = b.x0 + d0x * b.curve, b.z0 + d0z * b.curve
	local p2x, p2z = b.x1 - d1x * b.curve, b.z1 - d1z * b.curve
	local u = 1 - t
	local a, c, d, e = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
	return a * b.x0 + c * p1x + d * p2x + e * b.x1, CreekPlan.FOAM_Y, a * b.z0 + c * p1z + d * p2z + e * b.z1
end

function CreekPlan.foamBeamWidth(b: FoamBeam, t: number): number
	return b.w0 + (b.w1 - b.w0) * t
end

-- The beam's Transparency keypoints { t, value }: clear at both ends, `base` in the middle.
function CreekPlan.foamBeamFade(b: FoamBeam): { { number } }
	return { { 0, 1 }, { b.fadeIn, b.base }, { 1 - b.fadeOut, b.base }, { 1, 1 } }
end

-- TextureSpeed (texture cycles a second, positive runs Attachment0 to Attachment1, downstream).
-- With TextureMode Wrap one cycle travels TextureLength studs (FOAM_TILE_U).
function CreekPlan.foamTextureSpeed(speed: number): number
	return speed / CreekPlan.FOAM_TILE_U
end

-- The attachments' frame at an end: its flow direction (Axis, X) and the up and across vectors as
-- FOAM_BEAM_NORMAL says. Returns rightVector, upVector for CFrame.fromMatrix (both unit, level).
function CreekPlan.foamFrame(yaw: number): ({ number }, { number })
	local fx, fz = flowDir(yaw)
	if CreekPlan.FOAM_BEAM_NORMAL == "Z" then
		return { fx, 0, fz }, { -fz, 0, fx } -- Y across the flow, so Z (X cross Y) is vertical
	end
	return { fx, 0, fz }, { 0, 1, 0 }
end

local function foamRocks(seed: number?): { { number } }
	local out = {}
	for _, b in CreekPlan.BOULDERS do
		table.insert(out, { b[1], b[2], b[3] })
	end
	for _, k in CreekPlan.emergentRocks(seed) do
		table.insert(out, { k.x, k.z, k.r })
	end
	return out
end

-- Every beam: sampled every eighth of its length, the whole width (and 0.3 more) over the drawn
-- water; riffle and drop beams also keep their middle line 0.2 off every rock and boulder (a
-- trail starts under its own rock, so the rock hides its head).
function CreekPlan.foamBeamFits(b: FoamBeam, rocks: { { number } }): boolean
	for i = 0, 8 do
		local t = i / 8
		local x, _, z = CreekPlan.foamBeamPoint(b, t)
		if CreekPlan.D(x, z) > -(CreekPlan.foamBeamWidth(b, t) / 2 + 0.3) then
			return false
		end
		if b.kind == "riffle" or b.kind == "drop" then
			for _, k in rocks do
				if (x - k[1]) ^ 2 + (z - k[2]) ^ 2 < (k[3] + 0.2) ^ 2 then
					return false
				end
			end
		end
	end
	return true
end

function CreekPlan.foamBeams(seed: number?): { FoamBeam }
	local r = Scatter.rng((seed or CreekPlan.SEED) + 29)
	local rocks = foamRocks(seed)
	local out: { FoamBeam } = {}
	local function beam(kind: string, x0: number, z0: number, len: number, angle: number, w0: number, w1: number, speed: number): boolean
		local fx, fz = flowDir(angle)
		local bend = Scatter.range(r, -0.14, 0.14)
		local b: FoamBeam = {
			x0 = x0,
			z0 = z0,
			x1 = x0 + fx * len,
			z1 = z0 + fz * len,
			yaw0 = angle + bend,
			yaw1 = angle - bend * Scatter.range(r, -0.6, 1), -- an arc or a slight S
			w0 = w0,
			w1 = w1,
			curve = len * 0.3,
			speed = speed,
			base = Scatter.range(r, 0.12, 0.34),
			fadeIn = Scatter.range(r, 0.16, 0.3),
			fadeOut = Scatter.range(r, 0.3, 0.45),
			kind = kind,
		}
		if #out < CreekPlan.FOAM_BEAM_MAX and CreekPlan.foamBeamFits(b, rocks) then
			table.insert(out, b)
			return true
		end
		return false
	end
	-- The riffle: tongues down the chute, two or three narrow beams each, offset and overlapping.
	-- The emergent rocks stand every few studs, so a beam that would run into one is tried again
	-- (up to TRIES times, a little shorter each time) somewhere else in its tongue.
	local TRIES = 8
	local z = 73
	while z > 36 do
		local cx = -230 + Scatter.range(r, -2.6, 2.6)
		local n = if z > 64 or z < 42 then 3 else 2
		for _ = 1, n do
			local w = Scatter.range(r, 0.6, 1.5)
			local len = Scatter.range(r, 5, 9)
			for try = 0, TRIES - 1 do
				local spread = 1 + try * 0.5 -- wander further from the tongue's line on each retry
				if beam("riffle", cx + Scatter.range(r, -spread, spread), z + Scatter.range(r, -0.7, 0.7), len * (1 - 0.07 * try), Scatter.range(r, -0.12, 0.12), w * Scatter.range(r, 0.45, 0.7), w, Scatter.range(r, 3, 5)) then
					break
				end
			end
		end
		z -= Scatter.range(r, 2.4, 3.4)
	end
	-- Where the riffle drops into the rocky run: wider at the lip, narrowing as it spreads out.
	for _ = 1, 6 do
		local w = Scatter.range(r, 1.2, 2.4)
		local len = Scatter.range(r, 3.5, 6)
		for try = 0, TRIES - 1 do -- the run's boulders stand just below the lip: shorter on each retry
			if beam("drop", Scatter.range(r, -235, -225), Scatter.range(r, 31.5, 34), len * (1 - 0.08 * try), Scatter.range(r, -0.25, 0.25), w * 0.85, w * Scatter.range(r, 0.5, 0.8), Scatter.range(r, 2, 3)) then
				break
			end
		end
	end
	-- Two trails below each boulder, a little apart, starting under it.
	for _, b in CreekPlan.BOULDERS do
		for side = -1, 1, 2 do
			local w = Scatter.range(r, 0.5, 1)
			local _ = beam("boulder", b[1] + side * b[3] * 0.45, b[2] - b[3] * 0.7, Scatter.range(r, 3, 5.5), side * Scatter.range(r, 0.05, 0.18), w * 0.6, w, Scatter.range(r, 2, 3.5))
		end
	end
	-- One trail below each emergent rock, starting under it and narrowing downstream.
	for _, k in CreekPlan.emergentRocks(seed) do
		local w = k.r * Scatter.range(r, 0.6, 0.9)
		local len = Scatter.range(r, 2.5, 4.5)
		for try = 0, 3 do -- near a bank: narrower and shorter, then turned a little toward the middle
			local s = 1 - 0.15 * try
			local lean = if k.x > -230 then -0.08 * try else 0.08 * try
			if beam("rock", k.x + Scatter.range(r, -0.2, 0.2), k.z - k.r * 0.6, len * s, Scatter.range(r, -0.1, 0.1) + lean, w * 0.85 * s, w * 0.5 * s, Scatter.range(r, 3, 4.5)) then
				break
			end
		end
	end
	return out
end

-- The pillows (one behind each emergent rock and boulder, at its downstream foot) and the two
-- sprays (CreekPlan.SPRAY): low rate, short life, slow, soft.
function CreekPlan.foamPuffs(seed: number?): { FoamPuff }
	local out: { FoamPuff } = {}
	for _, k in foamRocks(seed) do
		local big = k[3] > 2.2 -- a boulder
		table.insert(out, {
			x = k[1],
			z = k[2] - k[3] * 0.75,
			y = CreekPlan.FOAM_Y + 0.05,
			kind = "pillow",
			w = 0,
			rate = if big then 4 else 3,
			life = { 0.7, 1.2 },
			speed = { 0.3, 0.8 },
			size = { 0.3, 0.9 + 0.2 * k[3] },
			transparency = { 0.55, 1 },
			rise = -0.8,
			drift = 1.2,
		})
	end
	for _, sp in CreekPlan.SPRAY do
		table.insert(out, {
			x = sp.x,
			z = sp.z,
			y = 0.1,
			kind = "spray",
			w = sp.w,
			rate = 10,
			life = { 0.5, 0.9 },
			speed = { 1.5, 3.5 },
			size = { 0.25, 0.7 },
			transparency = { 0.45, 1 },
			rise = -9,
			drift = 0,
		})
	end
	return out
end

-- Particles alive at once, at most: rate x the longest life, summed.
function CreekPlan.foamParticleMax(puffs: { FoamPuff }): number
	local n = 0
	for _, p in puffs do
		n += p.rate * p.life[2]
	end
	return n
end

---------------------------------------------------------------------------------------------
-- The creek kit (Neon Pass 2, 11/28/2026): the gate arch, the hero fence and the lantern posts
---------------------------------------------------------------------------------------------

-- The one switch for the creek kit. On: Scenery.creekKit places CreekGateArch over the gate (the
-- gray-box ArchPost and ArchBeam hide), eight CreekFenceSection copies on the gate face (the old
-- posts and rails in that span hide; the creek's FenceNorth and FenceSouth walls keep their
-- collision), WorldBuilder.paintSigns paints "Cedar Creek" on the arch's sign slab, and
-- CreekSwap builds its lanterns from CreekLanternPost. Off: the gray box as before (each builder
-- puts it back on its next run). Art from ServerStorage.Art (art/README.md, the last two sections).
CreekPlan.CREEK_KIT_ON = true

-- Triangles per placed set (art/models/manifest.json: the meshes of each set, specks included).
CreekPlan.KIT_TRIS = {
	CreekGateArch = 1100, -- bark 224, wood 668, stone 208
	CreekFenceSection1 = 212,
	CreekFenceSection2 = 212,
	CreekLanternPost = 351, -- bark 205, metal 134, glass 12
} :: { [string]: number }
CreekPlan.KIT_LANTERNS = 2 -- the pool lantern and the gate lamp (CreekSwap.LAMPS)

-- The arch, in studs from its pivot (the base centre, front -Z; the ground line SINK above it).
-- At yaw -90 degrees its front faces the lake (+X) and its own +X runs south (+Z).
CreekPlan.ARCH = {
	sink = 0.4,
	yaw = -math.pi / 2,
	opening = 8.56, -- clear between the posts
	stones = 8.1, -- clear between the footing stones
	-- The sign slab: 0.32 thick, its centre plane z -1.02; the flat lake face 6.97 x 1.24 at
	-- (0, 8.17, -1.18), the creek face at z -0.86. The painted board is a hair thicker so its two
	-- faces sit just proud of the slab's.
	sign = { y = 8.17, z = -1.02, width = 6.97, height = 1.24, depth = 0.36 },
	-- The invisible post blocks: the posts and their stones, local |x| from INNER to OUTER, DEPTH
	-- deep, from the ground to the beam's underside (10.2 over the pivot).
	post = { inner = 4.1, outer = 5.7, depth = 1.6, top = 10.2 },
}

-- The arch's pivot over the gate leaf at (gx, gz) on ground `ground`.
function CreekPlan.archCFrame(gx: number, gz: number, ground: number): CFrame
	return CFrame.new(gx, ground - CreekPlan.ARCH.sink, gz) * CFrame.Angles(0, CreekPlan.ARCH.yaw, 0)
end

-- The painted board on the sign slab: its centre (LookVector = the lake face), width, height and
-- thickness.
function CreekPlan.archSign(arch: CFrame): (CFrame, number, number, number)
	local S = CreekPlan.ARCH.sign
	return arch * CFrame.new(0, S.y, S.z), S.width, S.height, S.depth
end

-- The two post blocks: { cframe, size } each.
function CreekPlan.archColliders(arch: CFrame): { { cframe: CFrame, size: Vector3 } }
	local P = CreekPlan.ARCH.post
	local sink = CreekPlan.ARCH.sink
	local h = P.top - sink
	local out = {}
	for _, side in { -1, 1 } do
		local x = side * (P.inner + P.outer) / 2
		table.insert(out, { cframe = arch * CFrame.new(x, sink + h / 2, 0), size = Vector3.new(P.outer - P.inner, h, P.depth) })
	end
	return out
end

-- The hero fence (the advisor: the gate face only, eight sections, the rest of the fence as it
-- is). A section is 10 studs of fence: posts at local x +5 and 0, rails running on to -5.5 (its
-- open end, toward the arch). Four a side, the first pivot FIRST from the gate's centre line so
-- its rails end inside the arch post. The last post lands on Scenery's old post at END_AT (the
-- old fence's posts stand every 76/12 studs from the leaf's edge at 4), so the run hands over to
-- the old fence with no gap: the step stretches from 10 to about 10.88 (the modeler allows a
-- stretch; the rails still meet the next post).
CreekPlan.HERO_FENCE = {
	first = 10.7,
	perSide = 4,
	endAt = 4 + 7 * 76 / 12, -- 48.33
	post = 5, -- the far post, local +x
	openEnd = 5.5, -- the rails' open end, local -x
	sink = 0.4,
	yawJitter = 0.025, -- radians either way (about 1.4 degrees)
	liftJitter = 0.08, -- studs either way
}

export type FenceSection = { model: string, side: number, index: number, z: number, yaw: number, lift: number, cframe: CFrame }

function CreekPlan.heroStep(): number
	local F = CreekPlan.HERO_FENCE
	return (F.endAt - F.post - F.first) / (F.perSide - 1)
end

-- The eight sections round the gate at (gx, gz), alternating the two variants (south starts on
-- 1, north on 2). Seeded yaw and height jitter; the same seed gives the same fence.
function CreekPlan.heroFence(seed: number?, gx: number, gz: number, ground: number): { FenceSection }
	local F = CreekPlan.HERO_FENCE
	local r = Scatter.rng((seed or CreekPlan.SEED) + 31)
	local step = CreekPlan.heroStep()
	local out: { FenceSection } = {}
	for _, side in { 1, -1 } do -- south (+z), then north
		for i = 0, F.perSide - 1 do
			local d = F.first + i * step
			local z = gz + side * d
			local yaw = (if side == 1 then -math.pi / 2 else math.pi / 2) + Scatter.range(r, -F.yawJitter, F.yawJitter)
			local lift = Scatter.range(r, -F.liftJitter, F.liftJitter)
			local first = if side == 1 then 1 else 2
			local variant = if i % 2 == 0 then first else 3 - first
			table.insert(out, {
				model = "CreekFenceSection" .. variant,
				side = side,
				index = i,
				z = z,
				yaw = yaw,
				lift = lift,
				cframe = CFrame.new(gx, ground - F.sink + lift, z) * CFrame.Angles(0, yaw, 0),
			})
		end
	end
	return out
end

-- Whether Scenery's old fence part (a "Post", or a "Rail" by its middle) at `z` hides under the
-- hero fence round a gate at gz: posts up to and including the one the run ends on, rails short
-- of it.
function CreekPlan.heroHides(kind: string, z: number, gz: number): boolean
	local d = math.abs(z - gz)
	local E = CreekPlan.HERO_FENCE.endAt
	if kind == "Post" then
		return d <= E + 0.5
	end
	return d < E
end

-- The lantern post (CreekLanternPost): pivot at the foot, arm along local -Z, set at 1.15 so a
-- 5 stud avatar walks under the lantern, sunk 0.1 so its stones bite. The glass core (the
-- MeshPart that carries the light) is at CORE times the scale from the pivot.
CreekPlan.LANTERN_KIT = { scale = 1.15, sink = 0.1, core = Vector3.new(0, 5.59, -1.2) }

-- The turn about Y that points the arm (local -Z) along (ax, az).
function CreekPlan.lanternYaw(ax: number, az: number): number
	return math.atan2(-ax, -az)
end

function CreekPlan.lanternCFrame(foot: Vector3, ax: number, az: number): CFrame
	local L = CreekPlan.LANTERN_KIT
	return CFrame.new(foot - Vector3.new(0, L.sink, 0)) * CFrame.Angles(0, CreekPlan.lanternYaw(ax, az), 0)
end

function CreekPlan.lanternCore(cf: CFrame): Vector3
	local L = CreekPlan.LANTERN_KIT
	return (cf * CFrame.new(L.core * L.scale)).Position
end

-- The kit's triangles in the creek's views: the arch, the eight sections and the two lanterns.
function CreekPlan.kitTriangles(): number
	if not CreekPlan.CREEK_KIT_ON then
		return 0
	end
	local T = CreekPlan.KIT_TRIS
	local n = T.CreekGateArch + CreekPlan.KIT_LANTERNS * T.CreekLanternPost
	for _, s in CreekPlan.heroFence(CreekPlan.SEED, 0, 0, 1) do
		n += T[s.model]
	end
	return n
end

return CreekPlan
