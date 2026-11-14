--!strict
-- Plays the server's level timeline in the player's own lane: spawns pooled rigs, moves monsters, shows hits/HP/deaths, reports wave to State.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.Types)
local Timeline = require(ReplicatedStorage.Shared.Timeline)
local World = require(ReplicatedStorage.Shared.Config.World)
local Formation = require(ReplicatedStorage.Shared.Config.Formation)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Skills = require(ReplicatedStorage.Shared.Config.Skills)
local Text = require(ReplicatedStorage.Shared.Text)
local State = require(script.Parent.State)
local Rig = require(script.Rig)
local Camera = require(script.Camera)

type Live = {
	Unit: Rig.Unit,
	IsHero: boolean,
	X: number,
	Z: number,
	Moving: boolean,
	MoveFrom: number,
	MoveT: number,
	Speed: number,
	MaxHp: number,
	LungeUntil: number,
	Dead: boolean,
}

local Code = Timeline.Code
local LUNGE_TIME = 0.15
local FACE_HERO = CFrame.Angles(0, 0, 0)
local FACE_MONSTER = CFrame.Angles(0, math.pi, 0)

local player = Players.LocalPlayer

local units: { [number]: Live } = {}
local current: Types.TimelinePayload? = nil
local pointer = 1
local connection: RBXScriptConnection? = nil
local generation = 0

local function clear()
	generation += 1
	for id, live in units do
		Rig.Release(live.Unit)
		units[id] = nil
	end
end

local function setBar(live: Live, hp: number)
	local ratio = if live.MaxHp > 0 then math.clamp(hp / live.MaxHp, 0, 1) else 0
	live.Unit.Bar.Size = UDim2.fromScale(ratio, 1)
end

local function handle(event: Timeline.Event, payload: Types.TimelinePayload, now: number)
	local code = event.Code
	if code == Code.Spawn then
		local def = Monsters.List[event.B]
		if def == nil then
			return
		end
		local unit = Rig.Acquire(`M_{def.Id}`, false, def.Boss, nil, def.Scale)
		units[event.A] = {
			Unit = unit,
			IsHero = false,
			X = event.C,
			Z = ((event.A % 5) - 2) * 1.3,
			Moving = true,
			MoveFrom = event.C,
			MoveT = event.T,
			Speed = def.MoveSpeed,
			MaxHp = event.D,
			LungeUntil = 0,
			Dead = false,
		}
	elseif code == Code.Stop then
		local live = units[event.A]
		if live ~= nil then
			live.Moving = false
			live.X = event.C
		end
	elseif code == Code.Move then
		local live = units[event.A]
		if live ~= nil then
			live.Moving = true
			live.MoveFrom = live.X
			live.MoveT = event.T
		end
	elseif code == Code.Hit then
		local source = units[event.A]
		local target = units[event.B]
		if source ~= nil and now - event.T < 0.5 then
			source.LungeUntil = event.T + LUNGE_TIME
		end
		if target ~= nil then
			setBar(target, event.D)
		end
	elseif code == Code.Heal then
		local target = units[event.B]
		if target ~= nil then
			setBar(target, event.D)
		end
	elseif code == Code.Die then
		local live = units[event.A]
		if live ~= nil then
			live.Dead = true
			setBar(live, 0)
			Rig.SetFaded(live.Unit, true)
			if not live.IsHero then
				local gen = generation
				local id = event.A
				task.delay(0.4, function()
					if gen == generation and units[id] == live then
						Rig.Release(live.Unit)
						units[id] = nil
					end
				end)
			end
		end
	elseif code == Code.Revive then
		local live = units[event.A]
		if live ~= nil then
			live.Dead = false
			Rig.SetFaded(live.Unit, false)
			setBar(live, event.D)
		end
	elseif code == Code.Skill then
		local live = units[event.A]
		local def = Skills.List[event.B]
		if live ~= nil and def ~= nil and now - event.T < 1 then
			live.LungeUntil = event.T + LUNGE_TIME * 2
			Rig.Flash(live.Unit, Text.Skill(def.Id))
		end
	elseif code == Code.Wave then
		State.SetBattle(payload.Level, event.A, payload.Mode, payload.Skip == true)
	end
end

local function place(origin: CFrame, live: Live, now: number)
	local x = live.X
	if live.Moving then
		x = live.MoveFrom - live.Speed * (now - live.MoveT)
		live.X = x
	end
	local dir = if live.IsHero then 1 else -1
	if now < live.LungeUntil then
		x += dir * 0.8
	end
	local height = World.FloorY + 3 * live.Unit.Scale
	local bob = if live.Moving then math.abs(math.sin(now * 8)) * 0.3 else 0
	local cf = origin
		* CFrame.new(x + World.HeroOffsetX, height + bob, live.Z)
		* (if live.IsHero then FACE_HERO else FACE_MONSTER)
	if live.Dead and live.IsHero then
		cf *= CFrame.new(0, -2, 0) * CFrame.Angles(0, 0, math.rad(80))
	end
	live.Unit.Model:PivotTo(cf)
end

local function step()
	local payload = current
	local lane = player:GetAttribute("Lane")
	if payload == nil or type(lane) ~= "number" then
		return
	end
	local origin: CFrame? = World.LaneOrigins[lane]
	if origin == nil then
		return
	end
	local now = Workspace:GetServerTimeNow() - payload.StartAt
	while pointer <= payload.EventCount do
		local event = Timeline.Read(payload.Events, pointer)
		if event.T > now then
			break
		end
		handle(event, payload, now)
		pointer += 1
	end
	for _, live in units do
		place(origin, live, math.max(now, 0))
	end
end

local function play(payload: Types.TimelinePayload)
	if not Timeline.IsValid(payload.Events, payload.EventCount) then
		warn("[Battle] dropped malformed timeline")
		return
	end
	clear()
	current = payload
	pointer = 1
	State.SetBattle(payload.Level, 0, payload.Mode, payload.Skip == true)

	-- Heroes stand in their rows, spread across the lane width.
	local perRow: { [string]: number } = {}
	for _, hero in payload.Team do
		perRow[hero.Row] = (perRow[hero.Row] or 0) + 1
	end
	local seen: { [string]: number } = {}
	for i, hero in payload.Team do
		seen[hero.Row] = (seen[hero.Row] or 0) + 1
		local n = perRow[hero.Row]
		local unit = Rig.Acquire(`H_{hero.Class}`, true, false, hero.Class, 1)
		units[i] = {
			Unit = unit,
			IsHero = true,
			X = Formation.RowX[hero.Row] or 0,
			Z = (seen[hero.Row] - (n + 1) / 2) * Formation.LaneSpacing,
			Moving = false,
			MoveFrom = 0,
			MoveT = 0,
			Speed = 0,
			MaxHp = hero.MaxHp,
			LungeUntil = 0,
			Dead = false,
		}
	end
	if connection == nil then
		connection = RunService.RenderStepped:Connect(step)
	end
end

local Battle = {}

function Battle.Start()
	Camera.Start()
	State.OnTimeline(play)
	if State.Timeline ~= nil then
		play(State.Timeline)
	end
end

return Battle
