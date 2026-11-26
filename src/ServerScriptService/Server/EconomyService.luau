--!strict
-- Selling, buying, equipping bait and the assist toggle. All coin math happens here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaitData = require(Shared.BaitData)
local Config = require(Shared.Config)
local Inventory = require(Shared.Inventory)
local Remotes = require(Shared.Remotes)

local Server = script.Parent
local PlayerData = require(Server.PlayerData)
local RodService = require(Server.RodService)
local GoalService = require(Server.GoalService)

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
	GoalService.onSell(player, data, coins)
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

	Remotes.func("BuyRod").OnServerInvoke = function(player: Player, rodId: any)
		local data = PlayerData.get(player)
		if not data or type(rodId) ~= "string" then
			return false, "That rod isn't for sale."
		end
		local ok, msg = Inventory.buyRod(data, rodId)
		if ok then
			print(string.format("[Economy] %s bought rod %s (now %d coins)", player.Name, rodId, data.coins))
			PlayerData.changed(player)
			RodService.refresh(player)
		end
		return ok, msg
	end

	Remotes.event("EquipRod").OnServerEvent:Connect(function(player: Player, rodId: any)
		local data = PlayerData.get(player)
		if data and type(rodId) == "string" and Inventory.equipRod(data, rodId) then
			PlayerData.changed(player)
			RodService.refresh(player)
		end
	end)

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
	local creekPrompt = lake:FindFirstChild("CreekPrompt", true) :: ProximityPrompt?
	if creekPrompt then
		creekPrompt.Triggered:Connect(function(player: Player)
			local data = PlayerData.get(player)
			if not data then
				return
			end
			if data.creekPass then
				toast(player, "Your Creek Pass is good. Head on in.")
				return
			end
			if data.coins < Config.CREEK_PASS_PRICE then
				toast(player, string.format("A Creek Pass costs %d coins. You have %d.", Config.CREEK_PASS_PRICE, data.coins))
				return
			end
			data.coins -= Config.CREEK_PASS_PRICE
			data.creekPass = true
			print(string.format("[Economy] %s bought the Creek Pass (now %d coins)", player.Name, data.coins))
			toast(player, "Creek Pass bought! The gate is open. Trout, smallmouth and walleye are waiting.")
			PlayerData.changed(player)
			PlayerData.saveNow(player)
		end)
	else
		warn("[Economy] CreekPrompt missing")
	end
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
