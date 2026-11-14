--!strict
-- Daily reward page: the 7-day cycle with today's reward marked, claim button (server decides the day and streak).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Period = require(ReplicatedStorage.Shared.Period)
local Format = require(ReplicatedStorage.Shared.Format)
local Formula = require(ReplicatedStorage.Shared.Formula)
local DailyConfig = require(ReplicatedStorage.Shared.Config.Daily)
local Theme = require(script.Parent.Core.Theme)
local Widgets = require(script.Parent.Core.Widgets)
local State = require(script.Parent.Parent.State)

local e = React.createElement
local UI = Text.UI

local DAY = 86400

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

	local cards: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Horizontal, 8) }
	for i, reward in DailyConfig.Days do
		local gold = if reward.Gold ~= nil then Formula.Economy.Gold(reward.Gold, best) else nil
		local isToday = i == today
		cards[`D{i}`] = e("Frame", {
			Size = UDim2.fromOffset(112, 150),
			BackgroundColor3 = if isToday then Theme.Hover else Theme.PanelAlt,
			BorderSizePixel = 0,
			LayoutOrder = i,
		}, {
			Corner = Widgets.Corner(8),
			Stroke = Widgets.Stroke(),
			Padding = Widgets.Padding(8),
			Day = e(Widgets.Label, { text = `Day {i}`, bold = true, size = UDim2.new(1, 0, 0, 22) }),
			Reward = e(Widgets.Label, {
				text = Text.Eco.Reward(reward, gold),
				textSize = 15,
				wrap = true,
				color = if isToday then Theme.Text else Theme.Subtext,
				size = UDim2.new(1, 0, 1, -28),
				position = UDim2.fromOffset(0, 28),
			}),
		})
	end

	return e(Widgets.Window, {
		title = UI.Daily,
		onClose = function()
			State.SetPage(nil)
		end,
		closeOnBackdrop = true,
		size = UDim2.fromOffset(880, 290),
	}, {
		Cards = e("Frame", { Size = UDim2.new(1, 0, 0, 150), BackgroundTransparency = 1 }, cards),
		Hint = e(Widgets.Label, {
			text = `{UI.DailyHint}  Streak: {Format.Number(data.Daily.Streak)}`,
			color = Theme.Subtext,
			textSize = 15,
			size = UDim2.new(1, -220, 0, 40),
			position = UDim2.fromOffset(0, 168),
			wrap = true,
		}),
		Claim = e(Widgets.Button, {
			text = if claimedToday then UI.ClaimedToday else UI.Claim,
			size = UDim2.fromOffset(200, 44),
			position = UDim2.new(1, 0, 0, 166),
			anchor = Vector2.new(1, 0),
			disabled = claimedToday,
			selected = not claimedToday,
			onClick = State.Send.ClaimDaily,
		}),
	})
end

return Daily
