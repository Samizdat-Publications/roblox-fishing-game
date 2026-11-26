-- UNVERIFIED in Studio: written 2026-11-26 in the cloud.
return function(t, Shared)
	local Frenzy = require(Shared.Frenzy)
	local FishData = require(Shared.FishData)
	local FishLogic = require(Shared.FishLogic)

	t.test("every schooling fish is real and lives at its spot", function()
		for spot, school in Frenzy.SCHOOLS do
			t.ok(Frenzy.SIGNS[spot] ~= nil, spot .. " has a sign")
			for _, id in school do
				local s = FishData.byId[id]
				t.ok(s ~= nil and (s.spots[spot] or 0) > 0, id .. " at " .. spot)
			end
		end
	end)

	t.test("frenzies favour dawn, dusk and the pre-storm rush", function()
		local day = Frenzy.chancePerSecond("Day", "Clear", 960)
		t.ok(Frenzy.chancePerSecond("Dawn", "Clear", 960) > day, "dawn")
		t.ok(Frenzy.chancePerSecond("Day", "PreStorm", 960) > day, "rush")
		t.ok(Frenzy.chancePerSecond("Day", "ColdFront", 960) < day, "cold front")
		-- About one a day over a whole clear day.
		local total = 0
		for hour = 0, 23 do
			total += Frenzy.chancePerSecond(FishLogic.periodFromClock(hour), "Clear", 960) * 40
		end
		t.ok(total > 0.6 and total < 2, "expected per day " .. total)
	end)

	t.test("only spots where the school is active, and only reachable ones", function()
		local dusk = Frenzy.candidates("Dusk", nil, nil)
		t.ok(#dusk > 0, "something at dusk")
		local lakeOnly = Frenzy.candidates("Dawn", nil, { Dock = true, OpenWater = true, Logs = true })
		for _, spot in lakeOnly do
			t.ok(spot == "Dock" or spot == "OpenWater" or spot == "Logs", spot)
		end
	end)

	t.test("a frenzy boosts the school but never adds a fish that doesn't take the bait", function()
		local base = FishLogic.biteWeights("Dock", "Day", "Worm")
		local f = Frenzy.weights(base, "Dock")
		t.eq(#f, #base, "same fish")
		local function w(list, id)
			for _, x in list do
				if x.id == id then
					return x.w
				end
			end
			return 0
		end
		t.ok(math.abs(w(f, "Bluegill") - w(base, "Bluegill") * Frenzy.SCHOOL_BOOST) < 1e-9, "bluegill boosted")
		t.eq(w(f, "YellowPerch"), w(base, "YellowPerch"), "perch unchanged at the dock")
		t.eq(#Frenzy.weights({}, "Dock"), 0, "wrong bait stays wrong")
	end)
end
