--!strict
-- Enchant: trait lines per tier, cost, trait display order. Value pools are server-only (Secret/EnchantPools).

local Freeze = require(script.Parent.Parent.Freeze)

return Freeze({
	Item = "EnchantDust",
	Lines = { Common = 1, Uncommon = 2, Rare = 3 } :: { [string]: number },
	Dust = { Common = 2, Uncommon = 4, Rare = 8 } :: { [string]: number },
	GoldBase = 60, -- x Formula.Scaling.Item(gear level)
	-- Pct traits are percent points (10 = +10%); MoveSpeed is flat speed.
	Traits = { "AtkPct", "HpPct", "DefPct", "AtkSpeed", "MoveSpeed" },
})
