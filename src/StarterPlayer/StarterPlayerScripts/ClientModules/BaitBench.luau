--!strict
-- The bait bench (L3): a close-up of the hook and the bait, a hook-size picker, and one
-- button that works the recipe (Shared/BaitRig). The Controller opens it when the hook is
-- empty and you go to cast with live bait, and feeds it presses from every device. It
-- records each press as { down, up } in seconds after the marker starts and hands back the
-- timeline; the server grades it again with the same BaitRig rules.
--
-- The close-up is built from simple parts in a ViewportFrame: a hook from cylinder
-- segments, a worm as a chain of balls, a cricket, a minnow wedge and a lump of stinkbait.
-- The lures (L3b) use the same bench: the spinner's clinch knot (wraps on a beat, then a
-- pull snug) and the plastic worm's Texas rig (nose, slide, bury). Lures carry their own
-- hook, so the hook picker hides for them.
-- UNVERIFIED in Studio (written 2026-11-26 for L3; lures 2026-11-26 for L3b).
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaitRig = require(Shared.BaitRig)
local BaitData = require(Shared.BaitData)
local UIStyle = require(Shared.UIStyle)
local Skin = require(script.Parent.Skin)

local BaitBench = {}
local LOCK = UIStyle.LOCKED.bench
local K = UIStyle.COLORS

export type Result = {
	bait: string,
	hook: string,
	timeline: { BaitRig.Press },
	skipped: boolean,
	grade: BaitRig.Grade, -- the client's own grade, for the result card (the server decides)
}

type Opts = {
	bait: string,
	hook: string,
	firstTime: boolean,
	auto: boolean?, -- Studio test hook: press on the marks by itself
	onDone: (Result) -> (),
}

local C = {
	panel = Color3.fromRGB(24, 32, 40),
	panel2 = Color3.fromRGB(38, 50, 62),
	text = Color3.fromRGB(240, 244, 248),
	dim = Color3.fromRGB(170, 185, 200),
	gold = Color3.fromRGB(250, 205, 80),
	green = Color3.fromRGB(90, 200, 110),
	red = Color3.fromRGB(230, 90, 80),
	steel = Color3.fromRGB(190, 196, 204),
	marker = Color3.fromRGB(255, 120, 60),
}
local GRADE_COLOR = { Perfect = C.gold, Good = C.green, Okay = C.dim }
local RESULT_SHOW = 1.1 -- seconds the grade stays up after the last move

local gui: ScreenGui? = nil
local refs: { [string]: any } = {}
local opts: Opts? = nil
local recipe: BaitRig.Recipe? = nil
local openedAt = 0
local startAt = 0 -- os.clock() when the marker starts moving (after the lead-in)
local downAt: number? = nil -- bench time of the press being held, if it counted
local holdStart: number? = nil -- os.clock() a hold began (any press, for skip)
local timeline: { BaitRig.Press } = {}
local hook = BaitRig.DEFAULT_HOOK
local isLure = false -- the bench is rigging a lure (no hook picker, L3b)
local trackStep = 1 -- the move the timing track is showing (mixed recipes change it per move)
local finished = false
local hideAt = 0
local scene: { [string]: any } = {}

-- Which tap moves show the side-to-side swing on the track (the hook point is the middle).
local SWING: { [string]: { [number]: boolean } } = {
	Minnow = { [1] = true, [2] = true },
	PlasticWorm = { [1] = true },
}
local function swingAt(r: BaitRig.Recipe, i: number): boolean
	local t = SWING[r.bait]
	return t ~= nil and t[i] == true
end

-- The words for a hold move: track labels and what the feedback says on letting go.
type HoldWords = { band: string, low: string, over: string, fbOver: string, fbTight: string, fbLoose: string, fbLow: string }
local HOLD_WORDS: { [string]: HoldWords } = {
	Stinkbait = { band = "pack it here", low = "too little", over = "lump", fbOver = "Too much: a lump", fbTight = "Packed firm!", fbLoose = "Not bad", fbLow = "Too little" },
	Spinner = { band = "snug", low = "loose", over = "kinked", fbOver = "Too hard: it kinked", fbTight = "Snug!", fbLoose = "Not bad", fbLow = "Too loose" },
	PlasticWorm = { band = "slide it here", low = "short", over = "torn", fbOver = "Too far: it tore", fbTight = "Slid up right!", fbLoose = "Not bad", fbLow = "Not far enough" },
}
local LINE = Color3.fromRGB(235, 238, 240)

----------------------------------------------------------------------------------------
-- Building the panel

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function frame(parent: Instance, name: string, size: UDim2, pos: UDim2, color: Color3, transparency: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function label(parent: Instance, name: string, text: string, size: UDim2, pos: UDim2, textSize: number, color: Color3, font: Enum.Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color
	l.TextSize = textSize
	l.Font = font or Enum.Font.GothamMedium
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local function button(parent: Instance, name: string, text: string, size: UDim2, pos: UDim2, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = C.panel2
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Text = text
	b.TextColor3 = C.text
	b.TextSize = 15
	b.Font = Enum.Font.GothamBold
	b.TextWrapped = true
	b.Selectable = false -- the gamepad's A button works the bait, not these
	corner(b, 8)
	b.Activated:Connect(onClick)
	b.Parent = parent
	return b
end

local function refreshHooks()
	for name, b in refs.hookButtons do
		local on = name == hook
		if Skin.on then
			Skin.paint(b, if on then "sage" else "paper")
			Skin.stroke(b, if on then K.greenInk else K.inkFaint, if on then 3 else 1)
		else
			b.BackgroundColor3 = if on then Color3.fromRGB(70, 90, 60) else C.panel2
			b.Stroke.Transparency = if on then 0 else 1
		end
	end
end

-- The new look (Config.UI_STYLE_ON): a canvas bench with paper, ink and brass. The panel, the
-- close-up and the timing track keep their sizes and places (UIStyle.LOCKED.bench).
local function dress()
	local p = refs.panel :: Frame
	Skin.surface(p, "canvas", "panel", 3)
	Skin.text(refs.title, "title", 22, K.ink)
	refs.vp.BackgroundColor3 = K.water
	Skin.corner(refs.vp, "tag")
	Skin.stroke(refs.vp, K.leather, 2)
	Skin.text(refs.result, "title", 44, K.brass)
	refs.result.TextStrokeColor3 = K.ink
	Skin.text(refs.feedback, "bodyBold", 20, K.paper)
	refs.feedback.TextStrokeColor3 = K.ink
	Skin.surface(refs.track, "waterTrack", "tag", 2, 0.7)
	refs.marker.BackgroundColor3 = K.ink
	Skin.stroke(refs.marker, K.paper, 1)
	Skin.text(refs.hookTitle, "title", 17, K.ink)
	Skin.text(refs.lureNote, "hand", "note", K.ink)
	for _, b in refs.hookButtons do
		Skin.text(b, "bodyBold", 15)
		local old = b:FindFirstChild("Stroke")
		if old then
			old:Destroy()
		end
	end
	Skin.text(refs.hookHint, "body", 13, K.inkSoft)
	Skin.text(refs.how, "bodyBold", 16, K.ink)
	Skin.text(refs.tip, "hand", 15, K.ink)
	-- Skip: as tall as the space beside the hooks allows (the panel is locked at 340).
	refs.skip.Size = UDim2.fromOffset(110, 40)
	refs.skip.Position = UDim2.fromOffset(352, 252)
	Skin.button(refs.skip, "brass", 15)
	Skin.text(refs.skipHint, "body", 13, K.inkSoft)
end

local function build()
	local player = Players.LocalPlayer
	local g = Instance.new("ScreenGui")
	g.Name = "BaitBench"
	g.ResetOnSpawn = false
	g.DisplayOrder = 5 -- over the fishing HUD
	g.Enabled = false
	g.Parent = player:WaitForChild("PlayerGui")

	local scale = Instance.new("UIScale")
	scale.Parent = g
	local function rescale()
		local cam = workspace.CurrentCamera
		if cam then
			local v = cam.ViewportSize
			scale.Scale = math.clamp(math.min(v.X / 1280, v.Y / 720) * 1.15, 0.72, 1.25)
		end
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	-- Top centre, nudged left, so the touch Fish button (bottom right) stays clear. -100: at -50
	-- the panel still covered half the Fish button on the smallest phone (iPhone 7, 11/27/2026).
	local p = frame(g, "Panel", UDim2.fromOffset(LOCK.size[1], LOCK.size[2]), UDim2.new(LOCK.pos[1], LOCK.pos[2], LOCK.pos[3], LOCK.pos[4]), C.panel, 0.04)
	p.AnchorPoint = Vector2.new(0.5, 0)
	corner(p, 14)
	refs.title = label(p, "Title", "Bait the hook", UDim2.fromOffset(400, 32), UDim2.fromOffset(16, 8), 22, C.gold, Enum.Font.GothamBlack)
	refs.title.TextXAlignment = Enum.TextXAlignment.Left

	local vp = Instance.new("ViewportFrame")
	vp.Name = "CloseUp"
	vp.Size = UDim2.fromOffset(LOCK.closeUp[1], LOCK.closeUp[2])
	vp.Position = UDim2.fromOffset(LOCK.closeUp[3], LOCK.closeUp[4])
	vp.BackgroundColor3 = Color3.fromRGB(46, 70, 84)
	vp.BorderSizePixel = 0
	vp.Ambient = Color3.fromRGB(150, 150, 150)
	vp.LightColor = Color3.fromRGB(255, 245, 230)
	vp.LightDirection = Vector3.new(-1, -1, -1)
	corner(vp, 10)
	vp.Parent = p
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(Vector3.new(0.6, 0.5, 7), Vector3.new(0.6, 0.5, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
	refs.vp = vp
	local world = Instance.new("Model")
	world.Name = "Scene"
	world.Parent = vp
	refs.world = world

	-- The result over the close-up ("Perfect!").
	refs.result = label(vp, "Result", "", UDim2.fromScale(1, 0.4), UDim2.fromScale(0, 0.3), 44, C.gold, Enum.Font.GothamBlack)
	refs.result.TextStrokeTransparency = 0.2
	refs.result.ZIndex = 3
	refs.feedback = label(vp, "Feedback", "", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 1, -30), 20, C.text, Enum.Font.GothamBlack)
	refs.feedback.TextStrokeTransparency = 0.3
	refs.feedback.ZIndex = 3

	-- The timing track under the close-up: zones to hit and the moving marker (or fill bar).
	local track = frame(p, "Track", UDim2.fromOffset(LOCK.track[1], LOCK.track[2]), UDim2.fromOffset(LOCK.track[3], LOCK.track[4]), Color3.fromRGB(20, 30, 38), 0)
	corner(track, 6)
	track.ClipsDescendants = true
	refs.track = track
	refs.zones = {}
	refs.fill = frame(track, "Fill", UDim2.fromScale(0, 1), UDim2.fromScale(0, 0), Color3.fromRGB(150, 120, 70), 0)
	refs.fill.ZIndex = 2
	refs.marker = frame(track, "Marker", UDim2.new(0, 6, 1, 6), UDim2.new(0, 0, 0, -3), C.marker, 0)
	refs.marker.ZIndex = 4
	corner(refs.marker, 3)
	refs.marks = frame(p, "Marks", UDim2.fromOffset(320, 18), UDim2.fromOffset(16, 274), C.panel, 1)

	-- Hook size picker.
	refs.hookTitle = label(p, "HookTitle", "Hook size", UDim2.fromOffset(232, 22), UDim2.fromOffset(352, 46), 17, C.gold, Enum.Font.GothamBold)
	refs.hookTitle.TextXAlignment = Enum.TextXAlignment.Left
	refs.lureNote = label(p, "LureNote", "Lures carry their own hook.", UDim2.fromOffset(232, 60), UDim2.fromOffset(352, 70), 16, C.dim)
	refs.lureNote.Visible = false
	refs.hookButtons = {}
	for i, name in BaitRig.HOOKS do
		local b = button(p, "Hook" .. name, BaitRig.HOOK_LINES[name], UDim2.fromOffset(232, 50), UDim2.fromOffset(352, 70 + (i - 1) * 56), function()
			BaitBench.setHook(name)
		end)
		local stroke = Instance.new("UIStroke")
		stroke.Name = "Stroke"
		stroke.Color = C.gold
		stroke.Thickness = 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = b
		refs.hookButtons[name] = b
	end
	refs.hookHint = label(p, "HookHint", "", UDim2.fromOffset(232, 20), UDim2.fromOffset(352, 238), 13, C.dim)

	-- What to do, the real tip, and skipping.
	refs.how = label(p, "How", "", UDim2.fromOffset(568, 22), UDim2.fromOffset(16, 294), 16, C.text, Enum.Font.GothamBold)
	refs.how.TextXAlignment = Enum.TextXAlignment.Left
	refs.tip = label(p, "Tip", "", UDim2.fromOffset(440, 26), UDim2.fromOffset(16, 314), 15, C.dim)
	refs.tip.TextXAlignment = Enum.TextXAlignment.Left
	refs.skip = button(p, "Skip", "Skip", UDim2.fromOffset(110, 30), UDim2.fromOffset(352, 258), function()
		BaitBench.skip()
	end)
	refs.skipHint = label(p, "SkipHint", "or hold 1 s", UDim2.fromOffset(116, 30), UDim2.fromOffset(468, 258), 13, C.dim)
	refs.panel = p
	gui = g
	if Skin.on then
		dress()
	end
end

----------------------------------------------------------------------------------------
-- The close-up

local function part(shape: Enum.PartType?, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local pt = Instance.new("Part")
	pt.Shape = shape or Enum.PartType.Block
	pt.Size = size
	pt.CFrame = cf
	pt.Color = color
	pt.Material = material or Enum.Material.SmoothPlastic
	pt.Anchored = true
	pt.CanCollide = false
	pt.CastShadow = false
	pt.Parent = refs.world
	return pt
end

-- A stretched ball (Ball parts are always round, so this is a block with a sphere mesh).
local function blob(size: Vector3, cf: CFrame, color: Color3): Part
	local pt = part(Enum.PartType.Block, size, cf, color)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = pt
	return pt
end

-- Stretch a cylinder part from a to b (keeps its thickness).
local function placeRod(pt: BasePart, a: Vector3, b: Vector3)
	local len = math.max((b - a).Magnitude, 0.01)
	pt.Size = Vector3.new(len, pt.Size.Y, pt.Size.Z)
	pt.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
end

-- A rod-like cylinder from a to b.
local function rod(a: Vector3, b: Vector3, thick: number, color: Color3, material: Enum.Material?): Part
	local pt = part(Enum.PartType.Cylinder, Vector3.new(1, thick, thick), CFrame.new(), color, material)
	placeRod(pt, a, b)
	return pt
end

-- The hook as a path from the point (u = 0) round the bend (u = 0.5) up the shank (u = 1).
local HOOK_PATH: { Vector3 } = {}
do
	table.insert(HOOK_PATH, Vector3.new(1.2, 0.55, 0))
	table.insert(HOOK_PATH, Vector3.new(1.2, -0.5, 0))
	for i = 1, 8 do
		local a = -math.pi * i / 8
		table.insert(HOOK_PATH, Vector3.new(0.6 + 0.6 * math.cos(a), -0.5 + 0.6 * math.sin(a), 0))
	end
	table.insert(HOOK_PATH, Vector3.new(0, 0.6, 0))
	table.insert(HOOK_PATH, Vector3.new(0, 1.9, 0))
end
local HOOK_LEN: { number } = { 0 }
for i = 2, #HOOK_PATH do
	HOOK_LEN[i] = HOOK_LEN[i - 1] + (HOOK_PATH[i] - HOOK_PATH[i - 1]).Magnitude
end

local function hookAt(u: number): Vector3
	local want = math.clamp(u, 0, 1) * HOOK_LEN[#HOOK_LEN]
	for i = 2, #HOOK_PATH do
		if HOOK_LEN[i] >= want then
			local seg = HOOK_LEN[i] - HOOK_LEN[i - 1]
			local f = if seg > 0 then (want - HOOK_LEN[i - 1]) / seg else 0
			return HOOK_PATH[i - 1]:Lerp(HOOK_PATH[i], f)
		end
	end
	return HOOK_PATH[#HOOK_PATH]
end

-- Hook sizes draw a little bigger or smaller.
local HOOK_SCALE = { Small = 0.8, Medium = 1, Large = 1.2 }

local function buildHook(at: CFrame, size: string, scale: number?)
	local s = scale or HOOK_SCALE[size] or 1
	local hookModel = {}
	for i = 2, #HOOK_PATH do
		table.insert(hookModel, rod(at:PointToWorldSpace(HOOK_PATH[i - 1] * s), at:PointToWorldSpace(HOOK_PATH[i] * s), 0.09 * s, C.steel, Enum.Material.Metal))
	end
	-- The barb by the point, and the eye at the top of the shank.
	local tip = at:PointToWorldSpace(HOOK_PATH[1] * s)
	table.insert(hookModel, rod(tip, tip + at:VectorToWorldSpace(Vector3.new(-0.18, -0.3, 0)) * s, 0.07 * s, C.steel, Enum.Material.Metal))
	local eye = part(Enum.PartType.Ball, Vector3.one * 0.22 * s, CFrame.new(at:PointToWorldSpace(Vector3.new(0, 2.0, 0) * s)), C.steel, Enum.Material.Metal)
	table.insert(hookModel, eye)
	scene.hookParts = hookModel
	scene.hookScale = s
	scene.hookAt = at
end

local function clearScene()
	refs.world:ClearAllChildren()
	scene = {}
end

local function buildScene(bait: string)
	clearScene()
	local color = (BaitData.byId[bait] and BaitData.byId[bait].color) or C.marker
	scene.marker = part(Enum.PartType.Ball, Vector3.one * 0.22, CFrame.new(), C.marker, Enum.Material.Neon)
	if bait == "Worm" then
		buildHook(CFrame.new(), hook)
		scene.worm = {}
		for i = 1, 12 do
			scene.worm[i] = part(Enum.PartType.Ball, Vector3.one * 0.26, CFrame.new(), color)
		end
	elseif bait == "Cricket" then
		-- The cricket lies across the top; the marker runs along its back, tail to head.
		local y = 0.9
		scene.cricketY = y
		blob(Vector3.new(1.0, 0.5, 0.5), CFrame.new(-0.4, y, 0), color) -- abdomen
		blob(Vector3.new(0.5, 0.42, 0.42), CFrame.new(0.35, y + 0.02, 0), color) -- thorax
		part(Enum.PartType.Cylinder, Vector3.new(0.12, 0.44, 0.44), CFrame.new(0.72, y + 0.02, 0), Color3.fromRGB(120, 95, 60)) -- collar
		part(Enum.PartType.Ball, Vector3.one * 0.38, CFrame.new(1.0, y + 0.04, 0), color) -- head
		rod(Vector3.new(1.15, y + 0.12, 0), Vector3.new(2.0, y + 0.6, 0), 0.03, color) -- antennae
		rod(Vector3.new(1.15, y + 0.1, 0), Vector3.new(1.9, y + 0.75, -0.1), 0.03, color)
		for _, x in { -0.2, 0.2, 0.45 } do
			rod(Vector3.new(x, y - 0.15, 0), Vector3.new(x - 0.35, y - 0.55, 0), 0.05, color) -- legs
		end
		rod(Vector3.new(-0.3, y, 0), Vector3.new(-1.0, y + 0.45, 0), 0.08, color) -- jumping leg
		buildHook(CFrame.new(0.2, -0.9, 0), hook)
	elseif bait == "Minnow" then
		buildHook(CFrame.new(-0.3, -0.7, 0), hook)
		scene.minnow = blob(Vector3.new(1.4, 0.36, 0.18), CFrame.new(), color)
		scene.minnowTail = part(Enum.PartType.Block, Vector3.new(0.1, 0.4, 0.4), CFrame.new(), color)
		local tailMesh = Instance.new("SpecialMesh")
		tailMesh.MeshType = Enum.MeshType.Wedge
		tailMesh.Parent = scene.minnowTail
		scene.minnowEye = part(Enum.PartType.Ball, Vector3.one * 0.08, CFrame.new(), Color3.new(0.05, 0.05, 0.05))
	elseif bait == "Stinkbait" then
		buildHook(CFrame.new(), hook)
		scene.lumps = {}
		local offsets = { Vector3.new(0.6, -0.9, 0.1), Vector3.new(0.3, -0.7, -0.1), Vector3.new(0.9, -0.7, 0.05), Vector3.new(0.6, -0.55, 0.2), Vector3.new(0.45, -1.0, -0.15) }
		for i, o in offsets do
			local lump = part(Enum.PartType.Ball, Vector3.one * 0.1, CFrame.new(o), color, Enum.Material.Slate)
			scene.lumps[i] = { part = lump, at = o }
		end
	elseif bait == "Spinner" then
		-- The spinner on the left; the line runs right from its eye (the standing line). The
		-- marker is the tag end looping round the standing line: tap as it crosses in front.
		local eye = Vector3.new(-1.0, 0.5, 0)
		scene.eye = eye
		rod(Vector3.new(-3.0, 0.5, 0), eye, 0.05, C.steel, Enum.Material.Metal) -- the shaft
		blob(Vector3.new(0.7, 0.36, 0.08), CFrame.new(-2.05, 0.8, 0) * CFrame.Angles(0, 0, math.rad(-20)), color) -- the blade
		part(Enum.PartType.Ball, Vector3.one * 0.3, CFrame.new(-2.6, 0.5, 0), Color3.fromRGB(200, 60, 50)) -- the body
		part(Enum.PartType.Ball, Vector3.one * 0.18, CFrame.new(-1.5, 0.5, 0), C.steel, Enum.Material.Metal) -- a bead
		buildHook(CFrame.new(-3.0, 0.5 - 2.0 * 0.35, 0) * CFrame.Angles(0, math.rad(180), 0), hook, 0.35) -- its own small hook
		part(Enum.PartType.Ball, Vector3.one * 0.14, CFrame.new(eye), C.steel, Enum.Material.Metal) -- the eye
		rod(eye, Vector3.new(4.8, 0.5, 0), 0.035, LINE) -- the standing line
		scene.tag = rod(eye, eye + Vector3.new(0.3, -0.25, 0), 0.03, LINE)
		scene.coils = {}
		for i = 1, 5 do
			local c = rod(eye, eye + Vector3.new(0, 0.5, 0), 0.045, LINE)
			c.Transparency = 1
			scene.coils[i] = c
		end
	elseif bait == "PlasticWorm" then
		-- Its own worm hook (always the same size), and a soft plastic worm as a chain of balls.
		buildHook(CFrame.new(-0.2, -0.5, 0), hook, 1)
		scene.pw = {}
		for i = 1, 12 do
			scene.pw[i] = part(Enum.PartType.Ball, Vector3.one * (if i == 1 then 0.28 else 0.25), CFrame.new(), color)
		end
		scene.pwColor = color
		scene.pwCover = part(Enum.PartType.Ball, Vector3.one * 0.3, CFrame.new(), color)
		scene.pwCover.Transparency = 1
	end
end

-- How full a hold move's bar is: live while it's held, else as it was let go (0 before).
local function holdFill(r: BaitRig.Recipe, step: number, t: number): number
	local first = opts ~= nil and (opts :: Opts).firstTime
	if downAt and #timeline + 1 == step then
		return BaitRig.fillAt(r, t - (downAt :: number), first)
	end
	local p = timeline[step]
	if p then
		return BaitRig.fillAt(r, p.up - p.down, first)
	end
	return 0
end

-- Draw the close-up for this frame. `t` is bench time, `done` the presses made so far.
local function renderScene(t: number, done: number)
	local r = recipe
	local o = opts
	if not r or not o then
		return
	end
	local first = o.firstTime
	local s = scene.hookScale or 1
	local at: CFrame = scene.hookAt or CFrame.new()
	if r.bait == "Worm" then
		local u = BaitRig.markerAt(r, math.max(t, 0), first)
		scene.marker.Position = at:PointToWorldSpace(hookAt(u) * s) + Vector3.new(0, 0, 0.12)
		-- Threaded part of the worm follows the hook from the point; the rest hangs and wiggles.
		local onHook = math.floor(done / r.presses * 8 + 0.5)
		local reach = done / r.presses * 0.85
		for i, ball in scene.worm do
			if i <= onHook then
				ball.Position = at:PointToWorldSpace(hookAt(reach * (onHook - i + 1) / math.max(onHook, 1)) * s)
			else
				local k = i - onHook
				local base = if done > 0 then at:PointToWorldSpace(hookAt(0) * s) else Vector3.new(-1.0, 1.4, 0)
				ball.Position = base + Vector3.new(math.sin(os.clock() * 5 + k * 0.7) * 0.08 * k, -0.2 * k, 0.05)
			end
		end
	elseif r.bait == "Cricket" then
		local u = BaitRig.markerAt(r, math.max(t, 0), first)
		scene.marker.Position = Vector3.new(-0.9 + u * 2.6, (scene.cricketY or 0.9) + 0.32, 0.25)
	elseif r.bait == "Minnow" then
		local phase = BaitRig.markerAt(r, math.max(t, 0), first)
		local tipPos = at:PointToWorldSpace(HOOK_PATH[1] * s)
		-- Its lips (0.6 ahead of its middle) line up with the hook point mid-swing.
		local x = tipPos.X - 0.6 + math.cos(phase * 2 * math.pi) * 1.1
		local y = tipPos.Y + 0.35
		local swim = math.sin(os.clock() * 9) * 0.15
		scene.minnow.CFrame = CFrame.new(x, y, 0) * CFrame.Angles(0, swim, 0)
		scene.minnowTail.CFrame = CFrame.new(x - 0.78, y, 0) * CFrame.Angles(0, swim + math.rad(90), 0)
		scene.minnowEye.Position = Vector3.new(x + 0.5, y + 0.06, 0.1)
		scene.marker.Position = tipPos + Vector3.new(0, 0.1, 0.15)
		scene.marker.Transparency = if done >= r.presses then 1 else 0
	elseif r.bait == "Stinkbait" then
		local fill = 0
		if downAt then
			fill = BaitRig.fillAt(r, t - (downAt :: number), first)
		elseif #timeline > 0 then
			local p = timeline[#timeline]
			fill = BaitRig.fillAt(r, p.up - p.down, first)
		end
		for i, l in scene.lumps do
			local grow = math.clamp(fill * 1.15 - (i - 1) * 0.08, 0, 1.4)
			l.part.Size = Vector3.one * (0.1 + grow * 0.55)
			l.part.Position = at:PointToWorldSpace(l.at * s)
		end
		scene.marker.Transparency = 1
	elseif r.bait == "Spinner" then
		-- Five wraps go on as coils along the standing line; the pull draws them tight.
		local eye: Vector3 = scene.eye
		local wraps = math.min(done, 5)
		local fill = holdFill(r, 6, t)
		local snug = math.clamp(fill / r.band, 0, 1)
		local spacing = 0.3 - 0.16 * snug
		local start = eye.X + 0.35 - 0.15 * snug
		for k, c in scene.coils do
			local x = start + (k - 1) * spacing
			c.Transparency = if k <= wraps then 0 else 1
			c.Color = if fill > 1 then C.red else LINE
			placeRod(c, Vector3.new(x - 0.08, eye.Y - 0.24, 0.13), Vector3.new(x + 0.08, eye.Y + 0.24, 0.13))
		end
		if done < 5 then
			-- The tag end loops round the standing line once a beat; gold as it crosses in front.
			local phase = BaitRig.markerAt(r, math.max(t, 0), first)
			local a = 2 * math.pi * (phase - 0.5)
			local pos = Vector3.new(start + wraps * spacing, eye.Y + 0.3 * math.sin(a), 0.3 * math.cos(a))
			scene.marker.Position = pos
			scene.marker.Color = if math.abs(phase - 0.5) <= r.tight then C.gold else C.marker
			scene.marker.Transparency = if t < 0 then 0.6 else 0
			local from = if wraps == 0 then eye + Vector3.new(0.15, -0.2, 0.1) else Vector3.new(start + (wraps - 1) * spacing, eye.Y - 0.2, 0.1)
			placeRod(scene.tag, from, pos)
		else
			-- Back through the loop by the eye, then pulled: the tag end trails off down and right.
			scene.marker.Transparency = 1
			local last = start + 4 * spacing
			placeRod(scene.tag, Vector3.new(eye.X + 0.15, eye.Y - 0.12, 0.12), Vector3.new(last + 0.4 + 0.5 * snug, eye.Y - 0.45 - 0.3 * snug, 0.1))
		end
	elseif r.bait == "PlasticWorm" then
		local tipPos = at:PointToWorldSpace(HOOK_PATH[1] * s)
		local n = #scene.pw
		local gap = 0.2
		if done == 0 then
			-- The worm swings side to side above the point: tap when its nose is right over it.
			local phase = BaitRig.markerAt(r, math.max(t, 0), first)
			local noseX = tipPos.X + 1.1 * math.cos(phase * 2 * math.pi)
			for k, ball in scene.pw do
				local wig = math.sin(os.clock() * 4 + k * 0.6) * 0.04 * k
				ball.Position = Vector3.new(noseX + wig, tipPos.Y + 0.18 + (k - 1) * gap, 0.2)
			end
			scene.marker.Position = tipPos + Vector3.new(0, 0, 0.15)
			scene.marker.Transparency = 0
			scene.pwCover.Transparency = 1
		else
			-- The nose is on: holding slides the worm round the bend and up the shank.
			local fill = holdFill(r, 2, t)
			local headU = math.clamp(fill / r.band, 0, 1)
			local du = gap / (HOOK_LEN[#HOOK_LEN] * s)
			local positions: { Vector3 } = {}
			for k = 1, n do
				local u = headU - (k - 1) * du
				if u >= 0 then
					positions[k] = at:PointToWorldSpace(hookAt(u) * s) + Vector3.new(0, 0, 0.05)
				else
					local over = -u / du * gap
					positions[k] = tipPos + Vector3.new(math.sin(os.clock() * 4 + k * 0.6) * 0.03 * k, 0.18 + over, 0.05)
				end
			end
			for k, ball in scene.pw do
				ball.Position = positions[k]
				ball.Color = if fill > 1 then Color3.fromRGB(120, 40, 60) else scene.pwColor
			end
			if done >= 2 then
				-- The marker runs down the body: tap to bury the point back in.
				local phase = BaitRig.markerAt(r, math.max(t, 0), first)
				local f = 1 + phase * (n - 1)
				local i0 = math.clamp(math.floor(f), 1, n - 1)
				scene.marker.Position = positions[i0]:Lerp(positions[i0 + 1], f - i0) + Vector3.new(0, 0, 0.18)
				scene.marker.Transparency = if done >= 3 then 1 else 0
			else
				scene.marker.Transparency = 1
			end
			scene.pwCover.Position = tipPos + Vector3.new(0, 0, 0.04)
			scene.pwCover.Transparency = if done >= 3 then 0 else 1
		end
	end
end

----------------------------------------------------------------------------------------
-- The timing track

local function zone(x0: number, x1: number, color: Color3, transparency: number)
	local z = frame(refs.track, "Zone", UDim2.fromScale(math.clamp(x1 - x0, 0, 1), 1), UDim2.fromScale(math.clamp(x0, 0, 1), 0), color, transparency)
	z.ZIndex = 1
	table.insert(refs.zones, z)
	-- A zone that wraps past the end of the track continues at the start.
	if x0 < 0 then
		zone(1 + x0, 1, color, transparency)
	elseif x1 > 1 then
		zone(0, x1 - 1, color, transparency)
	end
end

local function markLabel(text: string, x: number)
	local l = label(refs.marks, "Mark", text, UDim2.fromOffset(90, 18), UDim2.new(x, -45, 0, 0), 13, C.dim)
	if Skin.on then
		Skin.text(l, "body", "tiny", K.ink)
	end
	table.insert(refs.zones, l)
end

-- The minnow's track shows its side-to-side swing; the hook point is the middle.
local function minnowX(phase: number): number
	return 0.5 + 0.45 * math.cos(phase * 2 * math.pi)
end

-- The track for move `step`. Taps-only recipes show every mark at once; a mixed recipe (the
-- lures, L3b) shows just the move you're on, so the track changes as you go.
local function buildTrack(r: BaitRig.Recipe, step: number)
	for _, z in refs.zones do
		z:Destroy()
	end
	refs.zones = {}
	trackStep = step
	local hold = BaitRig.moveOf(r, step) == "hold"
	local tight, loose = BaitRig.windowOf(r, step)
	refs.fill.Visible = hold
	refs.fill.Size = UDim2.fromScale(0, 1)
	refs.marker.Visible = not hold
	if hold then
		local words = HOLD_WORDS[r.bait] or HOLD_WORDS.Stinkbait
		zone(r.band - loose, r.band + loose, C.green, 0.65)
		zone(r.band - tight, r.band + tight, C.gold, 0.2)
		markLabel(words.band, r.band)
		markLabel(words.low, 0.2)
		markLabel(words.over, 0.94)
	elseif swingAt(r, step) then
		local slope = 0.45 * 2 * math.pi -- track units per marker unit at the middle of the swing
		zone(0.5 - loose * slope, 0.5 + loose * slope, C.green, 0.65)
		zone(0.5 - tight * slope, 0.5 + tight * slope, C.gold, 0.2)
		markLabel(if r.bait == "Minnow" then "hook point" else (r.marks[step] or ""), 0.5)
	elseif r.kind == "mixed" then
		for _, target in r.targets[step] or {} do
			zone(target - loose, target + loose, C.green, 0.65)
			zone(target - tight, target + tight, C.gold, 0.2)
			markLabel(r.marks[step] or "", target)
		end
	else
		for i, list in r.targets do
			for _, target in list do
				zone(target - r.loose, target + r.loose, C.green, 0.65)
				zone(target - r.tight, target + r.tight, C.gold, 0.2)
				markLabel(r.marks[i] or "", target)
			end
		end
	end
end

local function renderTrack(t: number)
	local r = recipe
	local o = opts
	if not r or not o then
		return
	end
	local step = math.min(#timeline + 1, r.presses)
	if r.kind == "mixed" and step ~= trackStep then
		buildTrack(r, step)
	end
	if BaitRig.moveOf(r, trackStep) == "hold" then
		local fill = holdFill(r, trackStep, t)
		refs.fill.Size = UDim2.fromScale(math.clamp(fill, 0, 1), 1)
		refs.fill.BackgroundColor3 = if fill > 1 then C.red else Color3.fromRGB(150, 120, 70)
		return
	end
	local phase = BaitRig.markerAt(r, math.max(t, 0), o.firstTime)
	local x = if swingAt(r, trackStep) then minnowX(phase) else phase
	refs.marker.Position = UDim2.new(x, -3, 0, -3)
	refs.marker.BackgroundTransparency = if t < 0 then 0.6 else 0
end

----------------------------------------------------------------------------------------
-- Running the bench

local function benchTime(): number
	return os.clock() - startAt
end

local function finish(skipped: boolean)
	local o = opts
	local r = recipe
	if finished or not o or not r then
		return
	end
	finished = true
	downAt = nil
	holdStart = nil
	local grade: BaitRig.Grade = "Okay"
	if not skipped then
		grade = BaitRig.grade(r, timeline, o.firstTime)
	end
	refs.result.Text = if skipped then "Skipped: Okay" else (grade .. "!")
	refs.result.TextColor3 = GRADE_COLOR[grade]
	refs.feedback.Text = ""
	hideAt = os.clock() + RESULT_SHOW
	o.onDone({ bait = o.bait, hook = hook, timeline = table.clone(timeline), skipped = skipped, grade = grade })
end

function BaitBench.open(o: Opts)
	if not gui then
		build()
	end
	local r = BaitRig.recipeFor(o.bait)
	if not r then
		return
	end
	opts = o
	recipe = r
	hook = if BaitRig.isHook(o.hook) then o.hook else BaitRig.DEFAULT_HOOK
	timeline = {}
	downAt = nil
	holdStart = nil
	finished = false
	openedAt = os.clock()
	startAt = openedAt + BaitRig.LEAD_IN
	local b = BaitData.byId[o.bait]
	isLure = b ~= nil and b.kind == "lure"
	refs.title.Text = (if isLure then "Rig the lure: " else "Bait the hook: ") .. (if b then b.name else o.bait)
	-- Lures carry their own hook: no hook picker (L3b).
	refs.hookTitle.Visible = not isLure
	refs.hookHint.Visible = not isLure
	refs.lureNote.Visible = isLure
	for _, hb in refs.hookButtons do
		hb.Visible = not isLure
	end
	refs.how.Text = r.how
	refs.tip.Text = "Tip: " .. r.tip
	-- The first time with a bait: a slower marker and the tip in big gold letters.
	if Skin.on then
		Skin.resize(refs.tip, if o.firstTime then 19 else 15)
		refs.tip.TextColor3 = if o.firstTime then K.brassInk else K.ink
	else
		refs.tip.TextSize = if o.firstTime then 19 else 15
		refs.tip.TextColor3 = if o.firstTime then C.gold else C.dim
		refs.tip.Font = if o.firstTime then Enum.Font.GothamBold else Enum.Font.GothamMedium
	end
	refs.result.Text = ""
	refs.feedback.Text = if o.firstTime then "First time: slow and steady" else ""
	refs.skipHint.Text = string.format("or hold %d s", math.floor(BaitRig.skipHold(r, o.firstTime) + 0.5))
	buildScene(o.bait)
	buildTrack(r, 1)
	refreshHooks()
	GuiService.SelectedObject = nil
	;(gui :: ScreenGui).Enabled = true
end

function BaitBench.isOpen(): boolean
	return gui ~= nil and (gui :: ScreenGui).Enabled
end

-- True while the bench is taking moves (not showing its result).
function BaitBench.isActive(): boolean
	return BaitBench.isOpen() and not finished and opts ~= nil
end

function BaitBench.close()
	if gui then
		(gui :: ScreenGui).Enabled = false
	end
	opts = nil
	recipe = nil
	downAt = nil
	holdStart = nil
	finished = true
end

-- Close it unless it is showing its result (a reset or a hint while baiting).
function BaitBench.cancel()
	if BaitBench.isActive() then
		BaitBench.close()
	end
end

function BaitBench.setHook(name: string)
	if BaitRig.isHook(name) and not finished and not isLure then
		hook = name
		refreshHooks()
		if opts then
			buildScene(opts.bait)
		end
	end
end

-- Gamepad L1 / X and the H key: the next hook size.
function BaitBench.cycleHook()
	local i = table.find(BaitRig.HOOKS, hook) or 2
	BaitBench.setHook(BaitRig.HOOKS[(i % #BaitRig.HOOKS) + 1])
end

function BaitBench.skip()
	if BaitBench.isActive() then
		finish(true)
	end
end

-- The move button went down (any device).
function BaitBench.press()
	local r = recipe
	local o = opts
	if not BaitBench.isActive() or not r or not o then
		return
	end
	if os.clock() - openedAt < 0.15 then
		return -- the press that opened the bench (going to cast) is not a move, nor a skip
	end
	holdStart = os.clock()
	local t = benchTime()
	if t < 0 or #timeline >= r.presses then
		return -- before the marker moves, the press only counts toward a skip hold
	end
	downAt = t
	local i = #timeline + 1
	if BaitRig.moveOf(r, i) == "tap" then
		local err = BaitRig.errorOf(r, i, { down = t, up = t }, o.firstTime)
		local tight, loose = BaitRig.windowOf(r, i)
		local prefix = if r.marks[i] == "wrap" then string.format("Wrap %d: ", i) else ""
		refs.feedback.Text = prefix .. (if err <= tight then "Right on!" elseif err <= loose then "Close" else "Missed the mark")
		refs.feedback.TextColor3 = if err <= tight then C.gold elseif err <= loose then C.green else C.red
	end
end

-- The move button came back up.
function BaitBench.release()
	local r = recipe
	local o = opts
	holdStart = nil
	if not BaitBench.isActive() or not r or not o or downAt == nil then
		downAt = nil
		return
	end
	local t = benchTime()
	local press: BaitRig.Press = { down = downAt :: number, up = math.max(t, downAt :: number) }
	downAt = nil
	table.insert(timeline, press)
	local i = #timeline
	if BaitRig.moveOf(r, i) == "hold" then
		local err = BaitRig.errorOf(r, i, press, o.firstTime)
		local tight, loose = BaitRig.windowOf(r, i)
		local words = HOLD_WORDS[r.bait] or HOLD_WORDS.Stinkbait
		refs.feedback.Text = if err == math.huge then words.fbOver elseif err <= tight then words.fbTight elseif err <= loose then words.fbLoose else words.fbLow
		refs.feedback.TextColor3 = if err <= tight then C.gold elseif err <= loose then C.green else C.red
	end
	if #timeline >= r.presses then
		finish(false)
	end
end

-- Studio test hook: press on the marks (taps) or let go in the band (stinkbait) by itself.
local autoDown = false
local function autoStep(t: number)
	local r = recipe
	local o = opts
	if not r or not o or t < 0 then
		return
	end
	local i = #timeline + 1
	if i > r.presses then
		return
	end
	if BaitRig.moveOf(r, i) == "hold" then
		if not autoDown then
			local prev = timeline[i - 1]
			local ready = if prev then t - prev.down >= BaitRig.MIN_GAP + 0.05 and t >= prev.up + 0.05 else t > 0.3
			if ready then
				autoDown = true
				BaitBench.press()
			end
		elseif downAt and BaitRig.fillAt(r, t - (downAt :: number), o.firstTime) >= r.band then
			autoDown = false
			BaitBench.release()
		end
		return
	end
	if autoDown then
		autoDown = false
		BaitBench.release()
		return
	end
	if i > 1 and t - timeline[i - 1].down < BaitRig.MIN_GAP + 0.05 then
		return
	end
	local tight = BaitRig.windowOf(r, i)
	if BaitRig.errorOf(r, i, { down = t, up = t }, o.firstTime) <= tight * 0.5 then
		autoDown = true
		BaitBench.press()
	end
end

-- Every frame while the bench is open.
function BaitBench.step()
	if not BaitBench.isOpen() then
		return
	end
	local now = os.clock()
	if finished then
		if now >= hideAt then
			BaitBench.close()
		end
		return
	end
	local r = recipe
	local o = opts
	if not r or not o then
		return
	end
	local t = benchTime()
	if o.auto then
		autoStep(t)
	end
	renderTrack(t)
	renderScene(t, #timeline)
	-- Hold to skip (stinkbait waits until its bar has overflowed).
	if holdStart and now - (holdStart :: number) >= BaitRig.skipHold(r, o.firstTime) then
		finish(true)
	elseif now - openedAt > BaitRig.BENCH_TIMEOUT then
		finish(true)
	end
end

-- True when a screen point is over one of the bench's buttons (or another button on screen),
-- so a click there picks a hook or skips instead of counting as a move.
function BaitBench.overButton(pos: Vector3 | Vector2): boolean
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return false
	end
	for _, obj in playerGui:GetGuiObjectsAtPosition(pos.X, pos.Y) do
		if obj:IsA("GuiButton") and obj.Visible then
			return true
		end
	end
	return false
end

return BaitBench
