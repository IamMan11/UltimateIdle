--!strict
-- Per-player level loop: sim a level, send its timeline, pay out when playback ends, advance/retreat (Progress) or loop with a lump (Farm).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local AccountConfig = require(ReplicatedStorage.Shared.Config.Account)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Rebirth = require(ReplicatedStorage.Shared.Config.Rebirth)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)
local Rng = require(ServerScriptService.Server.Util.Rng)
local Replication = require(script.Parent.Replication)
local Currency = require(script.Parent.Currency)
local Hero = require(script.Parent.Hero)
local Account = require(script.Parent.Account)
local Loot = require(script.Parent.Loot)
local Box = require(script.Parent.Box)
local Modifiers = require(script.Parent.Modifiers)
local Quest = require(script.Parent.Quest)
local Shop = require(script.Parent.Shop)
local Sim = require(script.Sim)

type Run = {
	Token: number,
	Level: number,
	Mode: Types.StageMode,
	Rebirth: number,
	HeroIds: { string }, -- the heroes that fought; they share this level's xp
	Result: Types.SimResult,
	Payload: Types.TimelinePayload?,
	Thread: thread?,
}

local timelineEvent = Net.StageTimeline:Server()

local runs: { [Player]: Run } = {}
local tokens: { [Player]: number } = {}

local Stage = {}

-- Progress of one rebirth (created at level 1 if missing).
function Stage.ProgressFor(data: Types.ProfileData, rebirth: number): Types.StageProgress
	local key = tostring(rebirth)
	local progress = data.Stage.ByRebirth[key]
	if progress == nil then
		progress = { Level = 1, MaxLevel = 1, FarmLevel = 1, LastFarmRound = 0 }
		data.Stage.ByRebirth[key] = progress
	end
	return progress
end

-- Progress of the rebirth being played.
function Stage.Progress(data: Types.ProfileData): Types.StageProgress
	return Stage.ProgressFor(data, data.Stage.Rebirth)
end

-- Best level reached across every rebirth (gates Farm).
function Stage.BestLevel(data: Types.ProfileData): number
	local best = 1
	for _, progress in data.Stage.ByRebirth do
		best = math.max(best, progress.MaxLevel)
	end
	return best
end

local function syncStage(player: Player, data: Types.ProfileData)
	Replication.Set(player, { "Stage" }, data.Stage)
end

local function rewards(player: Player, result: Types.SimResult, level: number): (number, number)
	local gold, xp = 0, 0
	for id, count in result.Kills do
		local def = Monsters.ById[id]
		if def ~= nil then
			gold += def.Gold * count
			xp += def.Xp * count
		end
	end
	local mods = Modifiers.Get(player)
	return math.floor(gold * Formula.Scaling.Gold(level) * Formula.Mods.Mult(mods.GoldPct)),
		math.floor(xp * Formula.Scaling.Xp(level) * Formula.Mods.Mult(mods.XpPct))
end

local function updateOfflineRate(data: Types.ProfileData, gold: number, xp: number, duration: number)
	if duration <= 0 then
		return
	end
	local blend = Game.OfflineRateBlend
	local rate = data.OfflineRate
	local g, x = gold / duration, xp / duration
	rate.Gold = if rate.Gold <= 0 then g else rate.Gold * (1 - blend) + g * blend
	rate.Xp = if rate.Xp <= 0 then x else rate.Xp * (1 - blend) + x * blend
end

local function dropMult(player: Player): number
	return Formula.Mods.Mult(Modifiers.Get(player).DropPct)
end

local function payLump(player: Player, lastLevel: number, rebirth: number)
	if lastLevel < 1 then
		return
	end
	local bundle = Loot.FarmLump(Rng.new(), lastLevel, rebirth, dropMult(player))
	local summary = Loot.Grant(player, bundle)
	Replication.Notify(player, "FarmLump", { Levels = lastLevel, Summary = summary })
end

local startLevel: (Player) -> ()

local function finishLevel(player: Player, token: number)
	local run = runs[player]
	local data = PlayerData.Data(player)
	if run == nil or run.Token ~= token or data == nil or player.Parent ~= Players then
		return
	end
	runs[player] = nil
	local result = run.Result
	local gold, xp = rewards(player, result, run.Level)
	-- The offline rate is stored without pass multipliers: offline pay applies the ones owned at login.
	updateOfflineRate(data, gold, xp, result.Duration + Stages.PauseBetweenLevels)
	gold = math.floor(gold * Shop.GoldMult(player))
	xp = math.floor(xp * Shop.XpMult(player))
	Currency.Add(player, "Gold", gold)
	Hero.AddXp(player, xp, run.HeroIds)
	Account.AddXp(player, xp * AccountConfig.XpShare)
	data.LastSeen = os.time()
	local kills = 0
	for _, n in result.Kills do
		kills += n
	end
	Quest.Progress(player, "Kill", kills)
	Quest.Progress(player, "Boss", result.BossKills)
	if result.Won then
		Quest.Progress(player, "ClearLevel", 1)
	end

	-- The played rebirth may have changed during the level: progress belongs to the one that was fought.
	local progress = Stage.ProgressFor(data, run.Rebirth)
	local summary: Loot.Summary? = nil
	if run.Mode == "Progress" then
		local rng = Rng.new()
		local bundle = Loot.ForLevel(rng, run.Level, run.Rebirth, result.Kills, dropMult(player))
		for boxId, n in bundle.Boxes do
			Box.Grant(player, boxId, n)
		end
		summary = Loot.Grant(player, bundle)
		if result.Won then
			progress.Level = run.Level + 1
			progress.MaxLevel = math.max(progress.MaxLevel, progress.Level)
		else
			progress.Level = math.max(1, run.Level - Stages.RetreatOnLose)
		end
	else
		local cap = Rebirth.Get(run.Rebirth).FarmRoundCap
		if data.Stage.Rebirth ~= run.Rebirth then
			-- Switched rebirth mid-round: same as leaving Farm (drop the round, pay the last finished one).
			payLump(player, progress.LastFarmRound or 0, run.Rebirth)
			progress.FarmLevel = 1
		elseif result.Won and run.Level < cap then
			progress.FarmLevel = run.Level + 1
			progress.MaxLevel = math.max(progress.MaxLevel, progress.FarmLevel)
		else
			local cleared = if result.Won then run.Level else run.Level - 1
			payLump(player, cleared, run.Rebirth)
			progress.LastFarmRound = cleared
			progress.FarmLevel = 1
		end
	end
	syncStage(player, data)
	Replication.Notify(player, "LevelEnd", {
		Level = run.Level,
		Won = result.Won,
		Gold = gold,
		Xp = xp,
		Loot = summary,
	})
	task.delay(Stages.PauseBetweenLevels, function()
		if runs[player] == nil and tokens[player] == token then
			startLevel(player)
		end
	end)
end

startLevel = function(player: Player)
	local data = PlayerData.Data(player)
	if data == nil or player.Parent ~= Players or runs[player] ~= nil then
		return
	end
	local team = Hero.GetTeam(player)
	if #team == 0 then
		return -- waits for Hero.OnTeamChanged
	end
	local progress = Stage.Progress(data)
	local mode: Types.StageMode = data.Stage.Mode
	local level = if mode == "Farm" then progress.FarmLevel else progress.Level
	local rebirth = data.Stage.Rebirth
	-- Skip wave only on levels this rebirth has already cleared (MaxLevel = highest level reached).
	local skip = data.Settings.SkipWave and level < progress.MaxLevel
	local result = Sim.Run(team, level, rebirth, Rng.Seed(), skip)

	local token = (tokens[player] or 0) + 1
	tokens[player] = token
	local heroIds: { string } = {}
	for _, hero in team do
		table.insert(heroIds, hero.Key)
	end
	local run: Run = {
		Token = token,
		Level = level,
		Mode = mode,
		Rebirth = rebirth,
		HeroIds = heroIds,
		Result = result,
		Payload = nil,
		Thread = nil,
	}
	runs[player] = run

	local lead = 0.3
	local teamInfo = {}
	for _, hero in team do
		table.insert(teamInfo, { Key = hero.Key, Class = hero.Class, Row = hero.Row, MaxHp = hero.Stats.MaxHp })
	end
	local payload: Types.TimelinePayload = {
		Level = level,
		Mode = mode,
		Rebirth = rebirth,
		StartAt = workspace:GetServerTimeNow() + lead,
		Duration = result.Duration,
		Won = result.Won,
		Skip = skip,
		Team = teamInfo,
		Events = result.Events,
		EventCount = result.EventCount,
	}
	run.Payload = payload
	if Replication.IsSynced(player) then
		timelineEvent:Fire(player, payload)
	end
	run.Thread = task.delay(result.Duration + lead, finishLevel, player, token)
end

-- Drops the level in progress (no payout) and starts again from current saved progress.
function Stage.Restart(player: Player)
	local run = runs[player]
	if run ~= nil then
		runs[player] = nil
		if run.Thread ~= nil then
			task.cancel(run.Thread)
		end
	end
	tokens[player] = (tokens[player] or 0) + 1
	startLevel(player)
end

local function setMode(player: Player, mode: string)
	if not RateLimit.Allow(player, "SetStageMode") then
		return
	end
	local data = PlayerData.Data(player)
	if data == nil or (mode ~= "Progress" and mode ~= "Farm") or data.Stage.Mode == mode then
		return
	end
	if mode == "Farm" and not AccountConfig.IsUnlocked("Farm", data.AccountLevel, Stage.BestLevel(data)) then
		Replication.Notify(player, "Error", "FarmLocked")
		return
	end
	local progress = Stage.Progress(data)
	if data.Stage.Mode == "Farm" then
		-- Leaving Farm mid-round drops the current round and pays a fresh roll of the last finished round.
		payLump(player, progress.LastFarmRound or 0, data.Stage.Rebirth)
	end
	progress.FarmLevel = 1
	data.Stage.Mode = mode :: Types.StageMode
	syncStage(player, data)
	Stage.Restart(player)
end

-- Rebirth being played (<= rebirths owned; checked by the caller). Applies from the next level.
function Stage.SetPlayRebirth(player: Player, rebirth: number)
	local data = PlayerData.Data(player)
	if data == nil or data.Stage.Rebirth == rebirth then
		return
	end
	data.Stage.Rebirth = rebirth
	local progress = Stage.ProgressFor(data, rebirth)
	if data.Stage.Mode == "Farm" then
		progress.FarmLevel = 1 -- a fresh round in the new rebirth
	end
	syncStage(player, data)
end

-- New rebirth keeps the stage level reached in the one it came from.
function Stage.SeedRebirth(player: Player, rebirth: number, from: number)
	local data = PlayerData.Data(player)
	if data == nil or data.Stage.ByRebirth[tostring(rebirth)] ~= nil then
		return
	end
	local level = Stage.ProgressFor(data, from).Level
	data.Stage.ByRebirth[tostring(rebirth)] = { Level = level, MaxLevel = level, FarmLevel = 1, LastFarmRound = 0 }
	syncStage(player, data)
end

function Stage.Start()
	Net.SetStageMode:Server():On(setMode)
	Replication.OnSynced(function(player)
		local run = runs[player]
		if run ~= nil and run.Payload ~= nil then
			timelineEvent:Fire(player, run.Payload)
		end
	end)
	Hero.OnTeamChanged(function(player)
		if runs[player] == nil then
			startLevel(player)
		end
	end)
	PlayerData.OnLoaded(function(player)
		task.defer(startLevel, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local run = runs[player]
		if run ~= nil and run.Thread ~= nil then
			task.cancel(run.Thread)
		end
		runs[player] = nil
		tokens[player] = nil
	end)
end

return Stage
