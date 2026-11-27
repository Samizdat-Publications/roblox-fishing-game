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
			-- Pink-gold low sun, haze lying on the water.
			Lighting = {
				Ambient = rgb(72, 62, 74),
				OutdoorAmbient = rgb(140, 128, 126),
				Brightness = 1.8,
				ColorShift_Top = rgb(255, 206, 178),
				ColorShift_Bottom = rgb(100, 90, 94),
				EnvironmentDiffuseScale = 0.6,
				EnvironmentSpecularScale = 0.7,
				ExposureCompensation = 0.15,
			},
			Atmosphere = {
				Density = 0.4,
				Offset = 0.12,
				Color = rgb(232, 204, 206),
				Decay = rgb(206, 156, 150),
				Glare = 1.2,
				Haze = 1.8,
			},
			BloomEffect = { Intensity = 0.6, Size = 28, Threshold = 1.6 },
			ColorCorrectionEffect = { Brightness = 0.03, Contrast = 0.04, Saturation = -0.02, TintColor = rgb(255, 238, 240) },
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
				EnvironmentDiffuseScale = 1,
				EnvironmentSpecularScale = 1,
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
			ColorCorrectionEffect = { Brightness = 0.02, Contrast = 0.12, Saturation = 0.1, TintColor = rgb(255, 236, 212) },
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
				Ambient = rgb(54, 50, 72),
				OutdoorAmbient = rgb(112, 106, 140),
				Brightness = 1.85, -- a storm at dusk must still clear the readable-night floor (spec)
				ColorShift_Top = rgb(255, 176, 196),
				ColorShift_Bottom = rgb(48, 44, 78),
				EnvironmentDiffuseScale = 0.55,
				EnvironmentSpecularScale = 0.8,
				ExposureCompensation = 0.3,
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
				Density = 0.3,
				Offset = 0.1,
				-- Darker than at first (11/27): the pale blue haze lit the far hills against the
				-- black sky; now they read as dark shapes, like real hills at night.
				Color = rgb(34, 42, 64),
				Decay = rgb(14, 18, 34),
				Glare = 0,
				Haze = 0.15,
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

-- The look at this clock in this weather (a fresh table each call). weather is a kind id
-- or nil (Clear); amount (default 1) blends from kind `from` (default Clear) to it.
-- With no weather, or Clear, the values are exactly the time-of-day look.
function LookPresets.at(clock: number, weather: string?, amount: number?, from: string?): Look
	local out = base(clock)
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
-- it is never created here (Scenery owns it).
function LookPresets.applyTo(lighting: any, clock: number, make: (string) -> any, weather: string?, amount: number?, from: string?, clouds: any?)
	for target, values in LookPresets.at(clock, weather, amount, from) do
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

return LookPresets
