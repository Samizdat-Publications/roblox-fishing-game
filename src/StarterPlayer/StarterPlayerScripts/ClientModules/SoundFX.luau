--!strict
-- The game's sound (docs/DIRECTION.md section 2). Ambience follows the clock and where you
-- stand; while the line is in, the music drops away and small sounds tell the story; the
-- fight clicks, zips and strains with the line; the catch ends on a stinger by rarity.
-- The rules live in Shared.SoundMix (tested); this module only plays them. Every sound is
-- made once and reused, and a missing id is simply skipped.
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SoundIds = require(Shared.SoundIds)
local SoundSheets = require(Shared.SoundSheets)
local SoundMix = require(Shared.SoundMix)
local FishData = require(Shared.FishData)
local BoatData = require(Shared.BoatData)

local SoundFX = {}

local AMBIENCE_VOLUME = 0.55
local MUSIC_VOLUME = 0.28
local THEME_GAP = 240 -- seconds of quiet between plays of a place's theme
local FIRST_THEME_AFTER = 20
local THEME_IDLE = 10 -- the theme only starts after this long with no line in

local sounds: { [string]: Sound } = {}
local groups: { [string]: SoundGroup } = {}
local phase = "Idle"
local lastThemeEnd = -math.huge
local started = false
local bigFight = false
local lastFishPos = 0.5
local cooldowns: { [string]: number } = {}
local stingerUntil = 0
local idleSince = 0
local rng = Random.new()
-- Overnight 2 (UNVERIFIED in Studio): when the next thunder roll and wind gust are due.
local nextThunder = 0
local nextGust = 0
local frenzyZones: { [string]: { Vector3 } } = {}
-- The wait (L4): a fish's shadow is coming in, and the held breath before its strike.
local approaching = false
local heldUntil = 0
local HELD_MAX = 1.5 -- the held breath ends by itself after this long (a lost message)
local ENDS_APPROACH = {
	Landed = true,
	Dip = true,
	Bite = true,
	Leave = true,
	Missed = true,
	Reset = true,
	Hooked = true,
	Caught = true,
	Escaped = true,
	Snag = true,
	Freed = true,
	Snapped = true,
	Hint = true,
}

local function group(name: string, volume: number): SoundGroup
	local g = Instance.new("SoundGroup")
	g.Name = "Fishing" .. name
	g.Volume = volume
	g.Parent = SoundService
	groups[name] = g
	return g
end

-- alias: a second copy of a sound under its own name (for its own volume and pitch).
-- The id comes from SoundSheets.resolve: the sound's own upload, a region of a sound sheet,
-- or a stand-in borrowed from an uploaded sound (audio/UPLOAD-PLAN.md).
local function make(name: string, g: SoundGroup, looped: boolean, volume: number, alias: string?): Sound?
	local r = SoundSheets.resolve(name, SoundIds)
	if not r then
		return nil
	end
	local key = alias or name
	local s = Instance.new("Sound")
	s.Name = key
	s.SoundId = r.id
	s.Looped = looped
	s.Volume = volume * r.volume
	s:SetAttribute("BaseSpeed", r.speed)
	s.PlaybackSpeed = r.speed
	if r.start and r.length then
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(r.start, r.start + r.length)
		s:SetAttribute("RegionStart", r.start)
	end
	s:SetAttribute("Via", r.via)
	s.SoundGroup = g
	s.Parent = g
	sounds[key] = s
	return s
end

-- Plays a one-shot from the start. cooldown (seconds) stops rapid repeats; vary nudges the
-- pitch a few percent each time so repeats never sound mechanical.
local function play(name: string, cooldown: number?, speed: number?, vary: boolean?)
	local s = sounds[name]
	if not s then
		return
	end
	local now = os.clock()
	if cooldown and (cooldowns[name] or 0) > now then
		return
	end
	cooldowns[name] = now + (cooldown or 0)
	local base = (s:GetAttribute("BaseSpeed") :: number?) or 1
	s.PlaybackSpeed = base * (speed or 1) * (if vary then rng:NextNumber(0.94, 1.06) else 1)
	s.TimePosition = (s:GetAttribute("RegionStart") :: number?) or 0
	s:Play()
end

local function setLoop(name: string, on: boolean)
	local s = sounds[name]
	if not s then
		return
	end
	if on and not s.IsPlaying then
		s:Play()
	elseif not on and s.IsPlaying then
		s:Stop()
	end
end

-- Moves a looped sound's volume toward a target (playing it while above zero).
local function fadeTo(name: string, target: number, rate: number, dt: number)
	local s = sounds[name]
	if not s then
		return
	end
	local v = s.Volume
	local step = rate * dt
	v = if v < target then math.min(target, v + step) else math.max(target, v - step)
	s.Volume = v
	if v > 0.001 and not s.IsPlaying then
		s:Play()
	elseif v <= 0.001 and s.IsPlaying then
		s:Stop()
	end
end

local function playerPosition(): Vector3?
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

local function lineIn(): boolean
	return phase == "Waiting" or phase == "Bite" or phase == "Hooking"
end

local function fighting(): boolean
	return phase == "Fighting" or phase == "Resolving"
end

local function update(dt: number)
	local pos = playerPosition()
	local creek = if pos then SoundMix.creekLevel(SoundMix.creekDistance(pos.X, pos.Z)) else 0
	-- While the line is in, everything else steps back a little, more as a fish comes in, and
	-- nearly all the way just before it strikes (SoundMix.waitMix, L4).
	local mix = SoundMix.waitMix(phase, approaching, os.clock() < heldUntil)
	local hush = mix.ambience
	local r = mix.rate
	local big = if pos then SoundMix.bigLakeLevel(pos.X, pos.Z) else 0
	local blue = if pos then SoundMix.blueLevel(pos.X, pos.Z) else 0
	local lake = SoundMix.lakeLevel(creek) * SoundMix.homeLakeLevel(big) * hush
	fadeTo("amb-biglake", big * (1 - blue) * hush, 0.4 * r, dt)
	fadeTo("amb-bluewater", blue * hush, 0.4 * r, dt)
	for id, w in SoundMix.lakeWeights(Lighting.ClockTime) do
		fadeTo(id, w * lake, 0.5 * r, dt)
	end
	fadeTo("amb-creek", creek * hush, 0.6 * r, dt)

	-- Music: one calm theme now and then, never while a line is in or a fish is on.
	local now = os.clock()
	local themeName = if creek > 0.5 then "theme-creek" elseif big > 0.5 and sounds["theme-biglake"] then "theme-biglake" else "theme-lake"
	local theme = sounds[themeName]
	local busy = lineIn() or fighting()
	for _, name in { "theme-lake", "theme-creek", "theme-biglake" } do
		local s = sounds[name]
		if s and s.IsPlaying then
			local want = if busy or name ~= themeName then 0 elseif now < stingerUntil then 0.35 else 1
			fadeTo(name, want, 0.3, dt)
			if not s.IsPlaying then
				lastThemeEnd = now
			end
		end
	end
	if busy or phase ~= "Idle" then
		idleSince = now
	end
	if theme and not theme.IsPlaying and now - idleSince > THEME_IDLE and now - lastThemeEnd > THEME_GAP then
		theme.Volume = 0.01
		theme.TimePosition = 0
		theme:Play()
		lastThemeEnd = math.huge -- set again when it ends
		theme.Ended:Once(function()
			lastThemeEnd = os.clock()
		end)
	end

	-- Bobber ticking in the ripples while waiting.
	fadeTo("wait-bobber-tick", mix.tick, 1.5 * r, dt)
	-- The tension layer comes in during fights with heavy fish.
	-- Out in blue water the deep-water layer takes over, once it's uploaded.
	local deep = blue > 0.5 and sounds["tension-bluewater"] ~= nil
	fadeTo("tension-fight", if fighting() and bigFight and not deep then 0.8 else 0, 0.6, dt)
	fadeTo("tension-bluewater", if fighting() and bigFight and deep then 0.8 else 0, 0.6, dt)

	-- Weather: rain on the water in a storm, thunder now and then, gusts on windy days.
	local weather = SoundMix.weather(workspace:GetAttribute("Weather"))
	fadeTo("rain-on-water", weather.rain * math.min(1, hush / SoundMix.WAIT_HUSH), 0.3 * r, dt)
	if weather.thunder then
		if now >= nextThunder then
			if nextThunder > 0 then
				play("thunder-far", nil, nil, true)
			end
			nextThunder = now + rng:NextNumber(weather.thunder[1], weather.thunder[2])
		end
	else
		nextThunder = 0
	end
	if weather.gust then
		if now >= nextGust then
			if nextGust > 0 then
				play("wind-gust", nil, nil, true)
			end
			nextGust = now + rng:NextNumber(weather.gust[1], weather.gust[2])
		end
	else
		nextGust = 0
	end

	-- A feeding frenzy boils louder the closer you are to it.
	local spot = workspace:GetAttribute("Frenzy")
	local boil = 0
	local boilAt = workspace:GetAttribute("FrenzyAt")
	if type(spot) == "string" and pos and typeof(boilAt) == "Vector3" then
		boil = SoundMix.frenzyLevel((Vector3.new(pos.X, 0, pos.Z) - Vector3.new(boilAt.X, 0, boilAt.Z)).Magnitude)
	elseif type(spot) == "string" and pos then
		for _, at in SoundFX.frenzyPoints(spot) do
			boil = math.max(boil, SoundMix.frenzyLevel((Vector3.new(pos.X, 0, pos.Z) - at).Magnitude))
		end
	end
	fadeTo("frenzy-boil", boil * 0.8, 0.5, dt)

	-- Your boat's motor, while you're aboard.
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local boatModel = seat and seat:FindFirstAncestorOfClass("Model")
	local boatId = boatModel and boatModel:GetAttribute("BoatId")
	local runName = SoundMix.motorName(boatId)
	if type(boatId) == "string" and seat then
		local v = seat.AssemblyLinearVelocity
		local b = BoatData.byId[boatId]
		local m = SoundMix.motor(Vector3.new(v.X, 0, v.Z).Magnitude, if b then b.maxSpeed else 12)
		fadeTo("motor-dinghy-idle", m.idle, 1.5, dt)
		fadeTo(runName, m.run, 1.5, dt)
		local run = sounds[runName]
		if run then
			run.PlaybackSpeed = m.pitch
		end
		-- The buoy line has a bell you hear as you come up on it.
		if pos and math.abs(pos.Z - SoundMix.BUOY_Z) < 35 then
			play("buoy-bell", 9, nil, true)
		end
	else
		fadeTo("motor-dinghy-idle", 0, 1.5, dt)
	end
	for _, name in { "motor-dinghy-run", "motor-deepv-run" } do
		if name ~= runName or type(boatId) ~= "string" then
			fadeTo(name, 0, 1.5, dt)
		end
	end
end

-- Where a frenzy spot's water is (its zone part, or the two open-water patches).
function SoundFX.frenzyPoints(spot: string): { Vector3 }
	local cached = frenzyZones[spot]
	if cached then
		return cached
	end
	local out = {}
	if spot == "OpenWater" then
		out = { Vector3.new(-60, 0, -40), Vector3.new(65, 0, -35) }
	else
		for _, root in { "Lake", "BigLake" } do
			local folder = workspace:FindFirstChild(root)
			local zones = folder and folder:FindFirstChild("Zones")
			local z = zones and zones:FindFirstChild(spot)
			if z and z:IsA("BasePart") then
				table.insert(out, Vector3.new(z.Position.X, 0, z.Position.Z))
			end
		end
	end
	if #out > 0 then
		frenzyZones[spot] = out -- with streaming a zone may arrive later, so only cache a find
	end
	return out
end

-- Called by the Controller every frame of a fight.
function SoundFX.fight(s: any, holding: boolean, dt: number)
	if not started or not s then
		return
	end
	local reel = sounds["reel-click"]
	if reel then
		local inside = math.abs(s.fishPos - s.zonePos) <= s.zoneSize / 2
		reel.PlaybackSpeed = SoundMix.reelPitch(s.progress, inside)
		if holding and not reel.IsPlaying then
			reel:Play()
		elseif not holding and reel.IsPlaying then
			reel:Stop()
		end
	end
	local speed = if dt > 0 then math.abs(s.fishPos - lastFishPos) / dt else 0
	lastFishPos = s.fishPos
	if speed > 0.9 then
		play("drag-zip", 1.4, nil, true) -- the fish runs and pulls line off the reel
	end
	if speed > 1.6 then
		play("thrash-splash", 2.5, nil, true)
	end
	local inside = math.abs(s.fishPos - s.zonePos) <= s.zoneSize / 2
	if s.progress < 0.18 and not inside then
		play("line-strain", 2.8)
	end
end

-- Called by the Controller whenever its fishing state changes.
function SoundFX.setPhase(newPhase: string)
	phase = newPhase
	if not fighting() then
		-- The fight is over: its sounds stop with it.
		for _, name in { "reel-click", "drag-zip", "thrash-splash", "line-strain" } do
			setLoop(name, false)
		end
	end
end

-- Called by the Controller for each server fishing event (and "Dip" for a nibble).
function SoundFX.event(kind: string, payload: any)
	if not started then
		return
	end
	-- The wait (L4): the approach dips the world, the held breath silences it, and anything
	-- that ends the approach lets it back in.
	if kind == "Approach" then
		approaching = true
		heldUntil = 0
		if payload and payload.swell then
			play("approach-swell", 2, 0.7) -- a big or rare fish: a low swell under it
		end
	elseif kind == "Hush" then
		heldUntil = os.clock() + HELD_MAX
	elseif ENDS_APPROACH[kind] then
		approaching = false
		heldUntil = 0
	end
	if kind == "Twitch" then
		play("twitch-tick", 0.1, 1.6, true) -- the bait jiggles: a quiet tick
	elseif kind == "Leave" then
		play("rise", 1, if payload and payload.spooked then 1.6 else 1.25, true) -- a tail flick as it goes
	elseif kind == "WaitEvent" then
		local what = payload and payload.kind
		if what == "rise" then
			play("rise", 1, 1.7, true)
		elseif what == "jump" then
			play("far-splash", 1, 1.1, true)
		elseif what == "turtle" then
			play("rise", 1, 2, true)
		end
	end
	if kind == "Landed" then
		play("plop", nil, 1.3, true) -- a light bobber plop, not a big splash
		local tick = sounds["wait-bobber-tick"]
		if tick then
			tick.PlaybackSpeed = rng:NextNumber(0.9, 1.05) -- each wait sounds a little different
		end
	elseif kind == "Dip" then
		play("bite-nibble", nil, nil, true)
	elseif kind == "Bite" then
		local cue = SoundMix.biteCue(payload and payload.style)
		play(cue, nil, nil, true)
		-- A crisp water snap on top, so the bite reads on small phone speakers too.
		play("snap", nil, if cue == "bite-deep-pull" then 0.9 else 1.25, true)
	elseif kind == "Hooked" then
		bigFight = SoundMix.isBigFight(payload and payload.fight)
		lastFishPos = 0.5
	elseif kind == "Caught" then
		local fish = payload and payload.fish
		local species = fish and FishData.byId[fish.id]
		play(SoundMix.splashFor(fish and fish.kg or 0), nil, nil, true)
		stingerUntil = os.clock() + 4
		-- A trophy or monster gets its own stinger once one is uploaded (UNVERIFIED in Studio, 2026-11-26).
		local sting = SoundMix.catchStinger(species and (species :: any).tier, fish and fish.sizeClass, function(name)
			return sounds[name] ~= nil
		end)
		task.delay(0.35, function()
			play(sting)
		end)
		if payload and payload.first then
			task.delay(0.9, function()
				play("sting-new-species")
			end)
		end
	elseif kind == "Escaped" then
		play(if payload and payload.snapped and sounds["line-snap"] then "line-snap" else "splash-small", nil, nil, true)
	-- Overnight 2 (UNVERIFIED in Studio): sounds for the new loop, each skipped until uploaded.
	elseif kind == "Announce" then
		play(if payload and payload.sound then payload.sound else "server-horn", 3)
	elseif kind == "Goal" then
		play("goal-complete", 1)
	elseif kind == "Sold" then
		play("sell-coins", 0.5, nil, true)
	elseif kind == "FrenzyStart" then
		play("frenzy-burst", 10)
	-- L2b (UNVERIFIED in Studio): a quiet splash for a rise, the snag's ending.
	elseif kind == "Rise" then
		play("rise", 1, 1.5, true)
	elseif kind == "Snag" or kind == "Wiggled" then
		play("plop", 0.1, 0.8, true)
	elseif kind == "Snapped" then
		play(if sounds["line-snap"] then "line-snap" else "splash-small", nil, nil, true)
	elseif kind == "Freed" then
		play("plop", nil, 1.1, true)
	end
	if kind == "Hooked" and payload and payload.sizeClass == "monster" then
		play("breach-huge", 2) -- something huge breaks the surface
	end
end

function SoundFX.start()
	if started then
		return
	end
	started = true
	local amb = group("Ambience", AMBIENCE_VOLUME)
	local music = group("Music", MUSIC_VOLUME)
	local fx = group("Effects", 0.9)
	for id in SoundMix.lakeWeights(12) do
		make(id, amb, true, 0)
	end
	make("amb-creek", amb, true, 0)
	make("wait-bobber-tick", fx, true, 0)
	make("theme-lake", music, false, 0)
	make("theme-creek", music, false, 0)
	make("tension-fight", music, true, 0)
	-- Overnight 2 sounds (audio/sounds-next.json); each is skipped until its id is pasted in.
	for _, name in { "amb-biglake", "amb-bluewater", "rain-on-water" } do
		make(name, amb, true, 0)
	end
	for _, name in { "frenzy-boil", "motor-dinghy-idle", "motor-dinghy-run", "motor-deepv-run" } do
		make(name, fx, true, 0)
	end
	make("theme-biglake", music, false, 0)
	make("tension-bluewater", music, true, 0)
	make("frenzy-burst", music, false, 0.7)
	for _, name in { "thunder-far", "wind-gust", "buoy-bell", "server-horn", "goal-complete", "sell-coins", "line-snap", "breach-huge" } do
		make(name, fx, false, 0.8)
	end
	make("reel-click", fx, true, 0.45)
	for _, name in { "bite-nibble", "bite-tap", "bite-slam", "bite-deep-pull" } do
		make(name, fx, false, 1)
	end
	make("drag-zip", fx, false, 0.35)
	make("line-strain", fx, false, 0.6)
	make("thrash-splash", fx, false, 0.55)
	make("splash-small", fx, false, 0.7)
	make("splash-small", fx, false, 0.3, "plop")
	make("splash-small", fx, false, 0.12, "rise") -- a far-off fish rising: quiet
	make("splash-small", fx, false, 0.45, "snap")
	-- The wait (L4): existing sounds only (uploads are capped, audio/UPLOAD-PLAN.md).
	make("splash-small", fx, false, 0.1, "twitch-tick")
	make("splash-small", fx, false, 0.16, "far-splash")
	make("bite-deep-pull", fx, false, 0.45, "approach-swell")
	make("splash-big", fx, false, 0.85)
	for _, name in { "sting-common", "sting-uncommon", "sting-rare", "sting-epic", "sting-legendary", "sting-mythic", "sting-godlike", "sting-new-species", "sting-trophy", "sting-monster" } do
		make(name, fx, false, 1)
	end
	lastThemeEnd = os.clock() - THEME_GAP + FIRST_THEME_AFTER
	RunService.Heartbeat:Connect(function(dt)
		update(math.min(dt, 0.1))
	end)
end

return SoundFX
