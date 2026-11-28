--!strict
-- White water on Cedar Creek's riffle (leg 3, N3), behind Config.WHITE_WATER_ON. On this screen
-- only: thin foam strips laid on the water down the riffle, across its drop into the rocky run
-- and trailing below each boulder (Shared/CreekPlan.foam), their texture scrolling downstream,
-- and a little spray where the riffle starts and where it drops (CreekPlan.SPRAY).
--
-- Never on the phone tier (player attribute LookTierActive "phone", set by LookDirector): the
-- foam's overdraw costs fill rate there, so everything is taken out of the world. On the desktop
-- it is also taken out while the camera is more than FAR studs from the riffle.
--
-- The foam and spray maps come from art/textures/white_water/ once uploaded: put their ids in
-- TEXTURES. Until then (nil) the strips are pale translucent parts that shimmer, and the spray
-- uses the stock particle.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CreekPlan = require(Shared:WaitForChild("CreekPlan"))

local WhiteWater = {}

WhiteWater.TEXTURES = {
	foam = 113344834192419 :: number?, -- tiling foam streaks, white on transparent (art/textures/white_water, uploaded 11/27/2026)
	spray = 100468867784698 :: number?, -- a soft droplet puff
}
WhiteWater.CENTRE = Vector3.new(-230, 0, 30)
WhiteWater.FAR = 180 -- studs from CENTRE past which the white water is taken out
WhiteWater.SURFACE = 0.06 -- the strips' height over the water (y 0) so the small chop does not hide them
WhiteWater.TEXTURE_TRANSPARENCY = 0.25 -- the foam map's transparency
-- N3 review 1, HELD: the advisor's numbers (wider riffle strips in CreekPlan.FOAM_REVIEW1, a
-- denser map, higher off the chop). They go live with CreekPlan.REVIEW1_FOAM (one edit).
-- Neon's N3 review, Pass 1 (11/28/2026): higher off the chop and denser still (was 0.12, 0.1),
-- and a cooler white, so the streaks read over the dawn ripples.
WhiteWater.REVIEW1 = { SURFACE = 0.14, TEXTURE_TRANSPARENCY = 0.08 }
if CreekPlan.REVIEW1_FOAM then
	WhiteWater.SURFACE = WhiteWater.REVIEW1.SURFACE
	WhiteWater.TEXTURE_TRANSPARENCY = WhiteWater.REVIEW1.TEXTURE_TRANSPARENCY
end
WhiteWater.FOAM_COLOR = Color3.fromRGB(242, 246, 240) -- Neon Pass 1 (was 236, 240, 230)
WhiteWater.EVERY = 0.5 -- seconds between distance and tier checks

type Strip = { part: BasePart, tex: Texture?, speed: number, phase: number }

local folder: Folder? = nil
local strips: { Strip } = {}
local emitters: { ParticleEmitter } = {}
local started = false
local shown = false

local function asset(id: number?): string
	return if id then "rbxassetid://" .. tostring(id) else ""
end

local function build(): Folder
	local f = Instance.new("Folder")
	f.Name = "WhiteWater"
	local foamId = WhiteWater.TEXTURES.foam
	for i, s in CreekPlan.foam(CreekPlan.SEED) do
		-- N3 review 3: the part's +X runs downstream so the map's U (its streaks) lies along the
		-- flow and its faded V rows on the strip's long edges (CreekPlan.foamFace).
		local face = CreekPlan.foamFace(s)
		local pos = Vector3.new(s.x, WhiteWater.SURFACE, s.z)
		local p = Instance.new("Part")
		p.Name = "Foam" .. i
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = Vector3.new(face.sizeX, 0.05, face.sizeZ)
		p.CFrame = CFrame.fromMatrix(pos, Vector3.new(face.rx, 0, face.rz), Vector3.yAxis) -- length (X) downstream
		p.Material = Enum.Material.SmoothPlastic
		p.Color = WhiteWater.FOAM_COLOR
		local tex: Texture? = nil
		if foamId then
			p.Transparency = 1
			local t = Instance.new("Texture")
			t.Texture = asset(foamId)
			t.Face = Enum.NormalId.Top
			t.StudsPerTileU = face.tileU
			t.StudsPerTileV = face.tileV
			t.Transparency = WhiteWater.TEXTURE_TRANSPARENCY
			t.Color3 = WhiteWater.FOAM_COLOR
			t.Parent = p
			tex = t
		else
			p.Transparency = 0.8
		end
		p.Parent = f
		table.insert(strips, { part = p, tex = tex, speed = s.speed, phase = i * 1.7 })
	end
	for i, sp in CreekPlan.SPRAY do
		local a = Instance.new("Part")
		a.Name = "Spray" .. i
		a.Anchored = true
		a.CanCollide = false
		a.CanQuery = false
		a.CanTouch = false
		a.Transparency = 1
		a.Size = Vector3.new(sp.w, 0.2, 1.5)
		a.CFrame = CFrame.new(sp.x, 0.1, sp.z)
		local e = Instance.new("ParticleEmitter")
		e.Texture = if WhiteWater.TEXTURES.spray then asset(WhiteWater.TEXTURES.spray) else e.Texture
		e.Color = ColorSequence.new(WhiteWater.FOAM_COLOR)
		e.LightEmission = 0.15
		e.LightInfluence = 1
		e.Rate = 10
		e.Lifetime = NumberRange.new(0.5, 0.9)
		e.Speed = NumberRange.new(1.5, 3.5)
		e.SpreadAngle = Vector2.new(25, 25)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = Vector3.new(0, -9, 0)
		e.Drag = 1.5
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.7) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
		e.Parent = a
		table.insert(emitters, e)
		a.Parent = f
	end
	return f
end

local function wanted(): boolean
	local player = Players.LocalPlayer
	if player and player:GetAttribute("LookTierActive") == "phone" then
		return false
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return false
	end
	return (cam.CFrame.Position - WhiteWater.CENTRE).Magnitude <= WhiteWater.FAR
end

local function setShown(on: boolean)
	if on == shown then
		return
	end
	shown = on
	if on and not folder then
		folder = build()
	end
	if folder then
		folder.Parent = if on then workspace else nil
	end
	for _, e in emitters do
		e.Enabled = on
	end
end

function WhiteWater.start()
	if started then
		return
	end
	started = true
	local since = math.huge
	local clock = 0
	RunService.Heartbeat:Connect(function(dt: number)
		since += dt
		if since >= WhiteWater.EVERY then
			since = 0
			setShown(wanted())
		end
		if not shown then
			return
		end
		clock += dt
		for _, s in strips do
			if s.tex then
				s.tex.OffsetStudsU = CreekPlan.foamOffsetU(clock, s.speed) -- downstream (+X)
			else
				s.part.Transparency = 0.8 + 0.07 * math.sin(clock * s.speed * 1.3 + s.phase)
			end
		end
	end)
	local player = Players.LocalPlayer
	if player then
		player:GetAttributeChangedSignal("LookTierActive"):Connect(function()
			setShown(wanted())
		end)
	end
end

return WhiteWater
