--!strict
-- Quests window: daily / weekly / monthly tabs, quest cards in two columns (progress, rewards, claim), reset countdown + claim all.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Format = require(ReplicatedStorage.Shared.Format)
local Period = require(ReplicatedStorage.Shared.Period)
local Quests = require(ReplicatedStorage.Shared.Config.Quests)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local Theme = require(script.Parent.Core.Theme)
local FloatWindow = require(script.Parent.Core.FloatWindow)
local Widgets = require(script.Parent.Core.Widgets)
local State = require(script.Parent.Parent.State)

local e = React.createElement
local UI = Text.Eco.UI

local WINDOW = Vector2.new(980, 600)
-- FloatWindow frame around the content (title bar + padding).
local CHROME = Vector2.new(12, 14)
local TABS_H = 46
local FOOTER_H = 54
local CARD_H = 92
local CLAIM_W = 110
local REWARD_W = 150

export type Props = { data: Types.ProfileData }

local TABS = {
	{ Id = "Daily", Label = UI.Daily },
	{ Id = "Weekly", Label = UI.Weekly },
	{ Id = "Monthly", Label = UI.Monthly },
}

-- Progress for the current period (a stale saved period counts as fresh: the server resets it on next touch).
local function periodOf(data: Types.ProfileData, kind: Period.Kind): Types.QuestPeriod?
	local p: Types.QuestPeriod = (data.Quests :: any)[kind]
	if p == nil or p.Key ~= Period.Key(kind) then
		return nil
	end
	return p
end

local function questCard(def: Quests.QuestDef, have: number, claimed: boolean, order: number): React.ReactNode
	local done = have >= def.Need
	local left = -(CLAIM_W + REWARD_W + 20)
	return e("Frame", {
		BackgroundColor3 = Theme.PanelAlt,
		BorderSizePixel = 0,
		LayoutOrder = order,
	}, {
		Corner = Widgets.Corner(8),
		Stroke = Widgets.Stroke(),
		Padding = Widgets.Padding(10),
		Name = e(Widgets.Label, { text = Text.Eco.Quest(def), bold = true, size = UDim2.new(1, left, 0, 22) }),
		Count = e(Widgets.Label, {
			text = `{Format.Number(math.min(have, def.Need))} / {Format.Number(def.Need)}`,
			textSize = 15,
			color = Theme.Subtext,
			size = UDim2.new(1, left, 0, 20),
			position = UDim2.fromOffset(0, 28),
		}),
		Bar = e(Widgets.Bar, {
			ratio = have / def.Need,
			size = UDim2.new(1, left, 0, 6),
			position = UDim2.new(0, 0, 1, -6),
		}),
		Rewards = e("Frame", {
			Size = UDim2.new(0, REWARD_W, 1, 0),
			Position = UDim2.new(1, -(CLAIM_W + 10), 0, 0),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
		}, {
			RubyIcon = e(Widgets.Icon, { image = Icons.Ruby, size = 22, position = UDim2.fromOffset(0, 8) }),
			Ruby = e(Widgets.Label, {
				text = `+{def.Ruby} Ruby`,
				textSize = 15,
				size = UDim2.new(1, -28, 0, 22),
				position = UDim2.fromOffset(28, 8),
			}),
			Points = e(Widgets.Label, {
				text = `+{def.PassPoints} {UI.PassPoints}`,
				textSize = 15,
				size = UDim2.new(1, 0, 0, 22),
				position = UDim2.fromOffset(0, 40),
			}),
		}),
		Claim = e(Widgets.Button, {
			text = if claimed then UI.Claimed else UI.Claim,
			size = UDim2.fromOffset(CLAIM_W, 44),
			position = UDim2.fromScale(1, 0.5),
			anchor = Vector2.new(1, 0.5),
			color = if done and not claimed then Theme.Confirm else nil,
			disabled = claimed or not done,
			onClick = function()
				State.Send.ClaimQuest(def.Id)
			end,
		}),
	})
end

local function QuestsPage(props: Props): React.ReactNode
	local data = props.data
	local tab = State.Ui.PageTabs.Quests
	local kind: Period.Kind = if tab == "Weekly" then "Weekly" elseif tab == "Monthly" then "Monthly" else "Daily"
	Widgets.useTick(1)

	local p = periodOf(data, kind)
	local claimable = 0
	local cards: { [string]: React.ReactNode } = {
		Grid = e("UIGridLayout", {
			CellSize = UDim2.new(0.5, -10, 0, CARD_H),
			CellPadding = UDim2.fromOffset(12, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		-- Room for the card outlines inside the clipping scroll frame.
		Inset = e("UIPadding", {
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
			PaddingLeft = UDim.new(0, 2),
		}),
	}
	for i, def in Quests.ByPeriod[kind] do
		local have = if p ~= nil then p.Progress[def.Kind] or 0 else 0
		local claimed = p ~= nil and p.Claimed[def.Id] == true
		if have >= def.Need and not claimed then
			claimable += 1
		end
		cards[def.Id] = questCard(def, have, claimed, i)
	end

	return e(FloatWindow, {
		id = "Quests",
		title = `{UI.Quests}   ·   {Format.Number(data.Ruby)} Ruby`,
		onClose = function()
			State.CloseWindow("Quests")
		end,
		defaultSize = WINDOW - CHROME,
		minSize = Vector2.new(720, 440),
	}, {
		Tabs = e(Widgets.Tabs, {
			tabs = TABS,
			current = kind :: string,
			onSelect = function(id: string)
				State.SetPageTab("Quests", id)
			end,
		}),
		List = e("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, -(TABS_H + FOOTER_H)),
			Position = UDim2.fromOffset(0, TABS_H),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, cards),
		Reset = e(Widgets.Label, {
			text = `{UI.ResetsIn} {Format.Time(math.max(Period.Ends(kind) - os.time(), 0))} (UTC)`,
			bold = true,
			textSize = 20,
			size = UDim2.new(1, -180, 0, 44),
			position = UDim2.fromScale(0, 1),
			anchor = Vector2.new(0, 1),
		}),
		ClaimAll = e(Widgets.Button, {
			text = UI.ClaimAll,
			size = UDim2.fromOffset(160, 44),
			position = UDim2.fromScale(1, 1),
			anchor = Vector2.new(1, 1),
			color = if claimable > 0 then Theme.Confirm else nil,
			disabled = claimable == 0,
			onClick = function()
				State.Send.ClaimQuest(kind)
			end,
		}),
	})
end

return QuestsPage
