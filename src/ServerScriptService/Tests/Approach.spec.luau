-- The wait (L4): approach timing, look-and-leave, twitches and spooks, shadow sizes, and the
-- bobber camera's phone check. Written 2026-11-26; UNVERIFIED in Studio until the L4 playtest.
return function(t, Shared)
	local Approach = require(Shared.Approach)
	local BobberCam = require(Shared.BobberCam)
	local FishLogic = require(Shared.FishLogic)
	local FishData = require(Shared.FishData)
	local CastLogic = require(Shared.CastLogic)
	local RodData = require(Shared.RodData)
	local BaitData = require(Shared.BaitData)

	t.test("the design numbers", function()
		t.eq(Approach.APPROACH_LEAD_MIN, 2.5, "lead min")
		t.eq(Approach.APPROACH_LEAD_MAX, 4, "lead max")
		t.eq(Approach.LOOK_LEAVE, 0.25, "look and leave")
		t.eq(Approach.TWITCH_TAP, 0.25, "tap")
		t.eq(Approach.REEL_HOLD, 0.35, "hold")
		t.eq(Approach.TWITCH_GAP, 0.3, "twitch rate limit")
		t.eq(Approach.TWITCH_SOONER_MIN, 0.5, "sooner min")
		t.eq(Approach.TWITCH_SOONER_MAX, 1.5, "sooner max")
		t.eq(Approach.SPOOK_COUNT, 3, "spook count")
		t.eq(Approach.SPOOK_WINDOW, 4, "spook window")
		t.eq(Approach.SPOOK_DELAY, 4, "spook delay")
		t.eq(Approach.WAIT_EVENT_AFTER, 8, "long wait")
		t.eq(Approach.HUGE_SHADOW_CHANCE, 0.02, "huge shadow")
	end)

	t.test("the approach sits inside the wait, 2.5 to 4 s before the strike when there's time", function()
		local rng = Random.new(7)
		for _ = 1, 2000 do
			local attempt = rng:NextNumber(0.5, 40)
			local p = Approach.plan(attempt, rng, false)
			t.ok(math.abs(p.approachIn + p.biteIn - attempt) < 1e-9, "adds up to the wait")
			t.ok(p.approachIn >= math.min(Approach.APPROACH_MIN_START, attempt * 0.5) - 1e-9, "not before the landing")
			t.ok(p.biteIn > 0 and p.biteIn <= Approach.APPROACH_LEAD_MAX + 1e-9, "lead " .. p.biteIn)
			if attempt >= Approach.APPROACH_LEAD_MAX + Approach.APPROACH_MIN_START then
				t.ok(p.biteIn >= Approach.APPROACH_LEAD_MIN - 1e-9, "full lead on a long wait " .. p.biteIn)
			end
		end
	end)

	t.test("a quarter of approaching fish look and leave; a rise's fish never does", function()
		local rng = Random.new(19)
		local n, left = 20000, 0
		for _ = 1, n do
			if Approach.plan(10, rng, false).leaves then
				left += 1
			end
			t.ok(not Approach.plan(2, rng, true).leaves, "rise fish stays")
		end
		local share = left / n
		t.ok(share > 0.23 and share < 0.27, "leave share " .. share)
		t.eq(Approach.attemptDelay(2.5, true), 2.5, "a rise keeps its quick bite")
		t.eq(Approach.attemptDelay(8, false), 8 * Approach.ATTEMPT_SCALE, "others wait a scaled attempt")
	end)

	-- Time from the cast to the strike under the new flow (no twitches): attempts repeat
	-- until a fish doesn't leave, each one a fresh delay draw.
	local function newTotal(weights, rng): number
		local total = 0
		for _ = 1, 100 do
			local delay = FishLogic.biteDelay(weights, rng) :: number
			local attempt = Approach.attemptDelay(delay, false)
			local p = Approach.plan(attempt, rng, false)
			total += attempt
			if not p.leaves then
				return total
			end
		end
		return total
	end

	t.test("an Okay player's average wait for a bite is unchanged", function()
		local combos = {
			{ "Dock", "Day", "Worm" },
			{ "WeedBed", "Day", "Cricket" },
			{ "DeepHole", "Night", "Stinkbait" },
			{ "Pool", "Night", "Minnow" },
			{ "Dock", "Night", "Worm" },
		}
		for _, c in combos do
			local weights = FishLogic.biteWeights(c[1], c[2], c[3])
			if #weights > 0 then
				local rng = Random.new(101)
				local n = 20000
				local old, new = 0, 0
				for _ = 1, n do
					old += FishLogic.biteDelay(weights, rng) :: number
					new += newTotal(weights, rng)
				end
				old /= n
				new /= n
				t.ok(math.abs(new - old) / old < 0.03, string.format("%s %s %s: old %.2f s, new %.2f s", c[1], c[2], c[3], old, new))
			end
		end
	end)

	t.test("a twitch keeps a looker and brings the bite sooner; only the first per fish counts", function()
		local rng = Random.new(5)
		local tw = Approach.newTwitches()
		local kind, sooner = Approach.twitch(tw, 10, true, rng)
		t.eq(kind, "sooner", "first twitch")
		t.ok(sooner >= 0.5 and sooner <= 1.5, "sooner " .. sooner)
		kind = Approach.twitch(tw, 10.1, true, rng)
		t.eq(kind, "ignored", "rate limited")
		kind = Approach.twitch(tw, 10.5, true, rng)
		t.eq(kind, "jiggle", "second twitch just jiggles")
		Approach.onApproach(tw)
		kind = Approach.twitch(tw, 20, true, rng)
		t.eq(kind, "sooner", "the next fish reacts again")
	end)

	t.test("twitches with no fish there only jiggle", function()
		local rng = Random.new(6)
		local tw = Approach.newTwitches()
		for i = 1, 10 do
			t.eq((Approach.twitch(tw, i * 0.5, false, rng)), "jiggle", "no fish " .. i)
		end
	end)

	t.test("three twitches inside 4 s spook an approaching fish; spaced out they don't", function()
		local rng = Random.new(8)
		local tw = Approach.newTwitches()
		t.eq((Approach.twitch(tw, 0, true, rng)), "sooner", "one")
		t.eq((Approach.twitch(tw, 1, true, rng)), "jiggle", "two")
		t.eq((Approach.twitch(tw, 2, true, rng)), "spook", "three")
		-- Spaced out: never three inside the window.
		local tw2 = Approach.newTwitches()
		for i = 0, 10 do
			local k = Approach.twitch(tw2, i * 2.1, true, rng)
			t.ok(k ~= "spook", "spaced twitch " .. i .. " was " .. k)
		end
		-- Spamming before the fish arrives scares it off when it gets there.
		local tw3 = Approach.newTwitches()
		Approach.twitch(tw3, 0, false, rng)
		Approach.twitch(tw3, 0.5, false, rng)
		Approach.onApproach(tw3)
		t.eq((Approach.twitch(tw3, 1.0, true, rng)), "spook", "spam then arrival")
	end)

	t.test("a sooner bite always leaves the held breath and is never later", function()
		local rng = Random.new(9)
		for _ = 1, 500 do
			local now = rng:NextNumber(0, 100)
			local biteAt = now + rng:NextNumber(Approach.HUSH_TIME, 5)
			local s = rng:NextNumber(0.5, 1.5)
			local b = Approach.soonerBiteAt(biteAt, now, s)
			t.ok(b <= biteAt + 1e-9, "never later")
			t.ok(b >= now + Approach.HUSH_TIME - 1e-9, "room for the held breath")
			t.ok(b >= biteAt - s - 1e-9, "no more than the twitch's worth sooner")
		end
	end)

	t.test("a quick tap twitches, a hold reels in, nothing in between", function()
		t.eq(Approach.pressKind(0.1, true), "twitch", "tap")
		t.eq(Approach.pressKind(0.24, true), "twitch", "quick tap")
		t.eq(Approach.pressKind(0.3, true), nil, "in between")
		t.eq(Approach.pressKind(0.2, false), nil, "still held, short")
		t.eq(Approach.pressKind(0.35, false), "reel", "held long enough")
		t.eq(Approach.pressKind(1, true), "reel", "long hold")
	end)

	t.test("the shadow is the hung catch's length, and its size class is honest", function()
		t.eq(Approach.shadowLength(24), 2, "24 cm is 2 studs")
		t.eq(Approach.shadowLength(5), 1, "never under a stud")
		t.eq(Approach.shadowLength(200), 8, "never over 8")
		for _, s in FishData.list do
			local small = Approach.sizeClass(s.minCm)
			local big = Approach.sizeClass(s.maxCm * 1.35)
			t.ok(Approach.shadowLength(s.minCm) <= Approach.shadowLength(s.maxCm), s.id .. " grows")
			t.ok(small ~= "large" or big == "large", s.id .. " size classes in order")
		end
		local bluegill = FishData.byId.Bluegill
		t.eq(Approach.sizeClass(bluegill.maxCm), "small", "a big bluegill is still small")
		t.eq(Approach.sizeClass(40), "medium", "40 cm")
		t.eq(Approach.sizeClass(70), "large", "70 cm")
	end)

	t.test("big or rare fish announce themselves", function()
		t.ok(Approach.announces("Rare", "small"), "Rare")
		t.ok(Approach.announces("Legendary", nil), "Legendary")
		t.ok(Approach.announces("Common", "large"), "large mouth")
		t.ok(not Approach.announces("Common", "small"), "a common panfish is quiet")
		t.ok(not Approach.announces("Uncommon", "medium"), "uncommon medium is quiet")
		t.ok(not Approach.announces(nil, nil), "unknown is quiet")
	end)

	t.test("the bobber is at least 24 px tall on a 375 px tall phone at every cast distance", function()
		local reach = 0
		for _, rod in RodData.list do
			for _, b in BaitData.list do
				reach = math.max(reach, CastLogic.distance(1, rod.id, b.id))
			end
		end
		t.ok(reach > 40, "the longest cast " .. reach)
		local camHeight = 5 -- the camera sits about this far above the water
		local d = 8
		while d <= reach do
			local back = d - BobberCam.pull(d) + BobberCam.DEFAULT_ZOOM
			local dist = math.sqrt(back * back + camHeight * camHeight)
			local fov = BobberCam.fovFor(BobberCam.BOBBER_HEIGHT, dist, 375, 70)
			local px = BobberCam.pixels(BobberCam.BOBBER_HEIGHT, dist, 375, fov)
			t.ok(px >= BobberCam.MIN_PX, string.format("cast %.0f studs: %.1f px at fov %.1f", d, px, fov))
			t.ok(fov <= 70 + 1e-9 and fov >= BobberCam.MIN_FOV - 1e-9, "fov in range " .. fov)
			d += 2
		end
	end)

	t.test("on a big screen a mid-range bobber needs no zoom", function()
		t.eq(BobberCam.fovFor(BobberCam.BOBBER_HEIGHT, 40, 1080, 70), 70, "desktop, mid cast")
		t.ok(BobberCam.fovFor(BobberCam.BOBBER_HEIGHT, 40, 375, 70) < 70, "phone, same cast leans in")
		t.eq(BobberCam.pull(100), BobberCam.PULL_MAX, "pull is capped")
		t.eq(BobberCam.ease(0), 0, "ease start")
		t.eq(BobberCam.ease(1), 1, "ease end")
	end)
end
