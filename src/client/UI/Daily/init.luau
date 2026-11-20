--!strict
-- Daily reward window: the 7-day cycle as cards (days 1-6 in two rows, day 7 tall on the right), today's marked, claim button (server decides the day and streak).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Period = require(ReplicatedStorage.Shared.Period)
local Format = require(ReplicatedStorage.Shared.Format)
local Formula = require(ReplicatedStorage.Shared.Formula)
local DailyConfig = require(ReplicatedStorage.Shared.Config.Daily)
local Theme = require(script.Parent.Core.Theme)
local Art = require(script.Parent.Core.Art)
local FloatWindow = require(script.Parent.Core.FloatWindow)
local Widgets = require(script.Parent.Core.Widgets)
local State = require(script.Parent.Parent.State)

local e = React.createElement
local UI = Text.UI

local DAY = 86400
local CELL = 124
local GAP = 16
local LABEL_H = 26
local TALL = 190 -- day 4
local LAST_W = 200 -- day 7
local ROW2_Y = CELL + LABEL_H + GAP
local GRID = Vector2.new(3 * (CELL + GAP) + LAST_W, ROW2_Y + TALL + LABEL_H)
local FOOTER_H = 60
-- Content laid out at this size and scaled to the window; CHROME = FloatWindow title bar + padding.
local BODY = Vector2.new(GRID.X + 4, GRID.Y + 4 + FOOTER_H)
local CHROME = Vector2.new(28, 68)

-- Card rectangles by day: x, y, width, height (the day label sits under each).
local RECTS: { { number } } = {
	{ 0, 0, CELL, CELL },
	{ CELL + GAP, 0, CELL, CELL },
	{ 2 * (CELL + GAP), 0, CELL, CELL },
	{ 0, ROW2_Y, CELL, TALL },
	{ CELL + GAP, ROW2_Y, CELL, CELL },
	{ 2 * (CELL + GAP), ROW2_Y, CELL, CELL },
	{ 3 * (CELL + GAP), 0, LAST_W, ROW2_Y + TALL },
}

export type Props = { data: Types.ProfileData }

local function bestLevel(data: Types.ProfileData): number
	local best = 1
	for _, p in data.Stage.ByRebirth do
		best = math.max(best, p.MaxLevel)
	end
	return best
end

-- Cycle day the next claim pays (mirrors Systems/Daily.NextDay; the server's answer is what counts).
local function nextDay(daily: Types.DailyState, now: number): number
	local yesterday = Period.Key("Daily", now - DAY)
	local streak = if daily.Day == yesterday then daily.Streak + 1 else 1
	return (streak - 1) % #DailyConfig.Days + 1
end

local function Daily(props: Props): React.ReactNode
	local data = props.data
	local now = os.time()
	local claimedToday = data.Daily.Day == Period.Key("Daily", now)
	-- Already claimed today: highlight the day just paid.
	local today = if claimedToday then (data.Daily.Streak - 1) % #DailyConfig.Days + 1 else nextDay(data.Daily, now)
	local best = bestLevel(data)

	local cards: { [string]: React.ReactNode } = {}
	for i, reward in DailyConfig.Days do
		local rect = RECTS[i]
		if rect == nil then
			continue
		end
		local gold = if reward.Gold ~= nil then Formula.Economy.Gold(reward.Gold, best) else nil
		local isToday = i == today
		local claimed = i < today or (isToday and claimedToday)
		local text = string.gsub(Text.Eco.Reward(reward, gold), ", ", "\n")
		cards[`D{i}`] = e("Frame", {
			Size = UDim2.fromOffset(rect[3], rect[4] + LABEL_H),
			Position = UDim2.fromOffset(rect[1] + 2, rect[2] + 2),
			BackgroundTransparency = 1,
		}, {
			Card = e("Frame", {
				Size = UDim2.fromOffset(rect[3], rect[4]),
				BackgroundTransparency = 1,
			}, {
				Art = Art.Back({
					piece = if isToday and not claimed then "BtnPaperHover" else "PaperCompactSharp",
					transparency = if claimed then 0.45 else 0,
					padding = 10,
				}),
				Glow = if isToday and not claimed then Widgets.Stroke(Theme.Accent, 2) else nil,
				Padding = Widgets.Padding(10),
				Reward = e(Widgets.Label, {
					text = if claimed then `{text}\n({Text.Eco.UI.Claimed})` else text,
					textSize = if i == #RECTS then 18 else 15,
					bold = isToday and not claimed,
					wrap = true,
					align = Enum.TextXAlignment.Center,
					color = if claimed then Theme.Subtext else Theme.Text,
					size = UDim2.fromScale(1, 1),
				}),
			}),
			Day = e(Widgets.Label, {
				text = `{UI.Day} {i}`,
				bold = isToday,
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(1, 0, 0, LABEL_H),
				position = UDim2.fromOffset(0, rect[4]),
			}),
		})
	end

	return e(FloatWindow, {
		id = "Daily",
		title = UI.Daily,
		onClose = function()
			State.CloseWindow("Daily")
		end,
		defaultSize = BODY + CHROME,
		minSize = BODY * 0.6,
		fit = BODY,
	}, {
		Cards = e("Frame", { Size = UDim2.fromOffset(GRID.X + 4, GRID.Y + 4), BackgroundTransparency = 1 }, cards),
		Hint = e(Widgets.Label, {
			text = `{UI.DailyHint}  Streak: {Format.Number(data.Daily.Streak)}`,
			color = Theme.Subtext,
			textSize = 15,
			size = UDim2.new(1, -220, 0, 44),
			position = UDim2.fromScale(0, 1),
			anchor = Vector2.new(0, 1),
			wrap = true,
		}),
		Claim = e(Widgets.Button, {
			text = if claimedToday then UI.ClaimedToday else UI.Claim,
			size = UDim2.fromOffset(200, 44),
			position = UDim2.fromScale(1, 1),
			anchor = Vector2.new(1, 1),
			color = if claimedToday then nil else Theme.Confirm,
			disabled = claimedToday,
			onClick = State.Send.ClaimDaily,
		}),
	})
end

return Daily
