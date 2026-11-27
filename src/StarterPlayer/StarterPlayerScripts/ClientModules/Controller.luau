--!strict
-- Client fishing flow and input. One "Fish" action on every device:
--   hold and release to cast, press on a bite to hook, hold to reel during the fight.
--   While waiting (L4): a quick tap (under Approach.TWITCH_TAP) twitches the bait, a hold
--   (Approach.REEL_HOLD or longer) reels the line back in; a tap never reels in. With live
--   bait and an empty hook, the press that would cast opens the bait bench first (L3,
--   BaitBench); the same button works it.
--   Working a lure (L4c, Config.LURE_RETRIEVE_ON): no bobber. Holding the button reels a
--   spinner, a short press hops a plastic worm (RetrieveView draws it); each press and
--   let-go goes to the server (remote "Reel"), which decides strikes.
--
-- From the bite until the fight ends, input is read straight from UserInputService, so a
-- click or touch ANYWHERE on screen (even over a panel or button) hooks and reels. Panels
-- can't open, the character stands still (so Space and gamepad A reel too), and after the
-- fight the button has to be let go and a short pause passes before it can cast again.
--
-- Drag (L4d): during a fight Q, gamepad Y or the small Drag button under the fight bar
-- cycles Light, Medium, Tight. The choice lasts the session (not saved). The first time the
-- line strains hard, a hint says to ease off.
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local FightModel = require(Shared.FightModel)
local Remotes = require(Shared.Remotes)
local CastLogic = require(Shared.CastLogic)
local FishLogic = require(Shared.FishLogic)
local WaterMap = require(Shared.WaterMap)
local Cover = require(Shared.Cover)
local BaitRig = require(Shared.BaitRig)
local BaitData = require(Shared.BaitData)
local Approach = require(Shared.Approach)
local FightFeel = require(Shared.FightFeel)
local Retrieve = require(Shared.Retrieve)

local UI = require(script.Parent.UI)
local PondView = require(script.Parent.PondView)
local TrophyWall = require(script.Parent.TrophyWall)
local SoundFX = require(script.Parent.SoundFX)
local CastRing = require(script.Parent.CastRing)
local RiseRipples = require(script.Parent.RiseRipples)
local BaitBench = require(script.Parent.BaitBench)
local BaitView = require(script.Parent.BaitView)
local WaitScene = require(script.Parent.WaitScene)
local BobberCamView = require(script.Parent.BobberCamView)
local RodFeel = require(script.Parent.RodFeel)
local CastFlight = require(script.Parent.CastFlight)
local FightTells = require(script.Parent.FightTells)
local CatchMoment = require(script.Parent.CatchMoment)
local RetrieveView = require(script.Parent.RetrieveView)

-- The same water and spot boxes the server casts against (Shared/WaterMap).
local castZones = WaterMap.castZones()
local castWaters = WaterMap.castWaters()

local Controller = {}

local state = "Idle" -- Idle, Baiting, Charging, Casting, Waiting, Retrieving, Snagged, Bite, Hooking, Fighting, Resolving
local stateSince = 0
local chargeStart = 0
local fight: FightModel.State? = nil
local snapshot: any = nil
local castTimeout = 0
local graceUntil = 0 -- after a fight: no new cast until this time...
local needRelease = false -- ...and until every reel input is let go
local heldInputs: { [InputObject]: boolean } = {}
local autoHolding = false
local savedMove: { walk: number, jumpPower: number, jumpHeight: number }? = nil
-- The live bait on the hook, as the server last said (L3). nil means an empty hook.
local rig: { bait: string, hook: string, grade: string }? = nil
local benchHeld: { [string]: boolean } = {} -- move inputs held down on the bait bench
-- A press of the Fish button while waiting (L4): when it went down, and whether it already
-- reeled in. Released quickly it's a twitch; held long enough it reels in.
local waitPressAt: number? = nil
local waitPressReeled = false
local landedAt: Vector3? = nil -- where the server put the bobber this cast (for the fight's tells, L4b)
-- Working a lure (L4c): the inputs holding the button down, the presses sent this cast (so a
-- press the server would refuse is never sent), and whether the last press went out.
local reelHeld: { [any]: boolean } = {}
local reelPresses: { Retrieve.Press } = {}
local reelSent = false
-- Line and drag (L4d): this session's drag, the hooked rod's line rating, whether the
-- first-time "ease off" hint has shown, and pointer presses that landed on the Drag button.
local dragChoice: FightModel.Drag = "Medium"
local fightLineLb: number? = nil
local strainHinted = false
local dragPointers: { [InputObject]: boolean } = {}
local STRAIN_HINT_AT = 0.4

-- Inputs that count as "reel" during a bite or fight, on every device.
local REEL_TYPES = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.Touch] = true,
}
local REEL_KEYS = {
	[Enum.KeyCode.ButtonR2] = true,
	[Enum.KeyCode.ButtonA] = true,
	[Enum.KeyCode.ButtonR1] = true,
	[Enum.KeyCode.Space] = true,
	[Enum.KeyCode.F] = true,
}

local sounds: { [string]: Sound } = {}
local SOUND_IDS = {
	cast = "rbxasset://sounds/swoosh.wav",
	catch = "rbxasset://sounds/collide.wav",
	click = "rbxasset://sounds/button.wav",
}

local function play(name: string)
	local s = sounds[name]
	if s then
		s:Play()
	end
end

-- Play an uploaded sound by its id from audio/README.md (Shared/SoundIds.luau); falls back to
-- a built-in sound until it's uploaded. UNVERIFIED in Studio (2026-11-26).
local SoundIds = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SoundIds"))
local uploaded: { [string]: Sound } = {}
local function playId(id: string, fallback: string?)
	local asset = SoundIds[id]
	if type(asset) == "string" and asset ~= "" then
		local s = uploaded[id]
		if not s then
			s = Instance.new("Sound")
			s.Name = "Fish_" .. id
			s.SoundId = asset
			s.Volume = 0.6
			s.Parent = SoundService
			uploaded[id] = s
		end
		s:Play()
	elseif fallback then
		play(fallback)
	end
end

local function setState(s: string)
	state = s
	stateSince = os.clock()
	SoundFX.setPhase(s)
end

local function isReelInput(input: InputObject): boolean
	return REEL_TYPES[input.UserInputType] == true or REEL_KEYS[input.KeyCode] == true
end

local function anyHeld(): boolean
	return next(heldInputs) ~= nil
end

local function holding(): boolean
	return anyHeld() or autoHolding
end

-- Studio-only test hook: when DebugAutoFish is set on the player, the client presses the
-- button on a bite and reels perfectly, through the same paths as real input.
local function autoFish(): boolean
	return RunService:IsStudio() and Players.LocalPlayer:GetAttribute("DebugAutoFish") == true
end

-- Keep the character still while a fish is on, so jump and move keys can't interfere.
local function freezeCharacter(on: boolean)
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if on and not savedMove then
		savedMove = { walk = hum.WalkSpeed, jumpPower = hum.JumpPower, jumpHeight = hum.JumpHeight }
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.JumpHeight = 0
	elseif not on and savedMove then
		hum.WalkSpeed = savedMove.walk
		hum.JumpPower = savedMove.jumpPower
		hum.JumpHeight = savedMove.jumpHeight
		savedMove = nil
	end
end

local function idleStatus()
	UI.status("Face the water. Hold " .. UI.inputName() .. " and let go to cast.")
end

-- What a press does while waiting (L4).
local function waitHint(): string
	return "Tap: twitch. Hold: reel in." -- short: the status line is one line on a phone
end

-- Next drag setting (L4d). Only during a fight; the setting stays for later fights.
local function cycleDrag()
	if state ~= "Fighting" or not fight then
		return
	end
	dragChoice = FightModel.nextDrag(dragChoice)
	FightModel.setDrag(fight :: FightModel.State, dragChoice)
	UI.showDrag(dragChoice, fightLineLb)
	play("click")
end

local function endFishOn()
	UI.setLocked(false)
	freezeCharacter(false)
	autoHolding = false
end

local function goIdle()
	BaitBench.cancel()
	waitPressAt = nil
	RetrieveView.stop()
	table.clear(reelHeld)
	reelSent = false
	WaitScene.clear()
	CastFlight.cancel()
	FightTells.stop()
	setState("Idle")
	fight = nil
	endFishOn()
	UI.bite(false)
	UI.showPower(nil)
	CastRing.hide()
	UI.showFight(nil)
	idleStatus()
end

-- After a fight: ignore the button until it is released and a short pause has passed.
local function goIdleAfterFight()
	goIdle()
	graceUntil = os.clock() + Config.FIGHT_GRACE
	needRelease = anyHeld()
end

-- The rod and bait this cast uses, from the last state the server sent.
local function castGear(): (string?, string?)
	if snapshot then
		return snapshot.rod, snapshot.equipped
	end
	return nil, nil
end

-- How the bait or lure on the hook went on: the rig's grade, or Okay when nothing is rigged
-- yet (the server ties it on Okay at the cast). Same rule as the server's onCast.
local function rigGrade(bait: string?): string
	local r = rig
	if r and bait and r.bait == bait then
		return r.grade
	end
	return "Okay"
end

-- Power rises and falls while held (the ring travels out and back), see CastLogic.powerAt.
-- A spinner knot tied Okay casts a little shorter (BaitRig.castScale, L3b).
local function chargePower(): number
	local rod, bait = castGear()
	return CastLogic.powerAt(os.clock() - chargeStart, rod, bait, BaitRig.castScale(bait, rigGrade(bait)))
end

-- Where a cast at this power would land, worked out exactly the way the server does it.
-- Returns the raw landing (for drawing), the landing after near-miss help (nil over dry
-- ground) and the rod tip the arc starts from.
local function predictCast(power: number): (Vector3?, Vector3?, Vector3?)
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return nil, nil, nil
	end
	local rod, bait = castGear()
	local origin = hrp.Position
	local flat = workspace.CurrentCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.01 then
		flat = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	local raw = CastLogic.landing(origin, flat, power, rod, bait, BaitRig.castScale(bait, rigGrade(bait)))
	if not raw then
		return nil, nil, nil
	end
	local assisted = CastLogic.assist(raw, origin, castWaters, FishLogic.isOnWaterAny)
	local rodPart = if char then char:FindFirstChild("Rod") else nil
	local tipAtt = if rodPart then rodPart:FindFirstChild("RodTip") else nil
	local tip = if tipAtt and tipAtt:IsA("Attachment") then tipAtt.WorldPosition else origin + Vector3.new(0, 4, 0) + flat.Unit
	return raw, assisted, tip
end

local function spotLabel(point: Vector3): string
	local name = FishLogic.SPOT_NAMES[FishLogic.spotAt(point, castZones)] or "open water"
	return name:sub(1, 1):upper() .. name:sub(2)
end

local function drawRing(power: number)
	local raw, assisted, tip = predictCast(power)
	if not raw or not tip then
		CastRing.hide()
		return
	end
	if assisted then
		-- Amber over a snag: right on a log, or deep in the weeds without a weedless rig (only
		-- a Perfect plastic worm is, L3b).
		local _, bait = castGear()
		local snag = Cover.snagAt(assisted, bait, rigGrade(bait))
		CastRing.setSnag(snag)
		CastRing.update(tip, assisted, true, spotLabel(assisted) .. (if snag then " (snag)" else ""))
	else
		CastRing.setSnag(false)
		CastRing.update(tip, raw, false, "Dry ground")
	end
end

----------------------------------------------------------------------------------------
-- The bait bench (L3)

-- The bench opens when you go to cast with live bait, the hook is empty (or tied on a
-- different bait or hook size), and Quick Bait is off. A lure (L3b) is tied once: the bench
-- opens only when it isn't the one tied on (you switched to it, its line snapped, or it's
-- the first cast with it this visit). Hook size doesn't matter for a lure.
local function needsBench(): boolean
	if not snapshot or snapshot.quickBait then
		return false
	end
	local id = snapshot.equipped
	local b = BaitData.byId[id]
	if not b or not BaitRig.recipeFor(id) then
		return false
	end
	local r = rig
	if b.kind == "lure" then
		return snapshot.lures[id] == true and not (r and r.bait == id)
	end
	if (snapshot.bait[id] or 0) <= 0 then
		return false
	end
	return not (r and r.bait == id and r.hook == (snapshot.hook or BaitRig.DEFAULT_HOOK))
end

-- What's on the hook right now, for the bait shown at the rod tip.
local function onHookNow(): string?
	if not snapshot then
		return nil
	end
	local b = BaitData.byId[snapshot.equipped]
	if b and b.kind == "lure" then
		return if snapshot.lures[b.id] then b.id else nil
	end
	local r = rig
	if r and b and r.bait == b.id then
		return r.bait
	end
	return nil
end

local function onBenchDone(result: BaitBench.Result)
	Remotes.event("Rig"):FireServer(result.bait, result.hook, result.timeline, result.skipped)
	rig = { bait = result.bait, hook = result.hook, grade = result.grade } -- until the server answers
	table.clear(benchHeld)
	goIdle()
	graceUntil = os.clock() + 0.3
	needRelease = anyHeld()
	local lure = BaitData.byId[result.bait] and BaitData.byId[result.bait].kind == "lure"
	UI.status(string.format("%s (%s). Hold %s and let go to cast.", if lure then "Lure on" else "Bait on", result.grade, UI.inputName()))
end

local function openBench()
	local id = snapshot.equipped
	setState("Baiting")
	table.clear(benchHeld)
	UI.setLocked(true)
	freezeCharacter(true)
	CastRing.hide()
	UI.status("")
	local learned = snapshot.tackle and snapshot.tackle.best and snapshot.tackle.best[id]
	BaitBench.open({
		bait = id,
		hook = snapshot.hook or BaitRig.DEFAULT_HOOK,
		firstTime = learned == nil,
		auto = autoFish(),
		onDone = onBenchDone,
	})
end

-- One move input went down or up on the bench. Several inputs held at once count as one press.
local function benchDown(key: string)
	local was = next(benchHeld) ~= nil
	benchHeld[key] = true
	if not was then
		BaitBench.press()
	end
end

local function benchUp(key: string)
	if not benchHeld[key] then
		return
	end
	benchHeld[key] = nil
	if next(benchHeld) == nil then
		BaitBench.release()
	end
end

----------------------------------------------------------------------------------------
-- Working a lure (L4c)

-- The button went down or up while working a lure. Several inputs held at once count as one
-- press. Each press goes to the model on this screen at once and to the server, stamped with
-- the seconds since the lure landed; one the server would refuse (too quick) isn't sent.
local function reelInput(key: any, down: boolean)
	local was = next(reelHeld) ~= nil
	if down then
		reelHeld[key] = true
	else
		reelHeld[key] = nil
	end
	local now = next(reelHeld) ~= nil
	if was == now then
		return
	end
	local t = RetrieveView.elapsed()
	local kind = if now then "down" else "up"
	if kind == "up" and not reelSent then
		return -- its down was never sent
	end
	if Retrieve.acceptEvent(reelPresses, kind, t) then
		reelSent = false
		return
	end
	Retrieve.addEvent(reelPresses, kind, t)
	reelSent = kind == "down"
	if kind == "down" then
		RetrieveView.press(t)
	else
		RetrieveView.release(t)
	end
	Remotes.event("Reel"):FireServer(kind, t)
end

-- What to do with a worked lure, for the status line (short: one line on a phone).
local function retrieveHint(lure: string): string
	if lure == "Spinner" then
		return "Hold to reel. Keep it green."
	end
	return "Tap to hop it, then let it fall."
end

-- Studio test hook (DebugAutoFish): work the lure the way Retrieve.wellTimeline does.
local autoReel: { Retrieve.Press }? = nil
local function autoWork()
	local lure = RetrieveView.lure()
	if not lure then
		return
	end
	if not autoReel then
		autoReel = Retrieve.wellTimeline(lure, Retrieve.MAX_TIME)
	end
	local t = RetrieveView.elapsed()
	local want = false
	for _, p in autoReel :: { Retrieve.Press } do
		if p.down > t then
			break
		end
		if t < (p.up :: number) then
			want = true
			break
		end
	end
	if want ~= (reelHeld.auto == true) then
		reelInput("auto", want)
	end
end

local function hook()
	if state ~= "Bite" then
		return
	end
	setState("Hooking")
	UI.bite(false)
	Remotes.event("Hook"):FireServer()
end

-- Casting and reeling back in (Idle, Charging, Waiting). Bite and fight input is handled by
-- onReelInput below; this path only hooks as a fallback.
local function onFish(_name: string, inputState: Enum.UserInputState, _input: InputObject?): Enum.ContextActionResult
	local began = inputState == Enum.UserInputState.Begin
	local ended = inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel
	if state == "Bite" and began then
		hook()
		return Enum.ContextActionResult.Sink
	end
	if state == "Baiting" then
		-- Mouse, F and R2 reach the bench through onReelInput; only the touch Fish button
		-- (no input object) comes this way.
		if _input == nil then
			if began then
				benchDown("button")
			elseif ended then
				benchUp("button")
			end
		end
		return Enum.ContextActionResult.Sink
	end
	if UI.isPanelOpen() then
		return Enum.ContextActionResult.Pass
	end
	if state == "Idle" and began then
		if os.clock() < graceUntil or needRelease then
			return Enum.ContextActionResult.Sink
		end
		if needsBench() then
			openBench()
			return Enum.ContextActionResult.Sink
		end
		CatchMoment.cancel()
		setState("Charging")
		chargeStart = os.clock()
		UI.showPower(0)
		drawRing(0)
		UI.status("Let go when the ring is where you want")
	elseif state == "Charging" and ended then
		local power = chargePower()
		local _, predicted = predictCast(power)
		UI.showPower(nil)
		CastRing.hide()
		setState("Casting")
		castTimeout = os.clock() + 3
		local cam = workspace.CurrentCamera
		Remotes.event("Cast"):FireServer(cam.CFrame.LookVector, power, predicted)
		-- The cast's feel (L4b): the rod swings back and whips forward, then the bobber flies
		-- the landing ring's arc and plops in (CastFlight).
		RodFeel.swing()
		if predicted then
			-- A worked lure (L4c) flies instead of the bobber.
			local _, bait = castGear()
			local lureLook = if Config.LURE_RETRIEVE_ON and Retrieve.isLure(bait) then BaitData.byId[bait :: string].color else nil
			CastFlight.start(predicted, FightFeel.releaseTime(), lureLook)
		end
		playId("cast-whoosh", "cast")
		UI.status("Casting...")
	elseif state == "Waiting" and began and os.clock() - stateSince > 0.6 then
		-- Tap or hold? Decided on release (a tap) or in the frame loop (a hold).
		waitPressAt = os.clock()
		waitPressReeled = false
	elseif state == "Waiting" and ended and waitPressAt then
		local held = os.clock() - (waitPressAt :: number)
		local reeled = waitPressReeled
		waitPressAt = nil
		if not reeled and Approach.pressKind(held, true) == "twitch" then
			WaitScene.twitch()
			Remotes.event("Twitch"):FireServer()
		end
	elseif state == "Retrieving" and (began or ended) then
		-- Hold reels a spinner, a short press hops a worm (L4c): mouse, F, R2 and the touch
		-- button all come this way, the same path the wait's tap and hold use.
		local key: any = if _input then _input.UserInputType.Name .. ":" .. _input.KeyCode.Name else "button"
		reelInput(key, began)
	elseif state == "Snagged" and began then
		Remotes.event("Wiggle"):FireServer() -- the server ignores presses too close together
	end
	return Enum.ContextActionResult.Sink
end

-- Global input: counts held reel inputs everywhere on screen, whatever is under the cursor.
local function onReelInput(input: InputObject, began: boolean)
	if not isReelInput(input) then
		return
	end
	-- A tap or click on the Drag button changes the drag; it isn't a reel press (L4d).
	if began and state == "Fighting" and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and UI.overDragButton(input.Position) then
		dragPointers[input] = true
		return
	end
	if not began and dragPointers[input] then
		dragPointers[input] = nil
		return
	end
	if state == "Baiting" then
		local key = input.UserInputType.Name .. ":" .. input.KeyCode.Name
		if began then
			local pointer = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
			if not (pointer and BaitBench.overButton(input.Position)) then
				benchDown(key) -- a click on a hook button or Skip is not a move
			end
		else
			benchUp(key)
		end
	end
	if began then
		heldInputs[input] = true
		if state == "Bite" then
			hook()
		elseif state == "Fighting" and fight then
			FightModel.press(fight)
		end
	else
		heldInputs[input] = nil
		-- Touch and some mouse paths end with a new InputObject; drop stale entries of that type.
		for other in heldInputs do
			if other.UserInputType == input.UserInputType and other.KeyCode == input.KeyCode then
				heldInputs[other] = nil
			end
		end
		if not anyHeld() then
			needRelease = false
		end
	end
end

local function onFishingEvent(kind: string, payload: any)
	-- The flying bobber (L4b): the server's landing point corrects its target; a bite or a
	-- fish lands it at once; a refused cast drops it. While it flies, the landing's plop and
	-- ripple wait for its touchdown.
	if kind == "Landed" and typeof(payload.pos) == "Vector3" then
		landedAt = payload.pos
		CastFlight.land(payload.pos)
		payload.inFlight = CastFlight.flying()
	elseif kind == "Bite" or kind == "Hooked" or kind == "Snag" then
		CastFlight.finish()
	elseif kind == "Hint" or kind == "Reset" then
		CastFlight.cancel()
	end
	SoundFX.event(kind, payload)
	local retrieving = kind == "Landed" and type(payload.retrieve) == "string"
	if not retrieving then
		WaitScene.event(kind, payload)
	end
	if retrieving then
		-- A worked lure (L4c): no bobber, no bobber camera; you work it back.
		setState("Retrieving")
		waitPressAt = nil
		table.clear(reelHeld)
		table.clear(reelPresses)
		reelSent = false
		autoReel = nil
		RetrieveView.start(payload)
		UI.status(
			"At "
				.. tostring(payload.spotName)
				.. "."
				.. (if payload.tight then " Near cover." else "")
				.. " "
				.. retrieveHint(payload.retrieve)
		)
		if payload.rise then
			UI.toast("Right on the rise!", Color3.fromRGB(120, 200, 255))
		end
	elseif kind == "Retrieved" then
		goIdle()
	elseif kind == "Landed" then
		setState("Waiting")
		waitPressAt = nil
		if typeof(payload.pos) == "Vector3" then
			BobberCamView.engage(payload.pos)
		end
		UI.status(
			"At "
				.. tostring(payload.spotName)
				.. "."
				.. (if payload.tight then " Near cover." else "")
				.. " "
				.. waitHint()
		)
		if payload.rise then
			UI.toast("Right on the rise!", Color3.fromRGB(120, 200, 255))
		end
	elseif kind == "Rise" then
		if typeof(payload.pos) == "Vector3" then
			RiseRipples.show(payload.pos)
		end
	elseif kind == "Snag" then
		setState("Snagged")
		UI.toast("Snagged! Tap to wiggle it free", Color3.fromRGB(255, 180, 40))
		UI.status(string.format("Snagged! Press %s again and again to wiggle it free.", UI.inputName()))
	elseif kind == "Wiggled" then
		UI.status(string.format("Wiggling... %d of %d. Keep going!", payload.count or 0, payload.need or Cover.SNAG_WIGGLES))
	elseif kind == "Freed" or kind == "Snapped" then
		UI.toast(payload.text)
		goIdle()
	elseif kind == "Bite" then
		waitPressAt = nil
		if payload and payload.lure then
			-- A strike on the worked lure (L4c): the rod thumps (the sound is the bite cue).
			RetrieveView.strike(if typeof(payload.pos) == "Vector3" then payload.pos else nil)
			if typeof(payload.pos) == "Vector3" then
				landedAt = payload.pos
			end
		end
		setState("Bite")
		UI.closePanels()
		UI.setLocked(true)
		freezeCharacter(true)
		UI.bite(true)
		local how = if payload and payload.lure then "Strike! " elseif payload and payload.style == "pull" then "It's pulling the bobber under! " elseif payload and payload.style == "slam" then "Wham! " else "Bite! "
		UI.status(how .. "Press " .. UI.inputName() .. " now!")
	elseif kind == "Missed" and payload and payload.ended then
		UI.toast(payload.text) -- a worked lure's strike was missed: the cast is over (L4c)
		goIdle()
	elseif kind == "Missed" then
		setState("Waiting")
		endFishOn()
		UI.bite(false)
		UI.toast(payload.text)
		UI.status("Waiting for another bite... " .. waitHint())
	elseif kind == "Hooked" then
		setState("Fighting")
		UI.closePanels()
		UI.setLocked(true)
		freezeCharacter(true)
		-- Studio test hook: a DebugDrag attribute ("Light", "Medium" or "Tight") sets the drag.
		local forcedDrag = if RunService:IsStudio() then Players.LocalPlayer:GetAttribute("DebugDrag") else nil
		if FightModel.isDrag(forcedDrag) then
			dragChoice = forcedDrag :: FightModel.Drag
		end
		fightLineLb = if type(payload.lineLb) == "number" then payload.lineLb else nil
		fight = FightModel.new(payload.fight, payload.assist, payload.seed, payload.start, payload.load, dragChoice)
		if anyHeld() then
			FightModel.press(fight :: FightModel.State)
		end
		CatchMoment.cancel()
		FightTells.begin(payload.fight and payload.fight.style, landedAt)
		UI.status("") -- the reel prompt says what to do; keeps small screens clear
		UI.showFight(fight, payload.note, holding())
		UI.showDrag(dragChoice, fightLineLb)
		if payload.sizeClass == "monster" then
			UI.toast("Something HUGE is on the line!", Color3.fromRGB(240, 75, 125))
		elseif payload.sizeClass == "trophy" then
			UI.toast("This one feels big!", Color3.fromRGB(250, 175, 40))
		end
	elseif kind == "Caught" then
		UI.catchCard(payload)
		goIdleAfterFight()
		CatchMoment.play(payload) -- a trophy or monster: hold it up for the camera (L4b)
	elseif kind == "Escaped" then
		UI.toast(payload.text)
		goIdleAfterFight()
	elseif kind == "Rigged" then
		rig = { bait = payload.bait, hook = payload.hook, grade = payload.grade }
		if payload.kept then
			UI.toast("Perfect bait! It stayed on the hook.", Color3.fromRGB(250, 205, 80))
		elseif payload.refused then
			UI.toast("Bait on: Okay.")
		end
	elseif kind == "RigEmpty" then
		rig = nil
	elseif kind == "Reset" then
		goIdle()
	elseif kind == "Hint" then
		UI.toast(payload.text)
		if state == "Casting" or state == "Charging" then
			goIdle()
		end
	end
end

-- The creek gate opens only on the screen of a player who owns the Creek Pass.
local function updateCreekGate(s: any)
	local lake = workspace:FindFirstChild("Lake")
	local gate = lake and lake:FindFirstChild("CreekGate", true) :: BasePart?
	local prompt = lake and lake:FindFirstChild("CreekPrompt", true) :: ProximityPrompt?
	if gate then
		gate.CanCollide = not s.creekPass
		-- Open means gone (it was 0.85, a faint grey pane in the arch the critic kept naming).
		gate.Transparency = if s.creekPass then 1 else 0
	end
	if prompt then
		prompt.Enabled = not s.creekPass
	end
end

local function cycleBait()
	if not snapshot then
		return
	end
	local BaitData = require(Shared.BaitData)
	local usable = {}
	for _, b in BaitData.list do
		local has = if b.kind == "lure" then snapshot.lures[b.id] == true else (snapshot.bait[b.id] or 0) > 0
		if has then
			table.insert(usable, b.id)
		end
	end
	if #usable == 0 then
		UI.toast("No bait. Visit Bait and Tackle.")
		return
	end
	local idx = table.find(usable, snapshot.equipped) or 0
	local nextId = usable[(idx % #usable) + 1]
	Remotes.event("Equip"):FireServer(nextId)
	play("click")
end

function Controller.start()
	SoundFX.start()
	RodFeel.start()
	BobberCamView.start(function()
		return state
	end)
	for name, id in SOUND_IDS do
		local s = Instance.new("Sound")
		s.Name = "Fish_" .. name
		s.SoundId = id
		s.Volume = 0.6
		s.Parent = SoundService
		sounds[name] = s
	end

	UI.init({
		-- The touch Fish button. During a bite or fight the global input path already
		-- handles the touch, so this only casts and reels in.
		fishDown = function()
			if state ~= "Fighting" then
				onFish("Fish", Enum.UserInputState.Begin, nil)
			end
		end,
		fishUp = function()
			if state ~= "Fighting" then
				onFish("Fish", Enum.UserInputState.End, nil)
			end
		end,
		cycleBait = function()
			if not UI.isLocked() then
				cycleBait()
			end
		end,
		cycleDrag = function()
			cycleDrag()
		end,
		toggleJournal = function()
			UI.toggleJournal()
		end,
		toggleAssist = function()
			if snapshot then
				Remotes.event("SetAssist"):FireServer(not snapshot.assist)
			end
		end,
		toggleQuickBait = function()
			if snapshot then
				Remotes.event("SetQuickBait"):FireServer(not snapshot.quickBait)
			end
		end,
		setHook = function(size: string)
			-- Only the hook size: the bait comes off, so the next cast baits up again.
			Remotes.event("Rig"):FireServer("", size, {}, true)
			play("click")
		end,
		pond = function(action: string, index: number)
			local ok, msg = Remotes.func("PondAction"):InvokeServer(action, index)
			UI.toast(msg, if ok then Color3.fromRGB(120, 220, 130) else Color3.fromRGB(240, 120, 110))
			if ok then
				play("click")
			end
		end,
		buyRod = function(rodId: string)
			local ok, msg = Remotes.func("BuyRod"):InvokeServer(rodId)
			UI.toast(msg, if ok then Color3.fromRGB(120, 220, 130) else Color3.fromRGB(240, 120, 110))
			UI.shopHint(msg)
			if ok then
				play("catch")
			end
		end,
		buyBoat = function(boatId: string) -- UNVERIFIED in Studio (2026-11-26)
			local ok, msg = Remotes.func("BuyBoat"):InvokeServer(boatId)
			UI.toast(msg, if ok then Color3.fromRGB(120, 220, 130) else Color3.fromRGB(240, 120, 110))
			UI.shopHint(msg)
			if ok then
				play("catch")
			end
		end,
		chooseBoat = function(boatId: string)
			Remotes.event("ChooseBoat"):FireServer(boatId)
			play("click")
		end,
		equipRod = function(rodId: string)
			Remotes.event("EquipRod"):FireServer(rodId)
			play("click")
		end,
		buy = function(baitId: string)
			local ok, msg = Remotes.func("Buy"):InvokeServer(baitId)
			UI.toast(msg, if ok then Color3.fromRGB(120, 220, 130) else Color3.fromRGB(240, 120, 110))
			UI.shopHint(msg)
			if ok then
				play("click")
			end
		end,
	})

	Remotes.event("State").OnClientEvent:Connect(function(s)
		snapshot = s
		UI.setState(s)
		PondView.update(s.pond)
		TrophyWall.update(s)
		updateCreekGate(s)
	end)
	Remotes.event("FishingEvent").OnClientEvent:Connect(onFishingEvent)
	Remotes.event("Toast").OnClientEvent:Connect(function(text)
		UI.toast(text)
	end)
	task.spawn(function()
		local s = Remotes.func("RequestState"):InvokeServer()
		if s then
			snapshot = s
			UI.setState(s)
			PondView.update(s.pond)
			TrophyWall.update(s)
			updateCreekGate(s)
		end
	end)

	-- Casting on mouse, F key and gamepad R2. Touch uses the big Fish button in the UI.
	ContextActionService:BindAction("Fish", onFish, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)

	-- Reeling: every click, tap or reel button anywhere, even over the UI (gameProcessed ignored).
	UserInputService.InputBegan:Connect(function(input)
		onReelInput(input, true)
	end)
	UserInputService.InputEnded:Connect(function(input)
		onReelInput(input, false)
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		table.clear(heldInputs)
	end)

	ContextActionService:BindAction("Journal", function(_, st)
		if st == Enum.UserInputState.Begin and not UI.isLocked() then
			UI.toggleJournal()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.J, Enum.KeyCode.ButtonY)
	-- Drag during a fight (L4d): Q or gamepad Y. Bound after the journal so Y reaches it first
	-- while a fish is on; otherwise Y passes through to the journal.
	ContextActionService:BindAction("Drag", function(_, st)
		if state ~= "Fighting" then
			return Enum.ContextActionResult.Pass
		end
		if st == Enum.UserInputState.Begin then
			cycleDrag()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonY)
	ContextActionService:BindAction("CycleBait", function(_, st)
		if st == Enum.UserInputState.Begin and not UI.isPanelOpen() and not UI.isLocked() then
			cycleBait()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.B, Enum.KeyCode.DPadRight)
	ContextActionService:BindAction("ClosePanels", function(_, st)
		if UI.isPanelOpen() then
			if st == Enum.UserInputState.Begin then
				UI.closePanels()
			end
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
	-- On the bait bench: the next hook size (gamepad L1 or X, keyboard H).
	ContextActionService:BindAction("BenchHook", function(_, st)
		if state == "Baiting" then
			if st == Enum.UserInputState.Begin then
				BaitBench.cycleHook()
			end
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonX, Enum.KeyCode.H)

	-- The shop opens from its stand's prompt (the server hands out free worms if you're stuck).
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
		if prompt.Name == "ShopPrompt" and not UI.isLocked() then
			UI.openShop()
		elseif prompt.Name == "PondPrompt" and not UI.isLocked() then
			UI.openPond()
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		UI.setClock(Lighting.ClockTime)
		BaitBench.step()
		BaitView.update(onHookNow(), state)
		if state == "Baiting" and not BaitBench.isOpen() then
			goIdle() -- the bench closed without finishing (should not happen)
		end
		WaitScene.step(state, dt)
		if state == "Retrieving" then
			if autoFish() then
				autoWork()
			end
			RetrieveView.step(dt, CastFlight.flying())
			if RetrieveView.finished() and next(reelHeld) == nil then
				UI.status("Here it comes...")
			end
			if RetrieveView.elapsed() > Retrieve.MAX_TIME + 5 then
				goIdle() -- the server never ended the cast; don't leave the player stuck
			end
		end
		-- Holding the Fish button while waiting reels the line in (a tap twitches instead).
		if state == "Waiting" and waitPressAt and not waitPressReeled then
			if Approach.pressKind(os.clock() - (waitPressAt :: number), false) == "reel" then
				waitPressReeled = true
				Remotes.event("CancelCast"):FireServer()
				UI.status("Reeling in...")
			end
		end
		if state == "Charging" then
			local power = chargePower()
			UI.showPower(power)
			drawRing(power)
		elseif state == "Casting" and os.clock() > castTimeout then
			goIdle()
		elseif state == "Bite" and autoFish() then
			hook()
		elseif (state == "Hooking" or state == "Resolving") and os.clock() - stateSince > 4 then
			goIdle() -- the server never answered; don't leave the player stuck
		elseif state == "Snagged" and os.clock() - stateSince > Cover.SNAG_TIME + 3 then
			goIdle() -- the server never said how the snag ended
		elseif state == "Fighting" and fight then
			if autoFish() then
				local want = fight.zonePos < fight.fishPos or fight.idle > Config.FIGHT_IDLE_GRACE * 0.8 -- tap before the line goes slack
				if fight.strain > 0.25 then
					want = false -- ease off when the line strains (L4d)
				end
				if want and not autoHolding then
					FightModel.press(fight)
				end
				autoHolding = want
			end
			local hold = holding()
			local result = FightModel.step(fight, math.min(dt, 0.1), hold)
			UI.showFight(fight, nil, hold, FightModel.slack(fight))
			SoundFX.fight(fight, hold, dt)
			SoundFX.strain(fight.strain)
			FightTells.step(fight, math.min(dt, 0.1))
			if fight.strain >= STRAIN_HINT_AT and not strainHinted then
				strainHinted = true -- first time this session only
				UI.toast("Big fish running! Ease off.", Color3.fromRGB(255, 150, 40))
			end
			if result then
				setState("Resolving")
				UI.showFight(nil)
				Remotes.event("FightResult"):FireServer(result, { tight = fight.usedTight, drag = fight.drag })
			end
		end
	end)

	goIdle()
end

return Controller
