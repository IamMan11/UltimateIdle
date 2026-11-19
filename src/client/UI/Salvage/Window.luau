--!strict
-- Auto Salvage window (floating, opened from Inventory): tier ticks on the left, Add item (opens the picker) in the middle, the salvage list on the right with Clear + ON/OFF. Double click a listed item = remove it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local FloatWindow = require(script.Parent.Parent.Core.FloatWindow)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local Tip = require(script.Parent.Parent.Core.Tip)
local State = require(script.Parent.Parent.Parent.State)
local BaseGrid = require(script.Parent.BaseGrid)
local Bases = require(script.Parent.Bases)

local e = React.createElement
local UI = Text.UI

local DEFAULT_SIZE = Vector2.new(1160, 640)
local MIN_SIZE = Vector2.new(640, 360)
local LEFT_W = 240
local MID_W = 150
local GAP = 14
local HEAD_H = 36
local HINT_H = 22
local ROW_H = 44

export type Props = { data: Types.ProfileData }

local function close()
	State.CloseWindow("SalvagePick")
	State.CloseWindow("AutoSalvage")
end

local function hint(settings: Types.Settings, listed: number): string
	if not settings.AutoSalvageOn then
		return UI.SalvageOff
	end
	local anyTier = false
	for _, tier in Tiers.List do
		if settings.AutoSalvage[tier.Id] == true then
			anyTier = true
		end
	end
	return if anyTier and listed > 0 then UI.SalvageActive else UI.SalvageNeedBoth
end

local function AutoSalvage(props: Props): React.ReactNode
	local settings = props.data.Settings
	local picked, setPicked = Widgets.useOptional(nil :: string?)
	local listed = Bases.Sorted(settings.SalvageItems)
	local on = settings.AutoSalvageOn

	local tierRows: { [string]: React.ReactNode } = {
		Layout = Widgets.List(Enum.FillDirection.Vertical, 8),
		Title = e(Widgets.Label, { text = UI.SelectTier, bold = true, layoutOrder = 0 }),
	}
	for i, tier in Tiers.List do
		local ticked = settings.AutoSalvage[tier.Id] == true
		tierRows[tier.Id] = e(
			"Frame",
			{ Size = UDim2.new(1, 0, 0, ROW_H), BackgroundTransparency = 1, LayoutOrder = i },
			{
				Name = e(Widgets.Label, {
					text = Text.Tier(tier.Id),
					textSize = 20,
					size = UDim2.new(1, -76, 1, 0),
				}),
				Tick = e(Widgets.Button, {
					text = if ticked then UI.On else UI.Off,
					size = UDim2.fromOffset(70, ROW_H),
					position = UDim2.fromScale(1, 0),
					anchor = Vector2.new(1, 0),
					textSize = 15,
					selected = ticked,
					onClick = function()
						State.Send.SetSetting("AutoSalvage", tier.Id, not ticked)
					end,
				}),
			}
		)
	end

	local marked: { [string]: boolean } = {}
	if picked ~= nil then
		marked[picked] = true
	end

	local rightX = LEFT_W + GAP + MID_W + GAP
	return e(FloatWindow, {
		id = "AutoSalvage",
		title = UI.AutoSalvage,
		onClose = close,
		defaultSize = DEFAULT_SIZE,
		minSize = MIN_SIZE,
		zoom = Game.WindowZoom,
	}, {
		Tiers = e("Frame", {
			Size = UDim2.new(0, LEFT_W, 1, 0),
			BackgroundColor3 = Theme.Bg,
		}, {
			Corner = Widgets.Corner(8),
			Padding = Widgets.Padding(12),
			Rows = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, tierRows),
		}),
		Add = e(Widgets.Button, {
			text = UI.AddItem,
			size = UDim2.fromOffset(MID_W, 48),
			position = UDim2.new(0, LEFT_W + GAP, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
			textSize = 17,
			selected = State.IsOpen("SalvagePick"),
			onClick = function()
				State.OpenWindow("SalvagePick")
			end,
		}),
		List = e("Frame", {
			Size = UDim2.new(1, -rightX, 1, 0),
			Position = UDim2.fromOffset(rightX, 0),
			BackgroundColor3 = Theme.Bg,
		}, {
			Corner = Widgets.Corner(8),
			Padding = Widgets.Padding(12),
			Title = e(Widgets.Label, {
				text = `{UI.SalvageList}  ({#listed})`,
				bold = true,
				size = UDim2.fromOffset(160, HEAD_H),
			}),
			Clear = e(Widgets.Button, {
				text = UI.Clear,
				size = UDim2.fromOffset(84, HEAD_H),
				position = UDim2.fromOffset(168, 0),
				textSize = 15,
				color = Theme.Danger,
				disabled = #listed == 0,
				onClick = function()
					State.Send.SetSalvageItems(listed, false)
					setPicked(nil)
				end,
			}),
			Switch = e(Widgets.Button, {
				text = `{UI.AutoSalvageButton}: {if on then UI.On else UI.Off}`,
				size = UDim2.fromOffset(120, HEAD_H),
				position = UDim2.fromScale(1, 0),
				anchor = Vector2.new(1, 0),
				textSize = 15,
				color = if on then Theme.Confirm else nil,
				onClick = function()
					State.Send.SetSetting("AutoSalvageOn", nil, not on)
				end,
			}),
			Hint = e(Widgets.Label, {
				text = `{hint(settings, #listed)}  {UI.SalvageRemoveHint}`,
				color = Theme.Subtext,
				textSize = 13,
				size = UDim2.new(1, 0, 0, HINT_H),
				position = UDim2.fromOffset(0, HEAD_H + 4),
			}),
			Grid = e("Frame", {
				Size = UDim2.new(1, 0, 1, -(HEAD_H + HINT_H + 12)),
				Position = UDim2.fromOffset(0, HEAD_H + HINT_H + 12),
				BackgroundTransparency = 1,
			}, {
				Cells = e(BaseGrid, {
					ids = listed,
					cols = 9,
					rows = 7,
					marked = marked,
					empty = UI.SalvageEmpty,
					onClick = function(id: string)
						if Tip.Double("Salvage:" .. id) then
							State.Send.SetSalvageItems({ id }, false)
							setPicked(nil)
						else
							setPicked(id)
						end
					end,
				}),
			}),
		}),
	})
end

return AutoSalvage
