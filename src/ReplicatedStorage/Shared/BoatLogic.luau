--!strict
-- Pure boat rules: buying, how input turns into speed and turning, the server's sanity
-- check on where a boat went, casting from a boat and docking. No Roblox services here.
-- UNVERIFIED: written overnight 2026-11-26 without Studio; nothing uses this yet.
local Shared = script.Parent
local BoatData = require(Shared.BoatData)

local BoatLogic = {}

export type Motion = {
	speed: number, -- studs per second along the bow (negative is reverse)
	yawRate: number, -- degrees per second (positive turns right)
}

local function clampInput(x: any): number
	if type(x) ~= "number" or x ~= x then
		return 0
	end
	return math.clamp(x, -1, 1)
end

-- Buy a boat. Owning one is saved; the boat itself waits at the slip each session.
function BoatLogic.buy(data: any, id: string): (boolean, string)
	local b = BoatData.byId[id]
	if not b then
		return false, "That boat isn't for sale."
	end
	data.boats = data.boats or {}
	if data.boats[id] then
		return false, "You already own the " .. b.name .. "."
	end
	if data.coins < b.price then
		return false, "Not enough coins. The " .. b.name .. " costs " .. b.price .. "."
	end
	data.coins -= b.price
	data.boats[id] = true
	return true, "Bought the " .. b.name .. "! It's waiting at the boat slip by the dock."
end

function BoatLogic.owns(data: any, id: string): boolean
	return type(data.boats) == "table" and data.boats[id] == true
end

-- Advance the boat's motion by dt seconds from throttle and steer (-1 to 1 each, like a
-- VehicleSeat's ThrottleFloat and SteerFloat). Exact easing, so frame rate doesn't matter.
function BoatLogic.step(m: Motion, boatId: string, throttle: any, steer: any, dt: number): Motion
	local b = assert(BoatData.byId[boatId], "unknown boat")
	local th = clampInput(throttle)
	local st = clampInput(steer)
	local target = if th >= 0 then th * b.maxSpeed else th * b.reverseSpeed
	local speed = target + (m.speed - target) * math.exp(-b.accel * math.max(dt, 0))
	-- Turning needs water moving past the rudder, but a little works at a standstill so
	-- nobody gets stuck nose-in to the shore.
	local moving = math.clamp(math.abs(speed) / b.maxSpeed, 0, 1)
	local turnShare = b.idleTurn + (1 - b.idleTurn) * moving
	local dir = if speed < -0.5 then -1 else 1 -- steering flips in reverse, like a real boat
	return { speed = speed, yawRate = st * b.turnRate * turnShare * dir }
end

-- Server check on a driver's reported movement (the driver owns the boat's physics so it
-- feels smooth). Allows a little slack for lag; anything faster is a cheat or a glitch.
function BoatLogic.moveOk(fromPos: Vector3, toPos: Vector3, dt: number, boatId: string): boolean
	local b = BoatData.byId[boatId]
	if not b or dt <= 0 then
		return false
	end
	local flat = Vector3.new(toPos.X - fromPos.X, 0, toPos.Z - fromPos.Z)
	return flat.Magnitude <= b.maxSpeed * 1.3 * dt + 2
end

-- Casting from a boat: only when it is nearly stopped (no trolling at full speed).
function BoatLogic.canCast(speed: number, boatId: string): (boolean, string?)
	local b = assert(BoatData.byId[boatId], "unknown boat")
	if math.abs(speed) > b.castSpeed then
		return false, "Slow the boat down to cast."
	end
	return true, nil
end

-- Docking: close enough to the slip and slow enough snaps the boat into place.
function BoatLogic.canDock(pos: Vector3, slip: Vector3, speed: number): boolean
	local flat = Vector3.new(pos.X - slip.X, 0, pos.Z - slip.Z)
	return flat.Magnitude <= 10 and math.abs(speed) <= 4
end

return BoatLogic
