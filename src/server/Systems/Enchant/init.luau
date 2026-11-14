--!strict
-- Enchant remote: spend gold + dust -> reroll every trait line (count by tier, no repeated trait). Writes go through Inventory.

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

function Enchant.Roll(rng: Rng.Rng, tier: string): { Types.Enchant }
	local lines = EnchantConfig.Lines[tier] or 1
	local pool = EnchantPools.Get(tier)
	local weights: { [string]: number } = {}
	local byId: { [string]: EnchantPools.Trait } = {}
	for _, trait in pool do
		weights[trait.Id] = trait.Weight
		byId[trait.Id] = trait
	end
	local out: { Types.Enchant } = {}
	for _ = 1, lines do
		local id = rng:Weighted(weights)
		if id == nil then
			break
		end
		weights[id] = nil
		local trait = byId[id]
		table.insert(out, { Id = id, Value = rng:Int(trait.Min, trait.Max) })
	end
	return out
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
	Currency.Spend(player, "Gold", gold)
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
