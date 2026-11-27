--!strict
-- Rises (L2b): every RISE_MIN to RISE_MAX seconds a fish breaks the surface at a random
-- point on the water. Every client sees the ripple; the first cast within RISE_RADIUS before
-- the window closes claims it, and FishingService gives that cast a quick bite.
-- Rules in Shared/Rises.luau. UNVERIFIED in Studio (written 2026-11-26).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Rises = require(Shared.Rises)
local WaterMap = require(Shared.WaterMap)

local RiseService = {}

local active: { Rises.Rise } = {}
local rng = Random.new()
local started = false

-- A cast landed here: claim an open rise for this player. True when one was claimed.
function RiseService.claim(player: Player, point: Vector3): boolean
	local now = workspace:GetServerTimeNow()
	Rises.prune(active, now)
	return Rises.claim(active, point, now, player) ~= nil
end

-- Studio testing: a rise right here, now (returns its position).
function RiseService.debugRise(pos: Vector3): Vector3
	local now = workspace:GetServerTimeNow()
	local p = Vector3.new(pos.X, 0.2, pos.Z)
	table.insert(active, { pos = p, zone = "Debug", untilT = now + Rises.RISE_WINDOW })
	Remotes.event("FishingEvent"):FireAllClients("Rise", { pos = p, ["until"] = now + Rises.RISE_WINDOW })
	return p
end

function RiseService.start()
	if started then
		return
	end
	started = true
	local fishingEvent = Remotes.event("FishingEvent")
	-- The lake and the creek, plus the Big Lake when it's switched on.
	local zones = WaterMap.castZones()
	local waters = WaterMap.castWaters()
	task.spawn(function()
		while true do
			task.wait(Rises.nextGap(rng))
			local now = workspace:GetServerTimeNow()
			Rises.prune(active, now)
			local pos, zone = Rises.pickPoint(rng, zones, waters)
			if pos and zone then
				local untilT = now + Rises.RISE_WINDOW
				table.insert(active, { pos = pos, zone = zone, untilT = untilT })
				fishingEvent:FireAllClients("Rise", { pos = pos, ["until"] = untilT }) -- workspace:GetServerTimeNow() time
			end
		end
	end)
	print("[Rises] ready")
end

return RiseService
