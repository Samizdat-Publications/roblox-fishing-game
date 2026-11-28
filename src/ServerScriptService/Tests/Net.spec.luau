-- The landing net (leg 3, N4, Config.NET_ON). Written 11/27/2026; UNVERIFIED in Studio.
return function(t, Shared)
	local Net = require(Shared.Net)

	t.test("the net comes out at 70 percent and goes away below 66", function()
		t.ok(not Net.open(false, 0.69), "not yet")
		t.ok(Net.open(false, 0.7), "at 70")
		t.ok(Net.open(true, 0.67), "stays open just under")
		t.ok(not Net.open(true, 0.6), "closes when the fish pulls back")
	end)

	t.test("the fish surfaces on a steady beat", function()
		local o = 100
		t.ok(not (Net.surfacing(o, o + 0.5)), "not up straight away")
		local up, at = Net.surfacing(o, o + Net.FIRST_UP + 0.1)
		t.ok(up, "up at the first surfacing")
		t.ok(math.abs(at - (o + Net.FIRST_UP)) < 1e-9, "which started then")
		local up2, nxt = Net.surfacing(o, o + Net.FIRST_UP + Net.UP_FOR + 0.2)
		t.ok(not up2, "down again")
		t.ok(math.abs(nxt - (o + Net.FIRST_UP + Net.UP_EVERY)) < 1e-9, "next one on the beat")
		t.ok((Net.surfacing(o, o + Net.FIRST_UP + Net.UP_EVERY * 3 + 0.3)), "still on the beat later")
	end)

	t.test("a well-timed press lands it", function()
		local h = {}
		t.eq(Net.press(h, 0, Net.FIRST_UP + 0.2), "landed")
	end)

	t.test("a miss costs nothing and you can try again after 2 seconds", function()
		local h = {}
		local miss = Net.FIRST_UP + Net.UP_FOR + Net.SLACK + 0.3 -- down, past the slack
		t.eq(Net.press(h, 0, miss), "missed", "mistimed")
		t.eq(Net.press(h, 0, miss + 1), "wait", "too soon to try again")
		local nextUp = Net.FIRST_UP + Net.UP_EVERY
		if nextUp - miss < Net.RETRY then
			t.eq(Net.press(h, 0, nextUp + 0.1), "wait", "a surfacing inside the 2 seconds is still the wait")
			nextUp += Net.UP_EVERY
		end
		t.eq(Net.press(h, 0, nextUp + 0.1), "landed", "the retry lands it")
	end)

	t.test("a press just after it goes down still counts (the round trip)", function()
		t.ok(Net.pressHits(0, Net.FIRST_UP + Net.UP_FOR + Net.SLACK * 0.5), "within the slack")
		t.ok(not Net.pressHits(0, Net.FIRST_UP + Net.UP_FOR + Net.SLACK + 0.05), "past it")
	end)

	t.test("the server believes progress only as fast as a fish can really be won", function()
		-- Start at 0.4, fastest win 6 s (5.4 with the slack): at 1 s the most is about 0.53.
		local m = Net.maxProgress(0.4, 6, 1)
		t.ok(m > 0.5 and m < 0.54, "max at 1 s: " .. m)
		t.eq(Net.maxProgress(0.4, 6, 100), 1, "never past 1")
		t.ok(math.abs(Net.acceptProgress(0.9, 0.4, 6, 1) :: number - m) < 1e-9, "a too-fast claim is clamped")
		t.eq(Net.acceptProgress(0.45, 0.4, 6, 1), 0.45, "an honest one is taken")
		t.eq(Net.acceptProgress("lots", 0.4, 6, 1), nil, "junk")
		t.eq(Net.acceptProgress(0 / 0, 0.4, 6, 1), nil, "NaN")
		t.eq(Net.acceptProgress(-3, 0.4, 6, 10), 0, "clamped at 0")
		-- 70 percent is reachable in time: 0.4 to 0.7 is half the climb, so about 2.7 s at the fastest.
		t.ok(Net.maxProgress(0.4, 6, 2.8) >= Net.THRESHOLD, "70 percent possible by 2.8 s")
	end)

	t.test("within 10 studs (the same boat or the same dock), with a little slack", function()
		t.ok(Net.inReach(Vector3.new(0, 0, 0), Vector3.new(8, 3, 0)), "8 studs")
		t.ok(Net.inReach(Vector3.new(0, 0, 0), Vector3.new(12, 0, 0)), "12 with slack")
		t.ok(not Net.inReach(Vector3.new(0, 0, 0), Vector3.new(20, 0, 0)), "20 is too far")
	end)
end
