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
Config.UI_STYLE_ON = true -- on 11/27/2026 after N2 round 4 (ui 7.5, touch-phone checks clean)
-- The phone tier's foliage savings (leg 3, N1 round 2, ClientModules/FoliageTier): on a phone
-- (player attribute LookTierActive "phone") tagged foliage casts no shadow, undergrowth past 40
-- studs is hidden, every second reed and stone group (past 60) and tree (past 100), and every
-- kit tree past 220 (N3 review 3, final: were 80 and 150, and no limit). It does nothing on the
-- desktop tier, so it is on. Off, foliage is never touched on the client.
Config.FOLIAGE_TIER_ON = true
-- The readable chalkboard (leg 3, N2, from Gemini's review): bigger hand-lettered chalk on the
-- board (the weather in a few words, the fish of the day, a teaser) and a "Read today's board"
-- prompt that opens a field-guide card (Shared/BoardText, ClientModules/BoardCard). Needs
-- UI_STYLE_ON too; with either off, the board and the screens are exactly as before.
Config.BOARD_CARD_ON = true -- on 11/27/2026 with the UI restyle

-- White water on Cedar Creek's riffle (leg 3, N3, ClientModules/WhiteWater): scrolling foam strips
-- down the riffle and below the boulders, a little spray at the riffle's head and its drop. Never
-- on the phone tier (player attribute LookTierActive "phone": fill rate). Off, nothing is made.
Config.WHITE_WATER_ON = false

-- The fleet (leg 3, N4). Each lands switched off and is turned on after its own playtest.
-- CANOE_ON: the Cedar Canoe is for sale (350 coins, two paddlers, Lily Cove), the dinghy gets
-- its passenger seat, every boat keeps to its own waters (BoatData.waters) and the canoe and
-- dinghy can land at any shore ("Land here") and be re-boarded there. Off, the fleet is the
-- L7 dinghy exactly. The journal's "Send my boat home" works with boats on, switch or not.
Config.CANOE_ON = false
-- NET_ON: a player within 10 studs of someone whose fish is at 70 percent gets "Net it"; a
-- press while the fish is up lands it (Shared/Net). Off, no prompt and no progress is read.
Config.NET_ON = false
-- ASSIST_BONUS_ON: on a shared catch (a net, or a Deep-V team catch) the angler keeps the full
-- price and each helper gets an assist in the journal plus 10 percent of it (Shared/Coop).
-- Off, a team catch is split evenly as in L7 and a net pays the helper nothing.
Config.ASSIST_BONUS_ON = false
-- QUIET_APPROACH_ON: arriving under paddle, or gliding the last 25 studs with the motor at
-- idle, makes wary fish 1.25 times as likely for a minute at that spot (Shared/Quiet).
Config.QUIET_APPROACH_ON = false
-- Gemini's co-op items for N4 (Shared/Coop). BUDDY_LOAN_ON: a passenger fishes with the boat
-- owner's rod and line if they are better, and a player within 20 studs of a Creek Pass holder
-- may walk through the creek gate and fish the creek. DOUBLE_HOOKUP_ON: two players within 15
-- studs fighting at once get a banner, and if both land, 10 percent more coins and a Double
-- Haul stamp each. CHUM_ON: the second seat of a canoe or dinghy can toss chum every 90
-- seconds; for 25 seconds bites come a quarter sooner for everyone aboard.
Config.BUDDY_LOAN_ON = false
Config.DOUBLE_HOOKUP_ON = false
Config.CHUM_ON = false

-- BOAT_FEEL_ON (N4, the feel layer, Shared/BoatFeel and ClientModules/BoatFeelClient): each screen
-- draws the boat's art model (hero on desktop, plain on a phone) on the server's flat hull, with
-- trim, lean, bob, the wake, lights from dusk, the horn on H, paddling and seated poses, a camera
-- that eases back with speed, big touch buttons, and the journal's "Send my boat home". The
-- server copies the art to ReplicatedStorage.BoatArt and seats the canoe on its cane seats.
-- Off, boats look and work exactly as before. The server's hull never tilts either way.
Config.BOAT_FEEL_ON = false

function Config.boatsOn(): boolean
	return Config.BOATS_ON and Config.BIG_LAKE_ON
end

-- Saving
Config.DATASTORE_NAME = "PlayerData_v1"
Config.AUTOSAVE_SECONDS = 120

return Config
