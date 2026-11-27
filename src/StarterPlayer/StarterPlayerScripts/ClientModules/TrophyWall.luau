--!strict
-- The trophy wall behind the home pond (L6, 11/27/2026): your six best catches, mounted on
-- plaques, on your own screen only (like your pond fish). Monsters first, then trophies, then
-- the rarest, then the heaviest (Shared/Journal.wall). Each plaque has a strip in the fish's
-- tier colour and a brass-style label with its name and weight; an empty slot waits for one.
-- The board is built by Scenery (Lake.Scenery.TrophyWall.Board); the models come from
-- ReplicatedStorage.FishModels (Server/FishModels).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FishData = require(Shared.FishData)
local Rarity = require(Shared.Rarity)
local Units = require(Shared.Units)
local Journal = require(Shared.Journal)

local TrophyWall = {}

-- Slot centres on the board's front, from its centre (studs): two rows of three, best first,
-- reading left to right for someone facing the front (the board's own +X is their left).
local SLOTS = {
	Vector2.new(4.8, 1.55),
	Vector2.new(0, 1.55),
	Vector2.new(-4.8, 1.55),
	Vector2.new(4.8, -1.55),
	Vector2.new(0, -1.55),
	Vector2.new(-4.8, -1.55),
}
local PLAQUE = Vector3.new(4.2, 2.7, 0.2)
local FISH_LEN = 3.3 -- studs, every mount the same length so they read as a set
local PLAQUE_COLOR = Color3.fromRGB(70, 46, 30)

local folder: Folder? = nil
local shownKey = ""

local function board(): BasePart?
	local lake = workspace:FindFirstChild("Lake")
	local scenery = lake and lake:FindFirstChild("Scenery")
	local wall = scenery and scenery:FindFirstChild("TrophyWall")
	local b = wall and wall:FindFirstChild("Board")
	return if b and b:IsA("BasePart") then b else nil
end

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
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
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function caption(plaque: BasePart, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0.5
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.fromScale(0.5, 0.97)
	label.Size = UDim2.fromScale(0.94, 0.3)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color
	label.Parent = gui
	gui.Parent = plaque
end

local function mount(b: BasePart, slot: Vector2, id: string?, st: any, parent: Instance)
	-- The plaque sits on the board's front face (its -Z side).
	local front = b.CFrame * CFrame.new(slot.X, slot.Y, -(b.Size.Z + PLAQUE.Z) / 2)
	local plaque = part("Plaque", PLAQUE, front, PLAQUE_COLOR, Enum.Material.Wood, parent)
	local species = id and FishData.byId[id]
	if not id or not species then
		caption(plaque, "Your next big one", Color3.fromRGB(170, 150, 120))
		return
	end
	local tier = Rarity.of(species)
	part("Strip", Vector3.new(PLAQUE.X, 0.18, PLAQUE.Z + 0.04), front * CFrame.new(0, PLAQUE.Y / 2 - 0.09, 0), Rarity.colorAt(tier, 0), Enum.Material.SmoothPlastic, parent)
	local best = st.bests[id]
	local tag = if ((st.monsters or {})[id] or 0) > 0 then "MONSTER " elseif ((st.trophies or {})[id] or 0) > 0 then "TROPHY " else ""
	caption(plaque, tag .. species.name .. ", " .. Units.weight(best.kg), Color3.fromRGB(240, 214, 150))
	local models = ReplicatedStorage:FindFirstChild("FishModels")
	local source = models and models:FindFirstChild(id)
	local fish: BasePart
	if source and source:IsA("BasePart") then
		fish = source:Clone()
		fish.Size = source.Size * (FISH_LEN / source.Size.X) -- the model's length runs along X
	else
		-- No model yet: a simple shape in the species' colour.
		local p = Instance.new("Part")
		p.Size = Vector3.new(FISH_LEN, FISH_LEN * 0.3, FISH_LEN * 0.12)
		p.Color = species.color
		p.Material = Enum.Material.SmoothPlastic
		fish = p
	end
	fish.Name = "Fish"
	fish.Anchored = true
	fish.CanCollide = false
	fish.CanQuery = false
	fish.CanTouch = false
	fish.CFrame = front * CFrame.new(0, 0.3, -(PLAQUE.Z / 2 + fish.Size.Z / 2 + 0.02))
	fish.Parent = parent
end

-- Rebuild the mounts from the journal snapshot (only when the six best change).
function TrophyWall.update(st: any)
	if not st or type(st.bests) ~= "table" then
		return
	end
	local b = board()
	if not b then
		return
	end
	local ids = Journal.wall(st.bests, st.trophies, st.monsters, FishData.byId, #SLOTS)
	local parts = {}
	for _, id in ids do
		table.insert(parts, id .. string.format(":%.2f", tonumber(st.bests[id].kg) or 0))
	end
	local key = table.concat(parts, ",")
	if key == shownKey and folder and folder.Parent then
		return
	end
	shownKey = key
	if folder then
		folder:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "MyTrophyWall"
	for i, slot in SLOTS do
		mount(b, slot, ids[i], st, f)
	end
	f.Parent = workspace
	folder = f
end

return TrophyWall
