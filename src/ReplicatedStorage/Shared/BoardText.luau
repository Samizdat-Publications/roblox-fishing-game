--!strict
-- What the Today on the Lake chalkboard says (leg 3, N2, Config.BOARD_CARD_ON): a short slate
-- you can read from the path (the weather in a few words, the fish of the day, a teaser) and
-- the full field-guide card the "Read today's board" prompt opens (the forecast, the fish of
-- the day with its rarity, the Legendary rumour, a handwritten note). Both come from the same
-- day number, so the slate, the card and the old board never disagree. The server publishes
-- the day as the workspace attribute "BoardDay" (Server/Chalkboard); the client builds the
-- card from it with this module. Pure logic, no Roblox services.
local Shared = script.Parent
local Daily = require(Shared.Daily)
local Weather = require(Shared.Weather)
local FishData = require(Shared.FishData)
local Rarity = require(Shared.Rarity)

local BoardText = {}

BoardText.TITLE = "Today on the Lake"
-- Longest each slate line may be, so it stays big enough to read from 10 to 15 studs.
BoardText.SLATE_MAX = { weather = 24, fish = 24, teaser = 34 }

export type Slate = { weather: string, fish: string, teaser: string }
export type Card = {
	title: string,
	weekday: string,
	forecast: string,
	fishId: string,
	fishName: string,
	fishTier: string, -- a Rarity id
	fishTierName: string,
	fishNote: string,
	rumourFish: string, -- the Legendary's name
	rumour: string,
	note: string, -- the shopkeeper's handwritten line
}

local NOTES = {
	"Tight lines!",
	"Bring me back a good story.",
	"Board's fresh every morning.",
	"Mind the weather out there.",
}

-- The date's weather plan (the same one the chalkboard and WeatherService use).
function BoardText.plan(day: number): Weather.DayPlan
	return Weather.planForDate(day)
end

-- The weather in a few words: the kind's short name, with the wind's side on a windy day.
function BoardText.weatherWords(plan: Weather.DayPlan): string
	local k = Weather.byId[plan.kind] or Weather.byId.Clear
	if plan.kind == "Wind" and plan.wind then
		return "Windy from the " .. plan.wind
	end
	return k.name
end

function BoardText.slate(day: number, bigLake: boolean?): Slate
	local fish = FishData.byId[Daily.fishOfDay(day)]
	local rumour = Daily.rumour(day, bigLake)
	local legend = FishData.byId[rumour.species]
	return {
		weather = BoardText.weatherWords(BoardText.plan(day)),
		fish = fish.name,
		teaser = string.format("Heard: the %s is about.", legend.name),
	}
end

function BoardText.card(day: number, bigLake: boolean?): Card
	local forecast = Weather.forecast(BoardText.plan(day), -1) -- no moon: moons run per server
	local b = Daily.board(day, forecast, bigLake)
	local fishId = Daily.fishOfDay(day)
	local fish = FishData.byId[fishId]
	local tier = Rarity.of(fish)
	local rumour = Daily.rumour(day, bigLake)
	return {
		title = BoardText.TITLE,
		weekday = b.weekday,
		forecast = b.weather,
		fishId = fishId,
		fishName = b.fish,
		fishTier = tier,
		fishTierName = (Rarity.byId[tier] or Rarity.byId.Common).name,
		fishNote = b.fishNote,
		rumourFish = FishData.byId[rumour.species].name,
		rumour = b.rumour,
		note = NOTES[day % #NOTES + 1] .. " - the shopkeeper",
	}
end

return BoardText
