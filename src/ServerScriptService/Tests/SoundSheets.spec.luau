-- Sound sheets and stand-ins (audio/UPLOAD-PLAN.md).
return function(t, Shared)
	local SoundSheets = require(Shared.SoundSheets)
	local SoundIds = require(Shared.SoundIds)

	t.test("a sound's own upload wins", function()
		local r = SoundSheets.resolve("splash-small", SoundIds)
		t.ok(r ~= nil and r.via == "upload" and r.id == SoundIds["splash-small"], "splash-small")
		t.eq((r :: any).start, nil, "no region for a whole file")
	end)

	t.test("a missing sound borrows its stand-in until uploaded", function()
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

	t.test("nothing at all is nil, so SoundFX skips it", function()
		t.eq(SoundSheets.resolve("no-such-sound", SoundIds), nil)
		local ids = table.clone(SoundIds)
		ids["splash-small"] = ""
		ids["bobber-plop"] = ""
		t.eq(SoundSheets.resolve("bobber-plop", ids), nil, "a stand-in of a missing sound is nothing")
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
