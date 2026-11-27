-- The reel and the feel (L4b): line tension and its colour, the rod's bend, the cast's swing
-- and flight arc. Pure rules from Shared/FightFeel and Shared/CastLogic. Written 2026-11-26.
return function(t, Shared)
	local FightFeel = require(Shared.FightFeel)
	local CastLogic = require(Shared.CastLogic)

	local function state(fishPos: number, zonePos: number, progress: number, mode: string?)
		return { fishPos = fishPos, zonePos = zonePos, zoneSize = 0.3, progress = progress, mode = mode or "normal" }
	end

	local function same(a: Color3, b: Color3): boolean
		return math.abs(a.R - b.R) < 1e-3 and math.abs(a.G - b.G) < 1e-3 and math.abs(a.B - b.B) < 1e-3
	end

	t.test("tension: low in the zone, higher the further out, red near escaping", function()
		local inZone = FightFeel.tension(state(0.5, 0.5, 0.6))
		local justOut = FightFeel.tension(state(0.70, 0.5, 0.6))
		local farOut = FightFeel.tension(state(0.95, 0.3, 0.6))
		t.ok(inZone < 0.3, "in the zone " .. inZone)
		t.ok(justOut > inZone and justOut < farOut, string.format("%.2f < %.2f < %.2f", inZone, justOut, farOut))
		t.eq(farOut, 1, "far out is full tension")
		t.ok(FightFeel.tension(state(0.5, 0.5, 0.6, "run")) > inZone, "a run pulls harder")
		-- Progress almost gone: red even in the zone.
		t.ok(FightFeel.tension(state(0.5, 0.5, 0.02)) > 0.9, "about to escape")
		t.ok(FightFeel.tension(state(0.5, 0.5, 0.29)) < 0.3, "not near escaping yet")
		for _, s in { state(0, 1, 0), state(1, 0, 1, "jump"), state(0.5, 0.5, 2) } do
			local v = FightFeel.tension(s)
			t.ok(v >= 0 and v <= 1, "in range " .. v)
		end
	end)

	t.test("line colour: white, then orange, then red", function()
		t.ok(same(FightFeel.lineColor(0), FightFeel.WHITE), "0 white")
		t.ok(same(FightFeel.lineColor(FightFeel.WHITE_UNTIL), FightFeel.WHITE), "white until")
		t.ok(same(FightFeel.lineColor(FightFeel.ORANGE_AT), FightFeel.ORANGE), "orange")
		t.ok(same(FightFeel.lineColor(FightFeel.RED_AT), FightFeel.RED), "red")
		t.ok(same(FightFeel.lineColor(1), FightFeel.RED), "1 red")
		t.ok(same(FightFeel.lineColor(-3), FightFeel.WHITE) and same(FightFeel.lineColor(7), FightFeel.RED), "clamped")
		-- Green falls steadily as tension rises: the line warms up without jumping back.
		local lastG = 2
		for i = 0, 20 do
			local c = FightFeel.lineColor(i / 20)
			t.ok(c.G <= lastG + 1e-6, "green never rises at " .. i / 20)
			lastG = c.G
		end
		-- Between white and orange it is a blend of the two.
		local mid = FightFeel.lineColor((FightFeel.WHITE_UNTIL + FightFeel.ORANGE_AT) / 2)
		t.ok(mid.G < FightFeel.WHITE.G and mid.G > FightFeel.ORANGE.G, "blend")
	end)

	t.test("the rod bends more with tension, and dips for a dive", function()
		t.eq(FightFeel.rodBend(0), FightFeel.BEND_MIN)
		t.eq(FightFeel.rodBend(1), FightFeel.BEND_MAX)
		t.ok(FightFeel.rodBend(0.5) > FightFeel.rodBend(0.2), "more tension, more bend")
		t.eq(FightFeel.rodBend(0.5, true), FightFeel.rodBend(0.5) + FightFeel.DIVE_DIP)
		t.ok(FightFeel.rodBend(1, true) < 90, "never folds over")
	end)

	t.test("the cast swing goes back, whips forward past rest, and settles", function()
		local back, whip = FightFeel.BACK_TIME, FightFeel.WHIP_TIME
		t.eq(FightFeel.swingPitch(0), 0)
		t.ok(math.abs(FightFeel.swingPitch(back - 1e-4) - FightFeel.SWING_BACK) < 0.5, "back at the top")
		t.ok(FightFeel.swingPitch(back * 0.5) > 0, "going back")
		t.ok(math.abs(FightFeel.swingPitch(back + whip - 1e-4) - FightFeel.SWING_WHIP) < 0.5, "whipped forward")
		t.ok(FightFeel.SWING_WHIP < 0, "the whip ends past rest")
		t.eq(FightFeel.swingPitch(FightFeel.swingTime() + 0.01), 0, "settled")
		t.ok(FightFeel.swingTime() <= 0.7, "quick: " .. FightFeel.swingTime())
		t.eq(FightFeel.releaseTime(), back + whip)
		-- No jumps: the pitch moves smoothly.
		local last = 0
		for i = 1, 200 do
			local p = FightFeel.swingPitch(i * FightFeel.swingTime() / 200)
			t.ok(math.abs(p - last) < 12, "smooth at step " .. i)
			last = p
		end
	end)

	t.test("the bobber flies the landing ring's arc in about 0.6 s", function()
		t.ok(CastLogic.FLIGHT_TIME >= 0.4 and CastLogic.FLIGHT_TIME <= 0.8, "flight " .. CastLogic.FLIGHT_TIME)
		local tip = Vector3.new(0, 5, 0)
		local land = Vector3.new(0, 0.3, -30)
		t.eq(CastLogic.arcPoint(tip, land, 0), tip)
		t.ok((CastLogic.arcPoint(tip, land, 1) - land).Magnitude < 1e-3, "ends on the landing point")
		local mid = CastLogic.arcPoint(tip, land, 0.5)
		t.ok(mid.Y > (tip.Y + land.Y) / 2 + 1, "it arcs up: " .. mid.Y)
		t.ok(math.abs(mid.Z - (-15)) < 1e-6, "halfway out")
		local longer = CastLogic.arcPoint(tip, Vector3.new(0, 0.3, -50), 0.5)
		t.ok(CastLogic.arcLift(tip, Vector3.new(0, 0.3, -50)) > CastLogic.arcLift(tip, land), "longer casts arc higher")
		t.ok(longer.Y > mid.Y, "and fly higher")
	end)
end
