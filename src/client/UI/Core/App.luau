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
local Inventory = require(script.Parent.Parent.Inventory)
local BoxesPage = require(script.Parent.Parent.Boxes)
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
		elseif ui.Page == "Bag" then
			page = e(Inventory, { data = data })
		elseif ui.Page == "Boxes" then
			page = e(BoxesPage, { data = data })
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
