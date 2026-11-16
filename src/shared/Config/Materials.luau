--!strict
-- Materials (incl. socket inserts from Config.Inserts): name key, tier, tags, units per bag slot (MaxStack), rebirth availability (nil = every rebirth).

local Freeze = require(script.Parent.Parent.Freeze)
local Inserts = require(script.Parent.Inserts)

export type MaterialDef = {
	Id: string,
	Order: number,
	Tier: string,
	Tags: { string },
	-- Units that share one bag slot before the next unit starts a new slot (1 = does not stack). Raised by the skill tree's StackPct (Formula.Bag.MaxStack).
	MaxStack: number,
	Rebirths: { number }?,
}

local list: { MaterialDef } = {
	{ Id = "EnhanceStone", Order = 1, Tier = "Common", Tags = { "enhance", "stone" }, MaxStack = 1 },
	{ Id = "EnchantDust", Order = 2, Tier = "Uncommon", Tags = { "power", "gem", "stone" }, MaxStack = 999 },
	{ Id = "SocketCore", Order = 3, Tier = "Rare", Tags = { "socket", "core" }, MaxStack = 1 },
	{ Id = "AncientShard", Order = 4, Tier = "Rare", Tags = { "enhance", "ancient", "shard" }, MaxStack = 1 },
}
for _, def in Inserts.List do
	table.insert(list, { Id = def.Id, Order = def.Order, Tier = def.Tier, Tags = table.clone(def.Tags), MaxStack = 1 })
end

local byId: { [string]: MaterialDef } = {}
for _, def in list do
	byId[def.Id] = def
end

return Freeze({
	List = list,
	ById = byId,
})
