--!strict
-- Team page: row columns laid out like the lane (back · middle · front) + bench. Drag or select-then-click to place; Apply sends SetTeam.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Heroes = require(ReplicatedStorage.Shared.Config.Heroes)
local Formation = require(ReplicatedStorage.Shared.Config.Formation)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Theme = require(script.Parent.Core.Theme)
local Widgets = require(script.Parent.Core.Widgets)
local State = require(script.Parent.Parent.State)

local e = React.createElement
local UI = Text.UI

type Entry = { HeroId: string, Row: string }
type Drag = { HeroId: string, Start: Vector2, Pos: Vector2, Moved: boolean }

local DISPLAY_ROWS = { "Back", "Middle", "Front" }
local DRAG_THRESHOLD = 6
local CARD_H = 58

export type Props = { data: Types.ProfileData }

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

local function TeamPage(props: Props): React.ReactNode
	local data = props.data
	local serverSig = signature(data.Team)
	local draft, setDraft = React.useState(copyTeam(data.Team))
	local selected, setSelected = Widgets.useOptional(nil :: string?)
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
		local nextTeam: { Entry } = {}
		local inRow = 0
		for _, entry in draft do
			if entry.HeroId ~= heroId then
				table.insert(nextTeam, entry)
				if entry.Row == row then
					inRow += 1
				end
			end
		end
		if row ~= nil then
			if inRow >= Formation.MaxPerRow then
				State.PushToast(Text.Error.RowFull)
				return
			elseif #nextTeam >= slots then
				State.PushToast(Text.Error.TeamTooBig)
				return
			end
			table.insert(nextTeam, { HeroId = heroId, Row = row })
		end
		setDraft(nextTeam)
		setSelected(nil)
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

	-- While a press is held: follow the pointer, drop on release (a press that never moved is a click = select).
	local dragging = drag ~= nil
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
				if zone == "Bench" then
					place(current.HeroId, nil)
				elseif zone ~= nil then
					place(current.HeroId, zone)
				end
			else
				setSelected(if selected == current.HeroId then nil else current.HeroId)
			end
		end)
		return function()
			changed:Disconnect()
			ended:Disconnect()
		end
	end, { dragging, draft, selected } :: { any })

	local members: { Formula.TeamMember } = {}
	local speeds: { { Row: string, Speed: number } } = {}
	for _, entry in draft do
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

	local function card(heroId: string, order: number, memberIndex: number?): React.ReactNode
		local hero = data.Heroes[heroId]
		local def = Heroes.ById[hero.Class]
		local bonus = if memberIndex ~= nil then Formula.Team.FormationBonus(members, memberIndex) else 0
		local sub = if memberIndex ~= nil
			then `Bonus +{math.floor(bonus * 100 + 0.5)}% · best: {Text.Row(def.PreferredRow)}`
			else `Best row: {Text.Row(def.PreferredRow)}`
		local lifted = drag ~= nil and drag.Moved and drag.HeroId == heroId
		return e("TextButton", {
			Size = UDim2.new(1, 0, 0, CARD_H),
			BackgroundColor3 = if selected == heroId then Theme.Hover else Theme.PanelAlt,
			BackgroundTransparency = if lifted then 0.6 else 0,
			AutoButtonColor = true,
			Text = "",
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
			Name = e(Widgets.Label, {
				text = `{Text.Advancement(hero.Class, hero.Advancement)}  Lv {hero.Level}`,
				bold = true,
				position = UDim2.fromOffset(10, 6),
				size = UDim2.new(1, -50, 0, 22),
			}),
			Sub = e(Widgets.Label, {
				text = sub,
				color = Theme.Subtext,
				textSize = 14,
				position = UDim2.fromOffset(10, 30),
				size = UDim2.new(1, -50, 0, 20),
			}),
			Remove = if memberIndex ~= nil
				then e(Widgets.Button, {
					text = "x",
					size = UDim2.fromOffset(30, 30),
					position = UDim2.new(1, -6, 0.5, 0),
					anchor = Vector2.new(1, 0.5),
					onClick = function()
						place(heroId, nil)
					end,
				})
				else nil,
		})
	end

	-- Row columns
	local columns: { [string]: React.ReactNode } = {}
	for col, row in DISPLAY_ROWS do
		local cards: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Vertical, 6) }
		local count = 0
		for i, entry in draft do
			if entry.Row == row and data.Heroes[entry.HeroId] ~= nil then
				count += 1
				cards[entry.HeroId] = card(entry.HeroId, i, i)
			end
		end
		columns[row] = e("TextButton", {
			Size = UDim2.new(1 / 3, -8, 1, 0),
			Position = UDim2.new((col - 1) / 3, 4, 0, 0),
			BackgroundColor3 = Theme.Bg,
			AutoButtonColor = false,
			Text = "",
			ref = zoneRef(row),
			[React.Event.Activated] = function()
				if selected ~= nil then
					place(selected, row)
				end
			end,
		}, {
			Corner = Widgets.Corner(8),
			Stroke = Widgets.Stroke(),
			Head = e(Widgets.Label, {
				text = `{Text.Row(row)}  {count}/{Formation.MaxPerRow}`,
				bold = true,
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(0, 6),
			}),
			Cards = e("Frame", {
				Size = UDim2.new(1, -16, 1, -40),
				Position = UDim2.fromOffset(8, 34),
				BackgroundTransparency = 1,
			}, cards),
		})
	end

	-- Bench
	local benchCards: { [string]: React.ReactNode } = {
		Layout = e("UIGridLayout", {
			CellSize = UDim2.new(0.25, -6, 0, CARD_H),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	local inTeam: { [string]: boolean } = {}
	for _, entry in draft do
		inTeam[entry.HeroId] = true
	end
	for i, def in Heroes.List do
		if data.Heroes[def.Id] ~= nil and not inTeam[def.Id] then
			benchCards[def.Id] = card(def.Id, i, nil)
		end
	end

	local dirty = signature(draft) ~= serverSig
	local speed = Formula.Team.Speed(speeds, Stages.ReferenceSpeed)

	local ghost: React.ReactNode = nil
	local root = rootRef.current
	if drag ~= nil and drag.Moved and root ~= nil and data.Heroes[drag.HeroId] ~= nil then
		local pos: Vector2 = drag.Pos
		local rel = pos - root.AbsolutePosition
		ghost = e("Frame", {
			Size = UDim2.fromOffset(180, 36),
			Position = UDim2.fromOffset(rel.X, rel.Y),
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

	return e(Widgets.Window, {
		title = UI.Team,
		group = "Team",
		onClose = function()
			State.SetPage(nil)
		end,
		closeOnBackdrop = true,
	}, {
		Root = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ref = rootRef }, {
			Info = e(Widgets.Label, {
				text = `Slots {#draft}/{slots}   ·   Team speed {math.floor(speed * 10 + 0.5) / 10}   ·   {UI.TeamHint}`,
				color = Theme.Subtext,
				textSize = 15,
				size = UDim2.new(1, -250, 0, 36),
				wrap = true,
			}),
			Reset = e(Widgets.Button, {
				text = UI.Reset,
				size = UDim2.fromOffset(110, 34),
				position = UDim2.new(1, -124, 0, 0),
				anchor = Vector2.new(1, 0),
				disabled = not dirty,
				onClick = function()
					setDraft(copyTeam(data.Team))
					setSelected(nil)
				end,
			}),
			Apply = e(Widgets.Button, {
				text = UI.Apply,
				size = UDim2.fromOffset(110, 34),
				position = UDim2.fromScale(1, 0),
				anchor = Vector2.new(1, 0),
				color = Theme.Confirm,
				disabled = not dirty or #draft == 0,
				onClick = function()
					State.Send.SetTeam(draft)
				end,
			}),
			Rows = e("Frame", {
				Size = UDim2.new(1, 0, 0.62, -50),
				Position = UDim2.fromOffset(0, 46),
				BackgroundTransparency = 1,
			}, columns),
			BenchHead = e(Widgets.Label, {
				text = UI.Bench,
				bold = true,
				position = UDim2.new(0, 0, 0.62, 4),
			}),
			Bench = e("TextButton", {
				Size = UDim2.new(1, 0, 0.38, -34),
				Position = UDim2.new(0, 0, 0.62, 30),
				BackgroundColor3 = Theme.Bg,
				AutoButtonColor = false,
				Text = "",
				ref = zoneRef("Bench"),
				[React.Event.Activated] = function()
					if selected ~= nil then
						place(selected, nil)
					end
				end,
			}, {
				Corner = Widgets.Corner(8),
				Stroke = Widgets.Stroke(),
				Padding = Widgets.Padding(8),
				Cards = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, benchCards),
			}),
			Ghost = ghost,
		}),
	})
end

return TeamPage
