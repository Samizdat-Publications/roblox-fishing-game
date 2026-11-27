--!strict
-- Sign lanterns (leg 3, N2): every PointLight tagged "Lantern" (Server/Signs) burns at night and
-- is dark by day, with its glass glowing (Neon) only while lit. Local only; checked twice a
-- second against Lighting.ClockTime (SignLayout.lanternsOn). Lanterns that stream in later are
-- set as they arrive.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SignLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SignLayout"))

local Lanterns = {}

local TAG = "Lantern"
local EVERY = 0.5

local started = false
local lit = false

local function set(inst: Instance, on: boolean)
	if inst:IsA("Light") then
		inst.Enabled = on
		-- The phone tier keeps the sun's shadows only (LookPresets.TIERS.phone.shadows).
		local player = game:GetService("Players").LocalPlayer
		local phone = player ~= nil and player:GetAttribute("LookTierActive") == "phone"
		pcall(function()
			(inst :: any).Shadows = not phone
		end)
		local glass = inst.Parent
		if glass and glass:IsA("BasePart") then
			glass.Material = if on then Enum.Material.Neon else Enum.Material.Glass
		end
	end
end

local function setAll(on: boolean)
	for _, inst in CollectionService:GetTagged(TAG) do
		set(inst, on)
	end
end

function Lanterns.start()
	if started then
		return
	end
	started = true
	lit = SignLayout.lanternsOn(Lighting.ClockTime)
	setAll(lit)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
		set(inst, lit)
	end)
	task.spawn(function()
		while true do
			task.wait(EVERY)
			local on = SignLayout.lanternsOn(Lighting.ClockTime)
			if on ~= lit then
				lit = on
				setAll(on)
			end
		end
	end)
end

return Lanterns
