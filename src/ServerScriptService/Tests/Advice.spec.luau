-- The "nothing wants this" hint names a better choice (L2b).
-- Written 2026-11-26; UNVERIFIED in Studio until the L2 playtest.
return function(t, Shared)
	local Advice = require(Shared.Advice)
	local BaitData = require(Shared.BaitData)
	local FishLogic = require(Shared.FishLogic)

	local ALL_BAIT = {}
	for _, b in BaitData.list do
		table.insert(ALL_BAIT, b.id)
	end
	local PERIODS = { "Dawn", "Day", "Dusk", "Night" }

	-- Every (spot, period, bait) where nothing bites, over the lake and creek.
	local function emptyCombos()
		local out = {}
		for _, spot in { "Dock", "WeedBed", "Logs", "DeepHole", "Riffle", "Rocks", "Pool" } do
			for _, period in PERIODS do
				for _, bait in ALL_BAIT do
					if #FishLogic.biteWeights(spot, period, bait) == 0 then
						table.insert(out, { spot = spot, period = period, bait = bait })
					end
				end
			end
		end
		return out
	end

	t.test("bait words a kid reads", function()
		t.eq(Advice.baitWords("Worm"), "worms", "worms")
		t.eq(Advice.baitWords("Minnow"), "minnows", "minnows")
		t.eq(Advice.baitWords("Spinner"), "a spinner", "lure")
		t.eq(Advice.baitWords("PlasticWorm"), "a plastic worm", "lure")
		t.eq(Advice.baitWords("Nope"), "that", "unknown")
	end)

	t.test("reachable spots: the lake always, the creek only with the pass, no Big Lake while boats are off", function()
		local lake = Advice.reachableSpots(false, {})
		t.eq(#lake, 4, "lake only")
		t.ok(table.find(lake, "Riffle") == nil, "no creek without the pass")
		local both = Advice.reachableSpots(true, { DeepV = true })
		t.ok(table.find(both, "Pool") ~= nil, "creek with the pass")
		t.ok(table.find(both, "Basin") == nil, "no Big Lake while boats are switched off")
	end)

	t.test("there are empty combos to give advice for", function()
		t.ok(#emptyCombos() > 0, "some bait at some spot and time gets nothing")
	end)

	t.test("every empty combo: the suggested bait and spot really get bites, and the text is short", function()
		local spots = Advice.reachableSpots(true, {})
		for _, c in emptyCombos() do
			local label = c.spot .. "/" .. c.period .. "/" .. c.bait
			local bait = Advice.bestBait(c.spot, c.period, ALL_BAIT, c.bait)
			if bait then
				t.ok(bait ~= c.bait, label .. " suggests a different bait")
				t.ok(#FishLogic.biteWeights(c.spot, c.period, bait) > 0, label .. " suggested bait bites")
				-- It's the best one: no owned bait beats it here.
				for _, other in ALL_BAIT do
					if other ~= c.bait then
						t.ok(Advice.total(c.spot, c.period, other) <= Advice.total(c.spot, c.period, bait) + 1e-9, label .. " best bait")
					end
				end
			end
			local where = Advice.bestSpot(c.bait, c.period, spots, c.spot)
			if where then
				t.ok(where ~= c.spot, label .. " suggests a different spot")
				t.ok(#FishLogic.biteWeights(where, c.period, c.bait) > 0, label .. " suggested spot bites")
			end
			local text = Advice.nothingText(c.spot, c.period, c.bait, ALL_BAIT, spots)
			t.ok(#text <= 120, label .. " short: " .. text)
			t.ok(text:find("^Nothing wants ") ~= nil, label .. " starts plainly")
			t.ok(text:find("\u{2014}") == nil, label .. " no em dash")
		end
	end)

	t.test("names the better bait here and the better spot for this bait", function()
		local c = emptyCombos()[1]
		local spots = Advice.reachableSpots(true, {})
		local bait = Advice.bestBait(c.spot, c.period, ALL_BAIT, c.bait)
		local where = Advice.bestSpot(c.bait, c.period, spots, c.spot)
		local text = Advice.nothingText(c.spot, c.period, c.bait, ALL_BAIT, spots)
		if bait then
			t.ok(text:find(Advice.baitWords(bait) .. " here", 1, true) ~= nil, "bait named: " .. text)
		end
		if where then
			t.ok(text:find(FishLogic.SPOT_NAMES[where], 1, true) ~= nil, "spot named: " .. text)
		end
	end)

	t.test("only suggests bait the player owns and spots they can reach", function()
		for _, c in emptyCombos() do
			local text = Advice.nothingText(c.spot, c.period, c.bait, { c.bait }, { "Dock", "WeedBed", "Logs", "DeepHole" })
			t.ok(text:find(" here", 1, true) == nil, "no other bait owned: " .. text)
			for _, creek in { "Riffle", "Rocks", "Pool" } do
				if creek ~= c.spot then
					t.ok(text:find(FishLogic.SPOT_NAMES[creek], 1, true) == nil, "no creek without the pass: " .. text)
				end
			end
		end
	end)

	t.test("with nothing better anywhere, it says to try another time", function()
		local c = emptyCombos()[1]
		local text = Advice.nothingText(c.spot, c.period, c.bait, { c.bait }, { c.spot })
		t.eq(text, string.format("Nothing wants %s at %s right now. Try again at another time of day.", Advice.baitWords(c.bait), FishLogic.SPOT_NAMES[c.spot]), "fallback")
	end)
end
