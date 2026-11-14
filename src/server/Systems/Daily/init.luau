--!strict
-- Owner of the daily login reward: one ClaimDaily per UTC day, streak continues only from yesterday, 7-day cycle from Config.Daily.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Period = require(ReplicatedStorage.Shared.Period)
local DailyConfig = require(ReplicatedStorage.Shared.Config.Daily)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)
local Replication = require(script.Parent.Replication)
local Rewards = require(script.Parent.Rewards)

local DAY = 86400

local Daily = {}

-- Day of the cycle (1..#Days) the next claim pays, given the saved state and today.
function Daily.NextDay(streak: number, lastDay: string, now: number): number
	local yesterday = Period.Key("Daily", now - DAY)
	local nextStreak = if lastDay == yesterday then streak + 1 else 1
	return (nextStreak - 1) % #DailyConfig.Days + 1
end

local function claim(player: Player)
	if not RateLimit.Allow(player, "ClaimDaily") then
		return
	end
	local data = PlayerData.Data(player)
	if data == nil then
		return
	end
	local now = os.time()
	local today = Period.Key("Daily", now)
	local daily = data.Daily
	if daily.Day == today then
		Replication.Notify(player, "Error", "DailyClaimed")
		return
	end
	local reward = DailyConfig.Days[Daily.NextDay(daily.Streak, daily.Day, now)]
	local ok, problem = Rewards.CanGrant(player, reward)
	if not ok then
		Replication.Notify(player, "Error", problem or "BoxFull")
		return
	end
	local yesterday = Period.Key("Daily", now - DAY)
	daily.Streak = if daily.Day == yesterday then daily.Streak + 1 else 1
	daily.Day = today
	Replication.Set(player, { "Daily" }, daily)
	local resolved = Rewards.Grant(player, reward, "Reward")
	Replication.Notify(
		player,
		"DailyClaimed",
		{ Streak = daily.Streak, Gold = if resolved ~= nil then resolved.Gold else 0 }
	)
end

function Daily.Start()
	Net.ClaimDaily:Server():On(claim)
end

return Daily
