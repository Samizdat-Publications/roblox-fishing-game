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

-- Filled in as each family is uploaded (art/textures/README.md has the same ids).
MaterialKit.FAMILIES = {
	{ name = "WeatheredPlank", base = Enum.Material.Wood, studs = 6 },
	{ name = "Rope", base = Enum.Material.Fabric, studs = 2 },
	{ name = "Canvas", base = Enum.Material.Fabric, studs = 4 },
	{ name = "MeadowGrass", base = Enum.Material.Grass, studs = 10, pattern = Enum.MaterialPattern.Organic },
	{ name = "WetSand", base = Enum.Material.Sand, studs = 8, pattern = Enum.MaterialPattern.Organic },
	{ name = "ShoreStone", base = Enum.Material.Slate, studs = 6, pattern = Enum.MaterialPattern.Organic },
	{ name = "FishSkin", base = Enum.Material.SmoothPlastic, studs = 1 },
} :: { Family }

-- Stock material -> our variant, for every part and voxel of it with no variant of its own.
MaterialKit.OVERRIDES = {} :: { [Enum.Material]: string }

-- Terrain slot remaps: { slot, base, variant (or ""), tint }.
MaterialKit.SLOTS = {} :: { { slot: number, base: Enum.Material, variant: string, tint: Color3 } }

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
