--!strict
-- Game formulas (pure, shared): scaling curves, xp, damage/wave timing, final stats, skills, account modifiers, team bonuses.

local Stats = require(script.Stats)
local Mods = require(script.Mods)
local Team = require(script.Team)

export type MonsterStats = Stats.MonsterStats
export type GearBonus = Stats.GearBonus
export type Mods = Mods.Mods
export type TeamMember = Team.Member

return table.freeze({
	Scaling = require(script.Scaling),
	Progression = require(script.Progression),
	Combat = require(script.Combat),
	Stats = Stats,
	Skills = require(script.Skills),
	Mods = Mods,
	Team = Team,
})
