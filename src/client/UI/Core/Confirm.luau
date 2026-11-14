--!strict
-- Confirm modal (one question, Cancel / action). Opened via State.OpenConfirm; closes by buttons or Esc only, Enter never confirms a danger action.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement

export type Props = {
	prompt: State.ConfirmPrompt,
}

local function Confirm(props: Props): React.ReactNode
	local prompt = props.prompt
	-- Ignore clicks for a moment after opening so a double-click cannot pass straight through.
	local ready, setReady = React.useState(false)
	React.useEffect(function()
		local thread = task.delay(0.35, function()
			setReady(true)
		end)
		return function()
			task.cancel(thread)
		end
	end, {})

	return e(Widgets.Window, {
		title = prompt.Title,
		onClose = State.CloseConfirm,
		size = UDim2.fromOffset(460, 220),
		zIndex = Theme.ZModal,
	}, {
		Body = e(Widgets.Label, {
			text = prompt.Body,
			size = UDim2.new(1, 0, 1, -50),
			color = Theme.Subtext,
			wrap = true,
		}),
		Footer = e("Frame", {
			Size = UDim2.new(1, 0, 0, 40),
			Position = UDim2.fromScale(0, 1),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,
		}, {
			Layout = Widgets.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right),
			Cancel = e(Widgets.Button, { text = Text.UI.Cancel, layoutOrder = 1, onClick = State.CloseConfirm }),
			Ok = e(Widgets.Button, {
				text = prompt.OkText,
				size = UDim2.fromOffset(170, 36),
				layoutOrder = 2,
				color = if prompt.Danger then Theme.Danger else Theme.Confirm,
				disabled = not ready,
				onClick = function()
					prompt.OnConfirm()
					State.CloseConfirm()
				end,
			}),
		}),
	})
end

return Confirm
