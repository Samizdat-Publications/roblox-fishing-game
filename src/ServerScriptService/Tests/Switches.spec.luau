-- The second overnight run's features land switched off (leg plan L0) and each is turned on
-- by itself. UNVERIFIED in Studio: written 2026-11-26 in the cloud.
return function(t, Shared)
	local Config = require(Shared.Config)
	local FishLogic = require(Shared.FishLogic)
	local FishData = require(Shared.FishData)

	-- Switched on one at a time as each is proven in Studio (L6): weather 11/27/2026.
	t.test("weather is on; frenzies, goals, the Big Lake and boats still off", function()
		t.eq(Config.WEATHER_ON, true, "weather")
		t.eq(Config.FRENZIES_ON, false, "frenzies")
		t.eq(Config.GOALS_ON, false, "goals")
		t.eq(Config.BIG_LAKE_ON, false, "Big Lake")
		t.eq(Config.BOATS_ON, false, "boats")
		t.eq(Config.boatsOn(), false, "boats need the Big Lake too")
	end)

	t.test("with weather off (clear skies) no weather-only fish bites anywhere", function()
		local calm = { weather = "Clear", moon = 0 }
		for _, spot in { "Dock", "WeedBed", "Logs", "DeepHole", "OpenWater", "Riffle", "Rocks", "Pool", "Basin", "IslandPoint", "DropOff" } do
			for _, period in { "Dawn", "Day", "Dusk", "Night" } do
				for _, bait in { "Worm", "Cricket", "Minnow", "Stinkbait", "Spinner", "PlasticWorm" } do
					for _, w in FishLogic.biteWeights(spot, period, bait, calm) do
						t.ok(FishData.byId[w.id].weather == nil, w.id .. " bit at " .. spot)
					end
				end
			end
		end
	end)
end
