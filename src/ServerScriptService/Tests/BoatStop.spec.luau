-- The N4 playtest fixes (11/28/2026): boats stop short of shores, logs and the dock (the server
-- looks ahead), and the helm's controls go out the frame they change. Written in a worktree;
-- the pure parts only. The hull staying level is a Studio check.
return function(t, Shared)
	local BoatRules = require(Shared.BoatRules)
	local BoatData = require(Shared.BoatData)
	local BoatInput = require(Shared.BoatInput)
	local Config = require(Shared.Config)

	local EAST = Vector3.new(1, 0, 0)
	local NORTH = Vector3.new(0, 0, -1)

	local function withCanoe(on: boolean, body: () -> ())
		local was = Config.CANOE_ON
		Config.CANOE_ON = on
		local ok, err = pcall(body)
		Config.CANOE_ON = was
		if not ok then
			error(err, 0)
		end
	end

	t.test("a still boat looks nowhere; a moving one looks past its leading end", function()
		t.eq(#BoatRules.probes("Dinghy", Vector3.new(0, 0, 0), EAST, 0), 0, "still")
		local fwd = BoatRules.probes("Dinghy", Vector3.new(0, 0, 0), EAST, 12)
		t.eq(#fwd, 3, "tip and two corners")
		local half = BoatData.byId.Dinghy.length / 2
		t.ok(fwd[1].X > half + BoatRules.STOP_CLEAR, "the tip is past the bow and the clearance")
		t.ok(fwd[1].X >= half + BoatRules.STOP_CLEAR + 12 * BoatRules.STOP_LOOK - 1e-6, "faster looks further")
		local back = BoatRules.probes("Dinghy", Vector3.new(0, 0, 0), EAST, -3)
		t.ok(back[1].X < -half, "reverse looks past the stern")
		for _, p in fwd do
			t.eq(p.Y, BoatRules.WATER_Y, "probes sit on the water")
		end
	end)

	t.test("open water is clear; land, logs and the dock are not", function()
		t.eq(BoatRules.blockedAt("Dinghy", Vector3.new(0, 0, 10)), nil, "open lake")
		t.eq(BoatRules.blockedAt("Dinghy", Vector3.new(0, 0, -110)), nil, "the channel")
		t.eq(BoatRules.blockedAt("Dinghy", Vector3.new(112, 0, 0)), "shore", "past the east bank")
		t.eq(BoatRules.blockedAt("Dinghy", Vector3.new(60, 0, -120)), "shore", "the north shore")
		t.eq(BoatRules.blockedAt("Dinghy", Vector3.new(70, 0, 55)), "log", "on a log")
		t.eq(BoatRules.blockedAt("Dinghy", Vector3.new(0, 0, 60)), "dock", "under the dock")
	end)

	t.test("full speed at the east bank stops with water to spare, then creeps close enough to land", function()
		withCanoe(true, function()
			local b = BoatData.byId.Canoe
			-- Drive east along z = 0 at the canoe's best speed; stop the frame the look says so.
			local x, speed, dt = 60, b.pairSpeed, 1 / 60
			local stoppedAt: number? = nil
			for _ = 1, 600 do
				local kind = BoatRules.stopAhead("Canoe", Vector3.new(x, 0, 0), EAST, speed)
				if kind then
					t.eq(kind, "shore", "the bank")
					stoppedAt = x
					break
				end
				x += speed * dt
			end
			t.ok(stoppedAt ~= nil, "it stopped")
			local bow = (stoppedAt :: number) + b.length / 2
			t.ok(bow < 110 - BoatRules.STOP_CLEAR + 1e-6, "the bow stopped short of the bank")
			-- Creep in at walking pace until the look stops it again: now Land here works.
			speed = 1
			while not BoatRules.stopAhead("Canoe", Vector3.new(x, 0, 0), EAST, speed) do
				x += speed * dt
			end
			t.ok(x + b.length / 2 < 110, "still afloat")
			t.ok(BoatRules.beachAt("Canoe", Vector3.new(x, 0, 0), EAST, 0) ~= nil, "close enough to land")
			-- Reversing away is never blocked by the bank ahead.
			t.eq(BoatRules.stopAhead("Canoe", Vector3.new(x, 0, 0), EAST, -2), nil, "backs off")
		end)
	end)

	-- Measured in Studio (11/28/2026): the terrain bank reaches the water line well before the
	-- map's water boxes end, so the ray down stopped the hull with no map shore within 5 studs of
	-- the bow and "Land here" never showed. The server's ground probe (isDry) now counts too.
	t.test("stopped by the terrain bank, a lander is offered Land here on the first dry ground", function()
		withCanoe(true, function()
			local SOUTH = Vector3.new(0, 0, 1)
			local eastBank = function(p: Vector3): boolean
				return p.X >= 106
			end
			local southBank = function(p: Vector3): boolean
				return p.Z >= 76.5
			end
			for _, id in { "Canoe", "Dinghy" } do
				local hull = Vector3.new(96.3, 0, 0)
				t.eq(BoatRules.beachAt(id, hull, EAST, 0), nil, id .. ": the map alone finds no shore (the bug)")
				local at = BoatRules.beachAt(id, hull, EAST, 0, eastBank)
				t.ok(at ~= nil, id .. ": east bank, Land here")
				local x = (at :: Vector3).X
				t.ok(x >= 106 and x <= 106 + BoatRules.BEACH_STEP + BoatRules.BEACH_UP + 1e-6, id .. string.format(": steps off on the bank (x %.1f)", x))
				local south = BoatRules.beachAt(id, Vector3.new(60, 0, 67.7), SOUTH, 0, southBank)
				t.ok(south ~= nil and (south :: Vector3).Z >= 76.5, id .. ": south bank, Land here")
			end
			-- Still only when slow, bow on, and within reach.
			t.eq(BoatRules.beachAt("Canoe", Vector3.new(96.3, 0, 0), EAST, BoatRules.BEACH_SPEED + 1, eastBank), nil, "too fast")
			t.eq(BoatRules.beachAt("Canoe", Vector3.new(96.3, 0, 0), -EAST, 0, eastBank), nil, "stern to the bank")
			t.eq(BoatRules.beachAt("Canoe", Vector3.new(60, 0, 0), EAST, 0, eastBank), nil, "the bank is past the reach")
			-- The Deep-V lands at piers only, whatever the ground says.
			t.eq(BoatRules.beachAt("DeepV", Vector3.new(94, 0, 0), EAST, 0, eastBank), nil, "Deep-V refuses the bank")
			t.eq(BoatRules.beachAt("DeepV", Vector3.new(100, 0, 0), EAST, 0, function()
				return true
			end), nil, "Deep-V refuses any shore")
		end)
	end)

	t.test("the look-ahead stop at the measured east bank leaves the bow within the dry search", function()
		withCanoe(true, function()
			-- The ray stops the hull 1.5 studs plus a quarter second short of the terrain; at a creep
			-- the bow is about 2 studs off it, at full paddle about 4.25. Both are in reach.
			for _, speed in { 1, BoatData.byId.Canoe.pairSpeed } do
				local gap = BoatRules.STOP_CLEAR + speed * BoatRules.STOP_LOOK
				local hull = Vector3.new(106 - gap - BoatData.byId.Canoe.length / 2, 0, 0)
				t.ok(BoatRules.beachAt("Canoe", hull, EAST, 0, function(p: Vector3)
					return p.X >= 106
				end) ~= nil, string.format("stopped %.2f studs short at speed %.0f", gap, speed))
			end
		end)
	end)

	t.test("a boat stops before a log and before backing into the dock from its slip", function()
		-- The log at (70, 55) lies along yaw 0.5: drive at it from the south.
		local kind = BoatRules.stopAhead("Dinghy", Vector3.new(70, 0, 63), NORTH, 6)
		t.eq(kind, "log", "the log ahead")
		local slip = BoatRules.slipCFrame(1, "Dinghy")
		t.eq(BoatRules.stopAhead("Dinghy", slip.Position, slip.LookVector, 2), nil, "out of the slip is clear")
		t.eq(BoatRules.stopAhead("Dinghy", slip.Position, slip.LookVector, -2), "dock", "backing into the dock")
	end)

	t.test("water a boat may not use stops it at the edge, with its own words", function()
		withCanoe(true, function()
			-- The Deep-V keeps to the Big Lake: heading south out of the channel into the home lake.
			local kind, msg = BoatRules.stopAhead("DeepV", Vector3.new(0, 0, -150), Vector3.new(0, 0, 1), 10)
			t.eq(kind, "water", "the home lake")
			t.ok(msg ~= nil and msg:find("can't go there") ~= nil, "says why")
		end)
	end)

	t.test("every stop has kind words, without dashes", function()
		withCanoe(true, function()
			for _, kind in { "shore", "log", "dock", "water", "thing" } do
				for _, b in BoatData.list do
					local s = BoatRules.stopText(b.id, kind, nil)
					t.ok(#s > 0 and s:find("\u{2014}") == nil, b.id .. " " .. kind)
				end
			end
			t.ok(BoatRules.stopText("Canoe", "shore", nil):find("land here") ~= nil, "a lander is told it can land")
			t.ok(BoatRules.stopText("DeepV", "shore", nil):find("land here") == nil, "the Deep-V lands at piers only")
		end)
	end)

	t.test("helm input goes out the frame it changes, and held keys repeat", function()
		local s = BoatInput.new()
		local send, th, st = BoatInput.decide(s, true, 0, 0, 0)
		t.ok(send, "sitting down sends at once")
		send = BoatInput.decide(s, true, 0, 0, 0.016)
		t.ok(not send, "nothing new, nothing sent")
		send, th, st = BoatInput.decide(s, true, 0, 1, 0.032)
		t.ok(send and th == 0 and st == 1, "a turn goes the same frame")
		send = BoatInput.decide(s, true, 0, 1, 0.048)
		t.ok(not send, "no repeat inside the heartbeat")
		send = BoatInput.decide(s, true, 0, 1, 0.032 + BoatInput.HEARTBEAT)
		t.ok(send, "a held key repeats on the heartbeat")
		send, th, st = BoatInput.decide(s, true, 0, 0, 0.2)
		t.ok(send and st == 0, "letting go goes at once")
		send = BoatInput.decide(s, true, 0, 0, 1)
		t.ok(not send, "nothing held, no heartbeat")
		send = BoatInput.decide(s, true, 0.52, 0, 1.01)
		t.ok(send, "a stick push sends")
		send = BoatInput.decide(s, true, 0.53, 0, 1.02)
		t.ok(not send, "a tiny stick move inside one step does not")
		send, th, st = BoatInput.decide(s, false, 0.53, 0, 1.03)
		t.ok(send and th == 0 and st == 0, "leaving the helm lets go")
		send = BoatInput.decide(s, false, 0, 0, 1.04)
		t.ok(not send, "and only once")
	end)

	-- N4 review 1: the logs sink at their west ends; a boat bumps only the part above the water.
	t.test("log 3's sunk end is clear for boats and its dry end blocks; snags unchanged", function()
		local Cover = require(Shared.Cover)
		local function onLog3(x: number): Vector3
			local yaw = 1.1
			return Vector3.new(62 + x * math.cos(yaw), 0, 28 - x * math.sin(yaw))
		end
		local from, to = Cover.logBlockSpan(-1.2)
		t.ok(from ~= nil and to ~= nil, "log 3 has a dry stretch")
		t.ok((from :: number) > -5 and (from :: number) < -3, "it starts near x -3.8 (" .. tostring(from) .. ")")
		t.ok(to == Cover.LOG_HALF, "and runs to the raised east end")
		t.eq(BoatRules.blockedAt("Dinghy", onLog3(-9)), nil, "the sunk end: open water to a boat")
		t.eq(BoatRules.blockedAt("Dinghy", onLog3(8)), "log", "the dry end blocks")
		t.ok(Cover.snagAt(onLog3(-9)), "a cast on the sunk end still snags")
		-- Log 5 (y -1.6) is dry only on its east half.
		local f5 = Cover.logBlockSpan(-1.6)
		t.ok(f5 ~= nil and (f5 :: number) > -1 and (f5 :: number) < 0, "log 5 dry from about x -0.5")
		-- Log 1 (y -0.4) is out of the water almost all along.
		local f1 = Cover.logBlockSpan(-0.4)
		t.ok(f1 ~= nil and (f1 :: number) < -10, "log 1 blocks nearly all its length")
		t.eq(BoatRules.blockedAt("Dinghy", Vector3.new(70, 0, 55)), "log", "on log 1")
	end)

	t.test("the footprint: 8 points on a box 1.1 times the boat (the dinghy's is 8.8 by 4.4)", function()
		local pts = BoatRules.footprint("Dinghy", Vector3.new(0, 0, 0), EAST)
		t.eq(#pts, 8, "eight points")
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		for _, p in pts do
			minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
			minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
		end
		t.ok(math.abs((maxX - minX) - 8.8) < 1e-6, "8.8 long")
		t.ok(math.abs((maxZ - minZ) - 4.4) < 1e-6, "4.4 wide")
	end)

	t.test("at its slip a boat touches nothing and pulls out; the dinghy turns round in place (SLIP_X_EDGE 6.5)", function()
		t.eq(BoatRules.SLIP_X_EDGE, 6.5, "slip edge 6.5")
		for _, b in BoatData.list do
			for i = 1, #BoatRules.SLIP_ZS do
				local cf = BoatRules.slipCFrame(i, b.id)
				local yaw = math.atan2(-cf.LookVector.X, -cf.LookVector.Z)
				t.eq((BoatRules.footprintHits(b.id, cf.Position, cf.LookVector)), 0, b.id .. " at slip " .. i .. " touches nothing")
				-- It can always pull straight out. (A long boat can't spin round at every slip: the
				-- canoe at slip 1 finds the end deck by a 40 degree swing to the north, so it goes out
				-- before it turns.)
				local moveOk = BoatRules.poseCheck(b.id, cf.Position, yaw, b.maxSpeed, 0)
				t.ok(moveOk, b.id .. " at slip " .. i .. " pulls straight out")
			end
		end
		-- The dinghy (the boat the stern was seen under the deck in) turns all the way round.
		for i = 1, #BoatRules.SLIP_ZS do
			local cf = BoatRules.slipCFrame(i, "Dinghy")
			local yaw = math.atan2(-cf.LookVector.X, -cf.LookVector.Z)
			for k = 0, 35 do
				local look = CFrame.fromOrientation(0, yaw + math.rad(k * 10), 0).LookVector
				local hits, kind = BoatRules.footprintHits("Dinghy", cf.Position, look)
				t.ok(hits == 0, string.format("Dinghy slip %d heading +%d: %s", i, k * 10, tostring(kind)))
			end
		end
	end)

	t.test("a stern beside the dock: the turn is refused, going straight on is not", function()
		-- The dinghy heading east with its stern 0.7 off the deck's edge (x 4) along the walkway.
		local half = BoatData.byId.Dinghy.length * BoatRules.FOOTPRINT_PAD / 2
		local pos = Vector3.new(4 + 0.7 + half, 0, 60)
		local yaw = math.atan2(-EAST.X, -EAST.Z)
		t.eq((BoatRules.footprintHits("Dinghy", pos, EAST)), 0, "clear where it is")
		local moveOk, turnOk, kind = BoatRules.poseCheck("Dinghy", pos, yaw, 6, 1)
		t.ok(moveOk, "forward is fine")
		t.ok(not turnOk, "but the stern would swing under the deck")
		t.eq(kind, "dock", "the dock is in the way")
		local backOk, turn2 = BoatRules.poseCheck("Dinghy", pos, yaw, -3, 0)
		t.ok(not backOk and turn2, "backing into the deck is refused (no turn asked)")
		local m3, t3 = BoatRules.poseCheck("Dinghy", pos, yaw, 0, 0)
		t.ok(m3 and t3, "standing still is always fine")
		-- Already touching (a stern 0.2 off the deck): moving away is never refused.
		local close = Vector3.new(4 + 0.2 + half, 0, 60)
		local away = BoatRules.poseCheck("Dinghy", close, yaw, 6, 0)
		t.ok(away, "a boat against the dock can always pull away")
	end)
end
