--!strict
-- Work the lure (L4c): with a lure on there is no bobber. The lure splashes down and you work
-- it back toward you along the line from where it landed to where you cast from.
--
--   Spinner       Hold to reel. Holding speeds the retrieve up, letting go lets it slow down
--                 (like the fight bar), so a steady medium speed takes a little rhythm. Fish
--                 hit it only while its speed is inside the band. Stop and it sinks: over a log
--                 or into the weed core it snags (Cover.snagAt, the L2 rules).
--   Plastic worm  A Texas rig on the bottom. Each short press pulls it forward a little and
--                 lifts it; fish hit it on the fall right after a pull. A press held past
--                 HOP_MAX drags it along the bottom (no fall, nothing bites), and pulling again
--                 before the fall starts (ripping it) gets nothing either. Left still on a
--                 log or in the weeds it snags, unless it's rigged weedless (a Perfect worm,
--                 Cover.weedless) and in the weeds.
--
-- Fair to the economy: every second of "good" retrieve carries a strike hazard. A retrieve
-- worked well spends WELL_SHARE of its time good, and the hazard is set so that, counting the
-- time spent casting again when a lure comes back with nothing (a bobber never has to), a lure
-- worked well strikes as often per minute as a bobber bites there (FishLogic.biteDelay with
-- every multiplier FishingService applies):
--   hazard per good second = 1 / (delay * WELL_SHARE[lure] * RECAST_PAYBACK[lure])
-- Badly worked, the good share is smaller and strikes come later or never. The fish is picked
-- by the same bite weights as a bobber bite.
--
-- The client streams its presses (seconds after the landing, as it saw it); the server runs
-- them through this same model on its own clock, a little behind real time (LAG), and rolls
-- strikes from the good seconds. acceptEvent refuses timelines no real player could make.
-- Pure rules, no Roblox services. UNVERIFIED in Studio (written 2026-11-27).
local Shared = script.Parent
local Cover = require(Shared.Cover)
local CastLogic = require(Shared.CastLogic)
local BaitData = require(Shared.BaitData)

local Retrieve = {}

-- The model's time step (seconds). Both sides integrate with it, so they agree.
Retrieve.STEP = 1 / 30

-- The cast ends (no strike, nothing lost) when the lure is this close to where you cast from.
Retrieve.END_DIST = 3
-- A retrieve that has gone this long ends too (a lure left sitting forever).
Retrieve.MAX_TIME = 90

----------------------------------------------------------------------------------------
-- Spinner (studs and seconds). A 20 to 40 stud cast comes back in about 6 to 12 seconds at
-- the middle of the band.
Retrieve.SPIN_ACCEL = 3 -- studs per second gained each second while holding
Retrieve.SPIN_DECEL = 2.5 -- studs per second lost each second after letting go
Retrieve.SPIN_MAX = 7 -- holding the whole time tops out here (ripping it)
Retrieve.BAND_LO = 2.4 -- the strike band: slower than this is too slow...
Retrieve.BAND_HI = 4.6 -- ...faster than this is too fast
Retrieve.LIFT_SPEED = 1.5 -- slower than this the spinner sinks
Retrieve.SINK_RATE = 0.9 -- studs per second it sinks when stopped
Retrieve.RISE_RATE = 1.5 -- studs per second it rises back when moving
Retrieve.BOTTOM = 4 -- it never sinks deeper than this
Retrieve.SNAG_DEPTH = 1.4 -- sunk this deep over a log or the weed core, it snags (about 1.6 s stopped)

----------------------------------------------------------------------------------------
-- Plastic worm (Texas rig)
Retrieve.HOP_MAX = 0.45 -- a press up to this long is a pull (a hop); longer drags it
Retrieve.HOP_BASE = 2 -- studs a pull moves it...
Retrieve.HOP_PER_SEC = 4 -- ...plus this many per second held (a tap about 2.4, a long pull 3.8)
Retrieve.DRAG_SPEED = 3 -- studs per second while dragging
Retrieve.FALL_START = 0.3 -- after a pull lets go, the worm is falling from this long after...
Retrieve.FALL_END = 1.5 -- ...to this long after: the strike window (the splashdown counts as a fall too)
Retrieve.REST_SNAG = 2.2 -- still this long on a log or in the weeds (not weedless) and it snags

----------------------------------------------------------------------------------------
-- Strikes. The good share of a retrieve worked well (wellTimeline over a 10 s retrieve,
-- checked by Retrieve.spec).
Retrieve.WELL_SHARE = {
	Spinner = 0.9,
	PlasticWorm = 0.73,
} :: { [string]: number }
-- In the water, a lure worked well strikes after this share of the bobber's delay, which pays
-- back the recasts: a lure comes back and is cast again (about 1.7 s), a bobber just sits. A
-- spinner is back in 6 to 12 seconds and recast often; a hopped worm takes about 18 seconds
-- from 30 studs and hardly ever. With these, a 30 stud cast worked well, recasts and all,
-- strikes after the bobber's delay on average (Retrieve.spec), and the economy sim's smart
-- player earns within 5 percent of today (tools/econ/sim.py --retrieve).
Retrieve.RECAST_PAYBACK = {
	Spinner = 0.85,
	PlasticWorm = 0.97,
} :: { [string]: number }

----------------------------------------------------------------------------------------
-- Timelines the server will accept.
Retrieve.MIN_PRESS_GAP = 0.08 -- two presses can't start closer together than this
Retrieve.MAX_PRESSES = 240 -- presses in one retrieve
Retrieve.LAG = 0.4 -- the server scores this far behind its own clock, so presses can arrive
Retrieve.FUTURE_SLACK = 0.25 -- a press can't be stamped more than this ahead of the server's clock
Retrieve.TICK = 0.1 -- seconds between the server's strike rolls

export type Press = { down: number, up: number? }

export type State = {
	lure: string,
	grade: string,
	land: Vector3, -- where it splashed down (flat, at the water)
	toward: Vector3, -- flat unit vector from the landing toward the caster
	length: number, -- flat studs from the landing to the caster
	t: number, -- seconds since the landing, as far as the model has run
	held: boolean,
	pressAt: number, -- when the current press went down
	speed: number, -- spinner: studs per second
	depth: number, -- spinner: studs under the surface
	traveled: number, -- studs worked back toward the caster
	good: number, -- seconds of good retrieve so far
	fallFrom: number, -- worm: the current fall window (absolute model time)...
	fallTo: number,
	lastMove: number, -- worm: when it last moved (for resting snags)
	dragging: boolean, -- worm: the current press has become a drag
	snagged: boolean,
	done: boolean, -- reached the caster (or MAX_TIME)
}

-- True for the baits this works with (the lures).
function Retrieve.isLure(baitId: string?): boolean
	local b = BaitData.byId[baitId or ""]
	return b ~= nil and b.kind == "lure" and Retrieve.WELL_SHARE[b.id] ~= nil
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- A fresh retrieve: the lure just landed at `land`, cast from `origin`.
function Retrieve.new(lure: string, grade: string?, land: Vector3, origin: Vector3): State
	local d = flat(origin) - flat(land)
	local length = d.Magnitude
	local toward = if length > 0.01 then d.Unit else Vector3.new(0, 0, 1)
	return {
		lure = lure,
		grade = grade or "Okay",
		land = Vector3.new(land.X, CastLogic.LAND_Y, land.Z),
		toward = toward,
		length = length,
		t = 0,
		held = false,
		pressAt = 0,
		speed = 0,
		depth = 0,
		traveled = 0,
		good = 0,
		-- The splashdown sinks the worm: that first fall is a strike window too.
		fallFrom = if lure == "PlasticWorm" then Retrieve.FALL_START else math.huge,
		fallTo = if lure == "PlasticWorm" then Retrieve.FALL_END else -math.huge,
		lastMove = 0,
		dragging = false,
		snagged = false,
		done = length <= Retrieve.END_DIST,
	}
end

-- Where the lure is now (flat, at the water's height).
function Retrieve.position(s: State): Vector3
	return s.land + s.toward * s.traveled
end

-- "slow", "right" or "fast" for a spinner speed (the meter by the rod).
function Retrieve.band(speed: number): string
	if speed < Retrieve.BAND_LO then
		return "slow"
	elseif speed > Retrieve.BAND_HI then
		return "fast"
	end
	return "right"
end

-- Studs a pull held this long moves the worm.
function Retrieve.hopDistance(held: number): number
	return Retrieve.HOP_BASE + Retrieve.HOP_PER_SEC * math.clamp(held, 0, Retrieve.HOP_MAX)
end

local function move(s: State, studs: number)
	s.traveled = math.min(s.traveled + studs, math.max(s.length - Retrieve.END_DIST, 0))
	if s.traveled >= s.length - Retrieve.END_DIST - 1e-6 then
		s.done = true
	end
end

local function snagsHere(s: State): boolean
	return Cover.snagAt(Retrieve.position(s), s.lure, s.grade)
end

-- Seconds out of `dt` that a speed starting at v0, changing at `rate` (signed) until it stops
-- at `cap`, spends inside [lo, hi]. Exact, so the server's streamed scoring (run in chunks)
-- and a whole-timeline score agree.
local function secondsIn(v0: number, rate: number, cap: number, dt: number, lo: number, hi: number): number
	if rate == 0 then
		return if v0 >= lo and v0 <= hi then dt else 0
	end
	local tc = math.clamp((cap - v0) / rate, 0, dt)
	local vEnd = v0 + rate * tc
	local a, b = math.min(v0, vEnd), math.max(v0, vEnd)
	local moving = math.max(0, math.min(b, hi) - math.max(a, lo)) / math.abs(rate)
	local resting = if cap >= lo and cap <= hi then dt - tc else 0
	return moving + resting
end

-- One small step of `dt` seconds with the current press state.
local function substep(s: State, dt: number)
	local t0 = s.t
	if s.lure == "Spinner" then
		local v0 = s.speed
		local rate = if s.held then Retrieve.SPIN_ACCEL else -Retrieve.SPIN_DECEL
		local cap = if s.held then Retrieve.SPIN_MAX else 0
		local tc = math.clamp((cap - v0) / rate, 0, dt)
		s.speed = v0 + rate * tc
		s.good += secondsIn(v0, rate, cap, dt, Retrieve.BAND_LO, Retrieve.BAND_HI)
		local sinking = secondsIn(v0, rate, cap, dt, -1, Retrieve.LIFT_SPEED)
		s.depth = math.clamp(s.depth + Retrieve.SINK_RATE * sinking - Retrieve.RISE_RATE * (dt - sinking), 0, Retrieve.BOTTOM)
		move(s, v0 * tc + 0.5 * rate * tc * tc + cap * (dt - tc))
		if s.depth >= Retrieve.SNAG_DEPTH and snagsHere(s) then
			s.snagged = true
		end
	else
		if s.held then
			local dragFrom = s.pressAt + Retrieve.HOP_MAX
			if t0 + dt > dragFrom then
				if not s.dragging then
					s.dragging = true
					move(s, Retrieve.hopDistance(Retrieve.HOP_MAX))
				end
				move(s, Retrieve.DRAG_SPEED * (t0 + dt - math.max(t0, dragFrom)))
			end
			s.lastMove = t0 + dt
		else
			local from = math.max(t0, s.fallFrom)
			local to = math.min(t0 + dt, s.fallTo)
			if to > from then
				s.good += to - from
			end
			if t0 + dt - s.lastMove >= Retrieve.REST_SNAG and snagsHere(s) then
				s.snagged = true
			end
		end
	end
	s.t = t0 + dt
end

-- Run the model on to time `t` (seconds after the landing) with the press state unchanged.
-- Stops early when the lure snags or reaches the caster.
function Retrieve.advance(s: State, t: number)
	local stop = math.min(t, Retrieve.MAX_TIME)
	while s.t < stop - 1e-9 and not s.snagged and not s.done do
		substep(s, math.min(Retrieve.STEP, stop - s.t))
	end
	if s.t >= Retrieve.MAX_TIME - 1e-9 then
		s.done = true
	end
end

-- The button went down at `t`.
function Retrieve.press(s: State, t: number)
	Retrieve.advance(s, t)
	if s.held or s.snagged or s.done then
		return
	end
	s.held = true
	s.pressAt = math.max(t, s.t)
	s.dragging = false
	if s.lure == "PlasticWorm" then
		s.fallTo = math.min(s.fallTo, s.pressAt) -- pulling again cuts the fall short
		s.lastMove = s.pressAt
	end
end

-- The button came up at `t`.
function Retrieve.release(s: State, t: number)
	Retrieve.advance(s, t)
	if not s.held then
		return
	end
	s.held = false
	if s.lure == "PlasticWorm" and not s.snagged and not s.done then
		local at = math.max(t, s.t)
		if not s.dragging then
			move(s, Retrieve.hopDistance(at - s.pressAt))
			s.fallFrom = at + Retrieve.FALL_START
			s.fallTo = at + Retrieve.FALL_END
		end
		s.dragging = false
		s.lastMove = at
	end
end

-- Chance of a strike over `goodSeconds` more of good retrieve, when a bobber here would bite
-- after `delay` seconds (nil: nothing here wants this lure).
function Retrieve.strikeChance(goodSeconds: number, delay: number?, lure: string): number
	if not delay or delay <= 0 or goodSeconds <= 0 then
		return 0
	end
	local share = Retrieve.WELL_SHARE[lure] or 1
	local payback = Retrieve.RECAST_PAYBACK[lure] or 1
	return 1 - math.exp(-goodSeconds / (delay * share * payback))
end

local function isNum(x: any): boolean
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

-- Can a press go "down" or "up" at `t` after these presses? Nil when it can, else why not.
-- Kinds alternate (down, up, down...), times never go backwards, presses can't start closer
-- than MIN_PRESS_GAP, nothing is negative or later than MAX_TIME, at most MAX_PRESSES.
function Retrieve.acceptEvent(presses: { Press }, kind: any, t: any): string?
	if kind ~= "down" and kind ~= "up" then
		return "not a press"
	end
	if not isNum(t) then
		return "bad time"
	end
	if t < 0 or t > Retrieve.MAX_TIME + 1 then
		return "time out of range"
	end
	local last = presses[#presses]
	if kind == "down" then
		if last and last.up == nil then
			return "already held"
		end
		if #presses >= Retrieve.MAX_PRESSES then
			return "too many presses"
		end
		if last then
			if t < (last.up :: number) then
				return "presses out of order"
			end
			if t - last.down < Retrieve.MIN_PRESS_GAP then
				return "presses faster than humanly possible"
			end
		end
	else
		if not last or last.up ~= nil then
			return "not held"
		end
		if t < last.down then
			return "presses out of order"
		end
	end
	return nil
end

-- Add the event to the list (call acceptEvent first).
function Retrieve.addEvent(presses: { Press }, kind: string, t: number)
	if kind == "down" then
		table.insert(presses, { down = t })
	else
		presses[#presses].up = t
	end
end

-- Why a whole timeline can't have come from a real player, or nil when it could have. Only
-- the last press may still be held (no `up`).
function Retrieve.refusal(presses: any): string?
	if type(presses) ~= "table" then
		return "not a list"
	end
	local seen: { Press } = {}
	for i, p in presses do
		if type(p) ~= "table" then
			return "bad press"
		end
		local why = Retrieve.acceptEvent(seen, "down", p.down)
		if why then
			return why
		end
		Retrieve.addEvent(seen, "down", p.down)
		if p.up ~= nil then
			why = Retrieve.acceptEvent(seen, "up", p.up)
			if why then
				return why
			end
			Retrieve.addEvent(seen, "up", p.up)
		elseif i < #presses then
			return "a press that never let go"
		end
	end
	return nil
end

-- Score a whole timeline from the landing to `upTo` seconds (the reference the server's
-- streamed scoring matches). Returns the final state, or nil and why for a refused timeline.
function Retrieve.score(lure: string, grade: string?, land: Vector3, origin: Vector3, presses: any, upTo: number): (State?, string?)
	local why = Retrieve.refusal(presses)
	if why then
		return nil, why
	end
	local s = Retrieve.new(lure, grade, land, origin)
	for _, p in presses :: { Press } do
		if p.down > upTo then
			break
		end
		Retrieve.press(s, p.down)
		if p.up and (p.up :: number) <= upTo then
			Retrieve.release(s, p.up :: number)
		else
			break
		end
	end
	Retrieve.advance(s, upTo)
	return s, nil
end

-- A retrieve worked well, for `duration` seconds (tests, the economy numbers and the Studio
-- debug hook; the game never calls it).
--   Spinner: hold 1.4 s to get it moving, then let go 0.54 s and hold 0.45 s, over and over
--   (it swings between about 2.85 and 4.2 studs a second, inside the band).
--   Worm: let the splashdown fall, then a quick pull every 1.55 s (each fall runs its course).
function Retrieve.wellTimeline(lure: string, duration: number): { Press }
	local out: { Press } = {}
	if lure == "Spinner" then
		local t = 0.15
		table.insert(out, { down = t, up = t + 1.4 })
		t += 1.4 + 0.54
		while t < duration do
			table.insert(out, { down = t, up = t + 0.45 })
			t += 0.99
		end
	else
		local t = Retrieve.FALL_END + 0.05
		while t < duration do
			table.insert(out, { down = t, up = t + 0.1 })
			t += 0.1 + Retrieve.FALL_END - 0.05
		end
	end
	return out
end

return Retrieve
