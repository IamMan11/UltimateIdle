--!strict
-- Owner of Gold/Ruby balances: Add/Spend/Has with finite, non-negative, capped amounts; every change is reported to Analytics with its source.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Game = require(ReplicatedStorage.Shared.Config.Game)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local Guard = require(ServerScriptService.Server.Util.Guard)
local Replication = require(script.Parent.Replication)
local Analytics = require(script.Parent.Analytics)

export type CurrencyId = "Gold" | "Ruby"

local function valid(id: string): boolean
	return table.find(Game.Currencies, id) ~= nil
end

local Currency = {}

function Currency.Get(player: Player, id: CurrencyId): number
	local data = PlayerData.Data(player)
	if data == nil then
		return 0
	end
	return (data :: any)[id] or 0
end

function Currency.Has(player: Player, id: CurrencyId, amount: number): boolean
	return Guard.Amount(amount) and Currency.Get(player, id) >= amount
end

-- `source` = Config.Analytics.TransactionTypes key (where the change came from).
function Currency.Add(player: Player, id: CurrencyId, amount: number, source: string): boolean
	local data = PlayerData.Data(player)
	if data == nil or not valid(id) or not Guard.Amount(amount) then
		if not Guard.Amount(amount) then
			warn(`[Currency] rejected Add {id} {amount} for {player.Name}`)
		end
		return false
	end
	if amount == 0 then
		return true
	end
	local balance = math.min(((data :: any)[id] or 0) + amount, Game.MaxCurrency)
	local balances: any = data
	balances[id] = balance
	Replication.Set(player, { id }, balance)
	Analytics.Economy(player, id, "Source", amount, source)
	return true
end

-- Deducts only if the full amount is available; never goes negative.
function Currency.Spend(player: Player, id: CurrencyId, amount: number, source: string): boolean
	local data = PlayerData.Data(player)
	if data == nil or not valid(id) or not Guard.Amount(amount) then
		return false
	end
	local balance = (data :: any)[id] or 0
	if balance < amount then
		return false
	end
	balance -= amount
	local balances: any = data
	balances[id] = balance
	Replication.Set(player, { id }, balance)
	Analytics.Economy(player, id, "Sink", amount, source)
	return true
end

return Currency
