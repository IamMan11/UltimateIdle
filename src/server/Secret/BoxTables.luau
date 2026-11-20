--!strict
-- SERVER ONLY. What a box rolls: tier weights, gear-score bias (share of the tier range skipped), box-only item chance, bonus materials.

export type BoxTable = {
	TierWeights: { [string]: number },
	ScoreFloor: number, -- 0..1: rolls start this far into the tier's gear score range
	BoxOnlyChance: number,
	Materials: { { Id: string, Chance: number, Min: number, Max: number } },
}

local NORMAL: BoxTable = {
	TierWeights = { Common = 55, Uncommon = 35, Rare = 10 },
	ScoreFloor = 0.4,
	BoxOnlyChance = 0.05,
	Materials = { { Id = "EnhanceStone", Chance = 0.5, Min = 1, Max = 3 } },
}

local BOSS: BoxTable = {
	TierWeights = { Common = 30, Uncommon = 45, Rare = 25 },
	ScoreFloor = 0.5,
	BoxOnlyChance = 0.12,
	Materials = {
		{ Id = "EnhanceStone", Chance = 1, Min = 2, Max = 5 },
		{ Id = "EnchantDust", Chance = 0.3, Min = 1, Max = 2 },
		{ Id = "AncientShard", Chance = 0.05, Min = 1, Max = 1 },
		{ Id = "SocketCore", Chance = 0.03, Min = 1, Max = 1 },
		{ Id = "GemAtk1", Chance = 0.08, Min = 1, Max = 1 },
		{ Id = "GemHp1", Chance = 0.08, Min = 1, Max = 1 },
		{ Id = "GemDef1", Chance = 0.08, Min = 1, Max = 1 },
		{ Id = "ArtLifesteal1", Chance = 0.02, Min = 1, Max = 1 },
		{ Id = "ArtCrit1", Chance = 0.02, Min = 1, Max = 1 },
		{ Id = "RelicGold1", Chance = 0.016, Min = 1, Max = 1 },
		{ Id = "RelicXp1", Chance = 0.016, Min = 1, Max = 1 },
		{ Id = "RelicDrop1", Chance = 0.016, Min = 1, Max = 1 },
		{ Id = "GemAtk", Chance = 0.04, Min = 1, Max = 1 },
		{ Id = "GemHp", Chance = 0.04, Min = 1, Max = 1 },
		{ Id = "GemDef", Chance = 0.04, Min = 1, Max = 1 },
		{ Id = "ArtLifesteal", Chance = 0.01, Min = 1, Max = 1 },
		{ Id = "ArtCrit", Chance = 0.01, Min = 1, Max = 1 },
		{ Id = "ArtSplash", Chance = 0.006, Min = 1, Max = 1 },
		{ Id = "RelicGold", Chance = 0.008, Min = 1, Max = 1 },
		{ Id = "RelicXp", Chance = 0.008, Min = 1, Max = 1 },
		{ Id = "RelicDrop", Chance = 0.005, Min = 1, Max = 1 },
	},
}

local CLASS: BoxTable = {
	TierWeights = { Common = 40, Uncommon = 42, Rare = 18 },
	ScoreFloor = 0.5,
	BoxOnlyChance = 0.1,
	Materials = { { Id = "EnhanceStone", Chance = 0.6, Min = 1, Max = 3 } },
}

local BoxTables = {}

function BoxTables.Get(boxId: string): BoxTable
	if boxId == "Boss" then
		return BOSS
	elseif string.sub(boxId, 1, 6) == "Class_" then
		return CLASS
	end
	return NORMAL
end

return table.freeze(BoxTables)
