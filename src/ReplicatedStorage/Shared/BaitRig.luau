--!strict
-- The bait bench (L3): hook sizes, the four live-bait recipes, and how a run on the bench is
-- graded. Pure: the client's bench draws from these numbers and the server re-scores the
-- same timeline with `grade`, so the two always agree.
--
-- A recipe is played with one button. The client records each press as { down, up } in
-- seconds after the bench's marker starts moving, and sends that timeline with the hook
-- size and bait id (remote "Rig"). Grades:
--   Perfect  every move inside the tight window
--   Good     every move inside the loose window
--   Okay     anything else, a skip, or a timeline the server refuses (exactly today's game)
local Shared = script.Parent
local Config = require(Shared.Config)

local BaitRig = {}

export type Grade = "Okay" | "Good" | "Perfect"
export type Press = { down: number, up: number }
export type Recipe = {
	bait: string,
	kind: "taps" | "hold",
	presses: number, -- how many moves the recipe has
	sweep: number, -- taps: seconds for the marker to run the hook once, at full speed
	targets: { { number } }, -- taps: per press, the marker positions (0 to 1) that count
	marks: { string }, -- names of the targets, for the bench
	tight: number, -- window for Perfect, in marker units (taps) or fill units (hold)
	loose: number, -- window for Good
	fillTime: number, -- hold: seconds to fill the bar at full speed
	band: number, -- hold: middle of the band to let go in
	tip: string, -- the real technique, shown under the close-up
	how: string, -- what to press, shown above the tip
}

----------------------------------------------------------------------------------------
-- Hook sizes

BaitRig.HOOKS = { "Small", "Medium", "Large" }
BaitRig.DEFAULT_HOOK = "Small" -- the dock's panfish want a small hook; trading up for bass and catfish is the lesson
BaitRig.HOOK_LINES = {
	Small = "Small: panfish, perch, trout",
	Medium = "Medium: bass, walleye, trout",
	Large = "Large: catfish, carp, pike",
}
local HOOK_SIZE = { Small = 1, Medium = 2, Large = 3 }
local MOUTH_SIZE = { small = 1, medium = 2, large = 3 }

BaitRig.HOOK_MISS_ONE = 0.25 -- one size off: chance the hook set fails ("It spat the hook")
BaitRig.HOOK_MISS_TWO = 0.5 -- two sizes off

function BaitRig.isHook(hook: any): boolean
	return type(hook) == "string" and HOOK_SIZE[hook] ~= nil
end

-- Chance that setting the hook fails because the hook doesn't fit this fish's mouth. Only
-- live bait uses the hook you chose; lures carry their own (`live` false gives 0).
function BaitRig.missChance(hook: string?, mouth: string?, live: boolean): number
	if not live then
		return 0
	end
	local h = HOOK_SIZE[hook or ""]
	local m = MOUTH_SIZE[mouth or ""]
	if not h or not m then
		return 0
	end
	local off = math.abs(h - m)
	if off >= 2 then
		return BaitRig.HOOK_MISS_TWO
	elseif off == 1 then
		return BaitRig.HOOK_MISS_ONE
	end
	return 0
end

-- What the player reads when a hook that doesn't fit lets a fish go.
function BaitRig.spitText(hook: string, mouth: string?, fishName: string): string
	local h = HOOK_SIZE[hook] or 2
	local m = MOUTH_SIZE[mouth or ""] or 2
	local how = if h > m then "too big" else "too small"
	return string.format("It spat the hook! A %s hook is %s for a %s.", hook, how, fishName)
end

----------------------------------------------------------------------------------------
-- Grades and what they earn. Okay must stay exactly the game before L3.

BaitRig.GRADES = { "Okay", "Good", "Perfect" }
local RANK = { Okay = 1, Good = 2, Perfect = 3 }
BaitRig.BITE_MULT = { Okay = 1, Good = 0.9, Perfect = 0.8 } -- times the bite wait
BaitRig.FIGHT_START = { Okay = Config.FIGHT_START, Good = 0.45, Perfect = 0.5 }
BaitRig.SURVIVE = { Okay = 0, Good = 0, Perfect = 0.5 } -- chance live bait stays on after a catch
BaitRig.GOLD_HOOK_PERFECTS = 25 -- Tackle Box badge (a label for now)

local function gradeOf(g: any): Grade
	if g == "Perfect" or g == "Good" then
		return g
	end
	return "Okay"
end

function BaitRig.biteMult(grade: string?): number
	return BaitRig.BITE_MULT[gradeOf(grade)]
end

function BaitRig.fightStart(grade: string?): number
	return BaitRig.FIGHT_START[gradeOf(grade)]
end

-- True when a Perfect bait survives this catch; `roll` is a uniform 0 to 1 draw.
function BaitRig.survives(grade: string?, roll: number): boolean
	return roll < BaitRig.SURVIVE[gradeOf(grade)]
end

function BaitRig.better(a: string?, b: string?): Grade
	local ga, gb = gradeOf(a), gradeOf(b)
	if a == nil then
		return gb
	end
	return if RANK[gb] > RANK[ga] then gb else ga
end

-- Tackle Box bookkeeping after a finished (not skipped, not refused) bench run.
export type Tackle = { best: { [string]: string }, perfects: number }
function BaitRig.record(tackle: Tackle, bait: string, grade: string)
	local g = gradeOf(grade)
	tackle.best[bait] = BaitRig.better(tackle.best[bait], g)
	if g == "Perfect" then
		tackle.perfects += 1
	end
end

----------------------------------------------------------------------------------------
-- Recipes

BaitRig.FIRST_SPEED = 0.6 -- the first time with a bait the marker runs this fast
BaitRig.LEAD_IN = 0.6 -- seconds of "get ready" before the marker moves (client only)
BaitRig.SKIP_HOLD = 1.0 -- hold this long on the bench to skip (gives Okay)
BaitRig.BENCH_TIMEOUT = 20 -- seconds with the bench open before it gives up (gives Okay)
BaitRig.MIN_FIRST = 0.15 -- no real first press comes sooner after the marker starts
BaitRig.MIN_GAP = 0.15 -- or two presses closer together than this
BaitRig.MAX_TIME = 40 -- or any press later than this

local recipes: { [string]: Recipe } = {
	Worm = {
		bait = "Worm",
		kind = "taps",
		presses = 3,
		sweep = 2.0,
		targets = { { 0.25 }, { 0.5 }, { 0.75 } },
		marks = { "point", "bend", "shank" },
		tight = 0.035,
		loose = 0.09,
		fillTime = 0,
		band = 0,
		tip = "Thread it on two or three times and leave the tail wiggling.",
		how = "Tap as the marker passes the point, the bend, then the shank.",
	},
	Cricket = {
		bait = "Cricket",
		kind = "taps",
		presses = 1,
		sweep = 1.8,
		targets = { { 0.62 } },
		marks = { "collar" },
		tight = 0.035,
		loose = 0.08,
		fillTime = 0,
		band = 0,
		tip = "Hook it under the collar behind the head so it stays lively.",
		how = "One careful tap when the marker is on the collar.",
	},
	Minnow = {
		-- The minnow swings side to side; it lines up with the hook point at the middle of
		-- each swing (positions 0.25 and 0.75 of one full wiggle).
		bait = "Minnow",
		kind = "taps",
		presses = 2,
		sweep = 1.6,
		targets = { { 0.25, 0.75 }, { 0.25, 0.75 } },
		marks = { "lower lip", "upper lip" },
		tight = 0.035,
		loose = 0.09,
		fillTime = 0,
		band = 0,
		tip = "Up through both lips so it swims naturally.",
		how = "Tap when the minnow lines up with the hook point. Twice.",
	},
	Stinkbait = {
		bait = "Stinkbait",
		kind = "hold",
		presses = 1,
		sweep = 0,
		targets = {},
		marks = { "band" },
		tight = 0.05,
		loose = 0.13,
		fillTime = 1.2,
		band = 0.72,
		tip = "Pack it firm around the hook.",
		how = "Hold to pack it on. Let go inside the band.",
	},
}
BaitRig.recipes = recipes

function BaitRig.recipeFor(bait: string?): Recipe?
	return recipes[bait or ""]
end

local function speedOf(firstTime: boolean): number
	return if firstTime then BaitRig.FIRST_SPEED else 1
end

-- Where the marker is (0 to 1 along the hook) `t` seconds after it starts.
function BaitRig.markerAt(recipe: Recipe, t: number, firstTime: boolean): number
	if recipe.sweep <= 0 then
		return 0
	end
	return (t * speedOf(firstTime) / recipe.sweep) % 1
end

-- How full the stinkbait bar is after holding `held` seconds (over 1 is a lump).
function BaitRig.fillAt(recipe: Recipe, held: number, firstTime: boolean): number
	if recipe.fillTime <= 0 then
		return 0
	end
	return held * speedOf(firstTime) / recipe.fillTime
end

-- How long to hold on the bench to skip. Stinkbait is played by holding, so its skip waits
-- until the bar has overflowed and a little more.
function BaitRig.skipHold(recipe: Recipe?, firstTime: boolean): number
	if recipe and recipe.kind == "hold" then
		return math.max(BaitRig.SKIP_HOLD, recipe.fillTime / speedOf(firstTime) + 0.5)
	end
	return BaitRig.SKIP_HOLD
end

local function circular(a: number, b: number): number
	local d = math.abs(a - b) % 1
	return math.min(d, 1 - d)
end

-- How far off a press was: marker units for taps, fill units for a hold. math.huge for a lump.
function BaitRig.errorOf(recipe: Recipe, index: number, press: Press, firstTime: boolean): number
	if recipe.kind == "hold" then
		local fill = BaitRig.fillAt(recipe, press.up - press.down, firstTime)
		if fill > 1 then
			return math.huge
		end
		return math.abs(fill - recipe.band)
	end
	local pos = BaitRig.markerAt(recipe, press.down, firstTime)
	local best = math.huge
	for _, target in recipe.targets[index] or {} do
		best = math.min(best, circular(pos, target))
	end
	return best
end

-- The soonest the recipe's last move can finish inside the loose window.
function BaitRig.minTotal(recipe: Recipe, firstTime: boolean): number
	local speed = speedOf(firstTime)
	if recipe.kind == "hold" then
		return (recipe.band - recipe.loose) * recipe.fillTime / speed
	end
	local last = recipe.targets[recipe.presses] or { 0 }
	local earliest = math.huge
	for _, target in last do
		earliest = math.min(earliest, math.max(0, target - recipe.loose))
	end
	return earliest * recipe.sweep / speed
end

local function isNum(x: any): boolean
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

-- Why a timeline can't have come from a real player, or nil when it could have.
function BaitRig.refusal(recipe: Recipe, timeline: any, firstTime: boolean): string?
	if type(timeline) ~= "table" then
		return "not a list"
	end
	local n = #timeline
	if n == 0 then
		return "no presses"
	end
	if n > recipe.presses then
		return "more presses than the recipe has"
	end
	local lastDown, lastUp = -math.huge, -math.huge
	for i = 1, n do
		local p = timeline[i]
		if type(p) ~= "table" or not isNum(p.down) or not isNum(p.up) then
			return "bad press"
		end
		if p.down < 0 or p.up < p.down or p.up > BaitRig.MAX_TIME then
			return "press out of range"
		end
		if i == 1 and p.down < BaitRig.MIN_FIRST then
			return "first press too soon"
		end
		if p.down <= lastDown or p.down < lastUp then
			return "presses out of order"
		end
		if i > 1 and p.down - lastDown < BaitRig.MIN_GAP then
			return "presses faster than humanly possible"
		end
		lastDown, lastUp = p.down, p.up
	end
	if n == recipe.presses and lastUp < BaitRig.minTotal(recipe, firstTime) - 1e-6 then
		return "finished sooner than the recipe allows"
	end
	return nil
end

-- Grade a bench run. Returns the grade and, when the timeline is refused, why (refused
-- always grades Okay). `recipe` may be a Recipe or a bait id.
function BaitRig.grade(recipe: Recipe | string, timeline: any, firstTime: boolean): (Grade, string?)
	local r: Recipe? = if type(recipe) == "string" then recipes[recipe :: string] else recipe :: Recipe
	if not r then
		return "Okay", "no recipe for that bait"
	end
	local why = BaitRig.refusal(r, timeline, firstTime)
	if why then
		return "Okay", why
	end
	if #timeline < r.presses then
		return "Okay", nil -- not finished
	end
	local worst = 0
	for i = 1, r.presses do
		worst = math.max(worst, BaitRig.errorOf(r, i, timeline[i], firstTime))
	end
	if worst <= r.tight + 1e-9 then
		return "Perfect", nil
	elseif worst <= r.loose + 1e-9 then
		return "Good", nil
	end
	return "Okay", nil
end

-- A timeline that grades Perfect: each press right on its first target from `after` on.
-- Used by the tests and the Studio debug hook; the bench never calls it.
function BaitRig.perfectTimeline(recipe: Recipe, firstTime: boolean, after: number?): { Press }
	local out: { Press } = {}
	local speed = speedOf(firstTime)
	if recipe.kind == "hold" then
		local down = math.max(after or 0, BaitRig.MIN_FIRST) + 0.2
		table.insert(out, { down = down, up = down + recipe.band * recipe.fillTime / speed })
		return out
	end
	local t = math.max(after or 0, BaitRig.MIN_FIRST)
	local period = recipe.sweep / speed
	for i = 1, recipe.presses do
		local soonest = if i == 1 then t else out[i - 1].up + BaitRig.MIN_GAP
		local best = math.huge
		for _, target in recipe.targets[i] do
			local at = target * period
			while at < soonest do
				at += period
			end
			best = math.min(best, at)
		end
		table.insert(out, { down = best, up = best + 0.08 })
	end
	return out
end

return BaitRig
