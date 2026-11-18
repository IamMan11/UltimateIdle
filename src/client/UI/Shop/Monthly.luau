--!strict
-- Monthly shop tab: item cards in five columns (reward, stock left this UTC month, price button) + the reset countdown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Format = require(ReplicatedStorage.Shared.Format)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Period = require(ReplicatedStorage.Shared.Period)
local ShopConfig = require(ReplicatedStorage.Shared.Config.Shop)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement
local UI = Text.Eco.UI

local CARD_H = 168
local FOOTER_H = 50

export type Props = { data: Types.ProfileData }

local function bestLevel(data: Types.ProfileData): number
	local best = 1
	for _, p in data.Stage.ByRebirth do
		best = math.max(best, p.MaxLevel)
	end
	return best
end

local function priceText(item: ShopConfig.ShopItem, gold: number): string
	if item.Currency == "Gold" then
		return Format.Number(gold)
	elseif item.Currency == "Ruby" then
		return tostring(item.Price)
	end
	return `R$ {item.Price}`
end

local function buy(item: ShopConfig.ShopItem, price: string)
	if item.Currency == "Ruby" then
		State.OpenConfirm({
			Title = `Buy {Text.Eco.ShopItem(item.Id)}?`,
			Body = `Costs {price} Ruby.`,
			OkText = UI.Buy,
			Danger = false,
			OnConfirm = function()
				State.Send.BuyShopItem(item.Id)
			end,
		})
	else
		State.Send.BuyShopItem(item.Id)
	end
end

-- Ticks by itself so the cards are not redrawn every second.
local function ResetClock(): React.ReactNode
	Widgets.useTick(1)
	return e(Widgets.Label, {
		text = `{UI.ResetsIn} {Format.Time(math.max(Period.Ends("Monthly") - os.time(), 0))} (UTC)`,
		bold = true,
		textSize = 20,
		size = UDim2.new(1, 0, 0, 40),
		position = UDim2.fromScale(0, 1),
		anchor = Vector2.new(0, 1),
	})
end

local function Monthly(props: Props): React.ReactNode
	local data = props.data
	local fresh = data.Shop.Month == Period.Key("Monthly")
	local best = bestLevel(data)
	local cells: { [string]: React.ReactNode } = {
		Grid = e("UIGridLayout", {
			CellSize = UDim2.new(0.2, -12, 0, CARD_H),
			CellPadding = UDim2.fromOffset(12, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		-- Room for the card outlines inside the clipping scroll frame.
		Inset = e("UIPadding", {
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
			PaddingLeft = UDim.new(0, 2),
		}),
	}
	for _, item in ShopConfig.Items do
		local bought = if fresh then data.Shop.Bought[item.Id] or 0 else 0
		local left = math.max(item.Quota - bought, 0)
		local goldPrice = if item.Currency == "Gold" then Formula.Economy.Gold(item.Price, best) else 0
		local rewardGold = if item.Reward.Gold ~= nil then Formula.Economy.Gold(item.Reward.Gold, best) else nil
		local forSale = item.Currency ~= "Robux"
			or (item.Product ~= nil and (ShopConfig.Products[item.Product] or 0) > 0)
		local price = priceText(item, goldPrice)
		local affordable = if item.Currency == "Gold"
			then data.Gold >= goldPrice
			elseif item.Currency == "Ruby" then data.Ruby >= item.Price
			else true
		local open = left > 0 and forSale
		cells[item.Id] = e("Frame", {
			BackgroundColor3 = Theme.PanelAlt,
			BackgroundTransparency = if left > 0 then 0 else 0.5,
			BorderSizePixel = 0,
			LayoutOrder = item.Order,
		}, {
			Corner = Widgets.Corner(8),
			Stroke = Widgets.Stroke(),
			Padding = Widgets.Padding(10),
			Name = e(Widgets.Label, {
				text = Text.Eco.ShopItem(item.Id),
				bold = true,
				align = Enum.TextXAlignment.Center,
			}),
			Reward = e(Widgets.Label, {
				text = Text.Eco.Reward(item.Reward, rewardGold),
				textSize = 15,
				wrap = true,
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(1, 0, 0, 44),
				position = UDim2.fromOffset(0, 26),
			}),
			Left = e(Widgets.Label, {
				text = `{left}/{item.Quota} {UI.LeftThisMonth}`,
				textSize = 14,
				color = Theme.Subtext,
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(0, 74),
			}),
			Buy = e(Widgets.Button, {
				text = if left <= 0 then UI.SoldOut elseif not forSale then UI.NotForSale else price,
				icon = if not open
					then nil
					elseif item.Currency == "Gold" then Icons.Gold
					elseif item.Currency == "Ruby" then Icons.Ruby
					else nil,
				iconSize = 24,
				size = UDim2.new(1, 0, 0, 40),
				position = UDim2.fromScale(0, 1),
				anchor = Vector2.new(0, 1),
				textSize = 15,
				color = if open and affordable then Theme.Confirm else nil,
				disabled = not open or not affordable,
				onClick = function()
					buy(item, price)
				end,
			}),
		})
	end
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Grid = e("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, -FOOTER_H),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Stroke,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, cells),
		Reset = e(ResetClock),
	})
end

return Monthly
