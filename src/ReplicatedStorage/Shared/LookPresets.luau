--!strict
-- The lake's light through the day (L5a, Real-ish): misty dawn, bright summer day, golden
-- afternoon, moonlit night (docs/DECISIONS.md, mockups in docs/looks/realish/). Each preset
-- holds over a stretch of the clock and blends smoothly into the next one, round midnight too.
--
-- Weather (L6a) is a layer on top: WEATHER holds one per kind, and at/apply take an
-- optional kind id plus a blend amount (DayNight eases weather changes in over 20 s).
--
-- Pure data plus two functions: at(clock) returns the blended values, apply(clock) writes
-- them to Lighting and its effects (Atmosphere, Bloom, ColorCorrection, SunRays), creating
-- each effect once under a fixed name. The server calls apply as the clock runs (DayNight);
-- Lighting replicates, so every player sees the same look. Lighting.Technology is never set.
-- N0: with Config.LOOK_DIRECTOR_ON the server stops and each client writes the look locally
-- instead (ClientModules/LookDirector), adding AREAS (blended by camera position) and TIERS.
--
-- Fog: Atmosphere density stays at or under MAX_DENSITY (0.42) with small haze, so the
-- bobber stays readable at the longest cast (about 68 studs). Lighting.Fog* is ignored by
-- Roblox while an Atmosphere exists, so it is not used.
local LookPresets = {}

export type Values = { [string]: number | Color3 }
-- Keyed by target: "Lighting" or an effect's class name.
export type Look = { [string]: Values }
export type Preset = { id: string, hour: number, from: number, to: number, look: Look }

LookPresets.MAX_DENSITY = 0.42

local rgb = Color3.fromRGB

-- The effects apply() keeps under Lighting, by class, and the name each one gets.
LookPresets.EFFECTS = {
	Atmosphere = "LookAtmosphere",
	BloomEffect = "LookBloom",
	ColorCorrectionEffect = "LookColor",
	SunRaysEffect = "LookSunRays",
}

-- In clock order. hour is the preset's own moment; it holds unchanged from `from` to `to`
-- and blends into its neighbours outside that window. Night wraps past midnight.
LookPresets.PRESETS = {
	{
		id = "dawn",
		hour = 6,
		from = 5.5,
		to = 7.0,
		look = {
			-- Cool rose low sun, lavender mist lying on the water. 11/27/2026: cooler than it was
			-- (the critic could not tell dawn from golden hour); golden owns the warm amber.
			Lighting = {
				Ambient = rgb(68, 64, 80),
				OutdoorAmbient = rgb(132, 128, 142),
				Brightness = 1.8,
				ColorShift_Top = rgb(255, 212, 206),
				ColorShift_Bottom = rgb(92, 90, 110),
				EnvironmentDiffuseScale = 0.6,
				EnvironmentSpecularScale = 0.7,
				ExposureCompensation = 0.15,
			},
			Atmosphere = {
				Density = 0.4,
				Offset = 0.12,
				Color = rgb(214, 206, 228),
				Decay = rgb(178, 160, 190),
				Glare = 1,
				Haze = 2,
			},
			BloomEffect = { Intensity = 0.6, Size = 28, Threshold = 1.6 },
			ColorCorrectionEffect = { Brightness = 0.03, Contrast = 0.04, Saturation = -0.06, TintColor = rgb(238, 240, 255) },
			SunRaysEffect = { Intensity = 0.12, Spread = 0.8 },
		},
	},
	{
		id = "day",
		hour = 12,
		from = 9.5,
		to = 15.5,
		look = {
			-- Crisp, saturated, clean; clear air.
			Lighting = {
				Ambient = rgb(78, 84, 96),
				OutdoorAmbient = rgb(132, 136, 146),
				Brightness = 3,
				ColorShift_Top = rgb(255, 248, 232),
				ColorShift_Bottom = rgb(40, 46, 56),
				-- 11/27/2026: the place's skybox is a warm one, and at full scale it tinted the
				-- far trees red-brown and put orange blotches on the noon water (critic, three runs).
				EnvironmentDiffuseScale = 0.45,
				EnvironmentSpecularScale = 0.25,
				ExposureCompensation = 0,
			},
			Atmosphere = {
				Density = 0.26,
				Offset = 0.25,
				Color = rgb(200, 216, 236),
				Decay = rgb(106, 128, 162),
				Glare = 0,
				Haze = 0,
			},
			BloomEffect = { Intensity = 0.35, Size = 24, Threshold = 2 },
			ColorCorrectionEffect = { Brightness = 0, Contrast = 0.1, Saturation = 0.15, TintColor = rgb(255, 255, 255) },
			SunRaysEffect = { Intensity = 0.05, Spread = 0.5 },
		},
	},
	{
		id = "golden",
		hour = 17.5,
		from = 16.75,
		to = 17.9, -- was 18.6, past sunset (see dusk)
		look = {
			-- Warm low sun, long shadows, glints on the water.
			Lighting = {
				Ambient = rgb(86, 66, 52),
				OutdoorAmbient = rgb(152, 116, 86),
				Brightness = 2.6,
				ColorShift_Top = rgb(255, 182, 104),
				ColorShift_Bottom = rgb(92, 62, 42),
				EnvironmentDiffuseScale = 0.8,
				EnvironmentSpecularScale = 1,
				ExposureCompensation = 0,
			},
			Atmosphere = {
				Density = 0.32,
				Offset = 0.15,
				Color = rgb(240, 212, 164),
				Decay = rgb(182, 122, 82),
				Glare = 2.5,
				Haze = 1.2,
			},
			BloomEffect = { Intensity = 0.8, Size = 32, Threshold = 1.4 },
			ColorCorrectionEffect = { Brightness = 0.02, Contrast = 0.12, Saturation = 0.14, TintColor = rgb(255, 226, 192) },
			SunRaysEffect = { Intensity = 0.2, Spread = 0.9 },
		},
	},
	{
		-- Blue hour (added 11/27/2026): the sun is down (Roblox sets it at 18.0), the sky goes
		-- violet and the land dims with it. Golden used to hold to 18.6, so its warm haze sat over
		-- a sunless sky and the dusk read as olive-brown murk.
		id = "dusk",
		hour = 18.7,
		from = 18.45,
		to = 19.0,
		look = {
			Lighting = {
				-- N4 review 1 (11/28/2026): dusk was the darkest hour (net exposure 0.15 under the
				-- grade against night's 0.8, a 0.6 mirror and 0.8 specular), so it is lifted:
				-- exposure 0.3 to 0.9, OutdoorAmbient 112,106,140 to 136,128,170, Ambient 54,50,72
				-- to 72,68,98, specular 0.8 to 0.3 (with WATER_BY_TIME.dusk below).
				Ambient = rgb(72, 68, 98),
				OutdoorAmbient = rgb(136, 128, 170),
				Brightness = 1.85, -- a storm at dusk must still clear the readable-night floor (spec)
				ColorShift_Top = rgb(255, 176, 196),
				ColorShift_Bottom = rgb(48, 44, 78),
				EnvironmentDiffuseScale = 0.55,
				EnvironmentSpecularScale = 0.3,
				ExposureCompensation = 0.9,
			},
			Atmosphere = {
				Density = 0.32,
				Offset = 0.12,
				Color = rgb(156, 128, 170),
				Decay = rgb(64, 56, 108),
				Glare = 0.4,
				Haze = 0.9,
			},
			BloomEffect = { Intensity = 0.8, Size = 30, Threshold = 1.3 },
			ColorCorrectionEffect = { Brightness = 0.02, Contrast = 0.08, Saturation = -0.04, TintColor = rgb(238, 228, 255) },
			SunRaysEffect = { Intensity = 0, Spread = 0.5 },
		},
	},
	{
		id = "night",
		hour = 22,
		from = 20.5,
		to = 4.75, -- wraps past midnight
		look = {
			-- Cool blue moonlight; dark but always readable, lamps and the bobber glow.
			Lighting = {
				Ambient = rgb(56, 64, 88),
				OutdoorAmbient = rgb(92, 108, 152), -- lifted 11/26 (critic: the creek pool read as black mud)
				Brightness = 1.2,
				ColorShift_Top = rgb(150, 176, 230),
				ColorShift_Bottom = rgb(30, 40, 72),
				EnvironmentDiffuseScale = 0.4,
				EnvironmentSpecularScale = 0.6,
				ExposureCompensation = 0.8,
			},
			Atmosphere = {
				Density = 0.36,
				Offset = 0.1,
				-- 11/27: first darkened (the pale blue haze lit the far hills), then a moonlit navy
				-- haze so the sky's horizon isn't black either: the critics kept naming the hills
				-- glowing against a pitch-black sky.
				Color = rgb(40, 52, 86),
				Decay = rgb(28, 36, 66),
				Glare = 0,
				Haze = 1.1,
			},
			BloomEffect = { Intensity = 0.9, Size = 30, Threshold = 1.2 },
			ColorCorrectionEffect = { Brightness = 0.04, Contrast = 0.08, Saturation = -0.12, TintColor = rgb(212, 226, 255) },
			SunRaysEffect = { Intensity = 0, Spread = 0.5 },
		},
	},
} :: { Preset }

LookPresets.byId = {} :: { [string]: Preset }
for _, p in LookPresets.PRESETS do
	LookPresets.byId[p.id] = p
end

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function within(c: number, from: number, to: number): boolean
	return (c - from) % 24 <= (to - from) % 24
end

-- The preset this clock is in, or the two it is between and how far (0..1, eased) towards the second.
local function pair(clock: number): (Preset, Preset?, number)
	local c = clock % 24
	local list = LookPresets.PRESETS
	for i, p in list do
		if within(c, p.from, p.to) then
			return p, nil, 0
		end
		local nextP = list[i % #list + 1]
		if within(c, p.to, nextP.from) then
			local span = (nextP.from - p.to) % 24
			return p, nextP, smooth(((c - p.to) % 24) / span)
		end
	end
	return list[1], nil, 0 -- unreachable while the windows cover the clock
end

-- How much each preset counts at this clock (0..1, summing to 1). At most two are non-zero.
function LookPresets.weights(clock: number): { [string]: number }
	local out: { [string]: number } = {}
	for _, p in LookPresets.PRESETS do
		out[p.id] = 0
	end
	local a, b, t = pair(clock)
	out[a.id] = 1 - t
	if b then
		out[b.id] = t
	end
	return out
end

local function mix(a: number | Color3, b: number | Color3, t: number): number | Color3
	if type(a) == "number" and type(b) == "number" then
		return a + (b - a) * t
	end
	local ca, cb = a :: Color3, b :: Color3
	return Color3.new(ca.R + (cb.R - ca.R) * t, ca.G + (cb.G - ca.G) * t, ca.B + (cb.B - ca.B) * t)
end

-- The blended time-of-day look at this clock, before weather (a fresh table each call).
local function base(clock: number): Look
	local a, b, t = pair(clock)
	local out: Look = {}
	for target, values in a.look do
		local blended: Values = {}
		local other = if b then b.look[target] else nil
		for k, v in values do
			blended[k] = if other then mix(v, other[k], t) else v
		end
		out[target] = blended
	end
	return out
end

-- Weather (L6a): a layer on top of the time-of-day look, one per kind in Shared/Weather.
-- Each field modifies the blended look: density and haze are added (then capped), the
-- Atmosphere colours are pulled toward a grey of their own brightness (times shade, so a
-- storm night gets darker, never lighter), Lighting.Brightness and both ambients are
-- multiplied, ColorCorrection saturation and brightness are added, SunRays intensity is
-- multiplied. cover, cloudDensity and cloudColor are set on Terrain's Clouds outright.
-- Clear is the identity. Storm keeps night readable: ambient only drops 15 percent and
-- Brightness 40 percent, and night's own exposure lift stays.
export type Layer = {
	density: number,
	haze: number,
	grey: number,
	shade: number,
	brightness: number,
	ambient: number,
	saturation: number,
	ccBrightness: number,
	sunRays: number,
	cover: number,
	cloudDensity: number,
	cloudColor: Color3,
	dayDim: number, -- extra Brightness multiplier, by day only (night keeps its floor)
}

LookPresets.MAX_HAZE = 3 -- Roblox allows 10; past 3 the far shore vanishes

-- stylua: ignore
LookPresets.WEATHER = {
	Clear =     { density = 0,     haze = 0,    grey = 0,    shade = 1,    brightness = 1,    ambient = 1,    saturation = 0,     ccBrightness = 0,     sunRays = 1,   cover = 0.5,  cloudDensity = 0.5,  cloudColor = rgb(255, 255, 255), dayDim = 1 },
	Overcast =  { density = 0.06,  haze = 0.8,  grey = 0.5,  shade = 1,    brightness = 0.7,  ambient = 0.95, saturation = -0.12, ccBrightness = -0.02, sunRays = 0.2, cover = 0.9,  cloudDensity = 0.6,  cloudColor = rgb(205, 208, 214), dayDim = 0.9 },
	Fog =       { density = 0.14,  haze = 1.8,  grey = 0.7,  shade = 1.05, brightness = 0.8,  ambient = 1,    saturation = -0.2,  ccBrightness = 0.02,  sunRays = 0,   cover = 0.75, cloudDensity = 0.4,  cloudColor = rgb(230, 230, 232), dayDim = 1 },
	Wind =      { density = 0,     haze = 0.2,  grey = 0.1,  shade = 1,    brightness = 1,    ambient = 1,    saturation = 0,     ccBrightness = 0,     sunRays = 1,   cover = 0.6,  cloudDensity = 0.45, cloudColor = rgb(245, 245, 248), dayDim = 1 },
	PreStorm =  { density = 0.06,  haze = 0.8,  grey = 0.4,  shade = 0.9,  brightness = 0.75, ambient = 0.92, saturation = -0.08, ccBrightness = -0.03, sunRays = 0.4, cover = 0.85, cloudDensity = 0.75, cloudColor = rgb(150, 152, 162), dayDim = 0.85 },
	Storm =     { density = 0.1,   haze = 1.4,  grey = 0.65, shade = 0.75, brightness = 0.6,  ambient = 0.85, saturation = -0.35, ccBrightness = -0.05, sunRays = 0,   cover = 1,    cloudDensity = 0.9,  cloudColor = rgb(96, 98, 108), dayDim = 0.65 },
	ColdFront = { density = -0.06, haze = -0.3, grey = 0,    shade = 1,    brightness = 1.1,  ambient = 1,    saturation = 0.08,  ccBrightness = 0.02,  sunRays = 1.2, cover = 0.25, cloudDensity = 0.35, cloudColor = rgb(255, 255, 255), dayDim = 1 },
} :: { [string]: Layer }

-- The layer for a kind id (nil or unknown means Clear).
local function layerOf(weather: string?): Layer
	return (if weather then LookPresets.WEATHER[weather] else nil) or LookPresets.WEATHER.Clear
end

-- The layer `amount` (0..1, default 1) of the way from kind `from` (default Clear) to `weather`.
function LookPresets.layer(weather: string?, amount: number?, from: string?): Layer
	local a, b = layerOf(from), layerOf(weather)
	local t = math.clamp(if amount == nil then 1 else amount, 0, 1)
	if t == 1 then
		return b
	elseif t == 0 then
		return a
	end
	local out = {} :: any
	for k, v in a :: any do
		out[k] = mix(v, (b :: any)[k], t)
	end
	return out :: Layer
end

local function isClear(l: Layer): boolean
	local c = LookPresets.WEATHER.Clear :: any
	for k, v in l :: any do
		if c[k] ~= v then
			return false
		end
	end
	return true
end

local function toward(c: Color3, grey: number, shade: number): Color3
	local lum = math.clamp((0.299 * c.R + 0.587 * c.G + 0.114 * c.B) * shade, 0, 1)
	return mix(c, Color3.new(lum, lum, lum), grey) :: Color3
end

local function scale(c: Color3, f: number): Color3
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end

-- The Realistic grade (N1): the presets were tuned under Lighting.LightingStyle Soft, and
-- Realistic overdrives them (golden-hour sky near white, the noon lawn too bright and yellow).
-- These are offsets ADDED to each preset's own values, only on the desktop tier with
-- Config.REALISTIC_DESKTOP (TIERS.desktop.grade, gradeFor); the phone tier and Soft never see
-- them. Between presets the offsets blend with the same weights the presets do, so every
-- clock gets a grade. Numbers only, keyed like a preset's look. Tune here, one table.
-- 11/27/2026 starting points (advisor, golden hour and noon measured under Realistic):
--   golden: exposure 0 to -0.3, glare 2.5 to 0.8, haze 1.2 to 0.7, bloom 0.8 to 0.4 with
--           threshold 1.4 to 1.9, sun rays 0.2 to 0.08 (mid-sky red under 235, treeline visible)
--   day:    exposure 0 to -0.35, saturation 0.15 to 0.02, haze 0 to 0.5 (lawn near 115,135,65)
--   dawn, dusk: the same direction, gentler; dawn's mist (haze 2) is kept.
--   night:  bloom only (lamps flare under Realistic); exposure and ambients untouched, so the
--           night stays moonlit navy, never black.
-- 11/27/2026 N1 review 1 (fable-advisor): golden glare -2.2 (net 0.3), haze -0.8 (net 0.4),
--   sun rays -0.17 (net 0.03); day haze +1.5 (net 1.5) and Ambient 96,104,112 (canopies read
--   black at noon); night lifted to OutdoorAmbient 112,128,176, Ambient 66,76,104 and a navy
--   haze 54,68,112 (still moonlit navy, brighter, never black).
-- 11/27/2026 N1 review 2 (fable-advisor): night EnvironmentSpecularScale -0.4 (net 0.2, with
--   the night water below: the tan band across the night water read as a reflection
--   fallback); golden exposure -0.4, Density -0.07 (net 0.25), haze colour 224,186,140 (the
--   view from height read washed); day Density +0.04 (net 0.30), saturation -0.2 (net -0.05),
--   haze colour 212,220,228 (noon read yellow-green and flat).
-- A number is an offset added to the preset's value; a Color3 is the colour that preset takes
-- under the grade (it blends with the preset weights like everything else; see applyGrade).
export type Grade = { [string]: { [string]: { [string]: number | Color3 } } }

-- stylua: ignore
LookPresets.REALISTIC_GRADE = {
	dawn = {
		Lighting = { ExposureCompensation = -0.2 },
		Atmosphere = { Glare = -0.4, Haze = -0.2 },
		BloomEffect = { Intensity = -0.2, Threshold = 0.3 },
		SunRaysEffect = { Intensity = -0.04 },
	},
	day = {
		Lighting = { ExposureCompensation = -0.35, Ambient = rgb(96, 104, 112) },
		Atmosphere = { Haze = 1.5, Density = 0.04, Color = rgb(212, 220, 228) },
		ColorCorrectionEffect = { Saturation = -0.2 },
	},
	golden = {
		Lighting = { ExposureCompensation = -0.4 },
		-- Follow-up knob (N1 review 3), OFF: the advisor wants this grade seen under Clear first.
		-- To try a lighter golden haze (net Density 0.22), swap Density -0.07 for -0.10 below.
		-- Atmosphere = { Glare = -2.2, Haze = -0.8, Density = -0.10, Color = rgb(224, 186, 140) },
		Atmosphere = { Glare = -2.2, Haze = -0.8, Density = -0.07, Color = rgb(224, 186, 140) },
		BloomEffect = { Intensity = -0.4, Threshold = 0.5 },
		SunRaysEffect = { Intensity = -0.17 },
	},
	dusk = {
		Lighting = { ExposureCompensation = -0.15 },
		Atmosphere = { Glare = -0.2 },
		BloomEffect = { Intensity = -0.3, Threshold = 0.3 },
	},
	night = {
		Lighting = { OutdoorAmbient = rgb(112, 128, 176), Ambient = rgb(66, 76, 104), EnvironmentSpecularScale = -0.4 },
		Atmosphere = { Color = rgb(54, 68, 112) },
		BloomEffect = { Intensity = -0.3, Threshold = 0.2 },
	},
} :: Grade

-- The range each graded field is held to after the offset (Roblox's own limits, or tighter).
-- stylua: ignore
LookPresets.GRADE_LIMITS = {
	["Lighting.ExposureCompensation"] = { -3, 3 },
	["Lighting.Brightness"] = { 0, 10 },
	["Lighting.EnvironmentDiffuseScale"] = { 0, 1 },
	["Lighting.EnvironmentSpecularScale"] = { 0, 1 },
	["Atmosphere.Density"] = { 0, LookPresets.MAX_DENSITY },
	["Atmosphere.Offset"] = { 0, 1 },
	["Atmosphere.Glare"] = { 0, 10 },
	["Atmosphere.Haze"] = { 0, LookPresets.MAX_HAZE },
	["BloomEffect.Intensity"] = { 0, 10 },
	["BloomEffect.Size"] = { 0, 56 },
	["BloomEffect.Threshold"] = { 0, 4 },
	["ColorCorrectionEffect.Brightness"] = { -1, 1 },
	["ColorCorrectionEffect.Contrast"] = { -1, 1 },
	["ColorCorrectionEffect.Saturation"] = { -1, 1 },
	["SunRaysEffect.Intensity"] = { 0, 1 },
	["SunRaysEffect.Spread"] = { 0, 1 },
} :: { [string]: { number } }

-- The grade's numeric offsets at this clock, blended by the preset weights:
-- { [target]: { [prop]: n } }. Colour entries are left to applyGrade.
function LookPresets.gradeAt(clock: number, grade: Grade): { [string]: { [string]: number } }
	local out: { [string]: { [string]: number } } = {}
	for id, w in LookPresets.weights(clock) do
		local g = grade[id]
		if g and w > 0 then
			for target, values in g do
				for k, v in values do
					if type(v) == "number" then
						local t = out[target] or {}
						out[target] = t
						t[k] = (t[k] or 0) + v * w
					end
				end
			end
		end
	end
	return out
end

-- The grade's colour shifts at this clock: for each preset with a Color3 for a field, its
-- weight times (that colour minus the preset's own). Added to the blended look this gives
-- exactly the weighted blend of the graded colours. { [target]: { [prop]: {r, g, b} } }.
local function gradeColoursAt(clock: number, grade: Grade): { [string]: { [string]: { number } } }
	local out: { [string]: { [string]: { number } } } = {}
	for id, w in LookPresets.weights(clock) do
		local g, p = grade[id], LookPresets.byId[id]
		if g and p and w > 0 then
			for target, values in g do
				for k, v in values do
					local own = p.look[target] and p.look[target][k]
					if typeof(v) == "Color3" and typeof(own) == "Color3" then
						local c, o = v :: Color3, own :: Color3
						local t = out[target] or {}
						out[target] = t
						local d = t[k] or { 0, 0, 0 }
						t[k] = d
						d[1] += (c.R - o.R) * w
						d[2] += (c.G - o.G) * w
						d[3] += (c.B - o.B) * w
					end
				end
			end
		end
	end
	return out
end

-- Adds the grade at this clock to a look in place, each field held to GRADE_LIMITS
-- (colours to 0..1 per channel).
local function applyGrade(look: Look, clock: number, grade: Grade)
	for target, values in gradeColoursAt(clock, grade) do
		local inst = look[target]
		if inst then
			for k, d in values do
				local v = inst[k]
				if typeof(v) == "Color3" then
					local c = v :: Color3
					inst[k] = Color3.new(math.clamp(c.R + d[1], 0, 1), math.clamp(c.G + d[2], 0, 1), math.clamp(c.B + d[3], 0, 1))
				end
			end
		end
	end
	for target, values in LookPresets.gradeAt(clock, grade) do
		local inst = look[target]
		if inst then
			for k, d in values do
				local v = inst[k]
				if type(v) == "number" then
					local lim = LookPresets.GRADE_LIMITS[target .. "." .. k]
					local nv = v + d
					inst[k] = if lim then math.clamp(nv, lim[1], lim[2]) else nv
				end
			end
		end
	end
end

-- The look at this clock in this weather (a fresh table each call). weather is a kind id
-- or nil (Clear); amount (default 1) blends from kind `from` (default Clear) to it.
-- With no weather, or Clear, the values are exactly the time-of-day look. `grade` (N1, the
-- desktop Realistic grade, see gradeFor) is added to the time-of-day look before the weather.
function LookPresets.at(clock: number, weather: string?, amount: number?, from: string?, grade: Grade?): Look
	local out = base(clock)
	if grade then
		applyGrade(out, clock, grade)
	end
	local l = LookPresets.layer(weather, amount, from)
	if isClear(l) then
		return out
	end
	local light, atmo = out.Lighting, out.Atmosphere
	local cc, rays = out.ColorCorrectionEffect, out.SunRaysEffect
	-- dayDim darkens a storm by day as much as it is day, so night keeps its readable floor.
	local dim = mix(1, l.dayDim, 1 - LookPresets.night(clock)) :: number
	light.Brightness = (light.Brightness :: number) * l.brightness * dim
	light.Ambient = scale(light.Ambient :: Color3, l.ambient)
	light.OutdoorAmbient = scale(light.OutdoorAmbient :: Color3, l.ambient)
	atmo.Density = math.clamp((atmo.Density :: number) + l.density, 0, LookPresets.MAX_DENSITY)
	atmo.Haze = math.clamp((atmo.Haze :: number) + l.haze, 0, LookPresets.MAX_HAZE)
	atmo.Color = toward(atmo.Color :: Color3, l.grey, l.shade)
	atmo.Decay = toward(atmo.Decay :: Color3, l.grey, l.shade)
	cc.Saturation = math.clamp((cc.Saturation :: number) + l.saturation, -1, 1)
	cc.Brightness = math.clamp((cc.Brightness :: number) + l.ccBrightness, -1, 1)
	rays.Intensity = math.clamp((rays.Intensity :: number) * l.sunRays, 0, 1)
	return out
end

-- Terrain's Clouds in this weather: Cover, Density, Color (Clear: 0.5, 0.5, white).
function LookPresets.clouds(weather: string?, amount: number?, from: string?): Values
	local l = LookPresets.layer(weather, amount, from)
	return { Cover = l.cover, Density = l.cloudDensity, Color = l.cloudColor }
end

-- The effect for this class under Lighting, created once: found by our name first, then an
-- existing one of the class is adopted (renamed) so the place never ends up with two.
-- `make` is Instance.new in the game and a fake in the unit tests.
local function effect(lighting: any, className: string, make: (string) -> any): any
	local name = LookPresets.EFFECTS[className]
	local e = lighting:FindFirstChild(name)
	if e then
		return e
	end
	e = lighting:FindFirstChildOfClass(className)
	if not e then
		e = make(className)
	end
	e.Name = name
	e.Parent = lighting
	return e
end

-- Writes the look for this clock (and weather, see at) to `lighting` (tests pass fakes for
-- lighting and make). With a weather given, `clouds` (Terrain's Clouds, if any) is set too;
-- it is never created here (Scenery owns it). `areas` (N0, LookDirector) are area weights
-- from areaWeights; nil, or home = 1, leaves the look exactly as it was. `grade` (N1) is the
-- desktop Realistic grade from gradeFor; nil leaves the look as it was.
function LookPresets.applyTo(lighting: any, clock: number, make: (string) -> any, weather: string?, amount: number?, from: string?, clouds: any?, areas: { [string]: number }?, grade: Grade?)
	local look = LookPresets.at(clock, weather, amount, from, grade)
	if areas ~= nil then
		look = LookPresets.blendAreas(look, areas, clock)
	end
	for target, values in look do
		local inst = if target == "Lighting" then lighting else effect(lighting, target, make)
		for k, v in values do
			inst[k] = v
		end
	end
	if weather ~= nil and clouds ~= nil then
		for k, v in LookPresets.clouds(weather, amount, from) do
			clouds[k] = v
		end
	end
end

-- Writes the look for this clock (and weather) to the game's Lighting and Terrain's Clouds.
function LookPresets.apply(clock: number, weather: string?, amount: number?, from: string?)
	local clouds = if weather ~= nil then workspace.Terrain:FindFirstChildOfClass("Clouds") else nil
	LookPresets.applyTo(game:GetService("Lighting"), clock, function(className: string): any
		return Instance.new(className :: any)
	end, weather, amount, from, clouds)
end

-- How strongly the night look holds (0 by day, 1 at night), for the bobber's night glow.
function LookPresets.night(clock: number): number
	return LookPresets.weights(clock).night or 0
end

-- The weather blend (L6a), shared by the server (DayNight) and the client (LookDirector, N0)
-- so both ease one kind into the next the same way: `from` into `to`, `amount` (0..1, linear)
-- of the way, over BLEND_SECONDS real seconds; at() takes smooth(amount).
export type Blend = { from: string, to: string, amount: number }

LookPresets.BLEND_SECONDS = 20
LookPresets.smooth = smooth

-- Moves the blend on by dt seconds toward kind `want` (mutates and returns b).
function LookPresets.stepBlend(b: Blend, want: string, dt: number): Blend
	if want ~= b.to then
		-- Start from whichever kind shows most right now (changes are game hours apart, so a
		-- change in the middle of a blend is rare; the small jump then is accepted).
		b.from = if b.amount >= 0.5 then b.to else b.from
		b.to = want
		b.amount = 0
	end
	b.amount = math.min(1, b.amount + dt / LookPresets.BLEND_SECONDS)
	return b
end

-- Areas (N0, docs/superpowers/plans/2026-11-27-leg-3.md "Area by area") -------------------
-- Each area changes the time-of-day-and-weather look a little: exposure and the fog's density
-- and haze are added, the ambients, Atmosphere colours and the colour-correction tint are
-- multiplied channel by channel, saturation is added. `home` is the identity, so at home the
-- look is exactly what the server used to write. Areas are kept modest; they get tuned later.
-- Each area also has its terrain water (Terrain's water settings are global, so the client
-- sets them from the area round the camera).
export type Water = {
	WaterColor: Color3,
	WaterTransparency: number,
	WaterReflectance: number,
	WaterWaveSize: number,
	WaterWaveSpeed: number,
}
export type Area = {
	exposure: number,
	ambient: Color3,
	density: number,
	haze: number,
	atmosphere: Color3,
	decay: Color3,
	tint: Color3,
	saturation: number,
	water: Water,
	-- (N3) Optional. exposureFloor: inside this area (weighted by its share of the blend) the
	-- ExposureCompensation is lifted to at least this. dawnMist: Atmosphere Density and Haze added
	-- at the dawn preset's weight (and the area's share).
	exposureFloor: number?,
	dawnMist: { density: number, haze: number }?,
	-- (Neon's N3 review, Pass 1) Optional. sunRaysMult: SunRays intensity multiplied by this
	-- inside the area (eased by its share); bloomThresholdOffset: added to Bloom's threshold
	-- (higher: less of the low sun blooms through the crowns).
	sunRaysMult: number?,
	bloomThresholdOffset: number?,
}

local WHITE = rgb(255, 255, 255)

LookPresets.AREAS = {
	home = {
		exposure = 0,
		ambient = WHITE,
		density = 0,
		haze = 0,
		atmosphere = WHITE,
		decay = WHITE,
		tint = WHITE,
		saturation = 0,
		-- The place's water: WaterLook.TERRAIN (L5d), written once in Edit and saved. Transparency
		-- 0.55 to 0.42 on 11/27/2026 (N1, with WaterLook). By time of day: WATER_BY_TIME.
		water = { WaterColor = rgb(26, 66, 62), WaterTransparency = 0.42, WaterReflectance = 0.35, WaterWaveSize = 0.12, WaterWaveSpeed = 8 },
	},
	creek = {
		-- The cold stream in the woods (N3): cooler shade under a closed canopy, clear tea water
		-- you see the pebbles through, low reflectance so the bed shows, a quick small chop.
		-- Exposure is lifted, not lowered: the cedars' shade already darkens it, and the bobber
		-- must stay readable (plan N3 risks).
		exposure = 0.15,
		ambient = rgb(236, 246, 255),
		density = 0.03,
		haze = 0.3,
		atmosphere = rgb(228, 240, 240),
		decay = rgb(226, 238, 236),
		tint = rgb(244, 250, 255),
		saturation = 0.02,
		water = { WaterColor = rgb(64, 84, 58), WaterTransparency = 0.8, WaterReflectance = 0.12, WaterWaveSize = 0.06, WaterWaveSpeed = 12 },
		-- N3 (blendAreas): the exposure never drops below -0.25 in the creek, so the bobber reads
		-- under the canopy at dusk and in storms; a little ground mist at dawn.
		exposureFloor = -0.25,
		dawnMist = { density = 0.08, haze = 0.8 },
	},
	basin = {
		-- The Big Lake's near half: a little cooler and airier than home.
		exposure = 0,
		ambient = rgb(246, 250, 255),
		density = 0.02,
		haze = 0.2,
		atmosphere = rgb(240, 248, 255),
		decay = rgb(240, 248, 255),
		tint = rgb(250, 252, 255),
		saturation = 0,
		water = { WaterColor = rgb(40, 70, 74), WaterTransparency = 0.5, WaterReflectance = 0.35, WaterWaveSize = 0.15, WaterWaveSpeed = 8 },
	},
	bluewater = {
		-- Big water: hazier and bluer, so the far end seems to go on; twice home's swell.
		exposure = 0.05,
		ambient = rgb(236, 245, 255),
		density = 0.04,
		haze = 0.4,
		atmosphere = rgb(226, 238, 255),
		decay = rgb(220, 232, 255),
		tint = rgb(245, 250, 255),
		saturation = -0.03,
		water = { WaterColor = rgb(16, 38, 66), WaterTransparency = 0.4, WaterReflectance = 0.4, WaterWaveSize = 0.24, WaterWaveSpeed = 10 },
	},
	island = {
		-- The far rock: clean, cold, clearer air.
		exposure = 0.05,
		ambient = rgb(240, 245, 255),
		density = -0.03,
		haze = -0.2,
		atmosphere = rgb(236, 245, 255),
		decay = rgb(236, 240, 255),
		tint = rgb(248, 250, 255),
		saturation = 0.05,
		water = { WaterColor = rgb(22, 60, 84), WaterTransparency = 0.6, WaterReflectance = 0.35, WaterWaveSize = 0.15, WaterWaveSpeed = 9 },
	},
} :: { [string]: Area }

-- N3 review 1 (the advisor), held until a clean desktop capture: the advisor's exposure and dawn
-- mist (and water numbers that review 2 replaced). N3 review 2 (11/28/2026): REVIEW1_CREEK is on
-- for the exposure and the mist only; the water is review 2's (CREEK_WATER_REVIEW2, its own
-- switch). These replace the creek's live values when this module loads.
LookPresets.REVIEW1_CREEK = true
LookPresets.CREEK_REVIEW1 = {
	exposure = 0, -- from 0.15 (the exposure floor stays)
	water = { WaterTransparency = 0.6, WaterReflectance = 0.28, WaterWaveSize = 0.1 }, -- not used since review 2
	dawnMist = { density = 0.14, haze = 1.4 },
}
-- N3 review 2: the creek water. Reflectance is one number on its own so a sweep (0.04 to 0.14)
-- is one edit.
LookPresets.CREEK_REFLECTANCE = 0.06
LookPresets.REVIEW2_CREEK_WATER = true
LookPresets.CREEK_WATER_REVIEW2 = {
	WaterColor = rgb(52, 70, 48),
	WaterTransparency = 0.65,
	WaterReflectance = LookPresets.CREEK_REFLECTANCE,
	WaterWaveSize = 0.06,
}
if LookPresets.REVIEW1_CREEK then
	local creek = LookPresets.AREAS.creek
	local r1 = LookPresets.CREEK_REVIEW1
	creek.exposure = r1.exposure
	creek.dawnMist = table.clone(r1.dawnMist)
end
if LookPresets.REVIEW2_CREEK_WATER then
	local creek = LookPresets.AREAS.creek
	local water = table.clone(creek.water) :: any
	for k, v in LookPresets.CREEK_WATER_REVIEW2 do
		water[k] = v
	end
	creek.water = water
end

-- Neon's N3 review, Pass 1 (11/28/2026), last so its numbers win over reviews 1 and 2: the
-- exposure lowered (-0.10, was review 1's 0; the floor stays -0.25), a green-neutral ambient and
-- tint in place of the blue cast that turned golden water purple, less saturation, a lighter dawn
-- mist, and the low golden sun damped through the crowns (sunRaysMult, bloomThresholdOffset).
LookPresets.NEON_CREEK_PASS1 = true
LookPresets.CREEK_NEON_PASS1 = {
	exposure = -0.1,
	ambient = rgb(242, 246, 244),
	tint = rgb(248, 252, 248),
	saturation = -0.06,
	dawnMist = { density = 0.12, haze = 1.2 },
	sunRaysMult = 0.45,
	bloomThresholdOffset = 0.3,
}
if LookPresets.NEON_CREEK_PASS1 then
	local creek = LookPresets.AREAS.creek :: any
	for k, v in LookPresets.CREEK_NEON_PASS1 do
		creek[k] = if type(v) == "table" then table.clone(v) else v
	end
end

-- N3 review 3 (final, the advisor, 11/28/2026), last so it wins over Neon Pass 1: the creek's
-- exposure back to 0 (Pass 1's -0.10 read too dark under the canopy) and the floor raised to
-- -0.10 (from -0.25), so the bobber and the pool read at dusk and in storms.
LookPresets.N3_REVIEW3_CREEK = true
LookPresets.CREEK_REVIEW3 = { exposure = 0, exposureFloor = -0.1 }
if LookPresets.N3_REVIEW3_CREEK then
	local creek = LookPresets.AREAS.creek :: any
	for k, v in LookPresets.CREEK_REVIEW3 do
		creek[k] = v
	end
end

-- Neon Pass 1: the creek's water by time of day (the home lake has had WATER_BY_TIME since N1).
-- With a clock (Config.WATER_BY_TIME_ON), areaMix gives the creek this, blended by the preset
-- weights, colour included; without one, AREAS.creek.water (review 2's water) stays the
-- fallback. Transparency never above 0.65 (Neon: higher strips the colour over the dark pool).
-- stylua: ignore
LookPresets.CREEK_WATER_BY_TIME = {
	dawn =   { WaterColor = rgb(54, 76, 56), WaterTransparency = 0.62, WaterReflectance = 0.18, WaterWaveSize = 0.07, WaterWaveSpeed = 9 },
	day =    { WaterColor = rgb(56, 78, 56), WaterTransparency = 0.58, WaterReflectance = 0.2,  WaterWaveSize = 0.08, WaterWaveSpeed = 9 },
	golden = { WaterColor = rgb(44, 68, 54), WaterTransparency = 0.48, WaterReflectance = 0.3,  WaterWaveSize = 0.05, WaterWaveSpeed = 5 },
	dusk =   { WaterColor = rgb(38, 60, 56), WaterTransparency = 0.45, WaterReflectance = 0.3,  WaterWaveSize = 0.05, WaterWaveSpeed = 5 },
	night =  { WaterColor = rgb(24, 44, 48), WaterTransparency = 0.42, WaterReflectance = 0.18, WaterWaveSize = 0.04, WaterWaveSpeed = 3 },
} :: { [string]: Water }

-- Where each area is, in world studs (x, z), checked against the code on 11/27/2026: the home
-- lake is Shore.LAKE (x -110..110, z -80..80) plus its shore; Cedar Creek's stretches are
-- x -252..-208, z -70..75 (Shore.AREAS); the basin is BoatRules' Basin zone (z -290..-140,
-- south of the buoy line); blue water starts at BoatRules.BUOY_Z (-290) and today ends at
-- z -440, but reaches -1150 for when the lake grows north. The island is the planned first
-- island (N6), not the basin's small lighthouse island (that one is basin).
-- `over` lists the areas this one sits on top of: inside it, theirs fade out.
export type Zone = {
	id: string,
	x1: number?,
	x2: number?,
	z1: number?,
	z2: number?,
	x: number?,
	z: number?,
	r: number?,
	over: { string }?,
}

LookPresets.AREA_BAND = 40 -- studs over which one area blends into the next, centred on the edge

LookPresets.ZONES = {
	-- Neon Pass 1 (11/28/2026): home starts at x -135 (was -150) and the creek reaches -145 (was
	-- -160), so the gate (x -162) and shot 11's eye (x -140) sit in the forest's shade blend.
	{ id = "home", x1 = -135, x2 = 150, z1 = -110, z2 = 140, over = { "creek", "basin" } },
	{ id = "creek", x1 = -260, x2 = -145, z1 = -120, z2 = 120 },
	{ id = "basin", x1 = -200, x2 = 200, z1 = -290, z2 = -140 },
	{ id = "bluewater", x1 = -450, x2 = 450, z1 = -1150, z2 = -290 },
	{ id = "island", x = 100, z = -950, r = 120, over = { "bluewater" } },
} :: { Zone }

-- Signed distance into a zone (studs): positive inside, negative outside.
local function inside(zn: Zone, x: number, z: number): number
	if zn.r then
		local dx, dz = x - (zn.x :: number), z - (zn.z :: number)
		return zn.r - math.sqrt(dx * dx + dz * dz)
	end
	local x1, x2, z1, z2 = zn.x1 :: number, zn.x2 :: number, zn.z1 :: number, zn.z2 :: number
	local dx = math.max(x1 - x, 0, x - x2)
	local dz = math.max(z1 - z, 0, z - z2)
	if dx > 0 or dz > 0 then
		return -math.sqrt(dx * dx + dz * dz)
	end
	return math.min(x - x1, x2 - x, z - z1, z2 - z)
end

-- How much of each area shows at this position (0..1 each, summing to 1). Each zone counts
-- smoothly across a band AREA_BAND wide centred on its edge; a zone fades out the zones it
-- sits `over`; where zones overlap past 1 they share; whatever is left is home.
function LookPresets.areaWeights(pos: Vector3): { [string]: number }
	local half = LookPresets.AREA_BAND / 2
	local raw: { [string]: number } = {}
	for _, zn in LookPresets.ZONES do
		raw[zn.id] = smooth((inside(zn, pos.X, pos.Z) + half) / LookPresets.AREA_BAND)
	end
	local own = table.clone(raw)
	for _, zn in LookPresets.ZONES do
		if zn.over then
			for _, o in zn.over do
				raw[o] *= 1 - own[zn.id]
			end
		end
	end
	local others = 0
	for id, w in raw do
		if id ~= "home" then
			others += w
		end
	end
	local out: { [string]: number } = {}
	local total = others + raw.home
	if total > 1 then
		for id, w in raw do
			out[id] = w / total
		end
	else
		for id, w in raw do
			out[id] = w
		end
		out.home = 1 - others
	end
	return out
end

-- The strongest area in a set of weights (home on a tie).
function LookPresets.topArea(weights: { [string]: number }): string
	local best, bestW = "home", weights.home or 0
	for id, w in weights do
		if w > bestW then
			best, bestW = id, w
		end
	end
	return best
end

local function mixColor(acc: Color3?, c: Color3, w: number): Color3
	local a = acc or Color3.new(0, 0, 0)
	return Color3.new(a.R + c.R * w, a.G + c.G * w, a.B + c.B * w)
end

-- The home lake's water by time of day (N1, signature 4: a mirror at dawn, a light chop by
-- day, calm at night). Per preset id, blended with the preset weights; WaterColor stays the
-- home area's. Used with Config.WATER_BY_TIME_ON (on its own, or inside the area blend with
-- LOOK_AREAS_ON). Day was the home water as it was (AREAS.home.water) until the noon water of
-- the Gemini fold-in (11/27/2026, N1 close-out): a finer chop (wave 0.12 to 0.09, speed 8 to 6)
-- and reflectance 0.35 to 0.28; transparency kept at 0.42. AREAS.home.water is unchanged.
-- N4 review 2 (11/28/2026): an entry may carry its own WaterColor (blended by the preset weights,
-- as creekWaterAt does; an entry without one uses the home area's colour). Dusk is a blue
-- (46, 72, 92) at transparency 0.25 instead of brighter exposure; golden's mirror 0.55 to 0.42 and
-- dawn's 0.75 to 0.6.
export type TimeWater = { WaterTransparency: number, WaterReflectance: number, WaterWaveSize: number, WaterWaveSpeed: number, WaterColor: Color3? }

-- N4 review 2 (11/28/2026): Sky.MoonAngularSize (DayNight sets it on the place's Sky at start;
-- Roblox's default is 11).
LookPresets.MOON_ANGULAR_SIZE = 6

-- stylua: ignore
LookPresets.WATER_BY_TIME = {
	dawn =   { WaterWaveSize = 0.03, WaterWaveSpeed = 3, WaterReflectance = 0.6,  WaterTransparency = 0.38 }, -- glass (N4 review 2: mirror 0.75 to 0.6)
	day =    { WaterWaveSize = 0.09, WaterWaveSpeed = 6, WaterReflectance = 0.28, WaterTransparency = 0.42 }, -- fine noon chop (N1 close-out)
	golden = { WaterWaveSize = 0.08, WaterWaveSpeed = 6, WaterReflectance = 0.42, WaterTransparency = 0.42 }, -- settling, glints (N4 review 2: 0.55 to 0.42)
	dusk =   { WaterWaveSize = 0.04, WaterWaveSpeed = 3, WaterReflectance = 0.3,  WaterTransparency = 0.25, WaterColor = rgb(46, 72, 92) }, -- N4 review 1: less mirror (was 0.6, 0.05, 4); review 2: its own blue, transparency 0.4 to 0.25
	night =  { WaterWaveSize = 0.08, WaterWaveSpeed = 3, WaterReflectance = 0.25, WaterTransparency = 0.42 }, -- calm, holds the moon (N1 review 2: less mirror, more break-up, against the tan reflection band)
} :: { [string]: TimeWater }

local WATER_KEYS = { "WaterTransparency", "WaterReflectance", "WaterWaveSize", "WaterWaveSpeed" }

-- The home lake's water at this clock (a fresh table).
function LookPresets.homeWaterAt(clock: number): Water
	local home = LookPresets.AREAS.home.water.WaterColor
	local out = { WaterTransparency = 0, WaterReflectance = 0, WaterWaveSize = 0, WaterWaveSpeed = 0 } :: any
	local total = 0
	for id, w in LookPresets.weights(clock) do
		local tw = LookPresets.WATER_BY_TIME[id]
		if tw and w > 0 then
			out.WaterColor = mixColor(out.WaterColor, tw.WaterColor or home, w)
			total += w
			for _, k in WATER_KEYS do
				out[k] += (tw :: any)[k] * w
			end
		end
	end
	if out.WaterColor == nil or total <= 0 then
		out.WaterColor = home
	end
	return out :: Water
end

-- The creek's water at this clock (Neon Pass 1; a fresh table, colour blended too).
function LookPresets.creekWaterAt(clock: number): Water
	local out = { WaterTransparency = 0, WaterReflectance = 0, WaterWaveSize = 0, WaterWaveSpeed = 0 } :: any
	for id, w in LookPresets.weights(clock) do
		local tw = LookPresets.CREEK_WATER_BY_TIME[id]
		if tw and w > 0 then
			out.WaterColor = mixColor(out.WaterColor, tw.WaterColor, w)
			for _, k in WATER_KEYS do
				out[k] += (tw :: any)[k] * w
			end
		end
	end
	if out.WaterColor == nil then
		return LookPresets.AREAS.creek.water
	end
	return out :: Water
end

-- The area settings for these weights, each field the weighted mean of the areas'. With a
-- clock (Config.WATER_BY_TIME_ON), home's water is its water at that time (homeWaterAt), and
-- (Neon Pass 1) the creek's is its own (creekWaterAt); without one, each area's fixed water.
function LookPresets.areaMix(weights: { [string]: number }, clock: number?): Area
	local out = {
		exposure = 0,
		density = 0,
		haze = 0,
		saturation = 0,
		water = { WaterTransparency = 0, WaterReflectance = 0, WaterWaveSize = 0, WaterWaveSpeed = 0 },
	} :: any
	local homeWater = if clock ~= nil then LookPresets.homeWaterAt(clock) else nil
	local creekWater = if clock ~= nil and (weights.creek or 0) > 0 then LookPresets.creekWaterAt(clock) else nil
	for id, w in weights do
		local a = LookPresets.AREAS[id]
		if a and w > 0 then
			local aw = if id == "home" and homeWater then homeWater elseif id == "creek" and creekWater then creekWater else a.water
			out.exposure += a.exposure * w
			out.density += a.density * w
			out.haze += a.haze * w
			out.saturation += a.saturation * w
			out.ambient = mixColor(out.ambient, a.ambient, w)
			out.atmosphere = mixColor(out.atmosphere, a.atmosphere, w)
			out.decay = mixColor(out.decay, a.decay, w)
			out.tint = mixColor(out.tint, a.tint, w)
			local water = out.water
			water.WaterColor = mixColor(water.WaterColor, aw.WaterColor, w)
			for _, k in WATER_KEYS do
				water[k] += (aw :: any)[k] * w
			end
		end
	end
	if out.ambient == nil then
		-- No known area weighted: home.
		if homeWater then
			local h = table.clone(LookPresets.AREAS.home) :: any
			h.water = homeWater
			return h :: Area
		end
		return LookPresets.AREAS.home
	end
	return out :: Area
end

-- Terrain water for these area weights (and, with a clock, home's water by time of day).
function LookPresets.areaWater(weights: { [string]: number }, clock: number?): Water
	return LookPresets.areaMix(weights, clock).water
end

local function isHome(a: Area): boolean
	return a.exposure == 0
		and a.density == 0
		and a.haze == 0
		and a.saturation == 0
		and a.ambient == WHITE
		and a.atmosphere == WHITE
		and a.decay == WHITE
		and a.tint == WHITE
end

local function tinted(c: Color3, t: Color3): Color3
	return Color3.new(math.clamp(c.R * t.R, 0, 1), math.clamp(c.G * t.G, 0, 1), math.clamp(c.B * t.B, 0, 1))
end

-- The look with the areas laid on top (a fresh table; at home, the same values exactly). With a
-- clock, an area's dawnMist is added at the dawn preset's weight (N3); an area's exposureFloor
-- applies with or without one.
function LookPresets.blendAreas(look: Look, weights: { [string]: number }, clock: number?): Look
	local a = LookPresets.areaMix(weights)
	local extras = false
	for id, w in weights do
		local ar = LookPresets.AREAS[id]
		if ar and w > 0 and (ar.exposureFloor ~= nil or ar.dawnMist ~= nil or ar.sunRaysMult ~= nil or ar.bloomThresholdOffset ~= nil) then
			extras = true
		end
	end
	if isHome(a) and not extras then
		return look
	end
	local out: Look = {}
	for target, values in look do
		out[target] = table.clone(values)
	end
	local light, atmo, cc = out.Lighting, out.Atmosphere, out.ColorCorrectionEffect
	if light then
		local e = (light.ExposureCompensation :: number) + a.exposure
		-- Each area's floor, by its share: fully at the floor inside it, eased across the band.
		for id, w in weights do
			local floor = LookPresets.AREAS[id] and LookPresets.AREAS[id].exposureFloor
			if floor and w > 0 then
				e += math.min(w, 1) * math.max(0, floor - e)
			end
		end
		light.ExposureCompensation = math.clamp(e, -3, 3)
		light.Ambient = tinted(light.Ambient :: Color3, a.ambient)
		light.OutdoorAmbient = tinted(light.OutdoorAmbient :: Color3, a.ambient)
	end
	if atmo then
		local density, haze = (atmo.Density :: number) + a.density, (atmo.Haze :: number) + a.haze
		if clock ~= nil then
			local dawn = LookPresets.weights(clock).dawn or 0
			for id, w in weights do
				local mist = LookPresets.AREAS[id] and LookPresets.AREAS[id].dawnMist
				if mist and w > 0 and dawn > 0 then
					density += mist.density * w * dawn
					haze += mist.haze * w * dawn
				end
			end
		end
		atmo.Density = math.clamp(density, 0, LookPresets.MAX_DENSITY)
		atmo.Haze = math.clamp(haze, 0, LookPresets.MAX_HAZE)
		atmo.Color = tinted(atmo.Color :: Color3, a.atmosphere)
		atmo.Decay = tinted(atmo.Decay :: Color3, a.decay)
	end
	if cc then
		cc.TintColor = tinted(cc.TintColor :: Color3, a.tint)
		cc.Saturation = math.clamp((cc.Saturation :: number) + a.saturation, -1, 1)
	end
	-- Neon Pass 1: an area's sun rays multiplier and bloom threshold offset, by its share.
	local rays, bloom = out.SunRaysEffect, out.BloomEffect
	for id, w in weights do
		local ar = LookPresets.AREAS[id]
		if ar and w > 0 then
			local share = math.min(w, 1)
			if rays and ar.sunRaysMult and rays.Intensity ~= nil then
				rays.Intensity = math.clamp((rays.Intensity :: number) * (1 + (ar.sunRaysMult - 1) * share), 0, 1)
			end
			if bloom and ar.bloomThresholdOffset and bloom.Threshold ~= nil then
				bloom.Threshold = math.clamp((bloom.Threshold :: number) + ar.bloomThresholdOffset * share, 0, 4)
			end
		end
	end
	return out
end

-- Device tiers (N0, plan "Two tiers"). Data only; LookDirector applies it on each client.
-- lightingStyle: Lighting.LightingStyle to set (the desktop's Realistic only when
-- Config.REALISTIC_DESKTOP; otherwise the place's own is kept). shadows: "all" or "sun"
-- (lantern shadows go with "sun" once lanterns cast them). sunRays, bloom, depthOfField:
-- whether those effects may run. cloudDetail: kept for when Clouds has a detail setting
-- (today it has only Cover, Density and Color, so nothing reads it).
export type Tier = {
	id: string,
	lightingStyle: string,
	shadows: string,
	sunRays: boolean,
	bloom: boolean,
	depthOfField: boolean,
	cloudDetail: number,
	grade: Grade?, -- offsets for this tier's Realistic style (N1); used only with REALISTIC_DESKTOP
}

LookPresets.TIERS = {
	desktop = { id = "desktop", lightingStyle = "Realistic", shadows = "all", sunRays = true, bloom = true, depthOfField = true, cloudDetail = 1, grade = LookPresets.REALISTIC_GRADE },
	-- LightingStyle is place-wide (a LocalScript may not write it: "lacking capability
	-- PluginOrOpenCloud", tested 11/27/2026), so the phone runs the place's style too, takes the
	-- same grade, and saves its cost elsewhere: no sun rays or depth of field, no lantern shadows.
	phone = { id = "phone", lightingStyle = "Realistic", shadows = "sun", sunRays = false, bloom = true, depthOfField = false, cloudDetail = 0.5, grade = LookPresets.REALISTIC_GRADE },
} :: { [string]: Tier }

-- The grade to lay on the look: the tier's grade only when the place really runs Realistic
-- (`realistic`: the place's Lighting.LightingStyle is Realistic and Config.REALISTIC_DESKTOP
-- allows the grade); otherwise nil, so Soft keeps the presets as they are. Both tiers carry
-- the grade, because the style is place-wide (see TIERS.phone).
function LookPresets.gradeFor(tier: Tier?, realistic: boolean): Grade?
	if tier and realistic then
		return tier.grade
	end
	return nil
end

return LookPresets
