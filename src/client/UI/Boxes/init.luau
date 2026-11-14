--!strict
-- Boxes page: one row per stack (kind · rebirth · level band) with open N / open all; convert a normal or boss stack into class boxes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Boxes = require(ReplicatedStorage.Shared.Config.Boxes)
local Heroes = require(ReplicatedStorage.Shared.Config.Heroes)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Theme = require(script.Parent.Core.Theme)
local Widgets = require(script.Parent.Core.Widgets)
local VirtualList = require(script.Parent.Core.VirtualList)
local State = require(script.Parent.Parent.State)

local e = React.createElement
local UI = Text.UI

export type Props = { data: Types.ProfileData }

type Stack = { Key: string, Kind: string, Rebirth: number, Band: number, Count: number, Max: number, Order: number }

local function stacks(data: Types.ProfileData): { Stack }
	local out: { Stack } = {}
	local bonus = Formula.Mods.Build(data.SkillTree, data.SkillOff, data.AccountLevel).BoxCapPct
	for key, count in data.Boxes do
		local parsed = Boxes.Parse(key)
		local def = if parsed ~= nil then Boxes.ById[parsed.Kind] else nil
		if parsed ~= nil and def ~= nil and count > 0 then
			table.insert(out, {
				Key = key,
				Kind = parsed.Kind,
				Rebirth = parsed.Rebirth,
				Band = parsed.Band,
				Count = count,
				Max = Boxes.Cap(parsed.Kind, bonus),
				Order = def.Order,
			})
		end
	end
	table.sort(out, function(a, b)
		if a.Order ~= b.Order then
			return a.Order < b.Order
		elseif a.Rebirth ~= b.Rebirth then
			return a.Rebirth > b.Rebirth
		end
		return a.Band > b.Band
	end)
	return out
end

local function BoxesPage(props: Props): React.ReactNode
	local data = props.data
	local counts, setCounts = React.useState({} :: { [string]: number })
	local source, setSource = Widgets.useOptional(nil :: string?)
	local convertClass, setConvertClass = React.useState("Warrior")
	local convertCount, setConvertCount = React.useState(1)

	local list = stacks(data)

	local sourceHave = if source ~= nil then data.Boxes[source] or 0 else 0
	local maxConvert = math.max(sourceHave // Boxes.ConvertCost, 1)
	local amount = math.min(convertCount, maxConvert)

	local convertRow: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Horizontal, 6) }
	for i, def in Heroes.List do
		convertRow[def.Id] = e(Widgets.Button, {
			text = Text.Class(def.Id),
			size = UDim2.fromOffset(96, 34),
			selected = convertClass == def.Id,
			layoutOrder = i,
			onClick = function()
				setConvertClass(def.Id)
			end,
		})
	end
	convertRow.Count = e(Widgets.Stepper, {
		value = amount,
		min = 1,
		max = maxConvert,
		layoutOrder = 10,
		onChange = setConvertCount,
	})
	convertRow.Go = e(Widgets.Button, {
		text = `{UI.Convert} (-{Boxes.ConvertCost * amount})`,
		size = UDim2.fromOffset(150, 34),
		textSize = 15,
		disabled = source == nil or sourceHave < Boxes.ConvertCost,
		layoutOrder = 11,
		onClick = function()
			if source ~= nil then
				State.Send.ConvertBox(source, convertClass, amount)
			end
		end,
	})

	return e(Widgets.Window, {
		title = UI.Boxes,
		onClose = function()
			State.SetPage(nil)
		end,
		closeOnBackdrop = true,
		maxSize = Vector2.new(980, 680),
	}, {
		Empty = if #list == 0 then e(Widgets.Label, { text = "No boxes yet", color = Theme.Subtext }) else nil,
		List = e(VirtualList, {
			count = #list,
			rowHeight = 46,
			size = UDim2.new(1, 0, 1, -96),
			renderRow = function(index: number): React.ReactNode
				local stack = list[index]
				local want = math.clamp(counts[stack.Key] or 1, 1, stack.Count)
				local convertible = table.find(Boxes.ConvertSources, stack.Kind) ~= nil
				return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.PanelAlt }, {
					Corner = Widgets.Corner(6),
					Name = e(Widgets.Label, {
						text = `{Text.Box(stack.Key)}   {stack.Count}/{stack.Max}`,
						size = UDim2.fromScale(0.42, 1),
						position = UDim2.fromOffset(10, 0),
					}),
					Controls = e("Frame", {
						Size = UDim2.new(0.58, -10, 1, -8),
						Position = UDim2.new(1, -6, 0.5, 0),
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundTransparency = 1,
					}, {
						Layout = Widgets.List(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right),
						Count = e(Widgets.Stepper, {
							value = want,
							min = 1,
							max = stack.Count,
							layoutOrder = 1,
							onChange = function(n: number)
								local nextCounts = table.clone(counts)
								nextCounts[stack.Key] = n
								setCounts(nextCounts)
							end,
						}),
						Open = e(Widgets.Button, {
							text = `{UI.Open} {want}`,
							size = UDim2.fromOffset(84, 32),
							layoutOrder = 2,
							onClick = function()
								State.Send.OpenBox(stack.Key, want)
							end,
						}),
						All = e(Widgets.Button, {
							text = UI.OpenAll,
							size = UDim2.fromOffset(84, 32),
							layoutOrder = 3,
							onClick = function()
								State.Send.OpenBox(stack.Key, stack.Count)
							end,
						}),
						Pick = if convertible
							then e(Widgets.Button, {
								text = "→ class",
								size = UDim2.fromOffset(84, 32),
								selected = source == stack.Key,
								layoutOrder = 4,
								onClick = function()
									setSource(if source == stack.Key then nil else stack.Key)
								end,
							})
							else nil,
					}),
				})
			end,
		}),
		ConvertHead = e(Widgets.Label, {
			text = if source ~= nil
				then `Convert {Boxes.ConvertCost} × {Text.Box(source)} → 1 class box (same rebirth and levels)`
				else `Pick a Box or Boss Box stack with "→ class" to convert {Boxes.ConvertCost} into 1 class box`,
			position = UDim2.new(0, 0, 1, -84),
			bold = true,
			textSize = 16,
		}),
		Convert = e("Frame", {
			Size = UDim2.new(1, 0, 0, 34),
			Position = UDim2.new(0, 0, 1, -40),
			BackgroundTransparency = 1,
		}, convertRow),
	})
end

return BoxesPage
