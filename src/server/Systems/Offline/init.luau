--!strict
-- Offline earnings (gold + xp only, share of the online rate, no time cap) and AFK auto-rejoin.

local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)
local Guard = require(ServerScriptService.Server.Util.Guard)
local Replication = require(script.Parent.Replication)
local Currency = require(script.Parent.Currency)
local Hero = require(script.Parent.Hero)

local Offline = {}

-- Skill tree adds to this in phase 3; gamepass x2 multipliers in phase 6.
function Offline.Share(_player: Player): number
	return Game.OfflineShare
end

local function payOffline(player: Player, data: PlayerData.Data)
	local now = os.time()
	local last = data.LastSeen
	data.LastSeen = now
	if last <= 0 or now <= last then
		return
	end
	local seconds = now - last
	local share = Offline.Share(player)
	local gold = math.floor(data.OfflineRate.Gold * seconds * share)
	local xp = math.floor(data.OfflineRate.Xp * seconds * share)
	if not (Guard.Amount(gold) and Guard.Amount(xp)) or (gold <= 0 and xp <= 0) then
		return
	end
	Currency.Add(player, "Gold", gold)
	Hero.AddXp(player, xp)
	Replication.Notify(player, "Offline", { Seconds = seconds, Gold = gold, Xp = xp })
end

local function rejoin(player: Player)
	if not RateLimit.Allow(player, "RequestRejoin") then
		return
	end
	if RunService:IsStudio() then
		print(`[Offline] AFK rejoin requested by {player.Name} (teleport skipped in Studio)`)
		return
	end
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player })
	end)
	if not ok then
		warn(`[Offline] rejoin teleport failed for {player.Name}: {err}`)
	end
end

function Offline.Start()
	PlayerData.OnLoaded(payOffline)
	PlayerData.OnReleasing(function(_player, data)
		data.LastSeen = os.time()
	end)
	Net.RequestRejoin:Server():On(rejoin)
end

return Offline
