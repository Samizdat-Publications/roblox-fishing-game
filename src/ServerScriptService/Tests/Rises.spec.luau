-- Rises (L2b): where a rise may come up, its timing, and who gets it.
-- Written 2026-11-26; UNVERIFIED in Studio until the L2 playtest.
return function(t, Shared)
	local Rises = require(Shared.Rises)
	local Cover = require(Shared.Cover)
	local Config = require(Shared.Config)
	local FishLogic = require(Shared.FishLogic)
	local WaterMap = require(Shared.WaterMap)

	t.test("the design numbers", function()
		t.eq(Rises.RISE_MIN, 14, "min gap")
		t.eq(Rises.RISE_MAX, 26, "max gap")
		t.eq(Rises.RISE_WINDOW, 8, "window")
		t.eq(Rises.RISE_RADIUS, 5, "radius")
		t.eq(Rises.RISE_BITE_MIN, 1.5, "bite min")
		t.eq(Rises.RISE_BITE_MAX, 3.5, "bite max")
	end)

	t.test("gaps and quick bites stay in their ranges", function()
		local rng = Random.new(3)
		for _ = 1, 300 do
			local g = Rises.nextGap(rng)
			t.ok(g >= 14 and g <= 26, "gap " .. g)
			local b = Rises.biteDelay(rng)
			t.ok(b >= 1.5 and b <= 3.5, "bite " .. b)
		end
	end)

	t.test("rises come up on the water in a fishing spot, never on cover; every lake and creek spot gets some", function()
		local zones = WaterMap.castZones()
		local waters = WaterMap.castWaters()
		local rng = Random.new(11)
		local seen = {}
		for _ = 1, 400 do
			local p, zone = Rises.pickPoint(rng, zones, waters)
			t.ok(p ~= nil and zone ~= nil, "picked a point")
			local q = p :: Vector3
			t.ok(FishLogic.isOnWaterAny(q, waters), "on water")
			t.ok(not Cover.onCover(q), "not on cover")
			t.eq(FishLogic.spotAt(q, zones), zone, "named by its spot")
			seen[zone :: string] = true
		end
		for _, name in { "Dock", "WeedBed", "Logs", "DeepHole", "Riffle", "Rocks", "Pool" } do
			t.ok(seen[name], "a rise at " .. name)
		end
		if not Config.BIG_LAKE_ON then
			t.ok(not seen.Basin and not seen.IslandPoint and not seen.DropOff, "no Big Lake rises while it's off")
		end
	end)

	t.test("a cast within 5 studs claims the rise once; farther, later or second casts don't", function()
		local list = { { pos = Vector3.new(0, 0.2, -20), zone = "DeepHole", untilT = 108 } }
		t.eq(Rises.claim(list, Vector3.new(15, 0.3, -20), 101, "far"), nil, "15 studs away")
		t.eq(Rises.claim(list, Vector3.new(3, 0.3, -24), 101, "a"), list[1], "5 studs away claims")
		t.eq(list[1].claimedBy, "a", "claimed by the first caster")
		t.eq(Rises.claim(list, Vector3.new(0, 0.3, -20), 102, "b"), nil, "one player per rise")
		local late = { { pos = Vector3.new(0, 0.2, -20), zone = "DeepHole", untilT = 108 } }
		t.eq(Rises.claim(late, Vector3.new(0, 0.3, -20), 108.5, "c"), nil, "window closed")
	end)

	t.test("the nearest open rise is the one claimed, and closed rises are pruned", function()
		local list = {
			{ pos = Vector3.new(0, 0.2, 0), zone = "DeepHole", untilT = 10 },
			{ pos = Vector3.new(4, 0.2, 0), zone = "DeepHole", untilT = 20 },
		}
		t.eq(Rises.claim(list, Vector3.new(3, 0.3, 0), 5, "x"), list[2], "nearest")
		Rises.prune(list, 15)
		t.eq(#list, 1, "pruned the closed one")
		t.eq(list[1].untilT, 20, "kept the open one")
	end)
end
