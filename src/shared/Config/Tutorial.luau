--!strict
-- Tutorial steps in order: the server event that completes each, the HUD page it points at, and the reward paid once per account.

local Freeze = require(script.Parent.Parent.Freeze)
local Types = require(script.Parent.Parent.Types)

export type Step = {
	Id: string,
	Event: string, -- Tutorial.Event id that completes the step
	Page: string?, -- HUD page button highlighted while the step is shown
	Reward: Types.Reward,
}

local steps: { Step } = {
	{ Id = "ClearLevel", Event = "ClearLevel", Page = nil, Reward = { Gold = 3 } },
	{ Id = "Equip", Event = "Equip", Page = "Team", Reward = { Boxes = { Normal = 1 } } },
	{ Id = "OpenBox", Event = "OpenBox", Page = "Inventory", Reward = { Gold = 10 } },
	{ Id = "BuyNode", Event = "BuyNode", Page = "Team", Reward = { Gold = 10 } },
	{ Id = "Enhance", Event = "Enhance", Page = "Inventory", Reward = { Ruby = 20 } },
}

return Freeze({
	Steps = steps,
})
