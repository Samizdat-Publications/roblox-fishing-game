--!strict
-- Client fishing flow and input. One "Fish" action on every device:
--   hold and release to cast, press on a bite to hook, hold to reel during the fight,
--   press while waiting to reel back in.
--
-- From the bite until the fight ends, input is read straight from UserInputService, so a
-- click or touch ANYWHERE on screen (even over a panel or button) hooks and reels. Panels
-- can't open, the character stands still (so Space and gamepad A reel too), and after the
-- fight the button has to be let go and a short pause passes before it can cast again.
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

local UI = require(script.Parent.UI)
local PondView = require(script.Parent.PondView)

local Controller = {}

local state = "Idle" -- Idle, Charging, Casting, Waiting, Bite, Hooking, Fighting, Resolving
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
	splash = "rbxasset://sounds/impact_water.mp3",
	bite = "rbxasset://sounds/electronicpingshort.wav",
	catch = "rbxasset://sounds/collide.wav",
	click = "rbxasset://sounds/button.wav",
}

local function play(name: string)
	local s = sounds[name]
	if s then
		s:Play()
	end
end

local function setState(s: string)
	state = s
	stateSince = os.clock()
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

local function endFishOn()
	UI.setLocked(false)
	freezeCharacter(false)
	autoHolding = false
end

local function goIdle()
	setState("Idle")
	fight = nil
	endFishOn()
	UI.bite(false)
	UI.showPower(nil)
	UI.showFight(nil)
	idleStatus()
end

-- After a fight: ignore the button until it is released and a short pause has passed.
local function goIdleAfterFight()
	goIdle()
	graceUntil = os.clock() + Config.FIGHT_GRACE
	needRelease = anyHeld()
end

local function chargePower(): number
	return math.clamp((os.clock() - chargeStart) / Config.CHARGE_TIME, 0, 1)
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
	if UI.isPanelOpen() then
		return Enum.ContextActionResult.Pass
	end
	if state == "Idle" and began then
		if os.clock() < graceUntil or needRelease then
			return Enum.ContextActionResult.Sink
		end
		setState("Charging")
		chargeStart = os.clock()
		UI.showPower(0)
		UI.status("Let go to cast")
	elseif state == "Charging" and ended then
		local power = chargePower()
		UI.showPower(nil)
		setState("Casting")
		castTimeout = os.clock() + 3
		local cam = workspace.CurrentCamera
		Remotes.event("Cast"):FireServer(cam.CFrame.LookVector, power)
		play("cast")
		UI.status("Casting...")
	elseif state == "Waiting" and began and os.clock() - stateSince > 0.6 then
		Remotes.event("CancelCast"):FireServer()
		UI.status("Reeling in...")
	end
	return Enum.ContextActionResult.Sink
end

-- Global input: counts held reel inputs everywhere on screen, whatever is under the cursor.
local function onReelInput(input: InputObject, began: boolean)
	if not isReelInput(input) then
		return
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
	if kind == "Landed" then
		setState("Waiting")
		play("splash")
		UI.status("Waiting for a bite at " .. tostring(payload.spotName) .. "...")
	elseif kind == "Bite" then
		setState("Bite")
		play("bite")
		UI.closePanels()
		UI.setLocked(true)
		freezeCharacter(true)
		UI.bite(true)
		local how = if payload and payload.style == "pull" then "It's pulling the bobber under! " elseif payload and payload.style == "slam" then "Wham! " else "Bite! "
		UI.status(how .. "Press " .. UI.inputName() .. " now!")
	elseif kind == "Missed" then
		setState("Waiting")
		endFishOn()
		UI.bite(false)
		UI.toast(payload.text)
		UI.status("Waiting for another bite...")
	elseif kind == "Hooked" then
		setState("Fighting")
		UI.closePanels()
		UI.setLocked(true)
		freezeCharacter(true)
		fight = FightModel.new(payload.fight, payload.assist, payload.seed)
		if anyHeld() then
			FightModel.press(fight :: FightModel.State)
		end
		UI.status("") -- the reel prompt says what to do; keeps small screens clear
		UI.showFight(fight, payload.note, holding())
	elseif kind == "Caught" then
		play("catch")
		UI.catchCard(payload)
		goIdleAfterFight()
	elseif kind == "Escaped" then
		UI.toast(payload.text)
		goIdleAfterFight()
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
		gate.Transparency = if s.creekPass then 0.85 else 0
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
		toggleJournal = function()
			UI.toggleJournal()
		end,
		toggleAssist = function()
			if snapshot then
				Remotes.event("SetAssist"):FireServer(not snapshot.assist)
			end
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
		if state == "Charging" then
			UI.showPower(chargePower())
		elseif state == "Casting" and os.clock() > castTimeout then
			goIdle()
		elseif state == "Bite" and autoFish() then
			hook()
		elseif (state == "Hooking" or state == "Resolving") and os.clock() - stateSince > 4 then
			goIdle() -- the server never answered; don't leave the player stuck
		elseif state == "Fighting" and fight then
			if autoFish() then
				local want = fight.zonePos < fight.fishPos or fight.idle > 2 -- tap before the line goes slack
				if want and not autoHolding then
					FightModel.press(fight)
				end
				autoHolding = want
			end
			local hold = holding()
			local result = FightModel.step(fight, math.min(dt, 0.1), hold)
			UI.showFight(fight, nil, hold, FightModel.slack(fight))
			if result then
				setState("Resolving")
				UI.showFight(nil)
				Remotes.event("FightResult"):FireServer(result == "won")
			end
		end
	end)

	goIdle()
end

return Controller
