--!strict
-- Forge costs (pure, shared so the UI shows what the server charges): enhance, socket merge/remove, enchant.

local Types = require(script.Parent.Parent.Types)
local Items = require(script.Parent.Parent.Config.Items)
local Enhance = require(script.Parent.Parent.Config.Enhance)
local Enchant = require(script.Parent.Parent.Config.Enchant)
local Inserts = require(script.Parent.Parent.Config.Inserts)
local Scaling = require(script.Parent.Scaling)

local Forge = {}

-- Cost of the next +1 (gold, materials). Call only when item.Plus < Enhance.MaxPlus.
function Forge.EnhanceCost(item: Types.GearItem): (number, { [string]: number })
	local tierMult = Enhance.TierMult[item.Tier] or 1
	local gold = math.floor(Enhance.GoldBase * Scaling.Item(item.Level) * tierMult * Enhance.GoldGrowth ^ item.Plus)
	local items: { [string]: number } = {
		[Enhance.StoneItem] = math.ceil((Enhance.StoneBase + Enhance.StonePerPlus * item.Plus) * tierMult),
	}
	local def = Items.ById[item.BaseId]
	if def ~= nil then
		for _, rule in Enhance.Extra do
			if item.Plus >= rule.FromPlus and table.find(def.Tags, rule.Tag) ~= nil then
				items[rule.Id] = (items[rule.Id] or 0) + rule.Count
			end
		end
	end
	return gold, items
end

-- Gold to merge a duplicate into `item` (gains one socket).
function Forge.MergeGold(item: Types.GearItem): number
	return math.floor(Inserts.MergeGold * Scaling.Item(item.Level) * (#item.Sockets + 1))
end

function Forge.RemoveGold(item: Types.GearItem): number
	return math.floor(Inserts.RemoveGold * Scaling.Item(item.Level))
end

-- Enchant reroll cost (gold, dust count).
function Forge.EnchantCost(item: Types.GearItem): (number, number)
	return math.floor(Enchant.GoldBase * Scaling.Item(item.Level)), Enchant.Dust[item.Tier] or 1
end

-- A duplicate that can be merged into `main`: same base + tier + socket count, not full, not itself.
function Forge.CanMerge(main: Types.GearItem, other: Types.GearItem): boolean
	if main.Uid == other.Uid or main.BaseId ~= other.BaseId or main.Tier ~= other.Tier then
		return false
	end
	if #main.Sockets >= Inserts.MaxSockets or #main.Sockets ~= #other.Sockets then
		return false
	end
	for _, socket in other.Sockets do
		if socket.Insert ~= nil then
			return false
		end
	end
	return true
end

return table.freeze(Forge)
