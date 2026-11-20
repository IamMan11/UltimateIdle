--!strict
-- Job change modal (Team window's Rebirth button, State.Ui.JobChange = hero id): the hero's next class advancement. First advancement = pick one of the class's two paths; after that the path is fixed. Shows what is needed and what each choice gives; the choice is sent to the server and is permanent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Format = require(ReplicatedStorage.Shared.Format)
local Text = require(ReplicatedStorage.Shared.Text)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local Theme = require(script.Parent.Parent.Core.Theme)
local Art = require(script.Parent.Parent.Core.Art)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement
local UI = Text.UI

local SIZE = Vector2.new(660, 400)
local NEEDS_H = 44
local FOOT_H = 24
local GAP = 12

export type Props = { data: Types.ProfileData, heroId: string }

local function pct(ratio: number): number
	return math.floor(ratio * 100 + 0.5)
end

local function JobChange(props: Props): React.ReactNode
	local data, heroId = props.data, props.heroId
	local hero = data.Heroes[heroId]
	local stage = if hero ~= nil then Classes.Stages[hero.Advancement + 1] else nil
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

	local body: { [string]: React.ReactNode } = {}
	if hero == nil or stage == nil then
		body.Done = e(Widgets.Label, {
			text = UI.AdvanceMax,
			color = Theme.Subtext,
			align = Enum.TextXAlignment.Center,
			size = UDim2.fromScale(1, 1),
		})
	else
		local needs = {
			`Lv {hero.Level}/{stage.HeroLevel}`,
			`{Format.Number(data.Gold)}/{Format.Number(stage.Gold)} gold`,
		}
		local ok = hero.Level >= stage.HeroLevel and data.Gold >= stage.Gold
		for id, n in stage.Items do
			local have = data.Stacks[id] or 0
			table.insert(needs, `{have}/{n} {Text.Material(id)}`)
			ok = ok and have >= n
		end
		body.Needs = e(Widgets.Label, {
			text = `{UI.JobNeeds}: {table.concat(needs, "  ·  ")}`,
			color = if ok then Theme.Text else Theme.Subtext,
			textSize = 15,
			wrap = true,
			size = UDim2.new(1, 0, 0, NEEDS_H),
		})

		-- The path is chosen with the first advancement and kept after it.
		local choices: { Classes.PathDef } = {}
		for _, path in Classes.Paths do
			if hero.Advancement == 0 or path.Index == (hero.Path or 1) then
				table.insert(choices, path)
			end
		end
		local cards: { [string]: React.ReactNode } = {}
		for i, path in choices do
			local name = Text.Advancement(heroId, stage.Index, path.Index)
			local lines = {
				`+{pct(stage.StatBonus)}% base stats`,
				`+{pct(stage.SkillPower + path.SkillPower)}% skill power`,
				`{pct(stage.CooldownCut)}% shorter cooldowns`,
			}
			if path.AtkPct > 0 then
				table.insert(lines, `+{pct(path.AtkPct)}% Attack`)
			end
			if path.HpPct > 0 then
				table.insert(lines, `+{pct(path.HpPct)}% HP`)
			end
			if path.DefPct > 0 then
				table.insert(lines, `+{pct(path.DefPct)}% Defense`)
			end
			local after = Classes.Stages[stage.Index + 1]
			if after ~= nil then
				table.insert(
					lines,
					`{UI.JobThen}: {Text.Advancement(heroId, after.Index, path.Index)} (Lv {after.HeroLevel})`
				)
			end
			cards[`Path{path.Index}`] = e("Frame", {
				Size = UDim2.new(1 / #choices, -GAP * (#choices - 1) / #choices, 1, 0),
				Position = UDim2.new((i - 1) / #choices, if i > 1 then GAP / #choices * (i - 1) else 0, 0, 0),
				BackgroundTransparency = 1,
			}, {
				Art = Art.Back({ piece = "PaperCompactSharp", padding = 16 }),
				Padding = Widgets.Padding(16),
				Name = e(Widgets.Label, { text = name, bold = true, textSize = 20, size = UDim2.new(1, 0, 0, 24) }),
				Path = e(Widgets.Label, {
					text = Text.Path(path.Index),
					color = Theme.Accent,
					bold = true,
					textSize = 14,
					position = UDim2.fromOffset(0, 26),
					size = UDim2.new(1, 0, 0, 18),
				}),
				Bonus = e(Widgets.Label, {
					text = table.concat(lines, "\n"),
					color = Theme.Subtext,
					textSize = 14,
					wrap = true,
					alignY = Enum.TextYAlignment.Top,
					position = UDim2.fromOffset(0, 52),
					size = UDim2.new(1, 0, 1, -(52 + 46)),
				}),
				Choose = e(Widgets.Button, {
					text = `{UI.JobChoose} {name}`,
					size = UDim2.new(1, 0, 0, 38),
					position = UDim2.fromScale(0, 1),
					anchor = Vector2.new(0, 1),
					textSize = 15,
					color = if ok then Theme.Confirm else nil,
					disabled = not ok or not ready,
					onClick = function()
						State.Send.Advance(heroId, path.Index)
						State.CloseJobChange()
					end,
				}),
			})
		end
		body.Cards = e("Frame", {
			Size = UDim2.new(1, 0, 1, -(NEEDS_H + FOOT_H + 8)),
			Position = UDim2.fromOffset(0, NEEDS_H),
			BackgroundTransparency = 1,
		}, cards)
		body.Note = e(Widgets.Label, {
			text = if hero.Advancement == 0 then UI.JobNotePick else UI.JobNote,
			color = Theme.Subtext,
			textSize = 13,
			position = UDim2.fromScale(0, 1),
			anchor = Vector2.new(0, 1),
			size = UDim2.new(1, 0, 0, FOOT_H),
		})
	end

	return e(Widgets.Window, {
		title = `{UI.JobTitle}: {if hero ~= nil
			then Text.Advancement(heroId, hero.Advancement, hero.Path)
			else Text.Class(heroId)}`,
		onClose = State.CloseJobChange,
		size = UDim2.fromOffset(SIZE.X, SIZE.Y),
		zIndex = Theme.ZModal,
	}, body)
end

return JobChange
