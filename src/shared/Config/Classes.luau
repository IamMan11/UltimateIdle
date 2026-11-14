--!strict
-- Class advancement: 2 linear stages per class (hero level + gold + items), each adding base stats, skill power, faster cooldowns.

local Freeze = require(script.Parent.Parent.Freeze)

export type StageDef = {
	Index: number,
	HeroLevel: number,
	Gold: number,
	Items: { [string]: number }, -- material id -> count
	StatBonus: number,
	SkillPower: number,
	CooldownCut: number,
}

-- Same requirements for every class for now; names live in Text.
local stages: { StageDef } = {
	{
		Index = 1,
		HeroLevel = 40,
		Gold = 20000,
		Items = { EnhanceStone = 20 },
		StatBonus = 0.1,
		SkillPower = 0.25,
		CooldownCut = 0.1,
	},
	{
		Index = 2,
		HeroLevel = 100,
		Gold = 500000,
		Items = { EnchantDust = 30, SocketCore = 10 },
		StatBonus = 0.15,
		SkillPower = 0.35,
		CooldownCut = 0.1,
	},
}

export type Totals = {
	StatBonus: number,
	SkillPower: number, -- multiplier, 1 at advancement 0
	CooldownMult: number,
}

local Classes = {
	Stages = stages,
	MaxAdvancement = #stages,
}

-- Combined effect of every stage up to `advancement`.
function Classes.Totals(advancement: number): Totals
	local out: Totals = { StatBonus = 0, SkillPower = 1, CooldownMult = 1 }
	for i = 1, math.min(advancement, #stages) do
		local s = stages[i]
		out.StatBonus += s.StatBonus
		out.SkillPower += s.SkillPower
		out.CooldownMult *= 1 - s.CooldownCut
	end
	return out
end

return Freeze(Classes)
