--!strict
-- Builds the plain lobby in Workspace at boot (code-built, not mapped by Rojo) and reserves one lane slot per player (stages are drawn client-side, far from the lobby).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Config.World)

local GREY = Color3.fromRGB(150, 150, 150)
local DARK = Color3.fromRGB(105, 105, 105)

local owners: { [number]: Player? } = {}

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

	folder.Parent = workspace
end

local function reserve(player: Player)
	for i = 1, World.LaneCount do
		if owners[i] == nil then
			owners[i] = player
			player:SetAttribute("Lane", i)
			return
		end
	end
	warn(`[World] no free lane for {player.Name}`)
end

local function release(player: Player)
	for i, owner in owners do
		if owner == player then
			owners[i] = nil
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
