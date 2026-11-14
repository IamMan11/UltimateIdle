--!strict
-- Owner of Heroes and Team: first pick, buying, xp/levels, equip/unequip, cached combat stats (rebuilt only when dirty).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Heroes = require(ReplicatedStorage.Shared.Config.Heroes)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Rebirth = require(ReplicatedStorage.Shared.Config.Rebirth)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)
local Guard = require(ServerScriptService.Server.Util.Guard)
local Replication = require(script.Parent.Replication)
local Currency = require(script.Parent.Currency)
local Inventory = require(script.Parent.Inventory)

local statCache: { [Player]: { [string]: Types.HeroStats } } = {}
local teamListeners: { (Player) -> () } = {}

local function newHero(class: Types.ClassId): Types.HeroState
	return { Class = class, Level = 1, Xp = 0, Advancement = 0, Equipped = {} }
end

local function syncHero(player: Player, heroId: string, hero: Types.HeroState)
	Replication.Set(player, { "Heroes", heroId }, hero)
end

local function notifyError(player: Player, key: string)
	Replication.Notify(player, "Error", key)
end

local Hero = {}

function Hero.MarkDirty(player: Player, heroId: string?)
	local cache = statCache[player]
	if cache == nil then
		return
	end
	if heroId == nil then
		table.clear(cache)
	else
		cache[heroId] = nil
	end
end

function Hero.GetStats(player: Player, heroId: string): Types.HeroStats?
	local data = PlayerData.Data(player)
	local hero = if data ~= nil then data.Heroes[heroId] else nil
	if data == nil or hero == nil then
		return nil
	end
	local cache = statCache[player]
	if cache == nil then
		cache = {}
		statCache[player] = cache
	end
	local cached = cache[heroId]
	if cached ~= nil then
		return cached
	end
	local gear: { Types.GearItem } = {}
	for _, uid in hero.Equipped do
		local item = data.Gear[uid]
		if item ~= nil then
			table.insert(gear, item)
		end
	end
	local stats = Formula.Stats.Hero(hero.Class, hero.Level, gear)
	cache[heroId] = stats
	return stats
end

-- Team as the sim needs it (heroes that no longer exist are skipped).
function Hero.GetTeam(player: Player): { Types.SimHero }
	local data = PlayerData.Data(player)
	local out: { Types.SimHero } = {}
	if data == nil then
		return out
	end
	for _, slot in data.Team do
		local hero = data.Heroes[slot.HeroId]
		local stats = Hero.GetStats(player, slot.HeroId)
		if hero ~= nil and stats ~= nil then
			table.insert(out, { Key = slot.HeroId, Class = hero.Class, Row = slot.Row, Stats = stats })
		end
	end
	return out
end

function Hero.OnTeamChanged(listener: (Player) -> ())
	table.insert(teamListeners, listener)
end

function Hero.LevelCap(data: Types.ProfileData): number
	return Rebirth.Get(data.Rebirth.Count).HeroLevelCap
end

-- Splits `amount` evenly between fielded heroes.
function Hero.AddXp(player: Player, amount: number)
	local data = PlayerData.Data(player)
	if data == nil or not Guard.Amount(amount) or #data.Team == 0 then
		return
	end
	local share = amount / #data.Team
	local cap = Hero.LevelCap(data)
	for _, slot in data.Team do
		local hero = data.Heroes[slot.HeroId]
		if hero ~= nil then
			local before = hero.Level
			hero.Level, hero.Xp =
				Formula.Progression.Apply(hero.Level, hero.Xp, share, cap, Formula.Progression.HeroXpToNext)
			if hero.Level ~= before then
				Hero.MarkDirty(player, slot.HeroId)
			end
			syncHero(player, slot.HeroId, hero)
		end
	end
end

local function chooseFirst(player: Player, class: string)
	if not RateLimit.Allow(player, "ChooseFirstHero") then
		return
	end
	local data = PlayerData.Data(player)
	if data == nil or next(data.Heroes) ~= nil or not Guard.OneOf(class, Game.StarterClasses) then
		return
	end
	local def = Heroes.ById[class]
	local hero = newHero(class :: Types.ClassId)
	data.Heroes[class] = hero
	data.Team = { { HeroId = class, Row = def.PreferredRow :: Types.Row } }
	syncHero(player, class, hero)
	Replication.Set(player, { "Team" }, data.Team)
	for _, listener in teamListeners do
		task.spawn(listener, player)
	end
end

local function buy(player: Player, class: string)
	if not RateLimit.Allow(player, "BuyHero") then
		return
	end
	local data = PlayerData.Data(player)
	local def = Heroes.ById[class]
	if data == nil or def == nil or data.Heroes[class] ~= nil or next(data.Heroes) == nil then
		return
	end
	if not Currency.Spend(player, "Gold", def.Price) then
		notifyError(player, "NotEnoughGold")
		return
	end
	local hero = newHero(class :: Types.ClassId)
	data.Heroes[class] = hero
	syncHero(player, class, hero)
end

local function equip(player: Player, heroId: string, uid: string, slot: string)
	if not RateLimit.Allow(player, "Equip") then
		return
	end
	local data = PlayerData.Data(player)
	if data == nil or not Guard.OneOf(slot, Items.GearSlots) then
		return
	end
	local hero = data.Heroes[heroId]
	local item = data.Gear[uid]
	if hero == nil or item == nil then
		return
	end
	local def = Items.ById[item.BaseId]
	if def == nil or Items.SlotOf[slot] ~= def.Slot then
		return
	end
	if hero.Level < item.Level then
		notifyError(player, "HeroLevelTooLow")
		return
	end
	if hero.Equipped[slot] == uid then
		return
	end
	local wornHero, wornSlot = Inventory.WornBy(player, uid)
	local occupied = hero.Equipped[slot] ~= nil
	-- Moving from another hero into an occupied slot sends the old piece to the bag: needs a free space.
	if wornHero ~= nil and occupied and not Inventory.HasSpace(player, 1) then
		notifyError(player, "BagFull")
		return
	end
	if wornHero ~= nil and wornSlot ~= nil then
		local other = data.Heroes[wornHero]
		other.Equipped[wornSlot] = nil
		Hero.MarkDirty(player, wornHero)
		syncHero(player, wornHero, other)
	end
	hero.Equipped[slot] = uid
	Hero.MarkDirty(player, heroId)
	syncHero(player, heroId, hero)
end

local function unequip(player: Player, heroId: string, slot: string)
	if not RateLimit.Allow(player, "Unequip") then
		return
	end
	local data = PlayerData.Data(player)
	local hero = if data ~= nil then data.Heroes[heroId] else nil
	if hero == nil or hero.Equipped[slot] == nil then
		return
	end
	if not Inventory.HasSpace(player, 1) then
		notifyError(player, "BagFull")
		return
	end
	hero.Equipped[slot] = nil
	Hero.MarkDirty(player, heroId)
	syncHero(player, heroId, hero)
end

function Hero.Start()
	Net.ChooseFirstHero:Server():On(chooseFirst)
	Net.BuyHero:Server():On(buy)
	Net.Equip:Server():On(equip)
	Net.Unequip:Server():On(unequip)
	Players.PlayerRemoving:Connect(function(player)
		statCache[player] = nil
	end)
end

return Hero
