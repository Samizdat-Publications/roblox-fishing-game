--!strict
-- Boats. UNVERIFIED: written overnight 2026-11-26 without Studio; nothing uses this yet.
-- See docs/superpowers/plans/2026-11-26-boat.md. The server applies these numbers when it
-- drives a boat and checks where it went; the client only shows them.
--
-- Order (Stewart, 2026-11-26): first a single-player inflatable dinghy, then a boat that
-- needs two players to pilot and is the only way into the deep "blue water".
export type Boat = {
	id: string,
	name: string,
	price: number,
	maxSpeed: number, -- studs per second at full throttle
	reverseSpeed: number, -- studs per second in reverse
	accel: number, -- how quickly speed reaches the throttle's target (per second)
	turnRate: number, -- degrees per second at full steer and full speed
	idleTurn: number, -- share of turnRate available when nearly stopped (0 to 1)
	castSpeed: number, -- you can cast only while the boat is slower than this
	seats: number, -- people aboard at most
	crew: number, -- people who must be aboard before it will move
	blueWater: boolean, -- may it cross into the deep blue water?
	length: number, -- studs, hull size for the model and the slip
	width: number,
	color: Color3,
	blurb: string,
}

local list: { Boat } = {
	{
		id = "Dinghy",
		name = "Inflatable Dinghy",
		price = 1200,
		maxSpeed = 12,
		reverseSpeed = 5,
		accel = 2,
		turnRate = 90,
		idleTurn = 0.5,
		castSpeed = 2,
		seats = 1,
		crew = 1,
		blueWater = false,
		length = 8,
		width = 4,
		color = Color3.fromRGB(235, 120, 40),
		blurb = "A one-person inflatable with a tiny motor. Gets you out to the Big Lake, but it's too small for blue water.",
	},
	{
		id = "DeepV",
		name = "Deep-V Boat",
		price = 4000,
		maxSpeed = 26,
		reverseSpeed = 8,
		accel = 1.2,
		turnRate = 60,
		idleTurn = 0.3,
		castSpeed = 2,
		seats = 2,
		crew = 2,
		blueWater = true,
		length = 16,
		width = 7,
		color = Color3.fromRGB(235, 235, 230),
		blurb = "A big-water boat for two: one at the helm, one on the fish finder. The only way into the blue water.",
	},
}

local byId: { [string]: Boat } = {}
for _, b in list do
	byId[b.id] = b
end

return {
	list = list,
	byId = byId,
}
