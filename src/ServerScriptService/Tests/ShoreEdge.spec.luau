-- The home lake's drawn waterline (leg 3, N1, ShoreEdge): no straight run over 30 studs along
-- any bank, never far enough out to wet the shore path, never far enough in to matter to a cast,
-- and Shore's corners, points, the channel mouth and the slips exactly as before.
return function(t, Shared)
	local Shore = require(Shared.Shore)
	local ShoreEdge = require(Shared.ShoreEdge)

	local lake = assert(Shore.AREAS[1])
	t.eq(lake.name, "Lake", "the first shaped area is the home lake")

	local RUN = 30 -- the plan's wrong-list: no straight shore longer than this
	local MIN_BEND = 0.75 -- studs a 30 stud stretch must bow off its chord (the least is 0.85, by the slips)

	-- One sample per stud along each bank: where the drawn waterline sits, and whether a corner,
	-- a point or the channel mouth shapes it (those are curves or openings, not straight bank).
	type Sample = { along: number, o: number, plain: boolean }
	local function samples(side: string): { Sample }
		local out = {}
		local horizontal = side == "z1" or side == "z2"
		local from = if horizontal then lake.x1 else lake.z1
		local to = if horizontal then lake.x2 else lake.z2
		for along = from, to do
			local o = ShoreEdge.waterline(lake, side, along)
			-- Plain bank: on the rule edge here Shore's depth is the straight bank's (0); a corner or
			-- a point lifts it above 0.
			local ex = if side == "x1" then lake.x1 elseif side == "x2" then lake.x2 else along
			local ez = if side == "z1" then lake.z1 elseif side == "z2" then lake.z2 else along
			local plain = Shore.depthIn(lake, ex, ez) < 0.05
			if side == "z1" and math.abs(along) < 19 then
				plain = false -- the channel's mouth: open water, timber banks either side
			end
			table.insert(out, { along = along, o = o, plain = plain })
		end
		return out
	end

	t.test("no plain bank runs straight for more than 30 studs", function()
		local worst = math.huge
		for _, side in { "x1", "x2", "z1", "z2" } do
			local s = samples(side)
			for i = 1, #s - RUN do
				local all = true
				for k = i, i + RUN do
					if not s[k].plain then
						all = false
						break
					end
				end
				if all then
					local a, b = s[i], s[i + RUN]
					local bend = 0
					for k = i, i + RUN do
						local u = (k - i) / RUN
						bend = math.max(bend, math.abs(s[k].o - (a.o + (b.o - a.o) * u)))
					end
					worst = math.min(worst, bend)
					t.ok(bend >= MIN_BEND, string.format("%s from %d to %d bows only %.2f studs", side, a.along, b.along, bend))
				end
			end
		end
		t.ok(worst < math.huge, "some plain bank was checked")
	end)

	t.test("the waterline stays inside its band: clear of the shore path, a short lip over rule water", function()
		for _, side in { "x1", "x2", "z1", "z2" } do
			for _, s in samples(side) do
				if s.plain then
					t.ok(s.o <= ShoreEdge.OUT_MAX + 0.1, string.format("%s at %d: %.2f studs out", side, s.along, s.o))
					t.ok(s.o >= -ShoreEdge.IN_MAX - 0.1, string.format("%s at %d: %.2f studs in", side, s.along, s.o))
					t.ok(s.o < 2, string.format("%s at %d: water under the path (%.2f)", side, s.along, s.o))
				end
			end
		end
	end)

	t.test("corners, points, the channel mouth and the slips are drawn exactly as Shore has them", function()
		local L = Shore.LAKE
		local spots = {
			Vector3.new(L.x1 + 3, 0, L.z1 + 3), -- a rounded corner's land
			Vector3.new(L.x2 - 6, 0, L.z2 - 6),
			Vector3.new(0, 0, L.z1 + 1), -- the channel mouth
			Vector3.new(15, 0, L.z2 - 1), -- the slips
			Vector3.new(15, 0, L.z2 + 1),
		}
		for _, p in Shore.POINTS do
			table.insert(spots, Vector3.new(p.x, 0, p.z))
		end
		for _, v in spots do
			t.eq(ShoreEdge.depth(lake, v.X, v.Z), Shore.depthIn(lake, v.X, v.Z), string.format("at %.0f,%.0f", v.X, v.Z))
		end
	end)

	t.test("out past the shallows the bed is untouched", function()
		t.eq(ShoreEdge.weight(lake, 0, 0), 0, "the lake's middle")
		t.eq(ShoreEdge.weight(lake, -60, 40), 0, "the weed bed")
		t.eq(ShoreEdge.depth(lake, 5, 5, false), Shore.depthIn(lake, 5, 5), "switched off")
	end)
end
