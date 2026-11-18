--!strict
-- Gamepass shop window: Gamepass tab (pass cards + potion grid), Monthly shop tab (gold / Ruby / Robux items, quota per UTC month), Gift tab (gift a pass to a player here).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Format = require(ReplicatedStorage.Shared.Format)
local FloatWindow = require(script.Parent.Core.FloatWindow)
local Widgets = require(script.Parent.Core.Widgets)
local State = require(script.Parent.Parent.State)
local PassesTab = require(script.Passes)
local MonthlyTab = require(script.Monthly)
local GiftTab = require(script.Gift)

local e = React.createElement
local UI = Text.Eco.UI

local WINDOW = Vector2.new(1040, 640)
local TABS_H = 46

export type Props = { data: Types.ProfileData }

local TABS = {
	{ Id = "Passes", Label = Text.UI.Gamepass },
	{ Id = "Monthly", Label = UI.MonthlyShop },
	{ Id = "Gift", Label = UI.Gift },
}

local function ShopPage(props: Props): React.ReactNode
	local data = props.data
	local tab = State.Ui.PageTabs.Shop or "Passes"
	return e(FloatWindow, {
		id = "Shop",
		title = `{Text.UI.Gamepass}   ·   {Format.Number(data.Gold)} gold   ·   {Format.Number(data.Ruby)} Ruby`,
		onClose = function()
			State.CloseWindow("Shop")
		end,
		defaultSize = WINDOW - Vector2.new(12, 14),
		minSize = Vector2.new(620, 400),
		fit = WINDOW - Vector2.new(40, 82),
	}, {
		Tabs = e(Widgets.Tabs, {
			tabs = TABS,
			current = tab,
			onSelect = function(id: string)
				State.SetPageTab("Shop", id)
			end,
			width = 160,
		}),
		Body = e("Frame", {
			Size = UDim2.new(1, 0, 1, -TABS_H),
			Position = UDim2.fromOffset(0, TABS_H),
			BackgroundTransparency = 1,
		}, {
			Content = if tab == "Monthly"
				then e(MonthlyTab, { data = data })
				elseif tab == "Gift" then e(GiftTab)
				else e(PassesTab, { data = data }),
		}),
	})
end

return ShopPage
