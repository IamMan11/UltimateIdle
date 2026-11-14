--!strict
-- Item tags (from Config + automatic: tier/slot/class/rebirth) and the search matcher ("@rare sword" = tag rare + name has "sword").

local Types = require(script.Parent.Types)
local Items = require(script.Parent.Config.Items)
local Materials = require(script.Parent.Config.Materials)

export type Query = {
	Tags: { string },
	Words: { string },
}

local Tags = {}

function Tags.ForGear(item: Types.GearItem): { string }
	local out = { "gear", string.lower(item.Tier), `r{item.Rebirth}` }
	local def = Items.ById[item.BaseId]
	if def ~= nil then
		table.insert(out, Items.SlotTag[def.Slot])
		table.insert(out, string.lower(def.Class))
		if def.BoxOnly then
			table.insert(out, "box")
		end
		for _, tag in def.Tags do
			table.insert(out, tag)
		end
	end
	return out
end

function Tags.ForMaterial(id: string): { string }
	local out = { "material" }
	local def = Materials.ById[id]
	if def ~= nil then
		table.insert(out, string.lower(def.Tier))
		for _, tag in def.Tags do
			table.insert(out, tag)
		end
		if def.Rebirths ~= nil then
			for _, r in def.Rebirths do
				table.insert(out, `r{r}`)
			end
		end
	end
	return out
end

function Tags.Parse(query: string): Query
	local parsed: Query = { Tags = {}, Words = {} }
	for token in string.gmatch(string.lower(query), "%S+") do
		if string.sub(token, 1, 1) == "@" then
			local tag = string.sub(token, 2)
			if tag ~= "" then
				table.insert(parsed.Tags, tag)
			end
		else
			table.insert(parsed.Words, token)
		end
	end
	return parsed
end

-- True when every @tag is on the item and every plain word appears in its name (case-insensitive).
function Tags.Match(query: string | Query, tags: { string }, name: string): boolean
	local parsed: Query = if type(query) == "string" then Tags.Parse(query) else query
	for _, wanted in parsed.Tags do
		if table.find(tags, wanted) == nil then
			return false
		end
	end
	local lowered = string.lower(name)
	for _, word in parsed.Words do
		if string.find(lowered, word, 1, true) == nil then
			return false
		end
	end
	return true
end

return table.freeze(Tags)
