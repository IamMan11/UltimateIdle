--!strict
-- Growth curves by level: hero, monster, item stats and kill rewards. All return plain multipliers (1 at level 1).

local Rebirth = require(script.Parent.Parent.Config.Rebirth)

local Scaling = {}

local function curve(base: number, linear: number, level: number): number
	local l = math.max(level, 1) - 1
	return base ^ l * (1 + linear * l)
end

function Scaling.Hero(level: number): number
	return curve(1.06, 0.04, level)
end

function Scaling.Item(level: number): number
	return curve(1.06, 0.04, level)
end

function Scaling.Monster(level: number, rebirth: number): number
	return curve(1.055, 0.03, level) * Rebirth.Get(rebirth).Difficulty
end

function Scaling.Gold(level: number): number
	return curve(1.058, 0.05, level)
end

function Scaling.Xp(level: number): number
	return curve(1.055, 0.05, level)
end

return table.freeze(Scaling)
