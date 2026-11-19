--!strict
-- Owner of Gear (wearables, by uid) and Stacks (materials): create/remove/stack with capacity checks (bag slots = gear + material slots + box stacks), plus/socket/enchant setters, trade locks + transfer. Other systems never write these tables.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Types = require(ReplicatedStorage.Shared.Types)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local EnchantConfig = require(ReplicatedStorage.Shared.Config.Enchant)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local Materials = require(ReplicatedStorage.Shared.Config.Materials)
local Formula = require(ReplicatedStorage.Shared.Formula)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local Guard = require(ServerScriptService.Server.Util.Guard)
local Replication = require(script.Parent.Replication)
local Modifiers = require(script.Parent.Modifiers)

export type GearSpec = {
	BaseId: string,
	Tier: Types.Tier,
	Level: number,
	Rebirth: number,
	GearScore: number,
}

-- Total gear entries (worn + bag) per player, kept in step with data.Gear.
local totals: { [Player]: number } = {}

-- Pieces offered in an open trade (memory only): they cannot be changed, worn or removed until the trade ends.
local locks: { [Player]: { [string]: boolean } } = {}

local freedListeners: { (Player) -> () } = {}
local changedListeners: { (Player, string) -> () } = {}

local Inventory = {}

-- Fires after a bag item is removed (space freed), e.g. so box auto-open can resume.
function Inventory.OnFreed(listener: (Player) -> ())
	table.insert(freedListeners, listener)
end

function Inventory.Get(player: Player, uid: string): Types.GearItem?
	local data = PlayerData.Data(player)
	return if data ~= nil then data.Gear[uid] else nil
end

-- Which hero wears this uid (nil = in the bag).
function Inventory.WornBy(player: Player, uid: string): (string?, string?)
	local data = PlayerData.Data(player)
	if data == nil then
		return nil, nil
	end
	for heroId, hero in data.Heroes do
		for slot, worn in hero.Equipped do
			if worn == uid then
				return heroId, slot
			end
		end
	end
	return nil, nil
end

local function wornCount(data: Types.ProfileData): number
	local n = 0
	for _, hero in data.Heroes do
		for _ in hero.Equipped do
			n += 1
		end
	end
	return n
end

-- Bag slots in use: gear not worn + material slots (Formula.Bag) + box stacks. Same number as Formula.Bag.Used.
-- Only gear is refused when the bag is full: materials and boxes are always granted (rewards and purchases must
-- never be lost), so this can go past the capacity; nothing new fits until it is back under.
function Inventory.Count(player: Player): number
	local data = PlayerData.Data(player)
	if data == nil then
		return 0
	end
	return (totals[player] or 0)
		- wornCount(data)
		+ Formula.Bag.MaterialSlots(data.Stacks, Modifiers.Get(player).StackPct)
		+ Formula.Bag.BoxSlots(data.Boxes)
end

function Inventory.FreeSpace(player: Player): number
	if PlayerData.Data(player) == nil then
		return 0
	end
	return math.max(Game.InventoryCapacity - Inventory.Count(player), 0)
end

function Inventory.HasSpace(player: Player, n: number): boolean
	return Inventory.FreeSpace(player) >= n
end

function Inventory.CreateGear(player: Player, spec: GearSpec): Types.GearItem?
	local data = PlayerData.Data(player)
	if data == nil or Items.ById[spec.BaseId] == nil or Tiers.ById[spec.Tier] == nil then
		return nil
	end
	if not (Guard.Int(spec.Level, 1, 1e6) and Guard.Int(spec.Rebirth, 0, 1e4) and Guard.Finite(spec.GearScore)) then
		warn(`[Inventory] bad gear spec for {player.Name}`)
		return nil
	end
	if not Inventory.HasSpace(player, 1) then
		return nil
	end
	local uid = tostring(data.NextUid)
	data.NextUid += 1
	local item: Types.GearItem = {
		Uid = uid,
		BaseId = spec.BaseId,
		Tier = spec.Tier,
		Level = spec.Level,
		Rebirth = spec.Rebirth,
		GearScore = spec.GearScore,
		Plus = 0,
		Sockets = {},
		Enchants = {},
	}
	assert(data.Gear[uid] == nil, `[Inventory] uid collision {uid}`)
	data.Gear[uid] = item
	totals[player] = (totals[player] or 0) + 1
	Replication.Set(player, { "Gear", uid }, item)
	Replication.Set(player, { "NextUid" }, data.NextUid)
	return item
end

function Inventory.IsLocked(player: Player, uid: string): boolean
	local set = locks[player]
	return set ~= nil and set[uid] == true
end

-- Replaces the player's lock set (Trade owns the contents; pass {} to clear).
function Inventory.SetLocks(player: Player, uids: { string })
	local set: { [string]: boolean } = {}
	for _, uid in uids do
		set[uid] = true
	end
	if next(set) ~= nil then
		locks[player] = set
	else
		locks[player] = nil
	end
end

local function take(player: Player, uid: string): Types.GearItem?
	local data = PlayerData.Data(player)
	if data == nil then
		return nil
	end
	local item = data.Gear[uid]
	if item == nil or Inventory.WornBy(player, uid) ~= nil then
		return nil
	end
	data.Gear[uid] = nil
	totals[player] = (totals[player] or 1) - 1
	Replication.Set(player, { "Gear", uid }, nil)
	for _, listener in freedListeners do
		task.defer(listener, player)
	end
	return item
end

-- Removes a bag item (refuses worn and trade-locked items) and returns it.
function Inventory.RemoveGear(player: Player, uid: string): Types.GearItem?
	if Inventory.IsLocked(player, uid) then
		return nil
	end
	return take(player, uid)
end

-- Trade only: removes a bag piece even though it is locked (the trade that locked it is executing).
function Inventory.TakeForTrade(player: Player, uid: string): Types.GearItem?
	local set = locks[player]
	if set ~= nil then
		set[uid] = nil
	end
	return take(player, uid)
end

-- Trade only: stores a piece that came from another profile under a fresh uid of this profile. Returns the new uid.
function Inventory.Adopt(player: Player, item: Types.GearItem): string?
	local data = PlayerData.Data(player)
	if data == nil or not Inventory.HasSpace(player, 1) then
		return nil
	end
	local uid = tostring(data.NextUid)
	data.NextUid += 1
	local sockets: { Types.Socket } = {}
	for i, socket in item.Sockets do
		sockets[i] = { Kind = socket.Kind, Insert = socket.Insert }
	end
	local enchants: { Types.Enchant } = {}
	for i, enchant in item.Enchants do
		enchants[i] = { Id = enchant.Id }
	end
	local copy: Types.GearItem = {
		Uid = uid,
		BaseId = item.BaseId,
		Tier = item.Tier,
		Level = item.Level,
		Rebirth = item.Rebirth,
		GearScore = item.GearScore,
		Plus = item.Plus,
		Sockets = sockets,
		Enchants = enchants,
	}
	assert(data.Gear[uid] == nil, `[Inventory] uid collision {uid}`)
	data.Gear[uid] = copy
	totals[player] = (totals[player] or 0) + 1
	Replication.Set(player, { "Gear", uid }, copy)
	Replication.Set(player, { "NextUid" }, data.NextUid)
	return uid
end

-- Fires after a piece's plus / sockets / enchants change (worn stats need rebuilding).
function Inventory.OnGearChanged(listener: (Player, string) -> ())
	table.insert(changedListeners, listener)
end

local function gearChanged(player: Player, item: Types.GearItem)
	Replication.Set(player, { "Gear", item.Uid }, item)
	for _, listener in changedListeners do
		task.spawn(listener, player, item.Uid)
	end
end

function Inventory.SetPlus(player: Player, uid: string, plus: number): boolean
	if Inventory.IsLocked(player, uid) then
		return false
	end
	local item = Inventory.Get(player, uid)
	if item == nil or not Guard.Int(plus, 0, 100) then
		return false
	end
	item.Plus = plus
	gearChanged(player, item)
	return true
end

-- Appends one empty socket (Kind chosen later).
function Inventory.AddSocket(player: Player, uid: string): boolean
	if Inventory.IsLocked(player, uid) then
		return false
	end
	local item = Inventory.Get(player, uid)
	if item == nil then
		return false
	end
	table.insert(item.Sockets, {})
	gearChanged(player, item)
	return true
end

function Inventory.SetSocket(player: Player, uid: string, index: number, socket: Types.Socket): boolean
	if Inventory.IsLocked(player, uid) then
		return false
	end
	local item = Inventory.Get(player, uid)
	if item == nil or item.Sockets[index] == nil then
		return false
	end
	item.Sockets[index] = { Kind = socket.Kind, Insert = socket.Insert }
	gearChanged(player, item)
	return true
end

function Inventory.SetEnchants(player: Player, uid: string, enchants: { Types.Enchant }): boolean
	if Inventory.IsLocked(player, uid) then
		return false
	end
	local item = Inventory.Get(player, uid)
	if item == nil then
		return false
	end
	for _, enchant in enchants do
		if EnchantConfig.ById[enchant.Id] == nil then
			return false
		end
	end
	item.Enchants = enchants
	gearChanged(player, item)
	return true
end

function Inventory.StackCount(player: Player, id: string): number
	local data = PlayerData.Data(player)
	return if data ~= nil then data.Stacks[id] or 0 else 0
end

function Inventory.AddStack(player: Player, id: string, n: number): boolean
	local data = PlayerData.Data(player)
	if data == nil or Materials.ById[id] == nil or not Guard.Amount(n) then
		return false
	end
	if n == 0 then
		return true
	end
	local count = math.min((data.Stacks[id] or 0) + math.floor(n), Game.MaxCurrency)
	data.Stacks[id] = count
	Replication.Set(player, { "Stacks", id }, count)
	return true
end

function Inventory.SpendStack(player: Player, id: string, n: number): boolean
	local data = PlayerData.Data(player)
	if data == nil or not Guard.Amount(n) then
		return false
	end
	local have = data.Stacks[id] or 0
	if have < n then
		return false
	end
	local left = have - n
	if left > 0 then
		data.Stacks[id] = left
	else
		data.Stacks[id] = nil
	end
	Replication.Set(player, { "Stacks", id }, data.Stacks[id])
	return true
end

function Inventory.Start()
	PlayerData.OnLoaded(function(player, data)
		local n = 0
		for _ in data.Gear do
			n += 1
		end
		totals[player] = n
	end)
	Players.PlayerRemoving:Connect(function(player)
		totals[player] = nil
		locks[player] = nil
	end)
end

return Inventory
