--!strict
-- What the Inventory grid shows, one entry per bag slot: every gear piece, each material split into slots of its max stack, one slot per box stack. Filtered by search (name + @tag), kind, tier and gear slot; gear sorted first.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Text = require(ReplicatedStorage.Shared.Text)
local Boxes = require(ReplicatedStorage.Shared.Config.Boxes)
local Materials = require(ReplicatedStorage.Shared.Config.Materials)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local ItemInfo = require(script.Parent.Parent.Core.ItemInfo)
local State = require(script.Parent.Parent.Parent.State)

export type Kind = State.BagKind
export type SortKey = State.BagSort

export type Entry = {
	Key: string, -- unique per slot
	Kind: Kind,
	Id: string, -- gear uid · material id · box stack key
	Label: string, -- text in the cell
	Line: string, -- one-line description under the grid
	Count: number, -- units in this slot (1 for gear)
	Worn: boolean,
	WornBy: string?, -- hero id (= class id)
	Tier: string?, -- gear / material tier (drawn as the cell rim)
}

export type Filter = {
	Query: string,
	Kind: Kind?, -- nil = everything
	Tier: string?,
	Slot: string?, -- SlotKind: gear of that slot only (hides materials and boxes)
	Sort: SortKey,
}

local BOX_TAGS = { "box" }

local Entries = {}

function Entries.Build(data: Types.ProfileData, filter: Filter): { Entry }
	local parsed = Tags.Parse(filter.Query)
	local out: { Entry } = {}

	if filter.Kind == nil or filter.Kind == "Gear" then
		local worn = ItemInfo.WornMap(data)
		local gear: { Types.GearItem } = {}
		for _, item in data.Gear do
			local def = Items.ById[item.BaseId]
			if
				(filter.Tier == nil or item.Tier == filter.Tier)
				and (filter.Slot == nil or (def ~= nil and def.Slot == filter.Slot))
				and Tags.Match(parsed, Tags.ForGear(item), ItemInfo.Name(item))
			then
				table.insert(gear, item)
			end
		end
		table.sort(gear, function(a, b)
			local ka, kb
			if filter.Sort == "Score" then
				ka, kb = a.GearScore, b.GearScore
			elseif filter.Sort == "Tier" then
				ka, kb = ItemInfo.TierOrder(a), ItemInfo.TierOrder(b)
			else
				ka, kb = a.Level, b.Level
			end
			if ka ~= kb then
				return ka > kb
			end
			return (tonumber(a.Uid) or 0) > (tonumber(b.Uid) or 0)
		end)
		for _, item in gear do
			local wornBy = worn[item.Uid]
			table.insert(out, {
				Key = "G:" .. item.Uid,
				Kind = "Gear",
				Id = item.Uid,
				Label = `{ItemInfo.Name(item)}\nLv {item.Level}`,
				Line = if wornBy ~= nil
					then `{ItemInfo.Line(item)}  ·  worn by {Text.Class(wornBy)}`
					else ItemInfo.Line(item),
				Count = 1,
				Worn = wornBy ~= nil,
				WornBy = wornBy,
				Tier = item.Tier :: string,
			})
		end
	end

	if (filter.Kind == nil or filter.Kind == "Box") and filter.Tier == nil and filter.Slot == nil then
		local capPct = Formula.Mods.Build(data.SkillTree, data.SkillOff, data.AccountLevel).BoxCapPct
		local keys: { string } = {}
		for key, count in data.Boxes do
			if count > 0 and Boxes.Parse(key) ~= nil and Tags.Match(parsed, BOX_TAGS, Text.Box(key)) then
				table.insert(keys, key)
			end
		end
		table.sort(keys)
		for _, key in keys do
			local box = Boxes.Parse(key)
			local count = data.Boxes[key]
			table.insert(out, {
				Key = "B:" .. key,
				Kind = "Box",
				Id = key,
				Label = `{Text.Box(key)}\nx{count}`,
				Line = `{Text.Box(key)}  ·  {count}/{if box ~= nil then Boxes.Cap(box.Kind, capPct) else count} in this stack`,
				Count = count,
				Worn = false,
			})
		end
	end

	if (filter.Kind == nil or filter.Kind == "Material") and filter.Slot == nil then
		local stackPct = Formula.Mods.Build(data.SkillTree, data.SkillOff, data.AccountLevel).StackPct
		for _, def in Materials.List do
			local total = data.Stacks[def.Id] or 0
			if
				total > 0
				and (filter.Tier == nil or def.Tier == filter.Tier)
				and Tags.Match(parsed, def.Tags, Text.Material(def.Id))
			then
				local max = Formula.Bag.MaxStack(def.Id, stackPct)
				local name = Text.Material(def.Id)
				for slot = 1, Formula.Bag.Slots(total, max) do
					local count = math.min(max, total - (slot - 1) * max)
					table.insert(out, {
						Key = `M:{def.Id}:{slot}`,
						Kind = "Material",
						Id = def.Id,
						Label = if max > 1 then `{name}\nx{count}` else name,
						Line = `{name}  ·  {total} in the bag  ·  {max} per slot`,
						Count = count,
						Worn = false,
						Tier = def.Tier,
					})
				end
			end
		end
	end
	return out
end

return Entries
