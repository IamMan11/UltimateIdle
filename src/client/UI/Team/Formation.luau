--!strict
-- Team window, right column: the draft formation standing on the lane ground (follows a hero being dragged over a row), row columns (back · middle · front) with one cell per place, Remove / Reset / Apply. Click a row to place the picked hero, drag a hero between rows; Apply sends SetTeam.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Formula = require(ReplicatedStorage.Shared.Formula)
local FormationConfig = require(ReplicatedStorage.Shared.Config.Formation)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local World = require(ReplicatedStorage.Shared.Config.World)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local ModelView = require(script.Parent.Parent.Core.ModelView)
local State = require(script.Parent.Parent.Parent.State)
local Scenery = require(script.Parent.Parent.Parent.Battle.Scenery)

local e = React.createElement
local UI = Text.UI

type Entry = { HeroId: string, Row: string }
type Drag = { HeroId: string, Start: Vector2, Pos: Vector2, Moved: boolean }

local DISPLAY_ROWS = { "Back", "Middle", "Front" }
local DRAG_THRESHOLD = 6
-- Share of the column height used by the preview.
local PREVIEW = 0.36
local INFO_H = 58
local FOOT_H = 34
local CELL_H = 54
local GAP = 8
-- Heroes face +X (towards the monsters); seen from the camera side of the lane and above, so the back row is on the left like the columns below.
local VIEW = Vector3.new(0.3, 0.75, 1)
local FACE_LANE = -math.pi / 2
-- Fixed framing (lane-origin space): the three rows with every place filled.
local ROW_X = FormationConfig.RowX :: { [string]: number }
local FOCUS: ModelView.Focus = {
	Center = Vector3.new((ROW_X.Front + ROW_X.Back) / 2 + World.HeroOffsetX, World.FloorY + 2, 0),
	Radius = 9,
}
local GROUND_HALF_WIDTH = 60

local function buildGround(parent: Instance)
	Scenery.BuildGround(parent, GROUND_HALF_WIDTH)
end

-- `team` with the hero moved to `row` (nil = taken out); second value = Text.Error key when the row or the team is full. Returns `team` itself when the hero is already in that row.
local function moved(team: { Entry }, heroId: string, row: string?, slots: number): ({ Entry }, string?)
	local nextTeam: { Entry } = {}
	local inRow = 0
	for _, entry in team do
		if entry.HeroId ~= heroId then
			table.insert(nextTeam, entry)
			if entry.Row == row then
				inRow += 1
			end
		elseif entry.Row == row then
			return team, nil
		end
	end
	if row ~= nil then
		if inRow >= FormationConfig.MaxPerRow then
			return team, "RowFull"
		elseif #nextTeam >= slots then
			return team, "TeamTooBig"
		end
		table.insert(nextTeam, { HeroId = heroId, Row = row })
	end
	return nextTeam, nil
end

export type Props = {
	data: Types.ProfileData,
	selected: string, -- class picked in the left column
	onSelect: (classId: string) -> (),
}

local function copyTeam(team: { Types.TeamSlot }): { Entry }
	local out: { Entry } = {}
	for _, slot in team do
		table.insert(out, { HeroId = slot.HeroId, Row = slot.Row :: string })
	end
	return out
end

local function signature(team: { Entry } | { Types.TeamSlot }): string
	local parts = {}
	for _, slot in team :: { Entry } do
		table.insert(parts, `{slot.HeroId}:{slot.Row}`)
	end
	return table.concat(parts, ",")
end

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function Formation(props: Props): React.ReactNode
	local data, selected = props.data, props.selected
	local serverSig = signature(data.Team)
	local draft, setDraft = React.useState(copyTeam(data.Team))
	local drag, setDragState = Widgets.useOptional(nil :: Drag?)
	-- The live drag: input handlers read and write this, so a late InputChanged after release cannot revive it.
	local dragRef = React.useRef(nil :: Drag?)
	local function setDrag(value: Drag?)
		dragRef.current = value
		setDragState(value)
	end
	local zones = React.useRef({} :: { [string]: GuiObject })
	local rootRef = React.useRef(nil :: Frame?)

	-- The server team changed (our Apply landed, or another source): start the draft from it again.
	React.useEffect(function()
		setDraft(copyTeam(data.Team))
	end, { serverSig })

	local slots = Formula.Mods.Build(data.SkillTree, data.SkillOff, data.AccountLevel).TeamSlots

	local function place(heroId: string, row: string?)
		local nextTeam, problem = moved(draft, heroId, row, slots)
		if problem ~= nil then
			State.PushToast((Text.Error :: { [string]: string })[problem] or problem)
		elseif nextTeam ~= draft then
			setDraft(nextTeam)
		end
	end

	local function zoneAt(pos: Vector2): string?
		for key, gui in zones.current do
			if gui.Parent ~= nil then
				local p, s = gui.AbsolutePosition, gui.AbsoluteSize
				if pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y then
					return key
				end
			end
		end
		return nil
	end

	-- While a press is held: follow the pointer, drop on release (a press that never moved is a click = pick that hero).
	local dragging = drag ~= nil
	local onSelect = props.onSelect
	React.useEffect(function()
		if not dragging then
			return function() end
		end
		local changed = UserInputService.InputChanged:Connect(function(input)
			local current = dragRef.current
			if
				current ~= nil
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				local pos = Vector2.new(input.Position.X, input.Position.Y)
				setDrag({
					HeroId = current.HeroId,
					Start = current.Start,
					Pos = pos,
					Moved = current.Moved or (pos - current.Start).Magnitude > DRAG_THRESHOLD,
				})
			end
		end)
		local ended = UserInputService.InputEnded:Connect(function(input)
			local current = dragRef.current
			if current == nil or not isPointer(input) then
				return
			end
			setDrag(nil)
			if current.Moved then
				local zone = zoneAt(current.Pos)
				if zone ~= nil then
					place(current.HeroId, zone)
				end
			else
				onSelect(current.HeroId)
			end
		end)
		return function()
			changed:Disconnect()
			ended:Disconnect()
		end
	end, { dragging, draft, onSelect } :: { any })

	local members: { Formula.TeamMember } = {}
	local speeds: { { Row: string, Speed: number } } = {}
	local inDraft = false
	for _, entry in draft do
		inDraft = inDraft or entry.HeroId == selected
		local hero = data.Heroes[entry.HeroId]
		if hero ~= nil then
			table.insert(members, { Class = hero.Class :: string, Row = entry.Row })
			local gear: { Types.GearItem } = {}
			for _, uid in hero.Equipped do
				local item = data.Gear[uid]
				if item ~= nil then
					table.insert(gear, item)
				end
			end
			local stats = Formula.Stats.Hero(hero.Class, hero.Level, gear, hero.Advancement)
			table.insert(speeds, { Row = entry.Row, Speed = stats.Speed })
		end
	end

	local function zoneRef(key: string): (GuiObject?) -> ()
		return function(rbx: GuiObject?)
			if rbx ~= nil then
				zones.current[key] = rbx
			end
		end
	end

	local function cell(heroId: string, order: number, memberIndex: number): React.ReactNode
		local hero = data.Heroes[heroId]
		local bonus = Formula.Team.FormationBonus(members, memberIndex)
		local lifted = drag ~= nil and drag.Moved and drag.HeroId == heroId
		return e("TextButton", {
			BackgroundColor3 = if selected == heroId then Theme.Hover else Theme.PanelAlt,
			BackgroundTransparency = if lifted then 0.6 else 0,
			AutoButtonColor = true,
			Text = `{Text.Class(hero.Class)}\nLv {hero.Level}\n+{math.floor(bonus * 100 + 0.5)}%`,
			TextColor3 = Theme.Text,
			FontFace = Theme.Font,
			TextSize = 12,
			TextWrapped = true,
			LayoutOrder = order,
			[React.Event.InputBegan] = function(_rbx: TextButton, input: InputObject)
				if isPointer(input) then
					local pos = Vector2.new(input.Position.X, input.Position.Y)
					setDrag({ HeroId = heroId, Start = pos, Pos = pos, Moved = false })
				end
			end,
		}, {
			Corner = Widgets.Corner(6),
			Stroke = if selected == heroId then Widgets.Stroke(Theme.Accent, 1.5, 0) else nil,
		})
	end

	-- The preview follows a hero being dragged: over a row it already stands there (when it would fit).
	local shown = draft
	if drag ~= nil and drag.Moved then
		local zone = zoneAt(drag.Pos)
		if zone ~= nil then
			shown = moved(draft, drag.HeroId, zone, slots)
		end
	end
	local models: { ModelView.Entry } = {}
	for _, row in DISPLAY_ROWS do
		local classes: { string } = {}
		for _, entry in shown do
			local hero = data.Heroes[entry.HeroId]
			if entry.Row == row and hero ~= nil then
				table.insert(classes, hero.Class :: string)
			end
		end
		for k, class in classes do
			table.insert(models, {
				Class = class,
				Position = Vector3.new(
					(ROW_X[row] or 0) + World.HeroOffsetX,
					World.FloorY,
					(k - (#classes + 1) / 2) * FormationConfig.LaneSpacing
				),
				Yaw = FACE_LANE,
			})
		end
	end
	local columns: { [string]: React.ReactNode } = {}
	for col, row in DISPLAY_ROWS do
		local inRow: { number } = {}
		for i, entry in draft do
			if entry.Row == row and data.Heroes[entry.HeroId] ~= nil then
				table.insert(inRow, i)
			end
		end
		local cells: { [string]: React.ReactNode } = {
			Layout = e("UIGridLayout", {
				CellSize = UDim2.new(0.5, -2, 0, CELL_H),
				CellPadding = UDim2.fromOffset(4, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for k, i in inRow do
			local heroId = draft[i].HeroId
			cells[heroId] = cell(heroId, k, i)
		end
		-- Free places: plain frames, so a click on one reaches the column button under it.
		for k = #inRow + 1, FormationConfig.MaxPerRow do
			cells[`Free{k}`] = e("Frame", {
				BackgroundColor3 = Theme.PanelAlt,
				BackgroundTransparency = 0.7,
				LayoutOrder = k,
			}, { Corner = Widgets.Corner(6) })
		end
		columns[row] = e("TextButton", {
			Size = UDim2.new(1 / 3, -4, 1, 0),
			Position = UDim2.new((col - 1) / 3, 2, 0, 0),
			BackgroundColor3 = Theme.Bg,
			AutoButtonColor = false,
			Text = "",
			ref = zoneRef(row),
			[React.Event.Activated] = function()
				if data.Heroes[selected] ~= nil then
					place(selected, row)
				end
			end,
		}, {
			Corner = Widgets.Corner(8),
			Stroke = Widgets.Stroke(),
			Head = e(Widgets.Label, {
				text = `{Text.Row(row)} {#inRow}/{FormationConfig.MaxPerRow}`,
				bold = true,
				textSize = 14,
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(0, 4),
			}),
			Cells = e("Frame", {
				Size = UDim2.new(1, -8, 1, -32),
				Position = UDim2.fromOffset(4, 28),
				BackgroundTransparency = 1,
			}, cells),
		})
	end

	local dirty = signature(draft) ~= serverSig
	local speed = Formula.Team.Speed(speeds, Stages.ReferenceSpeed)

	local ghost: React.ReactNode = nil
	local root = rootRef.current
	if drag ~= nil and drag.Moved and root ~= nil and data.Heroes[drag.HeroId] ~= nil then
		-- Pointer and AbsolutePosition are pixels: place by share of this frame so the UI scale does not matter.
		local pos: Vector2 = drag.Pos
		local rel = pos - root.AbsolutePosition
		local size = root.AbsoluteSize
		ghost = e("Frame", {
			Size = UDim2.fromOffset(120, 32),
			Position = UDim2.fromScale(rel.X / math.max(size.X, 1), rel.Y / math.max(size.Y, 1)),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme.Hover,
			ZIndex = 5,
		}, {
			Corner = Widgets.Corner(6),
			Stroke = Widgets.Stroke(Theme.Accent, 1.5, 0),
			Name = e(Widgets.Label, {
				text = Text.Class(data.Heroes[drag.HeroId].Class),
				bold = true,
				align = Enum.TextXAlignment.Center,
				size = UDim2.fromScale(1, 1),
			}),
		})
	end

	local third = UDim2.new(1 / 3, -4, 1, 0)
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ref = rootRef }, {
		Preview = e("Frame", { Size = UDim2.fromScale(1, PREVIEW), BackgroundTransparency = 1 }, {
			Model = e(ModelView, { entries = models, view = VIEW, scene = buildGround, focus = FOCUS }),
		}),
		Info = e(Widgets.Label, {
			text = `Slots {#draft}/{slots}   ·   Team speed {math.floor(speed * 10 + 0.5) / 10}\n{UI.TeamHint}`,
			color = Theme.Subtext,
			textSize = 13,
			wrap = true,
			position = UDim2.new(0, 0, PREVIEW, 4),
			size = UDim2.new(1, 0, 0, INFO_H - 8),
		}),
		Rows = e("Frame", {
			Size = UDim2.new(1, 0, 1 - PREVIEW, -(INFO_H + FOOT_H + GAP)),
			Position = UDim2.new(0, 0, PREVIEW, INFO_H),
			BackgroundTransparency = 1,
		}, columns),
		Foot = e("Frame", {
			Size = UDim2.new(1, 0, 0, FOOT_H),
			Position = UDim2.fromScale(0, 1),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,
		}, {
			Remove = e(Widgets.Button, {
				text = UI.Remove,
				size = third,
				position = UDim2.fromOffset(2, 0),
				textSize = 15,
				disabled = not inDraft,
				onClick = function()
					place(selected, nil)
				end,
			}),
			Reset = e(Widgets.Button, {
				text = UI.Reset,
				size = third,
				position = UDim2.new(1 / 3, 2, 0, 0),
				textSize = 15,
				disabled = not dirty,
				onClick = function()
					setDraft(copyTeam(data.Team))
				end,
			}),
			Apply = e(Widgets.Button, {
				text = UI.Apply,
				size = third,
				position = UDim2.new(2 / 3, 2, 0, 0),
				textSize = 15,
				color = Theme.Confirm,
				disabled = not dirty or #draft == 0,
				onClick = function()
					State.Send.SetTeam(draft)
				end,
			}),
		}),
		Ghost = ghost,
	})
end

return Formation
