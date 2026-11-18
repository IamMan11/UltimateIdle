--!strict
-- Trade limits and timing. The account level gate lives in Config.Account (Unlocks.Trade).

local Freeze = require(script.Parent.Parent.Freeze)

return Freeze({
	MaxSlots = 9, -- things per side: gear pieces + material kinds + box kinds (the 3x3 offer grid)
	RequestSeconds = 30, -- an unanswered request expires
	ConfirmDelay = 3, -- seconds after the last offer change (or both ready) before the final confirm counts
})
