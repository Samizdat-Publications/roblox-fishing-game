--[[
Default-look audit: counts, no judgment (leg 3, "Measurable checks" 2). Paste into execute_luau
on the Client during Play (Edit also works, but Play has the whole world the builder adds).
Returns one line of counts, then a newline, then the same numbers as JSON. Save the JSON line as
<run>/audit.json and `shots.py score` writes it beside the scores.

What it counts:
- plastic: visible BaseParts (Transparency < 0.95, in the workspace, not in a character, not under
  an instance with the AuditAllow attribute, not on ALLOW) in Plastic or SmoothPlastic.
- stockMaterial: visible parts in any other stock material with no MaterialVariant and no
  MaterialService override for that material; stockGround: the same, for ground materials only
  (the home-lake lawns are Grass parts, not terrain).
- materialVariants (ours: names not starting ZZ_), surfaceAppearances and heroSets (distinct
  models holding one), floating always-on-top BillboardGuis (and those not for a ProximityPrompt),
  terrain slots 23..63 in use, the share of solid terrain voxels in the play areas still on the
  stock slots 2..22, Lighting.LightingStyle and the GlobalWind strength.
Every engine call is inside pcall; anything that cannot be read prints n/a.
]]

-- Parts that may stay plain (by name or by an ancestor's name). Keep it short.
local ALLOW: { [string]: boolean } = {
	Baseplate = true,
	SpawnLocation = true,
}

-- Play areas sampled for stock terrain (studs). Home lake and the Big Lake basin.
local AREAS = {
	{ name = "homeLake", min = Vector3.new(-130, -16, -100), max = Vector3.new(130, 8, 130) },
	{ name = "bigLakeBasin", min = Vector3.new(-200, -16, -290), max = Vector3.new(200, 8, -140) },
}

-- TODO (leg 3): shore and path straightness (no run straighter than 30 studs) needs a spec on
-- Shore's numbers first; it lands here when that spec exists.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")

local function try(f: () -> any): any
	local ok, v = pcall(f)
	return if ok then v else nil
end

local PLASTIC = { [Enum.Material.Plastic] = true, [Enum.Material.SmoothPlastic] = true }
local GROUND = {}
for _, n in { "Grass", "LeafyGrass", "Ground", "Mud", "Sand", "Sandstone", "Rock", "Slate", "Limestone", "Basalt", "Pebble", "Cobblestone", "Salt", "Snow", "Glacier", "CrackedLava", "Asphalt", "Concrete", "Pavement" } do
	local m = try(function()
		return (Enum.Material :: any)[n]
	end)
	if m then
		GROUND[m] = true
	end
end
local INVISIBLE_MATERIALS = { [Enum.Material.ForceField] = true }

-- Characters: every player's character model.
local characters: { Instance } = {}
for _, p in Players:GetPlayers() do
	if p.Character then
		table.insert(characters, p.Character)
	end
end
local function inCharacter(x: Instance): boolean
	for _, c in characters do
		if x:IsDescendantOf(c) then
			return true
		end
	end
	return x:FindFirstAncestorOfClass("Model") ~= nil and (x:FindFirstAncestorOfClass("Model") :: Model):FindFirstChildOfClass("Humanoid") ~= nil
end

local function allowed(x: Instance): boolean
	local cur: Instance? = x
	while cur and cur ~= workspace do
		if ALLOW[cur.Name] or try(function()
			return cur:GetAttribute("AuditAllow")
		end) then
			return true
		end
		cur = cur.Parent
	end
	return false
end

-- A MaterialService override makes a base material ours everywhere it is used.
local overridden: { [Enum.Material]: boolean } = {}
local function isOverridden(m: Enum.Material): boolean
	if overridden[m] == nil then
		local name = try(function()
			return MaterialService:GetBaseMaterialOverride(m)
		end)
		overridden[m] = type(name) == "string" and name ~= ""
	end
	return overridden[m]
end

local out: { [string]: any } = {}

-- Parts.
local total, plastic, stockMat, stockGround = 0, 0, 0, 0
local plasticByModel: { [string]: number } = {}
for _, x in workspace:GetDescendants() do
	if x:IsA("BasePart") and not x:IsA("Terrain") then
		total += 1
		local visible = x.Transparency < 0.95 and not INVISIBLE_MATERIALS[x.Material]
		if visible and not inCharacter(x) and not allowed(x) then
			local variant = try(function()
				return x.MaterialVariant
			end)
			local plain = (variant == nil or variant == "") and not isOverridden(x.Material)
			if PLASTIC[x.Material] then
				if plain then
					plastic += 1
					local m = x:FindFirstAncestorOfClass("Model")
					local key = if m then m.Name else (if x.Parent then x.Parent.Name else "?")
					plasticByModel[key] = (plasticByModel[key] or 0) + 1
				end
			elseif plain then
				stockMat += 1
				if GROUND[x.Material] then
					stockGround += 1
				end
			end
		end
	end
end
out.parts = total
out.plastic = plastic
out.stockMaterial = stockMat
out.stockGround = stockGround
-- The ten models with the most plain plastic, to know where to look first.
local top = {}
for k, v in plasticByModel do
	table.insert(top, { k, v })
end
table.sort(top, function(a, b)
	return a[2] > b[2]
end)
local topText = {}
for i = 1, math.min(10, #top) do
	table.insert(topText, top[i][1] .. " " .. top[i][2])
end
out.plasticTop = table.concat(topText, ", ")

-- Material variants (ours: not ZZ_), surface appearances and hero sets.
local variants = try(function()
	local n = 0
	for _, v in MaterialService:GetDescendants() do
		if v:IsA("MaterialVariant") and string.sub(v.Name, 1, 3) ~= "ZZ_" then
			n += 1
		end
	end
	return n
end)
out.materialVariants = variants
local sa, heroes = 0, {}
local everything = try(function()
	return game:GetDescendants()
end) or workspace:GetDescendants()
for _, x in everything do
	local ok, isSA = pcall(function()
		return x:IsA("SurfaceAppearance")
	end)
	if ok and isSA then
		sa += 1
		local m = x:FindFirstAncestorOfClass("Model")
		heroes[m or x.Parent or x] = true
	end
end
local heroCount = 0
for _ in heroes do
	heroCount += 1
end
out.surfaceAppearances = sa
out.heroSets = heroCount

-- Floating labels: always-on-top BillboardGuis in the workspace (and any in PlayerGui aimed at
-- the world). A label belongs to a prompt when its parent or adornee holds a ProximityPrompt.
local function forPrompt(g: BillboardGui): boolean
	if string.find(g.Name, "Prompt") then
		return true
	end
	for _, holder in { g.Parent, try(function()
		return g.Adornee
	end) } do
		if holder and holder:FindFirstChildWhichIsA("ProximityPrompt", true) then
			return true
		end
	end
	return false
end
local boards, boardsNoPrompt = 0, 0
local function scanBoards(root: Instance?)
	if not root then
		return
	end
	for _, g in root:GetDescendants() do
		if g:IsA("BillboardGui") and g.AlwaysOnTop and g.Enabled then
			boards += 1
			if not forPrompt(g) then
				boardsNoPrompt += 1
			end
		end
	end
end
scanBoards(workspace)
scanBoards(try(function()
	return Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
end))
out.alwaysOnTopLabels = boards
out.alwaysOnTopLabelsNotPrompt = boardsNoPrompt

-- Terrain: custom slots in use and the share of play-area ground on the stock slots.
local terrain = workspace.Terrain
local slots = try(function()
	local n = 0
	for i = 23, 63 do
		if terrain:GetMaterialSlot(i) ~= nil then
			n += 1
		end
	end
	return n
end)
out.terrainCustomSlots = slots
local function stockShare(a): (number?, number?)
	return try(function()
		local region = Region3.new(a.min, a.max):ExpandToGrid(4)
		local ch = terrain:ReadVoxelChannels(region, 4, { "SolidMaterialIndex", "SolidOccupancy" }) :: any
		local idx, occ = ch.SolidMaterialIndex, ch.SolidOccupancy
		local solid, stock = 0, 0
		for x = 1, #idx do
			for y = 1, #idx[x] do
				for z = 1, #idx[x][y] do
					if occ[x][y][z] > 0 then
						solid += 1
						local i = idx[x][y][z]
						if i >= 2 and i <= 22 then
							stock += 1
						end
					end
				end
			end
		end
		return if solid > 0 then stock / solid else 0, solid
	end)
end
for _, a in AREAS do
	local share, solid = stockShare(a)
	out["stockTerrain_" .. a.name] = share
	out["solidVoxels_" .. a.name] = solid
end

-- Light and wind.
out.lightingStyle = try(function()
	return (Lighting :: any).LightingStyle.Name
end)
out.technology = try(function()
	return Lighting.Technology.Name
end)
out.wind = try(function()
	return math.floor(workspace.GlobalWind.Magnitude * 100 + 0.5) / 100
end)

local function v(x: any, pct: boolean?): string
	if x == nil then
		return "n/a"
	end
	if pct and type(x) == "number" then
		return string.format("%.0f%%", x * 100)
	end
	return tostring(x)
end
local line = string.format(
	"audit: plastic %s of %s parts | stock-material parts %s (ground %s) | our material variants %s | surface appearances %s in %s hero sets | always-on-top labels %s (%s not prompts) | terrain slots 23..63 in use %s | stock terrain home lake %s, Big Lake basin %s | lighting %s (%s) | wind %s | top plastic: %s",
	v(out.plastic), v(out.parts), v(out.stockMaterial), v(out.stockGround), v(out.materialVariants),
	v(out.surfaceAppearances), v(out.heroSets), v(out.alwaysOnTopLabels), v(out.alwaysOnTopLabelsNotPrompt),
	v(out.terrainCustomSlots), v(out.stockTerrain_homeLake, true), v(out.stockTerrain_bigLakeBasin, true),
	v(out.lightingStyle), v(out.technology), v(out.wind), v(out.plasticTop)
)
local json = try(function()
	return HttpService:JSONEncode(out)
end) or "{}"
return line .. "\n" .. json
