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
--
-- 11/28/2026, after the N3 final critic ("hard-edged rectangular whitewater foam patches"): with
-- CreekPlan.FOAM_BEAMS_ON the strips give way to soft Beams (CreekPlan.foamBeams: faded at both
-- ends by Transparency, at both sides by the map's faded rows, tapered and slightly bent) and a
-- small soft pillow emitter behind every emergent rock and boulder (CreekPlan.foamPuffs). All of
-- it hangs from one invisible anchored part. Off: the strips, as before.
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

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function sequence(points: { { number } }): NumberSequence
	local kps = {}
	for _, p in points do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(kps)
end

-- An attachment on `holder` at (x, y, z), its Axis (X) along the flow at `yaw`.
local function anchorAt(holder: BasePart, name: string, x: number, y: number, z: number, yaw: number): Attachment
	local right, up = CreekPlan.foamFrame(yaw)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = holder -- parent first: WorldCFrame is read against the holder
	a.WorldCFrame = CFrame.fromMatrix(Vector3.new(x, y, z), v3(right), v3(up))
	return a
end

local function sprayEmitter(p: CreekPlan.FoamPuff, downstream: Vector3): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = if WhiteWater.TEXTURES.spray then asset(WhiteWater.TEXTURES.spray) else e.Texture
	e.Color = ColorSequence.new(WhiteWater.FOAM_COLOR)
	e.LightEmission = 0.15
	e.LightInfluence = 1
	e.Rate = p.rate
	e.Lifetime = NumberRange.new(p.life[1], p.life[2])
	e.Speed = NumberRange.new(p.speed[1], p.speed[2])
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, p.rise, 0) + downstream * p.drift
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, p.size[1]), NumberSequenceKeypoint.new(1, p.size[2]) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), -- fades in too: no particle pops on at full strength
		NumberSequenceKeypoint.new(0.15, p.transparency[1]),
		NumberSequenceKeypoint.new(1, p.transparency[2]),
	})
	if p.kind == "pillow" then
		e.SpreadAngle = Vector2.new(70, 70)
		e.Drag = 2
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-20, 20)
	else
		e.SpreadAngle = Vector2.new(25, 25)
		e.Drag = 1.5
	end
	return e
end

-- The soft version (CreekPlan.FOAM_BEAMS_ON): beams and pillows on one invisible holder.
local function buildBeams(f: Folder)
	local holder = Instance.new("Part")
	holder.Name = "FoamHolder"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(WhiteWater.CENTRE)
	holder.Parent = f
	local foamId = WhiteWater.TEXTURES.foam
	for i, b in CreekPlan.foamBeams(CreekPlan.SEED) do
		local a0 = anchorAt(holder, "Foam" .. i .. "A", b.x0, CreekPlan.FOAM_Y, b.z0, b.yaw0)
		local a1 = anchorAt(holder, "Foam" .. i .. "B", b.x1, CreekPlan.FOAM_Y, b.z1, b.yaw1)
		local beam = Instance.new("Beam")
		beam.Name = "Foam" .. i
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.FaceCamera = false
		beam.Segments = CreekPlan.FOAM_SEGMENTS
		beam.CurveSize0 = b.curve
		beam.CurveSize1 = b.curve
		beam.Width0 = b.w0
		beam.Width1 = b.w1
		beam.Color = ColorSequence.new(WhiteWater.FOAM_COLOR)
		beam.Transparency = sequence(CreekPlan.foamBeamFade(b))
		beam.LightInfluence = 1 -- lit like the water round it, so it never glows at dawn or night
		beam.LightEmission = 0
		beam.ZOffset = CreekPlan.FOAM_ZOFFSET
		if foamId then
			beam.Texture = asset(foamId)
			beam.TextureMode = Enum.TextureMode.Wrap
			beam.TextureLength = CreekPlan.FOAM_TILE_U
			beam.TextureSpeed = CreekPlan.foamTextureSpeed(b.speed)
		else
			beam.Texture = ""
		end
		beam.Parent = holder
	end
	for i, p in CreekPlan.foamPuffs(CreekPlan.SEED) do
		local down = Vector3.new(0, 0, -1) -- the creek runs to -z
		local e = sprayEmitter(p, down)
		if p.kind == "pillow" then
			local a = Instance.new("Attachment")
			a.Name = "Pillow" .. i
			a.Parent = holder
			a.WorldCFrame = CFrame.new(p.x, p.y, p.z)
			e.Parent = a
		else
			local s = Instance.new("Part")
			s.Name = "Spray" .. i
			s.Anchored = true
			s.CanCollide = false
			s.CanQuery = false
			s.CanTouch = false
			s.CastShadow = false
			s.Transparency = 1
			s.Size = Vector3.new(p.w, 0.2, 1.5)
			s.CFrame = CFrame.new(p.x, p.y, p.z)
			e.Parent = s
			s.Parent = f
		end
		table.insert(emitters, e)
	end
end

local function build(): Folder
	local f = Instance.new("Folder")
	f.Name = "WhiteWater"
	if CreekPlan.FOAM_BEAMS_ON then
		buildBeams(f)
		return f
	end
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
