--!strict
-- Scrolling list that only mounts the rows in view (+ a small margin), for long lists like the 500-slot bag.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)

local e = React.createElement
local MARGIN = 3

export type Props = {
	count: number,
	rowHeight: number,
	renderRow: (index: number) -> React.ReactNode,
	size: UDim2?,
	position: UDim2?,
}

local function VirtualList(props: Props): React.ReactNode
	local scrollY, setScrollY = React.useState(0)
	local viewH, setViewH = React.useState(400)

	local first = math.max(1, math.floor(scrollY / props.rowHeight) + 1 - MARGIN)
	local last = math.min(props.count, math.ceil((scrollY + viewH) / props.rowHeight) + MARGIN)
	local rows: { [string]: React.ReactNode } = {}
	for i = first, last do
		rows[`Row{i}`] = e("Frame", {
			Size = UDim2.new(1, -8, 0, props.rowHeight - 4),
			Position = UDim2.fromOffset(0, (i - 1) * props.rowHeight),
			BackgroundTransparency = 1,
		}, { Content = props.renderRow(i) })
	end

	return e("ScrollingFrame", {
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, props.count * props.rowHeight),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Stroke,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		[React.Change.CanvasPosition] = function(rbx: ScrollingFrame)
			setScrollY(rbx.CanvasPosition.Y)
		end,
		[React.Change.AbsoluteSize] = function(rbx: ScrollingFrame)
			setViewH(rbx.AbsoluteSize.Y)
		end,
	}, rows)
end

return VirtualList
