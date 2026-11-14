--!strict
-- Trade page: with no open trade, incoming requests (accept / decline) + players in this server to ask; otherwise the open trade.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local AccountConfig = require(ReplicatedStorage.Shared.Config.Account)
local Theme = require(script.Parent.Core.Theme)
local Widgets = require(script.Parent.Core.Widgets)
local State = require(script.Parent.Parent.State)
local Offer = require(script.Offer)

local e = React.createElement
local UI = Text.Eco.UI

export type Props = { data: Types.ProfileData }

local function section(
	title: string,
	rows: { [string]: React.ReactNode },
	position: UDim2,
	size: UDim2
): React.ReactNode
	rows.Layout = Widgets.List(Enum.FillDirection.Vertical, 6)
	return e("Frame", { Size = size, Position = position, BackgroundColor3 = Theme.Bg }, {
		Corner = Widgets.Corner(8),
		Padding = Widgets.Padding(10),
		Title = e(Widgets.Label, { text = title, bold = true }),
		List = e("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, -28),
			Position = UDim2.fromOffset(0, 28),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, rows),
	})
end

local function row(order: number, name: string, buttons: { { Text: string, Confirm: boolean?, OnClick: () -> () } })
	local children: { [string]: React.ReactNode } = {
		Name = e(Widgets.Label, { text = name, size = UDim2.new(1, -230, 1, 0) }),
	}
	for i, b in buttons do
		children[`B{i}`] = e(Widgets.Button, {
			text = b.Text,
			size = UDim2.fromOffset(105, 32),
			position = UDim2.new(1, -(#buttons - i) * 112, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			textSize = 15,
			color = if b.Confirm then Theme.Confirm else nil,
			onClick = b.OnClick,
		})
	end
	return e("Frame", { Size = UDim2.new(1, -8, 0, 36), BackgroundTransparency = 1, LayoutOrder = order }, children)
end

local function Lobby(props: Props): React.ReactNode
	local data = props.data
	local others = Widgets.useOthers()
	Widgets.useTick(2) -- drops expired requests from view
	local need = AccountConfig.Unlocks.Trade.AccountLevel or 0
	local unlocked = data.AccountLevel >= need

	local requests: { [string]: React.ReactNode } = {}
	local live = State.LiveRequests()
	if #live == 0 then
		requests.Empty = e(Widgets.Label, { text = "-", color = Theme.Subtext, layoutOrder = 0 })
	end
	for i, r in live do
		requests[`R{r.UserId}`] = row(i, `{r.Name} wants to trade`, {
			{
				Text = UI.Accept,
				Confirm = true,
				OnClick = function()
					State.DropRequest(r.UserId)
					State.Send.TradeRespond(r.UserId, true)
				end,
			},
			{
				Text = UI.Decline,
				OnClick = function()
					State.DropRequest(r.UserId)
					State.Send.TradeRespond(r.UserId, false)
				end,
			},
		})
	end

	local players: { [string]: React.ReactNode } = {}
	if #others == 0 then
		players.Empty = e(Widgets.Label, { text = UI.NobodyHere, color = Theme.Subtext, layoutOrder = 0 })
	end
	for i, other in others do
		players[`P{other.UserId}`] = row(i, other.DisplayName, {
			{
				Text = UI.Request,
				OnClick = function()
					State.Send.TradeRequest(other.UserId)
				end,
			},
		})
	end

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Intro = e(Widgets.Label, {
			text = if unlocked then UI.TradeIntro else string.format(UI.TradeLockedHint, tostring(need)),
			color = if unlocked then Theme.Subtext else Theme.Text,
			wrap = true,
			size = UDim2.new(1, 0, 0, 24),
		}),
		Requests = section(UI.Requests, requests, UDim2.fromOffset(0, 34), UDim2.new(0.5, -6, 1, -34)),
		Players = section(UI.Players, players, UDim2.new(0.5, 6, 0, 34), UDim2.new(0.5, -6, 1, -34)),
	})
end

local function TradePage(props: Props): React.ReactNode
	local view = State.Trade
	return e(Widgets.Window, {
		title = if view ~= nil then `{UI.Trade} with {view.PartnerName}` else UI.Trade,
		onClose = function()
			State.SetPage(nil)
		end,
		closeOnBackdrop = false,
		maxSize = Vector2.new(1150, 720),
	}, {
		Body = if view ~= nil then e(Offer, { data = props.data, view = view }) else e(Lobby, { data = props.data }),
	})
end

return TradePage
