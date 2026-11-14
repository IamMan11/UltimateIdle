--!strict
-- Per-piece extras beyond base stats: enhance multiplier, gem flat stats, artifact effects, enchant traits; team relic totals.

local Types = require(script.Parent.Parent.Types)
local Inserts = require(script.Parent.Parent.Config.Inserts)
local Enhance = require(script.Parent.Parent.Config.Enhance)
local Scaling = require(script.Parent.Scaling)

-- Summed over a hero's worn gear, then applied once in Stats.Hero.
export type Extras = {
	AtkPct: number,
	HpPct: number,
	DefPct: number,
	AtkSpeed: number,
	MoveSpeed: number,
	Lifesteal: number,
	Crit: number,
	Splash: number,
}

local Gear = {}

function Gear.PlusMult(plus: number): number
	return 1 + Enhance.StatPerPlus * plus
end

function Gear.NewExtras(): Extras
	return { AtkPct = 0, HpPct = 0, DefPct = 0, AtkSpeed = 0, MoveSpeed = 0, Lifesteal = 0, Crit = 0, Splash = 0 }
end

-- Flat stats from gems in this piece (level-scaled, before the wrong-class penalty): MaxHp, Atk, Def.
function Gear.Gems(item: Types.GearItem): (number, number, number)
	local hp, atk, def = 0, 0, 0
	local scale = Scaling.Item(item.Level)
	for _, socket in item.Sockets do
		local insert = if socket.Insert ~= nil then Inserts.ById[socket.Insert] else nil
		if insert ~= nil and insert.Kind == "Gem" and socket.Kind == "Gem" then
			if insert.Stat == "MaxHp" then
				hp += insert.Value * scale
			elseif insert.Stat == "Atk" then
				atk += insert.Value * scale
			elseif insert.Stat == "Def" then
				def += insert.Value * scale
			end
		end
	end
	return hp, atk, def
end

-- Adds this piece's enchant traits and artifact effects to `into`.
function Gear.AddExtras(into: Extras, item: Types.GearItem)
	local t: any = into -- trait ids and artifact stats are field names of Extras
	for _, enchant in item.Enchants do
		if t[enchant.Id] ~= nil then
			t[enchant.Id] += enchant.Value
		end
	end
	for _, socket in item.Sockets do
		local insert = if socket.Insert ~= nil then Inserts.ById[socket.Insert] else nil
		if insert ~= nil and insert.Kind == "Artifact" and socket.Kind == "Artifact" and t[insert.Stat] ~= nil then
			t[insert.Stat] += insert.Value
		end
	end
end

function Gear.CapExtras(x: Extras)
	local caps = Inserts.Caps
	x.Lifesteal = math.min(x.Lifesteal, caps.Lifesteal)
	x.Crit = math.min(x.Crit, caps.Crit)
	x.Splash = math.min(x.Splash, caps.Splash)
end

-- Relic totals (GoldPct / XpPct / DropPct, capped) over the given pieces.
function Gear.Relics(items: { Types.GearItem }): { [string]: number }
	local out: { [string]: number } = {}
	for _, item in items do
		for _, socket in item.Sockets do
			local insert = if socket.Insert ~= nil then Inserts.ById[socket.Insert] else nil
			if insert ~= nil and insert.Kind == "Relic" and socket.Kind == "Relic" then
				out[insert.Stat] = (out[insert.Stat] or 0) + insert.Value
			end
		end
	end
	for stat, v in out do
		local cap = Inserts.Caps[stat]
		if cap ~= nil then
			out[stat] = math.min(v, cap)
		end
	end
	return out
end

-- Pieces worn by heroes in the team (the ones whose relics count).
function Gear.TeamGear(data: Types.ProfileData): { Types.GearItem }
	local out: { Types.GearItem } = {}
	for _, slot in data.Team do
		local hero = data.Heroes[slot.HeroId]
		if hero ~= nil then
			for _, uid in hero.Equipped do
				local item = data.Gear[uid]
				if item ~= nil then
					table.insert(out, item)
				end
			end
		end
	end
	return out
end

return table.freeze(Gear)
