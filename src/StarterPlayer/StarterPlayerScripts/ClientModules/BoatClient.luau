--!strict
-- Client side of boats: hides other owners' "Drive" and "Tie up" prompts on this screen
-- (the server refuses them anyway), so a player only ever sees prompts they can use.
-- UNVERIFIED in Studio: written 2026-11-26 in the cloud.
local Players = game:GetService("Players")
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

function BoatClient.start()
	task.spawn(fishFinder)
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
