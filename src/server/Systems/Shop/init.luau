--!strict
-- Robux + monthly shop: game pass ownership (account or gifted) and x2 gold/xp multipliers, gift / premium pass prompts,
-- the game's only ProcessReceipt (purchaseId dedupe, waits for the save), monthly shop with per-month quotas (UTC).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local Period = require(ReplicatedStorage.Shared.Period)
local Formula = require(ReplicatedStorage.Shared.Formula)
local ShopConfig = require(ReplicatedStorage.Shared.Config.Shop)
local PassConfig = require(ReplicatedStorage.Shared.Config.BattlePass)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)
local Guard = require(ServerScriptService.Server.Util.Guard)
local Replication = require(script.Parent.Replication)
local Currency = require(script.Parent.Currency)
local Rewards = require(script.Parent.Rewards)
local BattlePass = require(script.Parent.BattlePass)

-- Passes owned on the Roblox account this session (UserOwnsGamePassAsync + purchases made here).
local accountOwned: { [Player]: { [string]: boolean } } = {}

local productKeyById: { [number]: string } = {}
for key, id in ShopConfig.Products do
	if id > 0 then
		productKeyById[id] = key
	end
end

local Shop = {}

function Shop.Owns(player: Player, key: string): boolean
	local account = accountOwned[player]
	if account ~= nil and account[key] then
		return true
	end
	local data = PlayerData.Data(player)
	return data ~= nil and data.Purchases.Owned[key] == true
end

local function mult(player: Player, key: string): number
	local def = ShopConfig.PassByKey[key]
	return if def ~= nil and Shop.Owns(player, key) then def.Mult else 1
end

-- Applied to online level income and to offline earnings.
function Shop.GoldMult(player: Player): number
	return mult(player, "Gold2x")
end

function Shop.XpMult(player: Player): number
	return mult(player, "Xp2x")
end

local function sendPasses(player: Player)
	local view: { [string]: boolean } = {}
	for _, def in ShopConfig.Passes do
		view[def.Key] = Shop.Owns(player, def.Key)
	end
	Replication.Notify(player, "Passes", view)
end

local function checkAccountPasses(player: Player)
	local owned: { [string]: boolean } = accountOwned[player] or {}
	accountOwned[player] = owned
	for _, def in ShopConfig.Passes do
		if def.PassId > 0 then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, def.PassId)
			end)
			if player.Parent ~= Players then
				return
			end
			if ok then
				owned[def.Key] = result == true
			else
				warn(`[Shop] pass check failed for {player.Name} ({def.Key}): {result}`)
			end
		end
	end
	sendPasses(player)
end

-- Monthly shop state, reset when the UTC month changed.
local function shopMonth(player: Player, data: Types.ProfileData): Types.ShopState
	local key = Period.Key("Monthly")
	if data.Shop.Month ~= key then
		data.Shop = { Month = key, Bought = {} }
		Replication.Set(player, { "Shop" }, data.Shop)
	end
	return data.Shop
end

local function countBought(player: Player, data: Types.ProfileData, id: string)
	local state = shopMonth(player, data)
	state.Bought[id] = (state.Bought[id] or 0) + 1
	Replication.Set(player, { "Shop", "Bought", id }, state.Bought[id])
end

local function setOwned(player: Player, data: Types.ProfileData, key: string, fromName: string?): boolean
	local had = Shop.Owns(player, key)
	data.Purchases.Owned[key] = true
	Replication.Set(player, { "Purchases", "Owned", key }, true)
	if not had then
		Replication.Notify(player, "GiftReceived", { Pass = key, From = fromName })
		sendPasses(player)
	end
	return true
end

-- Grants one developer product. May yield (gift to a player who left). True = granted.
local function grantProduct(player: Player, data: Types.ProfileData, key: string): boolean
	if key == PassConfig.PremiumProduct then
		local ok = BattlePass.SetPremium(player)
		if ok then
			Replication.Notify(player, "Purchased", key)
		end
		return ok
	end
	for _, def in ShopConfig.Passes do
		if def.GiftProduct == key then
			local targetId = data.Purchases.GiftTo[key]
			if targetId == nil or targetId == player.UserId then
				-- No recipient recorded (should not happen): the buyer keeps the pass.
				return setOwned(player, data, def.Key, nil)
			end
			local target = Players:GetPlayerByUserId(targetId)
			local targetData = if target ~= nil then PlayerData.Data(target) else nil
			if target ~= nil and targetData ~= nil then
				setOwned(target, targetData, def.Key, player.Name)
			end
			-- The message is the durable record (the recipient may leave before their next save); setting
			-- Owned twice is harmless.
			local sent = PlayerData.MessageAsync(targetId, { Kind = "Gift", Pass = def.Key, From = player.Name })
			if sent then
				Replication.Notify(player, "GiftSent", { Pass = def.Key, To = targetId })
			end
			return sent
		end
	end
	for _, item in ShopConfig.Items do
		if item.Product == key then
			countBought(player, data, item.Id) -- counted even past the quota: it is already paid for
			Rewards.Grant(player, item.Reward)
			Replication.Notify(player, "Purchased", item.Id)
			return true
		end
	end
	warn(`[Shop] no grant for product key {key}`)
	return false
end

local function prune(receipts: { [string]: number })
	local count = 0
	for _ in receipts do
		count += 1
	end
	if count <= ShopConfig.ReceiptKeep then
		return
	end
	local cutoff = os.time() - ShopConfig.ReceiptMaxAge
	for id, at in receipts do
		if at < cutoff then
			receipts[id] = nil
		end
	end
end

local function waitProfile(player: Player): PlayerData.Data?
	local deadline = os.clock() + 60
	while PlayerData.Data(player) == nil and player.Parent == Players and os.clock() < deadline do
		task.wait(0.5)
	end
	return PlayerData.Data(player)
end

-- Shared by ProcessReceipt and the Studio dev command.
local function handleReceipt(player: Player, purchaseId: string, key: string): Enum.ProductPurchaseDecision
	local data = waitProfile(player)
	if data == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if data.Purchases.Receipts[purchaseId] == nil then
		local ok, granted = pcall(grantProduct, player, data, key)
		if not ok then
			warn(`[Shop] grant {key} failed for {player.Name}: {granted}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		-- grantProduct may have yielded: the profile must still be this session's.
		if not granted or PlayerData.Data(player) ~= data then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		data.Purchases.Receipts[purchaseId] = os.time()
		data.Purchases.GiftTo[key] = nil
		prune(data.Purchases.Receipts)
		print(`[Shop] granted {key} to {player.Name} (purchase {purchaseId})`)
	end
	local saved = PlayerData.WaitSaved(player, function(last: PlayerData.Data): boolean
		return last.Purchases ~= nil and last.Purchases.Receipts ~= nil and last.Purchases.Receipts[purchaseId] ~= nil
	end)
	return if saved then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

local function processReceipt(info: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- retried when they rejoin
	end
	local key = productKeyById[info.ProductId]
	if key == nil then
		warn(`[Shop] unknown product {info.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return handleReceipt(player, tostring(info.PurchaseId), key)
end

-- Studio dev command: runs a fake receipt through the real grant + dedupe path.
function Shop.DevReceipt(player: Player, key: string, purchaseId: string)
	if ShopConfig.Products[key] == nil then
		return
	end
	task.spawn(function()
		local decision = handleReceipt(player, purchaseId, key)
		print(`[Shop] dev receipt {key} {purchaseId}: {decision.Name}`)
	end)
end

-- Studio dev command: toggles a gifted pass on the profile.
function Shop.DevTogglePass(player: Player, key: string)
	local data = PlayerData.Data(player)
	if data == nil or ShopConfig.PassByKey[key] == nil then
		return
	end
	if data.Purchases.Owned[key] then
		data.Purchases.Owned[key] = nil
		Replication.Set(player, { "Purchases", "Owned", key }, nil)
	else
		data.Purchases.Owned[key] = true
		Replication.Set(player, { "Purchases", "Owned", key }, true)
	end
	sendPasses(player)
end

local function err(player: Player, key: string)
	Replication.Notify(player, "Error", key)
end

local function productId(key: string): number
	return ShopConfig.Products[key] or 0
end

local function buyPass(player: Player, key: string)
	if not RateLimit.Allow(player, "BuyPass") then
		return
	end
	local def = ShopConfig.PassByKey[key]
	if def == nil then
		return
	end
	if Shop.Owns(player, key) then
		err(player, "PassOwned")
	elseif def.PassId <= 0 then
		err(player, "NotForSale")
	else
		MarketplaceService:PromptGamePassPurchase(player, def.PassId)
	end
end

local function giftPass(player: Player, key: string, targetId: number)
	if not RateLimit.Allow(player, "GiftPass") then
		return
	end
	local def = ShopConfig.PassByKey[key]
	local data = PlayerData.Data(player)
	if def == nil or data == nil then
		return
	end
	local target = Players:GetPlayerByUserId(targetId)
	if target == nil or target == player or PlayerData.Data(target) == nil then
		err(player, "GiftNoTarget")
		return
	end
	if Shop.Owns(target, key) then
		err(player, "GiftOwned")
		return
	end
	local id = productId(def.GiftProduct)
	if id <= 0 then
		err(player, "NotForSale")
		return
	end
	data.Purchases.GiftTo[def.GiftProduct] = targetId
	MarketplaceService:PromptProductPurchase(player, id)
end

local function buyPremium(player: Player)
	if not RateLimit.Allow(player, "BuyPremium") then
		return
	end
	if BattlePass.HasPremium(player) then
		err(player, "PremiumOwned")
		return
	end
	local id = productId(PassConfig.PremiumProduct)
	if id <= 0 then
		err(player, "NotForSale")
		return
	end
	MarketplaceService:PromptProductPurchase(player, id)
end

local function buyItem(player: Player, id: string)
	if not RateLimit.Allow(player, "BuyShopItem") then
		return
	end
	local data = PlayerData.Data(player)
	local item = ShopConfig.ItemById[id]
	if data == nil or item == nil then
		return
	end
	local state = shopMonth(player, data)
	if (state.Bought[id] or 0) >= item.Quota then
		err(player, "QuotaReached")
		return
	end
	local ok, why = Rewards.CanGrant(player, item.Reward)
	if not ok then
		if why ~= nil then
			err(player, why)
		end
		return
	end
	if item.Currency == "Robux" then
		local pid = if item.Product ~= nil then productId(item.Product) else 0
		if pid <= 0 then
			err(player, "NotForSale")
			return
		end
		MarketplaceService:PromptProductPurchase(player, pid)
		return
	end
	local price = if item.Currency == "Gold"
		then Formula.Economy.Gold(item.Price, Rewards.BestLevel(data))
		else item.Price
	if not Guard.Amount(price) or not Currency.Spend(player, item.Currency :: any, price) then
		err(player, if item.Currency == "Gold" then "NotEnoughGold" else "NotEnoughRuby")
		return
	end
	countBought(player, data, id)
	Rewards.Grant(player, item.Reward)
	Replication.Notify(player, "Purchased", id)
end

function Shop.Start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for _, def in ShopConfig.Passes do
			if def.PassId == passId then
				local owned = accountOwned[player] or {}
				accountOwned[player] = owned
				owned[def.Key] = true
				sendPasses(player)
			end
		end
	end)
	PlayerData.OnLoaded(function(player, data)
		shopMonth(player, data)
		task.spawn(checkAccountPasses, player)
	end)
	PlayerData.OnMessage(function(player, data, message)
		if message.Kind ~= "Gift" or type(message.Pass) ~= "string" or ShopConfig.PassByKey[message.Pass] == nil then
			return false
		end
		return setOwned(player, data, message.Pass, if type(message.From) == "string" then message.From else nil)
	end)
	Replication.OnSynced(sendPasses)
	Net.BuyPass:Server():On(buyPass)
	Net.GiftPass:Server():On(giftPass)
	Net.BuyPremium:Server():On(buyPremium)
	Net.BuyShopItem:Server():On(buyItem)
	Players.PlayerRemoving:Connect(function(player)
		accountOwned[player] = nil
	end)
end

return Shop
