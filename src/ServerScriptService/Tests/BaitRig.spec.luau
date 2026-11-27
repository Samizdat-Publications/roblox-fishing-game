-- The bait bench (L3): each recipe grades a perfect timeline Perfect, a sloppy one Good or
-- Okay, refuses an impossible one, and runs slower the first time; hook sizes; and Okay is
-- exactly the game before L3. The two lure recipes (L3b) run through the same cases.
-- Written 2026-11-26; UNVERIFIED in Studio until the L3 and L3b playtests.
return function(t, Shared)
	local BaitRig = require(Shared.BaitRig)
	local BaitData = require(Shared.BaitData)
	local FishData = require(Shared.FishData)
	local FightModel = require(Shared.FightModel)
	local Config = require(Shared.Config)

	local LIVE = { "Worm", "Cricket", "Minnow", "Stinkbait" }
	local LURES = { "Spinner", "PlasticWorm" }
	local ALL = { "Worm", "Cricket", "Minnow", "Stinkbait", "Spinner", "PlasticWorm" }

	local function shift(timeline, dt: number, which: number?)
		local out = {}
		for i, p in timeline do
			local d = if which == nil or which == i then dt else 0
			out[i] = { down = p.down + d, up = p.up + d }
		end
		return out
	end

	t.test("every bait and lure has a recipe (lures since L3b)", function()
		for _, b in BaitData.list do
			t.ok(BaitRig.recipeFor(b.id) ~= nil, b.id .. " needs a recipe")
		end
		t.eq(#ALL, #BaitData.list, "the spec covers every bait")
	end)

	for _, bait in ALL do
		local r = BaitRig.recipeFor(bait) :: BaitRig.Recipe
		for _, first in { false, true } do
			local tag = bait .. (if first then " (first time)" else "")

			t.test(tag .. ": a perfect timeline grades Perfect and is not refused", function()
				local tl = BaitRig.perfectTimeline(r, first)
				local g, why = BaitRig.grade(r, tl, first)
				t.eq(why, nil, "refused")
				t.eq(g, "Perfect", "grade")
				-- The bait id works as well as the recipe.
				t.eq((BaitRig.grade(bait, tl, first)), "Perfect", "by id")
			end)

			t.test(tag .. ": a little off is Good, a lot off is Okay", function()
				local tl = BaitRig.perfectTimeline(r, first)
				local speed = if first then BaitRig.FIRST_SPEED else 1
				local n = r.presses
				local hold = BaitRig.moveOf(r, n) == "hold"
				local tight, loose = BaitRig.windowOf(r, n)
				-- How many seconds one marker (or fill) unit is worth.
				local unit = if hold then r.fillTime / speed else r.sweep / speed
				local good = (tight + loose) / 2 * unit
				local bad = (loose + 0.02) * unit
				local function nudge(dt: number)
					if hold then
						local out = table.clone(tl)
						out[n] = { down = tl[n].down, up = tl[n].up + dt } -- the last hold held longer
						return out
					end
					return shift(tl, dt, n) -- the last move late
				end
				t.eq((BaitRig.grade(r, nudge(good), first)), "Good", "a little late")
				t.eq((BaitRig.grade(r, nudge(bad), first)), "Okay", "far too late")
				t.eq((BaitRig.grade(r, nudge(-good), first)), "Good", "a little early")
			end)

			t.test(tag .. ": unfinished or skipped is Okay", function()
				local tl = BaitRig.perfectTimeline(r, first)
				table.remove(tl)
				t.eq((BaitRig.grade(r, tl, first)), "Okay", "unfinished")
			end)

			t.test(tag .. ": impossible timelines are refused (and grade Okay)", function()
				local tl = BaitRig.perfectTimeline(r, first)
				-- More presses than the recipe has.
				local extra = table.clone(tl)
				local last = extra[#extra]
				table.insert(extra, { down = last.up + 1, up = last.up + 1.1 })
				local g, why = BaitRig.grade(r, extra, first)
				t.eq(g, "Okay", "extra press grade")
				t.ok(why ~= nil, "extra press refused")
				-- A press before the marker could be seen.
				g, why = BaitRig.grade(r, { { down = 0.01, up = 0.05 } }, first)
				t.ok(why ~= nil and g == "Okay", "instant first press")
				-- Up before down.
				g, why = BaitRig.grade(r, { { down = 1, up = 0.5 } }, first)
				t.ok(why ~= nil, "up before down")
				-- Garbage.
				t.ok(select(2, BaitRig.grade(r, "Perfect", first)) ~= nil, "a string")
				t.ok(select(2, BaitRig.grade(r, { { down = 0 / 0, up = 1 } }, first)) ~= nil, "NaN")
				t.ok(select(2, BaitRig.grade(r, {}, first)) ~= nil, "empty")
				-- A whole recipe finished sooner than the marker allows.
				if r.kind == "hold" then
					local quick = { { down = 0.2, up = 0.2 + BaitRig.minTotal(r, first) * 0.5 } }
					t.ok(select(2, BaitRig.grade(r, quick, first)) ~= nil, "too quick")
				elseif r.kind == "mixed" then
					-- Every move as fast as hands allow, the hold let go at once: far too quick.
					local quick = {}
					for i = 1, r.presses do
						local d = 0.2 + (i - 1) * (BaitRig.MIN_GAP + 0.01)
						quick[i] = { down = d, up = d + 0.005 }
					end
					t.ok(quick[#quick].up < BaitRig.minTotal(r, first), "the quick timeline is under the minimum")
					t.ok(select(2, BaitRig.grade(r, quick, first)) ~= nil, "too quick")
				end
				-- The soonest possible good finish is never refused (the bound is a true minimum).
				t.ok(BaitRig.minTotal(r, first) <= tl[#tl].up + 1e-9, "minTotal under a perfect run")
			end)
		end

		if r.presses >= 2 then
			t.test(bait .. ": presses out of order or too fast are refused", function()
				local tl = BaitRig.perfectTimeline(r, false)
				local swapped = { tl[2], tl[1] }
				for i = 3, #tl do
					swapped[i] = tl[i]
				end
				t.ok(select(2, BaitRig.grade(r, swapped, false)) ~= nil, "out of order")
				local fast = {}
				for i = 1, r.presses do
					local d = 0.3 + (i - 1) * 0.05
					fast[i] = { down = d, up = d + 0.02 }
				end
				t.ok(select(2, BaitRig.grade(r, fast, false)) ~= nil, "machine-gun presses")
				-- Overlapping presses (a second down before the first up).
				local overlap = table.clone(tl)
				overlap[1] = { down = tl[1].down, up = tl[2].down + 0.05 }
				t.ok(select(2, BaitRig.grade(r, overlap, false)) ~= nil, "overlap")
			end)
		end

		t.test(bait .. ": the first-time marker is slower, so a learned timeline misses", function()
			local learned = BaitRig.perfectTimeline(r, false)
			local g = BaitRig.grade(r, learned, true)
			t.ok(g ~= "Perfect", "full-speed timing on the slow first-time bench should not be Perfect")
			if r.kind ~= "hold" then
				t.ok(math.abs(BaitRig.markerAt(r, 1, true) - BaitRig.FIRST_SPEED * BaitRig.markerAt(r, 1, false)) < 1e-9 or r.sweep < 1, "marker speed")
			else
				t.ok(math.abs(BaitRig.fillAt(r, 0.5, true) - 0.6 * BaitRig.fillAt(r, 0.5, false)) < 1e-9, "fill speed")
			end
		end)
	end

	t.test("a learned Perfect worm takes 4 seconds or less", function()
		local r = BaitRig.recipeFor("Worm") :: BaitRig.Recipe
		local tl = BaitRig.perfectTimeline(r, false)
		t.ok(tl[#tl].up + BaitRig.LEAD_IN <= 4, "worm took " .. tl[#tl].up)
	end)

	t.test("a learned Perfect is possible for every recipe within the bench timeout", function()
		for _, bait in ALL do
			local r = BaitRig.recipeFor(bait) :: BaitRig.Recipe
			local tl = BaitRig.perfectTimeline(r, true)
			t.ok(tl[#tl].up < BaitRig.BENCH_TIMEOUT, bait)
			t.ok(tl[#tl].up < BaitRig.MAX_TIME, bait)
		end
	end)

	t.test("stinkbait: too little or a lump is Okay; the skip hold waits past the overflow", function()
		local r = BaitRig.recipeFor("Stinkbait") :: BaitRig.Recipe
		local lump = { { down = 0.3, up = 0.3 + r.fillTime * 1.05 } }
		t.eq((BaitRig.grade(r, lump, false)), "Okay", "lump")
		local thin = { { down = 0.3, up = 0.3 + r.fillTime * 0.3 } }
		t.eq((BaitRig.grade(r, thin, false)), "Okay", "too little")
		for _, first in { false, true } do
			local full = r.fillTime / (if first then BaitRig.FIRST_SPEED else 1)
			t.ok(BaitRig.skipHold(r, first) > full, "skip comes after the bar overflows")
		end
		t.eq(BaitRig.skipHold(BaitRig.recipeFor("Worm"), false), BaitRig.SKIP_HOLD, "tap recipes skip at 1 s")
	end)

	t.test("hook sizes: right size never misses, one off 25 percent, two off 50 percent", function()
		t.eq(BaitRig.missChance("Small", "small", true), 0, "small on small")
		t.eq(BaitRig.missChance("Medium", "medium", true), 0, "medium on medium")
		t.eq(BaitRig.missChance("Large", "large", true), 0, "large on large")
		t.eq(BaitRig.missChance("Medium", "small", true), 0.25, "medium on small")
		t.eq(BaitRig.missChance("Small", "medium", true), 0.25, "small on medium")
		t.eq(BaitRig.missChance("Medium", "large", true), 0.25, "medium on large")
		t.eq(BaitRig.missChance("Large", "small", true), 0.5, "large on small")
		t.eq(BaitRig.missChance("Small", "large", true), 0.5, "small on large")
		t.eq(BaitRig.HOOK_MISS_ONE, 0.25, "constant")
		t.eq(BaitRig.HOOK_MISS_TWO, 0.5, "constant")
	end)

	t.test("lures carry their own hook: no hook-size misses", function()
		for _, h in BaitRig.HOOKS do
			for _, m in { "small", "medium", "large" } do
				t.eq(BaitRig.missChance(h, m, false), 0, h .. " " .. m)
			end
		end
	end)

	t.test("every species has a mouth class", function()
		for _, s in FishData.list do
			t.ok(s.mouth == "small" or s.mouth == "medium" or s.mouth == "large", s.id)
		end
		t.eq(FishData.byId.Bluegill.mouth, "small", "bluegill")
		t.eq(FishData.byId.Walleye.mouth, "medium", "walleye")
		t.eq(FishData.byId.ChannelCatfish.mouth, "large", "catfish")
		t.eq(FishData.byId.Burbot.mouth, "large", "burbot")
	end)

	t.test("the spit message says what was wrong", function()
		t.eq(BaitRig.spitText("Large", "small", "Bluegill"), "It spat the hook! A Large hook is too big for a Bluegill.", "too big")
		t.eq(BaitRig.spitText("Small", "large", "Northern Pike"), "It spat the hook! A Small hook is too small for a Northern Pike.", "too small")
	end)

	t.test("Okay is exactly the game before L3", function()
		t.eq(BaitRig.biteMult("Okay"), 1, "bite wait")
		t.eq(BaitRig.fightStart("Okay"), Config.FIGHT_START, "fight start")
		t.eq(Config.FIGHT_START, 0.4, "fight start value from before L3")
		t.eq(BaitRig.SURVIVE.Okay, 0, "bait always used up")
		t.ok(not BaitRig.survives("Okay", 0), "never survives")
		-- Unknown or missing grades act as Okay.
		t.eq(BaitRig.biteMult(nil), 1, "nil grade")
		t.eq(BaitRig.fightStart("Cheating"), Config.FIGHT_START, "junk grade")
		-- FightModel with no start, or Okay's start, matches the old numbers.
		local p = FishData.byId.Bluegill.fight
		t.eq(FightModel.new(p, true, 1).progress, Config.FIGHT_START, "default progress")
		t.eq(FightModel.new(p, true, 1, BaitRig.fightStart("Okay")).progress, Config.FIGHT_START, "okay progress")
		t.eq(FightModel.minSeconds(p, true), FightModel.minSeconds(p, true, BaitRig.fightStart("Okay")), "min seconds")
	end)

	t.test("Good and Perfect earn what the design says", function()
		t.eq(BaitRig.biteMult("Good"), 0.9, "good bite")
		t.eq(BaitRig.biteMult("Perfect"), 0.8, "perfect bite")
		t.eq(BaitRig.fightStart("Good"), 0.45, "good start")
		t.eq(BaitRig.fightStart("Perfect"), 0.5, "perfect start")
		t.ok(BaitRig.survives("Perfect", 0.49) and not BaitRig.survives("Perfect", 0.5), "perfect survives half the time")
		t.ok(not BaitRig.survives("Good", 0), "good never survives")
		local p = FishData.byId.Walleye.fight
		t.ok(FightModel.minSeconds(p, false, 0.5) < FightModel.minSeconds(p, false), "a higher start is a shorter fight")
	end)

	t.test("Tackle Box: best grade per bait and a Perfect count", function()
		local tackle = { best = {}, perfects = 0 }
		BaitRig.record(tackle, "Worm", "Okay")
		t.eq(tackle.best.Worm, "Okay", "first")
		BaitRig.record(tackle, "Worm", "Perfect")
		BaitRig.record(tackle, "Worm", "Good")
		t.eq(tackle.best.Worm, "Perfect", "best kept")
		t.eq(tackle.perfects, 1, "perfects")
		BaitRig.record(tackle, "Minnow", "Perfect")
		t.eq(tackle.perfects, 2, "perfects across baits")
		t.eq(tackle.best.Cricket, nil, "untouched")
	end)

	----------------------------------------------------------------------------------------
	-- The lures (L3b)

	t.test("live bait list is still the four live baits", function()
		for _, bait in LIVE do
			t.eq(BaitData.byId[bait].kind, "live", bait)
		end
		for _, bait in LURES do
			t.eq(BaitData.byId[bait].kind, "lure", bait)
		end
	end)

	t.test("spinner: five taps on the beat, then a hold; a learned knot takes 6 seconds or less", function()
		local r = BaitRig.recipeFor("Spinner") :: BaitRig.Recipe
		t.eq(r.kind, "mixed", "kind")
		t.eq(r.presses, 6, "five wraps and a pull")
		for i = 1, 5 do
			t.eq(BaitRig.moveOf(r, i), "tap", "wrap " .. i)
		end
		t.eq(BaitRig.moveOf(r, 6), "hold", "pull snug")
		t.ok(math.abs(r.sweep - 0.45) < 1e-9, "a wrap every 0.45 s at full speed")
		local tl = BaitRig.perfectTimeline(r, false)
		for i = 2, 5 do
			t.ok(math.abs((tl[i].down - tl[i - 1].down) - r.sweep) < 1e-6, "steady beat " .. i)
		end
		t.ok(tl[6].up + BaitRig.LEAD_IN <= 6, "knot took " .. tl[6].up)
		t.eq(r.tip, "Five wraps, back through the loop, then pull it snug.", "tip")
		local ht, hl = BaitRig.windowOf(r, 6)
		t.ok(ht < hl and ht ~= r.tight, "the pull has its own windows")
	end)

	t.test("spinner: sloppy wraps or a bad pull are Okay, near misses Good", function()
		local r = BaitRig.recipeFor("Spinner") :: BaitRig.Recipe
		local tl = BaitRig.perfectTimeline(r, false)
		-- One wrap a bit off the beat (inside loose, outside tight): Good.
		local off = (r.tight + r.loose) / 2 * r.sweep
		t.eq((BaitRig.grade(r, shift(tl, off, 3), false)), "Good", "one wrap a little late")
		-- One wrap right between beats: Okay.
		t.eq((BaitRig.grade(r, shift(tl, 0.5 * r.sweep, 4), false)), "Okay", "one wrap off the beat")
		-- Pulled too hard (the bar overflowed): Okay.
		local kinked = table.clone(tl)
		kinked[6] = { down = tl[6].down, up = tl[6].down + r.fillTime * 1.1 }
		t.eq((BaitRig.grade(r, kinked, false)), "Okay", "kinked")
		-- Too loose.
		local slack = table.clone(tl)
		slack[6] = { down = tl[6].down, up = tl[6].down + r.fillTime * 0.3 }
		t.eq((BaitRig.grade(r, slack, false)), "Okay", "too loose")
		-- Only four wraps and the pull: not finished, Okay.
		local four = { tl[1], tl[2], tl[3], tl[4], tl[6] }
		t.eq((BaitRig.grade(r, four, false)), "Okay", "four wraps")
	end)

	t.test("spinner: impossible knots are refused", function()
		local r = BaitRig.recipeFor("Spinner") :: BaitRig.Recipe
		local tl = BaitRig.perfectTimeline(r, false)
		-- Wraps machine-gunned faster than hands can (0.05 s apart).
		local fast = {}
		for i = 1, 5 do
			local d = 0.225 + (i - 1) * 0.05
			fast[i] = { down = d, up = d + 0.01 }
		end
		fast[6] = { down = 0.6, up = 0.6 + r.band * r.fillTime }
		t.ok(select(2, BaitRig.grade(r, fast, false)) ~= nil, "too fast")
		-- A seventh press.
		local extra = table.clone(tl)
		table.insert(extra, { down = tl[6].up + 0.5, up = tl[6].up + 0.6 })
		t.ok(select(2, BaitRig.grade(r, extra, false)) ~= nil, "seventh press")
		-- The pull pressed before the last wrap let go.
		local overlap = table.clone(tl)
		overlap[6] = { down = tl[5].down + 0.01, up = tl[5].down + 0.01 + r.band * r.fillTime }
		t.ok(select(2, BaitRig.grade(r, overlap, false)) ~= nil, "overlap")
	end)

	t.test("plastic worm: nose, slide, bury", function()
		local r = BaitRig.recipeFor("PlasticWorm") :: BaitRig.Recipe
		t.eq(r.kind, "mixed", "kind")
		t.eq(BaitRig.moveOf(r, 1), "tap", "in at the nose")
		t.eq(BaitRig.moveOf(r, 2), "hold", "slide it up")
		t.eq(BaitRig.moveOf(r, 3), "tap", "bury the point")
		t.eq(r.tip, "Hide the point in the worm and it won't snag.", "tip")
		local tl = BaitRig.perfectTimeline(r, false)
		t.eq((BaitRig.grade(r, tl, false)), "Perfect", "perfect")
		t.ok(tl[3].up + BaitRig.LEAD_IN <= 6, "learned Texas rig took " .. tl[3].up)
		-- Either swing of the worm lines its nose up with the point.
		local other = table.clone(tl)
		local half = 0.5 * r.sweep
		other[1] = { down = tl[1].down + half, up = tl[1].up + half }
		other[2] = { down = tl[2].down + half, up = tl[2].up + half }
		t.eq((BaitRig.grade(r, other, false)), "Perfect", "the other swing")
	end)

	t.test("plastic worm: a sloppy rig is Good or Okay; impossible ones are refused", function()
		local r = BaitRig.recipeFor("PlasticWorm") :: BaitRig.Recipe
		local tl = BaitRig.perfectTimeline(r, false)
		-- The slide let go a little long: Good. Far too long (torn): Okay.
		local ht, hl = BaitRig.windowOf(r, 2)
		local long = table.clone(tl)
		long[2] = { down = tl[2].down, up = tl[2].up + (ht + hl) / 2 * r.fillTime }
		t.eq((BaitRig.grade(r, long, false)), "Good", "slid a little far")
		local torn = table.clone(tl)
		torn[2] = { down = tl[2].down, up = tl[2].down + r.fillTime * 1.2 }
		t.eq((BaitRig.grade(r, torn, false)), "Okay", "torn")
		-- The bury tap way off its mark: Okay.
		t.eq((BaitRig.grade(r, shift(tl, 0.3 * r.sweep, 3), false)), "Okay", "point not buried")
		-- Refused: the bury tap pressed while the slide was still held.
		local overlap = table.clone(tl)
		overlap[3] = { down = tl[2].up - 0.1, up = tl[2].up - 0.05 }
		t.ok(select(2, BaitRig.grade(r, overlap, false)) ~= nil, "bury during the slide")
		-- Refused: the whole rig in half a second.
		local quick = { { down = 0.16, up = 0.17 }, { down = 0.32, up = 0.33 }, { down = 0.48, up = 0.49 } }
		t.ok(select(2, BaitRig.grade(r, quick, false)) ~= nil, "half a second")
	end)

	t.test("lures: the grade sets the fight start like live bait; the bite wait has its own table", function()
		for _, g in BaitRig.GRADES do
			t.eq(BaitRig.fightStart(g), BaitRig.FIGHT_START[g], g .. " fight start is shared")
			t.eq(BaitRig.biteMult(g, true), BaitRig.LURE_BITE_MULT[g], g .. " lure bite")
			t.eq(BaitRig.biteMult(g, false), BaitRig.BITE_MULT[g], g .. " live bite unchanged")
		end
		t.eq(BaitRig.biteMult("Okay", true), 1, "an Okay lure is exactly the old game")
		t.eq(BaitRig.biteMult("Perfect", true), 1, "lure bites don't speed up (economy cap, see BaitRig)")
		t.eq(BaitRig.biteMult("Perfect"), 0.8, "live bait still does")
	end)

	t.test("lures: skip waits past the pull's overflow", function()
		for _, bait in LURES do
			local r = BaitRig.recipeFor(bait) :: BaitRig.Recipe
			t.ok(BaitRig.hasHold(r), bait .. " has a hold")
			for _, first in { false, true } do
				local full = r.fillTime / (if first then BaitRig.FIRST_SPEED else 1)
				t.ok(BaitRig.skipHold(r, first) > full, bait .. " skip comes after the bar overflows")
			end
		end
		t.ok(not BaitRig.hasHold(BaitRig.recipeFor("Worm") :: BaitRig.Recipe), "worm has no hold")
	end)

	t.test("lures: an Okay spinner knot casts 5 percent shorter; nothing else changes the cast", function()
		t.eq(BaitRig.castScale("Spinner", "Okay"), 0.95, "okay knot")
		t.eq(BaitRig.castScale("Spinner", nil), 0.95, "not tied yet is Okay")
		t.eq(BaitRig.castScale("Spinner", "Good"), 1, "good knot")
		t.eq(BaitRig.castScale("Spinner", "Perfect"), 1, "perfect knot")
		for _, other in { "Worm", "Minnow", "PlasticWorm", "Stinkbait", "Cricket" } do
			t.eq(BaitRig.castScale(other, "Okay"), 1, other)
		end
		-- An Okay spinner still outcasts a worm with every rod, and a soft cast is unchanged.
		local CastLogic = require(Shared.CastLogic)
		local RodData = require(Shared.RodData)
		for _, rod in RodData.list do
			local spin = CastLogic.distance(1, rod.id, "Spinner", BaitRig.castScale("Spinner", "Okay"))
			t.ok(spin > CastLogic.distance(1, rod.id, "Worm"), rod.id)
			t.eq(CastLogic.distance(0, rod.id, "Spinner", 0.95), Config.CAST_MIN, rod.id .. " soft cast unchanged")
			t.ok(spin < CastLogic.distance(1, rod.id, "Spinner", 1), rod.id .. " shorter than a good knot")
		end
	end)
end
