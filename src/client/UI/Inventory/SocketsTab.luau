--!strict
-- Inventory window, Sockets tab (create socket): Use (empty = "+", narrows the grid to duplicates) + Keep slots joined to the Result slot, gold cost, Create (merge, confirm), Socket Core.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Format = require(ReplicatedStorage.Shared.Format)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Inserts = require(ReplicatedStorage.Shared.Config.Inserts)
local Theme = require(script.Parent.Parent.Core.Theme)
local Widgets = require(script.Parent.Parent.Core.Widgets)
local ItemInfo = require(script.Parent.Parent.Core.ItemInfo)
local State = require(script.Parent.Parent.Parent.State)
local Parts = require(script.Parent.Parts)

local e = React.createElement
local UI = Text.UI

local SQUARE = 64
-- Use / Keep centres as shares of the width; Result sits under their middle.
local USE_X, KEEP_X = 0.3, 0.7
local RESULT_Y = 110
local DIAGRAM_H = RESULT_Y + SQUARE + Parts.CaptionHeight
local LINE = 2

export type Props = {
	data: Types.ProfileData,
	keep: Types.GearItem?,
	use: Types.GearItem?,
	onClearKeep: () -> (),
	onClearUse: () -> (),
	finding: boolean, -- the grid is narrowed to duplicates of the kept piece
	duplicates: number, -- pieces in the bag that can be used up for the kept one
	onFind: () -> (),
}

local function line(size: UDim2, position: UDim2, anchor: Vector2): React.ReactNode
	return e("Frame", {
		Size = size,
		Position = position,
		AnchorPoint = anchor,
		BackgroundColor3 = Theme.Stroke,
		BorderSizePixel = 0,
	})
end

-- Merge diagram, cost, Create and the Socket Core button.
local function createRows(props: Props): { [string]: React.ReactNode }
	local data, keep, use = props.data, props.keep, props.use
	local full = keep ~= nil and #keep.Sockets >= Inserts.MaxSockets
	local gold = if keep ~= nil then Formula.Forge.MergeGold(keep) else 0
	local ready = keep ~= nil and use ~= nil and not full and data.Gold >= gold
	local canFind = keep ~= nil and not full
	-- Middle height of the top squares, where the joining line runs.
	local joinY = Parts.CaptionHeight + SQUARE / 2

	local rows: { [string]: React.ReactNode } = { Layout = Widgets.List(Enum.FillDirection.Vertical, 6) }
	rows.Diagram = e("Frame", { Size = UDim2.new(1, 0, 0, DIAGRAM_H), BackgroundTransparency = 1, LayoutOrder = 1 }, {
		Across = line(UDim2.new(KEEP_X - USE_X, -SQUARE, 0, LINE), UDim2.new(0.5, 0, 0, joinY), Vector2.new(0.5, 0.5)),
		Down = line(UDim2.fromOffset(LINE, RESULT_Y - joinY), UDim2.new(0.5, 0, 0, joinY), Vector2.new(0.5, 0)),
		Use = e(Parts.Square, {
			caption = UI.Use,
			text = if use ~= nil then Parts.GearText(use) else UI.AddMark,
			textSize = if use ~= nil then nil else 30,
			size = SQUARE,
			position = UDim2.fromScale(USE_X, 0),
			anchor = Vector2.new(0.5, 0),
			selected = use ~= nil or props.finding,
			dim = use == nil and not canFind,
			onClick = if use ~= nil then props.onClearUse elseif canFind then props.onFind else nil,
		}),
		Keep = e(Parts.Square, {
			caption = UI.Keep,
			text = if keep ~= nil then Parts.GearText(keep) else "",
			size = SQUARE,
			position = UDim2.fromScale(KEEP_X, 0),
			anchor = Vector2.new(0.5, 0),
			selected = keep ~= nil,
			dim = keep == nil,
			onClick = if keep ~= nil then props.onClearKeep else nil,
		}),
		Result = e(Parts.Square, {
			caption = UI.Result,
			text = if keep ~= nil and not full
				then `{ItemInfo.Name(keep)}\n{UI.Sockets} {#keep.Sockets + 1}`
				elseif full then UI.SocketsMax
				else "",
			size = SQUARE,
			position = UDim2.new(0.5, 0, 0, RESULT_Y),
			anchor = Vector2.new(0.5, 0),
			dim = not (keep ~= nil and use ~= nil and not full),
		}),
	})
	rows.Hint = Parts.Hint(
		if keep == nil
			then UI.PickKeep
			elseif full then UI.SocketsMax
			elseif use ~= nil then ""
			elseif props.duplicates == 0 then UI.NoDuplicate
			else UI.PickUse,
		2
	)
	rows.Cost = e("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 3 }, {
		Line = Parts.CostLine(
			UI.GoldCost,
			Parts.Amount(data.Gold, gold),
			keep == nil or data.Gold >= gold,
			UDim2.fromScale(0, 0)
		),
	})
	rows.Go = e("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 4 }, {
		Create = e(Widgets.Button, {
			text = UI.Create,
			size = UDim2.fromOffset(180, 40),
			position = UDim2.fromScale(0.5, 0),
			anchor = Vector2.new(0.5, 0),
			color = if ready then Theme.Confirm else nil,
			disabled = not ready,
			onClick = function()
				if keep == nil or use == nil then
					return
				end
				local lost = if use.Plus > 0 or #use.Enchants > 0
					then ` Its +{use.Plus}{if #use.Enchants > 0
						then " and power " .. Text.TraitName(use.Enchants[1].Id)
						else ""} are lost too.`
					else ""
				State.OpenConfirm({
					Title = `Use up {ItemInfo.Name(use)} for a socket?`,
					Body = `{ItemInfo.Line(use)} is destroyed for good and {ItemInfo.Name(keep)} gains socket {#keep.Sockets + 1}.{lost} Costs {Format.Number(
						gold
					)} gold.`,
					OkText = UI.Create,
					Danger = true,
					OnConfirm = function()
						State.Send.MergeSocket(keep.Uid, use.Uid)
					end,
				})
			end,
		}),
	})
	-- A Socket Core adds a socket without a duplicate piece.
	if keep ~= nil and not full then
		local cores = data.Stacks[Inserts.CoreItem] or 0
		rows.Core = e("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = 5 }, {
			Button = e(Widgets.Button, {
				text = `Use {Text.Material(Inserts.CoreItem)} (have {cores})`,
				size = UDim2.fromOffset(260, 34),
				position = UDim2.fromScale(0.5, 0),
				anchor = Vector2.new(0.5, 0),
				textSize = 14,
				disabled = cores <= 0,
				onClick = function()
					State.Send.UseSocketCore(keep.Uid)
				end,
			}),
		})
	end
	return rows
end

local function SocketsTab(props: Props): React.ReactNode
	return Parts.Scroll(createRows(props))
end

return SocketsTab
