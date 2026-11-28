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
					-- Neon Pass 1: deep enough for terrain to draw a water surface (top cell under half ground).
					t.ok(CreekPlan.height(x, z, D) <= -CreekPlan.WATER_MIN, string.format("water deep enough to show at %.1f, %.1f", x, z))
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
		t.ok(R.x2 <= -208 and R.z2 <= 76, "short of the bank path and the creek head's rocks (z 76 on)")
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
		-- The moss reaches into the backing forest, out to MOSS_D (Neon Pass 1: 52), over the grass
		-- beside the paths but never onto their gravel (slots 14, 24, 32 are not in MOSS_OVER).
		t.eq(CreekPlan.MOSS_D, 52, "moss to D 52")
		t.ok(CreekPlan.mossBand(-262, 40, CreekPlan.D(-262, 40)), "moss 25 studs west of the riffle")
		t.ok(CreekPlan.mossBand(-203, 40, CreekPlan.D(-203, 40)), "moss beside the bank path")
		for _, gravel in { 14, 24, 32 } do
			t.ok(not CreekPlan.MOSS_OVER[gravel], "never over gravel slot " .. gravel)
			t.eq(CreekPlan.fenceSlot(-203, 40, CreekPlan.D(-203, 40), gravel), nil, "the bank path's gravel stays (" .. gravel .. ")")
			t.eq(CreekPlan.fenceSlot(-180, 0, CreekPlan.D(-180, 0), gravel), nil, "the gate walk's gravel stays (" .. gravel .. ")")
		end
		t.ok(not CreekPlan.mossBand(-296, 40, CreekPlan.D(-296, 40)), "none past MOSS_D")
		-- Past the fence but inside Neon's box (behind the pool, by the gate): moss band only.
		t.eq(CreekPlan.fenceSlot(-158, -20, 40, 2), CreekPlan.SLOT.MOSS, "moss by the gate within D 52")
		t.eq(CreekPlan.fenceSlot(-158, -20, 60, 2), nil, "outside the fence past D 52: left alone")
		t.eq(CreekPlan.fenceSlot(-150, -20, 40, 2), nil, "past Neon's box (x -152): left alone")
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
				-- Neon Pass 1: the pool's east lip pass dresses the bank path's water edge too.
				if it.group ~= "EdgeStones" and it.group ~= "Lip" then
					t.ok(not CreekPlan.kept(it.x, it.z), bad(it, "in a keep-clear"))
				end
				if it.group == "Trees" then
					t.ok(CreekPlan.treeShotClear(it.x, it.z, it.model), bad(it, "in a shot"))
				else
					t.ok(Scatter.shotClear(it.x, it.z, false), bad(it, "in a shot"))
				end
			end
			if it.group == "Gate" then
				-- Neon Pass 1: the gate walk's dressing stands in the home lake's gate keep-clear
				-- (Scatter's), off the walk's middle and out of the gate itself.
				t.ok(math.abs(it.z) >= 4.5, bad(it, "on the walk's middle"))
				t.ok(not CreekPlan.kept(it.x, it.z), bad(it, "at the gate"))
			elseif it.group ~= "Boughs" then
				t.ok(not Scatter.inBox(Scatter.KEEP_BOXES[7], it.x, it.z), bad(it, "at the gate"))
			end
		end
		-- Shot 09's looser clearance is for cedars only: a pine there still keeps Scatter's (Neon
		-- Pass 1: 09's eye at -223.5, 25).
		t.ok(CreekPlan.treeShotClear(-212, 30, "Cedar") and not CreekPlan.treeShotClear(-212, 30, "ShorePine1"), "09's loose clearance is cedars only")
		t.ok(not CreekPlan.treeShotClear(-225, 19, "Cedar"), "nothing within 10 of 09's eye")
	end)

	-- N3 review 2: the advisor moved them for 09's new eye (low in the run) at scale 1.4. From there
	-- their crowns' lowest foliage sits about a third of the way down the frame, not in the top
	-- quarter as review 1 asked: the frame is judged on the new captures.
	-- Neon Pass 1 (11/28/2026): Neon's two at scale 1.3, flanking the riffle from 09's eye at the
	-- riffle mouth: the east one near the left third (0.35), the west one at 0.74, outside the
	-- right third, so the test asks for one trunk in each outer band rather than on the thirds.
	t.test("shot 09's two frame cedars: one each side of the chute, crowns in the top half", function()
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
				t.ok(it.model == "Cedar" and it.scale == 1.3 and it.tilt == nil, bad(it, "an upright cedar at 1.3"))
				t.ok(not CreekPlan.inLane(it.x, it.z) and not CreekPlan.kept(it.x, it.z), bad(it, "out of the lanes and paths"))
				t.ok(CreekPlan.D(it.x, it.z) > 1, bad(it, "on the bank"))
				t.ok(math.sqrt((it.x - eye.X) ^ 2 + (it.z - eye.Z) ^ 2) >= CreekPlan.SHOT09.eyeR, bad(it, "clear of 09's eye"))
				local g = CreekPlan.height(it.x, it.z)
				local sx = screen(it.x, g, it.z)
				t.ok((sx >= 0.25 and sx <= 0.42) or (sx >= 0.58 and sx <= 0.8), bad(it, string.format("trunk at %.2f of the frame", sx)))
				-- The crown's lowest foliage (CROWN: middle minus radius) stays in the top half, under 0.4.
				local _, sy = screen(it.x, g + (crown.h - crown.r) * it.scale, it.z)
				t.ok(sy < 0.4, bad(it, string.format("crown bottom at %.3f of the frame height", sy)))
			end
		end
		t.eq(found, #CreekPlan.FRAME_CEDARS, "both frame cedars")
	end)

	-- N3 review 3 (final): p07 has its own eye low in the riffle; every tree keeps clear of every
	-- camera, cedars by 09's looser radii for 09 and p07, so the riffle's cedars still frame both.
	t.test("p07's own eye: every tree clear of every camera, the riffle's cedars kept", function()
		local c = CreekPlan.shotCam("p07") :: any
		t.ok(c ~= nil and c.eye[1] == -229.5 and c.eye[2] == 2.8 and c.eye[3] == 27, "p07's eye in SHOT_CAMS")
		t.ok(CreekPlan.LOOSE_CEDAR_SHOTS["p07-riffle-morning"] == true, "p07 frames between cedars like 09")
		for _, it in plan.items do
			if it.group == "Trees" and it.row ~= "frame" then
				t.ok(CreekPlan.treeShotClear(it.x, it.z, it.model), bad(it, "clear of every shot camera"))
			end
		end
		local bankCedars = 0
		for _, it in plan.items do
			if it.model == "Cedar" and it.row == "bank" and it.z > 26 and it.z < 76 then
				bankCedars += 1
			end
		end
		t.ok(bankCedars >= 8, "cedars along the riffle: " .. bankCedars)
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
					-- N3 review 3: the south row's shore pines stand at any distance.
					local southPine = it.southPine == true
					t.ok(southPine or far == (D >= T.backFarD), bad(it, string.format("far pines from D %d (D %.1f)", T.backFarD, D)))
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
		local southPines, southOther = 0, 0
		for _, it in plan.items do
			if it.row == "south" then
				if it.southPine then
					southPines += 1
					t.ok(string.sub(it.model, 1, 9) == "ShorePine", bad(it, "a south shore pine"))
					t.ok(it.scale >= T.pineScale[1] and it.scale <= T.pineScale[2], bad(it, "south shore pine scale"))
				else
					southOther += 1
					t.ok(it.scale >= T.southScale[1] and it.scale <= T.southScale[2], bad(it, "south row scale"))
				end
			end
		end
		-- N3 review 3 (final): six of the south row's 18 are shore pines, the rest varied in scale.
		t.eq(southPines, T.southPines, "shore pines in the south row")
		t.eq(southOther, T.rowSouth.n - T.southPines, "the rest of the south row")
		for _, it in plan.items do
			if it.model == "ShorePine2" and it.row ~= "south" then
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
		-- Neon Pass 1: a bough that would not reach over the water is left off (at most a few).
		local nb = on.counts.CedarBough or 0
		t.ok(nb <= cedars * CreekPlan.BOUGHS_ON and nb >= cedars * CreekPlan.BOUGHS_ON - 4, string.format("about two per riffle cedar: %d for %d cedars", nb, cedars))
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
		-- Neon Pass 1: 8 to 10, bigger (scale 0.45 to 0.85), merged with the east lip pass.
		t.ok(#st >= 8 and #st <= CreekPlan.TUNING.edgeStones, "stones: " .. #st)
		for _, k in st do
			local sc = k.r * 2 / CreekPlan.ROCK_EXTENT
			t.ok(sc >= 0.45 - 1e-6 and sc <= 0.86, string.format("stone scale %.2f", sc))
			t.ok(k.z >= -72 and k.z <= -16, "on the pool's east edge stretch")
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
		local band = if CreekPlan.APPROACH_NO_LAWN then CreekPlan.FOREST_SLOT else CreekPlan.LAWN_SLOT
		t.eq(CreekPlan.approachSlot(-140, 7, 25), band, "the walk band")
		t.eq(CreekPlan.approachSlot(-140, 9, 25), CreekPlan.FOREST_SLOT, "forest floor past the band")
		-- Neon Pass 1: no meadow grass left in the gate's foreground; out past it, meadow stays.
		t.eq(CreekPlan.approachSlot(-140, 20, 2), CreekPlan.FOREST_SLOT, "meadow in the gate's foreground is forest floor")
		t.eq(CreekPlan.approachSlot(-140, 5, 2), band, "meadow beside the walk takes the band's slot")
		t.eq(CreekPlan.approachSlot(-125, 32, 2), nil, "meadow out past the foreground stays")
		for x = -154, -121, 4 do
			for z = -24, 24, 4 do
				t.ok(CreekPlan.approachSlot(x, z, 2) ~= nil, string.format("no meadow grass at %d, %d", x, z))
			end
		end
		t.eq(CreekPlan.approachSlot(-170, 0, 25), nil, "inside the fence is not the approach")
		t.eq(CreekPlan.PATH_SLOT, 32, "the creek paths on their own slot")
		local pt = CreekPlan.PATH_TINT
		t.ok(pt[1] == 120 and pt[2] == 110 and pt[3] == 92, "N3 review 3: the path gravel 120, 110, 92")
		-- N3 review 3 (final): no MeadowLawn anywhere in the approach box (slots 19 and 26 become
		-- 27 everywhere in it), and the walk's gravel is never touched.
		if CreekPlan.APPROACH_NO_LAWN then
			local A = CreekPlan.APPROACH
			for x = A.x1 + 1, A.x2 - 1, 4 do
				for z = A.z1 + 1, A.z2 - 1, 4 do
					for _, lawn in { 19, 26 } do
						t.eq(CreekPlan.approachSlot(x, z, lawn), CreekPlan.FOREST_SLOT, string.format("slot %d to 27 at %d, %d", lawn, x, z))
					end
					for _, gravel in { 14, 24, 32 } do
						t.eq(CreekPlan.approachSlot(x, z, gravel), nil, string.format("gravel %d kept at %d, %d", gravel, x, z))
					end
				end
			end
		end
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

	-- N3 review 3 (final): the foam map streaks along U, so the strip's +X (U) runs downstream,
	-- one V tile is the strip's width, and the U offset grows downstream.
	t.test("foam strips lay the map's U along the flow and scroll it downstream", function()
		for _, st in CreekPlan.foam(CreekPlan.SEED) do
			local f = CreekPlan.foamFace(st)
			t.eq(f.sizeX, st.len, "length along X")
			t.eq(f.sizeZ, st.w, "width along Z")
			t.ok(math.abs(f.rx * f.rx + f.rz * f.rz - 1) < 1e-9, "a unit direction")
			-- The water runs from the riffle's head (z 75) to the pool (-z): +X points south.
			t.ok(f.rz < -0.9, string.format("+X downstream (rz %.2f)", f.rz))
			t.eq(f.tileU, 6, "6 studs of flow a tile")
			t.eq(f.tileV, st.w, "one V tile across the strip")
		end
		t.eq(CreekPlan.foamOffsetU(0, 4), 0, "no offset at the start")
		t.ok(CreekPlan.foamOffsetU(0.5, 4) > CreekPlan.foamOffsetU(0.25, 4), "the offset grows (downstream)")
		for i = 0, 50 do
			local o = CreekPlan.foamOffsetU(i * 0.37, 3.5)
			t.ok(o >= 0 and o < CreekPlan.FOAM_TILE_U, "within one tile")
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

	-- White water, take 2 (after the N3 final critic): soft beams and pillows.
	t.test("foam beams: same seed same beams, inside the budget, over the water at one height", function()
		local a, b = CreekPlan.foamBeams(CreekPlan.SEED), CreekPlan.foamBeams(CreekPlan.SEED)
		t.eq(#a, #b, "same count")
		for i, x in a do
			t.ok(x.x0 == b[i].x0 and x.z1 == b[i].z1 and x.w0 == b[i].w0, "beam " .. i)
		end
		t.ok(#a >= 30 and #a <= CreekPlan.FOAM_BEAM_MAX, "beams: " .. #a)
		local kinds: { [string]: number } = {}
		for _, bm in a do
			kinds[bm.kind] = (kinds[bm.kind] or 0) + 1
			for i = 0, 16 do
				local s = i / 16
				local x, y, z = CreekPlan.foamBeamPoint(bm, s)
				t.eq(y, CreekPlan.FOAM_Y, "one height")
				t.ok(CreekPlan.D(x, z) < -CreekPlan.foamBeamWidth(bm, s) / 2, string.format("beam over water at %.1f, %.1f", x, z))
			end
			local x0, _, z0 = CreekPlan.foamBeamPoint(bm, 0)
			local x1, _, z1 = CreekPlan.foamBeamPoint(bm, 1)
			t.ok(math.abs(x0 - bm.x0) < 1e-9 and math.abs(z0 - bm.z0) < 1e-9, "starts on Attachment0")
			t.ok(math.abs(x1 - bm.x1) < 1e-9 and math.abs(z1 - bm.z1) < 1e-9, "ends on Attachment1")
			t.ok(z1 < z0, "runs downstream (-z)")
			t.ok(bm.w0 > 0 and bm.w1 > 0 and bm.w0 ~= bm.w1, "tapers")
			t.ok(bm.speed > 0 and CreekPlan.foamTextureSpeed(bm.speed) > 0, "scrolls Attachment0 to 1 (downstream)")
		end
		t.ok((kinds.riffle or 0) >= 20, "riffle beams: " .. tostring(kinds.riffle))
		t.ok((kinds.drop or 0) >= 3, "drop beams: " .. tostring(kinds.drop))
		t.ok((kinds.boulder or 0) >= 6, "boulder trails: " .. tostring(kinds.boulder))
		t.ok((kinds.rock or 0) >= 8, "rock trails: " .. tostring(kinds.rock))
		t.ok(CreekPlan.FOAM_Y > 0.06 and CreekPlan.FOAM_Y <= 0.15, "just over the water and its chop")
		t.ok(CreekPlan.FOAM_ZOFFSET > 0 and CreekPlan.FOAM_ZOFFSET <= 0.1, "a small pull toward the camera")
	end)

	t.test("foam beams have no hard edges: faded at both ends, never fully opaque", function()
		for _, bm in CreekPlan.foamBeams(CreekPlan.SEED) do
			local f = CreekPlan.foamBeamFade(bm)
			t.eq(f[1][1], 0, "first keypoint at the head")
			t.eq(f[1][2], 1, "clear at the head")
			t.eq(f[#f][1], 1, "last keypoint at the tail")
			t.eq(f[#f][2], 1, "clear at the tail")
			for i = 2, #f do
				t.ok(f[i][1] > f[i - 1][1], "keypoints in order")
			end
			t.ok(bm.fadeIn >= 0.15 and bm.fadeOut >= 0.25, "long soft fades")
			t.ok(bm.base >= 0.1 and bm.base < 0.5, "translucent in the middle")
		end
	end)

	t.test("riffle and drop beams keep clear of the rocks; every rock trails a beam from under it", function()
		local beams = CreekPlan.foamBeams(CreekPlan.SEED)
		local rocks = CreekPlan.emergentRocks(CreekPlan.SEED)
		for _, bm in beams do
			if bm.kind == "riffle" or bm.kind == "drop" then
				for i = 0, 8 do
					local x, _, z = CreekPlan.foamBeamPoint(bm, i / 8)
					for _, k in rocks do
						t.ok((x - k.x) ^ 2 + (z - k.z) ^ 2 >= k.r ^ 2, "beam clear of a rock")
					end
				end
			end
		end
		local trailed = 0
		for _, k in rocks do
			for _, bm in beams do
				if bm.kind == "rock" and (bm.x0 - k.x) ^ 2 + (bm.z0 - k.z) ^ 2 < k.r ^ 2 then
					trailed += 1
					break
				end
			end
		end
		t.ok(trailed >= 8, "rocks trailing a beam from under them: " .. trailed)
	end)

	t.test("the beams' attachments lie level, their Axis along the flow", function()
		for _, yaw in { -0.3, 0, 0.2 } do
			local right, up = CreekPlan.foamFrame(yaw)
			t.ok(math.abs(right[2]) < 1e-9, "Axis level")
			t.ok(right[3] < -0.9, "Axis downstream")
			t.ok(math.abs(right[1] * up[1] + right[2] * up[2] + right[3] * up[3]) < 1e-9, "up square to Axis")
			if CreekPlan.FOAM_BEAM_NORMAL == "Y" then
				t.eq(up[2], 1, "SecondaryAxis up")
			else
				t.ok(math.abs(up[2]) < 1e-9, "SecondaryAxis across the flow")
			end
		end
	end)

	t.test("pillows and spray: one pillow per rock and boulder, over water, inside the budget", function()
		local puffs = CreekPlan.foamPuffs(CreekPlan.SEED)
		local pillows = 0
		for _, p in puffs do
			t.ok(CreekPlan.D(p.x, p.z) < 0, string.format("%s over water at %.1f, %.1f", p.kind, p.x, p.z))
			t.ok(p.rate > 0 and p.rate <= 10 and p.life[2] <= 1.5, "low rate, short life")
			if p.kind == "pillow" then
				pillows += 1
				t.ok(p.speed[2] <= 1, "a slow pillow")
				t.ok(p.transparency[1] >= 0.5, "a soft pillow")
			end
		end
		t.eq(pillows, #CreekPlan.emergentRocks(CreekPlan.SEED) + #CreekPlan.BOULDERS, "pillows")
		t.ok(#puffs <= CreekPlan.FOAM_PUFF_MAX, "emitters: " .. #puffs)
		local n = CreekPlan.foamParticleMax(puffs)
		t.ok(n <= CreekPlan.FOAM_PARTICLE_MAX, "particles alive at most: " .. n)
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
		-- Neon Pass 1 (11/28/2026): the exposure is lowered a little (-0.10; round 3's 0 blew out the
		-- noon grass and the night gravel); the floor stays -0.25 so the bobber reads.
		t.ok(c.exposure >= c.exposureFloor, "the exposure above the floor")
		-- N3 review 3 (final, 11/28/2026): exposure 0 and the floor raised to -0.10.
		if LookPresets.N3_REVIEW3_CREEK then
			t.eq(c.exposure, 0, "review 3: exposure 0")
			t.eq(c.exposureFloor, -0.1, "review 3: the floor -0.10")
		else
			t.eq(c.exposureFloor, -0.25, "the floor stays -0.25")
		end
		t.ok(type(c.dawnMist) == "table" and c.dawnMist.density > 0, "a little mist at dawn")
		-- With a clock the creek's water is its time-of-day water (CREEK_WATER_BY_TIME); review 2's
		-- water above is the fallback without one.
		t.ok(LookPresets.creekWaterAt(12).WaterTransparency <= 0.65, "noon water not above 0.65")
	end)

	-- Neon Pass 1 (11/28/2026): the pool's east lip, the bushes under the backing trunks, the gate
	-- walk's dressing, and the log moved where shots 10 and 12 see it.
	t.test("Neon Pass 1: the pool's east lip: ferns on land, reeds at the edge", function()
		local T = CreekPlan.TUNING
		local spots = CreekPlan.lipSpots(CreekPlan.SEED)
		local ferns, reeds = 0, 0
		for _, p in spots do
			t.ok(p.x >= T.lipX[1] and p.x <= T.lipX[2] and p.z >= T.lipZ[1] and p.z <= T.lipZ[2], string.format("%s at %.1f, %.1f on the lip", p.model, p.x, p.z))
			t.ok(not CreekPlan.inLane(p.x, p.z), string.format("%s at %.1f, %.1f off the lanes", p.model, p.x, p.z))
			t.ok(Scatter.shotClear(p.x, p.z, false), "out of the shots")
			local D = CreekPlan.D(p.x, p.z)
			if p.kind == "fern" then
				ferns += 1
				t.ok(D > 0, "fern on land")
			else
				reeds += 1
				t.ok(p.model == "ReedClump1" and D <= 0, "reed at the water's edge")
			end
		end
		t.ok(ferns >= 4 and ferns <= T.lipFernsEast, "lip ferns: " .. ferns)
		t.ok(reeds >= 2 and reeds <= T.lipReeds, "lip reeds: " .. reeds)
	end)

	t.test("Neon Pass 1: bushes under the backing trunks, the gate walk dressed", function()
		local T = CreekPlan.TUNING
		local under, gate, stones = 0, 0, 0
		for _, it in plan.items do
			if it.group == "Under" then
				under += 1
				local D = CreekPlan.D(it.x, it.z)
				t.ok(D >= T.underD[1] and D <= T.underD[2], bad(it, string.format("under the backing trees (D %.1f)", D)))
				t.ok(it.model == "Bush1" or it.model == "Bush2", bad(it, "a bush"))
			elseif it.group == "Gate" then
				gate += 1
				t.ok(it.x >= -160.5 and it.x <= -138, bad(it, "by the gate walk"))
				t.ok(math.abs(it.z) >= 4.5 and math.abs(it.z) <= 35, bad(it, "off the walk's middle"))
				if string.sub(it.model, 1, 11) == "ShoreStones" then
					stones += 1
				end
			end
		end
		t.eq(under, T.underBushes, "bushes under the trunks")
		t.ok(gate >= 12 and gate <= 16, "gate walk items: " .. gate)
		t.eq(stones, T.gateStones, "shore stones by the gate")
	end)

	t.test("Neon Pass 1: the log searched for in x -250..-234, z -62..-42", function()
		for _, it in plan.items do
			if it.model == "MossyLog" then
				t.ok(it.x >= -250 and it.x <= -234 and it.z >= -62 and it.z <= -42, string.format("log middle at %.1f, %.1f", it.x, it.z))
			end
		end
		t.ok(CreekPlan.LOG_TINT_ON == false, "the log tint is held (part colour multiplies vertex colours)")
	end)

	t.test("Neon Pass 1: the riffle's water is deep enough to draw", function()
		-- Down the riffle's middle (z 28 to 75) the planned ground sits at least WATER_MIN under
		-- the surface, so the top terrain cell (y -4..0) is mostly water.
		for z = 28, 75 do
			local h = CreekPlan.height(-230, z)
			t.ok(h <= -CreekPlan.WATER_MIN, string.format("riffle bed at z %d: %.2f", z, h))
			t.ok((h + 4) / 4 < 0.5, string.format("top cell under half ground at z %d", z))
		end
		t.ok(CreekPlan.REGION.z2 >= 76, "the riffle's last cell redrawn")
	end)
end
