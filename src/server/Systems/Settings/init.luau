--!strict
-- Owner of player Settings: auto-salvage tier filter, skip-wave toggle (from the next level), box auto-open switch (needs the skill tree node), UI size, low detail, floating window places.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local Game = require(ReplicatedStorage.Shared.Config.Game)
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
	if data == nil then
		return
	end
	local settings = data.Settings
	if key == "UiScale" and sub == nil and type(value) == "number" then
		if table.find(Game.UiScales, value) == nil then
			return
		end
		settings.UiScale = value
		Replication.Set(player, { "Settings" }, settings)
		return
	end
	if type(value) ~= "boolean" then
		return
	end
	if key == "LowDetail" and sub == nil then
		settings.LowDetail = value
	elseif key == "AutoSalvage" and sub ~= nil and Tiers.ById[sub] ~= nil then
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

-- Range is checked by the Net validator (every number is a 0..1 screen fraction).
local function setWindow(player: Player, id: string, x: number, y: number, w: number, h: number)
	if not RateLimit.Allow(player, "SetWindow") then
		return
	end
	local data = PlayerData.Data(player)
	if data == nil or table.find(Game.Windows, id) == nil then
		return
	end
	local rect = { x, y, w, h }
	data.Settings.Windows[id] = rect
	Replication.Set(player, { "Settings", "Windows", id }, rect)
end

function Settings.Start()
	Net.SetSetting:Server():On(set)
	Net.SetWindow:Server():On(setWindow)
end

return Settings
