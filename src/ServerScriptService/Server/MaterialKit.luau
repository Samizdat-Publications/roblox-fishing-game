--!strict
-- Our own materials (leg 3, the look kit). The source of truth for every MaterialVariant in
-- MaterialService, every base-material override and every terrain slot we remap. Run once in
-- Edit after a change (`MaterialKit.apply()`); it is idempotent and `MaterialKit.revert()` puts
-- the stock look back. The image ids are the uploads logged in art/textures/README.md.
--
-- Facts it rests on (docs/DECISIONS.md, 11/27/2026 night):
--  * A variant's ColorMap multiplies the part colour or the mesh's vertex colours, so prop
--    families use the NEUTRAL colour map and keep their hue from the part or the vertices.
--  * Terrain slots 2..22 are the stock materials and existing voxels point at them, so pointing
--    a stock slot at one of ours re-skins all of that material at once. Slots 23+ are free for
--    per-area ground.
--  * A base-material override re-skins every part AND every voxel of that material that has no
--    variant of its own (the home lawns are Grass parts, the hills are Grass terrain).
local MaterialService = game:GetService("MaterialService")

local MaterialKit = {}

export type Family = {
	name: string, -- the MaterialVariant's Name (what parts and slots refer to)
	base: Enum.Material,
	color: number?, -- image asset ids; nil until uploaded
	normal: number?,
	rough: number?,
	metal: number?,
	studs: number, -- StudsPerTile
	pattern: Enum.MaterialPattern?,
}

-- Uploaded 11/27/2026 (art/textures/ids.json and README.md have the same ids). Prop families use
-- the NEUTRAL colour map (hue from the part or the vertices); ground families use the palette
-- colour map with a white tint.
MaterialKit.FAMILIES = {
	{ name = "WeatheredPlank", base = Enum.Material.Wood, color = 80741058595109, normal = 105890202267685, rough = 117284029037170, studs = 8 },
	{ name = "Rope", base = Enum.Material.Fabric, color = 135935120374206, normal = 95650373015874, rough = 105660536950018, studs = 2 },
	{ name = "Canvas", base = Enum.Material.Fabric, color = 118947593138172, normal = 86505477991598, rough = 124626230291622, studs = 3 },
	{ name = "MeadowGrass", base = Enum.Material.Grass, color = 101241396464400, normal = 99613738695349, rough = 138017832448140, studs = 16, pattern = Enum.MaterialPattern.Organic },
	{ name = "WetSand", base = Enum.Material.Sand, color = 100073655363155, normal = 138574749553165, rough = 96601916018034, studs = 16, pattern = Enum.MaterialPattern.Organic },
	{ name = "ShoreStone", base = Enum.Material.Slate, color = 89874330433856, normal = 111500464538293, rough = 80673120127218, studs = 8, pattern = Enum.MaterialPattern.Organic },
	{ name = "ShoreStoneGround", base = Enum.Material.Rock, color = 77321670500551, normal = 111500464538293, rough = 80673120127218, studs = 12, pattern = Enum.MaterialPattern.Organic },
	{ name = "FishSkin", base = Enum.Material.SmoothPlastic, color = 71877620575284, normal = 81839350043697, rough = 86528045576678, studs = 1 },
	-- N1 (uploaded 11/27/2026): five ground families (palette colour maps) and five prop families
	-- (neutral maps). Aluminium's metalness map is not uploaded yet (N4, the boats).
	{ name = "ForestFloor", base = Enum.Material.LeafyGrass, color = 95357700780503, normal = 95747081334473, rough = 82504253799149, studs = 16, pattern = Enum.MaterialPattern.Organic },
	{ name = "LakeMud", base = Enum.Material.Mud, color = 99107177716357, normal = 98896444647625, rough = 108288187418156, studs = 20, pattern = Enum.MaterialPattern.Organic },
	{ name = "FootpathGravel", base = Enum.Material.Ground, color = 115571706147624, normal = 102838146211477, rough = 99044862705199, studs = 12, pattern = Enum.MaterialPattern.Organic },
	-- The mown lawns by the stands: the meadow maps on a LeafyGrass base, which grows no blades
	-- (terrain Grass grows knee-high blades that hide the stand counters at eye height).
	{ name = "MeadowLawn", base = Enum.Material.LeafyGrass, color = 101241396464400, normal = 99613738695349, rough = 138017832448140, studs = 16, pattern = Enum.MaterialPattern.Organic },
	{ name = "ShoreSand", base = Enum.Material.Sand, color = 89114552304847, normal = 86859007204320, rough = 132693441658407, studs = 16, pattern = Enum.MaterialPattern.Organic },
	{ name = "DeepBed", base = Enum.Material.Basalt, color = 110490221392736, normal = 75840132113757, rough = 135764485636397, studs = 24, pattern = Enum.MaterialPattern.Organic },
	{ name = "Bark", base = Enum.Material.Wood, color = 131285884539566, normal = 75468619984383, rough = 116447292242793, studs = 4 },
	{ name = "LeafNeedle", base = Enum.Material.LeafyGrass, color = 77632184387333, normal = 106977982508439, rough = 101588155137944, studs = 8 },
	{ name = "TinRoof", base = Enum.Material.CorrodedMetal, color = 130249019931486, normal = 114659436037341, rough = 96342230031415, studs = 4 },
	{ name = "TinRoofRust", base = Enum.Material.CorrodedMetal, color = 123504692013472, normal = 114659436037341, rough = 96342230031415, studs = 4 },
	{ name = "PaintedWood", base = Enum.Material.WoodPlanks, color = 125197895604357, normal = 138548088880298, rough = 114031226403634, studs = 5 },
	{ name = "Aluminium", base = Enum.Material.Metal, color = 116945538976167, normal = 140540589693552, rough = 130928792762580, studs = 4 },
	-- N3, Cedar Creek (not uploaded yet: apply skips them, and CreekDress gives slots 28 to 31 the
	-- plain base material with a palette tint until they are). Ground families: palette colour maps.
	{ name = "CreekPebble", base = Enum.Material.Ground, color = 115838492914633, normal = 90324050686422, rough = 92628018119192, studs = 16, pattern = Enum.MaterialPattern.Organic },
	{ name = "WetSlate", base = Enum.Material.Slate, color = 97920981489099, normal = 131130650754049, rough = 136570282484131, studs = 12, pattern = Enum.MaterialPattern.Organic },
	{ name = "Moss", base = Enum.Material.LeafyGrass, color = 95460022034606, normal = 71904788721067, rough = 79579793871789, studs = 8, pattern = Enum.MaterialPattern.Organic },
	-- Props: moss on boulders and logs (neutral map) and cedar bark for the creek cedars (N3).
	{ name = "MossProp", base = Enum.Material.Grass, color = 89093689228043, normal = 71904788721067, rough = 79579793871789, studs = 5 },
	{ name = "CedarBark", base = Enum.Material.WoodPlanks, color = 71939342860443, normal = 136380260146967, rough = 115271845618414, studs = 4 },
} :: { Family }

-- The wet band: the slot the waterline sand is repainted with (MaterialKit.paintWetBand).
MaterialKit.WET_SLOT = 23

-- Part rules for MaterialKit.dress: a part matches a rule when its full name (without
-- "Workspace.") starts with `path` (and, if set, its Material is `from`). The part gets `material`,
-- `variant` and, if set, `color`. The part's old look is kept in attributes so `undress` restores it.
export type Rule = { path: string, from: Enum.Material?, material: Enum.Material, variant: string, color: Color3? }

-- N0, the proof corner: the dock area, both stands and the bank east of the dock.
MaterialKit.CORNER = {
	{ path = "Lake.GroundSouth", material = Enum.Material.Grass, variant = "MeadowGrass", color = Color3.new(1, 1, 1) },
	{ path = "Lake.BoatSlips.", material = Enum.Material.Wood, variant = "WeatheredPlank", color = Color3.fromRGB(150, 132, 112) },
	{ path = "Lake.Lamps.Post", material = Enum.Material.Wood, variant = "WeatheredPlank", color = Color3.fromRGB(120, 104, 88) },
	{ path = "Lake.Scenery.PondStones.", material = Enum.Material.Slate, variant = "ShoreStone" },
} :: { Rule }

local function nameOf(p: Instance): string
	return (p:GetFullName():gsub("^Workspace%.", ""))
end

-- Applies rules to every BasePart under `root`. Returns how many parts changed.
function MaterialKit.dress(root: Instance, rules: { Rule }): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local full = nameOf(d)
			for _, r in rules do
				if full:sub(1, #r.path) == r.path and (r.from == nil or d.Material == r.from) and MaterialService:FindFirstChild(r.variant) then
					if d:GetAttribute("KitOrigMaterial") == nil then
						d:SetAttribute("KitOrigMaterial", d.Material.Name)
						d:SetAttribute("KitOrigVariant", d.MaterialVariant)
						d:SetAttribute("KitOrigColor", d.Color)
					end
					d.Material = r.material
					d.MaterialVariant = r.variant
					if r.color then
						d.Color = r.color
					end
					n += 1
					break
				end
			end
		end
	end
	return n
end

-- N1, the whole home lake: the same rules spread from the corner, plus the paths (gravel on the
-- old sand strips until the paths are re-laid as wandering terrain) and the shore lamp posts.
MaterialKit.HOME_LAKE = {
	{ path = "Lake.BoatSlips.", material = Enum.Material.Wood, variant = "WeatheredPlank", color = Color3.fromRGB(150, 132, 112) },
	{ path = "Lake.Lamps.Post", material = Enum.Material.Wood, variant = "WeatheredPlank", color = Color3.fromRGB(120, 104, 88) },
	{ path = "Lake.Scenery.PondStones.", material = Enum.Material.Slate, variant = "ShoreStone" },
	{ path = "Lake.Path", from = Enum.Material.Sand, material = Enum.Material.Ground, variant = "FootpathGravel", color = Color3.new(1, 1, 1) },
	{ path = "Lake.CedarCreek.PathToCreek", material = Enum.Material.Ground, variant = "FootpathGravel", color = Color3.new(1, 1, 1) },
	{ path = "Lake.CedarCreek.BankPath", material = Enum.Material.Ground, variant = "FootpathGravel", color = Color3.new(1, 1, 1) },
} :: { Rule }

-- Layer B on the source models in ServerStorage.Art (WorldBuilder.dress copies them into the
-- world): model name -> variant. Single-family models only; mixed ones (pines with their
-- canopies, the leafy tree) are replaced by the split bank kit instead.
MaterialKit.ART_VARIANTS = {
	Log1 = "Bark",
	Log2 = "Bark",
	Log3 = "Bark",
	RockSmall = "ShoreStone",
	RockMedium = "ShoreStone",
	RockLarge = "ShoreStone",
	PondRim = "ShoreStone",
	Reeds = "LeafNeedle",
	LilyPads = "LeafNeedle",
} :: { [string]: string }

function MaterialKit.skinArt(): number
	local art = game:GetService("ServerStorage"):FindFirstChild("Art")
	if not art then
		return 0
	end
	local n = 0
	for name, variant in MaterialKit.ART_VARIANTS do
		local m = art:FindFirstChild(name)
		local f = MaterialKit.byName(variant)
		if m and f and MaterialService:FindFirstChild(variant) then
			for _, d in m:GetDescendants() do
				if d:IsA("MeshPart") then
					d.Material = f.base
					d.MaterialVariant = variant
					n += 1
				end
			end
		end
	end
	return n
end

-- The copies already standing in the world (N1 round 2): skinArt only reaches the sources in
-- ServerStorage.Art, so copies placed before it ran (Lake.Art from WorldBuilder.dress, the
-- Scenery shore's reeds, rocks and lily pads) kept the stock look. Every model under `root` named
-- in ART_VARIANTS gets its variant on each MeshPart; the old look is kept in the KitOrig
-- attributes, so MaterialKit.undress(root) restores it. Returns how many parts changed.
function MaterialKit.skinPlaced(root: Instance): number
	local n = 0
	for _, m in root:GetDescendants() do
		local variant = if m:IsA("Model") then MaterialKit.ART_VARIANTS[m.Name] else nil
		local f = variant and MaterialKit.byName(variant)
		if variant and f and MaterialService:FindFirstChild(variant) then
			for _, d in m:GetDescendants() do
				if d:IsA("MeshPart") and d.MaterialVariant ~= variant then
					if d:GetAttribute("KitOrigMaterial") == nil then
						d:SetAttribute("KitOrigMaterial", d.Material.Name)
						d:SetAttribute("KitOrigVariant", d.MaterialVariant)
						d:SetAttribute("KitOrigColor", d.Color)
					end
					d.Material = f.base
					d.MaterialVariant = variant
					n += 1
				end
			end
		end
	end
	return n
end

-- The lawns (N1): inside the boxes of the old Ground* lawn parts (WaterLook.lawnsToTerrain made
-- them terrain), meadow voxels (slot 2) become the bladeless lawn slot. Returns cells changed.
MaterialKit.LAWN_SLOT = 26

function MaterialKit.paintLawns(lake: Instance): number
	local t = workspace.Terrain
	local n = 0
	for _, p in lake:GetChildren() do
		if p:IsA("BasePart") and string.match(p.Name, "^Ground") then
			local half = p.Size / 2
			local lo = p.Position - Vector3.new(half.X, 0, half.Z)
			local hi = p.Position + Vector3.new(half.X, 0, half.Z)
			local region = Region3.new(Vector3.new(lo.X, -12, lo.Z), Vector3.new(hi.X, 8, hi.Z)):ExpandToGrid(4)
			local ch = t:ReadVoxelChannels(region, 4, { "SolidMaterialIndex" })
			local idx = ch.SolidMaterialIndex
			local size = ch.Size
			local changed = 0
			for x = 1, size.X do
				for y = 1, size.Y do
					for z = 1, size.Z do
						if idx[x][y][z] == 2 then
							idx[x][y][z] = MaterialKit.LAWN_SLOT
							changed += 1
						end
					end
				end
			end
			if changed > 0 then
				t:WriteVoxelChannels(region, 4, { SolidMaterialIndex = idx })
				n += changed
			end
		end
	end
	return n
end

-- Fish skin (N0 tries it on two; N1 does all 26): the fish models in ServerStorage.Art keep their
-- vertex colours and get the FishSkin variant (neutral scales, low roughness, a wet sheen).
MaterialKit.FISH_SKINNED = { "Bluegill", "LargemouthBass" }

-- Every species with a model (N1): the fish ids in FishData and BigLakeFishData.
function MaterialKit.allFish(): { string }
	local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local out = {}
	for _, modName in { "FishData", "BigLakeFishData" } do
		local mod = shared:FindFirstChild(modName)
		local ok, data = pcall(require, mod)
		if ok and type(data) == "table" then
			local list = data.LIST or data.list or data.FISH or data
			for k, v in list do
				local id = if type(v) == "table" and v.id then v.id elseif type(k) == "string" then k else nil
				if type(id) == "string" then
					table.insert(out, id)
				end
			end
		end
	end
	return out
end

function MaterialKit.skinFish(names: { string }?): number
	local art = game:GetService("ServerStorage"):FindFirstChild("Art")
	if not art or not MaterialService:FindFirstChild("FishSkin") then
		return 0
	end
	local n = 0
	for _, name in names or MaterialKit.FISH_SKINNED do
		local m = art:FindFirstChild(name)
		if m then
			for _, d in m:GetDescendants() do
				if d:IsA("MeshPart") then
					d.Material = Enum.Material.SmoothPlastic
					d.MaterialVariant = "FishSkin"
					n += 1
				end
			end
		end
	end
	return n
end

function MaterialKit.undress(root: Instance): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("KitOrigMaterial") ~= nil then
			d.Material = (Enum.Material :: any)[d:GetAttribute("KitOrigMaterial")]
			d.MaterialVariant = d:GetAttribute("KitOrigVariant") or ""
			d.Color = d:GetAttribute("KitOrigColor") or d.Color
			d:SetAttribute("KitOrigMaterial", nil)
			d:SetAttribute("KitOrigVariant", nil)
			d:SetAttribute("KitOrigColor", nil)
			n += 1
		end
	end
	return n
end

-- Repaints terrain sand that sits at the waterline with the wet-sand slot, inside the box lo..hi
-- (y is ignored), for water whose surface is at y = `waterY` (0). Two modes:
--  * band only (the N0 proof corner): cells whose centre is within `band` studs (2.5) of the surface;
--  * with `below` (N1, the whole lake): every cell that reaches from `below` studs under the
--    surface to `band` studs over it, so the submerged sand shelf and the strip just above the
--    waterline are both wet sand.
-- Returns how many voxels changed.
function MaterialKit.paintWetBand(lo: Vector3, hi: Vector3, waterY: number?, band: number?, below: number?): number
	local t = workspace.Terrain
	local wy, b = waterY or 0, band or 2.5
	local down = math.max(below or 0, 8)
	local region = Region3.new(Vector3.new(lo.X, wy - down - 4, lo.Z), Vector3.new(hi.X, wy + math.max(b, 4) + 4, hi.Z)):ExpandToGrid(4)
	local ch = t:ReadVoxelChannels(region, 4, { "SolidMaterialIndex", "SolidOccupancy" })
	local size = ch.Size
	local idx = ch.SolidMaterialIndex
	local y0 = region.CFrame.Position.Y - region.Size.Y / 2
	local n = 0
	for x = 1, size.X do
		for y = 1, size.Y do
			local cellLo = y0 + (y - 1) * 4
			local wet = if below then MaterialKit.wetCell(cellLo, wy, b, below) else math.abs(cellLo + 2 - wy) <= b
			if wet then
				for z = 1, size.Z do
					if idx[x][y][z] == 6 and ch.SolidOccupancy[x][y][z] > 0 then
						idx[x][y][z] = MaterialKit.WET_SLOT
						n += 1
					end
				end
			end
		end
	end
	if n > 0 then
		t:WriteVoxelChannels(region, 4, { SolidMaterialIndex = idx })
	end
	return n
end

-- True when a 4 stud cell starting at `cellLo` reaches into the wet band: from `below` studs under
-- the surface `wy` to `band` studs over it.
function MaterialKit.wetCell(cellLo: number, wy: number, band: number, below: number): boolean
	return cellLo < wy + band and cellLo + 4 > wy - below
end

-- The home lake's wet band (N1): its water box (Shore's x -110..110, z -80..80) plus a voxel past
-- the drawn waterline, which wanders up to 1.8 studs outside it (ShoreEdge.OUT_MAX). Band 6 under
-- the water, 1.5 over it. Run after WaterLook.lawnsToTerrain and again after any WaterLook.apply.
MaterialKit.HOME_LAKE_LO = Vector3.new(-124, 0, -94)
MaterialKit.HOME_LAKE_HI = Vector3.new(124, 0, 94)
MaterialKit.WET_BELOW = 6
MaterialKit.WET_ABOVE = 1.5

function MaterialKit.wetBandHomeLake(): number
	return MaterialKit.paintWetBand(MaterialKit.HOME_LAKE_LO, MaterialKit.HOME_LAKE_HI, 0, MaterialKit.WET_ABOVE, MaterialKit.WET_BELOW)
end

-- Stock material -> our variant, for every part and voxel of it with no variant of its own.
MaterialKit.OVERRIDES = {} :: { [Enum.Material]: string }

-- Terrain slot remaps: { slot, base, variant (or ""), tint }. Slot 2 is the stock Grass slot, so
-- this re-skins all terrain grass (the hills and meadows past the lawns).
MaterialKit.SLOTS = {
	{ slot = 2, base = Enum.Material.Grass, variant = "MeadowGrass", tint = Color3.new(1, 1, 1) },
	{ slot = 23, base = Enum.Material.Sand, variant = "WetSand", tint = Color3.new(1, 1, 1) },
	-- N1: dry sand above the water is ours (the wet band and the shelf are slot 23), and the
	-- stock mud of the lake beds is our lake mud.
	{ slot = 6, base = Enum.Material.Sand, variant = "ShoreSand", tint = Color3.new(1, 1, 1) },
	{ slot = 12, base = Enum.Material.Mud, variant = "LakeMud", tint = Color3.new(1, 1, 1) },
	-- N1 round 4 (the advisor, review 2): every stock Ground voxel shows our gravel and every stock
	-- LeafyGrass voxel our bladeless lawn (MaterialKit.revert puts the stock tints back).
	{ slot = 14, base = Enum.Material.Ground, variant = "FootpathGravel", tint = Color3.new(1, 1, 1) },
	{ slot = 19, base = Enum.Material.LeafyGrass, variant = "MeadowLawn", tint = Color3.new(1, 1, 1) },
	-- N1 dress pass (BankDress paints these by slot index): the wandering footpaths and the
	-- forest floor under the treeline.
	{ slot = 24, base = Enum.Material.Ground, variant = "FootpathGravel", tint = Color3.new(1, 1, 1) },
	{ slot = 25, base = Enum.Material.LeafyGrass, variant = "ForestFloor", tint = Color3.new(1, 1, 1) },
	{ slot = 26, base = Enum.Material.LeafyGrass, variant = "MeadowLawn", tint = Color3.new(1, 1, 1) },
	-- N1 round 2: the forest floor on the hills where the far pines stand, palette 62,84,52 (the
	-- advisor's call). The ForestFloor colour map is brown (92,72,48) and a tint can only darken
	-- it, and forest_floor has no neutral map uploaded, so this slot uses the LeafNeedle variant
	-- (its colour map is the neutral grey, mean 0.80) tinted 78,105,65: 0.80 of that is 62,84,52.
	-- LeafyGrass grows no blades. BankDress.HILL_SLOT paints it.
	{ slot = 27, base = Enum.Material.LeafyGrass, variant = "LeafNeedle", tint = Color3.fromRGB(78, 105, 65) },
	-- N3, Cedar Creek (CreekPlan.SLOT; CreekDress paints them by slot index): the gravel bars and
	-- the riffle's cobbles, the bed seen through the clear water (the same pebble map, darker),
	-- wet slate on the rocky run's banks, moss on the bank tops (LeafyGrass: no blades).
	{ slot = 28, base = Enum.Material.Ground, variant = "CreekPebble", tint = Color3.fromRGB(156, 148, 130) }, -- N3 review 2 (was white): the dry bars, duller
	{ slot = 29, base = Enum.Material.Ground, variant = "CreekPebble", tint = Color3.fromRGB(118, 112, 96) }, -- N3 review 1 (was 170,160,140): the wet bed, darker
	{ slot = 30, base = Enum.Material.Slate, variant = "WetSlate", tint = Color3.new(1, 1, 1) },
	{ slot = 31, base = Enum.Material.LeafyGrass, variant = "Moss", tint = Color3.fromRGB(200, 210, 195) }, -- Neon Pass 1 (11/28/2026, was white): deeper woodland shade
	-- N3 review 2 (11/28/2026): the creek's paths on their own slot (CreekPlan.PATH_SLOT), the
	-- path gravel tinted warmer and darker than the lake's; the old path parts take the same colour.
	-- N3 review 3 (final, 11/28/2026): 120,110,92 (was 150,140,120); the lit path read too pale.
	{ slot = 32, base = Enum.Material.Ground, variant = "FootpathGravel", tint = Color3.fromRGB(120, 110, 92) },
} :: { { slot: number, base: Enum.Material, variant: string, tint: Color3 } }

local function asset(id: number?): string
	return if id then "rbxassetid://" .. tostring(id) else ""
end

function MaterialKit.byName(name: string): Family?
	for _, f in MaterialKit.FAMILIES do
		if f.name == name then
			return f
		end
	end
	return nil
end

-- A family is ready once its colour map is uploaded.
function MaterialKit.ready(name: string): boolean
	local f = MaterialKit.byName(name)
	return f ~= nil and f.color ~= nil
end

-- Creates or updates the variants, then the overrides and slots. Returns counts for the log.
function MaterialKit.apply(): { variants: number, overrides: number, slots: number }
	local made = 0
	for _, f in MaterialKit.FAMILIES do
		if f.color then
			local v = MaterialService:FindFirstChild(f.name)
			if not (v and v:IsA("MaterialVariant")) then
				v = Instance.new("MaterialVariant")
				v.Name = f.name
			end
			local mv = v :: MaterialVariant
			mv.BaseMaterial = f.base
			mv.ColorMap = asset(f.color)
			mv.NormalMap = asset(f.normal)
			mv.RoughnessMap = asset(f.rough)
			mv.MetalnessMap = asset(f.metal)
			mv.StudsPerTile = f.studs
			mv.MaterialPattern = f.pattern or Enum.MaterialPattern.Regular
			mv:SetAttribute("Kit", true)
			mv.Parent = MaterialService
			made += 1
		end
	end
	local over = 0
	for material, name in MaterialKit.OVERRIDES do
		if MaterialService:FindFirstChild(name) then
			MaterialService:SetBaseMaterialOverride(material, name)
			over += 1
		end
	end
	local slots = 0
	for _, s in MaterialKit.SLOTS do
		if s.variant == "" or MaterialService:FindFirstChild(s.variant) then
			workspace.Terrain:SetMaterialSlot(s.slot, s.base, s.variant, s.tint)
			slots += 1
		end
	end
	return { variants = made, overrides = over, slots = slots }
end

-- Back to the stock look: clears our overrides, resets remapped stock slots to their stock
-- material with no variant and the tint the place had (read from Studio on 11/27/2026, place
-- version 111), and removes our variants.
MaterialKit.STOCK_TINTS = {
	[2] = Color3.fromRGB(106, 127, 63), -- Grass
	[3] = Color3.fromRGB(96, 92, 80), -- Slate
	[6] = Color3.fromRGB(198, 182, 134), -- Sand
	[8] = Color3.fromRGB(118, 114, 104), -- Rock
	[11] = Color3.fromRGB(148, 124, 95), -- Sandstone
	[12] = Color3.fromRGB(96, 88, 66), -- Mud
	[13] = Color3.fromRGB(34, 44, 58), -- Basalt
	[14] = Color3.fromRGB(44, 46, 40), -- Ground
	[17] = Color3.fromRGB(134, 134, 118), -- Cobblestone
	[19] = Color3.fromRGB(106, 134, 64), -- LeafyGrass
	[21] = Color3.fromRGB(140, 126, 100), -- Limestone
} :: { [number]: Color3 }

function MaterialKit.revert()
	for material in MaterialKit.OVERRIDES do
		MaterialService:SetBaseMaterialOverride(material, "")
	end
	for _, s in MaterialKit.SLOTS do
		if s.slot <= 22 then
			workspace.Terrain:SetMaterialSlot(s.slot, s.base, "", MaterialKit.STOCK_TINTS[s.slot] or s.tint)
		else
			workspace.Terrain:ResetMaterialSlot(s.slot)
		end
	end
	for _, v in MaterialService:GetChildren() do
		if v:IsA("MaterialVariant") and v:GetAttribute("Kit") then
			v:Destroy()
		end
	end
end

return MaterialKit
