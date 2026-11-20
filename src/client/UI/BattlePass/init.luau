--!strict
-- Battle Pass window: level progress + claim all on top, one row of reward cells per track (normal / premium) scrolling sideways together, season countdown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Format = require(ReplicatedStorage.Shared.Format)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Period = require(ReplicatedStorage.Shared.Period)
local PassConfig = require(ReplicatedStorage.Shared.Config.BattlePass)
local ShopConfig = require(ReplicatedStorage.Shared.Config.Shop)
local Theme = require(script.Parent.Core.Theme)
local Art = require(script.Parent.Core.Art)
local FloatWindow = require(script.Parent.Core.FloatWindow)
local Widgets = require(script.Parent.Core.Widgets)
local State = require(script.Parent.Parent.State)

local e = React.createElement
local UI = Text.Eco.UI

local WINDOW = Vector2.new(1000, 470)
-- FloatWindow frame around the content (title bar + padding).
local CHROME = Vector2.new(12, 14)
local TOP_H = 36
local LABEL_W = 150
local CELL = 96
local STEP = CELL + 14
local ROW_H = CELL + 40
local ROWS_Y = TOP_H + 16
local CANVAS_W = PassConfig.Tiers * STEP

export type Props = { data: Types.ProfileData }

local TRACKS: { PassConfig.Track } = { "Free", "Paid" }

local function bestLevel(data: Types.ProfileData): number
	local best = 1
	for _, p in data.Stage.ByRebirth do
		best = math.max(best, p.MaxLevel)
	end
	return best
end

-- Ticks by itself so the reward cells are not redrawn every second.
local function SeasonClock(): React.ReactNode
	Widgets.useTick(1)
	return e(Widgets.Label, {
		text = `{UI.SeasonEnds} {Format.Time(math.max(Period.Ends("Monthly") - os.time(), 0))}`,
		color = Theme.Subtext,
		textSize = 16,
		size = UDim2.new(1, 0, 0, 22),
		position = UDim2.fromScale(0, 1),
		anchor = Vector2.new(0, 1),
	})
end

type CellState = "Locked" | "Open" | "Claimed"

local function cell(
	text: string,
	tier: number,
	row: number,
	state: CellState,
	reached: boolean,
	onClaim: () -> ()
): React.ReactNode
	return e("Frame", {
		Size = UDim2.fromOffset(CELL, CELL + 22),
		Position = UDim2.fromOffset((tier - 1) * STEP + 2, row * ROW_H + 2),
		BackgroundTransparency = 1,
	}, {
		Box = e("TextButton", {
			Size = UDim2.fromOffset(CELL, CELL),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Active = state == "Open",
			Text = "",
			[React.Event.Activated] = function()
				if state == "Open" then
					onClaim()
				end
			end,
		}, {
			Art = Art.Back({
				piece = if state == "Open" then "SlotSelected" else "SlotPaper",
				transparency = if state == "Claimed" then 0.55 elseif reached then 0 else 0.4,
				padding = 5,
			}),
			Padding = Widgets.Padding(5),
			Label = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = if state == "Claimed" then `{text}\n({UI.Claimed})` else text,
				TextColor3 = if state == "Open" then Theme.Gold else Theme.Subtext,
				FontFace = if state == "Open" then Theme.FontBold else Theme.Font,
				TextSize = Theme.Body(12),
				TextScaled = true,
				TextWrapped = true,
				ZIndex = 2,
			}, {
				Max = e("UITextSizeConstraint", { MaxTextSize = Theme.Body(12) }),
				Heavy = if state == "Open" then Widgets.Heavy(Theme.Gold, Theme.Body(12)) else nil,
			}),
		}),
		Level = e(Widgets.Label, {
			text = `{UI.PassLevel} {tier}`,
			textSize = 14,
			bold = reached,
			color = if reached then Theme.Text else Theme.Subtext,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 20),
			position = UDim2.fromOffset(0, CELL + 2),
		}),
	})
end

local function trackCard(row: number, title: string, children: { [string]: React.ReactNode }): React.ReactNode
	children.Art = Art.Back({ piece = "PaperCompactSharp", padding = 8 })
	children.Padding = Widgets.Padding(8)
	children.Title = e(Widgets.Label, {
		text = title,
		bold = true,
		textSize = 20,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 26),
		position = UDim2.fromOffset(0, 8),
	})
	return e("Frame", {
		Size = UDim2.fromOffset(LABEL_W, CELL),
		Position = UDim2.fromOffset(0, ROWS_Y + row * ROW_H + 2),
		BackgroundTransparency = 1,
	}, children)
end

local function BattlePassPage(props: Props): React.ReactNode
	local data = props.data
	local fresh = data.Pass.Season == Period.Key("Monthly")
	local points = if fresh then data.Pass.Points else 0
	local premium = fresh and data.Pass.Premium
	local tierNow = math.min(points // PassConfig.PointsPerTier, PassConfig.Tiers)
	local maxed = tierNow >= PassConfig.Tiers
	local inTier = if maxed then PassConfig.PointsPerTier else points - tierNow * PassConfig.PointsPerTier
	local best = bestLevel(data)

	local scrollRef = React.useRef(nil :: ScrollingFrame?)
	-- Opens with the current level in view. CanvasPosition is in real pixels, the cells in design units.
	React.useEffect(function()
		local alive = true
		task.defer(function()
			local frame = scrollRef.current
			if alive and frame ~= nil then
				local ratio = frame.AbsoluteCanvasSize.X / CANVAS_W
				frame.CanvasPosition = Vector2.new(math.max(tierNow - 2, 0) * STEP * ratio, 0)
			end
		end)
		return function()
			alive = false
		end
	end, {})

	local claimable = 0
	local cells: { [string]: React.ReactNode } = {}
	for row, track in TRACKS do
		local paid = track == "Paid"
		local claimedSet = if not fresh then {} elseif paid then data.Pass.Paid else data.Pass.Free
		for tier = 1, PassConfig.Tiers do
			local reward = if paid then PassConfig.Paid[tier] else PassConfig.Free[tier]
			local reached = tier <= tierNow
			local state: CellState = if claimedSet[tostring(tier)] == true
				then "Claimed"
				elseif reached and (premium or not paid) then "Open"
				else "Locked"
			if state == "Open" then
				claimable += 1
			end
			local gold = if reward.Gold ~= nil then Formula.Economy.Gold(reward.Gold, best) else nil
			local text = string.gsub(Text.Eco.Reward(reward, gold), ", ", "\n")
			cells[`{track}{tier}`] = cell(text, tier, row - 1, state, reached, function()
				State.Send.ClaimPass(track, tier)
			end)
		end
	end

	local premiumId = ShopConfig.Products[PassConfig.PremiumProduct] or 0
	return e(FloatWindow, {
		id = "BattlePass",
		title = UI.Pass,
		onClose = function()
			State.CloseWindow("BattlePass")
		end,
		defaultSize = WINDOW - CHROME,
		minSize = Vector2.new(640, WINDOW.Y - CHROME.Y),
	}, {
		Progress = e("Frame", {
			Size = UDim2.new(1, -(LABEL_W + 10 + 280), 0, 26),
			Position = UDim2.fromOffset(LABEL_W + 10, 5),
			BackgroundTransparency = 1,
		}, {
			Bar = e(Widgets.Bar, {
				ratio = math.clamp(inTier / PassConfig.PointsPerTier, 0, 1),
				size = UDim2.fromScale(1, 1),
			}),
			-- Over both the gold fill and the dark track: outlined so it reads on either.
			Count = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = `{inTier}/{PassConfig.PointsPerTier}`,
				TextColor3 = Theme.OnDark,
				FontFace = Theme.FontBold,
				TextSize = Theme.Body(15),
				ZIndex = 2,
			}, { Outline = e("UIStroke", { Color = Theme.OnLight, Thickness = 1.5 }) }),
		}),
		Level = e(Widgets.Label, {
			text = `{UI.PassLevel}: {tierNow}`,
			bold = true,
			size = UDim2.fromOffset(120, TOP_H),
			position = UDim2.new(1, -270, 0, 0),
		}),
		ClaimAll = e(Widgets.Button, {
			text = UI.ClaimAll,
			size = UDim2.fromOffset(140, TOP_H),
			position = UDim2.fromScale(1, 0),
			anchor = Vector2.new(1, 0),
			color = if claimable > 0 then Theme.Confirm else nil,
			disabled = claimable == 0,
			onClick = function()
				State.Send.ClaimPass("Free", 0)
				if premium then
					State.Send.ClaimPass("Paid", 0)
				end
			end,
		}),
		Normal = trackCard(0, UI.Free, {}),
		Premium = trackCard(1, UI.Premium, {
			Owned = if premium
				then e(Widgets.Label, {
					text = UI.PremiumActive,
					textSize = 14,
					color = Theme.Subtext,
					align = Enum.TextXAlignment.Center,
					size = UDim2.new(1, 0, 0, 20),
					position = UDim2.new(0, 0, 1, -26),
				})
				else nil,
			Buy = if premium
				then nil
				else e(Widgets.Button, {
					text = if premiumId <= 0
						then UI.NotForSale
						else `R$ {ShopConfig.RobuxPrices[PassConfig.PremiumProduct]}`,
					size = UDim2.new(1, 0, 0, 36),
					position = UDim2.fromScale(0, 1),
					anchor = Vector2.new(0, 1),
					textSize = if premiumId <= 0 then 12 else 15,
					disabled = premiumId <= 0,
					onClick = function()
						State.Send.BuyPremium()
					end,
				}),
		}),
		Tiers = e("ScrollingFrame", {
			ref = scrollRef,
			Size = UDim2.new(1, -(LABEL_W + 10), 0, #TRACKS * ROW_H + 8),
			Position = UDim2.fromOffset(LABEL_W + 10, ROWS_Y),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 8,
			ScrollBarImageColor3 = Theme.Stroke,
			ScrollingDirection = Enum.ScrollingDirection.X,
			CanvasSize = UDim2.fromOffset(CANVAS_W, 0),
		}, cells),
		Season = e(SeasonClock),
	})
end

return BattlePassPage
