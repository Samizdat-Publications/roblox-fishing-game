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
	lineLb: number, -- the line's rating in pounds (L4d): fish much heavier can snap it on Tight or Medium drag
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
		lineLb = 6,
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
		lineLb = 10,
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
		lineLb = 15,
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

local KG_PER_LB = 0.45359237

-- Braided line (a one-time buy at Bait and Tackle): this many pounds on top of any rod's line.
RodData.BRAID_LB = 4
RodData.BRAID_PRICE = 120

-- The line rating in pounds for this rod, with braided line if the player owns it.
function RodData.lineLbFor(rodId: string?, braid: boolean?): number
	local rod = byId[rodId or ""] or byId.Willow
	return rod.lineLb + (if braid then RodData.BRAID_LB else 0)
end

-- The fish's weight over this rod's line rating (L4d, FightModel's `load`): 1 means the fish
-- weighs exactly what the line is rated for.
function RodData.lineLoad(kg: number, rodId: string?, braid: boolean?): number
	return (kg / KG_PER_LB) / RodData.lineLbFor(rodId, braid)
end

-- "6 lb line", for the shop, the journal and beside the fight bar.
function RodData.lineText(rodId: string?, braid: boolean?): string
	return string.format("%d lb line", RodData.lineLbFor(rodId, braid))
end

-- A copy of a fish's fight profile with this rod's help applied.
function RodData.applyFight(profile: any, rodId: string): any
	local rod = byId[rodId] or byId.Willow
	local copy = table.clone(profile)
	copy.zone = math.min(0.6, profile.zone * rod.zoneMult)
	copy.heavy = profile.heavy * (1 - rod.heavyResist)
	return copy
end

return RodData
