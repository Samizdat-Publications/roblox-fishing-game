--!strict
-- Big boat buttons on touch screens (leg 3, N4, Config.BOAT_FEEL_ON): Tie up (or Land here, when
-- that is what the boat can do), Leave and Horn, stacked above the touch Fish button while you
-- sit in a boat. Steering is Roblox's own touch thumbstick: in a VehicleSeat it fills the seat's
-- ThrottleFloat and SteerFloat, which BoatClient already sends to the server, so nothing new
-- stands between the thumb and the boat. Tie up and Land here work the boat's own prompts (the
-- server still decides), Leave stands you up as the jump button does, Horn is BoatFeelClient.horn.
-- Written 11/28/2026 in a worktree. UNVERIFIED in Studio.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Skin = require(script.Parent.Skin)
local BoatFeelClient = require(script.Parent.BoatFeelClient)

local BoatTouch = {}

BoatTouch.WIDTH = 150
BoatTouch.GAP = 10
BoatTouch.BOTTOM = 150 -- clear of the touch Fish button (110 tall, 20 up) and the jump button
BoatTouch.EVERY = 0.1

local started = false

local function makeButton(gui: ScreenGui, name: string, text: string, row: number, kind: string, onTap: () -> ()): TextButton
	local h = Skin.TOUCH
	local b = Instance.new("TextButton")
	b.Name = name
	b.AnchorPoint = Vector2.new(1, 1)
	b.Size = UDim2.fromOffset(BoatTouch.WIDTH, h)
	b.Position = UDim2.new(1, -16, 1, -(BoatTouch.BOTTOM + (row - 1) * (h + BoatTouch.GAP)))
	b.BackgroundColor3 = Color3.fromRGB(40, 60, 70)
	b.BackgroundTransparency = 0.1
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextSize = 22
	b.Font = Enum.Font.GothamBold
	b.AutoButtonColor = true
	b.Visible = false
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = b
	if Skin.on then
		Skin.button(b, kind)
	end
	b.Activated:Connect(onTap)
	b.Parent = gui
	return b
end

-- The prompt on your helm the server has switched on, if any: tying up comes first.
local function helmPrompt(): ProximityPrompt?
	local model = BoatFeelClient.myHelmBoat()
	local helm = model and model:FindFirstChild("Helm")
	if not helm then
		return nil
	end
	for _, name in { "TiePrompt", "BeachPrompt" } do
		local p = helm:FindFirstChild(name)
		if p and p:IsA("ProximityPrompt") and p.Enabled then
			return p
		end
	end
	return nil
end

function BoatTouch.start(panelOpen: (() -> boolean)?)
	if started or not UserInputService.TouchEnabled then
		return
	end
	started = true
	local gui = Instance.new("ScreenGui")
	gui.Name = "BoatTouch"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local tie = makeButton(gui, "TieUp", "Tie up", 3, "brass", function()
		local p = helmPrompt()
		if p then
			p:InputHoldBegin()
			p:InputHoldEnd()
		end
	end)
	local leave = makeButton(gui, "Leave", "Leave", 2, "leather", function()
		local char = Players.LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.SeatPart then
			hum.Jump = true -- the same as the jump button: stand up out of the seat
		end
	end)
	local horn = makeButton(gui, "Horn", "Horn", 1, "brass", function()
		BoatFeelClient.horn()
	end)

	local since = 0
	RunService.Heartbeat:Connect(function(dt: number)
		since += dt
		if since < BoatTouch.EVERY then
			return
		end
		since = 0
		local aboard = BoatFeelClient.myBoat() ~= nil and not (panelOpen and panelOpen())
		local atHelm = aboard and BoatFeelClient.myHelmBoat() ~= nil
		local p = if atHelm then helmPrompt() else nil
		leave.Visible = aboard
		horn.Visible = atHelm
		tie.Visible = p ~= nil
		if p then
			tie.Text = if p.Name == "BeachPrompt" then "Land here" else "Tie up"
		end
	end)
end

return BoatTouch
