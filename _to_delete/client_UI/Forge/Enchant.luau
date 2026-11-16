--!strict
-- Forge tab: reroll the selected piece's trait lines (current traits, cost, before/after of the last roll).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Formula = require(ReplicatedStorage.Shared.Formula)
local EnchantConfig = require(ReplicatedStorage.Shared.Config.Enchant)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local ItemInfo = require(script.Parent.Parent.Core.ItemInfo)
local State = require(script.Parent.Parent.Parent.State)
local Parts = require(script.Parent.Parts)

local e = React.createElement
local UI = Text.UI

export type Props = { data: Types.ProfileData, item: Types.GearItem, wornBy: string? }

local function traitText(list: { Types.Enchant }?): string
	if list == nil or #list == 0 then
		return UI.NoTraits
	end
	local out: { string } = {}
	for _, enchant in list do
		table.insert(out, Text.Trait(enchant))
	end
	return table.concat(out, "\n")
end

local function block(title: string, list: { Types.Enchant }?, order: number): React.ReactNode
	local n = math.max(if list ~= nil then #list else 0, 1)
	return e("Frame", { Size = UDim2.new(1, 0, 0, 26 + 22 * n), BackgroundTransparency = 1, LayoutOrder = order }, {
		Title = e(Widgets.Label, { text = title, bold = true, color = Theme.Subtext }),
		Lines = e(Widgets.Label, {
			text = traitText(list),
			size = UDim2.new(1, 0, 0, 22 * n),
			position = UDim2.fromOffset(0, 24),
			wrap = true,
		}),
	})
end

local function EnchantTab(props: Props): React.ReactNode
	local data, item = props.data, props.item
	local rows: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Vertical, 8) }
	local lines = EnchantConfig.Lines[item.Tier] or 1
	rows.Head = Parts.Heading(`{ItemInfo.Name(item)}   {Text.Tier(item.Tier)}: {lines} trait line(s)`, 1)

	local last = State.Ui.LastEnchant
	if last ~= nil and last.Uid == item.Uid then
		rows.Before = block(UI.Before, last.Before, 2)
		rows.After = block(UI.After, last.After, 3)
	else
		rows.Current = block("Current", item.Enchants, 2)
	end

	local gold, dust = Formula.Forge.EnchantCost(item)
	local costLabel, ok = Parts.CostLabel(data, gold, { [EnchantConfig.Item] = dust }, 4)
	rows.Cost = costLabel
	rows.Note = e(Widgets.Label, {
		text = UI.EnchantNote,
		color = Theme.Subtext,
		textSize = 15,
		layoutOrder = 5,
	})
	rows.Go = e(Widgets.Button, {
		text = UI.Enchant,
		size = UDim2.fromOffset(220, 48),
		color = if ok then Theme.Confirm else nil,
		disabled = not ok,
		layoutOrder = 6,
		onClick = function()
			if #item.Enchants == 0 then
				State.Send.Enchant(item.Uid)
				return
			end
			State.OpenConfirm({
				Title = `Reroll traits on {ItemInfo.Name(item)}?`,
				Body = `Current traits are replaced for good:\n{traitText(item.Enchants)}`,
				OkText = UI.Enchant,
				Danger = true,
				OnConfirm = function()
					State.Send.Enchant(item.Uid)
				end,
			})
		end,
	})
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, rows)
end

return EnchantTab
