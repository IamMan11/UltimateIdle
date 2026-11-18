--!strict
-- Owner of Quests: other systems report events via Quest.Progress(kind, n); UTC day/week/month periods reset when touched (load, progress, claim); ClaimQuest (one quest or a whole period) pays Ruby + pass points.

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
local progressListeners: { (Player, Quests.Kind) -> () } = {}

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
	for _, listener in progressListeners do
		task.spawn(listener, player, kind)
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

-- Fires on every reported event, before quest caps (the tutorial follows the same events).
function Quest.OnProgress(listener: (Player, Quests.Kind) -> ())
	table.insert(progressListeners, listener)
end

-- Fires after a quest is claimed (BattlePass adds the points).
function Quest.OnClaimed(listener: (Player, Quests.QuestDef) -> ())
	table.insert(claimedListeners, listener)
end

-- Pays one quest; returns the error key when it is already claimed or not finished.
local function claimOne(player: Player, data: Types.ProfileData, def: Quests.QuestDef): string?
	local p = current(player, data, def.Period)
	if p.Claimed[def.Id] then
		return "QuestClaimed"
	end
	if (p.Progress[def.Kind] or 0) < def.Need then
		return "QuestNotDone"
	end
	p.Claimed[def.Id] = true
	Replication.Set(player, { "Quests", def.Period, "Claimed", def.Id }, true)
	Currency.Add(player, "Ruby", def.Ruby, "Quest")
	for _, listener in claimedListeners do
		task.spawn(listener, player, def)
	end
	return nil
end

-- `id` = a quest id, or a period name ("Daily" / "Weekly" / "Monthly") = every finished quest of that period.
local function claim(player: Player, id: string)
	if not RateLimit.Allow(player, "ClaimQuest") then
		return
	end
	local data = PlayerData.Data(player)
	if data == nil then
		return
	end
	local all = Quests.ByPeriod[id]
	if all ~= nil then
		local ruby, points = 0, 0
		for _, def in all do
			if claimOne(player, data, def) == nil then
				ruby += def.Ruby
				points += def.PassPoints
			end
		end
		if points > 0 then
			Replication.Notify(player, "QuestClaimed", { Id = id, Ruby = ruby, Points = points })
		end
		return
	end
	local def = Quests.ById[id]
	if def == nil then
		return
	end
	local err = claimOne(player, data, def)
	if err ~= nil then
		Replication.Notify(player, "Error", err)
		return
	end
	Replication.Notify(player, "QuestClaimed", { Id = id, Ruby = def.Ruby, Points = def.PassPoints })
end

function Quest.Start()
	Net.ClaimQuest:Server():On(claim)
	PlayerData.OnLoaded(refreshAll)
end

return Quest
