--!strict
-- Owner of Pass (battle pass): season = UTC month, points from claimed quests, free/premium tier claims, premium unlock from the receipt handler.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local Period = require(ReplicatedStorage.Shared.Period)
local PassConfig = require(ReplicatedStorage.Shared.Config.BattlePass)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)
local Guard = require(ServerScriptService.Server.Util.Guard)
local Replication = require(script.Parent.Replication)
local Quest = require(script.Parent.Quest)
local Rewards = require(script.Parent.Rewards)

local BattlePass = {}

-- The live season, reset if the month changed (unclaimed tiers of an old season are gone).
local function season(player: Player, data: Types.ProfileData): Types.PassState
	local key = Period.Key("Monthly")
	if data.Pass.Season ~= key then
		data.Pass = { Season = key, Points = 0, Premium = false, Free = {}, Paid = {} }
		Replication.Set(player, { "Pass" }, data.Pass)
	end
	return data.Pass
end

function BattlePass.AddPoints(player: Player, n: number)
	local data = PlayerData.Data(player)
	if data == nil or not Guard.Int(n, 1, 1e6) then
		return
	end
	local pass = season(player, data)
	pass.Points = math.min(pass.Points + n, PassConfig.Tiers * PassConfig.PointsPerTier)
	Replication.Set(player, { "Pass", "Points" }, pass.Points)
end

-- Receipt handler: premium track for the season current at grant time. Idempotent.
function BattlePass.SetPremium(player: Player): boolean
	local data = PlayerData.Data(player)
	if data == nil then
		return false
	end
	local pass = season(player, data)
	pass.Premium = true
	Replication.Set(player, { "Pass", "Premium" }, true)
	return true
end

function BattlePass.HasPremium(player: Player): boolean
	local data = PlayerData.Data(player)
	return data ~= nil and season(player, data).Premium
end

-- Claims one tier; returns false (with notice) when it cannot.
local function claimOne(player: Player, data: Types.ProfileData, track: string, tier: number, quiet: boolean): boolean
	local pass = season(player, data)
	local claimed = if track == "Paid" then pass.Paid else pass.Free
	local key = tostring(tier)
	if claimed[key] or pass.Points < tier * PassConfig.PointsPerTier then
		return false
	end
	if track == "Paid" and not pass.Premium then
		if not quiet then
			Replication.Notify(player, "Error", "NeedPremium")
		end
		return false
	end
	local reward = if track == "Paid" then PassConfig.Paid[tier] else PassConfig.Free[tier]
	local ok, err = Rewards.CanGrant(player, reward)
	if not ok then
		if not quiet and err ~= nil then
			Replication.Notify(player, "Error", err)
		end
		return false
	end
	claimed[key] = true
	Replication.Set(player, { "Pass", track, key }, true)
	Rewards.Grant(player, reward, "Reward")
	return true
end

-- tier 0 = every tier that can be claimed on that track.
local function claim(player: Player, track: string, tier: number)
	if not RateLimit.Allow(player, "ClaimPass") then
		return
	end
	local data = PlayerData.Data(player)
	if data == nil or (track ~= "Free" and track ~= "Paid") or not Guard.Int(tier, 0, PassConfig.Tiers) then
		return
	end
	local count = 0
	if tier == 0 then
		for t = 1, PassConfig.Tiers do
			if claimOne(player, data, track, t, true) then
				count += 1
			end
		end
	elseif claimOne(player, data, track, tier, false) then
		count = 1
	end
	if count > 0 then
		Replication.Notify(player, "PassClaimed", count)
	end
end

function BattlePass.Start()
	Net.ClaimPass:Server():On(claim)
	Quest.OnClaimed(function(player, def)
		BattlePass.AddPoints(player, def.PassPoints)
	end)
	PlayerData.OnLoaded(function(player, data)
		season(player, data)
	end)
end

return BattlePass
