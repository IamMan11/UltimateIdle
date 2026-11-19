--!strict
-- SERVER ONLY. Power roll chances: weight per trait id (Config.Enchant), per gear tier. Higher tiers lean to rarer traits.

local WEIGHTS: { [string]: { [string]: number } } = {
	Common = {
		Strength = 25,
		Vitality = 25,
		Guard = 25,
		Speed = 7,
		Range = 6,
		Haste = 6,
		Vampire = 2.5,
		Deadeye = 2.5,
		Godspeed = 0.8,
		God = 0.2,
	},
	Uncommon = {
		Strength = 20,
		Vitality = 20,
		Guard = 20,
		Speed = 9,
		Range = 9,
		Haste = 9,
		Vampire = 5,
		Deadeye = 5,
		Godspeed = 2.4,
		God = 0.6,
	},
	Rare = {
		Strength = 14,
		Vitality = 14,
		Guard = 14,
		Speed = 11,
		Range = 11,
		Haste = 11,
		Vampire = 9,
		Deadeye = 9,
		Godspeed = 5.5,
		God = 1.5,
	},
}

local EnchantPools = {}

-- A fresh copy (the caller may edit it).
function EnchantPools.Get(tier: string): { [string]: number }
	return table.clone(WEIGHTS[tier] or WEIGHTS.Common)
end

return table.freeze(EnchantPools)
