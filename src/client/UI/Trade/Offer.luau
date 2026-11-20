--!strict
-- Open trade: both offers as 3x3 slot grids (mine left, theirs right), Ready -> Confirm under mine, the bag to add from (gear / materials / boxes) + gold / Ruby below.
-- Every edit sends the whole offer; the server's copy (view.Mine) is the one shown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Format = require(ReplicatedStorage.Shared.Format)
local Materials = require(ReplicatedStorage.Shared.Config.Materials)
local TradeConfig = require(ReplicatedStorage.Shared.Config.Trade)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local Theme = require(script.Parent.Parent.Core.Theme)
local Art = require(script.Parent.Parent.Core.Art)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local ItemInfo = require(script.Parent.Parent.Core.ItemInfo)
local VirtualList = require(script.Parent.Parent.Core.VirtualList)
local State = require(script.Parent.Parent.Parent.State)
local Badge = require(script.Parent.Parent.Core.Badge)
local Tip = require(script.Parent.Parent.Core.Tip)

local e = React.createElement
local UI = Text.Eco.UI

export type Props = {
	data: Types.ProfileData,
	view: Types.TradeView,
}

local PANEL_W = 320
local PANEL_PAD = 12
local MINE_X, THEIRS_X = 60, 580
local HEAD_H = 44
local CELL = 72
local CELL_GAP = 10
local GRID = CELL * 3 + CELL_GAP * 2
local MONEY_H = 24
local PANEL_H = PANEL_PAD * 2 + HEAD_H + 10 + GRID + 6 + MONEY_H
local ACTION_Y = PANEL_H + 10
local ACTION_H = 44
local BAG_Y = ACTION_Y + ACTION_H + 10

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

-- One filled slot of an offer.
type Entry = {
	Kind: "Gear" | "Stack" | "Box",
	Key: string, -- gear uid, material id or box key
	Text: string,
	Tip: Tip.Content?,
	Tier: string?,
}

-- Slots in display order: gear as offered, then materials, then boxes.
-- `own` = the player's side (gear redrawn live in the tooltip); the partner's pieces are snapshots.
local function entries(offer: Types.TradeOffer, gear: (string) -> Types.GearItem?, own: boolean): { Entry }
	local out: { Entry } = {}
	for _, uid in offer.Gear do
		local item = gear(uid)
		table.insert(out, {
			Kind = "Gear" :: "Gear",
			Key = uid,
			Text = if item ~= nil then `{ItemInfo.Name(item)}\nLv {item.Level}` else "?",
			Tip = if own then Tip.Gear(item) else Tip.Snapshot(item),
			Tier = if item ~= nil then item.Tier :: string else nil,
		})
	end
	local ids: { string } = {}
	for id in offer.Stacks do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		table.insert(out, {
			Kind = "Stack" :: "Stack",
			Key = id,
			Text = `{Text.Material(id)}\nx{Format.Number(offer.Stacks[id])}`,
			Tip = Tip.Material(id, offer.Stacks[id]),
			Tier = if Materials.ById[id] ~= nil then Materials.ById[id].Tier else nil,
		})
	end
	local keys: { string } = {}
	for key in offer.Boxes do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in keys do
		table.insert(out, {
			Kind = "Box" :: "Box",
			Key = key,
			Text = `{Text.Box(key)}\nx{Format.Number(offer.Boxes[key])}`,
			Tip = Tip.Box(key, offer.Boxes[key]),
		})
	end
	return out
end

local function money(icon: string, amount: number, x: number): React.ReactNode
	return e("Frame", {
		Size = UDim2.new(0.5, -4, 1, 0),
		Position = UDim2.new(x, if x > 0 then 4 else 0, 0, 0),
		BackgroundTransparency = 1,
	}, {
		Icon = e(Widgets.Icon, { image = icon, size = 20, position = UDim2.fromOffset(0, 2) }),
		Label = e(Widgets.Label, {
			text = Format.Number(amount),
			bold = amount > 0,
			textSize = 15,
			color = if amount > 0 then Theme.Text else Theme.Subtext,
			size = UDim2.new(1, -26, 1, 0),
			position = UDim2.fromOffset(26, 0),
		}),
	})
end

-- One side of the trade: who, the 3x3 grid, gold + Ruby. `onRemove` = clicking a filled slot (own side only).
local function panel(
	x: number,
	who: React.ReactNode,
	offer: Types.TradeOffer,
	list: { Entry },
	onRemove: ((Entry) -> ())?
): React.ReactNode
	local cells: { [string]: React.ReactNode } = {}
	for i = 1, TradeConfig.MaxSlots do
		local entry = list[i]
		local filled = entry ~= nil
		local accent = Theme.TierAccent(if filled then entry.Tier else nil)
		cells[`S{i}`] = e("TextButton", {
			Size = UDim2.fromOffset(CELL, CELL),
			Position = UDim2.fromOffset(((i - 1) % 3) * (CELL + CELL_GAP), ((i - 1) // 3) * (CELL + CELL_GAP)),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Active = filled and onRemove ~= nil,
			Text = "",
			[React.Event.MouseEnter] = Tip.Enter(if filled then entry.Tip else nil),
			[React.Event.MouseLeave] = Tip.Leave,
			[React.Event.Activated] = function()
				if filled and onRemove ~= nil then
					onRemove(entry)
				end
			end,
		}, {
			Art = Art.Back({
				piece = if filled then "BtnPaperHover" else "SlotPaper",
				transparency = if filled then 0 else 0.35,
				padding = 4,
			}),
			Padding = Widgets.Padding(4),
			Rim = Widgets.TierRim(if filled then entry.Tier else nil),
			Label = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = if filled then entry.Text else "",
				TextColor3 = if accent ~= nil then accent.Color else Theme.Text,
				FontFace = if accent ~= nil then Theme.FontBold else Theme.Font,
				TextSize = Theme.Body(11),
				TextScaled = true,
				TextWrapped = true,
				ZIndex = 2,
			}, {
				Max = e("UITextSizeConstraint", { MaxTextSize = Theme.Body(11) }),
				Heavy = if accent ~= nil then Widgets.Heavy(accent.Color, Theme.Body(11)) else nil,
			}),
		})
	end
	return e("Frame", {
		Size = UDim2.fromOffset(PANEL_W, PANEL_H),
		Position = UDim2.fromOffset(x, 0),
		BackgroundTransparency = 1,
	}, {
		Art = Art.Back({ piece = "PaperNotchInfo", padding = PANEL_PAD }),
		Padding = Widgets.Padding(PANEL_PAD),
		Who = who,
		Grid = e("Frame", {
			Size = UDim2.fromOffset(GRID, GRID),
			Position = UDim2.new(0.5, 0, 0, HEAD_H + 10),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
		}, cells),
		Money = e("Frame", {
			Size = UDim2.fromOffset(GRID, MONEY_H),
			Position = UDim2.fromScale(0.5, 1),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
		}, {
			Gold = money(Icons.Gold, offer.Gold, 0),
			Ruby = money(Icons.Ruby, offer.Ruby, 0.5),
		}),
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
	order: number,
	onSet: (number) -> (),
}

local function AmountInput(props: AmountProps): React.ReactNode
	local label, value, have, onSet = props.label, props.value, props.have, props.onSet
	local text, setText = React.useState(if value > 0 then tostring(value) else "")
	React.useEffect(function()
		setText(if value > 0 then tostring(value) else "")
	end, { value })
	return e("Frame", {
		Size = UDim2.new(0.5, -4, 0, 34),
		BackgroundTransparency = 1,
		LayoutOrder = props.order,
	}, {
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
	local function myGear(uid: string): Types.GearItem?
		return data.Gear[uid]
	end
	local function theirGear(uid: string): Types.GearItem?
		return view.TheirGear[uid]
	end
	local myList = entries(mine, myGear, true)
	local theirList = entries(view.Theirs, theirGear, false)

	local function send(edit: (Types.TradeOffer) -> ())
		local o = clone(mine)
		edit(o)
		State.Send.TradeOffer(o)
	end
	-- Adding one more kind of thing: false (with a toast) when all slots are taken.
	local function room(): boolean
		if #myList < TradeConfig.MaxSlots then
			return true
		end
		State.PushToast(Text.Error.TradeTooMany)
		return false
	end
	local function remove(entry: Entry)
		send(function(o)
			if entry.Kind == "Gear" then
				local at = table.find(o.Gear, entry.Key)
				if at ~= nil then
					table.remove(o.Gear, at)
				end
			elseif entry.Kind == "Stack" then
				o.Stacks[entry.Key] = nil
			else
				o.Boxes[entry.Key] = nil
			end
		end)
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
				local offered = inOffer[item.Uid] == true
				return e(Widgets.Button, {
					text = ItemInfo.Line(item),
					size = UDim2.fromScale(1, 1),
					textSize = 13,
					selected = offered,
					tip = Tip.Gear(item),
					onClick = function()
						if not offered and not room() then
							return
						end
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
				local offered = mine.Stacks[def.Id] or 0
				if have > 0 then
					rows[def.Id] = countRow(def.Order, Text.Material(def.Id), have, offered, function(n)
						if offered == 0 and n > 0 and not room() then
							return
						end
						send(function(o)
							setCount(o.Stacks, def.Id, n)
						end)
					end)
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
				local offered = mine.Boxes[key] or 0
				rows[key] = countRow(i, Text.Box(key), data.Boxes[key], offered, function(n)
					if offered == 0 and n > 0 and not room() then
						return
					end
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

	local bothReady = view.MeReady and view.ThemReady
	local wait = math.ceil(view.ConfirmAt - workspace:GetServerTimeNow())
	local canConfirm = bothReady and wait <= 0 and not view.MeConfirmed
	-- One button walks the trade: Ready -> (partner ready) Confirm -> Waiting. Before the partner is ready it takes Ready back.
	local actionText = if view.MeConfirmed
		then UI.Waiting
		elseif bothReady and wait > 0 then `{UI.Confirm} ({wait})`
		elseif bothReady then UI.Confirm
		elseif view.MeReady then UI.Unready
		else UI.Ready
	local partner = Players:GetPlayerByUserId(view.PartnerId)
	local me = Players.LocalPlayer

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Mine = panel(
			MINE_X,
			e(Badge, { userId = me.UserId, display = me.DisplayName, name = me.Name, avatar = HEAD_H }),
			mine,
			myList,
			remove
		),
		Theirs = panel(
			THEIRS_X,
			e(Badge, {
				userId = view.PartnerId,
				display = view.PartnerName,
				name = if partner ~= nil then partner.Name else nil,
				avatar = HEAD_H,
			}),
			view.Theirs,
			theirList,
			nil
		),
		Note = e(Widgets.Label, {
			text = `{UI.AddGear}\n\n{UI.TradeNote}`,
			textSize = 13,
			color = Theme.Subtext,
			wrap = true,
			align = Enum.TextXAlignment.Center,
			size = UDim2.fromOffset(THEIRS_X - MINE_X - PANEL_W - 24, 160),
			position = UDim2.fromOffset(MINE_X + PANEL_W + 12, (PANEL_H - 160) / 2),
		}),
		Action = e(Widgets.Button, {
			text = actionText,
			size = UDim2.fromOffset(200, ACTION_H),
			position = UDim2.fromOffset(MINE_X + PANEL_W / 2, ACTION_Y),
			anchor = Vector2.new(0.5, 0),
			color = if canConfirm or not (view.MeReady or view.MeConfirmed) then Theme.Confirm else nil,
			disabled = view.MeConfirmed or (bothReady and wait > 0),
			onClick = function()
				if bothReady then
					State.Send.TradeConfirm()
				else
					State.Send.TradeReady(not view.MeReady)
				end
			end,
		}),
		Cancel = e(Widgets.Button, {
			text = UI.CancelTrade,
			size = UDim2.fromOffset(150, 36),
			position = UDim2.fromOffset((MINE_X + PANEL_W + THEIRS_X) / 2, ACTION_Y + 4),
			anchor = Vector2.new(0.5, 0),
			textSize = 15,
			color = Theme.Danger,
			onClick = function()
				State.Send.TradeCancel()
			end,
		}),
		TheirStatus = e(Widgets.Label, {
			text = if view.ThemConfirmed then UI.Confirmed elseif view.ThemReady then UI.Ready else UI.NotReady,
			bold = true,
			textSize = 20,
			color = if view.ThemReady then Theme.Text else Theme.Subtext,
			align = Enum.TextXAlignment.Center,
			size = UDim2.fromOffset(PANEL_W, ACTION_H),
			position = UDim2.fromOffset(THEIRS_X, ACTION_Y),
		}),
		Bag = e("Frame", {
			Size = UDim2.new(1, 0, 1, -BAG_Y),
			Position = UDim2.fromOffset(0, BAG_Y),
			BackgroundTransparency = 1,
		}, {
			Art = Art.Back({ piece = "PaperNotchInfo", padding = 12 }),
			Padding = Widgets.Padding(12),
			Tabs = e(Widgets.Tabs, { tabs = PICK_TABS, current = pick, onSelect = setPick, width = 110 }),
			Slots = e(Widgets.Label, {
				text = `{#myList}/{TradeConfig.MaxSlots} {UI.Slots}`,
				color = if #myList >= TradeConfig.MaxSlots then Theme.Accent else Theme.Subtext,
				size = UDim2.fromOffset(140, 36),
				position = UDim2.fromOffset(360, 0),
			}),
			Amounts = e("Frame", {
				Size = UDim2.fromOffset(380, 34),
				Position = UDim2.fromScale(1, 0),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
			}, {
				Layout = Widgets.List(Enum.FillDirection.Horizontal, 8),
				Gold = e(AmountInput, {
					label = UI.GoldAmount,
					order = 1,
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
					order = 2,
					value = mine.Ruby,
					have = data.Ruby,
					onSet = function(n: number)
						send(function(o)
							o.Ruby = n
						end)
					end,
				}),
			}),
			List = e("Frame", {
				Size = UDim2.new(1, 0, 1, -44),
				Position = UDim2.fromOffset(0, 44),
				BackgroundTransparency = 1,
			}, { Content = picker }),
		}),
	})
end

return Offer
