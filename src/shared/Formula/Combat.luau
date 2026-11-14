--!strict
-- Damage and wave timing. Damage is ratio-based so it stays sane at any number scale.

local Stages = require(script.Parent.Parent.Config.Stages)

local Combat = {}

function Combat.Damage(atk: number, def: number): number
	if atk <= 0 then
		return 0
	end
	return atk * atk / (atk + math.max(def, 0))
end

function Combat.WaveInterval(teamSpeed: number): number
	local speed = math.max(teamSpeed, 1)
	return math.max(Stages.WaveIntervalBase * Stages.ReferenceSpeed / speed, Stages.MinWaveInterval)
end

function Combat.MonstersPerWave(level: number): number
	local extra = (level - 1) // Stages.LevelsPerExtraMonster
	return math.min(Stages.BaseMonstersPerWave + extra, Stages.MaxMonstersPerWave)
end

-- Kills in one cleared level: (normal kills, boss kills).
function Combat.KillsPerLevel(level: number): (number, number)
	local per = Combat.MonstersPerWave(level)
	local bossWave = math.max(per - Stages.BossWaveMinionDrop, 0)
	return per * (Stages.WavesPerLevel - 1) + bossWave, 1
end

return table.freeze(Combat)
