--!strict
-- Team-level combat bonuses: preferred row, class pairs, account modifiers. Pure; server sim input and team UI share it.

local Types = require(script.Parent.Parent.Types)
local Heroes = require(script.Parent.Parent.Config.Heroes)
local Formation = require(script.Parent.Parent.Config.Formation)
local Mods = require(script.Parent.Mods)
local Stats = require(script.Parent.Stats)

export type Member = {
	Class: string,
	Row: string,
}

local Team = {}

-- Formation bonus (fraction) for members[index]: preferred row + every pair it completes.
function Team.FormationBonus(members: { Member }, index: number): number
	local me = members[index]
	local def = Heroes.ById[me.Class]
	local bonus = if def ~= nil and def.PreferredRow == me.Row then Formation.PreferredRowBonus else 0
	for _, pair in Formation.Pairs do
		local other = if pair.A == me.Class then pair.B elseif pair.B == me.Class then pair.A else nil
		if other ~= nil then
			for j, m in members do
				if j ~= index and m.Class == other then
					bonus += pair.Bonus
					break
				end
			end
		end
	end
	return bonus
end

-- New stats table: base hero stats with formation bonus and account modifiers applied.
function Team.Apply(base: Types.HeroStats, formation: number, mods: Mods.Mods): Types.HeroStats
	local atk = Mods.Mult(formation + mods.AtkPct)
	local hp = Mods.Mult(formation + mods.HpPct)
	local def = Mods.Mult(formation + mods.DefPct)
	local s: Types.HeroStats = {
		MaxHp = base.MaxHp * hp,
		Atk = base.Atk * atk,
		Def = base.Def * def,
		AtkInterval = base.AtkInterval,
		Range = base.Range,
		Speed = base.Speed,
		Splash = base.Splash,
		Heal = base.Heal * Mods.Mult(formation + mods.AtkPct),
		Lifesteal = base.Lifesteal,
		Crit = base.Crit,
		Power = 0,
	}
	s.Power = Stats.Power(s)
	return s
end

-- Team speed as the sim uses it: fastest hero in the middle row, else the average of everyone.
function Team.Speed(members: { { Row: string, Speed: number } }, fallback: number): number
	local fastest, sum = 0, 0
	for _, m in members do
		sum += m.Speed
		if m.Row == "Middle" then
			fastest = math.max(fastest, m.Speed)
		end
	end
	if fastest > 0 then
		return fastest
	end
	return if #members > 0 then sum / #members else fallback
end

return table.freeze(Team)
