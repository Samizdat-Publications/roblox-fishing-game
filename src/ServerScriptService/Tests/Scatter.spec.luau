-- The home lake's dress pass (leg 3, N1, Scatter): the same seed gives the same layout, props
-- keep their spacing and never stand at even spacing, the footpaths have no straight run over
-- 30 studs, and nothing lands in a keep-clear box or a cast lane.
return function(t, Shared)
	local Scatter = require(Shared.Scatter)

	local SEED = 20261129
	local plan = Scatter.homeLake(SEED)

	local function group(name: string): { any }
		local out = {}
		for _, it in plan.items do
			if it.group == name then
				table.insert(out, it)
			end
		end
		return out
	end

	t.test("the same seed gives the same layout; another seed a different one", function()
		local again = Scatter.homeLake(SEED)
		t.eq(#again.items, #plan.items, "same count")
		local same = true
		for i, it in plan.items do
			local b = again.items[i]
			if b.model ~= it.model or b.x ~= it.x or b.z ~= it.z or b.yaw ~= it.yaw or b.scale ~= it.scale then
				same = false
			end
		end
		t.ok(same, "every item identical")
		for r = 1, #plan.routes do
			local a, b = plan.routes[r].samples, again.routes[r].samples
			t.eq(#a, #b, "same path samples")
			t.ok(a[10].x == b[10].x and a[10].z == b[10].z, "same path wobble")
		end
		local other = Scatter.homeLake(SEED + 1)
		local moved = 0
		for i = 1, math.min(#other.items, #plan.items) do
			if other.items[i].x ~= plan.items[i].x then
				moved += 1
			end
		end
		t.ok(moved > #plan.items / 2, "a different seed moves most things")
	end)

	t.test("the random numbers stay in range", function()
		local r = Scatter.rng(5)
		for _ = 1, 2000 do
			local v = Scatter.next(r)
			t.ok(v >= 0 and v < 1, "next in [0, 1)")
			local k = Scatter.int(r, 2, 4)
			t.ok(k >= 2 and k <= 4 and k == math.floor(k), "int in range")
		end
		for _ = 1, 200 do
			local n = Scatter.noise(Scatter.range(r, -500, 500), Scatter.range(r, -500, 500), 9, 3)
			t.ok(n >= 0 and n <= 1, "noise in [0, 1]")
		end
	end)

	t.test("every kind keeps its minimum spacing", function()
		local T = Scatter.TUNING
		local function check(name: string, min: number)
			local g = group(name)
			if #g >= 2 then
				t.ok(Scatter.minSpacing(g) >= min - 1e-9, string.format("%s closer than %.1f (%.2f)", name, min, Scatter.minSpacing(g)))
			end
		end
		check("Treeline", T.treeMinDist)
		check("Reeds", T.reedSpacing)
		check("Stones", T.stoneSpacing)
		check("Driftwood", 14)
		check("Birches", 10)
		check("Undergrowth", T.underSpacing)
	end)

	t.test("props are clustered, not at even spacing", function()
		-- A grid has a coefficient of variation of 0 for its nearest-neighbour distances.
		local grid = {}
		for i = 0, 9 do
			for j = 0, 9 do
				table.insert(grid, { x = i * 7, z = j * 7 })
			end
		end
		t.ok(Scatter.cv(Scatter.nearest(grid)) < 0.01, "a grid reads as even")
		-- Several seeds, so the checks are not luck of one draw.
		for _, seed in { SEED, 1, 2, 3, 77, 9999 } do
			local p = Scatter.homeLake(seed)
			local function kind(name: string): { any }
				local out = {}
				for _, it in p.items do
					if it.group == name then
						table.insert(out, it)
					end
				end
				return out
			end
			-- Poisson-spaced kinds: their nearest-neighbour distances vary.
			for name, least in { Treeline = 0.08, Undergrowth = 0.15 } do
				local cv = Scatter.cv(Scatter.nearest(kind(name)))
				if seed == SEED then
					print(string.format("  [Scatter] %s: %d, nearest-neighbour CV %.2f", name, #kind(name), cv))
				end
				t.ok(cv > least, string.format("seed %d: %s spacing too even (CV %.2f)", seed, name, cv))
			end
			-- Clustered kinds: clumped, not strung out. They sit far closer to their nearest
			-- neighbour than the same number spread evenly round the shore (about 700 studs).
			local SHORE = 2 * (220 + 160 - 4 * 30) + 2 * math.pi * 30
			for _, name in { "Reeds", "Stones" } do
				local g = kind(name)
				local sum = 0
				for _, d in Scatter.nearest(g) do
					sum += d
				end
				local ratio = (sum / #g) / (SHORE / #g)
				if seed == SEED then
					print(string.format("  [Scatter] %s: %d, mean nearest neighbour is %.2f of even spacing", name, #g, ratio))
				end
				t.ok(ratio < 0.4, string.format("seed %d: %s strung out evenly (%.2f)", seed, name, ratio))
			end
		end
	end)

	t.test("the footpaths wander: no straight run over 30 studs, wobble within 2, width 5 to 7", function()
		for _, rt in plan.routes do
			local flat = Scatter.flattest(rt.samples, 30)
			print(string.format("  [Scatter] %s: %d samples, flattest 30 stud stretch bows %.2f", rt.name, #rt.samples, flat))
			t.ok(flat >= 0.5, string.format("%s has a near-straight 30 stud run (bows %.2f)", rt.name, flat))
			for _, q in rt.samples do
				t.ok(math.abs(q.off) <= 2 + 1e-9, rt.name .. " wobbles past 2 studs")
				t.ok(q.w >= 5 - 1e-9 and q.w <= 7 + 1e-9, rt.name .. " width out of 5..7")
			end
		end
		t.ok(Scatter.flattest(Scatter.wander("Ruler", Scatter.polyline({ { "line", 0, 0, 100, 0 } }), Scatter.rng(1), { amp = 0, wMin = 6, wMax = 6 }).samples, 30) < 1e-6, "a ruler line is caught")
	end)

	t.test("the loop meets the footbridge's ramp feet and the gate dead on", function()
		local loop = plan.routes[1].samples
		t.ok(math.abs(loop[1].x - 26) < 1e-6 and math.abs(loop[1].z + 85) < 1e-6, "loop starts at the east ramp foot")
		t.ok(math.abs(loop[#loop].x + 26) < 1e-6 and math.abs(loop[#loop].z + 85) < 1e-6, "loop ends at the west ramp foot")
		for _, q in plan.routes[2].samples do
			if math.abs(q.x + 162) < 0.5 then
				t.ok(math.abs(q.z) < 0.01 and q.w <= 5.5 + 1e-9, "the path goes straight through the gate")
			end
		end
	end)

	t.test("nothing lands in a keep-clear place, a cast lane or on a path", function()
		local pidx = Scatter.pathIndex(plan.routes)
		for _, it in plan.items do
			t.ok(not Scatter.kept(it.x, it.z), string.format("%s at (%.1f, %.1f) is in a keep-clear place", it.model, it.x, it.z))
			if it.group == "Reeds" or it.group == "Stones" or it.group == "Driftwood" then
				t.ok(not Scatter.inLane(it.x, it.z), string.format("%s at (%.1f, %.1f) is in a cast lane", it.model, it.x, it.z))
				for _, l in Scatter.LANES do
					t.ok((it.x - l.x1) ^ 2 + (it.z - l.z1) ^ 2 > 36, it.model .. " within 6 studs of a spot's shore point")
				end
			end
			if it.group ~= "Reeds" and it.group ~= "Stones" then
				t.ok(Scatter.pathEdge(pidx, it.x, it.z) > 0, string.format("%s at (%.1f, %.1f) stands on a path", it.model, it.x, it.z))
			end
		end
	end)

	t.test("each kind sits where the kit says", function()
		for _, it in plan.items do
			local w = Scatter.waterline(it.x, it.z)
			if it.group == "Reeds" then
				t.ok(it.water and w < 0, "reeds stand in the water")
			elseif it.group == "Stones" then
				t.ok(math.abs(w) <= 1, "stones at the waterline")
			elseif it.group == "Birches" then
				t.ok(w >= 1 and w <= 3, "a bank birch's foot is 1 to 3 studs back from the water")
				-- Its lean (the model's -X turned by yaw) points out over the water.
				local lx, lz = -math.cos(it.yaw), math.sin(it.yaw)
				t.ok(Scatter.waterline(it.x + lx * 6, it.z + lz * 6) < w, "a bank birch leans toward the water")
			elseif it.group == "Treeline" then
				t.ok(w >= 8, string.format("the treeline stands 8 studs or more back from the water (%.1f, %.1f) w %.2f rb %.2f", it.x, it.z, w, Scatter.roundBox(it.x, it.z)))
				local d = Scatter.roundBox(it.x, it.z)
				t.ok(d >= Scatter.TUNING.treeBand[1] and d <= Scatter.TUNING.treeBand[2], "the treeline is in its band")
				if it.model == "ShorePine1" or it.model == "ShorePine2" then
					t.ok(it.scale >= 0.8 and it.scale <= 1.2, "pine scale 0.8 to 1.2")
				end
			end
			t.ok(Scatter.KIT[it.model] ~= nil, it.model .. " is in the kit")
		end
		local b = #group("Birches")
		t.ok(b >= 3 and b <= 5, string.format("3 to 5 bank birches (%d)", b))
		for _, it in group("Reeds") do
			t.ok(math.sqrt((it.x - Scatter.DOCK.x) ^ 2 + (it.z - Scatter.DOCK.z) ^ 2) > 40, "no reeds near the dock")
		end
		local parts = {}
		for m, n in plan.counts do
			table.insert(parts, m .. " " .. n)
		end
		table.sort(parts)
		print("  [Scatter] counts: " .. table.concat(parts, ", ") .. string.format(" (total %d)", #plan.items))
	end)

	t.test("the far shore is full and the near shore open", function()
		local far, near = 0, 0
		for _, it in plan.items do
			if it.group == "Treeline" then
				local side = Scatter.side(it.x, it.z)
				if side == "north" or side == "ne" or side == "nw" then
					far += 1
				elseif side == "south" then
					near += 1
				end
			end
		end
		print(string.format("  [Scatter] treeline on the far (north) shore: %d", far))
		t.ok(far >= 30, "the north shore has a treeline")
		t.eq(near, 0, "no treeline on the near shore")
	end)

	t.test("path and forest cells: soft-edged and on their routes", function()
		local cells = Scatter.pathCells(plan.routes, 4, SEED)
		local n = 0
		for _ in cells do
			n += 1
		end
		local blobs = Scatter.blobCells(plan.forest, 4, SEED)
		local m = 0
		for _ in blobs do
			m += 1
		end
		print(string.format("  [Scatter] footpath cells %d, forest floor cells %d", n, m))
		-- The old straight path's middle at a stretch: the loop covers it within the wobble.
		local hit = 0
		for x = -60, 60, 4 do
			for z = 80, 92, 4 do
				if cells[Scatter.key(math.floor(x / 4), math.floor(z / 4))] then
					hit += 1
					break
				end
			end
		end
		t.ok(hit >= 30, "the south path is painted all along")
		t.ok(n > 400 and m > 200, "cells to paint")
		-- No path cell centre is far off its route.
		local pidx = Scatter.pathIndex(plan.routes)
		for k in cells do
			local ix, iz = Scatter.unkey(k)
			t.ok(Scatter.pathEdge(pidx, (ix + 0.5) * 4, (iz + 0.5) * 4) <= 1.5 + 1e-9, "a path cell strays")
		end
	end)
end
