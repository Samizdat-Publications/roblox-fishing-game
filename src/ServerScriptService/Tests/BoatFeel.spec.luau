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

	t.test("wake: two soft arms that fade in at the stern, widen and fade out; the canoe's a hairline; lighter on a phone", function()
		local w0, a0 = BoatFeel.wakePiece("Dinghy", 0, 1)
		local wPeak, aPeak = BoatFeel.wakePiece("Dinghy", 0.5, 1)
		local w1, a1 = BoatFeel.wakePiece("Dinghy", 3.4, 1)
		t.ok(near(w0 :: number, 0.5) and near(a0 :: number, 1), "starts 0.5 wide and clear (it fades in at the stern)")
		t.ok(near(aPeak :: number, 0.38), "its peak: 0.38 transparent at full speed (N4 review 1; " .. tostring(aPeak) .. ")")
		t.ok((w1 :: number) > (wPeak :: number) and (wPeak :: number) > (w0 :: number), "widens")
		t.ok((a1 :: number) > (aPeak :: number), "fades out")
		local _, aIn = BoatFeel.wakePiece("Dinghy", 0.1, 1)
		t.ok((aIn :: number) > (aPeak :: number) and (aIn :: number) < 1, "still fading in at 0.1 s")
		for age = 0, 3.59, 0.05 do
			local _, tr = BoatFeel.wakePiece("Dinghy", age, 1)
			t.ok((tr :: number) >= 0.38 - 1e-9 and (tr :: number) <= 1, "never brighter than the peak")
		end
		t.eq(BoatFeel.wakePiece("Dinghy", 3.6, 1), nil, "gone at 3.6 s")
		t.eq(BoatFeel.wakePiece("Dinghy", 0.2, 0.05), nil, "none when crawling")
		local _, aSlow = BoatFeel.wakePiece("Dinghy", 0.5, 0.3)
		t.ok((aSlow :: number) > (aPeak :: number), "fainter when slow")
		local slowW = BoatFeel.wakePiece("Dinghy", 1.0, 0.3) :: number
		local fastW = BoatFeel.wakePiece("Dinghy", 1.0, 1) :: number
		t.ok(fastW > slowW, "wider at speed")
		local cw, ca = BoatFeel.wakePiece("Canoe", 1.0, 1)
		t.ok((cw :: number) < 0.3, "the canoe's is a hairline (" .. tostring(cw) .. ")")
		t.ok((ca :: number) >= 0.72 - 1e-9, "and fainter than a motor boat's")
		t.eq(BoatFeel.wakePiece("Dinghy", 2.2, 1, "phone"), nil, "shorter on a phone")
		local top = BoatData.byId.Dinghy.maxSpeed
		t.ok(BoatFeel.wakePieces("Dinghy", "phone", top) < BoatFeel.wakePieces("Dinghy", "desktop", top), "fewer points on a phone")
		t.eq(BoatFeel.wakePieces("Dinghy", "desktop", top), 15, "15 points an arm (3.6 s at 12 studs a second, one every 3)")
		t.eq(BoatFeel.wakePieces("Dinghy", "phone", top), 5, "5 on a phone")
		t.eq(BoatFeel.wakeStep("Dinghy", "desktop"), 3, "a point every 3 studs")
		t.eq(BoatFeel.wakeStep("Dinghy", "phone"), 6, "every 6 on a phone")
		t.ok(near(BoatFeel.wakeSpread(10, 1), 10 * math.tan(math.rad(19.47))), "arms spread at the Kelvin angle")
		local st = BoatFeel.wakeStart(BoatFeel.ART.Dinghy, 1)
		t.ok(st.X > 0 and st.X < BoatFeel.ART.Dinghy.halfBeam and st.Z < BoatFeel.ART.Dinghy.stern.Z, "starts inside the stern's starboard quarter")
		t.ok(BoatFeel.wakeStart(BoatFeel.ART.Canoe, -1).X < 0, "port arm to port")
		t.eq(BoatFeel.wakeTextureSpeed(0), 0, "no drift when stopped")
		t.ok(near(BoatFeel.wakeTextureSpeed(1), 0.2), "0.2 tiles a second at full speed")
		t.ok(BoatFeel.WAKE_Y > 0.06, "over the chop")
	end)

	t.test("N4 review 1: wake points every 3 studs travelled, one whole foam tile per beam, lying flat", function()
		t.eq(BoatFeel.WAKE_TEX.length, BoatFeel.WAKE.motor.step, "TextureLength equals the step (3)")
		t.eq(BoatFeel.WAKE_TEX.length, 3, "TextureLength 3")
		local m = BoatFeel.WAKE.motor
		t.ok(near(m.base, 0.38) and near(m.life, 3.6) and near(m.w0, 0.5) and near(m.w1, 1.2) and near(m.w1Speed, 1.6), "the motor wake's numbers")
		-- Not on a timer: nothing until the stern has gone a whole step.
		local a = Vector3.new(0, 0.1, 0)
		local none, last0 = BoatFeel.wakeDrops(a, Vector3.new(2.9, 0.1, 0), 3)
		t.eq(#none, 0, "under a step: no point")
		t.ok(last0 == a, "and the last point stays")
		-- 7.5 studs in one go: two points, exactly 3 apart along the path, the rest carried over.
		local drops, last = BoatFeel.wakeDrops(a, Vector3.new(7.5, 0.1, 0), 3)
		t.eq(#drops, 2, "two points in 7.5 studs")
		t.ok(near((drops[1] - a).Magnitude, 3) and near((drops[2] - drops[1]).Magnitude, 3), "3 studs apart")
		t.ok(last == drops[2], "the last point is the newest")
		local more = BoatFeel.wakeDrops(last, Vector3.new(9.1, 0.1, 0), 3)
		t.eq(#more, 1, "the next comes at 9")
		-- Each wake attachment's Y points straight up (its own setting, not the creek's).
		t.eq(BoatFeel.WAKE_BEAM_NORMAL, "Y", "the wake's own beam normal")
		for _, along in { Vector3.new(1, 0, 0), Vector3.new(-3, 0.4, 2), Vector3.new(0, 0, 0) } do
			local right, up = BoatFeel.wakeAxes(along)
			t.ok(up == Vector3.yAxis, "the attachment's Y is up")
			t.ok(near(right.Y, 0) and near(right.Magnitude, 1), "X level along the arm")
		end
	end)

	t.test("N4 review 1: soft side lights, a brighter stern light, dark housings", function()
		t.ok(near(BoatFeel.LIGHT.red.brightness, 0.35) and BoatFeel.LIGHT.red.range == 4, "red 0.35, range 4")
		t.ok(near(BoatFeel.LIGHT.green.brightness, 0.35) and BoatFeel.LIGHT.green.range == 4, "green 0.35, range 4")
		t.ok(near(BoatFeel.LIGHT.white.brightness, 0.8) and BoatFeel.LIGHT.white.range == 7, "white 0.8, range 7")
		t.ok(BoatFeel.LIGHT_COLORS.red == Color3.fromRGB(232, 70, 52), "red 232,70,52")
		t.ok(BoatFeel.LIGHT_COLORS.green == Color3.fromRGB(70, 200, 120), "green 70,200,120")
		local h = BoatFeel.LAMP_HOUSING.color
		t.ok(h.R < 0.2 and h.G < 0.2 and h.B < 0.2, "the housing is dark")
	end)

	t.test("N4 review 1: every lamp sits on its hull (gap to the art's box under 0.05)", function()
		local d = BoatFeel.ART.Dinghy.lights
		t.ok(d.red == Vector3.new(-0.45, 1.34, -3.4) and d.green == Vector3.new(0.45, 1.34, -3.4), "the dinghy's side lights on the tube crown")
		for _, id in { "Canoe", "Dinghy", "DeepV" } do
			for key, pos in BoatFeel.ART[id].lights :: any do
				local gap = BoatFeel.lampGap(id, pos)
				t.ok(gap < BoatFeel.LAMP_GAP, string.format("%s %s gap %.3f", id, key, gap))
			end
		end
		-- The old Deep-V stern light at y 3.6 was over its box: the check catches that.
		t.ok(BoatFeel.lampGap("DeepV", Vector3.new(0, 3.6, 8.0)) > 0.05, "a floating lamp fails")
	end)

	t.test("N4 review 1: knees straighten from 70 degrees until no leg is under the floor", function()
		t.eq(BoatFeel.KNEE_START, 70, "starts at 70")
		for _, id in { "Canoe", "Dinghy" } do
			local a = BoatFeel.ART[id]
			for name, seat in a.seats :: any do
				local k = BoatFeel.kneeStraighten(seat.Y, a.floor.y)
				t.ok(k >= 70 and k <= BoatFeel.KNEE_MAX, id .. " " .. name .. " " .. k)
				t.ok(BoatFeel.legLow(seat.Y, k) >= a.floor.y - 1e-9, id .. " " .. name .. ": legs over the floor")
			end
		end
		-- The canoe's seats (0.64 over a 0.22 floor) need more than the starting 70.
		local c = BoatFeel.ART.Canoe
		t.ok(BoatFeel.legLow(0.64, 0) < c.floor.y, "the plain sit pokes through the canoe floor")
		t.ok(BoatFeel.legLow(0.64, 70) < c.floor.y, "70 is not enough in the canoe")
		t.eq(BoatFeel.kneeStraighten(0.64, c.floor.y), 75, "75 clears it")
		-- The dinghy's passenger sits on the floor boards (0.309): straight legs.
		t.eq(BoatFeel.kneeStraighten(0.309, BoatFeel.ART.Dinghy.floor.y), 90, "legs out straight on the floor")
	end)

	t.test("the wash and swirls are soft: faint puffs that end clear", function()
		t.ok(BoatFeel.WASH.transparency[1] >= 0.6 and BoatFeel.WASH.transparency[2] == 1, "the wash is faint and ends clear")
		t.ok(BoatFeel.SWIRL_TRANSPARENCY[1] >= 0.6 and BoatFeel.SWIRL_TRANSPARENCY[2] == 1, "the swirls too")
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
