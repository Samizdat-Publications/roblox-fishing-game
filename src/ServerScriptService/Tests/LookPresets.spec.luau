return function(t, Shared)
	local LookPresets = require(Shared.LookPresets)

	-- Every number and colour channel in a look, flattened to "Target.Prop[.R]" = value.
	local function flat(look): { [string]: number }
		local out = {}
		for target, values in look do
			for k, v in values do
				local key = target .. "." .. k
				if type(v) == "number" then
					out[key] = v
				else
					out[key .. ".R"] = v.R
					out[key .. ".G"] = v.G
					out[key .. ".B"] = v.B
				end
			end
		end
		return out
	end

	-- The spread of each field across the four presets, to size the allowed step.
	local spread: { [string]: number } = {}
	do
		local lo, hi = {}, {}
		for _, p in LookPresets.PRESETS do
			for k, v in flat(p.look) do
				lo[k] = math.min(lo[k] or v, v)
				hi[k] = math.max(hi[k] or v, v)
			end
		end
		for k, v in lo do
			spread[k] = hi[k] - v
		end
	end

	t.test("each preset is exact at its own hour", function()
		for _, p in LookPresets.PRESETS do
			local want, got = flat(p.look), flat(LookPresets.at(p.hour))
			for k, v in want do
				t.ok(math.abs(got[k] - v) < 1e-9, p.id .. " " .. k)
			end
			t.ok(math.abs(LookPresets.weights(p.hour)[p.id] - 1) < 1e-9, p.id .. " weight")
		end
	end)

	t.test("the blend is continuous all round the clock, midnight included", function()
		local STEP = 0.01 -- game hours (0.4 real seconds)
		local prev = flat(LookPresets.at(-STEP))
		local worst, worstAt = 0, ""
		for i = 0, math.floor(24 / STEP) + 1 do
			local clock = i * STEP
			local now = flat(LookPresets.at(clock))
			for k, v in now do
				-- The shortest blend lasts 0.75 h and smoothstep's steepest slope is 1.5x, so one
				-- step moves at most 2 percent of a field's spread; allow 3.
				local limit = 0.03 * spread[k] + 1e-9
				local d = math.abs(v - prev[k])
				if d / (spread[k] + 1e-9) > worst then
					worst, worstAt = d / (spread[k] + 1e-9), string.format("%s at %.2f", k, clock)
				end
				t.ok(d <= limit, string.format("%s jumps %.4f at %.2f", k, d, clock))
			end
			prev = now
		end
		t.ok(worst > 0, "the look changes at all (" .. worstAt .. ")")
		-- Same values either side of midnight and for clocks past 24.
		local a, b = flat(LookPresets.at(23.999)), flat(LookPresets.at(0))
		for k, v in a do
			t.ok(math.abs(v - b[k]) < 0.01 * spread[k] + 1e-6, "midnight " .. k)
		end
		local c, d = flat(LookPresets.at(13)), flat(LookPresets.at(37))
		for k, v in c do
			t.ok(v == d[k], "wraps " .. k)
		end
	end)

	t.test("weights sum to one and only neighbours mix", function()
		for clock = 0, 24, 0.05 do
			local sum, mixing = 0, 0
			for _, w in LookPresets.weights(clock) do
				t.ok(w >= 0 and w <= 1, "weight in range at " .. clock)
				sum += w
				if w > 0 then
					mixing += 1
				end
			end
			t.ok(math.abs(sum - 1) < 1e-9, "sum at " .. clock)
			t.ok(mixing >= 1 and mixing <= 2, "two at most at " .. clock)
		end
		t.ok(LookPresets.night(2) == 1, "2 AM is full night, not half dawn")
		t.ok(LookPresets.night(12) == 0, "no night at noon")
		local fixed = { [6.6] = "dawn", [12] = "day", [17.4] = "golden", [18.7] = "dusk", [22] = "night" } -- tools/shots/shots.json (golden shots at 17.4 since L5a)
		for clock, id in fixed do
			t.ok(LookPresets.weights(clock)[id] == 1, "shot clock " .. clock .. " is pure " .. id)
		end
	end)

	t.test("values stay in Roblox's valid ranges, fog stays light, night stays readable", function()
		local RANGES = {
			["Lighting.Brightness"] = { 0, 10 },
			["Lighting.EnvironmentDiffuseScale"] = { 0, 1 },
			["Lighting.EnvironmentSpecularScale"] = { 0, 1 },
			["Lighting.ExposureCompensation"] = { -3, 3 },
			["Atmosphere.Density"] = { 0, LookPresets.MAX_DENSITY },
			["Atmosphere.Offset"] = { 0, 1 },
			["Atmosphere.Glare"] = { 0, 10 },
			["Atmosphere.Haze"] = { 0, 2 },
			["BloomEffect.Intensity"] = { 0, 1 },
			["BloomEffect.Size"] = { 0, 56 },
			["BloomEffect.Threshold"] = { 0, 4 },
			["ColorCorrectionEffect.Brightness"] = { -1, 1 },
			["ColorCorrectionEffect.Contrast"] = { -1, 1 },
			["ColorCorrectionEffect.Saturation"] = { -1, 1 },
			["SunRaysEffect.Intensity"] = { 0, 1 },
			["SunRaysEffect.Spread"] = { 0, 1 },
		}
		t.ok(LookPresets.MAX_DENSITY <= 0.45, "density cap within the review's 0.45")
		for clock = 0, 24, 0.25 do
			local look = LookPresets.at(clock)
			for target in look do
				t.ok(target == "Lighting" or LookPresets.EFFECTS[target] ~= nil, "known target " .. target)
			end
			for k, v in flat(look) do
				local r = RANGES[k]
				if r then
					t.ok(v >= r[1] and v <= r[2], string.format("%s = %.3f at %.2f", k, v, clock))
				elseif k:sub(-2, -2) == "." then -- a colour channel
					t.ok(v >= 0 and v <= 1, k .. " channel at " .. clock)
				else
					t.ok(false, "no range checked for " .. k)
				end
			end
			local oa = look.Lighting.OutdoorAmbient
			t.ok((oa.R + oa.G + oa.B) / 3 > 0.3, "never pitch black at " .. clock)
		end
	end)

	t.test("apply creates each effect once and adopts one the place already has", function()
		-- A fake Lighting: children are whatever has Parent == it.
		local all = {}
		local lighting = { ClassName = "Lighting", Name = "Lighting" }
		local made = 0
		local function children()
			local out = {}
			for _, i in all do
				if i.Parent == lighting then
					table.insert(out, i)
				end
			end
			return out
		end
		function lighting:FindFirstChild(name)
			for _, c in children() do
				if c.Name == name then
					return c
				end
			end
			return nil
		end
		function lighting:FindFirstChildOfClass(className)
			for _, c in children() do
				if c.ClassName == className then
					return c
				end
			end
			return nil
		end
		local function make(className)
			made += 1
			local i = { ClassName = className, Name = className }
			table.insert(all, i)
			return i
		end
		-- The place already has an Atmosphere (Roblox's default places do).
		local old = make("Atmosphere")
		old.Parent = lighting
		made = 0

		LookPresets.applyTo(lighting, 6.6, make)
		LookPresets.applyTo(lighting, 18.4, make)
		LookPresets.applyTo(lighting, 22, make)
		t.eq(made, 3, "Bloom, ColorCorrection and SunRays made once each")
		t.eq(#children(), 4, "four effects under Lighting")
		for className, name in LookPresets.EFFECTS do
			local e = lighting:FindFirstChild(name)
			t.ok(e ~= nil and e.ClassName == className, name)
		end
		t.ok(old.Name == "LookAtmosphere", "the place's Atmosphere was adopted, not doubled")
		t.eq(old.Density, LookPresets.byId.night.look.Atmosphere.Density, "last apply wins")
		t.eq(lighting.Brightness, LookPresets.byId.night.look.Lighting.Brightness, "Lighting itself set")
		t.ok(lighting.Technology == nil, "Technology untouched")
	end)
	-- Weather layer (L6a) ------------------------------------------------------------------

	local Weather = require(Shared.Weather)
	local CLOCKS = { 0, 2, 5, 6, 6.6, 8.2, 12, 16, 17.5, 18.4, 19.5, 22 }

	local function same(a, b, what)
		local fa, fb = flat(a), flat(b)
		for k, v in fa do
			t.ok(fb[k] == v, what .. " " .. k)
		end
		for k in fb do
			t.ok(fa[k] ~= nil, what .. " extra " .. k)
		end
	end

	t.test("every weather kind has a layer, and Clear is the identity", function()
		for _, k in Weather.list do
			t.ok(LookPresets.WEATHER[k.id] ~= nil, "layer for " .. k.id)
		end
		for _, c in CLOCKS do
			local old = LookPresets.at(c)
			same(old, LookPresets.at(c, nil), "nil at " .. c)
			same(old, LookPresets.at(c, "Clear"), "Clear at " .. c)
			same(old, LookPresets.at(c, "Clear", 0.5), "half Clear at " .. c)
			same(old, LookPresets.at(c, "NoSuchKind"), "unknown kind at " .. c)
			same(old, LookPresets.at(c, "Storm", 0), "Storm at amount 0 at " .. c)
			same(LookPresets.at(c, "Storm"), LookPresets.at(c, "Storm", 1), "Storm amount 1 at " .. c)
			same(LookPresets.at(c, "Fog"), LookPresets.at(c, "Storm", 0, "Fog"), "from Fog at 0 at " .. c)
		end
		local cl = LookPresets.clouds(nil)
		t.eq(cl.Cover, 0.5, "clear cover")
		t.eq(cl.Density, 0.5, "clear cloud density")
		t.ok(cl.Color == Color3.fromRGB(255, 255, 255), "clear clouds white")
	end)

	t.test("every weather keeps fog under the cap and values in range at every clock", function()
		t.ok(LookPresets.MAX_DENSITY <= 0.45, "density cap")
		for id in LookPresets.WEATHER do
			for clock = 0, 24, 0.25 do
				for _, amount in { 0.3, 1 } do
					local look = LookPresets.at(clock, id, amount)
					local a = look.Atmosphere
					local where = string.format("%s %.1f at %.2f", id, amount, clock)
					t.ok(a.Density >= 0 and a.Density <= LookPresets.MAX_DENSITY, "density " .. where)
					t.ok(a.Haze >= 0 and a.Haze <= LookPresets.MAX_HAZE, "haze " .. where)
					t.ok(look.Lighting.Brightness >= 0 and look.Lighting.Brightness <= 10, "brightness " .. where)
					t.ok(math.abs(look.ColorCorrectionEffect.Saturation) <= 1, "saturation " .. where)
					t.ok(math.abs(look.ColorCorrectionEffect.Brightness) <= 1, "cc brightness " .. where)
					local r = look.SunRaysEffect.Intensity
					t.ok(r >= 0 and r <= 1, "sun rays " .. where)
					for k, v in flat(look) do
						if k:sub(-2, -2) == "." then
							t.ok(v >= 0 and v <= 1, k .. " " .. where)
						end
					end
				end
			end
			local c = LookPresets.clouds(id)
			t.ok(c.Cover >= 0 and c.Cover <= 1 and c.Density >= 0 and c.Density <= 1, "clouds " .. id)
		end
		-- Fog and storm put out the sun rays; fog really is foggier than clear.
		t.eq(LookPresets.at(12, "Fog").SunRaysEffect.Intensity, 0, "no rays in fog")
		t.eq(LookPresets.at(17.5, "Storm").SunRaysEffect.Intensity, 0, "no rays in a storm")
		t.ok(LookPresets.at(12, "Fog").Atmosphere.Haze > LookPresets.at(12).Atmosphere.Haze + 1, "fog is hazy")
		t.ok(LookPresets.at(12, "Storm").Lighting.Brightness < LookPresets.at(12).Lighting.Brightness, "storm is darker")
		t.ok(LookPresets.at(12, "ColdFront").ColorCorrectionEffect.Saturation > LookPresets.at(12).ColorCorrectionEffect.Saturation, "cold front is crisper")
	end)

	t.test("a storm night stays readable", function()
		-- Floors: night's own Brightness is 1.2 and its OutdoorAmbient averages 0.46. The worst
		-- weather may take Brightness to 0.7 (about 60 percent; night's +0.8 exposure stays) and
		-- the ambient to 0.38: above the 0.3 "never pitch black" line the clear presets keep,
		-- with margin, so the dock, the water edge and the bobber still read.
		for id in LookPresets.WEATHER do
			for clock = 19, 29, 0.25 do
				local look = LookPresets.at(clock, id)
				local oa = look.Lighting.OutdoorAmbient
				local where = string.format("%s at %.2f", id, clock % 24)
				t.ok(look.Lighting.Brightness >= 0.7, string.format("brightness %.2f %s", look.Lighting.Brightness, where))
				t.ok((oa.R + oa.G + oa.B) / 3 >= 0.38, "outdoor ambient " .. where)
				t.ok(look.ColorCorrectionEffect.Brightness >= -0.05, "colour brightness " .. where)
			end
		end
	end)

	t.test("weather blends smoothly between kinds", function()
		local STEP = 0.02
		for _, pair in { { "Clear", "Storm" }, { "Overcast", "Storm" }, { "Fog", "ColdFront" } } do
			-- No step of the blend moves a field more than twice its even share of the whole change,
			-- plus a little for colours that swing toward grey and back (shade times grey).
			local first = flat(LookPresets.at(12, pair[2], 0, pair[1]))
			local last = flat(LookPresets.at(12, pair[2], 1, pair[1]))
			local prev = first
			for i = 1, 1 / STEP do
				local now = flat(LookPresets.at(12, pair[2], i * STEP, pair[1]))
				for k, v in now do
					local limit = 2 * (math.abs(last[k] - first[k]) + 0.05) * STEP
					t.ok(math.abs(v - prev[k]) <= limit, string.format("%s to %s %s step %d", pair[1], pair[2], k, i))
				end
				prev = now
			end
		end
	end)

	t.test("applyTo sets the clouds only when a weather is given", function()
		local lighting = {}
		function lighting:FindFirstChild()
			return nil
		end
		function lighting:FindFirstChildOfClass()
			return nil
		end
		local function make(className)
			return { ClassName = className }
		end
		local clouds = { Cover = 0.5, Density = 0.5 }
		LookPresets.applyTo(lighting, 12, make, nil, nil, nil, clouds)
		t.eq(clouds.Cover, 0.5, "no weather leaves the clouds alone")
		LookPresets.applyTo(lighting, 12, make, "Storm", 1, nil, clouds)
		t.eq(clouds.Cover, LookPresets.WEATHER.Storm.cover, "storm cover")
		t.ok(clouds.Color == LookPresets.WEATHER.Storm.cloudColor, "storm cloud colour")
		t.eq(lighting.Brightness, LookPresets.at(12, "Storm").Lighting.Brightness, "storm light written")
		LookPresets.applyTo(lighting, 12, make, "Storm", 1, nil, nil) -- no Clouds object: no error
	end)

	-- LookDirector (N0): blend sharing, areas, tiers ----------------------------------------

	t.test("stepBlend eases one kind into the next over 20 s, as DayNight did", function()
		local b = { from = "Clear", to = "Clear", amount = 1 }
		LookPresets.stepBlend(b, "Storm", 0.25)
		t.eq(b.from, "Clear", "from")
		t.eq(b.to, "Storm", "to")
		t.ok(math.abs(b.amount - 0.25 / 20) < 1e-12, "first step")
		for _ = 1, 100 do
			LookPresets.stepBlend(b, "Storm", 0.25)
		end
		t.eq(b.amount, 1, "done after 20 s")
		LookPresets.stepBlend(b, "Fog", 1)
		t.eq(b.from, "Storm", "a finished blend starts from what it shows")
		LookPresets.stepBlend(b, "Clear", 1)
		t.eq(b.from, "Storm", "a change early in a blend starts from the old kind")
		t.eq(LookPresets.smooth(0.5), 0.5, "smoothstep middle")
	end)

	local function sum(w)
		local s = 0
		for _, v in w do
			t.ok(v >= -1e-12 and v <= 1 + 1e-12, "weight in range")
			s += v
		end
		return s
	end

	t.test("area weights sum to one everywhere, home is the fallback", function()
		for x = -600, 600, 10 do
			for z = -1250, 300, 10 do
				local w = LookPresets.areaWeights(Vector3.new(x, 0, z))
				t.ok(math.abs(sum(w) - 1) < 1e-9, string.format("sum at %d, %d", x, z))
			end
		end
		for _, p in { Vector3.new(0, 0, 0), Vector3.new(0, 5, 600), Vector3.new(900, 0, 0), Vector3.new(0, 0, -2000) } do
			local w = LookPresets.areaWeights(p)
			t.eq(w.home, 1, "home at " .. tostring(p))
			t.eq(LookPresets.topArea(w), "home", "top home at " .. tostring(p))
		end
		local centres = { creek = Vector3.new(-230, 0, 0), basin = Vector3.new(0, 0, -220), bluewater = Vector3.new(0, 0, -600), island = Vector3.new(100, 0, -950) }
		for id, p in centres do
			local w = LookPresets.areaWeights(p)
			t.ok(math.abs(w[id] - 1) < 1e-9, id .. " is pure in its middle")
			t.eq(LookPresets.topArea(w), id, "top " .. id)
		end
		-- The basin and blue water meet at the buoy line with no home showing between them.
		local seam = LookPresets.areaWeights(Vector3.new(0, 0, -290))
		t.ok(seam.home < 1e-9, "no home at the buoy line")
		t.ok(math.abs(seam.basin - 0.5) < 1e-9 and math.abs(seam.bluewater - 0.5) < 1e-9, "half and half at the buoy line")
	end)

	t.test("the zones agree with the boat map", function()
		local BoatRules = require(Shared.BoatRules)
		local byId = {}
		for _, zn in LookPresets.ZONES do
			byId[zn.id] = zn
			t.ok(LookPresets.AREAS[zn.id] ~= nil, "area for zone " .. zn.id)
		end
		t.eq(byId.basin.z1, BoatRules.BUOY_Z, "basin ends at the buoy line")
		t.eq(byId.bluewater.z2, BoatRules.BUOY_Z, "blue water starts at the buoy line")
		local lake = BoatRules.BIG_LAKE
		t.eq(byId.basin.z2, lake.cframe.Position.Z + lake.size.Z / 2, "basin starts at the Big Lake's south shore")
		t.ok(byId.bluewater.z1 <= lake.cframe.Position.Z - lake.size.Z / 2, "blue water covers the Big Lake's north end")
	end)

	t.test("the 40 stud band blends smoothly", function()
		-- Blue water's east edge (x = 450), far from every other zone.
		local prev = 1
		local maxStep = 0
		for x = 420, 480, 1 do
			local w = LookPresets.areaWeights(Vector3.new(x, 0, -700)).bluewater
			t.ok(w <= prev + 1e-12, "falls steadily at x " .. x)
			maxStep = math.max(maxStep, prev - w)
			prev = w
		end
		t.ok(math.abs(LookPresets.areaWeights(Vector3.new(429, 0, -700)).bluewater - 1) < 1e-9, "full 21 studs inside")
		t.ok(math.abs(LookPresets.areaWeights(Vector3.new(450, 0, -700)).bluewater - 0.5) < 1e-9, "half on the edge")
		t.eq(LookPresets.areaWeights(Vector3.new(471, 0, -700)).home, 1, "gone 21 studs outside")
		t.ok(maxStep <= 1.5 / LookPresets.AREA_BAND + 1e-9, "no stud moves it more than smoothstep's steepest slope")
		-- The island fades the blue water out under it, with no home in between.
		local edge = LookPresets.areaWeights(Vector3.new(220, 0, -950))
		t.ok(math.abs(edge.island - 0.5) < 1e-9 and math.abs(edge.bluewater - 0.5) < 1e-9 and edge.home < 1e-9, "island edge")
	end)

	t.test("home areas leave the look exactly as it was", function()
		for _, c in CLOCKS do
			for _, w in { "Clear", "Storm", "Fog" } do
				local look = LookPresets.at(c, w, 0.6, "Overcast")
				same(look, LookPresets.blendAreas(look, { home = 1 }), "home at " .. c .. " " .. w)
				same(look, LookPresets.blendAreas(look, LookPresets.areaWeights(Vector3.new(0, 0, 0))), "lake at " .. c .. " " .. w)
			end
		end
		local h = LookPresets.areaWater({ home = 1 })
		t.ok(h.WaterColor == Color3.fromRGB(26, 66, 62), "home water colour (WaterLook.TERRAIN)")
		t.eq(h.WaterTransparency, 0.55, "home water transparency")
		t.eq(h.WaterWaveSize, 0.12, "home waves")
		-- applyTo with home areas writes what it wrote before.
		local function fake()
			local l = {}
			function l:FindFirstChild()
				return nil
			end
			function l:FindFirstChildOfClass()
				return nil
			end
			return l
		end
		local made = {}
		local function make(className)
			local i = { ClassName = className }
			made[className] = i
			return i
		end
		local a = fake()
		LookPresets.applyTo(a, 17.5, make, "Overcast", 0.4, "Clear", nil, { home = 1 })
		t.eq(a.Brightness, LookPresets.at(17.5, "Overcast", 0.4, "Clear").Lighting.Brightness, "home write")
	end)

	t.test("other areas change the look but keep it in range", function()
		for id in LookPresets.AREAS do
			for _, c in CLOCKS do
				local look = LookPresets.blendAreas(LookPresets.at(c, "Storm"), { [id] = 1 })
				local a = look.Atmosphere
				t.ok(a.Density >= 0 and a.Density <= LookPresets.MAX_DENSITY, id .. " density at " .. c)
				t.ok(a.Haze >= 0 and a.Haze <= LookPresets.MAX_HAZE, id .. " haze at " .. c)
				for k, v in flat(look) do
					if k:sub(-2, -2) == "." then
						t.ok(v >= 0 and v <= 1, id .. " " .. k .. " at " .. c)
					end
				end
			end
			local wtr = LookPresets.AREAS[id].water
			t.ok(wtr.WaterTransparency >= 0 and wtr.WaterTransparency <= 1, id .. " water transparency")
			t.ok(wtr.WaterReflectance >= 0 and wtr.WaterReflectance <= 1, id .. " water reflectance")
		end
		t.ok(LookPresets.blendAreas(LookPresets.at(12), { bluewater = 1 }).Atmosphere.Haze > LookPresets.at(12).Atmosphere.Haze, "blue water is hazier")
		t.eq(LookPresets.AREAS.bluewater.water.WaterWaveSize, 2 * LookPresets.AREAS.home.water.WaterWaveSize, "blue water swell is doubled")
		-- A half-and-half blend sits between the two.
		local half = LookPresets.areaWater({ home = 0.5, creek = 0.5 })
		t.ok(math.abs(half.WaterTransparency - (0.55 + 0.8) / 2) < 1e-9, "water blends")
	end)

	t.test("tiers: desktop and phone, and phone has no sun rays", function()
		local d, p = LookPresets.TIERS.desktop, LookPresets.TIERS.phone
		t.ok(d ~= nil and p ~= nil, "both tiers")
		t.eq(d.lightingStyle, "Realistic", "desktop style")
		t.eq(p.lightingStyle, "Soft", "phone style")
		t.eq(p.sunRays, false, "no sun rays on phone")
		t.eq(p.depthOfField, false, "no depth of field on phone")
		t.eq(p.bloom, true, "phone keeps bloom")
		t.eq(p.shadows, "sun", "phone: sun shadows only")
		t.ok(d.sunRays and d.bloom and d.depthOfField, "desktop extras on")
	end)
end
