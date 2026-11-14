--!strict
-- Per-rebirth caps and difficulty. Index 0 = before any rebirth. Phase 4 extends this table.

local Freeze = require(script.Parent.Parent.Freeze)

export type RebirthDef = {
	Index: number,
	HeroLevelCap: number,
	ItemLevelCap: number,
	Difficulty: number,
	FarmRoundCap: number, -- farm round ends (lump paid) when this level is cleared
	AccountLevelCap: number,
	WearCaps: { number }, -- highest item level a hero may wear, by class advancement (index 1 = not advanced)
}

local list: { RebirthDef } = {
	{
		Index = 0,
		HeroLevelCap = 150,
		ItemLevelCap = 150,
		Difficulty = 1,
		FarmRoundCap = 1000,
		AccountLevelCap = 100,
		WearCaps = { 60, 110, 150 },
	},
}

local Rebirth = {
	List = list,
}

function Rebirth.Get(index: number): RebirthDef
	return list[math.clamp(index + 1, 1, #list)]
end

function Rebirth.WearCap(index: number, advancement: number): number
	local caps = Rebirth.Get(index).WearCaps
	return caps[math.clamp(advancement + 1, 1, #caps)]
end

return Freeze(Rebirth)
