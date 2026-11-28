--!strict
-- The "Read today's board" card (leg 3, N2, Config.BOARD_CARD_ON with UI_STYLE_ON): a field-
-- guide page with today's forecast, the fish of the day (its rarity as an ink stamp) and the
-- Legendary rumour, plus a handwritten line from the shopkeeper. The server publishes the
-- day as the workspace attribute "BoardDay" (Server/Chalkboard); the words come from
-- Shared/BoardText, the same as the chalk on the board. UI.openBoard opens it (it respects
-- UI.setLocked and closes the other panels like the shop); a brass Close button, Escape,
-- Backspace, gamepad B or a tap outside the page close it.
-- UNVERIFIED in Studio: written 2026-11-27 in a worktree.
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local UIStyle = require(Shared.UIStyle)
local BoardText = require(Shared.BoardText)
local Goals = require(Shared.Goals)
local Skin = require(script.Parent.Skin)

local BoardCard = {}

-- On only with both switches; UI.luau checks this before building or wiring anything.
BoardCard.enabled = Config.BOARD_CARD_ON == true and Config.UI_STYLE_ON == true

local K = UIStyle.COLORS
local WIDTH = 600 -- interface units (432 real pixels at the smallest scale: fits 667 wide)
local MAX_H = 470
local HEAD = Skin.TOUCH + 12 -- a thumb-tall Close button in the header

local root: Frame? = nil
local refs: { [string]: any } = {}
local onClose: () -> () = function() end

local function textLabel(parent: Instance, name: string, order: number, face: string, base: string | number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Text = ""
	Skin.text(l, face, base, color)
	l.Parent = parent
	return l
end

-- An ink stamp: a double ring and the tier's name in its ink, over a light tint of its exact
-- colour, a little crooked (the catch card's stamp, smaller).
local function stamp(parent: Instance): (Frame, TextLabel, UIStroke, UIStroke)
	local s = Instance.new("Frame")
	s.Name = "Stamp"
	s.AnchorPoint = Vector2.new(1, 0.5)
	s.Size = UDim2.fromOffset(150, 40)
	s.Position = UDim2.new(1, -8, 0.5, 0)
	s.Rotation = -6
	s.BorderSizePixel = 0
	Skin.corner(s, "tag")
	local outer = Skin.stroke(s, K.ink, 3)
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.new(1, -8, 1, -8)
	ring.Position = UDim2.fromOffset(4, 4)
	Skin.corner(ring, "tag")
	local inner = Skin.stroke(ring, K.ink, 1)
	ring.Parent = s
	local tier = Instance.new("TextLabel")
	tier.Name = "Tier"
	tier.BackgroundTransparency = 1
	tier.Size = UDim2.fromScale(1, 1)
	tier.Text = ""
	Skin.text(tier, "title", 18, K.ink)
	tier.Parent = s
	s.Parent = parent
	return s, tier, outer, inner
end

function BoardCard.build(gui: ScreenGui, close: () -> ())
	onClose = close
	local holder = Instance.new("Frame")
	holder.Name = "BoardCard"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.ZIndex = 20 -- over the HUD

	-- Tap outside the page to close.
	local back = Instance.new("TextButton")
	back.Name = "Outside"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = K.ink
	back.BackgroundTransparency = 0.55
	back.BorderSizePixel = 0
	back.AutoButtonColor = false
	back.Text = ""
	back.Selectable = false
	back.Activated:Connect(function()
		onClose()
	end)
	back.Parent = holder

	local card = Instance.new("Frame")
	card.Name = "Page"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(WIDTH, MAX_H)
	card.BorderSizePixel = 0
	card.ZIndex = 2
	card.Active = true -- taps on the page don't fall through to "outside"
	Skin.surface(card, "paper", "panel", 3)
	card.Parent = holder

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -164, 0, HEAD)
	title.Position = UDim2.fromOffset(20, 0)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextWrapped = true
	title.Text = BoardText.TITLE
	Skin.text(title, "title", "title", K.ink)
	title.Parent = card
	Skin.rule(card, "Rule", UDim2.new(1, -24, 0, 2), UDim2.fromOffset(12, HEAD), K.ink)
	Skin.rule(card, "Rule2", UDim2.new(1, -24, 0, 1), UDim2.fromOffset(12, HEAD + 5), K.inkFaint)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "Close"
	closeBtn.Size = UDim2.fromOffset(120, Skin.TOUCH)
	closeBtn.Position = UDim2.new(1, -132, 0, 6)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "Close"
	closeBtn.Selectable = true
	Skin.button(closeBtn, "brass")
	closeBtn.Activated:Connect(function()
		onClose()
	end)
	closeBtn.Parent = card
	refs.close = closeBtn

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(20, HEAD + 12)
	body.Size = UDim2.new(1, -32, 1, -(HEAD + 24))
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 10
	body.ScrollBarImageColor3 = K.brassDark
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Selectable = false
	body.Parent = card
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = body
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 14) -- clear of the scroll bar
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = body
	refs.body = body

	refs.weekday = textLabel(body, "Weekday", 1, "bodyBold", "small", K.inkSoft)
	textLabel(body, "ForecastHead", 2, "title", "heading", K.ink).Text = "The forecast"
	refs.forecast = textLabel(body, "Forecast", 3, "body", "body", K.ink)
	textLabel(body, "FishHead", 4, "title", "heading", K.ink).Text = "Fish of the day"
	local row = Instance.new("Frame")
	row.Name = "FishRow"
	row.LayoutOrder = 5
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 52)
	row.Parent = body
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, -176, 1, 0)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextWrapped = true
	name.Text = ""
	Skin.text(name, "title", 22, K.ink)
	name.Parent = row
	refs.fishName = name
	refs.stamp, refs.tier, refs.stampOuter, refs.stampInner = stamp(row)
	refs.fishNote = textLabel(body, "FishNote", 6, "body", "body", K.ink)
	textLabel(body, "RumourHead", 7, "title", "heading", K.ink).Text = "Heard at the shop"
	refs.rumour = textLabel(body, "Rumour", 8, "body", "body", K.ink)
	refs.note = textLabel(body, "Note", 9, "hand", "note", K.ink)
	refs.note.TextXAlignment = Enum.TextXAlignment.Right

	holder.Parent = gui
	root = holder
	refs.page = card

	-- Escape, Backspace and gamepad B close it (the Controller's panel binding also closes it
	-- through UI.closePanels; closing twice is harmless).
	UserInputService.InputBegan:Connect(function(input)
		if not BoardCard.isOpen() then
			return
		end
		local k = input.KeyCode
		if k == Enum.KeyCode.Escape or k == Enum.KeyCode.Backspace or k == Enum.KeyCode.ButtonB then
			onClose()
		end
	end)
	workspace:GetAttributeChangedSignal("BoardDay"):Connect(function()
		if BoardCard.isOpen() then
			BoardCard.fill()
		end
	end)
end

local function today(): number
	local d = workspace:GetAttribute("BoardDay")
	if type(d) == "number" then
		return d
	end
	return Goals.dayOf(os.time()) -- the server hasn't said yet: the same UTC day it would use
end

function BoardCard.fill()
	if not root then
		return
	end
	local c = BoardText.card(today(), Config.BIG_LAKE_ON)
	refs.weekday.Text = c.weekday
	refs.forecast.Text = c.forecast
	refs.fishName.Text = c.fishName
	local tierInk = UIStyle.rarityInk(c.fishTier, os.clock())
	refs.tier.Text = string.upper(c.fishTierName)
	refs.tier.TextColor3 = tierInk
	refs.stampOuter.Color = tierInk
	refs.stampInner.Color = tierInk
	refs.stamp.BackgroundColor3 = UIStyle.mix(UIStyle.RARITY[c.fishTier] or UIStyle.RARITY.Common, K.paper, UIStyle.STAMP_TINT)
	refs.fishNote.Text = c.fishNote
	refs.rumour.Text = c.rumour
	refs.note.Text = c.note
end

-- Height of the screen in interface units: the page never runs off a short phone screen.
function BoardCard.fit(h: number)
	if refs.page then
		refs.page.Size = UDim2.fromOffset(WIDTH, math.max(240, math.min(MAX_H, h - 40)))
	end
end

function BoardCard.show(gamepad: boolean?)
	if not root then
		return
	end
	BoardCard.fill()
	refs.body.CanvasPosition = Vector2.zero
	root.Visible = true
	if gamepad then
		GuiService.SelectedObject = refs.close
	end
end

function BoardCard.hide()
	if root then
		root.Visible = false
	end
end

function BoardCard.isOpen(): boolean
	return root ~= nil and root.Visible
end

return BoardCard
