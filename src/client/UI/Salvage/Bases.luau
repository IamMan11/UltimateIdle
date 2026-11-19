--!strict
-- Gear bases for the auto-salvage windows: Config order, the bases in the bag that are not on the list yet (one per BaseId whatever tier/score/plus/sockets), search tags.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Items = require(ReplicatedStorage.Shared.Config.Items)

local ORDER: { [string]: number } = {}
for i, def in Items.List do
	ORDER[def.Id] = i
end

local Bases = {}

-- Known ids of a set, in Config order.
function Bases.Sorted(set: { [string]: boolean }): { string }
	local out: { string } = {}
	for id, on in set do
		if on and ORDER[id] ~= nil then
			table.insert(out, id)
		end
	end
	table.sort(out, function(a, b)
		return ORDER[a] < ORDER[b]
	end)
	return out
end

local function tagsFor(def: Items.ItemDef): { string }
	local out = { "gear", Items.SlotTag[def.Slot], string.lower(def.Class) }
	if def.BoxOnly then
		table.insert(out, "box")
	end
	for _, tag in def.Tags do
		table.insert(out, tag)
	end
	return out
end

-- Bases the player has at least one piece of, minus those already listed, matching the search (name or @tag).
function Bases.Available(data: Types.ProfileData, query: string): { string }
	local parsed = Tags.Parse(query)
	local listed = data.Settings.SalvageItems
	local set: { [string]: boolean } = {}
	for _, item in data.Gear do
		local id = item.BaseId
		local def = Items.ById[id]
		if set[id] == nil and listed[id] ~= true and def ~= nil then
			set[id] = Tags.Match(parsed, tagsFor(def), Text.Item(id))
		end
	end
	return Bases.Sorted(set)
end

return Bases
