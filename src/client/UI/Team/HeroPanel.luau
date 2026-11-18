--!strict
-- Team window, left column: model preview of the picked class with its name (or "not owned") (buy button when not owned), class strip paged with arrow buttons, then either the 10 gear slots laid out around the body or the class skills (toggle button), Inventory button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Format = require(ReplicatedStorage.Shared.Format)
local Text = require(ReplicatedStorage.Shared.Text)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Heroes = require(ReplicatedStorage.Shared.Config.Heroes)
local Skills = require(ReplicatedStorage.Shared.Config.Skills)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local ItemInfo = require(script.Parent.Parent.Core.ItemInfo)
local ModelView = require(script.Parent.Parent.Core.ModelView)
local State = require(script.Parent.Parent.Parent.State)

local e = React.createElement
local UI = Text.UI

-- Share of the column height used by the preview.
local PREVIEW = 0.38
local STRIP_H = 36
-- Class buttons shown at once between the arrows.
local VISIBLE = 2
local ARROW_W = 32
local TOGGLE = Vector2.new(84, 26)
local FOOT_H = 36
local GAP = 8
-- Templates face -Z: look at them from the front, a little to the side and above.
local VIEW = Vector3.new(-0.5, 0.25, -1)

-- Gear slot -> centre of its cell in the slot area (fractions): armour down the middle, hands left, jewellery right.
local DOLL: { [string]: Vector2 } = {
	Helmet = Vector2.new(0.38, 0.125),
	Armor = Vector2.new(0.38, 0.375),
	Pants = Vector2.new(0.38, 0.625),
	Boots = Vector2.new(0.38, 0.875),
	MainHand = Vector2.new(0.13, 0.375),
	OffHand = Vector2.new(0.13, 0.625),
	Bracelet1 = Vector2.new(0.65, 0.375),
	Bracelet2 = Vector2.new(0.87, 0.375),
	Ring1 = Vector2.new(0.65, 0.625),
	Ring2 = Vector2.new(0.87, 0.625),
}

export type Props = {
	data: Types.ProfileData,
	classId: string,
	slot: string?, -- gear slot whose picker is open
	onSelect: (classId: string) -> (),
	onSlot: (slot: string?) -> (),
}

local function HeroPanel(props: Props): React.ReactNode
	local data, classId, slot = props.data, props.classId, props.slot
	local hero: Types.HeroState? = data.Heroes[classId]
	local def = Heroes.ById[classId]

	local tab, setTab = React.useState("Gear")
	local offset, setOffset = React.useState(0)
	local count = #Heroes.List
	local maxOffset = math.max(count - VISIBLE, 0)
	local picked = 1
	for i, class in Heroes.List do
		if class.Id == classId then
			picked = i
		end
	end
	-- A class picked elsewhere (a team cell) is brought into the strip.
	React.useEffect(function()
		setOffset(function(current: number): number
			return math.clamp(current, math.max(picked - VISIBLE, 0), math.min(picked - 1, maxOffset))
		end)
	end, { picked })

	local classes: { [string]: React.ReactNode } = {}
	for i = 1, VISIBLE do
		local class = Heroes.List[offset + i]
		if class ~= nil then
			local owned = data.Heroes[class.Id]
			classes[class.Id] = e(Widgets.Button, {
				text = if owned ~= nil then `{Text.Class(class.Id)}  Lv {owned.Level}` else Text.Class(class.Id),
				size = UDim2.new(1 / VISIBLE, -4, 1, 0),
				position = UDim2.new((i - 1) / VISIBLE, 2, 0, 0),
				textSize = 14,
				textColor = if owned ~= nil then nil else Theme.Subtext,
				selected = class.Id == classId,
				onClick = function()
					props.onSelect(class.Id)
				end,
			})
		end
	end

	local level = if hero ~= nil then hero.Level else 0
	local advancement = if hero ~= nil then hero.Advancement else 0
	local skills: { [string]: React.ReactNode } = {}
	if tab == "Skills" then
		local power = Classes.Totals(advancement).SkillPower
		local forClass: { Skills.SkillDef } = Skills.ByClass[classId] or {}
		local order = 0
		for _, slotName in Skills.SlotOrder do
			for _, skill in forClass do
				if skill.Slot == slotName then
					local unlocked = hero ~= nil and Formula.Skills.IsUnlocked(skill, level)
					local at = order / #Skills.SlotOrder
					order += 1
					skills[skill.Id] = e("Frame", {
						Size = UDim2.new(1, 0, 1 / #Skills.SlotOrder, -4),
						Position = UDim2.fromScale(0, at),
						BackgroundColor3 = Theme.PanelAlt,
						BackgroundTransparency = if unlocked then 0 else 0.5,
					}, {
						Corner = Widgets.Corner(6),
						Name = e(Widgets.Label, {
							text = `{Text.Skill(skill.Id)}{if unlocked
								then ""
								else "  ·  " .. UI.Unlocks .. " " .. skill.UnlockLevel}`,
							bold = true,
							textSize = 14,
							color = if unlocked then Theme.Text else Theme.Subtext,
							position = UDim2.fromOffset(8, 4),
							size = UDim2.new(1, -16, 0, 18),
						}),
						Desc = e(Widgets.Label, {
							text = Text.SkillDesc(skill, Formula.Skills.Resolve(skill, advancement), power),
							color = Theme.Subtext,
							textSize = 12,
							wrap = true,
							position = UDim2.fromOffset(8, 22),
							size = UDim2.new(1, -16, 1, -26),
						}),
					})
				end
			end
		end
	end

	local cells: { [string]: React.ReactNode } = {}
	for name, at in DOLL do
		local item = if hero ~= nil then data.Gear[hero.Equipped[name] or ""] else nil
		local open = slot == name
		cells[name] = e("TextButton", {
			Size = UDim2.fromScale(0.2, 0.22),
			Position = UDim2.fromScale(at.X, at.Y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if open then Theme.Hover else Theme.PanelAlt,
			BackgroundTransparency = if hero ~= nil then 0 else 0.6,
			AutoButtonColor = hero ~= nil,
			Active = hero ~= nil,
			Text = if item ~= nil then `{ItemInfo.Name(item)}\nLv {item.Level}` else Text.Slot(name),
			TextColor3 = if item ~= nil then Theme.Text else Theme.Subtext,
			FontFace = Theme.Font,
			TextSize = 12,
			TextWrapped = true,
			[React.Event.Activated] = function()
				if hero ~= nil then
					props.onSlot(if open then nil else name)
				end
			end,
		}, {
			Aspect = e("UIAspectRatioConstraint", { AspectRatio = 1 }),
			Corner = Widgets.Corner(6),
			Stroke = if open then Widgets.Stroke(Theme.Accent, 1.5, 0) else Widgets.Stroke(),
		})
	end

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Preview = e("Frame", { Size = UDim2.fromScale(1, PREVIEW), BackgroundTransparency = 1 }, {
			Model = e(ModelView, { entries = { { Class = classId, Position = Vector3.zero } }, view = VIEW }),
			-- Above the viewport: sibling order is not fixed, so the overlay sets its own ZIndex.
			Overlay = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 }, {
				Name = e(Widgets.Label, {
					text = if hero ~= nil
						then Text.Advancement(classId, hero.Advancement)
						else `{Text.Class(classId)}  ·  {UI.NotOwned}`,
					bold = true,
					textSize = 17,
					position = UDim2.fromOffset(10, 8),
					size = UDim2.new(1, -20, 0, 22),
				}),
				Buy = if hero == nil and def ~= nil
					then e(Widgets.Button, {
						text = `{UI.Buy} {Text.Class(classId)} · {Format.Number(def.Price)} gold`,
						size = UDim2.new(1, -16, 0, 34),
						position = UDim2.new(0.5, 0, 1, -8),
						anchor = Vector2.new(0.5, 1),
						textSize = 15,
						color = if data.Gold >= def.Price then Theme.Confirm else nil,
						disabled = data.Gold < def.Price,
						onClick = function()
							State.Send.BuyHero(classId)
						end,
					})
					else nil,
			}),
		}),
		Classes = e("Frame", {
			Size = UDim2.new(1, 0, 0, STRIP_H),
			Position = UDim2.new(0, 0, PREVIEW, GAP),
			BackgroundTransparency = 1,
		}, {
			Previous = e(Widgets.Button, {
				text = "<",
				size = UDim2.new(0, ARROW_W, 1, 0),
				disabled = offset <= 0,
				onClick = function()
					setOffset(math.max(offset - 1, 0))
				end,
			}),
			Next = e(Widgets.Button, {
				text = ">",
				size = UDim2.new(0, ARROW_W, 1, 0),
				position = UDim2.fromScale(1, 0),
				anchor = Vector2.new(1, 0),
				disabled = offset >= maxOffset,
				onClick = function()
					setOffset(math.min(offset + 1, maxOffset))
				end,
			}),
			Shown = e("Frame", {
				Size = UDim2.new(1, -(ARROW_W + 2) * 2, 1, 0),
				Position = UDim2.fromOffset(ARROW_W + 2, 0),
				BackgroundTransparency = 1,
			}, classes),
		}),
		-- Switches the area below between gear slots and class skills; labelled with the view it opens.
		Toggle = e(Widgets.Button, {
			text = if tab == "Gear" then UI.Skills else UI.Gear,
			size = UDim2.fromOffset(TOGGLE.X, TOGGLE.Y),
			position = UDim2.new(1, 0, PREVIEW, STRIP_H + GAP * 2),
			anchor = Vector2.new(1, 0),
			textSize = 14,
			onClick = function()
				setTab(if tab == "Gear" then "Skills" else "Gear")
				props.onSlot(nil)
			end,
		}),
		Slots = if tab == "Gear"
			then e("Frame", {
				Size = UDim2.new(1, 0, 1 - PREVIEW, -(STRIP_H + GAP * 3 + FOOT_H)),
				Position = UDim2.new(0, 0, PREVIEW, STRIP_H + GAP * 2),
				BackgroundTransparency = 1,
			}, cells)
			else nil,
		Skills = if tab == "Skills"
			then e("Frame", {
				Size = UDim2.new(1, 0, 1 - PREVIEW, -(STRIP_H + GAP * 4 + FOOT_H + TOGGLE.Y)),
				Position = UDim2.new(0, 0, PREVIEW, STRIP_H + GAP * 3 + TOGGLE.Y),
				BackgroundTransparency = 1,
			}, skills)
			else nil,
		Inventory = e(Widgets.Button, {
			text = UI.Inventory,
			size = UDim2.new(1, 0, 0, FOOT_H),
			position = UDim2.fromScale(0, 1),
			anchor = Vector2.new(0, 1),
			onClick = function()
				State.OpenWindow("Inventory")
			end,
		}),
	})
end

return HeroPanel
