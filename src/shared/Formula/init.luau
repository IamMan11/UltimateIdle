--!strict
-- Game formulas (pure, shared): scaling curves, xp, damage/wave timing, final stats.

local Stats = require(script.Stats)

export type MonsterStats = Stats.MonsterStats
export type GearBonus = Stats.GearBonus

return table.freeze({
	Scaling = require(script.Scaling),
	Progression = require(script.Progression),
	Combat = require(script.Combat),
	Stats = Stats,
})
