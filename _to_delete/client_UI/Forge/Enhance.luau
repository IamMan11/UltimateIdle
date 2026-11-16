--!strict
-- Forge tab: enhance the selected piece by +1 (stats now vs next, cost, last result).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Formula = require(ReplicatedStorage.Shared.Formula)
local EnhanceConfig = require(ReplicatedStorage.Shared.Config.Enhance)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local ItemInfo = require(script.Parent.Parent.Core.ItemInfo)
local State = require(script.Parent.Parent.Parent.State)
local Parts = require(script.Parent.Parts)

local e = React.createElement
local UI = Text.UI

export type Props = { data: Types.ProfileData, item: Types.GearItem, wornBy: string? }

local function column(title: string, lines: { string }, x: number): React.ReactNode
	return e("Frame", {
		Size = UDim2.new(0.5, -6, 0, 30 + 22 * #lines),
		Position = UDim2.new(x, if x > 0 then 6 else 0, 0, 0),
		BackgroundTransparency = 1,
	}, {
		Title = e(Widgets.Label, { text = title, bold = true, color = Theme.Subtext }),
		Lines = e(Widgets.Label, {
			text = table.concat(lines, "\n"),
			size = UDim2.new(1, 0, 0, 22 * #lines),
			position = UDim2.fromOffset(0, 26),
			wrap = true,
			textSize = 16,
		}),
	})
end

local function EnhanceTab(props: Props): React.ReactNode
	local data, item = props.data, props.item
	local rows: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Vertical, 8) }
	rows.Head = Parts.Heading(`{ItemInfo.Name(item)}   +{item.Plus} / +{EnhanceConfig.MaxPlus}`, 1)
	if item.Plus >= EnhanceConfig.MaxPlus then
		rows.Max = e(Widgets.Label, { text = UI.EnhanceMax, layoutOrder = 2 })
		return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, rows)
	end

	local preview = table.clone(item)
	preview.Plus += 1
	local nowLines = ItemInfo.StatLines(item, props.wornBy)
	local nextLines = ItemInfo.StatLines(preview, props.wornBy)
	local height = 30 + 22 * math.max(#nowLines, #nextLines)
	rows.Compare = e("Frame", { Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1, LayoutOrder = 2 }, {
		Now = column(`Now +{item.Plus}`, nowLines, 0),
		Next = column(`Next +{preview.Plus}`, nextLines, 0.5),
	})

	local gold, items = Formula.Forge.EnhanceCost(item)
	local costLabel, ok = Parts.CostLabel(data, gold, items, 3)
	rows.Cost = costLabel
	rows.Note = e(Widgets.Label, {
		text = UI.EnhanceNote,
		color = Theme.Subtext,
		textSize = 15,
		size = UDim2.new(1, 0, 0, 40),
		wrap = true,
		layoutOrder = 4,
	})
	local last = State.Ui.LastEnhance
	if last ~= nil and last.Uid == item.Uid and last.Plus ~= nil then
		rows.Last = e(Widgets.Label, {
			text = if last.Ok
				then `Last try: success (+{last.Plus} -> +{last.Plus + 1})`
				else `Last try: failed (stayed +{last.Plus})`,
			bold = true,
			layoutOrder = 5,
		})
	end
	rows.Go = e(Widgets.Button, {
		text = `{UI.Enhance} to +{preview.Plus}`,
		size = UDim2.fromOffset(220, 48),
		color = if ok then Theme.Confirm else nil,
		disabled = not ok,
		layoutOrder = 6,
		onClick = function()
			State.Send.Enhance(item.Uid)
		end,
	})
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, rows)
end

return EnhanceTab
