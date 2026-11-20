--!strict
-- Root component: HUD + the open floating windows (stacked in State.Ui.Windows order) + modals + hover tooltip + toasts in one ScreenGui under one UIScale (viewport x UI-size setting). Re-renders on any store change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)
local WindowStack = require(script.Parent.WindowStack)
local Device = require(script.Parent.Device)
local HUD = require(script.Parent.HUD)
local Toasts = require(script.Parent.Toasts)
local Confirm = require(script.Parent.Confirm)
local Tooltip = require(script.Parent.Tooltip)
local HeroSelect = require(script.Parent.Parent.HeroSelect)
local TeamPage = require(script.Parent.Parent.Team)
local JobChange = require(script.Parent.Parent.Team.JobChange)
local TreePage = require(script.Parent.Parent.Tree)
local Inventory = require(script.Parent.Parent.Inventory)
local Salvage = require(script.Parent.Parent.Salvage)
local BagFilter = require(script.Parent.Parent.BagFilter)
local BoxesPage = require(script.Parent.Parent.Boxes)
local RebirthPage = require(script.Parent.Parent.Rebirth)
local QuestsPage = require(script.Parent.Parent.Quests)
local BattlePassPage = require(script.Parent.Parent.BattlePass)
local ShopPage = require(script.Parent.Parent.Shop)
local TradePage = require(script.Parent.Parent.Trade)
local Settings = require(script.Parent.Parent.Settings)
local DailyPage = require(script.Parent.Parent.Daily)
local CodesPage = require(script.Parent.Parent.Codes)
local Dev = require(script.Parent.Parent.Dev)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement

local function window(id: string, data: Types.ProfileData): React.ReactNode
	if id == "Team" then
		return e(TeamPage, { data = data })
	elseif id == "Tree" then
		return e(TreePage, { data = data })
	elseif id == "Inventory" then
		return e(Inventory, { data = data })
	elseif id == "AutoSalvage" then
		return e(Salvage.Window, { data = data })
	elseif id == "SalvagePick" then
		return e(Salvage.Picker, { data = data })
	elseif id == "Boxes" then
		return e(BoxesPage, { data = data })
	elseif id == "Rebirth" then
		return e(RebirthPage, { data = data })
	elseif id == "Quests" then
		return e(QuestsPage, { data = data })
	elseif id == "BattlePass" then
		return e(BattlePassPage, { data = data })
	elseif id == "Shop" then
		return e(ShopPage, { data = data })
	elseif id == "Trade" then
		return e(TradePage, { data = data })
	elseif id == "Daily" then
		return e(DailyPage, { data = data })
	elseif id == "Codes" then
		return e(CodesPage)
	elseif id == "Settings" then
		return e(Settings, { data = data })
	elseif id == "Dev" then
		return e(Dev)
	end
	return nil
end

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function App(): React.ReactNode
	Widgets.useStore()
	local viewport = Widgets.useViewport()

	-- Pressing anywhere on a window behind another brings it to the top.
	React.useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input: InputObject)
			if not isPointer(input) or State.ModalOpen() then
				return
			end
			local id = WindowStack.Hit(Vector2.new(input.Position.X, input.Position.Y))
			if id ~= nil then
				State.RaiseWindow(id)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

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
	-- Keyed by id so reordering only changes ZIndex (no remount); each layer is a full-screen see-through frame.
	local windows: { [string]: React.ReactNode } = {}
	if not needsHero then
		for i, id in ui.Windows do
			local node = window(id, data)
			if node ~= nil then
				windows[id] = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = i }, {
					Window = node,
				})
			end
		end
	end
	-- One UIScale for everything: the root is 1/scale of the screen so it covers the screen once scaled.
	local scale = Device.Scale(viewport, data.Settings.UiScale or 1)
	local compact = Device.Compact(viewport, scale)
	return e("Frame", { Size = UDim2.fromScale(1 / scale, 1 / scale), BackgroundTransparency = 1 }, {
		Scale = e("UIScale", { Scale = scale }),
		HUD = if needsHero then nil else e(HUD, { data = data, compact = compact }),
		Windows = e(
			"Frame",
			{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = Theme.ZPage },
			windows
		),
		HeroSelect = if needsHero then e(HeroSelect) else nil,
		BagFilter = if ui.BagFilterOpen and State.IsOpen("Inventory")
			then e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = Theme.ZModal }, {
				Modal = e(BagFilter),
			})
			else nil,
		JobChange = if ui.JobChange ~= nil then e(JobChange, { data = data, heroId = ui.JobChange }) else nil,
		Confirm = if ui.Confirm ~= nil then e(Confirm, { prompt = ui.Confirm }) else nil,
		Tooltip = e(Tooltip, { data = data, scale = scale, hidden = State.ModalOpen() }),
		Toasts = e(Toasts),
	})
end

return App
