--!strict
-- Owner of the account (personal) level: XP in, levels out. Feature unlocks by account level arrive in phase 3.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Formula = require(ReplicatedStorage.Shared.Formula)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local Guard = require(ServerScriptService.Server.Util.Guard)
local Replication = require(script.Parent.Replication)

local ACCOUNT_LEVEL_CAP = 100000

local Account = {}

function Account.AddXp(player: Player, amount: number)
	local data = PlayerData.Data(player)
	if data == nil or not Guard.Amount(amount) or amount == 0 then
		return
	end
	local level, xp = Formula.Progression.Apply(
		data.AccountLevel,
		data.AccountXp,
		amount,
		ACCOUNT_LEVEL_CAP,
		Formula.Progression.AccountXpToNext
	)
	data.AccountLevel = level
	data.AccountXp = xp
	Replication.Set(player, { "AccountLevel" }, level)
	Replication.Set(player, { "AccountXp" }, xp)
end

return Account
