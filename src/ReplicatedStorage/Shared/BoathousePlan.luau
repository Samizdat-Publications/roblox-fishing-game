--!strict
-- Where the boathouse and the sales mooring stand (leg 3, N4, Config.BOATHOUSE_ON), as pure
-- numbers: Server/Boathouse builds them in Edit, the client reads which boats a player may pick,
-- and Tests/Boathouse.spec checks the placement (clear of the path, the cast lanes, the shot
-- cameras, the slips and the boats' way to the channel). No Roblox services.
--
-- The boathouse (art/README.md, "The boathouse set"): pivot at the base centre, open front to
-- -Z (north, the water). Body 16 wide (x) by 12 deep (z) to the posts' outer faces; the tin
-- overhangs to 8.97 a side, 7.25 at the front and 6.62 at the back; deck top 0.4 up.
--
-- Where (11/28/2026, the builder's call, open to Stewart): on the east flank of PondPoint, the
-- point of land east of the slips. The slips and their keep-clear reach x 26 and the point's nose
-- is a cast lane (x 34 to 46 near the shore), so the 16 stud shed cannot fit between them; east of
-- the nose it stands half on the point and half over the water on piles, its back clear of the
-- wandering lake path (which bulges north to z 80 here). The shed is closed on three sides, so a
-- plank apron runs along its open front and a walkway down its east side to the shore.
local Shared = script.Parent
local BoatData = require(Shared.BoatData)
local BoatFeel = require(Shared.BoatFeel)

local BoathousePlan = {}

export type Rect = { name: string, x1: number, x2: number, z1: number, z2: number }

BoathousePlan.WATER_Y = 0
BoathousePlan.PIVOT = Vector3.new(55, 1.1, 73) -- deck top 1.5, level with the dock's
BoathousePlan.BODY = { halfX = 8, front = 6, back = 6 } -- to the posts' outer faces
BoathousePlan.ROOF = { halfX = 8.97, front = 7.25, back = 6.62 }
BoathousePlan.DECK_TOP = 0.4 -- above the pivot

-- Points on the art, from the pivot (art/README.md).
BoathousePlan.SHOP_BOARD = Vector3.new(-4.5, 4.15, -3.6) -- 4 x 3 face, facing -Z
BoathousePlan.SHOP_BOARD_SIZE = { w = 4, h = 3 }
BoathousePlan.COUNTER = Vector3.new(-4.5, 2.46, -4.16) -- its top centre
BoathousePlan.LANTERN = Vector3.new(-7.55, 4.945, -6.9) -- the glass (0.65 x 0.85 x 0.65) goes here
BoathousePlan.LANTERN_SIZE = Vector3.new(0.65, 0.85, 0.65)
BoathousePlan.RACK_LOW = Vector3.new(0.8, 2.4, 3.4) -- where a hull rests on the lower berth
-- N4 review 1 (11/28/2026): a day fill inside the shed, so its back wall and the rack canoe are not
-- a black hole in daylight: a PointLight in the middle under the tie beam (deck 0.4 + 6 clear),
-- always on, no shadows.
BoathousePlan.FILL = { at = Vector3.new(0, 4.6, 1), brightness = 0.6, range = 14 }
-- "Your boat": a painted board fixed to the east wall, facing the walkway (+X).
BoathousePlan.CHOICE_BOARD = Vector3.new(8.2, 3.6, 0.5)
BoathousePlan.CHOICE_BOARD_SIZE = { w = 3.6, h = 1.8 }

-- The plank apron along the open front and the walkway down the east side to the shore (world
-- rectangles, deck top 1.5). The walkway runs 1 stud onto the land.
BoathousePlan.DECK_Y = 1.5
BoathousePlan.APRON = { name = "Apron", x1 = 47, x2 = 67.5, z1 = 63.5, z2 = 67 } :: Rect
BoathousePlan.WALKWAY = { name = "Walkway", x1 = 64, x2 = 67.5, z1 = 67, z2 = 81 } :: Rect -- meets the apron at z 67
BoathousePlan.PILE = 0.8 -- piles' thickness
BoathousePlan.PILE_BOTTOM = -6

-- The canoe on the lower rack berth: the Cedar Canoe's pivot is its waterline, 0.22 over the keel.
BoathousePlan.CANOE_KEEL = 0.22

function BoathousePlan.cframe(): CFrame
	return CFrame.new(BoathousePlan.PIVOT)
end

-- A point on the boathouse (from its pivot) in the world.
function BoathousePlan.world(p: Vector3): Vector3
	return BoathousePlan.cframe() * p
end

-- The rack canoe: resting on its keel on the lower berth, long axis along X (bow to -X).
function BoathousePlan.rackCanoe(): CFrame
	local r = BoathousePlan.RACK_LOW
	return BoathousePlan.cframe() * CFrame.new(r.X, r.Y + BoathousePlan.CANOE_KEEL, r.Z) * CFrame.Angles(0, math.pi / 2, 0)
end

-- The painted "Boats" carrier, a hair in front of the art's board face, facing -Z (the water).
function BoathousePlan.shopBoard(): CFrame
	local p = BoathousePlan.world(BoathousePlan.SHOP_BOARD + Vector3.new(0, 0, -0.03))
	return CFrame.lookAt(p, p + Vector3.new(0, 0, -1))
end

-- "Your boat" on the east wall, facing the walkway (+X).
function BoathousePlan.choiceBoard(): CFrame
	local p = BoathousePlan.world(BoathousePlan.CHOICE_BOARD)
	return CFrame.lookAt(p, p + Vector3.new(1, 0, 0))
end

function BoathousePlan.lantern(): Vector3
	return BoathousePlan.world(BoathousePlan.LANTERN)
end

-- What stands on the ground or the water (world rectangles): the shed's body, the apron and the
-- walkway. The roof's overhang is 7 studs up and is listed by roofRect.
function BoathousePlan.footprint(): { Rect }
	local p, b = BoathousePlan.PIVOT, BoathousePlan.BODY
	return {
		{ name = "Body", x1 = p.X - b.halfX, x2 = p.X + b.halfX, z1 = p.Z - b.front, z2 = p.Z + b.back },
		BoathousePlan.APRON,
		BoathousePlan.WALKWAY,
	}
end

function BoathousePlan.roofRect(): Rect
	local p, r = BoathousePlan.PIVOT, BoathousePlan.ROOF
	return { name = "Roof", x1 = p.X - r.halfX, x2 = p.X + r.halfX, z1 = p.Z - r.front, z2 = p.Z + r.back }
end

-- Piles under the planks that stand over the water (world x, z): the apron's and walkway's
-- corners and every 6 studs or so along them, and the shed's front corners and middle.
export type Spot = { x: number, z: number }
function BoathousePlan.piles(): { Spot }
	local out: { Spot } = {}
	local a, w = BoathousePlan.APRON, BoathousePlan.WALKWAY
	local inset = BoathousePlan.PILE / 2 + 0.1
	for _, x in { a.x1 + inset, (a.x1 + a.x2) / 2 - 3, (a.x1 + a.x2) / 2 + 3, a.x2 - inset } do
		table.insert(out, { x = x, z = a.z1 + inset })
	end
	for _, z in { 70, 75, 79.5 } do
		table.insert(out, { x = w.x2 - inset, z = z })
		table.insert(out, { x = w.x1 + inset, z = z })
	end
	local p, b = BoathousePlan.PIVOT, BoathousePlan.BODY
	for _, x in { p.X - b.halfX + inset, p.X, p.X + b.halfX - inset } do
		table.insert(out, { x = x, z = p.Z - b.front + inset })
	end
	return out
end

----------------------------------------------------------------------------------------------
-- The sales mooring: off the dock end to the north-east, east of the boats' way from the slips
-- to the channel and north of the Logs. One station per boat in BoatData order, south to north:
-- the boat afloat with its bow to the east (as in the slips), and at its stern a float carrying
-- a price board turned to face the dock end, where everyone stands.
----------------------------------------------------------------------------------------------

BoathousePlan.MOORING_STERN_X = 36 -- every boat's stern lines up here
BoathousePlan.MOORING_FIRST_Z = 8 -- the first (southern) boat's middle
BoathousePlan.MOORING_GAP = 3 -- open water between neighbouring boats
BoathousePlan.FLOAT_GAP = 0.5 -- between a float and its boat's stern
BoathousePlan.FLOAT_SIZE = Vector3.new(4.15, 1.28, 4)
BoathousePlan.FLOAT_SINK = 0.35 -- the float's pivot sits this far under the water line
BoathousePlan.FLOAT_DECK = 0.78 -- its deck top over its pivot
BoathousePlan.BOARD_ON_FLOAT = Vector3.new(0, 0.78, 1.1) -- the PriceBoard's pivot on the float
BoathousePlan.PRICE_FACE = Vector3.new(0, 3.1, -0.2) -- the 3 x 2 face on the PriceBoard, facing -Z
BoathousePlan.PRICE_FACE_SIZE = { w = 3, h = 2 }
BoathousePlan.VIEW = Vector3.new(0, 4, 40) -- the dock end: the boards face it

-- The boats' way from the slips to the channel: from just past the slips' far posts to the
-- channel's mouth, this wide each side. Nothing of the mooring stands in it.
BoathousePlan.ROUTE = { x1 = 24, z1 = 44, x2 = 0, z2 = -78, half = 10 }

-- Thousands with a comma: 1200 -> "1,200".
function BoathousePlan.commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s
	while true do
		local next, k = string.gsub(out, "^(-?%d+)(%d%d%d)", "%1,%2")
		out = next
		if k == 0 then
			return out
		end
	end
end

-- What a boat's price board says: its price while it is on sale, else "Coming soon".
function BoathousePlan.priceText(b: BoatData.Boat): string
	if BoatData.onSale(b) then
		return BoathousePlan.commas(b.price)
	end
	return "Coming soon"
end

-- Model widths and lengths (art/README.md) where they are bigger than BoatData's hull numbers.
local function size(b: BoatData.Boat): (number, number)
	local w, l = b.width, b.length
	if b.id == "Canoe" then
		w, l = 3.18, 12.52
	elseif b.id == "DeepV" then
		w, l = 7.19, 17.75
	end
	return w, l
end

export type Station = {
	id: string,
	text: string,
	boat: CFrame, -- the art model's pivot (BoatFeel.ART lift and yaw applied)
	float: CFrame, -- the MooringFloat's pivot, its cleat (-Z) toward the boat
	board: CFrame, -- the PriceBoard's pivot, its face (-Z) toward VIEW
	face: CFrame, -- the painted carrier on the board's face
	rect: Rect, -- boat and float together, on the water
}

-- Every boat in the game has a station (a boat not for sale shows "Coming soon"), so the Deep-V
-- is on the water from the first session.
function BoathousePlan.mooring(): { Station }
	local out: { Station } = {}
	local z: number? = nil
	local lastHalf = 0
	for _, b in BoatData.list do
		local w, l = size(b)
		local zc = if z == nil then BoathousePlan.MOORING_FIRST_Z else (z :: number) - (lastHalf + BoathousePlan.MOORING_GAP + w / 2)
		z = zc
		lastHalf = w / 2
		local stern = BoathousePlan.MOORING_STERN_X
		local art = BoatFeel.ART[b.id]
		local lift = if art then art.lift else 0
		local yaw = if art then math.rad(art.yaw) else 0
		-- The model's bow is -Z; a turn of -90 degrees points it east (+X).
		local boat = CFrame.new(stern + l / 2, BoathousePlan.WATER_Y + lift, zc) * CFrame.Angles(0, -math.pi / 2 + yaw, 0)
		local fx = stern - BoathousePlan.FLOAT_GAP - BoathousePlan.FLOAT_SIZE.X / 2
		local fpos = Vector3.new(fx, BoathousePlan.WATER_Y - BoathousePlan.FLOAT_SINK, zc)
		local float = CFrame.lookAt(fpos, fpos + Vector3.new(1, 0, 0)) -- the cleat to the boat
		local bpos = float * BoathousePlan.BOARD_ON_FLOAT
		local flatView = Vector3.new(BoathousePlan.VIEW.X, bpos.Y, BoathousePlan.VIEW.Z)
		local board = CFrame.lookAt(bpos, flatView)
		local face = board * CFrame.new(BoathousePlan.PRICE_FACE + Vector3.new(0, 0, -0.03))
		local halfF = BoathousePlan.FLOAT_SIZE.Z / 2
		table.insert(out, {
			id = b.id,
			text = BoathousePlan.priceText(b),
			boat = boat,
			float = float,
			board = board,
			face = face,
			rect = {
				name = b.id,
				x1 = fx - BoathousePlan.FLOAT_SIZE.X / 2,
				x2 = stern + l,
				z1 = zc - math.max(w / 2, halfF),
				z2 = zc + math.max(w / 2, halfF),
			},
		})
	end
	return out
end

-- Distance in x, z from (x, z) to the boats' way (its centre line).
function BoathousePlan.routeDist(x: number, z: number): number
	local r = BoathousePlan.ROUTE
	local dx, dz = r.x2 - r.x1, r.z2 - r.z1
	local t = math.clamp(((x - r.x1) * dx + (z - r.z1) * dz) / (dx * dx + dz * dz), 0, 1)
	return math.sqrt((x - r.x1 - dx * t) ^ 2 + (z - r.z1 - dz * t) ^ 2)
end

----------------------------------------------------------------------------------------------
-- "Your boat": the boats a player may pick to wait at their slip (owned and in the game now),
-- in the shop's order. BoatLogic.choose is the rule the server applies.
----------------------------------------------------------------------------------------------

function BoathousePlan.yours(data: any): { string }
	local out: { string } = {}
	local owned = if type(data) == "table" and type(data.boats) == "table" then data.boats else {}
	for _, b in BoatData.list do
		if owned[b.id] == true and BoatData.available(b) then
			table.insert(out, b.id)
		end
	end
	return out
end

return BoathousePlan
