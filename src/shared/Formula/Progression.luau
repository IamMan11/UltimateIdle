--!strict
-- XP needed per level (hero, account) and how a pool of XP turns into levels.

local Progression = {}

function Progression.HeroXpToNext(level: number): number
	return math.floor(20 * 1.057 ^ (level - 1) * (1 + 0.06 * (level - 1)))
end

function Progression.AccountXpToNext(level: number): number
	return math.floor(60 * 1.05 ^ (level - 1) * (1 + 0.08 * (level - 1)))
end

-- Adds xp to (level, xp) and returns the new pair; stops at cap with xp clamped to 0.
function Progression.Apply(
	level: number,
	xp: number,
	gained: number,
	cap: number,
	toNext: (number) -> number
): (number, number)
	if level >= cap then
		return cap, 0
	end
	xp += gained
	local guard = 0
	while level < cap and guard < 10000 do
		local need = toNext(level)
		if xp < need then
			break
		end
		xp -= need
		level += 1
		guard += 1
	end
	if level >= cap then
		return cap, 0
	end
	return level, xp
end

return table.freeze(Progression)
