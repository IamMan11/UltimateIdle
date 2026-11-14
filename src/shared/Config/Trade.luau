--!strict
-- Trade limits and timing. The account level gate lives in Config.Account (Unlocks.Trade).

local Freeze = require(script.Parent.Parent.Freeze)

return Freeze({
	MaxGear = 50, -- gear pieces per side
	MaxKinds = 20, -- material / box stacks per side
	RequestSeconds = 30, -- an unanswered request expires
	ConfirmDelay = 3, -- seconds after the last offer change (or both ready) before the final confirm counts
})
