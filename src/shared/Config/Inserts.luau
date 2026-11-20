--!strict
-- Socket inserts (stackable) in three tiers: Gem = flat stat on the piece, Artifact = battle effect on the wearer, Relic = team/economy bonus. Caps, socket rules, upgrade (3 -> 1 next tier).

local Freeze = require(script.Parent.Parent.Freeze)

export type InsertDef = {
	Id: string,
	Kind: string, -- SocketKind
	Tier: string,
	Order: number,
	Tags: { string },
	Stat: string, -- Gem: MaxHp/Atk/Def · Artifact: Lifesteal/Crit/Splash · Relic: GoldPct/XpPct/DropPct
	Value: number, -- Gem: level-1 amount (scales with the gear's level) · others: flat per insert
}

-- Each tier holds its own inserts (a higher tier is a different insert, not the same one with a bigger number).
local list: { InsertDef } = {
	{ Id = "GemAtk1", Kind = "Gem", Tier = "Common", Order = 20, Tags = { "gem" }, Stat = "Atk", Value = 1 },
	{ Id = "GemHp1", Kind = "Gem", Tier = "Common", Order = 21, Tags = { "gem" }, Stat = "MaxHp", Value = 6 },
	{ Id = "GemDef1", Kind = "Gem", Tier = "Common", Order = 22, Tags = { "gem" }, Stat = "Def", Value = 0.75 },
	{ Id = "GemAtk", Kind = "Gem", Tier = "Uncommon", Order = 23, Tags = { "gem" }, Stat = "Atk", Value = 2 },
	{ Id = "GemHp", Kind = "Gem", Tier = "Uncommon", Order = 24, Tags = { "gem" }, Stat = "MaxHp", Value = 12 },
	{ Id = "GemDef", Kind = "Gem", Tier = "Uncommon", Order = 25, Tags = { "gem" }, Stat = "Def", Value = 1.5 },
	{ Id = "GemAtk3", Kind = "Gem", Tier = "Rare", Order = 26, Tags = { "gem" }, Stat = "Atk", Value = 3.5 },
	{ Id = "GemHp3", Kind = "Gem", Tier = "Rare", Order = 27, Tags = { "gem" }, Stat = "MaxHp", Value = 21 },
	{ Id = "GemDef3", Kind = "Gem", Tier = "Rare", Order = 28, Tags = { "gem" }, Stat = "Def", Value = 2.6 },
	{
		Id = "ArtLifesteal1",
		Kind = "Artifact",
		Tier = "Common",
		Order = 30,
		Tags = { "artifact", "lifesteal" },
		Stat = "Lifesteal",
		Value = 0.01,
	},
	{
		Id = "ArtCrit1",
		Kind = "Artifact",
		Tier = "Common",
		Order = 31,
		Tags = { "artifact", "crit" },
		Stat = "Crit",
		Value = 0.015,
	},
	{
		Id = "ArtLifesteal2",
		Kind = "Artifact",
		Tier = "Uncommon",
		Order = 32,
		Tags = { "artifact", "lifesteal" },
		Stat = "Lifesteal",
		Value = 0.02,
	},
	{
		Id = "ArtCrit2",
		Kind = "Artifact",
		Tier = "Uncommon",
		Order = 33,
		Tags = { "artifact", "crit" },
		Stat = "Crit",
		Value = 0.025,
	},
	{
		Id = "ArtLifesteal",
		Kind = "Artifact",
		Tier = "Rare",
		Order = 34,
		Tags = { "artifact", "lifesteal" },
		Stat = "Lifesteal",
		Value = 0.03,
	},
	{
		Id = "ArtCrit",
		Kind = "Artifact",
		Tier = "Rare",
		Order = 35,
		Tags = { "artifact", "crit" },
		Stat = "Crit",
		Value = 0.04,
	},
	{
		Id = "ArtSplash",
		Kind = "Artifact",
		Tier = "Rare",
		Order = 36,
		Tags = { "artifact", "splash" },
		Stat = "Splash",
		Value = 1,
	},
	{
		Id = "RelicGold1",
		Kind = "Relic",
		Tier = "Common",
		Order = 40,
		Tags = { "relic", "gold" },
		Stat = "GoldPct",
		Value = 0.01,
	},
	{
		Id = "RelicXp1",
		Kind = "Relic",
		Tier = "Common",
		Order = 41,
		Tags = { "relic", "xp" },
		Stat = "XpPct",
		Value = 0.01,
	},
	{
		Id = "RelicDrop1",
		Kind = "Relic",
		Tier = "Common",
		Order = 42,
		Tags = { "relic", "drop" },
		Stat = "DropPct",
		Value = 0.01,
	},
	{
		Id = "RelicGold2",
		Kind = "Relic",
		Tier = "Uncommon",
		Order = 43,
		Tags = { "relic", "gold" },
		Stat = "GoldPct",
		Value = 0.02,
	},
	{
		Id = "RelicXp2",
		Kind = "Relic",
		Tier = "Uncommon",
		Order = 44,
		Tags = { "relic", "xp" },
		Stat = "XpPct",
		Value = 0.02,
	},
	{
		Id = "RelicDrop2",
		Kind = "Relic",
		Tier = "Uncommon",
		Order = 45,
		Tags = { "relic", "drop" },
		Stat = "DropPct",
		Value = 0.02,
	},
	{
		Id = "RelicGold",
		Kind = "Relic",
		Tier = "Rare",
		Order = 46,
		Tags = { "relic", "gold" },
		Stat = "GoldPct",
		Value = 0.03,
	},
	{
		Id = "RelicXp",
		Kind = "Relic",
		Tier = "Rare",
		Order = 47,
		Tags = { "relic", "xp" },
		Stat = "XpPct",
		Value = 0.03,
	},
	{
		Id = "RelicDrop",
		Kind = "Relic",
		Tier = "Rare",
		Order = 48,
		Tags = { "relic", "drop" },
		Stat = "DropPct",
		Value = 0.03,
	},
}

local byId: { [string]: InsertDef } = {}
-- Kind -> Tier -> insert ids (what an upgrade can roll).
local pools: { [string]: { [string]: { string } } } = {}
for _, def in list do
	byId[def.Id] = def
	pools[def.Kind] = pools[def.Kind] or {}
	local byTier = pools[def.Kind]
	byTier[def.Tier] = byTier[def.Tier] or {}
	table.insert(byTier[def.Tier], def.Id)
end

return Freeze({
	List = list,
	ById = byId,
	Kinds = { "Gem", "Artifact", "Relic" },
	MaxSockets = 5,
	-- Rare item that adds one socket without a duplicate piece.
	CoreItem = "SocketCore",
	-- Totals from Artifacts (per hero) and Relics (per team) never go past these.
	Caps = {
		Lifesteal = 0.3,
		Crit = 0.5,
		Splash = 3,
		GoldPct = 1.5,
		XpPct = 1.5,
		DropPct = 1,
	} :: { [string]: number },
	CritMult = 2,
	-- Gold costs, multiplied by Formula.Scaling.Item(gear level).
	MergeGold = 150, -- x (sockets after merge)
	RemoveGold = 40,
	-- Upgrade: UpgradeCount inserts of one kind and tier -> one random insert of the same kind, next tier.
	UpgradeCount = 3,
	NextTier = { Common = "Uncommon", Uncommon = "Rare" } :: { [string]: string },
	-- Gold per upgrade by the input tier, in gold-level units (Formula.Economy.Gold with the best level reached).
	UpgradeGold = { Common = 10, Uncommon = 40 } :: { [string]: number },
	Pools = pools,
})
