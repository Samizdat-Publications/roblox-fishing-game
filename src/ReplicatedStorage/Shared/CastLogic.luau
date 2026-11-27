--!strict
-- Where a cast lands. The client's landing ring and the server's real cast both use this,
-- so what the player sees is what they get. Pure math, no Roblox services.
--
-- While the button is held a ring travels out from CAST_MIN to the rod's full reach and
-- back again at a steady RING_SPEED; let go when it sits where you want.
local Shared = script.Parent
local Config = require(Shared.Config)
local RodData = require(Shared.RodData)
local BaitData = require(Shared.BaitData)

local CastLogic = {}

CastLogic.RING_SPEED = 16 -- studs per second the ring travels while held
CastLogic.ACCEPT = 2 -- the server takes the client's landing if it is this close (flat studs) to its own
CastLogic.LAND_Y = 0.3 -- height of the bobber on the water
CastLogic.ASSIST_MAX = 3 -- near-miss help: how far back toward the caster a dry landing may slide
CastLogic.ASSIST_STEP = 0.5

-- The extra reach above CAST_MIN for this rod and bait at full power.
function CastLogic.range(rodId: string?, baitId: string?): number
	local rod = RodData.byId[rodId or ""] or RodData.byId.Willow
	local bait = BaitData.byId[baitId or ""]
	local mult = (bait and bait.castMult) or 1
	return (Config.CAST_RANGE + rod.castBonus) * mult
end

-- Power (0..1) after holding for this long: a triangle wave, out then back, so the ring
-- moves at RING_SPEED studs per second the whole time.
function CastLogic.powerAt(heldSeconds: number, rodId: string?, baitId: string?): number
	local range = CastLogic.range(rodId, baitId)
	if range <= 0 or heldSeconds <= 0 then
		return 0
	end
	local half = range / CastLogic.RING_SPEED -- seconds from soft to full
	local t = heldSeconds % (2 * half)
	if t <= half then
		return t / half
	end
	return (2 * half - t) / half
end

-- How far the cast flies (studs) at this power.
function CastLogic.distance(power: number, rodId: string?, baitId: string?): number
	return Config.CAST_MIN + math.clamp(power, 0, 1) * CastLogic.range(rodId, baitId)
end

-- The landing point on the water, along the flat direction `dir` from `origin`. Nil when
-- the direction has no flat part (the caller picks a fallback direction).
function CastLogic.landing(origin: Vector3, dir: Vector3, power: number, rodId: string?, baitId: string?): Vector3?
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.01 then
		return nil
	end
	local p = origin + flat.Unit * CastLogic.distance(power, rodId, baitId)
	return Vector3.new(p.X, CastLogic.LAND_Y, p.Z)
end

-- Near-miss help: a landing on dry ground slides back toward the caster along the cast line,
-- half a stud at a time up to ASSIST_MAX, onto the first water it finds. Returns the landing
-- unchanged when it is already on water, nil when no water is close enough.
-- isOnWater is FishLogic.isOnWaterAny (passed in so this stays testable).
function CastLogic.assist(landing: Vector3, origin: Vector3, waters: any, isOnWater: (Vector3, any) -> boolean): Vector3?
	if isOnWater(landing, waters) then
		return landing
	end
	local back = Vector3.new(origin.X - landing.X, 0, origin.Z - landing.Z)
	if back.Magnitude < 0.01 then
		return nil
	end
	back = back.Unit
	local steps = math.floor(CastLogic.ASSIST_MAX / CastLogic.ASSIST_STEP + 0.5)
	for i = 1, steps do
		local p = landing + back * (i * CastLogic.ASSIST_STEP)
		if isOnWater(p, waters) then
			return Vector3.new(p.X, CastLogic.LAND_Y, p.Z)
		end
	end
	return nil
end

-- Flat (x, z) distance between two points.
function CastLogic.flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

return CastLogic
