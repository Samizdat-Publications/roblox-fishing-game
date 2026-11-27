--!strict
-- Gives every character a fishing rod with a "RodTip" attachment for the line: an invisible
-- logical rod (the old gray box) with the real rod model welded along it (11/27/2026).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RodData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").RodData)
local PlayerData = require(script.Parent.PlayerData)

local RodService = {}

local function giveRod(character: Model)
	local hand = character:WaitForChild("RightHand", 5) or character:FindFirstChild("Right Arm")
	local owner = Players:GetPlayerFromCharacter(character)
	local data = owner and PlayerData.get(owner)
	local spec = RodData.byId[data and data.rod or "Willow"] or RodData.byId.Willow
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local old = character:FindFirstChild("Rod")
	if old then
		old:Destroy()
	end
	local rod = Instance.new("Part")
	rod.Name = "Rod"
	rod.Size = Vector3.new(0.18, 0.18, spec.length)
	rod.Color = spec.color
	rod.Material = Enum.Material.SmoothPlastic
	rod.CanCollide = false
	rod.CanQuery = false
	rod.CanTouch = false
	rod.Massless = true
	-- Aim from the character's facing, not the hand's current pose: forward and about 35 degrees up.
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local facing = if root then root.CFrame.Rotation else hand.CFrame.Rotation
	rod.CFrame = CFrame.new(hand.Position) * facing * CFrame.Angles(math.rad(35), 0, 0) * CFrame.new(0, 0, -spec.length / 2 + 0.2)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = rod
	weld.Parent = rod
	local tip = Instance.new("Attachment")
	tip.Name = "RodTip"
	tip.Position = Vector3.new(0, 0, -spec.length / 2)
	tip.Parent = rod
	-- The real rod model (art/README.md: WillowRod, FiberglassRod, GraphiteRod), welded along the
	-- gray-box rod, which stays as the invisible logical rod: it keeps the RodTip the line hangs
	-- from and RodFeel's bend. The model's tip points along its +Z and its blank sits 0.98 above
	-- its base (its centre 0.45 below the blank), so it's turned half round and lowered to fit.
	local art = ServerStorage:FindFirstChild("Art")
	local source = art and art:FindFirstChild(spec.id .. "Rod")
	local mesh = source and source:FindFirstChildWhichIsA("MeshPart", true)
	if mesh then
		local model = mesh:Clone()
		model:ClearAllChildren()
		model.Name = "RodModel"
		model.Anchored = false
		model.CanCollide = false
		model.CanQuery = false
		model.CanTouch = false
		model.Massless = true
		model.CFrame = rod.CFrame * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, -0.45, 0)
		local mw = Instance.new("WeldConstraint")
		mw.Part0 = rod
		mw.Part1 = model
		mw.Parent = model
		model.Parent = rod
		rod.Transparency = 1
		rod.Parent = character
		return
	end
	local reel = Instance.new("Part")
	reel.Name = "Reel"
	reel.Size = Vector3.new(0.5, 0.5, 0.5)
	reel.Color = Color3.fromRGB(150, 150, 155)
	reel.CanCollide = false
	reel.CanQuery = false
	reel.CanTouch = false
	reel.Massless = true
	reel.CFrame = rod.CFrame * CFrame.new(0, -0.3, spec.length / 2 - 1)
	local w2 = Instance.new("WeldConstraint")
	w2.Part0 = rod
	w2.Part1 = reel
	w2.Parent = reel
	reel.Parent = rod
	rod.Parent = character
end

-- Swap the rod in hand after buying or choosing another one.
function RodService.refresh(player: Player)
	if player.Character then
		giveRod(player.Character)
	end
end

function RodService.tip(player: Player): Attachment?
	local c = player.Character
	local rod = c and c:FindFirstChild("Rod")
	return rod and rod:FindFirstChild("RodTip") :: Attachment?
end

function RodService.start()
	PlayerData.onLoad(function(p)
		RodService.refresh(p)
	end)
	local function hook(player: Player)
		player.CharacterAppearanceLoaded:Connect(function(c)
			giveRod(c)
		end)
		player.CharacterAdded:Connect(function(c)
			task.defer(giveRod, c)
		end)
		if player.Character then
			task.defer(giveRod, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
end

return RodService
