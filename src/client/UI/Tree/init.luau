--!strict
-- Skill tree window (floating, on its own): small square nodes on a fixed grid, a Start node with one branch running left, right and down, right-angle lines to prerequisites; scrolls when the window is smaller than the map. No detail panel: clicking a node buys it (confirm), switches a toggle node, or says why it cannot be bought.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Format = require(ReplicatedStorage.Shared.Format)
local SkillTree = require(ReplicatedStorage.Shared.Config.SkillTree)
local Theme = require(script.Parent.Core.Theme)
local Widgets = require(script.Parent.Core.Widgets)
local FloatWindow = require(script.Parent.Core.FloatWindow)
local State = require(script.Parent.Parent.State)

local e = React.createElement
local UI = Text.UI

local DEFAULT_SIZE = Vector2.new(860, 520)
local MIN_SIZE = Vector2.new(480, 320)
-- Grid cell and node size in design units: nodes stay small and the map scrolls instead of stretching.
local CELL = 56
local NODE = 36
local LINE = 3

-- Where each branch runs from the Start node (grid cells, +Y down): a node sits `Row` cells along and `Col` cells across.
local DIRECTIONS: { [string]: { Along: Vector2, Across: Vector2 } } = {
	Combat = { Along = Vector2.new(-1, 0), Across = Vector2.new(0, 1) },
	Economy = { Along = Vector2.new(1, 0), Across = Vector2.new(0, 1) },
	System = { Along = Vector2.new(0, 1), Across = Vector2.new(1, 0) },
}

local function cellOf(def: SkillTree.NodeDef): Vector2
	local direction = DIRECTIONS[def.Branch]
	return direction.Along * def.Row + direction.Across * def.Col
end

-- Grid bounds over every node and the Start node at (0, 0).
local low, high = Vector2.zero, Vector2.zero
for _, def in SkillTree.List do
	local cell = cellOf(def)
	low, high = low:Min(cell), high:Max(cell)
end
local COLS, ROWS = high.X - low.X + 1, high.Y - low.Y + 1

-- Centre of a cell on the board, in design units.
local function at(cell: Vector2): Vector2
	return Vector2.new((cell.X - low.X + 0.5) * CELL, (cell.Y - low.Y + 0.5) * CELL)
end

export type Props = { data: Types.ProfileData }

type NodeState = "Owned" | "Available" | "Locked"

local function owns(data: Types.ProfileData, id: string): boolean
	return (data.SkillTree[id] or 0) > 0
end

local function stateOf(data: Types.ProfileData, def: SkillTree.NodeDef): NodeState
	if owns(data, def.Id) then
		return "Owned"
	end
	for _, req in def.Requires do
		if not owns(data, req) then
			return "Locked"
		end
	end
	return "Available"
end

local function costText(cost: SkillTree.Cost): string
	local parts = {}
	if (cost.Gold or 0) > 0 then
		table.insert(parts, `{Format.Number(cost.Gold :: number)} gold`)
	end
	local items: { [string]: number } = cost.Items or {}
	for id, n in items do
		table.insert(parts, `{n} {Text.Material(id)}`)
	end
	if (cost.RebirthPoints or 0) > 0 then
		table.insert(parts, `{cost.RebirthPoints} {UI.RebirthPoints}`)
	end
	return table.concat(parts, " · ")
end

-- Error key the server would answer with, so a click can explain itself before sending.
local function missing(data: Types.ProfileData, def: SkillTree.NodeDef): string?
	local cost = def.Cost
	if data.Gold < (cost.Gold or 0) then
		return "NotEnoughGold"
	end
	local items: { [string]: number } = cost.Items or {}
	for id, n in items do
		if (data.Stacks[id] or 0) < n then
			return "NotEnoughItems"
		end
	end
	if data.Rebirth.Points < (cost.RebirthPoints or 0) then
		return "NotEnoughPoints"
	end
	return nil
end

local function effectsText(def: SkillTree.NodeDef): string
	local parts = {}
	for _, effect in def.Effects do
		table.insert(parts, Text.Effect(effect))
	end
	return table.concat(parts, ", ")
end

local function click(data: Types.ProfileData, def: SkillTree.NodeDef)
	local st = stateOf(data, def)
	if st == "Owned" then
		if def.Toggle then
			State.Send.ToggleNode(def.Id, data.SkillOff[def.Id] == true)
		end
		return
	elseif st == "Locked" then
		State.PushToast(`{Text.Node(def.Id)}: {UI.Locked}`)
		return
	end
	local problem = missing(data, def)
	if problem ~= nil then
		State.PushToast((Text.Error :: { [string]: string })[problem] or problem)
		return
	end
	local cost = costText(def.Cost)
	State.OpenConfirm({
		Title = `Unlock {Text.Node(def.Id)}?`,
		Body = `Spends {if cost ~= "" then cost else "nothing"}. {effectsText(def)}. Skill tree nodes cannot be refunded.`,
		OkText = `Unlock {Text.Node(def.Id)}`,
		Danger = false,
		OnConfirm = function()
			State.Send.BuyNode(def.Id)
		end,
	})
end

-- One straight piece of a connector (cells share a row or a column).
local function segment(from: Vector2, to: Vector2, lit: boolean): React.ReactNode
	local a, b = at(from), at(to)
	local size = (b - a):Abs() + Vector2.new(LINE, LINE)
	local mid = (a + b) / 2
	return e("Frame", {
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(mid.X, mid.Y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = if lit then Theme.Accent else Theme.Stroke,
		BorderSizePixel = 0,
		ZIndex = if lit then 2 else 1,
	})
end

-- Connector from a node to the one it unlocks: straight, or a right angle that first runs along the branch, then across.
local function connect(
	out: { [string]: React.ReactNode },
	key: string,
	from: Vector2,
	to: Vector2,
	along: Vector2,
	lit: boolean
)
	local corner = from + along * (to - from):Dot(along)
	if corner == from or corner == to then
		out[key] = segment(from, to, lit)
	else
		out[key .. "_a"] = segment(from, corner, lit)
		out[key .. "_b"] = segment(corner, to, lit)
	end
end

local function node(
	cell: Vector2,
	label: string,
	owned: boolean,
	locked: boolean,
	onClick: (() -> ())?
): React.ReactNode
	local where = at(cell)
	return e("TextButton", {
		Size = UDim2.fromOffset(NODE, NODE),
		Position = UDim2.fromOffset(where.X, where.Y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		-- Owned = light, can be bought = mid grey with a bright edge, locked = dark. All opaque so lines never show through.
		BackgroundColor3 = if owned then Theme.Confirm elseif locked then Theme.Bg else Theme.PanelAlt,
		AutoButtonColor = onClick ~= nil,
		Text = label,
		TextColor3 = if owned then Theme.OnLight elseif locked then Theme.Subtext else Theme.Text,
		FontFace = Theme.FontBold,
		TextSize = 10,
		TextWrapped = true,
		ZIndex = 3,
		[React.Event.Activated] = onClick,
	}, {
		Corner = Widgets.Corner(4),
		Stroke = Widgets.Stroke(
			if locked then Theme.Stroke else Theme.Accent,
			if locked then 1 else 1.5,
			if locked then 0.4 else 0
		),
	})
end

local function TreePage(props: Props): React.ReactNode
	local data = props.data
	local board: { [string]: React.ReactNode } = {
		Start = node(Vector2.zero, UI.TreeStart, true, false, nil),
	}
	for _, def in SkillTree.List do
		local cell = cellOf(def)
		local st = stateOf(data, def)
		local along = DIRECTIONS[def.Branch].Along
		if #def.Requires == 0 then
			connect(board, `L_Start_{def.Id}`, Vector2.zero, cell, along, true)
		end
		for _, req in def.Requires do
			connect(board, `L_{req}_{def.Id}`, cellOf(SkillTree.ById[req]), cell, along, owns(data, req))
		end
		local first = def.Effects[1]
		local label = if first ~= nil then Text.EffectMark(first.Kind) else "?"
		if st == "Owned" and def.Toggle and data.SkillOff[def.Id] == true then
			label = UI.Off
		end
		board[def.Id] = node(cell, label, st == "Owned", st == "Locked", function()
			click(data, def)
		end)
	end

	return e(FloatWindow, {
		id = "Tree",
		title = UI.Tree,
		onClose = function()
			State.CloseWindow("Tree")
		end,
		defaultSize = DEFAULT_SIZE,
		minSize = MIN_SIZE,
	}, {
		-- The list layout centres the map while it fits and lets it scroll (both ways) once it does not.
		Map = e("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(COLS * CELL, ROWS * CELL),
			ScrollingDirection = Enum.ScrollingDirection.XY,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Stroke,
		}, {
			Layout = e("UIListLayout", {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Board = e("Frame", {
				Size = UDim2.fromOffset(COLS * CELL, ROWS * CELL),
				BackgroundTransparency = 1,
			}, board),
		}),
	})
end

return TreePage
