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
Config.BIG_LAKE_ON = false
Config.BOATS_ON = false
-- Work the lure (L4c): with a lure on, no bobber; you reel a spinner or hop a plastic worm back
-- and fish strike while it moves (Shared/Retrieve). On since the 11/27/2026 Studio playtest;
-- false puts lures back under a bobber.
Config.LURE_RETRIEVE_ON = true

function Config.boatsOn(): boolean
	return Config.BOATS_ON and Config.BIG_LAKE_ON
end

-- Saving
Config.DATASTORE_NAME = "PlayerData_v1"
Config.AUTOSAVE_SECONDS = 120

return Config
