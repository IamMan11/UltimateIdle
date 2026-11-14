--!strict
-- Personal (account) level: feature unlocks, small account-wide bonuses at milestones, share of hero xp that feeds it.

local Freeze = require(script.Parent.Parent.Freeze)

-- A feature unlocks when every listed condition holds. StageLevel = best level reached in any rebirth.
export type Unlock = {
	AccountLevel: number?,
	StageLevel: number?,
}

export type Bonus = {
	Level: number,
	Kind: "AtkPct" | "HpPct" | "GoldPct" | "XpPct",
	Value: number,
}

local unlocks: { [string]: Unlock } = {
	Farm = { StageLevel = 200 },
	Trade = { AccountLevel = 15 },
}

local bonuses: { Bonus } = {
	{ Level = 5, Kind = "GoldPct", Value = 0.03 },
	{ Level = 10, Kind = "XpPct", Value = 0.03 },
	{ Level = 20, Kind = "AtkPct", Value = 0.03 },
	{ Level = 30, Kind = "GoldPct", Value = 0.05 },
	{ Level = 50, Kind = "HpPct", Value = 0.05 },
	{ Level = 75, Kind = "XpPct", Value = 0.05 },
	{ Level = 100, Kind = "AtkPct", Value = 0.05 },
}

local Account = {
	Unlocks = unlocks,
	Bonuses = bonuses,
	XpShare = 0.25, -- account xp gained per hero xp earned in a level
}

function Account.IsUnlocked(feature: string, accountLevel: number, stageLevel: number): boolean
	local rule = unlocks[feature]
	if rule == nil then
		return false
	end
	return accountLevel >= (rule.AccountLevel or 0) and stageLevel >= (rule.StageLevel or 0)
end

return Freeze(Account)
