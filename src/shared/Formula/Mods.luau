--!strict
-- Account-wide modifiers: skill tree nodes (owned and not switched off) + account level milestones, folded into one table.

local SkillTree = require(script.Parent.Parent.Config.SkillTree)
local Account = require(script.Parent.Parent.Config.Account)
local Game = require(script.Parent.Parent.Config.Game)

export type Mods = {
	AtkPct: number,
	HpPct: number,
	DefPct: number,
	GoldPct: number,
	XpPct: number,
	OfflineShare: number, -- added to Game.OfflineShare
	BoxCapPct: number,
	TeamSlots: number, -- total slots, base included
	AutoOpen: boolean,
	AutoOpenInterval: number, -- seconds; only meaningful when AutoOpen
}

local Mods = {}

function Mods.Build(tree: { [string]: number }, off: { [string]: boolean }, accountLevel: number): Mods
	local m: Mods = {
		AtkPct = 0,
		HpPct = 0,
		DefPct = 0,
		GoldPct = 0,
		XpPct = 0,
		OfflineShare = 0,
		BoxCapPct = 0,
		TeamSlots = Game.BaseTeamSlots,
		AutoOpen = false,
		AutoOpenInterval = 0,
	}
	local speed = 1
	local pct: any = m -- Pct and share kinds are plain number fields of m
	for _, node in SkillTree.List do
		if (tree[node.Id] or 0) > 0 and not (node.Toggle and off[node.Id]) then
			for _, effect in node.Effects do
				local kind = effect.Kind
				if kind == "TeamSlots" then
					m.TeamSlots += effect.Value
				elseif kind == "AutoOpen" then
					m.AutoOpen = true
					m.AutoOpenInterval = if m.AutoOpenInterval > 0
						then math.min(m.AutoOpenInterval, effect.Value)
						else effect.Value
				elseif kind == "AutoOpenSpeed" then
					speed *= effect.Value
				else
					pct[kind] += effect.Value
				end
			end
		end
	end
	for _, bonus in Account.Bonuses do
		if accountLevel >= bonus.Level then
			pct[bonus.Kind] += bonus.Value
		end
	end
	m.TeamSlots = math.clamp(m.TeamSlots, 1, Game.MaxTeamSlots)
	if m.AutoOpen then
		m.AutoOpenInterval = math.max(m.AutoOpenInterval * speed, SkillTree.MinAutoOpenInterval)
	end
	return m
end

-- A Pct sum as a multiplier that never goes below 10%.
function Mods.Mult(pct: number): number
	return math.max(1 + pct, 0.1)
end

return table.freeze(Mods)
