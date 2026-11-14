--!strict
-- Final stats: hero (class + level + worn gear), single gear piece, monster at a stage level.

local Types = require(script.Parent.Parent.Types)
local Heroes = require(script.Parent.Parent.Config.Heroes)
local Items = require(script.Parent.Parent.Config.Items)
local Monsters = require(script.Parent.Parent.Config.Monsters)
local Scaling = require(script.Parent.Scaling)

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
	local mult = Scaling.Item(item.Level) * item.GearScore / 100 * (1 + 0.1 * item.Plus)
	if wearer ~= nil and wearer ~= def.Class then
		mult *= Items.ClassMismatchMultiplier
	end
	out.MaxHp = (def.Stats.MaxHp or 0) * mult
	out.Atk = (def.Stats.Atk or 0) * mult
	out.Def = (def.Stats.Def or 0) * mult
	out.Speed = def.Stats.Speed or 0
	return out
end

function Stats.Power(s: Types.HeroStats): number
	return s.Atk / s.AtkInterval * (1 + 0.5 * s.Splash) + s.MaxHp * 0.1 + s.Def * 0.5 + s.Heal
end

function Stats.Hero(class: string, level: number, gear: { Types.GearItem }): Types.HeroStats
	local def = Heroes.ById[class]
	assert(def ~= nil, `unknown hero class {class}`)
	local scale = Scaling.Hero(level)
	local s: Types.HeroStats = {
		MaxHp = def.MaxHp * scale,
		Atk = def.Atk * scale,
		Def = def.Def * scale,
		AtkInterval = def.AtkInterval,
		Range = def.Range,
		Speed = def.Speed,
		Splash = def.Splash,
		Heal = def.Heal * scale,
		Power = 0,
	}
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
	end
	if s.Heal > 0 then
		-- Healers heal with their own attack growth too.
		s.Heal = math.max(s.Heal, s.Atk * 1.5)
	end
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
