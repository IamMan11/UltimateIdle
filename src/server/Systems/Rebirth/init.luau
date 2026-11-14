--!strict
-- Owner of Rebirth (count, points): the Rebirth action (resets nothing, raises caps, grants points + items) and picking which owned rebirth to play.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local RebirthConfig = require(ReplicatedStorage.Shared.Config.Rebirth)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local Guard = require(ServerScriptService.Server.Util.Guard)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)
local Replication = require(script.Parent.Replication)
local Inventory = require(script.Parent.Inventory)
local Modifiers = require(script.Parent.Modifiers)
local Hero = require(script.Parent.Hero)
local Stage = require(script.Parent.Stage)

local Rebirth = {}

function Rebirth.Points(player: Player): number
	local data = PlayerData.Data(player)
	return if data ~= nil then data.Rebirth.Points else 0
end

function Rebirth.AddPoints(player: Player, n: number)
	local data = PlayerData.Data(player)
	if data == nil or not Guard.Int(n, 0, 1e6) then
		return
	end
	data.Rebirth.Points += n
	Replication.Set(player, { "Rebirth" }, data.Rebirth)
end

-- Deducts only if all `n` points are there.
function Rebirth.SpendPoints(player: Player, n: number): boolean
	local data = PlayerData.Data(player)
	if data == nil or not Guard.Int(n, 0, 1e6) or data.Rebirth.Points < n then
		return false
	end
	data.Rebirth.Points -= n
	Replication.Set(player, { "Rebirth" }, data.Rebirth)
	return true
end

-- Highest level cleared in the top owned rebirth (MaxLevel = highest level reached).
function Rebirth.Cleared(data: Types.ProfileData): number
	local progress = data.Stage.ByRebirth[tostring(data.Rebirth.Count)]
	return if progress ~= nil then progress.MaxLevel - 1 else 0
end

local function rebirth(player: Player)
	if not RateLimit.Allow(player, "Rebirth") then
		return
	end
	local data = PlayerData.Data(player)
	if data == nil then
		return
	end
	local from = data.Rebirth.Count
	local nextDef = RebirthConfig.Next(from)
	if nextDef == nil then
		Replication.Notify(player, "Error", "RebirthMax")
		return
	end
	if Rebirth.Cleared(data) < nextDef.RequiredLevel then
		Replication.Notify(player, "Error", "RebirthLocked")
		return
	end
	data.Rebirth.Count = nextDef.Index
	data.Rebirth.Points += nextDef.Points
	Replication.Set(player, { "Rebirth" }, data.Rebirth)
	for id, n in nextDef.Items do
		Inventory.AddStack(player, id, n)
	end
	Stage.SeedRebirth(player, nextDef.Index, from)
	Stage.SetPlayRebirth(player, nextDef.Index)
	Hero.MarkDirty(player)
	Modifiers.MarkDirty(player)
	Replication.Notify(player, "Rebirthed", nextDef.Index)
end

local function setPlay(player: Player, index: number)
	if not RateLimit.Allow(player, "SetPlayRebirth") then
		return
	end
	local data = PlayerData.Data(player)
	if data == nil or not Guard.Int(index, 0, data.Rebirth.Count) then
		return
	end
	Stage.SetPlayRebirth(player, index)
	Replication.Notify(player, "PlayRebirth", index)
end

function Rebirth.Start()
	Net.Rebirth:Server():On(rebirth)
	Net.SetPlayRebirth:Server():On(setPlay)
end

return Rebirth
