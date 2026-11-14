--!strict
-- Root component: HUD + the open page + modals + toasts in one ScreenGui under one UIScale (viewport x UI-size setting). Re-renders on any store change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local Widgets = require(script.Parent.Widgets)
local Device = require(script.Parent.Device)
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
local DailyPage = require(script.Parent.Parent.Daily)
local Dev = require(script.Parent.Parent.Dev)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement

-- Viewport size, updated on resize/rotation.
local function useViewport(): Vector2
	local viewport, setViewport = React.useState(Device.Viewport())
	React.useEffect(function(): () -> ()
		local camera = Workspace.CurrentCamera
		local connection = if camera ~= nil
			then camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				setViewport(camera.ViewportSize)
			end)
			else nil
		return function()
			if connection ~= nil then
				connection:Disconnect()
			end
		end
	end, {})
	return viewport
end

local function App(): React.ReactNode
	Widgets.useStore()
	local viewport = useViewport()
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
		elseif ui.Page == "Daily" then
			page = e(DailyPage, { data = data })
		elseif ui.Page == "Settings" then
			page = e(Settings, { data = data })
		elseif ui.Page == "Dev" then
			page = e(Dev)
		end
	end
	-- One UIScale for everything: the root is 1/scale of the screen so it covers the screen once scaled.
	local scale = Device.Scale(viewport, data.Settings.UiScale or 1)
	local compact = Device.Compact(viewport, scale)
	local tight = Device.Tight(viewport, scale)
	return e("Frame", { Size = UDim2.fromScale(1 / scale, 1 / scale), BackgroundTransparency = 1 }, {
		Scale = e("UIScale", { Scale = scale }),
		HUD = if needsHero then nil else e(HUD, { data = data, compact = compact, tight = tight }),
		Page = page,
		HeroSelect = if needsHero then e(HeroSelect) else nil,
		Confirm = if ui.Confirm ~= nil then e(Confirm, { prompt = ui.Confirm }) else nil,
		Toasts = e(Toasts),
	})
end

return App
