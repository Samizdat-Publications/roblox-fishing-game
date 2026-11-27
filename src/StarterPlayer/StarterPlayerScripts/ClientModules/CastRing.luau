--!strict
-- The landing ring shown while the cast button is held (L2): a flat ring on the water where
-- the bobber will land, a dotted arc from the rod tip out to it, and a small label naming the
-- spot. Client only: the parts are made by this client in a workspace folder and the label sits
-- in the player's own PlayerGui, so nobody else sees them (handle adornments under the camera
-- did not render in the 11/26 playtest). White over fishable water, red over dry ground, amber over a snag
-- (setSnag, for later).
local Players = game:GetService("Players")

local CastRing = {}

local RING_RADIUS = 2 -- 4 studs across, the size of the target in the design
local RING_INNER = 1.3 -- a thick rim so it reads from the dock on a phone
local BEADS = 10
local BEAD_SIZE = 0.4

local COLORS = {
	water = Color3.fromRGB(255, 255, 255),
	dry = Color3.fromRGB(235, 70, 60),
	snag = Color3.fromRGB(255, 180, 40),
}

local folder: Folder? = nil
local anchor: Part? = nil
local rim: CylinderHandleAdornment? = nil
local fill: CylinderHandleAdornment? = nil
local beads: { Part } = {}
local gui: BillboardGui? = nil
local label: TextLabel? = nil
local snag = false
local shown = false

local function plainPart(name: string, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Locked = true
	return p
end

local function build()
	if folder and folder.Parent then
		return
	end
	-- First time, or the camera was replaced: start over.
	if gui then
		gui:Destroy()
	end
	if folder then
		folder:Destroy()
	end
	shown = false
	local f = Instance.new("Folder")
	f.Name = "CastRing"

	-- An invisible part the ring and label hang off.
	local a = plainPart("RingAnchor", Vector3.new(0.2, 0.2, 0.2))
	a.Transparency = 1
	a.Parent = f

	-- The ring itself: a flat cylinder with a hole (InnerRadius), laid on the water.
	local r = Instance.new("CylinderHandleAdornment")
	r.Name = "Rim"
	r.Adornee = a
	r.Radius = RING_RADIUS
	r.InnerRadius = RING_INNER
	r.Height = 0.2
	r.CFrame = CFrame.Angles(math.rad(90), 0, 0) -- the cylinder's axis is its Z: point it up
	r.Transparency = 0
	r.AlwaysOnTop = false
	r.ZIndex = 1
	r.Parent = a

	-- A faint fill so the spot reads on a busy water surface.
	local d = Instance.new("CylinderHandleAdornment")
	d.Name = "Fill"
	d.Adornee = a
	d.Radius = RING_INNER
	d.Height = 0.06
	d.CFrame = CFrame.Angles(math.rad(90), 0, 0)
	d.Transparency = 0.7
	d.AlwaysOnTop = false
	d.ZIndex = 1
	d.Parent = a

	-- The dotted arc from the rod tip.
	table.clear(beads)
	for i = 1, BEADS do
		local b = plainPart("Bead" .. i, Vector3.new(BEAD_SIZE, BEAD_SIZE, BEAD_SIZE))
		b.Shape = Enum.PartType.Ball
		b.Material = Enum.Material.Neon
		b.Transparency = 0.15
		b.Parent = f
		beads[i] = b
	end

	-- The spot name above the ring.
	local g = Instance.new("BillboardGui")
	g.Name = "CastRingLabel"
	g.Adornee = a
	g.Size = UDim2.fromOffset(190, 34)
	g.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	g.AlwaysOnTop = false -- AlwaysOnTop labels didn't render in the 11/26 playtest
	g.LightInfluence = 0
	g.ResetOnSpawn = false
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(20, 25, 30)
	t.BackgroundTransparency = 0.35
	t.TextColor3 = COLORS.water
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.Text = ""
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = t
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = t
	t.Parent = g
	g.Enabled = false
	g.Parent = a -- under the anchor part: a BillboardGui in PlayerGui didn't show in the playtest

	f.Parent = workspace
	folder, anchor, rim, fill, gui, label = f, a, r, d, g, t
end

-- While aiming, the camera looks through the character, so the ring would sit behind the
-- player's head. Fade the character (only for this player) until the cast is let go.
local function fadeCharacter(on: boolean)
	local char = Players.LocalPlayer.Character
	if not char then
		return
	end
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			(d :: any).LocalTransparencyModifier = if on then 0.7 else 0
		end
	end
end

local function setVisible(on: boolean)
	if rim then
		rim.Visible = on
	end
	if fill then
		fill.Visible = on
	end
	for _, b in beads do
		b.Transparency = if on then 0.15 else 1
	end
	if gui then
		gui.Enabled = on
	end
	fadeCharacter(on)
	shown = on
end

-- Show the ring at `landing` with the arc from `tip`. `onWater` false paints it red;
-- `text` names the spot.
function CastRing.update(tip: Vector3, landing: Vector3, onWater: boolean, text: string)
	build()
	local a = anchor
	if not a then
		return
	end
	-- Keep it a hair above the water so it doesn't flicker into the surface.
	local at = Vector3.new(landing.X, 0.25, landing.Z)
	a.CFrame = CFrame.new(at)
	local color = if not onWater then COLORS.dry elseif snag then COLORS.snag else COLORS.water
	if rim then
		rim.Color3 = color
	end
	if fill then
		fill.Color3 = color
	end
	if label then
		label.Text = text
		label.TextColor3 = color
	end

	-- A parabola from the tip to the ring: higher for longer casts.
	local span = Vector3.new(at.X - tip.X, 0, at.Z - tip.Z).Magnitude
	local lift = 1 + span * 0.08
	for i, b in beads do
		local t = i / (BEADS + 1)
		local p = tip:Lerp(at, t) + Vector3.new(0, lift * 4 * t * (1 - t), 0)
		b.CFrame = CFrame.new(p)
		b.Color = color
	end
	if not shown then
		setVisible(true)
	end
end

function CastRing.hide()
	if shown then
		setVisible(false)
	end
end

-- Amber over a snag (logs, deep weeds). Not used yet: the snag rules come later in L2.
function CastRing.setSnag(on: boolean)
	snag = on
end

function CastRing.colors(): { [string]: Color3 }
	return COLORS
end

return CastRing
