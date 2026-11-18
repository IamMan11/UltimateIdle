--!strict
-- Inventory window, left side: search + filter, 8 x 7 grid of bag slots in pages (back / page / next), a line about the picked slot and its actions (gear: salvage · box: open, open all, more).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Format = require(ReplicatedStorage.Shared.Format)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Text = require(ReplicatedStorage.Shared.Text)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local ItemInfo = require(script.Parent.Parent.Core.ItemInfo)
local State = require(script.Parent.Parent.Parent.State)
local Entries = require(script.Parent.Entries)

local e = React.createElement
local UI = Text.UI

local COLS, ROWS = 8, 7
local PAGE = COLS * ROWS
local HEAD_H = 34
local FOOT_H = 34
local INFO_H = 22
local GAP = 8
local CELL_GAP = 6

local KINDS: { { Id: Entries.Kind, Label: string } } = {
	{ Id = "Gear", Label = UI.Gear },
	{ Id = "Material", Label = UI.Materials },
	{ Id = "Box", Label = UI.Boxes },
}
local SORTS: { Entries.SortKey } = { "Level", "Score", "Tier" }

export type Props = {
	data: Types.ProfileData,
	keepUid: string?, -- gear the right side works on
	useUid: string?, -- gear picked to be used up (Sockets tab)
	onGear: (uid: string) -> (),
}

local function confirmSalvage(item: Types.GearItem)
	local tier = Tiers.ById[item.Tier]
	local gold = if tier ~= nil then math.floor(tier.SalvageGold * Formula.Scaling.Item(item.Level)) else 0
	local stones = if tier ~= nil then tier.SalvageStones else 0
	State.OpenConfirm({
		Title = `Salvage {ItemInfo.Name(item)} [{Text.Tier(item.Tier)}]?`,
		Body = `You get {Format.Number(gold)} gold + {stones} {Text.Material("EnhanceStone")}. The item is gone for good.`,
		OkText = UI.Salvage,
		Danger = true,
		OnConfirm = function()
			State.Send.Salvage({ item.Uid })
		end,
	})
end

local function row(children: { [string]: React.ReactNode }, order: number): React.ReactNode
	children.Layout = Widgets.List(Enum.FillDirection.Horizontal, 6)
	return e("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = order }, children)
end

local function Grid(props: Props): React.ReactNode
	local data = props.data
	local query, setQuery = React.useState("")
	local kind, setKind = Widgets.useOptional(nil :: Entries.Kind?)
	local tier, setTier = Widgets.useOptional(nil :: string?)
	local sort, setSort = React.useState("Level" :: Entries.SortKey)
	local filterOpen, setFilterOpen = React.useState(false)
	local page, setPage = React.useState(1)
	local picked, setPicked = Widgets.useOptional(nil :: string?)

	local entries = Entries.Build(data, { Query = query, Kind = kind, Tier = tier, Sort = sort })
	local pages = math.max(math.ceil(#entries / PAGE), 1)
	local shown = math.clamp(page, 1, pages)

	local chosen: Entries.Entry? = nil
	local cells: { [string]: React.ReactNode } = {
		Layout = e("UIGridLayout", {
			CellSize = UDim2.new(1 / COLS, -CELL_GAP, 1 / ROWS, -CELL_GAP),
			CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for i = 1, PAGE do
		local entry = entries[(shown - 1) * PAGE + i]
		if entry == nil then
			-- Empty slots keep the grid's shape on a short page.
			cells[`Empty{i}`] = e("Frame", {
				BackgroundColor3 = Theme.Bg,
				BackgroundTransparency = 0.4,
				LayoutOrder = i,
			}, { Corner = Widgets.Corner(6) })
			continue
		end
		local isKeep = entry.Kind == "Gear" and entry.Id == props.keepUid
		local isUse = entry.Kind == "Gear" and entry.Id == props.useUid
		local isPicked = picked == entry.Key
		if isPicked then
			chosen = entry
		end
		cells[entry.Key] = e("TextButton", {
			BackgroundColor3 = if isKeep or isUse or isPicked then Theme.Hover else Theme.PanelAlt,
			AutoButtonColor = true,
			Text = entry.Label,
			TextColor3 = Theme.Text,
			FontFace = Theme.Font,
			TextSize = 11,
			TextWrapped = true,
			LayoutOrder = i,
			[React.Event.Activated] = function()
				setPicked(entry.Key)
				if entry.Kind == "Gear" then
					props.onGear(entry.Id)
				end
			end,
		}, {
			Corner = Widgets.Corner(6),
			Padding = Widgets.Padding(3),
			Stroke = if isKeep or isUse
				then Widgets.Stroke(Theme.Accent, 2, 0)
				elseif isPicked then Widgets.Stroke(Theme.Accent, 1, 0)
				else nil,
			-- Corner mark: worn by a hero, or its part in the socket merge.
			Mark = if entry.Worn
					or isUse
					or isKeep
				then e(Widgets.Label, {
					text = if isUse then UI.Use elseif isKeep then UI.Keep else UI.EquippedMark,
					bold = true,
					textSize = 10,
					color = Theme.Accent,
					size = UDim2.new(1, 0, 0, 10),
					position = UDim2.fromOffset(0, -2),
				})
				else nil,
		})
	end

	-- Filter panel (over the grid while open)
	local filter: React.ReactNode = nil
	if filterOpen then
		local kinds: { [string]: React.ReactNode } = {
			All = e(Widgets.Button, {
				text = UI.All,
				size = UDim2.fromOffset(70, 30),
				textSize = 14,
				selected = kind == nil,
				layoutOrder = 0,
				onClick = function()
					setKind(nil)
					setPage(1)
				end,
			}),
		}
		for i, k in KINDS do
			kinds[k.Id] = e(Widgets.Button, {
				text = k.Label,
				size = UDim2.fromOffset(96, 30),
				textSize = 14,
				selected = kind == k.Id,
				layoutOrder = i,
				onClick = function()
					setKind(k.Id)
					setPage(1)
				end,
			})
		end
		local tiers: { [string]: React.ReactNode } = {}
		for i, t in Tiers.List do
			tiers[t.Id] = e(Widgets.Button, {
				text = Text.Tier(t.Id),
				size = UDim2.fromOffset(96, 30),
				textSize = 14,
				selected = tier == t.Id,
				layoutOrder = i,
				onClick = function()
					setTier(if tier == t.Id then nil else t.Id)
					setPage(1)
				end,
			})
		end
		local sorts: { [string]: React.ReactNode } = {}
		for i, key in SORTS do
			sorts[key] = e(Widgets.Button, {
				text = key,
				size = UDim2.fromOffset(70, 30),
				textSize = 14,
				selected = sort == key,
				layoutOrder = i,
				onClick = function()
					setSort(key :: Entries.SortKey)
				end,
			})
		end
		filter = e("TextButton", {
			Size = UDim2.new(1, 0, 0, 30 * 3 + 6 * 2 + 20),
			Position = UDim2.fromOffset(0, HEAD_H + 4),
			BackgroundColor3 = Theme.Bg,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 5,
		}, {
			Corner = Widgets.Corner(8),
			Stroke = Widgets.Stroke(),
			Padding = Widgets.Padding(10),
			Layout = Widgets.List(Enum.FillDirection.Vertical, 6),
			Kinds = row(kinds, 1),
			Tiers = row(tiers, 2),
			Sorts = row(sorts, 3),
		})
	end

	-- Actions for the picked slot
	local actions: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Horizontal, 6) }
	if chosen ~= nil and chosen.Kind == "Gear" then
		local item = data.Gear[chosen.Id]
		actions.Salvage = e(Widgets.Button, {
			text = UI.Salvage,
			size = UDim2.fromOffset(100, FOOT_H),
			textSize = 15,
			color = Theme.Danger,
			disabled = item == nil or chosen.Worn,
			onClick = function()
				if item ~= nil then
					confirmSalvage(item)
				end
			end,
		})
	elseif chosen ~= nil and chosen.Kind == "Box" then
		local key, count = chosen.Id, chosen.Count
		actions.Open = e(Widgets.Button, {
			text = UI.Open,
			size = UDim2.fromOffset(72, FOOT_H),
			textSize = 15,
			layoutOrder = 1,
			onClick = function()
				State.Send.OpenBox(key, 1)
			end,
		})
		actions.OpenAll = e(Widgets.Button, {
			text = UI.OpenAll,
			size = UDim2.fromOffset(92, FOOT_H),
			textSize = 15,
			layoutOrder = 2,
			onClick = function()
				State.Send.OpenBox(key, count)
			end,
		})
		-- Open N, convert to class boxes: the full Boxes page.
		actions.More = e(Widgets.Button, {
			text = UI.More,
			size = UDim2.fromOffset(72, FOOT_H),
			textSize = 15,
			layoutOrder = 3,
			onClick = function()
				State.OpenWindow("Boxes")
			end,
		})
	end

	local below = INFO_H + FOOT_H + GAP * 2
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Search = e("Frame", { Size = UDim2.new(1, -92, 0, HEAD_H), BackgroundTransparency = 1 }, {
			Input = e(Widgets.TextInput, {
				text = query,
				placeholder = UI.Search,
				onChanged = function(text: string)
					setQuery(text)
					setPage(1)
				end,
			}),
		}),
		FilterButton = e(Widgets.Button, {
			text = UI.Filter,
			size = UDim2.fromOffset(84, HEAD_H),
			position = UDim2.fromScale(1, 0),
			anchor = Vector2.new(1, 0),
			textSize = 15,
			selected = filterOpen or kind ~= nil or tier ~= nil,
			onClick = function()
				setFilterOpen(not filterOpen)
			end,
		}),
		Filter = filter,
		Cells = e("Frame", {
			Size = UDim2.new(1, CELL_GAP, 1, -(HEAD_H + GAP + below)),
			Position = UDim2.fromOffset(0, HEAD_H + GAP),
			BackgroundTransparency = 1,
		}, cells),
		Info = e(Widgets.Label, {
			text = if chosen ~= nil then chosen.Line else "",
			color = Theme.Subtext,
			textSize = 13,
			position = UDim2.new(0, 0, 1, -(FOOT_H + GAP + INFO_H)),
			size = UDim2.new(1, 0, 0, INFO_H),
		}),
		Actions = e("Frame", {
			Size = UDim2.new(1, -220, 0, FOOT_H),
			Position = UDim2.fromScale(0, 1),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,
		}, actions),
		Pager = e("Frame", {
			Size = UDim2.fromOffset(212, FOOT_H),
			Position = UDim2.fromScale(1, 1),
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
		}, {
			Back = e(Widgets.Button, {
				text = UI.Back,
				size = UDim2.fromOffset(68, FOOT_H),
				textSize = 15,
				disabled = shown <= 1,
				onClick = function()
					setPage(shown - 1)
				end,
			}),
			Page = e(Widgets.Label, {
				text = `{shown}/{pages}`,
				align = Enum.TextXAlignment.Center,
				textSize = 15,
				position = UDim2.fromOffset(68, 0),
				size = UDim2.fromOffset(76, FOOT_H),
			}),
			Next = e(Widgets.Button, {
				text = UI.Next,
				size = UDim2.fromOffset(68, FOOT_H),
				position = UDim2.fromScale(1, 0),
				anchor = Vector2.new(1, 0),
				textSize = 15,
				disabled = shown >= pages,
				onClick = function()
					setPage(shown + 1)
				end,
			}),
		}),
	})
end

return Grid
