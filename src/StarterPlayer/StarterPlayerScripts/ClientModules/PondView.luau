--!strict
-- Draws the local player's own pond fish swimming in the home pond (each player sees theirs).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FishData = require(Shared.FishData)

local PondView = {}

type Swimmer = { body: BasePart, tail: BasePart, len: number, target: Vector3, speed: number }

local swimmers: { Swimmer } = {}
local folder: Folder? = nil
local water: BasePart? = nil
local rng = Random.new()
local started = false

local function waterPart(): BasePart?
	if water and water.Parent then
		return water
	end
	local lake = workspace:FindFirstChild("Lake")
	local pond = lake and lake:FindFirstChild("HomePond")
	local w = pond and pond:FindFirstChild("Water")
	water = if w and w:IsA("BasePart") then w else nil
	return water
end

local function randomPoint(): Vector3
	local w = waterPart()
	if not w then
		return Vector3.zero
	end
	local half = w.Size / 2 - Vector3.new(1.5, 0, 1.5)
	return w.Position + Vector3.new((rng:NextNumber() * 2 - 1) * half.X, -0.15, (rng:NextNumber() * 2 - 1) * half.Z)
end

local function makePart(name: string, size: Vector3, color: Color3, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function clear()
	for _, s in swimmers do
		s.body:Destroy()
		s.tail:Destroy()
	end
	table.clear(swimmers)
end

local function ensureLoop()
	if started then
		return
	end
	started = true
	RunService.RenderStepped:Connect(function(dt)
		for _, s in swimmers do
			local pos = s.body.Position
			local to = s.target - pos
			if to.Magnitude < 0.4 then
				s.target = randomPoint()
			else
				local dir = to.Unit
				local nextPos = pos + dir * math.min(to.Magnitude, s.speed * dt)
				local cf = CFrame.lookAt(nextPos, nextPos + dir)
				s.body.CFrame = cf
				local wag = math.sin(os.clock() * 8) * 0.4
				s.tail.CFrame = cf * CFrame.new(0, 0, s.len * 0.55) * CFrame.Angles(0, wag, 0)
			end
		end
	end)
end

-- Rebuild the swimmers from the pond snapshot ({ fish = { { id, cm, ... } } }).
function PondView.update(pond: any)
	if not pond or not waterPart() then
		return
	end
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "MyPondFish"
		f.Parent = workspace
		folder = f
	end
	clear()
	for _, fish in pond.fish do
		local s = FishData.byId[fish.id]
		local color = if s then s.color else Color3.fromRGB(150, 150, 150)
		local len = math.clamp(fish.cm / 14, 0.8, 4.5)
		local body = makePart("Body", Vector3.new(len * 0.32, len * 0.26, len), color, folder :: Folder)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = body
		local tail = makePart("Tail", Vector3.new(len * 0.05, len * 0.28, len * 0.3), color, folder :: Folder)
		local start = randomPoint()
		body.CFrame = CFrame.new(start)
		tail.CFrame = CFrame.new(start)
		table.insert(swimmers, { body = body, tail = tail, len = len, target = randomPoint(), speed = 1 + rng:NextNumber() * 1.5 })
	end
	ensureLoop()
end

return PondView
