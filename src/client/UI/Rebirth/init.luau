--!strict
-- Rebirth page: which owned rebirth to play, next rebirth's requirement + what it gives, rebirth button (confirm).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Format = require(ReplicatedStorage.Shared.Format)
local RebirthConfig = require(ReplicatedStorage.Shared.Config.Rebirth)
local Theme = require(script.Parent.Core.Theme)
local Widgets = require(script.Parent.Core.Widgets)
local State = require(script.Parent.Parent.State)

local e = React.createElement
local UI = Text.UI

export type Props = { data: Types.ProfileData }

local function progressOf(data: Types.ProfileData, rebirth: number): Types.StageProgress?
	return data.Stage.ByRebirth[tostring(rebirth)]
end

local function pct(v: number): string
	return `{math.floor(v * 100 + 0.5)}%`
end

local function gains(now: RebirthConfig.RebirthDef, nextDef: RebirthConfig.RebirthDef): { string }
	local lines = {
		`Hero level cap {now.HeroLevelCap} -> {nextDef.HeroLevelCap}`,
		`Item drop level cap {now.ItemLevelCap} -> {nextDef.ItemLevelCap}`,
		`Wear caps {table.concat(now.WearCaps, "/")} -> {table.concat(nextDef.WearCaps, "/")}`,
		`Account level cap {now.AccountLevelCap} -> {nextDef.AccountLevelCap}`,
		`Gold / xp bonus {pct(now.GoldPct)} -> {pct(nextDef.GoldPct)}`,
		`+{nextDef.Points} {UI.RebirthPoints}`,
	}
	local items: { string } = {}
	for id, n in nextDef.Items do
		table.insert(items, `{n} {Text.Material(id)}`)
	end
	table.sort(items)
	if #items > 0 then
		table.insert(lines, table.concat(items, ", "))
	end
	table.insert(lines, `Monsters in rebirth {nextDef.Index}: x{Format.Number(nextDef.Difficulty)} stats`)
	return lines
end

local function RebirthPage(props: Props): React.ReactNode
	local data = props.data
	local count = data.Rebirth.Count
	local playing = data.Stage.Rebirth
	local now = RebirthConfig.Get(count)
	local nextDef = RebirthConfig.Next(count)
	local top = progressOf(data, count)
	local cleared = if top ~= nil then top.MaxLevel - 1 else 0

	local playButtons: { [string]: React.ReactNode } = {
		Grid = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(150, 48),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for r = 0, count do
		local p = progressOf(data, r)
		playButtons[`R{r}`] = e(Widgets.Button, {
			text = `R{r} · Lv {if p ~= nil then p.Level else 1}`,
			selected = r == playing,
			layoutOrder = r,
			onClick = function()
				if r ~= playing then
					State.Send.SetPlayRebirth(r)
				end
			end,
		})
	end

	local nextBlock: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Vertical, 6) }
	if nextDef == nil then
		nextBlock.Max = e(Widgets.Label, { text = UI.RebirthMaxed, bold = true, layoutOrder = 1 })
	else
		local ready = cleared >= nextDef.RequiredLevel
		nextBlock.Head = e(Widgets.Label, {
			text = `Next: Rebirth {nextDef.Index}`,
			bold = true,
			textSize = 20,
			layoutOrder = 1,
		})
		nextBlock.Req = e(Widgets.Label, {
			text = `Clear level {nextDef.RequiredLevel} in rebirth {count} · cleared {math.max(cleared, 0)}`,
			color = if ready then Theme.Text else Theme.Subtext,
			layoutOrder = 2,
		})
		nextBlock.Bar = e(Widgets.Bar, {
			ratio = if nextDef.RequiredLevel > 0 then cleared / nextDef.RequiredLevel else 1,
			layoutOrder = 3,
		})
		local lines = gains(now, nextDef)
		nextBlock.Gains = e(Widgets.Label, {
			text = table.concat(lines, "\n"),
			size = UDim2.new(1, 0, 0, 22 * #lines),
			wrap = true,
			layoutOrder = 4,
		})
		nextBlock.Keeps = e(Widgets.Label, {
			text = UI.RebirthKeeps,
			color = Theme.Subtext,
			textSize = 15,
			size = UDim2.new(1, 0, 0, 40),
			wrap = true,
			layoutOrder = 5,
		})
		nextBlock.Go = e(Widgets.Button, {
			text = if ready then `Rebirth to {nextDef.Index}` else UI.Locked,
			size = UDim2.fromOffset(220, 48),
			color = if ready then Theme.Confirm else nil,
			disabled = not ready,
			layoutOrder = 6,
			onClick = function()
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
		})
	end

	return e(Widgets.Window, {
		title = `{UI.Rebirth}  {count}   ·   {data.Rebirth.Points} {UI.RebirthPoints}`,
		onClose = function()
			State.SetPage(nil)
		end,
		closeOnBackdrop = true,
		maxSize = Vector2.new(900, 680),
	}, {
		PlayHead = e(Widgets.Label, { text = UI.PlayRebirth, bold = true }),
		PlayHint = e(Widgets.Label, {
			text = UI.PlayHint,
			color = Theme.Subtext,
			textSize = 15,
			position = UDim2.fromOffset(0, 24),
		}),
		Play = e("ScrollingFrame", {
			Size = UDim2.new(1, 0, 0, 56),
			Position = UDim2.fromOffset(0, 52),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, playButtons),
		Next = e("Frame", {
			Size = UDim2.new(1, 0, 1, -120),
			Position = UDim2.fromOffset(0, 120),
			BackgroundColor3 = Theme.Bg,
		}, {
			Corner = Widgets.Corner(8),
			Padding = Widgets.Padding(12),
			Body = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, nextBlock),
		}),
	})
end

return RebirthPage
