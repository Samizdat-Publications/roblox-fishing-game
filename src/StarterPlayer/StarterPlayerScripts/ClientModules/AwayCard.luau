--!strict
-- The "While You Were Away" pond card (L6d): once per join, if the pond grew or bred while
-- the player was offline, a small card slides in on the left for a few seconds with what
-- changed and a "go see" hint. Nothing shows when nothing changed. The server decides what
-- happened (PondService, Shared/Daily.awayReport); this only shows it. Tap to close early.
-- UNVERIFIED in Studio: written 2026-11-27.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local AwayCard = {}

local SHOW_SECONDS = 9
local WIDTH = 360
local COLORS = {
	panel = Color3.fromRGB(24, 32, 40),
	text = Color3.fromRGB(240, 244, 248),
	dim = Color3.fromRGB(170, 185, 200),
	pond = Color3.fromRGB(120, 210, 200), -- the pond sign's colour
}

local function label(parent: Instance, name: string, text: string, order: number, size: number, color: Color3, font: Enum.Font): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.LayoutOrder = order
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color
	l.TextSize = size
	l.Font = font
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function show(report: any)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "AwayCard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")
	local scale = Instance.new("UIScale")
	local cam = workspace.CurrentCamera
	if cam then
		local v = cam.ViewportSize
		scale.Scale = math.clamp(math.min(v.X / 1280, v.Y / 720) * 1.15, 0.72, 1.25) -- same as the main UI
	end
	scale.Parent = gui

	local card = Instance.new("TextButton") -- a button so a tap closes it
	card.Name = "Card"
	card.AutoButtonColor = false
	card.Text = ""
	card.Size = UDim2.fromOffset(WIDTH, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.AnchorPoint = Vector2.new(0, 0.5)
	card.Position = UDim2.new(0, -WIDTH - 40, 0.42, 0)
	card.BackgroundColor3 = COLORS.panel
	card.BackgroundTransparency = 0.05
	card.BorderSizePixel = 0
	card.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.pond
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card
	local pad = Instance.new("UIPadding")
	for _, side in { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } do
		(pad :: any)[side] = UDim.new(0, 14)
	end
	pad.Parent = card
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = card

	label(card, "Title", tostring(report.title or "While You Were Away"), 1, 24, COLORS.pond, Enum.Font.GothamBlack)
	local order = 2
	for _, line in (if type(report.lines) == "table" then report.lines else {}) :: { any } do
		label(card, "Line", tostring(line), order, 18, COLORS.text, Enum.Font.GothamMedium)
		order += 1
	end
	label(card, "Hint", tostring(report.hint or ""), order, 16, COLORS.dim, Enum.Font.GothamMedium)

	local info = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(card, info, { Position = UDim2.new(0, 20, 0.42, 0) }):Play()
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		local out = TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0, -WIDTH - 40, 0.42, 0) })
		out.Completed:Connect(function()
			gui:Destroy()
		end)
		out:Play()
	end
	card.Activated:Connect(close)
	task.delay(SHOW_SECONDS, close)
end

function AwayCard.start()
	task.spawn(function()
		task.wait(2) -- let the world and the main screen settle first
		local ok, report = pcall(function()
			return Remotes.func("AwayReport"):InvokeServer()
		end)
		if ok and type(report) == "table" then
			show(report)
		end
	end)
end

return AwayCard
