--!strict
-- Sound sheets and stand-ins (audio/UPLOAD-PLAN.md). Roblox counts audio uploads per account
-- (100 per 30 days unless ID verified), so short one-shots are packed into a few "sheet"
-- files and each cue plays a region of its sheet. Until a sound is uploaded, a stand-in
-- borrows an uploaded sound with a different speed, region or volume, so swapping in the
-- real upload is one line in SoundIds. Pure: no Roblox services; SoundFX does the playing.
local SoundSheets = {}

export type Cue = { start: number, length: number }
export type Sheet = { id: string, cues: { [string]: Cue } }
export type StandIn = { from: string, speed: number?, start: number?, length: number?, volume: number? }
export type Resolved = { id: string, start: number?, length: number?, speed: number, volume: number, via: string }

-- Sheets, in seconds within one uploaded file. An empty id means the sheet isn't uploaded yet.
-- tools/audio/build_sheet.py packs the separate files into one sheet and prints these cues.
SoundSheets.sheets = {
	["sheet-ui"] = {
		id = "",
		cues = {
			["sell-coins"] = { start = 0, length = 1.2 },
			["journal-page"] = { start = 1.5, length = 0.8 },
			["goal-complete"] = { start = 2.6, length = 1.6 },
			["ui-click"] = { start = 4.5, length = 0.2 },
			["ui-open"] = { start = 5.0, length = 0.4 },
		},
	},
	["sheet-water"] = {
		id = "",
		cues = {
			["cast-whoosh"] = { start = 0, length = 0.8 },
			["bobber-plop"] = { start = 1.1, length = 0.6 },
			["pond-splash"] = { start = 2.0, length = 1.2 },
			["line-snap"] = { start = 3.5, length = 0.6 },
			["boat-bump"] = { start = 4.4, length = 0.8 },
			["buoy-bell"] = { start = 5.5, length = 2.5 },
		},
	},
	["sheet-bait"] = { -- the bait bench (leg plan L3)
		id = "",
		cues = {
			["bait-worm-wriggle"] = { start = 0, length = 1.0 },
			["bait-hook-click"] = { start = 1.3, length = 0.3 },
			["bait-knot-pull"] = { start = 1.9, length = 0.7 },
			["bait-minnow-flick"] = { start = 2.9, length = 0.6 },
			["bait-squish"] = { start = 3.8, length = 0.6 },
			["bait-cricket-chirp"] = { start = 4.7, length = 0.8 },
		},
	},
} :: { [string]: Sheet }

-- Stand-ins from sounds already uploaded, used until the real one is. Chosen by ear for
-- shape: a short, fast slice of a splash is a plop; a slowed stinger is a heavier one.
SoundSheets.standIns = {
	["bobber-plop"] = { from = "splash-small", speed = 1.6, start = 0, length = 0.45, volume = 0.35 },
	["pond-splash"] = { from = "splash-small", speed = 0.9, volume = 0.6 },
	["cast-whoosh"] = { from = "drag-zip", speed = 1.35, start = 0, length = 0.45, volume = 0.25 },
	["line-snap"] = { from = "line-strain", speed = 1.9, start = 0, length = 0.35, volume = 0.5 },
	["sell-coins"] = { from = "sting-common", speed = 1.35, volume = 0.6 },
	["goal-complete"] = { from = "sting-uncommon", speed = 1.1, volume = 0.8 },
	["sting-trophy"] = { from = "sting-rare", speed = 0.9, volume = 1 },
	["sting-monster"] = { from = "sting-mythic", speed = 0.85, volume = 1 },
	["server-horn"] = { from = "sting-legendary", speed = 0.7, start = 0, length = 1.6, volume = 0.6 },
	["frenzy-boil"] = { from = "thrash-splash", speed = 0.8, volume = 0.5 },
	["breach-huge"] = { from = "splash-big", speed = 0.8, volume = 1 },
} :: { [string]: StandIn }

-- Where a sound comes from: its own upload, then its sheet's cue, then a stand-in (whose
-- source is resolved the same way, one level deep). nil when none is available yet.
function SoundSheets.resolve(name: string, ids: { [string]: string }): Resolved?
	local own = ids[name]
	if own and own ~= "" then
		return { id = own, speed = 1, volume = 1, via = "upload" }
	end
	for sheetName, sheet in SoundSheets.sheets do
		local cue = sheet.cues[name]
		if cue and sheet.id ~= "" then
			return { id = sheet.id, start = cue.start, length = cue.length, speed = 1, volume = 1, via = sheetName }
		end
	end
	local stand = SoundSheets.standIns[name]
	if stand and stand.from ~= name then
		local src = ids[stand.from]
		if src and src ~= "" then
			return {
				id = src,
				start = stand.start,
				length = stand.length,
				speed = stand.speed or 1,
				volume = stand.volume or 1,
				via = "stand-in:" .. stand.from,
			}
		end
	end
	return nil
end

-- Every cue in a sheet must fit before the next one starts (no overlaps), so a packed file
-- can never bleed one sound into another.
function SoundSheets.overlaps(sheet: Sheet): { string }
	local list = {}
	for name, cue in sheet.cues do
		table.insert(list, { name = name, a = cue.start, b = cue.start + cue.length })
	end
	table.sort(list, function(x, y)
		return x.a < y.a
	end)
	local bad = {}
	for i = 2, #list do
		if list[i].a < list[i - 1].b then
			table.insert(bad, list[i - 1].name .. "/" .. list[i].name)
		end
	end
	return bad
end

return SoundSheets
