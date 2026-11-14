--!strict
-- Account skill tree: 3 branches, nodes with cost (gold / materials / rebirth points), prerequisites, effects, toggleable flag, grid position.

local Freeze = require(script.Parent.Parent.Freeze)

export type Branch = "Combat" | "Economy" | "System"
-- Pct kinds add to a multiplier (0.1 = +10%). TeamSlots adds slots. OfflineShare adds to the offline share.
-- AutoOpen unlocks box auto-open with Value = seconds between opens; AutoOpenSpeed multiplies that interval.
export type EffectKind =
	"AtkPct"
	| "HpPct"
	| "DefPct"
	| "GoldPct"
	| "XpPct"
	| "OfflineShare"
	| "BoxCapPct"
	| "TeamSlots"
	| "AutoOpen"
	| "AutoOpenSpeed"

export type Effect = {
	Kind: EffectKind,
	Value: number,
}

export type Cost = {
	Gold: number?,
	Items: { [string]: number }?,
	RebirthPoints: number?,
}

export type NodeDef = {
	Id: string,
	Branch: Branch,
	Row: number, -- 1 = top of the branch
	Col: number, -- -1 / 0 / 1 inside the branch column
	Requires: { string },
	Cost: Cost,
	Effects: { Effect },
	Toggle: boolean, -- can be switched off after buying (effects pause while off)
}

local list: { NodeDef } = {
	-- Combat
	{
		Id = "c_atk1",
		Branch = "Combat",
		Row = 1,
		Col = 0,
		Requires = {},
		Cost = { Gold = 300 },
		Effects = { { Kind = "AtkPct", Value = 0.05 } },
		Toggle = false,
	},
	{
		Id = "c_squad1",
		Branch = "Combat",
		Row = 2,
		Col = 0,
		Requires = { "c_atk1" },
		Cost = { Gold = 1500 },
		Effects = { { Kind = "TeamSlots", Value = 1 } },
		Toggle = false,
	},
	{
		Id = "c_hp1",
		Branch = "Combat",
		Row = 3,
		Col = -1,
		Requires = { "c_squad1" },
		Cost = { Gold = 4000 },
		Effects = { { Kind = "HpPct", Value = 0.08 } },
		Toggle = false,
	},
	{
		Id = "c_def1",
		Branch = "Combat",
		Row = 3,
		Col = 1,
		Requires = { "c_squad1" },
		Cost = { Gold = 10000 },
		Effects = { { Kind = "DefPct", Value = 0.08 } },
		Toggle = false,
	},
	{
		Id = "c_squad2",
		Branch = "Combat",
		Row = 4,
		Col = 0,
		Requires = { "c_hp1", "c_def1" },
		Cost = { Gold = 40000, Items = { EnhanceStone = 30 } },
		Effects = { { Kind = "TeamSlots", Value = 1 } },
		Toggle = false,
	},
	{
		Id = "c_berserk",
		Branch = "Combat",
		Row = 5,
		Col = -1,
		Requires = { "c_squad2" },
		Cost = { Gold = 80000 },
		Effects = { { Kind = "AtkPct", Value = 0.2 }, { Kind = "DefPct", Value = -0.15 } },
		Toggle = true,
	},
	{
		Id = "c_atk2",
		Branch = "Combat",
		Row = 5,
		Col = 1,
		Requires = { "c_squad2" },
		Cost = { Gold = 200000 },
		Effects = { { Kind = "AtkPct", Value = 0.1 } },
		Toggle = false,
	},
	{
		Id = "c_squad3",
		Branch = "Combat",
		Row = 6,
		Col = 0,
		Requires = { "c_atk2" },
		Cost = { Gold = 600000, Items = { SocketCore = 10 } },
		Effects = { { Kind = "TeamSlots", Value = 1 } },
		Toggle = false,
	},

	-- Economy
	{
		Id = "e_gold1",
		Branch = "Economy",
		Row = 1,
		Col = 0,
		Requires = {},
		Cost = { Gold = 800 },
		Effects = { { Kind = "GoldPct", Value = 0.1 } },
		Toggle = false,
	},
	{
		Id = "e_offline1",
		Branch = "Economy",
		Row = 2,
		Col = -1,
		Requires = { "e_gold1" },
		Cost = { Gold = 3000 },
		Effects = { { Kind = "OfflineShare", Value = 0.05 } },
		Toggle = false,
	},
	{
		Id = "e_xp1",
		Branch = "Economy",
		Row = 2,
		Col = 1,
		Requires = { "e_gold1" },
		Cost = { Gold = 8000 },
		Effects = { { Kind = "XpPct", Value = 0.1 } },
		Toggle = false,
	},
	{
		Id = "e_gold2",
		Branch = "Economy",
		Row = 3,
		Col = -1,
		Requires = { "e_offline1" },
		Cost = { Gold = 30000 },
		Effects = { { Kind = "GoldPct", Value = 0.15 } },
		Toggle = false,
	},
	{
		Id = "e_veteran",
		Branch = "Economy",
		Row = 3,
		Col = 1,
		Requires = { "e_xp1" },
		Cost = { RebirthPoints = 1 },
		Effects = { { Kind = "XpPct", Value = 0.1 } },
		Toggle = false,
	},
	{
		Id = "e_offline2",
		Branch = "Economy",
		Row = 4,
		Col = 0,
		Requires = { "e_gold2" },
		Cost = { Gold = 120000, Items = { EnchantDust = 20 } },
		Effects = { { Kind = "OfflineShare", Value = 0.1 } },
		Toggle = false,
	},

	-- System
	{
		Id = "s_boxcap1",
		Branch = "System",
		Row = 1,
		Col = 0,
		Requires = {},
		Cost = { Gold = 1000 },
		Effects = { { Kind = "BoxCapPct", Value = 0.4 } },
		Toggle = false,
	},
	{
		Id = "s_autoopen",
		Branch = "System",
		Row = 2,
		Col = -1,
		Requires = { "s_boxcap1" },
		Cost = { Gold = 6000 },
		Effects = { { Kind = "AutoOpen", Value = 20 } },
		Toggle = false,
	},
	{
		Id = "s_boxcap2",
		Branch = "System",
		Row = 2,
		Col = 1,
		Requires = { "s_boxcap1" },
		Cost = { Gold = 25000, Items = { EnhanceStone = 20 } },
		Effects = { { Kind = "BoxCapPct", Value = 0.6 } },
		Toggle = false,
	},
	{
		Id = "s_autoopen2",
		Branch = "System",
		Row = 3,
		Col = -1,
		Requires = { "s_autoopen" },
		Cost = { Gold = 50000 },
		Effects = { { Kind = "AutoOpenSpeed", Value = 0.5 } },
		Toggle = false,
	},
	{
		Id = "s_autoopen3",
		Branch = "System",
		Row = 4,
		Col = -1,
		Requires = { "s_autoopen2" },
		Cost = { Gold = 250000, Items = { SocketCore = 5 } },
		Effects = { { Kind = "AutoOpenSpeed", Value = 0.5 } },
		Toggle = false,
	},
}

local byId: { [string]: NodeDef } = {}
for _, def in list do
	assert(byId[def.Id] == nil, `duplicate skill tree node {def.Id}`)
	byId[def.Id] = def
end
for _, def in list do
	for _, req in def.Requires do
		assert(byId[req] ~= nil, `{def.Id} requires unknown node {req}`)
	end
end

return Freeze({
	List = list,
	ById = byId,
	Branches = { "Combat", "Economy", "System" },
	MinAutoOpenInterval = 2,
})
