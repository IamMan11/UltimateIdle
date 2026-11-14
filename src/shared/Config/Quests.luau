--!strict
-- Daily / weekly / monthly quests (UTC reset): counter kind, target, Ruby + battle pass point rewards. One quest per kind per period.

local Freeze = require(script.Parent.Parent.Freeze)

export type Kind = "ClearLevel" | "Kill" | "Boss" | "Enhance" | "OpenBox" | "Enchant"
export type PeriodKind = "Daily" | "Weekly" | "Monthly"

export type QuestDef = {
	Id: string,
	Period: PeriodKind,
	Order: number,
	Kind: Kind,
	Need: number,
	Ruby: number,
	PassPoints: number,
}

local list: { QuestDef } = {
	{ Id = "D_Levels", Period = "Daily", Order = 1, Kind = "ClearLevel", Need = 30, Ruby = 5, PassPoints = 10 },
	{ Id = "D_Kills", Period = "Daily", Order = 2, Kind = "Kill", Need = 500, Ruby = 5, PassPoints = 10 },
	{ Id = "D_Bosses", Period = "Daily", Order = 3, Kind = "Boss", Need = 5, Ruby = 5, PassPoints = 10 },
	{ Id = "D_Enhance", Period = "Daily", Order = 4, Kind = "Enhance", Need = 10, Ruby = 5, PassPoints = 10 },
	{ Id = "D_Boxes", Period = "Daily", Order = 5, Kind = "OpenBox", Need = 10, Ruby = 5, PassPoints = 10 },

	{ Id = "W_Levels", Period = "Weekly", Order = 1, Kind = "ClearLevel", Need = 300, Ruby = 40, PassPoints = 50 },
	{ Id = "W_Bosses", Period = "Weekly", Order = 2, Kind = "Boss", Need = 50, Ruby = 40, PassPoints = 50 },
	{ Id = "W_Enhance", Period = "Weekly", Order = 3, Kind = "Enhance", Need = 80, Ruby = 40, PassPoints = 50 },
	{ Id = "W_Enchant", Period = "Weekly", Order = 4, Kind = "Enchant", Need = 15, Ruby = 40, PassPoints = 50 },
	{ Id = "W_Boxes", Period = "Weekly", Order = 5, Kind = "OpenBox", Need = 100, Ruby = 40, PassPoints = 50 },

	{ Id = "M_Levels", Period = "Monthly", Order = 1, Kind = "ClearLevel", Need = 1500, Ruby = 150, PassPoints = 150 },
	{ Id = "M_Kills", Period = "Monthly", Order = 2, Kind = "Kill", Need = 50000, Ruby = 150, PassPoints = 150 },
	{ Id = "M_Bosses", Period = "Monthly", Order = 3, Kind = "Boss", Need = 250, Ruby = 150, PassPoints = 150 },
	{ Id = "M_Enhance", Period = "Monthly", Order = 4, Kind = "Enhance", Need = 400, Ruby = 150, PassPoints = 150 },
}

local byId: { [string]: QuestDef } = {}
local byPeriod: { [string]: { QuestDef } } = { Daily = {}, Weekly = {}, Monthly = {} }
-- Period -> kind -> highest Need (progress is capped there so counters stay small).
local capByPeriod: { [string]: { [string]: number } } = { Daily = {}, Weekly = {}, Monthly = {} }
for _, def in list do
	assert(byId[def.Id] == nil, `duplicate quest {def.Id}`)
	byId[def.Id] = def
	table.insert(byPeriod[def.Period], def)
	local caps = capByPeriod[def.Period]
	caps[def.Kind] = math.max(caps[def.Kind] or 0, def.Need)
end
for _, defs in byPeriod do
	table.sort(defs, function(a, b)
		return a.Order < b.Order
	end)
end

return Freeze({
	List = list,
	ById = byId,
	ByPeriod = byPeriod,
	CapByPeriod = capByPeriod,
})
