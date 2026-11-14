--!strict
-- SERVER ONLY. Enhance success chance by the plus being reached (index 1 = +0 -> +1). Failure keeps the plus.

local RATES = { 1, 0.95, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2 }

local EnhanceRates = {}

function EnhanceRates.Get(targetPlus: number): number
	return RATES[math.clamp(targetPlus, 1, #RATES)]
end

return table.freeze(EnhanceRates)
