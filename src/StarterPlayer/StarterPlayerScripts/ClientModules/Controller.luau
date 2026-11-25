--!strict
-- Client fishing flow and input. One "Fish" action on every device:
--   hold and release to cast, press on a bite to hook, hold to reel during the fight,
--   press while waiting to reel back in.
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local FightModel = require(Shared.FightModel)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)

local Controller = {}

local state = "Idle" -- Idle, Charging, Casting, Waiting, Bite, Hooking, Fighting, Resolving
local chargeStart = 0
local holding = false
local fight: FightModel.State? = nil
local snapshot: any = nil
local castTimeout = 0

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
end

-- Studio-only test hook: when the server sets DebugAutoFish on the player, the client presses
-- the Fish button on a bite and reels perfectly, through the same handler as real input.
local function autoFish(): boolean
	return RunService:IsStudio() and game:GetService("Players").LocalPlayer:GetAttribute("DebugAutoFish") == true
end

local function idleStatus()
	UI.status("Face the water. Hold " .. UI.inputName() .. " and let go to cast.")
end

local function goIdle()
	setState("Idle")
	holding = false
	fight = nil
	UI.bite(false)
	UI.showPower(nil)
	UI.showFight(nil)
	idleStatus()
end

local function chargePower(): number
	return math.clamp((os.clock() - chargeStart) / Config.CHARGE_TIME, 0, 1)
end

local function onFish(_name: string, inputState: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if UI.isPanelOpen() then
		return Enum.ContextActionResult.Pass
	end
	local began = inputState == Enum.UserInputState.Begin
	local ended = inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel
	if state == "Idle" and began then
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
	elseif state == "Waiting" and began then
		Remotes.event("CancelCast"):FireServer()
		UI.status("Reeling in...")
	elseif state == "Bite" and began then
		setState("Hooking")
		UI.bite(false)
		Remotes.event("Hook"):FireServer()
	elseif state == "Fighting" then
		if began then
			holding = true
		elseif ended then
			holding = false
		end
	end
	return Enum.ContextActionResult.Sink
end

local function onFishingEvent(kind: string, payload: any)
	if kind == "Landed" then
		setState("Waiting")
		play("splash")
		UI.status("Waiting for a bite at " .. tostring(payload.spotName) .. "...")
	elseif kind == "Bite" then
		setState("Bite")
		play("bite")
		UI.bite(true)
		UI.status("Bite! Press " .. UI.inputName() .. " now!")
	elseif kind == "Missed" then
		setState("Waiting")
		UI.bite(false)
		UI.toast(payload.text)
		UI.status("Waiting for another bite...")
	elseif kind == "Hooked" then
		setState("Fighting")
		holding = false
		fight = FightModel.new(payload.fight, payload.assist, payload.seed)
		UI.status("Fish on! Keep it in the green.")
		UI.showFight(fight, payload.note)
	elseif kind == "Caught" then
		play("catch")
		UI.catchCard(payload)
		goIdle()
	elseif kind == "Escaped" then
		UI.toast(payload.text)
		goIdle()
	elseif kind == "Reset" then
		goIdle()
	elseif kind == "Hint" then
		UI.toast(payload.text)
		if state == "Casting" or state == "Charging" then
			goIdle()
		end
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
		fishDown = function()
			onFish("Fish", Enum.UserInputState.Begin, (nil :: any))
		end,
		fishUp = function()
			onFish("Fish", Enum.UserInputState.End, (nil :: any))
		end,
		cycleBait = cycleBait,
		toggleJournal = function()
			UI.toggleJournal()
		end,
		toggleAssist = function()
			if snapshot then
				Remotes.event("SetAssist"):FireServer(not snapshot.assist)
			end
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
		end
	end)

	-- Main action on mouse, F key and gamepad R2. Touch uses the big Fish button in the UI.
	ContextActionService:BindAction("Fish", onFish, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)

	ContextActionService:BindAction("Journal", function(_, st)
		if st == Enum.UserInputState.Begin then
			UI.toggleJournal()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.J, Enum.KeyCode.ButtonY)
	ContextActionService:BindAction("CycleBait", function(_, st)
		if st == Enum.UserInputState.Begin and not UI.isPanelOpen() then
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
		if prompt.Name == "ShopPrompt" then
			UI.openShop()
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		UI.setClock(Lighting.ClockTime)
		if state == "Charging" then
			UI.showPower(chargePower())
		elseif state == "Casting" and os.clock() > castTimeout then
			goIdle()
		elseif state == "Bite" and autoFish() then
			onFish("Fish", Enum.UserInputState.Begin, (nil :: any))
		elseif state == "Fighting" and fight then
			if autoFish() then
				holding = fight.zonePos < fight.fishPos
			end
			local result = FightModel.step(fight, math.min(dt, 0.1), holding)
			UI.showFight(fight)
			if result then
				setState("Resolving")
				UI.showFight(nil)
				Remotes.event("FightResult"):FireServer(result == "won")
			end
		end
	end)

	goIdle()
end

-- Exposed for automated playtests.
function Controller.debug(): any
	return { state = state, holding = holding, fight = fight and { fishPos = fight.fishPos, zonePos = fight.zonePos, progress = fight.progress } }
end

function Controller.setHolding(on: boolean)
	holding = on
end

return Controller
