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
local FishLogic = require(Shared.FishLogic)

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
		for _, panel in { refs.shop, refs.journal } do
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
	refs.fight = fight

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
	local card = frame(gui, "CatchCard", UDim2.fromOffset(420, 200), UDim2.new(0.5, -210, 0.42, -100), C.panel, 0.05)
	corner(card, 14)
	pad(card, 14)
	card.Visible = false
	refs.cardTitle = label(card, "Title", "", UDim2.new(1, 0, 0, 34), UDim2.fromOffset(0, 0), 24, C.gold, Enum.Font.GothamBlack)
	refs.cardBody = label(card, "Body", "", UDim2.new(1, 0, 0, 60), UDim2.fromOffset(0, 38), 19, C.text)
	refs.cardNote = label(card, "Note", "", UDim2.new(1, 0, 0, 70), UDim2.fromOffset(0, 100), 16, C.dim)
	refs.card = card

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
	rescale()
end

function UI.setClock(clock: number)
	refs.clock.Text = clockText(clock) .. "  " .. FishLogic.periodFromClock(clock)
end

function UI.setState(state: any)
	lastState = state
	refs.coins.Text = string.format("%d coins", state.coins)
	refs.bag.Text = string.format("Bag: %d fish (%d)", state.bagCount, state.bagValue)
	refs.baitBtn.Text = baitLabel(state)
	if openPanel == "Shop" then
		UI.refreshShop()
	elseif openPanel == "Journal" then
		UI.refreshJournal()
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

function UI.showFight(s: any?, note: string?)
	if not s then
		refs.fight.Visible = false
		refs.baitBtn.Visible = true
		refs.journalBtn.Visible = true
		return
	end
	refs.fight.Visible = true
	refs.baitBtn.Visible = false
	refs.journalBtn.Visible = false
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
	refs.cardTitle.Text = (if payload.first then "New species! " else "") .. f.name
	refs.cardBody.Text = string.format("%.1f cm, %.2f kg. Worth %d coins.%s", f.cm, f.kg, f.price, if payload.best then "\nPersonal best!" else "")
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
	refs.shopHint.Text = string.format("You have %d coins. The right bait beats the expensive bait.", s.coins)
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
	refs.assistBtn = button(p, "Assist", "Reel assist: On", UDim2.fromOffset(220, 40), UDim2.new(0, 12, 1, -48), C.panel2, function()
		if callbacks.toggleAssist then
			callbacks.toggleAssist()
		end
	end)
	refs.journalSummary = label(p, "Summary", "", UDim2.new(1, -260, 0, 40), UDim2.new(0, 244, 1, -48), 15, C.dim)
	refs.journal = p
end

function UI.refreshJournal()
	local st = lastState
	if not st then
		return
	end
	local kinds = 0
	for _, s in FishData.list do
		local c = refs.journalCards[s.id]
		local best = st.bests[s.id]
		local count = st.counts[s.id] or 0
		if best then
			kinds += 1
			c.name.Text = s.name
			c.stats.Text = string.format("Caught %d. Best: %.2f kg, %.1f cm\non %s at %s", count, best.kg, best.cm, (BaitData.byId[best.bait] and BaitData.byId[best.bait].name or best.bait), FishLogic.SPOT_NAMES[best.spot] or best.spot)
			c.habit.Text = s.habit
		else
			c.name.Text = "???"
			c.stats.Text = "Not caught yet."
			c.habit.Text = ""
		end
	end
	refs.assistBtn.Text = "Reel assist: " .. (if st.assist then "On" else "Off")
	refs.journalSummary.Text = string.format("%d of %d species found. %d fish caught in all.", kinds, #FishData.list, st.totalCaught)
end

function UI.isPanelOpen(): boolean
	return openPanel ~= nil
end

function UI.closePanels()
	refs.shop.Visible = false
	refs.journal.Visible = false
	openPanel = nil
	GuiService.SelectedObject = nil
end

function UI.openShop()
	UI.closePanels()
	openPanel = "Shop"
	UI.refreshShop()
	refs.shop.Visible = true
	if UI.inputName() == "R2" then
		GuiService.SelectedObject = refs.shopRows[BaitData.list[1].id].buy
	end
end

function UI.toggleJournal()
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

function UI.shopHint(text: string)
	if refs.shopHint then
		refs.shopHint.Text = text
	end
end

return UI
