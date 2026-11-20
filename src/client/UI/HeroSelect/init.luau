--!strict
-- Forced first-login choice of the first hero (Warrior / Mage / Archer). Cannot be dismissed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Text = require(ReplicatedStorage.Shared.Text)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Heroes = require(ReplicatedStorage.Shared.Config.Heroes)
local Theme = require(script.Parent.Core.Theme)
local Art = require(script.Parent.Core.Art)
local Widgets = require(script.Parent.Core.Widgets)
local State = require(script.Parent.Parent.State)

local e = React.createElement

local function HeroSelect(): React.ReactNode
	local pending, setPending = React.useState(false)
	local cards: { [string]: React.ReactNode } = {
		Layout = Widgets.List(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center),
	}
	for i, class in Game.StarterClasses do
		local def = Heroes.ById[class]
		cards[class] = e("Frame", {
			Size = UDim2.fromOffset(220, 260),
			BackgroundTransparency = 1,
			LayoutOrder = i,
		}, {
			Art = Art.Back({ piece = "PaperCompactSharp", padding = 16 }),
			Padding = Widgets.Padding(16),
			Name = e(Widgets.Label, { text = Text.Class(class), bold = true, textSize = 22 }),
			Stats = e(Widgets.Label, {
				stat = true,
				text = `HP {def.MaxHp}\nAttack {def.Atk}\nDefense {def.Def}\nRange {def.Range}\nBest row: {Text.Row(
					def.PreferredRow
				)}`,
				size = UDim2.new(1, 0, 0, 130),
				position = UDim2.fromOffset(0, 34),
				color = Theme.Subtext,
				wrap = true,
			}),
			Pick = e(Widgets.Button, {
				text = Text.UI.Choose,
				size = UDim2.new(1, 0, 0, 40),
				position = UDim2.fromScale(0, 1),
				anchor = Vector2.new(0, 1),
				color = Theme.Confirm,
				disabled = pending,
				onClick = function()
					setPending(true)
					State.Send.ChooseFirstHero(class)
				end,
			}),
		})
	end
	return e(Widgets.Window, {
		title = Text.UI.ChooseHeroTitle,
		size = UDim2.fromOffset(740, 400),
		zIndex = Theme.ZModal,
	}, {
		Body = e(Widgets.Label, { text = Text.UI.ChooseHeroBody, color = Theme.Subtext }),
		Cards = e("Frame", {
			Size = UDim2.new(1, 0, 1, -34),
			Position = UDim2.fromOffset(0, 34),
			BackgroundTransparency = 1,
		}, cards),
	})
end

return HeroSelect
