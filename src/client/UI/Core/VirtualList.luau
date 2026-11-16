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
	initialIndex: number?, -- row scrolled to the top when the list mounts
}

local function VirtualList(props: Props): React.ReactNode
	local start = (math.max(props.initialIndex or 1, 1) - 1) * props.rowHeight
	local total = props.count * props.rowHeight
	local scrollY, setScrollY = React.useState(start)
	local viewH, setViewH = React.useState(400)
	local ref = React.useRef(nil :: ScrollingFrame?)

	-- CanvasPosition and the Absolute* sizes are screen pixels; row offsets are design units (pixels / UIScale of an
	-- ancestor). Pixels per design unit come from the canvas itself; nil while the canvas fits the window (no scrolling).
	local function ratio(frame: ScrollingFrame): number?
		local canvas = frame.AbsoluteCanvasSize.Y
		return if total > 0 and canvas > frame.AbsoluteWindowSize.Y + 0.5 then canvas / total else nil
	end
	local function measure(frame: ScrollingFrame)
		local k = ratio(frame)
		if k ~= nil then
			setScrollY(frame.CanvasPosition.Y / k)
			setViewH(frame.AbsoluteSize.Y / k)
		else
			setScrollY(0)
			setViewH(total)
		end
	end

	React.useEffect(function()
		-- Deferred: the canvas has no absolute size until the frame is laid out.
		local thread = task.defer(function()
			local frame = ref.current
			if frame ~= nil then
				if start > 0 then
					frame.CanvasPosition = Vector2.new(0, start * (ratio(frame) or 1))
				end
				measure(frame)
			end
		end)
		return function()
			task.cancel(thread)
		end
	end, {})

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
		ref = ref,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, total),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Stroke,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		[React.Change.CanvasPosition] = measure,
		[React.Change.AbsoluteSize] = measure,
		[React.Change.AbsoluteCanvasSize] = measure,
	}, rows)
end

return VirtualList
