--!strict
-- The Today on the Lake chalkboard beside the bait shop (L6d), and the shopkeeper's tackle
-- box on a crate next to it. Built from parts at start if the place doesn't have it yet;
-- the text is rewritten whenever the real date turns (Server/Today, with the Studio-only
-- DebugDayOffset). The board shows the date's forecast (Weather.planForDate, the same plan
-- WeatherService runs), the fish of the day and a rumour about a Legendary (Shared/Daily).
-- The gift itself is handed over by EconomyService (TacklePrompt).
-- UNVERIFIED in Studio: written 2026-11-27.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Daily = require(Shared.Daily)
local Weather = require(Shared.Weather)
local BoardText = require(Shared.BoardText)
local Today = require(script.Parent.Today)

local Chalkboard = {}

-- East of the bait shop stand (x 13 to 23, z 94 to 98) and its lamp (x 24, z 93), clear of
-- the path (z 82 to 88) and the home pond (x 39 to 61). The writing faces the path, toward
-- the dock (-z). The crate stands right of the board, out of reach of the shop's prompt.
local BOARD_POS = Vector3.new(30, 1, 94) -- on the ground (y 1 is the grass top)
local BOARD_W, BOARD_H = 7.2, 5 -- the writing surface, studs
local BOARD_MID = 4.7 -- height of the board's centre above the ground
local PIXELS = 80 -- SurfaceGui pixels per stud: 576 x 400
local CRATE_POS = Vector3.new(35.2, 1, 93.8)

local WOOD = Color3.fromRGB(120, 84, 52)
local DARK_WOOD = Color3.fromRGB(78, 54, 34)
local SLATE = Color3.fromRGB(36, 66, 50)
local CHALK = Color3.fromRGB(238, 238, 228)
local CHALK_YELLOW = Color3.fromRGB(246, 226, 140)
local HEAD_FONT = Enum.Font.PermanentMarker
local BODY_FONT = Enum.Font.PatrickHand

-- The readable board (leg 3, N2): a short slate in big chalk, and the prompt that opens the
-- field-guide card. Only with both switches on; otherwise the board is exactly as before.
local READABLE = Config.BOARD_CARD_ON == true and Config.UI_STYLE_ON == true

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Wood
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function text(parent: Instance, name: string, order: number, height: number, font: Enum.Font, color: Color3, maxSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.LayoutOrder = order
	l.Size = UDim2.new(1, 0, 0, height)
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextColor3 = color
	l.TextTransparency = 0.04 -- chalk, not paint
	l.TextScaled = true
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Text = ""
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maxSize
	limit.MinTextSize = 12
	limit.Parent = l
	l.Parent = parent
	return l
end

local function build(lake: Instance): Model
	local m = Instance.new("Model")
	m.Name = "Chalkboard"
	local base = BOARD_POS
	local mid = base + Vector3.new(0, BOARD_MID, 0)
	-- Two legs, a frame, the slate in front of it and a chalk tray under it.
	for i, x in { -(BOARD_W / 2 + 0.35), BOARD_W / 2 + 0.35 } do
		part(m, "Leg" .. i, Vector3.new(0.4, BOARD_MID + BOARD_H / 2 + 0.4, 0.4), CFrame.new(base + Vector3.new(x, (BOARD_MID + BOARD_H / 2 + 0.4) / 2, 0.15)), DARK_WOOD)
	end
	part(m, "Frame", Vector3.new(BOARD_W + 0.5, BOARD_H + 0.5, 0.3), CFrame.new(mid), WOOD)
	local slate = part(m, "Slate", Vector3.new(BOARD_W, BOARD_H, 0.1), CFrame.new(mid + Vector3.new(0, 0, -0.2)), SLATE, Enum.Material.Slate)
	part(m, "Tray", Vector3.new(BOARD_W, 0.12, 0.45), CFrame.new(mid + Vector3.new(0, -BOARD_H / 2 - 0.1, -0.3)), WOOD)
	part(m, "Chalk", Vector3.new(0.5, 0.1, 0.1), CFrame.new(mid + Vector3.new(2.2, -BOARD_H / 2 - 0.0, -0.35)), CHALK, Enum.Material.SmoothPlastic)

	-- The writing: on the slate's front face (-z, toward the path and the dock).
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Writing"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS
	gui.LightInfluence = 0.6 -- dims a little at night, still readable under the lamp
	gui.MaxDistance = 90
	gui.Parent = slate
	local holder = Instance.new("Frame")
	holder.Name = "Lines"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 18)
	pad.PaddingRight = UDim.new(0, 18)
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = holder
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 2)
	list.Parent = holder
	local title = text(holder, "Title", 1, 48, HEAD_FONT, CHALK, 42)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Text = "Today on the Lake"
	local day = text(holder, "Day", 2, 24, BODY_FONT, CHALK, 22)
	day.TextXAlignment = Enum.TextXAlignment.Center
	text(holder, "WeatherHead", 3, 28, HEAD_FONT, CHALK_YELLOW, 24).Text = "Weather"
	text(holder, "Weather", 4, 40, BODY_FONT, CHALK, 26)
	text(holder, "FishHead", 5, 28, HEAD_FONT, CHALK_YELLOW, 24).Text = "Fish of the Day"
	text(holder, "Fish", 6, 82, BODY_FONT, CHALK, 26)
	text(holder, "RumourHead", 7, 28, HEAD_FONT, CHALK_YELLOW, 24).Text = "Heard at the Shop"
	text(holder, "Rumour", 8, 62, BODY_FONT, CHALK, 26)

	-- The shopkeeper's tackle box on a crate, with its own small prompt.
	local crate = part(m, "Crate", Vector3.new(1.6, 1.3, 1.3), CFrame.new(CRATE_POS + Vector3.new(0, 0.65, 0)), WOOD, Enum.Material.WoodPlanks)
	local box = part(m, "TackleBox", Vector3.new(1.3, 0.55, 0.8), crate.CFrame * CFrame.new(0, 0.65 + 0.275, 0), Color3.fromRGB(176, 52, 44), Enum.Material.SmoothPlastic)
	part(m, "Handle", Vector3.new(0.6, 0.12, 0.12), box.CFrame * CFrame.new(0, 0.34, 0), Color3.fromRGB(40, 40, 40), Enum.Material.Metal)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TacklePrompt"
	prompt.ActionText = "Open tackle box"
	prompt.ObjectText = "A gift from the shopkeeper"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = box

	m.PrimaryPart = slate
	m.Parent = lake
	return m
end

local function lines(m: Model): { [string]: TextLabel }?
	local slate = m:FindFirstChild("Slate")
	local gui = slate and slate:FindFirstChild("Writing")
	local holder = gui and gui:FindFirstChild("Lines")
	if not holder then
		return nil
	end
	local out: { [string]: TextLabel } = {}
	for _, n in { "Day", "Weather", "Fish", "Rumour" } do
		local l = holder:FindFirstChild(n)
		if not (l and l:IsA("TextLabel")) then
			return nil
		end
		out[n] = l
	end
	return out
end

-- The short slate: a sibling of the old Lines in the same SurfaceGui (576 x 400 px, 80 px a
-- stud, so the big lines are about 0.65 studs tall: readable from the path 10 to 15 studs off).
local function slateLabel(parent: Instance, name: string, order: number, height: number, color: Color3, maxSize: number, minSize: number): TextLabel
	local l = text(parent, name, order, height, BODY_FONT, color, maxSize)
	l.TextTransparency = 0 -- full-strength chalk
	l.TextYAlignment = Enum.TextYAlignment.Center
	local limit = l:FindFirstChildOfClass("UITextSizeConstraint")
	if limit then
		limit.MinTextSize = minSize
	end
	return l
end

local function summary(m: Model): { [string]: TextLabel }?
	local slate = m:FindFirstChild("Slate")
	local gui = slate and slate:FindFirstChild("Writing")
	if not (gui and gui:IsA("SurfaceGui")) then
		return nil
	end
	local old = gui:FindFirstChild("Lines")
	if old and old:IsA("GuiObject") then
		old.Visible = false
	end
	gui.LightInfluence = 0.35 -- stays bright enough to read at dusk
	local holder = gui:FindFirstChild("Summary")
	if not holder then
		local f = Instance.new("Frame")
		f.Name = "Summary"
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundTransparency = 1
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 20)
		pad.PaddingRight = UDim.new(0, 20)
		pad.PaddingTop = UDim.new(0, 8)
		pad.PaddingBottom = UDim.new(0, 8)
		pad.Parent = f
		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 0)
		list.Parent = f
		local title = slateLabel(f, "Title", 1, 66, CHALK, 60, 40)
		title.TextXAlignment = Enum.TextXAlignment.Center
		title.Text = BoardText.TITLE
		slateLabel(f, "WeatherHead", 2, 32, CHALK_YELLOW, 30, 24).Text = "Weather"
		slateLabel(f, "Weather", 3, 62, CHALK, 56, 36)
		slateLabel(f, "FishHead", 4, 32, CHALK_YELLOW, 30, 24).Text = "Fish of the Day"
		slateLabel(f, "Fish", 5, 62, CHALK, 56, 36)
		slateLabel(f, "Teaser", 6, 90, CHALK_YELLOW, 42, 30)
		f.Parent = gui
		holder = f
	end
	local out: { [string]: TextLabel } = {}
	for _, n in { "Weather", "Fish", "Teaser" } do
		local l = (holder :: Instance):FindFirstChild(n)
		if not (l and l:IsA("TextLabel")) then
			return nil
		end
		out[n] = l
	end
	return out
end

-- "Read today's board": opens the card on the player's own screen (ClientModules/BoardCard).
local function addPrompt(m: Model)
	local slate = m:FindFirstChild("Slate")
	if not slate or slate:FindFirstChild("BoardPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BoardPrompt"
	prompt.ActionText = "Read today's board"
	prompt.ObjectText = BoardText.TITLE
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = slate
end

local function write(m: Model, day: number)
	local l = lines(m)
	if not l then
		warn("[Chalkboard] writing missing; rebuild the board")
		return
	end
	local forecast = Weather.forecast(Weather.planForDate(day), -1) -- no moon: moons run per server
	local b = Daily.board(day, forecast, Config.BIG_LAKE_ON)
	l.Day.Text = b.weekday
	l.Weather.Text = b.weather
	l.Fish.Text = b.fish .. ". " .. b.fishNote
	l.Rumour.Text = b.rumour
	workspace:SetAttribute("FishOfDay", Daily.fishOfDay(day)) -- for anything client-side that wants it
	if READABLE then
		local s = BoardText.slate(day, Config.BIG_LAKE_ON)
		local sl = summary(m)
		if sl then
			sl.Weather.Text = s.weather
			sl.Fish.Text = s.fish
			sl.Teaser.Text = s.teaser
		end
		workspace:SetAttribute("BoardDay", day) -- the card builds itself from this (Shared/BoardText)
	end
	print(string.format("[Chalkboard] day %d: %s | %s | %s", day, b.weather, b.fish, b.rumour))
end

function Chalkboard.start()
	local lake = workspace:WaitForChild("Lake")
	local m = lake:FindFirstChild("Chalkboard") :: Model?
	if not m then
		m = build(lake)
	end
	local board = m :: Model
	if READABLE then
		addPrompt(board)
	end
	local day = Today.day()
	write(board, day)
	task.spawn(function()
		while true do
			task.wait(if RunService:IsStudio() then 3 else 30)
			local now = Today.day()
			if now ~= day then
				day = now
				write(board, day)
			end
		end
	end)
end

return Chalkboard
