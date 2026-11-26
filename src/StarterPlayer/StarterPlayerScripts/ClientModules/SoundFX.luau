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
local SoundMix = require(Shared.SoundMix)
local FishData = require(Shared.FishData)

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

local function group(name: string, volume: number): SoundGroup
	local g = Instance.new("SoundGroup")
	g.Name = "Fishing" .. name
	g.Volume = volume
	g.Parent = SoundService
	groups[name] = g
	return g
end

-- alias: a second copy of a sound under its own name (for its own volume and pitch).
local function make(name: string, g: SoundGroup, looped: boolean, volume: number, alias: string?): Sound?
	local id = SoundIds[name]
	if not id or id == "" then
		return nil
	end
	local key = alias or name
	local s = Instance.new("Sound")
	s.Name = key
	s.SoundId = id
	s.Looped = looped
	s.Volume = volume
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
	s.PlaybackSpeed = (speed or 1) * (if vary then rng:NextNumber(0.94, 1.06) else 1)
	s.TimePosition = 0
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
	-- While the line is in, everything else steps back a little: the held breath before a bite.
	local hush = if lineIn() then 0.6 elseif fighting() then 0.75 else 1
	local lake = SoundMix.lakeLevel(creek) * hush
	for id, w in SoundMix.lakeWeights(Lighting.ClockTime) do
		fadeTo(id, w * lake, 0.5, dt)
	end
	fadeTo("amb-creek", creek * hush, 0.6, dt)

	-- Music: one calm theme now and then, never while a line is in or a fish is on.
	local now = os.clock()
	local themeName = if creek > 0.5 then "theme-creek" else "theme-lake"
	local other = if themeName == "theme-lake" then "theme-creek" else "theme-lake"
	local theme = sounds[themeName]
	local busy = lineIn() or fighting()
	for _, name in { "theme-lake", "theme-creek" } do
		local s = sounds[name]
		if s and s.IsPlaying then
			local want = if busy or name == other then 0 elseif now < stingerUntil then 0.35 else 1
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
	fadeTo("wait-bobber-tick", if phase == "Waiting" then 0.2 else 0, 1.5, dt)
	-- The tension layer comes in during fights with heavy fish.
	fadeTo("tension-fight", if fighting() and bigFight then 0.8 else 0, 0.6, dt)
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
		local cls = fish and fish.sizeClass
		local sting = if (cls == "monster" or cls == "trophy") and sounds["sting-" .. cls]
			then "sting-" .. cls
			else SoundMix.stingerFor(species and (species :: any).tier)
		task.delay(0.35, function()
			play(sting)
		end)
		if payload and payload.first then
			task.delay(0.9, function()
				play("sting-new-species")
			end)
		end
	elseif kind == "Escaped" then
		play("splash-small", nil, nil, true)
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
	make("reel-click", fx, true, 0.45)
	for _, name in { "bite-nibble", "bite-tap", "bite-slam", "bite-deep-pull" } do
		make(name, fx, false, 1)
	end
	make("drag-zip", fx, false, 0.35)
	make("line-strain", fx, false, 0.6)
	make("thrash-splash", fx, false, 0.55)
	make("splash-small", fx, false, 0.7)
	make("splash-small", fx, false, 0.3, "plop")
	make("splash-small", fx, false, 0.45, "snap")
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
