--!strict
-- One list of remote names. The server creates them; the client waits for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"Cast", -- client: (direction: Vector3, power: number)
	"Hook", -- client: ()
	"FightResult", -- client: (won: boolean)
	"CancelCast", -- client: ()
	"Equip", -- client: (baitId: string)
	"SetAssist", -- client: (on: boolean)
	"EquipRod", -- client: (rodId: string)
	"ChooseBoat", -- client: (boatId: string), which owned boat waits at your slip
	"FishingEvent", -- server: (kind: string, payload: table)
	"State", -- server: (snapshot: table)
	"Toast", -- server: (text: string)
}
local FUNCTIONS = {
	"RequestState", -- () -> snapshot
	"Buy", -- (baitId) -> (ok, message)
	"BuyRod", -- (rodId) -> (ok, message)
	"BuyBoat", -- (boatId) -> (ok, message)
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
