--!strict
-- UI palette (botanical paper sheets, black leather + antique gold headers, sepia ink), fonts, text sizes, z-index layers. Every UI colour comes from here.

local MICHROMA = "rbxasset://fonts/families/Michroma.json"
local GRENZE = "rbxasset://fonts/families/GrenzeGotisch.json"

-- Michroma runs ~1.2x wider than the BuilderSans sizes the layouts were written for; Grenze Gotisch ~0.65x.
local BODY_SCALE = 0.84
local BODY_MIN = 10
local TITLE_SCALE = 1.1

local Theme = {
	-- Leather header / dark plates, and the ink line around panels
	Wood = Color3.fromRGB(30, 24, 20),
	Outline = Color3.fromRGB(40, 28, 18),
	OnDark = Color3.fromRGB(243, 232, 208),
	Gold = Color3.fromRGB(232, 200, 126),
	OnDarkSub = Color3.fromRGB(196, 178, 142),
	-- Paper: Panel = sheet, PanelAlt = card on a sheet, Bg = well (inputs, lists, viewports), Hover = selected card
	Bg = Color3.fromRGB(214, 198, 164),
	Panel = Color3.fromRGB(240, 230, 208),
	PanelAlt = Color3.fromRGB(229, 214, 181),
	Hover = Color3.fromRGB(248, 238, 212),
	Stroke = Color3.fromRGB(110, 84, 54),
	Text = Color3.fromRGB(59, 40, 23),
	Subtext = Color3.fromRGB(104, 80, 54),
	Accent = Color3.fromRGB(176, 128, 44),
	-- Button faces (flat fallbacks; buttons draw paper / gilt art)
	Button = Color3.fromRGB(236, 222, 190),
	Confirm = Color3.fromRGB(122, 150, 74),
	Danger = Color3.fromRGB(168, 52, 44),
	Disabled = Color3.fromRGB(214, 204, 182),
	OnLight = Color3.fromRGB(59, 40, 23),
	Backdrop = Color3.fromRGB(14, 10, 6),
	Bar = Color3.fromRGB(214, 170, 84),
	BarBack = Color3.fromRGB(40, 30, 22),
	-- Multiplied over frame art: plain, and the red wash on danger buttons
	ArtTint = Color3.fromRGB(255, 255, 255),
	DangerTint = Color3.fromRGB(240, 168, 156),
	Font = Font.new(MICHROMA),
	FontBold = Font.new(MICHROMA),
	FontTitle = Font.new(GRENZE, Enum.FontWeight.Bold),
	-- Z layers (ScreenGui uses Sibling behaviour; set on the top frame of each layer only)
	ZHud = 1,
	ZPage = 3,
	ZModal = 6,
	ZTooltip = 8,
	ZToast = 10,
	ZDev = 20,
}

-- Body text size for a size written against the old font.
function Theme.Body(size: number): number
	return math.max(BODY_MIN, math.round(size * BODY_SCALE))
end

-- Heading text size (Grenze Gotisch) for a size written against the old font.
function Theme.Title(size: number): number
	return math.round(size * TITLE_SCALE)
end

return table.freeze(Theme)
