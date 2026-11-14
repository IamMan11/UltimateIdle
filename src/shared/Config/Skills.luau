--!strict
-- Hero skills per class: 1 passive + 2 actives (auto-cast), unlock level, cooldown, effect numbers. Advancement scaling is in Config.Classes.

local Freeze = require(script.Parent.Parent.Freeze)

export type SkillSlot = "Passive" | "Active1" | "Active2"
-- Damage: hit up to Targets monsters in range (0 = all in range) for Mult x attack.
-- Shield: whole team takes Reduce less damage for Duration seconds (cast once monsters are in contact).
-- HealAll: heal every alive ally for Mult x heal power when one drops under Threshold hp.
-- Revive: bring back one fallen ally at HpRatio hp.
export type SkillKind = "Passive" | "Damage" | "Shield" | "HealAll" | "Revive"

export type PassiveBonus = {
	AtkPct: number?,
	HpPct: number?,
	DefPct: number?,
	HealPct: number?,
	IntervalPct: number?, -- negative = attacks faster
}

export type SkillDef = {
	Id: string,
	Index: number, -- position in List; sent in timeline events
	Class: string,
	Slot: SkillSlot,
	UnlockLevel: number,
	Kind: SkillKind,
	Cooldown: number,
	Mult: number,
	Targets: number,
	Duration: number,
	Reduce: number,
	HpRatio: number,
	Threshold: number,
	Passive: PassiveBonus?,
}

type Spec = {
	Id: string,
	Class: string,
	Slot: SkillSlot,
	UnlockLevel: number,
	Kind: SkillKind,
	Cooldown: number?,
	Mult: number?,
	Targets: number?,
	Duration: number?,
	Reduce: number?,
	HpRatio: number?,
	Threshold: number?,
	Passive: PassiveBonus?,
}

local SPECS: { Spec } = {
	{
		Id = "IronSkin",
		Class = "Warrior",
		Slot = "Passive",
		UnlockLevel = 15,
		Kind = "Passive",
		Passive = { DefPct = 0.25, HpPct = 0.1 },
	},
	{
		Id = "PowerStrike",
		Class = "Warrior",
		Slot = "Active1",
		UnlockLevel = 5,
		Kind = "Damage",
		Cooldown = 8,
		Mult = 3,
		Targets = 1,
	},
	{
		Id = "ShieldWall",
		Class = "Warrior",
		Slot = "Active2",
		UnlockLevel = 35,
		Kind = "Shield",
		Cooldown = 25,
		Duration = 6,
		Reduce = 0.4,
	},

	{
		Id = "ArcaneFocus",
		Class = "Mage",
		Slot = "Passive",
		UnlockLevel = 15,
		Kind = "Passive",
		Passive = { AtkPct = 0.15 },
	},
	{
		Id = "Fireball",
		Class = "Mage",
		Slot = "Active1",
		UnlockLevel = 5,
		Kind = "Damage",
		Cooldown = 9,
		Mult = 2.2,
		Targets = 3,
	},
	{
		Id = "Meteor",
		Class = "Mage",
		Slot = "Active2",
		UnlockLevel = 35,
		Kind = "Damage",
		Cooldown = 22,
		Mult = 1.6,
		Targets = 0,
	},

	{
		Id = "QuickDraw",
		Class = "Archer",
		Slot = "Passive",
		UnlockLevel = 15,
		Kind = "Passive",
		Passive = { IntervalPct = -0.12 },
	},
	{
		Id = "AimedShot",
		Class = "Archer",
		Slot = "Active1",
		UnlockLevel = 5,
		Kind = "Damage",
		Cooldown = 8,
		Mult = 3.5,
		Targets = 1,
	},
	{
		Id = "ArrowRain",
		Class = "Archer",
		Slot = "Active2",
		UnlockLevel = 35,
		Kind = "Damage",
		Cooldown = 18,
		Mult = 1.1,
		Targets = 6,
	},

	{
		Id = "Grace",
		Class = "Healer",
		Slot = "Passive",
		UnlockLevel = 15,
		Kind = "Passive",
		Passive = { HealPct = 0.2 },
	},
	{
		Id = "MassHeal",
		Class = "Healer",
		Slot = "Active1",
		UnlockLevel = 5,
		Kind = "HealAll",
		Cooldown = 12,
		Mult = 1.2,
		Threshold = 0.7,
	},
	{
		Id = "Resurrect",
		Class = "Healer",
		Slot = "Active2",
		UnlockLevel = 35,
		Kind = "Revive",
		Cooldown = 30,
		HpRatio = 0.5,
	},
}

local list: { SkillDef } = {}
local byId: { [string]: SkillDef } = {}
local byClass: { [string]: { SkillDef } } = {}
for i, s in SPECS do
	local def: SkillDef = {
		Id = s.Id,
		Index = i,
		Class = s.Class,
		Slot = s.Slot,
		UnlockLevel = s.UnlockLevel,
		Kind = s.Kind,
		Cooldown = s.Cooldown or 0,
		Mult = s.Mult or 0,
		Targets = s.Targets or 0,
		Duration = s.Duration or 0,
		Reduce = s.Reduce or 0,
		HpRatio = s.HpRatio or 0,
		Threshold = s.Threshold or 0,
		Passive = s.Passive,
	}
	table.insert(list, def)
	byId[def.Id] = def
	local forClass = byClass[def.Class]
	if forClass == nil then
		forClass = {}
		byClass[def.Class] = forClass
	end
	table.insert(forClass, def)
end

return Freeze({
	List = list,
	ById = byId,
	ByClass = byClass,
	SlotOrder = { "Active1", "Passive", "Active2" },
	MaxShieldReduce = 0.8,
	MaxDamageTargets = 12, -- Targets = 0 is capped here
	FirstCastDelay = 2, -- seconds into a level before any skill can fire
})
