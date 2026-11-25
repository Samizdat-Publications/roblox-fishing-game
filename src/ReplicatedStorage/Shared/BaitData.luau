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
}

local list: { Bait } = {
	{ id = "Worm", name = "Worms", kind = "live", pack = 10, price = 8, blurb = "Everything eats a worm. Panfish love them." },
	{ id = "Cricket", name = "Crickets", kind = "live", pack = 10, price = 12, blurb = "Sunfish can't resist a cricket near weeds." },
	{ id = "Minnow", name = "Minnows", kind = "live", pack = 10, price = 20, blurb = "Small fish for bigger fish: perch, crappie, bass." },
	{ id = "Stinkbait", name = "Stinkbait", kind = "live", pack = 10, price = 16, blurb = "Smelly. Bottom feeders find it in the dark." },
	{ id = "Spinner", name = "Spinner", kind = "lure", pack = 1, price = 60, blurb = "Flashing blade. Hunters chase it in daylight." },
	{ id = "PlasticWorm", name = "Plastic Worm", kind = "lure", pack = 1, price = 80, blurb = "Slow and wiggly. Bass grab it around cover." },
}

local byId: { [string]: Bait } = {}
for _, b in list do
	byId[b.id] = b
end

return {
	list = list,
	byId = byId,
}
