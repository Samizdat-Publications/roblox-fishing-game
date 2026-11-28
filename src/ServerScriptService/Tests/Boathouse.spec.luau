-- The boathouse, the sales mooring and the "Your boat" choice (leg 3, N4, Config.BOATHOUSE_ON):
-- where they stand (clear of the path, the cast lanes, the shot cameras, the slips and the boats'
-- way to the channel), which boats show and what their boards say, and the choice rule.
-- Written 11/28/2026; UNVERIFIED in Studio until Boathouse.build() runs in Edit.
return function(t, Shared)
	local Config = require(Shared.Config)
	local BoatData = require(Shared.BoatData)
	local BoatLogic = require(Shared.BoatLogic)
	local BoatRules = require(Shared.BoatRules)
	local Plan = require(Shared.BoathousePlan)
	local Scatter = require(Shared.Scatter)
	local Shore = require(Shared.Shore)
	local WaterMap = require(Shared.WaterMap)

	local BANK_SEED = 20261129 -- BankDress.SEED: the painted path's wander

	local function with(key: string, value: any, body: () -> ())
		local was = (Config :: any)[key]
		;(Config :: any)[key] = value
		local ok, err = pcall(body)
		;(Config :: any)[key] = was
		if not ok then
			error(err, 0)
		end
	end

	-- Points over a rectangle, every `step` studs, edges included.
	local function samples(r: Plan.Rect, step: number): { { X: number, Y: number } }
		local out = {}
		local nx = math.max(1, math.ceil((r.x2 - r.x1) / step))
		local nz = math.max(1, math.ceil((r.z2 - r.z1) / step))
		for i = 0, nx do
			for j = 0, nz do
				table.insert(out, { X = r.x1 + (r.x2 - r.x1) * i / nx, Y = r.z1 + (r.z2 - r.z1) * j / nz })
			end
		end
		return out
	end

	local function overlap(a: Plan.Rect, b: Plan.Rect, pad: number): boolean
		return a.x1 < b.x2 + pad and b.x1 < a.x2 + pad and a.z1 < b.z2 + pad and b.z1 < a.z2 + pad
	end

	t.test("the boathouse lands switched off", function()
		t.eq(Config.BOATHOUSE_ON, false, "BOATHOUSE_ON")
	end)

	t.test("the boathouse stands off the path, out of the cast lanes, the keep-clears and the shot cameras", function()
		local idx = Scatter.pathIndex(Scatter.homeRoutes(BANK_SEED))
		for _, r in Plan.footprint() do
			for _, p in samples(r, 1) do
				local where = string.format("%s at (%.1f, %.1f)", r.name, p.X, p.Y)
				t.ok(Scatter.pathEdge(idx, p.X, p.Y) > 0.5, where .. " is on the path")
				t.ok(not Scatter.inLane(p.X, p.Y), where .. " is in a cast lane")
				t.ok(not Scatter.kept(p.X, p.Y), where .. " is in a keep-clear (slips, dock, stands, chalkboard)")
				t.ok(Scatter.shotClear(p.X, p.Y, false), where .. " is too near a shot camera")
			end
		end
	end)

	t.test("the shed is clear of the slips and their boats, with room to turn out of slip 4", function()
		local body = Plan.footprint()[1]
		local roof = Plan.roofRect()
		local farPosts = BoatRules.SLIP_X_EDGE + 18 -- BoatWorld's far posts
		t.ok(roof.x1 - farPosts >= 20, string.format("roof starts %.1f past the far posts", roof.x1 - farPosts))
		t.ok(body.x1 > 26, "west of it is the slips' keep-clear")
	end)

	t.test("the walkway reaches the shore and the shed's front opens on the water", function()
		local w = Plan.WALKWAY
		t.ok(not BoatRules.isBoatWater(Vector3.new((w.x1 + w.x2) / 2, 0, w.z2 - 0.2)), "walkway's shore end on land")
		t.ok(BoatRules.isBoatWater(Vector3.new((w.x1 + w.x2) / 2, 0, w.z1)), "walkway's north end over the water")
		local a = Plan.APRON
		t.ok(a.z2 == w.z1 and w.x2 == a.x2, "the walkway meets the apron")
		local body = Plan.footprint()[1]
		t.ok(math.abs(a.z2 - body.z1) < 0.01, "the apron runs along the shed's open front")
		for _, x in { body.x1 + 0.5, (body.x1 + body.x2) / 2, body.x2 - 0.5 } do
			t.ok(BoatRules.isBoatWater(Vector3.new(x, 0, body.z1 - 1)), string.format("water in front of the shed at x %.1f", x))
		end
	end)

	t.test("the shop board, lantern and rack canoe sit where the art has them", function()
		local cf = Plan.shopBoard()
		t.ok(cf.LookVector:Dot(Vector3.new(0, 0, -1)) > 0.999, "the Boats board faces the water")
		local body = Plan.footprint()[1]
		local p = cf.Position
		t.ok(p.X > body.x1 and p.X < body.x2 and p.Z > body.z1 and p.Z < body.z2, "board inside the shed")
		t.ok(math.abs(p.Y - (Plan.PIVOT.Y + 4.15)) < 1e-3, "board height")
		local lantern = Plan.lantern()
		t.ok(math.abs(lantern.X - (Plan.PIVOT.X - 7.55)) < 1e-3 and math.abs(lantern.Z - (Plan.PIVOT.Z - 6.9)) < 1e-3, "lantern glass point")
		local canoe = Plan.rackCanoe()
		t.ok(math.abs(canoe.Position.Y - Plan.CANOE_KEEL - (Plan.PIVOT.Y + 2.4)) < 1e-3, "the keel rests on the lower berth")
		t.ok(math.abs(canoe.LookVector.Z) < 1e-3, "the canoe lies along X")
		local choice = Plan.choiceBoard()
		t.ok(choice.LookVector:Dot(Vector3.new(1, 0, 0)) > 0.999, "Your boat faces the walkway")
		t.ok(choice.Position.X > body.x2 and choice.Position.X < Plan.WALKWAY.x1, "Your boat on the east wall, over the walkway's edge")
	end)

	t.test("one station per boat, in the shop's order, each with its price or Coming soon", function()
		with("CANOE_ON", false, function()
			local m = Plan.mooring()
			t.eq(#m, #BoatData.list, "a station per boat")
			for i, s in m do
				t.eq(s.id, BoatData.list[i].id, "order")
			end
			t.eq(m[1].text, "Coming soon", "the canoe before CANOE_ON")
			t.eq(m[2].text, "1,200", "the dinghy")
			t.eq(m[3].text, "Coming soon", "the Deep-V is not for sale")
		end)
		with("CANOE_ON", true, function()
			t.eq(Plan.mooring()[1].text, "350", "the canoe on sale")
		end)
		local deepV = BoatData.byId.DeepV
		local was = deepV.forSale
		deepV.forSale = true
		local text = Plan.priceText(deepV)
		deepV.forSale = was
		t.eq(text, "4,000", "the Deep-V once it is sold")
		t.eq(Plan.commas(350), "350")
		t.eq(Plan.commas(1200), "1,200")
		t.eq(Plan.commas(1234567), "1,234,567")
	end)

	t.test("the mooring floats in open water, clear of the boats' way, the spots and the cameras", function()
		local stations = Plan.mooring()
		local zones = WaterMap.zones()
		for i, s in stations do
			for _, p in samples(s.rect, 1) do
				local where = string.format("%s station at (%.1f, %.1f)", s.id, p.X, p.Y)
				local v = Vector3.new(p.X, 0, p.Y)
				t.ok(not Shore.isLand(v) and BoatRules.isBoatWater(v), where .. " is not open water")
				t.ok(Plan.routeDist(p.X, p.Y) >= Plan.ROUTE.half, where .. " is in the boats' way to the channel")
				t.ok(not Scatter.inLane(p.X, p.Y) and not Scatter.kept(p.X, p.Y), where .. " is in a lane or keep-clear")
				t.ok(Scatter.shotClear(p.X, p.Y, false), where .. " is too near a shot camera")
				for _, z in zones do
					local c, sz = z.cframe.Position, z.size
					local inside = math.abs(p.X - c.X) <= sz.X / 2 and math.abs(p.Y - c.Z) <= sz.Z / 2
					t.ok(not inside, where .. " is in the " .. z.name .. " fishing spot")
				end
			end
			for j, o in stations do
				if j ~= i then
					t.ok(not overlap(s.rect, o.rect, 1), s.id .. " and " .. o.id .. " stations touch")
				end
			end
			for _, r in Plan.footprint() do
				t.ok(not overlap(s.rect, r, 5), s.id .. " station near the boathouse " .. r.name)
			end
		end
	end)

	t.test("each price board faces the dock end, and each boat's bow points east", function()
		for _, s in Plan.mooring() do
			local to = Plan.VIEW - s.board.Position
			local flat = Vector3.new(to.X, 0, to.Z).Unit
			t.ok(s.board.LookVector:Dot(flat) > 0.999, s.id .. " board faces the dock end")
			t.ok(s.face.LookVector:Dot(flat) > 0.999, s.id .. " paint faces the dock end")
			t.ok(s.boat.LookVector:Dot(Vector3.new(1, 0, 0)) > 0.999, s.id .. " bow east")
			t.ok(s.float.LookVector:Dot(Vector3.new(1, 0, 0)) > 0.999, s.id .. " float's cleat toward its boat")
			t.ok(math.abs(s.float.Position.Y + Plan.FLOAT_SINK) < 1e-3, s.id .. " float rides 0.43 over the water")
		end
	end)

	t.test("Your boat lists the boats you own that are in the game, in the shop's order", function()
		with("CANOE_ON", false, function()
			t.eq(#Plan.yours({ boats = {} }), 0, "none")
			t.eq(#Plan.yours({}), 0, "an old save with no boats")
			local mine = Plan.yours({ boats = { Dinghy = true, Canoe = true } })
			t.eq(#mine, 1, "the canoe waits for CANOE_ON")
			t.eq(mine[1], "Dinghy")
		end)
		with("CANOE_ON", true, function()
			local mine = Plan.yours({ boats = { Dinghy = true, Canoe = true, DeepV = true } })
			t.eq(table.concat(mine, ","), "Canoe,Dinghy,DeepV", "shop order")
		end)
	end)

	t.test("choosing a boat: only one you own, in the game, not already at the slip", function()
		with("CANOE_ON", false, function()
			local d = { coins = 0, boats = { Dinghy = true, Canoe = true }, boat = "Dinghy" }
			local ok, msg = BoatLogic.choose(d, "Dinghy")
			t.ok(not ok and string.find(msg, "already", 1, true) ~= nil, "already at the slip")
			ok = BoatLogic.choose(d, "Canoe")
			t.ok(not ok, "the canoe isn't in the game yet")
			t.eq(d.boat, "Dinghy", "unchanged")
			ok = BoatLogic.choose(d, "DeepV")
			t.ok(not ok, "not owned")
			ok = BoatLogic.choose(d, "Yacht")
			t.ok(not ok, "unknown")
			ok = BoatLogic.choose(d, 42)
			t.ok(not ok, "not a name")
			t.eq(d.boat, "Dinghy", "still unchanged")
		end)
		with("CANOE_ON", true, function()
			local d = { coins = 0, boats = { Dinghy = true, Canoe = true }, boat = "Dinghy" }
			local ok, msg = BoatLogic.choose(d, "Canoe")
			t.ok(ok, msg)
			t.eq(d.boat, "Canoe", "the canoe waits at the slip now")
			t.eq(d.coins, 0, "choosing is free")
			local ok2 = BoatLogic.choose({ boats = { Canoe = true }, boat = "" }, "Canoe")
			t.ok(ok2, "a first pick from no boat at the slip")
		end)
	end)
end
