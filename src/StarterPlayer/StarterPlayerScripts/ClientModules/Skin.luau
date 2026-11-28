--!strict
-- Dresses GUI objects in the field guide and tackle box look (leg 3, N2) from Shared/UIStyle:
-- fonts, text sizes that never draw under 14 px on a phone, paper, canvas, leather, wood and
-- brass surfaces (a nine-slice image when its asset id is set, else the flat colour and a
-- stroke), and brass buttons. Only used when Config.UI_STYLE_ON is true.
-- UNVERIFIED in Studio: written 2026-11-27 in a worktree.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local UIStyle = require(Shared.UIStyle)

local Skin = {}

Skin.on = Config.UI_STYLE_ON == true
Skin.C = UIStyle.COLORS
-- The smallest side for anything you tap, in interface units, at the smallest scale.
Skin.TOUCH = UIStyle.touchSize(UIStyle.SCALE.min)

local scale = 1
local started = false
-- Every dressed text object and its base size; sizes follow the scale (weak keys: destroyed
-- labels drop out).
local texts: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
-- The face of each dressed text object (the handwriting has a higher floor).
local faces: { [Instance]: string } = setmetatable({}, { __mode = "k" }) :: any

local function readScale(): number
	local cam = workspace.CurrentCamera
	if cam then
		local v = cam.ViewportSize
		return UIStyle.uiScale(v.X, v.Y)
	end
	return 1
end

local function refresh()
	scale = readScale()
	for obj, base in texts do
		(obj :: any).TextSize = UIStyle.textSize(base, scale, faces[obj])
	end
end

local function start()
	if started then
		return
	end
	started = true
	scale = readScale()
	local function hook(cam: Camera?)
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
		end
	end
	hook(workspace.CurrentCamera)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		hook(workspace.CurrentCamera)
		refresh()
	end)
end

function Skin.scale(): number
	start()
	return scale
end

-- Font face (a UIStyle.FONTS role), base size (a UIStyle.TEXT role or a number) and colour.
function Skin.text(obj: Instance, face: string, base: string | number, color: Color3?)
	start()
	local size = if type(base) == "number" then base else (UIStyle.TEXT[base] or UIStyle.TEXT.body)
	local o = obj :: any
	o.FontFace = UIStyle.font(face)
	o.TextScaled = false
	texts[obj] = size
	faces[obj] = face
	o.TextSize = UIStyle.textSize(size, scale, face)
	if color then
		o.TextColor3 = color
	end
end

-- Change the base size of a dressed text object later.
function Skin.resize(obj: Instance, base: string | number)
	local size = if type(base) == "number" then base else (UIStyle.TEXT[base] or UIStyle.TEXT.body)
	texts[obj] = size;
	(obj :: any).TextSize = UIStyle.textSize(size, Skin.scale(), faces[obj])
end

function Skin.corner(obj: Instance, kind: string?)
	local c = obj:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	local r = UIStyle.RADIUS[kind or "panel"] or UIStyle.RADIUS.panel
	c.CornerRadius = if r >= 999 then UDim.new(0.5, 0) else UDim.new(0, r)
	c.Parent = obj
	return c
end

-- One border stroke per object (never the text outline).
function Skin.stroke(obj: Instance, color: Color3, thickness: number?, transparency: number?): UIStroke
	local s = obj:FindFirstChild("SkinStroke") :: UIStroke?
	if not s then
		local made = Instance.new("UIStroke")
		made.Name = "SkinStroke"
		made.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		made.Parent = obj
		s = made
	end
	local st = s :: UIStroke
	st.Color = color
	st.Thickness = thickness or UIStyle.STROKE.panel
	st.Transparency = transparency or 0
	return st
end

function Skin.pad(obj: Instance, p: number, bottom: number?)
	local u = obj:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	u.PaddingLeft = UDim.new(0, p)
	u.PaddingRight = UDim.new(0, p)
	u.PaddingTop = UDim.new(0, p)
	u.PaddingBottom = UDim.new(0, bottom or p)
	u.Parent = obj
	return u
end

-- Paper padding (UIStyle.PAPER_PAD): words sit in from the drawn edge of a paper card.
function Skin.padPaper(obj: Instance): UIPadding
	local P = UIStyle.PAPER_PAD
	local u = Skin.pad(obj, P.side, P.bottom)
	u.PaddingTop = UDim.new(0, P.top)
	return u
end

-- The surface image fills the whole object even when a UIPadding insets its children: it
-- bleeds out by the padding (else the art shrinks and the words land on its edge).
local function bleed(obj: GuiObject, img: GuiObject)
	local conns: { RBXScriptConnection } = {}
	local function fit()
		local u = obj:FindFirstChildOfClass("UIPadding")
		local l = if u then u.PaddingLeft.Offset else 0
		local r = if u then u.PaddingRight.Offset else 0
		local t = if u then u.PaddingTop.Offset else 0
		local b = if u then u.PaddingBottom.Offset else 0
		img.Position = UDim2.fromOffset(-l, -t)
		img.Size = UDim2.new(1, l + r, 1, t + b)
	end
	local watched: UIPadding? = nil
	local function watch()
		local u = obj:FindFirstChildOfClass("UIPadding")
		if u and u ~= watched then
			watched = u
			table.insert(conns, u.Changed:Connect(fit))
		end
		fit()
	end
	table.insert(conns, obj.ChildAdded:Connect(function(c)
		if c:IsA("UIPadding") then
			watch()
		end
	end))
	table.insert(conns, obj.ChildRemoved:Connect(function(c)
		if c == watched then
			watched = nil
			fit()
		end
	end))
	img.Destroying:Connect(function()
		for _, c in conns do
			c:Disconnect()
		end
	end)
	watch()
end

-- A surface from UIStyle.IMAGES: the sliced image under the object's children when the art is
-- uploaded, else its flat colour with a stroke. Returns the image (or nil).
-- sliceScale: the image's SliceScale in interface units (default: the phone mockups' value
-- from UIStyle, which is in real pixels at the smallest scale).
function Skin.surface(obj: GuiObject, imageKey: string, cornerKind: string?, strokeWidth: number?, sliceScale: number?): ImageLabel?
	local spec = UIStyle.IMAGES[imageKey]
	if not spec then
		return nil
	end
	local old = obj:FindFirstChild("SkinImage")
	if old then
		old:Destroy()
	end
	Skin.corner(obj, cornerKind or "panel")
	obj.BackgroundColor3 = Skin.C[spec.fill]
	if spec.id then
		local img = Instance.new("ImageLabel")
		img.Name = "SkinImage"
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = spec.id
		img.ZIndex = 0 -- under the object's own children
		local rect = UIStyle.sliceRect(imageKey)
		if rect then
			img.ScaleType = Enum.ScaleType.Slice
			img.SliceCenter = rect
			img.SliceScale = sliceScale or ((spec.phoneSlice or UIStyle.SCALE.min) / UIStyle.SCALE.min)
		else
			img.ScaleType = Enum.ScaleType.Fit
		end
		if spec.tint then
			img.ImageColor3 = Skin.C[spec.fill]
		end
		img.Parent = obj
		bleed(obj, img)
		obj.BackgroundTransparency = 1
		local st = obj:FindFirstChild("SkinStroke")
		if st then
			st:Destroy()
		end
		-- A child draws over its parent, so a text object's own words would sit under the
		-- image: they move to a copy above it that follows the original.
		if (obj:IsA("TextButton") or obj:IsA("TextLabel")) and not obj:FindFirstChild("SkinText") then
			local src = obj :: any
			local copy = Instance.new("TextLabel")
			copy.Name = "SkinText"
			copy.BackgroundTransparency = 1
			copy.Size = UDim2.fromScale(1, 1)
			copy.ZIndex = 2
			copy.TextWrapped = true
			local function sync()
				copy.Text = src.Text
				copy.TextColor3 = src.TextColor3
				copy.TextSize = src.TextSize
				copy.FontFace = src.FontFace
				copy.TextXAlignment = src.TextXAlignment
				copy.TextYAlignment = src.TextYAlignment
				copy.TextWrapped = src.TextWrapped
				copy.TextTruncate = src.TextTruncate
			end
			sync()
			for _, prop in { "Text", "TextColor3", "TextSize", "FontFace", "TextXAlignment", "TextYAlignment", "TextWrapped", "TextTruncate" } do
				obj:GetPropertyChangedSignal(prop):Connect(sync)
			end
			src.TextTransparency = 1
			copy.Parent = obj
		end
		-- If the image fails to load, go back to the flat colour and stroke.
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync({ img }, function(_, status)
					if status == Enum.AssetFetchStatus.Failure and img.Parent == obj then
						img:Destroy()
						obj.BackgroundTransparency = 0
						if spec.stroke then
							Skin.stroke(obj, Skin.C[spec.stroke], strokeWidth)
						end
						local copy = obj:FindFirstChild("SkinText")
						if copy then
							copy:Destroy();
							(obj :: any).TextTransparency = 0
						end
					end
				end)
			end)
		end)
		return img
	end
	obj.BackgroundTransparency = 0
	if spec.stroke then
		Skin.stroke(obj, Skin.C[spec.stroke], strokeWidth)
	end
	return nil
end

-- The colour of a surface: its fill now, and the tint of its image if the art is white.
function Skin.tint(obj: GuiObject, color: Color3)
	obj.BackgroundColor3 = color
	local img = obj:FindFirstChild("SkinImage") :: ImageLabel?
	if img then
		img.ImageColor3 = color
	end
end

-- A decoration from UIStyle.IMAGES (an icon, a seal, an overlay) when its art is uploaded;
-- nil before, so callers keep their flat stand-in.
function Skin.image(parent: Instance, key: string, size: UDim2, pos: UDim2, tint: Color3?): ImageLabel?
	local spec = UIStyle.IMAGES[key]
	if not spec or not spec.id then
		return nil
	end
	local img = Instance.new("ImageLabel")
	img.Name = key
	img.BackgroundTransparency = 1
	img.Size = size
	img.Position = pos
	img.Image = spec.id
	img.ScaleType = Enum.ScaleType.Fit
	if tint then
		img.ImageColor3 = tint
	end
	img.Parent = parent
	return img
end

-- Brass buttons with the pressed art: swap the image while held and drop the label 4 px times
-- SliceScale (art/ui/README.md).
local function pressable(btn: GuiObject)
	local down = UIStyle.IMAGES.brassButtonPressed
	local up = UIStyle.IMAGES.brassButton
	if not down.id or not up.id or btn:GetAttribute("SkinPressable") then
		return
	end
	btn:SetAttribute("SkinPressable", true)
	local function set(held: boolean)
		local img = btn:FindFirstChild("SkinImage") :: ImageLabel?
		local text = btn:FindFirstChild("SkinText") :: TextLabel?
		if not img or (img.Image ~= up.id and img.Image ~= down.id) then
			return -- painted something else since
		end
		img.Image = (if held then down.id else up.id) :: string
		if text then
			text.Position = UDim2.fromOffset(0, if held then 4 * img.SliceScale else 0)
		end
	end
	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			set(true)
		end
	end)
	btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			set(false)
		end
	end)
end

-- Button looks: brass (buy, act), leather (close, back), sage (use this), off (can't).
local BUTTON = {
	brass = { image = "brassButton", text = "ink" },
	leather = { image = "leather", text = "paper" },
	sage = { fill = "sage", stroke = "greenInk", text = "ink" },
	off = { fill = "paperDeep", stroke = "inkFaint", text = "inkSoft" },
	paper = { fill = "paper", stroke = "inkFaint", text = "ink" },
	tab = { image = "tackleTab", text = "ink", byHeight = 96 }, -- the side tabs: stretch sideways only
}

-- Paints a button (sets its surface and text colour). Fonts are set by Skin.button.
function Skin.paint(btn: GuiObject, kind: string)
	local b = BUTTON[kind] or BUTTON.brass
	if b.image then
		local sliceScale = if b.byHeight then btn.Size.Y.Offset / b.byHeight else nil
		Skin.surface(btn, b.image, "button", nil, sliceScale)
		if b.image == "brassButton" then
			pressable(btn)
		end
	else
		local old = btn:FindFirstChild("SkinImage")
		if old then
			old:Destroy()
		end
		-- The words come back to the button itself (the copy above the art goes).
		local copy = btn:FindFirstChild("SkinText")
		if copy then
			copy:Destroy();
			(btn :: any).TextTransparency = 0
		end
		btn.BackgroundColor3 = Skin.C[b.fill]
		btn.BackgroundTransparency = 0
		Skin.corner(btn, "button")
		Skin.stroke(btn, Skin.C[b.stroke], UIStyle.STROKE.button)
	end
	if btn:IsA("TextButton") or btn:IsA("TextLabel") then
		(btn :: any).TextColor3 = Skin.C[b.text]
	end
end

function Skin.button(btn: TextButton, kind: string, base: string | number?)
	Skin.text(btn, "bodyBold", base or "button")
	Skin.paint(btn, kind)
end

-- A hand-drawn rule: a thin ink line.
function Skin.rule(parent: Instance, name: string, size: UDim2, pos: UDim2, color: Color3?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color or Skin.C.inkFaint
	f.Parent = parent
	return f
end

return Skin
