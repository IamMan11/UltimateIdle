--!strict
-- Unit models (imported templates, or plain R6-shaped blocks when a kind has none) with an HP bar, pooled per kind so playback never clones per hit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MonsterAnims = require(ReplicatedStorage.Shared.Config.MonsterAnims)

-- One animated joint: a Motor6D (jointed models) or a Bone (skinned ones). A = the joint's rest rotation in model axes,
-- so a pose given in model axes becomes Transform = A:Inverse() * pose * A.
type Joint = { Motor: Motor6D?, Bone: Bone?, A: CFrame, Inv: CFrame, Poses: { [string]: { CFrame } } }
type Track = { Loop: boolean, Length: number, Hit: number, Times: { number } }
type Anim = { Joints: { Joint }, Tracks: { [string]: Track } }

export type Unit = {
	Model: Model,
	Root: BasePart,
	Bar: Frame,
	Cast: BillboardGui, -- skill name shown above the unit for a moment
	CastLabel: TextLabel,
	CastToken: number,
	Kind: string,
	Scale: number,
	-- Every visible part with its own transparency (templates have glass and hidden joint parts).
	Parts: { { Part: BasePart, Base: number } },
	Anim: Anim?,
}

local FADED = 0.7
-- Imported models: ReplicatedStorage.<folder>.<id>, looked up from the unit kind ("H_Warrior", "M_Goblin").
local TEMPLATE_FOLDERS: { [string]: string } = { H = "HeroModels", M = "MonsterModels" }

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

local visible = true

local function container(): Folder
	if folder ~= nil then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "ClientBattle"
	f.Parent = if visible then Workspace else nil
	folder = f
	return f
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

local function template(kind: string): Model?
	local prefix, id = string.match(kind, "^(%a)_(.+)$")
	local folderName = if prefix ~= nil then TEMPLATE_FOLDERS[prefix] else nil
	if folderName == nil or id == nil then
		return nil
	end
	local models = ReplicatedStorage:FindFirstChild(folderName)
	local found = if models ~= nil then models:FindFirstChild(id) else nil
	return if found ~= nil and found:IsA("Model") then found else nil
end

-- Clone of an imported model, re-pivoted to match the block rig: pivot 3 * scale above the feet, front along +X.
-- Templates are modelled facing -Z at their real size, so `scale` only sets the pivot height the playback expects.
local function fromTemplate(source: Model, kind: string, scale: number): (Model, BasePart, number)
	local model = source:Clone()
	model.Name = kind
	local found = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	local root = assert(found, "template has no parts")
	model.PrimaryPart = root
	-- Bounds of what is drawn (templates are stored unrotated; hidden joint parts would move the feet).
	local low, high = Vector3.one * math.huge, Vector3.one * -math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			if d.Transparency < 1 then
				low = low:Min(d.Position - d.Size / 2)
				high = high:Max(d.Position + d.Size / 2)
			end
		end
	end
	local feet = Vector3.new((low.X + high.X) / 2, low.Y, (low.Z + high.Z) / 2)
	local pivot = CFrame.new(feet + Vector3.new(0, 3 * scale, 0)) * CFrame.Angles(0, math.rad(90), 0)
	root.PivotOffset = root.CFrame:ToObjectSpace(pivot)
	return model, root, high.Y - low.Y - 3 * scale
end

-- Joints of `model` that the clips of `id` move, with every key turned into a CFrame once.
local function animFor(id: string, model: Model): Anim?
	local char = MonsterAnims[id]
	if char == nil then
		return nil
	end
	local tracks: { [string]: Track } = {}
	for name, clip in char.clips do
		local times = table.create(#clip.keys, 0)
		for i, key in clip.keys do
			times[i] = key.t
		end
		tracks[name] = { Loop = clip.loop, Length = times[#times], Hit = clip.hit or 0, Times = times }
	end
	local joints: { Joint } = {}
	local function add(name: string, motor: Motor6D?, bone: Bone?, rest: CFrame)
		local poses: { [string]: { CFrame } } = {}
		local used = false
		for clipName, clip in char.clips do
			local list = table.create(#clip.keys, CFrame.identity)
			for i, key in clip.keys do
				local v = key.j[name]
				if v ~= nil then
					used = true
					list[i] = CFrame.new(v[1], v[2], v[3], v[4], v[5], v[6], v[7])
				end
			end
			poses[clipName] = list
		end
		if used then
			table.insert(joints, { Motor = motor, Bone = bone, A = rest, Inv = rest:Inverse(), Poses = poses })
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part1 ~= nil then
			add(d.Part1.Name, d, nil, d.C0.Rotation)
		elseif d:IsA("Bone") then
			add(d.Name, nil, d, d.WorldCFrame.Rotation)
		end
	end
	return if #joints > 0 then { Joints = joints, Tracks = tracks } else nil
end

local function blocks(kind: string, color: Color3, marker: string?, scale: number): (Model, BasePart)
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
	return model, root
end

-- Root = pivot part; the whole model moves together via PivotTo.
local function build(kind: string, color: Color3, marker: string?, scale: number): Unit
	local source = template(kind)
	local model: Model, root: BasePart
	local barY, castY = 3 * scale, 4.2 * scale
	local anim: Anim? = nil
	if source ~= nil then
		local top: number
		model, root, top = fromTemplate(source, kind, scale)
		barY, castY = top + 0.8, top + 2
		anim = animFor(source.Name, model)
		if anim ~= nil then
			-- Motor6D joints only move parts that are not anchored; the anchored root carries the rest.
			for _, joint in anim.Joints do
				local motor = joint.Motor
				if motor ~= nil and motor.Part1 ~= nil and motor.Part1 ~= root then
					for _, d in model:GetDescendants() do
						if d:IsA("BasePart") and d ~= root then
							d.Anchored = false
						end
					end
					break
				end
			end
		end
	else
		model, root = blocks(kind, color, marker, scale)
	end
	local parts: { { Part: BasePart, Base: number } } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, { Part = d, Base = d.Transparency })
		end
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Hp"
	gui.Size = UDim2.fromScale(3.5, 0.35)
	gui.StudsOffsetWorldSpace = Vector3.new(0, barY, 0)
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
	cast.StudsOffsetWorldSpace = Vector3.new(0, castY, 0)
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
		Parts = parts,
		Anim = anim,
	}
end

local Rig = {}

function Rig.HeroColor(): Color3
	return HERO_COLOR
end

-- Units keep playing while hidden (walk view); they are only taken out of Workspace.
function Rig.SetVisible(show: boolean)
	visible = show
	if folder ~= nil then
		folder.Parent = if show then Workspace else nil
	end
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
	for _, entry in unit.Parts do
		entry.Part.Transparency = entry.Base
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

function Rig.IsAnimated(unit: Unit): boolean
	return unit.Anim ~= nil
end

-- Seconds a clip lasts for this unit (0 = it has no such clip).
function Rig.ClipLength(unit: Unit, clip: string): number
	local anim = unit.Anim
	local track = if anim ~= nil then anim.Tracks[clip] else nil
	return if track ~= nil then track.Length else 0
end

-- Seconds into the clip at which its blow lands (0 when the clip has none).
function Rig.HitTime(unit: Unit, clip: string): number
	local anim = unit.Anim
	local track = if anim ~= nil then anim.Tracks[clip] else nil
	return if track ~= nil then track.Hit else 0
end

-- Poses the unit at `t` seconds into `clip` (looping clips wrap, others hold their last key). Does nothing for units without clips.
function Rig.Animate(unit: Unit, clip: string, t: number)
	local anim = unit.Anim
	if anim == nil then
		return
	end
	local name = if anim.Tracks[clip] ~= nil then clip else "Idle"
	local track = anim.Tracks[name]
	if track == nil or track.Length <= 0 then
		return
	end
	local time = if track.Loop then t % track.Length else math.clamp(t, 0, track.Length)
	local times = track.Times
	local i = 1
	while i < #times - 1 and times[i + 1] <= time do
		i += 1
	end
	local span = times[i + 1] - times[i]
	local alpha = if span > 0 then math.clamp((time - times[i]) / span, 0, 1) else 0
	alpha = alpha * alpha * (3 - 2 * alpha)
	for _, joint in anim.Joints do
		local poses = joint.Poses[name]
		local transform = joint.Inv * poses[i]:Lerp(poses[i + 1], alpha) * joint.A
		local motor, bone = joint.Motor, joint.Bone
		if motor ~= nil then
			motor.Transform = transform
		elseif bone ~= nil then
			bone.Transform = transform
		end
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
	for _, entry in unit.Parts do
		entry.Part.Transparency = if faded then math.max(entry.Base, FADED) else entry.Base
	end
end

return Rig
