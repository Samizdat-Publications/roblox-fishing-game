--!strict
-- The lake's shore (L5d). The water boxes stay a 220 x 160 rectangle, but the shore inside it
-- isn't: the four corners are rounded and a few grassy points jut out into the lake (land you
-- can walk out on and fish from). Every rule that asks "is this water?" goes through
-- FishLogic.isOnWaterAny, which asks Shore.isLand first, so casts, the landing ring, rises
-- and fish shadows all see the same shore. WaterLook draws it in terrain from the same
-- numbers (Shore.depth), so what you see is what the rules use.
--
-- Pure data and math, no Roblox services: runs in the Lune tests.
local Shore = {}

-- The lake's water rectangle (WaterMap.WATER_SIZE centred on the origin).
Shore.LAKE = { x1 = -110, x2 = 110, z1 = -80, z2 = 80 }

-- Rounded corners: each corner of the rectangle becomes a quarter circle this big.
Shore.CORNER_R = 30

-- Points of land: a circle centred just past the bank line, so a rounded nose juts in.
-- Placed clear of the dock (x -15..15 on the south bank), the weed bed, the logs, the deep
-- hole and the boat channel cut through the north bank (x -15..15).
export type Point = { name: string, x: number, z: number, r: number }
Shore.POINTS = {
	{ name = "BirchPoint", x = -42, z = -85, r = 17 }, -- north bank, west of the channel
	{ name = "PinePoint", x = 58, z = -87, r = 21 }, -- north bank, east
	{ name = "EastPoint", x = 115, z = -22, r = 17 }, -- east bank
	{ name = "WestPoint", x = -115, z = -42, r = 15 }, -- west bank
	{ name = "PondPoint", x = 40, z = 86, r = 14 }, -- south bank, east of the dock
} :: { Point }

-- Signed distance to land at (x, z), in studs: positive inside land (how far in), negative
-- over water (how far from the shore). Only meaningful inside the lake rectangle; outside it
-- returns -math.huge (the shore isn't this module's business there: the creek has its own
-- boxes, and the ground ring is outside every water box anyway).
function Shore.depth(x: number, z: number): number
	local L = Shore.LAKE
	if x < L.x1 or x > L.x2 or z < L.z1 or z > L.z2 then
		return -math.huge
	end
	-- The rectangle's own bank: water gets deeper away from the nearest edge.
	local d = -math.min(x - L.x1, L.x2 - x, z - L.z1, L.z2 - z)
	-- Rounded corners: inside each corner square, land is everything outside the circle.
	local r = Shore.CORNER_R
	for _, c in { { L.x1, L.z1, 1, 1 }, { L.x2, L.z1, -1, 1 }, { L.x1, L.z2, 1, -1 }, { L.x2, L.z2, -1, -1 } } do
		local cx, cz, sx, sz = c[1], c[2], c[3], c[4]
		local u, v = (x - cx) * sx, (z - cz) * sz -- 0..r inside the corner square
		if u >= 0 and u <= r and v >= 0 and v <= r then
			local du, dv = r - u, r - v -- from the circle's centre
			d = math.max(d, math.sqrt(du * du + dv * dv) - r)
		end
	end
	-- Points of land.
	for _, p in Shore.POINTS do
		local dx, dz = x - p.x, z - p.z
		d = math.max(d, p.r - math.sqrt(dx * dx + dz * dz))
	end
	return d
end

-- True when this point inside the lake is land (a rounded corner or a point).
function Shore.isLand(pos: Vector3): boolean
	return Shore.depth(pos.X, pos.Z) > 0
end

return Shore
