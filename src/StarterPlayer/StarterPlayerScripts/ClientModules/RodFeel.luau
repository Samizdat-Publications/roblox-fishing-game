--!strict
-- The rod in this player's hand, bending and swinging (L4b), drawn on this screen only.
--
-- The server's rod (RodService) is one straight part welded to the hand with a "RodTip"
-- attachment the line hangs from. While the rod has something to show (the cast's back swing
-- and whip, or a fish bending it), this hides the real rod for this player and draws a copy
-- in SEGMENTS pieces from the hand: the whole copy pitches back and forward for the swing, and
-- each piece droops a little more than the last for the bend, so the tip curves down. The
-- RodTip attachment moves with the drawn tip, so the line leaves from where the tip is.
-- When there is nothing to show, the real rod comes back exactly as it was.
-- Rules (swing curve, bend per tension) live in Shared/FightFeel. UNVERIFIED in Studio.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FightFeel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FightFeel"))

local RodFeel = {}

local SEGMENTS = 5
local THICK = 0.16 -- the drawn rod's thickness (the real one is 0.18)
local GRIP = 0.2 -- the real rod runs this far behind the hand (RodService)
local BEND_RATE = 10 -- how quickly the drawn bend follows the target (per second)
local SWING_LAG = 0.25 -- during the swing the tip trails the rod by this share of its pitch

local folder: Folder? = nil
local pieces: { Part } = {}
local swingStart = -math.huge
local bendTarget = 0 -- degrees
local bend = 0
local showing = false
local savedTip: { att: Attachment, pos: Vector3 }? = nil

local function myRod(): (BasePart?, Attachment?)
	local char = Players.LocalPlayer.Character
	local rod = char and char:FindFirstChild("Rod")
	if not rod or not rod:IsA("BasePart") then
		return nil, nil
	end
	local tip = rod:FindFirstChild("RodTip")
	return rod, if tip and tip:IsA("Attachment") then tip else nil
end

local function build(rod: BasePart)
	if folder and folder.Parent and #pieces == SEGMENTS then
		return
	end
	if folder then
		folder:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "RodFeel"
	f.Parent = workspace
	folder = f
	table.clear(pieces)
	for i = 1, SEGMENTS do
		local p = Instance.new("Part")
		p.Name = "RodPiece" .. i
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = rod.Color
		p.Size = Vector3.new(THICK, THICK, 1)
		p.Transparency = 1
		p.Parent = f
		pieces[i] = p
	end
end

-- The rest of the character's fade (the bobber camera fades the character while waiting).
local function characterFade(): number
	local char = Players.LocalPlayer.Character
	local head = char and char:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head.LocalTransparencyModifier else 0
end

local function hide()
	if not showing then
		return
	end
	showing = false
	for _, p in pieces do
		p.Transparency = 1
	end
	local rod = myRod()
	if rod then
		rod.LocalTransparencyModifier = characterFade()
		local model = rod:FindFirstChild("RodModel")
		if model and model:IsA("BasePart") then
			model.LocalTransparencyModifier = characterFade()
		end
	end
	local saved = savedTip
	if saved and saved.att.Parent then
		saved.att.Position = saved.pos
	end
	savedTip = nil
end

local function step(dt: number)
	local now = os.clock()
	local swingT = now - swingStart
	local swinging = swingT >= 0 and swingT <= FightFeel.swingTime()
	bend += (bendTarget - bend) * (1 - math.exp(-BEND_RATE * dt))
	if not swinging and bendTarget <= 0 and bend < 0.3 then
		bend = 0
		hide()
		return
	end
	local rod, tip = myRod()
	if not rod then
		hide()
		return
	end
	build(rod)
	if not showing then
		showing = true
		if tip then
			savedTip = { att = tip, pos = tip.Position }
		end
	end
	rod.LocalTransparencyModifier = 1
	-- The real rod model (RodService) can't bend, so it hides while the drawn copy shows.
	local model = rod:FindFirstChild("RodModel")
	if model and model:IsA("BasePart") then
		model.LocalTransparencyModifier = 1
	end
	local fade = characterFade()

	local pitch = if swinging then FightFeel.swingPitch(swingT) else 0
	local totalBend = bend + (if swinging then -pitch * SWING_LAG else 0)
	local len = rod.Size.Z - GRIP
	local segLen = len / SEGMENTS
	-- Start at the hand, pointing along the real rod, pitched for the swing.
	local cf = rod.CFrame * CFrame.new(0, 0, rod.Size.Z / 2 - GRIP) * CFrame.Angles(math.rad(pitch), 0, 0)
	local weights = SEGMENTS * (SEGMENTS + 1) / 2
	for i, p in pieces do
		-- Each piece droops more than the one before (positive bend tips the rod down).
		cf *= CFrame.Angles(-math.rad(totalBend * i / weights), 0, 0)
		p.Color = rod.Color
		p.Size = Vector3.new(THICK * (1 - 0.35 * (i - 1) / SEGMENTS), THICK * (1 - 0.35 * (i - 1) / SEGMENTS), segLen + 0.04)
		p.CFrame = cf * CFrame.new(0, 0, -segLen / 2)
		p.Transparency = fade
		cf *= CFrame.new(0, 0, -segLen)
	end
	if tip then
		tip.Position = rod.CFrame:PointToObjectSpace(cf.Position)
	end
end

-- The cast's back swing and forward whip, starting now.
function RodFeel.swing()
	swingStart = os.clock()
end

-- How far (degrees) the tip should droop; 0 lets the rod straighten and come back.
function RodFeel.setBend(degrees: number)
	bendTarget = math.max(0, degrees)
end

-- Where the drawn rod tip is right now (the line leaves from here).
function RodFeel.tipPosition(): Vector3?
	local _, tip = myRod()
	return if tip then tip.WorldPosition else nil
end

function RodFeel.start()
	-- After the camera and the bobber camera's fade, so the real rod stays hidden while drawn.
	RunService:BindToRenderStep("RodFeel", Enum.RenderPriority.Camera.Value + 10, function(dt)
		step(math.min(dt, 0.1))
	end)
end

return RodFeel
