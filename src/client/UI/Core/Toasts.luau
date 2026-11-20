--!strict
-- Non-blocking toast stack (bottom centre). Never eats clicks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)
local Art = require(script.Parent.Art)
local Widgets = require(script.Parent.Widgets)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement

local function Toasts(): React.ReactNode
	local items: { [string]: React.ReactNode } = {
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
		}),
	}
	for i, toast in State.Ui.Toasts do
		items[`T{toast.Id}`] = e("Frame", {
			Size = UDim2.fromOffset(520, 36),
			BackgroundTransparency = 1,
			LayoutOrder = i,
		}, {
			Art = Art.Back({ piece = "NoticeDark" }),
			Label = e(Widgets.Label, {
				text = toast.Text,
				size = UDim2.new(1, -36, 1, 0),
				position = UDim2.fromOffset(18, 0),
				align = Enum.TextXAlignment.Center,
				color = Theme.OnDark,
				textSize = 16,
			}),
		})
	end
	return e("Frame", {
		Size = UDim2.fromOffset(520, 126),
		Position = UDim2.new(0.5, 0, 1, -110),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		ZIndex = Theme.ZToast,
	}, items)
end

return Toasts
