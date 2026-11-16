--!strict
-- Shop page: monthly shop (gold / Ruby / Robux items, quota per UTC month) + Passes tab (buy and gift game passes).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Format = require(ReplicatedStorage.Shared.Format)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Period = require(ReplicatedStorage.Shared.Period)
local ShopConfig = require(ReplicatedStorage.Shared.Config.Shop)
local Theme = require(script.Parent.Core.Theme)
local Widgets = require(script.Parent.Core.Widgets)
local State = require(script.Parent.Parent.State)
local PassesTab = require(script.Passes)

local e = React.createElement
local UI = Text.Eco.UI

export type Props = { data: Types.ProfileData }

local TABS = {
	{ Id = "Monthly", Label = UI.MonthlyShop },
	{ Id = "Passes", Label = UI.Passes },
}

local function bestLevel(data: Types.ProfileData): number
	local best = 1
	for _, p in data.Stage.ByRebirth do
		best = math.max(best, p.MaxLevel)
	end
	return best
end

local function priceText(item: ShopConfig.ShopItem, gold: number): string
	if item.Currency == "Gold" then
		return `{Format.Number(gold)} gold`
	elseif item.Currency == "Ruby" then
		return `{item.Price} Ruby`
	end
	return `R$ {item.Price}`
end

local function buy(item: ShopConfig.ShopItem, price: string)
	if item.Currency == "Ruby" then
		State.OpenConfirm({
			Title = `Buy {Text.Eco.ShopItem(item.Id)}?`,
			Body = `Costs {price}.`,
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

local function Monthly(props: Props): React.ReactNode
	local data = props.data
	local fresh = data.Shop.Month == Period.Key("Monthly")
	local best = bestLevel(data)
	local cells: { [string]: React.ReactNode } = {
		Grid = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(270, 150),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
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
		cells[item.Id] = e("Frame", { BackgroundColor3 = Theme.PanelAlt, LayoutOrder = item.Order }, {
			Corner = Widgets.Corner(8),
			Padding = Widgets.Padding(10),
			Name = e(Widgets.Label, { text = Text.Eco.ShopItem(item.Id), bold = true }),
			Reward = e(Widgets.Label, {
				text = Text.Eco.Reward(item.Reward, rewardGold),
				textSize = 15,
				wrap = true,
				size = UDim2.new(1, 0, 0, 40),
				position = UDim2.fromOffset(0, 24),
			}),
			Left = e(Widgets.Label, {
				text = `{left}/{item.Quota} {UI.LeftThisMonth}`,
				textSize = 14,
				color = Theme.Subtext,
				position = UDim2.fromOffset(0, 66),
			}),
			Buy = e(Widgets.Button, {
				text = if left <= 0 then UI.SoldOut elseif not forSale then UI.NotForSale else price,
				size = UDim2.new(1, 0, 0, 36),
				position = UDim2.fromScale(0, 1),
				anchor = Vector2.new(0, 1),
				textSize = 15,
				color = if left > 0 and forSale and affordable then Theme.Confirm else nil,
				disabled = left <= 0 or not forSale or not affordable,
				onClick = function()
					buy(item, price)
				end,
			}),
		})
	end
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Reset = e(Widgets.Label, {
			text = `{UI.ResetsIn} {Format.Time(math.max(Period.Ends("Monthly") - os.time(), 0))} (UTC)`,
			color = Theme.Subtext,
		}),
		Grid = e("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, -30),
			Position = UDim2.fromOffset(0, 30),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, cells),
	})
end

local function ShopPage(props: Props): React.ReactNode
	local data = props.data
	local tab = State.Ui.PageTab or "Monthly"
	Widgets.useTick(1)
	return e(Widgets.Window, {
		title = `{UI.Shop}   ·   {Format.Number(data.Gold)} gold   ·   {Format.Number(data.Ruby)} Ruby`,
		onClose = function()
			State.SetPage(nil)
		end,
		closeOnBackdrop = true,
	}, {
		Tabs = e(Widgets.Tabs, { tabs = TABS, current = tab, onSelect = State.SetPageTab, width = 160 }),
		Body = e("Frame", {
			Size = UDim2.new(1, 0, 1, -46),
			Position = UDim2.fromOffset(0, 46),
			BackgroundTransparency = 1,
		}, {
			Content = if tab == "Passes" then e(PassesTab, { data = data }) else e(Monthly, { data = data }),
		}),
	})
end

return ShopPage
