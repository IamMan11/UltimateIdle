--!strict
-- Root component: HUD + the open page + modals + toasts in one ScreenGui under one UIScale (viewport x UI-size setting). Re-renders on any store change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Widgets = require(script.Parent.Widgets)
local Device = require(script.Parent.Device)
local HUD = require(script.Parent.HUD)
local Toasts = require(script.Parent.Toasts)
local Confirm = require(script.Parent.Confirm)
local HeroSelect = require(script.Parent.Parent.HeroSelect)
local TeamPage = require(script.Parent.Parent.Team)
local TreePage = require(script.Parent.Parent.Tree)
local Inventory = require(script.Parent.Parent.Inventory)
local BoxesPage = require(script.Parent.Parent.Boxes)
local RebirthPage = require(script.Parent.Parent.Rebirth)
local QuestsPage = require(script.Parent.Parent.Quests)
local ShopPage = require(script.Parent.Parent.Shop)
local TradePage = require(script.Parent.Parent.Trade)
local Settings = require(script.Parent.Parent.Settings)
local DailyPage = require(script.Parent.Parent.Daily)
local CodesPage = require(script.Parent.Parent.Codes)
local Dev = require(script.Parent.Parent.Dev)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement

local function App(): React.ReactNode
	Widgets.useStore()
	local viewport = Widgets.useViewport()
	local data = State.Data
	if data == nil then
		return e(Widgets.Label, {
			text = "Loading...",
			size = UDim2.fromOffset(200, 40),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			align = Enum.TextXAlignment.Center,
		})
	end
	local ui = State.Ui
	local needsHero = next(data.Heroes) == nil
	local page: React.ReactNode = nil
	if not needsHero then
		if ui.Page == "Team" then
			page = e(TeamPage, { data = data })
		elseif ui.Page == "Inventory" then
			page = e(Inventory, { data = data })
		elseif ui.Page == "Boxes" then
			page = e(BoxesPage, { data = data })
		elseif ui.Page == "Rebirth" then
			page = e(RebirthPage, { data = data })
		elseif ui.Page == "Quests" then
			page = e(QuestsPage, { data = data })
		elseif ui.Page == "Shop" then
			page = e(ShopPage, { data = data })
		elseif ui.Page == "Trade" then
			page = e(TradePage, { data = data })
		elseif ui.Page == "Daily" then
			page = e(DailyPage, { data = data })
		elseif ui.Page == "Codes" then
			page = e(CodesPage)
		elseif ui.Page == "Settings" then
			page = e(Settings, { data = data })
		elseif ui.Page == "Dev" then
			page = e(Dev)
		end
	end
	-- One UIScale for everything: the root is 1/scale of the screen so it covers the screen once scaled.
	local scale = Device.Scale(viewport, data.Settings.UiScale or 1)
	local compact = Device.Compact(viewport, scale)
	return e("Frame", { Size = UDim2.fromScale(1 / scale, 1 / scale), BackgroundTransparency = 1 }, {
		Scale = e("UIScale", { Scale = scale }),
		HUD = if needsHero then nil else e(HUD, { data = data, compact = compact }),
		Page = page,
		Tree = if ui.Tree and not needsHero then e(TreePage, { data = data }) else nil,
		HeroSelect = if needsHero then e(HeroSelect) else nil,
		Confirm = if ui.Confirm ~= nil then e(Confirm, { prompt = ui.Confirm }) else nil,
		Toasts = e(Toasts),
	})
end

return App
