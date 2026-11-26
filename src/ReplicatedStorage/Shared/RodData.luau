--!strict
-- Rods (each comes with its reel). Better rods cast further and make the fight easier;
-- the server applies these numbers, the client only shows them.
export type Rod = {
	id: string,
	name: string,
	price: number,
	castBonus: number, -- extra studs at any power
	zoneMult: number, -- catch zone size multiplier
	heavyResist: number, -- share of a heavy fish's pull the rod soaks up (0 to 1)
	color: Color3,
	length: number, -- studs, for the rod in your hand
	blurb: string,
}

local list: { Rod } = {
	{
		id = "Willow",
		name = "Willow Rod",
		price = 0,
		castBonus = 0,
		zoneMult = 1,
		heavyResist = 0,
		color = Color3.fromRGB(110, 80, 50),
		length = 6,
		blurb = "Your first rod. Bendy, but it gets the job done.",
	},
	{
		id = "Fiberglass",
		name = "Fiberglass Rod",
		price = 150,
		castBonus = 8,
		zoneMult = 1.15,
		heavyResist = 0,
		color = Color3.fromRGB(230, 200, 60),
		length = 6.6,
		blurb = "Casts further and gives you a bigger catch zone.",
	},
	{
		id = "Graphite",
		name = "Graphite Rod",
		price = 900,
		castBonus = 16,
		zoneMult = 1.3,
		heavyResist = 0.5,
		color = Color3.fromRGB(40, 45, 60),
		length = 7.2,
		blurb = "Longest casts, biggest catch zone, and heavy fish pull half as hard.",
	},
}

local byId: { [string]: Rod } = {}
for _, r in list do
	byId[r.id] = r
end

local RodData = { list = list, byId = byId }

-- A copy of a fish's fight profile with this rod's help applied.
function RodData.applyFight(profile: any, rodId: string): any
	local rod = byId[rodId] or byId.Willow
	local copy = table.clone(profile)
	copy.zone = math.min(0.6, profile.zone * rod.zoneMult)
	copy.heavy = profile.heavy * (1 - rod.heavyResist)
	return copy
end

return RodData
