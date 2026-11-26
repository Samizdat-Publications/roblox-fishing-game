--!strict
-- Boats. UNVERIFIED: written overnight 2026-11-26 without Studio; nothing uses this yet.
-- See docs/superpowers/plans/2026-11-26-boat.md. The server applies these numbers when it
-- drives the boat and checks where it went; the client only shows them.
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
	seats: number, -- driver plus passengers (the second seat is for two-person play later)
	length: number, -- studs, hull size for the model and the dock slip
	width: number,
	color: Color3,
	blurb: string,
}

local list: { Boat } = {
	{
		id = "JonBoat",
		name = "Jon Boat",
		price = 1500,
		maxSpeed = 24,
		reverseSpeed = 8,
		accel = 1.5,
		turnRate = 70,
		idleTurn = 0.35,
		castSpeed = 2,
		seats = 2,
		length = 14,
		width = 6,
		color = Color3.fromRGB(120, 140, 110),
		blurb = "A flat-bottom boat with a little outboard. Takes you and a friend out to the Big Lake.",
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
