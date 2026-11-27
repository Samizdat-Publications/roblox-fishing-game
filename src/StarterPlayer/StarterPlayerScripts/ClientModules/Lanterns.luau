--!strict
-- Sign lanterns (leg 3, N2): every PointLight tagged "Lantern" (Server/Signs) burns at night and
-- is dark by day, with its glass glowing (Neon) only while lit. Shadows only on lights marked
-- SHADOW_ATTR (the dock's two), never on the phone tier, never where the server made none.
-- Local only; checked twice a second against Lighting.ClockTime (SignLayout.lanternsOn).
-- Lanterns that stream in later are set as they arrive.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SignLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SignLayout"))

local Lanterns = {}

local TAG = "Lantern"
local EVERY = 0.5
-- Only lights the server marks with this attribute may cast shadows (the two dock lanterns,
-- WorldBuilder.LANTERN.SHADOW_ATTR; N1 review 1, 11/27/2026). Every other lantern burns without.
local SHADOW_ATTR = "LanternShadows"

local started = false
local lit = false
-- What the server made each light with, read once before this client changes it, so a light
-- the server made without shadows is never given them here. Weak keys: streamed-out lights go.
local serverShadows = setmetatable({}, { __mode = "k" }) :: { [Instance]: boolean }

-- Whether this lantern light casts shadows on this client.
function Lanterns.shadowsFor(made: boolean, marked: boolean, phone: boolean): boolean
	-- The phone tier keeps the sun's shadows only (LookPresets.TIERS.phone.shadows).
	return made and marked and not phone
end

local function set(inst: Instance, on: boolean)
	if inst:IsA("Light") then
		inst.Enabled = on
		local made = serverShadows[inst]
		if made == nil then
			made = (inst :: any).Shadows == true
			serverShadows[inst] = made
		end
		local player = game:GetService("Players").LocalPlayer
		local phone = player ~= nil and player:GetAttribute("LookTierActive") == "phone"
		local cast = Lanterns.shadowsFor(made :: boolean, inst:GetAttribute(SHADOW_ATTR) == true, phone)
		pcall(function()
			(inst :: any).Shadows = cast
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
