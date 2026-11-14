--!strict
-- Owner of Rebirth (count, points). Phase 3 only spends/grants points; rebirthing itself arrives in phase 4.

local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local Guard = require(ServerScriptService.Server.Util.Guard)
local Replication = require(script.Parent.Replication)

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

return Rebirth
