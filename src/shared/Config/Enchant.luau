--!strict
-- Power (enchant): one named trait per gear piece, each with a fixed set of effects; roll cost; rarity order. Roll chances are server-only (Secret/EnchantPools).

local Freeze = require(script.Parent.Parent.Freeze)

-- Stat = a field of Formula.Gear Extras. Value in percent points (10 = +10%) for every stat, Crit/Lifesteal included.
export type Effect = { Stat: string, Value: number }

export type TraitDef = {
	Id: string,
	Order: number,
	Rarity: string, -- Rarities entry
	Effects: { Effect },
}

local list: { TraitDef } = {
	{ Id = "Strength", Order = 1, Rarity = "Common", Effects = { { Stat = "AtkPct", Value = 8 } } },
	{ Id = "Vitality", Order = 2, Rarity = "Common", Effects = { { Stat = "HpPct", Value = 10 } } },
	{ Id = "Guard", Order = 3, Rarity = "Common", Effects = { { Stat = "DefPct", Value = 10 } } },
	{
		Id = "Speed",
		Order = 4,
		Rarity = "Rare",
		Effects = { { Stat = "AtkPct", Value = 10 }, { Stat = "MovePct", Value = 10 } },
	},
	{ Id = "Range", Order = 5, Rarity = "Rare", Effects = { { Stat = "RangePct", Value = 15 } } },
	{ Id = "Haste", Order = 6, Rarity = "Rare", Effects = { { Stat = "AtkSpeed", Value = 12 } } },
	{
		Id = "Vampire",
		Order = 7,
		Rarity = "Epic",
		Effects = { { Stat = "Lifesteal", Value = 6 }, { Stat = "AtkPct", Value = 6 } },
	},
	{
		Id = "Deadeye",
		Order = 8,
		Rarity = "Epic",
		Effects = { { Stat = "Crit", Value = 12 }, { Stat = "RangePct", Value = 10 } },
	},
	{
		Id = "Godspeed",
		Order = 9,
		Rarity = "Legendary",
		Effects = { { Stat = "AtkSpeed", Value = 20 }, { Stat = "MovePct", Value = 25 } },
	},
	{
		Id = "God",
		Order = 10,
		Rarity = "Mythic",
		Effects = {
			{ Stat = "AtkPct", Value = 25 },
			{ Stat = "HpPct", Value = 25 },
			{ Stat = "DefPct", Value = 25 },
			{ Stat = "AtkSpeed", Value = 10 },
		},
	},
}

local byId: { [string]: TraitDef } = {}
for _, def in list do
	byId[def.Id] = def
end

return Freeze({
	Item = "EnchantDust",
	Dust = { Common = 2, Uncommon = 4, Rare = 8 } :: { [string]: number },
	GoldBase = 60, -- x Formula.Scaling.Item(gear level)
	Rarities = { "Common", "Rare", "Epic", "Legendary", "Mythic" },
	List = list,
	ById = byId,
})
