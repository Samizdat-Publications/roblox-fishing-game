--!strict
-- Client side of boats: hides other owners' "Drive" and "Tie up" prompts on this screen
-- (the server refuses them anyway), so a player only ever sees prompts they can use.
-- UNVERIFIED in Studio: written 2026-11-26 in the cloud.
local Players = game:GetService("Players")

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

function BoatClient.start()
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
