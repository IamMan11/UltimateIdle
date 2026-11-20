--!strict
-- Team window, middle column while a gear slot is open: what the slot holds, Unequip, and the bag items that fit it (best first) with Equip.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Text = require(ReplicatedStorage.Shared.Text)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Rebirth = require(ReplicatedStorage.Shared.Config.Rebirth)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local ItemInfo = require(script.Parent.Parent.Core.ItemInfo)
local Tip = require(script.Parent.Parent.Core.Tip)
local VirtualList = require(script.Parent.Parent.Core.VirtualList)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement
local UI = Text.UI

local HEAD_H = 66

export type Props = {
	data: Types.ProfileData,
	heroId: string,
	hero: Types.HeroState,
	slot: string,
	onClose: () -> (),
}

local function GearPicker(props: Props): React.ReactNode
	local data, heroId, hero, slot = props.data, props.heroId, props.hero, props.slot
	local kind = Items.SlotOf[slot]
	local worn = ItemInfo.WornMap(data)
	local wearCap = Rebirth.WearCap(data.Rebirth.Count, hero.Advancement)
	local candidates: { Types.GearItem } = {}
	for uid, item in data.Gear do
		local def = Items.ById[item.BaseId]
		if def ~= nil and def.Slot == kind and hero.Equipped[slot] ~= uid then
			table.insert(candidates, item)
		end
	end
	table.sort(candidates, function(a, b)
		local pa, pb = Formula.Scaling.Item(a.Level) * a.GearScore, Formula.Scaling.Item(b.Level) * b.GearScore
		if pa ~= pb then
			return pa > pb
		end
		return a.Uid < b.Uid
	end)
	local current = data.Gear[hero.Equipped[slot] or ""]

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Back = e(Widgets.Button, {
			text = UI.Back,
			size = UDim2.fromOffset(84, 30),
			onClick = props.onClose,
		}),
		Unequip = e(Widgets.Button, {
			text = UI.Unequip,
			size = UDim2.fromOffset(110, 30),
			position = UDim2.fromScale(1, 0),
			anchor = Vector2.new(1, 0),
			disabled = current == nil,
			onClick = function()
				State.Send.Unequip(heroId, slot)
			end,
		}),
		Head = e(Widgets.Label, {
			text = `{Text.Slot(slot)}: {if current ~= nil then ItemInfo.Line(current) else UI.Empty}`,
			position = UDim2.fromOffset(0, 36),
			textSize = 15,
		}),
		List = e(VirtualList, {
			count = #candidates,
			rowHeight = 44,
			size = UDim2.new(1, 0, 1, -HEAD_H),
			position = UDim2.fromOffset(0, HEAD_H),
			renderRow = function(index: number): React.ReactNode
				local item = candidates[index]
				local wornBy = worn[item.Uid]
				return e("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Theme.PanelAlt,
					[React.Event.MouseEnter] = Tip.Enter(Tip.Gear(item, hero.Class)),
					[React.Event.MouseLeave] = Tip.Leave,
				}, {
					Corner = Widgets.Corner(6),
					Line = e(Widgets.Label, {
						text = `{if wornBy ~= nil then UI.EquippedMark .. " " else ""}{ItemInfo.Line(item)}`,
						size = UDim2.new(1, -110, 1, 0),
						position = UDim2.fromOffset(10, 0),
						textSize = 14,
					}),
					Equip = e(Widgets.Button, {
						text = UI.Equip,
						size = UDim2.fromOffset(88, 32),
						position = UDim2.new(1, -6, 0.5, 0),
						anchor = Vector2.new(1, 0.5),
						disabled = item.Level > hero.Level or item.Level > wearCap,
						onClick = function()
							State.Send.Equip(heroId, item.Uid, slot)
						end,
					}),
				})
			end,
		}),
	})
end

return GearPicker
