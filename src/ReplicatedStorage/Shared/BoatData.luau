--!strict
-- Boats. Written overnight 2026-11-26; the dinghy proven in Studio 11/27/2026 (L7).
-- See docs/superpowers/plans/2026-11-26-boat.md. The server applies these numbers when it
-- drives a boat and checks where it went; the client only shows them.
--
-- Order (Stewart, 2026-11-26): first a single-player inflatable dinghy, then a boat that
-- needs two players to pilot and is the only way into the deep "blue water".
--
-- Leg 3, N4 (the fleet, Config.CANOE_ON): every boat says how it moves (motor or paddle), how
-- quiet it is, how deep it sits, where it lives, where it may go and land, and what each seat
-- is for. The Cedar Canoe joins (350 coins). The canoe's length and width are placeholders
-- until its model is made. The table is docs/superpowers/plans/2026-11-27-leg-3.md, "The fleet".
local Config = require(script.Parent.Config)

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
	seats: number, -- people aboard at most (the dinghy's second seat waits for CANOE_ON: BoatData.seatsOf)
	crew: number, -- people who must be aboard before it will move
	stations: { string }, -- what each seat is, by seat: the first is always "Helm" (it steers)
	paddle: boolean, -- paddled, not motored: always quiet, and the only kind allowed in Lily Cove
	pairSpeed: number, -- top speed with a second paddler in the bow (maxSpeed for motor boats)
	quiet: boolean, -- arriving in it counts as a quiet approach whatever the throttle (Shared/Quiet)
	draft: number, -- studs below the water line (shallow water and weeds, N5)
	home: string, -- "dock" (the slips) or "marina" (the Big Lake's pier, built in N5)
	waters: { [string]: boolean }, -- BoatRules.waterAt names it may be on, once CANOE_ON is on
	lands: string, -- "shore" (any shore or pier) or "pier" (piers only)
	chum: boolean, -- its second seat can toss chum (Config.CHUM_ON; the Deep-V's waits for N5)
	switch: string?, -- a Config switch that must be on before it is sold or shown
	blueWater: boolean, -- may it cross into the deep blue water?
	forSale: boolean, -- false: the shop shows it as coming soon and the server won't sell it
	length: number, -- studs, hull size for the model and the slip
	width: number,
	color: Color3,
	blurb: string,
}

local list: { Boat } = {
	{
		id = "Canoe",
		name = "Cedar Canoe",
		price = 350,
		maxSpeed = 7, -- one paddler; 11 with two (pairSpeed)
		reverseSpeed = 3,
		accel = 1.5,
		turnRate = 75,
		idleTurn = 0.6,
		castSpeed = 2,
		seats = 2,
		crew = 1,
		stations = { "Helm", "Bow" }, -- the stern paddler steers; the bow paddler adds speed
		paddle = true,
		pairSpeed = 11,
		quiet = true,
		draft = 0.5,
		home = "dock",
		waters = { Lake = true, Channel = true, Basin = true, LilyCove = true },
		lands = "shore",
		chum = true,
		switch = "CANOE_ON",
		blueWater = false,
		forSale = true,
		length = 12, -- placeholder until the model is made
		width = 3, -- placeholder
		color = Color3.fromRGB(176, 112, 62), -- varnished cedar
		blurb = "A cedar-strip canoe for two. Quiet on the water, and the only boat that can slip into Lily Cove. Faster with a friend paddling up front.",
	},
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
		seats = 2, -- 1 until CANOE_ON (BoatData.seatsOf)
		crew = 1,
		stations = { "Helm", "Passenger" },
		paddle = false,
		pairSpeed = 12,
		quiet = false,
		draft = 1,
		home = "dock",
		waters = { Lake = true, Channel = true, Basin = true },
		lands = "shore",
		chum = true,
		blueWater = false,
		forSale = true,
		-- N4 review 2 (11/28/2026): the art drawn 1.375 times (BoatFeel.ART.Dinghy.scale), since the
		-- avatar's shoulders spanned its whole 4 stud beam; was 8 by 4.
		length = 11,
		width = 5.5,
		color = Color3.fromRGB(204, 108, 48), -- orange (N1 review 2; the off-white 226,220,204 read as a stock white block; first orange was 235,120,40)
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
		stations = { "Helm", "Navigator" },
		paddle = false,
		pairSpeed = 26,
		quiet = false,
		draft = 2,
		home = "marina", -- too tall for the footbridge; until N5 builds the marina it uses the slips
		waters = { Basin = true, BlueWater = true },
		lands = "pier",
		chum = false, -- N5
		blueWater = true,
		-- Waits for the two-player playtest (Liam's account in the place). Stewart, 11/26/2026:
		-- it must move with one player too (crew becomes 1 when it goes on sale).
		forSale = false,
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

-- Is this boat in the game right now (its switch, if it has one, is on)? A boat that isn't
-- is neither shown in the shop nor sold.
local function available(b: Boat): boolean
	return b.switch == nil or (Config :: any)[b.switch] == true
end

-- For sale now: on sale and switched on.
local function onSale(b: Boat): boolean
	return b.forSale and available(b)
end

-- The boats the shop lists, in order.
local function shown(): { Boat }
	local out = {}
	for _, b in list do
		if available(b) then
			table.insert(out, b)
		end
	end
	return out
end

-- Seats built on the boat now: the dinghy's passenger seat waits for the fleet switch.
local function seatsOf(b: Boat): number
	if b.id == "Dinghy" and not Config.CANOE_ON then
		return 1
	end
	return b.seats
end

-- The second seat's name ("Bow", "Passenger", "Navigator"), or nil for a one-seat boat now.
local function secondSeat(b: Boat): string?
	return if seatsOf(b) >= 2 then b.stations[2] else nil
end

return {
	list = list,
	byId = byId,
	available = available,
	onSale = onSale,
	shown = shown,
	seatsOf = seatsOf,
	secondSeat = secondSeat,
}
