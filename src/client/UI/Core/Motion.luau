--!strict
-- UI motion: tweened bindings, window / modal open + close (useShow / usePop scale the frame and fade a backdrop,
-- Layer + usePresence keep a closed entry mounted while it animates out) and button hover / press scale.
-- No CanvasGroup fades: a CanvasGroup draws its text without anti-aliasing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement

local Motion = {}

-- Seconds. Close is quicker than open (ui-modal skill §8).
Motion.OPEN = 0.2
Motion.CLOSE = 0.15
-- Scale a window or modal grows from / shrinks to.
Motion.FROM = 0.94
-- Button scale on hover / while held.
Motion.HOVER = 1.04
Motion.PRESS = 0.95
Motion.BUTTON = 0.1

-- True inside a Layer that is animating out.
Motion.Closing = React.createContext(false)

export type Go = (target: number, time: number, direction: Enum.EasingDirection?) -> ()

-- A number as a React binding (no re-render per frame) and a function that eases it to a target.
-- A new target cancels the running tween and starts from wherever the value is now.
function Motion.useTween(initial: number): (React.Binding<number>, Go)
	local binding, set = React.useBinding(initial)
	local value = React.useRef(initial)
	local run = React.useRef(0)
	React.useEffect(function()
		return function()
			run.current = (run.current :: number) + 1
		end
	end, {})
	local go = React.useCallback(function(target: number, time: number, direction: Enum.EasingDirection?)
		run.current = (run.current :: number) + 1
		local mine = run.current
		local from = value.current :: number
		local start = os.clock()
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			if run.current ~= mine then
				connection:Disconnect()
				return
			end
			local t = math.min((os.clock() - start) / time, 1)
			local eased = TweenService:GetValue(t, Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
			local now = from + (target - from) * eased
			value.current = now
			set(now)
			if t >= 1 then
				connection:Disconnect()
			end
		end)
	end, {})
	return binding, go
end

-- 0 = hidden .. 1 = shown for a window / modal: eases in when mounted, out while its Layer closes.
function Motion.useShow(): React.Binding<number>
	local closing = React.useContext(Motion.Closing)
	local shown, go = Motion.useTween(0)
	React.useEffect(function()
		if closing then
			go(0, Motion.CLOSE, Enum.EasingDirection.In)
		else
			go(1, Motion.OPEN, Enum.EasingDirection.Out)
		end
	end, { closing })
	return shown
end

-- Scale for a window / modal frame (from useShow, or its own). Feed it to a UIScale.
function Motion.usePop(shown: React.Binding<number>?): React.Binding<number>
	local own = Motion.useShow()
	return (shown or own):map(function(p: number): number
		return Motion.FROM + (1 - Motion.FROM) * p
	end)
end

-- Button face scale from its hover / pressed state.
function Motion.useButton(hovered: boolean, pressed: boolean): React.Binding<number>
	local scale, go = Motion.useTween(1)
	local target = if pressed then Motion.PRESS elseif hovered then Motion.HOVER else 1
	React.useEffect(function()
		go(target, if pressed then Motion.BUTTON * 0.6 else Motion.BUTTON)
	end, { target })
	return scale
end

export type LayerProps = {
	open: boolean,
	zIndex: number?,
	children: any,
}

-- Full-screen layer for one window or modal. Once `open` turns false it stops taking input and tells the frames
-- inside (useShow) to animate out; the parent drops it after Motion.CLOSE (usePresence).
function Motion.Layer(props: LayerProps): React.ReactNode
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Interactable = props.open,
		ZIndex = props.zIndex,
	}, {
		Closing = e(Motion.Closing.Provider, { value = not props.open }, props.children),
	})
end

export type Entry<T> = { Value: T, Open: boolean }

-- Keyed presence: every key in `current` is open; a key that just left stays (Open = false, last value) for
-- Motion.CLOSE so its Layer can animate out, then disappears. A key that comes back while leaving reopens in place.
function Motion.usePresence<T>(current: { [string]: T }): { [string]: Entry<T> }
	local last = React.useRef({} :: { [string]: T })
	local leaving = React.useRef({} :: { [string]: {} })
	local _, setTick = React.useState(0)
	local kept = last.current :: { [string]: T }
	local timers = leaving.current :: { [string]: {} }
	local out: { [string]: Entry<T> } = {}
	for key, value in current do
		kept[key] = value
		timers[key] = nil
		out[key] = { Value = value, Open = true }
	end
	for key, value in kept do
		if current[key] == nil then
			out[key] = { Value = value, Open = false }
			if timers[key] == nil then
				local token = {}
				timers[key] = token
				task.delay(Motion.CLOSE + 0.03, function()
					if timers[key] == token then
						kept[key] = nil
						timers[key] = nil
						setTick(function(n: number): number
							return n + 1
						end)
					end
				end)
			end
		end
	end
	return out
end

return Motion
