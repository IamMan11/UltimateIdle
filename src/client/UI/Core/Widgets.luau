--!strict
-- Shared UI widgets: Label, Icon, Button (raised face on a dark base, optional icon), Window (wood frame + parchment sheet, backdrop/Esc close), TextInput, Stepper, Bar, Tabs; hooks: store, viewport, tick, other players.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)
local Text = require(ReplicatedStorage.Shared.Text)
local State = require(script.Parent.Parent.Parent.State)
local Device = require(script.Parent.Device)

local e = React.createElement

local Widgets = {}

-- Re-renders the caller whenever the client store changes; returns the store version.
function Widgets.useStore(): number
	local version, setVersion = React.useState(State.Version)
	React.useEffect(function()
		return State.Subscribe(function()
			setVersion(State.Version)
		end)
	end, {})
	return version
end

-- Viewport size in pixels, updated on resize/rotation.
function Widgets.useViewport(): Vector2
	local viewport, setViewport = React.useState(Device.Viewport())
	React.useEffect(function(): () -> ()
		local camera = Workspace.CurrentCamera
		local connection = if camera ~= nil
			then camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				setViewport(camera.ViewportSize)
			end)
			else nil
		return function()
			if connection ~= nil then
				connection:Disconnect()
			end
		end
	end, {})
	return viewport
end

-- Re-renders the caller every `interval` seconds while mounted (countdowns); returns os.clock() of the last tick.
function Widgets.useTick(interval: number): number
	local t, setT = React.useState(os.clock())
	React.useEffect(function()
		local alive = true
		task.spawn(function()
			while alive do
				task.wait(interval)
				if alive then
					setT(os.clock())
				end
			end
		end)
		return function()
			alive = false
		end
	end, { interval })
	return t
end

-- Everyone in the server except the local player, kept current as players join and leave.
function Widgets.useOthers(): { Player }
	local function others(): { Player }
		local list: { Player } = {}
		for _, p in Players:GetPlayers() do
			if p ~= Players.LocalPlayer then
				table.insert(list, p)
			end
		end
		table.sort(list, function(a, b)
			return a.DisplayName < b.DisplayName
		end)
		return list
	end
	local list, setList = React.useState(others())
	React.useEffect(function()
		local function refresh()
			setList(others())
		end
		local added = Players.PlayerAdded:Connect(refresh)
		-- Removing fires before the player leaves GetPlayers(): refresh on the next frame.
		local removing = Players.PlayerRemoving:Connect(function()
			task.defer(refresh)
		end)
		return function()
			added:Disconnect()
			removing:Disconnect()
		end
	end, {})
	return list
end

-- useState for an optional value: React's types infer the state type from the initial nil, so the
-- setter would only accept nil. `any` here is only that inference workaround; callers get T? back.
function Widgets.useOptional<T>(initial: T?): (T?, (T?) -> ())
	local value, set = React.useState(initial :: any)
	return value, set
end

function Widgets.Corner(radius: number?): React.ReactNode
	return e("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function Widgets.Stroke(color: Color3?, thickness: number?, transparency: number?): React.ReactNode
	return e("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Widgets.Padding(px: number): React.ReactNode
	local u = UDim.new(0, px)
	return e("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function Widgets.List(
	direction: Enum.FillDirection?,
	padding: number?,
	align: Enum.HorizontalAlignment?
): React.ReactNode
	return e("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	})
end

export type LabelProps = {
	text: string,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	bold: boolean?,
	textSize: number?,
	align: Enum.TextXAlignment?,
	alignY: Enum.TextYAlignment?,
	layoutOrder: number?,
	wrap: boolean?,
}

function Widgets.Label(props: LabelProps): React.ReactNode
	return e("TextLabel", {
		Size = props.size or UDim2.new(1, 0, 0, 22),
		Position = props.position,
		AnchorPoint = props.anchor,
		BackgroundTransparency = 1,
		Text = props.text,
		TextColor3 = props.color or Theme.Text,
		FontFace = if props.bold then Theme.FontBold else Theme.Font,
		TextSize = props.textSize or 18,
		TextXAlignment = props.align or Enum.TextXAlignment.Left,
		TextYAlignment = props.alignY,
		TextWrapped = props.wrap == true,
		TextTruncate = if props.wrap then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
		LayoutOrder = props.layoutOrder,
	})
end

export type IconProps = {
	image: string, -- Config.Icons value
	size: number?,
	position: UDim2?,
	anchor: Vector2?,
	transparency: number?,
	layoutOrder: number?,
}

-- Source art is 32 px pixel art: nearest sampling at 32 px and up, smooth below (nearest drops pixels when shrinking).
function Widgets.Icon(props: IconProps): React.ReactNode
	local size = props.size or 32
	return e("ImageLabel", {
		Size = UDim2.fromOffset(size, size),
		Position = props.position,
		AnchorPoint = props.anchor,
		BackgroundTransparency = 1,
		Image = props.image,
		ImageTransparency = props.transparency or 0,
		ResampleMode = if size >= 32 then Enum.ResamplerMode.Pixelated else Enum.ResamplerMode.Default,
		LayoutOrder = props.layoutOrder,
	})
end

export type ButtonProps = {
	text: string,
	icon: string?, -- Config.Icons value: drawn at the left, text left-aligned after it
	iconSize: number?,
	onClick: (() -> ())?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	textColor: Color3?,
	disabled: boolean?,
	selected: boolean?,
	textSize: number?,
	layoutOrder: number?,
}

-- Button geometry: the face sits BUTTON_LIFT above its dark base, rises on hover, drops onto the base when pressed.
local BUTTON_LIFT = 4
local BUTTON_HOVER = 2
local BUTTON_EDGE = 2
local BUTTON_RADIUS = 10
local BUTTON_TWEEN = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function Widgets.Button(props: ButtonProps): React.ReactNode
	local hovered, setHovered = React.useState(false)
	local pressed, setPressed = React.useState(false)
	local faceRef = React.useRef(nil :: Frame?)
	local disabled = props.disabled == true
	local selected = props.selected == true
	local bg = props.color or (if selected then Theme.Hover else Theme.Button)
	local icon = props.icon
	local iconSize = props.iconSize or 32
	local drop = if disabled or pressed
		then BUTTON_LIFT
		elseif selected then BUTTON_LIFT / 2
		elseif hovered then -BUTTON_HOVER
		else 0
	-- Position is set once by React and moved by the tween afterwards.
	local first = React.useRef(drop)
	React.useEffect(function(): () -> ()
		local face = faceRef.current
		if face == nil or face.Position.Y.Offset == BUTTON_EDGE + drop then
			return function() end
		end
		local tween =
			TweenService:Create(face, BUTTON_TWEEN, { Position = UDim2.fromOffset(BUTTON_EDGE, BUTTON_EDGE + drop) })
		tween:Play()
		return function()
			tween:Cancel()
		end
	end, { drop })

	local left = if icon ~= nil then iconSize + 12 else 6
	return e("TextButton", {
		Size = props.size or UDim2.fromOffset(120, 36),
		Position = props.position,
		AnchorPoint = props.anchor,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Active = not disabled,
		Text = "",
		LayoutOrder = props.layoutOrder,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
			setPressed(false)
		end,
		[React.Event.MouseButton1Down] = function()
			setPressed(true)
		end,
		[React.Event.MouseButton1Up] = function()
			setPressed(false)
		end,
		[React.Event.Activated] = function()
			if not disabled and props.onClick ~= nil then
				props.onClick()
			end
		end,
	}, {
		Base = e("Frame", {
			Size = UDim2.new(1, 0, 1, -BUTTON_LIFT),
			Position = UDim2.fromOffset(0, BUTTON_LIFT),
			BackgroundColor3 = Theme.Outline,
			BorderSizePixel = 0,
			Visible = not disabled,
		}, { Corner = Widgets.Corner(BUTTON_RADIUS) }),
		Face = e("Frame", {
			ref = faceRef,
			Size = UDim2.new(1, -BUTTON_EDGE * 2, 1, -BUTTON_LIFT - BUTTON_EDGE * 2),
			Position = UDim2.fromOffset(BUTTON_EDGE, BUTTON_EDGE + first.current),
			BackgroundColor3 = if disabled then Theme.Disabled else bg,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			Corner = Widgets.Corner(BUTTON_RADIUS - BUTTON_EDGE),
			Stroke = Widgets.Stroke(
				if selected then Theme.Accent else Theme.Outline,
				BUTTON_EDGE,
				if disabled then 0.55 else 0
			),
			Icon = if icon ~= nil
				then e(Widgets.Icon, {
					image = icon,
					size = iconSize,
					position = UDim2.new(0, 6, 0.5, 0),
					anchor = Vector2.new(0, 0.5),
					transparency = if disabled then 0.5 else 0,
				})
				else nil,
			Label = e("TextLabel", {
				Size = UDim2.new(1, -(left + 6), 1, 0),
				Position = UDim2.fromOffset(left, 0),
				BackgroundTransparency = 1,
				Text = props.text,
				TextColor3 = if disabled
					then Theme.Subtext
					else props.textColor or (if bg == Theme.Danger then Theme.OnDark else Theme.Text),
				TextTransparency = if disabled then 0.35 else 0,
				FontFace = Theme.FontBold,
				TextSize = props.textSize or 17,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = if icon ~= nil then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			}),
		}),
	})
end

export type BarProps = {
	ratio: number,
	size: UDim2?,
	position: UDim2?,
	layoutOrder: number?,
}

function Widgets.Bar(props: BarProps): React.ReactNode
	return e("Frame", {
		Size = props.size or UDim2.new(1, 0, 0, 6),
		Position = props.position,
		BackgroundColor3 = Theme.BarBack,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
	}, {
		Corner = Widgets.Corner(3),
		Fill = e("Frame", {
			Size = UDim2.fromScale(math.clamp(props.ratio, 0, 1), 1),
			BackgroundColor3 = Theme.Bar,
			BorderSizePixel = 0,
		}, { Corner = Widgets.Corner(3) }),
	})
end

export type TextInputProps = {
	text: string,
	placeholder: string,
	onChanged: (string) -> (),
	onFocusLost: ((string) -> ())?,
	size: UDim2?,
	position: UDim2?,
}

function Widgets.TextInput(props: TextInputProps): React.ReactNode
	return e("TextBox", {
		Size = props.size or UDim2.new(1, 0, 0, 34),
		Position = props.position,
		BackgroundColor3 = Theme.Bg,
		Text = props.text,
		PlaceholderText = props.placeholder,
		PlaceholderColor3 = Theme.Subtext,
		TextColor3 = Theme.Text,
		FontFace = Theme.Font,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		[React.Change.Text] = function(rbx: TextBox)
			props.onChanged(rbx.Text)
		end,
		[React.Event.FocusLost] = function(rbx: TextBox)
			if props.onFocusLost ~= nil then
				props.onFocusLost(rbx.Text)
			end
		end,
	}, {
		Corner = Widgets.Corner(6),
		Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		Stroke = Widgets.Stroke(),
	})
end

export type StepperProps = {
	value: number,
	min: number,
	max: number,
	onChange: (number) -> (),
	layoutOrder: number?,
}

function Widgets.Stepper(props: StepperProps): React.ReactNode
	return e("Frame", {
		Size = UDim2.fromOffset(120, 32),
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
	}, {
		Layout = Widgets.List(Enum.FillDirection.Horizontal, 4),
		Minus = e(Widgets.Button, {
			text = "-",
			size = UDim2.fromOffset(32, 32),
			layoutOrder = 1,
			disabled = props.value <= props.min,
			onClick = function()
				props.onChange(math.max(props.min, props.value - 1))
			end,
		}),
		Value = e(Widgets.Label, {
			text = tostring(props.value),
			size = UDim2.fromOffset(48, 32),
			align = Enum.TextXAlignment.Center,
			layoutOrder = 2,
		}),
		Plus = e(Widgets.Button, {
			text = "+",
			size = UDim2.fromOffset(32, 32),
			layoutOrder = 3,
			disabled = props.value >= props.max,
			onClick = function()
				props.onChange(math.min(props.max, props.value + 1))
			end,
		}),
	})
end

export type TabsProps = {
	tabs: { { Id: string, Label: string } },
	current: string,
	onSelect: (string) -> (),
	width: number?,
	position: UDim2?,
}

-- Row of tab buttons.
function Widgets.Tabs(props: TabsProps): React.ReactNode
	local buttons: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Horizontal, 8) }
	for i, t in props.tabs do
		buttons[t.Id] = e(Widgets.Button, {
			text = t.Label,
			size = UDim2.fromOffset(props.width or 130, 36),
			selected = props.current == t.Id,
			layoutOrder = i,
			onClick = function()
				props.onSelect(t.Id)
			end,
		})
	end
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		Position = props.position,
		BackgroundTransparency = 1,
	}, buttons)
end

-- Closes on Esc / gamepad B while mounted.
function Widgets.useEscape(onClose: (() -> ())?)
	React.useEffect(function()
		if onClose == nil then
			return function() end
		end
		local connection = UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
				onClose()
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { onClose })
end

export type WindowProps = {
	title: string,
	onClose: (() -> ())?, -- nil = cannot be dismissed (forced choice)
	closeOnBackdrop: boolean?,
	size: UDim2?,
	maxSize: Vector2?,
	zIndex: number?,
	children: any,
}

local WINDOW_RIM = 10
local WINDOW_INSET = 10
local WINDOW_HEADER = 42

-- Parchment sheet inside a wood window frame; content sits on top of it as a sibling.
function Widgets.Sheet(size: UDim2, position: UDim2): React.ReactNode
	return e("Frame", {
		Size = size,
		Position = position,
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		ZIndex = 0,
	}, {
		Corner = Widgets.Corner(8),
		Stroke = Widgets.Stroke(Theme.Outline, 2),
	})
end

-- Page / modal shell: dimmed backdrop that eats clicks, centred window with title + close button + content area.
function Widgets.Window(props: WindowProps): React.ReactNode
	Widgets.useEscape(props.onClose)
	local onClose = props.onClose
	return e("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Backdrop,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Modal = true,
		ZIndex = props.zIndex or Theme.ZPage,
		[React.Event.Activated] = function()
			if props.closeOnBackdrop and onClose ~= nil then
				onClose()
			end
		end,
	}, {
		-- A button (not a Frame) so clicks inside the window never reach the backdrop's close handler.
		Window = e("TextButton", {
			Size = props.size or UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme.Wood,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
		}, {
			Max = e("UISizeConstraint", { MaxSize = props.maxSize or Vector2.new(1100, 720) }),
			Corner = Widgets.Corner(14),
			Stroke = Widgets.Stroke(Theme.Outline, 3),
			Padding = Widgets.Padding(WINDOW_RIM),
			Title = e(Widgets.Label, {
				text = props.title,
				bold = true,
				textSize = 24,
				color = Theme.OnDark,
				position = UDim2.fromOffset(6, 0),
				size = UDim2.new(1, -116, 0, 32),
			}),
			Close = if onClose ~= nil
				then e(Widgets.Button, {
					text = Text.UI.Close,
					size = UDim2.fromOffset(96, 32),
					position = UDim2.fromScale(1, 0),
					anchor = Vector2.new(1, 0),
					onClick = onClose,
				})
				else nil,
			Sheet = Widgets.Sheet(UDim2.new(1, 0, 1, -WINDOW_HEADER), UDim2.fromOffset(0, WINDOW_HEADER)),
			Content = e("Frame", {
				Size = UDim2.new(1, -WINDOW_INSET * 2, 1, -(WINDOW_HEADER + WINDOW_INSET * 2)),
				Position = UDim2.fromOffset(WINDOW_INSET, WINDOW_HEADER + WINDOW_INSET),
				BackgroundTransparency = 1,
				ZIndex = 2,
			}, props.children),
		}),
	})
end

return Widgets
