-- The new cast (L2): the ring's travel, lure weight, the landing point and near-miss help.
-- Written 2026-11-26; UNVERIFIED in Studio until the L2 playtest. Runs with TestRunner like the others.
return function(t, Shared)
	local CastLogic = require(Shared.CastLogic)
	local Config = require(Shared.Config)
	local BaitData = require(Shared.BaitData)
	local RodData = require(Shared.RodData)
	local FishLogic = require(Shared.FishLogic)
	local WaterMap = require(Shared.WaterMap)

	local function near(a: number, b: number, eps: number?): boolean
		return math.abs(a - b) <= (eps or 1e-6)
	end

	local RODS = { "Willow", "Fiberglass", "Graphite" }

	t.test("bait cast multipliers: spinner 1.25, plastic worm 1.1, minnow 1.05, the rest 1", function()
		t.eq(BaitData.byId.Spinner.castMult, 1.25, "spinner")
		t.eq(BaitData.byId.PlasticWorm.castMult, 1.1, "plastic worm")
		t.eq(BaitData.byId.Minnow.castMult, 1.05, "minnow")
		for _, id in { "Worm", "Cricket", "Stinkbait" } do
			t.eq(BaitData.byId[id].castMult or 1, 1, id)
		end
	end)

	t.test("the ring goes out and back: 0 at 0 s, 1 at range/16 s, 0 again at twice that", function()
		for _, rod in RODS do
			for _, bait in { "Worm", "Spinner" } do
				local range = CastLogic.range(rod, bait)
				local half = range / CastLogic.RING_SPEED
				local label = rod .. "/" .. bait
				t.ok(near(CastLogic.powerAt(0, rod, bait), 0), label .. " start")
				t.ok(near(CastLogic.powerAt(half / 2, rod, bait), 0.5), label .. " rising")
				t.ok(near(CastLogic.powerAt(half, rod, bait), 1), label .. " full")
				t.ok(near(CastLogic.powerAt(half * 1.5, rod, bait), 0.5), label .. " falling")
				t.ok(near(CastLogic.powerAt(2 * half, rod, bait), 0), label .. " back")
				t.ok(near(CastLogic.powerAt(2 * half + half / 4, rod, bait), 0.25), label .. " second sweep")
				-- The ring moves a steady 16 studs a second.
				local d1 = CastLogic.distance(CastLogic.powerAt(0.2, rod, bait), rod, bait)
				local d2 = CastLogic.distance(CastLogic.powerAt(0.7, rod, bait), rod, bait)
				t.ok(near(d2 - d1, 8, 1e-4), label .. " speed")
			end
		end
	end)

	t.test("a soft cast is 8 studs with every rod and bait", function()
		for _, rod in RODS do
			for _, b in BaitData.list do
				t.eq(CastLogic.distance(0, rod, b.id), Config.CAST_MIN, rod .. "/" .. b.id)
				t.eq(CastLogic.distance(-1, rod, b.id), Config.CAST_MIN, rod .. "/" .. b.id .. " clamped")
			end
		end
		t.eq(Config.CAST_MIN, 8, "CAST_MIN")
	end)

	t.test("a spinner at full power outcasts a worm by exactly 1.25 on the reach part, with each rod", function()
		for _, rod in RODS do
			local worm = CastLogic.distance(1, rod, "Worm") - Config.CAST_MIN
			local spinner = CastLogic.distance(1, rod, "Spinner") - Config.CAST_MIN
			t.ok(near(worm, Config.CAST_RANGE + RodData.byId[rod].castBonus), rod .. " worm reach")
			t.ok(near(spinner, worm * 1.25), rod .. " spinner reach")
			t.ok(near(CastLogic.distance(2, rod, "Spinner"), CastLogic.distance(1, rod, "Spinner")), rod .. " clamped")
		end
		-- Unknown rod or bait falls back to the Willow and a multiplier of 1.
		t.eq(CastLogic.range(nil, nil), Config.CAST_RANGE, "fallbacks")
	end)

	t.test("the landing is flat at y 0.3 along the direction, nil for no direction", function()
		local origin = Vector3.new(10, 3, 20)
		local p = CastLogic.landing(origin, Vector3.new(0, -0.5, -2), 0, "Willow", "Worm")
		t.ok(p ~= nil, "landed")
		local q = p :: Vector3
		t.ok(near(q.Y, 0.3), "y")
		t.ok(near(q.X, 10) and near(q.Z, 12), "8 studs straight ahead along -z")
		local full = CastLogic.landing(origin, Vector3.new(1, 5, 1), 1, "Graphite", "Spinner") :: Vector3
		local want = CastLogic.distance(1, "Graphite", "Spinner")
		t.ok(near(CastLogic.flatDistance(full, origin), want, 1e-4), "full distance")
		t.ok(near(full.X - origin.X, full.Z - origin.Z, 1e-4), "along the diagonal")
		t.eq(CastLogic.landing(origin, Vector3.new(0, -1, 0), 1, "Willow", "Worm"), nil, "straight down")
	end)

	t.test("near-miss help slides a 2 stud miss onto the water and gives up on a 5 stud miss", function()
		-- Fake water: everything with z < 0 is water, the bank starts at z = 0.
		local function isOnWater(pos: Vector3, _waters: any): boolean
			return pos.Z < 0
		end
		local origin = Vector3.new(0, 3, -20) -- out on a dock, casting back toward the bank
		local miss2 = Vector3.new(0, 0.3, 2)
		local fixed = CastLogic.assist(miss2, origin, nil, isOnWater)
		t.ok(fixed ~= nil, "2 stud miss fixed")
		local f = fixed :: Vector3
		t.ok(f.Z < 0 and f.Z >= -0.5, "slid just onto the water")
		t.ok(near(f.X, 0) and near(f.Y, 0.3), "along the cast line, on the surface")
		t.eq(CastLogic.assist(Vector3.new(0, 0.3, 5), origin, nil, isOnWater), nil, "5 stud miss")
		local wet = Vector3.new(0, 0.3, -4)
		t.eq(CastLogic.assist(wet, origin, nil, isOnWater), wet, "already on water")
	end)

	t.test("the riffle is reachable with every rod and bait, and the creek bank shows as dry", function()
		local waters = WaterMap.castWaters()
		local zones = WaterMap.castZones()
		-- Standing on the east bank of the riffle (x -224..-236), facing west.
		local origin = Vector3.new(-220, 3, 50)
		for _, rod in RODS do
			for _, b in BaitData.list do
				local p = CastLogic.landing(origin, Vector3.new(-1, 0, 0), 0, rod, b.id) :: Vector3
				local landed = CastLogic.assist(p, origin, waters, FishLogic.isOnWaterAny)
				t.ok(landed ~= nil, rod .. "/" .. b.id .. " soft cast lands")
				t.eq(FishLogic.spotAt(landed :: Vector3, zones), "Riffle", rod .. "/" .. b.id .. " spot")
			end
		end
	end)

	t.test("the client and server see the same map", function()
		t.eq(#WaterMap.castWaters(), #WaterMap.waters() + (if Config.BIG_LAKE_ON then 2 else 0), "waters") -- the channel and the Big Lake
		t.ok(FishLogic.isOnWaterAny(Vector3.new(0, 0.3, 0), WaterMap.waters()), "lake middle")
		t.ok(not FishLogic.isOnWaterAny(Vector3.new(0, 0.3, 100), WaterMap.waters()), "south shore")
		t.eq(FishLogic.spotAt(Vector3.new(0, 0.3, 57), WaterMap.zones()), "Dock", "dock")
		t.eq(CastLogic.ACCEPT, 2, "accept radius")
	end)
end
