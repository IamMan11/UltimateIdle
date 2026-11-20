--!strict
-- A player in a list or panel (trade, gifting): round avatar, display name, @username.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local e = React.createElement

export type Props = {
	userId: number,
	display: string,
	name: string?, -- username; nil = unknown (the player left)
	avatar: number?, -- avatar size in px
	size: UDim2?,
	position: UDim2?,
}

local function Badge(props: Props): React.ReactNode
	local avatar = props.avatar or 44
	local left = avatar + 10
	return e("Frame", {
		Size = props.size or UDim2.new(1, 0, 0, avatar),
		Position = props.position,
		BackgroundTransparency = 1,
	}, {
		Avatar = e("ImageLabel", {
			Size = UDim2.fromOffset(avatar, avatar),
			BackgroundColor3 = Theme.PanelAlt,
			BorderSizePixel = 0,
			Image = `rbxthumb://type=AvatarHeadShot&id={props.userId}&w=150&h=150`,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Stroke = Widgets.Stroke(Theme.Accent, 2),
		}),
		Display = e(Widgets.Label, {
			text = props.display,
			bold = true,
			size = UDim2.new(1, -left, 0, 22),
			position = UDim2.new(0, left, 0.5, -21),
		}),
		Name = e(Widgets.Label, {
			text = if props.name ~= nil then `@{props.name}` else "",
			textSize = 14,
			color = Theme.Subtext,
			size = UDim2.new(1, -left, 0, 18),
			position = UDim2.new(0, left, 0.5, 2),
		}),
	})
end

return Badge
