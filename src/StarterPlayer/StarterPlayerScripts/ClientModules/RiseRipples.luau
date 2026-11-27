--!strict
-- The ripple where a fish rises (L2b): three flat rings spread out from the spot and fade
-- over about 1.5 seconds. Client only: the parts live in this client's own workspace folder,
-- don't collide and can't be hit by raycasts. The server says where (FishingEvent "Rise").
-- UNVERIFIED in Studio (written 2026-11-26).
local RunService = game:GetService("RunService")

local RiseRipples = {}

local RINGS = 3
local STAGGER = 0.25 -- seconds between rings
local LIFE = 1.5 -- seconds each ring lasts
local START_RADIUS = 0.4
local END_RADIUS = 4.5
local RIM = 0.35 -- ring thickness (studs)
local COLOR = Color3.fromRGB(235, 245, 255)

local folder: Folder? = nil

local function getFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "RiseRipples"
	f.Parent = workspace
	folder = f
	return f
end

local function ring(at: Vector3, delay: number)
	local a = Instance.new("Part")
	a.Name = "Ripple"
	a.Size = Vector3.new(0.2, 0.2, 0.2)
	a.Transparency = 1
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.CastShadow = false
	a.CFrame = CFrame.new(at)
	local r = Instance.new("CylinderHandleAdornment")
	r.Adornee = a
	r.Radius = START_RADIUS
	r.InnerRadius = math.max(START_RADIUS - RIM, 0)
	r.Height = 0.06
	r.CFrame = CFrame.Angles(math.rad(90), 0, 0) -- the cylinder's axis is its Z: point it up
	r.Color3 = COLOR
	r.Transparency = 1
	r.AlwaysOnTop = false
	r.Parent = a
	a.Parent = getFolder()
	task.delay(delay, function()
		local t0 = os.clock()
		local conn: RBXScriptConnection? = nil
		conn = RunService.RenderStepped:Connect(function()
			local k = (os.clock() - t0) / LIFE
			if k >= 1 or not a.Parent then
				if conn then
					conn:Disconnect()
				end
				a:Destroy()
				return
			end
			local ease = 1 - (1 - k) * (1 - k) -- fast out, slowing as it spreads
			local radius = START_RADIUS + (END_RADIUS - START_RADIUS) * ease
			r.Radius = radius
			r.InnerRadius = math.max(radius - RIM, 0)
			r.Transparency = 0.25 + 0.75 * k
		end)
	end)
end

-- A rise at `pos` (on the water).
function RiseRipples.show(pos: Vector3)
	local at = Vector3.new(pos.X, 0.22, pos.Z)
	for i = 1, RINGS do
		ring(at, (i - 1) * STAGGER)
	end
end

return RiseRipples
