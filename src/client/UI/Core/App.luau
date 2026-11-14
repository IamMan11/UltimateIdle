--!strict
-- Root component: HUD + the open page + modals + toasts, all mounted in one ScreenGui. Re-renders on any store change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Widgets = require(script.Parent.Widgets)
local HUD = require(script.Parent.HUD)
local Toasts = require(script.Parent.Toasts)
local Confirm = require(script.Parent.Confirm)
local HeroSelect = require(script.Parent.Parent.HeroSelect)
local HeroesPage = require(script.Parent.Parent.Heroes)
local TeamPage = require(script.Parent.Parent.Team)
local TreePage = require(script.Parent.Parent.Tree)
local Inventory = require(script.Parent.Parent.Inventory)
local BoxesPage = require(script.Parent.Parent.Boxes)
local ForgePage = require(script.Parent.Parent.Forge)
local RebirthPage = require(script.Parent.Parent.Rebirth)
local QuestsPage = require(script.Parent.Parent.Quests)
local ShopPage = require(script.Parent.Parent.Shop)
local TradePage = require(script.Parent.Parent.Trade)
local Settings = require(script.Parent.Parent.Settings)
local Dev = require(script.Parent.Parent.Dev)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement

local function App(): React.ReactNode
	Widgets.useStore()
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
		if ui.Page == "Heroes" then
			page = e(HeroesPage, { data = data })
		elseif ui.Page == "Team" then
			page = e(TeamPage, { data = data })
		elseif ui.Page == "Tree" then
			page = e(TreePage, { data = data })
		elseif ui.Page == "Bag" then
			page = e(Inventory, { data = data })
		elseif ui.Page == "Boxes" then
			page = e(BoxesPage, { data = data })
		elseif ui.Page == "Forge" then
			page = e(ForgePage, { data = data })
		elseif ui.Page == "Rebirth" then
			page = e(RebirthPage, { data = data })
		elseif ui.Page == "Quests" then
			page = e(QuestsPage, { data = data })
		elseif ui.Page == "Shop" then
			page = e(ShopPage, { data = data })
		elseif ui.Page == "Trade" then
			page = e(TradePage, { data = data })
		elseif ui.Page == "Settings" then
			page = e(Settings, { data = data })
		elseif ui.Page == "Dev" then
			page = e(Dev)
		end
	end
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		HUD = if needsHero then nil else e(HUD, { data = data }),
		Page = page,
		HeroSelect = if needsHero then e(HeroSelect) else nil,
		Confirm = if ui.Confirm ~= nil then e(Confirm, { prompt = ui.Confirm }) else nil,
		Toasts = e(Toasts),
	})
end

return App
