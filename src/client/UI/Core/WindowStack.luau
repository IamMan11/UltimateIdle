--!strict
-- Which open floating window sits under a point: FloatWindow registers its frame here, App raises the hit window on click/touch.

local State = require(script.Parent.Parent.Parent.State)

local WindowStack = {}

local frames: { [string]: GuiObject } = {}

function WindowStack.Register(id: string, frame: GuiObject)
	frames[id] = frame
end

function WindowStack.Unregister(id: string, frame: GuiObject)
	if frames[id] == frame then
		frames[id] = nil
	end
end

-- Topmost open window containing `point` (same space as AbsolutePosition / InputObject.Position).
function WindowStack.Hit(point: Vector2): string?
	local windows = State.Ui.Windows
	for i = #windows, 1, -1 do
		local id = windows[i]
		local frame: GuiObject? = frames[id]
		if frame ~= nil and frame:IsDescendantOf(game) then
			local from = frame.AbsolutePosition
			local to = from + frame.AbsoluteSize
			if point.X >= from.X and point.X <= to.X and point.Y >= from.Y and point.Y <= to.Y then
				return id
			end
		end
	end
	return nil
end

return WindowStack
