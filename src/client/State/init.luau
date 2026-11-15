--!strict
-- Client store: copy of server state (snapshot + deltas), current timeline, open trade + requests, pass ownership, UI state (page/modal/toasts/camera/watched lane), event senders.

local Players = game:GetService("Players")
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

export type ForgeResult = {
	Uid: string,
	Plus: number?,
	Ok: boolean?,
	Before: { Types.Enchant }?,
	After: { Types.Enchant }?,
}

export type Ui = {
	Page: string?,
	Tabs: { [string]: string }, -- page group id -> page last open in it
	ForgeUid: string?, -- item selected on the Forge page
	LastEnhance: ForgeResult?,
	LastEnchant: ForgeResult?,
	Confirm: ConfirmPrompt?,
	Toasts: { Toast },
	CameraMode: "Lane" | "Walk",
	View: "2D" | "3D",
	Watch: number?, -- userId of the lane being watched (nil = own lane)
}

export type TradeRequest = {
	UserId: number,
	Name: string,
	At: number, -- os.clock() when received
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
	Ui = {
		Page = nil,
		Tabs = {},
		ForgeUid = nil,
		LastEnhance = nil,
		LastEnchant = nil,
		Confirm = nil,
		Toasts = {},
		CameraMode = "Lane",
		View = "2D",
		Watch = nil,
	} :: Ui,
	Trade = nil :: Types.TradeView?,
	TradeRequests = {} :: { TradeRequest },
	Passes = {} :: { [string]: boolean }, -- effective pass ownership (account or gifted), from the server
	Version = 0,
}

-- Requests older than this are gone on the server too (Config.Trade.RequestSeconds).
local REQUEST_TTL = 30

local listeners: { [number]: () -> () } = {}
local timelineListeners: { (Types.TimelinePayload) -> () } = {}
local watchListeners: { (number, Types.TimelinePayload?) -> () } = {}
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

-- Timelines of the watched lane (payload nil = that lane has nothing to show).
function State.OnWatchTimeline(listener: (number, Types.TimelinePayload?) -> ())
	table.insert(watchListeners, listener)
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

function State.OpenForge(uid: string?)
	State.Ui.Page = "Forge"
	State.Ui.ForgeUid = uid
	notify()
end

function State.SelectForge(uid: string?)
	State.Ui.ForgeUid = uid
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

-- Watch another player's lane (nil = back to own lane); the camera follows the watched lane.
function State.SetWatch(userId: number?)
	if State.Ui.Watch == userId then
		return
	end
	State.Ui.Watch = userId
	Net.WatchLane:Client():Fire(if userId == nil then 0 else userId)
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

-- Pending trade requests that have not expired (oldest first).
function State.LiveRequests(): { TradeRequest }
	local live: { TradeRequest } = {}
	for _, r in State.TradeRequests do
		if os.clock() - r.At < REQUEST_TTL then
			table.insert(live, r)
		end
	end
	return live
end

function State.DropRequest(userId: number)
	for i, r in State.TradeRequests do
		if r.UserId == userId then
			table.remove(State.TradeRequests, i)
			break
		end
	end
	notify()
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
	SetSetting = function(key: string, sub: string?, value: boolean | number)
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
	Rebirth = function()
		Net.Rebirth:Client():Fire()
	end,
	SetPlayRebirth = function(index: number)
		Net.SetPlayRebirth:Client():Fire(index)
	end,
	Enhance = function(uid: string)
		Net.Enhance:Client():Fire(uid)
	end,
	MergeSocket = function(main: string, material: string)
		Net.MergeSocket:Client():Fire(main, material)
	end,
	UseSocketCore = function(uid: string)
		Net.UseSocketCore:Client():Fire(uid)
	end,
	SetSocketKind = function(uid: string, index: number, kind: string)
		Net.SetSocketKind:Client():Fire(uid, index, kind)
	end,
	InsertSocket = function(uid: string, index: number, id: string)
		Net.InsertSocket:Client():Fire(uid, index, id)
	end,
	RemoveInsert = function(uid: string, index: number)
		Net.RemoveInsert:Client():Fire(uid, index)
	end,
	Enchant = function(uid: string)
		Net.Enchant:Client():Fire(uid)
	end,
	TradeRequest = function(userId: number)
		Net.TradeRequest:Client():Fire(userId)
	end,
	TradeRespond = function(userId: number, accept: boolean)
		Net.TradeRespond:Client():Fire(userId, accept)
	end,
	TradeOffer = function(offer: Types.TradeOffer)
		Net.TradeOffer:Client():Fire(offer)
	end,
	TradeReady = function(on: boolean)
		Net.TradeReady:Client():Fire(on)
	end,
	TradeConfirm = function()
		Net.TradeConfirm:Client():Fire()
	end,
	TradeCancel = function()
		Net.TradeCancel:Client():Fire()
	end,
	ClaimQuest = function(id: string)
		Net.ClaimQuest:Client():Fire(id)
	end,
	ClaimPass = function(track: string, tier: number)
		Net.ClaimPass:Client():Fire(track, tier)
	end,
	BuyPass = function(key: string)
		Net.BuyPass:Client():Fire(key)
	end,
	GiftPass = function(key: string, userId: number)
		Net.GiftPass:Client():Fire(key, userId)
	end,
	BuyPremium = function()
		Net.BuyPremium:Client():Fire()
	end,
	BuyShopItem = function(id: string)
		Net.BuyShopItem:Client():Fire(id)
	end,
	RequestRejoin = function()
		Net.RequestRejoin:Client():Fire()
	end,
	TutorialSkip = function()
		Net.TutorialSkip:Client():Fire()
	end,
	TutorialRestart = function()
		Net.TutorialRestart:Client():Fire()
	end,
	ClaimDaily = function()
		Net.ClaimDaily:Client():Fire()
	end,
	RedeemCode = function(text: string)
		Net.RedeemCode:Client():Fire(text)
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
	elseif kind == "TutorialStep" then
		State.PushToast(if payload.Done then "Tutorial complete!" else "Tutorial step done")
	elseif kind == "DailyClaimed" then
		State.PushToast(`Daily reward claimed (day streak {payload.Streak})`)
	elseif kind == "CodeRedeemed" then
		State.PushToast(`Code redeemed: {Text.Eco.Reward(payload.Reward, payload.Gold)}`)
	elseif kind == "NodeBought" then
		State.PushToast(`Unlocked {Text.Node(payload)}`)
	elseif kind == "Advanced" then
		State.PushToast(`{Text.Class(payload.Hero)} advanced to {Text.Advancement(payload.Hero, payload.Stage)}`)
	elseif kind == "TeamSet" then
		State.PushToast("Team saved: applies from the next level")
	elseif kind == "Enhanced" then
		State.Ui.LastEnhance = { Uid = payload.Uid, Plus = payload.Plus, Ok = payload.Ok }
		State.PushToast(
			if payload.Ok then `Enhance success: +{payload.Plus + 1}` else `Enhance failed: stays +{payload.Plus}`
		)
	elseif kind == "Enchanted" then
		State.Ui.LastEnchant = { Uid = payload.Uid, Before = payload.Before, After = payload.After }
		State.PushToast("Enchanted: new traits rolled")
	elseif kind == "SocketAdded" then
		State.PushToast(`Socket opened ({payload.Count} total)`)
	elseif kind == "Rebirthed" then
		State.PushToast(`Rebirth {payload} reached! Caps raised.`)
	elseif kind == "PlayRebirth" then
		State.PushToast(`Playing rebirth {payload} from the next level`)
	elseif kind == "FarmLump" then
		State.PushToast(`Farm reward (levels 1-{payload.Levels}): {lootText(payload.Summary)}`)
	elseif kind == "TradeRequest" then
		State.DropRequest(payload.From)
		table.insert(State.TradeRequests, { UserId = payload.From, Name = payload.Name, At = os.clock() })
		State.PushToast(`{payload.Name} wants to trade (open Trade)`)
	elseif kind == "TradeRequested" then
		State.PushToast(`Trade request sent to {payload}`)
	elseif kind == "TradeDeclined" then
		State.PushToast(`{payload} declined your trade`)
	elseif kind == "TradeCancelled" then
		State.PushToast(`Trade cancelled by {payload}`)
	elseif kind == "TradeDone" then
		State.PushToast("Trade complete")
	elseif kind == "QuestClaimed" then
		State.PushToast(`Quest done: +{payload.Ruby} Ruby, +{payload.Points} pass points`)
	elseif kind == "PassClaimed" then
		State.PushToast(`Claimed {payload} pass reward{if payload == 1 then "" else "s"}`)
	elseif kind == "Passes" then
		State.Passes = payload
	elseif kind == "Purchased" then
		State.PushToast(`Purchased: {Text.Eco.ShopItem(payload)}`)
	elseif kind == "GiftSent" then
		State.PushToast(`Gift sent: {Text.Eco.PassName(payload.Pass)}`)
	elseif kind == "GiftReceived" then
		State.PushToast(
			`{Text.Eco.PassName(payload.Pass)} unlocked{if payload.From ~= nil
				then " (gift from " .. payload.From .. ")"
				else ""}`
		)
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
	Net.LaneTimeline:Client():On(function(userId: number, payload: Types.TimelinePayload?)
		if userId ~= State.Ui.Watch then
			return
		end
		if payload == nil and Players:GetPlayerByUserId(userId) == nil then
			State.Ui.Watch = nil
			notify()
		end
		for _, listener in watchListeners do
			task.spawn(listener, userId, payload)
		end
	end)
	Net.Notice:Client():On(onNotice)
	Net.TradeState:Client():On(function(view: Types.TradeView?)
		local opened = State.Trade == nil and view ~= nil
		State.Trade = view
		if opened and view ~= nil then
			State.DropRequest(view.PartnerId)
			State.Ui.Page = "Trade"
		end
		notify()
	end)
	-- Listeners are in place: now ask for the snapshot (the server answers once the profile is loaded).
	Net.RequestSnapshot:Client():Fire()
end

return State
