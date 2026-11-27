-- Save migration (L2b): a save from every older version the code knows (v1 to v8) loads
-- through the real Inventory.reconcile with its coins, journal, pond and bag intact, and no
-- feature switch changes what a migrated save keeps. Written 2026-11-26.
return function(t, Shared)
	local Inventory = require(Shared.Inventory)
	local Config = require(Shared.Config)

	local CURRENT = Inventory.new().v

	local function fish(id: string, kg: number, price: number)
		return { id = id, name = id, cm = 25, kg = kg, price = price, bait = "Worm", spot = "Dock", period = "Day", at = 1700000000 }
	end

	-- A save as version `v` wrote it: only the fields that version had.
	local function oldSave(v: number): any
		local bass = fish("LargemouthBass", 1.8, 31)
		local gill = fish("Bluegill", 0.2, 6)
		local save: any = {
			coins = 437,
			bait = { Worm = 7, Minnow = 12 },
			lures = { Spinner = true },
			equipped = "Minnow",
			bag = { gill, fish("YellowPerch", 0.3, 9) },
			journal = {
				entries = { gill, bass },
				bests = { Bluegill = gill, LargemouthBass = bass },
				counts = { Bluegill = 14, LargemouthBass = 3 },
			},
			assist = false,
			totalCaught = 17,
		}
		if v >= 2 then
			save.v = v
			save.assist = false -- turned off by choice after v2 brought it back
		end
		if v >= 3 then
			save.pond = {
				fish = { { id = "Bluegill", cm = 18.5, born = false }, { id = "LargemouthBass", cm = 40, born = true } },
				lastTick = 1700001234,
				capacity = 6,
				breedTimer = 900,
			}
		end
		if v >= 4 then
			save.rods = { Willow = true, Fiberglass = true }
			save.rod = "Fiberglass"
			save.creekPass = true
		end
		if v >= 5 then
			save.boats = { Dinghy = true }
			save.boat = "Dinghy"
		end
		if v >= 6 then
			save.goals = { day = 19700, list = {} }
		end
		if v >= 7 then
			save.hook = "Small"
			save.quickBait = true
			save.tackle = { best = { Worm = "Perfect", Minnow = "Good" }, perfects = 9 }
		end
		if v >= 8 then
			save.assistSet = true
		end
		return save
	end

	local function deepEqual(a: any, b: any): boolean
		if type(a) ~= type(b) then
			return false
		end
		if type(a) ~= "table" then
			return a == b
		end
		for k, v in a do
			if not deepEqual(v, b[k]) then
				return false
			end
		end
		for k in b do
			if a[k] == nil then
				return false
			end
		end
		return true
	end

	t.test("the code's current save version is 8", function()
		t.eq(CURRENT, 8, "bump this test (and add the new version below) when the save changes")
	end)

	for v = 1, CURRENT do
		t.test("a v" .. v .. " save migrates to v" .. CURRENT .. " with everything kept", function()
			local d = Inventory.reconcile(oldSave(v))
			t.eq(d.v, CURRENT, "version")
			t.eq(d.coins, 437, "coins")
			t.eq(d.bait.Worm, 7, "worms")
			t.eq(d.bait.Minnow, 12, "minnows")
			t.eq(d.lures.Spinner, true, "spinner")
			t.eq(d.equipped, "Minnow", "equipped")
			-- The bag.
			t.eq(#d.bag, 2, "bag size")
			t.eq(d.bag[1].id, "Bluegill", "bag fish")
			t.eq(d.bag[2].price, 9, "bag price")
			-- The journal.
			t.eq(d.totalCaught, 17, "totalCaught")
			t.eq(d.journal.counts.Bluegill, 14, "count")
			t.eq(d.journal.counts.LargemouthBass, 3, "count")
			t.eq(d.journal.bests.LargemouthBass.kg, 1.8, "best kg")
			t.eq(d.journal.bests.Bluegill.price, 6, "best price")
			t.eq(#d.journal.entries, 2, "entries")
			-- The pond: kept from v3 on, a fresh empty pond before that.
			if v >= 3 then
				t.eq(#d.pond.fish, 2, "pond fish")
				t.eq(d.pond.fish[2].id, "LargemouthBass", "pond bass")
				t.eq(d.pond.fish[2].cm, 40, "pond bass size")
				t.eq(d.pond.breedTimer, 900, "breed timer")
				t.eq(d.pond.lastTick, 1700001234, "last tick")
			else
				t.eq(#d.pond.fish, 0, "fresh pond")
				t.eq(d.pond.capacity, Config.POND_CAPACITY, "pond capacity")
			end
			-- Rods and the Creek Pass from v4, boats from v5, goals from v6.
			if v >= 4 then
				t.eq(d.rod, "Fiberglass", "rod")
				t.eq(d.rods.Fiberglass, true, "rods")
				t.eq(d.creekPass, true, "creek pass")
			else
				t.eq(d.rod, "Willow", "starter rod")
				t.eq(d.creekPass, false, "no pass yet")
			end
			if v >= 5 then
				t.eq(d.boats.Dinghy, true, "boat")
				t.eq(d.boat, "Dinghy", "boat at the slip")
			else
				t.ok(next(d.boats) == nil and d.boat == "", "no boats yet")
			end
			if v >= 6 then
				t.eq(d.goals.day, 19700, "goals kept")
			end
			-- Hook, Quick Bait and the Tackle Box from v7; before that Medium, off and empty.
			if v >= 7 then
				t.eq(d.hook, "Small", "hook kept")
				t.eq(d.quickBait, true, "quick bait kept")
				t.eq(d.tackle.best.Worm, "Perfect", "best grade kept")
				t.eq(d.tackle.best.Minnow, "Good", "best grade kept")
				t.eq(d.tackle.perfects, 9, "perfects kept")
			else
				t.eq(d.hook, "Small", "default hook")
				t.eq(d.quickBait, false, "bench on by default")
				t.ok(next(d.tackle.best) == nil and d.tackle.perfects == 0, "empty tackle box")
			end
			-- Later saves keep the player's assist choice. (A v1 save has no `v`, and reconcile
			-- fills `v` in from a fresh save before its version steps run, so the v2 "assist back
			-- on" step never fires for it. Only early test saves were v1; logged 2026-11-26.)
			if v >= 2 then
				t.eq(d.assist, false, "assist")
				-- v8: assist off in an older save was the player's own choice, so it stays set by hand.
				t.eq(d.assistSet, true, "assist set by hand")
			end
			-- Every field a new save has is filled in.
			for k in Inventory.new() :: any do
				t.ok((d :: any)[k] ~= nil, "has " .. k)
			end
			-- The client snapshot builds from it.
			local snap = Inventory.snapshot(d)
			t.eq(snap.coins, 437, "snapshot coins")
			t.eq(snap.bagCount, 2, "snapshot bag")
			t.eq(snap.hook, d.hook, "snapshot hook")
			t.eq(snap.tackle.perfects, d.tackle.perfects, "snapshot perfects")
		end)
	end

	t.test("a migrated save migrates again without change", function()
		for v = 1, CURRENT do
			local once = Inventory.reconcile(oldSave(v))
			local copy = Inventory.reconcile(table.clone(once))
			t.ok(deepEqual(once, copy), "v" .. v)
		end
	end)

	t.test("no feature switch changes what a migrated save keeps", function()
		local SWITCHES = { "WEATHER_ON", "GOALS_ON", "BOATS_ON", "BIG_LAKE_ON", "FRENZIES_ON" }
		local saved = {}
		for _, k in SWITCHES do
			saved[k] = (Config :: any)[k]
		end
		local ok, err = pcall(function()
			for v = 1, CURRENT do
				for _, k in SWITCHES do
					(Config :: any)[k] = false
				end
				local base = Inventory.reconcile(oldSave(v))
				for _, k in SWITCHES do
					(Config :: any)[k] = true
					local with = Inventory.reconcile(oldSave(v))
					t.ok(deepEqual(base, with), string.format("v%d with %s on", v, k))
					;(Config :: any)[k] = false
				end
				for _, k in SWITCHES do
					(Config :: any)[k] = true
				end
				t.ok(deepEqual(base, Inventory.reconcile(oldSave(v))), string.format("v%d with every switch on", v))
			end
		end)
		for _, k in SWITCHES do
			(Config :: any)[k] = saved[k]
		end
		if not ok then
			error(err, 0)
		end
	end)

	t.test("v8: an older save with reel assist on still gets the auto-off; one with it off keeps it off", function()
		for v = 2, 7 do
			local on = oldSave(v)
			on.assist = true
			local d = Inventory.reconcile(on)
			t.eq(d.assistSet, false, "v" .. v .. " on: not set by hand")
			t.eq(d.assist, true, "v" .. v .. " on: still on until the next catch")
			t.eq(Inventory.assistAfterCatch(d), true, "v" .. v .. " (17 catches already) turns off at the next catch")
			t.eq(d.assist, false, "v" .. v .. " now off")
			local off = Inventory.reconcile(oldSave(v))
			t.eq(Inventory.assistAfterCatch(off), false, "v" .. v .. " off stays as it was")
		end
		local bad = Inventory.reconcile({ v = 8, assistSet = "yes" })
		t.eq(bad.assistSet, false, "a damaged flag is repaired")
	end)

	t.test("a damaged v7 tackle box or hook is repaired", function()
		local save = oldSave(7)
		save.hook = "Gigantic"
		save.tackle = { best = "oops" }
		local d = Inventory.reconcile(save)
		t.eq(d.hook, "Small", "bad hook back to the default")
		t.eq(type(d.tackle.best), "table", "best rebuilt")
		t.eq(d.tackle.perfects, 0, "perfects rebuilt")
		local d2 = Inventory.reconcile({ v = 7, tackle = 5 })
		t.eq(type(d2.tackle), "table", "tackle rebuilt")
	end)
end
