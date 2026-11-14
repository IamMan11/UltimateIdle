--!strict
-- Display helpers for gear: one-line summary, stat lines for a wearer (incl. traits + inserts), which hero wears what.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Format = require(ReplicatedStorage.Shared.Format)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Text = require(ReplicatedStorage.Shared.Text)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local Inserts = require(ReplicatedStorage.Shared.Config.Inserts)

local ItemInfo = {}

function ItemInfo.Name(item: Types.GearItem): string
	local name = Text.Item(item.BaseId)
	return if item.Plus > 0 then `{name} +{item.Plus}` else name
end

function ItemInfo.Line(item: Types.GearItem): string
	local def = Items.ById[item.BaseId]
	local class = if def ~= nil then Text.Class(def.Class) else "?"
	return `{ItemInfo.Name(item)}  ·  {Text.Tier(item.Tier)}  ·  Lv {item.Level}  ·  GS {item.GearScore}  ·  {class}`
end

function ItemInfo.TierOrder(item: Types.GearItem): number
	local tier = Tiers.ById[item.Tier]
	return if tier ~= nil then tier.Order else 0
end

function ItemInfo.StatLines(item: Types.GearItem, wearer: string?): { string }
	local bonus = Formula.Stats.Gear(item, wearer)
	local lines = {}
	if bonus.Atk > 0 then
		table.insert(lines, `Attack +{Format.Number(bonus.Atk)}`)
	end
	if bonus.MaxHp > 0 then
		table.insert(lines, `HP +{Format.Number(bonus.MaxHp)}`)
	end
	if bonus.Def > 0 then
		table.insert(lines, `Defense +{Format.Number(bonus.Def)}`)
	end
	if bonus.Speed > 0 then
		table.insert(lines, `Speed +{bonus.Speed}`)
	end
	for _, enchant in item.Enchants do
		table.insert(lines, Text.Trait(enchant))
	end
	for _, socket in item.Sockets do
		local insert = if socket.Insert ~= nil then Inserts.ById[socket.Insert] else nil
		if insert ~= nil and insert.Kind ~= "Gem" then
			table.insert(lines, `{Text.Material(insert.Id)}: {Text.InsertEffect(insert.Id)}`)
		end
	end
	if #item.Sockets > 0 then
		table.insert(lines, `Sockets {#item.Sockets}/{Inserts.MaxSockets}`)
	end
	local def = Items.ById[item.BaseId]
	if def ~= nil and def.Ability ~= nil then
		local active = wearer == nil or wearer == def.Class
		table.insert(
			lines,
			if active then Text.Ability(def.Ability) else `{Text.Ability(def.Ability)} (off: wrong class)`
		)
	end
	return lines
end

-- uid -> hero id wearing it.
function ItemInfo.WornMap(data: Types.ProfileData): { [string]: string }
	local map: { [string]: string } = {}
	for heroId, hero in data.Heroes do
		for _, uid in hero.Equipped do
			map[uid] = heroId
		end
	end
	return map
end

return ItemInfo
