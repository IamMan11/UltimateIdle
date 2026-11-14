--!strict
-- Owner of Quests: other systems report events via Quest.Progress(kind, n); UTC day/week/month periods reset when touched (load, progress, claim); ClaimQuest pays Ruby + pass points.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local Period = require(ReplicatedStorage.Shared.Period)
local Quests = require(ReplicatedStorage.Shared.Config.Quests)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)
local Guard = require(ServerScriptService.Server.Util.Guard)
local Replication = require(script.Parent.Replication)
local Currency = require(script.Parent.Currency)

local claimedListeners: { (Player, Quests.QuestDef) -> () } = {}

local Quest = {}

-- The live period table, reset (and replicated whole) if its key is stale.
local function current(player: Player, data: Types.ProfileData, kind: Period.Kind): Types.QuestPeriod
	local quests: any = data.Quests
	local p: Types.QuestPeriod = quests[kind]
	local key = Period.Key(kind)
	if p.Key ~= key then
		p = { Key = key, Progress = {}, Claimed = {} }
		quests[kind] = p
		Replication.Set(player, { "Quests", kind }, p)
	end
	return p
end

local function refreshAll(player: Player, data: Types.ProfileData)
	for _, kind in Period.List() do
		current(player, data, kind :: Period.Kind)
	end
end

-- Adds n to every period that has a quest of this kind (capped at the largest target).
function Quest.Progress(player: Player, kind: Quests.Kind, n: number)
	local data = PlayerData.Data(player)
	if data == nil or not Guard.Amount(n) or n <= 0 then
		return
	end
	for _, period in Period.List() do
		local cap = Quests.CapByPeriod[period][kind]
		if cap ~= nil then
			local p = current(player, data, period :: Period.Kind)
			local before = p.Progress[kind] or 0
			if before < cap then
				local value = math.min(before + math.floor(n), cap)
				p.Progress[kind] = value
				Replication.Set(player, { "Quests", period, "Progress", kind }, value)
			end
		end
	end
end

-- Fires after a quest is claimed (BattlePass adds the points).
function Quest.OnClaimed(listener: (Player, Quests.QuestDef) -> ())
	table.insert(claimedListeners, listener)
end

local function claim(player: Player, id: string)
	if not RateLimit.Allow(player, "ClaimQuest") then
		return
	end
	local data = PlayerData.Data(player)
	local def = Quests.ById[id]
	if data == nil or def == nil then
		return
	end
	local p = current(player, data, def.Period)
	if p.Claimed[id] then
		Replication.Notify(player, "Error", "QuestClaimed")
		return
	end
	if (p.Progress[def.Kind] or 0) < def.Need then
		Replication.Notify(player, "Error", "QuestNotDone")
		return
	end
	p.Claimed[id] = true
	Replication.Set(player, { "Quests", def.Period, "Claimed", id }, true)
	Currency.Add(player, "Ruby", def.Ruby)
	for _, listener in claimedListeners do
		task.spawn(listener, player, def)
	end
	Replication.Notify(player, "QuestClaimed", { Id = id, Ruby = def.Ruby, Points = def.PassPoints })
end

function Quest.Start()
	Net.ClaimQuest:Server():On(claim)
	PlayerData.OnLoaded(refreshAll)
end

return Quest
