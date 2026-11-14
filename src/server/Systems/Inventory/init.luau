--!strict
-- Owner of Gear (wearables, by uid) and Stacks (materials): create/remove/stack with capacity checks. Other systems never write these tables.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Types = require(ReplicatedStorage.Shared.Types)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local Materials = require(ReplicatedStorage.Shared.Config.Materials)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local Guard = require(ServerScriptService.Server.Util.Guard)
local Replication = require(script.Parent.Replication)

export type GearSpec = {
	BaseId: string,
	Tier: Types.Tier,
	Level: number,
	Rebirth: number,
	GearScore: number,
}

-- Total gear entries (worn + bag) per player, kept in step with data.Gear.
local totals: { [Player]: number } = {}

local freedListeners: { (Player) -> () } = {}

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

-- Bag items (worn items do not count against capacity).
function Inventory.Count(player: Player): number
	local data = PlayerData.Data(player)
	if data == nil then
		return 0
	end
	return (totals[player] or 0) - wornCount(data)
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

-- Removes a bag item (refuses worn items) and returns it.
function Inventory.RemoveGear(player: Player, uid: string): Types.GearItem?
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
	end)
end

return Inventory
