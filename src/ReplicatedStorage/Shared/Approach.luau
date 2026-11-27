--!strict
-- The wait (L4): a fish is picked a few seconds before it bites, swims in as a shadow the
-- size of the fish, circles and noses the bait, and then strikes or (sometimes) leaves.
-- A quick tap twitches the bait: it can keep a looker from leaving and bring the bite a
-- little sooner, but three or more twitches close together spook it.
--
-- Timing: each attempt waits ATTEMPT_SCALE times the normal bite delay (FishLogic.biteDelay
-- with every multiplier applied). A looker leaves at the moment it would have bitten and a
-- fresh attempt starts, so with LOOK_LEAVE = 0.25 the average time to a bite is exactly the
-- old one: E[total] = ATTEMPT_SCALE * E[delay] / (1 - LOOK_LEAVE) = E[delay].
-- A cast onto a rise keeps its quick bite as is and its fish never leaves.
--
-- Pure rules, no Roblox services. FishingService (server) runs them; the client draws.
-- UNVERIFIED in Studio (written 2026-11-26).
local Shared = script.Parent
local Rarity = require(Shared.Rarity)

local Approach = {}

Approach.APPROACH_LEAD_MIN = 2.5 -- the shadow shows up this many seconds before the bite...
Approach.APPROACH_LEAD_MAX = 4 -- ...to this many
Approach.APPROACH_MIN_START = 0.4 -- never sooner than this after the bobber lands (short waits)
Approach.LOOK_LEAVE = 0.25 -- chance an approaching fish (not one from a rise) looks and leaves
Approach.ATTEMPT_SCALE = 1 - Approach.LOOK_LEAVE -- keeps the average wait unchanged (see above)

Approach.TWITCH_TAP = 0.25 -- a press shorter than this while waiting is a twitch
Approach.REEL_HOLD = 0.35 -- a press at least this long while waiting reels the line in
Approach.TWITCH_GAP = 0.3 -- the server looks at one twitch per this many seconds
Approach.TWITCH_SOONER_MIN = 0.5 -- a twitch the fish likes brings the bite this much sooner...
Approach.TWITCH_SOONER_MAX = 1.5 -- ...to this much
Approach.TWITCH_KEEP = 0.5 -- chance a twitch keeps a fish that was about to leave (always keeping saved 4 to 5 s at slow spots)
Approach.SPOOK_COUNT = 3 -- this many twitches...
Approach.SPOOK_WINDOW = 4 -- ...inside this many seconds spook an approaching fish
Approach.SPOOK_DELAY = 4 -- and the next approach waits this much longer

Approach.HUSH_TIME = 0.6 -- the held breath: everything goes quiet this long before the strike

-- Shadow sizes. The shadow is as long as the fish that hangs on the line after the catch
-- (FishingService.showCatch uses shadowLength too), so "big one" before the strike is true.
Approach.STUDS_PER_CM = 1 / 12 -- a bit bigger than life so it reads on screen
Approach.SHADOW_MIN = 1
Approach.SHADOW_MAX = 8
Approach.SMALL_MAX_CM = 30 -- shorter than this reads as a small fish (panfish)
Approach.LARGE_MIN_CM = 55 -- this long and up reads as a big one (catfish, pike, carp, big bass)

-- Small things on long waits (client flavour): after this long with no fish coming...
Approach.WAIT_EVENT_AFTER = 8
-- ...and once in a long while, a huge shadow passes under the bobber and doesn't bite.
Approach.HUGE_SHADOW_CHANCE = 0.02

export type Plan = {
	approachIn: number, -- seconds from now until the shadow starts its approach
	biteIn: number, -- seconds from the approach until it strikes (or leaves, for a looker)
	leaves: boolean, -- a looker: it circles, noses the bait and swims off
}

export type Twitches = {
	times: { number }, -- recent twitch times (os.clock), inside SPOOK_WINDOW
	last: number, -- time of the last twitch the server looked at
	used: boolean, -- this approach's fish already reacted to a twitch
}

export type TwitchResult = "ignored" | "jiggle" | "sooner" | "spook"

-- How long this attempt waits, from the normal bite delay. A rise's quick bite is kept as is.
function Approach.attemptDelay(delay: number, fromRise: boolean): number
	if fromRise then
		return delay
	end
	return delay * Approach.ATTEMPT_SCALE
end

-- When the shadow comes and whether it bites. `attempt` is attemptDelay's result: the time
-- from now until the strike. The approach sits inside that wait, never added to it.
function Approach.plan(attempt: number, rng: Random, fromRise: boolean): Plan
	local lead = rng:NextNumber(Approach.APPROACH_LEAD_MIN, Approach.APPROACH_LEAD_MAX)
	local earliest = math.min(Approach.APPROACH_MIN_START, attempt * 0.5)
	local approachIn = math.max(attempt - lead, earliest)
	local leaves = rng:NextNumber() < Approach.LOOK_LEAVE
	return {
		approachIn = approachIn,
		biteIn = attempt - approachIn,
		leaves = leaves and not fromRise,
	}
end

-- The shadow's length in studs for a fish this long (the hung-catch rule).
function Approach.shadowLength(cm: number): number
	return math.clamp(cm * Approach.STUDS_PER_CM, Approach.SHADOW_MIN, Approach.SHADOW_MAX)
end

-- "small", "medium" or "large", from the rolled length.
function Approach.sizeClass(cm: number): string
	if cm < Approach.SMALL_MAX_CM then
		return "small"
	elseif cm >= Approach.LARGE_MIN_CM then
		return "large"
	end
	return "medium"
end

-- Big or rare fish announce themselves: a low swell under the approach (Rare and up, or a
-- large mouth).
function Approach.announces(tier: string?, mouth: string?): boolean
	return (Rarity.rank[tier or ""] or 1) >= Rarity.rank.Rare or mouth == "large"
end

-- What a press while waiting means: "twitch" (a quick tap), "reel" (a hold) or nil (in
-- between, or still being held but not long enough yet).
function Approach.pressKind(heldSeconds: number, released: boolean): string?
	if heldSeconds >= Approach.REEL_HOLD then
		return "reel"
	end
	if released and heldSeconds < Approach.TWITCH_TAP then
		return "twitch"
	end
	return nil
end

function Approach.newTwitches(): Twitches
	return { times = {}, last = -math.huge, used = false }
end

-- A new fish starts its approach: it hasn't reacted to a twitch yet. Recent twitches still
-- count toward a spook (spamming before it arrives scares it off when it gets there).
function Approach.onApproach(tw: Twitches)
	tw.used = false
end

-- One twitch at `now`. `fishOpen` is true while a fish is approaching or circling (before the
-- held breath). Returns what it does, and for "sooner" how many seconds sooner.
--   ignored: too soon after the last one (rate limit)
--   jiggle:  the bait moves, nothing else (no fish yet, or it already reacted)
--   sooner:  the fish likes it: it stays (even a looker) and bites a little sooner
--   spook:   SPOOK_COUNT or more inside SPOOK_WINDOW with a fish there: it swims off
function Approach.twitch(tw: Twitches, now: number, fishOpen: boolean, rng: Random): (TwitchResult, number)
	if now - tw.last < Approach.TWITCH_GAP then
		return "ignored", 0
	end
	tw.last = now
	for i = #tw.times, 1, -1 do
		if now - tw.times[i] > Approach.SPOOK_WINDOW then
			table.remove(tw.times, i)
		end
	end
	table.insert(tw.times, now)
	if not fishOpen then
		return "jiggle", 0
	end
	if #tw.times >= Approach.SPOOK_COUNT then
		table.clear(tw.times)
		return "spook", 0
	end
	if tw.used then
		return "jiggle", 0
	end
	tw.used = true
	return "sooner", rng:NextNumber(Approach.TWITCH_SOONER_MIN, Approach.TWITCH_SOONER_MAX)
end

-- The strike time after a twitch the fish liked: `sooner` earlier, but always leaving a full
-- held breath from now, and never later than it was. Only called before the held breath
-- (now < biteAt - HUSH_TIME).
function Approach.soonerBiteAt(biteAt: number, now: number, sooner: number): number
	return math.min(biteAt, math.max(biteAt - sooner, now + Approach.HUSH_TIME))
end

return Approach
