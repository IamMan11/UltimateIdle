--!strict
-- Team window, middle column: picked hero's level, xp bar (amount written inside) and the Skill Tree button; below, the level path (what every level gives: stats, a skill, or a class advancement) or the gear picker while a slot is open.

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
local GearPicker = require(script.Parent.GearPicker)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement
local UI = Text.UI

local HEAD_H = 60
local XP_H = 18
-- Header when the class is not owned: only the Skill Tree button.
local HEAD_BARE = 40
local ROW_H = 56
local LINE_W = 8
local NO_GEAR: { Types.GearItem } = {}

export type Props = {
	data: Types.ProfileData,
	classId: string,
	slot: string?,
	onSlot: (slot: string?) -> (),
}

local function pct(ratio: number): number
	return math.floor(ratio * 100 + 0.5)
end

-- Base stats gained on reaching `level` (without gear), or the starting stats at level 1.
local function statGain(classId: string, level: number, advancement: number): string
	local now = Formula.Stats.Hero(classId, level, NO_GEAR, advancement)
	if level <= 1 then
		return `HP {Format.Number(now.MaxHp)} · Attack {Format.Number(now.Atk)} · Defense {Format.Number(now.Def)}`
	end
	local before = Formula.Stats.Hero(classId, level - 1, NO_GEAR, advancement)
	return `+{Format.Number(now.MaxHp - before.MaxHp)} HP · +{Format.Number(now.Atk - before.Atk)} Attack · +{Format.Number(
		now.Def - before.Def
	)} Defense`
end

local function LevelPanel(props: Props): React.ReactNode
	local data, classId, slot = props.data, props.classId, props.slot
	local hero: Types.HeroState? = data.Heroes[classId]
	local level = if hero ~= nil then hero.Level else 0
	local advancement = if hero ~= nil then hero.Advancement else 0
	local cap = Rebirth.Get(data.Rebirth.Count).HeroLevelCap
	local power = Classes.Totals(advancement).SkillPower

	local skillAt: { [number]: Skills.SkillDef } = {}
	local classSkills: { Skills.SkillDef } = Skills.ByClass[classId] or {}
	for _, def in classSkills do
		skillAt[def.UnlockLevel] = def
	end
	local stageAt: { [number]: Classes.StageDef } = {}
	for _, stage in Classes.Stages do
		stageAt[stage.HeroLevel] = stage
	end

	local function advance(stage: Classes.StageDef)
		local nextName = Text.Advancement(classId, stage.Index)
		local itemParts = {}
		for id, n in stage.Items do
			table.insert(itemParts, `{n} {Text.Material(id)}`)
		end
		State.OpenConfirm({
			Title = `Advance {Text.Class(classId)} to {nextName}?`,
			Body = `Spends {Format.Number(stage.Gold)} gold and {table.concat(itemParts, ", ")}. Advancement is permanent.`,
			OkText = `Advance to {nextName}`,
			Danger = false,
			OnConfirm = function()
				State.Send.Advance(classId)
			end,
		})
	end

	local function row(index: number): React.ReactNode
		local reached = index <= level
		local title = `Lv {index}`
		local detail: string
		local button: React.ReactNode = nil
		local skill, stage = skillAt[index], stageAt[index]
		if stage ~= nil then
			title ..= `  ·  {UI.Advance}: {Text.Advancement(classId, stage.Index)}`
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
						advance(stage)
					end,
				})
			else
				detail = `+{pct(stage.StatBonus)}% base stats · +{pct(stage.SkillPower)}% skill power · {pct(
					stage.CooldownCut
				)}% shorter cooldowns`
			end
		elseif skill ~= nil then
			title ..= `  ·  {UI.Skill}: {Text.Skill(skill.Id)}`
			detail = Text.SkillDesc(skill, Formula.Skills.Resolve(skill, advancement), power)
		else
			detail = statGain(classId, index, advancement)
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
			size = UDim2.new(1, -150, 0, 28),
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
	local body: { [string]: React.ReactNode } = {}
	if hero ~= nil and slot ~= nil then
		body.Picker = e(GearPicker, {
			data = data,
			heroId = classId,
			hero = hero,
			slot = slot,
			onClose = function()
				props.onSlot(nil)
			end,
		})
	else
		-- Keyed by class so the list remounts (and scrolls to that hero's level) when another class is picked.
		body["Path" .. classId] = e(VirtualList, {
			count = cap,
			rowHeight = ROW_H,
			initialIndex = level - 1,
			renderRow = row,
		})
	end
	children.Body = e("Frame", {
		Size = UDim2.new(1, 0, 1, -headH),
		Position = UDim2.fromOffset(0, headH),
		BackgroundTransparency = 1,
	}, body)
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, children)
end

return LevelPanel
