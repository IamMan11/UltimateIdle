--!strict
-- Overlay drawn at the root above windows (Core/Tip holds the state): hover/pinned card (+ the Team hero's worn piece beside a bag piece), drag ghost. Cards: gear = name + power (trait) names, enhance plus top-right, level/tier/GS, status, effect, sockets · material/gem · box · socket. Placed beside the hovered slot and kept on screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Format = require(ReplicatedStorage.Shared.Format)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Text = require(ReplicatedStorage.Shared.Text)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Inserts = require(ReplicatedStorage.Shared.Config.Inserts)
local Materials = require(ReplicatedStorage.Shared.Config.Materials)
local Boxes = require(ReplicatedStorage.Shared.Config.Boxes)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)
local ItemInfo = require(script.Parent.ItemInfo)
local Tip = require(script.Parent.Tip)
local Equip = require(script.Parent.Equip)

local e = React.createElement
local UI = Text.UI

local W = 330 -- card width (design units)
local PAD = 10
local IMG = 52
local SOCK = 22
local SOCK_GAP = 5
local GAP = 8 -- between the hovered slot and the card
local MARGIN = 6 -- from the screen edge
local PAIR_GAP = 6 -- between the card and the equipped piece's card
local GHOST = Vector2.new(84, 52)

export type Props = {
	data: Types.ProfileData,
	scale: number, -- the root UIScale: design unit = pixel / scale
	hidden: boolean?, -- a modal is open
}

-- What one card shows; sections with no lines are left out.
type Card = {
	Image: string?, -- Config.Icons value
	ImageText: string,
	Name: string,
	Powers: string, -- trait names right after the name (gear)
	Side: string, -- top-right: enhance plus ("+2") or units ("x12")
	Line: string, -- under the name
	Status: { string },
	Effect: { string },
	Foot: string, -- bottom-left
	Item: Types.GearItem?, -- draws its socket squares bottom-right
	Highlight: number?, -- socket square to mark
	Tag: string?, -- small heading above the card ("Equipped")
}

local function blank(): Card
	return {
		ImageText = "",
		Name = "",
		Powers = "",
		Side = "",
		Line = "",
		Status = {},
		Effect = {},
		Foot = "",
	}
end

local function gearCard(data: Types.ProfileData, item: Types.GearItem, wearer: string?): Card
	local card = blank()
	local def = Items.ById[item.BaseId]
	local own = data.Gear[item.Uid] == item
	local wornBy = if own then ItemInfo.WornMap(data)[item.Uid] else nil
	local reader = wearer or wornBy
	card.ImageText = if def ~= nil then Text.Slot(def.Slot) else ""
	card.Side = `+{item.Plus}`
	card.Name = Text.Item(item.BaseId)
	local powers = {}
	for _, enchant in item.Enchants do
		table.insert(powers, Text.TraitName(enchant.Id))
	end
	card.Powers = table.concat(powers, ", ")
	card.Line = `Lv {item.Level}  ·  {Text.Tier(item.Tier)}  ·  GS {item.GearScore}{if def ~= nil
		then "  ·  " .. Text.Class(def.Class)
		else ""}`
	card.Status = ItemInfo.Stats(item, reader)
	card.Effect = ItemInfo.Effects(item, reader)
	card.Foot = if wornBy ~= nil then `{UI.TipWornBy} {Text.Class(wornBy)}` else ""
	card.Item = item
	return card
end

local function materialCard(data: Types.ProfileData, id: string, count: number?): Card
	local card = blank()
	local def = Materials.ById[id]
	local insert = Inserts.ById[id]
	card.Image = if insert == nil then Icons.Forge else nil
	card.ImageText = if insert ~= nil then Text.SocketKind(insert.Kind) else ""
	card.Side = if count ~= nil and count > 1 then `x{Format.Number(count)}` else ""
	card.Name = Text.Material(id)
	card.Line = `{if def ~= nil then Text.Tier(def.Tier) else ""}  ·  {if insert ~= nil
		then Text.SocketKind(insert.Kind)
		else UI.TipMaterial}`
	if insert ~= nil then
		card.Status = { Text.InsertEffect(id) }
	end
	local use = Text.MaterialUse(id)
	card.Effect = if use ~= "" then { use } else {}
	card.Foot = `{Format.Number(data.Stacks[id] or 0)} {UI.TipInBag}`
	return card
end

local function boxCard(data: Types.ProfileData, key: string, count: number?): Card
	local card = blank()
	local box = Boxes.Parse(key)
	local have = data.Boxes[key] or 0
	card.Image = Icons.Boxes
	card.Side = if count ~= nil then `x{Format.Number(count)}` else ""
	card.Name = Text.Box(key)
	if box ~= nil then
		local capPct = Formula.Mods.Build(data.SkillTree, data.SkillOff, data.AccountLevel).BoxCapPct
		card.Line = `{Format.Number(have)}/{Format.Number(Boxes.Cap(box.Kind, capPct))} in this stack`
	end
	card.Effect = { UI.TipBoxUse }
	return card
end

local function socketCard(data: Types.ProfileData, item: Types.GearItem, index: number): Card
	local socket = item.Sockets[index]
	local insert = if socket ~= nil then socket.Insert else nil
	local card = if insert ~= nil then materialCard(data, insert, nil) else blank()
	if insert == nil then
		card.ImageText = UI.TipSocket
		card.Name = `{UI.TipSocket} {index}`
		local kind = if socket ~= nil then socket.Kind else nil
		card.Line = if kind ~= nil then `{Text.SocketKind(kind)}  ·  {UI.Empty}` else UI.Empty
		card.Effect = {
			if kind ~= nil then `{UI.TipTakes} {Text.SocketKind(kind)}.` else UI.TipPickKind,
		}
	end
	card.Foot = `{UI.TipSocket} {index} {UI.TipSocketOf} {ItemInfo.Name(item)}`
	card.Item = item
	card.Highlight = index
	return card
end

local function build(data: Types.ProfileData, content: Tip.Content): Card?
	local item = content.Item
	if item ~= nil and content.Live then
		-- Own piece: redraw from the store so an enhance/insert while hovering shows up.
		local fresh = data.Gear[item.Uid]
		if fresh == nil then
			return nil
		end
		item = fresh
	end
	if content.Kind == "Gear" and item ~= nil then
		return gearCard(data, item, content.Wearer)
	elseif content.Kind == "Socket" and item ~= nil and content.Index ~= nil then
		return socketCard(data, item, content.Index)
	elseif content.Kind == "Material" and content.Id ~= nil then
		return materialCard(data, content.Id, content.Count)
	elseif content.Kind == "Box" and content.Id ~= nil then
		return boxCard(data, content.Id, content.Count)
	end
	return nil
end

local function escape(value: string): string
	return (string.gsub(string.gsub(string.gsub(value, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

local function text(value: string, order: number, size: number, color: Color3?, bold: boolean?): React.ReactNode
	return e("TextLabel", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = value,
		TextColor3 = color or Theme.Text,
		FontFace = if bold then Theme.FontBold else Theme.Font,
		TextSize = size,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
	})
end

local function section(title: string, lines: { string }, order: number): React.ReactNode
	local children: { [string]: React.ReactNode } = {
		Layout = Widgets.List(Enum.FillDirection.Vertical, 2),
		Title = text(title, 0, 15, Theme.Text, true),
	}
	for i, line in lines do
		children[`L{i}`] = text(line, i, 14, Theme.Subtext)
	end
	if #lines == 0 then
		children.None = text(UI.TipNone, 1, 14, Theme.Subtext)
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, children)
end

local function sockets(item: Types.GearItem, highlight: number?): React.ReactNode
	local squares: { [string]: React.ReactNode } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, SOCK_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for i = 1, Inserts.MaxSockets do
		local socket = item.Sockets[i]
		local open = socket ~= nil
		local filled = open and socket.Insert ~= nil
		local mark = if open and socket.Kind ~= nil then string.sub(Text.SocketKind(socket.Kind), 1, 1) else ""
		squares[`S{i}`] = e("Frame", {
			Size = UDim2.fromOffset(SOCK, SOCK),
			BackgroundColor3 = if filled then Theme.Accent elseif highlight == i then Theme.Hover else Theme.Bg,
			BackgroundTransparency = if open then 0 else 1,
			LayoutOrder = i,
		}, {
			Corner = Widgets.Corner(4),
			Stroke = Widgets.Stroke(
				if highlight == i then Theme.Accent else Theme.Stroke,
				if highlight == i then 2 else 1.5,
				if open then 0 else 0.6
			),
			Mark = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = mark,
				TextColor3 = if filled then Theme.OnDark else Theme.Subtext,
				FontFace = Theme.FontBold,
				TextSize = 13,
			}),
		})
	end
	return e("Frame", {
		Size = UDim2.new(0, (SOCK + SOCK_GAP) * Inserts.MaxSockets, 1, 0),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
	}, squares)
end

local function render(card: Card): { [string]: React.ReactNode }
	local side: string = card.Side
	local nameW = if #side > 0 then -(IMG + 8 + 60) else -(IMG + 8)
	local powers: string = card.Powers
	-- Trait names follow the name in the accent colour; escape so a name can never break the rich text.
	local title = if #powers > 0
		then `{escape(card.Name)}  <font color="#{Theme.Accent:ToHex()}">{escape(powers)}</font>`
		else escape(card.Name)
	local children: { [string]: React.ReactNode } = {
		Layout = Widgets.List(Enum.FillDirection.Vertical, 8),
		Tag = if card.Tag ~= nil then text(card.Tag, 0, 13, Theme.Accent, true) else nil,
		Head = e("Frame", { Size = UDim2.new(1, 0, 0, IMG), BackgroundTransparency = 1, LayoutOrder = 1 }, {
			Image = e("Frame", { Size = UDim2.fromOffset(IMG, IMG), BackgroundColor3 = Theme.Bg }, {
				Corner = Widgets.Corner(6),
				Stroke = Widgets.Stroke(),
				Icon = if card.Image ~= nil
					then e(Widgets.Icon, {
						image = card.Image,
						size = 32,
						position = UDim2.fromScale(0.5, 0.5),
						anchor = Vector2.new(0.5, 0.5),
					})
					else nil,
				Text = if card.Image == nil
					then e("TextLabel", {
						Size = UDim2.new(1, -4, 1, -4),
						Position = UDim2.fromOffset(2, 2),
						BackgroundTransparency = 1,
						Text = card.ImageText,
						TextColor3 = Theme.Subtext,
						FontFace = Theme.FontBold,
						TextSize = 11,
						TextWrapped = true,
					})
					else nil,
			}),
			Name = e("TextLabel", {
				Size = UDim2.new(1, nameW, 0, 20),
				Position = UDim2.fromOffset(IMG + 8, 8),
				BackgroundTransparency = 1,
				Text = title,
				RichText = true,
				TextColor3 = Theme.Text,
				FontFace = Theme.FontBold,
				TextSize = 17,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			Side = e(Widgets.Label, {
				text = side,
				bold = true,
				textSize = 17,
				color = Theme.Accent,
				align = Enum.TextXAlignment.Right,
				size = UDim2.fromOffset(56, 20),
				position = UDim2.new(1, 0, 0, 8),
				anchor = Vector2.new(1, 0),
			}),
			Line = e(Widgets.Label, {
				text = card.Line,
				textSize = 13,
				color = Theme.Subtext,
				size = UDim2.new(1, -(IMG + 8), 0, 16),
				position = UDim2.fromOffset(IMG + 8, 30),
			}),
		}),
	}
	if card.Item ~= nil or #card.Status > 0 then
		children.Status = section(UI.TipStatus, card.Status, 2)
	end
	if card.Item ~= nil or #card.Effect > 0 then
		children.Effect = section(UI.TipEffect, card.Effect, 3)
	end
	local foot: string = card.Foot
	if #foot > 0 or card.Item ~= nil then
		children.Foot = e("Frame", { Size = UDim2.new(1, 0, 0, SOCK), BackgroundTransparency = 1, LayoutOrder = 4 }, {
			Text = e(Widgets.Label, {
				text = foot,
				textSize = 13,
				color = Theme.Subtext,
				size = UDim2.new(1, if card.Item ~= nil then -(SOCK + SOCK_GAP) * Inserts.MaxSockets - 4 else 0, 1, 0),
			}),
			Sockets = if card.Item ~= nil then sockets(card.Item, card.Highlight) else nil,
		})
	end
	return children
end

type CardProps = {
	card: Card,
	x: number, -- left edge, design units
	bottom: number, -- wanted bottom edge (clamped to the screen with the measured height)
	screenY: number,
	scale: number,
}

-- One card; measures its own height to stay on screen.
local function CardView(props: CardProps): React.ReactNode
	local height, setHeight = React.useState(0)
	local scale = props.scale
	local y = math.clamp(props.bottom - height, MARGIN, math.max(props.screenY - height - MARGIN, MARGIN))
	return e("Frame", {
		Size = UDim2.fromOffset(W, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(props.x, y),
		BackgroundColor3 = Theme.Panel,
		Active = false,
		[React.Change.AbsoluteSize] = function(rbx: Frame)
			setHeight(rbx.AbsoluteSize.Y / scale)
		end,
	}, {
		Corner = Widgets.Corner(8),
		Stroke = Widgets.Stroke(Theme.Outline, 2, 0),
		Padding = Widgets.Padding(PAD),
		Body = e("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, render(props.card)),
	})
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function inside(rbx: GuiObject, p: Vector3): boolean
	local at, size = rbx.AbsolutePosition, rbx.AbsoluteSize
	return p.X >= at.X and p.Y >= at.Y and p.X <= at.X + size.X and p.Y <= at.Y + size.Y
end

local function Tooltip(props: Props): React.ReactNode
	local _, setVersion = React.useState(Tip.Version)
	local rootRef = React.useRef(nil :: Frame?)

	React.useEffect(function()
		return Tip.Subscribe(function()
			setVersion(Tip.Version)
		end)
	end, {})

	local focus = Tip.Focus()
	local hovered = if focus ~= nil and focus ~= Tip.Pinned() then focus.Anchor else nil
	local pinned = Tip.Pinned()
	local pinAnchor = if pinned ~= nil then pinned.Anchor else nil

	-- MouseLeave is missed when the slot is destroyed or the pointer moves fast: hide once the pointer is off the slot.
	React.useEffect(function(): () -> ()
		if hovered == nil then
			return function() end
		end
		local moved = UserInputService.InputChanged:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseMovement and not inside(hovered, input.Position) then
				Tip.Hide(hovered)
			end
		end)
		local gone = hovered.AncestryChanged:Connect(function()
			if not hovered:IsDescendantOf(game) then
				Tip.Hide(hovered)
			end
		end)
		return function()
			moved:Disconnect()
			gone:Disconnect()
		end
	end, { hovered })

	-- A pinned card stays until a press lands somewhere else or its slot goes away.
	React.useEffect(function(): () -> ()
		if pinAnchor == nil then
			return function() end
		end
		local pressed = UserInputService.InputBegan:Connect(function(input: InputObject)
			if isPress(input) and not inside(pinAnchor, input.Position) then
				Tip.Unpin(pinAnchor)
			end
		end)
		local gone = pinAnchor.AncestryChanged:Connect(function()
			if not pinAnchor:IsDescendantOf(game) then
				Tip.Unpin(pinAnchor)
			end
		end)
		return function()
			pressed:Disconnect()
			gone:Disconnect()
		end
	end, { pinAnchor })

	local scale = props.scale
	local root = rootRef.current
	local origin = if root ~= nil then root.AbsolutePosition else Vector2.zero
	local screen = if root ~= nil then root.AbsoluteSize / scale else Vector2.new(1e4, 1e4)
	local children: { [string]: React.ReactNode } = {}

	local anchor = if focus ~= nil then focus.Anchor else nil
	local card = if focus ~= nil
			and anchor ~= nil
			and props.hidden ~= true
			and anchor:IsDescendantOf(game)
		then build(props.data, focus.Content)
		else nil
	if card ~= nil and anchor ~= nil and focus ~= nil then
		-- Pixels -> design units under the root UIScale.
		local at = (anchor.AbsolutePosition - origin) / scale
		local size = anchor.AbsoluteSize / scale
		local bottom = at.Y + size.Y / 2 -- cards rise from the slot's middle
		local right = at.X + size.X + GAP
		local left = at.X - GAP - W
		local onRight = right + W <= screen.X - MARGIN
		local x = math.max(if onRight then right else left, MARGIN)

		-- A bag piece next to what the Team window's hero wears in that slot.
		local item = card.Item
		local worn: Types.GearItem?, heroId: string? = nil, nil
		if focus.Content.Compare and item ~= nil then
			worn, heroId = Equip.Worn(props.data, item)
		end
		if worn ~= nil then
			card = gearCard(props.data, worn, heroId)
			card.Tag = UI.TipEquipped
			local main = build(props.data, focus.Content)
			if main ~= nil then
				local pairX = if onRight then x + W + PAIR_GAP else x - W - PAIR_GAP
				if pairX < MARGIN or pairX + W > screen.X - MARGIN then
					-- No room beside it: the equipped card goes on the slot's other side.
					pairX = math.max(if onRight then left else right, MARGIN)
				end
				children.Main = e(CardView, { card = main, x = x, bottom = bottom, screenY = screen.Y, scale = scale })
				children.Worn =
					e(CardView, { card = card, x = pairX, bottom = bottom, screenY = screen.Y, scale = scale })
			end
		else
			children.Main = e(CardView, { card = card, x = x, bottom = bottom, screenY = screen.Y, scale = scale })
		end
	end

	local dragging = Tip.Dragging()
	if dragging ~= nil then
		local at = (dragging.Position - origin) / scale
		children.Ghost = e("TextLabel", {
			Size = UDim2.fromOffset(GHOST.X, GHOST.Y),
			Position = UDim2.fromOffset(at.X, at.Y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme.Hover,
			BackgroundTransparency = 0.15,
			Text = dragging.Label,
			TextColor3 = Theme.Text,
			FontFace = Theme.Font,
			TextSize = 12,
			TextWrapped = true,
			Active = false,
		}, {
			Corner = Widgets.Corner(6),
			Stroke = Widgets.Stroke(Theme.Accent, 2, 0),
		})
	end

	return e("Frame", {
		ref = rootRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = Theme.ZTooltip,
	}, children)
end

return Tooltip
