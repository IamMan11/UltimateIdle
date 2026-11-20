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
	OnDark = Color3.fromRGB(252, 242, 216),
	Gold = Color3.fromRGB(250, 210, 110),
	OnDarkSub = Color3.fromRGB(222, 198, 150),
	OnDarkIdle = Color3.fromRGB(168, 152, 124), -- idle tab / disabled button text on leather
	-- Paper: Panel = sheet, PanelAlt = card on a sheet, Bg = well (inputs, lists, viewports), Hover = selected card
	Bg = Color3.fromRGB(214, 198, 164),
	Panel = Color3.fromRGB(240, 230, 208),
	PanelAlt = Color3.fromRGB(229, 214, 181),
	Hover = Color3.fromRGB(248, 238, 212),
	Stroke = Color3.fromRGB(110, 84, 54),
	Text = Color3.fromRGB(32, 20, 10),
	Subtext = Color3.fromRGB(96, 60, 26),
	Accent = Color3.fromRGB(196, 128, 18),
	-- Button faces (flat fallbacks; buttons draw paper / gilt art)
	Button = Color3.fromRGB(236, 222, 190),
	Confirm = Color3.fromRGB(122, 150, 74),
	Danger = Color3.fromRGB(168, 52, 44),
	Disabled = Color3.fromRGB(214, 204, 182),
	OnLight = Color3.fromRGB(32, 20, 10),
	Backdrop = Color3.fromRGB(14, 10, 6),
	Bar = Color3.fromRGB(214, 170, 84),
	BarBack = Color3.fromRGB(40, 30, 22),
	-- Multiplied over frame art: plain, and the red wash on danger buttons
	ArtTint = Color3.fromRGB(255, 255, 255),
	DangerTint = Color3.fromRGB(240, 168, 156),
	-- Multiplied into the gilt button plate: confirm = green leather, idle tab = dimmer, disabled = grey.
	ConfirmTint = Color3.fromRGB(176, 230, 150),
	IdleTint = Color3.fromRGB(170, 162, 150),
	DisabledTint = Color3.fromRGB(120, 116, 110),
	-- Stats and tiers: a strong colour with a little black in it (Color) for paper; Light = the same hue for dark plates.
	Stat = {
		Hp = { Color = Color3.fromRGB(200, 30, 30), Light = Color3.fromRGB(255, 160, 150) },
		Atk = { Color = Color3.fromRGB(214, 96, 0), Light = Color3.fromRGB(255, 200, 120) },
		Def = { Color = Color3.fromRGB(22, 92, 206), Light = Color3.fromRGB(150, 196, 255) },
		Speed = { Color = Color3.fromRGB(0, 140, 104), Light = Color3.fromRGB(130, 240, 204) },
		Skill = { Color = Color3.fromRGB(132, 44, 206), Light = Color3.fromRGB(214, 168, 255) },
		Heal = { Color = Color3.fromRGB(32, 150, 40), Light = Color3.fromRGB(166, 244, 150) },
		Cooldown = { Color = Color3.fromRGB(0, 120, 170), Light = Color3.fromRGB(140, 216, 246) },
		Range = { Color = Color3.fromRGB(150, 112, 0), Light = Color3.fromRGB(250, 222, 130) },
		Gold = { Color = Color3.fromRGB(196, 136, 0), Light = Color3.fromRGB(255, 226, 110) },
		Xp = { Color = Color3.fromRGB(96, 56, 212), Light = Color3.fromRGB(196, 176, 255) },
		Gs = { Color = Color3.fromRGB(176, 76, 10), Light = Color3.fromRGB(255, 196, 140) },
	},
	Tier = {
		Common = { Color = Color3.fromRGB(78, 82, 92), Light = Color3.fromRGB(206, 212, 222) },
		Uncommon = { Color = Color3.fromRGB(22, 150, 44), Light = Color3.fromRGB(150, 246, 150) },
		Rare = { Color = Color3.fromRGB(16, 104, 230), Light = Color3.fromRGB(130, 196, 255) },
	},
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

export type Accent = { Color: Color3, Light: Color3 }

-- Colour pair for a tier id (Common / Uncommon / Rare); nil for anything without one.
function Theme.TierAccent(tier: string?): Accent?
	if tier == nil then
		return nil
	end
	return (Theme.Tier :: { [string]: Accent })[tier]
end

-- Michroma has one weight: bold text is thickened with a stroke in its own colour this wide (by drawn size).
function Theme.Heavy(size: number): number
	return math.clamp(size * 0.055, 0.5, 1.1)
end

-- True for text colours that read as light (text on dark plates).
function Theme.IsLight(color: Color3): boolean
	return color.R * 0.299 + color.G * 0.587 + color.B * 0.114 > 0.55
end

return table.freeze(Theme)
