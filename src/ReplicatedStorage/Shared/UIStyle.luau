--!strict
-- The look of every screen (leg 3, N2): the field guide and the tackle box. Colours, fonts,
-- text sizes, corners, strokes, paddings and the panel images all live here, so the whole
-- interface can be re-dressed by editing this one file (Liam: start here).
--
-- Pure data plus tiny helpers, no Roblox services: it loads in the Lune spec runner, which has
-- Color3 but not Font, UDim2 or Rect. So fonts and slice rects are kept as plain values and
-- turned into Roblox objects by the helpers at the bottom, which only the client calls.
--
-- Only used when Config.UI_STYLE_ON is true, except LOCKED and the scale rule, which the
-- tuned minigames read either way (so a restyle can never move them).
local UIStyle = {}

----------------------------------------------------------------------------------------
-- Colours. Anything you read sits on paper in ink. Brass for buttons, tags and the coin.

UIStyle.COLORS = {
	-- Paper and ink: cards, pages, toasts, the catch plate.
	paper = Color3.fromRGB(236, 226, 200),
	paperDeep = Color3.fromRGB(224, 210, 176), -- rows and cards on a page, a little older
	ink = Color3.fromRGB(38, 34, 30),
	inkSoft = Color3.fromRGB(84, 70, 56), -- second lines, hints (still 4.5 to 1 on paper)
	inkFaint = Color3.fromRGB(150, 135, 110), -- ruled lines and borders only, never text

	-- Inks for meaning (text on paper): good, warning, cool, money.
	greenInk = Color3.fromRGB(44, 98, 48),
	redInk = Color3.fromRGB(150, 40, 32),
	waterInk = Color3.fromRGB(30, 84, 128),
	brassInk = Color3.fromRGB(118, 80, 26),

	-- Brass: buttons (ink text), the coin, tags.
	brass = Color3.fromRGB(176, 136, 72),
	brassDark = Color3.fromRGB(120, 88, 40), -- brass edges and strokes
	brassLight = Color3.fromRGB(214, 178, 108), -- a pressed or lit brass button

	-- The tackle box: canvas body, leather straps and tabs.
	canvas = Color3.fromRGB(200, 184, 146),
	canvasDark = Color3.fromRGB(170, 152, 112),
	leather = Color3.fromRGB(92, 56, 34), -- paper-coloured text on it
	leatherDark = Color3.fromRGB(62, 38, 24),

	-- Wood: the fight bar and power meter frames (paper-coloured text on it).
	wood = Color3.fromRGB(96, 64, 40),
	woodDark = Color3.fromRGB(64, 42, 26),

	-- The fight track and its zone.
	water = Color3.fromRGB(58, 108, 138),
	sage = Color3.fromRGB(150, 178, 118), -- in the zone; also a "use this" button (ink text)
	clay = Color3.fromRGB(196, 110, 90), -- out of the zone (no text on it)
	fish = Color3.fromRGB(30, 32, 30), -- the fish silhouette on the track
}

-- The rarity colours, exactly as Shared/Rarity has them (the spec checks). They are bright, so
-- they are used for ribbons and stamp rings, never as text on paper.
UIStyle.RARITY = {
	Common = Color3.fromRGB(175, 180, 185),
	Uncommon = Color3.fromRGB(95, 200, 110),
	Rare = Color3.fromRGB(80, 150, 240),
	Epic = Color3.fromRGB(170, 95, 235),
	Legendary = Color3.fromRGB(250, 175, 40),
	Mythic = Color3.fromRGB(240, 75, 125),
	Godlike = Color3.fromRGB(255, 255, 255),
}

-- The same colours darkened (same hue) until they read as ink on paper: the stamp's text and
-- ring, and fish names in the journal. 4.5 to 1 or better on paper and paperDeep.
UIStyle.RARITY_INK = {
	Common = Color3.fromRGB(88, 90, 92),
	Uncommon = Color3.fromRGB(47, 100, 55),
	Rare = Color3.fromRGB(48, 90, 144),
	Epic = Color3.fromRGB(116, 65, 160),
	Legendary = Color3.fromRGB(118, 82, 19),
	Mythic = Color3.fromRGB(158, 50, 82),
	Godlike = Color3.fromRGB(89, 89, 89),
}

----------------------------------------------------------------------------------------
-- Type. Families are Roblox's own font library (rbxasset://fonts/families/<Name>.json).

UIStyle.FONTS = {
	title = { family = "Merriweather", weight = "Bold" }, -- names, panel titles, the catch
	body = { family = "Nunito", weight = "Regular" }, -- everything you read
	bodyBold = { family = "Nunito", weight = "Bold" }, -- buttons, numbers, labels
	hand = { family = "PatrickHand", weight = "Regular" }, -- notes, goals, tips, the chalkboard
}

-- Text sizes per role, in the interface's own units (before UIScale). On a small screen the
-- size grows so that nothing draws under PHONE_MIN_PX real pixels (textSize below).
UIStyle.TEXT = {
	hero = 30, -- "HOLD TO REEL", the bite
	title = 26, -- panel titles, the fish's name
	heading = 21, -- section headings, the coin count
	body = 18,
	small = 16, -- second lines, hints
	note = 20, -- handwriting runs small, so its base is a little bigger
	button = 18,
	tiny = 14, -- marks under a track (still lifted to 14 px on a phone)
}
UIStyle.PHONE_MIN_PX = 14
UIStyle.TOUCH_MIN_PX = 44

-- The interface scale: the same rule the screens have always used (1280 by 720 is 1.15).
-- The tuned minigames are sized in these units, so this rule must not change.
UIStyle.SCALE = { baseX = 1280, baseY = 720, factor = 1.15, min = 0.72, max = 1.25 }

----------------------------------------------------------------------------------------
-- Shapes: small square-ish corners (paper and brass, not pills), strokes, paddings.

UIStyle.RADIUS = { panel = 4, card = 3, button = 4, tag = 2, round = 999 }
UIStyle.STROKE = { panel = 2, card = 2, button = 2, plate = 3, rule = 1 }
UIStyle.PAD = { panel = 14, card = 10, button = 8, tight = 6 }

----------------------------------------------------------------------------------------
-- Panel images (art/ui/README.md has the files, sizes and notes; drawn 11/27/2026; ids from
-- art/ui/ids.json, uploaded 11/27/2026). Set an id to nil and that image's users fall back to the flat `fill` colour with a
-- UIStroke in `stroke`, so the restyle works before the art does.
-- file: the PNG in art/ui. size: its pixels. slice: the nine-slice centre { left, top, right,
-- bottom } in those pixels (nil: drawn whole). tint: the image is white and takes its colour
-- from ImageColor3. phoneSlice: the SliceScale the phone mockups use (desktop draws 1 / scale
-- of that times the interface scale, see Skin.surface).

export type ImageSpec = {
	id: string?,
	file: string,
	size: { number },
	slice: { number }?,
	tint: boolean?,
	phoneSlice: number?,
	textArea: { number }?, -- where text goes, { x0, y0, x1, y1 } in image pixels
	fill: string, -- a COLORS key
	stroke: string?, -- a COLORS key, or nil for none
}

UIStyle.IMAGES = {
	paper = { id = "rbxassetid://111952873635447", file = "paper_card.png", size = { 256, 256 }, slice = { 24, 24, 232, 232 }, phoneSlice = 0.4, fill = "paper", stroke = "inkFaint" },
	canvas = { id = "rbxassetid://100647632577482", file = "canvas_panel.png", size = { 256, 256 }, slice = { 72, 72, 184, 184 }, phoneSlice = 0.5, fill = "canvas", stroke = "leather" },
	leather = { id = "rbxassetid://82829022242054", file = "leather_panel.png", size = { 256, 256 }, slice = { 76, 76, 180, 180 }, phoneSlice = 0.3, fill = "leather", stroke = "leatherDark" },
	brassButton = { id = "rbxassetid://76498368525806", file = "brass_button.png", size = { 128, 64 }, slice = { 16, 16, 112, 44 }, phoneSlice = 0.7, fill = "brass", stroke = "brassDark" },
	-- Held down: swap the image and move the label down 4 px times SliceScale.
	brassButtonPressed = { id = "rbxassetid://74847028651282", file = "brass_button_pressed.png", size = { 128, 64 }, slice = { 16, 16, 112, 44 }, phoneSlice = 0.7, fill = "brassLight", stroke = "brassDark" },
	-- The side tabs: stretch sideways only (SliceScale = height / 96); text from x = 22 x SliceScale.
	tackleTab = { id = "rbxassetid://113006756128385", file = "tackle_tab.png", size = { 128, 96 }, slice = { 36, 0, 100, 96 }, fill = "canvas", stroke = "leather" },
	-- The fight bar's frame has a see-through window and lies over the track; no rotation.
	fightFrame = { id = "rbxassetid://134599207241882", file = "fight_frame.png", size = { 256, 64 }, slice = { 30, 26, 226, 36 }, phoneSlice = 0.7, fill = "wood", stroke = "brassDark" },
	waterTrack = { id = "rbxassetid://134261839209912", file = "water_track.png", size = { 256, 32 }, slice = { 10, 10, 246, 22 }, fill = "water", stroke = "woodDark" },
	-- The body of the fight bar around the track (no art drawn for it: flat wood).
	woodPanel = { id = nil, file = "", size = { 128, 256 }, slice = nil, fill = "wood", stroke = "brassDark" },
	fishMarker = { id = "rbxassetid://98969018068113", file = "fish_marker.png", size = { 64, 32 }, slice = nil, tint = true, fill = "fish", stroke = "paper" },
	-- A mark of colour, not readable: the rarity's name is always written beside it.
	raritySeal = { id = "rbxassetid://134835721672003", file = "rarity_seal.png", size = { 128, 128 }, slice = nil, tint = true, fill = "paper", stroke = "ink" },
	-- Ink text on it is 4.2 to 1 on Epic: bold, 19 px or more, or the name beside it.
	rarityRibbon = { id = "rbxassetid://138362753541854", file = "rarity_ribbon.png", size = { 128, 32 }, slice = { 28, 0, 100, 32 }, tint = true, fill = "paper", stroke = nil },
	weightTag = { id = "rbxassetid://111653429100454", file = "weight_tag.png", size = { 96, 128 }, slice = nil, textArea = { 21, 56, 75, 116 }, fill = "brass", stroke = "brassDark" },
	coin = { id = "rbxassetid://123661913060053", file = "icon_coin.png", size = { 64, 64 }, slice = nil, fill = "brass", stroke = "brassDark" },
	creel = { id = "rbxassetid://114872319828894", file = "icon_creel.png", size = { 64, 64 }, slice = nil, fill = "canvasDark", stroke = "leather" },
	dial = { id = "rbxassetid://73280041727054", file = "icon_dial.png", size = { 64, 64 }, slice = nil, fill = "paperDeep", stroke = "brassDark" },
	dialHand = { id = "rbxassetid://112560754686750", file = "icon_dial_hand.png", size = { 64, 64 }, slice = nil, fill = "brass", stroke = nil }, -- up is noon
	journal = { id = "rbxassetid://72617922683670", file = "icon_journal.png", size = { 64, 64 }, slice = nil, fill = "leather", stroke = nil },
	goals = { id = "rbxassetid://97549842099129", file = "icon_goals.png", size = { 64, 64 }, slice = nil, fill = "paper", stroke = nil },
	bait = { id = "rbxassetid://125159545207312", file = "icon_bait.png", size = { 64, 64 }, slice = nil, fill = "brass", stroke = nil },
	ruler = { id = "rbxassetid://131872386818289", file = "ruler_strip.png", size = { 256, 32 }, slice = nil, tint = true, fill = "ink", stroke = nil }, -- tiles every 256 px
	stitch = { id = "rbxassetid://126422119016991", file = "stitch_strip.png", size = { 64, 12 }, slice = nil, tint = true, fill = "paper", stroke = nil }, -- ScaleType Tile
} :: { [string]: ImageSpec }

-- The thread colour for stitch_strip.
UIStyle.THREAD = Color3.fromRGB(230, 214, 172)

----------------------------------------------------------------------------------------
-- Locked sizes and places of the tuned minigames (offsets in interface units). The screens
-- read these in both looks, and the spec pins them, so a restyle changes skins only. One
-- exception: in the new look the drag box keeps its place but grows to a full thumb's height.

UIStyle.LOCKED = {
	fight = {
		size = { 150, 320 },
		pos = { 0.5, -260, 0.5, -140 }, -- UDim2 x scale, x offset, y scale, y offset
		track = { 56, 236, 20, 46 }, -- width, height, x, y inside the bar
		progress = { 22, 236, 100, 46 },
		reelPrompt = { 360, 80, 0.5, 70, 0.5, -40 },
		dragBox = { 150, 58, 0.5, -100, 0.5, 60 },
	},
	power = { 300, 22, 0.5, -150, 1, -100 },
	bench = {
		size = { 600, 340 },
		pos = { 0.5, -100, 0, 56 },
		closeUp = { 320, 196, 16, 46 },
		track = { 320, 22, 16, 250 },
	},
	castRing = { radius = 2, inner = 1.3, beads = 10, beadSize = 0.4, label = { 190, 34 } },
}

----------------------------------------------------------------------------------------
-- Helpers.

-- The interface scale for a screen of vx by vy pixels.
function UIStyle.uiScale(vx: number, vy: number): number
	local s = UIStyle.SCALE
	return math.clamp(math.min(vx / s.baseX, vy / s.baseY) * s.factor, s.min, s.max)
end

-- The text size (interface units) for a role or a size, at this scale: never under
-- PHONE_MIN_PX real pixels.
function UIStyle.textSize(roleOrSize: string | number, scale: number): number
	local base = if type(roleOrSize) == "number" then roleOrSize else (UIStyle.TEXT[roleOrSize] or UIStyle.TEXT.body)
	return math.max(base, math.ceil(UIStyle.PHONE_MIN_PX / scale))
end

-- The smallest button side (interface units) that is TOUCH_MIN_PX real pixels at this scale.
function UIStyle.touchSize(scale: number): number
	return math.ceil(UIStyle.TOUCH_MIN_PX / scale)
end

-- WCAG contrast ratio of two colours (1 to 21).
local function lum(c: Color3): number
	local function ch(v: number): number
		return if v <= 0.04045 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * ch(c.R) + 0.7152 * ch(c.G) + 0.0722 * ch(c.B)
end
function UIStyle.contrast(a: Color3, b: Color3): number
	local la, lb = lum(a), lum(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

-- Of ink and paper, whichever reads better on this background.
function UIStyle.textOn(bg: Color3): Color3
	local c = UIStyle.COLORS
	return if UIStyle.contrast(c.ink, bg) >= UIStyle.contrast(c.paper, bg) then c.ink else c.paper
end

-- The ink for a tier at time t (Godlike shifts hue like Rarity.colorAt, but dark).
function UIStyle.rarityInk(tierId: string?, t: number): Color3
	if tierId == "Godlike" then
		return Color3.fromHSV((t / 2) % 1, 0.8, 0.38)
	end
	return UIStyle.RARITY_INK[tierId or "Common"] or UIStyle.RARITY_INK.Common
end

-- a over b at weight t (0 is all b, 1 is all a): what a tint at transparency 1 - t looks like.
function UIStyle.mix(a: Color3, b: Color3, t: number): Color3
	return Color3.new(a.R * t + b.R * (1 - t), a.G * t + b.G * (1 - t), a.B * t + b.B * (1 - t))
end

-- The rarity stamp on the catch card: a ring and the tier's name in its ink, over a light
-- tint of the exact colour (this is how much of the colour shows).
UIStyle.STAMP_TINT = 0.12

-- Roblox objects from the plain values above (client only: Font and Rect exist there).
function UIStyle.font(role: string): Font
	local f = UIStyle.FONTS[role] or UIStyle.FONTS.body
	return Font.new("rbxasset://fonts/families/" .. f.family .. ".json", (Enum.FontWeight :: any)[f.weight])
end

function UIStyle.sliceRect(name: string): Rect?
	local img = UIStyle.IMAGES[name]
	local s = img and img.slice
	if not s then
		return nil
	end
	return Rect.new(s[1], s[2], s[3], s[4])
end

return UIStyle
