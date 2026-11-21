--!strict
-- Enhance tab, Upgrade mode: UpgradeCount In slots (empty = "+", narrows the grid to inserts; filled from the grid, same kind + tier), pay gold, get one random insert of the same kind from the next tier.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Format = require(ReplicatedStorage.Shared.Format)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Inserts = require(ReplicatedStorage.Shared.Config.Inserts)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local State = require(script.Parent.Parent.Parent.State)
local Parts = require(script.Parent.Parts)

local e = React.createElement
local UI = Text.UI

local SQUARE = 64
local SQUARE_GAP = 12
local ARROW_W = 40

export type Props = {
	data: Types.ProfileData,
	slots: { string }, -- inserts in the In slots, all one kind + tier
	finding: boolean, -- the grid is narrowed to inserts that fit the slots
	onFind: () -> (),
	onSlots: (slots: { string }) -> (),
}

local function bestLevel(data: Types.ProfileData): number
	local best = 1
	for _, p in data.Stage.ByRebirth do
		best = math.max(best, p.MaxLevel)
	end
	return best
end

local function pool(kind: string, tier: string): { string }
	local byTier = Inserts.Pools[kind]
	return if byTier ~= nil then byTier[tier] or {} else {}
end

local function UpgradePanel(props: Props): React.ReactNode
	local data = props.data
	local slots = props.slots
	local first = if slots[1] ~= nil then Inserts.ById[slots[1]] else nil
	local need = Inserts.UpgradeCount
	local gold = if first ~= nil then Formula.Forge.UpgradeGold(first.Tier, bestLevel(data)) else 0
	local ready = #slots == need and data.Gold >= gold

	local rows: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Vertical, 8) }

	-- In slots -> arrow -> Result
	local diagram: { [string]: React.ReactNode } = {}
	local width = need * SQUARE + (need - 1) * SQUARE_GAP + ARROW_W + SQUARE
	local left = -width / 2
	for i = 1, need do
		local id = slots[i]
		diagram[`In{i}`] = e(Parts.Square, {
			caption = `{UI.UpgradeIn} {i}`,
			text = if id ~= nil then Text.Material(id) else UI.AddMark,
			tier = if id ~= nil then Parts.MaterialTier(id) else nil,
			textSize = if id ~= nil then nil else 30,
			size = SQUARE,
			position = UDim2.new(0.5, left + (i - 1) * (SQUARE + SQUARE_GAP), 0, 0),
			selected = id ~= nil or props.finding,
			-- Filled: take the insert back out · empty: list the inserts that fit in the grid.
			onClick = if id ~= nil
				then function()
					local copy = table.clone(slots)
					table.remove(copy, i)
					props.onSlots(copy)
				end
				else props.onFind,
		})
	end
	local arrowX = left + need * SQUARE + (need - 1) * SQUARE_GAP
	diagram.Arrow = e(Widgets.Label, {
		text = ">",
		bold = true,
		textSize = 22,
		color = Theme.Subtext,
		align = Enum.TextXAlignment.Center,
		size = UDim2.fromOffset(ARROW_W, SQUARE),
		position = UDim2.new(0.5, arrowX, 0, Parts.CaptionHeight),
	})
	local last = State.Ui.LastUpgrade
	local showLast = #slots == 0 and last ~= nil
	diagram.Result = e(Parts.Square, {
		caption = UI.UpgradeOut,
		tier = if showLast and last ~= nil then Parts.MaterialTier(last) else nil,
		text = if showLast and last ~= nil
			then Text.Material(last)
			elseif first ~= nil then `?\n{Text.Tier(Inserts.NextTier[first.Tier] or first.Tier)}\n{Text.SocketKind(
				first.Kind
			)}`
			else "?",
		size = SQUARE,
		position = UDim2.new(0.5, arrowX + ARROW_W, 0, 0),
		selected = showLast,
		dim = not showLast and #slots < need,
	})
	rows.Diagram = e(
		"Frame",
		{ Size = UDim2.new(1, 0, 0, SQUARE + Parts.CaptionHeight), BackgroundTransparency = 1, LayoutOrder = 3 },
		diagram
	)

	local hintText = UI.UpgradePick
	if first ~= nil then
		local kindName = string.lower(Text.SocketKind(first.Kind))
		local nextTier = Inserts.NextTier[first.Tier] or first.Tier
		local outcomes: { string } = {}
		for _, id in pool(first.Kind, nextTier) do
			table.insert(outcomes, Text.Material(id))
		end
		hintText =
			`Put in {need} {Text.Tier(first.Tier)} {kindName}s, get 1 random {Text.Tier(nextTier)} {kindName}.\n{UI.UpgradePossible}: {table.concat(
				outcomes,
				", "
			)}`
	end
	rows.Hint = e(Widgets.Label, {
		text = hintText,
		color = Theme.Subtext,
		textSize = 13,
		wrap = true,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 36),
		layoutOrder = 4,
	})

	rows.Cost = e("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 6 }, {
		Line = Parts.CostLine(
			UI.GoldCost,
			if first ~= nil then Parts.Amount(data.Gold, gold) else "-",
			first == nil or data.Gold >= gold,
			UDim2.fromScale(0, 0)
		),
	})
	rows.Go = e("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 7 }, {
		Upgrade = e(Widgets.Button, {
			text = UI.Upgrade,
			icon = Icons.Upgrade,
			size = UDim2.fromOffset(180, 40),
			position = UDim2.fromScale(0.5, 0),
			anchor = Vector2.new(0.5, 0),
			color = if ready then Theme.Confirm else nil,
			disabled = not ready,
			onClick = function()
				local ids = table.clone(slots)
				local names: { string } = {}
				for _, id in ids do
					table.insert(names, Text.Material(id))
				end
				if first == nil then
					return
				end
				local kindName = string.lower(Text.SocketKind(first.Kind))
				local nextTier = Inserts.NextTier[first.Tier] or first.Tier
				State.OpenConfirm({
					Title = `Upgrade {need} {Text.Tier(first.Tier)} {kindName}s?`,
					Body = `{table.concat(names, ", ")} are used up for 1 random {Text.Tier(nextTier)} {kindName}. Costs {Format.Number(
						gold
					)} gold.`,
					OkText = UI.Upgrade,
					Danger = true,
					OnConfirm = function()
						State.Send.UpgradeInsert(ids)
						props.onSlots({})
					end,
				})
			end,
		}),
	})

	return e("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, rows)
end

return UpgradePanel
