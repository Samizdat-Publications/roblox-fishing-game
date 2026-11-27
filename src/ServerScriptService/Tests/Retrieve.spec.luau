-- Work the lure (L4c): the spinner's speed band, the worm's fall window, snags when a lure is
-- left still on a log or in the weeds (a Perfect worm slides through the weeds), the timeline
-- checks, and the economy rule: worked well, a lure strikes on average after the same time a
-- bobber would bite. Written 2026-11-27; UNVERIFIED in Studio until the L4c playtest.
return function(t, Shared)
	local Retrieve = require(Shared.Retrieve)
	local Config = require(Shared.Config)
	local Cover = require(Shared.Cover)

	local OPEN = Vector3.new(20, 0, 100) -- open water, far from every log, the dock and the weeds
	local FAR = Vector3.new(20, 0, 600) -- a caster so far away the lure never gets back

	local function near(a: number, b: number, tol: number, msg: string)
		t.ok(math.abs(a - b) <= tol, string.format("%s: expected %.3f within %.3f, got %.3f", msg, b, tol, a))
	end

	local function run(lure: string, presses, upTo: number, land: Vector3?, origin: Vector3?, grade: string?)
		local s, why = Retrieve.score(lure, grade or "Okay", land or OPEN, origin or FAR, presses, upTo)
		t.eq(why, nil, "refused")
		return s :: Retrieve.State
	end

	-- Switched on 11/27/2026 after the Studio playtest (spinner, worm, no strike, snag).
	t.test("switched on; only the lures are worked", function()
		t.eq(Config.LURE_RETRIEVE_ON, true, "LURE_RETRIEVE_ON")
		t.ok(Retrieve.isLure("Spinner"), "spinner")
		t.ok(Retrieve.isLure("PlasticWorm"), "plastic worm")
		for _, live in { "Worm", "Cricket", "Minnow", "Stinkbait" } do
			t.ok(not Retrieve.isLure(live), live)
		end
	end)

	----------------------------------------------------------------------------------------
	-- Spinner

	t.test("spinner: the meter reads too slow, just right and too fast at the band's edges", function()
		t.eq(Retrieve.band(0), "slow", "stopped")
		t.eq(Retrieve.band(Retrieve.BAND_LO - 0.01), "slow", "just under")
		t.eq(Retrieve.band(Retrieve.BAND_LO), "right", "bottom of the band")
		t.eq(Retrieve.band((Retrieve.BAND_LO + Retrieve.BAND_HI) / 2), "right", "middle")
		t.eq(Retrieve.band(Retrieve.BAND_HI), "right", "top of the band")
		t.eq(Retrieve.band(Retrieve.BAND_HI + 0.01), "fast", "just over")
		t.eq(Retrieve.band(Retrieve.SPIN_MAX), "fast", "ripping")
	end)

	t.test("spinner: worked steadily it is in the band nearly all the time, and comes back in 6 to 12 s from 20 to 40 studs", function()
		local s = run("Spinner", Retrieve.wellTimeline("Spinner", 12), 10)
		t.ok(s.good / 10 >= 0.85, string.format("good share %.2f", s.good / 10))
		near(s.good / 10, Retrieve.WELL_SHARE.Spinner, 0.03, "WELL_SHARE matches the well-worked retrieve")
		-- Average speed of a well-worked retrieve, from the landing.
		local studsPerSec = s.traveled / 10
		for _, cast in { 20, 40 } do
			local secs = (cast - Retrieve.END_DIST) / studsPerSec
			t.ok(secs >= 5 and secs <= 13, string.format("%d stud cast comes back in %.1f s", cast, secs))
		end
	end)

	t.test("spinner: left still, or held flat out the whole way, scores (almost) nothing", function()
		local still = run("Spinner", {}, 10)
		t.eq(still.good, 0, "never reeled")
		t.eq(still.traveled, 0, "never moved")
		near(still.depth, math.min(Retrieve.BOTTOM, Retrieve.SINK_RATE * 10), 1e-6, "it sank")
		local ripped = run("Spinner", { { down = 0.1, up = 9.9 } }, 10)
		-- Only the moment it speeds through the band on the way up counts.
		local through = (Retrieve.BAND_HI - Retrieve.BAND_LO) / Retrieve.SPIN_ACCEL
		near(ripped.good, through, 0.1, "held flat out")
		t.ok(ripped.speed > Retrieve.BAND_HI, "too fast")
		t.ok(ripped.good / 10 < 0.1, "ripping it is not a retrieve")
	end)

	t.test("spinner: too slow (short dabs) scores nothing", function()
		local presses = {}
		local tt = 0.2
		while tt < 10 do
			table.insert(presses, { down = tt, up = tt + 0.15 }) -- 0.45 studs/s gained, 2.5 lost per second
			tt += 1
		end
		local s = run("Spinner", presses, 10)
		t.eq(s.good, 0, "dabs")
		t.ok(s.speed < Retrieve.BAND_LO, "too slow")
	end)

	t.test("spinner: stopped over a log or in the weed core it sinks and snags; moving it doesn't; open water never snags", function()
		local log = Vector3.new(70, 0, 55) -- the middle of a log (Cover's LOGS)
		local weeds = Vector3.new(Cover.WEED_CORE.x, 0, Cover.WEED_CORE.z)
		for _, at in { log, weeds } do
			local s = run("Spinner", {}, 5, at, FAR)
			t.ok(s.snagged, "snagged when left to sink at " .. tostring(at))
			near(s.t, Retrieve.SNAG_DEPTH / Retrieve.SINK_RATE, 0.05, "snags once it has sunk SNAG_DEPTH")
		end
		-- Reeled steadily out of the weed core from its middle: no snag.
		local out = run("Spinner", Retrieve.wellTimeline("Spinner", 12), 10, weeds, weeds + Vector3.new(0, 0, 200))
		t.ok(not out.snagged, "kept moving")
		t.ok(out.traveled > Cover.WEED_CORE.hz, "and left the core")
		local open = run("Spinner", {}, 30)
		t.ok(not open.snagged, "open water")
		t.eq(open.depth, Retrieve.BOTTOM, "on the bottom")
	end)

	----------------------------------------------------------------------------------------
	-- Plastic worm

	local splashFall = Retrieve.FALL_END - Retrieve.FALL_START -- the cast's own sink is a fall

	t.test("worm: the strike window is the fall right after a pull", function()
		local s = run("PlasticWorm", { { down = 2, up = 2.1 } }, 8)
		near(s.good, splashFall * 2, 1e-6, "the splashdown fall and one pull's fall")
		near(s.traveled, Retrieve.hopDistance(0.1), 1e-6, "one tap moves it a little")
		-- Pulling again before the fall starts gets nothing for that pull.
		local cut = run("PlasticWorm", { { down = 2, up = 2.1 }, { down = 2.3, up = 2.4 } }, 8)
		near(cut.good, splashFall * 2, 1e-6, "only the second pull's fall counts")
		-- Pulling again in the middle of the fall cuts it short.
		local half = run("PlasticWorm", { { down = 2, up = 2.1 }, { down = 2.9, up = 3.0 } }, 8)
		near(half.good, splashFall + (2.9 - 2.4) + splashFall, 1e-6, "a cut fall counts up to the next pull")
	end)

	t.test("worm: hopped well it is in the fall window most of the time", function()
		local s = run("PlasticWorm", Retrieve.wellTimeline("PlasticWorm", 12), 10)
		near(s.good / 10, Retrieve.WELL_SHARE.PlasticWorm, 0.03, "WELL_SHARE matches the well-hopped retrieve")
	end)

	t.test("worm: dragged nonstop, ripped fast or left still scores nothing after the splashdown", function()
		local dragged = run("PlasticWorm", { { down = 1.6, up = 9 } }, 10)
		near(dragged.good, splashFall, 1e-6, "dragged")
		t.ok(dragged.traveled > 15, "a drag moves it a long way")
		local presses = {}
		local tt = 1.6
		while tt < 10 do
			table.insert(presses, { down = tt, up = tt + 0.05 })
			tt += 0.25 -- faster than the fall can start
		end
		local ripped = run("PlasticWorm", presses, 10)
		near(ripped.good, splashFall, 1e-6, "ripped")
		local still = run("PlasticWorm", {}, 10)
		near(still.good, splashFall, 1e-6, "left still")
	end)

	t.test("worm: left still in the weeds it snags unless rigged weedless (Perfect); on a log it snags anyway", function()
		local weeds = Vector3.new(Cover.WEED_CORE.x, 0, Cover.WEED_CORE.z)
		local log = Vector3.new(70, 0, 55)
		local okay = run("PlasticWorm", {}, 5, weeds, FAR, "Okay")
		t.ok(okay.snagged, "Okay worm in the weeds")
		near(okay.t, Retrieve.REST_SNAG, 0.05, "after resting REST_SNAG")
		local perfect = run("PlasticWorm", {}, 10, weeds, FAR, "Perfect")
		t.ok(not perfect.snagged, "a Perfect Texas rig is weedless")
		local onLog = run("PlasticWorm", {}, 5, log, FAR, "Perfect")
		t.ok(onLog.snagged, "still snags on a log (Cover.weedless is weeds only)")
		-- Hopped through the weeds, never resting long, an Okay worm doesn't snag.
		local hopped = run("PlasticWorm", Retrieve.wellTimeline("PlasticWorm", 12), 10, weeds, FAR, "Okay")
		t.ok(not hopped.snagged, "kept hopping")
		local open = run("PlasticWorm", {}, 30, OPEN, FAR, "Okay")
		t.ok(not open.snagged, "open water")
	end)

	----------------------------------------------------------------------------------------
	-- The end of the cast

	t.test("a lure that reaches the caster ends the cast", function()
		local origin = OPEN + Vector3.new(0, 0, 20)
		local s = run("Spinner", Retrieve.wellTimeline("Spinner", 30), 30, OPEN, origin)
		t.ok(s.done, "done")
		near(s.traveled, 20 - Retrieve.END_DIST, 1e-6, "stops END_DIST short of the caster")
		near((Retrieve.position(s) - Vector3.new(origin.X, Retrieve.position(s).Y, origin.Z)).Magnitude, Retrieve.END_DIST, 1e-6, "position")
		t.ok(s.t < 30, "stopped running")
		local w = run("PlasticWorm", { { down = 1, up = 20 } }, 30, OPEN, origin)
		t.ok(w.done, "a dragged worm comes back too")
		local close = Retrieve.new("Spinner", "Okay", OPEN, OPEN + Vector3.new(0, 0, 2))
		t.ok(close.done, "a cast at your feet is already back")
		local idle = Retrieve.new("PlasticWorm", "Okay", OPEN, FAR)
		Retrieve.advance(idle, Retrieve.MAX_TIME + 5)
		t.ok(idle.done, "MAX_TIME ends a lure left sitting")
	end)

	----------------------------------------------------------------------------------------
	-- The server's checks

	t.test("the scorer refuses timelines no player could make", function()
		local bad = {
			{ { down = -0.1, up = 0.2 } },
			{ { down = 1, up = 0.5 } },
			{ { down = 1, up = 1.1 }, { down = 1.12, up = 1.2 } }, -- presses 0.12 apart are fine...
			{ { down = 1, up = 1.01 }, { down = 1.05, up = 1.1 } }, -- ...0.05 apart are not
			{ { down = 1, up = 2 }, { down = 1.5, up = 2.5 } },
			{ { down = 1 }, { down = 2, up = 2.1 } },
			{ { down = 0 / 0, up = 1 } },
			{ { down = Retrieve.MAX_TIME + 5, up = Retrieve.MAX_TIME + 6 } },
			"nope",
		}
		local expectOk = { [3] = true }
		for i, tl in bad do
			local why = Retrieve.refusal(tl)
			if expectOk[i] then
				t.eq(why, nil, "case " .. i)
			else
				t.ok(why ~= nil, "case " .. i .. " should be refused")
				local s = Retrieve.score("Spinner", "Okay", OPEN, FAR, tl, 10)
				t.eq(s, nil, "score refuses case " .. i)
			end
		end
		local many = {}
		for i = 1, Retrieve.MAX_PRESSES + 1 do
			table.insert(many, { down = i * 0.2, up = i * 0.2 + 0.05 })
		end
		t.ok(Retrieve.refusal(many) ~= nil, "too many presses")
		t.eq(Retrieve.refusal(Retrieve.wellTimeline("Spinner", 20)), nil, "a well-worked spinner")
		t.eq(Retrieve.refusal(Retrieve.wellTimeline("PlasticWorm", 20)), nil, "a well-hopped worm")
		t.eq(Retrieve.refusal({ { down = 1 } }), nil, "the last press may still be held")
	end)

	t.test("streamed one event at a time it scores the same as the whole timeline", function()
		for _, lure in { "Spinner", "PlasticWorm" } do
			local tl = Retrieve.wellTimeline(lure, 12)
			local s = Retrieve.new(lure, "Okay", OPEN, FAR)
			local presses = {}
			local events = {}
			for _, p in tl do
				table.insert(events, { "down", p.down })
				table.insert(events, { "up", p.up })
			end
			local i = 1
			local now = 0
			while now < 10 do
				now += Retrieve.TICK
				while events[i] and events[i][2] <= now do
					local e = events[i]
					t.eq(Retrieve.acceptEvent(presses, e[1], e[2]), nil, "event " .. i)
					Retrieve.addEvent(presses, e[1], e[2])
					if e[1] == "down" then
						Retrieve.press(s, e[2])
					else
						Retrieve.release(s, e[2])
					end
					i += 1
				end
				Retrieve.advance(s, now)
			end
			local ref = run(lure, tl, s.t)
			near(s.good, ref.good, 1e-6, lure .. " good")
			near(s.traveled, ref.traveled, 1e-6, lure .. " traveled")
			t.ok(Retrieve.acceptEvent(presses, "up", now) ~= nil or presses[#presses].up == nil, "can't let go twice")
		end
	end)

	----------------------------------------------------------------------------------------
	-- The economy rule

	-- One cast worked the way wellTimeline does, ticking like the server. Returns the seconds to
	-- a strike, or nil and the seconds the cast lasted when the lure came back first.
	local function workCast(lure: string, delay: number, rng: Random, studs: number): (number?, number)
		local tl = Retrieve.wellTimeline(lure, Retrieve.MAX_TIME)
		local s = Retrieve.new(lure, "Okay", OPEN, OPEN + Vector3.new(0, 0, studs))
		local events = {}
		for _, p in tl do
			table.insert(events, { true, p.down })
			table.insert(events, { false, p.up })
		end
		local i, last, now = 1, 0, 0
		while not s.done and now < Retrieve.MAX_TIME do
			now += Retrieve.TICK
			while events[i] and events[i][2] <= now do
				if events[i][1] then
					Retrieve.press(s, events[i][2])
				else
					Retrieve.release(s, events[i][2])
				end
				i += 1
			end
			Retrieve.advance(s, now)
			if rng:NextNumber() < Retrieve.strikeChance(s.good - last, delay, lure) then
				return now, now
			end
			last = s.good
		end
		return nil, now
	end

	t.test("worked well, in the water a lure strikes after its RECAST_PAYBACK share of the bobber's delay", function()
		for _, lure in { "Spinner", "PlasticWorm" } do
			for _, delay in { 6, 10, 15 } do
				local rng = Random.new(4242 + delay)
				local total, n = 0, 1200
				for _ = 1, n do
					local struck, lasted = workCast(lure, delay, rng, 2000)
					total += struck or lasted
				end
				local mean = total / n
				local want = delay * Retrieve.RECAST_PAYBACK[lure]
				-- (the spinner's first second, getting up to speed, isn't good retrieve yet)
				t.ok(math.abs(mean / want - 1) <= 0.12, string.format("%s, delay %d: mean strike after %.2f s, want %.2f", lure, delay, mean, want))
			end
		end
	end)

	t.test("worked well from 30 studs out, recasts and all, a lure strikes as soon as a bobber bites", function()
		local RECAST = 1.7 -- charge, cast and flight (tools/econ/sim.py CAST_OVERHEAD)
		for _, lure in { "Spinner", "PlasticWorm" } do
			for _, delay in { 6, 10, 15 } do
				local rng = Random.new(777 + delay)
				local total, n = 0, 1200
				for _ = 1, n do
					local spent = 0
					while true do
						local struck, lasted = workCast(lure, delay, rng, 30)
						if struck then
							spent += struck
							break
						end
						spent += lasted + RECAST
					end
					total += spent
				end
				local mean = total / n
				t.ok(math.abs(mean / delay - 1) <= 0.15, string.format("%s, delay %d: mean strike after %.2f s with recasts", lure, delay, mean))
			end
		end
	end)

	t.test("nothing strikes without good retrieve, or where nothing wants the lure", function()
		t.eq(Retrieve.strikeChance(0, 5, "Spinner"), 0, "no good seconds")
		t.eq(Retrieve.strikeChance(3, nil, "Spinner"), 0, "nothing here")
		local a = Retrieve.strikeChance(1, 5, "Spinner")
		local b = Retrieve.strikeChance(1, 10, "Spinner")
		t.ok(a > b and b > 0, "a slower spot strikes less per second")
	end)
end
