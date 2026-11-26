-- UNVERIFIED in Studio: written overnight 2026-11-26. Checks the Big Lake fish data on its
-- own (they are not in FishData.list yet, so FishLogic.biteWeights can't see them).
return function(t, Shared)
	local BigLake = require(Shared.BigLakeFishData)
	local FishData = require(Shared.FishData)
	local BaitData = require(Shared.BaitData)

	local function weight(s, spot, period, bait)
		return s.rarity * (s.spots[spot] or 0) * (s.periods[period] or 0) * (s.baits[bait] or 0)
	end

	local function top(spot, period, bait)
		local all = {}
		for _, s in FishData.list do
			table.insert(all, s)
		end
		for _, s in BigLake.list do
			table.insert(all, s)
		end
		local best, bestW = nil, 0
		for _, s in all do
			local w = weight(s, spot, period, bait)
			if w > bestW then
				best, bestW = s.id, w
			end
		end
		return best
	end

	t.test("each Big Lake fish tops its own spot", function()
		t.eq(top("Basin", "Dusk", "Spinner"), "WhiteBass", "basin at dusk")
		t.eq(top("DropOff", "Dawn", "Minnow"), "LakeTrout", "drop-off at dawn")
		t.eq(top("IslandPoint", "Dusk", "Spinner"), "Muskellunge", "island point at dusk")
	end)

	t.test("Big Lake fish never bite in the lake or the creek", function()
		local spots = { "Dock", "WeedBed", "Logs", "DeepHole", "OpenWater", "Riffle", "Rocks", "Pool" }
		for _, s in BigLake.list do
			for _, spot in spots do
				t.eq(s.spots[spot], nil, s.id .. " at " .. spot)
			end
		end
	end)

	t.test("ids are new, baits exist, sizes and fights are sane", function()
		for _, s in BigLake.list do
			t.eq(FishData.byId[s.id], nil, "clashes with " .. s.id)
			for bait in s.baits do
				t.ok(BaitData.byId[bait] ~= nil, s.id .. " unknown bait " .. bait)
			end
			t.ok(s.minCm < s.maxCm and s.basePrice > 0, s.id .. " size or price")
			t.ok(s.fight.zone > 0.2 and s.fight.gain > 0.1, s.id .. " fight")
			t.ok(BigLake.spotNames ~= nil, "spot names")
			for spot in s.spots do
				t.ok(BigLake.spotNames[spot] ~= nil, s.id .. " unnamed spot " .. spot)
			end
		end
	end)

	t.test("the muskie is rare", function()
		t.ok(BigLake.byId.Muskellunge.rarity <= 0.15, "rarity")
	end)
end
