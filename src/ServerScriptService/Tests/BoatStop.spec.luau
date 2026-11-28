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
end
