--!strict
-- The lake's light through the day (L5a, Real-ish): misty dawn, bright summer day, golden
-- afternoon, moonlit night (docs/DECISIONS.md, mockups in docs/looks/realish/). Each preset
-- holds over a stretch of the clock and blends smoothly into the next one, round midnight too.
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
		to = 18.6,
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
				Color = rgb(62, 78, 112),
				Decay = rgb(30, 40, 72),
				Glare = 0,
				Haze = 0.4,
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

-- The blended look at this clock (a fresh table each call).
function LookPresets.at(clock: number): Look
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

-- Writes the look for this clock to `lighting` (tests pass fakes for lighting and make).
function LookPresets.applyTo(lighting: any, clock: number, make: (string) -> any)
	for target, values in LookPresets.at(clock) do
		local inst = if target == "Lighting" then lighting else effect(lighting, target, make)
		for k, v in values do
			inst[k] = v
		end
	end
end

-- Writes the look for this clock to the game's Lighting.
function LookPresets.apply(clock: number)
	LookPresets.applyTo(game:GetService("Lighting"), clock, function(className: string): any
		return Instance.new(className :: any)
	end)
end

-- How strongly the night look holds (0 by day, 1 at night), for the bobber's night glow.
function LookPresets.night(clock: number): number
	return LookPresets.weights(clock).night or 0
end

return LookPresets
