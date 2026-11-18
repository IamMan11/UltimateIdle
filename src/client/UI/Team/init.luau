--!strict
-- Team window (floating, resizable, place saved): left = class preview + class strip + gear slots · middle = level path / gear picker + Skill Tree button · right = formation preview + row places.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Heroes = require(ReplicatedStorage.Shared.Config.Heroes)
local FloatWindow = require(script.Parent.Core.FloatWindow)
local Widgets = require(script.Parent.Core.Widgets)
local HeroPanel = require(script.HeroPanel)
local LevelPanel = require(script.LevelPanel)
local Formation = require(script.Formation)
local State = require(script.Parent.Parent.State)

local e = React.createElement

local DEFAULT_SIZE = Vector2.new(1160, 640)
local MIN_SIZE = Vector2.new(860, 500)
-- Column widths as shares of the window; GAP is the space between columns.
local LEFT, MIDDLE = 0.27, 0.38
local GAP = 12

export type Props = { data: Types.ProfileData }

local function firstOwned(data: Types.ProfileData): string
	for _, def in Heroes.List do
		if data.Heroes[def.Id] ~= nil then
			return def.Id
		end
	end
	return Heroes.List[1].Id
end

local function close()
	State.CloseWindow("Team")
end

local function TeamPage(props: Props): React.ReactNode
	local data = props.data
	local classId, setClassId = React.useState(firstOwned(data))
	local slot, setSlot = Widgets.useOptional(nil :: string?)

	local select = React.useCallback(function(id: string)
		setClassId(id)
		setSlot(nil)
	end, {})

	return e(FloatWindow, {
		id = "Team",
		title = Text.UI.Team,
		onClose = close,
		defaultSize = DEFAULT_SIZE,
		minSize = MIN_SIZE,
	}, {
		Left = e("Frame", { Size = UDim2.new(LEFT, -GAP, 1, 0), BackgroundTransparency = 1 }, {
			Panel = e(HeroPanel, {
				data = data,
				classId = classId,
				slot = slot,
				onSelect = select,
				onSlot = setSlot,
			}),
		}),
		Middle = e("Frame", {
			Size = UDim2.new(MIDDLE, -GAP, 1, 0),
			Position = UDim2.fromScale(LEFT, 0),
			BackgroundTransparency = 1,
		}, {
			Panel = e(LevelPanel, { data = data, classId = classId, slot = slot, onSlot = setSlot }),
		}),
		Right = e("Frame", {
			Size = UDim2.fromScale(1 - LEFT - MIDDLE, 1),
			Position = UDim2.fromScale(LEFT + MIDDLE, 0),
			BackgroundTransparency = 1,
		}, {
			Panel = e(Formation, { data = data, selected = classId, onSelect = select }),
		}),
	})
end

return TeamPage
