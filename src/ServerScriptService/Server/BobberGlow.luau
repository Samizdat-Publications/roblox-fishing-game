--!strict
-- Night's glowing bobber (L5a, the Night mockup in docs/looks/realish/night/bite.jpg): a warm
-- glowing tip on top of the bobber and a soft light on the water round it, fading in with the
-- night look (LookPresets.night) and out again at dawn. Nothing changes by day.
--
-- FishingService.makeBobber calls BobberGlow.watch(b) once per bobber. The
-- tip is a BillboardGui, so it follows the bobber as it bobs without any welds; the bobber's
-- own small PointLight (FishingService) stays as it is.
local Lighting = game:GetService("Lighting")
local LookPresets = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("LookPresets"))

local BobberGlow = {}

local TIP = "NightGlow"
local LIGHT = "NightLight"
local TIP_COLOR = Color3.fromRGB(255, 236, 160)
local LIGHT_COLOR = Color3.fromRGB(255, 220, 150)
local LIGHT_BRIGHTNESS = 2.2 -- at full night
local EVERY = 0.5 -- seconds between updates

-- Adds the tip and the light (once). offsetY: how far above the bobber's centre the tip sits
-- (defaults to the top of the bobber's box).
function BobberGlow.attach(bobber: BasePart, offsetY: number?)
	if not bobber:FindFirstChild(TIP) then
		local gui = Instance.new("BillboardGui")
		gui.Name = TIP
		gui.Adornee = bobber
		gui.Size = UDim2.fromScale(0.9, 0.9) -- studs
		gui.StudsOffset = Vector3.new(0, offsetY or bobber.Size.Y / 2, 0)
		gui.LightInfluence = 0 -- glows whatever the light
		gui.AlwaysOnTop = false
		gui.MaxDistance = 250
		gui.Enabled = false
		local halo = Instance.new("Frame")
		halo.Name = "Halo"
		halo.AnchorPoint = Vector2.new(0.5, 0.5)
		halo.Position = UDim2.fromScale(0.5, 0.5)
		halo.Size = UDim2.fromScale(1, 1)
		halo.BackgroundColor3 = TIP_COLOR
		halo.BackgroundTransparency = 0.7
		halo.BorderSizePixel = 0
		local haloCorner = Instance.new("UICorner")
		haloCorner.CornerRadius = UDim.new(0.5, 0)
		haloCorner.Parent = halo
		halo.Parent = gui
		local core = Instance.new("Frame")
		core.Name = "Core"
		core.AnchorPoint = Vector2.new(0.5, 0.5)
		core.Position = UDim2.fromScale(0.5, 0.5)
		core.Size = UDim2.fromScale(0.45, 0.45)
		core.BackgroundColor3 = Color3.new(1, 1, 0.92)
		core.BorderSizePixel = 0
		local coreCorner = Instance.new("UICorner")
		coreCorner.CornerRadius = UDim.new(0.5, 0)
		coreCorner.Parent = core
		core.Parent = gui
		gui.Parent = bobber
	end
	if not bobber:FindFirstChild(LIGHT) then
		local light = Instance.new("PointLight")
		light.Name = LIGHT
		light.Color = LIGHT_COLOR
		light.Range = 10
		light.Brightness = 0
		light.Shadows = false
		light.Enabled = false
		light.Parent = bobber
	end
end

-- Sets the glow for a night amount (0 by day, 1 at full night).
function BobberGlow.set(bobber: BasePart, amount: number)
	local gui = bobber:FindFirstChild(TIP)
	local light = bobber:FindFirstChild(LIGHT)
	local on = amount > 0.02
	if gui and gui:IsA("BillboardGui") then
		gui.Enabled = on
		local halo = gui:FindFirstChild("Halo")
		if halo and halo:IsA("Frame") then
			halo.BackgroundTransparency = 1 - 0.3 * amount
		end
		local core = gui:FindFirstChild("Core")
		if core and core:IsA("Frame") then
			core.BackgroundTransparency = 1 - amount
		end
	end
	if light and light:IsA("PointLight") then
		light.Enabled = on
		light.Brightness = LIGHT_BRIGHTNESS * amount
	end
end

-- Attaches the glow and keeps it in step with the clock until the bobber is gone.
function BobberGlow.watch(bobber: BasePart, offsetY: number?)
	BobberGlow.attach(bobber, offsetY)
	local last = -1
	local function update()
		local amount = LookPresets.night(Lighting.ClockTime)
		if math.abs(amount - last) > 0.02 or (amount == 0) ~= (last == 0) then
			last = amount
			BobberGlow.set(bobber, amount)
		end
	end
	update()
	local alive = true
	bobber.Destroying:Connect(function()
		alive = false
	end)
	task.spawn(function()
		local seen = bobber.Parent ~= nil
		while alive do
			task.wait(EVERY)
			if bobber.Parent then
				seen = true
			elseif seen then
				break -- removed without Destroy
			end
			update()
		end
	end)
end

return BobberGlow
