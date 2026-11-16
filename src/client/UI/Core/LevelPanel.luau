--!strict
-- HUD level panel (right side, folds away with its arrow): the levels reached in the stage being played (stage = the rebirth being played), newest first, with a search box. Picking a level pins it (the team stays on it, win or lose) and highlights it; "Go to latest level" unpins. The stage button swaps the list for the stages to pick from.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)
local VirtualList = require(script.Parent.VirtualList)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement
local UI = Text.UI

local WIDTH = 236
local ARROW_W = 24
local HEAD_H = 34
local FOOT_H = 36
local ROW_H = 36
local GAP = 8

export type Props = {
	data: Types.ProfileData,
	open: boolean,
	onToggle: () -> (),
	top: number, -- y of the panel's top edge
	bottom: number, -- space kept free under it
}

-- Stage shown to players: rebirth 0 is stage 1.
local function stageName(rebirth: number): string
	return `{UI.Stage} {rebirth + 1}`
end

local function LevelPanel(props: Props): React.ReactNode
	local data = props.data
	local query, setQuery = React.useState("")
	local picking, setPicking = React.useState(false) -- true = the list shows stages instead of levels

	local stage = data.Stage
	local progress: Types.StageProgress? = stage.ByRebirth[tostring(stage.Rebirth)]
	local maxLevel = if progress ~= nil then progress.MaxLevel else 1
	local pin = if progress ~= nil then progress.Pin else nil
	local farm = stage.Mode == "Farm"

	local arrow = e(Widgets.Button, {
		text = if props.open then ">" else "<",
		size = UDim2.fromOffset(ARROW_W, 56),
		position = UDim2.new(1, if props.open then -(WIDTH + 4) else 0, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		onClick = props.onToggle,
	})
	local frame = {
		Size = UDim2.new(0, WIDTH + ARROW_W + 4, 1, -(props.top + props.bottom)),
		Position = UDim2.new(1, -12, 0, props.top),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
	}
	if not props.open then
		return e("Frame", frame, { Arrow = arrow })
	end

	local list: React.ReactNode
	if picking then
		local count = data.Rebirth.Count + 1
		list = e(VirtualList, {
			count = count,
			rowHeight = ROW_H,
			renderRow = function(index: number): React.ReactNode
				local rebirth = count - index -- newest stage first
				return e(Widgets.Button, {
					text = stageName(rebirth),
					size = UDim2.fromScale(1, 1),
					textSize = 15,
					selected = rebirth == stage.Rebirth,
					onClick = function()
						if rebirth ~= stage.Rebirth then
							State.Send.SetPlayRebirth(rebirth)
						end
						setPicking(false)
					end,
				})
			end,
		})
	else
		-- Newest level first; the search keeps the levels whose number starts with what was typed.
		local levels: { number } = {}
		for level = maxLevel, 1, -1 do
			if query == "" or string.sub(tostring(level), 1, #query) == query then
				table.insert(levels, level)
			end
		end
		list = e(VirtualList, {
			count = #levels,
			rowHeight = ROW_H,
			renderRow = function(index: number): React.ReactNode
				local level = levels[index]
				return e(Widgets.Button, {
					text = `{UI.Level} {level}`,
					size = UDim2.fromScale(1, 1),
					textSize = 15,
					selected = pin == level,
					disabled = farm,
					onClick = function()
						if pin ~= level then
							State.Send.SetStageLevel(level)
						end
					end,
				})
			end,
		})
	end

	return e("Frame", frame, {
		Arrow = arrow,
		Panel = e("Frame", {
			Size = UDim2.new(0, WIDTH, 1, 0),
			Position = UDim2.fromScale(1, 0),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Theme.Panel,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
		}, {
			Corner = Widgets.Corner(10),
			Stroke = Widgets.Stroke(),
			Padding = Widgets.Padding(8),
			Search = e("Frame", { Size = UDim2.new(1, -96, 0, HEAD_H), BackgroundTransparency = 1 }, {
				Input = e(Widgets.TextInput, {
					text = query,
					placeholder = UI.SearchLevel,
					onChanged = function(text: string)
						-- Level numbers only.
						setQuery((string.gsub(text, "%D", "")))
					end,
				}),
			}),
			Stage = e(Widgets.Button, {
				text = stageName(stage.Rebirth),
				size = UDim2.fromOffset(90, HEAD_H),
				position = UDim2.fromScale(1, 0),
				anchor = Vector2.new(1, 0),
				textSize = 14,
				selected = picking,
				onClick = function()
					setPicking(not picking)
				end,
			}),
			Note = if farm and not picking
				then e(Widgets.Label, {
					text = UI.LevelsFarm,
					color = Theme.Subtext,
					textSize = 13,
					wrap = true,
					position = UDim2.fromOffset(0, HEAD_H + 4),
					size = UDim2.new(1, 0, 0, 32),
				})
				else nil,
			List = e("Frame", {
				Size = UDim2.new(1, 0, 1, -(HEAD_H + FOOT_H + GAP * 2 + (if farm and not picking then 36 else 0))),
				Position = UDim2.fromOffset(0, HEAD_H + GAP + (if farm and not picking then 36 else 0)),
				BackgroundTransparency = 1,
			}, {
				-- Keyed by what is listed so the list starts at the top after a switch.
				[if picking then "Stages" else `Levels{stage.Rebirth}`] = list,
			}),
			Latest = e(Widgets.Button, {
				text = UI.GoLatest,
				size = UDim2.new(1, 0, 0, FOOT_H),
				position = UDim2.fromScale(0, 1),
				anchor = Vector2.new(0, 1),
				textSize = 15,
				color = if pin ~= nil and not farm then Theme.Confirm else nil,
				disabled = pin == nil or farm,
				onClick = function()
					State.Send.SetStageLevel(0)
				end,
			}),
		}),
	})
end

return LevelPanel
