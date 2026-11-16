--!strict
-- Inventory window, Enhance tab: the picked piece (+now -> +next), one slot per material the next +1 needs with have/need, gold cost, Enhance, last result.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Formula = require(ReplicatedStorage.Shared.Formula)
local EnhanceConfig = require(ReplicatedStorage.Shared.Config.Enhance)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local State = require(script.Parent.Parent.Parent.State)
local Parts = require(script.Parent.Parts)

local e = React.createElement
local UI = Text.UI

local SQUARE = 64
local MATERIAL = 52

export type Props = { data: Types.ProfileData, item: Types.GearItem? }

local function centred(height: number, order: number, children: { [string]: React.ReactNode }): React.ReactNode
	return e("Frame", { Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1, LayoutOrder = order }, children)
end

local function EnhanceTab(props: Props): React.ReactNode
	local data, item = props.data, props.item
	local maxed = item ~= nil and item.Plus >= EnhanceConfig.MaxPlus
	local rows: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Vertical, 8) }
	rows.Item = centred(SQUARE, 1, {
		Square = e(Parts.Square, {
			text = if item ~= nil then Parts.GearText(item) else "",
			size = SQUARE,
			position = UDim2.fromScale(0.5, 0),
			anchor = Vector2.new(0.5, 0),
			selected = item ~= nil,
			dim = item == nil,
		}),
	})
	rows.Step = e(Widgets.Label, {
		text = if item == nil
			then UI.PickItem
			elseif maxed then `+{item.Plus}  ·  {UI.EnhanceMax}`
			else `+{item.Plus}  ->  +{item.Plus + 1}   (max +{EnhanceConfig.MaxPlus})`,
		bold = item ~= nil,
		color = if item ~= nil then Theme.Text else Theme.Subtext,
		align = Enum.TextXAlignment.Center,
		layoutOrder = 2,
	})
	if item == nil or maxed then
		return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, rows)
	end

	local gold, items = Formula.Forge.EnhanceCost(item)
	local ids: { string } = {}
	for id in items do
		table.insert(ids, id)
	end
	table.sort(ids)
	local materials: { [string]: React.ReactNode } = {
		Layout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(MATERIAL + 12, MATERIAL + 22),
			CellPadding = UDim2.fromOffset(6, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for i, id in ids do
		local have, need = data.Stacks[id] or 0, items[id]
		materials[id] = e("Frame", { BackgroundTransparency = 1, LayoutOrder = i }, {
			Square = e(Parts.Square, {
				text = Text.Material(id),
				size = MATERIAL,
				position = UDim2.fromScale(0.5, 0),
				anchor = Vector2.new(0.5, 0),
				dim = have < need,
			}),
			Amount = e(Widgets.Label, {
				text = Parts.Amount(have, need),
				bold = true,
				textSize = 13,
				color = if have >= need then Theme.Text else Theme.Subtext,
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(0, MATERIAL + 2),
				size = UDim2.new(1, 0, 0, 18),
			}),
		})
	end
	local materialRows = math.max(math.ceil(#ids / 7), 1)
	rows.Materials = centred((MATERIAL + 28) * materialRows, 3, materials)
	rows.Cost = centred(40, 4, {
		Line = Parts.CostLine(UI.GoldCost, Parts.Amount(data.Gold, gold), data.Gold >= gold, UDim2.fromScale(0, 0)),
	})
	local ok = Parts.CanPay(data, gold, items)
	rows.Go = centred(40, 5, {
		Enhance = e(Widgets.Button, {
			text = UI.Enhance,
			size = UDim2.fromOffset(180, 40),
			position = UDim2.fromScale(0.5, 0),
			anchor = Vector2.new(0.5, 0),
			color = if ok then Theme.Confirm else nil,
			disabled = not ok,
			onClick = function()
				State.Send.Enhance(item.Uid)
			end,
		}),
	})
	local last = State.Ui.LastEnhance
	rows.Last = e(Widgets.Label, {
		text = if last ~= nil
				and last.Uid == item.Uid
				and last.Plus ~= nil
			then (if last.Ok
				then `Last try: success (+{last.Plus} -> +{last.Plus + 1})`
				else `Last try: failed (stayed +{last.Plus})`)
			else UI.EnhanceNote,
		color = Theme.Subtext,
		textSize = 13,
		wrap = true,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 34),
		layoutOrder = 6,
	})
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, rows)
end

return EnhanceTab
