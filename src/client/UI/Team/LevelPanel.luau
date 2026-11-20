--!strict
-- Team window, middle column: picked hero's level, Rebirth button (job change modal), xp bar (amount written inside) and the Skill Tree button; below, the level path (what every level gives: stats, a skill, or a class advancement).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Format = require(ReplicatedStorage.Shared.Format)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Text = require(ReplicatedStorage.Shared.Text)
local Skills = require(ReplicatedStorage.Shared.Config.Skills)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local Rebirth = require(ReplicatedStorage.Shared.Config.Rebirth)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local VirtualList = require(script.Parent.Parent.Core.VirtualList)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement
local UI = Text.UI

local HEAD_H = 60
local XP_H = 18
local LEVEL_W = 72
-- Header when the class is not owned: only the Skill Tree button.
local HEAD_BARE = 40
local ROW_H = 56
local LINE_W = 8
local NO_GEAR: { Types.GearItem } = {}

export type Props = {
	data: Types.ProfileData,
	classId: string,
}

local function pct(ratio: number): number
	return math.floor(ratio * 100 + 0.5)
end

-- Base stats gained on reaching `level` (without gear), or the starting stats at level 1.
local function statGain(classId: string, level: number, advancement: number, path: number?): string
	local now = Formula.Stats.Hero(classId, level, NO_GEAR, advancement, path)
	if level <= 1 then
		return `HP {Format.Number(now.MaxHp)} · Attack {Format.Number(now.Atk)} · Defense {Format.Number(now.Def)}`
	end
	local before = Formula.Stats.Hero(classId, level - 1, NO_GEAR, advancement, path)
	return `+{Format.Number(now.MaxHp - before.MaxHp)} HP · +{Format.Number(now.Atk - before.Atk)} Attack · +{Format.Number(
		now.Def - before.Def
	)} Defense`
end

local function LevelPanel(props: Props): React.ReactNode
	local data, classId = props.data, props.classId
	local hero: Types.HeroState? = data.Heroes[classId]
	local level = if hero ~= nil then hero.Level else 0
	local advancement = if hero ~= nil then hero.Advancement else 0
	local cap = Rebirth.Get(data.Rebirth.Count).HeroLevelCap
	local path = if hero ~= nil then hero.Path else nil
	local power = Classes.Totals(advancement, path).SkillPower
	-- Stage name on the hero's path; both paths' names while none is chosen.
	local function stageName(index: number): string
		if advancement > 0 then
			return Text.Advancement(classId, index, path)
		end
		local names: { string } = {}
		for _, p in Classes.Paths do
			table.insert(names, Text.Advancement(classId, index, p.Index))
		end
		return table.concat(names, " / ")
	end

	local skillAt: { [number]: Skills.SkillDef } = {}
	local classSkills: { Skills.SkillDef } = Skills.ByClass[classId] or {}
	for _, def in classSkills do
		skillAt[def.UnlockLevel] = def
	end
	local stageAt: { [number]: Classes.StageDef } = {}
	for _, stage in Classes.Stages do
		stageAt[stage.HeroLevel] = stage
	end

	local function row(index: number): React.ReactNode
		local reached = index <= level
		local title = `Lv {index}`
		local detail: string
		local button: React.ReactNode = nil
		local skill, stage = skillAt[index], stageAt[index]
		if stage ~= nil then
			title ..= `  ·  {UI.Advance}: {stageName(stage.Index)}`
			if stage.Index == advancement + 1 and hero ~= nil then
				local needs = { `{Format.Number(data.Gold)}/{Format.Number(stage.Gold)} gold` }
				local ok = level >= stage.HeroLevel and data.Gold >= stage.Gold
				for id, n in stage.Items do
					local have = data.Stacks[id] or 0
					table.insert(needs, `{have}/{n} {Text.Material(id)}`)
					ok = ok and have >= n
				end
				detail = `Needs: {table.concat(needs, " · ")}`
				button = e(Widgets.Button, {
					text = UI.Advance,
					size = UDim2.fromOffset(96, 30),
					position = UDim2.new(1, -8, 0.5, 0),
					anchor = Vector2.new(1, 0.5),
					textSize = 15,
					color = if ok then Theme.Confirm else nil,
					disabled = not ok,
					onClick = function()
						State.OpenJobChange(classId)
					end,
				})
			else
				detail = `+{pct(stage.StatBonus)}% base stats · +{pct(stage.SkillPower)}% skill power · {pct(
					stage.CooldownCut
				)}% shorter cooldowns`
			end
		elseif skill ~= nil then
			title ..= `  ·  {UI.Skill}: {Text.Skill(skill.Id)}`
			detail = Text.SkillDesc(skill, Formula.Skills.Resolve(skill, advancement, path), power)
		else
			detail = statGain(classId, index, advancement, path)
		end
		local textWidth = if button ~= nil then -122 else -20
		return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
			-- Level line: 4 px taller than the row so the segments join across the list's row gap.
			Line = e("Frame", {
				Size = UDim2.new(0, LINE_W, 1, 4),
				Position = UDim2.fromOffset(2, 0),
				BackgroundColor3 = if reached then Theme.Bar else Theme.BarBack,
				BorderSizePixel = 0,
			}),
			Card = e("Frame", {
				Size = UDim2.new(1, -(LINE_W + 12), 1, 0),
				Position = UDim2.fromOffset(LINE_W + 12, 0),
				BackgroundColor3 = if index == level then Theme.Hover else Theme.PanelAlt,
				BackgroundTransparency = if reached then 0 else 0.5,
			}, {
				Corner = Widgets.Corner(6),
				Stroke = if index == level then Widgets.Stroke(Theme.Accent, 1.5, 0) else nil,
				Title = e(Widgets.Label, {
					text = title,
					bold = true,
					textSize = 15,
					color = if reached then Theme.Text else Theme.Subtext,
					position = UDim2.fromOffset(10, 6),
					size = UDim2.new(1, textWidth, 0, 20),
				}),
				Detail = e(Widgets.Label, {
					text = detail,
					color = Theme.Subtext,
					textSize = 13,
					position = UDim2.fromOffset(10, 27),
					size = UDim2.new(1, textWidth, 0, 18),
				}),
				Button = button,
			}),
		})
	end

	local children: { [string]: React.ReactNode } = {
		Tree = e(Widgets.Button, {
			text = UI.Tree,
			size = UDim2.fromOffset(140, 30),
			position = UDim2.fromScale(1, 0),
			anchor = Vector2.new(1, 0),
			textSize = 15,
			onClick = function()
				State.OpenWindow("Tree")
			end,
		}),
	}
	if hero ~= nil then
		local need = Formula.Progression.HeroXpToNext(level)
		local maxed = level >= cap
		children.Level = e(Widgets.Label, {
			text = `Lv {level}`,
			bold = true,
			textSize = 18,
			size = UDim2.fromOffset(LEVEL_W, 28),
		})
		-- Job change: lit when the next advancement's level is reached.
		local nextStage = Classes.Stages[advancement + 1]
		children.Job = e(Widgets.Button, {
			text = if nextStage ~= nil then UI.JobButton else UI.Max,
			size = UDim2.fromOffset(96, 30),
			position = UDim2.fromOffset(LEVEL_W + 6, 0),
			textSize = 15,
			color = if nextStage ~= nil and level >= nextStage.HeroLevel then Theme.Confirm else nil,
			disabled = nextStage == nil,
			onClick = function()
				State.OpenJobChange(classId)
			end,
		})
		children.Xp = e("Frame", {
			Size = UDim2.new(1, 0, 0, XP_H),
			Position = UDim2.fromOffset(0, 34),
			BackgroundColor3 = Theme.BarBack,
			BorderSizePixel = 0,
		}, {
			Corner = Widgets.Corner(XP_H / 2),
			Fill = e("Frame", {
				Size = UDim2.fromScale(if maxed then 1 else math.clamp(hero.Xp / need, 0, 1), 1),
				BackgroundColor3 = Theme.Bar,
				BorderSizePixel = 0,
			}, { Corner = Widgets.Corner(XP_H / 2) }),
			-- Sits over both the light fill and the dark back: outlined so it reads on either.
			Amount = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = if maxed then UI.Max else `{Format.Number(hero.Xp)}/{Format.Number(need)}`,
				TextColor3 = Theme.OnDark,
				FontFace = Theme.FontBold,
				TextSize = 13,
				ZIndex = 2,
			}, {
				Outline = e("UIStroke", { Color = Theme.OnLight, Thickness = 1.5 }),
			}),
		})
	end
	local headH = if hero ~= nil then HEAD_H else HEAD_BARE
	-- Keyed by class so the list remounts (and scrolls to that hero's level) when another class is picked.
	local body: { [string]: React.ReactNode } = {
		["Path" .. classId] = e(VirtualList, {
			count = cap,
			rowHeight = ROW_H,
			initialIndex = level - 1,
			renderRow = row,
		}),
	}
	children.Body = e("Frame", {
		Size = UDim2.new(1, 0, 1, -headH),
		Position = UDim2.fromOffset(0, headH),
		BackgroundTransparency = 1,
	}, body)
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, children)
end

return LevelPanel
