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

local FishShadows = {}

local MAX_PER_SPOT = 4
local REFRESH = 6 -- seconds between activity checks
local DEPTH = -0.7 -- studs under the surface

type Area = { name: string, cframe: CFrame, size: Vector3 }
type Shadow = { part: BasePart, area: Area, target: Vector3, speed: number }

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

local function randomPoint(area: Area, rng: Random): Vector3
	local p = area.cframe:PointToWorldSpace(Vector3.new(
		(rng:NextNumber() - 0.5) * area.size.X * 0.9,
		0,
		(rng:NextNumber() - 0.5) * area.size.Z * 0.9
	))
	return Vector3.new(p.X, DEPTH, p.Z)
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
		while #list < want do
			table.insert(list, spawnShadow(area))
		end
		while #list > want do
			local s = table.remove(list) :: Shadow
			s.part:Destroy()
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
