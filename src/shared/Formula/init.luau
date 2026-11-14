--!strict
-- Game formulas (pure, shared): scaling curves, xp, damage/wave timing, final stats, skills, account modifiers, team bonuses, gear extras, forge costs, economy gold units.

local Stats = require(script.Stats)
local Mods = require(script.Mods)
local Team = require(script.Team)
local Gear = require(script.Gear)

export type MonsterStats = Stats.MonsterStats
export type GearBonus = Stats.GearBonus
export type Mods = Mods.Mods
export type TeamMember = Team.Member
export type GearExtras = Gear.Extras

return table.freeze({
	Scaling = require(script.Scaling),
	Progression = require(script.Progression),
	Combat = require(script.Combat),
	Stats = Stats,
	Skills = require(script.Skills),
	Mods = Mods,
	Team = Team,
	Gear = Gear,
	Forge = require(script.Forge),
	Economy = require(script.Economy),
})
