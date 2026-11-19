--!strict
-- Enchant remote (player-facing "Power"): spend gold + dust -> roll one new trait for the piece (chances by tier). Writes go through Inventory.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local Formula = require(ReplicatedStorage.Shared.Formula)
local EnchantConfig = require(ReplicatedStorage.Shared.Config.Enchant)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)
local Rng = require(ServerScriptService.Server.Util.Rng)
local EnchantPools = require(ServerScriptService.Server.Secret.EnchantPools)
local Replication = require(script.Parent.Replication)
local Currency = require(script.Parent.Currency)
local Inventory = require(script.Parent.Inventory)
local Quest = require(script.Parent.Quest)

local Enchant = {}

-- One power (trait) for a piece of this tier; nil only if the pool is empty.
function Enchant.Roll(rng: Rng.Rng, tier: string): { Types.Enchant }
	local id = rng:Weighted(EnchantPools.Get(tier))
	if id == nil or EnchantConfig.ById[id] == nil then
		return {}
	end
	return { { Id = id } }
end

local function enchant(player: Player, uid: string)
	if not RateLimit.Allow(player, "Enchant") then
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
	local gold, dust = Formula.Forge.EnchantCost(item)
	if not Currency.Has(player, "Gold", gold) then
		Replication.Notify(player, "Error", "NotEnoughGold")
		return
	end
	if Inventory.StackCount(player, EnchantConfig.Item) < dust then
		Replication.Notify(player, "Error", "NotEnoughItems")
		return
	end
	Currency.Spend(player, "Gold", gold, "Forge")
	Inventory.SpendStack(player, EnchantConfig.Item, dust)
	local before = item.Enchants
	local after = Enchant.Roll(Rng.new(), item.Tier)
	Inventory.SetEnchants(player, uid, after)
	Replication.Notify(player, "Enchanted", { Uid = uid, Before = before, After = after })
	Quest.Progress(player, "Enchant", 1)
end

function Enchant.Start()
	Net.Enchant:Server():On(enchant)
end

return Enchant
