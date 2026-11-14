--!strict
-- Camera modes: Lane (scriptable side view of own or watched lane, 2D = long lens, 3D = angled) and Walk (default Roblox camera).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Config.World)
local State = require(script.Parent.Parent.State)

local player = Players.LocalPlayer

local applied = ""

local function apply()
	local camera = Workspace.CurrentCamera
	local target = if State.Ui.Watch ~= nil then Players:GetPlayerByUserId(State.Ui.Watch) else player
	local lane = if target ~= nil then target:GetAttribute("Lane") else nil
	local mode, view = State.Ui.CameraMode, State.Ui.View
	local key = `{mode}/{view}/{lane}`
	if camera == nil or key == applied then
		return
	end
	applied = key
	-- Thumbstick/jump only while walking; the lane view has nothing to steer.
	GuiService.TouchControlsEnabled = mode == "Walk"
	local origin: CFrame? = if type(lane) == "number" then World.LaneOrigins[lane] else nil
	if mode == "Walk" or origin == nil then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		local character = player.Character
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid ~= nil then
			camera.CameraSubject = humanoid
		end
		return
	end
	local center = (origin * CFrame.new(World.HeroOffsetX + 22, World.FloorY + 3, 0)).Position
	camera.CameraType = Enum.CameraType.Scriptable
	if view == "2D" then
		camera.FieldOfView = 14
		camera.CFrame = CFrame.lookAt(center + Vector3.new(0, 6, 230), center + Vector3.new(0, 1, 0))
	else
		camera.FieldOfView = 50
		camera.CFrame = CFrame.lookAt(center + Vector3.new(-26, 26, 52), center)
	end
end

local Camera = {}

function Camera.Start()
	State.Subscribe(apply)
	player:GetAttributeChangedSignal("Lane"):Connect(apply)
	Players.PlayerRemoving:Connect(function()
		task.defer(apply)
	end)
	player.CharacterAdded:Connect(function()
		applied = ""
		task.defer(apply)
	end)
	apply()
end

return Camera
