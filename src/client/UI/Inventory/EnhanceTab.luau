--!strict
-- Inventory window, Enhance tab: mode bar (Enhance · Insert / Remove · Upgrade). Enhance = the picked piece (+now -> +next), one slot per material the next +1 needs with have/need, gold cost, Enhance, last result · Insert / Remove = the picked piece's sockets (SocketRows) · Upgrade = UpgradePanel.

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
local socketRows = require(script.Parent.SocketRows)
local UpgradePanel = require(script.Parent.UpgradePanel)

local e = React.createElement
local UI = Text.UI

local SQUARE = 64
local MATERIAL = 52
local MODE_H = 32
local GAP = 10

export type Mode = "Enhance" | "Insert" | "Upgrade"

local MODES: { { Id: Mode, Label: string } } = {
	{ Id = "Enhance", Label = UI.Enhance },
	{ Id = "Insert", Label = UI.ModeInsert },
	{ Id = "Upgrade", Label = UI.ModeUpgrade },
}

export type Props = {
	data: Types.ProfileData,
	item: Types.GearItem?,
	mode: Mode,
	onMode: (mode: Mode) -> (),
	upgradeSlots: { string },
	upgradeFinding: boolean,
	onUpgradeFind: () -> (),
	onUpgradeSlots: (slots: { string }) -> (),
}

local function centred(height: number, order: number, children: { [string]: React.ReactNode }): React.ReactNode
	return e("Frame", { Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1, LayoutOrder = order }, children)
end

local function enhanceBody(data: Types.ProfileData, item: Types.GearItem?): React.ReactNode
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

local function EnhanceTab(props: Props): React.ReactNode
	local modes: { [string]: React.ReactNode } = {}
	for i, m in MODES do
		modes[m.Id] = e(Widgets.Button, {
			text = m.Label,
			size = UDim2.new(1 / #MODES, -6, 1, 0),
			position = UDim2.new((i - 1) / #MODES, 3, 0, 0),
			textSize = 14,
			selected = props.mode == m.Id,
			onClick = function()
				props.onMode(m.Id)
			end,
		})
	end

	local body: React.ReactNode
	if props.mode == "Upgrade" then
		body = e(UpgradePanel, {
			data = props.data,
			slots = props.upgradeSlots,
			finding = props.upgradeFinding,
			onFind = props.onUpgradeFind,
			onSlots = props.onUpgradeSlots,
		})
	elseif props.mode == "Insert" then
		local rows: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Vertical, 6) }
		local item = props.item
		if item ~= nil then
			socketRows(props.data, item, rows, 1)
		else
			rows.Hint = Parts.Hint(UI.PickItemFirst, 1)
		end
		body = Parts.Scroll(rows)
	else
		body = enhanceBody(props.data, props.item)
	end

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Modes = e("Frame", { Size = UDim2.new(1, 0, 0, MODE_H), BackgroundTransparency = 1 }, modes),
		-- Keyed by mode so each starts from the top.
		[props.mode] = e("Frame", {
			Size = UDim2.new(1, 0, 1, -(MODE_H + GAP)),
			Position = UDim2.fromOffset(0, MODE_H + GAP),
			BackgroundTransparency = 1,
		}, { Body = body }),
	})
end

return EnhanceTab
