--!strict
-- Studio-only dev panel: quick buttons for server dev commands (server ignores them outside Studio).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local FloatWindow = require(script.Parent.Core.FloatWindow)
local Widgets = require(script.Parent.Core.Widgets)
local State = require(script.Parent.Parent.State)

local e = React.createElement

local COMMANDS: { { Label: string, Cmd: string, Arg: number } } = {
	{ Label = "+1M gold", Cmd = "gold", Arg = 1e6 },
	{ Label = "+1T gold", Cmd = "gold", Arg = 1e12 },
	{ Label = "+10K xp", Cmd = "xp", Arg = 1e4 },
	{ Label = "+1M xp", Cmd = "xp", Arg = 1e6 },
	{ Label = "Level 10", Cmd = "level", Arg = 10 },
	{ Label = "Level 200", Cmd = "level", Arg = 200 },
	{ Label = "+5 boxes", Cmd = "box", Arg = 5 },
	{ Label = "+20 gear", Cmd = "gear", Arg = 20 },
	{ Label = "+100 materials", Cmd = "mats", Arg = 100 },
	{ Label = "+5 rebirth pts", Cmd = "points", Arg = 5 },
}

local function Dev(): React.ReactNode
	local buttons: { [string]: React.ReactNode } = {
		Grid = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(150, 40),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for i, c in COMMANDS do
		buttons[`C{i}`] = e(Widgets.Button, {
			text = c.Label,
			layoutOrder = i,
			onClick = function()
				State.Send.DevCommand(c.Cmd, c.Arg)
			end,
		})
	end
	return e(FloatWindow, {
		id = "Dev",
		title = "Dev",
		onClose = function()
			State.CloseWindow("Dev")
		end,
		defaultSize = Vector2.new(508, 336),
		minSize = Vector2.new(400, 300),
	}, buttons)
end

return Dev
