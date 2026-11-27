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

	t.test("saves from before v2 get reel assist turned back on", function()
		local d = Inventory.reconcile({ v = 1, coins = 21, assist = false, journal = { entries = {} } })
		t.eq(d.assist, true)
		t.ok(d.v >= 2, "version " .. d.v)
		d.assist = false
		local again = Inventory.reconcile(d)
		t.eq(again.assist, false, "a v2 save keeps the player's choice")
	end)

	t.test("rods: start with the Willow Rod, buy, equip, refuse what you can't", function()
		local RodData = require(Shared.RodData)
		local d = Inventory.new()
		t.eq(d.rod, "Willow")
		t.eq(d.rods.Willow, true)
		local price = RodData.byId.Fiberglass.price
		d.coins = price - 1
		t.eq(Inventory.buyRod(d, "Fiberglass"), false, "too poor")
		t.eq(d.coins, price - 1)
		d.coins = price + 80
		t.eq(Inventory.buyRod(d, "Fiberglass"), true)
		t.eq(d.coins, 80)
		t.eq(d.rod, "Fiberglass", "buying equips")
		t.eq(Inventory.buyRod(d, "Fiberglass"), false, "already owned")
		t.eq(Inventory.equipRod(d, "Graphite"), false, "not owned")
		t.eq(Inventory.equipRod(d, "Willow"), true)
		t.eq(d.rod, "Willow")
		local cat = require(Shared.FishData).byId.ChannelCatfish.fight
		local helped = RodData.applyFight(cat, "Graphite")
		t.ok(math.abs(helped.zone - cat.zone * 1.3) < 1e-6, "zone")
		t.ok(math.abs(helped.heavy - cat.heavy * 0.5) < 1e-6, "heavy")
		t.ok(cat.heavy == 0.6, "original untouched")
	end)

	t.test("v3 saves get the Willow Rod and no creek pass", function()
		local d = Inventory.reconcile({ v = 3, coins = 5, journal = { entries = {} } })
		t.ok(d.v >= 4, "version " .. d.v)
		t.eq(d.rod, "Willow")
		t.eq(d.rods.Willow, true)
		t.eq(d.creekPass, false)
	end)

	t.test("v4 saves become v5 with no boat; the snapshot shows boats", function()
		local d = Inventory.reconcile({ v = 4, coins = 5, journal = { entries = {} }, rods = { Willow = true }, rod = "Willow" })
		t.ok(d.v >= 5, "version " .. d.v)
		t.eq(next(d.boats), nil, "owns no boat")
		t.eq(d.boat, "")
		local snap = Inventory.snapshot(d)
		t.ok(type(snap.boats) == "table" and snap.boat == "", "snapshot")
		d.boats.Dinghy = true
		t.eq(snap.boats.Dinghy, nil, "snapshot is a copy")
	end)

	t.test("v5 saves become v6 with empty goals; the snapshot lists today's goals", function()
		local Goals = require(Shared.Goals)
		local d = Inventory.reconcile({ v = 5, coins = 5, journal = { entries = {} } })
		t.eq(d.v, Inventory.new().v) -- 6, then 7 for the Tackle Box (L3)
		t.eq(type(d.goals), "table")
		t.eq(#Inventory.snapshot(d).goals, 0, "no goals until the server fills them in")
		d.goals = Goals.ensure(d.goals, 20000, false)
		local snap = Inventory.snapshot(d)
		t.eq(#snap.goals, 3)
		t.ok(type(snap.goals[1].text) == "string" and snap.goals[1].progress == 0, "goal fields")
	end)

	t.test("trophies and monsters are counted per species for the journal", function()
		local d = Inventory.new()
		local base = { id = "Bluegill", name = "Bluegill", cm = 25, kg = 0.3, price = 9, bait = "Worm", spot = "Dock", period = "Day", at = 0 }
		Inventory.recordCatch(d, base)
		local t1 = table.clone(base)
		t1.sizeClass = "trophy"
		Inventory.recordCatch(d, t1)
		local m1 = table.clone(base)
		m1.sizeClass = "monster"
		Inventory.recordCatch(d, m1)
		local snap = Inventory.snapshot(d)
		t.eq(snap.trophies.Bluegill, 1)
		t.eq(snap.monsters.Bluegill, 1)
		t.eq(snap.counts.Bluegill, 3)
	end)

	t.test("reconcile fills gaps in old saves", function()
		local d = Inventory.reconcile({ coins = 99, journal = { entries = {} } })
		t.eq(d.coins, 99)
		t.eq(d.equipped, "Worm")
		t.ok(d.journal.bests ~= nil)
	end)
end
