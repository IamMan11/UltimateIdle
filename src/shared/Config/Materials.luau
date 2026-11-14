--!strict
-- Stackable materials: name key, tier, tags, rebirth availability (nil = every rebirth).

local Freeze = require(script.Parent.Parent.Freeze)

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
}

local byId: { [string]: MaterialDef } = {}
for _, def in list do
	byId[def.Id] = def
end

return Freeze({
	List = list,
	ById = byId,
})
