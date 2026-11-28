-- The fleet (leg 3, N4, Config.CANOE_ON): the Cedar Canoe, the dinghy's second seat, where each
-- boat may go and land. Written 11/27/2026; UNVERIFIED in Studio until the N4 playtest.
return function(t, Shared)
	local Config = require(Shared.Config)
	local BoatData = require(Shared.BoatData)
	local BoatLogic = require(Shared.BoatLogic)
	local BoatRules = require(Shared.BoatRules)

	local function with(on: boolean, body: () -> ())
		local was = Config.CANOE_ON
		Config.CANOE_ON = on
		local ok, err = pcall(body)
		Config.CANOE_ON = was
		if not ok then
			error(err, 0)
		end
	end

	local canoe = BoatData.byId.Canoe

	t.test("the fleet lands switched off", function()
		t.eq(Config.CANOE_ON, false, "canoe")
		t.eq(Config.NET_ON, false, "net")
		t.eq(Config.ASSIST_BONUS_ON, false, "assist bonus")
		t.eq(Config.QUIET_APPROACH_ON, false, "quiet approach")
		t.eq(Config.BUDDY_LOAN_ON, false, "buddy loan")
		t.eq(Config.DOUBLE_HOOKUP_ON, false, "double hookup")
		t.eq(Config.CHUM_ON, false, "chum")
	end)

	t.test("the Cedar Canoe matches the fleet table", function()
		t.ok(canoe ~= nil, "exists")
		t.eq(canoe.price, 350, "price")
		t.eq(canoe.seats, 2, "seats")
		t.eq(canoe.maxSpeed, 7, "alone")
		t.eq(canoe.pairSpeed, 11, "two paddling")
		t.eq(canoe.paddle, true, "paddled")
		t.eq(canoe.quiet, true, "quiet")
		t.eq(canoe.home, "dock", "lives at the dock slips")
		t.eq(canoe.lands, "shore", "lands at any shore")
		t.eq(canoe.length, 12, "placeholder length")
		t.eq(canoe.width, 3, "placeholder width")
		for _, w in { "Lake", "Channel", "Basin", "LilyCove" } do
			t.ok(canoe.waters[w] == true, "canoe on " .. w)
		end
		t.ok(not canoe.waters.BlueWater and not canoe.blueWater, "no blue water")
		t.eq(BoatData.byId.Dinghy.seats, 2, "the dinghy has 2 seats")
		local d = BoatData.byId.Dinghy
		t.ok(d.waters.Lake and d.waters.Channel and d.waters.Basin and not d.waters.LilyCove, "dinghy waters")
		local v = BoatData.byId.DeepV
		t.ok(v.waters.Basin and v.waters.BlueWater and not v.waters.Lake and not v.waters.Channel, "Deep-V: Big Lake only")
		t.eq(v.lands, "pier", "Deep-V lands at piers only")
		t.eq(v.home, "marina", "Deep-V lives at the marina")
	end)

	t.test("every boat has the new fields, and the first seat steers", function()
		for _, b in BoatData.list do
			t.ok(type(b.quiet) == "boolean" and type(b.paddle) == "boolean", b.id .. " quiet and paddle")
			t.ok(type(b.draft) == "number" and b.draft > 0, b.id .. " draft")
			t.ok(b.home == "dock" or b.home == "marina", b.id .. " home")
			t.ok(b.lands == "shore" or b.lands == "pier", b.id .. " lands")
			t.eq(#b.stations, b.seats, b.id .. " a station per seat")
			t.eq(b.stations[1], "Helm", b.id .. " first seat steers")
			t.ok(b.pairSpeed >= b.maxSpeed, b.id .. " pair speed")
		end
	end)

	t.test("the canoe and the dinghy's second seat wait for the switch", function()
		with(false, function()
			t.eq(BoatData.available(canoe), false, "canoe hidden")
			t.eq(BoatData.onSale(canoe), false, "canoe not sold")
			for _, b in BoatData.shown() do
				t.ok(b.id ~= "Canoe", "not in the shop")
			end
			t.eq(BoatData.seatsOf(BoatData.byId.Dinghy), 1, "dinghy: one seat as in L7")
			t.eq(BoatData.secondSeat(BoatData.byId.Dinghy), nil, "no passenger seat")
			t.eq(BoatData.secondSeat(BoatData.byId.DeepV), "Navigator", "the Deep-V keeps its navigator")
		end)
		with(true, function()
			t.eq(BoatData.onSale(canoe), true, "canoe on sale")
			t.eq(BoatData.shown()[1].id, "Canoe", "first in the shop, the cheapest")
			t.eq(BoatData.seatsOf(BoatData.byId.Dinghy), 2, "dinghy: two seats")
			t.eq(BoatData.secondSeat(BoatData.byId.Dinghy), "Passenger", "passenger seat")
			t.eq(BoatData.secondSeat(canoe), "Bow", "bow seat")
		end)
	end)

	t.test("buying the canoe: 350 coins, only with the switch on, and a second buy is refused", function()
		with(false, function()
			local d = { coins = 1000, boats = {} }
			t.ok(not (BoatLogic.buy(d, "Canoe")), "refused while switched off")
			t.eq(d.coins, 1000, "nothing taken")
		end)
		with(true, function()
			local d = { coins = 400, boats = {} }
			local ok, msg = BoatLogic.buy(d, "Canoe")
			t.ok(ok, msg)
			t.eq(d.coins, 50, "350 paid")
			t.ok(BoatLogic.owns(d, "Canoe"), "owned")
			local ok2, msg2 = BoatLogic.buy(d, "Canoe")
			t.ok(not ok2 and string.find(msg2, "already own", 1, true) ~= nil, "second buy refused: " .. msg2)
			t.eq(d.coins, 50, "not charged twice")
			local poor = { coins = 349, boats = {} }
			t.ok(not (BoatLogic.buy(poor, "Canoe")), "one coin short")
		end)
	end)

	t.test("the canoe does 7 studs a second alone and 11 with a second paddler", function()
		local function top(paddlers)
			local m = { speed = 0, yawRate = 0 }
			for _ = 1, 900 do
				m = BoatLogic.step(m, "Canoe", 1, 0, 1 / 60, paddlers)
			end
			return m.speed
		end
		t.ok(math.abs(top(1) - 7) < 0.1, "alone " .. top(1))
		t.ok(math.abs(top(2) - 11) < 0.1, "two " .. top(2))
		t.ok(math.abs(top(nil) - 7) < 0.1, "left out means alone")
		t.eq(BoatLogic.topSpeed("Dinghy", 2), 12, "a passenger doesn't speed up a motor boat")
		t.eq(BoatLogic.paddlers("Canoe", 2), 2, "both canoeists paddle")
		t.eq(BoatLogic.paddlers("Dinghy", 2), 0, "nobody paddles a dinghy")
		t.ok(BoatLogic.moveOk(Vector3.zero, Vector3.new(11 * 0.5, 0, 0), 0.5, "Canoe"), "the server allows two paddlers' speed")
		t.ok(not BoatLogic.moveOk(Vector3.zero, Vector3.new(40, 0, 0), 0.5, "Canoe"), "but not a teleport")
	end)

	t.test("casting from the canoe, from either seat, only when slow", function()
		t.ok((BoatRules.castCheck(Vector3.new(0, 0, -200), "Canoe", 0)), "stopped in the basin")
		t.ok(not (BoatRules.castCheck(Vector3.new(0, 0, -200), "Canoe", 6)), "paddling")
	end)

	t.test("waters: each boat keeps to its own once the fleet is on", function()
		local lake, channel, basin = Vector3.new(0, 0, 0), Vector3.new(0, 0, -110), Vector3.new(0, 0, -200)
		t.eq(BoatRules.waterAt(lake), "Lake")
		t.eq(BoatRules.waterAt(channel), "Channel")
		t.eq(BoatRules.waterAt(basin), "Basin")
		t.eq(BoatRules.waterAt(Vector3.new(0, 0, -350)), "BlueWater")
		t.eq(BoatRules.waterAt(Vector3.new(0, 0, 100)), nil, "the south shore is land")
		with(true, function()
			for _, p in { lake, channel, basin } do
				t.ok((BoatRules.mayBeAt("Canoe", p)), "canoe")
				t.ok((BoatRules.mayBeAt("Dinghy", p)), "dinghy")
			end
			t.ok(not (BoatRules.mayBeAt("DeepV", lake)), "Deep-V kept off the home lake")
			t.ok(not (BoatRules.mayBeAt("DeepV", channel)), "and the channel")
			t.ok((BoatRules.mayBeAt("DeepV", basin)), "Deep-V in the basin")
			local v, at, msg = BoatRules.check("DeepV", basin, basin + Vector3.new(0, 0, 3), 0.5)
			t.eq(v, "ok", "a Deep-V moving in the basin")
			t.eq(at, nil)
			t.eq(msg, nil)
		end)
		with(false, function()
			t.ok((BoatRules.mayBeAt("DeepV", lake)), "switched off: anywhere on the water, as in L7")
		end)
	end)

	t.test("Lily Cove refuses a motor with its own words, and lets a paddle in", function()
		local cove = { name = "TestCove", cframe = CFrame.new(-180, 0, -190), size = Vector3.new(20, 10, 20) }
		table.insert(BoatRules.PADDLE_ONLY, cove)
		local ok, err = pcall(function()
			local inside = Vector3.new(-180, 0, -190)
			t.eq(BoatRules.waterAt(inside), "LilyCove", "a paddle-only cove")
			with(true, function()
				t.ok((BoatRules.mayBeAt("Canoe", inside)), "the canoe paddles in")
				local okD, msgD = BoatRules.mayBeAt("Dinghy", inside)
				t.ok(not okD, "the dinghy is refused")
				t.eq(msgD, "Too shallow and weedy for a motor. Paddle in.", "the refusal")
				local last = Vector3.new(-180, 0, -203)
				local v, at, msg = BoatRules.check("Dinghy", last, Vector3.new(-180, 0, -199), 0.5)
				t.eq(v, "back", "pushed back out")
				t.ok(at ~= nil and (at :: Vector3).Z == last.Z, "to its last good spot")
				t.eq(msg, BoatRules.LILY_TEXT, "with the words")
			end)
		end)
		table.remove(BoatRules.PADDLE_ONLY, table.find(BoatRules.PADDLE_ONLY, cove))
		if not ok then
			error(err, 0)
		end
	end)

	t.test("landing: canoe and dinghy beach on any shore, slow; the Deep-V never", function()
		local nearBank = Vector3.new(100, 0, 40) -- 10 studs off the lake's east bank (x 110)
		local east = Vector3.new(1, 0, 0)
		with(true, function()
			local at = BoatRules.beachAt("Canoe", nearBank, east, 1)
			t.ok(at ~= nil, "the canoe can land")
			t.ok(at ~= nil and not BoatRules.isBoatWater(at :: Vector3), "riders step onto dry land")
			t.ok(BoatRules.beachAt("Dinghy", Vector3.new(102, 0, 40), east, 2) ~= nil, "the dinghy too")
			t.eq(BoatRules.beachAt("Canoe", nearBank, east, 6), nil, "too fast")
			t.eq(BoatRules.beachAt("Canoe", Vector3.new(0, 0, 0), east, 0), nil, "no shore in reach mid-lake")
			t.eq(BoatRules.beachAt("Canoe", nearBank, Vector3.new(-1, 0, 0), 0), nil, "the bow must point at the shore")
			t.eq(BoatRules.beachAt("DeepV", Vector3.new(100, 0, -200), east, 0), nil, "the Deep-V lands at piers only")
			-- The island in the Big Lake, from its east side.
			t.ok(BoatRules.beachAt("Canoe", Vector3.new(-58, 0, -239), Vector3.new(-1, 0, 0), 0) ~= nil, "beach on the island")
		end)
		with(false, function()
			t.eq(BoatRules.beachAt("Canoe", nearBank, east, 1), nil, "switched off: no landing")
		end)
	end)
end
