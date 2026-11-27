--!strict
-- The look on this player's screen (leg 3, N0). With Config.LOOK_DIRECTOR_ON the server stops
-- writing Lighting (DayNight) and this module writes it locally instead; local writes to
-- Lighting, its effects and Terrain do not replicate, so each player can have their own look.
--
-- The look = time of day (the replicated Lighting.ClockTime) x the weather layer (the
-- Workspace attribute "Weather", blended over 20 s exactly as the server did, through
-- LookPresets.stepBlend) x an area preset (LookPresets.areaWeights round the camera, only
-- with Config.LOOK_AREAS_ON) x a device tier (LookPresets.TIERS). With areas off and the
-- desktop tier this writes exactly the values the server used to write.
-- N1: on the desktop tier with Config.REALISTIC_DESKTOP the look also carries the Realistic
-- grade (LookPresets.gradeFor, TIERS.desktop.grade); the phone tier never does. Terrain water
-- comes from the areas (LOOK_AREAS_ON) and/or the home lake's water by time of day
-- (Config.WATER_BY_TIME_ON, LookPresets.homeWaterAt).
--
-- The tier: touch with no keyboard is "phone", anything else "desktop". A watchdog drops to
-- phone once per session if frames average over 25 ms for 10 s (never in Studio, whose
-- unfocused window runs near 15 fps). The player attribute LookTier ("desktop", "phone" or
-- "auto") overrides both; a journal setting will write it later.
--
-- For tests and the harness: debugState(), and the player attributes LookArea (the strongest
-- area) and LookTierActive.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local LookPresets = require(Shared:WaitForChild("LookPresets"))

local LookDirector = {}

local FULL_EVERY = 0.1 -- real seconds between full look writes (about 10 Hz; the server wrote at 4 Hz)
local WATCH_WINDOW = 10 -- seconds of frames the watchdog averages
local WATCH_LIMIT = 0.025 -- average frame time (s) over which the watchdog drops to phone (40 fps)

local started = false
local blend: LookPresets.Blend? = nil -- nil until the first weather read
local weights: { [string]: number } = { home = 1 }
local area = "home"
local tierId = "desktop"
local watchdogDropped = false
local placeStyle: any = nil -- the place's own Lighting.LightingStyle, read once at start
local disabledByTier: { [Instance]: boolean } = {} -- effects the tier switched off, to switch back on
local lastWater: { [string]: any }? = nil

local function make(className: string): any
	return Instance.new(className :: any)
end

-- The kind to show now: nil while weather is switched off (as DayNight.wanted).
local function wanted(): string?
	if not Config.WEATHER_ON then
		return nil
	end
	local w = workspace:GetAttribute("Weather")
	return if type(w) == "string" and LookPresets.WEATHER[w] then w else "Clear"
end

-- The weather blend, stepped by dt. On the first read the client joins whatever the server
-- is showing: the server starts from Clear and blends in over BLEND_SECONDS, so a client that
-- joins in those first seconds starts part way (DistributedGameTime replicates the server's
-- run time); one that joins later starts with the kind fully in.
local function stepWeather(dt: number)
	local want = wanted()
	if want == nil then
		return
	end
	local b = blend
	if b == nil then
		local amount = if want == "Clear" then 1 else math.clamp(workspace.DistributedGameTime / LookPresets.BLEND_SECONDS, 0, 1)
		blend = { from = "Clear", to = want, amount = amount }
		return
	end
	LookPresets.stepBlend(b, want, dt)
end

local function autoTier(): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "phone"
	end
	return if watchdogDropped then "phone" else "desktop"
end

local function chooseTier(): string
	local player = Players.LocalPlayer
	local override = if player then player:GetAttribute("LookTier") else nil
	if override == "desktop" or override == "phone" then
		return override
	end
	return autoTier()
end

local function setStyle(style: any)
	pcall(function()
		(Lighting :: any).LightingStyle = style
	end)
end

-- Lighting.LightingStyle is place-wide: a LocalScript may not write it (tested 11/27/2026,
-- "lacking capability PluginOrOpenCloud"). The place is set to Realistic in Edit; the client
-- only reads it to know whether the Realistic grade applies.
local function placeIsRealistic(): boolean
	local ok, style = pcall(function()
		return (Lighting :: any).LightingStyle
	end)
	return ok and style == (Enum :: any).LightingStyle.Realistic
end

local function applyStyle(_tier: LookPresets.Tier)
	-- Nothing to write (see placeIsRealistic); kept so a tier change has one place to hook.
end

-- Switch an effect off for this tier, or back on if the tier switched it off before. An
-- effect the tier allows is never touched, so the desktop tier writes nothing of its own.
local function allow(e: Instance?, allowed: boolean)
	if not e then
		return
	end
	if not allowed then
		if (e :: any).Enabled then
			(e :: any).Enabled = false
			disabledByTier[e] = true
		end
	elseif disabledByTier[e] then
		(e :: any).Enabled = true
		disabledByTier[e] = nil
	end
end

local function applyEffects(tier: LookPresets.Tier)
	allow(Lighting:FindFirstChild(LookPresets.EFFECTS.SunRaysEffect), tier.sunRays)
	allow(Lighting:FindFirstChild(LookPresets.EFFECTS.BloomEffect), tier.bloom)
	local cam = workspace.CurrentCamera
	for _, parent in { Lighting :: Instance, cam :: Instance? } do
		if parent then
			for _, e in parent:GetChildren() do
				if e:IsA("DepthOfFieldEffect") then
					allow(e, tier.depthOfField)
				end
			end
		end
	end
	-- Shadows: "sun" keeps Lighting.GlobalShadows (the sun's) and will turn lantern shadows off
	-- once lanterns cast them (N0 proof corner); nothing to switch yet.
end

-- Two water values close enough not to rewrite (the per-time water drifts with the clock).
local function near(a: any, b: any): boolean
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) < 1e-3
	end
	if typeof(a) == "Color3" and typeof(b) == "Color3" then
		return math.abs(a.R - b.R) < 1e-3 and math.abs(a.G - b.G) < 1e-3 and math.abs(a.B - b.B) < 1e-3
	end
	return a == b
end

-- Terrain water, written when it changes: the blended areas with LOOK_AREAS_ON (home's water by
-- time of day inside them with WATER_BY_TIME_ON), else the home lake's water by time of day.
local function applyWater(clock: number)
	local byTime = if Config.WATER_BY_TIME_ON then clock else nil
	local water: any
	if Config.LOOK_AREAS_ON then
		water = LookPresets.areaWater(weights, byTime)
	else
		water = LookPresets.homeWaterAt(clock)
	end
	local last = lastWater
	if last then
		local same = true
		for k, v in water do
			if not near(last[k], v) then
				same = false
				break
			end
		end
		if same then
			return
		end
	end
	lastWater = water
	pcall(function()
		local terrain = workspace.Terrain :: any
		for k, v in water do
			terrain[k] = v
		end
	end)
end

local function setAttr(name: string, value: any)
	local player = Players.LocalPlayer
	if player and player:GetAttribute(name) ~= value then
		player:SetAttribute(name, value)
	end
end

local function fullWrite(dt: number)
	stepWeather(dt)
	local cam = workspace.CurrentCamera
	if cam then
		weights = LookPresets.areaWeights(cam.CFrame.Position)
		area = LookPresets.topArea(weights)
	end
	local areas = if Config.LOOK_AREAS_ON then weights else nil
	local clock = Lighting.ClockTime
	local id = chooseTier()
	local tier = LookPresets.TIERS[id] or LookPresets.TIERS.desktop
	-- The Realistic grade: whenever the place runs Realistic and REALISTIC_DESKTOP allows it.
	local grade = LookPresets.gradeFor(tier, Config.REALISTIC_DESKTOP and placeIsRealistic())
	local b = blend
	if Config.WEATHER_ON and b then
		-- The same call the server made (DayNight.applyLook), plus the areas and the grade.
		local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
		LookPresets.applyTo(Lighting, clock, make, b.to, LookPresets.smooth(b.amount), b.from, clouds, areas, grade)
	else
		LookPresets.applyTo(Lighting, clock, make, nil, nil, nil, nil, areas, grade)
	end
	if Config.LOOK_AREAS_ON or Config.WATER_BY_TIME_ON then
		applyWater(clock)
	end
	if id ~= tierId then
		print(string.format("[LookDirector] tier %s -> %s", tierId, id))
		tierId = id
		applyStyle(tier)
	end
	applyEffects(tier)
	setAttr("LookArea", area)
	setAttr("LookTierActive", tierId)
end

-- What the director is doing now, for tests and the harness.
function LookDirector.debugState(): { [string]: any }
	local b = blend
	return {
		clock = Lighting.ClockTime,
		weatherFrom = if b then b.from else nil,
		weatherTo = if b then b.to else nil,
		weatherAmount = if b then b.amount else nil,
		areas = table.clone(weights),
		area = area,
		areasOn = Config.LOOK_AREAS_ON,
		tier = tierId,
		graded = LookPresets.gradeFor(LookPresets.TIERS[tierId], Config.REALISTIC_DESKTOP and placeIsRealistic()) ~= nil,
		waterByTime = Config.WATER_BY_TIME_ON,
		water = lastWater,
		watchdogDropped = watchdogDropped,
	}
end

function LookDirector.start()
	if started then
		return
	end
	started = true
	local ok, style = pcall(function()
		return (Lighting :: any).LightingStyle
	end)
	placeStyle = if ok then style else nil
	tierId = chooseTier()
	applyStyle(LookPresets.TIERS[tierId] or LookPresets.TIERS.desktop)
	fullWrite(0)

	local sinceFull = 0
	local watchSum, watchCount = 0, 0
	local studio = RunService:IsStudio()
	RunService.RenderStepped:Connect(function(dt: number)
		sinceFull += dt
		if sinceFull >= FULL_EVERY then
			fullWrite(sinceFull)
			sinceFull = 0
		end
		if not watchdogDropped and not studio then
			watchSum += dt
			watchCount += 1
			if watchSum >= WATCH_WINDOW then
				local avg = watchSum / watchCount
				watchSum, watchCount = 0, 0
				if avg > WATCH_LIMIT then
					watchdogDropped = true
					print(string.format("[LookDirector] frames averaged %.1f ms over %d s: phone tier for this session", avg * 1000, WATCH_WINDOW))
				end
			end
		end
	end)
	print(string.format("[LookDirector] started: tier %s, areas %s", tierId, if Config.LOOK_AREAS_ON then "on" else "off"))
end

return LookDirector
