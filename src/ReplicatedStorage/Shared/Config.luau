--!strict
-- Game tunables. Change numbers here, not in the systems.
local Config = {}

-- Day and night
Config.DAY_LENGTH = 960 -- real seconds per full 24 hour day (40 s per game hour)
Config.START_CLOCK = 7 -- game starts at dawn

-- Casting
Config.CAST_MIN = 8 -- studs at zero power
Config.CAST_RANGE = 32 -- extra studs at full power
Config.CHARGE_TIME = 1.2 -- seconds to reach full power

-- Biting
Config.BITE_MIN = 3 -- fastest bite (a combo fish really want)
Config.BITE_SLOWEST = 40 -- slowest bite; weaker combos count as "nothing here" (see docs/ECONOMY.md)
Config.NOTHING_WAIT = 10 -- seconds before a "nothing is biting" hint
Config.HOOK_WINDOW = 2.0 -- seconds to press after a bite

-- Fight (bar minigame)
Config.FIGHT_START = 0.4 -- starting progress
Config.ZONE_UP_SPEED = 1.25 -- bar heights per second while holding
Config.ZONE_DOWN_SPEED = 0.85 -- bar heights per second while not holding
Config.ZONE_RESPONSE = 9 -- how quickly the zone reaches those speeds (per second)
Config.PRESS_KICK = 0.7 -- instant upward speed from each fresh click or tap
Config.FIGHT_IDLE_GRACE = 1.2 -- seconds without a press or hold before the line goes slack and progress stops filling (2.5 before L4b; tools/econ/sim.py --grace)
Config.TELL_LEAD = 0.45 -- seconds a fish's big move (run, jump, dive) is warned on the water before it shows on the bar (L4b)
Config.FIGHT_GRACE = 0.8 -- seconds after a fight ends before the button can cast again
Config.FIGHT_MAX_SECONDS = 90 -- server gives up after this
Config.ASSIST_ZONE = 1.4 -- zone size multiplier with assist on
Config.ASSIST_LOSS = 0.6 -- progress loss multiplier with assist on
Config.ASSIST_CATCHES = 3 -- reel assist turns itself off after this many catches, unless the player set it by hand (L4b)

-- Line and drag (L4d, Shared/FightModel). Drag is Light, Medium (the fight as it was) or
-- Tight. "Load" is the fish's weight over the line's rating (lb over lb, RodData.lineLb).
-- Strain (0 to 1) builds while you reel through a big move (run, jump, dive, and its tell)
-- at RISE x (load - FREE) per second, capped at RISE_MAX, and the line snaps at 1. It falls
-- at FALL_EASE once you let go, FALL_REELING while you reel with no big move on.
-- Calibrated 11/27/2026 with tools/econ/sim.py --drag and FightModel.spec.
Config.DRAG_TIGHT_GAIN = 1.3 -- Tight fills the progress bar 30 percent faster
Config.DRAG_LIGHT_GAIN = 0.8 -- Light fills it 20 percent slower...
Config.DRAG_LIGHT_TAKE = 0.08 -- ...and a running fish takes this much progress a second (it takes line)
Config.STRAIN_FREE_MEDIUM = 0.6 -- on Medium a fish under 60 percent of the line's rating never strains it
Config.STRAIN_FREE_TIGHT = 0.25
Config.STRAIN_RISE_MEDIUM = 1.0
Config.STRAIN_RISE_TIGHT = 4.0
Config.STRAIN_RISE_MAX = 1.5 -- never faster: letting go before the tell runs out (with one last tap) always saves the line
Config.STRAIN_FALL_EASE = 2.5
Config.STRAIN_FALL_REELING = 1.0
Config.STRAIN_REEL_WINDOW = 0.15 -- a fresh press counts as reeling this long (so fast mashing counts like holding)

-- Economy
Config.START_COINS = 30
Config.START_WORMS = 15
Config.FREE_WORMS = 5
Config.BAG_LIMIT = 30 -- fish carried before you must sell
Config.JOURNAL_KEEP = 100 -- most recent catches kept in the journal

-- Cedar Creek
Config.CREEK_PASS_PRICE = 500

-- Home pond
Config.POND_CAPACITY = 6
Config.POND_GROW_RATE = 0.3567 -- per hour: closes 30 percent of the gap to full size each hour
Config.POND_BREED_EVERY = 1800 -- seconds of pond time between breeding rolls
Config.POND_BREED_CHANCE = 0.25 -- chance per roll for each species with two grown fish
Config.POND_OFFLINE_CAP = 8 * 3600 -- most time counted while away
Config.POND_TICK = 30 -- seconds between pond updates while playing

-- Switches for the second overnight run's features (leg plan L0): each lands switched off
-- and is turned on and proven by itself. Boats need the Big Lake (its slips and channel).
-- With weather off the sky stays clear and weather-only fish (Mythics) don't bite.
-- What players read for fish sizes: "imperial" (inches, pounds) or "metric". Data stays metric.
Config.UNITS = "imperial"

Config.WEATHER_ON = true
Config.FRENZIES_ON = true
Config.GOALS_ON = true
-- The Big Lake and the dinghy (L7): on since the 11/27/2026 Studio playtest.
Config.BIG_LAKE_ON = true
Config.BOATS_ON = true
-- Work the lure (L4c): with a lure on, no bobber; you reel a spinner or hop a plastic worm back
-- and fish strike while it moves (Shared/Retrieve). On since the 11/27/2026 Studio playtest;
-- false puts lures back under a bobber.
Config.LURE_RETRIEVE_ON = true

-- The look on each player's screen (leg 3, N0): with LOOK_DIRECTOR_ON the server stops writing
-- Lighting and each client works out the look itself (ClientModules/LookDirector) and writes it
-- locally. LOOK_AREAS_ON adds the area presets (creek, basin, blue water, island) and per-area
-- water; off, the client draws exactly what the server drew. REALISTIC_DESKTOP lets the desktop
-- tier set Lighting.LightingStyle to Realistic; off, the place's own style is kept.
Config.LOOK_DIRECTOR_ON = true -- on 11/27/2026 after its playtest: set A 6.0 off and 6.0 on, clocks match
Config.LOOK_AREAS_ON = false
Config.REALISTIC_DESKTOP = true -- N1: the place runs Realistic (set in Edit; a LocalScript cannot write LightingStyle) and the grade applies
-- Painted world signs (leg 3, N2): wooden boards with painted words (Server/Signs) in place of
-- the floating name labels, and sign lanterns lit at night (ClientModules/Lanterns). Off, the
-- world builders make the old floating signs only.
Config.PAINTED_SIGNS_ON = true -- on 11/27/2026 after the corner playtest (boards by day, lanterns at night)
-- Wind you can see (leg 3, N1): the server sets workspace.GlobalWind from the weather
-- (Weather.windFor, blended over 20 s), so grass, clouds and particles move the same for
-- everyone. Off, GlobalWind is never touched.
Config.WIND_ON = true
-- The home lake's water by time of day (leg 3, N1, LookPresets.WATER_BY_TIME): a mirror at
-- dawn, a light chop by day. Works on its own (home water everywhere) or inside the area
-- water with LOOK_AREAS_ON. Off, the water is left as it was.
Config.WATER_BY_TIME_ON = true
-- The field guide and tackle box interface (leg 3, N2): paper, canvas, leather and brass, with
-- every colour, font and panel image in Shared/UIStyle. Off, every screen is exactly as before.
Config.UI_STYLE_ON = false

function Config.boatsOn(): boolean
	return Config.BOATS_ON and Config.BIG_LAKE_ON
end

-- Saving
Config.DATASTORE_NAME = "PlayerData_v1"
Config.AUTOSAVE_SECONDS = 120

return Config
