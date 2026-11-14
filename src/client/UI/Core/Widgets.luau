--!strict
-- Shared UI widgets: Label, Button, Window (page shell with backdrop/Esc close), TextInput, Stepper, Bar, Tabs; hooks: store, tick, other players.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)
local Text = require(ReplicatedStorage.Shared.Text)
local State = require(script.Parent.Parent.Parent.State)

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
		Thickness = thickness or 1,
		Transparency = transparency or 0.4,
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
		TextWrapped = props.wrap == true,
		TextTruncate = if props.wrap then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
		LayoutOrder = props.layoutOrder,
	})
end

export type ButtonProps = {
	text: string,
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

function Widgets.Button(props: ButtonProps): React.ReactNode
	local bg = props.color or (if props.selected then Theme.Hover else Theme.PanelAlt)
	local light = bg == Theme.Confirm
	return e("TextButton", {
		Size = props.size or UDim2.fromOffset(120, 36),
		Position = props.position,
		AnchorPoint = props.anchor,
		BackgroundColor3 = bg,
		BackgroundTransparency = if props.disabled then 0.6 else 0,
		AutoButtonColor = not props.disabled,
		Active = not props.disabled,
		Text = props.text,
		TextColor3 = props.textColor or (if light then Theme.OnLight else Theme.Text),
		TextTransparency = if props.disabled then 0.5 else 0,
		FontFace = Theme.FontBold,
		TextSize = props.textSize or 17,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = props.layoutOrder,
		[React.Event.Activated] = function()
			if not props.disabled and props.onClick ~= nil then
				props.onClick()
			end
		end,
	}, {
		Corner = Widgets.Corner(6),
		Stroke = if props.selected then Widgets.Stroke(Theme.Accent, 1.5, 0) else nil,
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
			BackgroundColor3 = Theme.Panel,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
		}, {
			Max = e("UISizeConstraint", { MaxSize = props.maxSize or Vector2.new(1100, 720) }),
			Corner = Widgets.Corner(12),
			Stroke = Widgets.Stroke(),
			Padding = Widgets.Padding(16),
			Title = e(Widgets.Label, {
				text = props.title,
				bold = true,
				textSize = 24,
				size = UDim2.new(1, -110, 0, 32),
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
			Content = e("Frame", {
				Size = UDim2.new(1, 0, 1, -44),
				Position = UDim2.fromOffset(0, 44),
				BackgroundTransparency = 1,
			}, props.children),
		}),
	})
end

return Widgets
