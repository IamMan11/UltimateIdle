--!strict
-- Always-on HUD: top row (leave idle · level / wave / stage · mode), profile card (avatar, account level + xp, rebirths, currencies), level panel, page buttons on the left and along the bottom, skip-wave / 2D-3D / settings at the bottom right, tutorial banner.

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
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)
local Device = require(script.Parent.Device)
local LevelPanel = require(script.Parent.LevelPanel)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement
local UI = Text.UI

local MARGIN = 12
local BUTTON_H = 40
local GAP = 6
local TOP_Y = 8
local LEAVE_W, INFO_W, MODE_W = 130, 370, 170
local PROFILE = Vector2.new(300, 100)
local AVATAR = 52
local SIDE_W = 140
local BOTTOM_W = 116
-- Roblox's touch thumbstick/jump button sit at the bottom corners while walking.
local TOUCH_CONTROLS_HEIGHT = 150

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

export type Props = {
	data: Types.ProfileData,
	compact: boolean?, -- short screen: the level panel starts folded
}

-- One HUD button: `id` = page id (and icon key), `tab` = page tab it opens (nil = the page's first).
type PageButton = { Id: string, Label: string, Tab: string?, Key: string }

-- Currency: icon + amount.
local function money(icon: string, text: string, position: UDim2): React.ReactNode
	return e("Frame", { Size = UDim2.new(0.5, -4, 0, 22), Position = position, BackgroundTransparency = 1 }, {
		Icon = e(Widgets.Icon, { image = icon, size = 22 }),
		Label = e(Widgets.Label, {
			text = text,
			bold = true,
			textSize = 16,
			size = UDim2.new(1, -28, 1, 0),
			position = UDim2.fromOffset(28, 0),
		}),
	})
end

local function profile(data: Types.ProfileData): React.ReactNode
	local player = Players.LocalPlayer
	local need = Formula.Progression.AccountXpToNext(data.AccountLevel)
	local ratio = math.clamp(data.AccountXp / math.max(need, 1), 0, 1)
	local right = AVATAR + 10
	return pill({
		Avatar = e("ImageLabel", {
			Size = UDim2.fromOffset(AVATAR, AVATAR),
			BackgroundColor3 = Theme.Bg,
			BorderSizePixel = 0,
			Image = `rbxthumb://type=AvatarHeadShot&id={player.UserId}&w=150&h=150`,
		}, { Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }),
		Name = e(Widgets.Label, {
			text = player.DisplayName,
			bold = true,
			position = UDim2.fromOffset(right, 0),
			size = UDim2.new(1, -right, 0, 22),
		}),
		Xp = e("Frame", {
			Size = UDim2.fromOffset(84, 18),
			Position = UDim2.fromOffset(right, 28),
			BackgroundColor3 = Theme.BarBack,
			BorderSizePixel = 0,
		}, {
			Corner = Widgets.Corner(9),
			Fill = e("Frame", {
				Size = UDim2.fromScale(ratio, 1),
				BackgroundColor3 = Theme.Bar,
				BorderSizePixel = 0,
			}, { Corner = Widgets.Corner(9) }),
			-- Over both the light fill and the dark back: outlined so it reads on either.
			Percent = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = `{math.floor(ratio * 100)}%`,
				TextColor3 = Theme.Text,
				FontFace = Theme.FontBold,
				TextSize = 13,
				ZIndex = 2,
			}, { Outline = e("UIStroke", { Color = Theme.OnLight, Thickness = 1.5 }) }),
		}),
		Level = e(Widgets.Label, {
			text = `{UI.Level} {data.AccountLevel}   {UI.Rebirth} {data.Rebirth.Count}`,
			textSize = 15,
			color = Theme.Subtext,
			position = UDim2.fromOffset(right + 92, 26),
			size = UDim2.new(1, -(right + 92), 0, 22),
		}),
		Gold = money(Icons.Gold, Format.Number(data.Gold), UDim2.new(0, 0, 1, -22)),
		Ruby = money(Icons.Ruby, Format.Number(data.Ruby), UDim2.new(0.5, 4, 1, -22)),
	}, {
		Size = UDim2.fromOffset(PROFILE.X, PROFILE.Y),
		Position = UDim2.new(1, -MARGIN, 0, TOP_Y),
		AnchorPoint = Vector2.new(1, 0),
	})
end

local function HUD(props: Props): React.ReactNode
	local data = props.data
	local battle = State.Battle
	local ui = State.Ui
	local levelsOpen, setLevelsOpen = React.useState(props.compact ~= true)
	local farmUnlocked = AccountConfig.IsUnlocked("Farm", data.AccountLevel, bestLevel(data))
	local tutorialStep = if data.Tutorial.Done then nil else TutorialConfig.Steps[data.Tutorial.Step]
	local mode = data.Stage.Mode
	local walking = ui.CameraMode == "Walk"
	local lift = if Device.IsTouch() and walking then TOUCH_CONTROLS_HEIGHT else 0

	local side: { PageButton } = {
		{ Id = "Team", Label = UI.Team, Key = "Team" },
		{ Id = "Inventory", Label = UI.Inventory, Key = "Inventory" },
		{ Id = "Rebirth", Label = UI.Rebirth, Key = "Rebirth" },
		{ Id = "Quests", Label = Text.Eco.UI.Quests, Key = "Quests" },
	}
	if RunService:IsStudio() then
		table.insert(side, { Id = "Dev", Label = UI.Dev, Key = "Dev" })
	end
	local bottom: { PageButton } = {
		{ Id = "Trade", Label = tradeLabel(data), Key = "Trade" },
		{
			Id = "Daily",
			Label = if data.Daily.Day ~= Period.Key("Daily") then `{UI.Daily} •` else UI.Daily,
			Key = "Daily",
		},
		{ Id = "Quests", Label = UI.BattlePass, Tab = "Pass", Key = "BattlePass" },
		{ Id = "Shop", Label = UI.Gamepass, Tab = "Passes", Key = "Gamepass" },
		{ Id = "Codes", Label = UI.Code, Key = "Codes" },
	}

	local function pageButton(button: PageButton, size: UDim2, order: number): React.ReactNode
		-- A button with a tab is lit only on that tab; the page's plain button on its other tabs.
		local open = ui.Page == button.Id
			and (if button.Tab ~= nil then ui.PageTab == button.Tab else ui.PageTab ~= "Pass")
		local hinted = tutorialStep ~= nil and tutorialStep.Page == button.Id and button.Tab == nil
		return e(Widgets.Button, {
			text = button.Label,
			icon = if button.Tab == nil then Icons[button.Id] else nil,
			size = size,
			textSize = 15,
			layoutOrder = order,
			selected = open or hinted,
			onClick = function()
				State.OpenPage(button.Id, button.Tab)
			end,
		})
	end

	local sideButtons: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Vertical, GAP) }
	for i, button in side do
		sideButtons[button.Key] = pageButton(button, UDim2.fromOffset(SIDE_W, BUTTON_H), i)
	end
	local bottomButtons: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Horizontal, GAP) }
	for i, button in bottom do
		bottomButtons[button.Key] = pageButton(button, UDim2.fromOffset(BOTTOM_W, BUTTON_H), i)
	end

	local topW = LEAVE_W + INFO_W + MODE_W + GAP * 2
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = Theme.ZHud }, {
		Top = e("Frame", {
			Size = UDim2.fromOffset(topW, BUTTON_H),
			Position = UDim2.new(0.5, 0, 0, TOP_Y),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
		}, {
			-- Walk around the lobby while the team keeps fighting; the same button brings the lane view back.
			Leave = e(Widgets.Button, {
				icon = Icons.Camera,
				iconSize = 24,
				text = if walking then UI.BackToIdle else UI.LeaveIdle,
				size = UDim2.fromOffset(LEAVE_W, BUTTON_H),
				textSize = 15,
				selected = walking,
				onClick = function()
					State.SetCamera(if walking then "Lane" else "Walk", ui.View)
				end,
			}),
			Info = pill({
				Label = e(Widgets.Label, {
					text = `{UI.Level} {battle.Level}   ·   {UI.Wave} {battle.Wave}/{Stages.WavesPerLevel}   ·   {UI.Stage} {data.Stage.Rebirth + 1}`,
					size = UDim2.fromScale(1, 1),
					bold = true,
					align = Enum.TextXAlignment.Center,
				}),
			}, {
				Size = UDim2.fromOffset(INFO_W, BUTTON_H),
				Position = UDim2.fromOffset(LEAVE_W + GAP, 0),
			}),
			Mode = e(Widgets.Button, {
				icon = Icons.Farm,
				iconSize = 24,
				text = if not farmUnlocked
					then UI.FarmLocked
					elseif mode == "Farm" then UI.ModeFarm
					else UI.ModeProgress,
				size = UDim2.fromOffset(MODE_W, BUTTON_H),
				position = UDim2.fromScale(1, 0),
				anchor = Vector2.new(1, 0),
				textSize = if farmUnlocked then 15 else 12,
				disabled = not farmUnlocked,
				onClick = function()
					State.Send.SetStageMode(if mode == "Farm" then "Progress" else "Farm")
				end,
			}),
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
				Position = UDim2.new(0.5, 0, 0, TOP_Y + BUTTON_H + 8),
				AnchorPoint = Vector2.new(0.5, 0),
			})
			else nil,
		Profile = profile(data),
		Levels = e(LevelPanel, {
			data = data,
			open = levelsOpen,
			onToggle = function()
				setLevelsOpen(not levelsOpen)
			end,
			top = TOP_Y + PROFILE.Y + 8,
			bottom = MARGIN + BUTTON_H + 8 + lift,
		}),
		Side = e("Frame", {
			Size = UDim2.fromOffset(SIDE_W, (BUTTON_H + GAP) * #side),
			Position = UDim2.fromOffset(MARGIN, TOP_Y + BUTTON_H + 16),
			BackgroundTransparency = 1,
		}, sideButtons),
		Bottom = e("Frame", {
			Size = UDim2.fromOffset((BOTTOM_W + GAP) * #bottom, BUTTON_H),
			Position = UDim2.new(0, MARGIN, 1, -MARGIN - lift),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,
		}, bottomButtons),
		Controls = e("Frame", {
			Size = UDim2.fromOffset(400, BUTTON_H),
			Position = UDim2.new(1, -MARGIN, 1, -MARGIN - lift),
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Skip = e(Widgets.Button, {
				icon = Icons.Skip,
				iconSize = 24,
				text = if not data.Settings.SkipWave
					then UI.SkipOff
					elseif battle.Skip then UI.SkipOn
					else UI.SkipWaiting,
				size = UDim2.fromOffset(170, BUTTON_H),
				textSize = if data.Settings.SkipWave and not battle.Skip then 11 else 14,
				selected = data.Settings.SkipWave,
				layoutOrder = 1,
				onClick = function()
					State.Send.SetSetting("SkipWave", nil, not data.Settings.SkipWave)
				end,
			}),
			View = e(Widgets.Button, {
				icon = Icons.View,
				iconSize = 24,
				text = if ui.View == "2D" then UI.Cam2D else UI.Cam3D,
				size = UDim2.fromOffset(84, BUTTON_H),
				textSize = 15,
				layoutOrder = 2,
				disabled = walking,
				onClick = function()
					State.SetCamera(ui.CameraMode, if ui.View == "2D" then "3D" else "2D")
				end,
			}),
			Settings = e(Widgets.Button, {
				icon = Icons.Settings,
				iconSize = 24,
				text = UI.Settings,
				size = UDim2.fromOffset(124, BUTTON_H),
				textSize = 15,
				layoutOrder = 3,
				selected = ui.Page == "Settings",
				onClick = function()
					State.SetPage("Settings")
				end,
			}),
		}),
	})
end

return HUD
