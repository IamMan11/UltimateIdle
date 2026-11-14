--!strict
-- Stackable materials (incl. socket inserts from Config.Inserts): name key, tier, tags, rebirth availability (nil = every rebirth).

local Freeze = require(script.Parent.Parent.Freeze)
local Inserts = require(script.Parent.Inserts)

export type MaterialDef = {
	Id: string,
	Order: number,
	Tier: string,
	Tags: { string },
	Rebirths: { number }?,
}

local list: { MaterialDef } = {
	{ Id = "EnhanceStone", Order = 1, Tier = "Common", Tags = { "enhance", "stone" } },
	{ Id = "EnchantDust", Order = 2, Tier = "Uncommon", Tags = { "enchant", "dust" } },
	{ Id = "SocketCore", Order = 3, Tier = "Rare", Tags = { "socket", "core" } },
	{ Id = "AncientShard", Order = 4, Tier = "Rare", Tags = { "enhance", "ancient", "shard" } },
}
for _, def in Inserts.List do
	table.insert(list, { Id = def.Id, Order = def.Order, Tier = def.Tier, Tags = table.clone(def.Tags) })
end

local byId: { [string]: MaterialDef } = {}
for _, def in list do
	byId[def.Id] = def
end

return Freeze({
	List = list,
	ById = byId,
})
