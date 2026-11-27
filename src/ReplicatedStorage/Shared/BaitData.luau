--!strict
-- Bait and tackle. Live bait comes in packs and is used up when a fish takes it.
-- Lures are bought once and kept.
export type Bait = {
	id: string,
	name: string,
	kind: "live" | "lure",
	pack: number,
	price: number,
	blurb: string,
	castMult: number?, -- how much farther it casts at full power (heavier lures fly farther); missing means 1
	color: Color3?, -- what it looks like on the hook (the bait at the rod tip and on the bench, L3)
}

local list: { Bait } = {
	{ id = "Worm", name = "Worms", kind = "live", pack = 10, price = 8, blurb = "Everything eats a worm. Panfish love them.", color = Color3.fromRGB(196, 110, 120) },
	{ id = "Cricket", name = "Crickets", kind = "live", pack = 10, price = 12, blurb = "Sunfish can't resist a cricket near weeds.", color = Color3.fromRGB(70, 55, 40) },
	{ id = "Minnow", name = "Minnows", kind = "live", pack = 10, price = 20, blurb = "Small fish for bigger fish: perch, crappie, bass.", castMult = 1.05, color = Color3.fromRGB(175, 185, 195) },
	{ id = "Stinkbait", name = "Stinkbait", kind = "live", pack = 10, price = 16, blurb = "Smelly. Bottom feeders find it in the dark.", color = Color3.fromRGB(120, 105, 60) },
	{ id = "Spinner", name = "Spinner", kind = "lure", pack = 1, price = 100, blurb = "Flashing blade. Hunters chase it in daylight.", castMult = 1.25, color = Color3.fromRGB(230, 200, 60) },
	{ id = "PlasticWorm", name = "Plastic Worm", kind = "lure", pack = 1, price = 100, blurb = "Slow and wiggly. Bass grab it around cover.", castMult = 1.1, color = Color3.fromRGB(90, 50, 140) },
}

local byId: { [string]: Bait } = {}
for _, b in list do
	byId[b.id] = b
end

return {
	list = list,
	byId = byId,
}
