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
	{ name = "WetSand", base = Enum.Material.Sand, color = 135696601239441, normal = 138574749553165, rough = 96601916018034, studs = 16, pattern = Enum.MaterialPattern.Organic },
	{ name = "ShoreStone", base = Enum.Material.Slate, color = 89874330433856, normal = 111500464538293, rough = 80673120127218, studs = 8, pattern = Enum.MaterialPattern.Organic },
	{ name = "ShoreStoneGround", base = Enum.Material.Rock, color = 77321670500551, normal = 111500464538293, rough = 80673120127218, studs = 12, pattern = Enum.MaterialPattern.Organic },
	{ name = "FishSkin", base = Enum.Material.SmoothPlastic, color = 71877620575284, normal = 81839350043697, rough = 86528045576678, studs = 1 },
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

-- Fish skin (N0 tries it on two; N1 does all 26): the fish models in ServerStorage.Art keep their
-- vertex colours and get the FishSkin variant (neutral scales, low roughness, a wet sheen).
MaterialKit.FISH_SKINNED = { "Bluegill", "LargemouthBass" }

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

-- Repaints terrain sand that sits at the waterline (cells whose centre is within `band` studs of
-- the water surface at y = `waterY`) with the wet-sand slot, inside the box lo..hi. Runs in chunks.
function MaterialKit.paintWetBand(lo: Vector3, hi: Vector3, waterY: number?, band: number?): number
	local t = workspace.Terrain
	local wy, b = waterY or 0, band or 2.5
	local region = Region3.new(Vector3.new(lo.X, wy - 8, lo.Z), Vector3.new(hi.X, wy + 8, hi.Z)):ExpandToGrid(4)
	local ch = t:ReadVoxelChannels(region, 4, { "SolidMaterialIndex", "SolidOccupancy" })
	local size = ch.Size
	local idx = ch.SolidMaterialIndex
	local y0 = region.CFrame.Position.Y - region.Size.Y / 2
	local n = 0
	for x = 1, size.X do
		for y = 1, size.Y do
			local cy = y0 + (y - 0.5) * 4
			if math.abs(cy - wy) <= b then
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

-- Stock material -> our variant, for every part and voxel of it with no variant of its own.
MaterialKit.OVERRIDES = {} :: { [Enum.Material]: string }

-- Terrain slot remaps: { slot, base, variant (or ""), tint }. Slot 2 is the stock Grass slot, so
-- this re-skins all terrain grass (the hills and meadows past the lawns).
MaterialKit.SLOTS = {
	{ slot = 2, base = Enum.Material.Grass, variant = "MeadowGrass", tint = Color3.new(1, 1, 1) },
	{ slot = 23, base = Enum.Material.Sand, variant = "WetSand", tint = Color3.new(1, 1, 1) },
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
