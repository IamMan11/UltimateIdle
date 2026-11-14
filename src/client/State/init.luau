--!strict
-- Client store: copy of server state (snapshot + deltas), current timeline, UI state (page/modal/toasts/camera), and event senders.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local Text = require(ReplicatedStorage.Shared.Text)
local Format = require(ReplicatedStorage.Shared.Format)

export type ConfirmPrompt = {
	Title: string,
	Body: string,
	OkText: string,
	Danger: boolean,
	OnConfirm: () -> (),
}

export type Toast = {
	Id: number,
	Text: string,
}

export type Ui = {
	Page: string?,
	Confirm: ConfirmPrompt?,
	Toasts: { Toast },
	CameraMode: "Lane" | "Walk",
	View: "2D" | "3D",
}

export type Battle = {
	Level: number,
	Wave: number,
	Mode: string,
	Skip: boolean,
}

local State = {
	Data = nil :: Types.ProfileData?,
	Timeline = nil :: Types.TimelinePayload?,
	Battle = { Level = 0, Wave = 0, Mode = "Progress", Skip = false } :: Battle,
	Ui = { Page = nil, Confirm = nil, Toasts = {}, CameraMode = "Lane", View = "2D" } :: Ui,
	Version = 0,
}

local listeners: { [number]: () -> () } = {}
local timelineListeners: { (Types.TimelinePayload) -> () } = {}
local nextListener = 0
local nextToast = 0
local notifyQueued = false

local function notify()
	if notifyQueued then
		return
	end
	notifyQueued = true
	task.defer(function()
		notifyQueued = false
		State.Version += 1
		for _, listener in listeners do
			task.spawn(listener)
		end
	end)
end

-- Fires (deferred, batched) after any change; returns an unsubscribe function.
function State.Subscribe(listener: () -> ()): () -> ()
	nextListener += 1
	local id = nextListener
	listeners[id] = listener
	return function()
		listeners[id] = nil
	end
end

function State.OnTimeline(listener: (Types.TimelinePayload) -> ())
	table.insert(timelineListeners, listener)
end

local function applyDelta(change: { any })
	local data = State.Data
	if data == nil then
		return
	end
	local path: { string } = change[1]
	local value = change[2]
	local node: any = data
	for i = 1, #path - 1 do
		local key = path[i]
		if node[key] == nil then
			node[key] = {}
		end
		node = node[key]
	end
	node[path[#path]] = value
end

-- UI state ---------------------------------------------------------------

function State.SetPage(page: string?)
	State.Ui.Page = if State.Ui.Page == page then nil else page
	notify()
end

function State.OpenConfirm(prompt: ConfirmPrompt)
	State.Ui.Confirm = prompt
	notify()
end

function State.CloseConfirm()
	State.Ui.Confirm = nil
	notify()
end

function State.SetCamera(mode: "Lane" | "Walk", view: "2D" | "3D")
	State.Ui.CameraMode = mode
	State.Ui.View = view
	notify()
end

function State.SetBattle(level: number, wave: number, mode: string, skip: boolean)
	local b = State.Battle
	if b.Level ~= level or b.Wave ~= wave or b.Mode ~= mode or b.Skip ~= skip then
		b.Level, b.Wave, b.Mode, b.Skip = level, wave, mode, skip
		notify()
	end
end

function State.PushToast(text: string)
	nextToast += 1
	local toast: Toast = { Id = nextToast, Text = text }
	local toasts = State.Ui.Toasts
	table.insert(toasts, toast)
	while #toasts > 3 do
		table.remove(toasts, 1)
	end
	notify()
	task.delay(4, function()
		local index = table.find(State.Ui.Toasts, toast)
		if index ~= nil then
			table.remove(State.Ui.Toasts, index)
			notify()
		end
	end)
end

-- Senders (intent only; the server decides) ---------------------------

State.Send = {
	ChooseFirstHero = function(class: string)
		Net.ChooseFirstHero:Client():Fire(class)
	end,
	BuyHero = function(class: string)
		Net.BuyHero:Client():Fire(class)
	end,
	SetStageMode = function(mode: string)
		Net.SetStageMode:Client():Fire(mode)
	end,
	SetSetting = function(key: string, sub: string?, value: boolean)
		Net.SetSetting:Client():Fire(key, sub, value)
	end,
	Equip = function(heroId: string, uid: string, slot: string)
		Net.Equip:Client():Fire(heroId, uid, slot)
	end,
	Unequip = function(heroId: string, slot: string)
		Net.Unequip:Client():Fire(heroId, slot)
	end,
	Salvage = function(uids: { string })
		Net.Salvage:Client():Fire(uids)
	end,
	OpenBox = function(boxId: string, count: number)
		Net.OpenBox:Client():Fire(boxId, count)
	end,
	ConvertBox = function(source: string, class: string, count: number)
		Net.ConvertBox:Client():Fire(source, class, count)
	end,
	SetTeam = function(entries: { { HeroId: string, Row: string } })
		Net.SetTeam:Client():Fire(entries)
	end,
	Advance = function(heroId: string)
		Net.Advance:Client():Fire(heroId)
	end,
	BuyNode = function(id: string)
		Net.BuyNode:Client():Fire(id)
	end,
	ToggleNode = function(id: string, on: boolean)
		Net.ToggleNode:Client():Fire(id, on)
	end,
	RequestRejoin = function()
		Net.RequestRejoin:Client():Fire()
	end,
	DevCommand = function(cmd: string, arg: number)
		Net.DevCommand:Client():Fire(cmd, arg)
	end,
}

-- Notices -> toasts --------------------------------------------------------

local function lootText(summary: any): string
	if type(summary) ~= "table" then
		return ""
	end
	local parts = {}
	if (summary.Gear or 0) > 0 then
		table.insert(parts, `{summary.Gear} gear`)
	end
	if (summary.Salvaged or 0) > 0 then
		table.insert(parts, `{summary.Salvaged} salvaged`)
	end
	return table.concat(parts, ", ")
end

local function onNotice(kind: string, payload: any)
	if kind == "Error" then
		State.PushToast(Text.Error[payload] or tostring(payload))
	elseif kind == "Offline" then
		State.PushToast(
			`{Text.UI.Offline} ({Format.Time(payload.Seconds)}): +{Format.Number(payload.Gold)} gold, +{Format.Number(
				payload.Xp
			)} xp`
		)
	elseif kind == "LevelEnd" then
		local head = if payload.Won then Text.UI.Won else Text.UI.Lost
		local loot = lootText(payload.Loot)
		State.PushToast(
			`{head} {payload.Level}: +{Format.Number(payload.Gold)} gold{if loot ~= "" then " · " .. loot else ""}`
		)
	elseif kind == "Salvaged" then
		State.PushToast(`Salvaged {payload.Count}: +{Format.Number(payload.Gold)} gold, +{payload.Stones} stones`)
	elseif kind == "BoxOpened" then
		State.PushToast(`Opened {payload.Opened} {Text.Box(payload.Box)}: {lootText(payload.Summary)}`)
	elseif kind == "NodeBought" then
		State.PushToast(`Unlocked {Text.Node(payload)}`)
	elseif kind == "Advanced" then
		State.PushToast(`{Text.Class(payload.Hero)} advanced to {Text.Advancement(payload.Hero, payload.Stage)}`)
	elseif kind == "TeamSet" then
		State.PushToast("Team saved: applies from the next level")
	elseif kind == "FarmLump" then
		State.PushToast(`Farm reward (levels 1-{payload.Levels}): {lootText(payload.Summary)}`)
	end
end

function State.Start()
	Net.StateSnapshot:Client():On(function(data: any)
		State.Data = data
		notify()
	end)
	Net.StateDelta:Client():On(function(changes: { { any } })
		for _, change in changes do
			applyDelta(change)
		end
		notify()
	end)
	Net.StageTimeline:Client():On(function(payload: Types.TimelinePayload)
		State.Timeline = payload
		for _, listener in timelineListeners do
			task.spawn(listener, payload)
		end
	end)
	Net.Notice:Client():On(onNotice)
	-- Listeners are in place: now ask for the snapshot (the server answers once the profile is loaded).
	Net.RequestSnapshot:Client():Fire()
end

return State
