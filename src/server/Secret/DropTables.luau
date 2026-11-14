--!strict
-- SERVER ONLY. Stage drop rates per rebirth: gear/box/material chances per kill, tier weights.

export type MaterialDrop = { Id: string, Chance: number, Min: number, Max: number }

export type DropTable = {
	GearChance: number, -- per normal kill
	BossGearChance: number, -- per boss kill
	TierWeights: { [string]: number },
	NormalBoxChance: number,
	BossBoxChance: number,
	Materials: { MaterialDrop },
}

local list: { DropTable } = {
	-- rebirth 0
	{
		GearChance = 0.035,
		BossGearChance = 0.6,
		TierWeights = { Common = 82, Uncommon = 15, Rare = 3 },
		NormalBoxChance = 0.02,
		BossBoxChance = 0.3,
		Materials = {
			{ Id = "EnhanceStone", Chance = 0.08, Min = 1, Max = 2 },
			{ Id = "EnchantDust", Chance = 0.01, Min = 1, Max = 1 },
			{ Id = "SocketCore", Chance = 0.002, Min = 1, Max = 1 },
			{ Id = "AncientShard", Chance = 0.001, Min = 1, Max = 1 },
			{ Id = "GemAtk", Chance = 0.003, Min = 1, Max = 1 },
			{ Id = "GemHp", Chance = 0.003, Min = 1, Max = 1 },
			{ Id = "GemDef", Chance = 0.003, Min = 1, Max = 1 },
			{ Id = "ArtLifesteal", Chance = 0.0008, Min = 1, Max = 1 },
			{ Id = "ArtCrit", Chance = 0.0008, Min = 1, Max = 1 },
			{ Id = "ArtSplash", Chance = 0.0005, Min = 1, Max = 1 },
			{ Id = "RelicGold", Chance = 0.0006, Min = 1, Max = 1 },
			{ Id = "RelicXp", Chance = 0.0006, Min = 1, Max = 1 },
			{ Id = "RelicDrop", Chance = 0.0004, Min = 1, Max = 1 },
		},
	},
}

local DropTables = {}

function DropTables.Get(rebirth: number): DropTable
	return list[math.clamp(rebirth + 1, 1, #list)]
end

return table.freeze(DropTables)
