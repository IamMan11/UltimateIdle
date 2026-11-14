--!strict
-- Cached account modifiers per player (skill tree, account level, rebirth count, team relics). Owners of those inputs call MarkDirty.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Formula = require(ReplicatedStorage.Shared.Formula)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)

local cache: { [Player]: Formula.Mods } = {}
local listeners: { (Player) -> () } = {}

local Modifiers = {}

function Modifiers.Get(player: Player): Formula.Mods
	local cached = cache[player]
	if cached ~= nil then
		return cached
	end
	local data = PlayerData.Data(player)
	if data == nil then
		return Formula.Mods.Build({}, {}, 1) -- not cached: the profile is not loaded yet
	end
	local relics = Formula.Gear.Relics(Formula.Gear.TeamGear(data))
	local mods = Formula.Mods.Build(data.SkillTree, data.SkillOff, data.AccountLevel, data.Rebirth.Count, relics)
	cache[player] = mods
	return mods
end

-- Rebuild on next Get and tell listeners (they read the new values through Get).
function Modifiers.MarkDirty(player: Player)
	cache[player] = nil
	for _, listener in listeners do
		task.spawn(listener, player)
	end
end

function Modifiers.OnChanged(listener: (Player) -> ())
	table.insert(listeners, listener)
end

Players.PlayerRemoving:Connect(function(player)
	cache[player] = nil
end)

return Modifiers
