-- Coming back tomorrow (L6d): the chalkboard, fish of the day, rumour, the daily tackle box,
-- the "While You Were Away" card, and one forecast per real date. Written 2026-11-27.
return function(t, Shared)
	local Daily = require(Shared.Daily)
	local Weather = require(Shared.Weather)
	local FishData = require(Shared.FishData)
	local Rarity = require(Shared.Rarity)
	local BaitData = require(Shared.BaitData)
	local Units = require(Shared.Units)

	local DAY = 20419 -- a Thursday (27 November 2025, UTC)
	local EM_DASH = utf8.char(0x2014)
	local LAKE_OR_CREEK = { Dock = true, WeedBed = true, Logs = true, DeepHole = true, OpenWater = true, Riffle = true, Rocks = true, Pool = true }

	local function plain(text: string, what: string)
		t.ok(#text > 0, what .. " is empty")
		t.ok(not string.find(text, EM_DASH, 1, true), what .. " has an em dash: " .. text)
		t.ok(not string.find(text, "%%"), what .. " has a stray format: " .. text)
	end

	t.test("the fish of the day is a Common or Uncommon lake or creek fish, the same all day", function()
		local choices = Daily.fishOfDayChoices()
		t.ok(#choices >= 5, "enough choices: " .. #choices)
		for _, s in choices do
			t.ok((Rarity.rank[Rarity.of(s)] or 9) <= 2, s.id .. " too rare")
			t.ok(s.weather == nil, s.id .. " is weather-only")
			local home = false
			for spot in s.spots do
				home = home or LAKE_OR_CREEK[spot] == true
			end
			t.ok(home, s.id .. " is not in the lake or creek")
		end
		for day = DAY, DAY + 60 do
			local id = Daily.fishOfDay(day)
			t.eq(id, Daily.fishOfDay(day), "same answer twice")
			local ok = false
			for _, s in choices do
				ok = ok or s.id == id
			end
			t.ok(ok, "pick is a choice: " .. id)
		end
	end)

	t.test("the fish of the day changes, every choice comes up, and it isn't tied to the weekday", function()
		local seen, n, changes = {}, 0, 0
		for day = DAY, DAY + 89 do
			local id = Daily.fishOfDay(day)
			if not seen[id] then
				seen[id] = true
				n += 1
			end
			if id ~= Daily.fishOfDay(day - 1) then
				changes += 1
			end
		end
		t.eq(n, #Daily.fishOfDayChoices(), "every choice in 90 days")
		t.ok(changes >= 60, "changes most days: " .. changes)
		local sameWeekday = 0
		for w = 1, 10 do
			if Daily.fishOfDay(DAY + 7 * w) == Daily.fishOfDay(DAY) then
				sameWeekday += 1
			end
		end
		t.ok(sameWeekday < 6, "not the same fish every Thursday")
	end)

	t.test("the boost lifts only the fish of the day, only where it already bites", function()
		local w = { { id = "Bluegill", w = 1 }, { id = "Pumpkinseed", w = 0.9 } }
		local b = Daily.boost(w, "Pumpkinseed")
		t.eq(b[1].id, "Pumpkinseed", "re-sorted heaviest first")
		t.ok(math.abs(b[1].w - 0.9 * Daily.FISH_OF_DAY_BOOST) < 1e-9, "boosted")
		t.eq(b[2].w, 1, "others untouched")
		t.eq(w[2].w, 0.9, "the input list isn't changed")
		local none = Daily.boost(w, "LakeSturgeon")
		t.eq(#none, 2, "never adds a fish")
		t.eq(none[1].w, 1)
		t.ok(Daily.FISH_OF_DAY_BOOST > 1 and Daily.FISH_OF_DAY_BOOST <= 1.5, "a little, not a lot")
	end)

	t.test("the rumour is hearsay about a Legendary, true to its habits", function()
		local kinds = {}
		for day = DAY, DAY + 60 do
			local r = Daily.rumour(day, false)
			local s = FishData.byId[r.species]
			t.eq(Rarity.of(s), "Legendary", r.species)
			plain(r.text, "rumour")
			t.ok(string.find(r.text, s.name, 1, true) ~= nil, "names the fish")
			t.ok(string.find(r.text, "say") or string.find(r.text, "swear"), "worded as hearsay: " .. r.text)
			kinds[r.kind] = true
			if r.kind == "spot" then
				t.ok((s.spots[r.hint] or 0) > 0 and LAKE_OR_CREEK[r.hint], "spot it lives in: " .. r.hint)
			elseif r.kind == "time" then
				t.ok((s.periods[r.hint] or 0) >= 0.5, "a time it feeds: " .. r.hint)
			else
				t.ok((s.baits[r.hint] or 0) >= 0.5, "a bait it likes: " .. r.hint)
			end
			t.eq(Daily.rumour(day, false).text, r.text, "same all day")
		end
		t.ok(kinds.spot and kinds.time and kinds.bait, "all three kinds of hint come up")
		for _, s in Daily.legendaries(false) do
			for spot in s.spots do
				t.ok(LAKE_OR_CREEK[spot] ~= nil, s.id .. " is a Big Lake fish while the Big Lake is closed")
			end
		end
		t.ok(#Daily.legendaries(true) > #Daily.legendaries(false), "the Big Lake adds its Legendary")
	end)

	t.test("the board has every line, kid-readable", function()
		for day = DAY, DAY + 20 do
			local b = Daily.board(day, Weather.forecast(Weather.planForDate(day), -1), false)
			for k, v in b :: any do
				plain(v, k)
			end
			t.ok(#b.fishNote < 160 and #b.rumour < 140 and #b.weather < 90, "short enough for the board")
		end
		t.eq(Daily.weekday(DAY), "Thursday")
		t.eq(Daily.weekday(DAY + 1), "Friday")
		t.eq(Daily.weekday(0), "Thursday", "1 January 1970")
	end)

	t.test("one forecast per real date: the same every time, varied, a cold front after a storm", function()
		local seen, n = {}, 0
		for d = DAY, DAY + 120 do
			local p = Weather.planForDate(d)
			local q = Weather.planForDate(d)
			t.eq(p.kind, q.kind, "same plan twice")
			t.eq(p.wind, q.wind, "same wind twice")
			if not seen[p.kind] then
				seen[p.kind] = true
				n += 1
			end
			if Weather.planForDate(d - 1).kind == "PreStorm" then
				t.eq(p.kind, "ColdFront", "cold front follows a storm date")
			end
			t.ok(p.kind ~= "Storm", "a storm is the afternoon of a PreStorm date, never a whole date")
			plain(Weather.forecast(p, -1), "forecast")
		end
		t.ok(n >= 5, "kinds over four months: " .. n)
		t.ok(not string.find(Weather.forecast({ day = 0, kind = "Clear" }, -1), "moon", 1, true), "no moon line for -1")
	end)

	t.test("the tackle box: once a day, worth 20 to 40 coins, nothing counts up", function()
		for _, g in Daily.GIFTS do
			local worth = Daily.giftWorth(g)
			t.ok(worth >= 20 and worth <= 40, g.bait .. " worth " .. worth)
			t.ok(BaitData.byId[g.bait].kind == "live", "live bait only")
			plain(g.text, "gift")
		end
		local data: any = { bait = { Worm = 2 }, giftDay = 0 }
		local ok, msg = Daily.claimGift(data, DAY)
		t.ok(ok, "first ask of the day gives")
		plain(msg, "gift line")
		local g = Daily.giftFor(DAY)
		t.eq(data.bait[g.bait], (if g.bait == "Worm" then 2 else 0) + g.count, "bait added")
		t.eq(data.giftDay, DAY, "day stored")
		local before = table.clone(data.bait)
		local ok2, msg2 = Daily.claimGift(data, DAY)
		t.ok(not ok2, "second ask the same day is refused")
		t.eq(msg2, Daily.GIFT_REFUSAL)
		for k, v in data.bait do
			t.eq(v, before[k], "nothing changes on a refusal")
		end
		-- A week away: the next ask gives one ordinary gift, no more.
		local ok3 = Daily.claimGift(data, DAY + 7)
		t.ok(ok3, "a week later it gives again")
		t.eq(data.giftDay, DAY + 7, "only the last day is kept")
		-- A damaged or missing gift day never blocks a gift.
		t.ok((Daily.claimGift({ bait = {}, giftDay = "x" }, DAY)), "damaged day")
		t.ok((Daily.claimGift({ bait = {} }, DAY)), "missing day")
		local kinds = {}
		for d = DAY, DAY + 30 do
			kinds[Daily.giftFor(d).bait] = true
		end
		t.ok(kinds.Worm and kinds.Minnow, "the gift varies")
	end)

	t.test("while you were away: what grew and who was born, nothing when nothing changed", function()
		local before = { { id = "Bluegill", name = "Bluegill", cm = 14 }, { id = "YellowPerch", name = "Yellow Perch", cm = 20 } }
		local after = { { id = "Bluegill", name = "Bluegill", cm = 20 }, { id = "YellowPerch", name = "Yellow Perch", cm = 20.04 }, { id = "Bluegill", name = "Bluegill", cm = 12 } }
		local r = Daily.awayReport(before, after, { "Bluegill" })
		t.ok(r ~= nil, "a report")
		local rep = r :: Daily.AwayReport
		t.eq(#rep.lines, 2, "one fish grew (the perch didn't, to the eye), one was born")
		t.ok(string.find(rep.lines[1], Units.length(14), 1, true) ~= nil and string.find(rep.lines[1], Units.length(20), 1, true) ~= nil, rep.lines[1])
		t.ok(string.find(rep.lines[2], "baby Bluegill", 1, true) ~= nil, rep.lines[2])
		t.ok(string.find(rep.hint, "pond", 1, true) ~= nil, "a go-see hint")
		plain(rep.title, "title")
		for _, l in rep.lines do
			plain(l, "line")
		end
		t.eq(Daily.awayReport(before, { { id = "Bluegill", name = "Bluegill", cm = 14.01 }, before[2] }, {}), nil, "nothing to tell")
		t.eq(Daily.awayReport({}, {}, {}), nil, "empty pond")
		-- Twins, and a full pond of growers stays short.
		local twins = Daily.awayReport({}, {}, { "Bluegill", "Bluegill" }) :: Daily.AwayReport
		t.eq(twins.lines[1], "2 baby Bluegill were born!")
		local many, grown = {}, {}
		for i = 1, 6 do
			many[i] = { id = "Bluegill", name = "Bluegill", cm = 13 }
			grown[i] = { id = "Bluegill", name = "Bluegill", cm = 22 }
		end
		local big = Daily.awayReport(many, grown, {}) :: Daily.AwayReport
		t.eq(#big.lines, Daily.AWAY_MAX_LINES, "capped")
		t.ok(string.find(big.lines[#big.lines], "more fish grew", 1, true) ~= nil, "and the rest summed up")
	end)
end
