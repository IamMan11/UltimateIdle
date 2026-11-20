--!strict
-- Filter modal over the Inventory window: a FloatWindow (same frame and zoom as Inventory) over an invisible click-blocking backdrop. Type / Slot (gear worn in one slot kind) / Tier / Sort by as rows of chips (applied at once), Reset + Done. Opened by the Filter button (State.ShowBagFilter); Esc, Done, Close or a click outside closes it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Text = require(ReplicatedStorage.Shared.Text)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local FloatWindow = require(script.Parent.Core.FloatWindow)
local Theme = require(script.Parent.Core.Theme)
local Widgets = require(script.Parent.Core.Widgets)
local State = require(script.Parent.Parent.State)

local e = React.createElement
local UI = Text.UI

-- Design units before the Inventory zoom (Config.Game.WindowZoom), like the window it sits on.
local DEFAULT_SIZE = Vector2.new(760, 470)
local MIN_SIZE = Vector2.new(560, 420)
local HEAD_H = 22
local CHIP_H = 34
local CHIP_GAP = 8
local SECTION_GAP = 14
local FOOT_H = 34

type Chip = { Key: string, Label: string, On: boolean, Pick: () -> () }

local KINDS: { { Id: State.BagKind, Label: string } } = {
	{ Id = "Gear", Label = UI.Gear },
	{ Id = "Material", Label = UI.Materials },
	{ Id = "Box", Label = UI.Boxes },
}
local SORTS: { { Id: State.BagSort, Label: string } } = {
	{ Id = "Level", Label = UI.SortLevel },
	{ Id = "Score", Label = UI.SortScore },
	{ Id = "Tier", Label = UI.SortTier },
}

-- Slot kinds in the order of the gear slots (Bracelet1/2 and Ring1/2 count once).
local SLOT_KINDS: { string } = {}
for _, slot in Items.GearSlots do
	local kind = Items.SlotOf[slot]
	if kind ~= nil and table.find(SLOT_KINDS, kind) == nil then
		table.insert(SLOT_KINDS, kind)
	end
end
-- GearSlot to read a slot kind's name from (Text.Slot is keyed by gear slot).
local function slotLabel(kind: string): string
	return Text.Slot(Items.Slots[kind][1])
end

local function close()
	State.ShowBagFilter(false)
end

local function section(title: string, hint: string?, chips: { Chip }, order: number): React.ReactNode
	local n = #chips
	local row: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Horizontal, CHIP_GAP) }
	for i, chip in chips do
		row[chip.Key] = e(Widgets.Button, {
			text = chip.Label,
			size = UDim2.new(1 / n, -CHIP_GAP * (n - 1) / n, 1, 0),
			textSize = if n > 6 then 12 else 15,
			selected = chip.On,
			layoutOrder = i,
			onClick = chip.Pick,
		})
	end
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, HEAD_H + 6 + CHIP_H),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, {
		Title = e(Widgets.Label, { text = title, bold = true, textSize = 16, size = UDim2.new(0.5, 0, 0, HEAD_H) }),
		Hint = if hint ~= nil
			then e(Widgets.Label, {
				text = hint,
				color = Theme.Subtext,
				textSize = 13,
				align = Enum.TextXAlignment.Right,
				size = UDim2.new(0.5, 0, 0, HEAD_H),
				position = UDim2.fromScale(0.5, 0),
			})
			else nil,
		Chips = e("Frame", {
			Size = UDim2.new(1, 0, 0, CHIP_H),
			Position = UDim2.fromOffset(0, HEAD_H + 6),
			BackgroundTransparency = 1,
		}, row),
	})
end

local function divider(order: number): React.ReactNode
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Stroke,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		LayoutOrder = order,
	})
end

local function BagFilter(): React.ReactNode
	local filter = State.Ui.BagFilter
	-- A gear slot only goes with gear: another type clears it.
	local function set(kind: State.BagKind?, tier: string?, sort: State.BagSort)
		local slot = if kind == nil or kind == "Gear" then filter.Slot else nil
		State.SetBagFilter({ Kind = kind, Tier = tier, Slot = slot, Sort = sort })
	end

	local slots: { Chip } = {
		{
			Key = "All",
			Label = UI.All,
			On = filter.Slot == nil,
			Pick = function()
				State.SetBagFilter({ Kind = filter.Kind, Tier = filter.Tier, Sort = filter.Sort })
			end,
		},
	}
	for _, slotKind in SLOT_KINDS do
		table.insert(slots, {
			Key = slotKind,
			Label = slotLabel(slotKind),
			On = filter.Slot == slotKind,
			Pick = function()
				State.SetBagFilter({ Kind = "Gear", Tier = filter.Tier, Slot = slotKind, Sort = filter.Sort })
			end,
		})
	end

	local kinds: { Chip } = {
		{
			Key = "All",
			Label = UI.All,
			On = filter.Kind == nil,
			Pick = function()
				set(nil, filter.Tier, filter.Sort)
			end,
		},
	}
	for _, k in KINDS do
		local key: string = k.Id
		table.insert(kinds, {
			Key = key,
			Label = k.Label,
			On = filter.Kind == k.Id,
			Pick = function()
				set(k.Id, filter.Tier, filter.Sort)
			end,
		})
	end

	local tiers: { Chip } = {
		{
			Key = "All",
			Label = UI.All,
			On = filter.Tier == nil,
			Pick = function()
				set(filter.Kind, nil, filter.Sort)
			end,
		},
	}
	for _, t in Tiers.List do
		table.insert(tiers, {
			Key = t.Id,
			Label = Text.Tier(t.Id),
			On = filter.Tier == t.Id,
			Pick = function()
				set(filter.Kind, t.Id, filter.Sort)
			end,
		})
	end

	local sorts: { Chip } = {}
	for _, s in SORTS do
		local key: string = s.Id
		table.insert(sorts, {
			Key = key,
			Label = s.Label,
			On = filter.Sort == s.Id,
			Pick = function()
				set(filter.Kind, filter.Tier, s.Id)
			end,
		})
	end

	local isDefault = filter.Kind == nil and filter.Tier == nil and filter.Slot == nil and filter.Sort == "Level"
	return e(FloatWindow, {
		id = "BagFilter",
		title = UI.FilterTitle,
		onClose = close,
		defaultSize = DEFAULT_SIZE,
		minSize = MIN_SIZE,
		zoom = Game.WindowZoom,
		modal = true,
	}, {
		Sections = e("Frame", {
			Size = UDim2.new(1, 0, 1, -(FOOT_H + SECTION_GAP)),
			BackgroundTransparency = 1,
		}, {
			Layout = Widgets.List(Enum.FillDirection.Vertical, SECTION_GAP),
			Type = section(UI.FilterType, nil, kinds, 1),
			Line1 = divider(2),
			Slot = section(UI.FilterSlot, UI.FilterSlotHint, slots, 3),
			Line2 = divider(4),
			Tier = section(UI.FilterTier, UI.FilterTierHint, tiers, 5),
			Line3 = divider(6),
			Sort = section(UI.FilterSort, UI.FilterSortHint, sorts, 7),
		}),
		Reset = e(Widgets.Button, {
			text = UI.Reset,
			size = UDim2.fromOffset(100, FOOT_H),
			position = UDim2.fromScale(0, 1),
			anchor = Vector2.new(0, 1),
			textSize = 15,
			disabled = isDefault,
			onClick = function()
				State.SetBagFilter({ Sort = "Level" })
			end,
		}),
		Done = e(Widgets.Button, {
			text = UI.Done,
			size = UDim2.fromOffset(110, FOOT_H),
			position = UDim2.fromScale(1, 1),
			anchor = Vector2.new(1, 1),
			textSize = 15,
			color = Theme.Confirm,
			onClick = close,
		}),
	})
end

return BagFilter
