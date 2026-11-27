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
local Today = require(Server.Today)
local Daily = require(Shared.Daily)

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
	Remotes.event("FishingEvent"):FireClient(player, "Sold", { coins = coins }) -- coin sound (UNVERIFIED in Studio)
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

-- The shopkeeper's tackle box (L6d): one small gift per real day, the first time a player
-- opens it. A second ask the same day is turned down kindly; missed days lose nothing.
local function onTackleBox(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local day = Today.day()
	local given, msg = Daily.claimGift(data, day)
	toast(player, msg)
	if given then
		print(string.format("[Economy] %s took the tackle box for day %d", player.Name, day))
		PlayerData.changed(player)
		PlayerData.saveNow(player)
	end
end

function EconomyService.start()
	toastEvent = Remotes.event("Toast")

	-- Studio-only test hook: set the player attribute DebugCoins to a number to set their coins.
	if game:GetService("RunService"):IsStudio() then
		PlayerData.onLoad(function(player: Player)
			player:GetAttributeChangedSignal("DebugCoins"):Connect(function()
				local data = PlayerData.get(player)
				local n = player:GetAttribute("DebugCoins")
				if data and type(n) == "number" then
					data.coins = math.max(0, math.floor(n))
					PlayerData.changed(player)
				end
			end)
		end)
	end

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

	Remotes.func("BuyBraid").OnServerInvoke = function(player: Player)
		local data = PlayerData.get(player)
		if not data then
			return false, "That isn't for sale."
		end
		local ok, msg = Inventory.buyBraid(data)
		if ok then
			print(string.format("[Economy] %s bought braided line (now %d coins)", player.Name, data.coins))
			PlayerData.changed(player)
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
			Inventory.setAssist(data, on) -- set by hand: it never turns itself off after this (L4b)
			PlayerData.changed(player)
		end
	end)

	-- Quick Bait (L3): skip the bait bench; every live bait goes on at Okay.
	Remotes.event("SetQuickBait").OnServerEvent:Connect(function(player: Player, on: any)
		local data = PlayerData.get(player)
		if data and type(on) == "boolean" then
			data.quickBait = on
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
	local tackle = lake:FindFirstChild("TacklePrompt", true) :: ProximityPrompt? -- built by Chalkboard
	if tackle then
		tackle.Triggered:Connect(onTackleBox)
	else
		warn("[Economy] TacklePrompt missing (Chalkboard not built?)")
	end
	print("[Economy] ready")
end

return EconomyService
