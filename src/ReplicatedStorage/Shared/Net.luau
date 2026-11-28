--!strict
-- The landing net (leg 3, N4, Config.NET_ON): "better with two", on boats and docks alike.
-- When someone within 10 studs has a fish at 70 percent or more, you get "Net it". The fish
-- comes up to the surface every few seconds; a press while it is up lands it. A press while it
-- is down misses, costs nothing, and you can try again 2 seconds later.
--
-- The fight runs on the angler's screen (FightModel), so the server only hears its progress.
-- It believes a report only when the fish could really be that far in by now: never faster
-- than FightModel's fastest possible win (its Tight drag time, less the same 10 percent slack
-- the server gives a win). Pure: the server keeps the state and the clock.
local Net = {}

Net.RANGE = 10 -- studs from the helper to the angler
Net.RANGE_SLACK = 3 -- the server allows this much extra (the two characters move)
Net.THRESHOLD = 0.7 -- progress at which the net comes out
Net.DROP = 0.66 -- below this the chance closes again (no flicker right at 70 percent)
Net.RETRY = 2 -- seconds after a miss before another press counts
Net.FIRST_UP = 1.2 -- seconds after the chance opens that the fish first surfaces
Net.UP_EVERY = 2.6 -- seconds between surfacings
Net.UP_FOR = 0.8 -- seconds it stays up
Net.SLACK = 0.25 -- a press this late after it goes down still counts (the round trip)

-- Is the fish up at `now`, for a chance opened at `openedAt`? Also the clock of the next
-- time it comes up (the current surfacing's start if it is up now).
function Net.surfacing(openedAt: number, now: number): (boolean, number)
	local t = now - openedAt - Net.FIRST_UP
	if t < 0 then
		return false, openedAt + Net.FIRST_UP
	end
	local k = math.floor(t / Net.UP_EVERY)
	local into = t - k * Net.UP_EVERY
	local start = openedAt + Net.FIRST_UP + k * Net.UP_EVERY
	if into <= Net.UP_FOR then
		return true, start
	end
	return false, start + Net.UP_EVERY
end

-- Does a press at `now` count (with the late slack for the round trip)?
function Net.pressHits(openedAt: number, now: number): boolean
	local up = Net.surfacing(openedAt, now)
	if up then
		return true
	end
	return (Net.surfacing(openedAt, now - Net.SLACK))
end

export type Helper = { lastMiss: number? }

-- One press by a helper: "landed", "missed" (try again in RETRY seconds) or "wait" (pressed
-- again too soon after a miss: ignored, nothing changes).
function Net.press(h: Helper, openedAt: number, now: number): string
	if h.lastMiss and now - (h.lastMiss :: number) < Net.RETRY then
		return "wait"
	end
	if Net.pressHits(openedAt, now) then
		return "landed"
	end
	h.lastMiss = now
	return "missed"
end

-- The most progress the server will believe: start, plus the fastest possible climb (to 1 in
-- `fastestWin` seconds, with 10 percent slack), plus a little for rounding.
function Net.maxProgress(start: number, fastestWin: number, elapsed: number): number
	if fastestWin <= 0 then
		return 1
	end
	return math.min(1, start + (1 - start) * math.max(elapsed, 0) / (fastestWin * 0.9) + 0.02)
end

-- A progress report the server will take, clamped to what is possible; nil for junk.
function Net.acceptProgress(claimed: any, start: number, fastestWin: number, elapsed: number): number?
	if type(claimed) ~= "number" or claimed ~= claimed then
		return nil
	end
	return math.clamp(math.min(claimed, Net.maxProgress(start, fastestWin, elapsed)), 0, 1)
end

-- Should the chance be open, given whether it was open and the latest progress?
function Net.open(wasOpen: boolean, progress: number): boolean
	if wasOpen then
		return progress >= Net.DROP
	end
	return progress >= Net.THRESHOLD
end

-- Close enough to net it? Flat distance, with the server's slack.
function Net.inReach(helperPos: Vector3, anglerPos: Vector3): boolean
	local d = Vector3.new(helperPos.X - anglerPos.X, 0, helperPos.Z - anglerPos.Z).Magnitude
	return d <= Net.RANGE + Net.RANGE_SLACK
end

return Net
