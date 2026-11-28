--!strict
-- Pure boat rules: buying, how input turns into speed and turning, the server's sanity
-- check on where a boat went, casting from a boat and docking. No Roblox services here.
-- Written overnight 2026-11-26; buying, driving and casting proven in Studio 11/27/2026 (L7).
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
	if not b or not BoatData.onSale(b) then
		return false, "That boat isn't for sale yet."
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

-- Pick which owned boat waits at your slip (the boathouse's "Your boat" board, N4, and the
-- shop's "Use this boat"). Sets data.boat (saved) when it is allowed. Whether the current boat is
-- out on the water with someone aboard is the server's check (BoatService), not this one.
function BoatLogic.choose(data: any, id: any): (boolean, string)
	local b = if type(id) == "string" then BoatData.byId[id] else nil
	if not b then
		return false, "That isn't one of your boats."
	end
	if not BoatLogic.owns(data, b.id) then
		return false, "You don't own the " .. b.name .. " yet."
	end
	if not BoatData.available(b) then
		return false, "The " .. b.name .. " isn't on the water yet."
	end
	if data.boat == b.id then
		return false, "Your " .. b.name .. " is already at your slip."
	end
	data.boat = b.id
	return true, "Your " .. b.name .. " will be waiting at your slip."
end

-- Top speed now: a paddled boat with a second paddler aboard goes faster (the canoe, 7 to 11).
function BoatLogic.topSpeed(boatId: string, paddlers: number?): number
	local b = assert(BoatData.byId[boatId], "unknown boat")
	if b.paddle and (paddlers or 1) >= 2 then
		return b.pairSpeed
	end
	return b.maxSpeed
end

-- The fastest this boat can ever go (the server's move check allows for it).
function BoatLogic.fastest(boatId: string): number
	local b = assert(BoatData.byId[boatId], "unknown boat")
	return math.max(b.maxSpeed, b.pairSpeed or 0)
end

-- Advance the boat's motion by dt seconds from throttle and steer (-1 to 1 each, like a
-- VehicleSeat's ThrottleFloat and SteerFloat). Exact easing, so frame rate doesn't matter.
-- paddlers: people paddling a paddled boat (1 when left out).
function BoatLogic.step(m: Motion, boatId: string, throttle: any, steer: any, dt: number, paddlers: number?): Motion
	local b = assert(BoatData.byId[boatId], "unknown boat")
	local th = clampInput(throttle)
	local st = clampInput(steer)
	local top = BoatLogic.topSpeed(boatId, paddlers)
	local target = if th >= 0 then th * top else th * b.reverseSpeed
	local speed = target + (m.speed - target) * math.exp(-b.accel * math.max(dt, 0))
	-- Turning needs water moving past the rudder, but a little works at a standstill so
	-- nobody gets stuck nose-in to the shore.
	local moving = math.clamp(math.abs(speed) / top, 0, 1)
	local turnShare = b.idleTurn + (1 - b.idleTurn) * moving
	local dir = if speed < -0.5 then -1 else 1 -- steering flips in reverse, like a real boat
	return { speed = speed, yawRate = st * b.turnRate * turnShare * dir }
end

-- Server check on a boat's movement between two checks (the server owns the boat's physics
-- and drives it from the helm's input). Allows a little slack; anything faster is a glitch.
function BoatLogic.moveOk(fromPos: Vector3, toPos: Vector3, dt: number, boatId: string): boolean
	local b = BoatData.byId[boatId]
	if not b or dt <= 0 then
		return false
	end
	local flat = Vector3.new(toPos.X - fromPos.X, 0, toPos.Z - fromPos.Z)
	return flat.Magnitude <= BoatLogic.fastest(boatId) * 1.3 * dt + 2
end

-- Will the boat move? A two-person boat needs its whole crew aboard.
function BoatLogic.canDrive(boatId: string, aboard: number): (boolean, string?)
	local b = assert(BoatData.byId[boatId], "unknown boat")
	if aboard < b.crew then
		return false, string.format("The %s needs %d people aboard. Get a friend to hop in.", b.name, b.crew)
	end
	return true, nil
end

-- May this boat be in blue water? Small boats are turned back at the edge.
function BoatLogic.canEnterBlueWater(boatId: string): (boolean, string?)
	local b = assert(BoatData.byId[boatId], "unknown boat")
	if not b.blueWater then
		return false, "The " .. b.name .. " is too small for blue water. Turn back toward the shore."
	end
	return true, nil
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

-- How many are paddling: everyone aboard a paddled boat paddles (a seat each); none on a motor boat.
function BoatLogic.paddlers(boatId: string, aboard: number): number
	local b = assert(BoatData.byId[boatId], "unknown boat")
	return if b.paddle then math.clamp(aboard, 0, b.seats) else 0
end

-- The bottom hint for someone sitting in a boat (N4 review 1): at the helm and moving faster than
-- the boat may cast from, the drive keys for this input ("mouse" for a keyboard, "gamepad",
-- "touch"); a rider under way, when to cast; stopped (or slow enough) in any seat, the cast line without "Face the water" (a boat
-- can't turn round to face it the way a player on foot does). `castWith` names the cast input
-- ("click", "R2", "the Fish button"). Nil when not in a boat (boatId nil): the usual line.
function BoatLogic.seatHint(boatId: string?, atHelm: boolean, speed: number, kind: string, castWith: string): string?
	if not boatId then
		return nil
	end
	local b = BoatData.byId[boatId]
	if not b then
		return nil
	end
	if atHelm and math.abs(speed) > b.castSpeed then
		if kind == "touch" then
			return "Steer with the thumbstick. Slow down to cast."
		elseif kind == "gamepad" then
			return "Left stick to steer and go. Slow down to cast."
		end
		return "W and S to go, A and D to steer. Slow down to cast."
	elseif math.abs(speed) > b.castSpeed then
		return "Cast when the boat slows down." -- a rider under way (the builder's wording)
	end
	return "Hold " .. castWith .. " and let go to cast."
end

return BoatLogic
