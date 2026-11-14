--!strict
-- UI palette (plain greys), fonts, z-index layers. Every UI colour comes from here.

return table.freeze({
	Bg = Color3.fromRGB(34, 34, 34),
	Panel = Color3.fromRGB(48, 48, 48),
	PanelAlt = Color3.fromRGB(62, 62, 62),
	Hover = Color3.fromRGB(80, 80, 80),
	Stroke = Color3.fromRGB(110, 110, 110),
	Text = Color3.fromRGB(236, 236, 236),
	Subtext = Color3.fromRGB(165, 165, 165),
	Accent = Color3.fromRGB(205, 205, 205),
	Confirm = Color3.fromRGB(222, 222, 222),
	OnLight = Color3.fromRGB(25, 25, 25),
	Danger = Color3.fromRGB(150, 62, 62),
	Backdrop = Color3.fromRGB(0, 0, 0),
	Bar = Color3.fromRGB(215, 215, 215),
	BarBack = Color3.fromRGB(28, 28, 28),
	Font = Font.fromEnum(Enum.Font.BuilderSans),
	FontBold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	-- Z layers (ScreenGui uses Sibling behaviour; set on the top frame of each layer only)
	ZHud = 1,
	ZPage = 3,
	ZModal = 6,
	ZToast = 10,
	ZDev = 20,
})
