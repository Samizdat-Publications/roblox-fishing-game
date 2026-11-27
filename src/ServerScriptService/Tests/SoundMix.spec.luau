return function(t, Shared)
	local SoundMix = require(Shared.SoundMix)
	local SoundIds = require(Shared.SoundIds)

	local function near(a: number, b: number): boolean
		return math.abs(a - b) < 1e-6
	end

	t.test("lake ambience always sums to one and follows the clock", function()
		for clock = 0, 23.9, 0.1 do
			local w = SoundMix.lakeWeights(clock)
			local sum = 0
			for _, v in w do
				sum += v
			end
			t.ok(near(sum, 1), "sum at " .. clock)
		end
		t.ok(near(SoundMix.lakeWeights(6.5)["amb-lake-dawn"], 1), "dawn at 6:30")
		t.ok(near(SoundMix.lakeWeights(12)["amb-lake-day"], 1), "day at noon")
		t.ok(near(SoundMix.lakeWeights(19)["amb-lake-dusk"], 1), "dusk at 7 PM")
		t.ok(near(SoundMix.lakeWeights(1)["amb-lake-night"], 1), "night past midnight")
		t.ok(near(SoundMix.lakeWeights(23)["amb-lake-night"], 1), "night before midnight")
		local edge = SoundMix.lakeWeights(8)
		t.ok(edge["amb-lake-dawn"] > 0.3 and edge["amb-lake-day"] > 0.3, "crossfade at 8 AM")
		t.ok(near(SoundMix.lakeWeights(24 + 12)["amb-lake-day"], 1), "clock wraps")
	end)

	t.test("the creek gets louder as you walk closer, and the lake steps back", function()
		t.eq(SoundMix.creekLevel(SoundMix.creekDistance(-230, 0)), 1, "standing in the creek")
		t.eq(SoundMix.creekLevel(SoundMix.creekDistance(0, 57)), 0, "on the dock")
		local mid = SoundMix.creekLevel(SoundMix.creekDistance(-160, 5))
		t.ok(mid > 0 and mid < 1, "at the gate " .. mid)
		local last = -1
		for x = 0, -230, -10 do
			local level = SoundMix.creekLevel(SoundMix.creekDistance(x, 10))
			t.ok(level >= last, "never quieter walking west at x " .. x)
			last = level
		end
		t.ok(SoundMix.lakeLevel(1) > 0 and SoundMix.lakeLevel(1) < SoundMix.lakeLevel(0), "lake fades down, not out")
	end)

	t.test("every cue has a sound and every sound has an id", function()
		local names = {
			SoundMix.splashFor(0.2),
			SoundMix.splashFor(5),
			"bite-nibble",
			"wait-bobber-tick",
			"reel-click",
			"drag-zip",
			"line-strain",
			"thrash-splash",
			"sting-new-species",
			"amb-creek",
			"theme-lake",
			"theme-creek",
			"tension-fight",
		}
		for _, style in { "nibble", "tap", "slam", "pull", "unknown" } do
			table.insert(names, SoundMix.biteCue(style))
		end
		for _, tier in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Godlike", "nonsense" } do
			table.insert(names, SoundMix.stingerFor(tier))
		end
		for id in SoundMix.lakeWeights(12) do
			table.insert(names, id)
		end
		for _, name in names do
			local id = SoundIds[name]
			t.ok(id ~= nil and id:match("^rbxassetid://%d+$") ~= nil, "id for " .. name)
		end
		t.eq(SoundMix.stingerFor(nil), "sting-common", "no tier yet reads as Common")
		t.eq(SoundMix.biteCue("pull"), "bite-deep-pull", "catfish pull is the deep cue")
	end)

	t.test("reel pitch rises only when the fish is close to breaking free", function()
		t.eq(SoundMix.reelPitch(0.9, true), 1, "winning is calm")
		t.ok(SoundMix.reelPitch(0.05, false) > 1.25, "about to lose it is high")
		t.ok(SoundMix.reelPitch(0.05, true) < SoundMix.reelPitch(0.05, false), "back in the zone eases it")
		t.ok(SoundMix.isBigFight({ heavy = 0.6 }) and not SoundMix.isBigFight({ heavy = 0 }), "heavy fish bring tension")
	end)
	t.test("Big Lake and blue water ambience follow where you are (overnight 2)", function()
		t.eq(SoundMix.bigLakeLevel(0, 57), 0, "on the dock")
		t.eq(SoundMix.bigLakeLevel(0, -200), 1, "out on the Big Lake")
		local mid = SoundMix.bigLakeLevel(0, -125)
		t.ok(mid > 0 and mid < 1, "fading in through the channel")
		t.eq(SoundMix.blueLevel(0, -200), 0, "inside the buoys")
		t.eq(SoundMix.blueLevel(0, -340), 1, "in blue water")
		t.ok(SoundMix.homeLakeLevel(1) < 0.2 and SoundMix.homeLakeLevel(0) == 1, "home lake steps back")
	end)

	t.test("boat motors idle at rest and rise with speed", function()
		local rest = SoundMix.motor(0, 12)
		t.ok(rest.idle > 0.3 and rest.run == 0, "idle putter at rest")
		local full = SoundMix.motor(12, 12)
		t.ok(full.idle == 0 and full.run > rest.run and full.pitch > rest.pitch, "full throttle")
		t.eq(SoundMix.motorName("DeepV"), "motor-deepv-run")
		t.eq(SoundMix.motorName("Dinghy"), "motor-dinghy-run")
	end)

	t.test("weather and frenzy sounds", function()
		t.ok(SoundMix.weather("Storm").rain > 0 and SoundMix.weather("Storm").thunder ~= nil, "storm: rain and thunder")
		t.eq(SoundMix.weather("Clear").rain, 0)
		t.ok(SoundMix.weather("Clear").thunder == nil and SoundMix.weather("Wind").gust ~= nil, "wind gusts only when windy")
		t.eq(SoundMix.frenzyLevel(10), 1, "right on it")
		t.eq(SoundMix.frenzyLevel(200), 0, "far away")
		local none = function(_: string)
			return false
		end
		local all = function(_: string)
			return true
		end
		t.eq(SoundMix.catchStinger("Rare", "monster", none), "sting-rare", "falls back to the tier")
		t.eq(SoundMix.catchStinger("Rare", "monster", all), "sting-monster")
		t.eq(SoundMix.catchStinger("Rare", nil, all), "sting-rare")
	end)

	t.test("the wait gets quieter as a fish comes, and nearly silent just before the strike (L4)", function()
		local idle = SoundMix.waitMix("Idle", false, false)
		local wait = SoundMix.waitMix("Waiting", false, false)
		local coming = SoundMix.waitMix("Waiting", true, false)
		local held = SoundMix.waitMix("Waiting", true, true)
		t.eq(idle.ambience, 1, "idle is full")
		t.ok(wait.ambience < idle.ambience, "line in steps back")
		t.ok(coming.ambience < wait.ambience, "a fish coming dips it more")
		t.ok(held.ambience < coming.ambience and held.ambience <= 0.1, "held breath")
		t.ok(coming.tick < wait.tick and coming.tick > 0, "the tick dips")
		t.eq(held.tick, 0, "the tick stops")
		t.ok(held.rate > wait.rate, "the held breath drops out quickly")
		t.eq(SoundMix.waitMix("Idle", true, true).ambience, 1, "a stale hush never mutes the idle world")
		t.eq(SoundMix.waitMix("Bite", false, false).tick, 0, "no tick once it bites")
	end)

	t.test("every sound the rules name has an id slot", function()
		for _, id in { "amb-biglake", "amb-bluewater", "motor-dinghy-idle", "motor-dinghy-run", "motor-deepv-run", "rain-on-water", "thunder-far", "wind-gust", "frenzy-boil", "frenzy-burst", "server-horn", "sting-trophy", "sting-monster", "buoy-bell", "goal-complete", "sell-coins", "line-snap", "breach-huge", "theme-biglake", "tension-bluewater" } do
			t.ok(SoundIds[id] ~= nil, id)
		end
	end)
end
