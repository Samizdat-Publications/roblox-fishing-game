--!strict
-- Button prompts in the field guide look (leg 3, N2): a brass key cap with the key on it and
-- an ink label on a paper slip, through ProximityPromptStyle.Custom. This client switches every
-- prompt it sees to Custom (only on its own screen) and draws them itself. Holds fill the key
-- cap from the bottom (HoldDuration); a tap on the slip or the cap works the prompt on touch.
-- Keyboard and gamepad keys work as before (the engine still runs the prompt).
-- Only started when Config.UI_STYLE_ON is true. UNVERIFIED in Studio: written 2026-11-27.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIStyle"))
local Skin = require(script.Parent.Skin)

local PromptStyle = {}

local C = UIStyle.COLORS
local CAP = 48 -- the key cap, in real pixels (a billboard has no UIScale): over 44 for a thumb
local GAP = 6
local ACTION_PX = 20
local OBJECT_PX = 16

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "Tap"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		local name = prompt.GamepadKeyCode.Name:gsub("^Button", "")
		return name
	end
	local s = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
	if s == nil or s == "" then
		s = prompt.KeyboardKeyCode.Name
	end
	return s
end

local function textWidth(text: string, px: number, role: string): number
	if text == "" then
		return 0
	end
	local ok, size = pcall(function()
		local params = Instance.new("GetTextBoundsParams")
		params.Text = text
		params.Font = UIStyle.font(role)
		params.Size = px
		params.Width = 1000
		return TextService:GetTextBoundsAsync(params)
	end)
	if ok and size then
		return math.ceil((size :: Vector2).X)
	end
	return #text * px * 0.55
end

local function adorneeOf(prompt: ProximityPrompt): Instance?
	local p = prompt.Parent
	if p and (p:IsA("BasePart") or p:IsA("Attachment")) then
		return p
	elseif p and p:IsA("Model") then
		return p.PrimaryPart
	end
	return nil
end

local function build(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): (BillboardGui, () -> ())
	local conns: { RBXScriptConnection } = {}
	local key = keyText(prompt, inputType)
	local action = prompt.ActionText
	local object = prompt.ObjectText
	local slipW = math.max(textWidth(action, ACTION_PX, "bodyBold"), textWidth(object, OBJECT_PX, "body")) + 20
	local hasSlip = action ~= "" or object ~= ""
	local width = CAP + (if hasSlip then GAP + slipW else 0)

	local g = Instance.new("BillboardGui")
	g.Name = "Prompt"
	g.AlwaysOnTop = true -- button prompts are the one thing allowed to float (the audit's rule)
	g.Active = true
	g.ResetOnSpawn = false
	g.LightInfluence = 0
	g.Size = UDim2.fromOffset(width, CAP)
	g.SizeOffset = Vector2.new(0, 0.5)
	g.Adornee = adorneeOf(prompt)
	g.MaxDistance = prompt.MaxActivationDistance + 10

	-- The key cap: brass with a darker rim, the key in ink.
	local cap = Instance.new("TextButton")
	cap.Name = "KeyCap"
	cap.AutoButtonColor = false
	cap.Size = UDim2.fromOffset(CAP, CAP)
	cap.BorderSizePixel = 0
	cap.Text = ""
	cap.Selectable = false
	Skin.surface(cap, "brassButton", "button", 2)
	cap.ClipsDescendants = true
	cap.Parent = g
	-- The key's name sits above the hold fill (a child draws over its parent's own text).
	local keyLabel = Instance.new("TextLabel")
	keyLabel.Name = "Key"
	keyLabel.BackgroundTransparency = 1
	keyLabel.Size = UDim2.fromScale(1, 1)
	keyLabel.Text = key
	keyLabel.TextColor3 = C.ink
	keyLabel.FontFace = UIStyle.font("bodyBold")
	keyLabel.TextSize = if #key > 2 then 16 else 22
	keyLabel.ZIndex = 3
	keyLabel.Parent = cap
	-- The hold fills the cap from the bottom.
	local fill = Instance.new("Frame")
	fill.Name = "Hold"
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	fill.Size = UDim2.fromScale(1, 0)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = C.brassLight
	fill.BackgroundTransparency = 0.2
	fill.ZIndex = 1
	fill.Parent = cap

	-- The slip: object text small and soft over the action in bold ink.
	local slip: TextButton? = nil
	if hasSlip then
		local s = Instance.new("TextButton")
		s.Name = "Slip"
		s.AutoButtonColor = false
		s.Text = ""
		s.Selectable = false
		s.Size = UDim2.fromOffset(slipW, CAP)
		s.Position = UDim2.fromOffset(CAP + GAP, 0)
		s.BorderSizePixel = 0
		Skin.surface(s, "paper", "tag", 1)
		local function line(name: string, text: string, px: number, role: string, color: Color3, y: number, h: number)
			local l = Instance.new("TextLabel")
			l.Name = name
			l.BackgroundTransparency = 1
			l.Size = UDim2.new(1, -16, 0, h)
			l.Position = UDim2.fromOffset(8, y)
			l.Text = text
			l.TextColor3 = color
			l.TextSize = px
			l.FontFace = UIStyle.font(role)
			l.TextXAlignment = Enum.TextXAlignment.Left
			l.ZIndex = 2
			l.Parent = s
		end
		if object ~= "" and action ~= "" then
			line("Object", object, OBJECT_PX, "body", C.inkSoft, 3, 18)
			line("Action", action, ACTION_PX, "bodyBold", C.ink, 21, 24)
		else
			line("Action", if action ~= "" then action else object, ACTION_PX, "bodyBold", C.ink, 0, CAP)
		end
		s.Parent = g
		slip = s
	end

	-- Hold progress (any device: the engine fires these for keys and for our touch holds).
	local holdTween: Tween? = nil
	table.insert(conns, prompt.PromptButtonHoldBegan:Connect(function()
		if prompt.HoldDuration > 0 then
			fill.Size = UDim2.fromScale(1, 0)
			holdTween = TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
			;(holdTween :: Tween):Play()
		end
		cap.BackgroundColor3 = C.brassLight
	end))
	table.insert(conns, prompt.PromptButtonHoldEnded:Connect(function()
		if holdTween then
			holdTween:Cancel()
			holdTween = nil
		end
		fill.Size = UDim2.fromScale(1, 0)
		cap.BackgroundColor3 = C.brass
	end))

	-- Touch (and mouse): pressing the cap or the slip holds the prompt.
	local function wire(b: TextButton)
		table.insert(conns, b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldBegin()
				local c: RBXScriptConnection
				c = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
					if input.UserInputState == Enum.UserInputState.End or input.UserInputState == Enum.UserInputState.Cancel then
						c:Disconnect()
						prompt:InputHoldEnd()
					end
				end)
				table.insert(conns, c)
			end
		end))
	end
	wire(cap)
	if slip then
		wire(slip)
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	g.Parent = playerGui
	return g, function()
		for _, c in conns do
			c:Disconnect()
		end
		g:Destroy()
	end
end

local started = false
function PromptStyle.start()
	if started then
		return
	end
	started = true
	local function adopt(d: Instance)
		if d:IsA("ProximityPrompt") then
			d.Style = Enum.ProximityPromptStyle.Custom
		end
	end
	for _, d in workspace:GetDescendants() do
		adopt(d)
	end
	workspace.DescendantAdded:Connect(adopt)

	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		local _, cleanup = build(prompt, inputType)
		local hidden: RBXScriptConnection
		hidden = prompt.PromptHidden:Connect(function()
			hidden:Disconnect()
			cleanup()
		end)
	end)
end

return PromptStyle
