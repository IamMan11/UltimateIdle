--!strict
-- Owner of player Settings: auto-salvage tier filter, skip-wave toggle (from the next level), box auto-open switch (needs the skill tree node).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)
local Replication = require(script.Parent.Replication)
local Modifiers = require(script.Parent.Modifiers)
local Box = require(script.Parent.Box)

local Settings = {}

local function set(player: Player, key: string, sub: string?, value: boolean | number | string)
	if not RateLimit.Allow(player, "SetSetting") then
		return
	end
	local data = PlayerData.Data(player)
	if data == nil or type(value) ~= "boolean" then
		return
	end
	local settings = data.Settings
	if key == "AutoSalvage" and sub ~= nil and Tiers.ById[sub] ~= nil then
		settings.AutoSalvage[sub] = value
	elseif key == "SkipWave" and sub == nil then
		settings.SkipWave = value
	elseif key == "AutoOpenBoxes" and sub == nil and Modifiers.Get(player).AutoOpen then
		settings.AutoOpenBoxes = value
	else
		return
	end
	Replication.Set(player, { "Settings" }, settings)
	if key == "AutoOpenBoxes" then
		Box.Refresh(player)
	end
end

function Settings.Start()
	Net.SetSetting:Server():On(set)
end

return Settings
