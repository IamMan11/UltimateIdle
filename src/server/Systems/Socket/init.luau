--!strict
-- Socket remotes: merge a duplicate (+1 socket), use a Socket Core (+1 socket), pick socket kind, insert, remove (costs gold). Writes go through Inventory.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Inserts = require(ReplicatedStorage.Shared.Config.Inserts)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)
local Guard = require(ServerScriptService.Server.Util.Guard)
local Replication = require(script.Parent.Replication)
local Currency = require(script.Parent.Currency)
local Inventory = require(script.Parent.Inventory)

local Socket = {}

local function err(player: Player, key: string)
	Replication.Notify(player, "Error", key)
end

-- Material piece is consumed; main keeps plus, gear score, enchants and inserts.
local function merge(player: Player, mainUid: string, materialUid: string)
	if not RateLimit.Allow(player, "MergeSocket") then
		return
	end
	local main = Inventory.Get(player, mainUid)
	local material = Inventory.Get(player, materialUid)
	if main == nil or material == nil or not Formula.Forge.CanMerge(main, material) then
		return
	end
	if Inventory.IsLocked(player, mainUid) or Inventory.IsLocked(player, materialUid) then
		err(player, "ItemInTrade")
		return
	end
	if Inventory.WornBy(player, materialUid) ~= nil then
		err(player, "MaterialWorn")
		return
	end
	local gold = Formula.Forge.MergeGold(main)
	if not Currency.Has(player, "Gold", gold) then
		err(player, "NotEnoughGold")
		return
	end
	-- RemoveGear refuses worn pieces; checked above, so this only fails if the piece vanished.
	if Inventory.RemoveGear(player, materialUid) == nil then
		return
	end
	Currency.Spend(player, "Gold", gold)
	Inventory.AddSocket(player, mainUid)
	Replication.Notify(player, "SocketAdded", { Uid = mainUid, Count = #main.Sockets })
end

local function useCore(player: Player, uid: string)
	if not RateLimit.Allow(player, "UseSocketCore") then
		return
	end
	local item = Inventory.Get(player, uid)
	if item == nil then
		return
	end
	if Inventory.IsLocked(player, uid) then
		err(player, "ItemInTrade")
		return
	end
	if #item.Sockets >= Inserts.MaxSockets then
		err(player, "SocketsFull")
		return
	end
	if not Inventory.SpendStack(player, Inserts.CoreItem, 1) then
		err(player, "NotEnoughItems")
		return
	end
	Inventory.AddSocket(player, uid)
	Replication.Notify(player, "SocketAdded", { Uid = uid, Count = #item.Sockets })
end

-- Changing the kind returns whatever was inserted to the bag (free).
local function setKind(player: Player, uid: string, index: number, kind: string)
	if not RateLimit.Allow(player, "SetSocketKind") then
		return
	end
	local item = Inventory.Get(player, uid)
	local socket = if item ~= nil then item.Sockets[index] else nil
	if Inventory.IsLocked(player, uid) then
		err(player, "ItemInTrade")
		return
	end
	if item == nil or socket == nil or not Guard.OneOf(kind, Inserts.Kinds) or socket.Kind == kind then
		return
	end
	if socket.Insert ~= nil then
		Inventory.AddStack(player, socket.Insert, 1)
	end
	Inventory.SetSocket(player, uid, index, { Kind = kind :: Types.SocketKind, Insert = nil })
end

local function insert(player: Player, uid: string, index: number, id: string)
	if not RateLimit.Allow(player, "InsertSocket") then
		return
	end
	local item = Inventory.Get(player, uid)
	local socket = if item ~= nil then item.Sockets[index] else nil
	if Inventory.IsLocked(player, uid) then
		err(player, "ItemInTrade")
		return
	end
	local def = Inserts.ById[id]
	if item == nil or socket == nil or def == nil then
		return
	end
	if socket.Kind ~= def.Kind then
		err(player, "WrongSocketKind")
		return
	end
	if socket.Insert ~= nil then
		err(player, "SocketTaken")
		return
	end
	if not Inventory.SpendStack(player, id, 1) then
		err(player, "NotEnoughItems")
		return
	end
	Inventory.SetSocket(player, uid, index, { Kind = socket.Kind, Insert = id })
end

local function remove(player: Player, uid: string, index: number)
	if not RateLimit.Allow(player, "RemoveInsert") then
		return
	end
	local item = Inventory.Get(player, uid)
	local socket = if item ~= nil then item.Sockets[index] else nil
	if Inventory.IsLocked(player, uid) then
		err(player, "ItemInTrade")
		return
	end
	if item == nil or socket == nil or socket.Insert == nil then
		return
	end
	if not Currency.Spend(player, "Gold", Formula.Forge.RemoveGold(item)) then
		err(player, "NotEnoughGold")
		return
	end
	Inventory.AddStack(player, socket.Insert, 1)
	Inventory.SetSocket(player, uid, index, { Kind = socket.Kind, Insert = nil })
end

function Socket.Start()
	Net.MergeSocket:Server():On(merge)
	Net.UseSocketCore:Server():On(useCore)
	Net.SetSocketKind:Server():On(setKind)
	Net.InsertSocket:Server():On(insert)
	Net.RemoveInsert:Server():On(remove)
end

return Socket
