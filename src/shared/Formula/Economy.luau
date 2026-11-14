--!strict
-- Gold amounts that keep their worth as the player progresses: "gold-level" units scaled by the best stage level reached.

local Shop = require(script.Parent.Parent.Config.Shop)
local Scaling = require(script.Parent.Scaling)

local Economy = {}

function Economy.Gold(units: number, bestLevel: number): number
	return math.floor(units * Shop.GoldUnit * Scaling.Gold(bestLevel))
end

return table.freeze(Economy)
