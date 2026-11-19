--!strict
-- Sockets of one gear piece as rows: kind buttons, the insert in it (remove for gold) or the inserts in the bag that fit, and opening a socket with a Socket Core.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Format = require(ReplicatedStorage.Shared.Format)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Inserts = require(ReplicatedStorage.Shared.Config.Inserts)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local State = require(script.Parent.Parent.Parent.State)
local Tip = require(script.Parent.Parent.Core.Tip)

local e = React.createElement
local UI = Text.UI

local ROW_H = 30

local function row(children: { [string]: React.ReactNode }, order: number, tip: Tip.Content?): React.ReactNode
	children.Layout = Widgets.List(Enum.FillDirection.Horizontal, 6)
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, ROW_H),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		[React.Event.MouseEnter] = if tip ~= nil then Tip.Enter(tip) else nil,
		[React.Event.MouseLeave] = if tip ~= nil then Tip.Leave else nil,
	}, children)
end

-- Adds the rows to `into` (a vertical list's children), LayoutOrder from `order` up.
return function(data: Types.ProfileData, item: Types.GearItem, into: { [string]: React.ReactNode }, order: number)
	into.SocketsHead = e(Widgets.Label, {
		text = `{UI.Sockets} {#item.Sockets}/{Inserts.MaxSockets}`,
		bold = true,
		textSize = 15,
		layoutOrder = order,
	})
	if #item.Sockets < Inserts.MaxSockets then
		local cores = data.Stacks[Inserts.CoreItem] or 0
		into.Core = e(Widgets.Button, {
			text = `Use {Text.Material(Inserts.CoreItem)} (have {cores})`,
			size = UDim2.new(1, 0, 0, ROW_H),
			textSize = 14,
			disabled = cores <= 0,
			layoutOrder = order + 1,
			onClick = function()
				State.Send.UseSocketCore(item.Uid)
			end,
		})
	end
	for i, socket in item.Sockets do
		local base = order + i * 10
		local head: { [string]: React.ReactNode } = {
			Name = e(Widgets.Label, {
				text = `Socket {i}`,
				size = UDim2.fromOffset(64, ROW_H),
				bold = true,
				textSize = 14,
				layoutOrder = 1,
			}),
		}
		for k, kind in Inserts.Kinds do
			head[kind] = e(Widgets.Button, {
				text = Text.SocketKind(kind),
				size = UDim2.fromOffset(80, ROW_H),
				textSize = 14,
				selected = socket.Kind == kind,
				layoutOrder = 1 + k,
				onClick = function()
					if socket.Kind ~= kind then
						State.Send.SetSocketKind(item.Uid, i, kind)
					end
				end,
			})
		end
		into[`S{i}`] = row(head, base, Tip.Socket(item, i))

		if socket.Insert ~= nil then
			local cost = Formula.Forge.RemoveGold(item)
			into[`C{i}`] = row({
				Insert = e(Widgets.Label, {
					text = `{Text.Material(socket.Insert)}: {Text.InsertEffect(socket.Insert)}`,
					size = UDim2.new(1, -166, 0, ROW_H),
					textSize = 13,
					layoutOrder = 1,
				}),
				Remove = e(Widgets.Button, {
					text = `{UI.Remove} ({Format.Number(cost)} gold)`,
					size = UDim2.fromOffset(160, ROW_H),
					textSize = 13,
					disabled = data.Gold < cost,
					layoutOrder = 2,
					onClick = function()
						State.Send.RemoveInsert(item.Uid, i)
					end,
				}),
			}, base + 1, Tip.Socket(item, i))
		elseif socket.Kind ~= nil then
			local choices: { [string]: React.ReactNode } = {}
			local any = false
			for _, def in Inserts.List do
				local have = data.Stacks[def.Id] or 0
				if def.Kind == socket.Kind and have > 0 then
					any = true
					choices[def.Id] = e(Widgets.Button, {
						text = `{Text.Material(def.Id)} x{have}`,
						size = UDim2.fromOffset(140, ROW_H),
						textSize = 13,
						layoutOrder = def.Order,
						tip = Tip.Material(def.Id),
						onClick = function()
							State.Send.InsertSocket(item.Uid, i, def.Id)
						end,
					})
				end
			end
			if not any then
				choices.None = e(Widgets.Label, {
					text = `{UI.NoInserts} ({Text.SocketKind(socket.Kind)})`,
					size = UDim2.fromOffset(260, ROW_H),
					color = Theme.Subtext,
					textSize = 13,
				})
			end
			into[`C{i}`] = row(choices, base + 1)
		end
	end
end
