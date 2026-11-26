--!strict
-- What players read for a fish's size. Fish data and saves stay metric (cm, kg); this only
-- turns them into text. Config.UNITS picks "imperial" (inches, pounds and ounces, the
-- default for Liam) or "metric". Pure: no Roblox services.
local Config = require(script.Parent.Config)

local Units = {}

local CM_PER_IN = 2.54
local KG_PER_LB = 0.45359237

local function imperial(): boolean
	return Config.UNITS ~= "metric"
end

-- "14.2 in" or "36.1 cm". decimals defaults to 1.
function Units.length(cm: number, decimals: number?): string
	local d = decimals or 1
	if imperial() then
		return string.format("%." .. d .. "f in", cm / CM_PER_IN)
	end
	return string.format("%." .. d .. "f cm", cm)
end

-- Under a pound: "6 oz". Under 10 pounds: "2 lb 5 oz". Bigger: "14.3 lb".
-- Metric: "0.17 kg" under 10 kg, "14.3 kg" above.
function Units.weight(kg: number): string
	if not imperial() then
		return if kg < 10 then string.format("%.2f kg", kg) else string.format("%.1f kg", kg)
	end
	local lb = kg / KG_PER_LB
	if lb >= 10 then
		return string.format("%.1f lb", lb)
	end
	local whole = math.floor(lb)
	local oz = math.floor((lb - whole) * 16 + 0.5)
	if oz == 16 then
		whole += 1
		oz = 0
	end
	if whole == 0 then
		return string.format("%d oz", math.max(1, oz))
	end
	if oz == 0 then
		return string.format("%d lb", whole)
	end
	return string.format("%d lb %d oz", whole, oz)
end

-- A goal's minimum length as a whole number, rounded up so the text never asks for more
-- than the goal needs: "at least 12 in".
function Units.atLeast(cm: number): string
	if imperial() then
		return string.format("%d in", math.ceil(cm / CM_PER_IN - 1e-9))
	end
	return string.format("%d cm", math.ceil(cm - 1e-9))
end

return Units
