-- UNVERIFIED in Studio: written 2026-11-26 in the cloud.
return function(t, Shared)
	local Teamwork = require(Shared.Teamwork)

	t.test("team catches: Deep-V, full crew, blue water", function()
		t.ok(Teamwork.isTeamCatch("DeepV", true, 2), "yes")
		t.ok(not Teamwork.isTeamCatch("DeepV", false, 2), "not in dinghy water")
		t.ok(not Teamwork.isTeamCatch("DeepV", true, 1), "not alone")
		t.ok(not Teamwork.isTeamCatch("Dinghy", true, 1), "not a dinghy")
		t.ok(not Teamwork.isTeamCatch(nil, true, 2), "not from shore")
	end)

	t.test("coins split evenly, the odd coin to the one who landed it, nothing lost", function()
		local s = Teamwork.split(41, 2)
		t.eq(s[1], 21)
		t.eq(s[2], 20)
		local total = 0
		for _, c in Teamwork.split(100, 3) do
			total += c
		end
		t.eq(total, 100)
		t.eq(Teamwork.split(7, 0)[1], 7, "bad crew counts as one")
	end)

	t.test("the fish finder shows marks without names, likeliest first", function()
		local marks = Teamwork.finder("DropOff", "Dawn", nil)
		t.ok(#marks >= 1 and #marks <= 4, "count " .. #marks)
		for _, m in marks do
			t.ok(m.tier ~= nil and (m.size == "small" or m.size == "medium" or m.size == "large"), "mark")
			t.eq((m :: any).id, nil, "no names")
		end
		t.eq(#Teamwork.finder("Nowhere", "Day", nil), 0, "empty water, no marks")
	end)
end
