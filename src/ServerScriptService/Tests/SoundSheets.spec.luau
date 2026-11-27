-- Sound sheets and stand-ins (audio/UPLOAD-PLAN.md).
return function(t, Shared)
	local SoundSheets = require(Shared.SoundSheets)
	local SoundIds = require(Shared.SoundIds)

	-- Run body as if the water sheet weren't uploaded (it is since 11/27/2026), so the
	-- stand-in rules underneath it are still tested.
	local function withoutWaterSheet(body: () -> ())
		local sheet = SoundSheets.sheets["sheet-water"]
		local old = sheet.id
		sheet.id = ""
		local ok, err = pcall(body)
		sheet.id = old
		if not ok then
			error(err, 0)
		end
	end

	t.test("a sound's own upload wins", function()
		local r = SoundSheets.resolve("splash-small", SoundIds)
		t.ok(r ~= nil and r.via == "upload" and r.id == SoundIds["splash-small"], "splash-small")
		t.eq((r :: any).start, nil, "no region for a whole file")
	end)

	t.test("a missing sound borrows its stand-in until uploaded", function()
		withoutWaterSheet(function()
		local ids = table.clone(SoundIds)
		ids["bobber-plop"] = ""
		local r = SoundSheets.resolve("bobber-plop", ids) :: any
		t.ok(r ~= nil, "has a stand-in")
		t.eq(r.via, "stand-in:splash-small")
		t.eq(r.id, SoundIds["splash-small"])
		t.ok(r.speed > 1 and r.length > 0 and r.length < 1, "short and quick")
		ids["bobber-plop"] = "rbxassetid://1"
		t.eq((SoundSheets.resolve("bobber-plop", ids) :: any).via, "upload", "real upload replaces it")
		end)
	end)

	t.test("an uploaded sheet serves its cues as regions, before any stand-in", function()
		local ids = table.clone(SoundIds)
		ids["bobber-plop"] = ""
		local sheet = SoundSheets.sheets["sheet-water"]
		local old = sheet.id
		sheet.id = "rbxassetid://2"
		local ok, err = pcall(function()
			local r = SoundSheets.resolve("bobber-plop", ids) :: any
			t.eq(r.via, "sheet-water")
			t.eq(r.id, "rbxassetid://2")
			t.eq(r.start, sheet.cues["bobber-plop"].start)
			t.eq(r.length, sheet.cues["bobber-plop"].length)
		end)
		sheet.id = old
		if not ok then
			error(err, 0)
		end
	end)

	t.test("the uploaded sheets serve their cues: goal chime, thunder, buoy bell", function()
		for _, name in { "goal-complete", "thunder-far", "wind-gust", "buoy-bell", "boat-bump" } do
			local r = SoundSheets.resolve(name, SoundIds) :: any
			t.ok(r ~= nil and string.sub(r.via, 1, 6) == "sheet-" and r.id ~= "", name)
		end
	end)

	t.test("nothing at all is nil, so SoundFX skips it", function()
		t.eq(SoundSheets.resolve("no-such-sound", SoundIds), nil)
		withoutWaterSheet(function()
			local ids = table.clone(SoundIds)
			ids["splash-small"] = ""
			ids["bobber-plop"] = ""
			t.eq(SoundSheets.resolve("bobber-plop", ids), nil, "a stand-in of a missing sound is nothing")
		end)
	end)

	t.test("every stand-in borrows an uploaded sound, and sheets never overlap", function()
		for name, s in SoundSheets.standIns do
			t.ok(SoundIds[s.from] ~= nil and SoundIds[s.from] ~= "", name .. " borrows " .. s.from)
		end
		for name, sheet in SoundSheets.sheets do
			t.eq(#SoundSheets.overlaps(sheet), 0, name .. " overlaps")
			for cue, c in sheet.cues do
				t.ok(c.start >= 0 and c.length > 0, name .. "." .. cue)
			end
		end
	end)
end
