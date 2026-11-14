--!strict
-- Battle pass: one season per UTC month (same as the monthly shop), free + premium track, points from quests.

local Freeze = require(script.Parent.Parent.Freeze)
local Types = require(script.Parent.Parent.Types)

export type Track = "Free" | "Paid"

local TIERS = 30
local POINTS_PER_TIER = 80

local free: { Types.Reward } = {}
local paid: { Types.Reward } = {}
for tier = 1, TIERS do
	local f: Types.Reward
	if tier % 10 == 0 then
		f = { Ruby = 50, Boxes = { Boss = 3 } }
	elseif tier % 5 == 0 then
		f = { Ruby = 25, Materials = { EnchantDust = 5 } }
	elseif tier % 2 == 0 then
		f = { Materials = { EnhanceStone = 20 } }
	else
		f = { Gold = 10, Boxes = { Normal = 2 } }
	end
	free[tier] = f

	local p: Types.Reward
	if tier % 10 == 0 then
		p = { Ruby = 150, Materials = { SocketCore = 2, AncientShard = 3 } }
	elseif tier % 5 == 0 then
		p = { Ruby = 75, Materials = { AncientShard = 2 } }
	elseif tier % 3 == 0 then
		p = { Materials = { EnchantDust = 8, EnhanceStone = 30 } }
	else
		p = { Ruby = 20, Gold = 20, Boxes = { Boss = 1 } }
	end
	paid[tier] = p
end

return Freeze({
	Tiers = TIERS,
	PointsPerTier = POINTS_PER_TIER,
	Free = free,
	Paid = paid,
	-- Config.Shop.Products key of the premium track purchase (valid for the season it is bought in).
	PremiumProduct = "PremiumPass",
})
