--!strict
-- Settings window: search box, group list on the left (click = jump to the group), every setting as a row with its control on the right.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Theme = require(script.Parent.Core.Theme)
local FloatWindow = require(script.Parent.Core.FloatWindow)
local Widgets = require(script.Parent.Core.Widgets)
local State = require(script.Parent.Parent.State)

local e = React.createElement
local UI = Text.UI

local WINDOW = Vector2.new(800, 560)
local TOP_H = 46
local NAV_W = 180
local HEAD_H = 32
local ROW_H = 46
local ROW_GAP = 6
local GROUP_GAP = 14
local CONTROL_W = 130

export type Props = { data: Types.ProfileData }

type Row = {
	Key: string,
	Label: string,
	Hint: string?,
	Value: string,
	On: boolean?, -- toggles: drawn selected when on
	Disabled: boolean?,
	OnClick: () -> (),
}

type Group = { Id: string, Title: string, Rows: { Row } }

local function onOff(on: boolean): string
	return if on then UI.On else UI.Off
end

local function groups(data: Types.ProfileData): { Group }
	local settings = data.Settings
	local mods = Formula.Mods.Build(data.SkillTree, data.SkillOff, data.AccountLevel)
	local scale = settings.UiScale or 1

	return {
		{
			Id = "Gameplay",
			Title = UI.GroupGameplay,
			Rows = {
				{
					Key = "SkipWave",
					Label = UI.SkipShort,
					Hint = UI.SkipHint,
					Value = onOff(settings.SkipWave),
					On = settings.SkipWave,
					OnClick = function()
						State.Send.SetSetting("SkipWave", nil, not settings.SkipWave)
					end,
				},
				{
					Key = "AutoOpen",
					Label = UI.AutoOpen,
					Hint = if mods.AutoOpen
						then `Every {math.floor(mods.AutoOpenInterval * 10 + 0.5) / 10}s`
						else UI.AutoOpenHint,
					Value = if mods.AutoOpen then onOff(settings.AutoOpenBoxes) else UI.Locked,
					On = mods.AutoOpen and settings.AutoOpenBoxes,
					Disabled = not mods.AutoOpen,
					OnClick = function()
						State.Send.SetSetting("AutoOpenBoxes", nil, not settings.AutoOpenBoxes)
					end,
				},
			},
		},
		{
			Id = "Display",
			Title = UI.GroupDisplay,
			Rows = {
				{
					Key = "UiScale",
					Label = UI.UiSize,
					Value = `{math.floor(scale * 100 + 0.5)}%`,
					OnClick = function()
						local i = table.find(Game.UiScales, scale) or 0
						State.Send.SetSetting("UiScale", nil, Game.UiScales[i % #Game.UiScales + 1])
					end,
				},
				{
					Key = "LowDetail",
					Label = UI.LowDetail,
					Value = onOff(settings.LowDetail),
					On = settings.LowDetail,
					OnClick = function()
						State.Send.SetSetting("LowDetail", nil, not settings.LowDetail)
					end,
				},
			},
		},
		{
			Id = "Help",
			Title = UI.GroupHelp,
			Rows = {
				{
					Key = "Tutorial",
					Label = UI.ReplayTutorial,
					Value = UI.Open,
					OnClick = function()
						State.Send.TutorialRestart()
						State.CloseWindow("Settings")
					end,
				},
			},
		},
	}
end

local function has(text: string, query: string): boolean
	return string.find(string.lower(text), query, 1, true) ~= nil
end

local function settingRow(row: Row, y: number): React.ReactNode
	local hint = row.Hint
	return e("Frame", {
		Size = UDim2.new(1, -12, 0, ROW_H),
		Position = UDim2.fromOffset(2, y),
		BackgroundColor3 = Theme.PanelAlt,
		BorderSizePixel = 0,
	}, {
		Corner = Widgets.Corner(6),
		Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 6) }),
		Label = e(Widgets.Label, {
			text = row.Label,
			size = UDim2.new(1, -(CONTROL_W + 10), 0, 22),
			position = if hint ~= nil then UDim2.fromOffset(0, 4) else UDim2.new(0, 0, 0.5, -11),
		}),
		Hint = if hint ~= nil
			then e(Widgets.Label, {
				text = hint,
				textSize = 13,
				color = Theme.Subtext,
				size = UDim2.new(1, -(CONTROL_W + 10), 0, 16),
				position = UDim2.fromOffset(0, 26),
			})
			else nil,
		Control = e(Widgets.Button, {
			text = row.Value,
			size = UDim2.fromOffset(CONTROL_W, 36),
			position = UDim2.fromScale(1, 0.5),
			anchor = Vector2.new(1, 0.5),
			textSize = 15,
			selected = row.On == true,
			disabled = row.Disabled == true,
			onClick = row.OnClick,
		}),
	})
end

local function Settings(props: Props): React.ReactNode
	local search, setSearch = React.useState("")
	local listRef = React.useRef(nil :: ScrollingFrame?)
	local query = string.lower((string.gsub(search, "^%s+", "")))

	local rows: { [string]: React.ReactNode } = {}
	local nav: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Vertical, 6) }
	local y = 2
	local shown = 0
	local tops: { [string]: number } = {}
	for order, group in groups(props.data) do
		local whole = query == "" or has(group.Title, query)
		local visible: { Row } = {}
		for _, row in group.Rows do
			if whole or has(row.Label, query) then
				table.insert(visible, row)
			end
		end
		if #visible > 0 then
			shown += 1
			tops[group.Id] = y
			rows[`Head{group.Id}`] = e(Widgets.Label, {
				text = group.Title,
				bold = true,
				textSize = 20,
				size = UDim2.new(1, -12, 0, HEAD_H),
				position = UDim2.fromOffset(2, y),
			})
			y += HEAD_H
			for _, row in visible do
				rows[`{group.Id}_{row.Key}`] = settingRow(row, y)
				y += ROW_H + ROW_GAP
			end
			y += GROUP_GAP
			nav[group.Id] = e(Widgets.Button, {
				text = group.Title,
				size = UDim2.new(1, 0, 0, 38),
				textSize = 15,
				layoutOrder = order,
				onClick = function()
					local list = listRef.current
					if list ~= nil then
						-- CanvasPosition is in real pixels, the rows in design units.
						local ratio = list.AbsoluteCanvasSize.Y / math.max(list.CanvasSize.Y.Offset, 1)
						list.CanvasPosition = Vector2.new(0, (tops[group.Id] - 2) * ratio)
					end
				end,
			})
		end
	end
	if shown == 0 then
		rows.Empty = e(Widgets.Label, {
			text = UI.SettingsNone,
			color = Theme.Subtext,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, -12, 0, 40),
		})
	end

	return e(FloatWindow, {
		id = "Settings",
		title = UI.Settings,
		onClose = function()
			State.CloseWindow("Settings")
		end,
		defaultSize = WINDOW - Vector2.new(12, 14),
		minSize = Vector2.new(560, 400),
	}, {
		Search = e(Widgets.TextInput, {
			text = search,
			placeholder = UI.SettingsSearch,
			onChanged = setSearch,
			size = UDim2.new(0.7, 0, 0, 34),
		}),
		Nav = e("Frame", {
			Size = UDim2.new(0, NAV_W, 1, -TOP_H),
			Position = UDim2.fromOffset(0, TOP_H),
			BackgroundColor3 = Theme.Bg,
			BorderSizePixel = 0,
		}, {
			Corner = Widgets.Corner(8),
			Stroke = Widgets.Stroke(),
			Padding = Widgets.Padding(8),
			Buttons = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, nav),
		}),
		List = e("ScrollingFrame", {
			ref = listRef,
			Size = UDim2.new(1, -(NAV_W + 14), 1, -TOP_H),
			Position = UDim2.fromOffset(NAV_W + 14, TOP_H),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Stroke,
			CanvasSize = UDim2.fromOffset(0, y),
		}, rows),
	})
end

return Settings
