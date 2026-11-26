-- UNVERIFIED in Studio: written 2026-11-26 in the cloud. Runs with TestRunner like the others.
return function(t, Shared)
	local BoatRules = require(Shared.BoatRules)
	local BoatData = require(Shared.BoatData)

	local DOCK = Vector3.new(0, 0, 40) -- open water off the end of the dock
	local CHANNEL = Vector3.new(0, 0, -110)
	local BASIN = Vector3.new(60, 0, -200)
	local ISLAND = Vector3.new(-90, 0, -240)
	local POINT = Vector3.new(-55, 0, -240)
	local BLUE = Vector3.new(0, 0, -350)
	local LAND = Vector3.new(0, 0, -120) + Vector3.new(60, 0, 0) -- north shore, beside the channel
	local CREEK = Vector3.new(-230, 0, 0)

	t.test("the lake, the channel and the Big Lake are boat water; land and the island aren't", function()
		for name, p in { dock = DOCK, channel = CHANNEL, basin = BASIN, point = POINT, blue = BLUE } do
			t.ok(BoatRules.isBoatWater(p), name)
		end
		for name, p in { shore = LAND, island = ISLAND, creek = CREEK, south = Vector3.new(0, 0, 100) } do
			t.ok(not BoatRules.isBoatWater(p), name)
		end
	end)

	t.test("only the Big Lake and the channel need a boat; only the far half is blue water", function()
		t.ok(not BoatRules.needsBoat(DOCK), "lake")
		t.ok(BoatRules.needsBoat(CHANNEL) and BoatRules.needsBoat(BASIN) and BoatRules.needsBoat(BLUE), "big lake")
		t.ok(not BoatRules.inBlueWater(BASIN) and not BoatRules.inBlueWater(POINT), "dinghy water")
		t.ok(BoatRules.inBlueWater(BLUE), "blue water")
		t.ok(BoatRules.inBlueWater(Vector3.new(0, 0, BoatRules.BUOY_Z - 1)), "just past the buoys")
		t.ok(not BoatRules.inBlueWater(Vector3.new(0, 0, BoatRules.BUOY_Z + 1)), "just short of them")
	end)

	t.test("Big Lake spots: island point, basin and drop-off", function()
		local FishLogic = require(Shared.FishLogic)
		t.eq(FishLogic.spotAt(POINT, BoatRules.ZONES), "IslandPoint")
		t.eq(FishLogic.spotAt(BASIN, BoatRules.ZONES), "Basin")
		t.eq(FishLogic.spotAt(BLUE, BoatRules.ZONES), "DropOff")
		t.eq(FishLogic.spotAt(DOCK, BoatRules.ZONES), "OpenWater", "the lake has no Big Lake spot")
		for name in BoatRules.BOAT_SPOTS do
			t.ok(BoatRules.SPOT_NAMES[name] ~= nil, name .. " named")
		end
	end)

	t.test("every boat fits its slip in the water beside the dock, without touching another", function()
		local zs = BoatRules.SLIP_ZS
		for i = 2, #zs do
			for _, b in BoatData.list do
				t.ok(zs[i] - zs[i - 1] >= b.width + 1, b.id .. " slips " .. (i - 1) .. " and " .. i)
			end
		end
		for i = 1, #zs do
			for _, b in BoatData.list do
				local cf = BoatRules.slipCFrame(i, b.id)
				local bow = cf.Position + cf.LookVector * (b.length / 2)
				local stern = cf.Position - cf.LookVector * (b.length / 2)
				t.ok(BoatRules.isBoatWater(bow) and BoatRules.isBoatWater(stern), b.id .. " in water at slip " .. i)
				t.ok(stern.X > 4 and bow.X > stern.X, b.id .. " clear of the deck, bow out at slip " .. i)
				t.ok(math.abs(cf.Position.Y - BoatRules.WATER_Y) < 1e-6, "at the water line")
			end
		end
	end)

	t.test("slips fill in order and run out", function()
		t.eq(BoatRules.nextFreeSlip({}), 1)
		t.eq(BoatRules.nextFreeSlip({ [1] = true, [3] = true }), 2)
		t.eq(BoatRules.nextFreeSlip({ [1] = true, [2] = true, [3] = true, [4] = true }), nil)
	end)

	t.test("the server keeps normal moves, puts back teleports and beached boats", function()
		local v, at = BoatRules.check("Dinghy", DOCK, DOCK + Vector3.new(5, 0, 0), 0.5)
		t.eq(v, "ok")
		t.eq(at, nil)
		v, at = BoatRules.check("Dinghy", DOCK, DOCK + Vector3.new(80, 0, 0), 0.5)
		t.eq(v, "back", "teleport")
		t.ok(at == DOCK, "back to the last good spot")
		v = BoatRules.check("Dinghy", Vector3.new(0, 0, 79), Vector3.new(0, 0, 82), 0.5)
		t.eq(v, "back", "drove onto the south shore")
		v = BoatRules.check("Dinghy", Vector3.new(-72, 0, -240), Vector3.new(-73, 0, -240), 0.5)
		t.eq(v, "back", "onto the island")
	end)

	t.test("the dinghy is turned back at the buoy line; the Deep-V goes on", function()
		local edge = Vector3.new(30, 0, BoatRules.BUOY_Z + 2)
		local over = Vector3.new(30, 0, BoatRules.BUOY_Z - 2)
		local v, at = BoatRules.check("Dinghy", edge, over, 0.5)
		t.eq(v, "turn")
		t.ok(at ~= nil and not BoatRules.inBlueWater(at :: Vector3) and BoatRules.isBoatWater(at :: Vector3), "pushed back into dinghy water")
		t.eq((BoatRules.check("DeepV", edge, over, 0.5)), "ok")
	end)

	t.test("casting on the water: slow boats only, the Big Lake needs a boat, blue water needs the Deep-V", function()
		t.ok((BoatRules.castCheck(DOCK, nil, 0)), "from the dock on foot")
		t.ok((BoatRules.castCheck(DOCK, "Dinghy", 0)), "from a stopped dinghy")
		local ok, msg = BoatRules.castCheck(DOCK, "Dinghy", BoatData.byId.Dinghy.maxSpeed)
		t.ok(not ok and msg ~= nil, "from a moving dinghy")
		ok, msg = BoatRules.castCheck(BASIN, nil, 0)
		t.ok(not ok and msg == "You need a boat to fish the Big Lake.", "swimmer in the Big Lake")
		t.ok((BoatRules.castCheck(BASIN, "Dinghy", 0)), "dinghy in the basin")
		ok = BoatRules.castCheck(BLUE, "Dinghy", 0)
		t.ok(not ok, "dinghy casting into blue water")
		t.ok((BoatRules.castCheck(BLUE, "DeepV", 0)), "Deep-V in blue water")
	end)

	t.test("mover math: full speed along the bow, right turns spin clockwise", function()
		local vx, vz = BoatRules.planeVelocity(Vector3.new(1, 0.2, 0), 12)
		t.ok(math.abs(vx - 12) < 1e-6 and math.abs(vz) < 1e-6, "east at 12")
		vx, vz = BoatRules.planeVelocity(Vector3.new(0, 0, -1), -5)
		t.ok(math.abs(vz - 5) < 1e-6, "reverse while facing north moves south")
		t.ok(BoatRules.spinY(90) < 0 and BoatRules.spinY(-90) > 0, "signs")
		t.ok(math.abs(BoatRules.spinY(180) + math.pi) < 1e-9, "degrees to radians")
	end)

	t.test("a Deep-V left with one aboard in blue water drifts back toward the buoys", function()
		local _, dz = BoatRules.drift("DeepV", BLUE, 1)
		t.ok(dz > 0, "drifts south")
		_, dz = BoatRules.drift("DeepV", BLUE, 2)
		t.eq(dz, 0, "full crew, no drift")
		_, dz = BoatRules.drift("DeepV", BASIN, 1)
		t.eq(dz, 0, "not in blue water")
	end)
end
