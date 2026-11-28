--!strict
-- Cedar Creek's stock tells, swapped cheaply now (leg 3, N1, Gemini's review 1.3); N3 dresses the
-- creek properly. Run in Edit after WorldBuilder.dress, Scenery.apply and BankDress.apply (it
-- leaves alone any tree BankDress already swapped); safe to run again (it reverts first).
--
--   require(game.ServerScriptService.Server.CreekSwap).apply(workspace.Lake)
--   require(game.ServerScriptService.Server.CreekSwap).revert(workspace.Lake)
--
-- (a) The pole-and-ball lamps (CedarCreek.GateLamp on GateLampPost, Scenery.PoolLantern's Bulb
--     on its Post, and any other glass or neon ball with a light on a thin post in the creek
--     area) become lantern posts like the shore lamps: a WeatheredPlank post with a short arm and
--     a small glass lantern box (255, 190, 120). The ball's existing PointLight, tagged
--     "Lantern", moves into the box (ClientModules/Lanterns lights its parent glass), and an
--     ObjectValue in the box remembers where it came from. The old ball and post are hidden.
-- (b) The cone pines (Lake.Art PineTall and PineShort, the copies over the creek's gray-box
--     trunks, and any other visible PineTall or PineShort in Scatter.CREEK_BOX) are hidden and
--     replaced at the same base and about the same height: ShorePine1 or ShorePine2 (its lite
--     copy when ServerStorage.Art has one) within 25 studs of the creek's water, FarPine1 or
--     FarPine2 past that (Scatter.creekPine).
--
-- Everything new is in Lake.CreekSwap: anchored, no collision, no queries, no touches (the old
-- art copies had none; the old lamp posts keep theirs, only hidden). What it changes outside its
-- folder is recorded on the instance (CreekSwapOrigTransparency) and put back by revert.
local ServerStorage = game:GetService("ServerStorage")
local MaterialService = game:GetService("MaterialService")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Scatter = require(Shared:WaitForChild("Scatter"))

local CreekSwap = {}

CreekSwap.FOLDER = "CreekSwap"
CreekSwap.SEED = 20261127
CreekSwap.HIDDEN_ATTR = "CreekSwapOrigTransparency"
local BANKDRESS_ATTR = "BankDressOrigTransparency" -- a tree BankDress swapped: not ours
local LIGHT_FROM = "LightFrom" -- ObjectValue in a new lantern's glass: the ball its light came from

CreekSwap.LANTERN_COLOR = Color3.fromRGB(255, 190, 120)
CreekSwap.POST_COLOR = Color3.fromRGB(120, 104, 88) -- the shore lamp posts' (MaterialKit)
CreekSwap.METAL_COLOR = Color3.fromRGB(46, 42, 38)

-- The named lamps: the ball, its post, and which way the arm reaches (x, z).
CreekSwap.LAMPS = {
	{ ball = "CedarCreek.GateLamp", post = "CedarCreek.GateLampPost", arm = { 0, 1 } }, -- toward the gate path
	{ ball = "Scenery.PoolLantern.Bulb", post = "Scenery.PoolLantern.Post", arm = { -1, 0 } }, -- out over the pool's bank
}

local VARIANT_BY_SUFFIX = {
	bark = { variant = "Bark", base = Enum.Material.Wood },
	leaf = { variant = "LeafNeedle", base = Enum.Material.LeafyGrass },
}

local function find(root: Instance, path: string): Instance?
	local node: Instance? = root
	for _, step in string.split(path, ".") do
		node = node and node:FindFirstChild(step)
	end
	return node
end

local function inBox(p: Vector3): boolean
	local b = Scatter.CREEK_BOX
	return p.X >= b.x1 and p.X <= b.x2 and p.Z >= b.z1 and p.Z <= b.z2
end

local function hidePart(p: BasePart)
	if p:GetAttribute(CreekSwap.HIDDEN_ATTR) == nil then
		p:SetAttribute(CreekSwap.HIDDEN_ATTR, p.Transparency)
	end
	p.Transparency = 1
end

local function visible(m: Instance): boolean
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			if d:GetAttribute(BANKDRESS_ATTR) ~= nil then
				return false
			end
			if d.Transparency < 1 then
				return true
			end
		end
	end
	return false
end

local function artModel(name: string): Model?
	local art = ServerStorage:FindFirstChild("Art")
	local m = art and art:FindFirstChild(name)
	return if m and m:IsA("Model") then m else nil
end

-- The kit model for `name`: its `_lite` copy when there is one. Second result: true for lite.
local function template(name: string): (Model?, boolean)
	local lite = artModel(name .. "_lite")
	if lite then
		return lite, true
	end
	return artModel(name), false
end

local function newPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A lantern post standing at `base` (the old post's foot), `h` studs tall, the arm reaching
-- along (ax, az). Returns the model and its glass box.
local function buildLantern(parent: Instance, base: Vector3, h: number, ax: number, az: number): (Model, Part)
	local m = Instance.new("Model")
	m.Name = "CreekLantern"
	local yaw = math.atan2(-az, ax) -- turns +X onto (ax, az)
	local at = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	local post = newPart(m, "Post", Vector3.new(0.6, h, 0.6), at * CFrame.new(0, h / 2, 0), CreekSwap.POST_COLOR, Enum.Material.Wood)
	if MaterialService:FindFirstChild("WeatheredPlank") then
		post.MaterialVariant = "WeatheredPlank"
	end
	local arm = newPart(m, "Arm", Vector3.new(1.5, 0.3, 0.3), at * CFrame.new(0.6, h - 0.4, 0), CreekSwap.POST_COLOR, Enum.Material.Wood)
	arm.MaterialVariant = post.MaterialVariant
	newPart(m, "Hook", Vector3.new(0.12, 0.35, 0.12), at * CFrame.new(1.15, h - 0.72, 0), CreekSwap.METAL_COLOR, Enum.Material.Metal)
	newPart(m, "Cap", Vector3.new(0.85, 0.18, 0.85), at * CFrame.new(1.15, h - 0.98, 0), CreekSwap.METAL_COLOR, Enum.Material.Metal)
	local glass = newPart(m, "Glass", Vector3.new(0.65, 0.85, 0.65), at * CFrame.new(1.15, h - 1.5, 0), CreekSwap.LANTERN_COLOR, Enum.Material.Glass)
	glass.CastShadow = false
	newPart(m, "Base", Vector3.new(0.8, 0.14, 0.8), at * CFrame.new(1.15, h - 1.99, 0), CreekSwap.METAL_COLOR, Enum.Material.Metal)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d ~= glass then
			d.CastShadow = false -- thin parts; the lantern light only, like the shore lamps
		end
	end
	m.Parent = parent
	return m, glass
end

-- The creek's pole-and-ball lamps: the named ones, then any glass or neon ball with a light
-- whose thin upright post stands under it in the creek area. Each { ball, post, arm }.
type Lamp = { ball: BasePart, post: BasePart?, arm: { number } }
local function findLamps(lake: Instance): { Lamp }
	local out: { Lamp } = {}
	local seen: { [Instance]: boolean } = {}
	for _, l in CreekSwap.LAMPS do
		local ball = find(lake, l.ball)
		local post = find(lake, l.post)
		if ball and ball:IsA("BasePart") then
			table.insert(out, { ball = ball, post = if post and post:IsA("BasePart") then post else nil, arm = l.arm })
			seen[ball] = true
		end
	end
	local posts: { BasePart } = {}
	local balls: { BasePart } = {}
	for _, d in lake:GetDescendants() do
		if d:IsA("BasePart") and inBox(d.Position) then
			if d:IsA("Part") and d.Shape == Enum.PartType.Ball and (d.Material == Enum.Material.Glass or d.Material == Enum.Material.Neon) and d:FindFirstChildWhichIsA("Light") then
				table.insert(balls, d)
			elseif d.Size.X <= 0.8 and d.Size.Z <= 0.8 and d.Size.Y >= 5 then
				table.insert(posts, d)
			end
		end
	end
	for _, b in balls do
		if not seen[b] then
			local best: BasePart? = nil
			for _, p in posts do
				local dx, dz = p.Position.X - b.Position.X, p.Position.Z - b.Position.Z
				local top = p.Position.Y + p.Size.Y / 2
				if dx * dx + dz * dz <= 1 and math.abs(top - b.Position.Y) <= 1.5 then
					best = p
				end
			end
			if best then
				table.insert(out, { ball = b, post = best, arm = { 1, 0 } })
				seen[b] = true
			end
		end
	end
	return out
end

-- The cone pines to swap: Lake.Art's PineTall and PineShort copies (the creek's trunks), and any
-- other visible copy of those in the creek area (Scenery's creek head and stands), skipping any
-- BankDress already swapped.
local function findPines(lake: Instance): { Model }
	local out: { Model } = {}
	local seen: { [Instance]: boolean } = {}
	local art = lake:FindFirstChild("Art")
	if art then
		for _, d in art:GetChildren() do
			if d:IsA("Model") and (d.Name == "PineTall" or d.Name == "PineShort") and visible(d) then
				table.insert(out, d)
				seen[d] = true
			end
		end
	end
	local scenery = lake:FindFirstChild("Scenery")
	if scenery then
		for _, d in scenery:GetDescendants() do
			if d:IsA("Model") and (d.Name == "PineTall" or d.Name == "PineShort") and not seen[d] and inBox(d:GetPivot().Position) and visible(d) then
				table.insert(out, d)
				seen[d] = true
			end
		end
	end
	return out
end

export type Result = {
	lamps: number, -- pole-and-ball lamps turned into lantern posts
	lightsMoved: number, -- their PointLights moved into the new glass
	pines: number, -- cone pines replaced
	shorePines: number,
	farPines: number,
	pinesMissing: number, -- left standing: the replacement is not in ServerStorage.Art
	lite: number, -- replacements placed from a `_lite` model
	hidden: number, -- parts hidden (recorded for revert)
}

export type RevertResult = { unhidden: number, lightsBack: number }

-- Takes the swap off: lights back into their balls, the folder gone, every part it hid shown.
function CreekSwap.revert(lake: Instance): RevertResult
	local lightsBack = 0
	local folder = lake:FindFirstChild(CreekSwap.FOLDER)
	if folder then
		for _, v in folder:GetDescendants() do
			if v:IsA("ObjectValue") and v.Name == LIGHT_FROM then
				local home = v.Value
				local glass = v.Parent
				if home and glass then
					for _, l in glass:GetChildren() do
						if l:IsA("Light") then
							l.Parent = home
							lightsBack += 1
						end
					end
				end
			end
		end
		folder:Destroy()
	end
	local unhidden = 0
	for _, d in lake:GetDescendants() do
		if d:IsA("BasePart") then
			local t = d:GetAttribute(CreekSwap.HIDDEN_ATTR)
			if type(t) == "number" then
				d.Transparency = t
				d:SetAttribute(CreekSwap.HIDDEN_ATTR, nil)
				unhidden += 1
			end
		end
	end
	return { unhidden = unhidden, lightsBack = lightsBack }
end

-- Swaps the lamps and the pines (reverting first when the swap is already on).
function CreekSwap.apply(lake: Instance): Result
	if lake:FindFirstChild(CreekSwap.FOLDER) then
		CreekSwap.revert(lake)
	end
	local folder = Instance.new("Folder")
	folder.Name = CreekSwap.FOLDER
	folder.Parent = lake
	local lampsFolder = Instance.new("Folder")
	lampsFolder.Name = "Lanterns"
	lampsFolder.Parent = folder
	local pinesFolder = Instance.new("Folder")
	pinesFolder.Name = "Pines"
	pinesFolder.Parent = folder
	local res: Result = { lamps = 0, lightsMoved = 0, pines = 0, shorePines = 0, farPines = 0, pinesMissing = 0, lite = 0, hidden = 0 }

	-- (a) The lamps.
	for _, l in findLamps(lake) do
		local ball, post = l.ball, l.post
		local base: Vector3
		local h: number
		if post then
			base = post.Position - Vector3.new(0, post.Size.Y / 2, 0)
			h = post.Size.Y + 0.6
		else
			base = ball.Position - Vector3.new(0, 8.4, 0)
			h = 8.6
		end
		local _, glass = buildLantern(lampsFolder, base, h, l.arm[1], l.arm[2])
		local from = Instance.new("ObjectValue")
		from.Name = LIGHT_FROM
		from.Value = ball
		from.Parent = glass
		for _, light in ball:GetChildren() do
			if light:IsA("Light") then
				light.Parent = glass
				res.lightsMoved += 1
				if not CollectionService:HasTag(light, "Lantern") then
					CollectionService:AddTag(light, "Lantern")
				end
			end
		end
		hidePart(ball)
		res.hidden += 1
		if post then
			hidePart(post)
			res.hidden += 1
		end
		res.lamps += 1
	end

	-- (b) The pines.
	local rng = Scatter.rng(CreekSwap.SEED)
	local alt: { [string]: number } = {}
	for _, old in findPines(lake) do
		local cf, size = old:GetBoundingBox()
		local base = Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z)
		local name = Scatter.creekPine(base.X, base.Z, Scatter.next(rng))
		local tpl, isLite = template(name)
		if not tpl then
			res.pinesMissing += 1
			continue
		end
		local th = tpl:GetExtentsSize().Y
		local scale = if th > 0 then math.clamp(size.Y / th, 0.5, 3) else 1
		local bury = (Scatter.KIT[name] or 1) * scale
		local m = tpl:Clone()
		m.Name = name
		m:ScaleTo(scale)
		m:PivotTo(CFrame.new(base.X, base.Y - bury, base.Z) * CFrame.Angles(0, Scatter.range(rng, 0, 2 * math.pi), 0))
		local far = Scatter.isFar(name)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = not far
				if d.MaterialVariant == "" then
					local suffix = string.match(d.Name, "_(%a+)$")
					local v = suffix and VARIANT_BY_SUFFIX[string.lower(suffix)]
					if v and MaterialService:FindFirstChild(v.variant) then
						d.Material = v.base
						d.MaterialVariant = v.variant
					end
				end
			end
		end
		CollectionService:AddTag(m, "FoliageTree")
		local key = if far then "far" else "kit"
		alt[key] = (alt[key] or 0) + 1
		m:SetAttribute("FoliageAlt", alt[key] % 2)
		if far then
			m:SetAttribute("FoliageFar", true)
		end
		m.Parent = pinesFolder
		for _, d in old:GetDescendants() do
			if d:IsA("BasePart") then
				hidePart(d)
				res.hidden += 1
			end
		end
		res.pines += 1
		if far then
			res.farPines += 1
		else
			res.shorePines += 1
		end
		if isLite then
			res.lite += 1
		end
	end
	return res
end

return CreekSwap
