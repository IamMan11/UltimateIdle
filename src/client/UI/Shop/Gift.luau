--!strict
-- Gift tab: players in this server, one gift button per game pass (a developer product pays for it).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Text = require(ReplicatedStorage.Shared.Text)
local ShopConfig = require(ReplicatedStorage.Shared.Config.Shop)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local Badge = require(script.Parent.Parent.Core.Badge)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement
local UI = Text.Eco.UI

local ROW_H = 60
local BUTTON_W = 230

local function GiftTab(): React.ReactNode
	local others = Widgets.useOthers()

	local rows: { [string]: React.ReactNode } = {
		Layout = Widgets.List(Enum.FillDirection.Vertical, 8),
		Inset = e("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }),
	}
	if #others == 0 then
		rows.Empty = e(Widgets.Label, {
			text = UI.NobodyHere,
			color = Theme.Subtext,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, -12, 0, 40),
		})
	end
	for i, other in others do
		local children: { [string]: React.ReactNode } = {
			Corner = Widgets.Corner(8),
			Stroke = Widgets.Stroke(),
			Padding = Widgets.Padding(8),
			Who = e(Badge, {
				userId = other.UserId,
				display = other.DisplayName,
				name = other.Name,
				size = UDim2.new(1, -(BUTTON_W + 8) * #ShopConfig.Passes, 1, 0),
			}),
		}
		for n, def in ShopConfig.Passes do
			local productId = ShopConfig.Products[def.GiftProduct] or 0
			children[def.Key] = e(Widgets.Button, {
				text = if productId > 0
					then `{Text.Eco.PassName(def.Key)} · R$ {ShopConfig.RobuxPrices[def.GiftProduct]}`
					else `{Text.Eco.PassName(def.Key)} · {UI.NotForSale}`,
				size = UDim2.fromOffset(BUTTON_W, 40),
				position = UDim2.new(1, -(#ShopConfig.Passes - n) * (BUTTON_W + 8), 0.5, 0),
				anchor = Vector2.new(1, 0.5),
				textSize = 14,
				color = if productId > 0 then Theme.Confirm else nil,
				disabled = productId <= 0,
				onClick = function()
					State.Send.GiftPass(def.Key, other.UserId)
				end,
			})
		end
		rows[`P{other.UserId}`] = e("Frame", {
			Size = UDim2.new(1, -12, 0, ROW_H),
			BackgroundColor3 = Theme.PanelAlt,
			BorderSizePixel = 0,
			LayoutOrder = i,
		}, children)
	end

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Head = e(Widgets.Label, { text = UI.GiftTo, bold = true, textSize = 20, size = UDim2.new(1, 0, 0, 26) }),
		List = e("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, -36),
			Position = UDim2.fromOffset(0, 36),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Stroke,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, rows),
	})
end

return GiftTab
