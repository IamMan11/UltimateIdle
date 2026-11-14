--!strict
-- Passes tab: each game pass (owned or buy) and gifting one to another player in this server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local ShopConfig = require(ReplicatedStorage.Shared.Config.Shop)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement
local UI = Text.Eco.UI

export type Props = { data: Types.ProfileData }

local function PassesTab(_props: Props): React.ReactNode
	local others = Widgets.useOthers()

	local cards: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Horizontal, 12) }
	for _, def in ShopConfig.Passes do
		local owned = State.Passes[def.Key] == true
		cards[def.Key] = e("Frame", {
			Size = UDim2.new(0.5, -6, 1, 0),
			BackgroundColor3 = Theme.PanelAlt,
			LayoutOrder = def.Order,
		}, {
			Corner = Widgets.Corner(8),
			Padding = Widgets.Padding(12),
			Name = e(Widgets.Label, { text = Text.Eco.PassName(def.Key), bold = true, textSize = 20 }),
			Desc = e(Widgets.Label, {
				text = Text.Eco.PassDesc(def.Key),
				color = Theme.Subtext,
				textSize = 15,
				wrap = true,
				size = UDim2.new(1, 0, 0, 40),
				position = UDim2.fromOffset(0, 28),
			}),
			Buy = e(Widgets.Button, {
				text = if owned then UI.Owned elseif def.PassId <= 0 then UI.NotForSale else UI.Buy,
				size = UDim2.new(1, 0, 0, 36),
				position = UDim2.fromScale(0, 1),
				anchor = Vector2.new(0, 1),
				color = if not owned and def.PassId > 0 then Theme.Confirm else nil,
				disabled = owned or def.PassId <= 0,
				onClick = function()
					State.Send.BuyPass(def.Key)
				end,
			}),
		})
	end

	local rows: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Vertical, 6) }
	if #others == 0 then
		rows.Empty = e(Widgets.Label, { text = UI.NobodyHere, color = Theme.Subtext })
	end
	for i, other in others do
		local buttons: { [string]: React.ReactNode } = {
			Layout = Widgets.List(Enum.FillDirection.Horizontal, 8),
		}
		for _, def in ShopConfig.Passes do
			local productId = ShopConfig.Products[def.GiftProduct] or 0
			buttons[def.Key] = e(Widgets.Button, {
				text = if productId > 0
					then `{UI.Gift} {Text.Eco.PassName(def.Key)} · R$ {ShopConfig.RobuxPrices[def.GiftProduct]}`
					else `{UI.Gift} {Text.Eco.PassName(def.Key)} · {UI.NotForSale}`,
				size = UDim2.fromOffset(250, 34),
				textSize = 14,
				disabled = productId <= 0,
				layoutOrder = def.Order,
				onClick = function()
					State.Send.GiftPass(def.Key, other.UserId)
				end,
			})
		end
		rows[`P{other.UserId}`] = e("Frame", {
			Size = UDim2.new(1, -8, 0, 40),
			BackgroundTransparency = 1,
			LayoutOrder = i,
		}, {
			Name = e(Widgets.Label, {
				text = other.DisplayName,
				size = UDim2.new(0, 200, 1, 0),
			}),
			Buttons = e("Frame", {
				Size = UDim2.new(1, -210, 1, 0),
				Position = UDim2.fromOffset(210, 0),
				BackgroundTransparency = 1,
			}, buttons),
		})
	end

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Cards = e("Frame", { Size = UDim2.new(1, 0, 0, 150), BackgroundTransparency = 1 }, cards),
		GiftHead = e(Widgets.Label, {
			text = UI.GiftTo,
			bold = true,
			position = UDim2.fromOffset(0, 164),
		}),
		Gift = e("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, -196),
			Position = UDim2.fromOffset(0, 196),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, rows),
	})
end

return PassesTab
