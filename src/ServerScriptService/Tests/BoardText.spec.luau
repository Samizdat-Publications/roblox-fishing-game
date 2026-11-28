-- The readable chalkboard (leg 3, N2): the short slate and the field-guide card agree with the
-- old board (Shared/Daily), stay short enough to read from the path, and use plain words.
-- UNVERIFIED in Studio: written 2026-11-27 in a worktree.
return function(t, Shared)
	local BoardText = require(Shared.BoardText)
	local Daily = require(Shared.Daily)
	local Weather = require(Shared.Weather)
	local FishData = require(Shared.FishData)
	local Rarity = require(Shared.Rarity)
	local Config = require(Shared.Config)

	local DAY = 20419 -- a Thursday (27 November 2025, UTC)
	local EM_DASH = utf8.char(0x2014)

	local function plain(text: string, what: string)
		t.ok(#text > 0, what .. " is empty")
		t.ok(not string.find(text, EM_DASH, 1, true), what .. " has an em dash: " .. text)
		t.ok(not string.find(text, "%%"), what .. " has a stray format: " .. text)
	end

	t.test("the readable board lands switched off", function()
		t.eq(Config.BOARD_CARD_ON, true, "BOARD_CARD_ON (on since 11/27/2026)")
	end)

	t.test("the slate is short enough to read from the path, every day, with and without the Big Lake", function()
		for _, big in { false, true } do
			for day = DAY, DAY + 120 do
				local s = BoardText.slate(day, big)
				for key, max in BoardText.SLATE_MAX do
					local line = (s :: any)[key] :: string
					plain(line, key)
					t.ok(#line <= max, string.format("day %d %s is %d long: %s", day, key, #line, line))
				end
			end
		end
	end)

	t.test("every weather kind has a few words, and a windy day names its side", function()
		for _, k in Weather.list do
			local words = BoardText.weatherWords({ day = DAY, kind = k.id })
			plain(words, k.id)
			t.ok(#words <= BoardText.SLATE_MAX.weather, k.id .. " too long: " .. words)
		end
		for _, dir in Weather.DIRECTIONS do
			local words = BoardText.weatherWords({ day = DAY, kind = "Wind", wind = dir })
			t.ok(string.find(words, dir, 1, true) ~= nil, "wind side missing: " .. words)
			t.ok(#words <= BoardText.SLATE_MAX.weather, "too long: " .. words)
		end
	end)

	t.test("the card says what the old board says: forecast, fish of the day and rumour", function()
		for day = DAY, DAY + 60 do
			local c = BoardText.card(day, Config.BIG_LAKE_ON)
			local b = Daily.board(day, Weather.forecast(Weather.planForDate(day), -1), Config.BIG_LAKE_ON)
			t.eq(c.title, "Today on the Lake", "title")
			t.eq(c.weekday, b.weekday, "weekday")
			t.eq(c.forecast, b.weather, "forecast")
			t.eq(c.fishName, b.fish, "fish")
			t.eq(c.fishNote, b.fishNote, "fish note")
			t.eq(c.rumour, b.rumour, "rumour")
			t.eq(c.fishId, Daily.fishOfDay(day), "fish id")
			t.eq(c.fishName, BoardText.slate(day, Config.BIG_LAKE_ON).fish, "slate and card agree on the fish")
			t.ok(not string.find(c.forecast, "moon", 1, true), "no moon on the board: " .. c.forecast)
			for _, key in { "title", "weekday", "forecast", "fishName", "fishTierName", "fishNote", "rumourFish", "rumour", "note" } do
				plain((c :: any)[key], key)
			end
		end
	end)

	t.test("the fish of the day's stamp is its own tier, and the rumour is about a Legendary", function()
		for day = DAY, DAY + 60 do
			local c = BoardText.card(day, true)
			local fish = FishData.byId[c.fishId]
			t.eq(c.fishTier, Rarity.of(fish), "tier")
			t.eq(c.fishTierName, Rarity.byId[c.fishTier].name, "tier name")
			t.ok((Rarity.rank[c.fishTier] or 9) <= 2, "fish of the day is Common or Uncommon")
			local legend = FishData.byId[Daily.rumour(day, true).species]
			t.eq(c.rumourFish, legend.name, "rumour fish")
			t.eq(Rarity.of(legend), "Legendary", "rumour is about a Legendary")
			t.ok(string.find(c.rumour, legend.name, 1, true) ~= nil, "rumour names it")
			t.ok(string.find(BoardText.slate(day, true).teaser, legend.name, 1, true) ~= nil, "teaser names it")
		end
	end)

	t.test("the card is the same all day and changes from day to day", function()
		local changed = 0
		for day = DAY, DAY + 30 do
			local a, b = BoardText.card(day, true), BoardText.card(day, true)
			t.eq(a.fishId, b.fishId, "fish")
			t.eq(a.rumour, b.rumour, "rumour")
			t.eq(a.note, b.note, "note")
			local y = BoardText.card(day - 1, true)
			if a.fishId ~= y.fishId or a.rumour ~= y.rumour or a.forecast ~= y.forecast then
				changed += 1
			end
		end
		t.ok(changed >= 25, "changes most days: " .. changed)
	end)
end
