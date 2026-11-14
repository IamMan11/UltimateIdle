--!strict
-- Daily login reward: one claim per UTC day, a 7-day cycle; missing a day restarts the streak at day 1.

local Freeze = require(script.Parent.Parent.Freeze)
local Types = require(script.Parent.Parent.Types)

-- Gold is in "gold-level" units (Formula.Economy); boxes by kind.
local days: { Types.Reward } = {
	{ Gold = 10 },
	{ Gold = 15, Materials = { EnchantDust = 2 } },
	{ Ruby = 15 },
	{ Gold = 25, Boxes = { Normal = 2 } },
	{ Ruby = 20, Materials = { EnchantDust = 4 } },
	{ Gold = 40, Boxes = { Boss = 1 } },
	{ Ruby = 50, Boxes = { Boss = 2 } },
}

return Freeze({
	Days = days,
})
