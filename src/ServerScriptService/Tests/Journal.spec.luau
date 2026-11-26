-- UNVERIFIED in Studio: written 2026-11-26 in the cloud.
return function(t, Shared)
	local Journal = require(Shared.Journal)
	local FishData = require(Shared.FishData)

	t.test("common fish have rumours from the start; rare ones need more catches", function()
		t.ok(Journal.rumour(FishData.byId.Bluegill, 0) ~= nil, "bluegill")
		t.eq(Journal.rumour(FishData.byId.LakeSturgeon, 10), nil, "sturgeon too early")
		local r = Journal.rumour(FishData.byId.LakeSturgeon, 60)
		t.ok(r ~= nil and string.find(r :: string, "deep hole") ~= nil, tostring(r))
	end)

	t.test("mythic rumours name their weather", function()
		local r = Journal.rumour(FishData.byId.GoldenTrout, 100)
		t.ok(r ~= nil and string.find(r :: string, "foggy") ~= nil, tostring(r))
	end)

	t.test("every species gets a sensible rumour eventually", function()
		for _, s in FishData.list do
			local r = Journal.rumour(s, 1000)
			t.ok(r ~= nil and #(r :: string) > 20 and not string.find(r :: string, "nil"), s.id .. ": " .. tostring(r))
		end
	end)

	t.test("Big Lake fish stay out of the journal until boats are on, unless already caught", function()
		local Config = require(Shared.Config)
		local old = Config.BOATS_ON
		local oldLake = Config.BIG_LAKE_ON
		Config.BOATS_ON, Config.BIG_LAKE_ON = false, false
		local ok, err = pcall(function()
			t.ok(Journal.listed(FishData.byId.Bluegill), "home fish always listed")
			local hidden = 0
			for _, s in FishData.list do
				if not Journal.listed(s) then
					hidden += 1
					for spot in s.spots do
						t.ok(Journal.BOAT_SPOTS[spot] or s.spots[spot] == 0, s.id .. " hidden but lives at " .. spot)
					end
				end
				t.ok(Journal.listed(s, true), s.id .. " shows once caught")
			end
			t.ok(hidden >= 5, "Big Lake fish hidden: " .. hidden)
			Config.BOATS_ON, Config.BIG_LAKE_ON = true, true
			for _, s in FishData.list do
				t.ok(Journal.listed(s), s.id .. " listed with boats on")
			end
		end)
		Config.BOATS_ON, Config.BIG_LAKE_ON = old, oldLake
		if not ok then
			error(err, 0)
		end
	end)

	t.test("counts down to the next rumour", function()
		t.eq(Journal.nextRumourIn(0), 5)
		t.eq(Journal.nextRumourIn(14), 1)
		t.eq(Journal.nextRumourIn(10000), 0)
	end)
	t.test("keep fishing and a rumour names the bait too", function()
		local early = Journal.rumour(FishData.byId.Bluegill, 0) :: string
		t.ok(not string.find(early, "swear"), early)
		local later = Journal.rumour(FishData.byId.Bluegill, 12) :: string
		t.ok(string.find(later, "Old%-timers swear by") ~= nil, later)
		t.ok(Journal.rumour(FishData.byId.LakeSturgeon, 65) ~= nil and not string.find(Journal.rumour(FishData.byId.LakeSturgeon, 65) :: string, "swear"), "legendary needs 70")
	end)
end
