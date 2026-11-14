--!strict
-- Rows: order, x position in the lane, capacity · bonus for a hero in its class's preferred row · class pairs that boost each other.

local Freeze = require(script.Parent.Parent.Freeze)

return Freeze({
	Rows = { "Front", "Middle", "Back" },
	RowX = { Front = 0, Middle = -5, Back = -10 },
	MaxPerRow = 4,
	LaneSpacing = 2.5, -- z gap between heroes sharing a row
	PreferredRowBonus = 0.1, -- +10% attack/hp/defense/heal
	Pairs = {
		{ A = "Warrior", B = "Healer", Bonus = 0.05 },
		{ A = "Mage", B = "Archer", Bonus = 0.05 },
		{ A = "Warrior", B = "Mage", Bonus = 0.04 },
	},
})
