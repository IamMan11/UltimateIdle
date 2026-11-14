--!strict
-- Owner of Boxes (stacks keyed kind:rebirth:band): receive (over cap = lost), open (bounded by bag space), convert 5 normal/boss -> 1 class box.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Boxes = require(ReplicatedStorage.Shared.Config.Boxes)
local Heroes = require(ReplicatedStorage.Shared.Config.Heroes)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)
local Guard = require(ServerScriptService.Server.Util.Guard)
local Rng = require(ServerScriptService.Server.Util.Rng)
local Replication = require(script.Parent.Replication)
local Inventory = require(script.Parent.Inventory)
local Loot = require(script.Parent.Loot)

local Box = {}

function Box.Cap(_player: Player, key: string): number
	local parsed = Boxes.Parse(key)
	local def = if parsed ~= nil then Boxes.ById[parsed.Kind] else nil
	-- Skill tree raises this in phase 3.
	return if def ~= nil then def.Max else 0
end

local function set(player: Player, key: string, n: number)
	local data = PlayerData.Data(player)
	if data == nil then
		return
	end
	if n > 0 then
		data.Boxes[key] = n
	else
		data.Boxes[key] = nil
	end
	Replication.Set(player, { "Boxes", key }, data.Boxes[key])
end

-- Adds up to the stack cap; returns (kept, lost).
function Box.Grant(player: Player, key: string, n: number): (number, number)
	local data = PlayerData.Data(player)
	if data == nil or Boxes.Parse(key) == nil or not Guard.Int(n, 0, 1e6) then
		return 0, n
	end
	local have = data.Boxes[key] or 0
	local kept = math.clamp(Box.Cap(player, key) - have, 0, n)
	if kept > 0 then
		set(player, key, have + kept)
	end
	return kept, n - kept
end

local function open(player: Player, key: string, count: number)
	if not RateLimit.Allow(player, "OpenBox") then
		return
	end
	local data = PlayerData.Data(player)
	local parsed = Boxes.Parse(key)
	local def = if parsed ~= nil then Boxes.ById[parsed.Kind] else nil
	if data == nil or parsed == nil or def == nil then
		return
	end
	local have = data.Boxes[key] or 0
	local fits = Inventory.FreeSpace(player) // def.GearPerOpen
	local n = math.min(count, have, fits, Game.OpenBatchMax)
	if n <= 0 then
		if have > 0 then
			Replication.Notify(player, "Error", "BagFull")
		end
		return
	end
	set(player, key, have - n)
	local rng = Rng.new()
	local low, high = Boxes.BandRange(parsed.Band, parsed.Rebirth)
	local bundle: Loot.Bundle = { Gear = {}, Materials = {}, Boxes = {} }
	for _ = 1, n do
		Loot.RollBox(rng, parsed.Kind, rng:Int(low, high), parsed.Rebirth, bundle)
	end
	local summary = Loot.Grant(player, bundle)
	Replication.Notify(player, "BoxOpened", { Box = key, Opened = n, Summary = summary })
end

local function convert(player: Player, source: string, class: string, count: number)
	if not RateLimit.Allow(player, "ConvertBox") then
		return
	end
	local data = PlayerData.Data(player)
	local parsed = Boxes.Parse(source)
	if data == nil or Heroes.ById[class] == nil then
		return
	end
	if parsed == nil or table.find(Boxes.ConvertSources, parsed.Kind) == nil then
		Replication.Notify(player, "Error", "BadBox")
		return
	end
	local target = Boxes.Key(`Class_{class}`, parsed.Rebirth, parsed.Band)
	local have = data.Boxes[source] or 0
	local room = Box.Cap(player, target) - (data.Boxes[target] or 0)
	local n = math.min(count, have // Boxes.ConvertCost, room)
	if n <= 0 then
		Replication.Notify(player, "Error", if room <= 0 then "BoxFull" else "NotEnoughBoxes")
		return
	end
	set(player, source, have - n * Boxes.ConvertCost)
	set(player, target, (data.Boxes[target] or 0) + n)
end

function Box.Start()
	Net.OpenBox:Server():On(open)
	Net.ConvertBox:Server():On(convert)
end

return Box
