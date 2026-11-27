--!strict
-- One list of remote names. The server creates them; the client waits for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"Cast", -- client: (direction: Vector3, power: number)
	"Hook", -- client: ()
	"FightResult", -- client: (won: boolean)
	"CancelCast", -- client: ()
	"Wiggle", -- client: (), one press to work a snagged hook free (L2b)
	"Twitch", -- client: (), a quick tap while waiting jiggles the bait (L4)
	"Equip", -- client: (baitId: string)
	"SetAssist", -- client: (on: boolean)
	"SetQuickBait", -- client: (on: boolean), skip the bait bench (L3)
	"Rig", -- client: (baitId: string, hook: string, timeline: { {down, up} }, skipped: boolean), the bait bench result (L3)
	"EquipRod", -- client: (rodId: string)
	"ChooseBoat", -- client: (boatId: string), which owned boat waits at your slip
	"BoatInput", -- client: (throttle: number, steer: number), the helm's controls, ~10 a second
	"FishingEvent", -- server: (kind: string, payload: table)
	"State", -- server: (snapshot: table)
	"Toast", -- server: (text: string)
}
local FUNCTIONS = {
	"RequestState", -- () -> snapshot
	"Buy", -- (baitId) -> (ok, message)
	"BuyRod", -- (rodId) -> (ok, message)
	"BuyBoat", -- (boatId) -> (ok, message)
	"FishFinder", -- () -> marks under the boat, for the Deep-V's navigator only
	"PondAction", -- (action: "keep"|"sell"|"release", index) -> (ok, message)
}

local Remotes = {}

local function folder(): Folder
	if RunService:IsServer() then
		local f = ReplicatedStorage:FindFirstChild("Remotes")
		if not f then
			f = Instance.new("Folder")
			f.Name = "Remotes"
			f.Parent = ReplicatedStorage
		end
		return f :: Folder
	end
	return ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

-- Server only: make sure every remote exists.
function Remotes.setup()
	local f = folder()
	for _, n in EVENTS do
		if not f:FindFirstChild(n) then
			local r = Instance.new("RemoteEvent")
			r.Name = n
			r.Parent = f
		end
	end
	for _, n in FUNCTIONS do
		if not f:FindFirstChild(n) then
			local r = Instance.new("RemoteFunction")
			r.Name = n
			r.Parent = f
		end
	end
end

function Remotes.event(name: string): RemoteEvent
	return folder():WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return folder():WaitForChild(name) :: RemoteFunction
end

return Remotes
