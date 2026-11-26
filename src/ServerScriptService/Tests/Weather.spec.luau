-- UNVERIFIED in Studio: written 2026-11-26 in the cloud. Follows docs/WEATHER.md.
return function(t, Shared)
	local Weather = require(Shared.Weather)
	local FishLogic = require(Shared.FishLogic)
	local FishData = require(Shared.FishData)

	local function now(id, wind, moon)
		return { weather = id, wind = wind, moon = moon or 0 }
	end

	local function weightOf(list, id)
		for _, w in list do
			if w.id == id then
				return w.w
			end
		end
		return 0
	end

	t.test("clear weather changes nothing", function()
		local a = FishLogic.biteWeights("WeedBed", "Dusk", "Minnow")
		local b = FishLogic.biteWeights("WeedBed", "Dusk", "Minnow", now("Clear"))
		t.eq(#a, #b)
		for i = 1, #a do
			t.eq(a[i].id, b[i].id)
			t.ok(math.abs(a[i].w - b[i].w) < 1e-9, a[i].id)
		end
	end)

	t.test("overcast: bass hunt the weed bed at noon on a plastic worm", function()
		local clear = FishLogic.biteWeights("WeedBed", "Day", "PlasticWorm", now("Clear"))
		local cloudy = FishLogic.biteWeights("WeedBed", "Day", "PlasticWorm", now("Overcast"))
		t.eq(cloudy[1].id, "LargemouthBass", "top at noon when cloudy")
		t.ok(weightOf(cloudy, "LargemouthBass") > weightOf(clear, "LargemouthBass") * 1.2, "more than on a clear day")
	end)

	t.test("a cold front halves everything except the deep spots", function()
		for _, spot in { "WeedBed", "Logs" } do
			for _, s in FishData.list do
				t.ok(math.abs(Weather.multiplier(now("ColdFront"), s.id, spot, "Day") - 0.5) < 1e-9, s.id .. " at " .. spot)
			end
		end
		t.ok(Weather.multiplier(now("ColdFront"), "ChannelCatfish", "DeepHole", "Night") > 0.75, "deep hole holds up")
	end)

	t.test("weather never changes which bait a fish accepts or where it lives", function()
		for _, w in Weather.list do
			for _, spot in { "Dock", "WeedBed", "Logs", "DeepHole", "Riffle", "Rocks", "Pool" } do
				for _, period in { "Dawn", "Day", "Dusk", "Night" } do
					for _, bait in { "Worm", "Cricket", "Minnow", "Stinkbait", "Spinner", "PlasticWorm" } do
						for _, x in FishLogic.biteWeights(spot, period, bait, now(w.id, "west", Weather.FULL)) do
							local s = FishData.byId[x.id]
							t.ok((s.spots[spot] or 0) > 0 and (s.baits[bait] or 0) > 0, w.id .. ": " .. x.id .. " at " .. spot .. " on " .. bait)
						end
					end
				end
			end
		end
	end)

	t.test("the pre-storm rush feeds predators most; the storm slows everything", function()
		t.ok(Weather.multiplier(now("PreStorm"), "NorthernPike", "WeedBed", "Day") > Weather.multiplier(now("PreStorm"), "Bluegill", "Dock", "Day"), "predators most")
		t.ok(Weather.multiplier(now("PreStorm"), "Bluegill", "Dock", "Day") > 1, "everyone more")
		t.ok(Weather.multiplier(now("Storm"), "Bluegill", "Dock", "Day") < 1, "storm slower")
	end)

	t.test("wind: hunters on the downwind shore, a slower upwind shore, the island point catches most winds", function()
		-- Wind from the west blows toward the east shore, where the logs are.
		t.ok(Weather.multiplier(now("Wind", "west"), "LargemouthBass", "Logs", "Day") > 1.3, "downwind predator")
		t.eq(Weather.multiplier(now("Wind", "west"), "Bluegill", "Logs", "Day"), 1, "panfish don't care")
		t.ok(Weather.multiplier(now("Wind", "west"), "LargemouthBass", "WeedBed", "Day") < 1, "upwind is slower")
		local downwindCount = 0
		for _, d in Weather.DIRECTIONS do
			if Weather.multiplier(now("Wind", d), "Muskellunge", "IslandPoint", "Day") > 1 then
				downwindCount += 1
			end
		end
		t.eq(downwindCount, 3, "island point is downwind for three of four winds")
	end)

	t.test("full moon: night feeders up at night, a slow dawn after", function()
		t.ok(Weather.multiplier(now("Clear", nil, Weather.FULL), "Walleye", "Pool", "Night") > 1.2)
		t.eq(Weather.multiplier(now("Clear", nil, Weather.FULL), "Walleye", "Pool", "Day"), 1)
		t.ok(Weather.multiplier(now("Clear", nil, Weather.FULL + 1), "Bluegill", "Dock", "Dawn") < 1)
	end)

	t.test("day plans: chances add up, storms bring a cold front the next day, plans repeat for a seed", function()
		local total = 0
		for _, k in Weather.list do
			total += k.chance
		end
		t.ok(math.abs(total - 1) < 1e-9, "chances add to 1: " .. total)
		local counts = {}
		local prev = nil
		local afterStorm, coldFronts = 0, 0
		for day = 1, 5000 do
			local plan = Weather.planDay(day, 42, prev)
			counts[plan.kind] = (counts[plan.kind] or 0) + 1
			if prev and prev.kind == "PreStorm" then
				afterStorm += 1
				t.eq(plan.kind, "ColdFront", "day after a storm")
			end
			if plan.kind == "ColdFront" then
				coldFronts += 1
			end
			if plan.kind == "Wind" then
				t.ok(table.find(Weather.DIRECTIONS, plan.wind) ~= nil, "wind has a direction")
			end
			prev = plan
		end
		t.eq(coldFronts, afterStorm, "cold fronts only after storms")
		t.ok((counts.Clear or 0) > (counts.Wind or 0), "clear is the most common")
		t.eq(Weather.planDay(77, 5, nil).kind, Weather.planDay(77, 5, nil).kind, "same seed, same plan")
	end)

	t.test("fog lifts mid-morning; a storm day goes rush, storm, clear", function()
		local fog = { day = 1, kind = "Fog" }
		t.eq(Weather.at(fog, 6, 0).weather, "Fog")
		t.eq(Weather.at(fog, 11, 0).weather, "Clear")
		local storm = { day = 1, kind = "PreStorm" }
		t.eq(Weather.at(storm, 10, 0).weather, "Clear")
		t.eq(Weather.at(storm, 14, 0).weather, "PreStorm")
		t.eq(Weather.at(storm, 16, 0).weather, "Storm")
		t.eq(Weather.at(storm, 19, 0).weather, "Clear")
	end)

	t.test("forecasts read well and a cold front explains a slow bite", function()
		t.eq(Weather.forecast({ day = 1, kind = "Wind", wind = "west" }, 0), "Wind from the west. Fish the shore it blows toward.")
		t.ok(string.find(Weather.forecast({ day = 1, kind = "Clear" }, Weather.FULL), "Full moon") ~= nil)
		t.ok(Weather.hint(now("ColdFront")) ~= nil and Weather.hint(now("Clear")) == nil)
	end)
end
