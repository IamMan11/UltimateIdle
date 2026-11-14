--!strict
-- Heroes page: list (owned / buy), selected hero's level + stats, 10 gear slots, picker to equip/unequip.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Format = require(ReplicatedStorage.Shared.Format)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Text = require(ReplicatedStorage.Shared.Text)
local Heroes = require(ReplicatedStorage.Shared.Config.Heroes)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Theme = require(script.Parent.Core.Theme)
local Widgets = require(script.Parent.Core.Widgets)
local ItemInfo = require(script.Parent.Core.ItemInfo)
local VirtualList = require(script.Parent.Core.VirtualList)
local State = require(script.Parent.Parent.State)

local e = React.createElement
local UI = Text.UI

export type Props = { data: Types.ProfileData }

local function firstOwned(data: Types.ProfileData): string?
	for _, def in Heroes.List do
		if data.Heroes[def.Id] ~= nil then
			return def.Id
		end
	end
	return nil
end

local function HeroesPage(props: Props): React.ReactNode
	local data = props.data
	local selected, setSelected = React.useState(firstOwned(data))
	local slot, setSlot = Widgets.useOptional(nil :: string?)
	local heroId = if selected ~= nil and data.Heroes[selected] ~= nil then selected else firstOwned(data)
	local hero = if heroId ~= nil then data.Heroes[heroId] else nil

	-- Left: hero list
	local list: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Vertical, 6) }
	for i, def in Heroes.List do
		local owned = data.Heroes[def.Id]
		if owned ~= nil then
			list[def.Id] = e(Widgets.Button, {
				text = `{Text.Class(def.Id)}  Lv {owned.Level}`,
				size = UDim2.new(1, 0, 0, 42),
				selected = def.Id == heroId,
				layoutOrder = i,
				onClick = function()
					setSelected(def.Id)
					setSlot(nil)
				end,
			})
		else
			list[def.Id] = e(Widgets.Button, {
				text = `{UI.Buy} {Text.Class(def.Id)} · {Format.Number(def.Price)} gold`,
				size = UDim2.new(1, 0, 0, 42),
				textSize = 15,
				disabled = data.Gold < def.Price,
				layoutOrder = i,
				onClick = function()
					State.Send.BuyHero(def.Id)
				end,
			})
		end
	end

	local right: { [string]: React.ReactNode } = {}
	if hero ~= nil and heroId ~= nil then
		local gear: { Types.GearItem } = {}
		for _, uid in hero.Equipped do
			local item = data.Gear[uid]
			if item ~= nil then
				table.insert(gear, item)
			end
		end
		local stats = Formula.Stats.Hero(hero.Class, hero.Level, gear)
		local need = Formula.Progression.HeroXpToNext(hero.Level)
		local teamRow: string? = nil
		for _, t in data.Team do
			if t.HeroId == heroId then
				teamRow = t.Row
			end
		end
		right.Head = e(Widgets.Label, {
			text = `{Text.Class(hero.Class)}  ·  Lv {hero.Level}  ·  {if teamRow ~= nil
				then "In team (" .. Text.Row(teamRow) .. ")"
				else "Not in team"}`,
			bold = true,
			textSize = 20,
		})
		right.XpBar = e(Widgets.Bar, { ratio = hero.Xp / need, position = UDim2.fromOffset(0, 28) })
		right.Stats = e(Widgets.Label, {
			text = `Power {Format.Number(stats.Power)}   HP {Format.Number(stats.MaxHp)}   Attack {Format.Number(
				stats.Atk
			)}   Defense {Format.Number(stats.Def)}   Speed {stats.Speed}   Range {stats.Range}`,
			position = UDim2.fromOffset(0, 40),
			color = Theme.Subtext,
			textSize = 16,
		})

		local slots: { [string]: React.ReactNode } = {
			Grid = e("UIGridLayout", {
				CellSize = UDim2.new(0.2, -6, 0, 52),
				CellPadding = UDim2.fromOffset(6, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for i, s in Items.GearSlots do
			local item = data.Gear[hero.Equipped[s] or ""]
			slots[s] = e(Widgets.Button, {
				text = `{Text.Slot(s)}\n{if item ~= nil then ItemInfo.Name(item) .. " Lv" .. item.Level else UI.Empty}`,
				textSize = 14,
				selected = slot == s,
				layoutOrder = i,
				onClick = function()
					setSlot(if slot == s then nil else s)
				end,
			})
		end
		right.Slots = e("Frame", {
			Size = UDim2.new(1, 0, 0, 116),
			Position = UDim2.fromOffset(0, 70),
			BackgroundTransparency = 1,
		}, slots)

		if slot ~= nil then
			local kind = Items.SlotOf[slot]
			local worn = ItemInfo.WornMap(data)
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
			right.PickerHead = e(Widgets.Label, {
				text = `{Text.Slot(slot)}: {if current ~= nil then ItemInfo.Line(current) else UI.Empty}`,
				position = UDim2.fromOffset(0, 194),
				textSize = 16,
			})
			right.Unequip = if current ~= nil
				then e(Widgets.Button, {
					text = UI.Unequip,
					size = UDim2.fromOffset(110, 30),
					position = UDim2.new(1, 0, 0, 190),
					anchor = Vector2.new(1, 0),
					onClick = function()
						State.Send.Unequip(heroId, slot)
					end,
				})
				else nil
			right.Picker = e(VirtualList, {
				count = #candidates,
				rowHeight = 44,
				size = UDim2.new(1, 0, 1, -230),
				position = UDim2.fromOffset(0, 228),
				renderRow = function(index: number): React.ReactNode
					local item = candidates[index]
					local wornBy = worn[item.Uid]
					return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.PanelAlt }, {
						Corner = Widgets.Corner(6),
						Line = e(Widgets.Label, {
							text = `{if wornBy ~= nil then UI.EquippedMark .. " " else ""}{ItemInfo.Line(item)}`,
							size = UDim2.new(1, -120, 1, 0),
							position = UDim2.fromOffset(10, 0),
							textSize = 15,
						}),
						Equip = e(Widgets.Button, {
							text = UI.Equip,
							size = UDim2.fromOffset(100, 32),
							position = UDim2.new(1, -6, 0.5, 0),
							anchor = Vector2.new(1, 0.5),
							disabled = item.Level > hero.Level,
							onClick = function()
								State.Send.Equip(heroId, item.Uid, slot)
							end,
						}),
					})
				end,
			})
		end
	end

	return e(Widgets.Window, {
		title = UI.Heroes,
		onClose = function()
			State.SetPage(nil)
		end,
		closeOnBackdrop = true,
	}, {
		List = e("Frame", { Size = UDim2.new(0, 230, 1, 0), BackgroundTransparency = 1 }, list),
		Right = e("Frame", {
			Size = UDim2.new(1, -246, 1, 0),
			Position = UDim2.fromOffset(246, 0),
			BackgroundTransparency = 1,
		}, right),
	})
end

return HeroesPage
