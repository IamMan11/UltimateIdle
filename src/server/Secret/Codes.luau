--!strict
-- SERVER ONLY (kept out of ReplicatedStorage so unreleased codes cannot be read by clients). Redeemable codes: one use per account.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Freeze = require(ReplicatedStorage.Shared.Freeze)
local Types = require(ReplicatedStorage.Shared.Types)

export type Code = {
	Id: string, -- saved in ProfileData.Codes; never reuse an id for a new code
	Reward: Types.Reward,
	Expires: number?, -- os.time() after which the code stops working (nil = never)
}

-- Keyed by the code players type, upper-case without spaces.
local codes: { [string]: Code } = {
	WELCOME = { Id = "WELCOME", Reward = { Ruby = 25, Gold = 10 } },
	RELEASE = { Id = "RELEASE", Reward = { Boxes = { Boss = 2 } }, Expires = nil },
}

return Freeze(codes)
