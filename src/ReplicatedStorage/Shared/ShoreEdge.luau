--!strict
-- The home lake's drawn waterline (leg 3, N1): where the grass lawns become terrain, the bank
-- that terrain draws must not run ruler-straight (the plan's wrong-list: no straight shore over
-- 30 studs). Shore's rule outline keeps its straight banks (casts, zones and fish read it); this
-- only nudges the DRAWN bank a few studs in and out of it with a slow, seeded wave.
--
-- Which way it may move is set by what stands near the water:
--  * out (water past the rule box): at most to OUT_MAX, so the shore path (its inner edge 2 studs
--    past the box) never stands in water;
--  * in (sand and grass over rule water): at most IN_MAX, a lip a cast hardly ever reaches.
-- Rounded corners and points of land are curves already and are left exactly as Shore draws
-- them, and so are the boat channel's mouth and the boat slips (a boat sits 2 studs off the bank).
--
-- Pure math over Shore's numbers, no Roblox services: the Lune specs sample it.
local Shore = require(script.Parent.Shore)

local ShoreEdge = {}

-- Ground height along the bank (WaterLook.shoreHeight): the top of the sand sits SHORE_DEPTH
-- under the water at the rule edge and rises SLOPE studs per stud into the land.
ShoreEdge.SHORE_DEPTH = 0.7
ShoreEdge.SLOPE = 0.6
-- The drawn waterline sits this far into the land from where the bump is zero.
ShoreEdge.WATERLINE_D = ShoreEdge.SHORE_DEPTH / ShoreEdge.SLOPE

ShoreEdge.OUT_MAX = 1.8 -- studs the drawn waterline may sit outside the rule box
ShoreEdge.IN_MAX = 2.2 -- studs it may sit inside it
-- Bump range: added to the signed depth to land, so +bump moves the waterline toward the water.
ShoreEdge.BUMP_LO = ShoreEdge.WATERLINE_D - ShoreEdge.OUT_MAX
ShoreEdge.BUMP_HI = ShoreEdge.WATERLINE_D + ShoreEdge.IN_MAX

-- Where the bank keeps Shore's own line (rectangles x1, x2, z1, z2; FADE studs to blend in).
ShoreEdge.FADE = 6
ShoreEdge.QUIET = {
	{ name = "ChannelMouth", x1 = -17, x2 = 17, z1 = -100, z2 = -60 }, -- BoatRules.CHANNEL meets the north bank
	{ name = "Slips", x1 = 6, x2 = 22, z1 = 60, z2 = 100 }, -- BoatRules slips east of the dock (x 5 to 23)
}

-- Three slow sine waves, mixed so every bank (along x or along z) has one with a wavelength near
-- 25 studs (tuned so every 30 stud stretch of plain bank bows 1.5 studs or more). Returns -1..1.
local function wave(x: number, z: number): number
	return (0.6 * math.sin(0.25 * x + 0.24 * z + 1.3) + 0.35 * math.sin(0.18 * x - 0.23 * z + 4.1) + 0.15 * math.sin(0.05 * x + 0.06 * z + 0.4)) / 1.1
end

-- 0 inside a quiet rectangle, 1 past FADE studs from all of them.
function ShoreEdge.quiet(x: number, z: number): number
	local k = 1
	for _, q in ShoreEdge.QUIET do
		local dx = math.max(q.x1 - x, 0, x - q.x2)
		local dz = math.max(q.z1 - z, 0, z - q.z2)
		k = math.min(k, math.clamp(math.sqrt(dx * dx + dz * dz) / ShoreEdge.FADE, 0, 1))
	end
	return k
end

-- The bump at (x, z) before the corner, point and quiet fades: BUMP_LO..BUMP_HI.
function ShoreEdge.rawBump(x: number, z: number): number
	local n = (wave(x, z) + 1) / 2
	return ShoreEdge.BUMP_LO + n * (ShoreEdge.BUMP_HI - ShoreEdge.BUMP_LO)
end

-- Signed distance to the area's straight banks alone (no corners or points): positive past the
-- edge, negative over the water. Open stretches count as far from any bank.
local function bankDepth(a: Shore.Area, x: number, z: number): number
	local nearest = math.huge
	local function open(edge: string, along: number): boolean
		for _, o in a.open do
			if o.edge == edge and along >= o.from and along <= o.to then
				return true
			end
		end
		return false
	end
	if not open("x1", z) then
		nearest = math.min(nearest, x - a.x1)
	end
	if not open("x2", z) then
		nearest = math.min(nearest, a.x2 - x)
	end
	if not open("z1", x) then
		nearest = math.min(nearest, z - a.z1)
	end
	if not open("z2", x) then
		nearest = math.min(nearest, a.z2 - z)
	end
	return -nearest
end

-- How much of the bump applies here, 0..1: none where a corner or point shapes the shore (it is
-- a curve already), none in the quiet places, none out past the shallows, where the bed starts.
function ShoreEdge.weight(a: Shore.Area, x: number, z: number): number
	local d = Shore.depthIn(a, x, z)
	local curved = d - bankDepth(a, x, z) -- > 0 where a corner or point lifts the land
	local f = math.clamp(1 - curved / 3, 0, 1)
	local s = a.shallows
	local ramp = math.clamp((d + s) / (s / 2), 0, 1)
	return f * ramp * ShoreEdge.quiet(x, z)
end

-- The drawn depth to land at (x, z): Shore's, plus the weighted bump.
function ShoreEdge.depth(a: Shore.Area, x: number, z: number, on: boolean?): number
	local d = Shore.depthIn(a, x, z)
	if on == false then
		return d
	end
	return d + ShoreEdge.rawBump(x, z) * ShoreEdge.weight(a, x, z)
end

-- Where the drawn waterline crosses a line across one bank: `side` is "x1", "x2", "z1" or "z2",
-- `along` the position along that edge. Returns the offset from the rule edge, positive into the
-- land (outside the box), found by stepping across in `step` stud steps.
function ShoreEdge.waterline(a: Shore.Area, side: string, along: number, step: number?): number
	local st = step or 0.05
	local function at(o: number): (number, number)
		if side == "x1" then
			return a.x1 - o, along
		elseif side == "x2" then
			return a.x2 + o, along
		elseif side == "z1" then
			return along, a.z1 - o
		end
		return along, a.z2 + o
	end
	local o = -ShoreEdge.IN_MAX - 3
	while o < ShoreEdge.OUT_MAX + 3 do
		local x, z = at(o)
		if ShoreEdge.depth(a, x, z) >= ShoreEdge.WATERLINE_D then
			return o
		end
		o += st
	end
	return o
end

return ShoreEdge
