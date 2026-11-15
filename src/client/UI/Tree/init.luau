--!strict
-- Skill tree page: one column per branch, nodes on a grid with lines to their prerequisites, detail panel to buy (confirm) or toggle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Format = require(ReplicatedStorage.Shared.Format)
local SkillTree = require(ReplicatedStorage.Shared.Config.SkillTree)
local Theme = require(script.Parent.Core.Theme)
local Widgets = require(script.Parent.Core.Widgets)
local State = require(script.Parent.Parent.State)

local e = React.createElement
local UI = Text.UI

local NODE_W, NODE_H = 104, 52
local COL_GAP = 112 -- x distance between Col -1 / 0 / 1
local ROW_GAP = 74
local TOP = 34
local DETAIL_H = 120

export type Props = { data: Types.ProfileData }

type NodeState = "Owned" | "Available" | "Locked"

local function owns(data: Types.ProfileData, id: string): boolean
	return (data.SkillTree[id] or 0) > 0
end

local function stateOf(data: Types.ProfileData, def: SkillTree.NodeDef): NodeState
	if owns(data, def.Id) then
		return "Owned"
	end
	for _, req in def.Requires do
		if not owns(data, req) then
			return "Locked"
		end
	end
	return "Available"
end

local function costText(cost: SkillTree.Cost): string
	local parts = {}
	if (cost.Gold or 0) > 0 then
		table.insert(parts, `{Format.Number(cost.Gold :: number)} gold`)
	end
	local items: { [string]: number } = cost.Items or {}
	for id, n in items do
		table.insert(parts, `{n} {Text.Material(id)}`)
	end
	if (cost.RebirthPoints or 0) > 0 then
		table.insert(parts, `{cost.RebirthPoints} {UI.RebirthPoints}`)
	end
	return table.concat(parts, " · ")
end

-- Error key the server would answer with, so the button can explain itself before sending.
local function missing(data: Types.ProfileData, def: SkillTree.NodeDef): string?
	local cost = def.Cost
	if data.Gold < (cost.Gold or 0) then
		return "NotEnoughGold"
	end
	local items: { [string]: number } = cost.Items or {}
	for id, n in items do
		if (data.Stacks[id] or 0) < n then
			return "NotEnoughItems"
		end
	end
	if data.Rebirth.Points < (cost.RebirthPoints or 0) then
		return "NotEnoughPoints"
	end
	return nil
end

local function effectsText(def: SkillTree.NodeDef): string
	local parts = {}
	for _, effect in def.Effects do
		table.insert(parts, Text.Effect(effect))
	end
	return table.concat(parts, ", ")
end

local function line(a: Vector2, b: Vector2, color: Color3, key: string): (string, React.ReactNode)
	local d = b - a
	local mid = (a + b) / 2
	return key,
		e("Frame", {
			Size = UDim2.fromOffset(d.Magnitude, 2),
			Position = UDim2.new(0.5, mid.X, 0, mid.Y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = math.deg(math.atan2(d.Y, d.X)),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 1,
		})
end

local function TreePage(props: Props): React.ReactNode
	local data = props.data
	local selected, setSelected = Widgets.useOptional(nil :: string?)

	local maxRow = 1
	for _, def in SkillTree.List do
		maxRow = math.max(maxRow, def.Row)
	end

	local function center(def: SkillTree.NodeDef): Vector2
		return Vector2.new(def.Col * COL_GAP, TOP + (def.Row - 1) * ROW_GAP + NODE_H / 2)
	end

	local branches: { [string]: React.ReactNode } = {}
	for b, branch in SkillTree.Branches do
		local children: { [string]: React.ReactNode } = {
			Head = e(Widgets.Label, {
				text = Text.Branch(branch),
				bold = true,
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(1, 0, 0, 24),
			}),
		}
		for _, def in SkillTree.List do
			if def.Branch == branch then
				local st = stateOf(data, def)
				local c = center(def)
				for _, req in def.Requires do
					local reqDef = SkillTree.ById[req]
					local from = center(reqDef) + Vector2.new(0, NODE_H / 2)
					local to = c - Vector2.new(0, NODE_H / 2)
					local k, v =
						line(from, to, if owns(data, req) then Theme.Accent else Theme.Stroke, `L_{req}_{def.Id}`)
					children[k] = v
				end
				local off = def.Toggle and data.SkillOff[def.Id] == true
				local label = Text.Node(def.Id)
				if st == "Owned" and def.Toggle then
					label ..= if off then `\n{UI.Off}` else `\n{UI.On}`
				elseif st == "Owned" then
					label ..= "\n" .. UI.Owned
				end
				children[def.Id] = e("TextButton", {
					Size = UDim2.fromOffset(NODE_W, NODE_H),
					Position = UDim2.new(0.5, c.X, 0, c.Y),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = if st == "Owned" then Theme.Hover else Theme.PanelAlt,
					BackgroundTransparency = if st == "Locked" then 0.55 else 0,
					Text = label,
					TextColor3 = Theme.Text,
					TextTransparency = if st == "Locked" then 0.45 else 0,
					FontFace = Theme.FontBold,
					TextSize = 14,
					TextWrapped = true,
					ZIndex = 2,
					[React.Event.Activated] = function()
						setSelected(def.Id)
					end,
				}, {
					Corner = Widgets.Corner(6),
					Stroke = Widgets.Stroke(
						if selected == def.Id then Theme.Accent else Theme.Stroke,
						if selected == def.Id then 2 else 1,
						if selected == def.Id or st == "Owned" then 0 else 0.4
					),
				})
			end
		end
		branches[branch] = e("Frame", {
			Size = UDim2.new(1 / 3, -8, 1, 0),
			Position = UDim2.new((b - 1) / 3, 4, 0, 0),
			BackgroundTransparency = 1,
		}, children)
	end

	-- Detail panel
	local detail: { [string]: React.ReactNode } = {}
	local def = if selected ~= nil then SkillTree.ById[selected] else nil
	if def ~= nil then
		local st = stateOf(data, def)
		local reqNames = {}
		for _, req in def.Requires do
			table.insert(reqNames, Text.Node(req))
		end
		local cost = costText(def.Cost)
		detail.Name = e(Widgets.Label, {
			text = `{Text.Node(def.Id)}  ·  {Text.Branch(def.Branch)}{if def.Toggle
				then "  ·  can be switched off"
				else ""}`,
			bold = true,
		})
		detail.Effect = e(Widgets.Label, { text = effectsText(def), position = UDim2.fromOffset(0, 26) })
		detail.Cost = e(Widgets.Label, {
			text = `Cost: {if cost ~= "" then cost else "free"}{if #reqNames > 0
				then "   ·   Needs: " .. table.concat(reqNames, ", ")
				else ""}`,
			color = Theme.Subtext,
			textSize = 15,
			position = UDim2.fromOffset(0, 52),
			size = UDim2.new(1, -200, 0, 22),
		})
		local problem = if st == "Available" then missing(data, def) else nil
		if st == "Owned" and def.Toggle then
			local off = data.SkillOff[def.Id] == true
			detail.Action = e(Widgets.Button, {
				text = if off then "Turn on" else "Turn off",
				size = UDim2.fromOffset(180, 40),
				position = UDim2.fromScale(1, 1),
				anchor = Vector2.new(1, 1),
				onClick = function()
					State.Send.ToggleNode(def.Id, off)
				end,
			})
		elseif st ~= "Owned" then
			detail.Action = e(Widgets.Button, {
				text = if st == "Locked" then UI.Locked elseif problem ~= nil then Text.Error[problem] else UI.Buy,
				size = UDim2.fromOffset(180, 40),
				position = UDim2.fromScale(1, 1),
				anchor = Vector2.new(1, 1),
				textSize = if problem ~= nil then 14 else nil,
				color = if st == "Available" and problem == nil then Theme.Confirm else nil,
				disabled = st ~= "Available" or problem ~= nil,
				onClick = function()
					State.OpenConfirm({
						Title = `Unlock {Text.Node(def.Id)}?`,
						Body = `Spends {cost}. {effectsText(def)}. Skill tree nodes cannot be refunded.`,
						OkText = `Unlock {Text.Node(def.Id)}`,
						Danger = false,
						OnConfirm = function()
							State.Send.BuyNode(def.Id)
						end,
					})
				end,
			})
		end
	else
		detail.Hint = e(Widgets.Label, { text = "Select a node.", color = Theme.Subtext })
	end

	local gridH = TOP + maxRow * ROW_GAP
	return e(Widgets.Window, {
		title = UI.Team,
		group = "Team",
		onClose = function()
			State.SetPage(nil)
		end,
		closeOnBackdrop = true,
	}, {
		Grid = e("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, -(DETAIL_H + 10)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(0, gridH),
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Stroke,
			ScrollingDirection = Enum.ScrollingDirection.Y,
		}, branches),
		Detail = e("Frame", {
			Size = UDim2.new(1, 0, 0, DETAIL_H),
			Position = UDim2.fromScale(0, 1),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = Theme.Bg,
		}, {
			Corner = Widgets.Corner(8),
			Padding = Widgets.Padding(12),
			Content = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, detail),
		}),
	})
end

return TreePage
