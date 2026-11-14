--!strict
-- Always-on HUD: level/wave, tutorial banner, currencies, team levels/xp, page buttons, skip-wave / camera / watch-lane / mode toggles.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Format = require(ReplicatedStorage.Shared.Format)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Text = require(ReplicatedStorage.Shared.Text)
local AccountConfig = require(ReplicatedStorage.Shared.Config.Account)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.Tutorial)
local Period = require(ReplicatedStorage.Shared.Period)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)
local Device = require(script.Parent.Device)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement
local UI = Text.UI

local function pill(children: { [string]: React.ReactNode }, props: { [string]: any }): React.ReactNode
	local frameProps: { [string]: any } = {
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}
	for k, v in props do
		frameProps[k] = v
	end
	children.Corner = Widgets.Corner(10)
	children.Stroke = Widgets.Stroke()
	children.Padding = Widgets.Padding(8)
	return e("Frame", frameProps, children)
end

local function bestLevel(data: Types.ProfileData): number
	local best = 1
	for _, p in data.Stage.ByRebirth do
		best = math.max(best, p.MaxLevel)
	end
	return best
end

-- "Trade", with the pending request count or a mark while a trade is open.
local function tradeLabel(_data: Types.ProfileData): string
	if State.Trade ~= nil then
		return `{Text.Eco.UI.Trade} •`
	end
	local n = #State.LiveRequests()
	return if n > 0 then `{Text.Eco.UI.Trade} ({n})` else Text.Eco.UI.Trade
end

-- Other players with a lane, in lane order.
local function otherLanes(): { Player }
	local list: { Player } = {}
	for _, p in Players:GetPlayers() do
		if p ~= Players.LocalPlayer and type(p:GetAttribute("Lane")) == "number" then
			table.insert(list, p)
		end
	end
	table.sort(list, function(a, b)
		return (a:GetAttribute("Lane") :: number) < (b:GetAttribute("Lane") :: number)
	end)
	return list
end

-- Own lane -> each other lane in order -> own lane.
local function nextWatch()
	local list = otherLanes()
	local current = State.Ui.Watch
	local index = 0
	for i, p in list do
		if p.UserId == current then
			index = i
		end
	end
	State.SetWatch(if index < #list then list[index + 1].UserId else nil)
	State.SetCamera("Lane", State.Ui.View)
end

local function watchLabel(): string
	local watching = if State.Ui.Watch ~= nil then Players:GetPlayerByUserId(State.Ui.Watch) else nil
	if watching ~= nil then
		return `Watch: {watching.DisplayName}`
	end
	return if #otherLanes() > 0 then UI.WatchOwn else UI.WatchNone
end

export type Props = {
	data: Types.ProfileData,
	compact: boolean?, -- short screen: page buttons in a 2-column grid at the top-left
	tight: boolean?, -- phone landscape: no team panel (it would sit under the page grid)
}

-- Roblox's touch thumbstick/jump button sit at the bottom corners while walking.
local TOUCH_CONTROLS_HEIGHT = 150

local function HUD(props: Props): React.ReactNode
	local data = props.data
	local battle = State.Battle
	local ui = State.Ui
	local farmUnlocked = AccountConfig.IsUnlocked("Farm", data.AccountLevel, bestLevel(data))

	local team: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Vertical, 4) }
	for i, slot in data.Team do
		local hero = data.Heroes[slot.HeroId]
		if hero ~= nil then
			local need = Formula.Progression.HeroXpToNext(hero.Level)
			team[`H{i}`] = e("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = i }, {
				Name = e(Widgets.Label, {
					text = `{Text.Advancement(hero.Class, hero.Advancement)}  Lv {hero.Level}`,
					size = UDim2.new(1, 0, 0, 20),
					textSize = 16,
				}),
				Xp = e(Widgets.Bar, { ratio = hero.Xp / need, position = UDim2.fromOffset(0, 24) }),
			})
		end
	end

	local pages = {
		{ "Heroes", UI.Heroes },
		{ "Team", UI.Team },
		{ "Tree", UI.Tree },
		{ "Bag", UI.Bag },
		{ "Boxes", UI.Boxes },
		{ "Forge", UI.Forge },
		{ "Rebirth", UI.Rebirth },
		{ "Quests", Text.Eco.UI.Quests },
		{ "Shop", Text.Eco.UI.Shop },
		{ "Trade", tradeLabel(data) },
		{ "Daily", if data.Daily.Day ~= Period.Key("Daily") then `{UI.Daily} •` else UI.Daily },
		{ "Settings", UI.Settings },
	}
	local tutorialStep = if data.Tutorial.Done then nil else TutorialConfig.Steps[data.Tutorial.Step]
	if RunService:IsStudio() then
		table.insert(pages, { "Dev", UI.Dev })
	end
	local compact = props.compact == true
	local pageButtons: { [string]: React.ReactNode } = {
		Layout = if compact
			then e("UIGridLayout", {
				CellSize = UDim2.fromOffset(120, 40),
				CellPadding = UDim2.fromOffset(6, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
			else Widgets.List(Enum.FillDirection.Vertical, 6),
	}
	for i, page in pages do
		pageButtons[page[1]] = e(Widgets.Button, {
			text = page[2],
			size = UDim2.fromOffset(120, 40),
			layoutOrder = i,
			selected = ui.Page == page[1] or (tutorialStep ~= nil and tutorialStep.Page == page[1]),
			onClick = function()
				State.SetPage(page[1])
			end,
		})
	end

	local mode = data.Stage.Mode
	local touchWalk = Device.IsTouch() and ui.CameraMode == "Walk"
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = Theme.ZHud }, {
		Top = pill({
			Label = e(Widgets.Label, {
				text = `{UI.Level} {battle.Level}   ·   {UI.Wave} {battle.Wave}/{Stages.WavesPerLevel}   ·   {if mode
						== "Farm"
					then "Farm"
					else "Progress"}`,
				size = UDim2.fromScale(1, 1),
				bold = true,
				align = Enum.TextXAlignment.Center,
			}),
		}, {
			Size = UDim2.fromOffset(380, 40),
			Position = UDim2.new(0.5, 0, 0, 8),
			AnchorPoint = Vector2.new(0.5, 0),
		}),
		Tutorial = if tutorialStep ~= nil
			then pill({
				Label = e(Widgets.Label, {
					text = `{data.Tutorial.Step}/{#TutorialConfig.Steps}  {Text.Tutorial[tutorialStep.Id] or tutorialStep.Id}`,
					size = UDim2.new(1, -80, 1, 0),
					wrap = true,
					textSize = 16,
				}),
				Skip = e(Widgets.Button, {
					text = UI.SkipTutorial,
					size = UDim2.fromOffset(70, 30),
					position = UDim2.fromScale(1, 0.5),
					anchor = Vector2.new(1, 0.5),
					textSize = 14,
					onClick = State.Send.TutorialSkip,
				}),
			}, {
				Size = UDim2.fromOffset(460, 52),
				Position = UDim2.new(0.5, 0, 0, 56),
				AnchorPoint = Vector2.new(0.5, 0),
			})
			else nil,
		Money = pill({
			Layout = Widgets.List(Enum.FillDirection.Vertical, 2),
			Gold = e(Widgets.Label, { text = `{UI.Gold}  {Format.Number(data.Gold)}`, bold = true, layoutOrder = 1 }),
			Ruby = e(Widgets.Label, { text = `{UI.Ruby}  {Format.Number(data.Ruby)}`, layoutOrder = 2 }),
			Account = e(Widgets.Label, {
				text = `Account Lv {data.AccountLevel}`,
				color = Theme.Subtext,
				textSize = 15,
				layoutOrder = 3,
			}),
		}, {
			Size = UDim2.fromOffset(210, 90),
			Position = UDim2.new(1, -12, 0, 60),
			AnchorPoint = Vector2.new(1, 0),
		}),
		Team = if touchWalk
			then nil
			else pill(team, {
				Size = UDim2.fromOffset(220, 24 + 36 * math.max(#data.Team, 1)),
				Position = UDim2.new(0, 12, 1, -12),
				AnchorPoint = Vector2.new(0, 1),
			}),
		Pages = e("Frame", {
			Size = if compact
				then UDim2.fromOffset(246, 46 * math.ceil(#pages / 2))
				else UDim2.fromOffset(120, 46 * #pages),
			Position = if compact then UDim2.fromOffset(12, 8) else UDim2.new(0, 12, 0.5, 0),
			AnchorPoint = if compact then Vector2.zero else Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
		}, pageButtons),
		Controls = e("Frame", {
			Size = UDim2.fromOffset(190, 266),
			Position = UDim2.new(1, -12, 1, if touchWalk then -12 - TOUCH_CONTROLS_HEIGHT else -12),
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
		}, {
			Layout = Widgets.List(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right),
			Skip = e(Widgets.Button, {
				text = if not data.Settings.SkipWave
					then UI.SkipOff
					elseif battle.Skip then UI.SkipOn
					else UI.SkipWaiting,
				size = UDim2.fromOffset(190, 40),
				textSize = if data.Settings.SkipWave and not battle.Skip then 13 else nil,
				selected = data.Settings.SkipWave,
				layoutOrder = 1,
				onClick = function()
					State.Send.SetSetting("SkipWave", nil, not data.Settings.SkipWave)
				end,
			}),
			Camera = e(Widgets.Button, {
				text = if ui.CameraMode == "Lane" then UI.CamLane else UI.CamWalk,
				size = UDim2.fromOffset(190, 40),
				layoutOrder = 2,
				onClick = function()
					State.SetCamera(if ui.CameraMode == "Lane" then "Walk" else "Lane", ui.View)
				end,
			}),
			View = e(Widgets.Button, {
				text = if ui.View == "2D" then UI.Cam2D else UI.Cam3D,
				size = UDim2.fromOffset(190, 40),
				layoutOrder = 3,
				disabled = ui.CameraMode ~= "Lane",
				onClick = function()
					State.SetCamera(ui.CameraMode, if ui.View == "2D" then "3D" else "2D")
				end,
			}),
			Watch = e(Widgets.Button, {
				text = watchLabel(),
				size = UDim2.fromOffset(190, 40),
				layoutOrder = 5,
				textSize = 15,
				selected = ui.Watch ~= nil,
				disabled = ui.Watch == nil and #otherLanes() == 0,
				onClick = nextWatch,
			}),
			Mode = e(Widgets.Button, {
				text = if not farmUnlocked
					then UI.FarmLocked
					elseif mode == "Farm" then UI.ModeFarm
					else UI.ModeProgress,
				size = UDim2.fromOffset(190, 40),
				layoutOrder = 4,
				disabled = not farmUnlocked,
				textSize = 15,
				onClick = function()
					State.Send.SetStageMode(if mode == "Farm" then "Progress" else "Farm")
				end,
			}),
		}),
	})
end

return HUD
