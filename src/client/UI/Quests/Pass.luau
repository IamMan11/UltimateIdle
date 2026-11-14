--!strict
-- Battle Pass tab: season countdown, points/tier, premium unlock, 30 tiers with free + premium reward claims.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Format = require(ReplicatedStorage.Shared.Format)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Period = require(ReplicatedStorage.Shared.Period)
local PassConfig = require(ReplicatedStorage.Shared.Config.BattlePass)
local ShopConfig = require(ReplicatedStorage.Shared.Config.Shop)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement
local UI = Text.Eco.UI

export type Props = { data: Types.ProfileData }

local function bestLevel(data: Types.ProfileData): number
	local best = 1
	for _, p in data.Stage.ByRebirth do
		best = math.max(best, p.MaxLevel)
	end
	return best
end

local function PassTab(props: Props): React.ReactNode
	local data = props.data
	local fresh = data.Pass.Season == Period.Key("Monthly")
	local points = if fresh then data.Pass.Points else 0
	local premium = fresh and data.Pass.Premium
	local tierNow = math.min(points // PassConfig.PointsPerTier, PassConfig.Tiers)
	local best = bestLevel(data)

	local function cell(track: "Free" | "Paid", tier: number, reward: Types.Reward): React.ReactNode
		local claimedSet = if not fresh then {} elseif track == "Paid" then data.Pass.Paid else data.Pass.Free
		local claimed = claimedSet[tostring(tier)] == true
		local reached = tier <= tierNow
		local usable = reached and not claimed and (track == "Free" or premium)
		local gold = if reward.Gold ~= nil then Formula.Economy.Gold(reward.Gold, best) else nil
		return e("Frame", {
			Size = UDim2.new(0.42, -8, 1, 0),
			Position = if track == "Free" then UDim2.fromScale(0.16, 0) else UDim2.fromScale(0.58, 0),
			BackgroundColor3 = Theme.PanelAlt,
			BackgroundTransparency = if reached then 0 else 0.5,
		}, {
			Corner = Widgets.Corner(6),
			Padding = Widgets.Padding(6),
			Reward = e(Widgets.Label, {
				text = Text.Eco.Reward(reward, gold),
				textSize = 14,
				wrap = true,
				size = UDim2.new(1, -96, 1, 0),
			}),
			Claim = e(Widgets.Button, {
				text = if claimed then UI.Claimed else UI.Claim,
				size = UDim2.fromOffset(90, 32),
				position = UDim2.fromScale(1, 0.5),
				anchor = Vector2.new(1, 0.5),
				textSize = 14,
				color = if usable then Theme.Confirm else nil,
				disabled = not usable,
				onClick = function()
					State.Send.ClaimPass(track, tier)
				end,
			}),
		})
	end

	local rows: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Vertical, 6) }
	for tier = 1, PassConfig.Tiers do
		rows[`T{tier}`] = e("Frame", {
			Size = UDim2.new(1, -8, 0, 52),
			BackgroundTransparency = 1,
			LayoutOrder = tier,
		}, {
			Tier = e(Widgets.Label, {
				text = `{UI.Tier} {tier}\n{tier * PassConfig.PointsPerTier} pts`,
				textSize = 14,
				wrap = true,
				size = UDim2.fromScale(0.15, 1),
				color = if tier <= tierNow then Theme.Text else Theme.Subtext,
			}),
			Free = cell("Free", tier, PassConfig.Free[tier]),
			Paid = cell("Paid", tier, PassConfig.Paid[tier]),
		})
	end

	local premiumId = ShopConfig.Products[PassConfig.PremiumProduct] or 0
	local nextNeed = (tierNow + 1) * PassConfig.PointsPerTier
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Head = e(Widgets.Label, {
			text = `{UI.SeasonEnds} {Format.Time(math.max(Period.Ends("Monthly") - os.time(), 0))}   ·   {points} {UI.PassPoints}   ·   {UI.Tier} {tierNow}/{PassConfig.Tiers}`,
			bold = true,
			size = UDim2.new(1, 0, 0, 22),
		}),
		Bar = e(Widgets.Bar, {
			ratio = if tierNow >= PassConfig.Tiers
				then 1
				else (points - tierNow * PassConfig.PointsPerTier) / (nextNeed - tierNow * PassConfig.PointsPerTier),
			position = UDim2.fromOffset(0, 26),
		}),
		Buttons = e("Frame", {
			Size = UDim2.new(1, 0, 0, 36),
			Position = UDim2.fromOffset(0, 38),
			BackgroundTransparency = 1,
		}, {
			Layout = Widgets.List(Enum.FillDirection.Horizontal, 8),
			Premium = e(Widgets.Button, {
				text = if premium
					then UI.PremiumActive
					elseif premiumId <= 0 then `{UI.BuyPremium} · {UI.NotForSale}`
					else `{UI.BuyPremium} · R$ {ShopConfig.RobuxPrices[PassConfig.PremiumProduct]}`,
				size = UDim2.fromOffset(280, 36),
				textSize = 15,
				disabled = premium or premiumId <= 0,
				layoutOrder = 1,
				onClick = function()
					State.Send.BuyPremium()
				end,
			}),
			FreeAll = e(Widgets.Button, {
				text = `{UI.ClaimAll} ({UI.Free})`,
				size = UDim2.fromOffset(170, 36),
				textSize = 15,
				layoutOrder = 2,
				onClick = function()
					State.Send.ClaimPass("Free", 0)
				end,
			}),
			PaidAll = e(Widgets.Button, {
				text = `{UI.ClaimAll} ({UI.Premium})`,
				size = UDim2.fromOffset(200, 36),
				textSize = 15,
				disabled = not premium,
				layoutOrder = 3,
				onClick = function()
					State.Send.ClaimPass("Paid", 0)
				end,
			}),
		}),
		Columns = e("Frame", {
			Size = UDim2.new(1, -8, 0, 20),
			Position = UDim2.fromOffset(0, 80),
			BackgroundTransparency = 1,
		}, {
			Free = e(Widgets.Label, {
				text = UI.Free,
				bold = true,
				size = UDim2.fromScale(0.42, 1),
				position = UDim2.fromScale(0.16, 0),
			}),
			Paid = e(Widgets.Label, {
				text = UI.Premium,
				bold = true,
				size = UDim2.fromScale(0.42, 1),
				position = UDim2.fromScale(0.58, 0),
			}),
		}),
		List = e("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, -104),
			Position = UDim2.fromOffset(0, 104),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, rows),
	})
end

return PassTab
