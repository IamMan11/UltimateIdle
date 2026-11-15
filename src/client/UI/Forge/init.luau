--!strict
-- Forge page: searchable list of every piece (worn included) + tabs for the selected one: Enhance, Sockets, Enchant.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.Core.Theme)
local Widgets = require(script.Parent.Core.Widgets)
local ItemInfo = require(script.Parent.Core.ItemInfo)
local VirtualList = require(script.Parent.Core.VirtualList)
local State = require(script.Parent.Parent.State)
local EnhanceTab = require(script.Enhance)
local SocketsTab = require(script.Sockets)
local EnchantTab = require(script.Enchant)

local e = React.createElement
local UI = Text.UI

type Tab = "Enhance" | "Sockets" | "Enchant"

export type Props = { data: Types.ProfileData }

local TABS: { { Id: Tab, Label: string } } = {
	{ Id = "Enhance", Label = UI.Enhance },
	{ Id = "Sockets", Label = UI.Sockets },
	{ Id = "Enchant", Label = UI.Enchant },
}

local function Forge(props: Props): React.ReactNode
	local data = props.data
	local query, setQuery = React.useState("")
	local tab, setTab = React.useState("Enhance" :: Tab)

	local worn = ItemInfo.WornMap(data)
	local parsed = Tags.Parse(query)
	local items: { Types.GearItem } = {}
	for _, item in data.Gear do
		if Tags.Match(parsed, Tags.ForGear(item), ItemInfo.Name(item)) then
			table.insert(items, item)
		end
	end
	table.sort(items, function(a, b)
		local wa, wb = worn[a.Uid] ~= nil, worn[b.Uid] ~= nil
		if wa ~= wb then
			return wa
		end
		if a.Level ~= b.Level then
			return a.Level > b.Level
		end
		return (tonumber(a.Uid) or 0) > (tonumber(b.Uid) or 0)
	end)

	local uid = State.Ui.ForgeUid
	local item = if uid ~= nil then data.Gear[uid] else nil

	local tabButtons: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Horizontal, 8) }
	for i, t in TABS do
		tabButtons[t.Id] = e(Widgets.Button, {
			text = t.Label,
			size = UDim2.fromOffset(120, 36),
			selected = tab == t.Id,
			layoutOrder = i,
			onClick = function()
				setTab(t.Id)
			end,
		})
	end

	local body: React.ReactNode
	if item == nil then
		body = e(Widgets.Label, { text = UI.PickItem, color = Theme.Subtext })
	else
		local tabProps = { data = data, item = item, wornBy = worn[item.Uid] }
		if tab == "Sockets" then
			body = e(SocketsTab, tabProps)
		elseif tab == "Enchant" then
			body = e(EnchantTab, tabProps)
		else
			body = e(EnhanceTab, tabProps)
		end
	end

	return e(Widgets.Window, {
		title = UI.Inventory,
		group = "Inventory",
		onClose = function()
			State.SetPage(nil)
		end,
		closeOnBackdrop = true,
	}, {
		Search = e("Frame", { Size = UDim2.new(0.38, 0, 0, 34), BackgroundTransparency = 1 }, {
			Input = e(Widgets.TextInput, { text = query, placeholder = UI.Search, onChanged = setQuery }),
		}),
		List = e(VirtualList, {
			count = #items,
			rowHeight = 40,
			size = UDim2.new(0.38, 0, 1, -42),
			position = UDim2.fromOffset(0, 42),
			renderRow = function(index: number): React.ReactNode
				local it = items[index]
				local mark = if worn[it.Uid] ~= nil then UI.EquippedMark .. " " else ""
				return e(Widgets.Button, {
					text = `{mark}{ItemInfo.Line(it)}`,
					size = UDim2.fromScale(1, 1),
					textSize = 14,
					selected = uid == it.Uid,
					onClick = function()
						State.SelectForge(it.Uid)
					end,
				})
			end,
		}),
		Tabs = e("Frame", {
			Size = UDim2.new(0.6, 0, 0, 36),
			Position = UDim2.fromScale(0.4, 0),
			BackgroundTransparency = 1,
		}, tabButtons),
		Panel = e("Frame", {
			Size = UDim2.new(0.6, 0, 1, -44),
			Position = UDim2.new(0.4, 0, 0, 44),
			BackgroundColor3 = Theme.Bg,
		}, {
			Corner = Widgets.Corner(8),
			Padding = Widgets.Padding(12),
			Body = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, { Body = body }),
		}),
	})
end

return Forge
