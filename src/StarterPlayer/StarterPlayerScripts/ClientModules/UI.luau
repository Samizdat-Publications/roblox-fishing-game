--!strict
-- Code-built interface: top bar, status line, power meter, fight bar, shop, journal, toasts.
-- Pure view: the Controller tells it what to show and passes callbacks for buttons.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FishData = require(Shared.FishData)
local BaitData = require(Shared.BaitData)
local RodData = require(Shared.RodData)
local FishLogic = require(Shared.FishLogic)
local Rarity = require(Shared.Rarity)
local BoatData = require(Shared.BoatData)
local Config = require(Shared.Config)
local Journal = require(Shared.Journal)
local Units = require(Shared.Units)
local BaitRig = require(Shared.BaitRig)

local UI = {}

local C = {
	panel = Color3.fromRGB(24, 32, 40),
	panel2 = Color3.fromRGB(38, 50, 62),
	text = Color3.fromRGB(240, 244, 248),
	dim = Color3.fromRGB(170, 185, 200),
	gold = Color3.fromRGB(250, 205, 80),
	green = Color3.fromRGB(90, 200, 110),
	red = Color3.fromRGB(230, 90, 80),
	blue = Color3.fromRGB(90, 160, 230),
	fish = Color3.fromRGB(255, 150, 60),
}

local gui: ScreenGui
local refs: { [string]: any } = {}
local callbacks: { [string]: (...any) -> () } = {}
local lastState: any = nil
local openPanel: string? = nil
local locked = false -- true from a bite until the fight ends: no panels, no side buttons

local function corner(parent: Instance, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = parent
end

local function pad(parent: Instance, p: number)
	local u = Instance.new("UIPadding")
	u.PaddingLeft = UDim.new(0, p)
	u.PaddingRight = UDim.new(0, p)
	u.PaddingTop = UDim.new(0, p)
	u.PaddingBottom = UDim.new(0, p)
	u.Parent = parent
end

local function frame(parent: Instance, name: string, size: UDim2, pos: UDim2, color: Color3?, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color or C.panel
	f.BackgroundTransparency = transparency or 0.15
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function label(parent: Instance, name: string, text: string, size: UDim2, pos: UDim2, textSize: number?, color: Color3?, font: Enum.Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color or C.text
	l.TextSize = textSize or 18
	l.Font = font or Enum.Font.GothamMedium
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local function button(parent: Instance, name: string, text: string, size: UDim2, pos: UDim2, color: Color3?, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color or C.panel2
	b.BackgroundTransparency = 0.05
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Text = text
	b.TextColor3 = C.text
	b.TextSize = 18
	b.Font = Enum.Font.GothamBold
	b.TextWrapped = true
	b.Selectable = true
	corner(b, 8)
	b.Activated:Connect(onClick)
	b.Parent = parent
	return b
end

-- What to call the main button for the current device.
function UI.inputName(): string
	local last = UserInputService:GetLastInputType()
	if last.Name:match("^Gamepad") then
		return "R2"
	end
	if UserInputService.TouchEnabled and (last == Enum.UserInputType.Touch or not UserInputService.KeyboardEnabled) then
		return "the Fish button"
	end
	return "click"
end

local function clockText(clock: number): string
	local h = math.floor(clock)
	local m = math.floor((clock - h) * 60)
	local suffix = if h < 12 then "AM" else "PM"
	local h12 = h % 12
	if h12 == 0 then
		h12 = 12
	end
	return string.format("%d:%02d %s", h12, m, suffix)
end

local function baitLabel(state: any): string
	local b = BaitData.byId[state.equipped]
	if not b then
		return "Bait: none"
	end
	if b.kind == "lure" then
		return "Bait: " .. b.name
	end
	return string.format("Bait: %s x%d", b.name, state.bait[b.id] or 0)
end

function UI.init(cbs: { [string]: (...any) -> () })
	callbacks = cbs
	local player = Players.LocalPlayer
	gui = Instance.new("ScreenGui")
	gui.Name = "FishingUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor -- a fishing game plays sideways
	gui.Parent = playerGui

	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local function rescale()
		local cam = workspace.CurrentCamera
		if cam then
			local v = cam.ViewportSize
			scale.Scale = math.clamp(math.min(v.X / 1280, v.Y / 720) * 1.15, 0.72, 1.25)
		end
		-- Panels shrink to fit short phone screens (heights are in scaled units).
		local h = gui.AbsoluteSize.Y / scale.Scale
		for _, panel in { refs.shop, refs.journal, refs.pond, refs.tackle } do
			if panel then
				panel.Size = UDim2.fromOffset(640, math.min(470, h - 70))
			end
		end
	end
	refs.rescale = rescale
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)

	-- Top bar: coins, clock, bag. Sits below Roblox's top buttons.
	local top = frame(gui, "TopBar", UDim2.fromOffset(560, 44), UDim2.new(0.5, -280, 0, 8))
	corner(top)
	refs.coins = label(top, "Coins", "0 coins", UDim2.fromOffset(150, 44), UDim2.fromOffset(10, 0), 20, C.gold, Enum.Font.GothamBold)
	refs.coins.TextXAlignment = Enum.TextXAlignment.Left
	refs.clock = label(top, "Clock", "7:00 AM  Dawn", UDim2.fromOffset(200, 44), UDim2.fromOffset(180, 0), 20)
	refs.clock.TextScaled = true -- room for the weather after the time
	local clockMax = Instance.new("UITextSizeConstraint")
	clockMax.MaxTextSize = 20
	clockMax.Parent = refs.clock
	refs.bag = label(top, "Bag", "Bag: 0", UDim2.fromOffset(170, 44), UDim2.fromOffset(380, 0), 18, C.dim)
	refs.bag.TextXAlignment = Enum.TextXAlignment.Right

	-- Left buttons (big enough for thumbs)
	refs.baitBtn = button(gui, "BaitButton", "Bait: Worms", UDim2.fromOffset(190, 50), UDim2.new(0, 12, 0.5, -60), C.panel2, function()
		if callbacks.cycleBait then
			callbacks.cycleBait()
		end
	end)
	refs.journalBtn = button(gui, "JournalButton", "Journal (J)", UDim2.fromOffset(190, 50), UDim2.new(0, 12, 0.5, 0), C.panel2, function()
		if callbacks.toggleJournal then
			callbacks.toggleJournal()
		end
	end)

	-- Daily goals: a button under the journal and a small list beside it.
	-- UNVERIFIED in Studio (2026-11-26).
	refs.goalsBtn = button(gui, "GoalsButton", "Goals", UDim2.fromOffset(190, 50), UDim2.new(0, 12, 0.5, 60), C.panel2, function()
		refs.goalsBox.Visible = not refs.goalsBox.Visible
	end)
	local goalsBox = frame(gui, "Goals", UDim2.fromOffset(330, 150), UDim2.new(0, 212, 0.5, -60), C.panel, 0.15)
	corner(goalsBox)
	pad(goalsBox, 10)
	goalsBox.Visible = false
	local goalsList = Instance.new("UIListLayout")
	goalsList.Padding = UDim.new(0, 4)
	goalsList.SortOrder = Enum.SortOrder.LayoutOrder
	goalsList.Parent = goalsBox
	refs.goalsTitle = label(goalsBox, "Title", "Today's goals", UDim2.new(1, 0, 0, 24), UDim2.new(), 18, C.gold, Enum.Font.GothamBold)
	refs.goalsTitle.TextXAlignment = Enum.TextXAlignment.Left
	refs.goalLines = {}
	for i = 1, 3 do
		local l = label(goalsBox, "Goal" .. i, "", UDim2.new(1, 0, 0, 34), UDim2.new(), 15, C.text)
		l.LayoutOrder = i
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextWrapped = true
		refs.goalLines[i] = l
	end
	refs.goalsBox = goalsBox

	-- Status line and power meter (bottom center)
	refs.status = label(gui, "Status", "", UDim2.fromOffset(640, 40), UDim2.new(0.5, -320, 1, -150), 22, C.text, Enum.Font.GothamBold)
	refs.status.TextStrokeTransparency = 0.4
	local power = frame(gui, "Power", UDim2.fromOffset(300, 22), UDim2.new(0.5, -150, 1, -100), C.panel, 0.2)
	corner(power, 11)
	power.Visible = false
	local fill = frame(power, "Fill", UDim2.fromScale(0, 1), UDim2.fromScale(0, 0), C.gold, 0)
	corner(fill, 11)
	refs.power, refs.powerFill = power, fill

	-- Bite alert
	refs.bite = label(gui, "Bite", "!", UDim2.fromOffset(120, 120), UDim2.new(0.5, -60, 0.32, -60), 110, C.gold, Enum.Font.GothamBlack)
	refs.bite.TextStrokeTransparency = 0
	refs.bite.Visible = false

	-- Fight bar: left of center, so a thumb on the touch Fish button never covers it,
	-- and short enough to clear the top bar on small phones.
	local fight = frame(gui, "Fight", UDim2.fromOffset(150, 320), UDim2.new(0.5, -260, 0.5, -140), C.panel, 0.2)
	corner(fight)
	fight.Visible = false
	refs.fightNote = label(fight, "Note", "", UDim2.fromOffset(150, 40), UDim2.fromOffset(0, 2), 15, C.dim)
	local track = frame(fight, "Track", UDim2.fromOffset(56, 236), UDim2.fromOffset(20, 46), Color3.fromRGB(20, 60, 90), 0)
	corner(track, 6)
	refs.zone = frame(track, "Zone", UDim2.new(1, 0, 0.3, 0), UDim2.fromScale(0, 0.5), C.green, 0.35)
	corner(refs.zone, 6)
	refs.fishMark = frame(track, "FishMark", UDim2.new(1, 8, 0, 14), UDim2.fromScale(0, 0.5), C.fish, 0)
	refs.fishMark.Position = UDim2.new(0, -4, 0.5, 0)
	corner(refs.fishMark, 7)
	local prog = frame(fight, "Progress", UDim2.fromOffset(22, 236), UDim2.fromOffset(100, 46), Color3.fromRGB(40, 40, 40), 0)
	corner(prog, 6)
	refs.progFill = frame(prog, "Fill", UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0.65), C.gold, 0)
	corner(refs.progFill, 6)
	refs.fightHelp = label(fight, "Help", "Hold to reel in", UDim2.fromOffset(150, 26), UDim2.fromOffset(0, 288), 15, C.text)
	local zoneStroke = Instance.new("UIStroke")
	zoneStroke.Color = Color3.new(1, 1, 1)
	zoneStroke.Thickness = 0
	zoneStroke.Parent = refs.zone
	refs.zoneStroke = zoneStroke
	-- Cue that rides beside the catch zone and says what to do right now.
	local cue = label(fight, "Cue", "", UDim2.fromOffset(150, 40), UDim2.new(1, 10, 0.5, -20), 26, C.gold, Enum.Font.GothamBlack)
	cue.TextXAlignment = Enum.TextXAlignment.Left
	cue.TextStrokeTransparency = 0.2
	refs.cue = cue

	-- Big reel prompt right of the fight bar: where and how to press, and feedback while holding.
	local prompt = frame(gui, "ReelPrompt", UDim2.fromOffset(360, 80), UDim2.new(0.5, 70, 0.5, -40), C.panel, 0.15)
	corner(prompt, 14)
	prompt.Visible = false
	refs.reelTitle = label(prompt, "Title", "HOLD TO REEL", UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 4), 30, C.gold, Enum.Font.GothamBlack)
	refs.reelSub = label(prompt, "Sub", "", UDim2.new(1, -16, 0, 30), UDim2.fromOffset(8, 44), 17, C.text)
	refs.reelPrompt = prompt
	refs.fight = fight

	-- Drag (L4d): a small button beside the fight bar (below the coaching cue, left of the reel
	-- prompt) cycles Light, Medium, Tight (Q or gamepad Y do the same), with the rod's line
	-- rating under it. A tap on it is not a reel press. It sat under the bar at first, which is
	-- off the bottom of the smallest phone (iPhone 7, 11/27/2026).
	local dragBox = frame(gui, "DragBox", UDim2.fromOffset(150, 58), UDim2.new(0.5, -100, 0.5, 60), C.panel, 1)
	dragBox.Visible = false
	refs.dragBtn = button(dragBox, "Drag", "Drag: Medium", UDim2.fromOffset(150, 36), UDim2.fromOffset(0, 0), C.panel2, function()
		if callbacks.cycleDrag then
			callbacks.cycleDrag()
		end
	end)
	refs.dragBtn.TextSize = 16
	refs.dragLine = label(dragBox, "Line", "Line 6 lb", UDim2.fromOffset(150, 20), UDim2.fromOffset(0, 37), 14, C.dim)
	refs.dragLine.TextStrokeTransparency = 0.5
	refs.dragBox = dragBox

	-- Toasts (top center, under the bar)
	local toasts = Instance.new("Frame")
	toasts.Name = "Toasts"
	toasts.Size = UDim2.fromOffset(560, 200)
	toasts.Position = UDim2.new(0.5, -280, 0, 60)
	toasts.BackgroundTransparency = 1
	toasts.Parent = gui
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = toasts
	refs.toasts = toasts

	-- Catch card (center)
	-- Right of center so the fish held up on the line stays in view.
	local card = frame(gui, "CatchCard", UDim2.fromOffset(420, 200), UDim2.new(0.5, 70, 0.5, -110), C.panel, 0.05)
	corner(card, 14)
	pad(card, 14)
	card.Visible = false
	refs.cardTitle = label(card, "Title", "", UDim2.new(1, 0, 0, 34), UDim2.fromOffset(0, 0), 24, C.gold, Enum.Font.GothamBlack)
	refs.cardBody = label(card, "Body", "", UDim2.new(1, 0, 0, 60), UDim2.fromOffset(0, 38), 19, C.text)
	refs.cardNote = label(card, "Note", "", UDim2.new(1, 0, 0, 70), UDim2.fromOffset(0, 100), 16, C.dim)
	refs.card = card
	refs.cardStroke = Instance.new("UIStroke")
	refs.cardStroke.Thickness = 3
	refs.cardStroke.Transparency = 0.1
	refs.cardStroke.Parent = card

	-- Big touch Fish button, left of Roblox's jump button. Hold and release like a mouse button.
	if UserInputService.TouchEnabled then
		local fishBtn = Instance.new("TextButton")
		fishBtn.Name = "TouchFish"
		fishBtn.AnchorPoint = Vector2.new(1, 1)
		fishBtn.Position = UDim2.new(1, -150, 1, -20)
		fishBtn.Size = UDim2.fromOffset(110, 110)
		fishBtn.BackgroundColor3 = C.blue
		fishBtn.BackgroundTransparency = 0.1
		fishBtn.Text = "Fish"
		fishBtn.TextColor3 = C.text
		fishBtn.TextSize = 28
		fishBtn.Font = Enum.Font.GothamBlack
		fishBtn.AutoButtonColor = true
		corner(fishBtn, 55)
		local held: InputObject? = nil
		fishBtn.InputBegan:Connect(function(input)
			if held or not (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
				return
			end
			held = input
			if callbacks.fishDown then
				callbacks.fishDown()
			end
			local conn: RBXScriptConnection
			conn = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
				if input.UserInputState == Enum.UserInputState.End or input.UserInputState == Enum.UserInputState.Cancel then
					conn:Disconnect()
					held = nil
					if callbacks.fishUp then
						callbacks.fishUp()
					end
				end
			end)
		end)
		fishBtn.Parent = gui
		refs.touchFish = fishBtn
	end

	UI.buildShop()
	UI.buildJournal()
	UI.buildPond()
	UI.buildTackle()
	rescale()
end

function UI.setClock(clock: number)
	local weather = workspace:GetAttribute("WeatherName")
	refs.clock.Text = clockText(clock) .. "  " .. FishLogic.periodFromClock(clock) .. (if type(weather) == "string" and weather ~= "Clear" then ", " .. weather else "")
end

function UI.setState(state: any)
	lastState = state
	refs.coins.Text = string.format("%d coins", state.coins)
	refs.bag.Text = string.format("Bag: %d fish (%d)", state.bagCount, state.bagValue)
	refs.baitBtn.Text = baitLabel(state)
	local goals = state.goals or {}
	local doneCount = 0
	for i, l in refs.goalLines do
		local g = goals[i]
		if g then
			if g.done then
				doneCount += 1
			end
			l.Text = string.format("%s %s  (%d/%d, %d coins)", if g.done then "[done]" else "-", g.text, g.progress, g.target, g.reward)
			l.TextColor3 = if g.done then C.green else C.text
		else
			l.Text = ""
		end
	end
	refs.goalsBtn.Text = string.format("Goals %d/%d", doneCount, #goals)
	refs.goalsBtn.Visible = #goals > 0 -- no goals while they're switched off
	if #goals == 0 then
		refs.goalsBox.Visible = false
	end
	if openPanel == "Shop" then
		UI.refreshShop()
	elseif openPanel == "Journal" then
		UI.refreshJournal()
	elseif openPanel == "Pond" then
		UI.refreshPond()
	elseif openPanel == "Tackle" then
		UI.refreshTackle()
	end
end

function UI.status(text: string)
	refs.status.Text = text
	-- Keep the key hint on the Journal button right for the current device.
	local name = UI.inputName()
	refs.journalBtn.Text = if name == "R2" then "Journal (Y)" elseif name == "click" then "Journal (J)" else "Journal"
end

function UI.showPower(p: number?)
	if p == nil then
		refs.power.Visible = false
		return
	end
	refs.power.Visible = true
	refs.powerFill.Size = UDim2.fromScale(math.clamp(p, 0, 1), 1)
end

function UI.bite(on: boolean)
	refs.bite.Visible = on
	if on then
		refs.bite.Rotation = -10
		TweenService:Create(refs.bite, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 10 }):Play()
	end
end

-- What to tell the player to press, for the device they're using.
local function reelHowTo(): string
	local name = UI.inputName()
	if name == "R2" then
		return "Hold R2 or A. Let go to drop."
	elseif name == "click" then
		return "Hold the mouse anywhere, or Space."
	end
	return "Hold anywhere on the screen."
end

-- The drag button's text (L4d): the setting, the key for this device, and the line rating.
function UI.showDrag(drag: string?, lineLb: number?)
	if not drag then
		refs.dragBox.Visible = false
		return
	end
	local name = UI.inputName()
	local key = if name == "R2" then " (Y)" elseif name == "click" then " (Q)" else ""
	refs.dragBtn.Text = "Drag: " .. drag .. key
	if lineLb then
		refs.dragLine.Text = string.format("Line %d lb", lineLb)
	end
	refs.dragBox.Visible = true
end

-- True when a screen position is over the drag button (so the Controller doesn't count that
-- tap as reeling).
function UI.overDragButton(pos: Vector3 | Vector2): boolean
	if not refs.dragBox or not refs.dragBox.Visible then
		return false
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return false
	end
	for _, obj in playerGui:GetGuiObjectsAtPosition(pos.X, pos.Y) do
		if obj == refs.dragBtn then
			return true
		end
	end
	return false
end

function UI.showFight(s: any?, note: string?, holding: boolean?, slack: boolean?)
	if not s then
		refs.fight.Visible = false
		refs.reelPrompt.Visible = false
		refs.dragBox.Visible = false
		if refs.touchFish then
			refs.touchFish.Text = "Fish"
			refs.touchFish.BackgroundColor3 = C.blue
		end
		return
	end
	if not refs.fight.Visible then
		refs.reelSub.Text = reelHowTo()
	end
	refs.fight.Visible = true
	refs.reelPrompt.Visible = true
	if note then
		refs.fightNote.Text = note
	end
	refs.zone.Size = UDim2.new(1, 0, s.zoneSize, 0)
	refs.zone.Position = UDim2.new(0, 0, 1 - s.zonePos - s.zoneSize / 2, 0)
	refs.fishMark.Position = UDim2.new(0, -4, 1 - s.fishPos, -7)
	local inside = math.abs(s.fishPos - s.zonePos) <= s.zoneSize / 2
	refs.zone.BackgroundColor3 = if inside then C.green else C.red
	refs.progFill.Size = UDim2.fromScale(1, s.progress)
	refs.progFill.Position = UDim2.fromScale(0, 1 - s.progress)

	-- Cue beside the zone (the track sits 46 px down and is 236 px tall).
	local cueY = 46 + (1 - s.zonePos) * 236 - 20
	refs.cue.Position = UDim2.new(1, 10, 0, cueY)
	if inside then
		refs.cue.Text = "Nice!"
		refs.cue.TextColor3 = C.green
	elseif s.fishPos > s.zonePos then
		refs.cue.Text = "HOLD"
		refs.cue.TextColor3 = C.gold
	else
		refs.cue.Text = "LET GO"
		refs.cue.TextColor3 = C.blue
	end

	-- Feedback while holding: bright outline, prompt turns green, touch button lights up.
	refs.zoneStroke.Thickness = if holding then 3 else 0
	local strain = if type(s.strain) == "number" then s.strain else 0
	if strain >= 0.5 then
		-- Line and drag (L4d): the line is close to snapping. Let go!
		refs.reelTitle.Text = "EASE OFF!"
		refs.reelTitle.TextColor3 = if (os.clock() % 0.3) < 0.15 then C.red else C.text
	elseif holding then
		refs.reelTitle.Text = "REELING!"
		refs.reelTitle.TextColor3 = C.green
	elseif slack then
		-- No press for a while: the line has gone slack and the fish is working free.
		refs.reelTitle.Text = "KEEP REELING!"
		refs.reelTitle.TextColor3 = if (os.clock() % 0.5) < 0.25 then C.red else C.gold
	else
		refs.reelTitle.Text = "HOLD TO REEL"
		refs.reelTitle.TextColor3 = if (os.clock() % 0.8) < 0.4 then C.gold else C.text
	end
	if refs.touchFish then
		refs.touchFish.Text = "REEL"
		refs.touchFish.BackgroundColor3 = if holding then C.green else C.gold
	end
end

function UI.toast(text: string, color: Color3?)
	local t = label(refs.toasts, "Toast", text, UDim2.fromOffset(540, 0), UDim2.new(), 18, color or C.text)
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.BackgroundTransparency = 0.2
	t.BackgroundColor3 = C.panel
	t.LayoutOrder = os.clock() * 1000
	corner(t, 8)
	pad(t, 8)
	local count = 0
	for _, c in refs.toasts:GetChildren() do
		if c:IsA("TextLabel") then
			count += 1
		end
	end
	if count > 3 then
		local oldest, order = nil, math.huge
		for _, c in refs.toasts:GetChildren() do
			if c:IsA("TextLabel") and c.LayoutOrder < order then
				oldest, order = c, c.LayoutOrder
			end
		end
		if oldest then
			oldest:Destroy()
		end
	end
	task.delay(5, function()
		if t.Parent then
			t:Destroy()
		end
	end)
end

function UI.catchCard(payload: any)
	local f = payload.fish
	-- Rarity: the tier colour on the title and border, and a banner for trophies and monsters.
	-- UNVERIFIED in Studio (rarity plan Task 3, 2026-11-26).
	local tier = payload.tier or Rarity.of(FishData.byId[f.id])
	local color = Rarity.colorAt(tier, os.clock())
	local class = Rarity.sizeClassOf(f)
	local banner = if class == "monster" then "MONSTER! " elseif class == "trophy" then "TROPHY! " else ""
	refs.cardTitle.Text = banner .. (if payload.first then "New species! " else "") .. f.name
	refs.cardTitle.TextColor3 = color
	refs.cardStroke.Color = color
	refs.cardBody.Text = string.format("%s. %s, %s. Worth %d coins.%s", (Rarity.byId[tier] or Rarity.byId.Common).name, Units.length(f.cm), Units.weight(f.kg), f.price, if payload.best then "\nPersonal best!" else "")
	refs.cardNote.Text = if payload.first then ("Journal: " .. payload.habit) else ("Caught at " .. (FishLogic.SPOT_NAMES[f.spot] or f.spot) .. " on " .. ((BaitData.byId[f.bait] and BaitData.byId[f.bait].name) or f.bait) .. ".")
	refs.card.Visible = true
	local token = os.clock()
	refs.card:SetAttribute("Token", token)
	task.delay(if payload.first then 6 else 4, function()
		if refs.card:GetAttribute("Token") == token then
			refs.card.Visible = false
		end
	end)
end

----------------------------------------------------------------------------------------
-- Panels

local function panelShell(name: string, title: string): (Frame, ScrollingFrame)
	local p = frame(gui, name, UDim2.fromOffset(640, 470), UDim2.new(0.5, 0, 0.5, 24), C.panel, 0.03)
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	corner(p, 14)
	p.Visible = false
	label(p, "Title", title, UDim2.new(1, -120, 0, 44), UDim2.fromOffset(16, 6), 24, C.gold, Enum.Font.GothamBlack).TextXAlignment = Enum.TextXAlignment.Left
	button(p, "Close", "Close", UDim2.fromOffset(90, 36), UDim2.new(1, -102, 0, 10), C.red, function()
		UI.closePanels()
	end)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "List"
	scroll.Size = UDim2.new(1, -24, 1, -110)
	scroll.Position = UDim2.fromOffset(12, 56)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Selectable = false
	scroll.Parent = p
	return p, scroll
end

function UI.buildShop()
	local p, scroll = panelShell("Shop", "Bait and Tackle")
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	refs.shopRows = {}
	for i, b in BaitData.list do
		local row = frame(scroll, b.id, UDim2.new(1, -10, 0, 70), UDim2.new(), C.panel2, 0.1)
		row.LayoutOrder = i
		corner(row, 10)
		label(row, "Name", b.name, UDim2.fromOffset(200, 28), UDim2.fromOffset(12, 6), 20, C.text, Enum.Font.GothamBold).TextXAlignment = Enum.TextXAlignment.Left
		local blurb = label(row, "Blurb", b.blurb, UDim2.fromOffset(330, 34), UDim2.fromOffset(12, 32), 14, C.dim)
		blurb.TextXAlignment = Enum.TextXAlignment.Left
		local owned = label(row, "Owned", "", UDim2.fromOffset(100, 28), UDim2.fromOffset(250, 6), 15, C.dim)
		owned.TextXAlignment = Enum.TextXAlignment.Left
		local buy = button(row, "Buy", "", UDim2.fromOffset(150, 50), UDim2.new(1, -162, 0, 10), C.blue, function()
			if callbacks.buy then
				callbacks.buy(b.id)
			end
		end)
		refs.shopRows[b.id] = { owned = owned, buy = buy }
	end
	-- Rods: each comes with its reel. Bought once, switch any time.
	local rodHeader = label(scroll, "RodsHeader", "Rods", UDim2.new(1, -10, 0, 30), UDim2.new(), 20, C.gold, Enum.Font.GothamBlack)
	rodHeader.TextXAlignment = Enum.TextXAlignment.Left
	rodHeader.LayoutOrder = 100
	refs.rodRows = {}
	for i, r in RodData.list do
		local row = frame(scroll, "Rod_" .. r.id, UDim2.new(1, -10, 0, 70), UDim2.new(), C.panel2, 0.1)
		row.LayoutOrder = 100 + i
		corner(row, 10)
		local swatch = frame(row, "Swatch", UDim2.fromOffset(6, 50), UDim2.fromOffset(6, 10), r.color, 0)
		corner(swatch, 3)
		label(row, "Name", r.name, UDim2.fromOffset(220, 28), UDim2.fromOffset(18, 6), 20, C.text, Enum.Font.GothamBold).TextXAlignment = Enum.TextXAlignment.Left
		local blurb = label(row, "Blurb", string.format("%s %d lb line.", r.blurb, r.lineLb), UDim2.fromOffset(330, 34), UDim2.fromOffset(18, 32), 14, C.dim)
		blurb.TextXAlignment = Enum.TextXAlignment.Left
		local btn = button(row, "Buy", "", UDim2.fromOffset(150, 50), UDim2.new(1, -162, 0, 10), C.blue, function()
			local st = lastState
			if not st then
				return
			end
			if st.rods and st.rods[r.id] then
				if callbacks.equipRod then
					callbacks.equipRod(r.id)
				end
			elseif callbacks.buyRod then
				callbacks.buyRod(r.id)
			end
		end)
		refs.rodRows[r.id] = btn
	end
	-- Boats: bought once; the chosen one waits at your slip by the dock. UNVERIFIED in Studio.
	local boatHeader = label(scroll, "BoatsHeader", "Boats", UDim2.new(1, -10, 0, 30), UDim2.new(), 20, C.gold, Enum.Font.GothamBlack)
	boatHeader.TextXAlignment = Enum.TextXAlignment.Left
	boatHeader.LayoutOrder = 200
	refs.boatRows = {}
	boatHeader.Visible = Config.boatsOn()
	for i, b in (if Config.boatsOn() then BoatData.list else {}) do
		local row = frame(scroll, "Boat_" .. b.id, UDim2.new(1, -10, 0, 84), UDim2.new(), C.panel2, 0.1)
		row.LayoutOrder = 200 + i
		corner(row, 10)
		local swatch = frame(row, "Swatch", UDim2.fromOffset(6, 64), UDim2.fromOffset(6, 10), b.color, 0)
		corner(swatch, 3)
		local title = b.name .. (if b.crew > 1 then " (for two players)" else "")
		label(row, "Name", title, UDim2.fromOffset(320, 28), UDim2.fromOffset(18, 6), 20, C.text, Enum.Font.GothamBold).TextXAlignment = Enum.TextXAlignment.Left
		local blurb = label(row, "Blurb", b.blurb, UDim2.fromOffset(330, 48), UDim2.fromOffset(18, 32), 14, C.dim)
		blurb.TextXAlignment = Enum.TextXAlignment.Left
		blurb.TextYAlignment = Enum.TextYAlignment.Top
		local btn = button(row, "Buy", "", UDim2.fromOffset(150, 50), UDim2.new(1, -162, 0, 17), C.blue, function()
			local st = lastState
			if not st then
				return
			end
			if st.boats and st.boats[b.id] then
				if callbacks.chooseBoat then
					callbacks.chooseBoat(b.id)
				end
			elseif callbacks.buyBoat then
				callbacks.buyBoat(b.id)
			end
		end)
		refs.boatRows[b.id] = btn
	end
	refs.shopHint = label(p, "Hint", "", UDim2.new(1, -24, 0, 40), UDim2.new(0, 12, 1, -48), 15, C.dim)
	refs.shop = p
end

function UI.refreshShop()
	local s = lastState
	if not s then
		return
	end
	for _, b in BaitData.list do
		local r = refs.shopRows[b.id]
		if b.kind == "lure" then
			local has = s.lures[b.id] == true
			r.owned.Text = if has then "Owned" else "Lure, keep forever"
			r.buy.Text = if has then "Owned" else (b.price .. " coins")
			r.buy.AutoButtonColor = not has
			r.buy.BackgroundColor3 = if has then C.panel else (if s.coins >= b.price then C.blue else C.panel)
		else
			r.owned.Text = "You have " .. (s.bait[b.id] or 0)
			r.buy.Text = string.format("%d for %d", b.pack, b.price)
			r.buy.BackgroundColor3 = if s.coins >= b.price then C.blue else C.panel
		end
	end
	for _, r in RodData.list do
		local btn = refs.rodRows[r.id]
		local owned = s.rods and s.rods[r.id]
		if s.rod == r.id then
			btn.Text = "In your hands"
			btn.BackgroundColor3 = C.panel
		elseif owned then
			btn.Text = "Use this rod"
			btn.BackgroundColor3 = C.green
		else
			btn.Text = r.price .. " coins"
			btn.BackgroundColor3 = if s.coins >= r.price then C.blue else C.panel
		end
	end
	for _, b in BoatData.list do
		local btn = refs.boatRows and refs.boatRows[b.id]
		if btn then
			local owned = s.boats and s.boats[b.id]
			if s.boat == b.id then
				btn.Text = "At your slip"
				btn.BackgroundColor3 = C.panel
			elseif owned then
				btn.Text = "Use this boat"
				btn.BackgroundColor3 = C.green
			else
				btn.Text = b.price .. " coins"
				btn.BackgroundColor3 = if s.coins >= b.price then C.blue else C.panel
			end
		end
	end
	local forecast = workspace:GetAttribute("Forecast")
	refs.shopHint.Text = string.format("You have %d coins. %s", s.coins, if type(forecast) == "string" then "Forecast: " .. forecast else "The right bait beats the expensive bait.")
end

function UI.buildJournal()
	local p, scroll = panelShell("Journal", "Fish Journal")
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(296, 150)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	refs.journalCards = {}
	for i, s in FishData.list do
		local card = frame(scroll, s.id, UDim2.new(), UDim2.new(), C.panel2, 0.1)
		card.LayoutOrder = i
		corner(card, 10)
		pad(card, 10)
		local name = label(card, "Name", "???", UDim2.new(1, 0, 0, 26), UDim2.new(), 20, C.text, Enum.Font.GothamBold)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local stats = label(card, "Stats", "", UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 28), 15, C.gold)
		stats.TextXAlignment = Enum.TextXAlignment.Left
		stats.TextYAlignment = Enum.TextYAlignment.Top
		local habit = label(card, "Habit", "", UDim2.new(1, 0, 0, 60), UDim2.fromOffset(0, 68), 14, C.dim)
		habit.TextXAlignment = Enum.TextXAlignment.Left
		habit.TextYAlignment = Enum.TextYAlignment.Top
		refs.journalCards[s.id] = { name = name, stats = stats, habit = habit }
	end
	refs.assistBtn = button(p, "Assist", "Reel assist: On", UDim2.fromOffset(170, 40), UDim2.new(0, 12, 1, -48), C.panel2, function()
		if callbacks.toggleAssist then
			callbacks.toggleAssist()
		end
	end)
	-- Quick Bait (L3): skip the bait bench, always Okay. And the Tackle Box page.
	refs.quickBtn = button(p, "QuickBait", "Quick Bait: Off", UDim2.fromOffset(170, 40), UDim2.new(0, 188, 1, -48), C.panel2, function()
		if callbacks.toggleQuickBait then
			callbacks.toggleQuickBait()
		end
	end)
	refs.tackleBtn = button(p, "TackleBox", "Tackle Box", UDim2.fromOffset(130, 40), UDim2.new(0, 364, 1, -48), C.panel2, function()
		UI.openTackle()
	end)
	-- The summary sits in the title row, so the three switches fit along the bottom.
	refs.journalSummary = label(p, "Summary", "", UDim2.new(1, -330, 0, 44), UDim2.fromOffset(220, 6), 13, C.dim)
	refs.journal = p
end

function UI.refreshJournal()
	local st = lastState
	if not st then
		return
	end
	local kinds, shown = 0, 0
	for _, s in FishData.list do
		local c = refs.journalCards[s.id]
		local best = st.bests[s.id]
		local listed = Journal.listed(s, best ~= nil)
		c.name.Parent.Visible = listed
		if listed then
			shown += 1
		end
		local count = st.counts[s.id] or 0
		if best then
			kinds += 1
			c.name.Text = s.name .. "  (" .. Rarity.of(s) .. ")"
			c.name.TextColor3 = Rarity.colorAt(Rarity.of(s), 0)
			local big = ""
			local nT, nM = (st.trophies or {})[s.id] or 0, (st.monsters or {})[s.id] or 0
			if nM > 0 then
				big = string.format(" %d monster%s!", nM, if nM == 1 then "" else "s")
			elseif nT > 0 then
				big = string.format(" %d troph%s.", nT, if nT == 1 then "y" else "ies")
			end
			c.stats.Text = string.format("Caught %d.%s Best: %s, %s\non %s at %s", count, big, Units.weight(best.kg), Units.length(best.cm), (BaitData.byId[best.bait] and BaitData.byId[best.bait].name or best.bait), FishLogic.SPOT_NAMES[best.spot] or best.spot)
			c.habit.Text = s.habit
		else
			-- Not caught yet: show its tier, and a rumour once enough fish are caught overall.
			c.name.Text = "???  (" .. Rarity.of(s) .. ")"
			c.name.TextColor3 = Rarity.colorAt(Rarity.of(s), 0)
			c.stats.Text = "Not caught yet."
			c.habit.Text = Journal.rumour(s, st.totalCaught) or "Catch more fish to hear rumours about this one."
		end
	end
	refs.assistBtn.Text = "Reel assist: " .. (if st.assist then "On" else "Off")
	refs.quickBtn.Text = "Quick Bait: " .. (if st.quickBait then "On" else "Off")
	local nextIn = Journal.nextRumourIn(st.totalCaught)
	local rod = RodData.byId[st.rod or ""] or RodData.byId.Willow
	refs.journalSummary.Text = string.format(
		"%d of %d species found. %d fish caught in all.%s Rod: %s, %s.",
		kinds,
		shown,
		st.totalCaught,
		if nextIn > 0 then string.format(" New rumour in %d.", nextIn) else "",
		rod.name,
		RodData.lineText(rod.id)
	)
end

-- From a bite until the fight ends nothing else may take the player's clicks.
function UI.setLocked(on: boolean)
	locked = on
	refs.baitBtn.Visible = not on
	refs.journalBtn.Visible = not on
	if on then
		UI.closePanels()
	end
end

function UI.isLocked(): boolean
	return locked
end

function UI.isPanelOpen(): boolean
	return openPanel ~= nil
end

function UI.closePanels()
	refs.shop.Visible = false
	refs.journal.Visible = false
	if refs.pond then
		refs.pond.Visible = false
	end
	if refs.tackle then
		refs.tackle.Visible = false
	end
	openPanel = nil
	GuiService.SelectedObject = nil
end

function UI.openShop()
	if locked then
		return
	end
	UI.closePanels()
	openPanel = "Shop"
	UI.refreshShop()
	refs.shop.Visible = true
	if UI.inputName() == "R2" then
		GuiService.SelectedObject = refs.shopRows[BaitData.list[1].id].buy
	end
end

function UI.toggleJournal()
	if locked then
		return
	end
	if openPanel == "Journal" then
		UI.closePanels()
		return
	end
	UI.closePanels()
	openPanel = "Journal"
	UI.refreshJournal()
	refs.journal.Visible = true
	if UI.inputName() == "R2" then
		GuiService.SelectedObject = refs.assistBtn
	end
end

----------------------------------------------------------------------------------------
-- Home pond panel

function UI.buildPond()
	local p, scroll = panelShell("Pond", "Your Pond")
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	refs.pondList = scroll
	refs.pondHint = label(p, "Hint", "Fish grow while you're away (up to 8 hours). Two grown fish of a kind can have babies.", UDim2.new(1, -24, 0, 40), UDim2.new(0, 12, 1, -48), 14, C.dim)
	refs.pond = p
end

local function pondRow(parent: Instance, order: number, title: string, detail: string, grow: number?, buttons: { { text: string, color: Color3, fn: () -> () } }): Frame
	local row = frame(parent, "Row" .. order, UDim2.new(1, -10, 0, 58), UDim2.new(), C.panel2, 0.1)
	row.LayoutOrder = order
	corner(row, 10)
	local name = label(row, "Name", title, UDim2.fromOffset(220, 26), UDim2.fromOffset(12, 4), 18, C.text, Enum.Font.GothamBold)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local info = label(row, "Info", detail, UDim2.fromOffset(250, 22), UDim2.fromOffset(12, 30), 14, C.gold)
	info.TextXAlignment = Enum.TextXAlignment.Left
	if grow then
		local bar = frame(row, "Grow", UDim2.fromOffset(90, 8), UDim2.fromOffset(240, 12), Color3.fromRGB(40, 40, 40), 0)
		corner(bar, 4)
		local fill = frame(bar, "Fill", UDim2.fromScale(math.clamp(grow, 0.03, 1), 1), UDim2.new(), C.green, 0)
		corner(fill, 4)
	end
	for i, b in buttons do
		button(row, "Btn" .. i, b.text, UDim2.fromOffset(100, 42), UDim2.new(1, -(110 * (#buttons - i + 1)), 0, 8), b.color, b.fn)
	end
	return row
end

local function header(parent: Instance, order: number, text: string)
	local h = label(parent, "Header" .. order, text, UDim2.new(1, -10, 0, 28), UDim2.new(), 17, C.gold, Enum.Font.GothamBlack)
	h.TextXAlignment = Enum.TextXAlignment.Left
	h.LayoutOrder = order
end

function UI.refreshPond()
	local st = lastState
	if not st or not refs.pondList then
		return
	end
	for _, c in refs.pondList:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local pond = st.pond or { fish = {}, capacity = 6 }
	local order = 1
	header(refs.pondList, order, string.format("In your pond (%d of %d)", #pond.fish, pond.capacity))
	for i, f in pond.fish do
		order += 1
		local s = FishData.byId[f.id]
		local grow = if s then (f.cm - s.minCm) / (s.maxCm - s.minCm) else 0
		pondRow(refs.pondList, order, (if f.bornHere then "Baby " else "") .. f.name, string.format("%s, %s. Worth %d.", Units.length(f.cm), Units.weight(f.kg), f.price), grow, {
			{ text = "Sell", color = C.green, fn = function()
				callbacks.pond("sell", i)
			end },
			{ text = "Let go", color = C.panel, fn = function()
				callbacks.pond("release", i)
			end },
		})
	end
	if #pond.fish == 0 then
		order += 1
		local l = label(refs.pondList, "Empty", "Nothing here yet. Keep a fish from your bag below.", UDim2.new(1, -10, 0, 30), UDim2.new(), 15, C.dim)
		l.LayoutOrder = order
	end
	order += 1
	header(refs.pondList, order, "In your bag")
	local bag = st.bag or {}
	for i, f in bag do
		order += 1
		pondRow(refs.pondList, order, f.name, string.format("%s. Sells for %d now.", Units.length(f.cm), f.price), nil, {
			{ text = "Keep", color = C.blue, fn = function()
				callbacks.pond("keep", i)
			end },
		})
	end
	if #bag == 0 then
		order += 1
		local l = label(refs.pondList, "BagEmpty", "Your bag is empty. Catch some fish first.", UDim2.new(1, -10, 0, 30), UDim2.new(), 15, C.dim)
		l.LayoutOrder = order
	end
	if UI.inputName() == "R2" and openPanel == "Pond" then
		for _, d in refs.pondList:GetDescendants() do
			if d:IsA("TextButton") then
				GuiService.SelectedObject = d
				break
			end
		end
	end
end

function UI.openPond()
	if locked then
		return
	end
	UI.closePanels()
	openPanel = "Pond"
	refs.pond.Visible = true
	UI.refreshPond()
	refs.pondList.CanvasPosition = Vector2.zero -- always open at the top
end

----------------------------------------------------------------------------------------
-- Tackle Box (L3): the hook size, best grade per bait, and Perfects toward the gold hook.

function UI.buildTackle()
	local p, scroll = panelShell("Tackle", "Tackle Box")
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	refs.tackleList = scroll
	button(p, "Back", "Back to journal", UDim2.fromOffset(170, 40), UDim2.new(0, 12, 1, -48), C.panel2, function()
		UI.toggleJournal()
	end)
	refs.tackleHint = label(p, "Hint", "Lures carry their own hook. Changing hooks takes the bait off, so you bait up again.", UDim2.new(1, -200, 0, 40), UDim2.new(0, 190, 1, -48), 13, C.dim)
	refs.tackle = p
end

function UI.refreshTackle()
	local st = lastState
	if not st or not refs.tackleList then
		return
	end
	for _, c in refs.tackleList:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local order = 1
	header(refs.tackleList, order, "Hook size (for live bait)")
	order += 1
	local hooks = frame(refs.tackleList, "Hooks", UDim2.new(1, -10, 0, 56), UDim2.new(), C.panel, 1)
	hooks.LayoutOrder = order
	local firstBtn: TextButton? = nil
	for i, size in BaitRig.HOOKS do
		local on = st.hook == size
		local b = button(hooks, "Hook" .. size, BaitRig.HOOK_LINES[size], UDim2.new(1 / 3, -6, 1, 0), UDim2.new((i - 1) / 3, 0, 0, 0), if on then Color3.fromRGB(70, 90, 60) else C.panel2, function()
			if callbacks.setHook and not on then
				callbacks.setHook(size)
			end
		end)
		b.TextSize = 15
		if on then
			local stroke = Instance.new("UIStroke")
			stroke.Color = C.gold
			stroke.Thickness = 2
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = b
		end
		firstBtn = firstBtn or b
	end
	order += 1
	header(refs.tackleList, order, "Best bait job")
	local tackle = st.tackle or { best = {}, perfects = 0 }
	for _, b in BaitData.list do
		if BaitRig.recipeFor(b.id) then -- live bait and the lures (L3b)
			order += 1
			local best = tackle.best[b.id]
			local row = frame(refs.tackleList, "Row" .. b.id, UDim2.new(1, -10, 0, 34), UDim2.new(), C.panel2, 0.1)
			row.LayoutOrder = order
			corner(row, 8)
			local name = label(row, "Name", b.name, UDim2.fromOffset(200, 34), UDim2.fromOffset(12, 0), 17, C.text, Enum.Font.GothamBold)
			name.TextXAlignment = Enum.TextXAlignment.Left
			local grade = label(row, "Grade", best or "Not tried on the bench yet", UDim2.new(1, -230, 1, 0), UDim2.fromOffset(220, 0), 16, if best == "Perfect" then C.gold elseif best == "Good" then C.green else C.dim, Enum.Font.GothamBold)
			grade.TextXAlignment = Enum.TextXAlignment.Left
		end
	end
	order += 1
	local goal = BaitRig.GOLD_HOOK_PERFECTS
	local n = tackle.perfects or 0
	local badge = if n >= goal then string.format("Gold hook earned! %d Perfects.", n) else string.format("Perfects: %d of %d for the gold hook.", n, goal)
	local l = label(refs.tackleList, "Perfects", badge, UDim2.new(1, -10, 0, 34), UDim2.new(), 18, C.gold, Enum.Font.GothamBlack)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.LayoutOrder = order
	if UI.inputName() == "R2" and openPanel == "Tackle" and firstBtn then
		GuiService.SelectedObject = firstBtn
	end
end

function UI.openTackle()
	if locked then
		return
	end
	UI.closePanels()
	openPanel = "Tackle"
	refs.tackle.Visible = true
	UI.refreshTackle()
end

function UI.shopHint(text: string)
	if refs.shopHint then
		refs.shopHint.Text = text
	end
end

return UI
