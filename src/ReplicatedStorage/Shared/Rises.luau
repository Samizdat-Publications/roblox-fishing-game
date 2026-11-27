--!strict
-- Rises (L2b, "reasons to aim"): every so often a fish breaks the surface somewhere on the
-- water. Cast within RISE_RADIUS of it before its window closes and that fish is yours: a
-- bite comes in a couple of seconds. One player per rise. RiseService (server) runs the
-- timer and the claims with these rules; the client only draws the ripple.
-- Pure rules, no Roblox services. UNVERIFIED in Studio (written 2026-11-26).
local Shared = script.Parent
local FishLogic = require(Shared.FishLogic)
local Cover = require(Shared.Cover)

local Rises = {}

Rises.RISE_MIN = 14 -- seconds between rises, at least...
Rises.RISE_MAX = 26 -- ...and at most
Rises.RISE_WINDOW = 8 -- seconds a rise stays claimable
Rises.RISE_RADIUS = 5 -- flat studs: a cast this close to a rise claims it
Rises.RISE_BITE_MIN = 1.5 -- the claimed cast's bite comes in this many seconds...
Rises.RISE_BITE_MAX = 3.5 -- ...to this many
Rises.INSET = 1 -- keep rises this far inside their zone box
-- How often one player can actually reach a rise (most appear out of casting range). Not used by
-- the game; the economy sim (tools/econ/sim.py) reads it for an attentive player.
Rises.REACH_MIN = 90
Rises.REACH_MAX = 150

export type Rise = { pos: Vector3, zone: string, untilT: number, claimedBy: any? }
export type Zone = { name: string, cframe: CFrame, size: Vector3 }

function Rises.nextGap(rng: Random): number
	return rng:NextNumber(Rises.RISE_MIN, Rises.RISE_MAX)
end

function Rises.biteDelay(rng: Random): number
	return rng:NextNumber(Rises.RISE_BITE_MIN, Rises.RISE_BITE_MAX)
end

-- A random point for the next rise: a random fishing zone, a random spot in it that is on
-- the water and not on top of cover (a log, the dock, a boulder). Nil after a few misses.
-- zones and waters are WaterMap.castZones() and castWaters() (the Big Lake only when it's on).
function Rises.pickPoint(rng: Random, zones: { Zone }, waters: any): (Vector3?, string?)
	if #zones == 0 then
		return nil, nil
	end
	for _ = 1, 40 do
		local z = zones[rng:NextInteger(1, #zones)]
		local hx = math.max(z.size.X / 2 - Rises.INSET, 0)
		local hz = math.max(z.size.Z / 2 - Rises.INSET, 0)
		local local_ = Vector3.new(rng:NextNumber(-hx, hx), 0, rng:NextNumber(-hz, hz))
		local p = z.cframe:PointToWorldSpace(local_)
		p = Vector3.new(p.X, 0.2, p.Z)
		-- First zone match names the spot, so a point inside the dock's box counts as the dock.
		if FishLogic.isOnWaterAny(p, waters) and not Cover.onCover(p) and FishLogic.spotAt(p, zones) == z.name then
			return p, z.name
		end
	end
	return nil, nil
end

-- Drop rises whose window has closed.
function Rises.prune(list: { Rise }, now: number)
	for i = #list, 1, -1 do
		if now > list[i].untilT then
			table.remove(list, i)
		end
	end
end

-- A cast landed at `point`: claim the nearest open, unclaimed rise within RISE_RADIUS for
-- `who`. Returns the rise, or nil.
function Rises.claim(list: { Rise }, point: Vector3, now: number, who: any): Rise?
	local best: Rise? = nil
	local bestD = math.huge
	for _, r in list do
		if r.claimedBy == nil and now <= r.untilT then
			local d = Vector3.new(r.pos.X - point.X, 0, r.pos.Z - point.Z).Magnitude
			if d <= Rises.RISE_RADIUS and d < bestD then
				best, bestD = r, d
			end
		end
	end
	if best then
		best.claimedBy = who
	end
	return best
end

return Rises
