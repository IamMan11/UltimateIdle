--!strict
-- Owner of the account (personal) level: XP in, levels out (capped per rebirth). Level changes refresh account modifiers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Formula = require(ReplicatedStorage.Shared.Formula)
local Rebirth = require(ReplicatedStorage.Shared.Config.Rebirth)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local Guard = require(ServerScriptService.Server.Util.Guard)
local Replication = require(script.Parent.Replication)
local Modifiers = require(script.Parent.Modifiers)

local Account = {}

function Account.AddXp(player: Player, amount: number)
	local data = PlayerData.Data(player)
	if data == nil or not Guard.Amount(amount) or amount == 0 then
		return
	end
	local before = data.AccountLevel
	local level, xp = Formula.Progression.Apply(
		data.AccountLevel,
		data.AccountXp,
		amount,
		Rebirth.Get(data.Rebirth.Count).AccountLevelCap,
		Formula.Progression.AccountXpToNext
	)
	data.AccountLevel = level
	data.AccountXp = xp
	Replication.Set(player, { "AccountLevel" }, level)
	Replication.Set(player, { "AccountXp" }, xp)
	if level ~= before then
		Modifiers.MarkDirty(player)
	end
end

return Account
