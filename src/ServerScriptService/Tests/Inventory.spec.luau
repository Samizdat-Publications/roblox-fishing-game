return function(t, Shared)
	local Inventory = require(Shared.Inventory)
	local Config = require(Shared.Config)

	local function fish(id, kg, price)
		return { id = id, name = id, cm = 20, kg = kg, price = price, bait = "Worm", spot = "Dock", period = "Day", at = 0 }
	end

	t.test("new player starts with coins and worms", function()
		local d = Inventory.new()
		t.eq(d.coins, Config.START_COINS)
		t.eq(d.bait.Worm, Config.START_WORMS)
		t.eq(d.equipped, "Worm")
	end)

	t.test("can't buy without coins", function()
		local d = Inventory.new()
		d.coins = 5
		local ok = Inventory.buy(d, "Minnow")
		t.eq(ok, false)
		t.eq(d.coins, 5)
	end)

	t.test("buying live bait adds a pack", function()
		local d = Inventory.new()
		local ok = Inventory.buy(d, "Cricket")
		t.eq(ok, true)
		t.eq(d.bait.Cricket, 10)
		t.eq(d.coins, Config.START_COINS - 12)
	end)

	t.test("a lure is bought once and never used up", function()
		local d = Inventory.new()
		d.coins = 500
		t.eq(Inventory.buy(d, "Spinner"), true)
		t.eq(Inventory.buy(d, "Spinner"), false)
		Inventory.consumeBait(d, "Spinner")
		t.ok(Inventory.hasBait(d, "Spinner"))
	end)

	t.test("live bait is used up", function()
		local d = Inventory.new()
		Inventory.consumeBait(d, "Worm")
		t.eq(d.bait.Worm, Config.START_WORMS - 1)
	end)

	t.test("selling empties the bag and pays", function()
		local d = Inventory.new()
		Inventory.recordCatch(d, fish("Bluegill", 0.2, 4))
		Inventory.recordCatch(d, fish("LargemouthBass", 1.5, 30))
		local coins, count = Inventory.sellAll(d)
		t.eq(coins, 34)
		t.eq(count, 2)
		t.eq(#d.bag, 0)
		t.eq(d.coins, Config.START_COINS + 34)
		t.eq(#d.journal.entries, 2, "journal keeps sold fish")
	end)

	t.test("personal bests by weight", function()
		local d = Inventory.new()
		t.eq(Inventory.recordCatch(d, fish("Bluegill", 0.2, 4)), true)
		t.eq(Inventory.recordCatch(d, fish("Bluegill", 0.1, 3)), false)
		t.eq(Inventory.recordCatch(d, fish("Bluegill", 0.3, 5)), true)
		t.eq(d.journal.counts.Bluegill, 3)
	end)

	t.test("free worms only when truly stuck", function()
		local d = Inventory.new()
		t.eq(Inventory.freeWormsIfStuck(d), false, "has worms")
		d.bait.Worm = 0
		d.coins = 50
		t.eq(Inventory.freeWormsIfStuck(d), false, "can afford")
		d.coins = 3
		t.eq(Inventory.freeWormsIfStuck(d), true, "stuck")
		t.eq(d.bait.Worm, Config.FREE_WORMS)
		d.bait.Worm = 0
		d.lures.Spinner = true
		t.eq(Inventory.freeWormsIfStuck(d), false, "has a lure")
	end)

	t.test("reconcile fills gaps in old saves", function()
		local d = Inventory.reconcile({ coins = 99, journal = { entries = {} } })
		t.eq(d.coins, 99)
		t.eq(d.equipped, "Worm")
		t.ok(d.journal.bests ~= nil)
	end)
end
