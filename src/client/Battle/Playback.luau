--!strict
-- One lane's timeline playback (own lane or a watched one): pooled rigs, movement, hits/HP/deaths, skill flashes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Timeline = require(ReplicatedStorage.Shared.Timeline)
local World = require(ReplicatedStorage.Shared.Config.World)
local Formation = require(ReplicatedStorage.Shared.Config.Formation)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Skills = require(ReplicatedStorage.Shared.Config.Skills)
local Text = require(ReplicatedStorage.Shared.Text)
local Rig = require(script.Parent.Rig)

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

export type Lane = {
	Units: { [number]: Live },
	Payload: Types.TimelinePayload?,
	Pointer: number,
	Generation: number,
	MaxMonsters: number, -- monsters drawn at once; extra spawns are simulated but not shown
	Shown: number,
	Flash: boolean, -- skill names over heads
	OnWave: ((payload: Types.TimelinePayload, wave: number) -> ())?,
}

local Code = Timeline.Code
local LUNGE_TIME = 0.15
local FACE_HERO = CFrame.Angles(0, 0, 0)
local FACE_MONSTER = CFrame.Angles(0, math.pi, 0)

local Playback = {}

function Playback.New(maxMonsters: number, onWave: ((Types.TimelinePayload, number) -> ())?): Lane
	return {
		Units = {},
		Payload = nil,
		Pointer = 1,
		Generation = 0,
		MaxMonsters = maxMonsters,
		Shown = 0,
		Flash = true,
		OnWave = onWave,
	}
end

local function release(lane: Lane, id: number, live: Live)
	Rig.Release(live.Unit)
	lane.Units[id] = nil
	if not live.IsHero then
		lane.Shown -= 1
	end
end

function Playback.Clear(lane: Lane)
	lane.Generation += 1
	for id, live in lane.Units do
		release(lane, id, live)
	end
	lane.Payload = nil
	lane.Shown = 0
end

function Playback.SetDetail(lane: Lane, maxMonsters: number, flash: boolean)
	lane.MaxMonsters = maxMonsters
	lane.Flash = flash
end

local function setBar(live: Live, hp: number)
	local ratio = if live.MaxHp > 0 then math.clamp(hp / live.MaxHp, 0, 1) else 0
	live.Unit.Bar.Size = UDim2.fromScale(ratio, 1)
end

local function handle(lane: Lane, event: Timeline.Event, payload: Types.TimelinePayload, now: number)
	local units = lane.Units
	local code = event.Code
	if code == Code.Spawn then
		local def = Monsters.List[event.B]
		if def == nil or lane.Shown >= lane.MaxMonsters then
			return
		end
		lane.Shown += 1
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
				local gen = lane.Generation
				local id = event.A
				task.delay(0.4, function()
					if gen == lane.Generation and units[id] == live then
						release(lane, id, live)
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
			if lane.Flash then
				Rig.Flash(live.Unit, Text.Skill(def.Id))
			end
		end
	elseif code == Code.Wave then
		if lane.OnWave ~= nil then
			lane.OnWave(payload, event.A)
		end
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

-- Advances to server time `serverNow` and places units at `origin` (the lane being drawn).
function Playback.Step(lane: Lane, origin: CFrame, serverNow: number)
	local payload = lane.Payload
	if payload == nil then
		return
	end
	local now = serverNow - payload.StartAt
	while lane.Pointer <= payload.EventCount do
		local event = Timeline.Read(payload.Events, lane.Pointer)
		if event.T > now then
			break
		end
		handle(lane, event, payload, now)
		lane.Pointer += 1
	end
	local t = math.max(now, 0)
	for _, live in lane.Units do
		place(origin, live, t)
	end
end

-- Starts a new level's playback; returns false for a malformed buffer.
function Playback.Play(lane: Lane, payload: Types.TimelinePayload): boolean
	if not Timeline.IsValid(payload.Events, payload.EventCount) then
		warn("[Battle] dropped malformed timeline")
		return false
	end
	Playback.Clear(lane)
	lane.Payload = payload
	lane.Pointer = 1

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
		lane.Units[i] = {
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
	return true
end

return Playback
