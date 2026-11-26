--!strict
-- Rarity tiers and their colours (docs/DIRECTION.md section 3). Each species has one tier
-- (FishData `tier`). The colour is used everywhere the fish shows: catch card, journal,
-- shadows, stingers. Godlike shifts through the rainbow, one full cycle every 2 seconds.
-- Pure data, no Roblox services. UNVERIFIED in Studio (written 2026-11-26 in the cloud).
local Rarity = {}

export type Tier = { id: string, name: string, color: Color3, feel: string }

Rarity.list = {
	{ id = "Common", name = "Common", color = Color3.fromRGB(175, 180, 185), feel = "every cast" },
	{ id = "Uncommon", name = "Uncommon", color = Color3.fromRGB(95, 200, 110), feel = "most sessions" },
	{ id = "Rare", name = "Rare", color = Color3.fromRGB(80, 150, 240), feel = "a good find" },
	{ id = "Epic", name = "Epic", color = Color3.fromRGB(170, 95, 235), feel = "the right spot, bait and time" },
	{ id = "Legendary", name = "Legendary", color = Color3.fromRGB(250, 175, 40), feel = "the story you tell later" },
	{ id = "Mythic", name = "Mythic", color = Color3.fromRGB(240, 75, 125), feel = "a once-in-a-while legend" },
	{ id = "Godlike", name = "Godlike", color = Color3.fromRGB(255, 255, 255), feel = "a myth players hunt for" },
} :: { Tier }

Rarity.byId = {} :: { [string]: Tier }
Rarity.rank = {} :: { [string]: number } -- Common 1 up to Godlike 7
for i, t in Rarity.list do
	Rarity.byId[t.id] = t
	Rarity.rank[t.id] = i
end

Rarity.RAINBOW_SECONDS = 2

-- The colour to draw a tier at time t (seconds). Unknown tiers read as Common.
function Rarity.colorAt(tierId: string?, t: number): Color3
	if tierId == "Godlike" then
		local hue = (t / Rarity.RAINBOW_SECONDS) % 1
		return Color3.fromHSV(hue, 0.65, 1)
	end
	local tier = Rarity.byId[tierId or "Common"] or Rarity.byId.Common
	return tier.color
end

-- The tier of a species, Common when it has none.
function Rarity.of(species: any): string
	local t = species and species.tier
	return if type(t) == "string" and Rarity.byId[t] then t else "Common"
end

-- Size classes for a single catch, rolled on the server at the hook.
-- Monster 0.2 percent: 1.25 to 1.5 times the species' longest. Trophy 2 percent: 0.95 to
-- 1.1 times it. Weight follows length as for any fish, so the payout grows on its own.
Rarity.MONSTER_CHANCE = 0.002
Rarity.TROPHY_CHANCE = 0.02
Rarity.MONSTER_LENGTH = { 1.25, 1.5 }
Rarity.TROPHY_LENGTH = { 0.95, 1.1 }

-- Harder fights for big ones: less progress per second, more pull against your lift.
Rarity.FIGHT = {
	normal = { gain = 1, heavy = 0 },
	trophy = { gain = 0.8, heavy = 0.15 },
	monster = { gain = 0.65, heavy = 0.3 },
}
Rarity.HEAVY_CAP = 0.9

-- Old catches saved before size classes read as normal.
function Rarity.sizeClassOf(fish: any): string
	local c = fish and fish.sizeClass
	return if c == "trophy" or c == "monster" then c else "normal"
end

return Rarity
