--!strict
-- Player-to-player trade in one server: request/accept -> offers (gear locked, boxes reserved) -> ready + delayed final
-- confirm (any offer change clears both) -> re-check both sides -> swap with no yield -> log. Ends if either side leaves.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local Boxes = require(ReplicatedStorage.Shared.Config.Boxes)
local Materials = require(ReplicatedStorage.Shared.Config.Materials)
local AccountConfig = require(ReplicatedStorage.Shared.Config.Account)
local TradeConfig = require(ReplicatedStorage.Shared.Config.Trade)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)
local Guard = require(ServerScriptService.Server.Util.Guard)
local Replication = require(script.Parent.Replication)
local Currency = require(script.Parent.Currency)
local Inventory = require(script.Parent.Inventory)
local Box = require(script.Parent.Box)
local Rewards = require(script.Parent.Rewards)

type Offer = Types.TradeOffer

type Side = {
	Player: Player,
	Offer: Offer,
	Ready: boolean,
	Confirmed: boolean,
}

type Trade = {
	Id: number,
	A: Side,
	B: Side,
	ConfirmAt: number, -- server time from which the final confirm counts
}

local stateEvent = Net.TradeState:Server()

local trades: { [Player]: Trade } = {}
-- target -> requester -> os.clock() expiry
local requests: { [Player]: { [Player]: number } } = {}
-- PolicyService IsPaidItemTradingAllowed per player (Robux buys items here, so every trade counts as paid item trading).
local policy: { [Player]: boolean } = {}
local nextId = 0

local Trade = {}

local function emptyOffer(): Offer
	return { Gear = {}, Stacks = {}, Boxes = {}, Gold = 0, Ruby = 0 }
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function err(player: Player, key: string)
	Replication.Notify(player, "Error", key)
end

local function sidesOf(trade: Trade, player: Player): (Side, Side)
	if trade.A.Player == player then
		return trade.A, trade.B
	end
	return trade.B, trade.A
end

local function policyAllows(player: Player): boolean
	local cached = policy[player]
	if cached ~= nil then
		return cached
	end
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	local allowed: boolean
	if ok then
		allowed = (info :: any).IsPaidItemTradingAllowed == true
	else
		warn(`[Trade] policy lookup failed for {player.Name}: {info}`)
		allowed = RunService:IsStudio() -- unknown outside Studio = not allowed
	end
	if player.Parent == Players then
		policy[player] = allowed
	end
	return allowed
end

-- Error key when this player may not trade at all (cached policy only: never yields).
local function blocked(player: Player): string?
	local data = PlayerData.Data(player)
	if data == nil then
		return "TradeUnavailable"
	end
	if not AccountConfig.IsUnlocked("Trade", data.AccountLevel, Rewards.BestLevel(data)) then
		return "TradeLocked"
	end
	if policy[player] ~= true then
		return "TradePolicy"
	end
	return nil
end

local function count(map: { [string]: number }): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

-- Error key if `player` cannot give `offer` right now.
local function checkOffer(player: Player, offer: Offer): string?
	local data = PlayerData.Data(player)
	if data == nil then
		return "TradeUnavailable"
	end
	if #offer.Gear + count(offer.Stacks) + count(offer.Boxes) > TradeConfig.MaxSlots then
		return "TradeTooMany"
	end
	local seen: { [string]: boolean } = {}
	for _, uid in offer.Gear do
		if seen[uid] or data.Gear[uid] == nil then
			return "TradeMissing"
		end
		seen[uid] = true
		if Inventory.WornBy(player, uid) ~= nil then
			return "TradeWorn"
		end
	end
	for id, n in offer.Stacks do
		if Materials.ById[id] == nil or not Guard.Int(n, 1, 1e12) or Inventory.StackCount(player, id) < n then
			return "TradeMissing"
		end
	end
	for key, n in offer.Boxes do
		if Boxes.Parse(key) == nil or not Guard.Int(n, 1, 1e6) or (data.Boxes[key] or 0) < n then
			return "TradeMissing"
		end
	end
	if not (Guard.Amount(offer.Gold) and Guard.Amount(offer.Ruby)) then
		return "TradeMissing"
	end
	if data.Gold < offer.Gold or data.Ruby < offer.Ruby then
		return "TradeMissing"
	end
	return nil
end

-- Error key if `player` (giving `give`) has no room for `get`.
local function checkReceive(player: Player, give: Offer, get: Offer): string?
	local data = PlayerData.Data(player)
	if data == nil then
		return "TradeUnavailable"
	end
	if Inventory.FreeSpace(player) + #give.Gear < #get.Gear then
		return "TradeBagFull"
	end
	for key, n in get.Boxes do
		local after = (data.Boxes[key] or 0) - (give.Boxes[key] or 0) + n
		if after > Box.Cap(player, key) then
			return "TradeBoxFull"
		end
	end
	return nil
end

local function view(trade: Trade, player: Player): Types.TradeView
	local me, them = sidesOf(trade, player)
	local theirGear: { [string]: Types.GearItem } = {}
	local theirData = PlayerData.Data(them.Player)
	if theirData ~= nil then
		for _, uid in them.Offer.Gear do
			local item = theirData.Gear[uid]
			if item ~= nil then
				theirGear[uid] = item
			end
		end
	end
	return {
		Id = trade.Id,
		PartnerId = them.Player.UserId,
		PartnerName = them.Player.DisplayName,
		Mine = me.Offer,
		Theirs = them.Offer,
		TheirGear = theirGear,
		MeReady = me.Ready,
		ThemReady = them.Ready,
		MeConfirmed = me.Confirmed,
		ThemConfirmed = them.Confirmed,
		ConfirmAt = trade.ConfirmAt,
	}
end

local function push(trade: Trade)
	stateEvent:Fire(trade.A.Player, view(trade, trade.A.Player))
	stateEvent:Fire(trade.B.Player, view(trade, trade.B.Player))
end

local function release(player: Player)
	trades[player] = nil
	Inventory.SetLocks(player, {})
	Box.SetReserved(player, {})
	if player.Parent == Players then
		stateEvent:Fire(player, nil)
	end
end

local function endTrade(trade: Trade, notice: string?, payload: any)
	for _, side in { trade.A, trade.B } do
		if trades[side.Player] == trade then
			release(side.Player)
			if notice ~= nil and side.Player.Parent == Players then
				Replication.Notify(side.Player, notice, payload)
			end
		end
	end
end

local function isEmpty(offer: Offer): boolean
	return #offer.Gear == 0
		and next(offer.Stacks) == nil
		and next(offer.Boxes) == nil
		and offer.Gold <= 0
		and offer.Ruby <= 0
end

local function unready(trade: Trade)
	trade.A.Ready, trade.B.Ready = false, false
	trade.A.Confirmed, trade.B.Confirmed = false, false
end

-- Removes one side's offer from its owner. Called only after both sides passed every check, with no yield since.
local function takeOffer(side: Side): { Types.GearItem }
	local player = side.Player
	local items: { Types.GearItem } = {}
	for _, uid in side.Offer.Gear do
		local item = Inventory.TakeForTrade(player, uid)
		if item ~= nil then
			table.insert(items, item)
		else
			warn(`[Trade] {player.Name} lost gear {uid} between check and swap`)
		end
	end
	for id, n in side.Offer.Stacks do
		Inventory.SpendStack(player, id, n)
	end
	for key, n in side.Offer.Boxes do
		Box.Take(player, key, n)
	end
	Currency.Spend(player, "Gold", side.Offer.Gold, "Trade")
	Currency.Spend(player, "Ruby", side.Offer.Ruby, "Trade")
	return items
end

-- Returns old uid -> new uid for the log.
local function giveOffer(to: Player, offer: Offer, items: { Types.GearItem }): { [string]: string }
	local uids: { [string]: string } = {}
	for _, item in items do
		local uid = Inventory.Adopt(to, item)
		if uid ~= nil then
			uids[item.Uid] = uid
		else
			warn(`[Trade] could not store gear {item.Uid} ({item.BaseId}) for {to.Name}`)
		end
	end
	for id, n in offer.Stacks do
		Inventory.AddStack(to, id, n)
	end
	for key, n in offer.Boxes do
		Box.Grant(to, key, n)
	end
	Currency.Add(to, "Gold", offer.Gold, "Trade")
	Currency.Add(to, "Ruby", offer.Ruby, "Trade")
	return uids
end

local function execute(trade: Trade)
	local a, b = trade.A, trade.B
	local problem = blocked(a.Player)
		or blocked(b.Player)
		or checkOffer(a.Player, a.Offer)
		or checkOffer(b.Player, b.Offer)
		or checkReceive(a.Player, a.Offer, b.Offer)
		or checkReceive(b.Player, b.Offer, a.Offer)
	if problem ~= nil then
		unready(trade)
		err(a.Player, problem)
		err(b.Player, problem)
		push(trade)
		return
	end
	-- From here to the end: no yields, so neither profile can change between the checks above and the swap.
	local fromA = takeOffer(a)
	local fromB = takeOffer(b)
	local toB = giveOffer(b.Player, a.Offer, fromA)
	local toA = giveOffer(a.Player, b.Offer, fromB)
	print(`[Trade] #{trade.Id} {HttpService:JSONEncode({
		A = { User = a.Player.UserId, Gave = a.Offer, GearUids = toB },
		B = { User = b.Player.UserId, Gave = b.Offer, GearUids = toA },
	})}`)
	endTrade(trade, "TradeDone", nil)
	PlayerData.SaveNow(a.Player)
	PlayerData.SaveNow(b.Player)
end

local function request(player: Player, targetId: number)
	if not RateLimit.Allow(player, "TradeRequest") then
		return
	end
	local target = Players:GetPlayerByUserId(targetId)
	if target == nil or target == player then
		err(player, "TradeUnavailable")
		return
	end
	policyAllows(player)
	policyAllows(target)
	-- Policy lookups may have yielded.
	if player.Parent ~= Players or target.Parent ~= Players then
		return
	end
	local mine = blocked(player)
	if mine ~= nil then
		err(player, mine)
		return
	end
	if blocked(target) ~= nil then
		err(player, "TradePartnerLocked")
		return
	end
	if trades[player] ~= nil or trades[target] ~= nil then
		err(player, "TradeBusy")
		return
	end
	local pending = requests[target]
	if pending == nil then
		pending = {}
		requests[target] = pending
	end
	pending[player] = os.clock() + TradeConfig.RequestSeconds
	Replication.Notify(target, "TradeRequest", { From = player.UserId, Name = player.DisplayName })
	Replication.Notify(player, "TradeRequested", target.DisplayName)
end

local function respond(player: Player, fromId: number, accept: boolean)
	if not RateLimit.Allow(player, "TradeRespond") then
		return
	end
	local from = Players:GetPlayerByUserId(fromId)
	local pending = requests[player]
	local expiry = if pending ~= nil and from ~= nil then pending[from] else nil
	if from == nil or pending == nil or expiry == nil then
		err(player, "TradeExpired")
		return
	end
	pending[from] = nil
	if os.clock() > expiry then
		err(player, "TradeExpired")
		return
	end
	if not accept then
		Replication.Notify(from, "TradeDeclined", player.DisplayName)
		return
	end
	local problem = blocked(player) or blocked(from)
	if problem ~= nil then
		err(player, problem)
		return
	end
	if trades[player] ~= nil or trades[from] ~= nil then
		err(player, "TradeBusy")
		return
	end
	nextId += 1
	local trade: Trade = {
		Id = nextId,
		A = { Player = from, Offer = emptyOffer(), Ready = false, Confirmed = false },
		B = { Player = player, Offer = emptyOffer(), Ready = false, Confirmed = false },
		ConfirmAt = now() + TradeConfig.ConfirmDelay,
	}
	trades[from] = trade
	trades[player] = trade
	requests[from] = nil -- an accepted trade cancels requests made to either side
	requests[player] = nil
	push(trade)
end

local function setOffer(player: Player, offer: Offer)
	if not RateLimit.Allow(player, "TradeOffer") then
		return
	end
	local trade = trades[player]
	if trade == nil then
		return
	end
	offer.Gold = math.floor(offer.Gold)
	offer.Ruby = math.floor(offer.Ruby)
	local problem = checkOffer(player, offer)
	if problem ~= nil then
		err(player, problem)
		push(trade) -- puts the client's view back to the last accepted offer
		return
	end
	local me = sidesOf(trade, player)
	me.Offer = offer
	Inventory.SetLocks(player, offer.Gear)
	Box.SetReserved(player, offer.Boxes)
	unready(trade)
	trade.ConfirmAt = now() + TradeConfig.ConfirmDelay
	push(trade)
end

local function setReady(player: Player, on: boolean)
	if not RateLimit.Allow(player, "TradeReady") then
		return
	end
	local trade = trades[player]
	if trade == nil then
		return
	end
	local me, them = sidesOf(trade, player)
	if me.Ready == on then
		return
	end
	me.Ready = on
	me.Confirmed, them.Confirmed = false, false
	if on and them.Ready then
		-- Both sides just locked in: the final confirm opens after a short look at the final offers.
		trade.ConfirmAt = math.max(trade.ConfirmAt, now() + TradeConfig.ConfirmDelay)
	end
	push(trade)
end

local function confirm(player: Player)
	if not RateLimit.Allow(player, "TradeConfirm") then
		return
	end
	local trade = trades[player]
	if trade == nil then
		return
	end
	local me, them = sidesOf(trade, player)
	if not (me.Ready and them.Ready) or now() < trade.ConfirmAt then
		err(player, "TradeNotReady")
		return
	end
	if isEmpty(me.Offer) and isEmpty(them.Offer) then
		err(player, "TradeEmpty")
		return
	end
	me.Confirmed = true
	if them.Confirmed then
		execute(trade)
	else
		push(trade)
	end
end

local function cancel(player: Player)
	if not RateLimit.Allow(player, "TradeCancel") then
		return
	end
	local trade = trades[player]
	if trade ~= nil then
		endTrade(trade, "TradeCancelled", player.DisplayName)
	end
end

local function onLeave(player: Player)
	local trade = trades[player]
	if trade ~= nil then
		endTrade(trade, "TradeCancelled", player.DisplayName)
	end
	requests[player] = nil
	for _, pending in requests do
		pending[player] = nil
	end
	policy[player] = nil
end

function Trade.IsTrading(player: Player): boolean
	return trades[player] ~= nil
end

function Trade.Start()
	Net.TradeRequest:Server():On(request)
	Net.TradeRespond:Server():On(respond)
	Net.TradeOffer:Server():On(setOffer)
	Net.TradeReady:Server():On(setReady)
	Net.TradeConfirm:Server():On(confirm)
	Net.TradeCancel:Server():On(cancel)
	PlayerData.OnLoaded(function(player)
		task.spawn(policyAllows, player)
	end)
	-- Before the profile is released: the trade must end while both profiles are still in memory.
	PlayerData.OnReleasing(function(player)
		onLeave(player)
	end)
	Players.PlayerRemoving:Connect(onLeave)
end

return Trade
