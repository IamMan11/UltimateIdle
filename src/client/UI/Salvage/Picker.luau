--!strict
-- Add item window (floating, opened from Auto Salvage): search + paged grid of the gear bases in the bag that are not on the salvage list. Click or drag across cells to pick several; Confirm adds them to the list.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local FloatWindow = require(script.Parent.Parent.Core.FloatWindow)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local State = require(script.Parent.Parent.Parent.State)
local BaseGrid = require(script.Parent.BaseGrid)
local Bases = require(script.Parent.Bases)

local e = React.createElement
local UI = Text.UI

local DEFAULT_SIZE = Vector2.new(1000, 640)
local MIN_SIZE = Vector2.new(560, 360)
local HEAD_H = 34
local HINT_H = 22
local GAP = 8

export type Props = { data: Types.ProfileData }

local function close()
	State.CloseWindow("SalvagePick")
end

local function Picker(props: Props): React.ReactNode
	local query, setQuery = React.useState("")
	-- Picks + drag mode in refs (drag events read them between renders); `bump` redraws.
	local picks = React.useRef({} :: { [string]: boolean })
	local adding = React.useRef(true)
	local version, setVersion = React.useState(0)
	local function bump()
		setVersion(version + 1)
	end

	local ids = Bases.Available(props.data, query)
	-- Every base still in the bag and off the list (picks hidden by the search stay picked).
	local open: { [string]: boolean } = {}
	for _, id in Bases.Available(props.data, "") do
		open[id] = true
	end
	local chosen: { string } = {}
	for _, id in Bases.Sorted(picks.current) do
		if open[id] then
			table.insert(chosen, id)
		end
	end

	local function apply(id: string)
		local set = picks.current
		if adding.current then
			set[id] = true
		else
			set[id] = nil
		end
		bump()
	end

	local footer: React.ReactNode = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Layout = Widgets.List(Enum.FillDirection.Horizontal, 8),
		Count = e(Widgets.Label, {
			text = `{#chosen} {UI.Picked}`,
			textSize = 15,
			size = UDim2.new(0, 110, 1, 0),
			layoutOrder = 1,
		}),
		Cancel = e(Widgets.Button, {
			text = UI.Cancel,
			size = UDim2.new(0, 96, 1, 0),
			textSize = 15,
			layoutOrder = 2,
			onClick = close,
		}),
		Confirm = e(Widgets.Button, {
			text = UI.Confirm,
			size = UDim2.new(0, 110, 1, 0),
			textSize = 15,
			color = Theme.Confirm,
			disabled = #chosen == 0,
			layoutOrder = 3,
			onClick = function()
				State.Send.SetSalvageItems(chosen, true)
				close()
			end,
		}),
	})

	return e(FloatWindow, {
		id = "SalvagePick",
		title = UI.AddItem,
		onClose = close,
		defaultSize = DEFAULT_SIZE,
		minSize = MIN_SIZE,
		zoom = Game.WindowZoom,
	}, {
		Search = e("Frame", { Size = UDim2.new(1, 0, 0, HEAD_H), BackgroundTransparency = 1 }, {
			Input = e(Widgets.TextInput, {
				text = query,
				placeholder = UI.Search,
				onChanged = setQuery,
			}),
		}),
		Hint = e(Widgets.Label, {
			text = UI.PickHint,
			color = Theme.Subtext,
			textSize = 13,
			size = UDim2.new(1, 0, 0, HINT_H),
			position = UDim2.fromOffset(0, HEAD_H + 4),
		}),
		Grid = e("Frame", {
			Size = UDim2.new(1, 0, 1, -(HEAD_H + HINT_H + GAP + 4)),
			Position = UDim2.fromOffset(0, HEAD_H + HINT_H + GAP + 4),
			BackgroundTransparency = 1,
		}, {
			Cells = e(BaseGrid, {
				ids = ids,
				cols = 8,
				rows = 7,
				marked = picks.current,
				empty = UI.PickNone,
				footer = footer,
				-- The pressed cell decides the drag: picking an unpicked cell picks, otherwise unpicks.
				onPress = function(id: string)
					adding.current = picks.current[id] ~= true
					apply(id)
				end,
				onDrag = apply,
			}),
		}),
	})
end

return Picker
