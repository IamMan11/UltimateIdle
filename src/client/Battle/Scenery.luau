--!strict
-- Stage scenery for the lane on screen: the imported stage kit (ReplicatedStorage.StageKits) or, without one, placeholder ground, path, backdrop, cut-out layers and props. Built once, moved to the viewed lane, out of Workspace while hidden. BuildGround = ground-only copy for UI previews.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Scenery)
local World = require(ReplicatedStorage.Shared.Config.World)

local Colors = Config.Colors
local PPS = Config.PixelsPerStud
local CENTER_X = World.StageCenterX
local FLOOR = World.FloorY

local model: Model? = nil

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Gui on the face that looks at the cameras (+Z); 1 stud = PPS pixels.
local function canvas(parent: BasePart): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.LightInfluence = 0
	gui.Parent = parent
	return gui
end

local function rect(parent: Instance, position: Vector2, size: Vector2, color: Color3): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(position.X, position.Y)
	f.Size = UDim2.fromOffset(size.X, size.Y)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function disc(parent: Instance, position: Vector2, diameter: number, color: Color3)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = rect(parent, position, Vector2.new(diameter, diameter), color)
end

-- Row of rolling hills (circle caps) rising from the ground line at `horizon` px.
local function hills(rng: Random, gui: Instance, horizon: number, minSize: number, maxSize: number, color: Color3)
	local x = -maxSize * PPS / 2
	local width = Config.Width * PPS
	while x < width + maxSize * PPS / 2 do
		local d = rng:NextNumber(minSize, maxSize) * PPS
		local rise = d * rng:NextNumber(0.16, 0.32)
		disc(gui, Vector2.new(x, horizon + d / 2 - rise), d, color)
		x += d * rng:NextNumber(0.35, 0.65)
	end
	-- Fills the strip under the ground line so no sky shows between caps.
	rect(gui, Vector2.new(width / 2, horizon + 40), Vector2.new(width, 80), color)
end

local function flatTrees(
	rng: Random,
	gui: Instance,
	horizon: number,
	minSize: number,
	maxSize: number,
	gap: number,
	color: Color3,
	trunk: Color3
)
	local x = rng:NextNumber(0, gap) * PPS
	local width = Config.Width * PPS
	while x < width do
		local h = rng:NextNumber(minSize, maxSize) * PPS
		rect(gui, Vector2.new(x, horizon - h * 0.25), Vector2.new(h * 0.09, h * 0.5), trunk)
		disc(gui, Vector2.new(x, horizon - h * 0.68), h * 0.62, color)
		disc(gui, Vector2.new(x + h * rng:NextNumber(-0.2, 0.2), horizon - h * 0.48), h * 0.5, color)
		x += gap * rng:NextNumber(0.6, 1.4) * PPS
	end
end

local function backdrop(rng: Random, parent: Instance)
	local cfg = Config.Backdrop
	local wall = part(
		"Backdrop",
		Vector3.new(Config.Width, cfg.Height, 1),
		CFrame.new(CENTER_X, FLOOR - cfg.Buried + cfg.Height / 2, cfg.Z),
		cfg.SkyBottom,
		parent
	)
	local gui = canvas(wall)
	local sky = Instance.new("Frame")
	sky.Size = UDim2.fromScale(1, 1)
	sky.BackgroundColor3 = Color3.new(1, 1, 1)
	sky.BorderSizePixel = 0
	sky.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, cfg.SkyTop),
		ColorSequenceKeypoint.new(0.75, cfg.SkyBottom),
		ColorSequenceKeypoint.new(1, cfg.SkyBottom),
	})
	gradient.Parent = sky
	if cfg.Image ~= "" then
		local image = Instance.new("ImageLabel")
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		image.Image = cfg.Image
		image.ScaleType = Enum.ScaleType.Tile
		image.TileSize = UDim2.new(0, cfg.Height * PPS * 2, 1, 0)
		image.Parent = gui
	else
		hills(rng, gui, (cfg.Height - cfg.Buried) * PPS, cfg.HillMin, cfg.HillMax, cfg.HillColor)
	end
end

local function cards(rng: Random, parent: Instance)
	local buried = 2
	for i, cfg in Config.Cards do
		local card = part(
			`Card{i}`,
			Vector3.new(Config.Width, cfg.Height, 0.2),
			CFrame.new(CENTER_X, FLOOR - buried + cfg.Height / 2, cfg.Z),
			cfg.HillColor,
			parent
		)
		card.Transparency = 1
		local gui = canvas(card)
		local horizon = (cfg.Height - buried) * PPS
		hills(rng, gui, horizon, cfg.HillMin, cfg.HillMax, cfg.HillColor)
		flatTrees(rng, gui, horizon, cfg.TreeMin, cfg.TreeMax, cfg.TreeGap, cfg.TreeColor, cfg.TrunkColor)
	end
end

local function ground(rng: Random, parent: Instance)
	local depth = Config.GroundFront - Config.GroundBack
	local midZ = (Config.GroundFront + Config.GroundBack) / 2
	part("Ground", Vector3.new(Config.Width, 4, depth), CFrame.new(CENTER_X, FLOOR - 2, midZ), Colors.Grass, parent)
	part(
		"Path",
		Vector3.new(Config.Width, 0.2, Config.PathWidth),
		CFrame.new(CENTER_X, FLOOR - 0.06, 0),
		Colors.Path,
		parent
	)
	for _, side in { -1, 1 } do
		part(
			"PathEdge",
			Vector3.new(Config.Width, 0.2, 1.2),
			CFrame.new(CENTER_X, FLOOR - 0.04, side * Config.PathWidth / 2),
			Colors.PathEdge,
			parent
		)
	end
	local half = Config.Width / 2
	for _ = 1, Config.PathPatches do
		part(
			"PathPatch",
			Vector3.new(rng:NextNumber(3, 8), 0.2, rng:NextNumber(0.8, 2)),
			CFrame.new(
				CENTER_X + rng:NextNumber(-half, half),
				FLOOR - 0.05,
				rng:NextNumber(-1, 1) * (Config.PathWidth / 2 - 2)
			),
			Colors.PathPatch,
			parent
		)
	end
end

local function tree(rng: Random, position: Vector3, height: number, parent: Instance)
	local trunkHeight = height * 0.5
	local width = height * 0.1
	local trunk = part(
		"Trunk",
		Vector3.new(trunkHeight, width, width),
		CFrame.new(position + Vector3.new(0, trunkHeight / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Colors.Trunk,
		parent
	)
	trunk.Shape = Enum.PartType.Cylinder
	trunk.CastShadow = true
	local color = Colors.Canopy[rng:NextInteger(1, #Colors.Canopy)]
	local size = height * 0.55
	for i = 1, 3 do
		local d = size * (if i == 1 then 1 else rng:NextNumber(0.6, 0.8))
		local offset = if i == 1
			then Vector3.new(0, trunkHeight + size * 0.3, 0)
			else Vector3.new(
				rng:NextNumber(-0.35, 0.35) * size,
				trunkHeight + size * rng:NextNumber(0, 0.25),
				rng:NextNumber(-0.3, 0.3) * size
			)
		local ball = part("Canopy", Vector3.new(d, d, d), CFrame.new(position + offset), color, parent)
		ball.Shape = Enum.PartType.Ball
		ball.CastShadow = true
	end
end

local function props(rng: Random, parent: Instance)
	local half = Config.Width / 2
	local function spot(zMin: number, zMax: number): Vector3
		return Vector3.new(CENTER_X + rng:NextNumber(-half, half), FLOOR, rng:NextNumber(zMin, zMax))
	end
	-- Either side of the path, never on it.
	local function beside(backZ: number, frontZ: number): Vector3
		if rng:NextNumber() < 0.5 then
			return spot(backZ, -Config.PathClear)
		end
		return spot(Config.PathClear, frontZ)
	end

	local trees = Config.Trees
	for _ = 1, trees.Count do
		tree(rng, spot(trees.ZMin, trees.ZMax), rng:NextNumber(trees.HeightMin, trees.HeightMax), parent)
	end
	local bushes = Config.Bushes
	for _ = 1, bushes.Count do
		local d = rng:NextNumber(bushes.SizeMin, bushes.SizeMax)
		local at = beside(bushes.BackZ, bushes.FrontZ)
		local bush =
			part("Bush", Vector3.new(d, d, d), CFrame.new(at + Vector3.new(0, d * 0.25, 0)), Colors.Bush, parent)
		bush.Shape = Enum.PartType.Ball
	end
	local rocks = Config.Rocks
	for _ = 1, rocks.Count do
		local d = rng:NextNumber(rocks.SizeMin, rocks.SizeMax)
		local at = beside(bushes.BackZ, bushes.FrontZ)
		part(
			"Rock",
			Vector3.new(d * 1.4, d, d * 1.1),
			CFrame.new(at + Vector3.new(0, d * 0.2, 0))
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
			Colors.Rock,
			parent
		)
	end
end

-- Kit pieces are modelled with the lane along X and the far side on +Z; the stage has its far side on -Z, so the kit is turned half a turn.
local function fromKit(rng: Random, kit: Instance, parent: Instance)
	local cfg = Config.Kit
	local toStage = CFrame.new(CENTER_X, FLOOR, 0) * CFrame.Angles(0, math.pi, 0)
	local depth = Config.GroundFront - Config.GroundBack
	-- Flat filler under the tiles so nothing shows through past their front edge.
	part(
		"GroundFill",
		Vector3.new(Config.Width, 1, depth),
		CFrame.new(CENTER_X, FLOOR - 1, (Config.GroundFront + Config.GroundBack) / 2),
		cfg.FillColor,
		parent
	)
	local function piece(name: string): MeshPart?
		local found = kit:FindFirstChild(cfg.Prefix .. name)
		return if found ~= nil and found:IsA("MeshPart") then found else nil
	end
	-- Terrain pieces keep the layout they were exported with.
	for _, name in cfg.Terrain do
		local src = piece(name)
		if src ~= nil then
			local c = src:Clone()
			c.CFrame = toStage * src.CFrame
			c.Parent = parent
		end
	end
	-- Props sit on the flat part of the ground: bottom of the bounding box on the floor (rocks sunk a little).
	local function drop(name: string, x: number, z: number, yaw: number, scale: number, sink: number)
		local src = piece(name)
		if src == nil then
			return
		end
		local c = src:Clone()
		c.Size = src.Size * scale
		c.CFrame = CFrame.new(CENTER_X + x, FLOOR + c.Size.Y / 2 - sink * scale, z) * CFrame.Angles(0, yaw, 0)
		c.Parent = parent
	end
	local grass = cfg.Grass
	for _ = 1, grass.Clusters do
		local cx = rng:NextNumber(-grass.HalfWidth, grass.HalfWidth)
		local cz = (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(grass.MinDepth, grass.MaxDepth)
		if rng:NextNumber() < grass.ThicketChance then
			local name = grass.Thickets[rng:NextInteger(1, #grass.Thickets)]
			drop(name, cx, cz, rng:NextNumber() * math.pi * 2, rng:NextNumber(grass.ScaleMin, grass.ScaleMax), 0)
		end
		for _ = 1, rng:NextInteger(grass.ClumpsMin, grass.ClumpsMax) do
			local x = cx + rng:NextNumber(-grass.Spread, grass.Spread)
			local z = cz + rng:NextNumber(-grass.Spread, grass.Spread)
			if math.abs(z) > Config.PathClear then
				local name = grass.Clumps[rng:NextInteger(1, #grass.Clumps)]
				drop(name, x, z, rng:NextNumber() * math.pi * 2, rng:NextNumber(grass.ScaleMin, grass.ScaleMax), 0)
			end
		end
	end
	for _, rock in cfg.Rocks do
		drop(rock.Piece, rock.X, rock.Z, rock.X * 1.9, rock.Scale, cfg.RockSink)
	end
end

-- Built in lane-origin space (origin = identity) so PivotTo(laneOrigin) drops it on any stage.
local function build(): Model
	local rng = Random.new(Config.Seed)
	local m = Instance.new("Model")
	m.Name = Config.FolderName
	local kits = ReplicatedStorage:FindFirstChild(Config.Kit.Folder)
	local kit = if kits ~= nil then kits:FindFirstChild(Config.Kit.Name) else nil
	if kit ~= nil then
		fromKit(rng, kit, m)
		m.WorldPivot = CFrame.new()
		return m
	end
	ground(rng, m)
	backdrop(rng, m)
	cards(rng, m)
	props(rng, m)
	m.WorldPivot = CFrame.new()
	return m
end

local Scenery = {}

-- Ground and path around the lane only (no props, no backdrop), in lane-origin space, parented to `parent`: for small previews such as a ViewportFrame.
function Scenery.BuildGround(parent: Instance, halfWidth: number)
	local kits = ReplicatedStorage:FindFirstChild(Config.Kit.Folder)
	local kit = if kits ~= nil then kits:FindFirstChild(Config.Kit.Name) else nil
	if kit == nil then
		ground(Random.new(Config.Seed), parent)
		return
	end
	local cfg = Config.Kit
	local toStage = CFrame.new(CENTER_X, FLOOR, 0) * CFrame.Angles(0, math.pi, 0)
	for _, name in cfg.Terrain do
		local src = kit:FindFirstChild(cfg.Prefix .. name)
		if src ~= nil and src:IsA("MeshPart") then
			local cframe = toStage * src.CFrame
			-- Only the tiles that reach the stretch being shown, and none of the far hills behind the lane.
			if math.abs(cframe.X - CENTER_X) - src.Size.X / 2 < halfWidth and math.abs(cframe.Z) < src.Size.Z / 2 then
				local c = src:Clone()
				c.CFrame = cframe
				c.Parent = parent
			end
		end
	end
end

-- Shows the scenery at `origin` (a lane origin); nil hides it.
function Scenery.Show(origin: CFrame?)
	if origin == nil then
		if model ~= nil then
			model.Parent = nil
		end
		return
	end
	local m = if model ~= nil then model else build()
	model = m
	m:PivotTo(origin)
	m.Parent = Workspace
end

return Scenery
