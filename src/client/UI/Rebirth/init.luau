--!strict
-- Rebirth window: current rebirth's caps on the left, the next one's on the right, the level requirement and the Rebirth button (confirm) under them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Format = require(ReplicatedStorage.Shared.Format)
local RebirthConfig = require(ReplicatedStorage.Shared.Config.Rebirth)
local Theme = require(script.Parent.Core.Theme)
local FloatWindow = require(script.Parent.Core.FloatWindow)
local Widgets = require(script.Parent.Core.Widgets)
local State = require(script.Parent.Parent.State)

local e = React.createElement
local UI = Text.UI

local WINDOW = Vector2.new(940, 580)
local CARD = Vector2.new(380, 236)
local CARD_Y = 36
local ARROW_Y = CARD_Y + CARD.Y / 2
local REQUIRE_Y = CARD_Y + CARD.Y + 14
local CHIP = Vector2.new(320, 48)

export type Props = { data: Types.ProfileData }

local function pct(v: number): string
	return `+{math.floor(v * 100 + 0.5)}%`
end

local function caps(def: RebirthConfig.RebirthDef): { string }
	return {
		`Hero level cap {def.HeroLevelCap}`,
		`Item drop level cap {def.ItemLevelCap}`,
		`Wear caps {table.concat(def.WearCaps, " / ")}`,
		`Account level cap {def.AccountLevelCap}`,
		`Gold / xp bonus {pct(def.GoldPct)}`,
		`Monster stats x{Format.Number(def.Difficulty)}`,
	}
end

-- One-time rewards for reaching `def`.
local function rewards(def: RebirthConfig.RebirthDef): { string }
	local lines = { `+{def.Points} {UI.RebirthPoints}` }
	local items: { string } = {}
	for id, n in def.Items do
		table.insert(items, `{n} {Text.Material(id)}`)
	end
	table.sort(items)
	if #items > 0 then
		table.insert(lines, table.concat(items, ", "))
	end
	return lines
end

local function card(head: string, lines: { string }?, placeholder: string?, x: number): React.ReactNode
	return e("Frame", {
		Size = UDim2.fromOffset(CARD.X, CARD_Y + CARD.Y),
		Position = UDim2.fromOffset(x, 0),
		BackgroundTransparency = 1,
	}, {
		Head = e(Widgets.Label, { text = head, bold = true, textSize = 20, size = UDim2.new(1, 0, 0, 26) }),
		Card = e("Frame", {
			Size = UDim2.fromOffset(CARD.X, CARD.Y),
			Position = UDim2.fromOffset(0, CARD_Y),
			BackgroundColor3 = Theme.Bg,
			BorderSizePixel = 0,
		}, {
			Corner = Widgets.Corner(8),
			Stroke = Widgets.Stroke(),
			Padding = Widgets.Padding(14),
			Lines = if lines ~= nil
				then e(Widgets.Label, {
					text = table.concat(lines, "\n"),
					textSize = 17,
					wrap = true,
					alignY = Enum.TextYAlignment.Top,
					size = UDim2.fromScale(1, 1),
				})
				else nil,
			Placeholder = if placeholder ~= nil
				then e(Widgets.Label, {
					text = placeholder,
					bold = true,
					textSize = 20,
					color = Theme.Subtext,
					align = Enum.TextXAlignment.Center,
					size = UDim2.fromScale(1, 1),
				})
				else nil,
		}),
	})
end

local function RebirthPage(props: Props): React.ReactNode
	local data = props.data
	local count = data.Rebirth.Count
	local now = RebirthConfig.Get(count)
	local nextDef = RebirthConfig.Next(count)
	local top = data.Stage.ByRebirth[tostring(count)]
	local cleared = math.max(if top ~= nil then top.MaxLevel - 1 else 0, 0)
	local ready = nextDef ~= nil and cleared >= nextDef.RequiredLevel
	local right = WINDOW.X - 40 - CARD.X
	local gap = right - CARD.X

	local nextLines: { string }? = nil
	if nextDef ~= nil then
		local lines = caps(nextDef)
		for _, line in rewards(nextDef) do
			table.insert(lines, line)
		end
		nextLines = lines
	end

	return e(FloatWindow, {
		id = "Rebirth",
		title = `{UI.Rebirth}   ·   {data.Rebirth.Points} {UI.RebirthPoints}`,
		onClose = function()
			State.CloseWindow("Rebirth")
		end,
		defaultSize = WINDOW - Vector2.new(12, 14),
		minSize = Vector2.new(560, 360),
		fit = WINDOW - Vector2.new(40, 82),
	}, {
		Current = card(
			`{UI.CurrentRebirth}: {count}{if nextDef == nil then ` ({UI.RebirthMax})` else ""}`,
			caps(now),
			nil,
			0
		),
		Next = card(
			`{UI.NextRebirth}: {if nextDef ~= nil then tostring(nextDef.Index) else `({UI.RebirthWait})`}`,
			nextLines,
			if nextDef == nil then `{UI.NextRebirth}: ({UI.RebirthWait})` else nil,
			right
		),
		Arrow = e("Frame", {
			Size = UDim2.fromOffset(gap - 16, 44),
			Position = UDim2.fromOffset(CARD.X + 8, ARROW_Y - 30),
			BackgroundTransparency = 1,
		}, {
			Label = e(Widgets.Label, {
				text = UI.NextRebirth,
				textSize = 15,
				color = Theme.Subtext,
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(1, 0, 0, 20),
			}),
			Line = e("Frame", {
				Size = UDim2.new(1, -8, 0, 3),
				Position = UDim2.fromOffset(0, 29),
				BackgroundColor3 = Theme.Outline,
				BorderSizePixel = 0,
			}),
			Head = e(Widgets.Label, {
				text = ">",
				bold = true,
				textSize = 26,
				align = Enum.TextXAlignment.Right,
				size = UDim2.fromOffset(20, 26),
				position = UDim2.new(1, 0, 0, 17),
				anchor = Vector2.new(1, 0),
			}),
		}),
		Requirement = if nextDef ~= nil
			then e("Frame", {
				Size = UDim2.new(1, 0, 0, 24 + CHIP.Y),
				Position = UDim2.fromOffset(0, REQUIRE_Y),
				BackgroundTransparency = 1,
			}, {
				Head = e(Widgets.Label, {
					text = UI.Requirement,
					textSize = 15,
					color = Theme.Subtext,
					align = Enum.TextXAlignment.Center,
				}),
				Chip = e("Frame", {
					Size = UDim2.fromOffset(CHIP.X, CHIP.Y),
					Position = UDim2.new(0.5, 0, 0, 24),
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundColor3 = if ready then Theme.Hover else Theme.PanelAlt,
					BorderSizePixel = 0,
				}, {
					Corner = Widgets.Corner(8),
					Stroke = Widgets.Stroke(),
					Padding = Widgets.Padding(8),
					Label = e(Widgets.Label, {
						text = `{UI.Stage} {count + 1} {UI.Level} {math.min(cleared, nextDef.RequiredLevel)}/{nextDef.RequiredLevel}`,
						bold = true,
						textSize = 16,
						align = Enum.TextXAlignment.Center,
						size = UDim2.new(1, 0, 0, 20),
					}),
					Bar = e(Widgets.Bar, {
						ratio = if nextDef.RequiredLevel > 0 then cleared / nextDef.RequiredLevel else 1,
						position = UDim2.new(0, 0, 1, -6),
					}),
				}),
			})
			else nil,
		Keeps = if nextDef ~= nil
			then e(Widgets.Label, {
				text = UI.RebirthKeeps,
				color = Theme.Subtext,
				textSize = 14,
				align = Enum.TextXAlignment.Center,
				position = UDim2.new(0, 0, 1, -84),
				size = UDim2.new(1, 0, 0, 20),
			})
			else nil,
		Go = e(Widgets.Button, {
			text = if nextDef == nil then UI.RebirthMax elseif ready then UI.Rebirth else UI.Locked,
			size = UDim2.fromOffset(240, 52),
			position = UDim2.fromScale(0.5, 1),
			anchor = Vector2.new(0.5, 1),
			textSize = 20,
			color = if ready then Theme.Confirm else nil,
			disabled = not ready,
			onClick = function()
				if nextDef == nil then
					return
				end
				State.OpenConfirm({
					Title = `Rebirth to {nextDef.Index}?`,
					Body = `Nothing is reset. You keep everything and start rebirth {nextDef.Index} at your current level; monsters there have x{Format.Number(
						nextDef.Difficulty
					)} stats. You can still play lower rebirths.`,
					OkText = `Rebirth to {nextDef.Index}`,
					Danger = false,
					OnConfirm = function()
						State.Send.Rebirth()
					end,
				})
			end,
		}),
	})
end

return RebirthPage
