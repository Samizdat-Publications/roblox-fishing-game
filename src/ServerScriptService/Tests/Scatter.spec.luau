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
		check("FarRow", T.farMinDist)
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

	-- N1 round 2 (the advisor's ruling after review 1).

	t.test("the walk from the back lawn to the dock head wanders and lands on the loop", function()
		local walk
		for _, rt in plan.routes do
			if rt.name == "StandsWalk" then
				walk = rt
			end
		end
		t.ok(walk ~= nil, "there is a walk")
		local w = walk.samples
		t.ok(math.abs(w[#w].x) < 0.01 and math.abs(w[#w].z - 86) < 0.01, "it ends at the dock head, dead on")
		t.ok(w[1].z > 125, "it starts on the back lawn")
		local flat = Scatter.flattest(w, 30)
		t.ok(flat >= 0.5, string.format("no straight run over 30 studs (bows %.2f)", flat))
		for _, seed in { 1, 2, 3, 77, 9999 } do
			for _, rt in Scatter.homeRoutes(seed) do
				if rt.name == "StandsWalk" then
					t.ok(Scatter.flattest(rt.samples, 30) >= 0.5, string.format("seed %d: the walk has a straight run", seed))
				end
			end
		end
		-- Between the stands (x +-18) it keeps off them: the gravel's edge stays inside x +-11.
		for _, q in w do
			if q.z > 90 and q.z < 102 then
				t.ok(math.abs(q.x) + q.w / 2 <= 11, string.format("the walk brushes a stand at z %.1f", q.z))
			end
		end
	end)

	t.test("the dock head and the chalkboard stay clear", function()
		local box
		for _, b in Scatter.KEEP_BOXES do
			if b.name == "DockHeadChalk" then
				box = b
			end
		end
		t.ok(box ~= nil, "the dock head keep-out exists")
		-- Shot 08's line of sight, from the dock (0, 50) to the chalkboard (30, 94).
		local sight = { name = "Sight", x1 = 0, z1 = 50, x2 = 30, z2 = 94, r = 3 }
		for _, it in plan.items do
			t.ok(not Scatter.inBox(box, it.x, it.z), string.format("%s at (%.1f, %.1f) is between the dock head and the chalkboard", it.model, it.x, it.z))
			t.ok(not Scatter.inBox(Scatter.KEEP_BOXES[4], it.x, it.z), it.model .. " at the chalkboard")
			if it.group == "Reeds" then
				t.ok(Scatter.laneDist(sight, it.x, it.z) > 3, string.format("reeds at (%.1f, %.1f) block the chalkboard from the dock", it.x, it.z))
			end
		end
		t.eq(Scatter.KEEP_BOXES[4].name, "Chalkboard", "box 4 is the chalkboard")
	end)

	t.test("kit reeds stand over the weed bed", function()
		local n = 0
		for _, it in group("Reeds") do
			if it.x >= -102 and it.x <= -54 and it.z >= 11 and it.z <= 65 and Scatter.waterline(it.x, it.z) <= -3 then
				n += 1
			end
		end
		print(string.format("  [Scatter] kit reeds over the weed bed: %d", n))
		t.ok(n >= 8, "at least 8 clumps over the weed bed")
	end)

	t.test("the far row: 34 to 60 studs back, spaced, no shadows", function()
		local far = group("FarRow")
		print(string.format("  [Scatter] far row: %d", #far))
		t.ok(#far >= 75 and #far <= Scatter.TUNING.farRow, string.format("about 80 far pines (%d)", #far))
		local fb = Scatter.TUNING.farBand
		for _, it in far do
			local d = Scatter.roundBox(it.x, it.z)
			t.ok(d >= fb[1] and d <= fb[2], string.format("a far pine at (%.1f, %.1f) is %.1f back, not 34 to 60", it.x, it.z, d))
			t.ok(it.shadow == false, "far pines cast no shadow")
			t.ok(it.model == "FarPine1" or it.model == "FarPine2", "far pines are FarPine1 or FarPine2")
			t.ok(it.z >= Scatter.TUNING.farZMin and it.z > -140 + 5, "clear of the Big Lake's water (z -140)")
			t.ok(Scatter.side(it.x, it.z) ~= "south", "no far row on the near shore")
		end
	end)

	t.test("shadows stop at 110 studs from the dock", function()
		t.eq(Scatter.TUNING.shadowDist, 110, "shadowDist")
		t.eq(Scatter.TUNING.treeMax, 140, "treeMax unchanged")
		for _, it in plan.items do
			local d = math.sqrt((it.x - Scatter.DOCK.x) ^ 2 + (it.z - Scatter.DOCK.z) ^ 2)
			if it.group == "Treeline" or it.group == "CornerTree" then
				t.ok(it.shadow == (d < 110), string.format("%s at %.0f studs from the dock: shadow %s", it.model, d, tostring(it.shadow)))
			end
		end
	end)

	t.test("the south lawn: meadow blobs off the walk and keep boxes, a group at each outer corner", function()
		local pidx = Scatter.pathIndex(plan.routes)
		local m = plan.meadow
		print(string.format("  [Scatter] meadow blobs: %d", #m))
		t.ok(#m >= 6 and #m <= 8, string.format("6 to 8 meadow blobs (%d)", #m))
		for _, b in m do
			t.ok(b.r >= 5 and b.r <= 8, "radius 5 to 8")
			t.ok(not Scatter.kept(b.x, b.z, b.r * 1.3), string.format("a meadow blob at (%.1f, %.1f) reaches a keep box", b.x, b.z))
			t.ok(Scatter.pathEdge(pidx, b.x, b.z) > b.r * 1.3, string.format("a meadow blob at (%.1f, %.1f) reaches a path", b.x, b.z))
			t.ok(b.z > 85, "on the south lawn")
		end
		for _, side in { -1, 1 } do
			local trees, under = 0, 0
			for _, it in plan.items do
				if it.x * side > 80 and it.z > 100 then
					if it.group == "CornerTree" then
						trees += 1
					elseif it.group == "CornerUnder" then
						under += 1
					end
				end
			end
			t.eq(trees, 1, "a pine at each outer corner")
			t.ok(under >= 3, string.format("bushes and ferns at each outer corner (%d)", under))
		end
	end)

	t.test("hill pines stand on hills, clear of the Big Lake, spaced", function()
		-- A fake world: flat at y 1, one dome 20 high at (240, 40), radius 70, and one inside the
		-- Big Lake's banks that must stay bare.
		local function height(x: number, z: number): number?
			local h = 1
			for _, d in { { x = 240, z = 40, r = 70 }, { x = 0, z = -300, r = 80 } } do
				local q = (x - d.x) ^ 2 + (z - d.z) ^ 2
				if q < d.r * d.r then
					h = math.max(h, 1 + 20 * (1 - q / (d.r * d.r)))
				end
			end
			return h
		end
		local items, blobs = Scatter.hillPines(SEED, height)
		print(string.format("  [Scatter] hill pines on the test hill: %d", #items))
		t.ok(#items >= 20, "pines on the hill")
		t.eq(#blobs, #items, "a forest floor patch under each")
		for _, it in items do
			t.ok((height(it.x, it.z) :: number) >= Scatter.TUNING.hillMinHeight, "on a hill")
			t.ok(not Scatter.inBigLake(it.x, it.z), "not by the Big Lake")
			t.ok(it.shadow == false, "no shadow")
			local d = Scatter.roundBox(it.x, it.z)
			t.ok(d >= 60 and d <= 300, "60 to 300 studs out")
		end
		t.ok(#items < 2 or Scatter.minSpacing(items) >= Scatter.TUNING.hillMinDist - 1e-9, "spaced")
	end)

	t.test("every placed group but driftwood carries a phone-tier tag", function()
		local seen = {}
		for _, it in plan.items do
			seen[it.group] = (seen[it.group] or 0) + 1
		end
		local parts = {}
		for g, n in seen do
			table.insert(parts, g .. " " .. n)
		end
		table.sort(parts)
		print("  [Scatter] groups: " .. table.concat(parts, ", "))
		for g in seen do
			if g ~= "Driftwood" then
				t.ok(Scatter.TAGS[g] ~= nil, g .. " has no tag")
			end
		end
		t.eq(Scatter.TAGS.TreeSwap, "FoliageTree", "swapped trees are trees")
		t.eq(Scatter.TAGS.HillPines, "FoliageTree", "hill pines are trees")
	end)
end
