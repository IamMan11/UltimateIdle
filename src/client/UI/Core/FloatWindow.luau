--!strict
-- Floating window (no backdrop, several open at once, order in State.Ui.Windows): moves by its title bar, resizes from edges and corners (everything inside scales with the size), keeps its centre + size per id in Settings.Windows. Esc closes the top one; Close closes this one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.Theme)
local Art = require(script.Parent.Art)
local Widgets = require(script.Parent.Widgets)
local Device = require(script.Parent.Device)
local WindowStack = require(script.Parent.WindowStack)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement

-- Frame art insets (Widgets.WINDOW_*): leather title band, then the paper body inside its ink rule.
local HEAD = Widgets.WINDOW_HEADER
local SIDE = Widgets.WINDOW_SIDE
local TOP = Widgets.WINDOW_TOP
local BOTTOM = Widgets.WINDOW_BOTTOM
local ORNAMENT = Widgets.WINDOW_ORNAMENT
-- Pages were laid out for the old wood frame (14 rim, 40 header): the frame grows by the difference so content keeps its room.
local GROW = Vector2.new(SIDE * 2 - 28, TOP + BOTTOM - 68)
-- Grab zones: edges resize one side, corners two.
local EDGE = 8
local CORNER = 14
-- Pixels of the window that always stay on screen while moving it.
local KEEP_VISIBLE = 60
local MAX_DEFAULT = 0.96
local DEFAULT_MIN = Vector2.new(720, 420)
-- `fit` content never grows past this (a huge window would blow the text up).
local FIT_MAX = 1.6
-- Whole-window scale range when resizing.
local SCALE_MIN, SCALE_MAX = 0.3, 1.6

-- Resizing scales the whole window (frame, text, content) by the smaller of width / height against defaultSize:
-- the layout inside always gets at least defaultSize, so nothing overlaps; the longer side gets the extra room.
local function scaleFor(drawn: Vector2, defaultSize: Vector2): number
	return math.clamp(math.min(drawn.X / defaultSize.X, drawn.Y / defaultSize.Y), SCALE_MIN, SCALE_MAX)
end

export type Props = {
	id: string, -- State.Ui.Windows id; also the Settings.Windows key unless saveId is given
	saveId: string?, -- Config.Game.Windows entry the place is saved under (one window with two layouts, e.g. Trade)
	title: string,
	onClose: () -> (),
	defaultSize: Vector2, -- design units (before the UI scale)
	minSize: Vector2?,
	fit: Vector2?, -- fixed-layout content: laid out at this size, then scaled to fit the window (centred)
	defaultCenter: Vector2?, -- screen fractions before the player moves it (default: middle)
	zoom: number?, -- opens the window at defaultSize x zoom on screen (minSize too); see `scaleFor`
	-- Modal: drawn over an invisible backdrop that blocks everything below (click on it = onClose); takes Esc while up. Mounted by App outside State.Ui.Windows.
	modal: boolean?,
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

-- Grab zones sized in the window's own (zoomed) units so they stay EDGE / CORNER wide on screen.
local function handles(edge: number, corner: number): { Handle }
	return {
		{
			Name = "L",
			Sides = sides(true, false, false, false),
			Size = UDim2.new(0, edge, 1, 0),
			Position = UDim2.fromScale(0, 0),
			Anchor = Vector2.new(0, 0),
			Z = 3,
		},
		{
			Name = "R",
			Sides = sides(false, true, false, false),
			Size = UDim2.new(0, edge, 1, 0),
			Position = UDim2.fromScale(1, 0),
			Anchor = Vector2.new(1, 0),
			Z = 3,
		},
		{
			Name = "T",
			Sides = sides(false, false, true, false),
			Size = UDim2.new(1, 0, 0, edge),
			Position = UDim2.fromScale(0, 0),
			Anchor = Vector2.new(0, 0),
			Z = 3,
		},
		{
			Name = "B",
			Sides = sides(false, false, false, true),
			Size = UDim2.new(1, 0, 0, edge),
			Position = UDim2.fromScale(0, 1),
			Anchor = Vector2.new(0, 1),
			Z = 3,
		},
		{
			Name = "TL",
			Sides = sides(true, false, true, false),
			Size = UDim2.fromOffset(corner, corner),
			Position = UDim2.fromScale(0, 0),
			Anchor = Vector2.new(0, 0),
			Z = 4,
		},
		{
			Name = "TR",
			Sides = sides(false, true, true, false),
			Size = UDim2.fromOffset(corner, corner),
			Position = UDim2.fromScale(1, 0),
			Anchor = Vector2.new(1, 0),
			Z = 4,
		},
		{
			Name = "BL",
			Sides = sides(true, false, false, true),
			Size = UDim2.fromOffset(corner, corner),
			Position = UDim2.fromScale(0, 1),
			Anchor = Vector2.new(0, 1),
			Z = 4,
		},
		{
			Name = "BR",
			Sides = sides(false, true, false, true),
			Size = UDim2.fromOffset(corner, corner),
			Position = UDim2.fromScale(1, 1),
			Anchor = Vector2.new(1, 1),
			Z = 4,
		},
	}
end

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- Like math.clamp, but a crossed range (window larger than the screen) gives `low` instead of an error.
local function clamp(value: number, low: number, high: number): number
	return math.max(low, math.min(value, high))
end

local function FloatWindow(props: Props): React.ReactNode
	local onTop = if props.modal
		then State.Ui.Confirm == nil
		else State.TopWindow() == props.id and not State.ModalOpen()
	Widgets.useEscape(if onTop then props.onClose else nil)
	local viewport = Widgets.useViewport()
	local data = State.Data
	local scale = Device.Scale(viewport, if data ~= nil then data.Settings.UiScale else 1)
	-- The ScreenGui stops below the top-bar inset: screen fractions are of that area, not the full viewport.
	local insetTop, insetBottom = GuiService:GetGuiInset()
	local area = (viewport - insetTop - insetBottom) / scale
	local saveId = props.saveId or props.id
	local saved: { number }? = if data ~= nil then data.Settings.Windows[saveId] else nil
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

	local zoom = props.zoom or 1
	-- Sizes below are as drawn (after zoom).
	local minSize = ((props.minSize or DEFAULT_MIN) + GROW) * zoom
	local baseSize = props.defaultSize + GROW
	local defaultSize = baseSize * zoom
	local minPx = minSize * scale
	local id = saveId

	React.useEffect(function(): () -> ()
		local frame = rootRef.current
		if frame == nil then
			return function() end
		end
		WindowStack.Register(props.id, frame)
		return function()
			WindowStack.Unregister(props.id, frame)
		end
	end, { props.id })

	local rect: Rect
	if live ~= nil then
		rect = live
	else
		local minFraction = Vector2.new(math.min(minSize.X / area.X, 1), math.min(minSize.Y / area.Y, 1))
		local size = if hasSize
			then Vector2.new(savedW, savedH)
			else Vector2.new(
				math.min(defaultSize.X / area.X, MAX_DEFAULT),
				math.min(defaultSize.Y / area.Y, MAX_DEFAULT)
			)
		local fitted = Vector2.new(clamp(size.X, minFraction.X, 1), clamp(size.Y, minFraction.Y, 1))
		local center = if saved ~= nil
			then Vector2.new(saved[1] or 0.5, saved[2] or 0.5)
			else props.defaultCenter or Vector2.new(0.5, 0.5)
		-- Opened (not being dragged): the whole window stays on screen, whatever the screen or UI size became.
		rect = {
			Center = Vector2.new(
				clamp(center.X, fitted.X / 2, 1 - fitted.X / 2),
				clamp(center.Y, fitted.Y / 2, 1 - fitted.Y / 2)
			),
			Size = fitted,
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

	local content: any = props.children
	local k = scaleFor(rect.Size * area, baseSize)
	local fit = props.fit
	if fit ~= nil then
		local avail = rect.Size * area / k - Vector2.new(SIDE * 2, TOP + BOTTOM)
		local fitScale = math.clamp(math.min(avail.X / fit.X, avail.Y / fit.Y), 0.05, FIT_MAX)
		content = {
			Fit = e("Frame", {
				Size = UDim2.fromOffset(fit.X, fit.Y),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
			}, {
				Scale = e("UIScale", { Scale = fitScale }),
				Body = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, props.children),
			}),
		}
	end

	local children: { [string]: React.ReactNode } = {
		-- Laid out 1/k larger, drawn at k: the window keeps rect's size on screen.
		Zoom = if k ~= 1 then e("UIScale", { Scale = k }) else nil,
		Art = Art.Back({ piece = "MainWindow" }),
		TitleBar = e("TextButton", {
			Size = UDim2.new(1, 0, 0, HEAD),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 2,
			[React.Event.InputBegan] = function(_rbx: TextButton, input: InputObject)
				begin(input, nil)
			end,
		}, {
			Title = e("TextLabel", {
				Text = props.title,
				Size = UDim2.new(1, -(ORNAMENT * 2 + 190), 0, HEAD - 14),
				Position = UDim2.fromOffset(ORNAMENT, 6),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Gold,
				FontFace = Theme.FontTitle,
				TextSize = Theme.Title(28),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
		}),
		Buttons = e("Frame", {
			Size = UDim2.fromOffset(176, 34),
			Position = UDim2.new(1, -ORNAMENT, 0, 15),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, {
			Reset = e(Widgets.Button, {
				text = Text.UI.ResetWindow,
				size = UDim2.fromOffset(134, 30),
				position = UDim2.fromOffset(0, 2),
				textSize = 13,
				disabled = saved == nil,
				onClick = function()
					local home = props.defaultCenter or Vector2.new(0.5, 0.5)
					State.SetWindow(id, home.X, home.Y, 0, 0)
				end,
			}),
			Close = e(Widgets.CloseButton, {
				onClick = props.onClose,
				position = UDim2.fromScale(1, 0),
				anchor = Vector2.new(1, 0),
			}),
		}),
		Content = e("Frame", {
			Size = UDim2.new(1, -SIDE * 2, 1, -(TOP + BOTTOM)),
			Position = UDim2.fromOffset(SIDE, TOP),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = 2,
		}, content),
		Grip = e(Widgets.Label, {
			text = "///",
			color = Theme.Subtext,
			textSize = 11,
			align = Enum.TextXAlignment.Right,
			size = UDim2.fromOffset(20, 12),
			position = UDim2.new(1, -SIDE, 1, -8),
			anchor = Vector2.new(1, 1),
		}),
	}
	for _, handle in handles(EDGE / k, CORNER / k) do
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
	local window = e("TextButton", {
		ref = rootRef,
		Size = UDim2.fromScale(rect.Size.X / k, rect.Size.Y / k),
		Position = UDim2.fromScale(rect.Center.X, rect.Center.Y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
	}, children)
	if not props.modal then
		return window
	end
	-- Invisible: no dimming, it only eats clicks below the modal.
	return e("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Modal = true,
		[React.Event.Activated] = props.onClose,
	}, { Window = window })
end

return FloatWindow
