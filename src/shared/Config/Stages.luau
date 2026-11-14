--!strict
-- Stage rules: wave layout, timing, revive, lose/retreat, sim limits. Scaling curves live in Formula.

local Freeze = require(script.Parent.Parent.Freeze)

return Freeze({
	WavesPerLevel = 5,
	BaseMonstersPerWave = 3,
	LevelsPerExtraMonster = 10,
	MaxMonstersPerWave = 8,
	-- Last wave = boss + this many fewer minions than a normal wave.
	BossWaveMinionDrop = 2,
	-- Seconds between waves at team speed 10; faster teams call waves sooner.
	WaveIntervalBase = 9,
	ReferenceSpeed = 10,
	MinWaveInterval = 3,
	FirstWaveDelay = 1,
	SpawnX = 36,
	SpawnSpread = 1.6, -- x gap between monsters of one wave
	ContactGap = 2.5, -- monsters stop this far in front of the first alive row
	SimStep = 0.1,
	MaxDuration = 180, -- level not cleared by then = lost
	ReviveSeconds = 60,
	ReviveHpRatio = 0.5,
	PauseBetweenLevels = 2,
	RetreatOnLose = 1,
})
