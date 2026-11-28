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
		-- N3 review 1: the riffle's bed under the water is the BED slot, not the dry bar's pebble.
		t.eq(CreekPlan.slotAt(-230, 50, -1.2, -2), S.BED, "riffle bed under the water")
		t.eq(CreekPlan.slotAt(-230, 50, -0.3, -0.2), S.PEBBLE, "riffle's very edge")
		-- The moss reaches into the backing forest, out to MOSS_D, but not onto the paths or the gate.
		t.ok(CreekPlan.mossBand(-262, 40, CreekPlan.D(-262, 40)), "moss 25 studs west of the riffle")
		t.ok(not CreekPlan.mossBand(-203, 40, CreekPlan.D(-203, 40)), "no moss on the bank path")
		t.ok(not CreekPlan.mossBand(-180, 0, CreekPlan.D(-180, 0)), "no moss on the walk to the gate")
		t.ok(not CreekPlan.mossBand(-290, 40, CreekPlan.D(-290, 40)), "none past MOSS_D")
		-- The riffle's meander noses (Shore points) are dry gravel, not water.
		t.ok(CreekPlan.D(-239, 41) > 0 and CreekPlan.height(-239, 41) > 0, "RiffleWestA nose is a gravel bar")
	end)

	local function bad(it: any, why: string)
		return string.format("%s at %.1f, %.1f: %s", it.model, it.x, it.z, why)
	end

	t.test("nothing stands in a lane, on the paths, at the gate or in a shot", function()
		local withBoughs = CreekPlan.plan(CreekPlan.SEED, { boughsPer = CreekPlan.BOUGHS_ON })
		for _, it in withBoughs.items do
			if it.group ~= "Log" and it.group ~= "Roots" and it.group ~= "Boughs" and it.row ~= "frame" then
				t.ok(not CreekPlan.inLane(it.x, it.z), bad(it, "in a cast lane"))
				-- N3 review 2: the pool's edge stones sit on the waterline, where the bank path's
				-- keep-clear reaches the water (they keep off the lanes and the lantern).
				if it.group ~= "EdgeStones" then
					t.ok(not CreekPlan.kept(it.x, it.z), bad(it, "in a keep-clear"))
				end
				if it.group == "Trees" then
					t.ok(CreekPlan.treeShotClear(it.x, it.z, it.model), bad(it, "in a shot"))
				else
					t.ok(Scatter.shotClear(it.x, it.z, false), bad(it, "in a shot"))
				end
			end
			if it.group ~= "Boughs" then
				t.ok(not Scatter.inBox(Scatter.KEEP_BOXES[7], it.x, it.z), bad(it, "at the gate"))
			end
		end
		-- Shot 09's looser clearance is for cedars only: a pine there still keeps Scatter's (N3
		-- review 2: 09's eye at -230.5, 19).
		t.ok(CreekPlan.treeShotClear(-219, 27, "Cedar") and not CreekPlan.treeShotClear(-219, 27, "ShorePine1"), "09's loose clearance is cedars only")
		t.ok(not CreekPlan.treeShotClear(-225, 19, "Cedar"), "nothing within 10 of 09's eye")
	end)

	-- N3 review 2: the advisor moved them for 09's new eye (low in the run) at scale 1.4. From there
	-- their crowns' lowest foliage sits about a third of the way down the frame, not in the top
	-- quarter as review 1 asked: the frame is judged on the new captures.
	t.test("shot 09's two frame cedars: on the thirds, crowns in the top half", function()
		local c = CreekPlan.shotCam("09") :: any
		local eye = Vector3.new(c.eye[1], c.eye[2], c.eye[3])
		local cf = CFrame.lookAt(eye, Vector3.new(c.look[1], c.look[2], c.look[3]))
		local th = math.tan(math.rad(35)) -- shots.json fov 70 (vertical), a 16:9 frame
		local function screen(x: number, y: number, z: number): (number, number)
			local p = cf:PointToObjectSpace(Vector3.new(x, y, z))
			return 0.5 + 0.5 * (p.X / -p.Z) / (th * 16 / 9), 0.5 - 0.5 * (p.Y / -p.Z) / th
		end
		local found = 0
		local crown = CreekPlan.CROWN.Cedar
		for _, it in plan.items do
			if it.row == "frame" then
				found += 1
				t.ok(it.model == "Cedar" and it.scale == 1.4 and it.tilt == nil, bad(it, "an upright cedar at 1.4"))
				t.ok(not CreekPlan.inLane(it.x, it.z) and not CreekPlan.kept(it.x, it.z), bad(it, "out of the lanes and paths"))
				t.ok(CreekPlan.D(it.x, it.z) > 1, bad(it, "on the bank"))
				t.ok(math.sqrt((it.x - eye.X) ^ 2 + (it.z - eye.Z) ^ 2) >= CreekPlan.SHOT09.eyeR, bad(it, "clear of 09's eye"))
				local g = CreekPlan.height(it.x, it.z)
				local sx = screen(it.x, g, it.z)
				t.ok(math.abs(sx - 1 / 3) < 0.05 or math.abs(sx - 2 / 3) < 0.05, bad(it, string.format("trunk at %.2f of the frame", sx)))
				-- The crown's lowest foliage (CROWN: middle minus radius) stays in the top half, under 0.4.
				local _, sy = screen(it.x, g + (crown.h - crown.r) * it.scale, it.z)
				t.ok(sy < 0.4, bad(it, string.format("crown bottom at %.3f of the frame height", sy)))
			end
		end
		t.eq(found, #CreekPlan.FRAME_CEDARS, "both frame cedars")
	end)

	t.test("trunks: the bank row 1 to 9 studs back leaning out, the backing forest behind it", function()
		local trees = 0
		local rows: { [string]: number } = {}
		local back = { west = 0, east = 0, cedar = 0, near = 0 }
		local T = CreekPlan.TUNING
		for _, it in plan.items do
			if it.group == "Trees" then
				trees += 1
				rows[it.row or "?"] = (rows[it.row or "?"] or 0) + 1
				local D = CreekPlan.D(it.x, it.z)
				if it.row == "poolEast" then
					t.ok(D >= 10 and D <= 17, bad(it, "the pool's east row is past the path"))
				elseif it.row == "bank" then
					t.ok(D >= T.treeBand[1] and D <= T.treeBand[2], bad(it, string.format("D %.1f", D)))
					local deg = math.deg(it.tilt or 0)
					t.ok(deg >= 4 - 1e-6 and deg <= 10 + 1e-6, bad(it, "tilt"))
					t.ok(it.model ~= "Cedar" or (it.scale >= 1.2 and it.scale <= 1.5), bad(it, "cedar scale"))
				elseif it.row == "back" or it.row == "south" or it.row == "head" or it.row == "gate" then
					t.ok(it.tilt == nil, bad(it, "the backing forest stands upright"))
					-- N3 review 2: at D 20 and beyond, far pines; nearer, cedar and shore pine.
					local far = string.sub(it.model, 1, 7) == "FarPine"
					t.ok(far == (D >= T.backFarD), bad(it, string.format("far pines from D %d (D %.1f)", T.backFarD, D)))
				end
				if it.row == "south" or it.row == "head" or it.row == "gate" then
					local spec = if it.row == "south" then T.rowSouth elseif it.row == "head" then T.rowHead else T.rowGate
					t.ok(it.x >= spec.x[1] and it.x <= spec.x[2] and it.z >= spec.z[1] and it.z <= spec.z[2], bad(it, "inside its row's box"))
					t.ok(CreekPlan.inFence(it.x, it.z), bad(it, "inside the creek fence"))
					t.ok(not CreekPlan.kept(it.x, it.z) and not CreekPlan.inLane(it.x, it.z), bad(it, "off the paths and the lanes"))
				elseif it.row == "back" then
					if it.x <= T.backWestX then
						back.west += 1
						t.ok(D >= T.backWestBand[1] and D <= T.backWestBand[2], bad(it, string.format("west backing D %.1f", D)))
						t.ok(it.x >= CreekPlan.PROPS.x1, bad(it, "inside the props box"))
					else
						back.east += 1
						t.ok(it.x >= T.backEastX[1] and it.x <= T.backEastX[2], bad(it, "east backing x"))
					end
					if D < T.backFarD then
						back.near += 1
						if it.model == "Cedar" then
							back.cedar += 1
						end
					end
				elseif it.row ~= "frame" and it.row ~= "bank" and it.row ~= "poolEast" then
					t.ok(false, bad(it, "a tree with no row"))
				end
				t.ok(not CreekPlan.ruleWater(it.x, it.z), bad(it, "in the water"))
			elseif it.group == "Ferns" or it.group == "Moss" then
				t.ok(CreekPlan.D(it.x, it.z) > 0, bad(it, "on land"))
			end
		end
		t.ok((rows.bank or 0) >= 36, "bank trees: " .. tostring(rows.bank))
		t.eq(back.west, T.backWest, "west backing trees")
		t.eq(back.east, T.backEast, "east backing trees")
		-- The near backing trees (under D 20) are about 70 percent cedar (few of them: a loose band).
		local share = back.cedar / math.max(1, back.near)
		t.ok(back.near == 0 or (share >= 0.4 and share <= 0.9), string.format("near backing forest %.0f%% cedar of %d (70 wanted)", share * 100, back.near))
		t.eq(rows.south or 0, T.rowSouth.n, "the south row")
		t.eq(rows.head or 0, T.rowHead.n, "the head hill's row")
		t.eq(rows.gate or 0, T.rowGate.n, "the row behind the gate")
		local pine2 = 0
		for _, it in plan.items do
			if it.model == "ShorePine2" then
				pine2 += 1
			end
		end
		t.ok(pine2 <= 10, "few ShorePine2 along the riffle: " .. pine2)
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
		-- 44 studs wide, so bank trees cannot cover its middle (accepted: the pool stays open).
		t.ok(plan.coverage >= 0.2, string.format("crowns over %.0f%% of the riffle and run water", plan.coverage * 100))
	end)

	t.test("boughs: on (N3 review 2), 60 percent of the riffle is under crowns or boughs", function()
		t.eq(CreekPlan.TUNING.boughsPer, CreekPlan.BOUGHS_ON, "two boughs per riffle cedar, on")
		local off = CreekPlan.plan(CreekPlan.SEED, { boughsPer = 0 })
		t.eq(off.counts.CedarBough or 0, 0, "none with the switch at 0")
		local on = CreekPlan.plan(CreekPlan.SEED, { boughsPer = CreekPlan.BOUGHS_ON })
		t.ok(on.riffleCoverage >= 0.6, string.format("riffle %.0f%% covered with the boughs on", on.riffleCoverage * 100))
		local cedars = 0
		for i, it in on.items do
			if it.model == "CedarBough" then
				local tree = on.items[it.parent :: number]
				t.ok(tree.model == "Cedar" and (tree.row == "bank" or tree.row == "frame"), "a bough hangs from a bank cedar")
				t.ok(CreekPlan.weights(tree.z) > 0.5, "along the riffle")
				local H = CreekPlan.CEDAR_H * tree.scale
				t.ok(it.lift >= 0.5 * H and it.lift <= 0.85 * H + 1e-6, string.format("bough %d at %.0f%% of its tree", i, 100 * it.lift / H))
				-- it points out over the water: along its -X the drawn water comes nearer
				local lx, lz = -math.cos(it.yaw), math.sin(it.yaw)
				t.ok(CreekPlan.D(it.x + lx * 6, it.z + lz * 6) < CreekPlan.D(it.x, it.z), "a bough reaches toward the water")
			elseif it.model == "Cedar" and (it.row == "bank" or it.row == "frame") and CreekPlan.weights(it.z) > 0.5 then
				cedars += 1
			end
		end
		t.eq(on.counts.CedarBough or 0, cedars * CreekPlan.BOUGHS_ON, "two per riffle cedar")
	end)

	t.test("ten emergent rocks on the riffle, off the lanes, each trailing foam", function()
		local rocks = CreekPlan.emergentRocks(CreekPlan.SEED)
		t.eq(#rocks, CreekPlan.TUNING.rocks, "rocks")
		for _, k in rocks do
			t.ok(k.r >= 1 and k.r <= 2, "radius 1 to 2")
			t.ok(k.z >= 36 and k.z <= 70, "on the riffle")
			t.ok(CreekPlan.D(k.x, k.z) <= -k.r, string.format("rock at %.1f, %.1f over the water", k.x, k.z))
			t.ok(not CreekPlan.inLane(k.x, k.z, k.r), string.format("rock at %.1f, %.1f off the lanes", k.x, k.z))
		end
		t.eq(plan.counts.RockMedium, #rocks + #CreekPlan.edgeStones(CreekPlan.SEED), "placed (with the pool's edge stones)")
		local foam = CreekPlan.foam(CreekPlan.SEED)
		local trailed = 0
		for _, k in rocks do
			for _, s in foam do
				if math.abs(s.x - k.x) < 1 and s.z < k.z and s.z > k.z - k.r - 4 then
					trailed += 1
					break
				end
			end
		end
		t.ok(trailed >= 8, "rocks with a foam trail: " .. trailed)
	end)

	t.test("N3 review 2: ten wet-slate stones along the pool's east edge", function()
		local st = CreekPlan.edgeStones(CreekPlan.SEED)
		t.eq(#st, CreekPlan.TUNING.edgeStones, "stones")
		for _, k in st do
			t.ok(math.abs(CreekPlan.D(k.x, k.z)) <= 0.4, string.format("stone at %.1f, %.1f on the waterline", k.x, k.z))
			t.ok(k.x > -216, string.format("stone at %.1f, %.1f on the east side", k.x, k.z))
			t.ok(not CreekPlan.inLane(k.x, k.z), string.format("stone at %.1f, %.1f off the lanes", k.x, k.z))
		end
	end)

	t.test("N3 review 2: no meadow grass in the fence, the gate approach, the path slot", function()
		local S = CreekPlan.SLOT
		-- Inside the fence: moss to D 30, then grass becomes the hill forest floor; the paths stay.
		t.eq(CreekPlan.fenceSlot(-262, 40, CreekPlan.D(-262, 40), 2), S.MOSS, "moss 25 studs west of the riffle")
		t.eq(CreekPlan.fenceSlot(-290, 100, CreekPlan.D(-290, 100), 2), CreekPlan.FOREST_SLOT, "grass far out is forest floor")
		t.eq(CreekPlan.fenceSlot(-290, 100, CreekPlan.D(-290, 100), 25), nil, "the forest floor stays")
		t.eq(CreekPlan.fenceSlot(-203, 40, CreekPlan.D(-203, 40), 24), nil, "the bank path stays")
		t.eq(CreekPlan.fenceSlot(-150, 40, 50, 2), nil, "outside the fence: left alone")
		local grassLeft = 0
		for x = -298, -166, 4 do
			for z = -110, 124, 4 do
				local D = CreekPlan.D(x, z)
				local new = CreekPlan.fenceSlot(x, z, D, 2)
				if new == nil and not CreekPlan.kept(x, z, 1) and D >= 7 then
					grassLeft += 1
				end
			end
		end
		t.eq(grassLeft, 0, "no grass left inside the fence past the banks")
		-- The gate approach: lawn five studs each side of the walk, forest floor beyond.
		t.eq(CreekPlan.approachSlot(-140, 7, 25), CreekPlan.LAWN_SLOT, "lawn beside the walk")
		t.eq(CreekPlan.approachSlot(-140, 9, 25), CreekPlan.FOREST_SLOT, "forest floor past the band")
		t.eq(CreekPlan.approachSlot(-140, 20, 2), nil, "meadow out in the approach stays")
		t.eq(CreekPlan.approachSlot(-170, 0, 25), nil, "inside the fence is not the approach")
		t.eq(CreekPlan.PATH_SLOT, 32, "the creek paths on their own slot")
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
		local on = CreekPlan.plan(CreekPlan.SEED, { boughsPer = CreekPlan.BOUGHS_ON })
		t.ok(on.triangles <= CreekPlan.BUDGET, string.format("%d triangles with the boughs on", on.triangles))
		t.ok(plan.triangles >= 40000, string.format("%d triangles: dense enough", plan.triangles))
		for _, it in plan.items do
			if it.group == "Trees" then
				t.eq(it.shadow, Scatter.creekWaterDist(it.x, it.z) <= CreekPlan.TUNING.shadowDist, "tree shadow")
			end
		end
	end)

	t.test("foam lies on the riffle and below the boulders, over the water", function()
		local foam = CreekPlan.foam(CreekPlan.SEED)
		t.ok(#foam >= 15 and #foam <= 60, "strips: " .. #foam)
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
		if LookPresets.REVIEW2_CREEK_WATER then
			-- N3 review 2: darker water with a little more surface, its reflectance one constant.
			t.ok(math.abs(w.WaterColor.R * 255 - 52) < 1 and math.abs(w.WaterColor.G * 255 - 70) < 1 and math.abs(w.WaterColor.B * 255 - 48) < 1, "water 52, 70, 48")
			t.eq(w.WaterTransparency, 0.65, "transparency 0.65")
			t.eq(w.WaterReflectance, LookPresets.CREEK_REFLECTANCE, "reflectance from CREEK_REFLECTANCE")
			t.ok(w.WaterReflectance >= 0.04 and w.WaterReflectance <= 0.14, "inside the sweep")
			t.eq(w.WaterWaveSize, 0.06, "wave 0.06")
		elseif LookPresets.REVIEW1_CREEK then
			-- N3 review 1 (switched on): less glassy, more surface.
			t.ok(w.WaterTransparency >= 0.55 and w.WaterTransparency <= 0.65, "clear, with a surface")
			t.ok(w.WaterReflectance <= 0.3, "some reflectance")
		else
			t.ok(w.WaterTransparency >= 0.7 and w.WaterTransparency <= 0.8, "very clear")
			t.ok(w.WaterReflectance <= 0.15, "low reflectance")
		end
		t.ok(c.ambient.B >= c.ambient.R, "cooler shade")
		t.ok(type(c.exposureFloor) == "number" and c.exposureFloor > -1, "an exposure floor")
		t.ok(c.exposure >= 0, "the canopy's shade is lifted, not deepened")
		t.ok(type(c.dawnMist) == "table" and c.dawnMist.density > 0, "a little mist at dawn")
	end)
end
