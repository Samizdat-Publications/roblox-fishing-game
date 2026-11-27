-- The lake's shore (L5d): rounded corners and points of land, and that every fishing rule
-- sees them through FishLogic.isOnWaterAny.
return function(t, Shared)
	local Shore = require(Shared.Shore)
	local FishLogic = require(Shared.FishLogic)
	local WaterMap = require(Shared.WaterMap)

	t.test("corners are land, the middle and the dock are water", function()
		local L = Shore.LAKE
		for _, c in { { L.x1 + 1, L.z1 + 1 }, { L.x2 - 1, L.z1 + 1 }, { L.x1 + 1, L.z2 - 1 }, { L.x2 - 1, L.z2 - 1 } } do
			t.ok(Shore.isLand(Vector3.new(c[1], 0, c[2])), string.format("corner %d,%d", c[1], c[2]))
		end
		t.ok(not Shore.isLand(Vector3.new(0, 0, 0)), "middle")
		for z = 30, 79, 7 do
			for x = -14, 14, 7 do
				t.ok(not Shore.isLand(Vector3.new(x, 0, z)), string.format("dock water %d,%d", x, z))
			end
		end
	end)

	t.test("each point of land is land at its nose and water a little past it", function()
		for _, p in Shore.POINTS do
			-- The nose: from the centre toward the lake's middle, just inside the radius.
			local dx, dz = -p.x, -p.z
			local len = math.sqrt(dx * dx + dz * dz)
			local nose = Vector3.new(p.x + dx / len * (p.r - 2), 0, p.z + dz / len * (p.r - 2))
			local past = Vector3.new(p.x + dx / len * (p.r + 3), 0, p.z + dz / len * (p.r + 3))
			t.ok(Shore.isLand(nose), p.name .. " nose is land")
			t.ok(not Shore.isLand(past), p.name .. " water past the nose")
			t.ok(not FishLogic.isOnWaterAny(nose, WaterMap.castWaters()), p.name .. " nose isn't castable water")
		end
	end)

	-- (Cover.spec checks every cover feature through isOnWaterAny, so the shore can't swallow one.)
	t.test("every fishing zone's middle stays open water", function()
		for _, z in WaterMap.zones() do
			local c = z.cframe.Position
			local d = Shore.depth(c.X, c.Z)
			-- The creek is narrow: its middles only need a few studs of water round them.
			local need = if c.X < -160 then -3 else -5
			t.ok(d == -math.huge or d < need, string.format("%s middle is open water (%.1f)", z.name, d))
		end
	end)

	t.test("the creek meanders but stays water down its middle, and is open where stretches join", function()
		t.ok(FishLogic.isOnWaterAny(Vector3.new(-230, 0, 50), WaterMap.waters()), "riffle is water")
		for z = 31, 74 do
			t.ok(not Shore.isLand(Vector3.new(-230, 0, z)), "riffle middle at z " .. z)
		end
		for z = -9, 29 do
			t.ok(not Shore.isLand(Vector3.new(-230, 0, z)), "run middle at z " .. z)
		end
		-- The joins: pool to run (z = -10) and run to riffle (z = 30) are open water.
		t.ok(not Shore.isLand(Vector3.new(-230, 0, -10.5)), "pool mouth")
		t.ok(not Shore.isLand(Vector3.new(-230, 0, 29.5)), "riffle mouth")
		-- The pool's corners are rounded off, and the banks bulge in.
		t.ok(Shore.isLand(Vector3.new(-251, 0, -69)), "pool corner")
		t.ok(Shore.isLand(Vector3.new(-235.5, 0, 41)), "riffle west bulge")
		t.ok(Shore.isLand(Vector3.new(-224.5, 0, 55)), "riffle east bulge")
	end)

	t.test("outside every shaped water the shore has no say", function()
		t.eq(Shore.depth(0, 120), -math.huge, "the south lawn")
		t.eq(Shore.depth(-300, 0), -math.huge, "past the creek")
	end)

	t.test("depth is continuous across the corner squares' edges", function()
		local r = Shore.CORNER_R
		local L = Shore.LAKE
		-- Walk along the inner edge of the south-east corner square: no jumps over 1.5 studs.
		local prev: number? = nil
		for i = 0, 40 do
			local z = L.z2 - r - 5 + i * 0.25 * 4
			local d = Shore.depth(L.x2 - r, math.min(z, L.z2))
			if prev then
				t.ok(math.abs(d - prev) < 1.5, string.format("smooth at z %.1f", z))
			end
			prev = d
		end
	end)
end
