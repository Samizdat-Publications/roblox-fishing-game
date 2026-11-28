-- Cedar Creek's dress (leg 3, N3, Shared/CreekPlan): the same seed gives the same creek; every
-- point the fishing rules call water is drawn as water and stays under it; the drawn water has
-- no square corners and reaches only a little past the rules' edge; nothing stands in a cast
-- lane, on the bank path, on the walk to the gate or the gate, or in a fixed shot; the triangle
-- budget and the creek's look preset.
return function(t, Shared)
	local CreekPlan = require(Shared.CreekPlan)
	local FishLogic = require(Shared.FishLogic)
	local WaterMap = require(Shared.WaterMap)
	local Scatter = require(Shared.Scatter)
	local LookPresets = require(Shared.LookPresets)

	local plan = CreekPlan.plan(CreekPlan.SEED)
	local R = CreekPlan.REGION

	t.test("the same seed gives the same creek; another seed a different one", function()
		local again = CreekPlan.plan(CreekPlan.SEED)
		t.eq(#again.items, #plan.items, "same count")
		for i, it in plan.items do
			local b = again.items[i]
			t.ok(b.model == it.model and b.x == it.x and b.z == it.z and b.yaw == it.yaw and b.scale == it.scale, "item " .. i)
		end
		local f1, f2 = CreekPlan.foam(CreekPlan.SEED), CreekPlan.foam(CreekPlan.SEED)
		t.eq(#f1, #f2, "same foam")
		t.ok(f1[1].x == f2[1].x and f1[#f1].z == f2[#f2].z, "same foam strips")
		local other = CreekPlan.plan(CreekPlan.SEED + 1)
		local differs = #other.items ~= #plan.items
		for i, it in plan.items do
			local b = other.items[i]
			if not b or b.x ~= it.x then
				differs = true
			end
		end
		t.ok(differs, "another seed moves things")
	end)

	t.test("ruleWater agrees with FishLogic.isOnWaterAny in the creek", function()
		local boxes = WaterMap.waters()
		for x = -256, -204, 1.5 do
			for z = -74, 78, 1.5 do
				local a = CreekPlan.ruleWater(x, z)
				local b = FishLogic.isOnWaterAny(Vector3.new(x, -0.5, z), boxes)
				t.ok(a == b, string.format("rule water at %.1f, %.1f", x, z))
			end
		end
	end)

	t.test("every point the rules call water is drawn as water, under water", function()
		local worst, n = -math.huge, 0
		for x = -253, -207, 0.5 do
			for z = -71, 75, 0.5 do
				if CreekPlan.ruleWater(x, z) then
					n += 1
					local D = CreekPlan.D(x, z)
					worst = math.max(worst, D)
					t.ok(D <= -0.25, string.format("drawn water at %.1f, %.1f (D %.2f)", x, z, D))
					t.ok(CreekPlan.height(x, z, D) <= -0.6, string.format("ground under the water at %.1f, %.1f", x, z))
				end
			end
		end
		t.ok(n > 8000, "sampled the creek")
	end)

	t.test("every creek spot's middle and the four creek shots' water stay water", function()
		for _, c in WaterMap.CREEK do
			local mx, mz = (c.x1 + c.x2) / 2, (c.z1 + c.z2) / 2
			t.ok(CreekPlan.ruleWater(mx, mz), c.name .. " middle is rule water")
			t.ok(CreekPlan.D(mx, mz) < -3, c.name .. " middle drawn deep in the water")
		end
	end)

	t.test("the drawn water reaches only a little past the rules' water", function()
		-- Every drawn-water point is within 4.5 studs of rule water, and the extra area is small.
		local rule, extra = 0, 0
		for x = -262, -207, 1 do
			for z = -80, 72, 1 do
				local w = CreekPlan.ruleWater(x, z)
				if w then
					rule += 1
				elseif CreekPlan.D(x, z) < 0 then
					extra += 1
					local near = false
					for dx = -4.5, 4.5, 0.5 do
						for dz = -4.5, 4.5, 0.5 do
							if not near and dx * dx + dz * dz <= 4.5 * 4.5 and CreekPlan.ruleWater(x + dx, z + dz) then
								near = true
							end
						end
					end
					t.ok(near, string.format("drawn water at %d, %d is near the rules' water", x, z))
				end
			end
		end
		t.ok(extra / rule < 0.12, string.format("extra drawn water %.1f%% of the rules' water", 100 * extra / rule))
	end)

	t.test("no square corners where the stretches meet", function()
		-- At each step between stretches, the old 90 degree land corner is now drawn water (a
		-- fillet), and the bank turns through it gradually: the waterline crosses the diagonal.
		for _, c in { { -236, 30, -1, 1 }, { -224, 30, 1, 1 }, { -240, -10, -1, 1 }, { -220, -10, 1, 1 } } do
			local x, z, sx, sz = c[1], c[2], c[3], c[4]
			t.ok(not CreekPlan.ruleWater(x + sx * 0.5, z + sz * 0.5), "the rules keep the corner land")
			t.ok(CreekPlan.D(x + sx * 0.5, z + sz * 0.5) < 0, string.format("corner %d, %d is filleted", x, z))
		end
	end)

	t.test("the terrain region stays in the creek", function()
		t.ok(R.x2 <= -208 and R.z2 <= 72, "short of the bank path and the creek head")
		t.ok(R.x1 >= -270 and R.z1 >= -84, "inside the creek's look zone")
		for _, v in { R.x1, R.x2, R.y1, R.y2, R.z1, R.z2 } do
			t.eq(v % 4, 0, "whole cells")
		end
		-- Columns past TOUCH from the water are not rewritten; blending ends by then.
		t.ok(CreekPlan.BLEND[2] <= CreekPlan.TOUCH, "blend inside the touched band")
		t.eq(CreekPlan.blend(0.5, 1, CreekPlan.TOUCH), 1, "old ground at the edge")
	end)

	t.test("ground: gravel bars, cut banks, moss, and pebbles under the water", function()
		local S = CreekPlan.SLOT
		local seen = {}
		for x = -266, -210, 4 do
			for z = -82, 70, 4 do
				local D = CreekPlan.D(x + 2, z + 2)
				if D < CreekPlan.TOUCH then
					local h = CreekPlan.height(x + 2, z + 2, D)
					local slot = CreekPlan.slotAt(x + 2, z + 2, h, D)
					if slot then
						seen[slot] = (seen[slot] or 0) + 1
					end
					t.ok(h >= -10 and h <= 2.4, "height in range")
				end
			end
		end
		for name, slot in S do
			t.ok((seen[slot] or 0) > 0, "some " .. name)
		end
		-- The riffle's meander noses (Shore points) are dry gravel, not water.
		t.ok(CreekPlan.D(-239, 41) > 0 and CreekPlan.height(-239, 41) > 0, "RiffleWestA nose is a gravel bar")
	end)

	local function bad(it: any, why: string)
		return string.format("%s at %.1f, %.1f: %s", it.model, it.x, it.z, why)
	end

	t.test("nothing stands in a lane, on the paths, at the gate or in a shot", function()
		for _, it in plan.items do
			if it.group ~= "Log" and it.group ~= "Roots" then
				t.ok(not CreekPlan.inLane(it.x, it.z), bad(it, "in a cast lane"))
				t.ok(not CreekPlan.kept(it.x, it.z), bad(it, "in a keep-clear"))
				t.ok(Scatter.shotClear(it.x, it.z, it.group == "Trees"), bad(it, "in a shot"))
			end
			t.ok(not Scatter.inBox(Scatter.KEEP_BOXES[7], it.x, it.z), bad(it, "at the gate"))
		end
	end)

	t.test("trunks stand 2 to 6 studs back from the water, never on it, leaning out 4 to 10 degrees", function()
		local trees = 0
		for _, it in plan.items do
			if it.group == "Trees" then
				trees += 1
				local D = CreekPlan.D(it.x, it.z)
				if it.x > -200 then
					t.ok(D >= 10 and D <= 17, bad(it, "the pool's east row is past the path"))
				else
					t.ok(D >= 2 and D <= 6, bad(it, string.format("D %.1f", D)))
					local deg = math.deg(it.tilt or 0)
					t.ok(deg >= 4 - 1e-6 and deg <= 10 + 1e-6, bad(it, "tilt"))
					t.ok(it.model ~= "Cedar" or (it.scale >= 1.2 and it.scale <= 1.5), bad(it, "cedar scale"))
				end
				t.ok(not CreekPlan.ruleWater(it.x, it.z), bad(it, "in the water"))
			elseif it.group == "Ferns" or it.group == "Moss" then
				t.ok(CreekPlan.D(it.x, it.z) > 0, bad(it, "on land"))
			end
		end
		t.ok(trees >= 36, "trees: " .. trees)
		t.ok(Scatter.minSpacing((function()
			local out = {}
			for _, it in plan.items do
				if it.group == "Trees" then
					table.insert(out, it)
				end
			end
			return out
		end)()) >= CreekPlan.TUNING.treeGap, "trunk spacing")
	end)

	t.test("the crowns reach out over the riffle, the run and the pool", function()
		-- Measured 11/28/2026: about 25 percent overall (riffle 42, run 34, pool 17); the pool is
		-- 44 studs wide, so bank trees cannot cover its middle.
		t.ok(plan.coverage >= 0.2, string.format("crowns over %.0f%% of the riffle and run water", plan.coverage * 100))
	end)

	t.test("the mossy log lies across the pool's corner, out of the cast lanes", function()
		local log
		for _, it in plan.items do
			if it.model == "MossyLog" then
				log = it
			end
		end
		t.ok(log ~= nil, "a log")
		local e = log.ends
		t.ok(CreekPlan.D(e[1], e[2]) > 0 and CreekPlan.D(e[3], e[4]) > 0, "both ends on the bank")
		t.ok(CreekPlan.D(log.x, log.z) < -1, "its middle over the water")
		t.ok(e[3] < e[1], "root plate on the west end")
		for _, l in CreekPlan.LANES do
			t.ok(CreekPlan.laneDist(l, log.x, log.z) > l.r + CreekPlan.LOG_HALF_WIDTH, "clear of " .. l.name)
		end
		-- The yaw lays +X toward the west end.
		local xx, xz = math.cos(log.yaw), -math.sin(log.yaw)
		t.ok(xx * (e[3] - log.x) + xz * (e[4] - log.z) > 0, "+X toward the root end")
	end)

	t.test("roots hang on the cut banks", function()
		local n = 0
		for _, it in plan.items do
			if it.model == "CreekRoots" then
				n += 1
				t.ok(CreekPlan.cut(it.lipX, it.lipZ) > 0.3, bad(it, "on a cut bank"))
				t.ok(CreekPlan.D(it.lipX, it.lipZ) > 1, bad(it, "lip on land"))
			end
		end
		t.ok(n >= 4, "roots: " .. n)
	end)

	t.test("inside the triangle budget, and trees near the creek cast shadows", function()
		t.ok(plan.triangles <= CreekPlan.BUDGET, string.format("%d triangles", plan.triangles))
		t.ok(plan.triangles >= 40000, string.format("%d triangles: dense enough", plan.triangles))
		for _, it in plan.items do
			if it.group == "Trees" then
				t.eq(it.shadow, Scatter.creekWaterDist(it.x, it.z) <= CreekPlan.TUNING.shadowDist, "tree shadow")
			end
		end
	end)

	t.test("foam lies on the riffle and below the boulders, over the water", function()
		local foam = CreekPlan.foam(CreekPlan.SEED)
		t.ok(#foam >= 15 and #foam <= 45, "strips: " .. #foam)
		for _, s in foam do
			t.ok(CreekPlan.D(s.x, s.z) < -0.4, string.format("strip at %.1f, %.1f over water", s.x, s.z))
			t.ok(s.speed > 0 and s.w > 0 and s.len > 0, "a real strip")
		end
		for _, p in CreekPlan.SPRAY do
			t.ok(CreekPlan.D(p.x, p.z) < 0, "spray over water")
		end
	end)

	t.test("the creek's look: clear tea water, cool shade, a floor under the exposure", function()
		local c = LookPresets.AREAS.creek :: any
		local w = c.water
		t.ok(math.abs(w.WaterColor.R * 255 - 64) < 1 and math.abs(w.WaterColor.G * 255 - 84) < 1 and math.abs(w.WaterColor.B * 255 - 58) < 1, "water 64, 84, 58")
		t.ok(w.WaterTransparency >= 0.7 and w.WaterTransparency <= 0.8, "very clear")
		t.ok(w.WaterReflectance <= 0.15, "low reflectance")
		t.ok(c.ambient.B >= c.ambient.R, "cooler shade")
		t.ok(type(c.exposureFloor) == "number" and c.exposureFloor > -1, "an exposure floor")
		t.ok(c.exposure >= 0, "the canopy's shade is lifted, not deepened")
		t.ok(type(c.dawnMist) == "table" and c.dawnMist.density > 0, "a little mist at dawn")
	end)
end
