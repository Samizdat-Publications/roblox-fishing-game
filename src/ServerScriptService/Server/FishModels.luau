--!strict
-- Copies of every species' model where players' screens can reach them (11/27/2026): the
-- art lives in ServerStorage, which clients can't see, and the trophy wall (ClientModules/
-- TrophyWall) mounts each player's own best fish on their screen only. One plain MeshPart per
-- species in ReplicatedStorage.FishModels, named by species id, no children.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local FishData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishData"))

local FishModels = {}

function FishModels.start(): number
	local art = ServerStorage:FindFirstChild("Art")
	local folder = ReplicatedStorage:FindFirstChild("FishModels")
	if folder then
		folder:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "FishModels"
	local n = 0
	for _, s in FishData.list do
		local source = art and art:FindFirstChild(s.id)
		local mesh = source and source:FindFirstChildWhichIsA("MeshPart", true)
		if mesh then
			local copy = mesh:Clone()
			copy:ClearAllChildren()
			copy.Name = s.id
			copy.Anchored = true
			copy.CanCollide = false
			copy.CanQuery = false
			copy.CanTouch = false
			copy.Parent = f
			n += 1
		end
	end
	f.Parent = ReplicatedStorage
	return n
end

return FishModels
