--!strict
-- Gear tiers: gear score range (roll -> stat multiplier GS/100), salvage yield, sort order.

local Freeze = require(script.Parent.Parent.Freeze)

export type TierDef = {
	Id: string,
	Order: number,
	GearScoreMin: number,
	GearScoreMax: number,
	SalvageGold: number, -- multiplied by Formula.ItemScale(level)
	SalvageStones: number,
}

local list: { TierDef } = {
	{ Id = "Common", Order = 1, GearScoreMin = 60, GearScoreMax = 100, SalvageGold = 8, SalvageStones = 1 },
	{ Id = "Uncommon", Order = 2, GearScoreMin = 90, GearScoreMax = 150, SalvageGold = 25, SalvageStones = 3 },
	{ Id = "Rare", Order = 3, GearScoreMin = 130, GearScoreMax = 220, SalvageGold = 70, SalvageStones = 8 },
}

local byId: { [string]: TierDef } = {}
for _, def in list do
	byId[def.Id] = def
end

return Freeze({
	List = list,
	ById = byId,
})
