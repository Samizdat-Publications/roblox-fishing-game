return function(t, Shared)
	local FightModel = require(Shared.FightModel)
	local FishData = require(Shared.FishData)
	local DT = 1 / 30

	local function run(profile, assist, seed, policy): (string, number)
		local s = FightModel.new(profile, assist, seed)
		local rng = Random.new(seed + 1000)
		for _ = 1, math.floor(60 / DT) do
			local r = FightModel.step(s, DT, policy(s, rng))
			if r then
				return r, s.t
			end
		end
		return "timeout", s.t
	end

	local function tracker(s)
		return s.zonePos < s.fishPos
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

	t.test("doing nothing loses a bluegill", function()
		local r = run(FishData.byId.Bluegill.fight, false, 3, function()
			return false
		end)
		t.eq(r, "lost")
	end)

	t.test("assist lets a sloppy player land a bluegill", function()
		local wins = 0
		for seed = 1, 10 do
			local r = run(FishData.byId.Bluegill.fight, true, seed, function(s, rng)
				local right = s.zonePos < s.fishPos
				if rng:NextNumber() < 0.25 then
					return not right
				end
				return right
			end)
			if r == "won" then
				wins += 1
			end
		end
		t.ok(wins >= 8, "wins " .. wins)
	end)

	t.test("same seed, same fight", function()
		local a1, s1 = run(FishData.byId.LargemouthBass.fight, false, 9, tracker)
		local a2, s2 = run(FishData.byId.LargemouthBass.fight, false, 9, tracker)
		t.eq(a1, a2)
		t.eq(s1, s2)
	end)
end
