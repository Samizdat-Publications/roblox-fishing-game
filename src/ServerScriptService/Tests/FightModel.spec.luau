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

	-- Holds while the fish is above the zone; taps just before the line goes slack.
	local Cfg = require(Shared.Config)
	local function tracker(s)
		return s.zonePos < s.fishPos or s.idle > Cfg.FIGHT_IDLE_GRACE * 0.8
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

	-- Fight styles (added 2026-11-26, pass in Studio).
	local BigLake = require(Shared.BigLakeFishData)

	-- Watch a fish for 30 seconds with progress frozen, tracking what its style does.
	local function watch(profile, seed)
		local s = FightModel.new(profile, false, seed)
		local seen = { top = 0, bottom = 0, runs = 0, jumps = 0, maxStep = 0 }
		local last, lastMode = s.fishPos, s.mode
		for _ = 1, math.floor(30 / DT) do
			FightModel.step(s, DT, false)
			s.progress = 0.5
			seen.top = math.max(seen.top, s.fishPos)
			seen.bottom = seen.bottom + (if s.fishPos < 0.3 then DT else 0)
			if s.mode ~= lastMode and s.mode == "run" then
				seen.runs += 1
			elseif s.mode ~= lastMode and s.mode == "jump" then
				seen.jumps += 1
			end
			seen.maxStep = math.max(seen.maxStep, math.abs(s.fishPos - last))
			last, lastMode = s.fishPos, s.mode
		end
		return seen
	end

	t.test("every fish has a known fight style and bite", function()
		local styles = { tugger = true, steady = true, runner = true, jumper = true, diver = true, shaker = true }
		local bites = { nibble = true, tap = true, slam = true, pull = true }
		for _, list in { FishData.list, BigLake.list } do
			for _, sp in list do
				t.ok(styles[sp.fight.style or ""], sp.id .. " style")
				t.ok(bites[sp.bite or ""], sp.id .. " bite")
			end
		end
	end)

	t.test("styles show up: trout jump, bass run, catfish hug the bottom, pike shake", function()
		local trout, bass, cat, gill, pike = 0, 0, 0, 0, 0
		for seed = 1, 6 do
			trout += watch(FishData.byId.RainbowTrout.fight, seed).jumps
			bass += watch(FishData.byId.LargemouthBass.fight, seed).runs
			cat += watch(FishData.byId.ChannelCatfish.fight, seed).bottom
			gill += watch(FishData.byId.Bluegill.fight, seed).bottom
			pike = math.max(pike, watch(FishData.byId.NorthernPike.fight, seed).maxStep)
		end
		t.ok(trout >= 6, "trout jumps " .. trout)
		t.ok(bass >= 6, "bass runs " .. bass)
		t.ok(cat > gill * 1.5, string.format("catfish bottom %.1f s vs bluegill %.1f s", cat, gill))
		t.ok(pike > FishData.byId.NorthernPike.fight.speed * DT * 1.5, "pike shakes " .. pike)
	end)

	t.test("a tracking player still beats the Big Lake fish without assist", function()
		for _, sp in BigLake.list do
			for seed = 1, 5 do
				t.eq((run(sp.fight, false, seed, tracker)), "won", sp.id .. " seed " .. seed)
			end
		end
	end)

	t.test("bite patterns: nibblers dip first, catfish give the longest window, nobody gets a short one", function()
		local FishLogic = require(Shared.FishLogic)
		local Config = require(Shared.Config)
		local gill = FishLogic.bitePattern(FishData.byId.Bluegill)
		local cat = FishLogic.bitePattern(FishData.byId.ChannelCatfish)
		local pike = FishLogic.bitePattern(FishData.byId.NorthernPike)
		t.ok(gill.predips > 0 and pike.predips == 0, "nibbles before the bite")
		t.ok(pike.depth > gill.depth, "a slam pulls the bobber deeper")
		t.ok(cat.hookWindow > gill.hookWindow, "a pull gives more time")
		for _, list in { FishData.list, BigLake.list } do
			for _, sp in list do
				t.ok(FishLogic.bitePattern(sp).hookWindow >= Config.HOOK_WINDOW - 0.2, sp.id .. " window")
			end
		end
		t.eq(FishLogic.bitePattern({ bite = nil } :: any).style, "slam", "old data falls back")
	end)

	-- L4b: tells and the shorter idle grace.
	local FightFeel = require(Shared.FightFeel)

	-- Watch a fish (progress frozen) and note each warned move: when the warning started and
	-- when the move showed on the bar.
	local function tellTimes(profile, seed, secs)
		local s = FightModel.new(profile, false, seed)
		local out = {}
		local open: { move: string, at: number }? = nil
		local lastTells = 0
		for _ = 1, math.floor(secs / DT) do
			FightModel.step(s, DT, false)
			s.progress = 0.5
			if s.tells > lastTells then
				lastTells = s.tells
				local move, left = FightModel.tell(s)
				t.ok(move ~= nil, "a new tell names its move")
				t.ok(math.abs(left - Cfg.TELL_LEAD) < 1e-6, "a fresh tell has the full lead, got " .. left)
				open = { move = move :: string, at = s.t }
			end
			local o = open
			if o and s.mode == o.move then
				table.insert(out, { move = o.move, lead = s.t - o.at })
				open = nil
			end
		end
		return out
	end

	t.test("every big move is warned 0.3 to 0.6 s before it shows on the bar", function()
		t.ok(Cfg.TELL_LEAD >= 0.3 and Cfg.TELL_LEAD <= 0.6, "TELL_LEAD " .. Cfg.TELL_LEAD)
		local cases = {
			{ id = "LargemouthBass", style = "runner", move = "run" },
			{ id = "RainbowTrout", style = "jumper", move = "jump" },
			{ id = "ChannelCatfish", style = "diver", move = "dive" },
			{ id = "NorthernPike", style = "shaker", move = "run" },
		}
		for _, c in cases do
			local sp = FishData.byId[c.id]
			t.eq(sp.fight.style, c.style, c.id .. " style")
			local n = 0
			for seed = 1, 4 do
				for _, e in tellTimes(sp.fight, seed, 40) do
					n += 1
					t.eq(e.move, c.move, c.id .. " move")
					t.ok(e.lead >= 0.3 - 1e-6 and e.lead <= 0.6 + 1e-6, string.format("%s warned %.2f s ahead", c.id, e.lead))
				end
			end
			t.ok(n >= 4, c.id .. " big moves seen " .. n)
			t.ok(FightFeel.tellFor(c.style, c.move) ~= nil, c.style .. " has a tell")
		end
	end)

	t.test("the tells: runner drag, jumper breach, diver dive, shaker thrash, tugger twitch, steady pull", function()
		t.eq(FightFeel.tellFor("runner", "run"), "drag")
		t.eq(FightFeel.tellFor("jumper", "jump"), "breach")
		t.eq(FightFeel.tellFor("diver", "dive"), "dive")
		t.eq(FightFeel.tellFor("shaker", "run"), "thrash")
		t.eq(FightFeel.tellFor("tugger", nil), "twitch")
		t.eq(FightFeel.tellFor("steady", nil), "pull")
		t.eq(FightFeel.TELL_SOUNDS.drag.name, "drag-zip")
		t.eq(FightFeel.TELL_SOUNDS.breach.name, "thrash-splash")
		t.eq(FightFeel.TELL_SOUNDS.thrash.name, "thrash-splash")
		t.eq(FightFeel.TELL_SOUNDS.dive.name, "line-creak")
		-- Tuggers and steady fish make no big moves, but their darts are counted for the line's twitch.
		for _, id in { "Bluegill", "YellowPerch" } do
			local s = FightModel.new(FishData.byId[id].fight, false, 2)
			for _ = 1, math.floor(10 / DT) do
				FightModel.step(s, DT, false)
				s.progress = 0.5
			end
			t.eq(s.tells, 0, id .. " no big moves")
			t.ok(s.darts >= 5, id .. " darts " .. s.darts)
		end
	end)

	-- A kid: sees the fish a third of a second late, a little dead zone, and now and then looks
	-- away for 0.4 s. `cue`: taps when "Keep reeling!" shows (it shows after the idle grace).
	local function kid(profile, assist, seed, cue)
		local s = FightModel.new(profile, assist, seed)
		local rng = Random.new(seed * 7 + 3)
		local reaction = 0.3
		local lag = math.floor(reaction / DT + 0.5)
		local seenPos = {}
		local holding, lapse = false, 0
		for _ = 1, math.floor(90 / DT) do
			table.insert(seenPos, s.fishPos)
			local seen = if #seenPos >= lag then seenPos[#seenPos - lag + 1] else 0.5
			local want
			if lapse > 0 then
				lapse -= DT
				want = false
			else
				if rng:NextNumber() < 0.25 * DT then
					lapse = 0.4
				end
				want = if holding then seen > s.zonePos - 0.03 else seen > s.zonePos + 0.03
				if cue and FightModel.slack(s) and s.idle > Cfg.FIGHT_IDLE_GRACE + reaction then
					want = true
				end
			end
			if want and not holding then
				FightModel.press(s)
			end
			holding = want
			local r = FightModel.step(s, DT, holding)
			if r then
				return r == "won"
			end
		end
		return false
	end

	t.test("idle grace: a kid with assist off lands at least 85 percent of Common and Uncommon fish", function()
		t.eq(Cfg.FIGHT_IDLE_GRACE, 1.2, "chosen 2026-11-26 from tools/econ/sim.py --grace")
		local easy = {}
		for _, sp in FishData.list do
			if sp.tier == "Common" or sp.tier == "Uncommon" then
				table.insert(easy, sp)
			end
		end
		t.ok(#easy >= 5, "easy fish " .. #easy)
		local won, missedCue, n = 0, 0, 0
		for _, sp in easy do
			for seed = 1, 40 do
				n += 1
				if kid(sp.fight, false, seed, true) then
					won += 1
				end
				if kid(sp.fight, false, seed, false) then
					missedCue += 1
				end
			end
		end
		t.ok(won / n >= 0.85, string.format("kid lands %.0f%%", won / n * 100))
		t.ok(missedCue / n >= 0.85, string.format("kid who never reads the cue lands %.0f%%", missedCue / n * 100))
	end)

	t.test("idle grace: resting longer than the grace drains progress even inside the zone", function()
		local s = FightModel.new(FishData.byId.Bluegill.fight, false, 1)
		s.zoneSize = 1 -- the fish is always inside
		FightModel.press(s)
		FightModel.step(s, DT, true)
		local p0 = s.progress
		for _ = 1, math.floor((Cfg.FIGHT_IDLE_GRACE - 0.1) / DT) do
			FightModel.step(s, DT, false)
		end
		t.ok(s.progress > p0, "still filling within the grace")
		local p1 = s.progress
		for _ = 1, math.floor(0.6 / DT) do
			FightModel.step(s, DT, false)
		end
		t.ok(s.progress < p1, "draining after the grace")
	end)

	t.test("the slack cue waits for the first press, then shows after the idle grace", function()
		local Config = require(Shared.Config)
		local s = FightModel.new(FishData.byId.Bluegill.fight, false, 1)
		for _ = 1, 90 do
			FightModel.step(s, DT, false)
		end
		t.ok(not FightModel.slack(s), "quiet before the first press")
		FightModel.press(s)
		FightModel.step(s, DT, true)
		t.ok(not FightModel.slack(s), "tight right after a press")
		for _ = 1, math.ceil((Config.FIGHT_IDLE_GRACE + 0.2) / DT) do
			FightModel.step(s, DT, false)
		end
		t.ok(FightModel.slack(s), "slack after the grace")
	end)
end
