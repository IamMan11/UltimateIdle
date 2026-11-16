--!strict
-- Forge tab: sockets of the selected piece (kind, insert, remove) and opening a new one (duplicate merge or Socket Core).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Format = require(ReplicatedStorage.Shared.Format)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Inserts = require(ReplicatedStorage.Shared.Config.Inserts)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local ItemInfo = require(script.Parent.Parent.Core.ItemInfo)
local State = require(script.Parent.Parent.Parent.State)
local Parts = require(script.Parent.Parts)

local e = React.createElement
local UI = Text.UI

local MAX_CANDIDATES = 6

export type Props = { data: Types.ProfileData, item: Types.GearItem, wornBy: string? }

local function row(children: { [string]: React.ReactNode }, height: number, order: number): React.ReactNode
	children.Layout = Widgets.List(Enum.FillDirection.Horizontal, 6)
	return e("Frame", { Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1, LayoutOrder = order }, children)
end

local function socketRows(data: Types.ProfileData, item: Types.GearItem, into: { [string]: React.ReactNode })
	for i, socket in item.Sockets do
		local base = i * 10
		local head: { [string]: React.ReactNode } = {
			Name = e(Widgets.Label, {
				text = `Socket {i}`,
				size = UDim2.fromOffset(80, 36),
				bold = true,
				layoutOrder = 1,
			}),
		}
		for k, kind in Inserts.Kinds do
			head[kind] = e(Widgets.Button, {
				text = Text.SocketKind(kind),
				size = UDim2.fromOffset(92, 36),
				textSize = 15,
				selected = socket.Kind == kind,
				layoutOrder = 1 + k,
				onClick = function()
					if socket.Kind ~= kind then
						State.Send.SetSocketKind(item.Uid, i, kind)
					end
				end,
			})
		end
		into[`S{i}`] = row(head, 36, base)

		if socket.Insert ~= nil then
			local cost = Formula.Forge.RemoveGold(item)
			into[`C{i}`] = row({
				Insert = e(Widgets.Label, {
					text = `{Text.Material(socket.Insert)}: {Text.InsertEffect(socket.Insert)}`,
					size = UDim2.new(1, -186, 0, 32),
					textSize = 15,
					layoutOrder = 1,
				}),
				Remove = e(Widgets.Button, {
					text = `{UI.Remove} ({Format.Number(cost)} gold)`,
					size = UDim2.fromOffset(180, 32),
					textSize = 14,
					disabled = data.Gold < cost,
					layoutOrder = 2,
					onClick = function()
						State.Send.RemoveInsert(item.Uid, i)
					end,
				}),
			}, 32, base + 1)
		end

		if socket.Kind ~= nil and socket.Insert == nil then
			local choices: { [string]: React.ReactNode } = {}
			local any = false
			for _, def in Inserts.List do
				local have = data.Stacks[def.Id] or 0
				if def.Kind == socket.Kind and have > 0 then
					any = true
					choices[def.Id] = e(Widgets.Button, {
						text = `{Text.Material(def.Id)} x{have}`,
						size = UDim2.fromOffset(160, 32),
						textSize = 14,
						layoutOrder = def.Order,
						onClick = function()
							State.Send.InsertSocket(item.Uid, i, def.Id)
						end,
					})
				end
			end
			if not any then
				choices.None = e(Widgets.Label, {
					text = `{UI.NoInserts} ({Text.SocketKind(socket.Kind)})`,
					size = UDim2.fromOffset(300, 32),
					color = Theme.Subtext,
					textSize = 15,
				})
			end
			into[`C{i}`] = row(choices, 32, base + 1)
		end
	end
end

local function SocketsTab(props: Props): React.ReactNode
	local data, item = props.data, props.item
	local worn = ItemInfo.WornMap(data)
	local rows: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Vertical, 6) }
	rows.Head = Parts.Heading(`{ItemInfo.Name(item)}   {UI.Sockets} {#item.Sockets}/{Inserts.MaxSockets}`, 0)
	socketRows(data, item, rows)

	local order = 1000
	if #item.Sockets >= Inserts.MaxSockets then
		rows.Full = e(Widgets.Label, { text = UI.SocketsMax, color = Theme.Subtext, layoutOrder = order })
	else
		rows.AddHead = Parts.Heading(UI.AddSocket, order)
		local cores = data.Stacks[Inserts.CoreItem] or 0
		rows.Core = e(Widgets.Button, {
			text = `Use {Text.Material(Inserts.CoreItem)} (have {cores})`,
			size = UDim2.fromOffset(280, 40),
			disabled = cores <= 0,
			layoutOrder = order + 1,
			onClick = function()
				State.Send.UseSocketCore(item.Uid)
			end,
		})
		local gold = Formula.Forge.MergeGold(item)
		rows.MergeHint = e(Widgets.Label, {
			text = `{UI.MergeHint} Cost: {Format.Number(gold)} gold.`,
			size = UDim2.new(1, 0, 0, 40),
			wrap = true,
			color = Theme.Subtext,
			textSize = 15,
			layoutOrder = order + 2,
		})
		local candidates: { Types.GearItem } = {}
		for uid, other in data.Gear do
			if worn[uid] == nil and Formula.Forge.CanMerge(item, other) then
				table.insert(candidates, other)
			end
		end
		table.sort(candidates, function(a, b)
			-- least valuable first: it gets destroyed
			if a.Plus ~= b.Plus then
				return a.Plus < b.Plus
			end
			return a.GearScore < b.GearScore
		end)
		if #candidates == 0 then
			rows.NoDup = e(Widgets.Label, { text = UI.NoDuplicates, color = Theme.Subtext, layoutOrder = order + 3 })
		end
		for i = 1, math.min(#candidates, MAX_CANDIDATES) do
			local other = candidates[i]
			rows[`M{i}`] = e(Widgets.Button, {
				text = `Merge: {ItemInfo.Line(other)}`,
				size = UDim2.new(1, 0, 0, 36),
				textSize = 14,
				disabled = data.Gold < gold,
				layoutOrder = order + 3 + i,
				onClick = function()
					local lost = if other.Plus > 0 or #other.Enchants > 0
						then ` Its +{other.Plus} and {#other.Enchants} trait(s) are lost too.`
						else ""
					State.OpenConfirm({
						Title = `Destroy {ItemInfo.Name(other)} for a socket?`,
						Body = `{ItemInfo.Line(other)} is destroyed for good and {ItemInfo.Name(item)} gains socket {#item.Sockets + 1}.{lost} Costs {Format.Number(
							gold
						)} gold.`,
						OkText = "Merge",
						Danger = true,
						OnConfirm = function()
							State.Send.MergeSocket(item.Uid, other.Uid)
						end,
					})
				end,
			})
		end
	end

	return e("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, rows)
end

return SocketsTab
