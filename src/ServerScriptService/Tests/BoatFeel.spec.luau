-- How a boat feels (leg 3, N4, Config.BOAT_FEEL_ON): the trim curve, the lean, the bob and the
-- canoe's cap, the floor kept dry on screen, paddling, wake widths, camera easing.
-- Written 11/28/2026 in a worktree; UNVERIFIED in Studio.
return function(t, Shared)
	local BoatFeel = require(Shared.BoatFeel)
	local BoatData = require(Shared.BoatData)
	local Config = require(Shared.Config)

	local function near(a: number, b: number, eps: number?): boolean
		return math.abs(a - b) <= (eps or 1e-6)
	end

	t.test("the feel layer lands switched off", function()
		t.eq(Config.BOAT_FEEL_ON, false, "BOAT_FEEL_ON")
	end)

	t.test("every boat has art, and the art names list covers every model and paddle", function()
		local names = {}
		for _, n in BoatFeel.artNames() do
			names[n] = true
		end
		for _, b in BoatData.list do
			local a = BoatFeel.ART[b.id]
			t.ok(a ~= nil, b.id .. " has an art entry")
			t.ok(names[a.hero] and names[a.plain], b.id .. " models listed")
		end
		t.ok(names.CedarCanoe and names.CedarCanoePlain and names.CanoePaddle and names.CanoePaddlePlain, "the canoe set")
		t.eq(BoatFeel.modelFor("Canoe", "phone"), "CedarCanoePlain", "phone draws the plain twin")
		t.eq(BoatFeel.modelFor("Canoe", "desktop"), "CedarCanoe", "desktop draws the hero")
		t.eq(BoatFeel.modelFor("Nope", "desktop"), nil, "unknown boat")
	end)

	t.test("the canoe's seats match its model (art/README.md)", function()
		local s = BoatFeel.ART.Canoe.seats :: any
		t.ok(s.Helm == Vector3.new(0, 0.64, 3.0), "stern seat")
		t.ok(s.Bow == Vector3.new(0, 0.64, -2.3), "bow seat")
	end)

	t.test("trim: flat when slow, up to 6 degrees past 40 percent, settling to 2 or 3 on plane", function()
		t.ok(near(BoatFeel.trim("Dinghy", 0), 0), "stopped")
		t.ok(near(BoatFeel.trim("Dinghy", 0.05), 0), "crawling")
		t.ok(BoatFeel.trim("Dinghy", 0.3) > 1 and BoatFeel.trim("Dinghy", 0.3) < 6, "climbing")
		t.ok(near(BoatFeel.trim("Dinghy", 0.45), 6), "the hump at 45 percent")
		local peak = 0
		for i = 0, 100 do
			peak = math.max(peak, BoatFeel.trim("Dinghy", i / 100))
		end
		t.ok(peak <= 6 + 1e-9, "never past 6")
		local plane = BoatFeel.trim("Dinghy", 1)
		t.ok(plane >= 2 and plane <= 3, "on plane: " .. plane)
		t.ok(near(BoatFeel.trim("DeepV", 1), plane), "the Deep-V planes the same")
		t.ok(BoatFeel.trim("Canoe", 0.45) <= 1.5 + 1e-9, "the canoe barely lifts")
		t.ok(near(BoatFeel.trim("Dinghy", -0.45), 6), "reverse counts by size")
	end)

	t.test("lean: into the turn, up to 8 degrees, growing with speed", function()
		t.ok(near(BoatFeel.lean("Dinghy", 1, 1), -8), "hard right at speed: starboard down 8")
		t.ok(near(BoatFeel.lean("Dinghy", -1, 1), 8), "hard left: port down")
		t.ok(near(BoatFeel.lean("Dinghy", 1, 0), 0), "no lean when stopped")
		t.ok(near(BoatFeel.lean("Dinghy", 1, 0.25), -4), "half lean at a quarter speed")
		t.ok(near(BoatFeel.lean("Dinghy", 3, 1), -8), "clamped")
		t.ok(near(BoatFeel.lean("Canoe", 1, 1), -3), "the canoe leans 3")
		-- 90 degrees a second turning right (a negative yaw rate) is a full right turn
		t.ok(near(BoatFeel.turnFromYawRate(-math.rad(90), 90), 1), "full right")
		t.ok(near(BoatFeel.turnFromYawRate(math.rad(45), 90), -0.5), "half left")
		t.ok(near(BoatFeel.turnFromYawRate(1, 0), 0), "no turn rate")
	end)

	t.test("bob: 0.15 studs and 1.5 degrees at rest, twice in blue water, the canoe capped", function()
		local maxH, maxP, maxR, maxBlue = 0, 0, 0, 0
		for i = 0, 2000 do
			local s = i * 0.013
			local b = BoatFeel.bob("Dinghy", s, 0, false)
			maxH = math.max(maxH, math.abs(b.heave))
			maxP = math.max(maxP, math.abs(b.pitch))
			maxR = math.max(maxR, math.abs(b.roll))
			maxBlue = math.max(maxBlue, math.abs(BoatFeel.bob("DeepV", s, 0, true).heave))
		end
		t.ok(maxH <= 0.15 + 1e-9 and maxH > 0.149, "heave " .. maxH)
		t.ok(maxP <= 1.5 + 1e-9 and maxP > 1.49, "pitch " .. maxP)
		t.ok(maxR <= 1.5 + 1e-9 and maxR > 1.49, "roll " .. maxR)
		t.ok(maxBlue <= 0.3 + 1e-9 and maxBlue > 0.29, "blue water heave " .. maxBlue)
		local fast = BoatFeel.bob("Dinghy", 0.7, 1, false)
		local rest = BoatFeel.bob("Dinghy", 0.7, 0, false)
		t.ok(near(fast.heave, rest.heave * 0.5), "half the bob at full speed")
	end)

	t.test("the canoe's drawn floor never dips more than 0.2 studs (its draft is 0.22)", function()
		local a = BoatFeel.ART.Canoe
		local c = BoatFeel.BOB.paddle
		local worst = 0
		for _, heave in { -c.heave, c.heave } do
			for _, pitch in { -c.pitch, c.pitch } do
				for _, trim in { 0, BoatFeel.TRIM.paddle.peak } do
					for _, sgn in { -1, 1 } do
						local roll = sgn * (c.roll + BoatFeel.LEAN_MAX.paddle + BoatFeel.STROKE_ROLL)
						local dip = BoatFeel.floorDip(a, heave, trim, pitch, roll)
						worst = math.max(worst, dip)
						t.ok(BoatFeel.floorLow(a, heave, trim, pitch, roll) >= BoatFeel.FLOOR_MIN, "floor dry")
						t.ok(near(BoatFeel.settle(a, heave, trim, pitch, roll), heave), "no lift needed for the canoe")
					end
				end
			end
		end
		t.ok(worst <= BoatFeel.CANOE_DIP_MAX, "worst dip " .. worst)
		t.ok(worst > 0.1, "the test reaches a real dip (" .. worst .. ")")
		-- the canoe never goes to blue water, so its bob is never doubled
		t.ok(BoatData.byId.Canoe.waters.BlueWater == nil, "no blue water for the canoe")
	end)

	t.test("trim lifts the bow about the stern: it never sinks the floor", function()
		for _, id in { "Canoe", "Dinghy", "DeepV" } do
			local a = BoatFeel.ART[id]
			t.ok(near(BoatFeel.floorDip(a, 0, 6, 0, 0), 0), id)
		end
	end)

	t.test("a hard lean on the dinghy lifts it just enough to keep the floor dry", function()
		local a = BoatFeel.ART.Dinghy
		local heave = BoatFeel.settle(a, -0.15, 0, 1.5, -9.5)
		t.ok(heave > -0.15, "lifted")
		t.ok(near(BoatFeel.floorLow(a, heave, 0, 1.5, -9.5), BoatFeel.FLOOR_MIN, 1e-9), "just dry")
		t.ok(near(BoatFeel.settle(a, 0, 0, 0, 0), 0), "level needs nothing")
	end)

	t.test("paddling: strokes only when moving, faster at speed; the canoe rolls toward each stroke", function()
		t.eq(BoatFeel.strokeRate(0, 7), 0, "stopped")
		t.eq(BoatFeel.strokeRate(0.3, 7), 0, "drifting")
		t.ok(near(BoatFeel.strokeRate(7, 7), 1 / 1.2), "full speed, 1.2 s a stroke")
		t.ok(BoatFeel.strokeRate(2, 7) < BoatFeel.strokeRate(6, 7), "faster when faster")
		t.ok(near(BoatFeel.strokeRoll(BoatFeel.PULL / 2, 1), -1), "starboard dips 1 degree mid-pull")
		t.ok(near(BoatFeel.strokeRoll(BoatFeel.PULL / 2, -1), 1), "port side")
		t.ok(near(BoatFeel.strokeRoll(0.7, 1), 0), "nothing in the recovery")
		local d = BoatFeel.paddleDir(0.1, 1)
		t.ok(near(d.Magnitude, 1, 1e-6) and d.Y < -0.5 and d.X > 0, "blade down, starboard side")
		t.ok(BoatFeel.paddleDir(0.0, 1).Z < 0 and BoatFeel.paddleDir(0.34, 1).Z > 0, "sweeps bow to stern")
		t.ok(BoatFeel.paddleDir(0.6, -1).X < 0 and BoatFeel.paddleDir(0.6, -1).Y > -0.5, "recovery out of the water, port")
		local lowReach, upReach = BoatFeel.paddleArms(0)
		local lowEnd = BoatFeel.paddleArms(BoatFeel.PULL - 1e-6)
		t.ok(lowReach > lowEnd and upReach > lowReach, "reach, then pull back; the top hand high")
	end)

	t.test("wake: two arms that widen and fade; the canoe's a hairline; lighter on a phone", function()
		local w0, a0 = BoatFeel.wakePiece("Dinghy", 0, 1)
		local w1, a1 = BoatFeel.wakePiece("Dinghy", 1.2, 1)
		t.ok(w0 ~= nil and w1 ~= nil and (w1 :: number) > (w0 :: number), "widens")
		t.ok((a1 :: number) > (a0 :: number), "fades")
		t.ok(near(w0 :: number, 0.6) and near(a0 :: number, 0.35), "starts 0.6 wide at 0.35")
		t.eq(BoatFeel.wakePiece("Dinghy", 1.6, 1), nil, "gone at 1.6 s")
		t.eq(BoatFeel.wakePiece("Dinghy", 0.2, 0.05), nil, "none when crawling")
		local slowW = BoatFeel.wakePiece("Dinghy", 1.0, 0.3) :: number
		local fastW = BoatFeel.wakePiece("Dinghy", 1.0, 1) :: number
		t.ok(fastW > slowW, "wider at speed")
		local cw = BoatFeel.wakePiece("Canoe", 1.0, 1) :: number
		t.ok(cw < 0.6, "the canoe's is a hairline (" .. cw .. ")")
		t.eq(BoatFeel.wakePiece("Dinghy", 1.2, 1, "phone"), nil, "shorter on a phone")
		t.ok(BoatFeel.wakePieces("Dinghy", "phone") < BoatFeel.wakePieces("Dinghy", "desktop"), "fewer pieces on a phone")
		t.eq(BoatFeel.wakePieces("Dinghy", "desktop"), 16, "16 pieces an arm")
		t.ok(near(BoatFeel.wakeSpread(10, 1), 10 * math.tan(math.rad(19.47))), "arms spread at the Kelvin angle")
	end)

	t.test("spray at the bow above 60 percent (motor boats), wash with speed, lighter on a phone", function()
		t.eq(BoatFeel.sprayRate("Dinghy", 0.6), 0, "none at 60 percent")
		t.ok(BoatFeel.sprayRate("Dinghy", 0.8) > 0, "some at 80")
		t.ok(near(BoatFeel.sprayRate("DeepV", 1), 30), "30 at full")
		t.eq(BoatFeel.sprayRate("Canoe", 1), 0, "no spray off a canoe")
		t.ok(near(BoatFeel.sprayRate("Dinghy", 1, "phone"), 12), "phone 40 percent")
		t.eq(BoatFeel.washRate("Dinghy", 0), 0, "no wash when stopped")
		t.ok(BoatFeel.washRate("Canoe", 1) < BoatFeel.washRate("Dinghy", 1), "the canoe's wash is small")
	end)

	t.test("camera: eases back and up with speed, field of view up 6 at full, and returns", function()
		local back, up, fov = BoatFeel.cameraFor(1)
		t.ok(near(back, 4) and near(up, 1.5) and near(fov, 6), "full")
		local b0, u0, f0 = BoatFeel.cameraFor(0)
		t.ok(b0 == 0 and u0 == 0 and f0 == 0, "slow: nothing")
		t.ok(near(select(3, BoatFeel.cameraFor(2)), 6), "clamped")
		-- easing: about 63 percent of the way in one time constant, never past the target
		local w = BoatFeel.approach(0, 1, 0.8, 0.8, 1.2)
		t.ok(near(w, 1 - math.exp(-1), 1e-9), "up in 0.8 s")
		local down = BoatFeel.approach(1, 0, 1.2, 0.8, 1.2)
		t.ok(near(down, math.exp(-1), 1e-9), "down in 1.2 s")
		local x = 0
		for _ = 1, 600 do
			x = BoatFeel.approach(x, 1, 1 / 60, 0.8, 1.2)
		end
		t.ok(x <= 1 and x > 0.99, "settles without overshoot")
	end)

	t.test("the horn waits 1.5 seconds between blasts", function()
		t.ok(BoatFeel.hornReady(nil, 0), "first")
		t.ok(not BoatFeel.hornReady(10, 11), "too soon")
		t.ok(BoatFeel.hornReady(10, 11.5), "ready")
	end)
end
