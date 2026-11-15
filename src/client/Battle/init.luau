--!strict
-- Draws battle stages: the player's own timeline plus one watched lane (spectating); click the stage to change the view angle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.Types)
local World = require(ReplicatedStorage.Shared.Config.World)
local State = require(script.Parent.State)
local Playback = require(script.Playback)
local Camera = require(script.Camera)

local player = Players.LocalPlayer

local CLICK_SECONDS = 0.4
local CLICK_PIXELS = 12

-- Monsters drawn at once: fewer on touch devices, the watched lane and with Low detail on.
local function maxMonsters(watched: boolean): number
	local mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local n = if mobile
		then (if watched then World.MaxMonstersWatchedMobile else World.MaxMonstersMobile)
		else (if watched then World.MaxMonstersWatched else World.MaxMonsters)
	local data = State.Data
	if data ~= nil and data.Settings.LowDetail then
		n = math.max(1, math.floor(n * World.LowDetailShare))
	end
	return n
end

local own = Playback.New(maxMonsters(false), function(payload: Types.TimelinePayload, wave: number)
	State.SetBattle(payload.Level, wave, payload.Mode, payload.Skip == true)
end)
local watched = Playback.New(maxMonsters(true), nil)
local watchedOwner = 0 -- userId whose payload `watched` is playing
local connection: RBXScriptConnection? = nil

local function laneOrigin(p: Player?): CFrame?
	if p == nil then
		return nil
	end
	local lane = p:GetAttribute("Lane")
	return if type(lane) == "number" then World.LaneOrigins[lane] else nil
end

local function step()
	local now = Workspace:GetServerTimeNow()
	local origin = laneOrigin(player)
	if origin ~= nil then
		Playback.Step(own, origin, now)
	end
	if watchedOwner ~= 0 then
		local watchedOrigin = laneOrigin(Players:GetPlayerByUserId(watchedOwner))
		if watchedOrigin ~= nil then
			Playback.Step(watched, watchedOrigin, now)
		end
	end
end

local function ensureLoop()
	if connection == nil then
		connection = RunService.RenderStepped:Connect(step)
	end
end

local function playOwn(payload: Types.TimelinePayload)
	if Playback.Play(own, payload) then
		State.SetBattle(payload.Level, 0, payload.Mode, payload.Skip == true)
		ensureLoop()
	end
end

local function playWatched(userId: number, payload: Types.TimelinePayload?)
	if userId ~= State.Ui.Watch then
		return
	end
	watchedOwner = userId
	if payload == nil then
		Playback.Clear(watched)
	elseif Playback.Play(watched, payload) then
		ensureLoop()
	end
end

-- Click/tap on the stage (not on UI) flips between the 2D and 3D view.
local function onClick()
	local ui = State.Ui
	if ui.CameraMode == "Lane" then
		State.SetCamera("Lane", if ui.View == "2D" then "3D" else "2D")
	end
end

local Battle = {}

function Battle.Start()
	Camera.Start()
	State.OnTimeline(playOwn)
	State.OnWatchTimeline(playWatched)
	State.Subscribe(function()
		local data = State.Data
		local flash = data == nil or not data.Settings.LowDetail
		Playback.SetDetail(own, maxMonsters(false), flash)
		Playback.SetDetail(watched, maxMonsters(true), flash)
		if State.Ui.Watch == nil and watchedOwner ~= 0 then
			watchedOwner = 0
			Playback.Clear(watched)
		end
	end)
	-- A click is a short press that barely moved (drags rotate the walk camera instead).
	local pressed: { [InputObject]: { At: number, Pos: Vector2 } } = {}
	UserInputService.InputBegan:Connect(function(input, processed)
		local t = input.UserInputType
		if not processed and (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) then
			pressed[input] = { At = os.clock(), Pos = Vector2.new(input.Position.X, input.Position.Y) }
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local press = pressed[input]
		if press == nil then
			return
		end
		pressed[input] = nil
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		if os.clock() - press.At < CLICK_SECONDS and (pos - press.Pos).Magnitude < CLICK_PIXELS then
			onClick()
		end
	end)
	if State.Timeline ~= nil then
		playOwn(State.Timeline)
	end
end

return Battle
