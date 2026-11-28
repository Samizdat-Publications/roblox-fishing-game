--!strict
-- Painted world signs (leg 3, N2, behind Config.PAINTED_SIGNS_ON): a plank board with the words
-- painted on it (a SurfaceGui that darkens at night like paint), on posts or hung from an eave
-- by two chains, with an optional lantern whose light the client lights at night
-- (ClientModules/Lanterns, CollectionService tag "Lantern"). Nothing floats.
--
-- Every part is anchored decoration: no collision, no raycasts (casting and prompts pass
-- through), no touches. WorldBuilder.paintSigns and BoatWorld.paintSigns place the boards over
-- the old BillboardGui signs; Signs.cover / Signs.uncover switch those off and back on.
local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SignLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SignLayout"))

local Signs = {}

Signs.LANTERN_TAG = "Lantern"
Signs.CREAM = Color3.fromRGB(236, 226, 200) -- paint on a dark board
Signs.INK = Color3.fromRGB(38, 34, 30) -- ink on a pale board
-- Weathered paint bases, one per sign (art calls, easy to change).
Signs.PAINT = {
	sell = Color3.fromRGB(112, 50, 38), -- oxblood
	shop = Color3.fromRGB(42, 66, 84), -- faded navy
	pond = Color3.fromRGB(58, 84, 64), -- moss green
	creek = Color3.fromRGB(86, 62, 42), -- dark stain
	slips = Color3.fromRGB(40, 58, 76), -- harbour blue
	pale = Color3.fromRGB(214, 204, 178), -- whitewash, for ink lettering
}

local POST_COLOR = Color3.fromRGB(88, 62, 40)
local METAL = Color3.fromRGB(50, 48, 46)
local GLOW = Color3.fromRGB(255, 190, 120)
local FONT = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
local POST = 0.35 -- post thickness (studs)
local CHAIN = 0.1

export type BoardOptions = {
	text: string,
	width: number,
	height: number,
	cframe: CFrame, -- the board's centre; its LookVector is the painted front
	paint: Color3?,
	ink: Color3?, -- defaults to cream on a dark paint, ink on a pale one
	twoSided: boolean?,
	thickness: number?,
	hang: string?, -- "posts" | "post" | "eave" | nil (fixed to something already there)
	ground: number?, -- posts: the y they stand on
	eave: number?, -- eave: the y the chains hang from
	lantern: boolean?,
	name: string?,
	-- Paint only (the creek kit's arch, CreekPlan.archSign): the board is an unseen carrier for the
	-- painted faces, laid on a slab the art already draws. No wood, no shadow, no supports.
	bare: boolean?,
}

local function piece(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shadow: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = shadow ~= false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Wood, or the WeatheredPlank variant when the place has it (on the variant's own base material).
local function weathered(p: BasePart)
	local v = MaterialService:FindFirstChild("WeatheredPlank")
	if v and v:IsA("MaterialVariant") then
		p.Material = v.BaseMaterial
		p.MaterialVariant = v.Name
	end
end

local function luminance(c: Color3): number
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end

local function paintFace(board: BasePart, face: Enum.NormalId, text: string, paint: Color3, ink: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Paint" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = SignLayout.PIXELS_PER_STUD
	gui.LightInfluence = 1 -- lit by the sun and the lantern, dark at night, like paint
	gui.ClipsDescendants = true
	local shown, size = SignLayout.fit(board.Size.X, board.Size.Y, text)
	local tilt = SignLayout.tilt(text)

	-- A painted border line, a little worn.
	local border = Instance.new("Frame")
	border.Name = "Border"
	border.BackgroundTransparency = 1
	border.Position = UDim2.fromScale(0.04, 0.09)
	border.Size = UDim2.fromScale(0.92, 0.82)
	local stroke = Instance.new("UIStroke")
	stroke.Color = ink
	stroke.Thickness = math.max(2, math.floor(size * 0.06))
	stroke.Transparency = 0.5
	stroke.Parent = border
	border.Parent = gui

	local function label(name: string, offset: number, transparency: number)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.new(0.5, offset, 0.5, offset)
		l.Size = UDim2.fromScale(1 - 2 * SignLayout.MARGIN, 1 - 2 * SignLayout.MARGIN)
		l.BackgroundTransparency = 1
		l.FontFace = FONT
		l.Text = shown
		l.TextSize = size
		l.TextColor3 = ink
		l.TextTransparency = transparency
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.TextYAlignment = Enum.TextYAlignment.Center
		l.LineHeight = 1
		l.Rotation = tilt
		l.Parent = gui
	end
	label("Worn", 2, 0.8) -- a faint second pass, offset, like paint that bled
	label("Words", 0, 0.04)
	gui.Parent = board
end

local function lantern(parent: Instance, at: Vector3, chainTo: number?)
	local m = Instance.new("Model")
	m.Name = "Lantern"
	piece(m, "Cap", Vector3.new(0.6, 0.12, 0.6), CFrame.new(at + Vector3.new(0, 0.36, 0)), METAL, Enum.Material.Metal)
	piece(m, "Base", Vector3.new(0.6, 0.12, 0.6), CFrame.new(at - Vector3.new(0, 0.34, 0)), METAL, Enum.Material.Metal)
	piece(m, "Handle", Vector3.new(0.08, 0.26, 0.34), CFrame.new(at + Vector3.new(0, 0.55, 0)), METAL, Enum.Material.Metal, false)
	for i, c in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
		piece(m, "Bar" .. i, Vector3.new(0.06, 0.58, 0.06), CFrame.new(at + c * 0.24), METAL, Enum.Material.Metal, false)
	end
	local glass = piece(m, "Glass", Vector3.new(0.42, 0.56, 0.42), CFrame.new(at), GLOW, Enum.Material.Neon, false)
	local light = Instance.new("PointLight")
	light.Name = "LanternLight"
	light.Range = 12
	light.Brightness = 1.2
	light.Shadows = true
	light.Color = GLOW
	light.Enabled = false -- the client lights it at night (ClientModules/Lanterns)
	light.Parent = glass
	CollectionService:AddTag(light, Signs.LANTERN_TAG)
	if chainTo and chainTo > at.Y + 0.7 then
		local top = at.Y + 0.68
		piece(m, "Chain", Vector3.new(CHAIN, chainTo - top, CHAIN), CFrame.new(at.X, (top + chainTo) / 2, at.Z), METAL, Enum.Material.Metal, false)
	end
	m.Parent = parent
	return m
end

-- One painted board (a Model, PrimaryPart "Board").
function Signs.board(opts: BoardOptions): Model
	local m = Instance.new("Model")
	m.Name = opts.name or "PaintedSign"
	m:SetAttribute("SignText", opts.text)
	local w, h = opts.width, opts.height
	local thick = opts.thickness or 0.3
	local cf = opts.cframe
	local paint = opts.paint or Signs.PAINT.creek
	local ink = opts.ink or (if luminance(paint) > 0.5 then Signs.INK else Signs.CREAM)

	local board = piece(m, "Board", Vector3.new(w, h, thick), cf, paint, Enum.Material.Wood, not opts.bare)
	if opts.bare then
		board.Transparency = 1
	else
		weathered(board)
	end
	paintFace(board, Enum.NormalId.Front, opts.text, paint, ink)
	if opts.twoSided then
		paintFace(board, Enum.NormalId.Back, opts.text, paint, ink)
	end
	m.PrimaryPart = board

	-- Supports. The board stands upright, so local y is world y.
	local top = cf.Position.Y + h / 2
	local behind = thick / 2 + POST / 2
	local lanternAt: Vector3? = nil
	local lanternChain: number? = nil
	if opts.bare then
		lanternAt = nil
	elseif opts.hang == "posts" or opts.hang == "post" then
		local postTop = top + 0.2
		local bottom = opts.ground or (cf.Position.Y - h / 2 - 3)
		local len = math.max(postTop - bottom, 0.2)
		local midY = (postTop + bottom) / 2 - cf.Position.Y
		local xs = if opts.hang == "post" then { 0 } else { -(w / 2 - 0.45), w / 2 - 0.45 }
		for i, x in xs do
			local post = piece(m, "Post" .. i, Vector3.new(POST, len, POST), cf * CFrame.new(x, midY, behind), POST_COLOR, Enum.Material.Wood)
			weathered(post)
		end
		lanternAt = if opts.hang == "post" then (cf * CFrame.new(0, h / 2 + 0.55, 0)).Position else (cf * CFrame.new(w / 2 - 0.45, h / 2 + 0.2 + 0.45, behind)).Position
	elseif opts.hang == "eave" then
		local eave = opts.eave or (top + 1)
		local len = math.max(eave - top, 0.1)
		for i, x in { -(w / 2 - 0.5), w / 2 - 0.5 } do
			piece(m, "Chain" .. i, Vector3.new(CHAIN, len, CHAIN), cf * CFrame.new(x, h / 2 + len / 2, 0), METAL, Enum.Material.Metal, false)
		end
		lanternAt = (cf * CFrame.new(w / 2 + 0.55, h / 2 - 0.35, 0)).Position
		lanternChain = eave
	else
		lanternAt = (cf * CFrame.new(0, h / 2 + 0.55, 0)).Position
	end
	if opts.lantern and lanternAt then
		lantern(m, lanternAt, lanternChain)
	end
	return m
end

-- Switches an old floating sign off (kept, so unpaint can bring it back).
function Signs.cover(gui: Instance?)
	if gui and gui:IsA("BillboardGui") then
		gui.Enabled = false
		gui:SetAttribute("PaintedOver", true)
	end
end

-- Switches every sign under root that cover switched off back on.
function Signs.uncover(root: Instance?)
	if not root then
		return
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BillboardGui") and d:GetAttribute("PaintedOver") then
			d.Enabled = true
			d:SetAttribute("PaintedOver", nil)
		end
	end
end

-- A fresh folder (the old one, from an earlier run, is destroyed) so painting twice adds nothing.
function Signs.folder(parent: Instance): Folder
	local old = parent:FindFirstChild("PaintedSigns")
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "PaintedSigns"
	f.Parent = parent
	return f
end

-- The direct-child BillboardGui named "Sign" (how WorldBuilder and BoatWorld name them).
function Signs.find(parent: Instance?): BillboardGui?
	local gui = parent and parent:FindFirstChild("Sign")
	return if gui and gui:IsA("BillboardGui") then gui else nil
end

-- The top of a part in world space (works for turned parts, like the upright buoys).
function Signs.topOf(p: BasePart): number
	local cf, s = p.CFrame, p.Size
	return p.Position.Y + math.abs(cf.RightVector.Y) * s.X / 2 + math.abs(cf.UpVector.Y) * s.Y / 2 + math.abs(cf.LookVector.Y) * s.Z / 2
end

return Signs
