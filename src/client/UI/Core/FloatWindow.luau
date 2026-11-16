--!strict
-- Floating page window (no backdrop): moves by its title bar, resizes from edges and corners, keeps its centre + size per id in Settings.Windows. Esc / Close closes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)
local Device = require(script.Parent.Device)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement

local PAD = 14
local HEADER = 40
-- Parchment sheet behind the content: gap to the wood edge, and how far it reaches past the content.
local SHEET_RIM = 6
local SHEET_INSET = 8
-- Grab zones: edges resize one side, corners two.
local EDGE = 8
local CORNER = 14
-- Pixels of the window that always stay on screen while moving it.
local KEEP_VISIBLE = 60
local MAX_DEFAULT = 0.96
local DEFAULT_MIN = Vector2.new(720, 420)

export type Props = {
	id: string, -- Config.Game.Windows entry
	title: string,
	onClose: () -> (),
	defaultSize: Vector2, -- design units (before the UI scale)
	minSize: Vector2?,
	zIndex: number?, -- Theme.ZPage when nil; a window opened over another passes a higher one
	closeOnEscape: boolean?, -- false while another window on top should take Esc
	children: any,
}

-- Centre and size as fractions of the screen.
type Rect = { Center: Vector2, Size: Vector2 }
type Sides = { L: boolean, R: boolean, T: boolean, B: boolean }
type Drag = {
	Start: Vector2,
	Left: number,
	Top: number,
	Right: number,
	Bottom: number,
	Sides: Sides?, -- nil = moving
	KeepDefault: boolean, -- moved without ever being resized: stays at the default size
	Last: Rect?,
}

type Handle = { Name: string, Sides: Sides, Size: UDim2, Position: UDim2, Anchor: Vector2, Z: number }

local function sides(l: boolean, r: boolean, t: boolean, b: boolean): Sides
	return { L = l, R = r, T = t, B = b }
end

local HANDLES: { Handle } = {
	{
		Name = "L",
		Sides = sides(true, false, false, false),
		Size = UDim2.new(0, EDGE, 1, 0),
		Position = UDim2.fromScale(0, 0),
		Anchor = Vector2.new(0, 0),
		Z = 3,
	},
	{
		Name = "R",
		Sides = sides(false, true, false, false),
		Size = UDim2.new(0, EDGE, 1, 0),
		Position = UDim2.fromScale(1, 0),
		Anchor = Vector2.new(1, 0),
		Z = 3,
	},
	{
		Name = "T",
		Sides = sides(false, false, true, false),
		Size = UDim2.new(1, 0, 0, EDGE),
		Position = UDim2.fromScale(0, 0),
		Anchor = Vector2.new(0, 0),
		Z = 3,
	},
	{
		Name = "B",
		Sides = sides(false, false, false, true),
		Size = UDim2.new(1, 0, 0, EDGE),
		Position = UDim2.fromScale(0, 1),
		Anchor = Vector2.new(0, 1),
		Z = 3,
	},
	{
		Name = "TL",
		Sides = sides(true, false, true, false),
		Size = UDim2.fromOffset(CORNER, CORNER),
		Position = UDim2.fromScale(0, 0),
		Anchor = Vector2.new(0, 0),
		Z = 4,
	},
	{
		Name = "TR",
		Sides = sides(false, true, true, false),
		Size = UDim2.fromOffset(CORNER, CORNER),
		Position = UDim2.fromScale(1, 0),
		Anchor = Vector2.new(1, 0),
		Z = 4,
	},
	{
		Name = "BL",
		Sides = sides(true, false, false, true),
		Size = UDim2.fromOffset(CORNER, CORNER),
		Position = UDim2.fromScale(0, 1),
		Anchor = Vector2.new(0, 1),
		Z = 4,
	},
	{
		Name = "BR",
		Sides = sides(false, true, false, true),
		Size = UDim2.fromOffset(CORNER, CORNER),
		Position = UDim2.fromScale(1, 1),
		Anchor = Vector2.new(1, 1),
		Z = 4,
	},
}

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- Like math.clamp, but a crossed range (window larger than the screen) gives `low` instead of an error.
local function clamp(value: number, low: number, high: number): number
	return math.max(low, math.min(value, high))
end

local function FloatWindow(props: Props): React.ReactNode
	Widgets.useEscape(if props.closeOnEscape == false then nil else props.onClose)
	local viewport = Widgets.useViewport()
	local data = State.Data
	local scale = Device.Scale(viewport, if data ~= nil then data.Settings.UiScale else 1)
	local area = viewport / scale
	local saved: { number }? = if data ~= nil then data.Settings.Windows[props.id] else nil
	local savedW, savedH = 0, 0
	if saved ~= nil then
		savedW, savedH = saved[3] or 0, saved[4] or 0
	end
	local hasSize = savedW > 0 and savedH > 0

	local live, setLive = Widgets.useOptional(nil :: Rect?)
	local dragging, setDragging = React.useState(false)
	-- The live drag: input handlers read and write this (state is only for drawing).
	local dragRef = React.useRef(nil :: Drag?)
	local rootRef = React.useRef(nil :: TextButton?)

	local minSize = props.minSize or DEFAULT_MIN
	local minPx = minSize * scale
	local id = props.id

	local rect: Rect
	if live ~= nil then
		rect = live
	else
		local minFraction = Vector2.new(math.min(minSize.X / area.X, 1), math.min(minSize.Y / area.Y, 1))
		local size = if hasSize
			then Vector2.new(savedW, savedH)
			else Vector2.new(
				math.min(props.defaultSize.X / area.X, MAX_DEFAULT),
				math.min(props.defaultSize.Y / area.Y, MAX_DEFAULT)
			)
		rect = {
			Center = if saved ~= nil
				then Vector2.new(clamp(saved[1] or 0.5, 0, 1), clamp(saved[2] or 0.5, 0, 1))
				else Vector2.new(0.5, 0.5),
			Size = Vector2.new(clamp(size.X, minFraction.X, 1), clamp(size.Y, minFraction.Y, 1)),
		}
	end

	local function begin(input: InputObject, grabbed: Sides?)
		local frame = rootRef.current
		if dragRef.current ~= nil or frame == nil or not isPointer(input) then
			return
		end
		local screen = frame.Parent
		if screen == nil or not screen:IsA("GuiObject") then
			return
		end
		local from = frame.AbsolutePosition - screen.AbsolutePosition
		local to = from + frame.AbsoluteSize
		dragRef.current = {
			Start = Vector2.new(input.Position.X, input.Position.Y),
			Left = from.X,
			Top = from.Y,
			Right = to.X,
			Bottom = to.Y,
			Sides = grabbed,
			KeepDefault = grabbed == nil and not hasSize,
			Last = nil,
		}
		setDragging(true)
	end

	React.useEffect(function(): () -> ()
		if not dragging then
			return function() end
		end
		local changed = UserInputService.InputChanged:Connect(function(input: InputObject)
			local d = dragRef.current
			local frame = rootRef.current
			local screen = if frame ~= nil then frame.Parent else nil
			if d == nil or screen == nil or not screen:IsA("GuiObject") then
				return
			end
			local t = input.UserInputType
			if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then
				return
			end
			local view = screen.AbsoluteSize
			if view.X <= 0 or view.Y <= 0 then
				return
			end
			local delta = Vector2.new(input.Position.X, input.Position.Y) - d.Start
			local l, top, r, b = d.Left, d.Top, d.Right, d.Bottom
			local s = d.Sides
			if s ~= nil then
				local minW, minH = math.min(minPx.X, view.X), math.min(minPx.Y, view.Y)
				if s.L then
					l = clamp(l + delta.X, 0, r - minW)
				end
				if s.R then
					r = clamp(r + delta.X, l + minW, view.X)
				end
				if s.T then
					top = clamp(top + delta.Y, 0, b - minH)
				end
				if s.B then
					b = clamp(b + delta.Y, top + minH, view.Y)
				end
			else
				local half = Vector2.new(r - l, b - top) / 2
				-- The title bar never leaves the top of the screen; a strip of the window stays visible on the other sides.
				local midX = clamp((l + r) / 2 + delta.X, KEEP_VISIBLE - half.X, view.X - KEEP_VISIBLE + half.X)
				local midY = clamp((top + b) / 2 + delta.Y, half.Y, view.Y - KEEP_VISIBLE + half.Y)
				l, r, top, b = midX - half.X, midX + half.X, midY - half.Y, midY + half.Y
			end
			local nextRect: Rect = {
				Center = Vector2.new(clamp((l + r) / 2 / view.X, 0, 1), clamp((top + b) / 2 / view.Y, 0, 1)),
				Size = Vector2.new(clamp((r - l) / view.X, 0, 1), clamp((b - top) / view.Y, 0, 1)),
			}
			d.Last = nextRect
			setLive(nextRect)
		end)
		local ended = UserInputService.InputEnded:Connect(function(input: InputObject)
			local d = dragRef.current
			if d == nil or not isPointer(input) then
				return
			end
			dragRef.current = nil
			setDragging(false)
			local last = d.Last
			if last ~= nil then
				local size = if d.KeepDefault then Vector2.zero else last.Size
				State.SetWindow(id, last.Center.X, last.Center.Y, size.X, size.Y)
			end
			setLive(nil)
		end)
		return function()
			changed:Disconnect()
			ended:Disconnect()
		end
	end, { dragging })

	local children: { [string]: React.ReactNode } = {
		Corner = Widgets.Corner(14),
		Stroke = Widgets.Stroke(Theme.Outline, 3),
		Sheet = Widgets.Sheet(
			UDim2.new(1, -SHEET_RIM * 2, 1, -(PAD + HEADER - SHEET_INSET + SHEET_RIM)),
			UDim2.fromOffset(SHEET_RIM, PAD + HEADER - SHEET_INSET)
		),
		TitleBar = e("TextButton", {
			Size = UDim2.new(1, 0, 0, PAD + HEADER),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			[React.Event.InputBegan] = function(_rbx: TextButton, input: InputObject)
				begin(input, nil)
			end,
		}, {
			Title = e(Widgets.Label, {
				text = props.title,
				bold = true,
				textSize = 22,
				color = Theme.OnDark,
				position = UDim2.fromOffset(PAD, PAD),
				size = UDim2.new(1, -(PAD * 2 + 250), 0, 30),
			}),
		}),
		Buttons = e("Frame", {
			Size = UDim2.fromOffset(236, 30),
			Position = UDim2.new(1, -PAD, 0, PAD),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, {
			Reset = e(Widgets.Button, {
				text = Text.UI.ResetWindow,
				size = UDim2.fromOffset(132, 30),
				textSize = 14,
				disabled = saved == nil,
				onClick = function()
					State.SetWindow(id, 0.5, 0.5, 0, 0)
				end,
			}),
			Close = e(Widgets.Button, {
				text = Text.UI.Close,
				size = UDim2.fromOffset(96, 30),
				position = UDim2.fromScale(1, 0),
				anchor = Vector2.new(1, 0),
				onClick = props.onClose,
			}),
		}),
		Content = e("Frame", {
			Size = UDim2.new(1, -PAD * 2, 1, -(PAD * 2 + HEADER)),
			Position = UDim2.fromOffset(PAD, PAD + HEADER),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = 2,
		}, props.children),
		Grip = e(Widgets.Label, {
			text = "///",
			color = Theme.Subtext,
			textSize = 11,
			align = Enum.TextXAlignment.Right,
			size = UDim2.fromOffset(20, 12),
			position = UDim2.new(1, -3, 1, -1),
			anchor = Vector2.new(1, 1),
		}),
	}
	for _, handle in HANDLES do
		children["Resize" .. handle.Name] = e("TextButton", {
			Size = handle.Size,
			Position = handle.Position,
			AnchorPoint = handle.Anchor,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			ZIndex = handle.Z,
			[React.Event.InputBegan] = function(_rbx: TextButton, input: InputObject)
				begin(input, handle.Sides)
			end,
		})
	end

	-- A button (not a Frame) so clicks inside the window never reach the game behind it.
	return e("TextButton", {
		ref = rootRef,
		Size = UDim2.fromScale(rect.Size.X, rect.Size.Y),
		Position = UDim2.fromScale(rect.Center.X, rect.Center.Y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Wood,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = props.zIndex or Theme.ZPage,
	}, children)
end

return FloatWindow
