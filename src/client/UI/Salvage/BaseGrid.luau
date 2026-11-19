--!strict
-- Paged grid of gear bases (one cell per BaseId: name + class) with back / page / next. Used by the auto-salvage list and the Add item picker; optional press + drag across cells (picker multi-select).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Text = require(ReplicatedStorage.Shared.Text)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)

local e = React.createElement
local UI = Text.UI

local CELL_GAP = 6
local FOOT_H = 34
local GAP = 8
local PAGER_W = 212

export type Props = {
	ids: { string }, -- in display order
	cols: number,
	rows: number,
	marked: { [string]: boolean }, -- drawn highlighted
	empty: string?, -- shown over the grid when ids is empty
	onClick: ((id: string) -> ())?,
	-- Pointer pressed on a cell; while it stays down, onDrag fires once for each other cell it moves onto.
	onPress: ((id: string) -> ())?,
	onDrag: ((id: string) -> ())?,
	footer: React.ReactNode?, -- left of the pager
}

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function BaseGrid(props: Props): React.ReactNode
	local page, setPage = React.useState(1)
	local cellsRef = React.useRef(nil :: Frame?)
	-- Drag state lives in refs: input events arriving after release must not revive it.
	local dragging = React.useRef(false)
	local lastId = React.useRef(nil :: string?)
	local latest = React.useRef(props)
	latest.current = props

	React.useEffect(function(): () -> ()
		local moved = UserInputService.InputChanged:Connect(function(input: InputObject)
			local onDrag = latest.current.onDrag
			local frame = cellsRef.current
			if not dragging.current or onDrag == nil or frame == nil then
				return
			end
			if
				input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local p = Vector2.new(input.Position.X, input.Position.Y)
			for _, child in frame:GetChildren() do
				if child:IsA("GuiButton") then
					local pos, size = child.AbsolutePosition, child.AbsoluteSize
					if p.X >= pos.X and p.X <= pos.X + size.X and p.Y >= pos.Y and p.Y <= pos.Y + size.Y then
						-- Cell instances are named by their React key = BaseId.
						if child.Name ~= lastId.current then
							lastId.current = child.Name
							onDrag(child.Name)
						end
						break
					end
				end
			end
		end)
		local ended = UserInputService.InputEnded:Connect(function(input: InputObject)
			if isPointer(input) then
				dragging.current = false
				lastId.current = nil
			end
		end)
		return function()
			moved:Disconnect()
			ended:Disconnect()
		end
	end, {})

	local cols, rows = props.cols, props.rows
	local perPage = cols * rows
	local ids = props.ids
	local pages = math.max(math.ceil(#ids / perPage), 1)
	local shown = math.clamp(page, 1, pages)

	local cells: { [string]: React.ReactNode } = {
		Layout = e("UIGridLayout", {
			CellSize = UDim2.new(1 / cols, -CELL_GAP, 1 / rows, -CELL_GAP),
			CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for i = 1, perPage do
		local id = ids[(shown - 1) * perPage + i]
		if id == nil then
			cells[`Empty{i}`] = e("Frame", {
				BackgroundColor3 = Theme.Bg,
				BackgroundTransparency = 0.4,
				LayoutOrder = i,
			}, { Corner = Widgets.Corner(6) })
			continue
		end
		local def = Items.ById[id]
		local marked = props.marked[id] == true
		cells[id] = e("TextButton", {
			BackgroundColor3 = if marked then Theme.Hover else Theme.PanelAlt,
			AutoButtonColor = true,
			Text = if def ~= nil then `{Text.Item(id)}\n{Text.Class(def.Class)}` else Text.Item(id),
			TextColor3 = Theme.Text,
			FontFace = Theme.Font,
			TextSize = 11,
			TextWrapped = true,
			LayoutOrder = i,
			[React.Event.InputBegan] = function(_rbx: TextButton, input: InputObject)
				local onPress = latest.current.onPress
				if onPress ~= nil and isPointer(input) then
					dragging.current = true
					lastId.current = id
					onPress(id)
				end
			end,
			[React.Event.Activated] = function()
				local onClick = latest.current.onClick
				if onClick ~= nil then
					onClick(id)
				end
			end,
		}, {
			Corner = Widgets.Corner(6),
			Padding = Widgets.Padding(3),
			Stroke = if marked then Widgets.Stroke(Theme.Accent, 2, 0) else nil,
		})
	end

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Cells = e("Frame", {
			Size = UDim2.new(1, CELL_GAP, 1, -(FOOT_H + GAP)),
			BackgroundTransparency = 1,
			ref = cellsRef,
		}, cells),
		Empty = if #ids == 0 and props.empty ~= nil
			then e(Widgets.Label, {
				text = props.empty,
				color = Theme.Subtext,
				textSize = 16,
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(1, 0, 0, 30),
				position = UDim2.new(0.5, 0, 0.5, -(FOOT_H + GAP) / 2),
				anchor = Vector2.new(0.5, 0.5),
			})
			else nil,
		Footer = e("Frame", {
			Size = UDim2.new(1, -(PAGER_W + GAP), 0, FOOT_H),
			Position = UDim2.fromScale(0, 1),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,
		}, { Content = props.footer }),
		Pager = e("Frame", {
			Size = UDim2.fromOffset(PAGER_W, FOOT_H),
			Position = UDim2.fromScale(1, 1),
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
		}, {
			Back = e(Widgets.Button, {
				text = UI.Back,
				size = UDim2.fromOffset(68, FOOT_H),
				textSize = 15,
				disabled = shown <= 1,
				onClick = function()
					setPage(shown - 1)
				end,
			}),
			Page = e(Widgets.Label, {
				text = `{shown}/{pages}`,
				align = Enum.TextXAlignment.Center,
				textSize = 15,
				position = UDim2.fromOffset(68, 0),
				size = UDim2.fromOffset(76, FOOT_H),
			}),
			Next = e(Widgets.Button, {
				text = UI.Next,
				size = UDim2.fromOffset(68, FOOT_H),
				position = UDim2.fromScale(1, 0),
				anchor = Vector2.new(1, 0),
				textSize = 15,
				disabled = shown >= pages,
				onClick = function()
					setPage(shown + 1)
				end,
			}),
		}),
	})
end

return BaseGrid
