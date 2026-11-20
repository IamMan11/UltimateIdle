--!strict
-- Class advancement: 2 stages per class (hero level + gold + items), each adding base stats, skill power, faster cooldowns · 2 paths per class, picked with the first stage: each stage reached also adds its path's bonus.

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

-- Bonus a path adds for every stage reached, on top of the stage's own. Names live in Text.
export type PathDef = {
	Index: number,
	AtkPct: number,
	HpPct: number,
	DefPct: number,
	SkillPower: number,
}

local paths: { PathDef } = {
	-- Power: hits harder.
	{ Index = 1, AtkPct = 0.12, HpPct = 0, DefPct = 0, SkillPower = 0.1 },
	-- Guard: lasts longer.
	{ Index = 2, AtkPct = 0, HpPct = 0.15, DefPct = 0.15, SkillPower = 0 },
}

export type Totals = {
	StatBonus: number,
	SkillPower: number, -- multiplier, 1 at advancement 0
	CooldownMult: number,
	-- From the path, on top of StatBonus.
	AtkPct: number,
	HpPct: number,
	DefPct: number,
}

local Classes = {
	Stages = stages,
	Paths = paths,
	MaxAdvancement = #stages,
}

-- Combined effect of every stage up to `advancement` on `path` (nil = path 1: heroes advanced before paths existed).
function Classes.Totals(advancement: number, path: number?): Totals
	local out: Totals = { StatBonus = 0, SkillPower = 1, CooldownMult = 1, AtkPct = 0, HpPct = 0, DefPct = 0 }
	local p = paths[path or 1] or paths[1]
	for i = 1, math.min(advancement, #stages) do
		local s = stages[i]
		out.StatBonus += s.StatBonus
		out.SkillPower += s.SkillPower + p.SkillPower
		out.CooldownMult *= 1 - s.CooldownCut
		out.AtkPct += p.AtkPct
		out.HpPct += p.HpPct
		out.DefPct += p.DefPct
	end
	return out
end

return Freeze(Classes)
