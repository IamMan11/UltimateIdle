--!strict
-- Gamepass tab: pass cards in fixed slots (two banners, one wide, two square; empty slots read "Coming soon") + the potion grid (placeholder until potions exist).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local ShopConfig = require(ReplicatedStorage.Shared.Config.Shop)
local Theme = require(script.Parent.Parent.Core.Theme)
local Art = require(script.Parent.Parent.Core.Art)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement
local UI = Text.Eco.UI

export type Props = { data: Types.ProfileData }

local BANNER_H = 110
local GAP = 12
local ROW3_Y = 2 * (BANNER_H + GAP)
local SMALL = 124
local WIDE_W = 250
local POTIONS_X = WIDE_W + 2 * (SMALL + GAP) + 28
local POTION_COLS, POTION_ROWS = 4, 2
local POTION_BOX_H = 56
local POTION_H = POTION_BOX_H + 6 + 30 + 18
local POTION_GAP = 12

-- Pass slots in Config.Shop pass order: position + size (scale, offset pairs).
local SLOTS: { { Position: UDim2, Size: UDim2 } } = {
	{ Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, BANNER_H) },
	{ Position = UDim2.fromOffset(0, BANNER_H + GAP), Size = UDim2.new(1, 0, 0, BANNER_H) },
	{ Position = UDim2.fromOffset(0, ROW3_Y), Size = UDim2.fromOffset(WIDE_W, SMALL) },
	{ Position = UDim2.fromOffset(WIDE_W + GAP, ROW3_Y), Size = UDim2.fromOffset(SMALL, SMALL) },
	{ Position = UDim2.fromOffset(WIDE_W + SMALL + 2 * GAP, ROW3_Y), Size = UDim2.fromOffset(SMALL, SMALL) },
}

local function comingSoon(position: UDim2, size: UDim2): React.ReactNode
	return e("Frame", {
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
	}, {
		Art = Art.Back({ piece = "SlotPaper", transparency = 0.4 }),
		Label = e(Widgets.Label, {
			text = UI.ComingSoon,
			color = Theme.Subtext,
			align = Enum.TextXAlignment.Center,
			size = UDim2.fromScale(1, 1),
		}),
	})
end

local function passCard(def: ShopConfig.PassDef, position: UDim2, size: UDim2, banner: boolean): React.ReactNode
	local owned = State.Passes[def.Key] == true
	local forSale = def.PassId > 0
	local buy = e(Widgets.Button, {
		text = if owned then UI.Owned elseif forSale then UI.Buy else UI.NotForSale,
		size = if banner then UDim2.fromOffset(180, 46) else UDim2.new(1, 0, 0, 36),
		position = if banner then UDim2.fromScale(1, 0.5) else UDim2.fromScale(0, 1),
		anchor = if banner then Vector2.new(1, 0.5) else Vector2.new(0, 1),
		textSize = if forSale or owned then 17 else 13,
		color = if not owned and forSale then Theme.Confirm else nil,
		disabled = owned or not forSale,
		onClick = function()
			State.Send.BuyPass(def.Key)
		end,
	})
	local right = if banner then -200 else 0
	return e("Frame", {
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
	}, {
		Art = Art.Back({
			piece = if owned then "BtnPaperHover" else "PaperCompactSharp",
			padding = if banner then 18 else 12,
		}),
		Padding = Widgets.Padding(if banner then 18 else 12),
		Name = e(Widgets.Label, {
			text = Text.Eco.PassName(def.Key),
			bold = true,
			textSize = if banner then 26 else 18,
			size = UDim2.new(1, right, 0, if banner then 32 else 24),
		}),
		Desc = e(Widgets.Label, {
			text = Text.Eco.PassDesc(def.Key),
			color = Theme.Subtext,
			textSize = if banner then 16 else 13,
			wrap = true,
			alignY = Enum.TextYAlignment.Top,
			size = UDim2.new(1, right, 1, if banner then -38 else -(26 + 42)),
			position = UDim2.fromOffset(0, if banner then 38 else 26),
		}),
		Buy = buy,
	})
end

local function potion(index: number): React.ReactNode
	local col = (index - 1) % POTION_COLS
	local row = (index - 1) // POTION_COLS
	return e("Frame", {
		Size = UDim2.new(1 / POTION_COLS, -POTION_GAP, 0, POTION_H),
		Position = UDim2.new(col / POTION_COLS, POTION_GAP, 0, row * (POTION_H + POTION_GAP)),
		BackgroundTransparency = 1,
	}, {
		Box = e("Frame", {
			Size = UDim2.new(1, 0, 0, POTION_BOX_H),
			BackgroundTransparency = 1,
		}, {
			Art = Art.Back({ piece = "SlotPaper", transparency = 0.4 }),
			Name = e(Widgets.Label, {
				text = UI.Potion,
				bold = true,
				textSize = 15,
				color = Theme.Subtext,
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(1, 0, 0, 20),
				position = UDim2.fromOffset(0, 8),
			}),
			Soon = e(Widgets.Label, {
				text = UI.ComingSoon,
				textSize = 12,
				color = Theme.Subtext,
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(1, 0, 0, 16),
				position = UDim2.fromOffset(0, 30),
			}),
		}),
		Buy = e(Widgets.Button, {
			text = UI.Buy,
			size = UDim2.new(0.5, -3, 0, 30),
			position = UDim2.fromOffset(0, POTION_BOX_H + 6),
			textSize = 13,
			disabled = true,
		}),
		Use = e(Widgets.Button, {
			text = UI.Use,
			size = UDim2.new(0.5, -3, 0, 30),
			position = UDim2.new(0.5, 3, 0, POTION_BOX_H + 6),
			textSize = 13,
			disabled = true,
		}),
		Count = e(Widgets.Label, {
			text = "x0",
			textSize = 13,
			color = Theme.Subtext,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(0.5, -3, 0, 16),
			position = UDim2.new(0.5, 3, 0, POTION_BOX_H + 38),
		}),
	})
end

local function PassesTab(_props: Props): React.ReactNode
	local children: { [string]: React.ReactNode } = {}
	for i, slot in SLOTS do
		local def = ShopConfig.Passes[i]
		children[`Slot{i}`] = if def ~= nil
			then passCard(def, slot.Position, slot.Size, i <= 2)
			else comingSoon(slot.Position, slot.Size)
	end
	local potions: { [string]: React.ReactNode } = {}
	for i = 1, POTION_COLS * POTION_ROWS do
		potions[`P{i}`] = potion(i)
	end
	children.Potions = e("Frame", {
		Size = UDim2.new(1, -POTIONS_X, 0, POTION_ROWS * (POTION_H + POTION_GAP)),
		Position = UDim2.fromOffset(POTIONS_X, ROW3_Y),
		BackgroundTransparency = 1,
	}, potions)
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, children)
end

return PassesTab
