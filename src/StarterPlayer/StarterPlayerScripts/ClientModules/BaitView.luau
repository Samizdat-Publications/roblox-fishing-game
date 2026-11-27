--!strict
-- What's on the hook, shown in the world (L3): a small part in the bait's colour hanging from
-- the rod tip while you stand ready and charge a cast, and just under the bobber while you
-- wait. An empty hook shows nothing, so you can see when it needs baiting. Local to this
-- player's screen. UNVERIFIED in Studio (written 2026-11-26).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaitData = require(Shared.BaitData)

local BaitView = {}

-- Rough shape per bait: size of the part and whether it's a ball.
local SHAPE: { [string]: { size: Vector3, ball: boolean } } = {
	Worm = { size = Vector3.new(0.12, 0.42, 0.12), ball = false },
	Cricket = { size = Vector3.new(0.18, 0.3, 0.14), ball = false },
	Minnow = { size = Vector3.new(0.1, 0.45, 0.16), ball = false },
	Stinkbait = { size = Vector3.one * 0.26, ball = true },
	Spinner = { size = Vector3.new(0.06, 0.32, 0.2), ball = false },
	PlasticWorm = { size = Vector3.new(0.1, 0.5, 0.1), ball = false },
}
local HANG = 1.3 -- studs below the rod tip
local UNDER_BOBBER = 0.9 -- studs below the bobber

local piece: Part? = nil
local shownBait: string? = nil
local tipAtt: Attachment? = nil
local line: Beam? = nil

local function hide()
	if piece then
		piece.Parent = nil
	end
end

local function make(baitId: string): Part
	if piece then
		piece:Destroy()
	end
	local shape = SHAPE[baitId] or { size = Vector3.one * 0.22, ball = true }
	local p = Instance.new("Part")
	p.Name = "BaitOnHook"
	p.Shape = if shape.ball then Enum.PartType.Ball else Enum.PartType.Block
	p.Size = shape.size
	local b = BaitData.byId[baitId]
	p.Color = (b and b.color) or Color3.fromRGB(200, 120, 120)
	p.Material = if b and b.kind == "lure" then Enum.Material.Metal else Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	local att = Instance.new("Attachment")
	att.Name = "Top"
	att.Position = Vector3.new(0, shape.size.Y / 2, 0)
	att.Parent = p
	piece = p
	shownBait = baitId
	line = nil
	return p
end

-- `baitId` is what's on the hook now (nil for an empty hook); `phase` is the Controller's state.
function BaitView.update(baitId: string?, phase: string)
	local player = Players.LocalPlayer
	local char = player.Character
	if not baitId or not char then
		hide()
		return
	end
	local where: Vector3? = nil
	local fromTip = false
	if phase == "Idle" or phase == "Charging" or phase == "Baiting" then
		local rod = char:FindFirstChild("Rod")
		local tip = rod and rod:FindFirstChild("RodTip")
		if tip and tip:IsA("Attachment") then
			tipAtt = tip
			where = tip.WorldPosition - Vector3.new(0, HANG, 0)
			fromTip = true
		end
	elseif phase == "Casting" or phase == "Waiting" or phase == "Snagged" or phase == "Bite" then
		local bobber = workspace:FindFirstChild("Bobber_" .. player.Name)
		if bobber and bobber:IsA("BasePart") then
			where = bobber.Position - Vector3.new(0, UNDER_BOBBER, 0)
		end
	end
	if not where then
		hide()
		return
	end
	local p = if piece and shownBait == baitId then piece else make(baitId)
	local sway = math.sin(os.clock() * 2.2) * 0.12
	p.CFrame = CFrame.new(where + Vector3.new(sway, 0, 0)) * CFrame.Angles(0, 0, sway)
	-- A short bit of line from the rod tip while it dangles there.
	if fromTip and tipAtt then
		if not line then
			local beam = Instance.new("Beam")
			beam.Name = "Leader"
			beam.Width0 = 0.03
			beam.Width1 = 0.03
			beam.Color = ColorSequence.new(Color3.fromRGB(235, 235, 235))
			beam.FaceCamera = true
			beam.Attachment1 = p:FindFirstChild("Top") :: Attachment
			beam.Parent = p
			line = beam
		end
		(line :: Beam).Attachment0 = tipAtt
		;(line :: Beam).Enabled = true
	elseif line then
		line.Enabled = false
	end
	p.Parent = workspace
end

return BaitView
