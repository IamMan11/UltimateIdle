--!strict
-- Owner of Boxes (stacks keyed kind:rebirth:band): receive (over cap = lost), open (bounded by bag space), convert 5 normal/boss -> 1 class box, timed auto-open.

local Players = game:GetService("Players")
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
local Modifiers = require(script.Parent.Modifiers)

-- One pending auto-open timer per player at most; nil = idle (nothing to open, no space, or switched off).
local autoThreads: { [Player]: thread } = {}
-- Set once the "bag full" notice was sent, so a stalled auto-open warns only once until it resumes.
local autoStalled: { [Player]: boolean } = {}

local Box = {}

function Box.Cap(player: Player, key: string): number
	local parsed = Boxes.Parse(key)
	if parsed == nil then
		return 0
	end
	return Boxes.Cap(parsed.Kind, Modifiers.Get(player).BoxCapPct)
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
		Box.Refresh(player)
	end
	return kept, n - kept
end

-- Opens up to `count` boxes of one stack, bounded by bag space. Returns how many opened.
local function openStack(player: Player, key: string, count: number, silent: boolean): number
	local data = PlayerData.Data(player)
	local parsed = Boxes.Parse(key)
	local def = if parsed ~= nil then Boxes.ById[parsed.Kind] else nil
	if data == nil or parsed == nil or def == nil then
		return 0
	end
	local have = data.Boxes[key] or 0
	local fits = Inventory.FreeSpace(player) // def.GearPerOpen
	local n = math.min(count, have, fits, Game.OpenBatchMax)
	if n <= 0 then
		if have > 0 and not silent then
			Replication.Notify(player, "Error", "BagFull")
		end
		return 0
	end
	set(player, key, have - n)
	local rng = Rng.new()
	local low, high = Boxes.BandRange(parsed.Band, parsed.Rebirth)
	local bundle: Loot.Bundle = { Gear = {}, Materials = {}, Boxes = {} }
	for _ = 1, n do
		Loot.RollBox(rng, parsed.Kind, rng:Int(low, high), parsed.Rebirth, bundle)
	end
	local summary = Loot.Grant(player, bundle)
	if not silent then
		Replication.Notify(player, "BoxOpened", { Box = key, Opened = n, Summary = summary })
	end
	return n
end

local function open(player: Player, key: string, count: number)
	if not RateLimit.Allow(player, "OpenBox") then
		return
	end
	openStack(player, key, count, false)
end

-- Auto-open target: first stack (by kind order, newest band first) whose open fits the bag; nil if none.
-- Second result: true when boxes exist but none fit (bag full).
local function nextAutoStack(player: Player): (string?, boolean)
	local data = PlayerData.Data(player)
	if data == nil then
		return nil, false
	end
	local free = Inventory.FreeSpace(player)
	local best: string? = nil
	local bestOrder, bestBand = math.huge, -1
	local blocked = false
	for key, count in data.Boxes do
		local parsed = Boxes.Parse(key)
		local def = if parsed ~= nil then Boxes.ById[parsed.Kind] else nil
		if parsed ~= nil and def ~= nil and count > 0 then
			if def.GearPerOpen > free then
				blocked = true
			elseif def.Order < bestOrder or (def.Order == bestOrder and parsed.Band > bestBand) then
				best, bestOrder, bestBand = key, def.Order, parsed.Band
			end
		end
	end
	return best, best == nil and blocked
end

local function autoEnabled(player: Player): boolean
	local data = PlayerData.Data(player)
	return data ~= nil and data.Settings.AutoOpenBoxes and Modifiers.Get(player).AutoOpen
end

local function autoTick(player: Player)
	autoThreads[player] = nil
	if not autoEnabled(player) then
		return
	end
	local key = nextAutoStack(player)
	if key ~= nil then
		openStack(player, key, 1, true)
	end
	Box.Refresh(player)
end

-- (Re)arms the auto-open timer if it is idle and there is something it can open. Cheap: no-op when armed.
function Box.Refresh(player: Player)
	if autoThreads[player] ~= nil or player.Parent ~= Players or not autoEnabled(player) then
		return
	end
	local key, bagFull = nextAutoStack(player)
	if key == nil then
		if bagFull and not autoStalled[player] then
			autoStalled[player] = true
			Replication.Notify(player, "Error", "AutoOpenBagFull")
		end
		return
	end
	autoStalled[player] = nil
	autoThreads[player] = task.delay(Modifiers.Get(player).AutoOpenInterval, autoTick, player)
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
	PlayerData.OnLoaded(function(player)
		Box.Refresh(player)
	end)
	Modifiers.OnChanged(Box.Refresh)
	Inventory.OnFreed(Box.Refresh)
	Players.PlayerRemoving:Connect(function(player)
		local thread = autoThreads[player]
		if thread ~= nil then
			task.cancel(thread)
		end
		autoThreads[player] = nil
		autoStalled[player] = nil
	end)
end

return Box
