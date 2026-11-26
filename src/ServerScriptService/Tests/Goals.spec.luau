-- UNVERIFIED in Studio: written 2026-11-26 in the cloud.
return function(t, Shared)
	local Goals = require(Shared.Goals)
	local FishData = require(Shared.FishData)
	local CREEK = { Riffle = true, Rocks = true, Pool = true }

	t.test("three goals a day, easy to hard, same for everyone on the same day", function()
		local a, b = Goals.forDay(20000, false), Goals.forDay(20000, false)
		t.eq(#a, 3)
		t.eq(a[1].id, "easy")
		t.eq(a[3].id, "hard")
		for i = 1, 3 do
			t.eq(a[i].text, b[i].text, "goal " .. i)
		end
		t.ok(a[1].reward < a[2].reward and a[2].reward < a[3].reward, "harder pays more")
	end)

	t.test("goals change from day to day", function()
		local seen = {}
		local n = 0
		for day = 20000, 20013 do
			local key = Goals.forDay(day, true)[2].text
			if not seen[key] then
				seen[key] = true
				n += 1
			end
		end
		t.ok(n >= 4, "different medium goals over two weeks: " .. n)
	end)

	t.test("no goal needs the creek before you have the Creek Pass, and every goal can be done", function()
		for day = 19000, 19365 do
			for _, creek in { false, true } do
				for _, g in Goals.forDay(day, creek) do
					t.ok(g.target >= 1 and g.reward > 0 and #g.text > 0, "sane " .. g.text)
					if g.species then
						local s = FishData.byId[g.species]
						t.ok(s ~= nil, "species exists " .. g.species)
						if not creek then
							local lake = false
							for spot, w in s.spots do
								if w > 0 and not CREEK[spot] then
									lake = true
								end
							end
							t.ok(lake, g.text .. " needs the creek")
						end
					end
					if g.spot then
						t.ok(creek or not CREEK[g.spot], g.text .. " needs the creek")
						local bites = false
						for _, s in FishData.list do
							if (s.spots[g.spot] or 0) > 0 and (s.periods[g.period or ""] or 0) >= 0.5 then
								bites = true
							end
						end
						t.ok(bites, g.text .. " has something biting")
					end
				end
			end
		end
	end)

	t.test("catches move goals forward and finish each one once", function()
		local state = Goals.ensure(nil, 1, true)
		state.list = {
			{ id = "easy", kind = "catchAny", text = "", target = 2, progress = 0, reward = 25, done = false },
			{ id = "medium", kind = "catchSpecies", text = "", target = 1, progress = 0, reward = 60, done = false, species = "Bluegill" },
			{ id = "hard", kind = "catchAt", text = "", target = 1, progress = 0, reward = 120, done = false, spot = "DeepHole", period = "Night" },
		}
		local done = Goals.onCatch(state, { id = "Bluegill", spot = "Dock", period = "Day" })
		t.eq(#done, 1, "bluegill goal")
		t.eq(done[1].id, "medium")
		done = Goals.onCatch(state, { id = "ChannelCatfish", spot = "DeepHole", period = "Night" })
		t.eq(#done, 2, "catch any and deep hole at night")
		done = Goals.onCatch(state, { id = "Bluegill", spot = "Dock", period = "Day" })
		t.eq(#done, 0, "nothing finishes twice")
		t.eq(state.list[1].progress, 2, "progress capped at the target")
	end)

	t.test("a Rare-or-better goal ignores commons", function()
		local state = { day = 1, list = { { id = "hard", kind = "catchTier", text = "", target = 1, progress = 0, reward = 120, done = false, tier = "Rare" } } }
		t.eq(#Goals.onCatch(state, { id = "Bluegill", spot = "Dock", period = "Day" }), 0)
		t.eq(#Goals.onCatch(state, { id = "NorthernPike", spot = "WeedBed", period = "Day" }), 1)
	end)

	t.test("selling counts toward a sell goal", function()
		local state = { day = 1, list = { { id = "easy", kind = "sell", text = "", target = 60, progress = 0, reward = 25, done = false } } }
		t.eq(#Goals.onSell(state, 40), 0)
		t.eq(#Goals.onSell(state, 40), 1)
	end)

	t.test("a new day brings new goals; the same day keeps progress", function()
		local s = Goals.ensure(nil, 100, false)
		s.list[1].progress = 1
		t.eq(Goals.ensure(s, 100, false).list[1].progress, 1, "same day")
		local fresh = Goals.ensure(s, 101, false)
		t.eq(fresh.day, 101)
		t.eq(fresh.list[1].progress, 0, "new day")
		t.eq(Goals.dayOf(86400 * 3 + 5), 3)
	end)
end
