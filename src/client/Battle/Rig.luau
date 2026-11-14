--!strict
-- Plain colourless R6-shaped unit models (anchored, no physics) with an HP bar, pooled per kind so playback never clones per hit.

local Workspace = game:GetService("Workspace")

export type Unit = {
	Model: Model,
	Root: BasePart,
	Bar: Frame,
	Cast: BillboardGui, -- skill name shown above the unit for a moment
	CastLabel: TextLabel,
	CastToken: number,
	Kind: string,
	Scale: number,
}

local CAST_SECONDS = 1.2

local HERO_COLOR = Color3.fromRGB(205, 205, 205)
local MONSTER_COLOR = Color3.fromRGB(95, 95, 95)
local BOSS_COLOR = Color3.fromRGB(60, 60, 60)

-- Class marker so heroes are told apart without colour.
local MARKERS: { [string]: { Size: Vector3, Offset: CFrame } } = {
	Warrior = { Size = Vector3.new(0.3, 1.8, 1.4), Offset = CFrame.new(0, 0, -1.4) * CFrame.Angles(0, math.rad(90), 0) },
	Mage = { Size = Vector3.new(0.9, 1.4, 0.9), Offset = CFrame.new(0, 2.2, 0) },
	Archer = { Size = Vector3.new(0.2, 2.6, 0.2), Offset = CFrame.new(0.9, 0, 0.6) },
	Healer = { Size = Vector3.new(1.4, 0.15, 1.4), Offset = CFrame.new(0, 2.3, 0) },
}

local folder: Folder? = nil
local pools: { [string]: { Unit } } = {}

local function container(): Folder
	if folder == nil or folder.Parent == nil then
		local f = Instance.new("Folder")
		f.Name = "ClientBattle"
		f.Parent = Workspace
		folder = f
	end
	return folder :: Folder
end

local function block(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- Root = torso centre; parts are placed relative to it once and move together via PivotTo.
local function build(kind: string, color: Color3, marker: string?, scale: number): Unit
	local model = Instance.new("Model")
	model.Name = kind
	local root = block("Torso", Vector3.new(2, 2, 1), color, model)
	root.CFrame = CFrame.new()
	block("Head", Vector3.new(1.2, 1.2, 1.2), color, model).CFrame = CFrame.new(0, 1.6, 0)
	block("LeftArm", Vector3.new(1, 2, 1), color, model).CFrame = CFrame.new(0, 0, -1.5)
	block("RightArm", Vector3.new(1, 2, 1), color, model).CFrame = CFrame.new(0, 0, 1.5)
	block("LeftLeg", Vector3.new(1, 2, 1), color, model).CFrame = CFrame.new(0, -2, -0.5)
	block("RightLeg", Vector3.new(1, 2, 1), color, model).CFrame = CFrame.new(0, -2, 0.5)
	if marker ~= nil then
		local m = MARKERS[marker]
		if m ~= nil then
			block("Marker", m.Size, Color3.fromRGB(240, 240, 240), model).CFrame = m.Offset
		end
	end
	model.PrimaryPart = root
	if scale ~= 1 then
		model:ScaleTo(scale)
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Hp"
	gui.Size = UDim2.fromScale(3.5, 0.35)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3 * scale, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = root
	gui.Parent = root
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	back.BorderSizePixel = 0
	back.Parent = gui
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
	bar.BorderSizePixel = 0
	bar.Parent = back

	local cast = Instance.new("BillboardGui")
	cast.Name = "Cast"
	cast.Size = UDim2.fromOffset(160, 26)
	cast.StudsOffsetWorldSpace = Vector3.new(0, 4.2 * scale, 0)
	cast.AlwaysOnTop = true
	cast.LightInfluence = 0
	cast.Enabled = false
	cast.Adornee = root
	cast.Parent = root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextStrokeTransparency = 0.3
	label.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
	label.TextSize = 18
	label.Parent = cast

	return {
		Model = model,
		Root = root,
		Bar = bar,
		Cast = cast,
		CastLabel = label,
		CastToken = 0,
		Kind = kind,
		Scale = scale,
	}
end

local Rig = {}

function Rig.HeroColor(): Color3
	return HERO_COLOR
end

function Rig.Acquire(kind: string, isHero: boolean, boss: boolean, marker: string?, scale: number): Unit
	local pool = pools[kind]
	local unit: Unit
	if pool ~= nil and #pool > 0 then
		unit = table.remove(pool) :: Unit
	else
		local color = if isHero then HERO_COLOR elseif boss then BOSS_COLOR else MONSTER_COLOR
		unit = build(kind, color, marker, scale)
	end
	unit.Bar.Size = UDim2.fromScale(1, 1)
	unit.CastToken += 1
	unit.Cast.Enabled = false
	for _, d in unit.Model:GetChildren() do
		if d:IsA("BasePart") then
			d.Transparency = 0
		end
	end
	unit.Model.Parent = container()
	return unit
end

function Rig.Release(unit: Unit)
	unit.Model.Parent = nil
	local pool = pools[unit.Kind]
	if pool == nil then
		pool = {}
		pools[unit.Kind] = pool
	end
	if #pool < 16 then
		table.insert(pool, unit)
	else
		unit.Model:Destroy()
	end
end

-- Shows `text` above the unit for a moment (a newer flash replaces an older one).
function Rig.Flash(unit: Unit, text: string)
	unit.CastToken += 1
	local token = unit.CastToken
	unit.CastLabel.Text = text
	unit.Cast.Enabled = true
	task.delay(CAST_SECONDS, function()
		if unit.CastToken == token then
			unit.Cast.Enabled = false
		end
	end)
end

function Rig.SetFaded(unit: Unit, faded: boolean)
	for _, d in unit.Model:GetChildren() do
		if d:IsA("BasePart") then
			d.Transparency = if faded then 0.7 else 0
		end
	end
end

return Rig
