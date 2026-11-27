--!strict
-- Fish shadows cruising just under the surface. Purely visual and local to each player.
-- The number of shadows in each spot follows the real bite rules: a spot shows more fish
-- at the times of day when its fish are active, so players can learn to read the water.
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FishLogic = require(Shared.FishLogic)
local BaitData = require(Shared.BaitData)
local Config = require(Shared.Config)
local Shore = require(Shared.Shore)

local FishShadows = {}

local MAX_PER_SPOT = 4
local REFRESH = 6 -- seconds between activity checks
local DEPTH = -0.7 -- studs under the surface

type Area = { name: string, cframe: CFrame, size: Vector3 }
type Shadow = { part: BasePart, area: Area, target: Vector3, speed: number }

-- Gulls circling and diving over a feeding frenzy, so it can be spotted from across the
-- water (DIRECTION.md: "announced by sight"). Local and purely visual. UNVERIFIED in Studio.
local BIRDS = 5
type Bird = { model: Model, angle: number, radius: number, speed: number, dive: number }
local birds: { Bird } = {}
local birdSpot: string? = nil

local areas: { Area } = {}
local shadows: { [Area]: { Shadow } } = {}
local folder: Folder

-- How lively a spot is right now: the best total bite weight over every bait.
local function activity(spot: string, period: string): number
	local best = 0
	for _, b in BaitData.list do
		local total = 0
		local now = { weather = workspace:GetAttribute("Weather") or "Clear", wind = workspace:GetAttribute("WindFrom"), moon = workspace:GetAttribute("Moon") or 0 }
		for _, w in FishLogic.biteWeights(spot, period, b.id, now :: any) do
			total += w.w
		end
		best = math.max(best, total)
	end
	return best
end

-- A point in the area, kept off the lake's rounded corners and points of land (Shore, L5d):
-- a few tries, then the area's centre, which is always water.
local function randomPoint(area: Area, rng: Random): Vector3
	for _ = 1, 8 do
		local p = area.cframe:PointToWorldSpace(Vector3.new(
			(rng:NextNumber() - 0.5) * area.size.X * 0.9,
			0,
			(rng:NextNumber() - 0.5) * area.size.Z * 0.9
		))
		if Shore.depth(p.X, p.Z) < -3 then
			return Vector3.new(p.X, DEPTH, p.Z)
		end
	end
	local c = area.cframe.Position
	return Vector3.new(c.X, DEPTH, c.Z)
end

local rng = Random.new()

local function spawnShadow(area: Area): Shadow
	local scale = 0.8 + rng:NextNumber() * 0.9
	local part = Instance.new("Part")
	part.Name = "Shadow"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = Vector3.new(0.7 * scale, 0.1, 2.4 * scale)
	part.Color = Color3.fromRGB(18, 30, 42)
	part.Transparency = 0.45
	part.Material = Enum.Material.SmoothPlastic
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	local start = randomPoint(area, rng)
	part.CFrame = CFrame.new(start)
	part.Parent = folder
	return { part = part, area = area, target = randomPoint(area, rng), speed = 1.5 + rng:NextNumber() * 2.5 }
end

local function refresh()
	local period = FishLogic.periodFromClock(Lighting.ClockTime)
	for _, area in areas do
		local list = shadows[area]
		local spotName = if area.name:match("^OpenWater") then "OpenWater" else area.name
		local want = math.clamp(math.floor(activity(spotName, period) * MAX_PER_SPOT + 0.5), 0, MAX_PER_SPOT)
		if workspace:GetAttribute("Frenzy") == spotName then
			want = MAX_PER_SPOT -- a feeding frenzy: the water is full of fish (UNVERIFIED in Studio)
		end
		while #list < want do
			table.insert(list, spawnShadow(area))
		end
		while #list > want do
			local s = table.remove(list) :: Shadow
			s.part:Destroy()
		end
	end
end

local function makeBird(): Model
	local m = Instance.new("Model")
	m.Name = "Gull"
	for i, side in { -1, 1 } do
		local wing = Instance.new("Part")
		wing.Name = if i == 1 then "WingL" else "WingR"
		wing.Anchored = true
		wing.CanCollide = false
		wing.CanQuery = false
		wing.CanTouch = false
		wing.CastShadow = false
		wing.Size = Vector3.new(1.3, 0.12, 0.5)
		wing.Color = Color3.fromRGB(240, 240, 235)
		wing.Material = Enum.Material.SmoothPlastic
		wing:SetAttribute("Side", side)
		wing.Parent = m
	end
	m.Parent = folder
	return m
end

-- Where the frenzy's water is: the zone's centre (or the first open-water patch).
local function frenzyCentre(spot: string): Vector3?
	local at = workspace:GetAttribute("FrenzyAt")
	if typeof(at) == "Vector3" then
		return Vector3.new(at.X, 0, at.Z) -- the server's boil
	end
	for _, a in areas do
		local name = if a.name:match("^OpenWater") then "OpenWater" else a.name
		if name == spot then
			return Vector3.new(a.cframe.Position.X, 0, a.cframe.Position.Z)
		end
	end
	return nil
end

local function updateBirds(dt: number)
	local spot = workspace:GetAttribute("Frenzy")
	local centre = if type(spot) == "string" then frenzyCentre(spot) else nil
	if not centre then
		for _, b in birds do
			b.model:Destroy()
		end
		table.clear(birds)
		birdSpot = nil
		return
	end
	if birdSpot ~= spot then
		for _, b in birds do
			b.model:Destroy()
		end
		table.clear(birds)
		for i = 1, BIRDS do
			table.insert(birds, { model = makeBird(), angle = i * math.pi * 2 / BIRDS, radius = 6 + rng:NextNumber() * 6, speed = 0.8 + rng:NextNumber() * 0.6, dive = rng:NextNumber() * 6 })
		end
		birdSpot = spot
	end
	local t = os.clock()
	for _, b in birds do
		b.angle += b.speed * dt
		b.dive -= dt
		local height = 9 + math.sin(t * 2 + b.angle) * 1.2
		if b.dive < 0 then
			-- A dive: drop to the water and climb back over about a second.
			local k = math.clamp(-b.dive, 0, 1)
			height = 9 - 8 * math.sin(k * math.pi)
			if b.dive < -1 then
				b.dive = 3 + rng:NextNumber() * 5
			end
		end
		local pos = centre + Vector3.new(math.cos(b.angle) * b.radius, height, math.sin(b.angle) * b.radius)
		local ahead = centre + Vector3.new(math.cos(b.angle + 0.1) * b.radius, height, math.sin(b.angle + 0.1) * b.radius)
		local cf = CFrame.lookAt(pos, ahead)
		local flap = math.sin(t * 9 + b.angle * 3) * 0.5
		for _, wing in b.model:GetChildren() do
			if wing:IsA("BasePart") then
				local side = wing:GetAttribute("Side") :: number
				wing.CFrame = cf * CFrame.Angles(0, 0, side * flap) * CFrame.new(side * 0.65, 0, 0)
			end
		end
	end
end

function FishShadows.start()
	local lake = workspace:WaitForChild("Lake")
	local zones = lake:WaitForChild("Zones")
	-- Wait for each zone: with streaming on they can arrive a moment after the player.
	for _, name in { "Dock", "WeedBed", "Logs", "DeepHole", "Riffle", "Rocks", "Pool" } do
		local z = zones:WaitForChild(name, 15)
		if z and z:IsA("BasePart") then
			table.insert(areas, { name = z.Name, cframe = z.CFrame, size = z.Size })
		end
	end
	-- The Big Lake's spots, when it exists (UNVERIFIED in Studio, 2026-11-26).
	local big = if Config.BIG_LAKE_ON then workspace:WaitForChild("BigLake", 15) else nil
	local bigZones = big and big:WaitForChild("Zones", 15)
	if bigZones then
		for _, name in { "Basin", "IslandPoint", "DropOff" } do
			local z = bigZones:WaitForChild(name, 15)
			if z and z:IsA("BasePart") then
				table.insert(areas, { name = z.Name, cframe = z.CFrame, size = z.Size })
			end
		end
	end
	-- Two patches of open water away from the shore features.
	table.insert(areas, { name = "OpenWater1", cframe = CFrame.new(-60, 0, -40), size = Vector3.new(50, 1, 40) })
	table.insert(areas, { name = "OpenWater2", cframe = CFrame.new(65, 0, -35), size = Vector3.new(50, 1, 40) })
	for _, a in areas do
		shadows[a] = {}
	end

	folder = Instance.new("Folder")
	folder.Name = "FishShadows"
	folder.Parent = workspace

	refresh()
	local last = os.clock()
	RunService.RenderStepped:Connect(function(dt)
		if os.clock() - last > REFRESH then
			last = os.clock()
			refresh()
		end
		updateBirds(dt)
		for _, list in shadows do
			for _, s in list do
				local pos = s.part.Position
				local to = s.target - pos
				if to.Magnitude < 0.5 then
					s.target = randomPoint(s.area, rng)
				else
					local step = math.min(to.Magnitude, s.speed * dt)
					local nextPos = pos + to.Unit * step
					s.part.CFrame = CFrame.lookAt(nextPos, nextPos + to.Unit)
				end
			end
		end
	end)
end

return FishShadows
