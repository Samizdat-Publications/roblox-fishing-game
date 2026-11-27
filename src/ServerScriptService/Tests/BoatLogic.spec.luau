-- UNVERIFIED in Studio: written overnight 2026-11-26. Runs with TestRunner like the others.
return function(t, Shared)
	local BoatLogic = require(Shared.BoatLogic)
	local BoatData = require(Shared.BoatData)
	local dinghy = BoatData.byId.Dinghy

	local function newData(coins)
		return { coins = coins }
	end

	t.test("buying a boat needs the coins and only works once", function()
		local poor = newData(dinghy.price - 1)
		local ok = BoatLogic.buy(poor, "Dinghy")
		t.ok(not ok, "poor buy should fail")
		t.eq(poor.coins, dinghy.price - 1, "coins unchanged")

		local rich = newData(dinghy.price + 10)
		local ok2, msg = BoatLogic.buy(rich, "Dinghy")
		t.ok(ok2, msg)
		t.eq(rich.coins, 10, "paid once")
		t.ok(BoatLogic.owns(rich, "Dinghy"), "owns it")
		local ok3 = BoatLogic.buy(rich, "Dinghy")
		t.ok(not ok3, "second buy should fail")
		t.eq(rich.coins, 10, "not charged twice")
	end)

	t.test("unknown boats are refused", function()
		local d = newData(99999)
		t.ok(not (BoatLogic.buy(d, "Yacht")), "unknown")
		local rich = { coins = 10000, boats = {} }
		t.ok(not (BoatLogic.buy(rich, "DeepV")), "the Deep-V isn't on sale until its two-player test")
		t.eq(rich.coins, 10000, "coins unchanged")
		t.eq(d.coins, 99999)
		t.ok(not BoatLogic.owns(d, "Dinghy"), "old saves own no boat")
	end)

	t.test("full throttle reaches top speed, never more", function()
		local m = { speed = 0, yawRate = 0 }
		for _ = 1, 600 do
			m = BoatLogic.step(m, "Dinghy", 1, 0, 1 / 60)
		end
		t.ok(math.abs(m.speed - dinghy.maxSpeed) < 0.1, "speed " .. m.speed)
		m = BoatLogic.step(m, "Dinghy", 5, 0, 1) -- a hacked throttle is clamped
		t.ok(m.speed <= dinghy.maxSpeed + 1e-6, "clamped " .. m.speed)
	end)

	t.test("reverse is slower than forward", function()
		local m = { speed = 0, yawRate = 0 }
		for _ = 1, 600 do
			m = BoatLogic.step(m, "Dinghy", -1, 0, 1 / 60)
		end
		t.ok(math.abs(m.speed + dinghy.reverseSpeed) < 0.1, "speed " .. m.speed)
	end)

	t.test("bad input counts as no input", function()
		local m = BoatLogic.step({ speed = 0, yawRate = 0 }, "Dinghy", 0 / 0, "left", 1)
		t.eq(m.speed, 0, "speed")
		t.eq(m.yawRate, 0, "yaw")
	end)

	t.test("turning works a little when stopped and fully when moving", function()
		local still = BoatLogic.step({ speed = 0, yawRate = 0 }, "Dinghy", 0, 1, 1 / 60)
		local moving = BoatLogic.step({ speed = dinghy.maxSpeed, yawRate = 0 }, "Dinghy", 1, 1, 1 / 60)
		t.ok(still.yawRate > 0, "can turn when stopped")
		t.ok(still.yawRate <= moving.yawRate * (dinghy.idleTurn + 0.05), "but slowly")
		t.ok(math.abs(moving.yawRate - dinghy.turnRate) < 1, "full turn at speed")
	end)

	t.test("steering flips in reverse", function()
		local m = BoatLogic.step({ speed = -dinghy.reverseSpeed, yawRate = 0 }, "Dinghy", -1, 1, 1 / 60)
		t.ok(m.yawRate < 0, "yaw " .. m.yawRate)
	end)

	t.test("frame rate doesn't change the result", function()
		local a, b = { speed = 0, yawRate = 0 }, { speed = 0, yawRate = 0 }
		for _ = 1, 15 do
			a = BoatLogic.step(a, "Dinghy", 1, 0, 1 / 15)
		end
		for _ = 1, 120 do
			b = BoatLogic.step(b, "Dinghy", 1, 0, 1 / 120)
		end
		t.ok(math.abs(a.speed - b.speed) < 0.01, a.speed .. " vs " .. b.speed)
	end)

	t.test("the server accepts normal moves and refuses teleports", function()
		local from = Vector3.new(0, 0, 0)
		t.ok(BoatLogic.moveOk(from, Vector3.new(dinghy.maxSpeed, 0, 0), 1, "Dinghy"), "top speed for a second")
		t.ok(BoatLogic.moveOk(from, Vector3.new(0, 30, 0), 0.1, "Dinghy"), "bobbing up and down is fine")
		t.ok(not BoatLogic.moveOk(from, Vector3.new(200, 0, 0), 1, "Dinghy"), "teleport")
		t.ok(not BoatLogic.moveOk(from, from, 0, "Dinghy"), "zero time")
	end)

	t.test("you cast only from a slow boat", function()
		t.ok((BoatLogic.canCast(0, "Dinghy")), "stopped")
		local ok, msg = BoatLogic.canCast(dinghy.maxSpeed, "Dinghy")
		t.ok(not ok and msg ~= nil, "moving")
	end)

	t.test("docking needs to be close and slow", function()
		local slip = Vector3.new(12, 0, 60)
		t.ok(BoatLogic.canDock(Vector3.new(15, 0, 62), slip, 1), "close and slow")
		t.ok(not BoatLogic.canDock(Vector3.new(15, 0, 62), slip, 20), "too fast")
		t.ok(not BoatLogic.canDock(Vector3.new(60, 0, 60), slip, 0), "too far")
	end)

	t.test("the dinghy goes alone; the Deep-V needs two aboard", function()
		t.ok((BoatLogic.canDrive("Dinghy", 1)), "dinghy solo")
		local ok, msg = BoatLogic.canDrive("DeepV", 1)
		t.ok(not ok and msg ~= nil, "Deep-V alone")
		t.ok((BoatLogic.canDrive("DeepV", 2)), "Deep-V with a friend")
	end)

	t.test("only the Deep-V goes into blue water", function()
		local ok, msg = BoatLogic.canEnterBlueWater("Dinghy")
		t.ok(not ok and msg ~= nil, "dinghy turned back")
		t.ok((BoatLogic.canEnterBlueWater("DeepV")), "Deep-V allowed")
	end)

	t.test("every boat's numbers make sense", function()
		for _, b in BoatData.list do
			t.ok(b.crew >= 1 and b.crew <= b.seats, b.id .. " crew and seats")
			t.ok(b.reverseSpeed < b.maxSpeed and b.price > 0, b.id .. " speed and price")
		end
		t.ok(BoatData.byId.Dinghy.price < BoatData.byId.DeepV.price, "dinghy first, then the big boat")
	end)
end
