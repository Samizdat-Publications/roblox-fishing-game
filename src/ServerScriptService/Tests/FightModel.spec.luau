return function(t, Shared)
	local FightModel = require(Shared.FightModel)
	local FishData = require(Shared.FishData)
	local DT = 1 / 30

	-- policy(s, rng) -> holding, pressedThisStep
	local function run(profile, assist, seed, policy): (string, number)
		local s = FightModel.new(profile, assist, seed)
		local rng = Random.new(seed + 1000)
		local wasHolding = false
		for _ = 1, math.floor(60 / DT) do
			local hold = policy(s, rng)
			if hold and not wasHolding then
				FightModel.press(s)
			end
			wasHolding = hold
			local r = FightModel.step(s, DT, hold)
			if r then
				return r, s.t
			end
		end
		return "timeout", s.t
	end

	-- Holds while the fish is above the zone; taps if the line has been slack a while
	-- (a real player sees the "Keep reeling!" cue).
	local function tracker(s)
		return s.zonePos < s.fishPos or s.idle > 2
	end

	-- Move the zone only (progress frozen) to measure how input feels.
	local function lift(profile, dt, secs, pattern): number
		local s = FightModel.new(profile, false, 1)
		s.zonePos = s.zoneSize / 2
		local start = s.zonePos
		local tt, was = 0, false
		while tt < secs do
			local hold = pattern(tt)
			if hold and not was then
				FightModel.press(s)
			end
			was = hold
			FightModel.step(s, dt, hold)
			s.progress = 0.5
			tt += dt
		end
		return s.zonePos - start
	end

	t.test("a tracking player beats every species without assist", function()
		for _, sp in FishData.list do
			for seed = 1, 5 do
				local r, secs = run(sp.fight, false, seed, tracker)
				t.eq(r, "won", sp.id .. " seed " .. seed)
				t.ok(secs >= FightModel.minSeconds(sp.fight, false) - 1e-6, sp.id .. " faster than minSeconds")
			end
		end
	end)

	t.test("holding half a second clearly lifts the zone for every species", function()
		for _, sp in FishData.list do
			local d = lift(sp.fight, 1 / 60, 0.5, function()
				return true
			end)
			t.ok(d >= 0.33, sp.id .. " lifted only " .. string.format("%.2f", d))
		end
	end)

	t.test("quick clicks lift the zone too", function()
		for _, sp in FishData.list do
			local d = lift(sp.fight, 1 / 60, 2, function(tt)
				return (tt % 0.3) < 0.08 -- about three short clicks a second
			end)
			t.ok(d >= 0.25, sp.id .. " clicks lifted only " .. string.format("%.2f", d))
		end
	end)

	t.test("frame rate barely changes the feel", function()
		local hold = function()
			return true
		end
		local slow = lift(FishData.byId.ChannelCatfish.fight, 1 / 15, 0.6, hold)
		local fast = lift(FishData.byId.ChannelCatfish.fight, 1 / 120, 0.6, hold)
		t.ok(math.abs(slow - fast) < 0.04, string.format("15fps %.3f vs 120fps %.3f", slow, fast))
	end)

	t.test("doing nothing loses a bluegill", function()
		local r = run(FishData.byId.Bluegill.fight, false, 3, function()
			return false
		end)
		t.eq(r, "lost")
	end)

	t.test("assist lets a slow player (reacts a quarter second late) land a bluegill", function()
		local wins = 0
		for seed = 1, 10 do
			local queue = {}
			local r = run(FishData.byId.Bluegill.fight, true, seed, function(s)
				table.insert(queue, s.zonePos < s.fishPos)
				if #queue > 8 then -- 8 steps at 30 per second is about 0.27 s
					return table.remove(queue, 1)
				end
				return false
			end)
			if r == "won" then
				wins += 1
			end
		end
		t.ok(wins >= 8, "wins " .. wins)
	end)

	t.test("a clicker (short clicks only) lands panfish with assist", function()
		for _, id in { "Bluegill", "Pumpkinseed", "YellowPerch" } do
			local wins = 0
			for seed = 1, 6 do
				local clock = 0
				local r = run(FishData.byId[id].fight, true, seed, function(s)
					clock += DT
					-- click when the fish is above the zone, at most ~5 clicks a second
					return s.zonePos < s.fishPos and (clock % 0.2) < 0.07
				end)
				if r == "won" then
					wins += 1
				end
			end
			t.ok(wins >= 5, id .. " clicker wins " .. wins)
		end
	end)

	t.test("species still fight differently", function()
		local b = FishData.byId.Bluegill.fight
		local c = FishData.byId.ChannelCatfish.fight
		t.ok(c.heavy > b.heavy and c.gain < b.gain, "catfish should be heavier and slower to land")
		t.ok(FightModel.minSeconds(c, false) > FightModel.minSeconds(b, false) * 1.5, "catfish fight should last longer")
	end)

	t.test("same seed, same fight", function()
		local a1, s1 = run(FishData.byId.LargemouthBass.fight, false, 9, tracker)
		local a2, s2 = run(FishData.byId.LargemouthBass.fight, false, 9, tracker)
		t.eq(a1, a2)
		t.eq(s1, s2)
	end)

	t.test("doing nothing never lands a fish, even with assist", function()
		for _, sp in FishData.list do
			for seed = 1, 8 do
				local r = run(sp.fight, true, seed, function()
					return false
				end)
				t.ok(r ~= "won", sp.id .. " seed " .. seed .. " was landed with no input")
			end
		end
	end)
end
