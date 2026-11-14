--!strict
-- Bag page: search (name + @tag), sort, tier filter, virtual list, item detail, salvage one or many (with confirm).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Format = require(ReplicatedStorage.Shared.Format)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Text = require(ReplicatedStorage.Shared.Text)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local Materials = require(ReplicatedStorage.Shared.Config.Materials)
local Theme = require(script.Parent.Core.Theme)
local Widgets = require(script.Parent.Core.Widgets)
local ItemInfo = require(script.Parent.Core.ItemInfo)
local VirtualList = require(script.Parent.Core.VirtualList)
local State = require(script.Parent.Parent.State)

local e = React.createElement
local UI = Text.UI

type SortKey = "Level" | "Score" | "Tier"

export type Props = { data: Types.ProfileData }

local function salvageValue(items: { Types.GearItem }): (number, number)
	local gold, stones = 0, 0
	for _, item in items do
		local tier = Tiers.ById[item.Tier]
		if tier ~= nil then
			gold += math.floor(tier.SalvageGold * Formula.Scaling.Item(item.Level))
			stones += tier.SalvageStones
		end
	end
	return gold, stones
end

local function confirmSalvage(items: { Types.GearItem }, onDone: () -> ())
	local gold, stones = salvageValue(items)
	local what = if #items == 1
		then ItemInfo.Name(items[1]) .. " [" .. Text.Tier(items[1].Tier) .. "]"
		else `{#items} items`
	State.OpenConfirm({
		Title = `Salvage {what}?`,
		Body = `You get {Format.Number(gold)} gold + {stones} {Text.Material("EnhanceStone")}. The item is gone for good.`,
		OkText = if #items == 1 then UI.Salvage else `Salvage {#items}`,
		Danger = true,
		OnConfirm = function()
			local uids = {}
			for i, item in items do
				if i > Game.SalvageBatchMax then
					break
				end
				table.insert(uids, item.Uid)
			end
			State.Send.Salvage(uids)
			onDone()
		end,
	})
end

local function Inventory(props: Props): React.ReactNode
	local data = props.data
	local query, setQuery = React.useState("")
	local sortKey, setSortKey = React.useState("Level" :: SortKey)
	local tierFilter, setTierFilter = Widgets.useOptional(nil :: string?)
	local selectMode, setSelectMode = React.useState(false)
	local picked, setPicked = React.useState({} :: { [string]: boolean })
	local focus, setFocus = Widgets.useOptional(nil :: string?)

	local worn = ItemInfo.WornMap(data)
	local parsed = Tags.Parse(query)
	local items: { Types.GearItem } = {}
	local bagCount = 0
	for uid, item in data.Gear do
		if worn[uid] == nil then
			bagCount += 1
		end
		if
			(tierFilter == nil or item.Tier == tierFilter)
			and Tags.Match(parsed, Tags.ForGear(item), ItemInfo.Name(item))
		then
			table.insert(items, item)
		end
	end
	table.sort(items, function(a, b)
		local ka, kb
		if sortKey == "Score" then
			ka, kb = a.GearScore, b.GearScore
		elseif sortKey == "Tier" then
			ka, kb = ItemInfo.TierOrder(a), ItemInfo.TierOrder(b)
		else
			ka, kb = a.Level, b.Level
		end
		if ka ~= kb then
			return ka > kb
		end
		return (tonumber(a.Uid) or 0) > (tonumber(b.Uid) or 0)
	end)

	local pickedItems: { Types.GearItem } = {}
	for uid in picked do
		local item = data.Gear[uid]
		if item ~= nil and worn[uid] == nil then
			table.insert(pickedItems, item)
		end
	end

	-- Header: search, sort, tier filter, select mode
	local header: { [string]: React.ReactNode } = {
		Layout = Widgets.List(Enum.FillDirection.Horizontal, 6),
		Search = e("Frame", { Size = UDim2.fromOffset(260, 34), BackgroundTransparency = 1, LayoutOrder = 1 }, {
			Input = e(Widgets.TextInput, { text = query, placeholder = UI.Search, onChanged = setQuery }),
		}),
	}
	for i, key in { "Level", "Score", "Tier" } do
		header[`Sort{key}`] = e(Widgets.Button, {
			text = key,
			size = UDim2.fromOffset(70, 34),
			selected = sortKey == key,
			layoutOrder = 1 + i,
			onClick = function()
				setSortKey(key :: SortKey)
			end,
		})
	end
	for i, tier in Tiers.List do
		header[`Tier{tier.Id}`] = e(Widgets.Button, {
			text = Text.Tier(tier.Id),
			size = UDim2.fromOffset(92, 34),
			textSize = 15,
			selected = tierFilter == tier.Id,
			layoutOrder = 10 + i,
			onClick = function()
				setTierFilter(if tierFilter == tier.Id then nil else tier.Id)
			end,
		})
	end
	header.Select = e(Widgets.Button, {
		text = if selectMode then `{UI.SalvageSelected} ({#pickedItems})` else UI.Select,
		size = UDim2.fromOffset(if selectMode then 190 else 80, 34),
		textSize = 15,
		color = if selectMode and #pickedItems > 0 then Theme.Danger else nil,
		layoutOrder = 20,
		onClick = function()
			if selectMode and #pickedItems > 0 then
				confirmSalvage(pickedItems, function()
					setPicked({})
					setSelectMode(false)
				end)
			else
				setSelectMode(not selectMode)
				setPicked({})
			end
		end,
	})

	local matParts = {}
	for _, def in Materials.List do
		local n = data.Stacks[def.Id]
		if n ~= nil and n > 0 then
			table.insert(matParts, `{Text.Material(def.Id)} ×{Format.Number(n)}`)
		end
	end

	-- Detail panel
	local detail: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Vertical, 4) }
	local focused = if focus ~= nil then data.Gear[focus] else nil
	if focused ~= nil then
		local tags = Tags.ForGear(focused)
		for i, tag in tags do
			tags[i] = "@" .. tag
		end
		detail.Name = e(Widgets.Label, { text = ItemInfo.Name(focused), bold = true, textSize = 22, layoutOrder = 1 })
		detail.Meta = e(Widgets.Label, {
			text = `{Text.Tier(focused.Tier)} · Lv {focused.Level} · GS {focused.GearScore} · Rebirth {focused.Rebirth}`,
			color = Theme.Subtext,
			layoutOrder = 2,
		})
		local lines = ItemInfo.StatLines(focused, nil)
		detail.Stats = e(Widgets.Label, {
			text = table.concat(lines, "\n"),
			size = UDim2.new(1, 0, 0, 22 * math.max(#lines, 1)),
			wrap = true,
			layoutOrder = 3,
		})
		detail.Tags = e(Widgets.Label, {
			text = table.concat(tags, " "),
			size = UDim2.new(1, 0, 0, 44),
			color = Theme.Subtext,
			textSize = 15,
			wrap = true,
			layoutOrder = 4,
		})
		local wornBy = worn[focused.Uid]
		detail.Worn = if wornBy ~= nil
			then e(Widgets.Label, { text = `Worn by {Text.Class(wornBy)}`, layoutOrder = 5 })
			else nil
		detail.Salvage = e(Widgets.Button, {
			text = UI.Salvage,
			color = Theme.Danger,
			disabled = wornBy ~= nil,
			layoutOrder = 6,
			onClick = function()
				confirmSalvage({ focused }, function()
					setFocus(nil)
				end)
			end,
		})
	end

	return e(Widgets.Window, {
		title = `{UI.Bag}  {bagCount}/{Game.InventoryCapacity}`,
		onClose = function()
			State.SetPage(nil)
		end,
		closeOnBackdrop = true,
	}, {
		Header = e("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 }, header),
		Mats = e(Widgets.Label, {
			text = if #matParts > 0 then table.concat(matParts, "   ·   ") else "No materials",
			position = UDim2.fromOffset(0, 42),
			color = Theme.Subtext,
			textSize = 15,
		}),
		List = e(VirtualList, {
			count = #items,
			rowHeight = 40,
			size = UDim2.new(0.62, 0, 1, -72),
			position = UDim2.fromOffset(0, 72),
			renderRow = function(index: number): React.ReactNode
				local item = items[index]
				local isPicked = picked[item.Uid] == true
				local wornMark = if worn[item.Uid] ~= nil then UI.EquippedMark .. " " else ""
				local check = if selectMode then (if isPicked then "[x] " else "[ ] ") else ""
				return e(Widgets.Button, {
					text = `{check}{wornMark}{ItemInfo.Line(item)}`,
					size = UDim2.fromScale(1, 1),
					textSize = 15,
					selected = if selectMode then isPicked else (focus == item.Uid),
					onClick = function()
						if selectMode then
							if worn[item.Uid] == nil then
								local nextPicked = table.clone(picked)
								if isPicked then
									nextPicked[item.Uid] = nil
								else
									nextPicked[item.Uid] = true
								end
								setPicked(nextPicked)
							end
						else
							setFocus(item.Uid)
						end
					end,
				})
			end,
		}),
		Detail = e("Frame", {
			Size = UDim2.new(0.36, 0, 1, -72),
			Position = UDim2.new(0.64, 0, 0, 72),
			BackgroundColor3 = Theme.PanelAlt,
		}, {
			Corner = Widgets.Corner(8),
			Padding = Widgets.Padding(12),
			Body = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, detail),
		}),
	})
end

return Inventory
