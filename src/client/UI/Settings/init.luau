--!strict
-- Settings page: auto-salvage per tier, skip-wave toggle, box auto-open (once unlocked in the skill tree).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Theme = require(script.Parent.Core.Theme)
local Widgets = require(script.Parent.Core.Widgets)
local State = require(script.Parent.Parent.State)

local e = React.createElement

export type Props = { data: Types.ProfileData }

local function Settings(props: Props): React.ReactNode
	local settings = props.data.Settings
	local rows: { [string]: React.ReactNode } = {
		Layout = Widgets.List(Enum.FillDirection.Vertical, 8),
		Head = e(Widgets.Label, { text = Text.UI.AutoSalvage, bold = true, layoutOrder = 0 }),
	}
	for i, tier in Tiers.List do
		local on = settings.AutoSalvage[tier.Id] == true
		rows[tier.Id] = e(Widgets.Button, {
			text = `{Text.Tier(tier.Id)}: {if on then "ON" else "OFF"}`,
			size = UDim2.fromOffset(260, 38),
			selected = on,
			layoutOrder = i,
			onClick = function()
				State.Send.SetSetting("AutoSalvage", tier.Id, not on)
			end,
		})
	end
	rows.Skip = e(Widgets.Button, {
		text = if settings.SkipWave then Text.UI.SkipOn else Text.UI.SkipOff,
		size = UDim2.fromOffset(260, 38),
		selected = settings.SkipWave,
		layoutOrder = 20,
		onClick = function()
			State.Send.SetSetting("SkipWave", nil, not settings.SkipWave)
		end,
	})
	rows.Note = e(Widgets.Label, {
		text = "Skip wave sends all 5 waves at once, from the next level, on levels you have already cleared.",
		color = Theme.Subtext,
		textSize = 15,
		layoutOrder = 21,
	})
	local data = props.data
	local mods = Formula.Mods.Build(data.SkillTree, data.SkillOff, data.AccountLevel)
	rows.AutoOpen = e(Widgets.Button, {
		text = if not mods.AutoOpen
			then Text.UI.AutoOpenLocked
			else `{Text.UI.AutoOpen} (every {math.floor(mods.AutoOpenInterval * 10 + 0.5) / 10}s): {if settings.AutoOpenBoxes
				then Text.UI.On
				else Text.UI.Off}`,
		size = UDim2.fromOffset(420, 38),
		textSize = 15,
		selected = mods.AutoOpen and settings.AutoOpenBoxes,
		disabled = not mods.AutoOpen,
		layoutOrder = 30,
		onClick = function()
			State.Send.SetSetting("AutoOpenBoxes", nil, not settings.AutoOpenBoxes)
		end,
	})
	return e(Widgets.Window, {
		title = Text.UI.Settings,
		onClose = function()
			State.SetPage(nil)
		end,
		closeOnBackdrop = true,
		size = UDim2.fromOffset(520, 470),
	}, rows)
end

return Settings
