--!strict
-- UI palette (wood frame, parchment panels, dark outline), fonts, z-index layers. Every UI colour comes from here.

return table.freeze({
	-- Window frame and the ink line around panels and buttons
	Wood = Color3.fromRGB(150, 92, 48),
	Outline = Color3.fromRGB(52, 30, 16),
	OnDark = Color3.fromRGB(250, 238, 210),
	-- Parchment: Panel = sheet, PanelAlt = card on a sheet, Bg = well (inputs, lists, viewports), Hover = selected card
	Bg = Color3.fromRGB(212, 188, 146),
	Panel = Color3.fromRGB(240, 224, 190),
	PanelAlt = Color3.fromRGB(228, 207, 166),
	Hover = Color3.fromRGB(253, 244, 218),
	Stroke = Color3.fromRGB(96, 62, 36),
	Text = Color3.fromRGB(52, 30, 16),
	Subtext = Color3.fromRGB(105, 76, 48),
	Accent = Color3.fromRGB(196, 98, 28),
	-- Button faces
	Button = Color3.fromRGB(236, 200, 132),
	Confirm = Color3.fromRGB(156, 200, 96),
	Danger = Color3.fromRGB(196, 78, 58),
	Disabled = Color3.fromRGB(204, 188, 156),
	OnLight = Color3.fromRGB(52, 30, 16),
	Backdrop = Color3.fromRGB(0, 0, 0),
	Bar = Color3.fromRGB(232, 156, 44),
	BarBack = Color3.fromRGB(84, 54, 32),
	Font = Font.fromEnum(Enum.Font.BuilderSans),
	FontBold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	-- Z layers (ScreenGui uses Sibling behaviour; set on the top frame of each layer only)
	ZHud = 1,
	ZPage = 3,
	ZModal = 6,
	ZToast = 10,
	ZDev = 20,
})
