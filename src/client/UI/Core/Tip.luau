--!strict
-- Overlay state drawn by Core/Tooltip: the hovered slot's card, a pinned card (clicked slot), and dragging a gear piece between windows (drop targets register here). Kept out of the client store so pointer moves only redraw the overlay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Types = require(ReplicatedStorage.Shared.Types)

export type Content = {
	Kind: string, -- "Gear" | "Material" | "Box" | "Socket"
	Item: Types.GearItem?, -- Gear / Socket
	Live: boolean?, -- Item is the player's own: redraw from State.Data by Uid (a trade partner's piece is a snapshot)
	Wearer: string?, -- class id the stats and ability are read for
	Id: string?, -- material id or box key
	Count: number?, -- units in the hovered slot
	Index: number?, -- Socket: 1-based
	Compare: boolean?, -- bag piece: also show what the Team window's hero wears in that slot
}

export type Current = {
	Anchor: GuiObject,
	Content: Content,
}

export type Drag = {
	Uid: string,
	Label: string,
	Position: Vector2, -- pointer, pixels (same space as AbsolutePosition)
	Active: boolean, -- moved past the threshold (before that it is still a click)
}

local Tip = {}

local hovered: Current? = nil
local pinned: Current? = nil
local drag: Drag? = nil
local listeners: { [() -> ()]: boolean } = {}
local targets: { [string]: GuiObject } = {}

-- Pixels the pointer must move before a press becomes a drag.
local DRAG_START = 6
-- Seconds between two clicks on the same thing that count as a double click.
local DOUBLE = 0.45

Tip.Version = 0

local function changed()
	Tip.Version += 1
	for fn in listeners do
		fn()
	end
end

local function isTouch(): boolean
	return UserInputService:GetLastInputType() == Enum.UserInputType.Touch
end

function Tip.Subscribe(fn: () -> ()): () -> ()
	listeners[fn] = true
	return function()
		listeners[fn] = nil
	end
end

-- What the card shows: the hovered slot, else the pinned one. Nothing while dragging.
function Tip.Focus(): Current?
	if drag ~= nil and drag.Active then
		return nil
	end
	return hovered or pinned
end

function Tip.Pinned(): Current?
	return pinned
end

function Tip.Show(anchor: GuiObject, content: Content)
	-- Touch has no hover: a tap would leave the card stuck on screen (taps pin instead).
	if isTouch() then
		return
	end
	hovered = { Anchor = anchor, Content = content }
	changed()
end

-- Hides the hover card; with `anchor`, only if that object is the one showing it.
function Tip.Hide(anchor: GuiObject?)
	if hovered ~= nil and (anchor == nil or hovered.Anchor == anchor) then
		hovered = nil
		changed()
	end
end

-- Keeps a card up after the pointer leaves (a clicked slot) until Unpin or a press elsewhere.
function Tip.Pin(anchor: GuiObject, content: Content?)
	pinned = if content ~= nil then { Anchor = anchor, Content = content } else nil
	changed()
end

function Tip.Unpin(anchor: GuiObject?)
	if pinned ~= nil and (anchor == nil or pinned.Anchor == anchor) then
		pinned = nil
		changed()
	end
end

-- Handlers for [React.Event.MouseEnter] / [React.Event.MouseLeave]. Entering with nil content hides the hover card.
-- Typed `(...any) -> ()`: a props table's event handlers unify to one type, and the others take (rbx, input).
function Tip.Enter(content: Content?): (...any) -> ()
	return function(rbx: GuiObject)
		if content ~= nil then
			Tip.Show(rbx, content)
		else
			Tip.Hide()
		end
	end
end

Tip.Leave = function(rbx: GuiObject)
	Tip.Hide(rbx)
end :: (...any) -> ()

-- Double click: true when the same key was clicked within DOUBLE seconds (the pair is then used up).
local lastKey: string? = nil
local lastAt = 0
function Tip.Double(key: string): boolean
	local now = os.clock()
	if lastKey == key and now - lastAt <= DOUBLE then
		lastKey = nil
		return true
	end
	lastKey, lastAt = key, now
	return false
end

-- Drop targets for dragged gear, by key (Team gear slot name). Pass nil to remove.
function Tip.SetTarget(key: string, rbx: GuiObject?)
	if rbx ~= nil then
		targets[key] = rbx
	else
		targets[key] = nil
	end
end

function Tip.Dragging(): Drag?
	return if drag ~= nil and drag.Active then drag else nil
end

local function targetAt(p: Vector2): string?
	for key, rbx in targets do
		if rbx:IsDescendantOf(game) and rbx.Visible then
			local at, size = rbx.AbsolutePosition, rbx.AbsoluteSize
			if p.X >= at.X and p.Y >= at.Y and p.X <= at.X + size.X and p.Y <= at.Y + size.Y then
				return key
			end
		end
	end
	return nil
end

-- Pressing a gear slot: becomes a drag once the pointer moves; on release over a target `onDrop(key)` runs.
function Tip.Press(input: InputObject, uid: string, label: string, onDrop: (target: string) -> ())
	local kind = input.UserInputType
	if drag ~= nil or (kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch) then
		return
	end
	local start = Vector2.new(input.Position.X, input.Position.Y)
	local current: Drag = { Uid = uid, Label = label, Position = start, Active = false }
	drag = current
	local moved, ended
	moved = UserInputService.InputChanged:Connect(function(change: InputObject)
		local t = change.UserInputType
		if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then
			return
		end
		current.Position = Vector2.new(change.Position.X, change.Position.Y)
		if not current.Active and (current.Position - start).Magnitude >= DRAG_START then
			current.Active = true
			hovered = nil
		end
		if current.Active then
			changed()
		end
	end)
	ended = UserInputService.InputEnded:Connect(function(done: InputObject)
		local t = done.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
			return
		end
		moved:Disconnect()
		ended:Disconnect()
		drag = nil
		if current.Active then
			local key = targetAt(Vector2.new(done.Position.X, done.Position.Y))
			changed()
			if key ~= nil then
				onDrop(key)
			end
		end
	end)
end

function Tip.Gear(item: Types.GearItem?, wearer: string?): Content?
	if item == nil then
		return nil
	end
	return { Kind = "Gear", Item = item, Live = true, Wearer = wearer }
end

-- A bag piece: its card is shown beside what the Team window's hero wears in that slot.
function Tip.BagGear(item: Types.GearItem?, wearer: string?): Content?
	if item == nil then
		return nil
	end
	return { Kind = "Gear", Item = item, Live = true, Wearer = wearer, Compare = true }
end

-- Someone else's piece (trade partner): shown exactly as given.
function Tip.Snapshot(item: Types.GearItem?): Content?
	if item == nil then
		return nil
	end
	return { Kind = "Gear", Item = item, Live = false }
end

function Tip.Material(id: string, count: number?): Content
	return { Kind = "Material", Id = id, Count = count }
end

function Tip.Box(key: string, count: number?): Content
	return { Kind = "Box", Id = key, Count = count }
end

function Tip.Socket(item: Types.GearItem, index: number, wearer: string?): Content
	return { Kind = "Socket", Item = item, Live = true, Index = index, Wearer = wearer }
end

return Tip
