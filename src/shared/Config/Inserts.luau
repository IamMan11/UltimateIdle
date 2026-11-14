--!strict
-- Socket inserts (stackable): Gem = flat stat on the piece, Artifact = battle effect on the wearer, Relic = team/economy bonus. Caps and socket rules.

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

local list: { InsertDef } = {
	{ Id = "GemAtk", Kind = "Gem", Tier = "Uncommon", Order = 20, Tags = { "gem" }, Stat = "Atk", Value = 2 },
	{ Id = "GemHp", Kind = "Gem", Tier = "Uncommon", Order = 21, Tags = { "gem" }, Stat = "MaxHp", Value = 12 },
	{ Id = "GemDef", Kind = "Gem", Tier = "Uncommon", Order = 22, Tags = { "gem" }, Stat = "Def", Value = 1.5 },
	{
		Id = "ArtLifesteal",
		Kind = "Artifact",
		Tier = "Rare",
		Order = 30,
		Tags = { "artifact", "lifesteal" },
		Stat = "Lifesteal",
		Value = 0.03,
	},
	{
		Id = "ArtCrit",
		Kind = "Artifact",
		Tier = "Rare",
		Order = 31,
		Tags = { "artifact", "crit" },
		Stat = "Crit",
		Value = 0.04,
	},
	{
		Id = "ArtSplash",
		Kind = "Artifact",
		Tier = "Rare",
		Order = 32,
		Tags = { "artifact", "splash" },
		Stat = "Splash",
		Value = 1,
	},
	{
		Id = "RelicGold",
		Kind = "Relic",
		Tier = "Rare",
		Order = 40,
		Tags = { "relic", "gold" },
		Stat = "GoldPct",
		Value = 0.03,
	},
	{
		Id = "RelicXp",
		Kind = "Relic",
		Tier = "Rare",
		Order = 41,
		Tags = { "relic", "xp" },
		Stat = "XpPct",
		Value = 0.03,
	},
	{
		Id = "RelicDrop",
		Kind = "Relic",
		Tier = "Rare",
		Order = 42,
		Tags = { "relic", "drop" },
		Stat = "DropPct",
		Value = 0.03,
	},
}

local byId: { [string]: InsertDef } = {}
for _, def in list do
	byId[def.Id] = def
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
})
