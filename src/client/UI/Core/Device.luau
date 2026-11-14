--!strict
-- Screen/input facts for layout: touch-first device, UI scale from viewport size (times the player's UI-size setting), compact HUD.

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Layout is authored for this viewport; the UI scales from it.
local DESIGN = Vector2.new(1280, 720)
local MIN_SCALE = 0.7
local MIN_SCALE_TOUCH = 0.8 -- keeps 40 px buttons >= 32 px on phones
local MAX_SCALE = 1.25
-- Below this scaled height the HUD switches to its compact layout.
local COMPACT_HEIGHT = 800
-- Below this scaled height (phones in landscape) the HUD drops the team panel so the page grid fits.
local TIGHT_HEIGHT = 560

local Device = {}

function Device.IsTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function Device.Viewport(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera ~= nil then camera.ViewportSize else DESIGN
end

-- `userScale` = Settings.UiScale (1 = auto size).
function Device.Scale(viewport: Vector2, userScale: number): number
	local fit = math.min(viewport.X / DESIGN.X, viewport.Y / DESIGN.Y)
	local low = if Device.IsTouch() then MIN_SCALE_TOUCH else MIN_SCALE
	return math.clamp(fit, low, MAX_SCALE) * userScale
end

-- True when the scaled screen is short (most screens below 1440p): HUD pages become a grid at the top-left.
function Device.Compact(viewport: Vector2, scale: number): boolean
	return viewport.Y / scale < COMPACT_HEIGHT
end

function Device.Tight(viewport: Vector2, scale: number): boolean
	return viewport.Y / scale < TIGHT_HEIGHT
end

return Device
