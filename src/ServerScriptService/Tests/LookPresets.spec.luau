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
end
