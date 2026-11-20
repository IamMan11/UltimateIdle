--!strict
-- Inventory window, Power tab (the enchant system): the picked piece, a box with its powers (before/after of the last roll, or the index of what a roll can give), Gem Power Stone + gold cost, Roll (confirm when it replaces powers), Index.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Formula = require(ReplicatedStorage.Shared.Formula)
local EnchantConfig = require(ReplicatedStorage.Shared.Config.Enchant)
local Theme = require(script.Parent.Parent.Core.Theme)
local Art = require(script.Parent.Parent.Core.Art)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local ItemInfo = require(script.Parent.Parent.Core.ItemInfo)
local State = require(script.Parent.Parent.Parent.State)
local Parts = require(script.Parent.Parts)

local e = React.createElement
local UI = Text.UI

local SQUARE = 64
local COST_H = 40
local GO_H = 40
local GAP = 8

export type Props = { data: Types.ProfileData, item: Types.GearItem? }

-- "Godspeed (Legendary)" and its effects under it.
local function traitText(list: { Types.Enchant }?): string
	if list == nil or #list == 0 then
		return UI.NoTraits
	end
	local out: { string } = {}
	for _, enchant in list do
		table.insert(out, `{Text.TraitName(enchant.Id)} ({Text.TraitRarity(enchant.Id)})`)
		for _, effect in Text.TraitEffects(enchant.Id) do
			table.insert(out, effect)
		end
	end
	return table.concat(out, "\n")
end

-- Every power a roll can land on, rarest last, with what it does. Chances are server-only.
local function indexText(): string
	local out: { string } = { UI.PowerIndex .. ":" }
	for _, def in EnchantConfig.List do
		table.insert(
			out,
			`{Text.TraitName(def.Id)} ({Text.TraitRarity(def.Id)}): {table.concat(Text.TraitEffects(def.Id), ", ")}`
		)
	end
	return table.concat(out, "\n")
end

local function PowerTab(props: Props): React.ReactNode
	local data, item = props.data, props.item
	local index, setIndex = React.useState(false)

	local body: string
	if index then
		body = indexText()
	elseif item == nil then
		body = UI.PickItem
	else
		local last = State.Ui.LastEnchant
		body = if last ~= nil and last.Uid == item.Uid
			then `{UI.Before}\n{traitText(last.Before)}\n\n{UI.After}\n{traitText(last.After)}`
			else `{ItemInfo.Name(item)}  ·  {Text.Tier(item.Tier)}\n\n{traitText(item.Enchants)}`
	end

	local gold, stones = 0, 0
	if item ~= nil then
		gold, stones = Formula.Forge.EnchantCost(item)
	end
	local have = data.Stacks[EnchantConfig.Item] or 0
	local ok = item ~= nil and have >= stones and data.Gold >= gold
	local below = COST_H * 2 + GO_H + GAP * 3
	local top = SQUARE + GAP

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Item = e(Parts.Square, {
			text = if item ~= nil then Parts.GearText(item) else "",
			size = SQUARE,
			position = UDim2.fromScale(0.5, 0),
			anchor = Vector2.new(0.5, 0),
			selected = item ~= nil,
			dim = item == nil,
		}),
		Powers = e("Frame", {
			Size = UDim2.new(0.8, 0, 1, -(top + below)),
			Position = UDim2.new(0.5, 0, 0, top),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
		}, {
			Art = Art.Back({ piece = "PaperCompactSharp", padding = 14 }),
			Padding = Widgets.Padding(14),
			Text = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = body,
				TextColor3 = if item ~= nil or index then Theme.Text else Theme.Subtext,
				FontFace = Theme.Font,
				TextSize = Theme.Body(15),
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		}),
		Stones = Parts.CostLine(
			Text.Material(EnchantConfig.Item),
			Parts.Amount(have, stones),
			item == nil or have >= stones,
			UDim2.new(0, 0, 1, -(below - GAP))
		),
		Gold = Parts.CostLine(
			UI.GoldCost,
			Parts.Amount(data.Gold, gold),
			item == nil or data.Gold >= gold,
			UDim2.new(0, 0, 1, -(GO_H + GAP + COST_H))
		),
		Roll = e(Widgets.Button, {
			text = UI.Roll,
			size = UDim2.fromOffset(170, GO_H),
			position = UDim2.new(0.5, -4, 1, 0),
			anchor = Vector2.new(1, 1),
			color = if ok then Theme.Confirm else nil,
			disabled = not ok,
			onClick = function()
				if item == nil then
					return
				end
				setIndex(false)
				if #item.Enchants == 0 then
					State.Send.Enchant(item.Uid)
					return
				end
				State.OpenConfirm({
					Title = `Roll a new power on {ItemInfo.Name(item)}?`,
					Body = `The current power is replaced for good:\n{traitText(item.Enchants)}`,
					OkText = UI.Roll,
					Danger = true,
					OnConfirm = function()
						State.Send.Enchant(item.Uid)
					end,
				})
			end,
		}),
		Index = e(Widgets.Button, {
			text = UI.Index,
			size = UDim2.fromOffset(90, GO_H),
			position = UDim2.new(0.5, 4, 1, 0),
			anchor = Vector2.new(0, 1),
			selected = index,
			onClick = function()
				setIndex(not index)
			end,
		}),
	})
end

return PowerTab
