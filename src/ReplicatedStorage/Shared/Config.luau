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
Config.BITE_MIN = 3 -- fastest bite (great combo)
Config.BITE_MAX = 11 -- slowest bite (weak combo)
Config.NOTHING_WAIT = 10 -- seconds before a "nothing is biting" hint
Config.HOOK_WINDOW = 2.0 -- seconds to press after a bite

-- Fight (bar minigame)
Config.FIGHT_START = 0.4 -- starting progress
Config.ZONE_UP_SPEED = 1.25 -- bar heights per second while holding
Config.ZONE_DOWN_SPEED = 0.85 -- bar heights per second while not holding
Config.ZONE_RESPONSE = 9 -- how quickly the zone reaches those speeds (per second)
Config.PRESS_KICK = 0.7 -- instant upward speed from each fresh click or tap
Config.FIGHT_GRACE = 0.8 -- seconds after a fight ends before the button can cast again
Config.FIGHT_MAX_SECONDS = 90 -- server gives up after this
Config.ASSIST_ZONE = 1.4 -- zone size multiplier with assist on
Config.ASSIST_LOSS = 0.6 -- progress loss multiplier with assist on

-- Economy
Config.START_COINS = 30
Config.START_WORMS = 15
Config.FREE_WORMS = 5
Config.BAG_LIMIT = 30 -- fish carried before you must sell
Config.JOURNAL_KEEP = 100 -- most recent catches kept in the journal

-- Home pond
Config.POND_CAPACITY = 6
Config.POND_GROW_RATE = 0.3567 -- per hour: closes 30 percent of the gap to full size each hour
Config.POND_BREED_EVERY = 1800 -- seconds of pond time between breeding rolls
Config.POND_BREED_CHANCE = 0.25 -- chance per roll for each species with two grown fish
Config.POND_OFFLINE_CAP = 8 * 3600 -- most time counted while away
Config.POND_TICK = 30 -- seconds between pond updates while playing

-- Saving
Config.DATASTORE_NAME = "PlayerData_v1"
Config.AUTOSAVE_SECONDS = 120

return Config
