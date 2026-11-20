--!strict
-- Right-click menu of a gear cell in the Inventory grid (Lock / Unlock · Salvage). Drawn as a child of the cell; each choice starts that mode in Grid.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)

local e = React.createElement
local UI = Text.UI

local WIDTH = 96
local ROW = 30

export type Props = {
	frameRef: { current: Frame? }, -- Grid closes the menu on a press outside this frame
	locked: boolean,
	up: boolean, -- opens above the cell (last rows)
	right: boolean, -- hangs from the cell's right edge (last column)
	onLock: () -> (),
	onSalvage: () -> (),
}

local function GearMenu(props: Props): React.ReactNode
	local up, right = props.up, props.right
	return e("Frame", {
		ref = props.frameRef,
		Size = UDim2.fromOffset(WIDTH, ROW * 2 + 12),
		Position = UDim2.new(if right then 1 else 0, 0, if up then 0 else 1, if up then -6 else 6),
		AnchorPoint = Vector2.new(if right then 1 else 0, if up then 1 else 0),
		BackgroundColor3 = Theme.Panel,
		Active = true,
		ZIndex = 5,
	}, {
		Corner = Widgets.Corner(8),
		Stroke = Widgets.Stroke(),
		Padding = Widgets.Padding(4),
		Layout = Widgets.List(Enum.FillDirection.Vertical, 4),
		Lock = e(Widgets.Button, {
			text = if props.locked then UI.UnlockItem else UI.LockItem,
			size = UDim2.new(1, 0, 0, ROW),
			textSize = 13,
			layoutOrder = 1,
			onClick = props.onLock,
		}),
		Salvage = e(Widgets.Button, {
			text = UI.Salvage,
			size = UDim2.new(1, 0, 0, ROW),
			textSize = 13,
			layoutOrder = 2,
			onClick = props.onSalvage,
		}),
	})
end

return GearMenu
