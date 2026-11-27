--!strict
-- Where the water is and what each fishing spot is called, as plain boxes. Shared so the
-- server (which decides where a cast lands) and the client (which draws the landing ring)
-- use exactly the same map. WorldBuilder builds the geometry from these same numbers.
-- Pure data, no Roblox services, so it runs in tests outside Studio.
local Shared = script.Parent
local Config = require(Shared.Config)
local BoatRules = require(Shared.BoatRules)

local WaterMap = {}

export type Box = { cframe: CFrame, size: Vector3 }
export type Zone = { name: string, cframe: CFrame, size: Vector3 }

-- Lake 220 x 160 centered on the origin, water surface at y = 0.
WaterMap.WATER_SIZE = Vector3.new(220, 1, 160)
WaterMap.WATER_CF = CFrame.new(0, -0.5, 0)

-- Zone boxes (first match wins, so the dock is listed first).
WaterMap.ZONES = {
	{ name = "Dock", center = Vector3.new(0, 0, 57), size = Vector3.new(30, 10, 46) },
	{ name = "WeedBed", center = Vector3.new(-78, 0, 38), size = Vector3.new(56, 10, 64) },
	{ name = "Logs", center = Vector3.new(78, 0, 42), size = Vector3.new(56, 10, 60) },
	{ name = "DeepHole", center = Vector3.new(0, 0, -22), size = Vector3.new(60, 10, 56) },
}

-- Cedar Creek, west of the lake behind a gated fence: three stretches of water, each its own spot.
-- Rectangles in studs (x1, x2, z1, z2) with the bed height under the water.
WaterMap.CREEK = {
	{ name = "Riffle", x1 = -236, x2 = -224, z1 = 30, z2 = 75, bed = -1.5 },
	{ name = "Rocks", x1 = -240, x2 = -220, z1 = -10, z2 = 30, bed = -4 },
	{ name = "Pool", x1 = -252, x2 = -208, z1 = -70, z2 = -10, bed = -9 },
}
for _, c in WaterMap.CREEK do
	table.insert(WaterMap.ZONES, {
		name = c.name,
		center = Vector3.new((c.x1 + c.x2) / 2, 0, (c.z1 + c.z2) / 2),
		size = Vector3.new(c.x2 - c.x1, 10, c.z2 - c.z1),
	})
end

function WaterMap.zones(): { Zone }
	local out = {}
	for _, z in WaterMap.ZONES do
		table.insert(out, { name = z.name, cframe = CFrame.new(z.center), size = z.size })
	end
	return out
end

-- Every water box a cast may land in: the lake and the creek's three stretches.
function WaterMap.waters(): { Box }
	local out = { { cframe = WaterMap.WATER_CF, size = WaterMap.WATER_SIZE } }
	for _, c in WaterMap.CREEK do
		table.insert(out, {
			cframe = CFrame.new((c.x1 + c.x2) / 2, -0.5, (c.z1 + c.z2) / 2),
			size = Vector3.new(c.x2 - c.x1, 1, c.z2 - c.z1),
		})
	end
	return out
end

-- The zones a cast is named by, with the Big Lake's spots added when it is switched on.
function WaterMap.castZones(): { Zone }
	local out = WaterMap.zones()
	if Config.BIG_LAKE_ON then
		for _, z in BoatRules.ZONES do
			table.insert(out, z)
		end
	end
	return out
end

-- The water a cast may land in, with the channel and the Big Lake added when it is on.
function WaterMap.castWaters(): { Box }
	local out = WaterMap.waters()
	if Config.BIG_LAKE_ON then
		for _, b in BoatRules.extraCastWaters() do
			table.insert(out, b)
		end
	end
	return out
end

return WaterMap
