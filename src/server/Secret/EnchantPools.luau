--!strict
-- SERVER ONLY. Enchant trait pools per tier: weight + integer value range. Lines never repeat a trait.

export type Trait = { Id: string, Weight: number, Min: number, Max: number }

local POOLS: { [string]: { Trait } } = {
	Common = {
		{ Id = "AtkPct", Weight = 30, Min = 2, Max = 6 },
		{ Id = "HpPct", Weight = 30, Min = 2, Max = 6 },
		{ Id = "DefPct", Weight = 25, Min = 2, Max = 6 },
		{ Id = "AtkSpeed", Weight = 10, Min = 1, Max = 4 },
		{ Id = "MoveSpeed", Weight = 5, Min = 1, Max = 1 },
	},
	Uncommon = {
		{ Id = "AtkPct", Weight = 30, Min = 4, Max = 10 },
		{ Id = "HpPct", Weight = 30, Min = 4, Max = 10 },
		{ Id = "DefPct", Weight = 25, Min = 4, Max = 10 },
		{ Id = "AtkSpeed", Weight = 10, Min = 2, Max = 7 },
		{ Id = "MoveSpeed", Weight = 5, Min = 1, Max = 2 },
	},
	Rare = {
		{ Id = "AtkPct", Weight = 30, Min = 6, Max = 15 },
		{ Id = "HpPct", Weight = 30, Min = 6, Max = 15 },
		{ Id = "DefPct", Weight = 25, Min = 6, Max = 15 },
		{ Id = "AtkSpeed", Weight = 10, Min = 3, Max = 10 },
		{ Id = "MoveSpeed", Weight = 5, Min = 1, Max = 3 },
	},
}

local EnchantPools = {}

function EnchantPools.Get(tier: string): { Trait }
	return POOLS[tier] or POOLS.Common
end

return table.freeze(EnchantPools)
