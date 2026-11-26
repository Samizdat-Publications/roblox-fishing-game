return function(t, Shared)
	local FishLogic = require(Shared.FishLogic)
	local FishData = require(Shared.FishData)

	t.test("periods from the clock", function()
		t.eq(FishLogic.periodFromClock(6), "Dawn")
		t.eq(FishLogic.periodFromClock(12), "Day")
		t.eq(FishLogic.periodFromClock(18.5), "Dusk")
		t.eq(FishLogic.periodFromClock(23), "Night")
		t.eq(FishLogic.periodFromClock(2), "Night")
	end)

	t.test("bluegill rules the dock by day on worms", function()
		t.eq(FishLogic.biteWeights("Dock", "Day", "Worm")[1].id, "Bluegill")
	end)

	t.test("catfish rule the deep hole at night on stinkbait", function()
		t.eq(FishLogic.biteWeights("DeepHole", "Night", "Stinkbait")[1].id, "ChannelCatfish")
	end)

	t.test("bass rule the weeds at dawn on a plastic worm", function()
		t.eq(FishLogic.biteWeights("WeedBed", "Dawn", "PlasticWorm")[1].id, "LargemouthBass")
	end)

	t.test("no bass on stinkbait at the dock", function()
		for _, w in FishLogic.biteWeights("Dock", "Day", "Stinkbait") do
			t.ok(w.id ~= "LargemouthBass", "bass should not take stinkbait")
		end
	end)

	t.test("wrong combo gives no bite", function()
		local w = FishLogic.biteWeights("DeepHole", "Day", "Cricket")
		t.eq(#w, 0, "weights")
		t.eq(FishLogic.biteDelay(w, Random.new(1)), nil, "delay")
	end)

	t.test("good combo bites faster than weak combo", function()
		local good = FishLogic.biteDelay(FishLogic.biteWeights("Dock", "Day", "Worm"), Random.new(5)) :: number
		local weak = FishLogic.biteDelay(FishLogic.biteWeights("OpenWater", "Night", "Worm"), Random.new(5)) :: number
		t.ok(good < weak, "good " .. good .. " weak " .. weak)
	end)

	t.test("sizes stay in range and price grows with weight", function()
		local rng = Random.new(42)
		for _, s in FishData.list do
			for _ = 1, 200 do
				local cm, kg = FishLogic.rollSize(s, rng)
				t.ok(cm >= s.minCm and cm <= s.maxCm, s.id .. " cm " .. cm)
				t.ok(kg > 0, s.id .. " kg")
			end
			t.ok(FishLogic.priceFor(s, 3) >= FishLogic.priceFor(s, 1), s.id .. " price")
			t.ok(FishLogic.priceFor(s, 0.01) >= 1, s.id .. " min price")
		end
	end)

	t.test("pickSpecies respects weights", function()
		local rng = Random.new(7)
		local counts = {}
		local w = FishLogic.biteWeights("Dock", "Day", "Worm")
		for _ = 1, 500 do
			local id = FishLogic.pickSpecies(w, rng) :: string
			counts[id] = (counts[id] or 0) + 1
		end
		t.ok((counts.Bluegill or 0) > 250, "bluegill should dominate")
	end)

	t.test("water and zones", function()
		local cf, size = CFrame.new(0, 0, 0), Vector3.new(220, 1, 160)
		t.ok(FishLogic.isOnWater(Vector3.new(100, 0, 70), cf, size), "inside")
		t.ok(not FishLogic.isOnWater(Vector3.new(115, 0, 0), cf, size), "past edge")
		local zones = { { name = "Dock", cframe = CFrame.new(0, 0, 55), size = Vector3.new(30, 10, 50) } }
		t.eq(FishLogic.spotAt(Vector3.new(5, 0, 50), zones), "Dock")
		t.eq(FishLogic.spotAt(Vector3.new(60, 0, -60), zones), "OpenWater")
	end)
	t.test("creek fish live in the creek and only there", function()
		t.eq(FishLogic.biteWeights("Riffle", "Dawn", "Cricket")[1].id, "RainbowTrout")
		t.eq(FishLogic.biteWeights("Pool", "Night", "Minnow")[1].id, "Walleye")
		t.eq(FishLogic.biteWeights("Rocks", "Day", "Spinner")[1].id, "SmallmouthBass")
		local creekIds = { RainbowTrout = true, SmallmouthBass = true, Walleye = true }
		for _, spot in { "Dock", "WeedBed", "Logs", "DeepHole", "OpenWater" } do
			for _, period in { "Dawn", "Day", "Dusk", "Night" } do
				for _, bait in { "Worm", "Cricket", "Minnow", "Stinkbait", "Spinner", "PlasticWorm" } do
					for _, w in FishLogic.biteWeights(spot, period, bait) do
						t.ok(not creekIds[w.id], w.id .. " bit in the lake at " .. spot)
					end
				end
			end
		end
	end)

	t.test("creek water counts as water, its banks don't", function()
		local boxes = {
			{ cframe = CFrame.new(0, -0.5, 0), size = Vector3.new(220, 1, 160) },
			{ cframe = CFrame.new(-230, 0, 52.5), size = Vector3.new(12, 1, 45) },
		}
		t.ok(FishLogic.isOnWaterAny(Vector3.new(-230, 0, 50), boxes), "riffle")
		t.ok(not FishLogic.isOnWaterAny(Vector3.new(-245, 0, 50), boxes), "bank")
		t.ok(FishLogic.isOnWaterAny(Vector3.new(10, 0, 10), boxes), "lake")
	end)
end
