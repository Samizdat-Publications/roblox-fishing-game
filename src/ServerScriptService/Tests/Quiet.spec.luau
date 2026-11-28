-- Quiet approach (leg 3, N4, Config.QUIET_APPROACH_ON). Written 11/27/2026; UNVERIFIED in Studio.
return function(t, Shared)
	local Quiet = require(Shared.Quiet)
	local FishData = require(Shared.FishData)

	-- Drive a boat `studs` along +X at `speed` with `throttle`, then stop at `now`.
	local function trip(st, boatId, throttle, speed, studs, from, now)
		local x = from.X
		local step = speed / 10
		local moved = 0
		while moved < studs do
			x += step
			moved += step
			Quiet.step(st, boatId, throttle, speed, step, Vector3.new(x, 0, from.Z), now)
		end
		local at = Vector3.new(x, 0, from.Z)
		Quiet.step(st, boatId, 0, 0, 0, at, now)
		return at
	end

	t.test("wary fish: trout, muskie, pike, sturgeon, and Rare-or-better marked wary", function()
		local by = FishData.byId
		for _, id in { "RainbowTrout", "BrookTrout", "BrownTrout", "NorthernPike", "LakeSturgeon" } do
			t.ok(Quiet.isWary(by[id]), id)
		end
		if by.Muskellunge then
			t.ok(Quiet.isWary(by.Muskellunge), "muskie")
		end
		for _, id in { "Bluegill", "LargemouthBass", "ChannelCatfish", "YellowPerch" } do
			t.ok(not Quiet.isWary(by[id]), id .. " is not wary")
		end
		t.ok(Quiet.isWary({ id = "Ghost", tier = "Epic", wary = true }), "an Epic marked wary")
		t.ok(not Quiet.isWary({ id = "Shy", tier = "Uncommon", wary = true }), "marked, but not Rare")
		t.ok(not Quiet.isWary(nil), "nothing")
	end)

	t.test("paddling in is a quiet arrival for a minute, at that spot", function()
		local st = Quiet.new()
		local at = trip(st, "Canoe", 1, 7, 40, Vector3.zero, 100)
		t.ok(Quiet.active(st, 100, at), "quiet on arrival")
		t.ok(Quiet.active(st, 159, at), "still at 59 s")
		t.ok(not Quiet.active(st, 161, at), "over after a minute")
		t.ok(not Quiet.active(st, 120, at + Vector3.new(30, 0, 0)), "not 30 studs away")
	end)

	t.test("motoring in at full throttle is a normal arrival (no penalty, just no bonus)", function()
		local st = Quiet.new()
		local at = trip(st, "Dinghy", 1, 12, 60, Vector3.zero, 10)
		t.ok(not Quiet.active(st, 10, at), "not quiet")
	end)

	t.test("gliding the last 25 studs at idle makes a motor arrival quiet", function()
		local st = Quiet.new()
		local mid = trip(st, "Dinghy", 1, 12, 60, Vector3.zero, 0)
		-- From the stop, idle on (a quarter throttle is 3 studs a second) for 30 studs.
		local at = trip(st, "Dinghy", 0.25, 3, 30, mid, 50)
		t.ok(Quiet.active(st, 50, at), "quiet after 30 idle studs")
		local st2 = Quiet.new()
		local x = 0
		for _ = 1, 50 do -- full throttle, then only 12 idle studs before stopping
			x += 1
			Quiet.step(st2, "Dinghy", 1, 12, 1, Vector3.new(x, 0, 0), 0)
		end
		for _ = 1, 12 do
			x += 1
			Quiet.step(st2, "Dinghy", 0.2, 3, 1, Vector3.new(x, 0, 0), 0)
		end
		Quiet.step(st2, "Dinghy", 0, 0, 0, Vector3.new(x, 0, 0), 0)
		t.ok(not Quiet.active(st2, 0, Vector3.new(x, 0, 0)), "12 idle studs are not enough")
	end)

	t.test("a nudge at the spot keeps the arrival; a new trip replaces it", function()
		local st = Quiet.new()
		local at = trip(st, "Canoe", 1, 7, 40, Vector3.zero, 0)
		local nudged = trip(st, "Canoe", 1, 7, 5, at, 10)
		t.ok(Quiet.active(st, 10, nudged), "a 5 stud nudge is still the same quiet arrival")
		local far = trip(st, "Dinghy", 1, 12, 60, nudged, 20)
		t.ok(not Quiet.active(st, 20, far), "motoring to a new spot is a new, normal arrival")
	end)

	t.test("the boost makes wary fish 1.25 times as likely and leaves the rest", function()
		local w = { { id = "Bluegill", w = 1 }, { id = "RainbowTrout", w = 0.4 } }
		local b = Quiet.boost(w, FishData.byId)
		local by = {}
		for _, x in b do
			by[x.id] = x.w
		end
		t.ok(math.abs(by.RainbowTrout - 0.5) < 1e-9, "trout x1.25")
		t.eq(by.Bluegill, 1, "bluegill unchanged")
		t.ok(math.abs(Quiet.waryShare(w, FishData.byId) - 0.4 / 1.4) < 1e-9, "share before")
		t.ok(Quiet.waryShare(b, FishData.byId) > Quiet.waryShare(w, FishData.byId), "share up")
		t.eq(Quiet.waryShare({}, FishData.byId), 0, "empty")
	end)

	t.test("the tally counts casts and wary bites each way, for the playtest log", function()
		local tl = Quiet.newTally()
		Quiet.countCast(tl, true)
		Quiet.countBite(tl, true, true)
		Quiet.countCast(tl, false)
		Quiet.countBite(tl, false, false)
		t.eq(tl.quietCasts, 1)
		t.eq(tl.quietWary, 1)
		t.eq(tl.loudBites, 1)
		t.eq(tl.loudWary, 0)
		t.ok(string.find(Quiet.tallyText(tl), "100%", 1, true) ~= nil, Quiet.tallyText(tl))
	end)
end
