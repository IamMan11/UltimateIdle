--!strict
-- Shared UI widgets: Label (Michroma body, Grenze Gotisch headings), Icon, Button (paper / gilt frame art, optional icon), CloseButton, Window (leather header + paper sheet art, backdrop/Esc close), TextInput, Stepper, Bar, Tabs; hooks: store, viewport, tick, other players.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)
local Art = require(script.Parent.Art)
local Rich = require(script.Parent.Rich)
local Motion = require(script.Parent.Motion)
local State = require(script.Parent.Parent.Parent.State)
local Device = require(script.Parent.Device)
local Tip = require(script.Parent.Tip)

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

-- Bold weight for Michroma (one face only): a stroke in the text's own colour thickens the glyphs.
function Widgets.Heavy(color: Color3, size: number, transparency: number?): React.ReactNode
	return e("UIStroke", {
		Color = color,
		Thickness = Theme.Heavy(size),
		Transparency = transparency or 0,
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

-- Tier rim for an item slot: a solid line in the tier colour, over the slot art (ZIndex 1) and under its text
-- (ZIndex 2); nil for anything without a tier.
function Widgets.TierRim(tier: string?, inset: number?): React.ReactNode
	local accent = Theme.TierAccent(tier)
	if accent == nil then
		return nil
	end
	local pad = inset or 0
	return e("Frame", {
		Size = UDim2.new(1, -pad * 2, 1, -pad * 2),
		Position = UDim2.fromOffset(pad, pad),
		BackgroundTransparency = 1,
		ZIndex = 1,
	}, {
		Corner = Widgets.Corner(6),
		Stroke = e("UIStroke", {
			Color = accent.Color,
			Thickness = 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
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
	stat: boolean?, -- colour stat phrases and tier names (Core/Rich)
	accent: Theme.Accent?, -- whole label in an accent colour (tier names, headline stats)
}

-- Single-line text that is too long shrinks (down to 70 %) instead of being cut: TextScaled under a size cap.
function Widgets.Shrink(textSize: number): React.ReactNode
	return e("UITextSizeConstraint", {
		MaxTextSize = textSize,
		MinTextSize = math.max(8, math.floor(textSize * 0.7)),
	})
end

-- Bold labels at 20+ are headings: drawn in the title face (Grenze Gotisch); everything else is body text (Michroma).
-- Single-line labels shrink to fit (Widgets.Shrink); wrapped ones keep their size.
function Widgets.Label(props: LabelProps): React.ReactNode
	local size = props.textSize or 18
	local heading = props.bold == true and size >= 20
	local drawn = if heading then Theme.Title(size) else Theme.Body(size)
	local wrap = props.wrap == true
	local color = props.color or Theme.Text
	local accent = props.accent
	local fill = if accent ~= nil then (if Theme.IsLight(color) then accent.Light else accent.Color) else color
	-- Bold body text and accent labels are drawn heavy; stat labels bolden their own phrases (Core/Rich).
	local heavy = not heading and props.stat ~= true and (props.bold == true or accent ~= nil)
	return e("TextLabel", {
		Size = props.size or UDim2.new(1, 0, 0, 22),
		Position = props.position,
		AnchorPoint = props.anchor,
		BackgroundTransparency = 1,
		Text = if props.stat then Rich.Stats(props.text, Theme.IsLight(color), drawn) else props.text,
		RichText = props.stat == true,
		TextColor3 = fill,
		FontFace = if heading then Theme.FontTitle elseif props.bold then Theme.FontBold else Theme.Font,
		TextSize = drawn,
		TextScaled = not wrap,
		TextXAlignment = props.align or Enum.TextXAlignment.Left,
		TextYAlignment = props.alignY,
		TextWrapped = wrap,
		LayoutOrder = props.layoutOrder,
	}, {
		Fit = if wrap then nil else Widgets.Shrink(drawn),
		Heavy = if heavy then Widgets.Heavy(fill, drawn) else nil,
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
	tip: Tip.Content?, -- hover tooltip (Core/Tooltip)
}

-- Every button is the gilt leather plate (gold text). `selected = false` = an idle tab / toggle: dimmer plate and
-- text, full gold on hover. Danger / confirm colours tint the plate; disabled is a greyed plate.
function Widgets.Button(props: ButtonProps): React.ReactNode
	local hovered, setHovered = React.useState(false)
	local pressed, setPressed = React.useState(false)
	local disabled = props.disabled == true
	local idle = props.selected == false and not hovered
	local color = props.color
	local danger = color == Theme.Danger
	local confirm = color == Theme.Confirm
	local down = pressed and not disabled
	local labelColor = if disabled or idle
		then Theme.OnDarkIdle
		elseif props.textColor == Theme.Subtext then Theme.OnDarkSub
		elseif danger then Theme.DangerTint
		else Theme.Gold
	local state = if down then "Pressed" elseif hovered and not disabled then "Hover" else "Normal"
	local size = props.size or UDim2.fromOffset(120, 36)
	-- Narrow buttons (arrows, toggles) use the square plate: the wide plate's end studs would crowd the label.
	local narrow = size.X.Scale == 0 and size.Y.Scale == 0 and size.X.Offset <= size.Y.Offset * 1.2
	local piece = if narrow then "BtnSquareGilt" else "BtnGilt" .. state
	local tint = if disabled
		then Theme.DisabledTint
		elseif idle then Theme.IdleTint
		elseif danger then Theme.DangerTint
		elseif confirm then Theme.ConfirmTint
		else nil
	local scale = Motion.useButton(hovered and not disabled, down)
	local height = if size.Y.Scale == 0 then size.Y.Offset else 40
	local icon = props.icon
	local iconSize = math.min(props.iconSize or 32, math.max(height - 12, 12))
	local left = if icon ~= nil then iconSize + 14 else 8
	local textSize = Theme.Body(props.textSize or 17)
	local fade = if disabled then 0.35 else 0

	return e("TextButton", {
		Size = size,
		Position = props.position,
		AnchorPoint = props.anchor,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Active = not disabled,
		Text = "",
		LayoutOrder = props.layoutOrder,
		[React.Event.MouseEnter] = function(rbx: GuiObject)
			setHovered(true)
			if props.tip ~= nil then
				Tip.Show(rbx, props.tip)
			end
		end,
		[React.Event.MouseLeave] = function(rbx: GuiObject)
			setHovered(false)
			setPressed(false)
			Tip.Hide(rbx)
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
		-- Centred so hover / press scale from the middle of the button.
		Body = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, {
			Scale = e("UIScale", { Scale = scale }),
			Art = Art.Back({
				piece = piece,
				edge = Art.FitEdge(piece, height),
				color = tint,
			}),
			Icon = if icon ~= nil
				then e(Widgets.Icon, {
					image = icon,
					size = iconSize,
					position = UDim2.new(0, 7, 0.5, 0),
					anchor = Vector2.new(0, 0.5),
					transparency = if disabled then 0.5 else 0,
				})
				else nil,
			Label = e("TextLabel", {
				Size = UDim2.new(1, -(left + 8), 1, 0),
				Position = UDim2.fromOffset(left, 0),
				BackgroundTransparency = 1,
				Text = props.text,
				TextColor3 = labelColor,
				TextTransparency = fade,
				FontFace = Theme.FontBold,
				TextSize = textSize,
				TextScaled = true,
				TextXAlignment = if icon ~= nil then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
				ZIndex = 2,
			}, {
				Fit = Widgets.Shrink(textSize),
				Heavy = Widgets.Heavy(labelColor, textSize, fade),
			}),
		}),
	})
end

export type CloseButtonProps = {
	onClick: () -> (),
	size: number?,
	position: UDim2?,
	anchor: Vector2?,
}

-- Small gilt square with an X: closes windows and modals.
function Widgets.CloseButton(props: CloseButtonProps): React.ReactNode
	local hovered, setHovered = React.useState(false)
	local pressed, setPressed = React.useState(false)
	local s = props.size or 32
	local cross: { [string]: React.ReactNode } = {}
	for i, angle in { 45, -45 } do
		cross["Bar" .. i] = e("Frame", {
			Size = UDim2.fromOffset(s * 0.5, 2.5),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = angle,
			BackgroundColor3 = if hovered then Theme.OnDark else Theme.Gold,
			BorderSizePixel = 0,
			ZIndex = 2,
		})
	end
	cross.Art = Art.Back({ piece = "BtnSquareGilt", edge = Art.FitEdge("BtnSquareGilt", s) })
	cross.Scale = e("UIScale", { Scale = Motion.useButton(hovered, pressed) })
	return e("TextButton", {
		Size = UDim2.fromOffset(s, s),
		Position = props.position,
		AnchorPoint = props.anchor,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
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
		[React.Event.Activated] = props.onClick,
	}, {
		-- Centred so hover / press scale from the middle.
		Body = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, cross),
	})
end

export type BarProps = {
	ratio: number,
	size: UDim2?,
	position: UDim2?,
	layoutOrder: number?,
}

-- Gilt-rimmed leather track with a gold fill.
function Widgets.Bar(props: BarProps): React.ReactNode
	local size = props.size or UDim2.new(1, 0, 0, 6)
	local height = if size.Y.Scale == 0 then size.Y.Offset else 10
	local inset = math.clamp(math.floor(height * 0.22), 1, 4)
	local ratio = math.clamp(props.ratio, 0, 1)
	return e("Frame", {
		Size = size,
		Position = props.position,
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
	}, {
		Art = Art.Back({ piece = "BarTrackGilt", edge = Art.FitEdge("BarTrackGilt", height) }),
		Fill = e("Frame", {
			Size = UDim2.new(ratio, -inset * 2 * ratio, 1, -inset * 2),
			Position = UDim2.fromOffset(inset, inset),
			BackgroundColor3 = Theme.Bar,
			BorderSizePixel = 0,
			Visible = ratio > 0,
			ZIndex = 1,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Shine = e("UIGradient", {
				Color = ColorSequence.new(Theme.Gold, Theme.Bar),
				Rotation = 90,
			}),
		}),
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

-- Recessed paper field; the TextBox sits inside the art.
function Widgets.TextInput(props: TextInputProps): React.ReactNode
	local size = props.size or UDim2.new(1, 0, 0, 34)
	local height = if size.Y.Scale == 0 then size.Y.Offset else 34
	return e("Frame", {
		Size = size,
		Position = props.position,
		BackgroundTransparency = 1,
	}, {
		Art = Art.Back({ piece = "InputPaper", edge = Art.FitEdge("InputPaper", height) }),
		Box = e("TextBox", {
			Size = UDim2.new(1, -20, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			BackgroundTransparency = 1,
			Text = props.text,
			PlaceholderText = props.placeholder,
			PlaceholderColor3 = Theme.Subtext,
			TextColor3 = Theme.Text,
			FontFace = Theme.Font,
			TextSize = Theme.Body(17),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ClearTextOnFocus = false,
			ZIndex = 1,
			[React.Change.Text] = function(rbx: TextBox)
				props.onChanged(rbx.Text)
			end,
			[React.Event.FocusLost] = function(rbx: TextBox)
				if props.onFocusLost ~= nil then
					props.onFocusLost(rbx.Text)
				end
			end,
		}),
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

-- Window art (Config.UiArt MainWindow): leather header band on top, paper body; content sits inside the ink rule.
Widgets.WINDOW_HEADER = 66
Widgets.WINDOW_SIDE = 28
Widgets.WINDOW_TOP = 74
Widgets.WINDOW_BOTTOM = 34
-- Room the header ornaments take at each end of the title band.
Widgets.WINDOW_ORNAMENT = 58

-- Plain paper sheet (raised card art) at `size`/`position`, under any sibling with ZIndex >= 1.
function Widgets.Sheet(size: UDim2, position: UDim2): React.ReactNode
	return e("Frame", {
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		ZIndex = 0,
	}, {
		Art = Art.Back({ piece = "PaperCompactSharp" }),
	})
end

-- Page / modal shell: dimmed backdrop that eats clicks, centred window with title + close button + content area.
function Widgets.Window(props: WindowProps): React.ReactNode
	Widgets.useEscape(props.onClose)
	local onClose = props.onClose
	local side, top, bottom = Widgets.WINDOW_SIDE, Widgets.WINDOW_TOP, Widgets.WINDOW_BOTTOM
	local shown = Motion.useShow()
	local pop = Motion.usePop(shown)
	return e("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Backdrop,
		-- Dims to 0.45 as the modal opens, back to clear as it closes.
		BackgroundTransparency = shown:map(function(p: number): number
			return 1 - 0.55 * p
		end),
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
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
		}, {
			Max = e("UISizeConstraint", { MaxSize = props.maxSize or Vector2.new(1100, 720) }),
			Pop = e("UIScale", { Scale = pop }),
			Art = Art.Back({ piece = "MainWindow" }),
			Title = e("TextLabel", {
				Text = props.title,
				Size = UDim2.new(1, -(Widgets.WINDOW_ORNAMENT * 2 + 44), 0, Widgets.WINDOW_HEADER - 14),
				Position = UDim2.fromOffset(Widgets.WINDOW_ORNAMENT, 6),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Gold,
				FontFace = Theme.FontTitle,
				TextSize = Theme.Title(28),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 2,
			}),
			Close = if onClose ~= nil
				then e(Widgets.CloseButton, {
					onClick = onClose,
					position = UDim2.new(1, -Widgets.WINDOW_ORNAMENT, 0, 13),
					anchor = Vector2.new(1, 0),
				})
				else nil,
			Content = e("Frame", {
				Size = UDim2.new(1, -side * 2, 1, -(top + bottom)),
				Position = UDim2.fromOffset(side, top),
				BackgroundTransparency = 1,
				ZIndex = 2,
			}, props.children),
		}),
	})
end

return Widgets
