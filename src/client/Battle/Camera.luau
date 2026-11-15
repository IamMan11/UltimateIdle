--!strict
-- Camera modes: Lane (scriptable view of the own or watched stage, 2D = long lens side view, 3D = angled; avatar frozen) and Walk (default Roblox camera, stage hidden).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Config.World)
local State = require(script.Parent.Parent.State)
local Rig = require(script.Parent.Rig)
local Scenery = require(script.Parent.Scenery)

local player = Players.LocalPlayer

local applied = ""

-- 2D: long lens tilted down this much, so the path and the rows of units show depth.
local PITCH_2D = math.rad(12)
local DISTANCE_2D = 230

type Movement = { Humanoid: Humanoid, WalkSpeed: number, JumpPower: number, JumpHeight: number, AutoRotate: boolean }

local held: Movement? = nil

-- Freezes the avatar while a stage is on screen: no walking, jumping or turning from any input device.
-- Done on the Humanoid (not the control scripts) so it holds whatever control module the place runs.
local function setFrozen(freeze: boolean)
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local was = held
	if was ~= nil and (not freeze or was.Humanoid ~= humanoid) then
		held = nil
		if was.Humanoid.Parent ~= nil then
			was.Humanoid.WalkSpeed = was.WalkSpeed
			was.Humanoid.JumpPower = was.JumpPower
			was.Humanoid.JumpHeight = was.JumpHeight
			was.Humanoid.AutoRotate = was.AutoRotate
		end
	end
	if freeze and humanoid ~= nil and held == nil then
		held = {
			Humanoid = humanoid,
			WalkSpeed = humanoid.WalkSpeed,
			JumpPower = humanoid.JumpPower,
			JumpHeight = humanoid.JumpHeight,
			AutoRotate = humanoid.AutoRotate,
		}
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.AutoRotate = false
	end
end

local function apply()
	local camera = Workspace.CurrentCamera
	local target = if State.Ui.Watch ~= nil then Players:GetPlayerByUserId(State.Ui.Watch) else player
	local lane = if target ~= nil then target:GetAttribute("Lane") else nil
	local mode, view = State.Ui.CameraMode, State.Ui.View
	local key = `{mode}/{view}/{lane}`
	if camera == nil or key == applied then
		return
	end
	-- Thumbstick/jump only while walking; the lane view has nothing to steer.
	GuiService.TouchControlsEnabled = mode == "Walk"
	local origin: CFrame? = if type(lane) == "number" then World.LaneOrigins[lane] else nil
	local onStage = mode == "Lane" and origin ~= nil
	applied = key
	setFrozen(onStage)
	Rig.SetVisible(onStage)
	Scenery.Show(if onStage then origin else nil)
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
	local center = (origin * CFrame.new(World.StageCenterX, World.FloorY + 3, 0)).Position
	camera.CameraType = Enum.CameraType.Scriptable
	if view == "2D" then
		local focus = center + Vector3.new(0, 5, 0)
		camera.FieldOfView = 14
		camera.CFrame =
			CFrame.lookAt(focus + Vector3.new(0, math.sin(PITCH_2D), math.cos(PITCH_2D)) * DISTANCE_2D, focus)
	else
		camera.FieldOfView = 50
		camera.CFrame = CFrame.lookAt(center + Vector3.new(-26, 26, 52), center)
	end
end

local Camera = {}

function Camera.Start()
	-- The Humanoid can arrive after the character; re-apply once it exists so the freeze lands on it.
	local function onCharacter(character: Model)
		character:WaitForChild("Humanoid")
		applied = ""
		apply()
	end
	State.Subscribe(apply)
	player:GetAttributeChangedSignal("Lane"):Connect(apply)
	Players.PlayerRemoving:Connect(function()
		task.defer(apply)
	end)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character ~= nil then
		task.spawn(onCharacter, player.Character)
	end
	apply()
end

return Camera
