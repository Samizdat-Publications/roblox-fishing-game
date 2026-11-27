-- Cover and snags (L2b): tight-to-cover landings, snags on logs and in the weed core, the
-- wiggle and what a snag costs. Written 2026-11-26; UNVERIFIED in Studio until the L2 playtest.
return function(t, Shared)
	local Cover = require(Shared.Cover)
	local FishData = require(Shared.FishData)
	local FishLogic = require(Shared.FishLogic)
	local WaterMap = require(Shared.WaterMap)

	local function kinds()
		local n = {}
		for _, f in Cover.features do
			n[f.kind] = (n[f.kind] or 0) + 1
		end
		return n
	end

	local function firstOf(kind: string)
		for _, f in Cover.features do
			if f.kind == kind then
				return f
			end
		end
		error("no " .. kind)
	end

	-- A point `out` studs off a box feature's long side (its local +Z face).
	local function offSide(f, out: number): Vector3
		local half = f.half :: Vector3
		return f.cframe:PointToWorldSpace(Vector3.new(0, 0, half.Z + out))
	end

	t.test("the design numbers", function()
		t.eq(Cover.COVER_RANGE, 4, "range")
		t.eq(Cover.COVER_DELAY, 1, "delay (cover brings better fish, not faster bites)")
		t.eq(Cover.COVER_WEIGHT, 1.25, "weight")
		t.eq(Cover.SNAG_WIGGLES, 4, "wiggles")
		t.eq(Cover.SNAG_TIME, 8, "time")
		t.eq(Cover.SNAG_BAIT_LOSS, 0.35, "bait loss")
		t.eq(Cover.WIGGLE_GAP, 0.12, "wiggle gap")
	end)

	t.test("cover matches the world: 5 logs, the dock's 2 decks, the weed core, 5 boulders", function()
		local n = kinds()
		t.eq(n.Log, 5, "logs")
		t.eq(n.Dock, 2, "dock")
		t.eq(n.Weeds, 1, "weeds")
		t.eq(n.Boulder, 5, "boulders")
	end)

	t.test("every cover feature sits in its own fishing spot, on the water", function()
		local zones = WaterMap.zones()
		local waters = WaterMap.waters()
		local want = { Log = "Logs", Dock = "Dock", Weeds = "WeedBed", Boulder = "Rocks" }
		for _, f in Cover.features do
			local c = f.cframe.Position
			t.eq(FishLogic.spotAt(c, zones), want[f.kind], f.kind .. " at " .. tostring(c))
			t.ok(FishLogic.isOnWaterAny(c, waters), f.kind .. " on water")
		end
	end)

	t.test("every cover-loving species is a real fish", function()
		for id in Cover.COVER_SPECIES do
			t.ok(FishData.byId[id] ~= nil, id)
		end
	end)

	t.test("landing on a log snags with any bait, the plastic worm too", function()
		for _, f in Cover.features do
			if f.kind == "Log" then
				local c = f.cframe.Position
				t.ok(Cover.snagAt(c, "Worm"), "worm on log")
				t.ok(Cover.snagAt(c, "PlasticWorm"), "plastic worm on log")
				t.ok(Cover.snagAt(c, "Spinner"), "spinner on log")
				t.ok(not Cover.tightAt(c, "Worm"), "on the log is not tight to it")
				-- Touching the wood (inside the small margin) still snags.
				t.ok(Cover.snagAt(offSide(f, Cover.SNAG_MARGIN * 0.5), "Worm"), "touching")
			end
		end
	end)

	t.test("2 studs off a log is tight to cover and doesn't snag; 6 studs off is open water", function()
		local log = firstOf("Log")
		local near = offSide(log, 2)
		t.ok(not Cover.snagAt(near, "Worm"), "no snag")
		t.ok(Cover.tightAt(near, "Worm"), "tight")
		local kind, d = Cover.coverAt(near)
		t.eq(kind, "Log", "kind")
		t.ok(math.abs((d :: number) - 2) < 1e-4, "distance 2")
		local far = offSide(log, 6)
		t.ok(not Cover.tightAt(far, "Worm"), "6 studs is not tight")
		t.eq((Cover.coverAt(far)), nil, "no cover within range")
		t.ok(Cover.tightAt(offSide(log, 3.9), "Worm"), "3.9 studs still tight")
	end)

	t.test("the weed core snags anything but the weedless plastic worm; its edge is cover", function()
		local core = Vector3.new(Cover.WEED_CORE.x, 0.3, Cover.WEED_CORE.z)
		t.ok(Cover.snagAt(core, "Worm"), "worm snags")
		t.ok(Cover.snagAt(core, "Spinner"), "spinner snags")
		t.ok(not Cover.snagAt(core, "PlasticWorm"), "plastic worm is weedless")
		t.ok(Cover.tightAt(core, "PlasticWorm"), "plastic worm in the weeds is fishing cover")
		local edge = Vector3.new(Cover.WEED_CORE.x + Cover.WEED_CORE.hx + 2, 0.3, Cover.WEED_CORE.z)
		t.ok(not Cover.snagAt(edge, "Worm"), "edge doesn't snag")
		t.ok(Cover.tightAt(edge, "Worm"), "edge is tight to cover")
		local outer = Vector3.new(Cover.WEED_CORE.x + Cover.WEED_CORE.hx + 8, 0.3, Cover.WEED_CORE.z)
		t.ok(not Cover.tightAt(outer, "Worm"), "the outer weed bed is not tight")
	end)

	t.test("the dock's edge and the creek boulders are cover, but never snag", function()
		t.ok(Cover.tightAt(Vector3.new(6, 0.3, 60), "Worm"), "2 studs off the deck")
		t.ok(not Cover.snagAt(Vector3.new(6, 0.3, 60), "Worm"), "dock no snag")
		t.ok(not Cover.tightAt(Vector3.new(0, 0.3, 60), "Worm"), "on the deck is not tight")
		t.ok(not Cover.snagAt(Vector3.new(0, 0.3, 60), "Worm"), "on the deck no snag")
		t.ok(Cover.tightAt(Vector3.new(-233 + 3.5 + 2, 0.3, -2), "Worm"), "2 studs off a boulder")
		t.ok(not Cover.snagAt(Vector3.new(-233, 0.3, -2), "Worm"), "boulder no snag")
		t.ok(not Cover.tightAt(Vector3.new(0, 0.3, -22), "Worm"), "the deep hole is open water")
		t.eq((Cover.coverAt(Vector3.new(0, 0.3, -22))), nil, "no cover in the deep hole")
	end)

	t.test("applyCover: cover fish weigh COVER_WEIGHT times more, others unchanged, heaviest first", function()
		local w = { { id = "Bluegill", w = 1 }, { id = "LargemouthBass", w = 0.9 }, { id = "YellowPerch", w = 0.5 } }
		t.eq(Cover.applyCover(w, false), w, "not tight: unchanged")
		local c = Cover.applyCover(w, true)
		t.eq(c[1].id, "LargemouthBass", "bass first now")
		t.ok(math.abs(c[1].w - 0.9 * Cover.COVER_WEIGHT) < 1e-9, "bass x COVER_WEIGHT")
		t.eq(c[2].id, "Bluegill", "bluegill second")
		t.eq(c[2].w, 1, "bluegill unchanged")
		t.eq(c[3].w, 0.5, "perch unchanged")
		t.eq(w[2].w, 0.9, "input untouched")
		t.eq(Cover.adjustDelay(8, true), 8 * Cover.COVER_DELAY, "delay x COVER_DELAY")
		t.eq(Cover.adjustDelay(8, false), 8, "no change in open water")
	end)

	t.test("tight to cover bites sooner than open water at the same spot", function()
		for _, bait in { "Minnow", "Worm", "PlasticWorm" } do
			local base = FishLogic.biteWeights("Logs", "Dusk", bait)
			if #base > 0 then
				local covered = Cover.applyCover(base, true)
				local function mean(ws)
					local rng = Random.new(7)
					local sum = 0
					for _ = 1, 200 do
						sum += FishLogic.biteDelay(ws, rng) :: number
					end
					return sum / 200
				end
				local open = mean(base)
				local tight = Cover.adjustDelay(mean(covered), true)
				t.ok(tight < open, bait .. string.format(": %.2f < %.2f", tight, open))
			end
		end
	end)

	t.test("the wiggle: 4 presses inside 8 s free it, fast repeats are ignored, late is too late", function()
		local s = Cover.newSnag(100)
		t.eq(Cover.wiggle(s, 100.5), "counted", "1")
		t.eq(Cover.wiggle(s, 100.55), "ignored", "too fast")
		t.eq(Cover.wiggle(s, 100.8), "counted", "2")
		t.eq(Cover.wiggle(s, 101.1), "counted", "3")
		t.eq(Cover.wiggle(s, 101.4), "freed", "4")
		local late = Cover.newSnag(0)
		t.eq(Cover.wiggle(late, 2), "counted", "early press")
		t.eq(Cover.wiggle(late, 8.1), "expired", "after 8 s")
	end)

	t.test("snag costs: a lure never, live bait always on a snap, 35 percent when freed", function()
		t.eq(Cover.losesBait("lure", false, 0), false, "lure on a snap")
		t.eq(Cover.losesBait("lure", true, 0), false, "lure freed")
		t.eq(Cover.losesBait("live", false, 0.99), true, "live on a snap")
		t.eq(Cover.losesBait("live", true, 0.34), true, "live freed, unlucky")
		t.eq(Cover.losesBait("live", true, 0.36), false, "live freed, lucky")
		t.eq(Cover.losesBait(nil, false, 0), false, "unknown bait")
	end)
end
