--!strict
-- Trade window. No open trade: a narrow list of players in this server (search by @name; Trade = ask, incoming requests show Accept / Decline). Open trade: the offer window.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local AccountConfig = require(ReplicatedStorage.Shared.Config.Account)
local Theme = require(script.Parent.Core.Theme)
local Art = require(script.Parent.Core.Art)
local FloatWindow = require(script.Parent.Core.FloatWindow)
local Widgets = require(script.Parent.Core.Widgets)
local State = require(script.Parent.Parent.State)
local Offer = require(script.Offer)
local Badge = require(script.Parent.Core.Badge)

local e = React.createElement
local UI = Text.Eco.UI

local LOBBY = Vector2.new(440, 620)
local OFFER = Vector2.new(1000, 680)
local ROW_H = 56
local BUTTON = Vector2.new(84, 38)

export type Props = { data: Types.ProfileData }

local function matches(player: Player, query: string): boolean
	if query == "" then
		return true
	end
	return string.find(string.lower(player.Name), query, 1, true) ~= nil
		or string.find(string.lower(player.DisplayName), query, 1, true) ~= nil
end

local function Lobby(props: Props): React.ReactNode
	local data = props.data
	local others = Widgets.useOthers()
	local search, setSearch = React.useState("")
	Widgets.useTick(2) -- drops expired requests from view
	local need = AccountConfig.Unlocks.Trade.AccountLevel or 0
	local unlocked = data.AccountLevel >= need
	local top = if unlocked then 0 else 30

	local asked: { [number]: boolean } = {}
	for _, r in State.LiveRequests() do
		asked[r.UserId] = true
	end
	local query = string.lower((string.gsub(search, "^%s*@?", "")))

	local rows: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Vertical, 6) }
	local shown = 0
	for i, other in others do
		if matches(other, query) then
			shown += 1
			local userId = other.UserId
			local wants = asked[userId] == true
			local buttons = if wants then 2 else 1
			rows[`P{userId}`] = e("Frame", {
				Size = UDim2.new(1, -10, 0, ROW_H),
				BackgroundTransparency = 1,
				-- Players asking to trade come first.
				LayoutOrder = if wants then i else #others + i,
			}, {
				Art = Art.Back({ piece = if wants then "BtnPaperHover" else "PaperCompactSharp", padding = 8 }),
				Padding = Widgets.Padding(8),
				Who = e(Badge, {
					userId = userId,
					display = if wants then `{other.DisplayName} {UI.WantsTrade}` else other.DisplayName,
					name = other.Name,
					size = UDim2.new(1, -(BUTTON.X + 6) * buttons, 1, 0),
				}),
				Trade = if wants
					then nil
					else e(Widgets.Button, {
						text = UI.Trade,
						size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
						position = UDim2.fromScale(1, 0.5),
						anchor = Vector2.new(1, 0.5),
						textSize = 15,
						disabled = not unlocked,
						onClick = function()
							State.Send.TradeRequest(userId)
						end,
					}),
				Accept = if wants
					then e(Widgets.Button, {
						text = UI.Accept,
						size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
						position = UDim2.new(1, -(BUTTON.X + 6), 0.5, 0),
						anchor = Vector2.new(1, 0.5),
						textSize = 15,
						color = Theme.Confirm,
						onClick = function()
							State.DropRequest(userId)
							State.Send.TradeRespond(userId, true)
						end,
					})
					else nil,
				Decline = if wants
					then e(Widgets.Button, {
						text = UI.Decline,
						size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
						position = UDim2.fromScale(1, 0.5),
						anchor = Vector2.new(1, 0.5),
						textSize = 15,
						onClick = function()
							State.DropRequest(userId)
							State.Send.TradeRespond(userId, false)
						end,
					})
					else nil,
			})
		end
	end
	if shown == 0 then
		rows.Empty = e(Widgets.Label, {
			text = if #others == 0 then UI.NobodyHere else UI.NoMatch,
			color = Theme.Subtext,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, -10, 0, 40),
		})
	end

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Locked = if unlocked
			then nil
			else e(Widgets.Label, { text = string.format(UI.TradeLockedHint, tostring(need)), bold = true }),
		Search = e(Widgets.TextInput, {
			text = search,
			placeholder = UI.SearchName,
			onChanged = setSearch,
			position = UDim2.fromOffset(0, top),
		}),
		List = e("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, -(top + 46)),
			Position = UDim2.fromOffset(0, top + 46),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, rows),
	})
end

local function TradePage(props: Props): React.ReactNode
	local view = State.Trade
	-- Lobby and offer have their own size and saved place; the offer's fixed layout scales with the window.
	local offer = view ~= nil
	return e(FloatWindow, {
		id = "Trade",
		title = UI.Trade,
		onClose = function()
			State.CloseWindow("Trade")
		end,
		saveId = if offer then "TradeOffer" else "Trade",
		defaultSize = (if offer then OFFER else LOBBY) - Vector2.new(12, 14),
		minSize = if offer then Vector2.new(600, 420) else Vector2.new(360, 400),
		fit = if offer then OFFER - Vector2.new(40, 82) else nil,
	}, {
		Body = if view ~= nil then e(Offer, { data = props.data, view = view }) else e(Lobby, { data = props.data }),
	})
end

return TradePage
