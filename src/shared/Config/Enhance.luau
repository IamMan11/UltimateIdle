--!strict
-- Enhancement +1..+10: stat gain per step, gold/stone costs, special items some pieces need. Success rates are server-only (Secret/EnhanceRates).

local Freeze = require(script.Parent.Parent.Freeze)

export type ExtraRule = {
	Tag: string, -- item def tag that triggers the rule
	FromPlus: number, -- applies when enhancing from this plus upward
	Id: string,
	Count: number,
}

return Freeze({
	MaxPlus = 10,
	StatPerPlus = 0.1, -- gear stat multiplier gained per +1
	-- Gold = GoldBase * Scaling.Item(level) * TierMult * GoldGrowth ^ plus
	GoldBase = 40,
	GoldGrowth = 1.35,
	-- Stones = ceil((StoneBase + StonePerPlus * plus) * TierMult)
	StoneItem = "EnhanceStone",
	StoneBase = 2,
	StonePerPlus = 2,
	TierMult = { Common = 1, Uncommon = 1.6, Rare = 2.5 } :: { [string]: number },
	Extra = {
		{ Tag = "ancient", FromPlus = 0, Id = "AncientShard", Count = 1 },
	} :: { ExtraRule },
})
