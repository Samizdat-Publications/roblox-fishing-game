--!strict
-- The land round the lake (L5b). The critic's top fix after L5a: the map read as "a flat
-- square swimming pool floating in an empty void". Run once in Edit; it is saved in the place;
-- safe to run again (it rebuilds its parts and refills the same terrain).
--
--   require(game.ServerScriptService.Server.Scenery).apply(workspace.Lake)
--
-- What it adds:
--   * terrain grass out to the horizon round the playable world, rolling hills past it, a few
--     rock outcrops;
--   * stands of pines and leafy trees on that land (copies of the Art models);
--   * reeds, rocks and lily pads along the lake's straight banks so the edge reads as shore;
--   * a rocky hillside at the head of Cedar Creek, where the riffle used to run into the sky;
--   * a lantern at the creek pool, which was black at night;
--   * invisible walls at the old world edge (players used to fall off it; now there is land
--     out there to look at, not to wander into), and along the creek fence line past its ends.
-- Everything but the walls and the lantern post is decoration: no collision, no queries, no
-- touches. No fishing rule reads any of it. With the Big Lake switched on (BoatRules.BIG_LAKE)
-- its ground stays flat, open grass for its water; with it off the land there is dressed too.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoatRules = require(Shared:WaitForChild("BoatRules"))
local Config = require(Shared:WaitForChild("Config"))
local WaterMap = require(Shared:WaitForChild("WaterMap"))
local Shore = require(Shared:WaitForChild("Shore"))

local Scenery = {}

local FOLDER = "Scenery"
local SEED = 20261127

type Rect = { x1: number, x2: number, z1: number, z2: number }
type Hill = { c: Vector3, r: number }

-- The playable world (its parts), the ground's top, and how far the land runs past it.
Scenery.WORLD = { x1 = -300, x2 = 160, z1 = -140, z2 = 140 } :: Rect
Scenery.GROUND_TOP = 1
Scenery.FAR = 560
-- Inside the world rectangle but with no ground under it (north and south of the creek banks).
local GAPS: { Rect } = {
	{ x1 = -300, x2 = -160, z1 = 80, z2 = 140 },
	{ x1 = -300, x2 = -160, z1 = -140, z2 = -80 },
}
local GRASS = Color3.fromRGB(106, 127, 63) -- the ground parts' colour, so terrain and parts match
local ROCK = Color3.fromRGB(118, 114, 104)

Scenery.HILLS = 70
Scenery.OUTCROPS = 14
Scenery.CLUSTERS = 44
Scenery.POND_R = 8 -- the round home pond's radius (it was a 22 x 14 box)
local HILL_CLEAR = 18 -- studs between the world edge and where a hill starts to rise
local SHADOW_RANGE = 160 -- trees farther than this from the world cast no shadow (cheaper)

local function rectDist(r: Rect, x: number, z: number): number
	local dx = math.max(r.x1 - x, 0, x - r.x2)
	local dz = math.max(r.z1 - z, 0, z - r.z2)
	return math.sqrt(dx * dx + dz * dz)
end

local function inRect(r: Rect, x: number, z: number, pad: number): boolean
	return x >= r.x1 - pad and x <= r.x2 + pad and z >= r.z1 - pad and z <= r.z2 + pad
end

local function bigLake(): Rect
	local b = BoatRules.BIG_LAKE
	local c, s = b.cframe.Position, b.size
	return { x1 = c.X - s.X / 2, x2 = c.X + s.X / 2, z1 = c.Z - s.Z / 2, z2 = c.Z + s.Z / 2 }
end

-- Grass from 8 studs down up to the ground's top over a rectangle.
local function flat(t: Terrain, r: Rect)
	local top, bottom = Scenery.GROUND_TOP, -8
	t:FillBlock(
		CFrame.new((r.x1 + r.x2) / 2, (top + bottom) / 2, (r.z1 + r.z2) / 2),
		Vector3.new(r.x2 - r.x1, top - bottom, r.z2 - r.z1),
		Enum.Material.Grass
	)
end

-- Ground height at (x, z): the flat land, or the highest hill over it.
local function heightAt(hills: { Hill }, x: number, z: number): number
	local h = Scenery.GROUND_TOP
	for _, hill in hills do
		local dx, dz = x - hill.c.X, z - hill.c.Z
		local d2 = dx * dx + dz * dz
		if d2 < hill.r * hill.r then
			h = math.max(h, hill.c.Y + math.sqrt(hill.r * hill.r - d2))
		end
	end
	return h
end

local function art(lake: Model, name: string): Model?
	local folder = lake:FindFirstChild("Art")
	local m = folder and folder:FindFirstChild(name)
	return if m and m:IsA("Model") then m else nil
end

-- A copy of an Art model, scaled, turned, its base (pivot) at `base`. Decoration only.
local function place(template: Model, parent: Instance, base: Vector3, scale: number, yaw: number, shadow: boolean): Model
	local m = template:Clone()
	m:ScaleTo(scale)
	m:PivotTo(CFrame.new(base) * CFrame.Angles(0, yaw, 0))
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = shadow
		end
	end
	m.Parent = parent
	return m
end

-- Moves a placed model up or down so its lowest point sits at `bottom`.
local function seatBottom(m: Model, bottom: number)
	local cf, size = m:GetBoundingBox()
	local low = cf.Position.Y - size.Y / 2
	m:PivotTo(m:GetPivot() + Vector3.new(0, bottom - low, 0))
end

local function wall(parent: Instance, name: string, x1: number, x2: number, z1: number, z2: number)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.CastShadow = false
	p.Size = Vector3.new(math.max(x2 - x1, 1), 80, math.max(z2 - z1, 1))
	p.CFrame = CFrame.new((x1 + x2) / 2, 38, (z1 + z2) / 2)
	p.Parent = parent
end

local function lampPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, collide: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = collide
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

export type Result = { hills: number, trees: number, shore: number, walls: number }

function Scenery.apply(lake: Model): Result
	local rng = Random.new(SEED)
	local t = workspace.Terrain
	t:SetMaterialColor(Enum.Material.Grass, GRASS)
	t:SetMaterialColor(Enum.Material.Rock, ROCK)

	local old = lake:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER

	local W, FAR = Scenery.WORLD, Scenery.FAR
	-- With the Big Lake on, its ground stays flat and empty for its water. With it off (now),
	-- the land north of the lake is the dock's main view, so it gets hills and trees too; turning
	-- the Big Lake on later means Scenery.revert, then apply again (docs/DECISIONS.md, L5b).
	local reserve = bigLake()
	local function reserved(x: number, z: number, pad: number): boolean
		return Config.BIG_LAKE_ON and inRect(reserve, x, z, pad)
	end

	-- 1. Flat land round the world (four strips) and in the two gaps beside the creek.
	flat(t, { x1 = W.x1 - FAR, x2 = W.x2 + FAR, z1 = W.z1 - FAR, z2 = W.z1 })
	flat(t, { x1 = W.x1 - FAR, x2 = W.x2 + FAR, z1 = W.z2, z2 = W.z2 + FAR })
	flat(t, { x1 = W.x1 - FAR, x2 = W.x1, z1 = W.z1, z2 = W.z2 })
	flat(t, { x1 = W.x2, x2 = W.x2 + FAR, z1 = W.z1, z2 = W.z2 })
	for _, g in GAPS do
		flat(t, g)
	end

	-- 2. Rolling hills, lower near the world and taller toward the horizon.
	local hills: { Hill } = {}
	local tries = 0
	while #hills < Scenery.HILLS and tries < 4000 do
		tries += 1
		local x = rng:NextNumber(W.x1 - FAR + 40, W.x2 + FAR - 40)
		local z = rng:NextNumber(W.z1 - FAR + 40, W.z2 + FAR - 40)
		local d = rectDist(W, x, z)
		if d > 30 and not reserved(x, z, 30) then
			local far = math.clamp((d - 30) / 380, 0, 1)
			local r = rng:NextNumber(40, 70 + 60 * far)
			local h = rng:NextNumber(5 + 10 * far, 12 + 34 * far)
			h = math.min(h, r * 0.6)
			local capR = math.sqrt(2 * r * h - h * h) -- radius where the hill meets the flat
			if d - capR >= HILL_CLEAR and not (Config.BIG_LAKE_ON and rectDist(reserve, x, z) < capR * 0.6) then
				local c = Vector3.new(x, Scenery.GROUND_TOP + h - r, z)
				t:FillBall(c, r, Enum.Material.Grass)
				table.insert(hills, { c = c, r = r })
			end
		end
	end
	-- A few rock outcrops on the hilltops.
	for i = 1, math.min(Scenery.OUTCROPS, #hills) do
		local hill = hills[rng:NextInteger(1, #hills)]
		local top = hill.c + Vector3.new(0, hill.r, 0)
		t:FillBall(top + Vector3.new(rng:NextNumber(-6, 6), -2, rng:NextNumber(-6, 6)), rng:NextNumber(5, 11), Enum.Material.Rock)
	end

	-- 3. Stands of trees: clusters on the land, denser near the world.
	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = folder
	local kinds = { "PineTall", "PineTall", "PineShort", "LeafyTree", "LeafyTree", "PineShort", "PineTall" }
	local treeCount = 0
	local clusters = 0
	tries = 0
	while clusters < Scenery.CLUSTERS and tries < 2000 do
		tries += 1
		local x = rng:NextNumber(W.x1 - 360, W.x2 + 360)
		local z = rng:NextNumber(W.z1 - 360, W.z2 + 360)
		local d = rectDist(W, x, z)
		-- Keep most clusters close in: accept a far one only sometimes.
		if d >= 10 and not reserved(x, z, 12) and rng:NextNumber() < math.clamp(1.2 - d / 340, 0.15, 1) then
			clusters += 1
			-- Tight clumps (11/27/2026; was 3 to 8 trees over 8 to 22 studs, which the critic read
			-- as single trees dotted about).
			local n = rng:NextInteger(4, 9)
			local spread = rng:NextNumber(5, 12)
			for _ = 1, n do
				local tx = x + rng:NextNumber(-spread, spread)
				local tz = z + rng:NextNumber(-spread, spread)
				local td = rectDist(W, tx, tz)
				if td >= 6 and not reserved(tx, tz, 6) then
					local template = art(lake, kinds[rng:NextInteger(1, #kinds)])
					if template then
						local y = heightAt(hills, tx, tz) - 0.4
						place(template, trees, Vector3.new(tx, y, tz), rng:NextNumber(0.9, 1.7), rng:NextNumber(0, 2 * math.pi), td < SHADOW_RANGE)
						treeCount += 1
					end
				end
			end
		end
	end

	-- 4. The lake shore: reeds, rocks and lily pads along the four straight banks.
	local shore = Instance.new("Folder")
	shore.Name = "Shore"
	shore.Parent = folder
	local size = WaterMap.WATER_SIZE
	local hx, hz = size.X / 2, size.Z / 2
	local reeds, lily = art(lake, "Reeds"), art(lake, "LilyPads")
	local rocks = { art(lake, "RockSmall"), art(lake, "RockMedium"), art(lake, "RockSmall") }
	-- Each bank: a point on it from s (-1..1 along), and the direction into the water.
	local banks = {
		{ name = "south", len = size.X, at = function(s: number, inward: number) return Vector3.new(s * hx, 0, hz - inward) end },
		{ name = "north", len = size.X, at = function(s: number, inward: number) return Vector3.new(s * hx, 0, -hz + inward) end },
		{ name = "east", len = size.Z, at = function(s: number, inward: number) return Vector3.new(hx - inward, 0, s * hz) end },
		{ name = "west", len = size.Z, at = function(s: number, inward: number) return Vector3.new(-hx + inward, 0, s * hz) end },
	}
	local shoreCount = 0
	for _, bank in banks do
		local along = -bank.len / 2 + rng:NextNumber(2, 8)
		while along < bank.len / 2 - 2 do
			local s = along / (bank.len / 2)
			local probe = bank.at(s, 0)
			local skip = bank.name == "south" and math.abs(probe.X) < 14 -- the dock
			if not skip then
				-- Where the water really starts here: past a rounded corner or a point of land
				-- (Shore, L5d) that's further in than the straight bank line.
				local base = 0
				while base < 40 do
					local q = bank.at(s, base + 1)
					if Shore.depth(q.X, q.Z) <= 0 then
						break
					end
					base += 1
				end
				local roll = rng:NextNumber()
				local bush = art(lake, "LeafyTree")
				if roll >= 0.62 and roll < 0.74 and bush then
					-- A low bush on the bank's lip (a leafy tree at a third the size), L5c: the
					-- critic read the even row of reed clumps as artificial.
					local p = bank.at(s, base + rng:NextNumber(-1.4, -0.6)) -- the lip before the path (or the point's edge)
					place(bush, shore, Vector3.new(p.X, Scenery.GROUND_TOP - 0.3, p.Z), rng:NextNumber(0.28, 0.42), rng:NextNumber(0, 2 * math.pi), true)
					shoreCount += 1
				elseif roll < 0.35 and reeds then
					for _ = 1, rng:NextInteger(1, 3) do
						local p = bank.at(s + rng:NextNumber(-0.02, 0.02), base + rng:NextNumber(0.5, 3.5))
						place(reeds, shore, Vector3.new(p.X, -1.2, p.Z), rng:NextNumber(0.7, 1.2), rng:NextNumber(0, 2 * math.pi), false)
						shoreCount += 1
					end
					if lily and rng:NextNumber() < 0.35 then
						local p = bank.at(s, base + rng:NextNumber(4, 9))
						place(lily, shore, Vector3.new(p.X, -0.3, p.Z), rng:NextNumber(0.8, 1.3), rng:NextNumber(0, 2 * math.pi), false)
						shoreCount += 1
					end
				elseif roll < 0.62 then
					local template = rocks[rng:NextInteger(1, #rocks)]
					if template then
						-- Kept small and just off the bank: bigger ones filled the view of anyone fishing there.
						local p = bank.at(s, base + rng:NextNumber(0.5, 2.5))
						local m = place(template, shore, Vector3.new(p.X, 0, p.Z), rng:NextNumber(1.0, 1.8), rng:NextNumber(0, 2 * math.pi), true)
						seatBottom(m, -1.6)
						shoreCount += 1
					end
				end
			end
			along += rng:NextNumber(7, 15)
		end
	end

	-- 4a. A tree on each point of land (L5d), back from the nose so it shades the bank without
	-- standing in anyone's cast.
	local pointTree = art(lake, "LeafyTree")
	if pointTree then
		for _, pt in Shore.POINTS do
			local dx, dz = -pt.x, -pt.z
			local len = math.sqrt(dx * dx + dz * dz)
			local at = Vector3.new(pt.x + dx / len * pt.r * 0.25, Scenery.GROUND_TOP - 0.3, pt.z + dz / len * pt.r * 0.25)
			place(pointTree, shore, at, rng:NextNumber(0.6, 0.85), rng:NextNumber(0, 2 * math.pi), true)
			shoreCount += 1
		end
	end

	-- 4b. Bushes and small trees on the ground ring past the lake path (L5c), so the far bank
	-- reads as planted shore, not a lawn. Clear of the stands, the spawn, the pond and the paths.
	local planting = Instance.new("Folder")
	planting.Name = "BankPlanting"
	planting.Parent = shore
	local leafy, pine = art(lake, "LeafyTree"), art(lake, "PineShort")
	local KEEP_CLEAR: { Rect } = {
		{ x1 = -36, x2 = 76, z1 = 84, z2 = 140 }, -- stands, spawn, home pond
		{ x1 = -24, x2 = 24, z1 = -140, z2 = -84 }, -- the north path's middle (the boat channel later)
		{ x1 = -160, x2 = -110, z1 = -24, z2 = 24 }, -- the walk to the creek gate
		{ x1 = 110, x2 = 145, z1 = 25, z2 = 85 }, -- the east bank facing the fallen logs (a favourite place to stand)
	}
	local function clear(x: number, z: number): boolean
		for _, r in KEEP_CLEAR do
			if inRect(r, x, z, 0) then
				return false
			end
		end
		return true
	end
	for _ = 1, 70 do
		-- A point on the ground ring: 10 to 26 studs outside the water's edge.
		local side = rng:NextInteger(1, 4)
		local out = rng:NextNumber(10, 26)
		local x, z
		if side == 1 then
			x, z = rng:NextNumber(-hx - 30, hx + 30), hz + out
		elseif side == 2 then
			x, z = rng:NextNumber(-hx - 30, hx + 30), -hz - out
		elseif side == 3 then
			x, z = hx + out, rng:NextNumber(-hz, hz)
		else
			x, z = -hx - out, rng:NextNumber(-hz, hz)
		end
		if clear(x, z) and inRect(W, x, z, -4) then
			local template = if rng:NextNumber() < 0.65 then leafy else pine
			if template then
				local scale = if template == leafy then rng:NextNumber(0.35, 0.75) else rng:NextNumber(0.5, 0.9)
				place(template, planting, Vector3.new(x, Scenery.GROUND_TOP - 0.3, z), scale, rng:NextNumber(0, 2 * math.pi), true)
				shoreCount += 1
			end
		end
	end

	-- 4c. Clouds (L5c): the noon sky was flat blue. Weather can change Cover later.
	local clouds = t:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.5
	clouds.Density = 0.5
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = t

	-- 4d. The creek fence (L5c): the solid plank walls stay as invisible walls, with a weathered
	-- split-rail fence drawn in front of them and a timber arch over the gate.
	local fence = Instance.new("Folder")
	fence.Name = "CreekFence"
	fence.Parent = folder
	local creek = lake:FindFirstChild("CedarCreek")
	local RAIL = Color3.fromRGB(122, 98, 72)
	for _, name in { "FenceNorth", "FenceSouth" } do
		local wallPart = creek and creek:FindFirstChild(name)
		if wallPart and wallPart:IsA("BasePart") then
			if wallPart:GetAttribute("OrigTransparency") == nil then
				wallPart:SetAttribute("OrigTransparency", wallPart.Transparency)
			end
			wallPart.Transparency = 1
			local x = wallPart.Position.X
			local z1 = wallPart.Position.Z - wallPart.Size.Z / 2
			local z2 = wallPart.Position.Z + wallPart.Size.Z / 2
			local posts = math.floor((z2 - z1) / 6)
			local step = (z2 - z1) / posts
			for i = 0, posts do
				local z = z1 + i * step
				local lean = rng:NextNumber(-0.04, 0.04)
				lampPart(fence, "Post", Vector3.new(0.6, 5, 0.6), CFrame.new(x, Scenery.GROUND_TOP + 2.3, z) * CFrame.Angles(lean, 0, lean), RAIL, Enum.Material.Wood, false)
				if i < posts then
					for _, h in { 1.6, 3.4 } do
						local sag = rng:NextNumber(-0.12, 0.12)
						lampPart(fence, "Rail", Vector3.new(0.3, 0.35, step + 0.4), CFrame.new(x, Scenery.GROUND_TOP + h + sag, z + step / 2), RAIL, Enum.Material.Wood, false)
					end
				end
			end
		end
	end
	local gate = creek and creek:FindFirstChild("CreekGate")
	if gate and gate:IsA("BasePart") then
		local g = gate.Position
		local half = gate.Size.Z / 2 + 0.6
		for _, dz in { -half, half } do
			lampPart(fence, "ArchPost", Vector3.new(0.9, 10, 0.9), CFrame.new(g.X, Scenery.GROUND_TOP + 5, g.Z + dz), RAIL, Enum.Material.Wood, false)
		end
		lampPart(fence, "ArchBeam", Vector3.new(0.9, 0.9, half * 2 + 2), CFrame.new(g.X, Scenery.GROUND_TOP + 10.2, g.Z), RAIL, Enum.Material.Wood, false)
	end
	-- The gray-box sign post stood just in front of the arch's post as a stubby block (critic,
	-- 11/27/2026). It still carries the "Cedar Creek" sign and the gate prompt, so it stays,
	-- unseen; the arch is the post now.
	local gatePost = creek and creek:FindFirstChild("GatePost")
	if gatePost and gatePost:IsA("BasePart") then
		if gatePost:GetAttribute("OrigTransparency") == nil then
			gatePost:SetAttribute("OrigTransparency", gatePost.Transparency)
		end
		gatePost.Transparency = 1
	end

	-- 4e. The lake path follows the rounded corners (L5d): the four straight paths stop where
	-- the shore starts to curve, and a quarter-circle bend joins them at each corner (radius 35
	-- round the same centre as the shore's corner, so it meets both straight paths exactly).
	local bends = Instance.new("Folder")
	bends.Name = "PathBends"
	bends.Parent = folder
	local L = Shore.LAKE
	local cr = Shore.CORNER_R
	local cx, cz = L.x2 - cr, L.z2 - cr -- 80, 50: the corner circles' centres, mirrored
	local function trim(name: string, long: number)
		local p = lake:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			if p:GetAttribute("OrigSize") == nil then
				p:SetAttribute("OrigSize", p.Size)
			end
			local orig = p:GetAttribute("OrigSize") :: Vector3
			p.Size = if orig.X > orig.Z then Vector3.new(long, orig.Y, orig.Z) else Vector3.new(orig.X, orig.Y, long)
			return p
		end
		return nil
	end
	local north = trim("PathNorth", cx * 2)
	trim("PathSouth", cx * 2)
	trim("PathEast", cz * 2)
	trim("PathWest", cz * 2)
	if north then
		local y, width, thick = north.Position.Y, north.Size.Z, north.Size.Y
		local radius = math.abs(north.Position.Z) - cz -- 85 - 50 = 35
		local steps = 12
		for _, c in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
			local sx, sz = c[1], c[2]
			local centre = Vector3.new(cx * sx, y, cz * sz)
			local function at(t: number): Vector3
				return centre + Vector3.new(sx * math.sin(t), 0, sz * math.cos(t)) * radius
			end
			for i = 1, steps do
				local a, b = at((i - 1) / steps * math.pi / 2), at(i / steps * math.pi / 2)
				local seg = Instance.new("Part")
				seg.Name = "Bend"
				seg.Anchored = true
				seg.CanCollide = true
				seg.Material = north.Material
				seg.Color = north.Color
				seg.TopSurface = Enum.SurfaceType.Smooth
				seg.BottomSurface = Enum.SurfaceType.Smooth
				seg.Size = Vector3.new(width, thick, (b - a).Magnitude + 0.8)
				seg.CFrame = CFrame.lookAt((a + b) / 2, b)
				seg.Parent = bends
			end
		end
	end

	-- 5. The head of Cedar Creek: the riffle now comes out from under a rocky bank and a hill.
	local head = Instance.new("Folder")
	head.Name = "CreekHead"
	head.Parent = folder
	local riffle = WaterMap.CREEK[1]
	local cx, top = (riffle.x1 + riffle.x2) / 2, riffle.z2
	t:FillBlock(CFrame.new(cx, -3.5, top + 5), Vector3.new(riffle.x2 - riffle.x1 + 4, 9, 8), Enum.Material.Rock)
	t:FillBall(Vector3.new(cx, -7, top + 22), 17, Enum.Material.Rock)
	t:FillBall(Vector3.new(cx - 4, -28, top + 52), 44, Enum.Material.Grass)
	table.insert(hills, { c = Vector3.new(cx - 4, -28, top + 52), r = 44 })
	table.insert(hills, { c = Vector3.new(cx, -7, top + 22), r = 17 })
	local big = art(lake, "RockLarge")
	if big then
		for i, off in { Vector3.new(-7, 0, 2), Vector3.new(6, 0, 3), Vector3.new(-1, 0, 6), Vector3.new(9, 0, 8) } do
			local m = place(big, head, Vector3.new(cx + off.X, 0, top + off.Z), 1.3 + i * 0.2, rng:NextNumber(0, 2 * math.pi), true)
			seatBottom(m, -1.5)
		end
	end
	for _, off in { Vector3.new(-12, 0, 24), Vector3.new(10, 0, 30), Vector3.new(-2, 0, 40) } do
		local template = art(lake, "PineTall")
		if template then
			local x, z = cx + off.X, top + off.Z
			place(template, head, Vector3.new(x, heightAt(hills, x, z) - 0.4, z), rng:NextNumber(1.2, 1.6), rng:NextNumber(0, 2 * math.pi), true)
		end
	end

	-- 6. A lantern on the bank by the creek pool.
	local lantern = Instance.new("Model")
	lantern.Name = "PoolLantern"
	local pool = WaterMap.CREEK[3]
	local lx, lz = pool.x2 + 3, (pool.z1 + pool.z2) / 2 - 12
	lampPart(lantern, "Post", Vector3.new(0.5, 8, 0.5), CFrame.new(lx, Scenery.GROUND_TOP + 4, lz), Color3.fromRGB(70, 50, 35), Enum.Material.Wood, true)
	local bulb = lampPart(lantern, "Bulb", Vector3.new(1.2, 1.2, 1.2), CFrame.new(lx, Scenery.GROUND_TOP + 8.4, lz), Color3.fromRGB(255, 230, 170), Enum.Material.Neon, false)
	bulb.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Range = 20
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 198, 138)
	light.Shadows = false
	light.Parent = bulb
	lantern.Parent = folder

	-- 7. Walls at the old world edge, and along the creek fence line past its ends.
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = folder
	local north = W.z1 - 1
	if Config.BIG_LAKE_ON then
		-- Leave the boat channel open (BoatRules.CHANNEL, x -15..15).
		wall(walls, "NorthWest", W.x1, -16, north - 0.5, north + 0.5)
		wall(walls, "NorthEast", 16, W.x2, north - 0.5, north + 0.5)
	else
		wall(walls, "North", W.x1, W.x2, north - 0.5, north + 0.5)
	end
	wall(walls, "South", W.x1, W.x2, W.z2 + 0.5, W.z2 + 1.5)
	wall(walls, "West", W.x1 - 1.5, W.x1 - 0.5, W.z1, W.z2)
	wall(walls, "East", W.x2 + 0.5, W.x2 + 1.5, W.z1, W.z2)
	wall(walls, "CreekFenceNorth", -162.5, -161.5, W.z1, -80)
	wall(walls, "CreekFenceSouth", -162.5, -161.5, 80, W.z2)

	-- 8. A round home pond (11/27/2026). The critic read the 22 x 14 box with its square stone rim
	-- as "a flat grey rectangle". Its water and bottom parts become discs on the same centre (the
	-- water a shade of the lake's own colour), a ring of rocks edges them, and the box rim model
	-- hides. PondView keeps the fish inside the water's PondRadius. Revert puts the box back.
	local pond = lake:FindFirstChild("HomePond")
	local water = pond and pond:FindFirstChild("Water")
	local bottom = pond and pond:FindFirstChild("Bottom")
	if water and water:IsA("BasePart") and bottom and bottom:IsA("BasePart") then
		local R = Scenery.POND_R
		local top = Scenery.GROUND_TOP
		for _, p in { water, bottom } do
			if p:GetAttribute("OrigSize") == nil then
				p:SetAttribute("OrigSize", p.Size)
				p:SetAttribute("OrigCFrame", p.CFrame)
				p:SetAttribute("OrigColor", p.Color)
				p:SetAttribute("OrigTransparency", p.Transparency)
				p:SetAttribute("OrigMaterial", p.Material.Name)
				p:SetAttribute("OrigReflectance", p.Reflectance)
			end
		end
		local c = (water:GetAttribute("OrigCFrame") :: CFrame).Position
		local upright = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis is its X; stand it up
		-- Water from inside the ground to 0.4 above it (the stones hide its edge); the mud bottom
		-- sits at the ground's top. Plastic, not glass: glass mirrored the sky bright blue.
		water.Shape = Enum.PartType.Cylinder
		water.Size = Vector3.new(0.7, R * 2, R * 2)
		water.CFrame = CFrame.new(c.X, top + 0.05, c.Z) * upright
		water.Material = Enum.Material.SmoothPlastic
		water.Reflectance = 0.2
		water.Color = Color3.fromRGB(34, 82, 76)
		water.Transparency = 0.25
		water:SetAttribute("PondRadius", R - 1)
		water:SetAttribute("PondFishY", top + 0.05)
		bottom.Shape = Enum.PartType.Cylinder
		bottom.Size = Vector3.new(0.2, R * 2, R * 2)
		bottom.CFrame = CFrame.new(c.X, top + 0.05, c.Z) * upright
		local rim = art(lake, "PondRim")
		if rim then
			for _, d in rim:GetDescendants() do
				if d:IsA("BasePart") then
					if d:GetAttribute("OrigTransparency") == nil then
						d:SetAttribute("OrigTransparency", d.Transparency)
					end
					d.Transparency = 1
					d.CanCollide = false
				end
			end
		end
		local stones = Instance.new("Folder")
		stones.Name = "PondStones"
		stones.Parent = folder
		local small, medium = art(lake, "RockSmall"), art(lake, "RockMedium")
		local n = 24
		for i = 1, n do
			local a = (i + rng:NextNumber(-0.3, 0.3)) / n * 2 * math.pi
			local big = i % 4 == 0 and medium ~= nil
			local template = if big then medium else small
			if template then
				local r = R + rng:NextNumber(0.2, 0.8) + (if big then 0.8 else 0)
				local scale = if big then rng:NextNumber(0.4, 0.55) else rng:NextNumber(0.9, 1.4)
				local m = place(template, stones, Vector3.new(c.X + math.cos(a) * r, top, c.Z + math.sin(a) * r), scale, rng:NextNumber(0, 2 * math.pi), true)
				seatBottom(m, top - 0.3)
			end
		end
	end

	folder.Parent = lake
	return { hills = #hills, trees = treeCount, shore = shoreCount, walls = #walls:GetChildren() }
end

-- Removes the parts and clears the terrain land back to air (the lake and creek water, and the
-- lake bed from WaterLook, are inside the world rectangle and stay).
function Scenery.revert(lake: Model)
	local old = lake:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	for _, name in { "PathNorth", "PathSouth", "PathEast", "PathWest" } do
		local p = lake:FindFirstChild(name)
		local size = p and p:GetAttribute("OrigSize")
		if p and p:IsA("BasePart") and typeof(size) == "Vector3" then
			p.Size = size
			p:SetAttribute("OrigSize", nil)
		end
	end
	-- The home pond back to its box (section 8).
	local pond = lake:FindFirstChild("HomePond")
	for _, name in { "Water", "Bottom" } do
		local p = pond and pond:FindFirstChild(name)
		local size = p and p:GetAttribute("OrigSize")
		if p and p:IsA("BasePart") and typeof(size) == "Vector3" then
			p.Shape = Enum.PartType.Block
			p.Size = size
			p.CFrame = p:GetAttribute("OrigCFrame") :: CFrame
			p.Color = p:GetAttribute("OrigColor") :: Color3
			p.Transparency = p:GetAttribute("OrigTransparency") :: number
			local material = p:GetAttribute("OrigMaterial")
			if type(material) == "string" then
				p.Material = (Enum.Material :: any)[material]
			end
			p.Reflectance = (p:GetAttribute("OrigReflectance") :: number?) or 0
			for _, k in { "OrigSize", "OrigCFrame", "OrigColor", "OrigTransparency", "OrigMaterial", "OrigReflectance", "PondRadius", "PondFishY" } do
				p:SetAttribute(k, nil)
			end
		end
	end
	local artFolder = lake:FindFirstChild("Art")
	local rim = artFolder and artFolder:FindFirstChild("PondRim")
	for _, d in (if rim then rim:GetDescendants() else {}) do
		local was = d:GetAttribute("OrigTransparency")
		if d:IsA("BasePart") and type(was) == "number" then
			d.Transparency = was
			d.CanCollide = true
			d:SetAttribute("OrigTransparency", nil)
		end
	end
	local creek = lake:FindFirstChild("CedarCreek")
	for _, name in { "FenceNorth", "FenceSouth", "GatePost" } do
		local p = creek and creek:FindFirstChild(name)
		local was = p and p:GetAttribute("OrigTransparency")
		if p and p:IsA("BasePart") and type(was) == "number" then
			p.Transparency = was
			p:SetAttribute("OrigTransparency", nil)
		end
	end
	local t = workspace.Terrain
	local clouds = t:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds:Destroy()
	end
	local W, FAR = Scenery.WORLD, Scenery.FAR
	local function clear(r: Rect)
		t:FillBlock(CFrame.new((r.x1 + r.x2) / 2, 40, (r.z1 + r.z2) / 2), Vector3.new(r.x2 - r.x1, 200, r.z2 - r.z1), Enum.Material.Air)
	end
	clear({ x1 = W.x1 - FAR, x2 = W.x2 + FAR, z1 = W.z1 - FAR, z2 = W.z1 })
	clear({ x1 = W.x1 - FAR, x2 = W.x2 + FAR, z1 = W.z2, z2 = W.z2 + FAR })
	clear({ x1 = W.x1 - FAR, x2 = W.x1, z1 = W.z1, z2 = W.z2 })
	clear({ x1 = W.x2, x2 = W.x2 + FAR, z1 = W.z1, z2 = W.z2 })
	for _, g in GAPS do
		clear(g)
	end
end

return Scenery
