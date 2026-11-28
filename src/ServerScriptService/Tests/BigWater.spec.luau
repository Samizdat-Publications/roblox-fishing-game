-- Big water (leg 3, N5, Shared/BigWater behind Config.BIG_WATER_ON): the bigger lake's shape, its
-- islets and keep-clears, the terrain column the Edit builder writes, the buoys, the marina and its
-- path, the walls, and the rules with the switch on and off.
return function(t, Shared)
	-- BoatRules reads the switch for its ZONES when it loads, so it goes on before anything else.
	local Config = require(Shared.Config)
	local wasOn = Config.BIG_WATER_ON
	Config.BIG_WATER_ON = true
	local BigWater = require(Shared.BigWater)
	local Shore = require(Shared.Shore)
	local BoatRules = require(Shared.BoatRules)
	local LookPresets = require(Shared.LookPresets)
	local FishLogic = require(Shared.FishLogic)
	local WaterMap = require(Shared.WaterMap)

	local function v(x: number, z: number): Vector3
		return Vector3.new(x, 0, z)
	end
	local function with(on: boolean, body: () -> ())
		local old = Config.BIG_WATER_ON
		Config.BIG_WATER_ON = on
		local ok, err = pcall(body)
		Config.BIG_WATER_ON = old
		if not ok then
			error(err, 0)
		end
	end
	local function blueArea(): any
		for _, a in BigWater.ownAreas() do
			if a.name == "BlueWater" then
				return a
			end
		end
		error("no BlueWater area")
	end
	local function routeDist(x: number, z: number): number
		local a, b = BigWater.ROUTE.from, BigWater.ROUTE.to
		local dx, dz = b.X - a.X, b.Z - a.Z
		local k = math.clamp(((x - a.X) * dx + (z - a.Z) * dz) / (dx * dx + dz * dz), 0, 1)
		return math.sqrt((x - a.X - dx * k) ^ 2 + (z - a.Z - dz * k) ^ 2)
	end

	t.test("the plan agrees with the rules, the looks and the old basin", function()
		t.eq(BigWater.BUOY_Z, BoatRules.BUOY_Z, "the buoy line")
		t.eq(BigWater.CROSS_BAND, LookPresets.AREA_BAND, "the crossing band is the look's blend band")
		local zones = {}
		for _, zn in LookPresets.ZONES do
			zones[zn.id] = zn
		end
		local u = BigWater.BLUE
		t.ok(zones.bluewater.x1 == u.x1 and zones.bluewater.x2 == u.x2 and zones.bluewater.z1 == u.z1 and zones.bluewater.z2 == u.z2, "blue water look covers the new extents")
		local b = BigWater.BASIN
		t.ok(zones.basin.x1 == b.x1 and zones.basin.x2 == b.x2 and zones.basin.z1 == b.z1 and zones.basin.z2 == b.z2, "the basin look is the basin")
		t.ok(zones.island.x == BigWater.ISLAND_RESERVE.x and zones.island.z == BigWater.ISLAND_RESERVE.z, "the island look sits on the reserve")
		t.ok(zones.island.r <= BigWater.ISLAND_RESERVE.r, "and inside it")
		local isl = BoatRules.ISLAND
		local c, s = isl.cframe.Position, isl.size
		local L = BigWater.LIGHTHOUSE_ISLAND
		t.ok(L.x1 == c.X - s.X / 2 and L.x2 == c.X + s.X / 2 and L.z1 == c.Z - s.Z / 2 and L.z2 == c.Z + s.Z / 2, "the lighthouse island box")
		-- The basin keeps L7's island and points.
		local old
		for _, a in Shore.AREAS do
			if a.name == "BigLake" then
				old = a
			end
		end
		for _, p in BigWater.BASIN_POINTS do
			local found = false
			for _, q in old.points do
				if q.name == p.name and q.x == p.x and q.z == p.z and q.r == p.r then
					found = true
				end
			end
			t.ok(found, p.name .. " kept from L7")
		end
	end)

	t.test("switched off, everything is L7's Big Lake", function()
		with(false, function()
			t.ok(Shore.areas() == Shore.AREAS, "Shore's areas")
			t.eq(BoatRules.waterAt(v(0, -700)), nil, "no water at z -700")
			t.eq(BoatRules.waterAt(v(-245, -229)), nil, "no cove")
			t.eq(BoatRules.paddleOnlyAt(v(-245, -229)), nil, "no paddle-only cove")
			t.eq(BoatRules.waterAt(v(0, -350)), "BlueWater", "the old blue water")
			t.eq(BoatRules.blueShare(v(0, -295)), 1, "the bob steps at the line, as before")
			t.eq(BoatRules.blueShare(v(0, -285)), 0, "and not before it")
			t.eq(#BoatRules.waters(), 3, "lake, channel, Big Lake")
		end)
	end)

	t.test("switched on: the bigger lake's water and land where the plan puts them", function()
		with(true, function()
			for _, p in { v(0, -700), v(-400, -700), v(400, -500), v(100, -950), v(0, -1140), v(-420, -400), v(420, -1100) } do
				t.eq(BoatRules.waterAt(p), "BlueWater", string.format("blue water at %d,%d", p.X, p.Z))
			end
			t.eq(BoatRules.waterAt(v(0, -200)), "Basin", "the basin")
			t.eq(BoatRules.waterAt(v(-245, -229)), "LilyCove", "Lily Cove")
			t.eq(BoatRules.waterAt(v(-202, -229)), "LilyCove", "the cove's mouth is water")
			t.ok(Shore.isLand(v(-202, -258)) and Shore.isLand(v(-202, -200)), "pinched by its two points")
			t.ok(Shore.isLand(v(-198, -258)) and Shore.isLand(v(-198, -200)), "seen from the basin too")
			for _, p in { v(-460, -700), v(470, -600), v(0, -1155), v(-240, -278), v(300, -285), v(0, -1300) } do
				t.eq(BoatRules.waterAt(p), nil, string.format("no boat water at %d,%d", p.X, p.Z))
			end
			t.ok(BigWater.pastNorthWall(0, -1200), "the North Reach is past the wall")
			t.ok(Shore.depth(0, -1200) < -20, "but it is drawn water")
			t.ok(not FishLogic.isOnWaterAny(v(0, -1200), WaterMap.castWaters()), "and never castable")
			t.ok(FishLogic.isOnWaterAny(v(0, -700), WaterMap.castWaters()), "blue water is castable")
			t.ok(FishLogic.isOnWaterAny(v(-245, -229), WaterMap.castWaters()), "the cove is castable")
			t.ok(BoatRules.needsBoat(v(-245, -229)) and BoatRules.needsBoat(v(0, -700)), "both need a boat")
			t.eq(#BoatRules.waters(), 5, "lake, channel, basin, blue water, cove")
		end)
	end)

	t.test("rock islets: on the route's way, spaced, clear of banks, the buoys and the reserves", function()
		with(true, function()
			local n = #BigWater.ISLETS
			t.ok(n >= 6 and n <= 10, "6 to 10 islets: " .. n)
			local bare = table.clone(blueArea())
			bare.points = {}
			for _, h in BigWater.HEADLANDS do
				if table.find(h.areas, "BlueWater") then
					table.insert(bare.points, { name = h.name, x = h.x, z = h.z, r = h.r })
				end
			end
			local ir = BigWater.ISLAND_RESERVE
			local onRoute = 0
			for i, a in BigWater.ISLETS do
				t.ok(Shore.isLand(v(a.x, a.z)), a.name .. " is land")
				t.ok(not Shore.isLand(v(a.x + a.r + 3, a.z)), a.name .. " has water round it")
				t.ok(Shore.depthIn(bare, a.x, a.z) <= -(a.r + BigWater.ISLET_BANK_CLEAR), a.name .. " clear of every bank and headland")
				t.ok(math.sqrt((a.x - ir.x) ^ 2 + (a.z - ir.z) ^ 2) >= ir.r + a.r, a.name .. " clear of the island reserve")
				t.ok(routeDist(a.x, a.z) >= a.r + BigWater.ROUTE_CLEAR, a.name .. " leaves the route open")
				t.ok(a.z + a.r <= BigWater.BUOY_Z - BigWater.ISLET_BUOY_CLEAR, a.name .. " clear of the buoy line")
				t.ok(not BigWater.inSeaReserve(a.x, a.z, a.r), a.name .. " clear of the sea channel")
				if routeDist(a.x, a.z) <= 120 then
					onRoute += 1
				end
				for j = i + 1, n do
					local b = BigWater.ISLETS[j]
					t.ok(math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) >= BigWater.ISLET_SPACING, a.name .. " and " .. b.name .. " spaced")
				end
			end
			t.ok(onRoute >= 4, "at least four mark the way out: " .. onRoute)
		end)
	end)

	t.test("headlands, hills, ridges and trees keep the island and the sea channel clear", function()
		local ir, sea = BigWater.ISLAND_RESERVE, BigWater.SEA_RESERVE
		for _, h in BigWater.HEADLANDS do
			t.ok(not BigWater.inSeaReserve(h.x, h.z, h.r), h.name .. " clear of the sea channel")
			t.ok(math.sqrt((h.x - ir.x) ^ 2 + (h.z - ir.z) ^ 2) >= ir.r + h.r, h.name .. " clear of the island")
		end
		for _, hl in BigWater.hills() do
			t.ok(not BigWater.inSeaReserve(hl.x, hl.z, hl.r), "no hill in the sea channel")
		end
		local north, west = 0, 0
		for _, p in BigWater.ridges() do
			t.ok(not (p.x > BigWater.BLUE.x2 and p.z > BigWater.REACH.z1), "the east side stays open: no ridge east of the lake")
			t.ok(not BigWater.inSeaReserve(p.x, p.z, p.w), "no ridge in the sea channel")
			if p.facing == "south" then
				north += 1
			else
				west += 1
			end
		end
		t.ok(north >= 20 and west >= 5, string.format("ridges north %d and west %d", north, west))
		with(true, function()
			-- The east bank in the sea reserve is low plain bank: no feature, ground no higher than its cap.
			for z = sea.z1, sea.z2, 8 do
				for x = BigWater.BLUE.x2 + 2, BigWater.CLEAR.x2, 8 do
					local kind = BigWater.featureAt(x, z)
					t.eq(kind, nil, string.format("no headland at %d,%d", x, z))
					t.ok(BigWater.column(x, z).top <= BigWater.SEA_BANK_TOP + 1e-9, "low bank there")
				end
			end
		end)
	end)

	t.test("the run: marina to the island stays on open water and takes about half a minute", function()
		with(true, function()
			local a, b = BigWater.ROUTE.from, BigWater.ROUTE.to
			local len = (b - a).Magnitude
			t.ok(len / 26 >= 25 and len / 26 <= 35, string.format("%.0f studs, %.1f s at 26", len, len / 26))
			for k = 0, 40 do
				local p = a:Lerp(b, k / 40)
				t.ok(BoatRules.isBoatWater(p), string.format("water at %.0f,%.0f", p.X, p.Z))
				t.ok(Shore.depth(p.X, p.Z) <= -20, string.format("20 studs from land at %.0f,%.0f", p.X, p.Z))
			end
			local bell = BigWater.BELL_BUOY
			t.ok(routeDist(bell.X, bell.Z) <= 30, "the bell buoy is on the way")
			t.ok(Shore.depth(bell.X, bell.Z) <= -20, "in open water")
			for _, i in BigWater.ISLETS do
				t.ok(math.sqrt((bell.X - i.x) ^ 2 + (bell.Z - i.z) ^ 2) >= i.r + 40, "bell buoy clear of " .. i.name)
			end
			for _, name in BigWater.GULLS.perches do
				local found = false
				for _, i in BigWater.ISLETS do
					found = found or i.name == name
				end
				t.ok(found, "gull perch " .. name .. " is an islet")
			end
		end)
	end)

	t.test("the buoy line: red west of the route, green east, a gate the route runs through", function()
		with(true, function()
			local list = BigWater.buoys()
			t.ok(#list >= 8, "buoys across the basin's mouth: " .. #list)
			local gateX = BigWater.routeX(BigWater.BUOY_Z)
			local signs = {}
			for _, b in list do
				t.eq(b.z, BoatRules.BUOY_Z, b.name .. " on the line")
				t.ok(Shore.depth(b.x, b.z) <= -3, b.name .. " on water")
				t.eq(b.color, if b.x < gateX then "Red" else "Green", b.name .. " colour")
				if b.sign then
					table.insert(signs, b)
				end
			end
			t.eq(#signs, 2, "two gate buoys carry the board")
			t.ok(signs[1].x < gateX and signs[2].x > gateX, "the route runs between them")
		end)
	end)

	t.test("the marina: a pier off the basin's south bank, four Deep-V slips on water", function()
		with(true, function()
			local m = BigWater.MARINA
			t.ok(math.abs(m.root.Z - BigWater.BASIN.z2) <= 3, "the pier leaves the south bank")
			t.ok(m.root.X > 15 + 30, "east of the channel")
			t.ok(BoatRules.isBoatWater(m.tip), "its end stands in the water")
			t.ok(BoatRules.isBoatWater(Vector3.new(m.lantern.X, 0, m.lantern.Z)), "the lantern at the end, over water")
			local L, W = 16, 7 -- the Deep-V (BoatData)
			local prev = nil
			for i = 1, #m.slipZs do
				local c = BigWater.marinaSlip(i, L)
				for _, dx in { -L / 2, 0, L / 2 } do
					for _, dz in { -W / 2, W / 2 } do
						local p = c + Vector3.new(dx * 1.1, 0, dz * 1.1)
						t.ok(BoatRules.isBoatWater(p), string.format("slip %d footprint on water at %.1f,%.1f", i, p.X, p.Z))
					end
				end
				t.ok(c.X - L / 2 >= m.root.X + m.width / 2 + 1, "slip " .. i .. " clear of the pier")
				if prev then
					t.ok(math.abs(prev.Z - c.Z) >= W + 2, "slips " .. (i - 1) .. " and " .. i .. " apart")
				end
				prev = c
			end
		end)
	end)

	t.test("the path: from the footbridge's east ramp to the pier, on dry ground", function()
		with(true, function()
			local P = BigWater.PATH
			local ch = BoatRules.CHANNEL
			local half = ch.size.X / 2
			t.ok(P[1].X >= half + 10 and P[1].X <= half + 14, "starts at the foot of the east ramp")
			t.ok((P[#P] - BigWater.MARINA.root).Magnitude < 1e-6, "ends at the pier's root")
			for k = 1, #P - 1 do
				for s = 0, 10 do
					local p = P[k]:Lerp(P[k + 1], s / 10)
					t.ok(not BoatRules.isBoatWater(p), string.format("dry at %.0f,%.0f", p.X, p.Z))
					t.ok(not FishLogic.isOnWaterAny(p, WaterMap.waters()), string.format("not the home lake at %.0f,%.0f", p.X, p.Z))
					t.ok(p.X - half >= 8, "clear of the channel")
				end
				t.ok((P[k + 1] - P[k]).Magnitude <= 25, "no long straight run")
			end
		end)
	end)

	t.test("the bed: deep blue water, shallows near shore, a drop-off past the line, a shallow cove", function()
		with(true, function()
			t.eq(BigWater.column(-100, -650).top, -BigWater.BLUE_DEPTH, "24 deep out in the blue water")
			t.eq(BigWater.column(0, -215).top, -BigWater.BASIN_DEPTH, "7 deep in the basin")
			t.ok(math.abs(BigWater.column(0, -1205).top + BigWater.REACH_DEPTH) < 0.5, "about 16 under the North Reach")
			local cove = BigWater.column(-245, -229)
			t.ok(cove.top >= -BigWater.COVE_DEPTH - 1e-9 and cove.top < 0, "Lily Cove is shallow water")
			-- Two studs off the west bank of the blue water: shallow.
			t.ok(BigWater.column(BigWater.BLUE.x1 + 2, -700).top > -2, "shallows by the bank")
			-- The drop-off: the bed never rises going north across it, and has dropped 15 within 50 studs.
			-- (x -100: away from the islets, whose skirts rise round them.)
			local prev = BigWater.column(-100, -280).top
			for z = -284, -350, -4 do
				local top = BigWater.column(-100, z).top
				t.ok(top <= prev + 1e-9, "never rises at z " .. z)
				prev = top
			end
			t.ok(BigWater.column(-100, -280).top - BigWater.column(-100, -340).top >= 15, "the drop-off")
			for _, i in BigWater.ISLETS do
				local c = BigWater.column(i.x, i.z)
				t.eq(c.top, i.h, i.name .. " rises to its height")
				t.eq(c.material, "Rock", i.name .. " is granite")
				t.eq(c.slot, BigWater.SLOTS.granite.slot, i.name .. " on the granite slot")
			end
			for _, h in BigWater.HEADLANDS do
				-- The nose: just inside the circle toward the lake's middle line.
				local dx = if h.x < 0 then 1 else -1
				local nose = BigWater.column(h.x + dx * (h.r - 3), h.z)
				t.eq(nose.material, "Rock", h.name .. " has a rocky nose")
			end
			t.eq(BigWater.column(0, -900).material, "Basalt", "the deep bed")
			t.eq(BigWater.column(0, -900).slot, BigWater.SLOTS.deepBed.slot, "on the deep-bed slot")
		end)
	end)

	t.test("the terrain has no steps: neighbouring columns differ by at most a cell", function()
		with(true, function()
			local c = BigWater.CLEAR
			local worst, at = 0, ""
			for x = c.x1 + 2, c.x2 - 6, 16 do
				for z = c.z1 + 2, c.z2 - 6, 16 do
					local a = BigWater.column(x, z).top
					for _, d in { { 4, 0 }, { 0, 4 } } do
						local b = BigWater.column(x + d[1], z + d[2]).top
						if math.abs(a - b) > worst then
							worst, at = math.abs(a - b), string.format("%d,%d", x, z)
						end
					end
				end
			end
			-- The seams: basin and blue water, blue water and the reach, the cove's mouth.
			for x = -196, 196, 4 do
				for _, z in { -282, -286, -290, -294, -1146, -1150, -1154 } do
					local d = math.abs(BigWater.column(x, z).top - BigWater.column(x, z - 4).top)
					if d > worst then
						worst, at = d, string.format("%d,%d", x, z)
					end
				end
			end
			for z = -244, -214, 2 do
				local d = math.abs(BigWater.column(-198, z).top - BigWater.column(-202, z).top)
				if d > worst then
					worst, at = d, string.format("-198,%d", z)
				end
			end
			t.ok(worst <= BigWater.CELL + 0.5, string.format("worst step %.2f at %s", worst, at))
		end)
	end)

	t.test("crossing the buoy line is felt over 40 studs, the same as the look's blend", function()
		with(true, function()
			t.eq(BigWater.crossing(-270), 0, "not yet")
			t.ok(math.abs(BigWater.crossing(-290) - 0.5) < 1e-9, "half at the line")
			t.eq(BigWater.crossing(-310), 1, "all the way")
			for z = -260, -320, -2 do
				local w = LookPresets.areaWeights(v(0, z)).bluewater
				t.ok(math.abs(w - BigWater.crossing(z)) < 1e-9, "the water colour and the swell agree at z " .. z)
				t.ok(math.abs(BoatRules.blueShare(v(0, z)) - BigWater.crossing(z)) < 1e-9, "blueShare at z " .. z)
			end
			t.eq(BoatRules.blueShare(v(0, 0)), 0, "none on the home lake")
			t.ok(math.abs(BigWater.windGain(-700) - BigWater.WIND_GAIN) < 1e-9, "the wind is up out there")
			t.eq(BigWater.windGain(-200), 1, "and calm in the basin")
		end)
	end)

	t.test("the rules on the bigger lake: the cove, the line and the wall", function()
		with(true, function()
			local CoveIn, BasinNear = v(-245, -229), v(-150, -229)
			t.ok((BoatRules.mayBeAt("Canoe", CoveIn)), "the canoe paddles into Lily Cove")
			local ok, msg = BoatRules.mayBeAt("Dinghy", CoveIn)
			t.ok(not ok and msg == BoatRules.LILY_TEXT, "the dinghy is refused with the cove's words")
			local okV, msgV = BoatRules.mayBeAt("DeepV", CoveIn)
			t.ok(not okV and msgV == BoatRules.LILY_TEXT, "so is the Deep-V")
			-- The canoe never crosses the buoy line to get there.
			for k = 0, 20 do
				local p = BasinNear:Lerp(CoveIn, k / 20)
				local w = BoatRules.waterAt(p)
				t.ok(w == "Basin" or w == "LilyCove", "basin or cove all the way: " .. tostring(w))
			end
			-- The dinghy is still turned back at the line, anywhere along it.
			for _, x in { -150, 0, 150 } do
				local verdict, at = BoatRules.check("Dinghy", v(x, BoatRules.BUOY_Z + 2), v(x, BoatRules.BUOY_Z - 2), 0.5)
				t.eq(verdict, "turn", "dinghy turned at x " .. x)
				t.ok(at ~= nil and (at :: Vector3).Z > BoatRules.BUOY_Z, "pushed back south")
			end
			t.ok((BoatRules.mayBeAt("DeepV", v(-400, -1000))), "the Deep-V goes anywhere in the blue water")
			-- The north wall.
			local kind, text = BoatRules.stopAhead("DeepV", v(0, -1145), Vector3.new(0, 0, -1), 26)
			t.eq(kind, "edge", "the wall stops a boat heading north")
			t.eq(text, BigWater.EDGE_TEXT, "with its words")
			t.ok(not (string.find(BigWater.EDGE_TEXT, "\u{2014}", 1, true)), "no em dash")
			-- Spots.
			t.eq(FishLogic.spotAt(v(0, -1000), BoatRules.ZONES), "DropOff", "the drop-off is all the blue water")
			t.eq(FishLogic.spotAt(v(420, -500), BoatRules.ZONES), "DropOff", "even out on the wings")
			t.eq(FishLogic.spotAt(CoveIn, BoatRules.ZONES), "Basin", "the cove fishes as the basin")
			t.eq(FishLogic.spotAt(v(-55, -240), BoatRules.ZONES), "IslandPoint", "the island point is unchanged")
			t.eq(BoatRules.castCheck(v(0, -700), "Dinghy", 0), false, "blue water still needs a bigger boat")
		end)
	end)

	t.test("walls: round the water on land, the north one across it, Lily Cove's mouth open", function()
		with(true, function()
			for _, w in BigWater.walls() do
				t.ok(w.x2 > w.x1 and w.z2 > w.z1, w.name .. " has size")
				for _, p in { v(w.x1, w.z1), v(w.x2, w.z1), v(w.x1, w.z2), v(w.x2, w.z2), v((w.x1 + w.x2) / 2, (w.z1 + w.z2) / 2) } do
					t.ok(not BoatRules.isBoatWater(p), string.format("%s stands off the boat water at %.0f,%.0f", w.name, p.X, p.Z))
				end
				for z = -242, -216 do
					t.ok(not (BigWater.inRect(w, -201, z)), w.name .. " leaves the cove's mouth open")
				end
			end
		end)
	end)

	t.test("tree and reed spots: on dry banks and in the cove's shallows", function()
		with(true, function()
			local trees = BigWater.treeSpots()
			t.ok(#trees >= 120 and #trees <= 360, "trees: " .. #trees)
			local ir = BigWater.ISLAND_RESERVE
			for i, s in trees do
				if s.kind ~= "islet" then
					t.ok(BigWater.depth(s.x, s.z) >= 10, "a tree on dry land")
					t.ok(not BigWater.inSeaReserve(s.x, s.z), "none in the sea channel")
				else
					t.ok(Shore.isLand(v(s.x, s.z)), "an islet pine on its islet")
				end
				t.ok(math.sqrt((s.x - ir.x) ^ 2 + (s.z - ir.z) ^ 2) > ir.r, "none on the island reserve")
				for j = i + 1, #trees do
					local o = trees[j]
					t.ok((s.x - o.x) ^ 2 + (s.z - o.z) ^ 2 >= BigWater.MIN_TREE_GAP ^ 2 - 1e-6, "trees apart")
				end
			end
			local weeds = BigWater.coveWeeds()
			t.eq(#weeds, 48, "48 weeds in the cove")
			for _, s in weeds do
				t.eq(BoatRules.waterAt(v(s.x, s.z)), "LilyCove", "in the cove")
			end
		end)
	end)

	t.test("the terrain writes: chunks tile the rewrite exactly", function()
		local c = BigWater.CLEAR
		local area = 0
		for _, k in BigWater.chunks() do
			area += (k.x2 - k.x1) * (k.z2 - k.z1)
			t.ok(k.x1 % BigWater.CELL == 0 and k.z1 % BigWater.CELL == 0, "on the voxel grid")
		end
		t.eq(area, (c.x2 - c.x1) * (c.z2 - c.z1), "no gap, no overlap")
		local n = BigWater.voxelCount()
		t.eq(n.columns, 240 * 290, "columns")
	end)

	Config.BIG_WATER_ON = wasOn
end
