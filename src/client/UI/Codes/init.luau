--!strict
-- Codes page: type a code and redeem it (the server answers with a toast).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Text = require(ReplicatedStorage.Shared.Text)
local FloatWindow = require(script.Parent.Core.FloatWindow)
local Widgets = require(script.Parent.Core.Widgets)
local State = require(script.Parent.Parent.State)

local e = React.createElement
local UI = Text.UI

local MAX_LENGTH = 32

local function Codes(): React.ReactNode
	local code, setCode = React.useState("")
	return e(FloatWindow, {
		id = "Codes",
		title = UI.Codes,
		onClose = function()
			State.CloseWindow("Codes")
		end,
		defaultSize = Vector2.new(458, 136),
		minSize = Vector2.new(360, 136),
	}, {
		Input = e(Widgets.TextInput, {
			text = code,
			placeholder = UI.CodePlaceholder,
			size = UDim2.new(1, -150, 0, 38),
			onChanged = setCode,
		}),
		Redeem = e(Widgets.Button, {
			text = UI.Redeem,
			size = UDim2.fromOffset(140, 38),
			position = UDim2.fromScale(1, 0),
			anchor = Vector2.new(1, 0),
			disabled = #code == 0 or #code > MAX_LENGTH,
			onClick = function()
				State.Send.RedeemCode(code)
				setCode("")
			end,
		}),
	})
end

return Codes
