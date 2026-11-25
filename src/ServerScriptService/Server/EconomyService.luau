--!strict
-- Selling, buying, equipping bait and the assist toggle. All coin math happens here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaitData = require(Shared.BaitData)
local Inventory = require(Shared.Inventory)
local Remotes = require(Shared.Remotes)

local Server = script.Parent
local PlayerData = require(Server.PlayerData)

local EconomyService = {}

local toastEvent: RemoteEvent

local function toast(player: Player, text: string)
	toastEvent:FireClient(player, text)
end

local function onSell(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local coins, count = Inventory.sellAll(data)
	if count == 0 then
		toast(player, "Nothing to sell yet. Go catch something!")
		return
	end
	print(string.format("[Economy] %s sold %d fish for %d coins (now %d)", player.Name, count, coins, data.coins))
	toast(player, string.format("Sold %d fish for %d coins.", count, coins))
	PlayerData.changed(player)
	PlayerData.saveNow(player)
end

local function onShopOpened(player: Player)
	local data = PlayerData.get(player)
	if data and Inventory.freeWormsIfStuck(data) then
		toast(player, "You look broke. The shopkeeper hands you a few free worms.")
		PlayerData.changed(player)
	end
end

function EconomyService.start()
	toastEvent = Remotes.event("Toast")

	Remotes.func("Buy").OnServerInvoke = function(player: Player, baitId: any)
		local data = PlayerData.get(player)
		if not data or type(baitId) ~= "string" or not BaitData.byId[baitId] then
			return false, "That isn't for sale."
		end
		local ok, msg = Inventory.buy(data, baitId)
		if ok then
			print(string.format("[Economy] %s bought %s (now %d coins)", player.Name, baitId, data.coins))
			PlayerData.changed(player)
		end
		return ok, msg
	end

	Remotes.event("Equip").OnServerEvent:Connect(function(player: Player, baitId: any)
		local data = PlayerData.get(player)
		if data and type(baitId) == "string" and Inventory.equip(data, baitId) then
			PlayerData.changed(player)
		end
	end)

	Remotes.event("SetAssist").OnServerEvent:Connect(function(player: Player, on: any)
		local data = PlayerData.get(player)
		if data and type(on) == "boolean" then
			data.assist = on
			PlayerData.changed(player)
		end
	end)

	local lake = workspace:WaitForChild("Lake")
	local sell = lake:FindFirstChild("SellPrompt", true) :: ProximityPrompt?
	local shop = lake:FindFirstChild("ShopPrompt", true) :: ProximityPrompt?
	if sell then
		sell.Triggered:Connect(onSell)
	else
		warn("[Economy] SellPrompt missing")
	end
	if shop then
		shop.Triggered:Connect(onShopOpened)
	else
		warn("[Economy] ShopPrompt missing")
	end
	print("[Economy] ready")
end

return EconomyService
