return function(t, Shared)
	local PondLogic = require(Shared.PondLogic)
	local Inventory = require(Shared.Inventory)
	local FishData = require(Shared.FishData)
	local Config = require(Shared.Config)
	local HOUR = 3600

	local function pondFish(id, cm)
		local f = { id = id, name = FishData.byId[id].name, cm = cm, kg = 0, price = 0, bornHere = false }
		PondLogic.grow(f, FishData.byId[id], 0)
		return f
	end

	local function bagFish(id, cm)
		return { id = id, name = id, cm = cm, kg = 0.1, price = 3, bait = "Worm", spot = "Dock", period = "Day", at = 0 }
	end

	t.test("an hour closes 30 percent of the gap to full size", function()
		local f = pondFish("Bluegill", 20)
		local before = f.price
		PondLogic.grow(f, FishData.byId.Bluegill, 1)
		t.ok(math.abs(f.cm - 21.5) < 0.1, "cm " .. f.cm)
		t.ok(f.price >= before, "price should not drop")
		t.ok(f.kg > 0, "kg")
	end)

	t.test("fish never grow past their species maximum", function()
		local f = pondFish("Bluegill", 20)
		PondLogic.grow(f, FishData.byId.Bluegill, 100)
		t.ok(f.cm <= 25, "cm " .. f.cm)
	end)

	t.test("negative time changes nothing", function()
		local pond = { fish = { pondFish("Bluegill", 20) }, lastTick = 0, capacity = Config.POND_CAPACITY }
		PondLogic.tick(pond, -500, Random.new(1))
		t.eq(pond.fish[1].cm, 20)
	end)

	t.test("a week away counts as eight hours", function()
		local a = { fish = { pondFish("Bluegill", 14) }, lastTick = 0, capacity = Config.POND_CAPACITY }
		local b = { fish = { pondFish("Bluegill", 14) }, lastTick = 0, capacity = Config.POND_CAPACITY }
		PondLogic.tick(a, 7 * 24 * HOUR, Random.new(3))
		PondLogic.tick(b, 8 * HOUR, Random.new(3))
		t.eq(a.fish[1].cm, b.fish[1].cm)
		t.eq(#a.fish, #b.fish)
	end)

	t.test("two grown fish breed, but never past capacity", function()
		local pond = { fish = { pondFish("Bluegill", 24), pondFish("Bluegill", 24) }, lastTick = 0, capacity = 3 }
		local born = PondLogic.tick(pond, 8 * HOUR, Random.new(7))
		t.ok(#born >= 1, "expected a birth")
		t.ok(#pond.fish <= 3, "over capacity: " .. #pond.fish)
		local young = pond.fish[3]
		t.ok(young.bornHere, "young fish marked")
	end)

	t.test("a single fish never breeds", function()
		local pond = { fish = { pondFish("Bluegill", 24) }, lastTick = 0, capacity = 6 }
		local born = PondLogic.tick(pond, 8 * HOUR, Random.new(7))
		t.eq(#born, 0)
		t.eq(#pond.fish, 1)
	end)

	t.test("keep moves a bag fish into the pond, refuses when full", function()
		local d = Inventory.new()
		table.insert(d.bag, bagFish("Bluegill", 18))
		local ok = PondLogic.keep(d, 1)
		t.eq(ok, true)
		t.eq(#d.bag, 0)
		t.eq(#d.pond.fish, 1)
		d.pond.capacity = 1
		table.insert(d.bag, bagFish("Pumpkinseed", 15))
		local ok2, msg = PondLogic.keep(d, 1)
		t.eq(ok2, false, msg)
		t.eq(#d.bag, 1, "fish stays in the bag")
	end)

	t.test("sell pays once, bad index fails", function()
		local d = Inventory.new()
		d.pond.fish = { pondFish("LargemouthBass", 50) }
		local coins0 = d.coins
		local ok, _, paid = PondLogic.sell(d, 1)
		t.eq(ok, true)
		t.ok(paid > 0, "paid")
		t.eq(d.coins, coins0 + paid)
		local ok2 = PondLogic.sell(d, 1)
		t.eq(ok2, false, "second sell of the same slot")
		t.eq(d.coins, coins0 + paid)
		t.eq(PondLogic.release(d, 5), false)
	end)

	t.test("old saves get an empty pond", function()
		local d = Inventory.reconcile({ v = 2, coins = 10, journal = { entries = {} } })
		t.ok(d.v >= 3, "version " .. d.v)
		t.ok(d.pond ~= nil and #d.pond.fish == 0, "pond")
		t.eq(d.pond.capacity, Config.POND_CAPACITY)
	end)
end
