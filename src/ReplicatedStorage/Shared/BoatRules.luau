--!strict
-- Where boats live and where they may go: the slips by the dock, the channel north to the
-- Big Lake, its island, the buoy line and the blue water beyond it. Also the server's
-- per-check verdict on a moving boat and the extra casting rules on the water.
-- Pure data and checks, no Roblox services, so it runs in tests outside Studio.
-- Written 2026-11-26 in the cloud; the Big Lake's shape moved into Shore on 11/27/2026 (L7).
local Shared = script.Parent
local BoatData = require(Shared.BoatData)
local BoatLogic = require(Shared.BoatLogic)
local Config = require(Shared.Config)
local Shore = require(Shared.Shore)

local BoatRules = {}

export type Box = { cframe: CFrame, size: Vector3 }
export type Zone = { name: string, cframe: CFrame, size: Vector3 }

-- The water's surface. The lake's terrain water is filled up to y = 0 (WorldBuilder).
BoatRules.WATER_Y = 0

-- Water boxes use the same shape as WorldBuilder.waters(): centred half a stud down, 1 tall.
local function box(x1: number, z1: number, x2: number, z2: number): Box
	return { cframe = CFrame.new((x1 + x2) / 2, -0.5, (z1 + z2) / 2), size = Vector3.new(x2 - x1, 1, z2 - z1) }
end

local function zone(name: string, x1: number, z1: number, x2: number, z2: number): Zone
	return { name = name, cframe = CFrame.new((x1 + x2) / 2, 0, (z1 + z2) / 2), size = Vector3.new(x2 - x1, 10, z2 - z1) }
end

local function inBox(pos: Vector3, b: Box): boolean
	local p = b.cframe:PointToObjectSpace(pos)
	return math.abs(p.X) <= b.size.X / 2 and math.abs(p.Z) <= b.size.Z / 2
end

-- The map (studs). The lake is x -110..110, z -80..80; north of it is GroundNorth, z -80..-140.
BoatRules.LAKE = box(-110, -80, 110, 80)
BoatRules.CHANNEL = box(-15, -142, 15, -78) -- a 30 stud cut through the north shore
BoatRules.BIG_LAKE = box(-200, -440, 200, -140) -- about 400 x 300
-- The island's bounds. Its real outline (three circles) and the Big Lake's rounded corners
-- and headlands are in Shore, which every "is this water?" check asks first.
BoatRules.ISLAND = box(-111, -255, -66, -225)
BoatRules.BUOY_Z = -290 -- the line of orange buoys; north of it (smaller z) is blue water
BoatRules.BLUE_WATER = box(-200, -440, 200, -290)

-- The Big Lake's water box (Shore carves the island and the banks out of it).
local BIG_LAKE_WATER: { Box } = { BoatRules.BIG_LAKE }

-- Fishing spots on the Big Lake. Order matters: the island point is checked before the basin.
BoatRules.ZONES = {
	zone("IslandPoint", -70, -258, -40, -222), -- the weedy east tip of the island
	zone("Basin", -200, -290, 200, -140), -- the open near half, dinghy water
	zone("DropOff", -200, -440, 200, -290), -- the blue water, Deep-V only
} :: { Zone }

BoatRules.BOAT_SPOTS = { Basin = true, IslandPoint = true, DropOff = true }

BoatRules.SPOT_NAMES = {
	Basin = "the open basin",
	IslandPoint = "the island point",
	DropOff = "the blue-water drop-off",
}

-- Boat slips: on the east side of the dock walkway (the deck is x -4..4, z 35..81). Boats
-- lie side by side with the bow pointing east, out into the lake.
BoatRules.SLIP_X_EDGE = 5 -- the near end of each boat, one stud off the deck
BoatRules.SLIP_ZS = { 47, 56, 65, 74 }

-- Every box a boat may be over: the lake, the channel and the Big Lake around the island.
function BoatRules.waters(): { Box }
	local out = { BoatRules.LAKE, BoatRules.CHANNEL }
	for _, b in BIG_LAKE_WATER do
		table.insert(out, b)
	end
	return out
end

-- Water boxes a cast may land in that the lake's own list doesn't have yet.
function BoatRules.extraCastWaters(): { Box }
	local out = { BoatRules.CHANNEL }
	for _, b in BIG_LAKE_WATER do
		table.insert(out, b)
	end
	return out
end

function BoatRules.isBoatWater(pos: Vector3): boolean
	if Shore.isLand(pos) then
		return false
	end
	for _, b in BoatRules.waters() do
		if inBox(pos, b) then
			return true
		end
	end
	return false
end

-- The channel and the Big Lake: places you can only fish from a boat.
function BoatRules.needsBoat(pos: Vector3): boolean
	return inBox(pos, BoatRules.CHANNEL) or inBox(pos, BoatRules.BIG_LAKE)
end

function BoatRules.inBlueWater(pos: Vector3): boolean
	return inBox(pos, BoatRules.BLUE_WATER)
end

-- Where a boat sits at slip i: centred so its stern is at the slip edge, bow east.
function BoatRules.slipCFrame(i: number, boatId: string): CFrame
	local b = assert(BoatData.byId[boatId], "unknown boat")
	local z = assert(BoatRules.SLIP_ZS[i], "no such slip")
	local p = Vector3.new(BoatRules.SLIP_X_EDGE + b.length / 2, BoatRules.WATER_Y, z)
	return CFrame.lookAt(p, p + Vector3.new(1, 0, 0))
end

-- The fleet's waters (leg 3, N4, behind Config.CANOE_ON). Each boat lists the waters it may be
-- on (BoatData.waters). Paddle-only places refuse a motor. Lily Cove, a paddle-only cove on the
-- Big Lake's west shore, comes with the bigger lake in N5: it is added to PADDLE_ONLY then, and
-- the refusal below already applies to it.
BoatRules.PADDLE_ONLY = {} :: { Zone }
BoatRules.LILY_TEXT = "Too shallow and weedy for a motor. Paddle in."

function BoatRules.paddleOnlyAt(pos: Vector3): Zone?
	for _, z in BoatRules.PADDLE_ONLY do
		if inBox(pos, z) then
			return z
		end
	end
	return nil
end

-- The named water at a point: "LilyCove" (any paddle-only cove), "BlueWater", "Basin" (the
-- rest of the Big Lake), "Channel" or "Lake"; nil off the water.
function BoatRules.waterAt(pos: Vector3): string?
	if not BoatRules.isBoatWater(pos) then
		return nil
	end
	if BoatRules.paddleOnlyAt(pos) then
		return "LilyCove"
	end
	if BoatRules.inBlueWater(pos) then
		return "BlueWater"
	end
	if inBox(pos, BoatRules.BIG_LAKE) then
		return "Basin"
	end
	if inBox(pos, BoatRules.CHANNEL) then
		return "Channel"
	end
	return "Lake"
end

-- May this boat be here? Off the water, never. With the fleet switch off every boat may go
-- anywhere on the water as in L7 (blue water is still turned back by check below).
function BoatRules.mayBeAt(boatId: string, pos: Vector3): (boolean, string?)
	local b = assert(BoatData.byId[boatId], "unknown boat")
	local w = BoatRules.waterAt(pos)
	if not w then
		return false, nil
	end
	if not Config.CANOE_ON then
		return true, nil
	end
	if w == "LilyCove" and not b.paddle then
		return false, BoatRules.LILY_TEXT
	end
	if w == "BlueWater" then
		return true, nil -- check() turns small boats back at the buoy line with its own words
	end
	if not b.waters[w] then
		return false, "The " .. b.name .. " can't go there."
	end
	return true, nil
end

-- Landing on a shore (the fleet, CANOE_ON): a boat that lands on shores, slow enough, with dry
-- land within a few studs of its bow. Returns where its riders step off, or nil.
BoatRules.BEACH_SPEED = 4
BoatRules.BEACH_REACH = 5 -- studs past the bow that are searched for dry land

function BoatRules.beachAt(boatId: string, pos: Vector3, look: Vector3, speed: number): Vector3?
	local b = assert(BoatData.byId[boatId], "unknown boat")
	if not Config.CANOE_ON or b.lands ~= "shore" or math.abs(speed) > BoatRules.BEACH_SPEED then
		return nil
	end
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-6 then
		return nil
	end
	flat = flat.Unit
	for k = 1, BoatRules.BEACH_REACH do
		local probe = Vector3.new(pos.X, BoatRules.WATER_Y, pos.Z) + flat * (b.length / 2 + k)
		if not BoatRules.isBoatWater(probe) then
			return probe + flat * 2 -- two studs up the bank
		end
	end
	return nil
end

-- The first free slip, or nil when every slip is taken.
function BoatRules.nextFreeSlip(taken: { [number]: boolean }): number?
	for i = 1, #BoatRules.SLIP_ZS do
		if not taken[i] then
			return i
		end
	end
	return nil
end

-- The server's check on a boat every half second.
-- "ok": fine, remember this spot. "back": off the water or moved too far (a cheat, a glitch
-- or a crash onto land), or into water this boat may not use (the fleet): put it back at its
-- last good spot. "turn": a small boat crossed the buoy line: push it back to just south of
-- the line, facing home. The third value is what to tell the driver, when there is a reason.
function BoatRules.check(boatId: string, lastGood: Vector3, pos: Vector3, dt: number): (string, Vector3?, string?)
	if not BoatRules.isBoatWater(pos) or not BoatLogic.moveOk(lastGood, pos, dt, boatId) then
		return "back", lastGood, nil
	end
	if BoatRules.inBlueWater(pos) and not BoatLogic.canEnterBlueWater(boatId) then
		local _, msg = BoatLogic.canEnterBlueWater(boatId)
		return "turn", Vector3.new(pos.X, pos.Y, BoatRules.BUOY_Z + 8), msg
	end
	local ok, msg = BoatRules.mayBeAt(boatId, pos)
	if not ok then
		return "back", lastGood, msg
	end
	return "ok", nil, nil
end

-- Extra casting rules on the water. boatId is the boat the caster sits in (nil if on foot),
-- speed is that boat's speed on the server.
function BoatRules.castCheck(landing: Vector3, boatId: string?, speed: number): (boolean, string?)
	if boatId then
		local ok, msg = BoatLogic.canCast(speed, boatId)
		if not ok then
			return false, msg
		end
	end
	if BoatRules.needsBoat(landing) and not boatId then
		return false, "You need a boat to fish the Big Lake."
	end
	if BoatRules.inBlueWater(landing) then
		local b = boatId and BoatData.byId[boatId]
		if not (b and b.blueWater) then
			return false, "Blue water needs a bigger boat than this one."
		end
	end
	return true, nil
end

-- How the movers should push: flat velocity along the bow and spin around the vertical.
-- Positive yawRate turns right (clockwise seen from above), which is negative around +Y.
function BoatRules.planeVelocity(look: Vector3, speed: number): (number, number)
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-6 then
		return 0, 0
	end
	flat = flat.Unit
	return flat.X * speed, flat.Z * speed
end

function BoatRules.spinY(yawRate: number): number
	return -math.rad(yawRate)
end

-- A boat with too few aboard drifts slowly south, so a Deep-V left with one player in blue
-- water comes back to the buoy line instead of stranding them.
BoatRules.DRIFT_SPEED = 4

function BoatRules.drift(boatId: string, pos: Vector3, aboard: number): (number, number)
	local b = assert(BoatData.byId[boatId], "unknown boat")
	if aboard < b.crew and BoatRules.inBlueWater(pos) then
		return 0, BoatRules.DRIFT_SPEED
	end
	return 0, 0
end

return BoatRules
