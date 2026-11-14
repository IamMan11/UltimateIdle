--!strict
-- Builds the plain lobby + 6 lanes in Workspace at boot (code-built, not mapped by Rojo) and reserves one lane per player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Config.World)

local GREY = Color3.fromRGB(150, 150, 150)
local DARK = Color3.fromRGB(105, 105, 105)

local owners: { [number]: Player? } = {}
local signs: { [number]: TextLabel? } = {}

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function build()
	local old = workspace:FindFirstChild(World.FolderName)
	if old ~= nil then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = World.FolderName

	part("Lobby", World.LobbySize, CFrame.new(0, World.FloorY - World.LobbySize.Y / 2, 0), GREY, folder)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, World.FloorY + 0.5, 0)
	spawn.Color = DARK
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Parent = folder

	for i, origin in World.LaneOrigins do
		local lane = Instance.new("Model")
		lane.Name = `Lane{i}`
		local floor =
			part("Floor", World.LaneSize, origin * CFrame.new(0, World.FloorY - World.LaneSize.Y / 2, 0), DARK, lane)
		-- Walkway joining the lane to the lobby edge.
		local towardLobby = if origin.Position.Z < 0 then 1 else -1
		part(
			"Walkway",
			Vector3.new(6, World.LaneSize.Y, 8),
			origin * CFrame.new(0, World.FloorY - World.LaneSize.Y / 2, towardLobby * (World.LaneSize.Z / 2 + 3)),
			GREY,
			lane
		)
		local sign = part(
			"Sign",
			Vector3.new(14, 3, 0.4),
			origin * CFrame.new(World.HeroOffsetX - 10, World.FloorY + 4, 0) * CFrame.Angles(0, math.rad(90), 0),
			GREY,
			lane
		)
		sign.CanCollide = false
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = sign
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = `Lane {i}`
		label.Parent = gui
		signs[i] = label
		lane.PrimaryPart = floor
		lane.Parent = folder
	end

	folder.Parent = workspace
end

local function reserve(player: Player)
	for i = 1, World.LaneCount do
		if owners[i] == nil then
			owners[i] = player
			player:SetAttribute("Lane", i)
			local sign = signs[i]
			if sign ~= nil then
				sign.Text = player.DisplayName
			end
			return
		end
	end
	warn(`[World] no free lane for {player.Name}`)
end

local function release(player: Player)
	for i, owner in owners do
		if owner == player then
			owners[i] = nil
			local sign = signs[i]
			if sign ~= nil then
				sign.Text = `Lane {i}`
			end
		end
	end
end

local WorldSystem = {}

function WorldSystem.LaneOf(player: Player): number?
	for i, owner in owners do
		if owner == player then
			return i
		end
	end
	return nil
end

function WorldSystem.Start()
	build()
	for _, player in Players:GetPlayers() do
		reserve(player)
	end
	Players.PlayerAdded:Connect(reserve)
	Players.PlayerRemoving:Connect(release)
end

return WorldSystem
