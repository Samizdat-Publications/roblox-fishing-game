--!strict
-- Client side of boats: hides other owners' "Drive" and "Tie up" prompts on this screen
-- (the server refuses them anyway), so a player only ever sees prompts they can use; sends
-- the helm's controls; keeps the camera on the player while seated; the fish finder panel.
-- Written 2026-11-26 in the cloud; the helm and the camera proven in Studio 11/27/2026 (L7).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarity = require(Shared.Rarity)
local Remotes = require(Shared.Remotes)

local BoatClient = {}

local OWNER_ONLY = { DrivePrompt = true, TiePrompt = true }

local function watch(prompt: ProximityPrompt)
	if not OWNER_ONLY[prompt.Name] then
		return
	end
	local model = prompt:FindFirstAncestorOfClass("Model")
	local owner = model and model:GetAttribute("OwnerId")
	if owner == nil or owner == Players.LocalPlayer.UserId then
		return
	end
	prompt.Enabled = false
	-- The server turns prompts on and off as seats fill and empty; keep this one off here.
	prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if prompt.Enabled then
			prompt.Enabled = false
		end
	end)
end

-- The fish finder panel: shown only while you sit in a boat's navigator seat.
local function fishFinder()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FishFinder"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(220, 130)
	panel.Position = UDim2.new(1, -232, 0, 70)
	panel.BackgroundColor3 = Color3.fromRGB(10, 30, 30)
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 26)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextColor3 = Color3.fromRGB(40, 220, 170)
	title.Text = "Fish finder"
	title.Parent = panel
	local marks: { Frame } = {}
	for i = 1, 4 do
		local m = Instance.new("Frame")
		m.AnchorPoint = Vector2.new(0.5, 0.5)
		m.Position = UDim2.new(0, 30 + (i - 1) * 52, 0, 80)
		m.Visible = false
		m.Parent = panel
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = m
		marks[i] = m
	end
	local SIZE = { small = 14, medium = 22, large = 32 }
	task.spawn(function()
		while true do
			task.wait(2)
			local hum = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			local seat = hum and hum.SeatPart
			local on = seat ~= nil and seat.Name == "Navigator"
			panel.Visible = on
			if on then
				local ok, result = pcall(function()
					return Remotes.func("FishFinder"):InvokeServer()
				end)
				local list = if ok and type(result) == "table" then result else {}
				for i, m in marks do
					local mark = list[i]
					m.Visible = mark ~= nil
					if mark then
						local px = SIZE[mark.size] or 18
						m.Size = UDim2.fromOffset(px, px)
						m.BackgroundColor3 = Rarity.colorAt(mark.tier, os.clock())
					end
				end
				title.Text = if #list == 0 then "Fish finder: nothing below" else "Fish finder"
			end
		end
	end)
end

-- At the helm, send the seat's controls to the server about ten times a second (the server
-- drives the boat and owns its physics, so the seat's own values don't reach it). Roblox's
-- vehicle controls fill ThrottleFloat and SteerFloat from keyboard, thumbstick and gamepad.
local SEND_EVERY = 0.1
local function sendInput()
	local input = Remotes.event("BoatInput")
	local timer, wasAtHelm = 0, false
	RunService.Heartbeat:Connect(function(dt)
		timer += dt
		if timer < SEND_EVERY then
			return
		end
		timer = 0
		local char = Players.LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local seat = hum and hum.SeatPart
		local atHelm = seat ~= nil and seat:IsA("VehicleSeat") and seat.Name == "Helm"
		if atHelm then
			local s = seat :: VehicleSeat
			local throttle, steer = s.ThrottleFloat, s.SteerFloat
			if throttle == 0 and steer == 0 then
				throttle, steer = s.Throttle, s.Steer
			end
			input:FireServer(throttle, steer)
		elseif wasAtHelm then
			input:FireServer(0, 0) -- let go when leaving the helm
		end
		wasAtHelm = atHelm
	end)
end

-- Roblox points the camera at a VehicleSeat when you sit in one. On a boat keep it on the
-- player instead, so fishing from the seat looks and works like fishing from the dock (the
-- bobber camera and the catch moment only follow the player's Humanoid).
local function cameraOnPlayer()
	local cam = workspace.CurrentCamera
	local function check()
		local subject = cam.CameraSubject
		local char = Players.LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and subject and subject:IsA("VehicleSeat") and hum.SeatPart == subject then
			local model = subject:FindFirstAncestorOfClass("Model")
			if model and model:GetAttribute("BoatId") then
				cam.CameraSubject = hum
			end
		end
	end
	cam:GetPropertyChangedSignal("CameraSubject"):Connect(function()
		task.defer(check)
	end)
	check()
end

function BoatClient.start()
	task.spawn(fishFinder)
	cameraOnPlayer()
	task.spawn(sendInput)
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			task.defer(watch, d)
		end
	end)
	for _, d in workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			watch(d)
		end
	end
end

return BoatClient
