--!strict
-- Small pieces shared by the Forge tabs: cost line (have / need), section heading.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Format = require(ReplicatedStorage.Shared.Format)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)

local e = React.createElement

local Parts = {}

-- "Cost: 1.2K gold · 4 Enhance Stone" and whether the player has all of it (+ what is short).
function Parts.Cost(data: Types.ProfileData, gold: number, items: { [string]: number }): (string, boolean, string)
	local parts: { string } = {}
	local short: { string } = {}
	if gold > 0 then
		table.insert(parts, `{Format.Number(gold)} gold`)
		if data.Gold < gold then
			table.insert(short, `{Format.Number(gold - data.Gold)} gold`)
		end
	end
	local ids: { string } = {}
	for id in items do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local need = items[id]
		local have = data.Stacks[id] or 0
		table.insert(parts, `{need} {Text.Material(id)} (have {Format.Number(have)})`)
		if have < need then
			table.insert(short, `{need - have} {Text.Material(id)}`)
		end
	end
	return `Cost: {table.concat(parts, " · ")}`, #short == 0, table.concat(short, ", ")
end

function Parts.CostLabel(
	data: Types.ProfileData,
	gold: number,
	items: { [string]: number },
	order: number
): (React.ReactNode, boolean)
	local text, ok, short = Parts.Cost(data, gold, items)
	return e(Widgets.Label, {
		text = if ok then text else `{text}\nMissing: {short}`,
		size = UDim2.new(1, 0, 0, if ok then 40 else 62),
		wrap = true,
		textSize = 16,
		color = if ok then Theme.Text else Theme.Subtext,
		layoutOrder = order,
	}),
		ok
end

function Parts.Heading(text: string, order: number): React.ReactNode
	return e(Widgets.Label, { text = text, bold = true, textSize = 18, layoutOrder = order })
end

return Parts
