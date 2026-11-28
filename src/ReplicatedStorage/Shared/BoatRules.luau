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
local Cover = require(Shared.Cover)

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
-- N4 review 1 (11/28/2026): 6.5 (was 5), so a boat at its slip can swing its stern without the
-- footprint check (below) finding the deck: the dinghy's 8.8 stud footprint then clears the deck's
-- edge (x 4) by more than OBSTACLE_CLEAR at any heading.
BoatRules.SLIP_X_EDGE = 6.5 -- the near end of each boat, 2.5 studs off the deck
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
--
-- The look-ahead stop (below) keeps 1.5 studs of water plus a quarter second of travel, and the
-- server's ray down also stops a boat where the real terrain bank rises out of the shallows,
-- which can be several studs before the map's water boxes end (11/28/2026, measured in Studio:
-- the east bank's terrain reaches the water line at x 106, the map says water to x 110). So the
-- server passes `isDry`, its own probe of the real ground (terrain at or above the water line),
-- searched up to 12 studs past the bow; the map's own shore still counts within 5 studs as
-- before. The first dry point either way wins.
BoatRules.BEACH_SPEED = 4
BoatRules.BEACH_REACH = 5 -- studs past the bow where the map's shore counts
BoatRules.BEACH_DRY_REACH = 12 -- studs past the bow where the server's ground probe counts
BoatRules.BEACH_STEP = 1 -- studs between probes
BoatRules.BEACH_UP = 2 -- riders step off this far up the bank from the first dry point

function BoatRules.beachAt(boatId: string, pos: Vector3, look: Vector3, speed: number, isDry: ((Vector3) -> boolean)?): Vector3?
	local b = assert(BoatData.byId[boatId], "unknown boat")
	if not Config.CANOE_ON or b.lands ~= "shore" or math.abs(speed) > BoatRules.BEACH_SPEED then
		return nil
	end
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-6 then
		return nil
	end
	flat = flat.Unit
	local reach = if isDry then math.max(BoatRules.BEACH_REACH, BoatRules.BEACH_DRY_REACH) else BoatRules.BEACH_REACH
	local k = BoatRules.BEACH_STEP
	while k <= reach + 1e-6 do
		local probe = Vector3.new(pos.X, BoatRules.WATER_Y, pos.Z) + flat * (b.length / 2 + k)
		local mapShore = k <= BoatRules.BEACH_REACH + 1e-6 and not BoatRules.isBoatWater(probe)
		if mapShore or (isDry ~= nil and isDry(probe)) then
			return probe + flat * BoatRules.BEACH_UP
		end
		k += BoatRules.BEACH_STEP
	end
	return nil
end

-- Stopping short of the shore (the N4 playtest, 11/28/2026): a boat driven at a bank or a log
-- used to ride up it and tilt. Now the server looks ahead along the way the boat is moving
-- (the bow going forward, the stern in reverse) and stops it while there is still water
-- between it and whatever is ahead. Steering still works when stopped (BoatLogic.idleTurn).
BoatRules.STOP_CLEAR = 1.5 -- studs of water always kept between the bow (or stern) and the obstacle
BoatRules.STOP_LOOK = 0.25 -- plus this many seconds of travel at the boat's speed
BoatRules.OBSTACLE_CLEAR = 0.6 -- a probe this close to a log or the dock counts as hitting it

-- The points checked ahead of a moving boat: the middle of its leading end and its two
-- corners, pushed out by STOP_CLEAR plus STOP_LOOK seconds of travel. None when it is still.
function BoatRules.probes(boatId: string, pos: Vector3, look: Vector3, speed: number): { Vector3 }
	local b = assert(BoatData.byId[boatId], "unknown boat")
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-6 or math.abs(speed) < 1e-3 then
		return {}
	end
	flat = flat.Unit
	local dir = if speed > 0 then flat else -flat
	local side = Vector3.new(-flat.Z, 0, flat.X)
	local reach = BoatRules.STOP_CLEAR + math.abs(speed) * BoatRules.STOP_LOOK
	local centre = Vector3.new(pos.X, BoatRules.WATER_Y, pos.Z)
	local tip = centre + dir * (b.length / 2 + reach)
	local edge = centre + dir * (b.length / 2 + reach * 0.5)
	return { tip, edge + side * (b.width / 2), edge - side * (b.width / 2) }
end

-- What a boat would hit at this point: "shore" (off the water), "log", "dock", "water" (water
-- this boat may not use, with the reason) or nil when it is clear.
function BoatRules.blockedAt(boatId: string, point: Vector3): (string?, string?)
	if not BoatRules.isBoatWater(point) then
		return "shore", nil
	end
	for _, f in Cover.features do
		-- A log only where it is above the water line (Cover.boatEdgeDistance, N4 review 1).
		if (f.kind == "Log" or f.kind == "Dock") and Cover.boatEdgeDistance(f, point) <= BoatRules.OBSTACLE_CLEAR then
			return string.lower(f.kind), nil
		end
	end
	local ok, msg = BoatRules.mayBeAt(boatId, point)
	if not ok then
		return "water", msg
	end
	return nil, nil
end

-- Should this boat stop now? The first thing ahead (see blockedAt) and what to tell the driver.
function BoatRules.stopAhead(boatId: string, pos: Vector3, look: Vector3, speed: number): (string?, string?)
	for _, p in BoatRules.probes(boatId, pos, look, speed) do
		local kind, msg = BoatRules.blockedAt(boatId, p)
		if kind then
			return kind, BoatRules.stopText(boatId, kind, msg)
		end
	end
	return nil, nil
end

-- The whole hull, not only what is ahead (N4 review 1): the look-ahead only looks past the leading
-- end, so a stern swinging in a turn went under the dock deck. Each frame the server tests the
-- boat's next pose (FOOTPRINT_LOOK seconds on) all round: 8 points on a box FOOTPRINT_PAD times the
-- boat's length and width (the dinghy's 8 by 4 is 8.8 by 4.4), against the shore, the dock, logs
-- above the water and (the server's own probe) anything else solid. The turn and the move are
-- tested apart, so a boat that may not turn can still go straight, and one that may not go on can
-- still turn. A pose is refused only if it touches more than the boat touches now, so a boat that
-- is already against something can always get out.
BoatRules.FOOTPRINT_PAD = 1.1
BoatRules.FOOTPRINT_LOOK = 0.1 -- seconds of travel and turn the next pose is taken at

-- The 8 points round a boat's footprint at this place and heading: the four corners, the middle of
-- the bow and the stern, and the middle of each side.
function BoatRules.footprint(boatId: string, pos: Vector3, look: Vector3): { Vector3 }
	local b = assert(BoatData.byId[boatId], "unknown boat")
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-6 then
		flat = Vector3.new(0, 0, -1)
	end
	flat = flat.Unit
	local side = Vector3.new(-flat.Z, 0, flat.X)
	local hl = b.length * BoatRules.FOOTPRINT_PAD / 2
	local hw = b.width * BoatRules.FOOTPRINT_PAD / 2
	local c = Vector3.new(pos.X, BoatRules.WATER_Y, pos.Z)
	local out = {}
	for _, u in { { 1, 1 }, { 1, 0 }, { 1, -1 }, { 0, 1 }, { 0, -1 }, { -1, 1 }, { -1, 0 }, { -1, -1 } } do
		table.insert(out, c + flat * (u[1] * hl) + side * (u[2] * hw))
	end
	return out
end

-- How many footprint points touch something, and the first thing touched: the shore, the dock or a
-- log (blockedAt's kinds; water a boat may not use is the half-second check's job), or what the
-- optional `solid` probe says ("shore" for terrain, "thing" for a part).
function BoatRules.footprintHits(boatId: string, pos: Vector3, look: Vector3, solid: ((Vector3) -> string?)?): (number, string?)
	local n, first = 0, nil
	for _, p in BoatRules.footprint(boatId, pos, look) do
		local kind = BoatRules.blockedAt(boatId, p)
		if kind == "water" then
			kind = nil
		end
		if not kind and solid then
			kind = solid(p)
		end
		if kind then
			n += 1
			first = first or kind
		end
	end
	return n, first
end

-- May the boat turn and may it move this frame? From its place, heading (yaw, radians about +Y, as
-- CFrame.fromOrientation), speed (studs a second along the bow) and spin (radians a second about
-- +Y, BoatRules.spinY). Returns moveOk, turnOk, and the thing in the way (nil when both are fine).
function BoatRules.poseCheck(boatId: string, pos: Vector3, yaw: number, speed: number, spin: number, solid: ((Vector3) -> string?)?): (boolean, boolean, string?)
	local t = BoatRules.FOOTPRINT_LOOK
	local look = CFrame.fromOrientation(0, yaw, 0).LookVector
	local moving = math.abs(speed) > 1e-3
	local turning = math.abs(spin) > 1e-4
	if not moving and not turning then
		return true, true, nil
	end
	local now = BoatRules.footprintHits(boatId, pos, look, solid)
	local moveOk, turnOk, why = true, true, nil
	if moving then
		local flat = Vector3.new(look.X, 0, look.Z).Unit
		local n, kind = BoatRules.footprintHits(boatId, pos + flat * (speed * t), look, solid)
		if n > now then
			moveOk, why = false, kind
		end
	end
	if turning then
		local turned = CFrame.fromOrientation(0, yaw + spin * t, 0).LookVector
		local n, kind = BoatRules.footprintHits(boatId, pos, turned, solid)
		if n > now then
			turnOk = false
			why = why or kind
		end
	end
	return moveOk, turnOk, why
end

-- The toast for a stop. "thing" is anything else solid the server's own look finds.
function BoatRules.stopText(boatId: string, kind: string, msg: string?): string
	local b = assert(BoatData.byId[boatId], "unknown boat")
	if kind == "shore" then
		if Config.CANOE_ON and b.lands == "shore" then
			return "Shore ahead. Turn the boat, or land here."
		end
		return "Shore ahead. Turn the boat."
	elseif kind == "log" then
		return "A log is in the way. Turn the boat."
	elseif kind == "dock" then
		return "The dock is in the way. Turn the boat."
	elseif kind == "water" then
		return msg or "The boat can't go there."
	end
	return "Something is in the way. Turn the boat."
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
