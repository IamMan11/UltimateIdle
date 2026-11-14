--!strict
-- Profile -> client sync: full snapshot once the client asks and the profile is ready, then batched deltas (one flush per frame).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)

type Pending = {
	Order: { string },
	Changes: { [string]: { any } },
}

local snapshotEvent = Net.StateSnapshot:Server()
local deltaEvent = Net.StateDelta:Server()
local noticeEvent = Net.Notice:Server()

local synced: { [Player]: boolean } = {}
local wanting: { [Player]: boolean } = {}
local pending: { [Player]: Pending } = {}
-- Notices raised before the snapshot (e.g. offline earnings at load) wait here and follow the snapshot.
local queuedNotices: { [Player]: { { any } } } = {}
local flushQueued = false
local syncedListeners: { (Player) -> () } = {}

local function flush()
	flushQueued = false
	for player, batch in pending do
		local changes: { { any } } = {}
		for _, key in batch.Order do
			table.insert(changes, batch.Changes[key])
		end
		if synced[player] and player.Parent == Players then
			deltaEvent:Fire(player, changes)
		end
	end
	table.clear(pending)
end

local function sendSnapshot(player: Player)
	local data = PlayerData.Data(player)
	if data == nil then
		wanting[player] = true
		return
	end
	wanting[player] = nil
	synced[player] = true
	pending[player] = nil
	snapshotEvent:Fire(player, data)
	local queued = queuedNotices[player]
	queuedNotices[player] = nil
	if queued ~= nil then
		for _, notice in queued do
			noticeEvent:Fire(player, notice[1], notice[2])
		end
	end
	for _, listener in syncedListeners do
		task.spawn(listener, player)
	end
end

local Replication = {}

-- Queue `value` at `path` for the owning client. Later sets to the same path in one frame replace earlier ones.
-- Pass the live table for table values: it is serialized at flush, so it always carries the latest contents.
function Replication.Set(player: Player, path: { string }, value: any)
	if not synced[player] then
		return
	end
	local batch = pending[player]
	if batch == nil then
		batch = { Order = {}, Changes = {} }
		pending[player] = batch
	end
	local key = table.concat(path, "\0")
	if batch.Changes[key] == nil then
		table.insert(batch.Order, key)
	end
	batch.Changes[key] = { path, value }
	if not flushQueued then
		flushQueued = true
		task.defer(flush)
	end
end

-- One-off message for UI (toasts, reward summaries). Not state. Before the snapshot it is queued and sent right after it.
function Replication.Notify(player: Player, kind: string, payload: any)
	if synced[player] then
		noticeEvent:Fire(player, kind, payload)
	elseif player.Parent == Players then
		local queued = queuedNotices[player]
		if queued == nil then
			queued = {}
			queuedNotices[player] = queued
		end
		if #queued < 20 then
			table.insert(queued, { kind, payload })
		end
	end
end

-- Called each time a client receives a snapshot (so systems can resend non-profile state, e.g. the running timeline).
function Replication.OnSynced(listener: (Player) -> ())
	table.insert(syncedListeners, listener)
end

function Replication.IsSynced(player: Player): boolean
	return synced[player] == true
end

function Replication.Start()
	Net.RequestSnapshot:Server():On(function(player: Player)
		if not RateLimit.Allow(player, "RequestSnapshot") then
			return
		end
		sendSnapshot(player)
	end)

	-- Registered last in boot order so load-time grants are already inside the snapshot.
	PlayerData.OnLoaded(function(player)
		if wanting[player] then
			sendSnapshot(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		synced[player] = nil
		wanting[player] = nil
		pending[player] = nil
		queuedNotices[player] = nil
	end)
end

return Replication
