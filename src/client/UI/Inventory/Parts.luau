--!strict
-- Small pieces shared by the Inventory window: captioned square slot, "have/need" amount, gear cell text, cost check, scroll body, hint line.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Format = require(ReplicatedStorage.Shared.Format)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local ItemInfo = require(script.Parent.Parent.Core.ItemInfo)

local e = React.createElement

local CAPTION_H = 18

local Parts = {}

Parts.CaptionHeight = CAPTION_H

export type SquareProps = {
	text: string,
	caption: string?, -- small label above the square
	size: number,
	position: UDim2?,
	anchor: Vector2?,
	selected: boolean?,
	dim: boolean?, -- empty / unavailable
	onClick: (() -> ())?,
	layoutOrder: number?,
	textSize: number?,
}

-- Square slot (item, material or result). The frame is `size` wide and CAPTION_H taller when it has a caption.
function Parts.Square(props: SquareProps): React.ReactNode
	local top = if props.caption ~= nil then CAPTION_H else 0
	return e("Frame", {
		Size = UDim2.fromOffset(props.size, props.size + top),
		Position = props.position,
		AnchorPoint = props.anchor,
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
	}, {
		Caption = if props.caption ~= nil
			then e(Widgets.Label, {
				text = props.caption,
				color = Theme.Subtext,
				textSize = 13,
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(1, 0, 0, CAPTION_H),
			})
			else nil,
		Box = e("TextButton", {
			Size = UDim2.fromOffset(props.size, props.size),
			Position = UDim2.fromOffset(0, top),
			BackgroundColor3 = if props.selected then Theme.Hover else Theme.PanelAlt,
			BackgroundTransparency = if props.dim then 0.5 else 0,
			AutoButtonColor = props.onClick ~= nil,
			Text = props.text,
			TextColor3 = if props.dim then Theme.Subtext else Theme.Text,
			FontFace = Theme.Font,
			TextSize = props.textSize or 11,
			TextWrapped = true,
			[React.Event.Activated] = props.onClick,
		}, {
			Corner = Widgets.Corner(6),
			Padding = Widgets.Padding(3),
			Stroke = if props.selected then Widgets.Stroke(Theme.Accent, 1.5, 0) else Widgets.Stroke(),
		}),
	})
end

-- "12/40"
function Parts.Amount(have: number, need: number): string
	return `{Format.Number(have)}/{Format.Number(need)}`
end

function Parts.GearText(item: Types.GearItem): string
	return `{ItemInfo.Name(item)}\nLv {item.Level}`
end

-- True when the player holds the gold and every material of a cost.
function Parts.CanPay(data: Types.ProfileData, gold: number, items: { [string]: number }): boolean
	if data.Gold < gold then
		return false
	end
	for id, need in items do
		if (data.Stacks[id] or 0) < need then
			return false
		end
	end
	return true
end

-- Two centred lines: a caption and the amount under it (gold or one material).
function Parts.CostLine(caption: string, amount: string, ok: boolean, position: UDim2): React.ReactNode
	return e("Frame", { Size = UDim2.new(1, 0, 0, 40), Position = position, BackgroundTransparency = 1 }, {
		Caption = e(Widgets.Label, {
			text = caption,
			bold = true,
			textSize = 14,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 18),
		}),
		Amount = e(Widgets.Label, {
			text = amount,
			textSize = 14,
			color = if ok then Theme.Text else Theme.Subtext,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(0, 20),
			size = UDim2.new(1, 0, 0, 18),
		}),
	})
end

-- Vertical scroll body sized to its rows.
function Parts.Scroll(rows: { [string]: React.ReactNode }): React.ReactNode
	return e("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, rows)
end

-- Centred grey hint line in a list.
function Parts.Hint(text: string, order: number): React.ReactNode
	return e(Widgets.Label, {
		text = text,
		color = Theme.Subtext,
		textSize = 13,
		wrap = true,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 32),
		layoutOrder = order,
	})
end

return Parts
