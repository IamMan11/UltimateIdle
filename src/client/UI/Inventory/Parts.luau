--!strict
-- Small pieces shared by the Inventory window: captioned square slot, "have/need" amount, gear cell text, cost check, scroll body, hint line.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Format = require(ReplicatedStorage.Shared.Format)
local Materials = require(ReplicatedStorage.Shared.Config.Materials)
local Theme = require(script.Parent.Parent.Core.Theme)
local Art = require(script.Parent.Parent.Core.Art)
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
	tier: string?, -- tier of what it holds: rim + text in the tier colour
}

-- Square slot (item, material or result). The frame is `size` wide and CAPTION_H taller when it has a caption.
function Parts.Square(props: SquareProps): React.ReactNode
	local top = if props.caption ~= nil then CAPTION_H else 0
	local accent = Theme.TierAccent(props.tier)
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
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			[React.Event.Activated] = props.onClick,
		}, {
			Art = Art.Back({
				piece = if props.selected then "SlotOrnate" else "SlotPaper",
				transparency = if props.dim then 0.4 else 0,
				edge = Art.FitEdge(if props.selected then "SlotOrnate" else "SlotPaper", props.size),
				padding = 6,
			}),
			Padding = Widgets.Padding(6),
			Rim = Widgets.TierRim(props.tier),
			Label = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = props.text,
				TextColor3 = if accent ~= nil and props.selected
					then accent.Light
					elseif props.selected then Theme.OnDark
					elseif props.dim then Theme.Subtext
					elseif accent ~= nil then accent.Color
					else Theme.Text,
				FontFace = if accent ~= nil then Theme.FontBold else Theme.Font,
				TextSize = Theme.Body(props.textSize or 11),
				TextScaled = true,
				TextWrapped = true,
				ZIndex = 2,
			}, {
				Max = e("UITextSizeConstraint", { MaxTextSize = Theme.Body(props.textSize or 11) }),
				Heavy = if accent ~= nil
					then Widgets.Heavy(
						if props.selected then accent.Light else accent.Color,
						Theme.Body(props.textSize or 11)
					)
					else nil,
			}),
		}),
	})
end

-- "12/40"
function Parts.Amount(have: number, need: number): string
	return `{Format.Number(have)}/{Format.Number(need)}`
end

-- Tier of a material or socket insert id (nil when unknown).
function Parts.MaterialTier(id: string): string?
	local def = Materials.ById[id]
	return if def ~= nil then def.Tier else nil
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
