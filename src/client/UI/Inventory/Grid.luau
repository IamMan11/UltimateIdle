--!strict
-- Inventory window, left side: search + Auto (auto-salvage window) + Filter (modal, State.Ui.BagFilter), 8 x 7 grid of bag slots in pages (back / page / next), a line about the picked slot and its actions (gear: salvage · box: open, open all, more). Click pins a slot's card; gear: double click or drag onto a Team slot = wear it.

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
local Tip = require(script.Parent.Parent.Core.Tip)
local Equip = require(script.Parent.Parent.Core.Equip)

local e = React.createElement
local UI = Text.UI

local COLS, ROWS = 8, 7
local PAGE = COLS * ROWS
local HEAD_H = 34
local FOOT_H = 34
local INFO_H = 22
local GAP = 8
local CELL_GAP = 6

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

local function Grid(props: Props): React.ReactNode
	local data = props.data
	local query, setQuery = React.useState("")
	local filter = State.Ui.BagFilter
	local kind, tier, sort = filter.Kind, filter.Tier, filter.Sort
	local page, setPage = React.useState(1)
	-- A new filter starts from the first page.
	React.useEffect(function()
		setPage(1)
	end, { kind, tier, sort } :: { any })
	local picked, setPicked = Widgets.useOptional(nil :: string?)

	local entries = Entries.Build(
		data,
		{ Query = query, Kind = kind :: Entries.Kind?, Tier = tier, Sort = sort :: Entries.SortKey }
	)
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
		local tip = if entry.Kind == "Gear"
			then Tip.BagGear(data.Gear[entry.Id], entry.WornBy)
			elseif entry.Kind == "Box" then Tip.Box(entry.Id, entry.Count)
			else Tip.Material(entry.Id, entry.Count)
		cells[entry.Key] = e("TextButton", {
			BackgroundColor3 = if isKeep or isUse or isPicked then Theme.Hover else Theme.PanelAlt,
			AutoButtonColor = true,
			Text = entry.Label,
			TextColor3 = Theme.Text,
			FontFace = Theme.Font,
			TextSize = 11,
			TextWrapped = true,
			LayoutOrder = i,
			[React.Event.MouseEnter] = Tip.Enter(tip),
			[React.Event.MouseLeave] = Tip.Leave,
			-- Gear can be dragged onto a gear slot of the Team window.
			[React.Event.InputBegan] = function(_rbx: TextButton, input: InputObject)
				if entry.Kind == "Gear" then
					Tip.Press(input, entry.Id, entry.Label, function(target: string)
						local now = State.Data
						if now ~= nil then
							Equip.FromBag(now, entry.Id, target)
						end
					end)
				end
			end,
			-- Click = pick + pin its card · double click on gear = wear it on the Team window's hero.
			[React.Event.Activated] = function(rbx: TextButton)
				setPicked(entry.Key)
				Tip.Pin(rbx, tip)
				if entry.Kind == "Gear" then
					props.onGear(entry.Id)
					if Tip.Double(entry.Key) then
						Equip.FromBag(data, entry.Id, nil)
					end
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
		Search = e("Frame", { Size = UDim2.new(1, -184, 0, HEAD_H), BackgroundTransparency = 1 }, {
			Input = e(Widgets.TextInput, {
				text = query,
				placeholder = UI.Search,
				onChanged = function(text: string)
					setQuery(text)
					setPage(1)
				end,
			}),
		}),
		AutoSalvage = e(Widgets.Button, {
			text = UI.AutoSalvageButton,
			size = UDim2.fromOffset(84, HEAD_H),
			position = UDim2.new(1, -92, 0, 0),
			anchor = Vector2.new(1, 0),
			textSize = 15,
			-- Lit while auto-salvage is switched on.
			selected = data.Settings.AutoSalvageOn,
			onClick = function()
				State.ToggleWindow("AutoSalvage")
			end,
		}),
		FilterButton = e(Widgets.Button, {
			text = UI.Filter,
			size = UDim2.fromOffset(84, HEAD_H),
			position = UDim2.fromScale(1, 0),
			anchor = Vector2.new(1, 0),
			textSize = 15,
			-- Lit while the grid is narrowed down.
			selected = kind ~= nil or tier ~= nil,
			onClick = function()
				State.ShowBagFilter(true)
			end,
		}),
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
