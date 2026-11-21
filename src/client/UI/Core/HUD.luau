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
local IconOf = require(ReplicatedStorage.Shared.Config.IconOf)
local Theme = require(script.Parent.Theme)
local Art = require(script.Parent.Art)
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
local PROFILE = Vector2.new(320, 112)
local AVATAR = 52
local SIDE_W = 140
local BOTTOM_W = 116
-- Roblox's touch thumbstick/jump button sit at the bottom corners while walking.
local TOUCH_CONTROLS_HEIGHT = 150

-- HUD plate: a frame-art background (paper notice by default) with padding; `props` are Frame props.
local function pill(
	children: { [string]: React.ReactNode },
	props: { [string]: any },
	piece: string?,
	pad: number?
): React.ReactNode
	local frameProps: { [string]: any } = { BackgroundTransparency = 1 }
	for k, v in props do
		frameProps[k] = v
	end
	children.Art = Art.Back({ piece = piece or "NoticePaper", padding = pad or 10 })
	children.Padding = Widgets.Padding(pad or 10)
	return e("Frame", frameProps, children)
end

-- Wave progress: one lozenge per wave, filled up to the current one.
local function pips(current: number, total: number): React.ReactNode
	local items: { [string]: React.ReactNode } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 7),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for i = 1, total do
		local filled = i <= current
		items["P" .. i] = e("Frame", {
			Size = UDim2.fromOffset(8, 8),
			Rotation = 45,
			BackgroundColor3 = Theme.Gold,
			BackgroundTransparency = if filled then 0 else 1,
			BorderSizePixel = 0,
			LayoutOrder = i,
		}, {
			Ring = if filled then nil else e("UIStroke", { Color = Theme.Gold, Thickness = 1.2, Transparency = 0.35 }),
		})
	end
	return e("Frame", { Size = UDim2.fromOffset(total * 15, 12), BackgroundTransparency = 1 }, items)
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
local function money(icon: Icons.Icon, text: string, position: UDim2, size: UDim2): React.ReactNode
	return e("Frame", { Size = size, Position = position, BackgroundTransparency = 1 }, {
		Icon = e(Widgets.Icon, { image = icon, size = 22 }),
		Label = e(Widgets.Label, {
			text = text,
			bold = true,
			textSize = 17,
			color = Theme.OnDark,
			size = UDim2.new(1, -28, 1, 0),
			position = UDim2.fromOffset(28, 0),
		}),
	})
end

local function profile(data: Types.ProfileData): React.ReactNode
	local player = Players.LocalPlayer
	local need = Formula.Progression.AccountXpToNext(data.AccountLevel)
	local ratio = math.clamp(data.AccountXp / math.max(need, 1), 0, 1)
	local right = AVATAR + 14
	return pill({
		Avatar = e("ImageLabel", {
			Size = UDim2.fromOffset(AVATAR, AVATAR),
			Position = UDim2.fromOffset(2, 2),
			BackgroundColor3 = Theme.Wood,
			BorderSizePixel = 0,
			Image = `rbxthumb://type=AvatarHeadShot&id={player.UserId}&w=150&h=150`,
		}, { Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }),
		Ring = e(Art.Image, {
			piece = "GiltRingPortrait",
			width = AVATAR + 8,
			position = UDim2.fromOffset(-2, -2),
			zIndex = 2,
		}),
		Name = e(Widgets.Label, {
			text = player.DisplayName,
			bold = true,
			color = Theme.OnDark,
			position = UDim2.fromOffset(right, 0),
			size = UDim2.new(1, -(right + 84), 0, 22),
		}),
		Rebirth = e(Widgets.Label, {
			text = `{UI.Rebirth} {data.Rebirth.Count}`,
			textSize = 14,
			color = Theme.OnDarkSub,
			align = Enum.TextXAlignment.Right,
			position = UDim2.new(1, -84, 0, 2),
			size = UDim2.fromOffset(84, 20),
		}),
		Level = e(Widgets.Label, {
			text = `{UI.Level} {data.AccountLevel}`,
			bold = true,
			textSize = 14,
			color = Theme.Gold,
			position = UDim2.fromOffset(right, 26),
			size = UDim2.fromOffset(70, 18),
		}),
		Xp = e(Widgets.Bar, {
			ratio = ratio,
			size = UDim2.new(1, -(right + 70 + 42), 0, 16),
			position = UDim2.fromOffset(right + 70, 27),
		}),
		Percent = e(Widgets.Label, {
			text = `{math.floor(ratio * 100)}%`,
			textSize = 13,
			color = Theme.OnDarkSub,
			align = Enum.TextXAlignment.Right,
			position = UDim2.new(1, -38, 0, 26),
			size = UDim2.fromOffset(38, 18),
		}),
		Gold = money(
			Icons.Gold,
			Format.Number(data.Gold),
			UDim2.new(0, right, 1, -22),
			UDim2.new(0.5, -right / 2 - 4, 0, 22)
		),
		Ruby = money(
			Icons.Ruby,
			Format.Number(data.Ruby),
			UDim2.new(0.5, right / 2 + 4, 1, -22),
			UDim2.new(0.5, -right / 2 - 4, 0, 22)
		),
	}, {
		Size = UDim2.fromOffset(PROFILE.X, PROFILE.Y),
		Position = UDim2.new(1, -MARGIN, 0, TOP_Y),
		AnchorPoint = Vector2.new(1, 0),
	}, "Plaque", 18)
end

local function HUD(props: Props): React.ReactNode
	local data = props.data
	local battle = State.Battle
	local stageIcon = IconOf.Stage(data.Stage.Rebirth)
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
		{ Id = "BattlePass", Label = UI.BattlePass, Key = "BattlePass" },
		{ Id = "Shop", Label = UI.Gamepass, Tab = "Passes", Key = "Gamepass" },
		{ Id = "Codes", Label = UI.Code, Key = "Codes" },
	}

	local function pageButton(button: PageButton, size: UDim2, order: number): React.ReactNode
		-- A button with a tab is lit only on that tab.
		local open = State.IsOpen(button.Id) and (button.Tab == nil or ui.PageTabs[button.Id] == button.Tab)
		local hinted = tutorialStep ~= nil and tutorialStep.Page == button.Id and button.Tab == nil
		return e(Widgets.Button, {
			text = button.Label,
			icon = if button.Tab == nil then Icons[button.Id] else nil,
			size = size,
			textSize = 15,
			layoutOrder = order,
			selected = open or hinted,
			onClick = function()
				State.ToggleWindow(button.Id, button.Tab)
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
			Info = e("Frame", {
				Size = UDim2.fromOffset(INFO_W, BUTTON_H),
				Position = UDim2.fromOffset(LEAVE_W + GAP, 0),
				BackgroundTransparency = 1,
			}, {
				Art = Art.Back({ piece = "TitleBarSlim" }),
				StageIcon = if stageIcon ~= nil
					then e(Widgets.Icon, {
						image = stageIcon,
						size = 28,
						position = UDim2.new(0, 3, 0.5, 0),
						anchor = Vector2.new(0, 0.5),
					})
					else nil,
				WaveIcon = e(Widgets.Icon, {
					image = if battle.Wave >= Stages.WavesPerLevel then Icons.Wave_Boss else Icons.Wave,
					size = 28,
					position = UDim2.new(1, -3, 0.5, 0),
					anchor = Vector2.new(1, 0.5),
				}),
				Stage = e(Widgets.Label, {
					text = `{UI.Stage} {data.Stage.Rebirth + 1}`,
					textSize = 14,
					color = Theme.OnDarkSub,
					position = UDim2.fromOffset(32, 0),
					size = UDim2.new(0, 90, 1, 0),
				}),
				Level = e(Widgets.Label, {
					text = `{UI.Level} {battle.Level}`,
					bold = true,
					textSize = 24,
					color = Theme.Gold,
					align = Enum.TextXAlignment.Center,
					position = UDim2.fromScale(0.5, 0),
					anchor = Vector2.new(0.5, 0),
					size = UDim2.new(0, 150, 1, 0),
				}),
				Wave = e("Frame", {
					Size = UDim2.new(0, 130, 1, 0),
					Position = UDim2.new(1, -32, 0, 0),
					AnchorPoint = Vector2.new(1, 0),
					BackgroundTransparency = 1,
				}, {
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 8),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					Pips = pips(battle.Wave, Stages.WavesPerLevel),
					Count = e("TextLabel", {
						Text = `{battle.Wave}/{Stages.WavesPerLevel}`,
						Size = UDim2.fromOffset(34, 20),
						BackgroundTransparency = 1,
						TextColor3 = Theme.OnDark,
						FontFace = Theme.Font,
						TextSize = Theme.Body(14),
						TextXAlignment = Enum.TextXAlignment.Right,
						LayoutOrder = 2,
					}),
				}),
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
				Size = UDim2.fromOffset(470, 54),
				Position = UDim2.new(0.5, 0, 0, TOP_Y + BUTTON_H + 10),
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
				selected = State.IsOpen("Settings"),
				onClick = function()
					State.ToggleWindow("Settings")
				end,
			}),
		}),
	})
end

return HUD
