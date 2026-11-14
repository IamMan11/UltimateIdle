--!strict
-- Open trade: pick what to give (gear / materials / boxes / gold / Ruby), both offers side by side, Ready -> Confirm -> Cancel.
-- Every edit sends the whole offer; the server's copy (view.Mine) is the one shown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Format = require(ReplicatedStorage.Shared.Format)
local Materials = require(ReplicatedStorage.Shared.Config.Materials)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local ItemInfo = require(script.Parent.Parent.Core.ItemInfo)
local VirtualList = require(script.Parent.Parent.Core.VirtualList)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement
local UI = Text.Eco.UI

export type Props = {
	data: Types.ProfileData,
	view: Types.TradeView,
}

local PICK_TABS = {
	{ Id = "Gear", Label = Text.UI.Bag },
	{ Id = "Materials", Label = UI.Materials },
	{ Id = "Boxes", Label = UI.Boxes },
}

local function clone(o: Types.TradeOffer): Types.TradeOffer
	return {
		Gear = table.clone(o.Gear),
		Stacks = table.clone(o.Stacks),
		Boxes = table.clone(o.Boxes),
		Gold = o.Gold,
		Ruby = o.Ruby,
	}
end

local function setCount(map: { [string]: number }, key: string, n: number)
	if n > 0 then
		map[key] = n
	else
		map[key] = nil
	end
end

local function lines(offer: Types.TradeOffer, gear: (string) -> Types.GearItem?): { string }
	local out: { string } = {}
	for _, uid in offer.Gear do
		local item = gear(uid)
		table.insert(out, if item ~= nil then ItemInfo.Line(item) else "?")
	end
	local mats: { string } = {}
	for id, n in offer.Stacks do
		table.insert(mats, `{Format.Number(n)} {Text.Material(id)}`)
	end
	table.sort(mats)
	for _, l in mats do
		table.insert(out, l)
	end
	for key, n in offer.Boxes do
		table.insert(out, `{n} {Text.Box(key)}`)
	end
	if offer.Gold > 0 then
		table.insert(out, `{Format.Number(offer.Gold)} gold`)
	end
	if offer.Ruby > 0 then
		table.insert(out, `{Format.Number(offer.Ruby)} Ruby`)
	end
	return out
end

local function summary(title: string, status: string, items: { string }, position: UDim2): React.ReactNode
	local rows: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Vertical, 2) }
	if #items == 0 then
		rows.Empty = e(Widgets.Label, { text = UI.NothingOffered, color = Theme.Subtext, textSize = 15 })
	end
	for i, line in items do
		rows[`L{i}`] = e(Widgets.Label, { text = line, textSize = 14, layoutOrder = i })
	end
	return e("Frame", {
		Size = UDim2.new(0.31, -8, 1, -136),
		Position = position,
		BackgroundColor3 = Theme.Bg,
	}, {
		Corner = Widgets.Corner(8),
		Padding = Widgets.Padding(10),
		Title = e(Widgets.Label, { text = title, bold = true }),
		Status = e(Widgets.Label, {
			text = status,
			textSize = 15,
			color = Theme.Subtext,
			position = UDim2.fromOffset(0, 22),
		}),
		List = e("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, -50),
			Position = UDim2.fromOffset(0, 50),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, rows),
	})
end

local function countRow(order: number, name: string, have: number, offered: number, onSet: (number) -> ())
	return e("Frame", { Size = UDim2.new(1, -8, 0, 34), BackgroundTransparency = 1, LayoutOrder = order }, {
		Name = e(Widgets.Label, {
			text = `{name} ({Format.Number(have)})`,
			textSize = 14,
			size = UDim2.new(1, -190, 1, 0),
		}),
		Step = e("Frame", {
			Size = UDim2.fromOffset(120, 32),
			Position = UDim2.new(1, -64, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
		}, {
			Stepper = e(Widgets.Stepper, { value = offered, min = 0, max = have, onChange = onSet }),
		}),
		All = e(Widgets.Button, {
			text = "All",
			size = UDim2.fromOffset(56, 32),
			position = UDim2.fromScale(1, 0.5),
			anchor = Vector2.new(1, 0.5),
			textSize = 14,
			disabled = offered >= have,
			onClick = function()
				onSet(have)
			end,
		}),
	})
end

type AmountProps = {
	label: string,
	value: number,
	have: number,
	onSet: (number) -> (),
}

local function AmountInput(props: AmountProps): React.ReactNode
	local label, value, have, onSet = props.label, props.value, props.have, props.onSet
	local text, setText = React.useState(if value > 0 then tostring(value) else "")
	React.useEffect(function()
		setText(if value > 0 then tostring(value) else "")
	end, { value })
	return e("Frame", { Size = UDim2.new(0.5, -4, 0, 34), BackgroundTransparency = 1 }, {
		Input = e(Widgets.TextInput, {
			text = text,
			placeholder = `{label} (have {Format.Number(have)})`,
			onChanged = setText,
			onFocusLost = function(raw: string)
				local n = tonumber(raw) or 0
				n = math.clamp(math.floor(n), 0, math.floor(have))
				if n ~= value then
					onSet(n)
				end
			end,
		}),
	})
end

local function Offer(props: Props): React.ReactNode
	local data = props.data
	local view = props.view
	local pick, setPick = React.useState("Gear")
	Widgets.useTick(0.5)

	local mine = view.Mine
	local inOffer: { [string]: boolean } = {}
	for _, uid in mine.Gear do
		inOffer[uid] = true
	end
	local function send(edit: (Types.TradeOffer) -> ())
		local o = clone(mine)
		edit(o)
		State.Send.TradeOffer(o)
	end

	local worn = ItemInfo.WornMap(data)
	local bag: { Types.GearItem } = {}
	for _, item in data.Gear do
		if worn[item.Uid] == nil then
			table.insert(bag, item)
		end
	end
	table.sort(bag, function(a, b)
		if a.Level ~= b.Level then
			return a.Level > b.Level
		end
		return (tonumber(a.Uid) or 0) > (tonumber(b.Uid) or 0)
	end)

	local picker: React.ReactNode
	if pick == "Gear" then
		picker = e(VirtualList, {
			count = #bag,
			rowHeight = 38,
			renderRow = function(index: number): React.ReactNode
				local item = bag[index]
				return e(Widgets.Button, {
					text = ItemInfo.Line(item),
					size = UDim2.fromScale(1, 1),
					textSize = 13,
					selected = inOffer[item.Uid] == true,
					onClick = function()
						send(function(o)
							local at = table.find(o.Gear, item.Uid)
							if at ~= nil then
								table.remove(o.Gear, at)
							else
								table.insert(o.Gear, item.Uid)
							end
						end)
					end,
				})
			end,
		})
	else
		local rows: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Vertical, 4) }
		if pick == "Materials" then
			for _, def in Materials.List do
				local have = data.Stacks[def.Id] or 0
				if have > 0 then
					rows[def.Id] = countRow(
						def.Order,
						Text.Material(def.Id),
						have,
						mine.Stacks[def.Id] or 0,
						function(n)
							send(function(o)
								setCount(o.Stacks, def.Id, n)
							end)
						end
					)
				end
			end
		else
			local keys: { string } = {}
			for key, n in data.Boxes do
				if n > 0 then
					table.insert(keys, key)
				end
			end
			table.sort(keys)
			for i, key in keys do
				rows[key] = countRow(i, Text.Box(key), data.Boxes[key], mine.Boxes[key] or 0, function(n)
					send(function(o)
						setCount(o.Boxes, key, n)
					end)
				end)
			end
		end
		picker = e("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, rows)
	end

	local function myGear(uid: string): Types.GearItem?
		return data.Gear[uid]
	end
	local function theirGear(uid: string): Types.GearItem?
		return view.TheirGear[uid]
	end
	local function status(ready: boolean, confirmed: boolean): string
		return if confirmed then UI.Confirmed elseif ready then UI.Ready else UI.NotReady
	end

	local bothReady = view.MeReady and view.ThemReady
	local wait = math.ceil(view.ConfirmAt - workspace:GetServerTimeNow())
	local canConfirm = bothReady and wait <= 0 and not view.MeConfirmed
	local confirmText = if view.MeConfirmed
		then UI.Waiting
		elseif bothReady and wait > 0 then `{UI.Confirm} ({wait})`
		else UI.Confirm

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Picker = e("Frame", {
			Size = UDim2.new(0.36, -8, 1, -56),
			BackgroundColor3 = Theme.Bg,
		}, {
			Corner = Widgets.Corner(8),
			Padding = Widgets.Padding(8),
			Tabs = e(Widgets.Tabs, { tabs = PICK_TABS, current = pick, onSelect = setPick, width = 110 }),
			Hint = e(Widgets.Label, {
				text = UI.AddGear,
				textSize = 13,
				color = Theme.Subtext,
				position = UDim2.fromOffset(0, 40),
			}),
			List = e("Frame", {
				Size = UDim2.new(1, 0, 1, -66),
				Position = UDim2.fromOffset(0, 66),
				BackgroundTransparency = 1,
			}, { Content = picker }),
		}),
		Amounts = e("Frame", {
			Size = UDim2.new(0.31, -8, 0, 34),
			Position = UDim2.fromScale(0.36, 0),
			BackgroundTransparency = 1,
		}, {
			Layout = Widgets.List(Enum.FillDirection.Horizontal, 8),
			Gold = e(AmountInput, {
				label = UI.GoldAmount,
				value = mine.Gold,
				have = data.Gold,
				onSet = function(n: number)
					send(function(o)
						o.Gold = n
					end)
				end,
			}),
			Ruby = e(AmountInput, {
				label = UI.RubyAmount,
				value = mine.Ruby,
				have = data.Ruby,
				onSet = function(n: number)
					send(function(o)
						o.Ruby = n
					end)
				end,
			}),
		}),
		Mine = summary(
			UI.YourOffer,
			status(view.MeReady, view.MeConfirmed),
			lines(mine, myGear),
			UDim2.new(0.36, 0, 0, 42)
		),
		Theirs = summary(
			`{UI.TheirOffer} ({view.PartnerName})`,
			status(view.ThemReady, view.ThemConfirmed),
			lines(view.Theirs, theirGear),
			UDim2.new(0.67, 0, 0, 42)
		),
		Note = e(Widgets.Label, {
			text = UI.TradeNote,
			textSize = 14,
			color = Theme.Subtext,
			size = UDim2.new(0.64, -8, 0, 20),
			position = UDim2.new(0.36, 0, 1, -88),
		}),
		Buttons = e("Frame", {
			Size = UDim2.new(1, 0, 0, 44),
			Position = UDim2.fromScale(0, 1),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,
		}, {
			Layout = Widgets.List(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Right),
			Ready = e(Widgets.Button, {
				text = if view.MeReady then UI.Unready else UI.Ready,
				size = UDim2.fromOffset(180, 44),
				layoutOrder = 1,
				onClick = function()
					State.Send.TradeReady(not view.MeReady)
				end,
			}),
			Confirm = e(Widgets.Button, {
				text = confirmText,
				size = UDim2.fromOffset(200, 44),
				color = if canConfirm then Theme.Confirm else nil,
				disabled = not canConfirm,
				layoutOrder = 2,
				onClick = function()
					State.Send.TradeConfirm()
				end,
			}),
			Cancel = e(Widgets.Button, {
				text = UI.CancelTrade,
				size = UDim2.fromOffset(160, 44),
				color = Theme.Danger,
				layoutOrder = 3,
				onClick = function()
					State.Send.TradeCancel()
				end,
			}),
		}),
	})
end

return Offer
