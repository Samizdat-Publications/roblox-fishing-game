--!strict
-- Today's real date, shared by everything that changes once a day: goals, the weather
-- forecast, the chalkboard and the shopkeeper's gift (L6d). Day numbers are UTC days since
-- 1970 (Goals.dayOf); every Roblox server agrees on os.time, so every server agrees on today.
-- Studio-only test hook: Workspace attribute DebugDayOffset (whole days) moves the date
-- forward, so "tomorrow" can be checked without waiting.
local RunService = game:GetService("RunService")
local Goals = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Goals)

local Today = {}

-- Now, in seconds (with the Studio day offset).
function Today.now(): number
	local offset = if RunService:IsStudio() then workspace:GetAttribute("DebugDayOffset") else nil
	return os.time() + (if type(offset) == "number" then math.floor(offset) * 86400 else 0)
end

-- Today's day number.
function Today.day(): number
	return Goals.dayOf(Today.now())
end

return Today
