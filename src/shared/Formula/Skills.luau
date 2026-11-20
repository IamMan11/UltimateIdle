--!strict
-- Which skills a hero has unlocked and their numbers after advancement scaling; passive stat bonuses.

local Types = require(script.Parent.Parent.Types)
local SkillsConfig = require(script.Parent.Parent.Config.Skills)
local Classes = require(script.Parent.Parent.Config.Classes)

local Skills = {}

function Skills.IsUnlocked(def: SkillsConfig.SkillDef, heroLevel: number): boolean
	return heroLevel >= def.UnlockLevel
end

-- Scaled numbers for one skill at an advancement stage (used by the sim and the skills UI).
function Skills.Resolve(def: SkillsConfig.SkillDef, advancement: number, path: number?): Types.SimSkill
	local totals = Classes.Totals(advancement, path)
	local power = totals.SkillPower
	return {
		Index = def.Index,
		Kind = def.Kind,
		Cooldown = def.Cooldown * totals.CooldownMult,
		Mult = def.Mult * power,
		Targets = def.Targets,
		Duration = def.Duration,
		Reduce = math.min(def.Reduce * power, SkillsConfig.MaxShieldReduce),
		HpRatio = math.min(def.HpRatio * power, 1),
		Threshold = def.Threshold,
	}
end

-- Unlocked active skills in cast-priority order (Active2 first: it is the bigger one).
function Skills.Active(class: string, level: number, advancement: number, path: number?): { Types.SimSkill }
	local out: { Types.SimSkill } = {}
	local forClass = SkillsConfig.ByClass[class]
	if forClass == nil then
		return out
	end
	for _, slot in { "Active2", "Active1" } do
		for _, def in forClass do
			if def.Slot == slot and Skills.IsUnlocked(def, level) then
				table.insert(out, Skills.Resolve(def, advancement, path))
			end
		end
	end
	return out
end

-- Applies the class passive (if unlocked), scaled by advancement skill power.
function Skills.ApplyPassive(s: Types.HeroStats, class: string, level: number, advancement: number, path: number?)
	local forClass = SkillsConfig.ByClass[class]
	if forClass == nil then
		return
	end
	local power = Classes.Totals(advancement, path).SkillPower
	for _, def in forClass do
		local bonus = def.Passive
		if bonus ~= nil and Skills.IsUnlocked(def, level) then
			s.Atk *= 1 + (bonus.AtkPct or 0) * power
			s.MaxHp *= 1 + (bonus.HpPct or 0) * power
			s.Def *= 1 + (bonus.DefPct or 0) * power
			s.Heal *= 1 + (bonus.HealPct or 0) * power
			s.AtkInterval *= math.max(1 + (bonus.IntervalPct or 0) * power, 0.3)
		end
	end
end

return table.freeze(Skills)
