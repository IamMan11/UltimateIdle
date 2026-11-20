--!strict
-- Final stats: hero (class + level + advancement + worn gear incl. gems/artifacts/enchants + passive), single gear piece, monster at a stage level.

local Types = require(script.Parent.Parent.Types)
local Heroes = require(script.Parent.Parent.Config.Heroes)
local Items = require(script.Parent.Parent.Config.Items)
local Monsters = require(script.Parent.Parent.Config.Monsters)
local Classes = require(script.Parent.Parent.Config.Classes)
local Inserts = require(script.Parent.Parent.Config.Inserts)
local Scaling = require(script.Parent.Scaling)
local Skills = require(script.Parent.Skills)
local Gear = require(script.Parent.Gear)

export type GearBonus = {
	MaxHp: number,
	Atk: number,
	Def: number,
	Speed: number,
}

export type MonsterStats = {
	MaxHp: number,
	Atk: number,
	Def: number,
	AtkInterval: number,
	Range: number,
	MoveSpeed: number,
}

-- Weapon abilities: only active when the wearer's class matches the weapon's class label.
local ABILITIES: { [string]: (Types.HeroStats) -> () } = {
	Cleave = function(s)
		s.Splash += 1
	end,
	Overload = function(s)
		s.Atk *= 1.15
	end,
	Pierce = function(s)
		s.Range += 6
	end,
	Blessing = function(s)
		s.Heal *= 1.25
	end,
}

local Stats = {}

function Stats.Gear(item: Types.GearItem, wearer: string?): GearBonus
	local def = Items.ById[item.BaseId]
	local out: GearBonus = { MaxHp = 0, Atk = 0, Def = 0, Speed = 0 }
	if def == nil then
		return out
	end
	local mismatch = if wearer ~= nil and wearer ~= def.Class then Items.ClassMismatchMultiplier else 1
	local mult = Scaling.Item(item.Level) * item.GearScore / 100 * Gear.PlusMult(item.Plus) * mismatch
	local gemHp, gemAtk, gemDef = Gear.Gems(item)
	out.MaxHp = (def.Stats.MaxHp or 0) * mult + gemHp * mismatch
	out.Atk = (def.Stats.Atk or 0) * mult + gemAtk * mismatch
	out.Def = (def.Stats.Def or 0) * mult + gemDef * mismatch
	out.Speed = def.Stats.Speed or 0
	return out
end

function Stats.Power(s: Types.HeroStats): number
	local crit = 1 + s.Crit * (Inserts.CritMult - 1)
	return s.Atk * crit / s.AtkInterval * (1 + 0.5 * s.Splash) * (1 + s.Lifesteal)
		+ s.MaxHp * 0.1
		+ s.Def * 0.5
		+ s.Heal
end

function Stats.Hero(
	class: string,
	level: number,
	gear: { Types.GearItem },
	advancement: number,
	path: number?
): Types.HeroStats
	local def = Heroes.ById[class]
	assert(def ~= nil, `unknown hero class {class}`)
	local totals = Classes.Totals(advancement, path)
	local scale = Scaling.Hero(level) * (1 + totals.StatBonus)
	local s: Types.HeroStats = {
		MaxHp = def.MaxHp * scale * (1 + totals.HpPct),
		Atk = def.Atk * scale * (1 + totals.AtkPct),
		Def = def.Def * scale * (1 + totals.DefPct),
		AtkInterval = def.AtkInterval,
		Range = def.Range,
		Speed = def.Speed,
		Splash = def.Splash,
		Heal = def.Heal * scale,
		Lifesteal = 0,
		Crit = 0,
		Power = 0,
	}
	local extras = Gear.NewExtras()
	for _, item in gear do
		local bonus = Stats.Gear(item, class)
		s.MaxHp += bonus.MaxHp
		s.Atk += bonus.Atk
		s.Def += bonus.Def
		s.Speed += bonus.Speed
		local itemDef = Items.ById[item.BaseId]
		if itemDef ~= nil and itemDef.Ability ~= nil and itemDef.Class == class then
			local apply = ABILITIES[itemDef.Ability]
			if apply ~= nil then
				apply(s)
			end
		end
		Gear.AddExtras(extras, item)
	end
	Gear.CapExtras(extras)
	s.Atk *= 1 + extras.AtkPct / 100
	s.MaxHp *= 1 + extras.HpPct / 100
	s.Def *= 1 + extras.DefPct / 100
	s.AtkInterval /= 1 + extras.AtkSpeed / 100
	s.Speed *= 1 + extras.MovePct / 100
	s.Range *= 1 + extras.RangePct / 100
	s.Lifesteal = extras.Lifesteal
	s.Crit = extras.Crit
	s.Splash += extras.Splash
	if s.Heal > 0 then
		-- Healers heal with their own attack growth too.
		s.Heal = math.max(s.Heal, s.Atk * 1.5)
	end
	Skills.ApplyPassive(s, class, level, advancement, path)
	s.Power = Stats.Power(s)
	return s
end

function Stats.Monster(def: Monsters.MonsterDef, level: number, rebirth: number): MonsterStats
	local scale = Scaling.Monster(level, rebirth)
	return {
		MaxHp = def.MaxHp * scale,
		Atk = def.Atk * scale,
		Def = def.Def * scale,
		AtkInterval = def.AtkInterval,
		Range = def.Range,
		MoveSpeed = def.MoveSpeed,
	}
end

return table.freeze(Stats)
