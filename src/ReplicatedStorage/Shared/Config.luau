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
Config.BITE_MAX = 14 -- slowest bite (weak combo)
Config.NOTHING_WAIT = 12 -- seconds before a "nothing is biting" hint
Config.HOOK_WINDOW = 1.6 -- seconds to press after a bite

-- Fight (bar minigame)
Config.FIGHT_START = 0.35 -- starting progress
Config.FIGHT_LIFT = 2.6 -- zone acceleration while holding
Config.FIGHT_GRAVITY = 2.0 -- zone acceleration while not holding
Config.FIGHT_DAMPING = 2.2
Config.FIGHT_MAX_SECONDS = 90 -- server gives up after this
Config.ASSIST_ZONE = 1.4 -- zone size multiplier with assist on
Config.ASSIST_LOSS = 0.6 -- progress loss multiplier with assist on

-- Economy
Config.START_COINS = 30
Config.START_WORMS = 15
Config.FREE_WORMS = 5
Config.BAG_LIMIT = 30 -- fish carried before you must sell
Config.JOURNAL_KEEP = 100 -- most recent catches kept in the journal

-- Saving
Config.DATASTORE_NAME = "PlayerData_v1"
Config.AUTOSAVE_SECONDS = 120

return Config
