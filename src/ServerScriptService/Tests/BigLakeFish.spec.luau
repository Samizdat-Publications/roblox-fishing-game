-- UNVERIFIED in Studio: written overnight 2026-11-26. Checks the Big Lake fish data and
-- that FishData now carries them (so FishLogic.biteWeights sees them), once each.
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
		local best, bestW = nil, 0
		for _, s in all do
			local w = weight(s, spot, period, bait)
			if w > bestW then
				best, bestW = s.id, w
			end
		end
		return best
	end

	-- Since the rarity retune (RARITY-DIRECTION.md) the commonest fish tops every spot and the
	-- rare ones bite beside it, so this checks each one bites where it should, and who leads.
	t.test("each Big Lake fish bites at its own spot, with a commoner fish leading", function()
		local function bites(id, spot, period, bait)
			for _, s in BigLake.list do
				if s.id == id then
					return weight(s, spot, period, bait) > 0
				end
			end
			return false
		end
		t.eq(top("Basin", "Dusk", "Spinner"), "WhiteBass", "basin at dusk")
		t.ok(bites("LakeTrout", "DropOff", "Dawn", "Minnow"), "lake trout at the drop-off at dawn")
		t.ok(bites("Muskellunge", "IslandPoint", "Dusk", "Spinner"), "muskie off the island point at dusk")
		t.eq(top("IslandPoint", "Dusk", "Spinner"), "WhiteBass", "white bass lead at the point")
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
			t.ok(FishData.byId[s.id] == s, "in FishData once: " .. s.id)
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

	t.test("no id appears twice in FishData", function()
		local seen = {}
		for _, s in FishData.list do
			t.ok(not seen[s.id], "twice: " .. s.id)
			seen[s.id] = true
		end
	end)

	t.test("the muskie is rare", function()
		t.ok(BigLake.byId.Muskellunge.rarity <= 0.15, "rarity")
	end)
end
