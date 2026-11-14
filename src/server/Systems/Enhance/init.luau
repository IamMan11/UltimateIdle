--!strict
-- Enhance remote: check cost -> spend gold + materials -> roll -> +1 or unchanged (never breaks). Plus is written through Inventory.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Formula = require(ReplicatedStorage.Shared.Formula)
local EnhanceConfig = require(ReplicatedStorage.Shared.Config.Enhance)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)
local Rng = require(ServerScriptService.Server.Util.Rng)
local EnhanceRates = require(ServerScriptService.Server.Secret.EnhanceRates)
local Replication = require(script.Parent.Replication)
local Currency = require(script.Parent.Currency)
local Inventory = require(script.Parent.Inventory)
local Quest = require(script.Parent.Quest)

local Enhance = {}

local function enhance(player: Player, uid: string)
	if not RateLimit.Allow(player, "Enhance") then
		return
	end
	local item = Inventory.Get(player, uid)
	if item == nil then
		return
	end
	if Inventory.IsLocked(player, uid) then
		Replication.Notify(player, "Error", "ItemInTrade")
		return
	end
	if item.Plus >= EnhanceConfig.MaxPlus then
		Replication.Notify(player, "Error", "MaxPlus")
		return
	end
	local gold, items = Formula.Forge.EnhanceCost(item)
	if not Currency.Has(player, "Gold", gold) then
		Replication.Notify(player, "Error", "NotEnoughGold")
		return
	end
	for id, n in items do
		if Inventory.StackCount(player, id) < n then
			Replication.Notify(player, "Error", "NotEnoughItems")
			return
		end
	end
	Currency.Spend(player, "Gold", gold)
	for id, n in items do
		Inventory.SpendStack(player, id, n)
	end
	local before = item.Plus
	local ok = Rng.new():Chance(EnhanceRates.Get(before + 1))
	if ok then
		Inventory.SetPlus(player, uid, before + 1)
	end
	Replication.Notify(player, "Enhanced", { Uid = uid, Plus = before, Ok = ok })
	Quest.Progress(player, "Enhance", 1)
end

function Enhance.Start()
	Net.Enhance:Server():On(enhance)
end

return Enhance
