-- UNVERIFIED in Studio: written 2026-11-26 in the cloud (rarity plan Task 1).
return function(t, Shared)
	local Rarity = require(Shared.Rarity)
	local FishData = require(Shared.FishData)
	local BigLake = require(Shared.BigLakeFishData)
	local FishLogic = require(Shared.FishLogic)
	local FightModel = require(Shared.FightModel)

	local function allSpecies()
		local out = {}
		for _, s in FishData.list do
			table.insert(out, s)
		end
		for _, s in BigLake.list do
			table.insert(out, s)
		end
		return out
	end

	t.test("seven tiers in order, each with its colour", function()
		t.eq(#Rarity.list, 7)
		t.eq(Rarity.list[1].id, "Common")
		t.eq(Rarity.list[7].id, "Godlike")
		t.eq(Rarity.rank.Legendary, 5)
		t.ok(Rarity.colorAt("Rare", 0) == Rarity.byId.Rare.color, "fixed colour")
		t.ok(Rarity.colorAt("Nonsense", 0) == Rarity.byId.Common.color, "unknown reads as Common")
	end)

	t.test("Godlike cycles the rainbow every 2 seconds", function()
		local a, b = Rarity.colorAt("Godlike", 0), Rarity.colorAt("Godlike", 1)
		t.ok(a ~= b, "changes over time")
		local c = Rarity.colorAt("Godlike", Rarity.RAINBOW_SECONDS)
		t.ok(math.abs(a.R - c.R) < 1e-6 and math.abs(a.G - c.G) < 1e-6 and math.abs(a.B - c.B) < 1e-6, "loops")
	end)

	t.test("every species has a known tier, and the plan's tiers for the first eleven", function()
		for _, s in allSpecies() do
			t.ok(Rarity.byId[s.tier or ""] ~= nil, s.id .. " tier")
		end
		local want = {
			Bluegill = "Common",
			Pumpkinseed = "Common",
			YellowPerch = "Uncommon",
			BlackCrappie = "Uncommon",
			CommonCarp = "Uncommon",
			LargemouthBass = "Rare",
			ChannelCatfish = "Rare",
			RainbowTrout = "Rare",
			SmallmouthBass = "Rare",
			NorthernPike = "Epic",
			Walleye = "Epic",
		}
		for id, tier in want do
			t.eq(FishData.byId[id].tier, tier, id)
		end
	end)

	t.test("each place has 6 to 10 species and at least one Legendary", function()
		local places = {
			lake = { Dock = true, WeedBed = true, Logs = true, DeepHole = true, OpenWater = true },
			creek = { Riffle = true, Rocks = true, Pool = true },
			bigLake = { Basin = true, IslandPoint = true, DropOff = true },
		}
		for name, spots in places do
			local count, legend = 0, false
			for _, s in allSpecies() do
				local here = false
				for spot in s.spots do
					if spots[spot] then
						here = true
					end
				end
				if here then
					count += 1
					legend = legend or (Rarity.rank[s.tier or "Common"] or 1) >= 5
				end
			end
			t.ok(count >= 6 and count <= 10, name .. " has " .. count)
			t.ok(legend, name .. " has a Legendary")
		end
	end)

	t.test("Legendary fish really are hard to find", function()
		for _, s in allSpecies() do
			if (Rarity.rank[s.tier or "Common"] or 1) >= 5 then
				t.ok(s.rarity <= 0.15, s.id .. " rarity " .. s.rarity)
			end
		end
	end)

	t.test("size classes: about 2 percent trophies and 0.2 percent monsters", function()
		local rng = Random.new(7)
		local s = FishData.byId.Bluegill
		local n, trophies, monsters = 200000, 0, 0
		for _ = 1, n do
			local cm, _, class = FishLogic.rollCatch(s, rng)
			if class == "trophy" then
				trophies += 1
				t.ok(cm >= s.maxCm * 0.95 - 0.1 and cm <= s.maxCm * 1.1 + 0.1, "trophy length " .. cm)
			elseif class == "monster" then
				monsters += 1
				t.ok(cm > s.maxCm, "monster longer than any normal fish " .. cm)
			else
				t.ok(cm >= s.minCm and cm <= s.maxCm, "normal length " .. cm)
			end
		end
		local tp, mp = trophies / n * 100, monsters / n * 100
		t.ok(tp >= 1.6 and tp <= 2.4, string.format("trophies %.2f%%", tp))
		t.ok(mp >= 0.12 and mp <= 0.3, string.format("monsters %.3f%%", mp))
	end)

	t.test("big ones pay more", function()
		local s = FishData.byId.LargemouthBass
		local mid = (s.minCm + s.maxCm) / 2
		local avg = FishLogic.priceFor(s, s.weightCoef * mid ^ 3)
		local trophyCm = s.maxCm * 1.0
		local monsterCm = s.maxCm * 1.4
		local trophy = FishLogic.priceFor(s, s.weightCoef * trophyCm ^ 3)
		local monster = FishLogic.priceFor(s, s.weightCoef * monsterCm ^ 3)
		t.ok(trophy >= avg * 1.8 and trophy <= avg * 3.5, "trophy " .. trophy .. " vs " .. avg)
		t.ok(monster >= avg * 4 and monster <= avg * 9, "monster " .. monster .. " vs " .. avg)
	end)

	t.test("monster fights are harder but a tracking player still lands every species' monster", function()
		local DT = 1 / 30
		for _, sp in allSpecies() do
			local m = FishLogic.fightFor(sp.fight, "monster")
			t.ok(m.gain < sp.fight.gain and m.heavy >= sp.fight.heavy and m.heavy <= Rarity.HEAVY_CAP, sp.id .. " harder")
			t.eq(FishLogic.fightFor(sp.fight, "normal").gain, sp.fight.gain, sp.id .. " normal unchanged")
			local before = sp.fight.gain
			FishLogic.fightFor(sp.fight, "trophy")
			t.eq(sp.fight.gain, before, sp.id .. " species data not changed in place")
			for seed = 1, 3 do
				local s = FightModel.new(m, false, seed)
				local result = nil
				local was = false
				for _ = 1, math.floor(90 / DT) do
					local hold = s.zonePos < s.fishPos or s.idle > 2
					if hold and not was then
						FightModel.press(s)
					end
					was = hold
					result = FightModel.step(s, DT, hold)
					if result then
						break
					end
				end
				t.eq(result, "won", sp.id .. " monster seed " .. seed)
			end
		end
	end)

	t.test("old catches without a size class read as normal", function()
		t.eq(Rarity.sizeClassOf({ id = "Bluegill", cm = 20 }), "normal")
		t.eq(Rarity.sizeClassOf({ sizeClass = "trophy" }), "trophy")
		t.eq(Rarity.sizeClassOf({ sizeClass = "weird" }), "normal")
		t.eq(Rarity.of({}), "Common")
	end)
end
