--!strict
-- Quests page: daily / weekly / monthly quest lists (progress, reward, claim, reset countdown) + the Battle Pass tab.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Format = require(ReplicatedStorage.Shared.Format)
local Period = require(ReplicatedStorage.Shared.Period)
local Quests = require(ReplicatedStorage.Shared.Config.Quests)
local Theme = require(script.Parent.Core.Theme)
local Widgets = require(script.Parent.Core.Widgets)
local State = require(script.Parent.Parent.State)
local PassTab = require(script.Pass)

local e = React.createElement
local UI = Text.Eco.UI

export type Props = { data: Types.ProfileData }

local TABS = {
	{ Id = "Daily", Label = UI.Daily },
	{ Id = "Weekly", Label = UI.Weekly },
	{ Id = "Monthly", Label = UI.Monthly },
	{ Id = "Pass", Label = UI.Pass },
}

-- Progress for the current period (a stale saved period counts as fresh: the server resets it on next touch).
local function periodOf(data: Types.ProfileData, kind: Period.Kind): Types.QuestPeriod?
	local p: Types.QuestPeriod = (data.Quests :: any)[kind]
	if p == nil or p.Key ~= Period.Key(kind) then
		return nil
	end
	return p
end

local function questRow(def: Quests.QuestDef, p: Types.QuestPeriod?, order: number): React.ReactNode
	local have = if p ~= nil then p.Progress[def.Kind] or 0 else 0
	local claimed = p ~= nil and p.Claimed[def.Id] == true
	local done = have >= def.Need
	return e("Frame", {
		Size = UDim2.new(1, -8, 0, 64),
		BackgroundColor3 = Theme.PanelAlt,
		LayoutOrder = order,
	}, {
		Corner = Widgets.Corner(8),
		Padding = Widgets.Padding(10),
		Desc = e(Widgets.Label, { text = Text.Eco.Quest(def), bold = true, size = UDim2.new(1, -150, 0, 20) }),
		Reward = e(Widgets.Label, {
			text = `+{def.Ruby} Ruby  ·  +{def.PassPoints} {UI.PassPoints}`,
			color = Theme.Subtext,
			textSize = 15,
			size = UDim2.new(0.5, 0, 0, 18),
			position = UDim2.fromOffset(0, 24),
		}),
		Count = e(Widgets.Label, {
			text = `{Format.Number(math.min(have, def.Need))} / {Format.Number(def.Need)}`,
			textSize = 15,
			size = UDim2.new(0.3, 0, 0, 18),
			position = UDim2.new(0.5, 0, 0, 24),
		}),
		Bar = e(Widgets.Bar, {
			ratio = have / def.Need,
			size = UDim2.new(1, -150, 0, 4),
			position = UDim2.new(0, 0, 1, -4),
		}),
		Claim = e(Widgets.Button, {
			text = if claimed then UI.Claimed else UI.Claim,
			size = UDim2.fromOffset(130, 40),
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
	local tab = State.Ui.PageTab or "Daily"
	Widgets.useTick(1)

	local body: React.ReactNode
	if tab == "Pass" then
		body = e(PassTab, { data = data })
	else
		local kind: Period.Kind = if tab == "Weekly" then "Weekly" elseif tab == "Monthly" then "Monthly" else "Daily"
		local p = periodOf(data, kind)
		local rows: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Vertical, 8) }
		for i, def in Quests.ByPeriod[kind] do
			rows[def.Id] = questRow(def, p, i)
		end
		body = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
			Reset = e(Widgets.Label, {
				text = `{UI.ResetsIn} {Format.Time(math.max(Period.Ends(kind) - os.time(), 0))} (UTC)`,
				color = Theme.Subtext,
			}),
			List = e("ScrollingFrame", {
				Size = UDim2.new(1, 0, 1, -30),
				Position = UDim2.fromOffset(0, 30),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 6,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
			}, rows),
		})
	end

	return e(Widgets.Window, {
		title = `{UI.Quests}   ·   {Format.Number(data.Ruby)} Ruby`,
		onClose = function()
			State.SetPage(nil)
		end,
		closeOnBackdrop = true,
		maxSize = Vector2.new(960, 700),
	}, {
		Tabs = e(Widgets.Tabs, { tabs = TABS, current = tab, onSelect = State.SetPageTab }),
		Body = e("Frame", {
			Size = UDim2.new(1, 0, 1, -46),
			Position = UDim2.fromOffset(0, 46),
			BackgroundTransparency = 1,
		}, { Content = body }),
	})
end

return QuestsPage
