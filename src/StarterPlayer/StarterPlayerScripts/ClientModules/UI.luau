--!strict
-- Code-built interface: top bar, status line, power meter, fight bar, shop, journal, toasts.
-- Pure view: the Controller tells it what to show and passes callbacks for buttons.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
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
local UIStyle = require(Shared.UIStyle)
local Skin = require(script.Parent.Skin)
local BoardCard = require(script.Parent.BoardCard)

local UI = {}

-- The field guide and tackle box look (leg 3, N2, Config.UI_STYLE_ON). Off, every screen is
-- built exactly as before; on, the same screens are dressed from Shared/UIStyle.
local STYLED = Skin.on
local K = UIStyle.COLORS
local LOCK = UIStyle.LOCKED

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
local hasGoals = false -- today's goals are on (the Goals button shows outside fights)
local tabsShown = true -- the side tabs are out (no panel is open; sideTabs)
local benchOpen = false -- the bait bench is on screen (its own ScreenGui, watched in init)

-- The top bar (new look only): steps aside while the bait bench is open, at every size, and
-- on a short screen while a panel takes the whole height (N2 review 2: the bench sat over it).
local function updateTop()
	if not STYLED or not refs.top then
		return
	end
	refs.top.Visible = not benchOpen and not (refs.phone and (not tabsShown or openPanel ~= nil))
end
local cardSpin: RBXScriptConnection? = nil -- turns the fish in the catch card

-- In the new look, the old palette's colours stand for these (a background, or text on paper).
local BG_OF = { panel = "paper", panel2 = "paperDeep", text = "ink", dim = "inkSoft", gold = "brass", green = "sage", red = "clay", blue = "brass", fish = "fish" }
local INK_OF = { panel = "paper", panel2 = "paperDeep", text = "ink", dim = "inkSoft", gold = "brassInk", green = "greenInk", red = "redInk", blue = "waterInk", fish = "ink" }
local BUTTON_OF = { red = "leather", blue = "brass", green = "sage", panel = "off", panel2 = "paper", gold = "brass" }

local function keyOf(c: Color3): string?
	for k, v in C do
		if v == c then
			return k
		end
	end
	return nil
end

-- A background colour: unchanged in the old look.
local function bg(c: Color3): Color3
	if not STYLED then
		return c
	end
	local k = keyOf(c)
	return if k then K[BG_OF[k]] else c
end

-- A text colour: unchanged in the old look; in the new one, an ink that reads on paper.
local function ink(c: Color3): Color3
	if not STYLED then
		return c
	end
	local k = keyOf(c)
	return if k then K[INK_OF[k]] else c
end

-- A button's state colour: the old look sets the colour; the new one paints a surface.
local function paint(b: GuiObject, c: Color3)
	if STYLED then
		Skin.paint(b, BUTTON_OF[keyOf(c) or "panel2"] or "paper")
	else
		b.BackgroundColor3 = c
	end
end

local function setSize(obj: Instance, n: number)
	if STYLED then
		Skin.resize(obj, n)
	else
		(obj :: any).TextSize = n
	end
end

local function corner(parent: Instance, r: number?)
	local c = Instance.new("UICorner")
	local radius = r or 10
	if STYLED and radius < 40 then
		radius = UIStyle.RADIUS.card -- paper and brass, not pills (round things stay round)
	end
	c.CornerRadius = UDim.new(0, radius)
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
	if STYLED then
		f.BackgroundColor3 = bg(color or C.panel)
		-- Paper and canvas are opaque (nothing shows through); see-through overlays stay so.
		f.BackgroundTransparency = if (transparency or 0.15) >= 0.3 then (transparency :: number) else 0
	end
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local FACE_OF: { [Enum.Font]: string } = {
	[Enum.Font.GothamBlack] = "title",
	[Enum.Font.GothamBold] = "bodyBold",
}

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
	if STYLED then
		Skin.text(l, FACE_OF[font or Enum.Font.GothamMedium] or "body", textSize or 18, ink(color or C.text))
	end
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
	if STYLED then
		Skin.button(b, BUTTON_OF[keyOf(color or C.panel2) or "panel2"] or "paper")
	end
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
	-- One rule for every prompt (UIStyle.inputKind): the phone layout on a touch screen counts
	-- as touch even with a keyboard attached (Studio's Device Simulator keeps it on).
	local kind = UIStyle.inputKind(last.Name, UserInputService.TouchEnabled, UserInputService.KeyboardEnabled, refs.phone == true)
	if kind == "touch" then
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
	-- The new look's tab carries a bait icon, so the word "Bait" goes (N2 review 1).
	local prefix = if STYLED then "" else "Bait: "
	if not b then
		return if STYLED then "No bait" else "Bait: none"
	end
	if b.kind == "lure" then
		return prefix .. b.name
	end
	return string.format("%s%s x%d", prefix, b.name, state.bait[b.id] or 0)
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
		-- Panels shrink to fit short phone screens (heights are in scaled units). In the new
		-- look a short screen gets the whole height, and the top bar steps aside (sideTabs).
		local h = gui.AbsoluteSize.Y / scale.Scale
		refs.phone = STYLED and h < UIStyle.PHONE_PANEL_H
		Skin.phone = refs.phone == true
		for _, panel in { refs.shop, refs.journal, refs.pond, refs.tackle } do
			if panel then
				if refs.phone then
					panel.Size = UDim2.fromOffset(640, h - 12)
					panel.Position = UDim2.new(0.5, 0, 0.5, 0)
				else
					panel.Size = UDim2.fromOffset(640, math.min(470, h - 70))
					panel.Position = UDim2.new(0.5, 0, 0.5, 24)
				end
			end
		end
		if refs.boardCard then
			BoardCard.fit(h)
		end
		if refs.fitWeightTag then
			refs.fitWeightTag()
		end
		updateTop()
		if refs.refreshPrompts then
			refs.refreshPrompts()
		end
	end
	refs.rescale = rescale
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)

	-- Key hints follow the device (N2 review 2): reprint them when the input changes.
	UserInputService.LastInputTypeChanged:Connect(function()
		if refs.refreshPrompts then
			refs.refreshPrompts()
		end
	end)
	for _, prop in { "TouchEnabled", "KeyboardEnabled", "GamepadEnabled" } do
		pcall(function()
			UserInputService:GetPropertyChangedSignal(prop):Connect(function()
				if refs.refreshPrompts then
					refs.refreshPrompts()
				end
			end)
		end)
	end

	-- The bait bench is its own ScreenGui (BaitBench, built on first open): while it is on
	-- screen the top bar steps aside (N2 review 2). The bench itself does not move.
	local function watchBench(child: Instance)
		if child.Name == "BaitBench" and child:IsA("ScreenGui") then
			local g = child :: ScreenGui
			local function sync()
				benchOpen = g.Enabled and g.Parent ~= nil
				updateTop()
			end
			g:GetPropertyChangedSignal("Enabled"):Connect(sync)
			g.AncestryChanged:Connect(sync)
			sync()
		end
	end
	for _, child in playerGui:GetChildren() do
		watchBench(child)
	end
	playerGui.ChildAdded:Connect(watchBench)

	-- Top bar: coins, clock, bag. Sits below Roblox's top buttons.
	if STYLED then
		UI.buildStyledTop()
	else
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
	end

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
	local LW = LOCK.power
	local power = frame(gui, "Power", UDim2.fromOffset(LW[1], LW[2]), UDim2.new(LW[3], LW[4], LW[5], LW[6]), C.panel, 0.2)
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
	local fight = frame(gui, "Fight", UDim2.fromOffset(LOCK.fight.size[1], LOCK.fight.size[2]), UDim2.new(LOCK.fight.pos[1], LOCK.fight.pos[2], LOCK.fight.pos[3], LOCK.fight.pos[4]), C.panel, 0.2)
	corner(fight)
	fight.Visible = false
	refs.fightNote = label(fight, "Note", "", UDim2.fromOffset(150, 40), UDim2.fromOffset(0, 2), 15, C.dim)
	local LT = LOCK.fight.track
	local track = frame(fight, "Track", UDim2.fromOffset(LT[1], LT[2]), UDim2.fromOffset(LT[3], LT[4]), Color3.fromRGB(20, 60, 90), 0)
	corner(track, 6)
	refs.zone = frame(track, "Zone", UDim2.new(1, 0, 0.3, 0), UDim2.fromScale(0, 0.5), C.green, 0.35)
	corner(refs.zone, 6)
	refs.fishMark = frame(track, "FishMark", UDim2.new(1, 8, 0, 14), UDim2.fromScale(0, 0.5), C.fish, 0)
	refs.fishMark.Position = UDim2.new(0, -4, 0.5, 0)
	corner(refs.fishMark, 7)
	local LP = LOCK.fight.progress
	local prog = frame(fight, "Progress", UDim2.fromOffset(LP[1], LP[2]), UDim2.fromOffset(LP[3], LP[4]), Color3.fromRGB(40, 40, 40), 0)
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
	local LR = LOCK.fight.reelPrompt
	local prompt = frame(gui, "ReelPrompt", UDim2.fromOffset(LR[1], LR[2]), UDim2.new(LR[3], LR[4], LR[5], LR[6]), C.panel, 0.15)
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
	local LD = LOCK.fight.dragBox
	local dragBox = frame(gui, "DragBox", UDim2.fromOffset(LD[1], LD[2]), UDim2.new(LD[3], LD[4], LD[5], LD[6]), C.panel, 0.3)
	corner(dragBox, 8) -- a dark backing: the line rating under the button didn't read over the dock
	dragBox.Visible = false
	refs.dragBtn = button(dragBox, "Drag", "Drag: Medium", UDim2.fromOffset(150, 36), UDim2.fromOffset(0, 0), C.panel2, function()
		if callbacks.cycleDrag then
			callbacks.cycleDrag()
		end
	end)
	setSize(refs.dragBtn, 16)
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
	-- Right of center so the fish held up on the line stays in view. +30 (was +70): on the
	-- smallest phone the card ran about 20 px off the right edge (11/27/2026).
	if STYLED then
		UI.buildPlate()
	else
		local card = frame(gui, "CatchCard", UDim2.fromOffset(420, 200), UDim2.new(0.5, 30, 0.5, -110), C.panel, 0.05)
		corner(card, 14)
		pad(card, 14)
		card.Visible = false
		refs.cardTitle = label(card, "Title", "", UDim2.new(1, -136, 0, 34), UDim2.fromOffset(0, 0), 24, C.gold, Enum.Font.GothamBlack)
		refs.cardBody = label(card, "Body", "", UDim2.new(1, -140, 0, 60), UDim2.fromOffset(0, 38), 19, C.text)
		refs.cardNote = label(card, "Note", "", UDim2.new(1, -140, 0, 70), UDim2.fromOffset(0, 100), 16, C.dim)
		-- The fish itself, turning slowly in the card (the playtest critic: the reveal was text only).
		-- Lit from the camera's side and brighter all round (it read as a dark silhouette).
		local view = Instance.new("ViewportFrame")
		view.Name = "Fish"
		view.Size = UDim2.fromOffset(130, 130)
		view.Position = UDim2.new(1, -130, 0, 38)
		view.BackgroundColor3 = Color3.fromRGB(20, 40, 55)
		view.BackgroundTransparency = 0.3
		view.Ambient = Color3.fromRGB(215, 215, 215)
		view.LightColor = Color3.fromRGB(255, 250, 240)
		view.LightDirection = Vector3.new(-0.3, -0.6, -1)
		-- The tier's name on a pill of its colour, over the top of the fish window.
		local badge = label(card, "Badge", "", UDim2.fromOffset(130, 24), UDim2.new(1, -130, 0, 26), 15, Color3.new(1, 1, 1), Enum.Font.GothamBlack)
		badge.BackgroundTransparency = 0
		badge.ZIndex = 3
		corner(badge, 12)
		refs.cardBadge = badge
		view.Visible = false
		corner(view, 10)
		view.Parent = card
		-- Rare and up: a shimmer in the tier's colour sweeps across behind the fish (catchCard).
		local shimmer = Instance.new("UIGradient")
		shimmer.Name = "Shimmer"
		shimmer.Enabled = false
		shimmer.Parent = view
		refs.cardShimmer = shimmer
		refs.cardView = view
		refs.card = card
		refs.cardStroke = Instance.new("UIStroke")
		refs.cardStroke.Thickness = 3
		refs.cardStroke.Transparency = 0.1
		refs.cardStroke.Parent = card
		-- The card pops in (bigger pop for rarer fish).
		refs.cardScale = Instance.new("UIScale")
		refs.cardScale.Parent = card
	end

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
	-- The readable chalkboard's card (leg 3, N2): only with BOARD_CARD_ON and UI_STYLE_ON.
	if STYLED and BoardCard.enabled then
		BoardCard.build(gui, function()
			UI.closePanels()
		end)
		refs.boardCard = true
		game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
			if prompt.Name == "BoardPrompt" then
				UI.openBoard()
			end
		end)
	end
	if STYLED then
		UI.dressScreen()
		require(script.Parent.PromptStyle).start() -- brass key caps on the button prompts
	end
	rescale()
end

function UI.setClock(clock: number)
	local weather = workspace:GetAttribute("WeatherName")
	if STYLED then
		-- The time over the weather as a word; the dial turns the sun and moon round.
		refs.clock.Text = clockText(clock)
		refs.weather.Text = if type(weather) == "string" and weather ~= "" then weather else "Clear"
		refs.dialArm.Rotation = (clock - 12) / 24 * 360
		return
	end
	refs.clock.Text = clockText(clock) .. "  " .. FishLogic.periodFromClock(clock) .. (if type(weather) == "string" and weather ~= "Clear" then ", " .. weather else "")
end

function UI.setState(state: any)
	lastState = state
	if STYLED then
		refs.coins.Text = tostring(state.coins)
		refs.bag.Text = string.format("%d fish", state.bagCount)
		refs.bagValue.Text = string.format("worth %d", state.bagValue)
	else
		refs.coins.Text = string.format("%d coins", state.coins)
		refs.bag.Text = string.format("Bag: %d fish (%d)", state.bagCount, state.bagValue)
	end
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
			l.TextColor3 = ink(if g.done then C.green else C.text)
		else
			l.Text = ""
		end
	end
	refs.goalsBtn.Text = string.format("Goals %d/%d", doneCount, #goals)
	hasGoals = #goals > 0
	refs.goalsBtn.Visible = hasGoals and not locked and not (STYLED and openPanel ~= nil) -- no goals while they're switched off; hidden in a fight
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
	if STYLED then
		-- A paper slip behind the words, only while there are words.
		local img = refs.status:FindFirstChild("SkinImage") :: ImageLabel?
		if img then
			img.Visible = text ~= ""
		else
			refs.status.BackgroundTransparency = if text == "" then 1 else 0.04
		end
		local st = refs.status:FindFirstChild("SkinStroke") :: UIStroke?
		if st then
			st.Transparency = if text == "" then 1 else 0
		end
	end
	-- Keep the key hint on the Journal button right for the current device.
	local name = UI.inputName()
	refs.journalBtn.Text = if name == "R2" then "Journal (Y)" elseif name == "click" then "Journal (J)" else "Journal"
end

-- Hides the catch card (its timer ran out, or the player started the next cast) and brings
-- back the status line it was hiding.
local function closeCard()
	refs.card.Visible = false
	refs.card:SetAttribute("Token", nil)
	refs.status.Visible = true
	if cardSpin then
		cardSpin:Disconnect()
		cardSpin = nil
	end
end

function UI.showPower(p: number?)
	if p == nil then
		refs.power.Visible = false
		return
	end
	-- Charging the next cast puts the catch card away.
	if refs.card.Visible then
		closeCard()
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

local lastDrag: string? = nil

-- Reprints every key hint for the device in use now (N2 review 2): the Journal tab, the drag
-- button and the reel hint. Runs when the input, the touch or keyboard state, or the layout
-- changes, so a phone never shows a keyboard key.
local function refreshPrompts()
	if not refs.journalBtn then
		return
	end
	local name = UI.inputName()
	refs.journalBtn.Text = if name == "R2" then "Journal (Y)" elseif name == "click" then "Journal (J)" else "Journal"
	if refs.dragBox and refs.dragBox.Visible and lastDrag then
		local key = if name == "R2" then " (Y)" elseif name == "click" then " (Q)" else ""
		refs.dragBtn.Text = "Drag: " .. lastDrag .. key
	end
	if refs.fight and refs.fight.Visible and refs.reelSub then
		refs.reelSub.Text = reelHowTo()
	end
end
refs.refreshPrompts = refreshPrompts

-- The drag button's text (L4d): the setting, the key for this device, and the line rating.
function UI.showDrag(drag: string?, lineLb: number?)
	if not drag then
		refs.dragBox.Visible = false
		return
	end
	lastDrag = drag
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
			refs.touchFish.BackgroundColor3 = bg(C.blue)
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
	refs.zone.BackgroundColor3 = bg(if inside then C.green else C.red)
	refs.progFill.Size = UDim2.fromScale(1, s.progress)
	refs.progFill.Position = UDim2.fromScale(0, 1 - s.progress)

	-- Cue beside the zone (the track sits 46 px down and is 236 px tall), but never lower than
	-- the drag box's top (200 px down the bar), which used to cover it (playtest critic).
	local cueY = math.min(46 + (1 - s.zonePos) * 236 - 20, 158)
	refs.cue.Position = UDim2.new(1, 10, 0, cueY)
	if inside then
		refs.cue.Text = "Nice!"
		refs.cue.TextColor3 = ink(C.green)
	elseif s.fishPos > s.zonePos then
		refs.cue.Text = "HOLD"
		refs.cue.TextColor3 = ink(C.gold)
	else
		refs.cue.Text = "LET GO"
		refs.cue.TextColor3 = ink(C.blue)
	end

	-- Feedback while holding: bright outline, prompt turns green, touch button lights up.
	refs.zoneStroke.Thickness = if holding then 3 else 0
	local strain = if type(s.strain) == "number" then s.strain else 0
	if strain >= 0.5 then
		-- Line and drag (L4d): the line is close to snapping. Let go!
		refs.reelTitle.Text = "EASE OFF!"
		refs.reelTitle.TextColor3 = ink(if (os.clock() % 0.3) < 0.15 then C.red else C.text)
	elseif not inside and s.fishPos < s.zonePos then
		-- The fish is below the zone: the cue says LET GO, so the big prompt says it too (the
		-- playtest critic saw HOLD TO REEL beside LET GO).
		refs.reelTitle.Text = if holding then "LET GO!" else "LET IT DROP"
		refs.reelTitle.TextColor3 = ink(C.blue)
	elseif holding then
		refs.reelTitle.Text = "REELING!"
		refs.reelTitle.TextColor3 = ink(C.green)
	elseif slack then
		-- No press for a while: the line has gone slack and the fish is working free.
		refs.reelTitle.Text = "KEEP REELING!"
		refs.reelTitle.TextColor3 = ink(if (os.clock() % 0.5) < 0.25 then C.red else C.gold)
	else
		refs.reelTitle.Text = "HOLD TO REEL"
		refs.reelTitle.TextColor3 = ink(if (os.clock() % 0.8) < 0.4 then C.gold else C.text)
	end
	if refs.touchFish then
		refs.touchFish.Text = "REEL"
		refs.touchFish.BackgroundColor3 = bg(if holding then C.green else C.gold)
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
	if STYLED then
		-- A paper slip in ink; the colour it came with becomes a ribbon down its left edge.
		t.TextColor3 = K.ink
		Skin.surface(t, "paper", "card", 1)
		local u = Skin.padPaper(t)
		u.PaddingLeft = UDim.new(0, 22)
		local P = UIStyle.PAPER_PAD
		local ribbon = Instance.new("Frame")
		ribbon.Name = "Ribbon"
		ribbon.BorderSizePixel = 0
		ribbon.BackgroundColor3 = color or K.brass
		ribbon.Size = UDim2.new(0, 7, 1, P.top + P.bottom - 12)
		ribbon.Position = UDim2.fromOffset(-16, -P.top + 6)
		ribbon.Parent = t
	end
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
	if STYLED then
		UI.fillPlate(payload)
		return
	end
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
	-- The cast prompt waits until the card is gone (the playtest critic: "Face the water" came
	-- back under the card at once).
	refs.status.Visible = false
	local rank = Rarity.rank[tier] or 1
	refs.cardBadge.Text = string.upper((Rarity.byId[tier] or Rarity.byId.Common).name)
	refs.cardBadge.BackgroundColor3 = color
	refs.cardBadge.TextColor3 = if rank == 1 or rank == 7 then Color3.fromRGB(25, 25, 30) else Color3.new(1, 1, 1)
	refs.cardScale.Scale = if rank >= 3 then 0.6 else 0.85
	TweenService:Create(refs.cardScale, TweenInfo.new(if rank >= 3 then 0.45 else 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- Rare and up: the fish sits in a sweep of the tier's colour.
	local shimmer = refs.cardShimmer :: UIGradient
	shimmer.Enabled = rank >= 3
	-- A gradient multiplies the frame's own colour, so the frame goes white under it.
	refs.cardView.BackgroundColor3 = if rank >= 3 then Color3.new(1, 1, 1) else Color3.fromRGB(20, 40, 55)
	if rank >= 3 then
		shimmer.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 40, 55)),
			ColorSequenceKeypoint.new(0.5, color),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 40, 55)),
		})
	end
	local token = os.clock()
	refs.card:SetAttribute("Token", token)
	UI.showCardFish(token)
	task.delay(if payload.first or rank >= 3 then 6 else 4, function()
		if refs.card:GetAttribute("Token") == token then
			closeCard()
		end
	end)
end

----------------------------------------------------------------------------------------
-- The new look (Config.UI_STYLE_ON): the top bar, the catch plate and the dressing of the
-- rest. Nothing below runs in the old look.

-- The weight tag at the current scale: the weight on two lines, the tag grown so both fit
-- (UIStyle.weightTagFit). Only the drawn tag; the plain fallback keeps one line.
local function fitWeightTag()
	local tag = refs.cardWeightTag :: Frame?
	local label = refs.cardWeight :: TextLabel?
	if not tag or not label then
		return
	end
	local text = (string.gsub(label.Text, "\n", " "))
	local cam = workspace.CurrentCamera
	local scale = if cam then UIStyle.uiScale(cam.ViewportSize.X, cam.ViewportSize.Y) else Skin.scale()
	local a = UIStyle.IMAGES.weightTag.textArea :: { number }
	local lines, k, size, w, h = UIStyle.weightTagFit(text, scale)
	tag.Size = UDim2.fromOffset(96 * k, 128 * k)
	label.Size = UDim2.fromOffset(w, h)
	label.Position = UDim2.fromOffset(a[1] * k, a[2] * k)
	label.Text = lines
	label.TextSize = size
end
refs.fitWeightTag = fitWeightTag

local function styledLabel(parent: Instance, name: string, text: string, size: UDim2, pos: UDim2, face: string, base: string | number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextWrapped = true
	Skin.text(l, face, base, color)
	l.Parent = parent
	return l
end

local function disc(parent: Instance, name: string, d: number, pos: UDim2, color: Color3, strokeColor: Color3?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(d, d)
	f.Position = pos
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	Skin.corner(f, "round")
	if strokeColor then
		Skin.stroke(f, strokeColor, 1.5)
	end
	f.Parent = parent
	return f
end

-- Top bar: a paper strip with a brass coin and the count, a sun-and-moon dial with the time
-- and the weather as a word, and a creel with the bag.
function UI.buildStyledTop()
	local top = Instance.new("Frame")
	top.Name = "TopBar"
	top.Size = UDim2.fromOffset(548, 60)
	top.Position = UDim2.new(0.5, -274, 0, 6)
	top.BorderSizePixel = 0
	Skin.surface(top, "paper", "panel")
	top.Parent = gui

	-- The coin: brass with a rim.
	local coin = Instance.new("Frame")
	coin.Name = "Coin"
	coin.Size = UDim2.fromOffset(40, 40)
	coin.Position = UDim2.fromOffset(12, 10)
	coin.BorderSizePixel = 0
	Skin.surface(coin, "coin", "round")
	coin.Parent = top
	if not UIStyle.IMAGES.coin.id then
		local rim = disc(coin, "Rim", 28, UDim2.fromScale(0.5, 0.5), K.brass, K.brassDark)
		rim.BackgroundTransparency = 1
	end
	refs.coins = styledLabel(top, "Coins", "0", UDim2.fromOffset(136, 60), UDim2.fromOffset(60, 0), "title", "heading", K.ink)
	refs.coins.TextXAlignment = Enum.TextXAlignment.Left
	Skin.rule(top, "Rule1", UDim2.fromOffset(1, 40), UDim2.fromOffset(200, 10))

	-- The dial: the sun at the top at noon, the moon at the top at midnight.
	local dial = Instance.new("Frame")
	dial.Name = "Dial"
	dial.Size = UDim2.fromOffset(44, 44)
	dial.Position = UDim2.fromOffset(212, 8)
	dial.BorderSizePixel = 0
	Skin.surface(dial, "dial", "round")
	dial.Parent = top
	local arm = Instance.new("Frame")
	arm.Name = "Arm"
	arm.AnchorPoint = Vector2.new(0.5, 0.5)
	arm.Position = UDim2.fromScale(0.5, 0.5)
	arm.Size = UDim2.fromScale(1, 1)
	arm.BackgroundTransparency = 1
	arm.Parent = dial
	-- With the art: the dial face stays still (day on top) and its hand turns, up at noon.
	-- Without it: a sun and a moon on a turning arm.
	local hand = Skin.image(dial, "dialHand", UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5))
	if hand then
		hand.AnchorPoint = Vector2.new(0.5, 0.5)
		arm:Destroy()
		refs.dialArm = hand
	else
		disc(arm, "Sun", 14, UDim2.fromScale(0.5, 0.2), K.brass, K.brassDark)
		disc(arm, "Moon", 12, UDim2.fromScale(0.5, 0.8), K.paper, K.inkSoft)
		Skin.rule(dial, "Horizon", UDim2.new(1, -8, 0, 1), UDim2.new(0, 4, 0.5, 0), K.brassDark)
		refs.dialArm = arm
	end
	refs.clock = styledLabel(top, "Clock", "7:00 AM", UDim2.fromOffset(130, 28), UDim2.fromOffset(264, 4), "bodyBold", "body", K.ink)
	refs.clock.TextXAlignment = Enum.TextXAlignment.Left
	refs.weather = styledLabel(top, "Weather", "Clear", UDim2.fromOffset(130, 26), UDim2.fromOffset(264, 30), "hand", "note", K.inkSoft)
	refs.weather.TextXAlignment = Enum.TextXAlignment.Left
	Skin.rule(top, "Rule2", UDim2.fromOffset(1, 40), UDim2.fromOffset(398, 10))

	-- The creel: a wicker box with a lid strap and a handle.
	local creel = Instance.new("Frame")
	creel.Name = "Creel"
	creel.Size = UDim2.fromOffset(34, 30)
	creel.Position = UDim2.fromOffset(410, 18)
	creel.BorderSizePixel = 0
	Skin.surface(creel, "creel", "tag")
	creel.Parent = top
	if not UIStyle.IMAGES.creel.id then
		Skin.rule(creel, "Lid", UDim2.new(1, 0, 0, 3), UDim2.fromOffset(0, 7), K.leather)
		local handle = Instance.new("Frame")
		handle.Name = "Handle"
		handle.Size = UDim2.fromOffset(18, 8)
		handle.Position = UDim2.fromOffset(8, -9)
		handle.BackgroundTransparency = 1
		Skin.stroke(handle, K.leather, 2)
		Skin.corner(handle, "tag")
		handle.Parent = creel
	end
	refs.bag = styledLabel(top, "Bag", "0 fish", UDim2.fromOffset(92, 30), UDim2.fromOffset(452, 4), "bodyBold", "body", K.ink)
	refs.bag.TextXAlignment = Enum.TextXAlignment.Left
	refs.bagValue = styledLabel(top, "BagValue", "worth 0", UDim2.fromOffset(92, 24), UDim2.fromOffset(452, 32), "body", "small", K.inkSoft)
	refs.bagValue.TextXAlignment = Enum.TextXAlignment.Left
	refs.top = top
end

-- The catch card as a field-guide plate: the fish in its window on paper with a ruled length
-- line, the name in the serif, the weight on a hanging tag, the tier as a stamped seal and a
-- ribbon of its colour along the top.
function UI.buildPlate()
	local card = Instance.new("Frame")
	card.Name = "CatchCard"
	card.Size = UDim2.fromOffset(420, 260)
	card.Position = UDim2.new(0.5, 30, 0.5, -130)
	card.BorderSizePixel = 0
	Skin.surface(card, "paper", "card")
	card.Visible = false
	card.Parent = gui
	-- (No ribbon along the top: the 8-unit strip read as a selection bar, N2 review 1. The
	-- tier's colour is on the seal and the stamp.)
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.new(1, -28, 1, -36)
	inner.Position = UDim2.fromOffset(14, 20)
	inner.Parent = card

	-- Left column: what it is and what it is worth.
	local LEFT = 204 -- the left column's width; the right column (window, ruler) is 176
	local RIGHT = 176
	refs.cardKicker = styledLabel(inner, "Kicker", "", UDim2.fromOffset(LEFT, 28), UDim2.fromOffset(0, -4), "hand", "note", K.inkSoft)
	refs.cardKicker.TextXAlignment = Enum.TextXAlignment.Left
	refs.cardTitle = styledLabel(inner, "Title", "", UDim2.fromOffset(LEFT, 62), UDim2.fromOffset(0, 24), "title", 24, K.ink)
	refs.cardTitle.TextXAlignment = Enum.TextXAlignment.Left
	refs.cardTitle.TextYAlignment = Enum.TextYAlignment.Top
	refs.cardBody = styledLabel(inner, "Body", "", UDim2.fromOffset(LEFT, 26), UDim2.fromOffset(0, 90), "bodyBold", "body", K.brassInk)
	refs.cardBody.TextXAlignment = Enum.TextXAlignment.Left
	refs.cardNote = styledLabel(inner, "Note", "", UDim2.fromOffset(LEFT, 104), UDim2.fromOffset(0, 120), "hand", "note", K.inkSoft)
	refs.cardNote.TextXAlignment = Enum.TextXAlignment.Left
	refs.cardNote.TextYAlignment = Enum.TextYAlignment.Top
	refs.cardNote.TextTruncate = Enum.TextTruncate.AtEnd

	-- Right column: the window with the fish, the ruler under it, the length.
	local window = Instance.new("Frame")
	window.Name = "Window"
	window.Size = UDim2.fromOffset(RIGHT, 122)
	window.Position = UDim2.new(1, -RIGHT, 0, 6)
	window.BorderSizePixel = 0
	window.BackgroundColor3 = K.paper
	Skin.corner(window, "tag")
	Skin.stroke(window, K.ink, 2)
	window.Parent = inner
	local view = Instance.new("ViewportFrame")
	view.Name = "Fish"
	view.Size = UDim2.new(1, -6, 1, -6)
	view.Position = UDim2.fromOffset(3, 3)
	view.BackgroundColor3 = K.paper
	view.BackgroundTransparency = 0
	view.BorderSizePixel = 0
	view.Ambient = Color3.fromRGB(215, 215, 215)
	view.LightColor = Color3.fromRGB(255, 250, 240)
	view.LightDirection = Vector3.new(-0.3, -0.6, -1)
	view.Visible = false
	view.Parent = window
	local shimmer = Instance.new("UIGradient")
	shimmer.Name = "Shimmer"
	shimmer.Enabled = false
	shimmer.Parent = view
	refs.cardShimmer = shimmer
	refs.cardView = view

	local ruler = Instance.new("Frame")
	ruler.Name = "Ruler"
	ruler.BackgroundTransparency = 1
	ruler.Size = UDim2.fromOffset(RIGHT, 12)
	ruler.Position = UDim2.new(1, -RIGHT, 0, 134)
	ruler.Parent = inner
	local rulerArt = Skin.image(ruler, "ruler", UDim2.fromScale(1, 1), UDim2.new(), K.ink)
	if rulerArt then
		rulerArt.ScaleType = Enum.ScaleType.Tile
		rulerArt.TileSize = UDim2.fromOffset(96, 12) -- the 256 by 32 strip at 12 tall
	else
		Skin.rule(ruler, "Line", UDim2.new(1, 0, 0, 2), UDim2.fromOffset(0, 0), K.ink)
		for i = 0, 10 do
			local tall = i % 5 == 0
			Skin.rule(ruler, "Tick" .. i, UDim2.fromOffset(1, if tall then 10 else 5), UDim2.fromOffset(math.min(math.floor(i * RIGHT / 10), RIGHT - 1), 2), K.ink)
		end
	end
	refs.cardLength = styledLabel(inner, "Length", "", UDim2.fromOffset(RIGHT, 24), UDim2.new(1, -RIGHT, 0, 148), "bodyBold", "body", K.ink)

	-- The weight on a brass tag hanging on a string over the window's corner.
	local tagArt = UIStyle.IMAGES.weightTag
	local tag = Instance.new("Frame")
	tag.Name = "WeightTag"
	tag.AnchorPoint = Vector2.new(0.5, 0)
	tag.Rotation = 6
	tag.BorderSizePixel = 0
	tag.ZIndex = 5
	if tagArt.id then
		-- The drawn tag carries its own string off the top: hang it from the card's top edge,
		-- the weight inside its text area (x 21 to 75, y 56 to 116 of 96 by 128).
		local k = 0.6
		tag.Size = UDim2.fromOffset(96 * k, 128 * k)
		tag.Position = UDim2.new(1, -30, 0, -20)
		Skin.surface(tag, "weightTag", "tag")
		local a = tagArt.textArea :: { number }
		refs.cardWeight = styledLabel(tag, "Weight", "", UDim2.fromOffset((a[3] - a[1]) * k, (a[4] - a[2]) * k), UDim2.fromOffset(a[1] * k, a[2] * k), "bodyBold", UIStyle.WEIGHT_TAG.base, K.ink)
		-- Two set lines, never wrapped (a wrapped line that does not fit is dropped, which cut
		-- "5 oz" on a phone); fitWeightTag grows the tag until both fit (N2 review 2).
		refs.cardWeight.TextWrapped = false
		refs.cardWeight.LineHeight = UIStyle.WEIGHT_TAG.lineHeight
		refs.cardWeightTag = tag
	else
		local cord = Skin.rule(inner, "TagString", UDim2.fromOffset(2, 22), UDim2.new(1, -30, 0, -8), K.inkSoft)
		cord.ZIndex = 4
		tag.Size = UDim2.fromOffset(78, 34)
		tag.Position = UDim2.new(1, -29, 0, 12)
		Skin.surface(tag, "weightTag", "tag")
		local hole = disc(tag, "Hole", 6, UDim2.new(0.5, 0, 0, 5), K.paper, K.brassDark)
		hole.ZIndex = 6
		refs.cardWeight = styledLabel(tag, "Weight", "", UDim2.new(1, 0, 1, -6), UDim2.fromOffset(0, 6), "bodyBold", "body", K.ink)
	end
	tag.Parent = inner
	refs.cardWeight.ZIndex = 6

	-- The stamp: a double ring and the tier's name in the tier's ink, a little crooked.
	local stamp = Instance.new("Frame")
	stamp.Name = "Stamp"
	stamp.Size = UDim2.fromOffset(140, 42)
	stamp.Position = UDim2.new(1, -RIGHT + (RIGHT - 140) / 2, 0, 178) -- centred under the window
	stamp.Rotation = -7
	stamp.BorderSizePixel = 0
	stamp.ZIndex = 5
	Skin.corner(stamp, "tag")
	refs.cardStampStroke = Skin.stroke(stamp, K.ink, 3)
	stamp.Parent = inner
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.new(1, -8, 1, -8)
	ring.Position = UDim2.fromOffset(4, 4)
	ring.ZIndex = 5
	Skin.corner(ring, "tag")
	refs.cardStampRing = Skin.stroke(ring, K.ink, 1)
	ring.Parent = stamp
	refs.cardBadge = styledLabel(stamp, "Tier", "", UDim2.fromScale(1, 1), UDim2.new(), "title", 18, K.ink)
	refs.cardBadge.ZIndex = 6
	refs.cardStamp = stamp
	-- With the art: the seal, a mark of the tier's colour, pressed beside the written name.
	refs.cardSeal = Skin.image(inner, "raritySeal", UDim2.fromOffset(40, 40), UDim2.new(1, -RIGHT + (RIGHT - 140) / 2 - 30, 0, 176))
	if refs.cardSeal then
		refs.cardSeal.Rotation = -12
		refs.cardSeal.ZIndex = 4
	end

	refs.card = card
	refs.cardStroke = card:FindFirstChild("SkinStroke") -- nil over the paper art (its edge is drawn)
	refs.cardScale = Instance.new("UIScale")
	refs.cardScale.Parent = card
end

function UI.fillPlate(payload: any)
	local f = payload.fish
	local tier = payload.tier or Rarity.of(FishData.byId[f.id])
	local rank = Rarity.rank[tier] or 1
	local now = os.clock()
	local exact = Rarity.colorAt(tier, now)
	local tierInk = UIStyle.rarityInk(tier, now)
	local class = Rarity.sizeClassOf(f)
	local kicker = {}
	if class == "monster" then
		table.insert(kicker, "Monster!")
	elseif class == "trophy" then
		table.insert(kicker, "Trophy!")
	end
	if payload.first then
		table.insert(kicker, "New species!")
	end
	if payload.best then
		table.insert(kicker, "Personal best!")
	end
	refs.cardKicker.Text = table.concat(kicker, " ")
	refs.cardKicker.TextColor3 = tierInk
	refs.cardTitle.Text = f.name
	refs.cardBody.Text = string.format("Worth %d coins.", f.price)
	refs.cardNote.Text = if payload.first then ("New in your journal: " .. payload.habit) else ("Caught at " .. (FishLogic.SPOT_NAMES[f.spot] or f.spot) .. " on " .. ((BaitData.byId[f.bait] and BaitData.byId[f.bait].name) or f.bait) .. ".")
	refs.cardLength.Text = Units.length(f.cm)
	refs.cardWeight.Text = Units.weight(f.kg)
	fitWeightTag()
	if refs.cardRibbon then
		Skin.tint(refs.cardRibbon, exact)
	end
	local plateStroke = refs.cardStroke :: UIStroke?
	if plateStroke then
		plateStroke.Color = tierInk
		plateStroke.Thickness = UIStyle.STROKE.plate
	end
	refs.cardBadge.Text = string.upper((Rarity.byId[tier] or Rarity.byId.Common).name)
	refs.cardBadge.TextColor3 = tierInk
	refs.cardStampStroke.Color = tierInk
	refs.cardStampRing.Color = tierInk
	refs.cardStamp.BackgroundColor3 = UIStyle.mix(exact, K.paper, UIStyle.STAMP_TINT)
	if refs.cardSeal then
		refs.cardSeal.ImageColor3 = exact
	end
	refs.card.Visible = true
	refs.status.Visible = false
	refs.cardScale.Scale = if rank >= 3 then 0.6 else 0.85
	TweenService:Create(refs.cardScale, TweenInfo.new(if rank >= 3 then 0.45 else 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- Rare and up: a sweep of the tier's colour behind the fish (a gradient multiplies the
	-- window's own colour, so the window goes white under it).
	local shimmer = refs.cardShimmer :: UIGradient
	shimmer.Enabled = rank >= 3
	refs.cardView.BackgroundColor3 = if rank >= 3 then Color3.new(1, 1, 1) else K.paper
	if rank >= 3 then
		shimmer.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, K.paper),
			ColorSequenceKeypoint.new(0.5, exact),
			ColorSequenceKeypoint.new(1, K.paper),
		})
	end
	local token = os.clock()
	refs.card:SetAttribute("Token", token)
	UI.showCardFish(token)
	task.delay(if payload.first or rank >= 3 then 6 else 4, function()
		if refs.card:GetAttribute("Token") == token then
			closeCard()
		end
	end)
end

-- Dresses the screens built above (the HUD, the fight, the toasts) in the new look. Sizes and
-- places of the fight bar, its track, the reel prompt and the power meter stay as built.
function UI.dressScreen()
	local T = Skin.TOUCH

	-- The side buttons become tabs on the edge of a tackle box: a leather strap down the left
	-- edge, canvas tabs with a brass rivet, each a full thumb tall.
	local strap = Instance.new("Frame")
	strap.Name = "TackleEdge"
	strap.Size = UDim2.fromOffset(12, 3 * T + 40)
	strap.Position = UDim2.new(0, 0, 0.5, -(3 * T + 40) / 2)
	strap.BorderSizePixel = 0
	Skin.surface(strap, "leather", "tag")
	strap.Parent = gui
	refs.tabStrap = strap
	local icons = { "bait", "journal", "goals" }
	for i, b in { refs.baitBtn, refs.journalBtn, refs.goalsBtn } do
		b.Size = UDim2.fromOffset(176, T)
		b.Position = UDim2.new(0, 6, 0.5, -(3 * T + 16) / 2 + (i - 1) * (T + 8))
		Skin.button(b, "tab")
		local u = Skin.pad(b, 6)
		u.PaddingRight = UDim.new(0, 22)
		local icon = Skin.image(b, icons[i], UDim2.fromOffset(34, 34), UDim2.new(0, 0, 0.5, -17))
		if icon then
			-- The drawn tab: content from x = 22 x SliceScale; the icon at content x 0 and the
			-- words left-aligned from content x 40 (N2 review 1).
			local edge = math.floor(22 * T / 96)
			icon.ZIndex = 3
			icon.Position = UDim2.new(0, -40, 0.5, -17)
			u.PaddingLeft = UDim.new(0, edge + 40)
			b.TextXAlignment = Enum.TextXAlignment.Left
		else
			local rivet = disc(b, "Rivet", 10, UDim2.new(1, -12, 0.5, 0), K.brass, K.brassDark)
			rivet.ZIndex = 2
		end
	end

	-- Today's goals: a handwritten note pinned beside the tabs.
	local goals = refs.goalsBox :: Frame
	goals.Size = UDim2.fromOffset(340, 0)
	goals.AutomaticSize = Enum.AutomaticSize.Y
	goals.Position = UDim2.new(0, 196, 0.5, -(3 * T + 16) / 2)
	goals.Rotation = -1
	-- The list moves into a body frame, so the paper image is not laid out as a line.
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.ZIndex = 2
	for _, c in goals:GetChildren() do
		if c:IsA("UIListLayout") or c:IsA("GuiObject") then
			c.Parent = body
		end
	end
	body.Parent = goals
	Skin.surface(goals, "paper", "card", 1)
	Skin.padPaper(goals)
	Skin.text(refs.goalsTitle, "title", "heading", K.ink)
	refs.goalsTitle.Size = UDim2.new(1, 0, 0, 30)
	for _, l in refs.goalLines do
		Skin.text(l, "hand", "note", K.ink)
		l.Size = UDim2.new(1, 0, 0, 0)
		l.AutomaticSize = Enum.AutomaticSize.Y
	end

	-- The status line sits on a paper slip that hugs its words (nothing over the water glare).
	local status = refs.status :: TextLabel
	status.TextStrokeTransparency = 1
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.new(0.5, 0, 1, -150)
	-- One line, never wrapped (it wrapped word by word inside the hugging slip): it grows
	-- sideways only, 36 tall (N2 review 1). The copy over the paper art follows TextWrapped.
	status.Size = UDim2.fromOffset(0, 36)
	status.AutomaticSize = Enum.AutomaticSize.X
	status.TextWrapped = false
	Skin.text(status, "bodyBold", 20, K.ink)
	Skin.surface(status, "paper", "card", 1)
	local su = Skin.padPaper(status)
	su.PaddingTop = UDim.new(0, 0)
	su.PaddingBottom = UDim.new(0, 0)
	status.BackgroundTransparency = 1
	local sst = status:FindFirstChild("SkinStroke") :: UIStroke?
	if sst then
		sst.Transparency = 1
	end
	local simg = status:FindFirstChild("SkinImage") :: ImageLabel?
	if simg then
		simg.Visible = false
	end

	-- The power meter: a wood frame with a brass fill.
	Skin.surface(refs.power, "fightFrame", "tag", nil, 0.35)
	local powerArt = refs.power:FindFirstChild("SkinImage") :: ImageLabel?
	if powerArt then
		powerArt.ZIndex = 2 -- the frame over the fill; the fill shows through its window
	end
	refs.powerFill.BackgroundColor3 = K.brass
	Skin.corner(refs.powerFill, "tag")

	-- The bite: a brass mark outlined in ink.
	refs.bite.TextColor3 = K.brass
	refs.bite.TextStrokeColor3 = K.ink
	Skin.text(refs.bite, "title", 110, K.brass)

	-- The fight bar: wood and brass, a water-blue track, a fish silhouette for the marker.
	local fight = refs.fight :: Frame
	Skin.surface(fight, "woodPanel", "panel", 3)
	local track = fight:FindFirstChild("Track") :: Frame
	Skin.surface(track, "waterTrack", "tag", 2, 0.7)
	-- The drawn wood and brass frame lies over the track, its window see-through (window
	-- x 16 to 240, y 15 to 46 of 256 by 64, so about 15 px of rail all round at SliceScale 1).
	local frameArt = Skin.image(track, "fightFrame", UDim2.new(1, 22, 1, 22), UDim2.fromOffset(-11, -11))
	if frameArt then
		frameArt.ScaleType = Enum.ScaleType.Slice
		frameArt.SliceCenter = UIStyle.sliceRect("fightFrame") :: Rect
		frameArt.SliceScale = 0.7
		frameArt.ZIndex = 6
	end
	refs.zoneStroke.Color = K.paper
	local mark = refs.fishMark :: Frame
	local fishImg = Skin.image(mark, "fishMarker", UDim2.new(1, 8, 1, 12), UDim2.fromOffset(-4, -6), K.fish)
	if fishImg then
		mark.BackgroundTransparency = 1
	else
		-- No art yet: a dark body with a paper outline and a tail.
		mark.BackgroundColor3 = K.fish
		Skin.corner(mark, "round")
		Skin.stroke(mark, K.paper, 1.5)
		local tail = Instance.new("Frame")
		tail.Name = "Tail"
		tail.AnchorPoint = Vector2.new(0.5, 0.5)
		tail.Size = UDim2.fromOffset(12, 12)
		tail.Position = UDim2.new(0, 0, 0.5, 0)
		tail.Rotation = 45
		tail.BorderSizePixel = 0
		tail.BackgroundColor3 = K.fish
		Skin.stroke(tail, K.paper, 1.5)
		tail.ZIndex = 0
		tail.Parent = mark
	end
	local prog = fight:FindFirstChild("Progress") :: Frame
	prog.BackgroundColor3 = K.woodDark
	Skin.stroke(prog, K.brassDark, 1)
	refs.progFill.BackgroundColor3 = K.brass
	Skin.text(refs.fightNote, "body", 15, K.paper)
	refs.fightNote.LineHeight = 0.9
	Skin.text(refs.fightHelp, "bodyBold", 15, K.paper)
	refs.fightHelp.Text = "Hold to reel"
	-- The cue rides beside the zone over the water: a paper chip so it reads anywhere.
	local cue = refs.cue :: TextLabel
	-- A fixed chip, one line, so "Nice!" reads whole (it wrapped inside the hugging chip).
	cue.TextStrokeTransparency = 1
	cue.Size = UDim2.fromOffset(124, 40)
	cue.AutomaticSize = Enum.AutomaticSize.None
	cue.TextWrapped = false
	Skin.surface(cue, "paper", "tag", 1)
	local cuePad = Skin.pad(cue, 0)
	cuePad.PaddingLeft = UDim.new(0, 10)
	cuePad.PaddingRight = UDim.new(0, 8)
	-- The reel prompt: a paper slip with a brass edge.
	Skin.surface(refs.reelPrompt, "paper", "card", 2)
	Skin.text(refs.reelTitle, "title", 30, K.brassInk)
	Skin.text(refs.reelSub, "body", 17, K.ink)
	-- The drag box keeps its place and grows to a thumb's height; the line rating rides inside
	-- the button so the whole box is one target.
	local dragBox = refs.dragBox :: Frame
	dragBox.Size = UDim2.fromOffset(LOCK.fight.dragBox[1], T)
	dragBox.BackgroundTransparency = 1
	local dragBtn = refs.dragBtn :: TextButton
	dragBtn.Size = UDim2.fromOffset(LOCK.fight.dragBox[1], T)
	dragBtn.TextYAlignment = Enum.TextYAlignment.Top
	Skin.button(dragBtn, "brass", 16)
	Skin.pad(dragBtn, 6)
	local line = refs.dragLine :: TextLabel
	line.TextStrokeTransparency = 1
	line.Parent = dragBtn
	-- 26 down from the button's top (its content starts 6 down), above the brass face's
	-- lower edge at 51 (N2 review 1).
	line.Size = UDim2.new(1, 0, 0, 22)
	line.Position = UDim2.fromOffset(0, 26 - 6)
	line.ZIndex = 3
	Skin.text(line, "bodyBold", 14, K.ink)

	-- Toasts under the taller top bar.
	refs.toasts.Position = UDim2.new(0.5, -280, 0, 74)

	-- The touch Fish button: a big brass button.
	if refs.touchFish then
		local fb = refs.touchFish :: TextButton
		Skin.text(fb, "title", 28, K.ink)
		fb.BackgroundColor3 = K.brass
		fb.BackgroundTransparency = 0
		Skin.stroke(fb, K.brassDark, 3)
	end
end

-- In the new look the side tabs and the status line step aside while a panel is open (the
-- critic saw them peeking out from behind the shop and the journal on a phone).
local function sideTabs(show: boolean)
	if not STYLED then
		return
	end
	local on = show and not locked
	refs.baitBtn.Visible = on
	refs.journalBtn.Visible = on
	refs.goalsBtn.Visible = on and hasGoals
	refs.tabStrap.Visible = on
	if not show then
		refs.goalsBox.Visible = false
	end
	if not refs.card.Visible then
		refs.status.Visible = show
	end
	-- On a short screen a panel takes the whole height: the top bar steps aside too.
	tabsShown = show
	updateTop()
end
UI.sideTabs = sideTabs

-- The landed fish in the catch card: a copy of the one the server hangs on the line
-- ("CaughtFish_<name>", FishingService.showCatch), lying flat and turning slowly. If it
-- doesn't turn up within a moment (no model), the card stays text only.
function UI.showCardFish(token: number)
	local view = refs.cardView :: ViewportFrame
	-- The last fish and its camera go; the view's corner and shimmer stay.
	for _, c in view:GetChildren() do
		if not c:IsA("UIComponent") then
			c:Destroy()
		end
	end
	view.Visible = false
	if cardSpin then
		cardSpin:Disconnect()
		cardSpin = nil
	end
	task.spawn(function()
		local name = "CaughtFish_" .. Players.LocalPlayer.Name
		local hung: Instance? = nil
		for _ = 1, 30 do
			hung = workspace:FindFirstChild(name)
			if hung or refs.card:GetAttribute("Token") ~= token then
				break
			end
			task.wait(0.05)
		end
		local body = hung and hung:FindFirstChild("Body")
		if not body or not body:IsA("BasePart") or refs.card:GetAttribute("Token") ~= token then
			return
		end
		local fish = body:Clone()
		fish.Anchored = true
		local isMesh = fish:IsA("MeshPart")
		local len = if isMesh then fish.Size.X else fish.Size.Y -- the art model runs along X; the stand-in stands along Y
		-- Lying flat, head to the left (the art model's head points along -X).
		local flat = if isMesh then CFrame.identity else CFrame.Angles(0, 0, math.rad(90))
		fish.CFrame = flat
		fish.Parent = view
		local cam = Instance.new("Camera")
		cam.FieldOfView = 40
		cam.CFrame = CFrame.lookAt(Vector3.new(0, len * 0.25, len * 1.2), Vector3.zero) -- closer (was 1.55): the fish filled too little of the window
		cam.Parent = view
		view.CurrentCamera = cam
		view.Visible = true
		local t0 = os.clock()
		local shimmer = refs.cardShimmer :: UIGradient
		cardSpin = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			fish.CFrame = CFrame.Angles(0, math.sin(t * 0.9) * 0.6, 0) * flat
			if shimmer.Enabled then
				-- The colour sweeps slowly across and back behind the fish.
				shimmer.Offset = Vector2.new(math.sin(t * 1.6) * 0.6, 0)
				shimmer.Rotation = 20
			end
		end)
	end)
end

----------------------------------------------------------------------------------------
-- Panels

-- New look: a tackle box ("box": canvas with a leather band, brass close button and rivets)
-- or a field-guide page ("page": paper, ink title over a double rule). Buttons a thumb tall.
local PANEL_HEAD = Skin.TOUCH + 12
local PANEL_FOOT = Skin.TOUCH + 20
local function styledShell(name: string, title: string, look: string): (Frame, ScrollingFrame)
	local box = look == "box"
	local p = Instance.new("Frame")
	p.Name = name
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Size = UDim2.fromOffset(640, 470)
	p.Position = UDim2.new(0.5, 0, 0.5, 24)
	p.BorderSizePixel = 0
	p.Visible = false
	Skin.surface(p, if box then "canvas" else "paper", "panel", 3)
	p.Parent = gui
	if box then
		local band = Instance.new("Frame")
		band.Name = "Band"
		band.Size = UDim2.new(1, 0, 0, PANEL_HEAD)
		band.BorderSizePixel = 0
		Skin.surface(band, "leather", "panel")
		band.Parent = p
		for i, at in { UDim2.fromOffset(9, 9), UDim2.new(1, -9, 0, 9), UDim2.new(0, 9, 1, -9), UDim2.new(1, -9, 1, -9) } do
			disc(p, "Rivet" .. i, 8, at, K.brass, K.brassDark).ZIndex = 3
		end
	else
		Skin.rule(p, "Rule", UDim2.new(1, -24, 0, 2), UDim2.fromOffset(12, PANEL_HEAD), K.ink)
		Skin.rule(p, "Rule2", UDim2.new(1, -24, 0, 1), UDim2.fromOffset(12, PANEL_HEAD + 5), K.inkFaint)
	end
	local t = styledLabel(p, "Title", title, UDim2.new(1, -160, 0, PANEL_HEAD), UDim2.fromOffset(20, 0), "title", "title", if box then K.paper else K.ink)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.ZIndex = 2
	local close = button(p, "Close", "Close", UDim2.fromOffset(112, Skin.TOUCH), UDim2.new(1, -124, 0, 6), C.red, function()
		UI.closePanels()
	end)
	close.ZIndex = 2
	if box then
		Skin.paint(close, "brass") -- brass on the leather band
	end
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "List"
	scroll.Size = UDim2.new(1, -24, 1, -(PANEL_HEAD + 14 + PANEL_FOOT))
	scroll.Position = UDim2.fromOffset(12, PANEL_HEAD + 12)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 10
	scroll.ScrollBarImageColor3 = K.brassDark
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Selectable = false
	scroll.Parent = p
	return p, scroll
end

-- New look: a shop row as a paper card that grows to fit its words, the button a thumb tall
-- on the right, and what you own under the blurb (N2 review 1: rows as short as the button
-- allows, so about three show on a phone).
local SHOP_ROW_MIN = Skin.TOUCH + 16
local SHOP_FOOT = 32
local function layoutRow(row: Frame, minH: number)
	if not STYLED then
		return
	end
	local T = Skin.TOUCH
	row.Size = UDim2.new(1, -14, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	local c = Instance.new("UISizeConstraint")
	c.MinSize = Vector2.new(0, minH)
	c.Parent = row
	Skin.surface(row, "paper", "card", 1)
	local u = Instance.new("UIPadding")
	u.PaddingBottom = UDim.new(0, 12)
	u.Parent = row
	local name = row:FindFirstChild("Name") :: TextLabel?
	if name then
		name.Position = UDim2.fromOffset(20, 8)
		name.Size = UDim2.new(1, -206, 0, 30)
		Skin.text(name, "title", 20, K.ink)
	end
	-- The blurb and, under it, what you own: one left column that grows with its words.
	local column = Instance.new("Frame")
	column.Name = "Column"
	column.BackgroundTransparency = 1
	column.Position = UDim2.fromOffset(20, 42)
	column.Size = UDim2.new(1, -206, 0, 0)
	column.AutomaticSize = Enum.AutomaticSize.Y
	column.ZIndex = 2
	local lines = Instance.new("UIListLayout")
	lines.SortOrder = Enum.SortOrder.LayoutOrder
	lines.Padding = UDim.new(0, 2)
	lines.Parent = column
	column.Parent = row
	local blurb = row:FindFirstChild("Blurb") :: TextLabel?
	if blurb then
		blurb.Parent = column
		blurb.LayoutOrder = 1
		blurb.Size = UDim2.new(1, 0, 0, 0)
		blurb.AutomaticSize = Enum.AutomaticSize.Y
		blurb.TextYAlignment = Enum.TextYAlignment.Top
		Skin.text(blurb, "body", "small", K.inkSoft)
	end
	local owned = row:FindFirstChild("Owned") :: TextLabel?
	if owned then
		owned.Parent = column
		owned.LayoutOrder = 2
		owned.Size = UDim2.new(1, 0, 0, 0)
		owned.AutomaticSize = Enum.AutomaticSize.Y
		owned.TextXAlignment = Enum.TextXAlignment.Left
		Skin.text(owned, "bodyBold", "small", K.ink)
	end
	local buy = row:FindFirstChild("Buy") :: TextButton?
	if buy then
		buy.Size = UDim2.fromOffset(164, T)
		buy.Position = UDim2.new(1, -176, 0, 8)
	end
	local swatch = row:FindFirstChild("Swatch") :: Frame?
	if swatch then
		-- The item's own colour as a ribbon down the card's left edge.
		swatch.Size = UDim2.fromOffset(7, minH - 16)
		swatch.Position = UDim2.fromOffset(6, 8)
	end
end

local function panelShell(name: string, title: string, look: string?): (Frame, ScrollingFrame)
	if STYLED then
		return styledShell(name, title, look or "page")
	end
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
	local p, scroll = panelShell("Shop", "Bait and Tackle", "box")
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
		layoutRow(row, SHOP_ROW_MIN)
	end
	-- Rods: each comes with its reel. Bought once, switch any time.
	local rodHeader = label(scroll, "RodsHeader", "Rods", UDim2.new(1, -10, 0, 30), UDim2.new(), 20, C.gold, Enum.Font.GothamBlack)
	rodHeader.TextXAlignment = Enum.TextXAlignment.Left
	rodHeader.LayoutOrder = 100
	refs.rodRows = {}
	refs.rodBlurbs = {}
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
		refs.rodBlurbs[r.id] = blurb
		layoutRow(row, SHOP_ROW_MIN)
	end
	-- Braided line: one purchase, 4 lb more on every rod. UNVERIFIED in Studio (2026-11-27).
	do
		local row = frame(scroll, "Braid", UDim2.new(1, -10, 0, 70), UDim2.new(), C.panel2, 0.1)
		row.LayoutOrder = 100 + #RodData.list + 1
		corner(row, 10)
		local swatch = frame(row, "Swatch", UDim2.fromOffset(6, 50), UDim2.fromOffset(6, 10), Color3.fromRGB(90, 140, 90), 0)
		corner(swatch, 3)
		label(row, "Name", "Braided Line", UDim2.fromOffset(220, 28), UDim2.fromOffset(18, 6), 20, C.text, Enum.Font.GothamBold).TextXAlignment = Enum.TextXAlignment.Left
		local blurb = label(row, "Blurb", string.format("Stronger line on every rod you own: %d lb more.", RodData.BRAID_LB), UDim2.fromOffset(330, 34), UDim2.fromOffset(18, 32), 14, C.dim)
		blurb.TextXAlignment = Enum.TextXAlignment.Left
		refs.braidBtn = button(row, "Buy", "", UDim2.fromOffset(150, 50), UDim2.new(1, -162, 0, 10), C.blue, function()
			local st = lastState
			if not st or st.braid then
				return
			end
			if callbacks.buyBraid then
				callbacks.buyBraid()
			end
		end)
		layoutRow(row, SHOP_ROW_MIN)
	end
	-- Boats: bought once; the chosen one waits at your slip by the dock (L7).
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
		local title = b.name
		label(row, "Name", title, UDim2.fromOffset(320, 28), UDim2.fromOffset(18, 6), 20, C.text, Enum.Font.GothamBold).TextXAlignment = Enum.TextXAlignment.Left
		local blurb = label(row, "Blurb", b.blurb, UDim2.fromOffset(330, 48), UDim2.fromOffset(18, 32), 14, C.dim)
		blurb.TextXAlignment = Enum.TextXAlignment.Left
		blurb.TextYAlignment = Enum.TextYAlignment.Top
		local btn = button(row, "Buy", "", UDim2.fromOffset(150, 50), UDim2.new(1, -162, 0, 17), C.blue, function()
			local st = lastState
			if not st then
				return
			end
			if not b.forSale then
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
		layoutRow(row, SHOP_ROW_MIN)
	end
	refs.shopHint = label(p, "Hint", "", UDim2.new(1, -24, 0, 40), UDim2.new(0, 12, 1, -48), 15, C.dim)
	if STYLED then
		-- The shop has no buttons along its foot, only this line: a short foot (N2 review 1).
		scroll.Size = UDim2.new(1, -24, 1, -(PANEL_HEAD + 14 + SHOP_FOOT))
		refs.shopHint.Size = UDim2.new(1, -40, 0, SHOP_FOOT - 4)
		refs.shopHint.Position = UDim2.new(0, 20, 1, -(SHOP_FOOT - 2))
		refs.shopHint.TextXAlignment = Enum.TextXAlignment.Left
		refs.shopHint.TextWrapped = false
		refs.shopHint.TextTruncate = Enum.TextTruncate.AtEnd
		Skin.text(refs.shopHint, "hand", "note", K.ink)
	end
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
			paint(r.buy, if has then C.panel else (if s.coins >= b.price then C.blue else C.panel))
		else
			r.owned.Text = "You have " .. (s.bait[b.id] or 0)
			r.buy.Text = string.format("%d for %d", b.pack, b.price)
			paint(r.buy, if s.coins >= b.price then C.blue else C.panel)
		end
	end
	local braid = s.braid == true
	for _, r in RodData.list do
		local btn = refs.rodRows[r.id]
		local owned = s.rods and s.rods[r.id]
		refs.rodBlurbs[r.id].Text = string.format("%s %s.", r.blurb, RodData.lineText(r.id, braid))
		if s.rod == r.id then
			btn.Text = "In your hands"
			paint(btn, C.panel)
		elseif owned then
			btn.Text = "Use this rod"
			paint(btn, C.green)
		else
			btn.Text = r.price .. " coins"
			paint(btn, if s.coins >= r.price then C.blue else C.panel)
		end
	end
	if refs.braidBtn then
		refs.braidBtn.Text = if braid then "Owned" else (RodData.BRAID_PRICE .. " coins")
		refs.braidBtn.AutoButtonColor = not braid
		paint(refs.braidBtn, if braid then C.panel else (if s.coins >= RodData.BRAID_PRICE then C.blue else C.panel))
	end
	for _, b in BoatData.list do
		local btn = refs.boatRows and refs.boatRows[b.id]
		if btn then
			local owned = s.boats and s.boats[b.id]
			if not b.forSale then
				btn.Text = "Coming soon"
				btn.AutoButtonColor = false
				paint(btn, C.panel)
			elseif s.boat == b.id then
				btn.Text = "At your slip"
				paint(btn, C.panel)
			elseif owned then
				btn.Text = "Use this boat"
				paint(btn, C.green)
			else
				btn.Text = b.price .. " coins"
				paint(btn, if s.coins >= b.price then C.blue else C.panel)
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
		if STYLED then
			-- An entry in the field guide: full width, as tall as its words.
			card.Size = UDim2.new(1, -14, 0, 0)
			card.AutomaticSize = Enum.AutomaticSize.Y
			Skin.surface(card, "paper", "card", 1)
			Skin.padPaper(card)
			local body = Instance.new("Frame")
			body.Name = "Body"
			body.BackgroundTransparency = 1
			body.Size = UDim2.new(1, 0, 0, 0)
			body.AutomaticSize = Enum.AutomaticSize.Y
			body.ZIndex = 2
			body.Parent = card
			local lines = Instance.new("UIListLayout")
			lines.SortOrder = Enum.SortOrder.LayoutOrder
			lines.Padding = UDim.new(0, 4)
			lines.Parent = body
			for order, l in { name, stats, habit } do
				l.Parent = body
				l.LayoutOrder = order
				l.Size = UDim2.new(1, 0, 0, 0)
				l.AutomaticSize = Enum.AutomaticSize.Y
			end
			Skin.text(name, "title", 20, K.ink)
			Skin.text(stats, "bodyBold", 15, K.brassInk)
			Skin.text(habit, "hand", "note", K.inkSoft)
		end
	end
	if STYLED then
		-- One column of entries (the grid's cells could not grow to fit a phone's bigger text).
		grid:Destroy()
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 8)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = scroll
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
	if STYLED then
		-- A handwritten note at the top of the page instead (the title row was too narrow for
		-- it on a phone), and the three switches a thumb tall along the bottom.
		local sum = refs.journalSummary :: TextLabel
		sum.Parent = scroll
		sum.LayoutOrder = 0
		sum.Size = UDim2.new(1, -14, 0, 0)
		sum.AutomaticSize = Enum.AutomaticSize.Y
		sum.TextXAlignment = Enum.TextXAlignment.Left
		Skin.text(sum, "hand", "note", K.ink)
		local x = 12
		for _, b in { refs.assistBtn, refs.quickBtn, refs.tackleBtn } do
			local w = if b == refs.tackleBtn then 160 else 190
			b.Size = UDim2.fromOffset(w, Skin.TOUCH)
			b.Position = UDim2.new(0, x, 1, -(Skin.TOUCH + 10))
			x += w + 10
		end
	end
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
		local entry = if STYLED then (c.name.Parent :: Instance).Parent else c.name.Parent
		;(entry :: any).Visible = listed
		if listed then
			shown += 1
		end
		local count = st.counts[s.id] or 0
		if best then
			kinds += 1
			c.name.Text = s.name .. "  (" .. Rarity.of(s) .. ")"
			c.name.TextColor3 = if STYLED then UIStyle.rarityInk(Rarity.of(s), 0) else Rarity.colorAt(Rarity.of(s), 0)
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
			c.name.TextColor3 = if STYLED then UIStyle.rarityInk(Rarity.of(s), 0) else Rarity.colorAt(Rarity.of(s), 0)
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
		RodData.lineText(rod.id, st.braid == true)
	)
end

-- From a bite until the fight ends nothing else may take the player's clicks.
function UI.setLocked(on: boolean)
	locked = on
	refs.baitBtn.Visible = not on
	refs.journalBtn.Visible = not on
	refs.goalsBtn.Visible = hasGoals and not on -- the playtest critic: it floated alone in fights
	if STYLED then
		refs.tabStrap.Visible = not on
	end
	if on then
		refs.goalsBox.Visible = false
	end
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
	if refs.boardCard then
		BoardCard.hide()
	end
	openPanel = nil
	GuiService.SelectedObject = nil
	sideTabs(true)
end

function UI.openShop()
	if locked then
		return
	end
	UI.closePanels()
	openPanel = "Shop"
	sideTabs(false)
	UI.refreshShop()
	refs.shop.Visible = true
	if UI.inputName() == "R2" then
		GuiService.SelectedObject = refs.shopRows[BaitData.list[1].id].buy
	end
end

-- The chalkboard's card (BoardCard): opens like the shop, never during a fight.
function UI.openBoard()
	if locked or not refs.boardCard then
		return
	end
	UI.closePanels()
	openPanel = "Board"
	sideTabs(false)
	BoardCard.show(UI.inputName() == "R2")
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
	sideTabs(false)
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
	if STYLED then
		refs.pondHint.Size = UDim2.new(1, -40, 0, PANEL_FOOT - 12)
		refs.pondHint.Position = UDim2.new(0, 20, 1, -(PANEL_FOOT - 4))
		refs.pondHint.TextXAlignment = Enum.TextXAlignment.Left
		Skin.text(refs.pondHint, "hand", "note", K.ink)
	end
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
	if STYLED then
		local T = Skin.TOUCH
		row.Size = UDim2.new(1, -14, 0, T + 16)
		Skin.surface(row, "paper", "card", 1)
		name.Position = UDim2.fromOffset(14, 8)
		name.Size = UDim2.fromOffset(230, 30)
		info.Position = UDim2.fromOffset(14, 40)
		info.Size = UDim2.new(1, -(14 + 114 * #buttons), 0, 28)
		for i = 1, #buttons do
			local btn = row:FindFirstChild("Btn" .. i) :: TextButton
			btn.Size = UDim2.fromOffset(104, T)
			btn.Position = UDim2.new(1, -(114 * (#buttons - i + 1)), 0, 8)
			if buttons[i].color == C.panel then
				Skin.paint(btn, "paper") -- "Let go" is an action, not a greyed-out button
			end
		end
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
	sideTabs(false)
	refs.pond.Visible = true
	UI.refreshPond()
	refs.pondList.CanvasPosition = Vector2.zero -- always open at the top
end

----------------------------------------------------------------------------------------
-- Tackle Box (L3): the hook size, best grade per bait, and Perfects toward the gold hook.

function UI.buildTackle()
	local p, scroll = panelShell("Tackle", "Tackle Box", "box")
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	refs.tackleList = scroll
	button(p, "Back", "Back to journal", UDim2.fromOffset(170, 40), UDim2.new(0, 12, 1, -48), C.panel2, function()
		UI.toggleJournal()
	end)
	refs.tackleHint = label(p, "Hint", "Lures carry their own hook. Changing hooks takes the bait off, so you bait up again.", UDim2.new(1, -200, 0, 40), UDim2.new(0, 190, 1, -48), 13, C.dim)
	if STYLED then
		local back = p:FindFirstChild("Back") :: TextButton
		back.Size = UDim2.fromOffset(190, Skin.TOUCH)
		back.Position = UDim2.new(0, 12, 1, -(Skin.TOUCH + 10))
		Skin.paint(back, "leather")
		refs.tackleHint.Size = UDim2.new(1, -226, 0, PANEL_FOOT - 8)
		refs.tackleHint.Position = UDim2.new(0, 214, 1, -(PANEL_FOOT - 2))
		refs.tackleHint.TextXAlignment = Enum.TextXAlignment.Left
		Skin.text(refs.tackleHint, "hand", "note", K.ink)
	end
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
	local hooks = frame(refs.tackleList, "Hooks", UDim2.new(1, -10, 0, if STYLED then Skin.TOUCH else 56), UDim2.new(), C.panel, 1)
	hooks.LayoutOrder = order
	local firstBtn: TextButton? = nil
	for i, size in BaitRig.HOOKS do
		local on = st.hook == size
		local b = button(hooks, "Hook" .. size, BaitRig.HOOK_LINES[size], UDim2.new(1 / 3, -6, 1, 0), UDim2.new((i - 1) / 3, 0, 0, 0), if on then Color3.fromRGB(70, 90, 60) else C.panel2, function()
			if callbacks.setHook and not on then
				callbacks.setHook(size)
			end
		end)
		setSize(b, 15)
		if STYLED then
			Skin.paint(b, if on then "sage" else "paper")
			if on then
				Skin.stroke(b, K.greenInk, 3)
			end
		elseif on then
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
			local row = frame(refs.tackleList, "Row" .. b.id, UDim2.new(1, -10, 0, if STYLED then 40 else 34), UDim2.new(), C.panel2, 0.1)
			row.LayoutOrder = order
			corner(row, 8)
			local name = label(row, "Name", b.name, if STYLED then UDim2.new(0, 200, 1, 0) else UDim2.fromOffset(200, 34), UDim2.fromOffset(12, 0), 17, C.text, Enum.Font.GothamBold)
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
	sideTabs(false)
	refs.tackle.Visible = true
	UI.refreshTackle()
end

function UI.shopHint(text: string)
	if refs.shopHint then
		refs.shopHint.Text = text
	end
end

return UI
