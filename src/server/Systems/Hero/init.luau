--!strict
-- Owner of Heroes and Team: first pick, buying, xp/levels, equip/unequip, team rows, class advancement, cached combat stats (rebuilt only when dirty).

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
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local Formation = require(ReplicatedStorage.Shared.Config.Formation)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)
local Guard = require(ServerScriptService.Server.Util.Guard)
local Replication = require(script.Parent.Replication)
local Currency = require(script.Parent.Currency)
local Inventory = require(script.Parent.Inventory)
local Modifiers = require(script.Parent.Modifiers)

export type TeamEntry = { HeroId: string, Row: string }

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
	local stats = Formula.Stats.Hero(hero.Class, hero.Level, gear, hero.Advancement)
	cache[heroId] = stats
	return stats
end

-- Team as the sim needs it: cached hero stats + formation bonus + account modifiers, unlocked skills.
-- Heroes that no longer exist are skipped.
function Hero.GetTeam(player: Player): { Types.SimHero }
	local data = PlayerData.Data(player)
	local out: { Types.SimHero } = {}
	if data == nil then
		return out
	end
	local members: { Formula.TeamMember } = {}
	local heroes: { Types.HeroState } = {}
	local keys: { string } = {}
	for _, slot in data.Team do
		local hero = data.Heroes[slot.HeroId]
		if hero ~= nil then
			table.insert(members, { Class = hero.Class :: string, Row = slot.Row :: string })
			table.insert(heroes, hero)
			table.insert(keys, slot.HeroId)
		end
	end
	local mods = Modifiers.Get(player)
	for i, hero in heroes do
		local base = Hero.GetStats(player, keys[i])
		if base ~= nil then
			table.insert(out, {
				Key = keys[i],
				Class = hero.Class,
				Row = members[i].Row :: Types.Row,
				Stats = Formula.Team.Apply(base, Formula.Team.FormationBonus(members, i), mods),
				Skills = Formula.Skills.Active(hero.Class, hero.Level, hero.Advancement),
			})
		end
	end
	return out
end

local function teamChanged(player: Player)
	for _, listener in teamListeners do
		task.spawn(listener, player)
	end
end

function Hero.OnTeamChanged(listener: (Player) -> ())
	table.insert(teamListeners, listener)
end

function Hero.LevelCap(data: Types.ProfileData): number
	return Rebirth.Get(data.Rebirth.Count).HeroLevelCap
end

-- Highest item level this hero may wear (rebirth + class advancement).
function Hero.WearCap(data: Types.ProfileData, hero: Types.HeroState): number
	return Rebirth.WearCap(data.Rebirth.Count, hero.Advancement)
end

-- Splits `amount` evenly between `heroIds` (the heroes that fought), or the current team when nil.
function Hero.AddXp(player: Player, amount: number, heroIds: { string }?)
	local data = PlayerData.Data(player)
	if data == nil or not Guard.Amount(amount) then
		return
	end
	local ids: { string } = {}
	if heroIds ~= nil then
		ids = heroIds
	else
		for _, slot in data.Team do
			table.insert(ids, slot.HeroId)
		end
	end
	if #ids == 0 then
		return
	end
	local share = amount / #ids
	local cap = Hero.LevelCap(data)
	for _, heroId in ids do
		local hero = data.Heroes[heroId]
		if hero ~= nil then
			local before = hero.Level
			hero.Level, hero.Xp =
				Formula.Progression.Apply(hero.Level, hero.Xp, share, cap, Formula.Progression.HeroXpToNext)
			if hero.Level ~= before then
				Hero.MarkDirty(player, heroId)
			end
			syncHero(player, heroId, hero)
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
	teamChanged(player)
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
	if item.Level > Hero.WearCap(data, hero) then
		notifyError(player, "WearCapTooLow")
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

-- Replaces the whole team. Applies from the next level (the running level keeps its sim).
local function setTeam(player: Player, entries: { TeamEntry })
	if not RateLimit.Allow(player, "SetTeam") then
		return
	end
	local data = PlayerData.Data(player)
	if data == nil or #entries == 0 then
		return
	end
	if #entries > Modifiers.Get(player).TeamSlots then
		notifyError(player, "TeamTooBig")
		return
	end
	local seen: { [string]: boolean } = {}
	local perRow: { [string]: number } = {}
	local team: { Types.TeamSlot } = {}
	for _, entry in entries do
		if data.Heroes[entry.HeroId] == nil or seen[entry.HeroId] or Formation.RowX[entry.Row] == nil then
			return
		end
		seen[entry.HeroId] = true
		perRow[entry.Row] = (perRow[entry.Row] or 0) + 1
		if perRow[entry.Row] > Formation.MaxPerRow then
			notifyError(player, "RowFull")
			return
		end
		table.insert(team, { HeroId = entry.HeroId, Row = entry.Row :: Types.Row })
	end
	data.Team = team
	Replication.Set(player, { "Team" }, team)
	Replication.Notify(player, "TeamSet", #team)
	teamChanged(player)
end

-- Next class advancement stage: hero level + gold + materials, all checked before anything is spent.
local function advance(player: Player, heroId: string)
	if not RateLimit.Allow(player, "Advance") then
		return
	end
	local data = PlayerData.Data(player)
	local hero = if data ~= nil then data.Heroes[heroId] else nil
	if data == nil or hero == nil then
		return
	end
	local stage = Classes.Stages[hero.Advancement + 1]
	if stage == nil then
		return
	end
	if hero.Level < stage.HeroLevel then
		notifyError(player, "HeroLevelTooLow")
		return
	end
	if not Currency.Has(player, "Gold", stage.Gold) then
		notifyError(player, "NotEnoughGold")
		return
	end
	for id, n in stage.Items do
		if Inventory.StackCount(player, id) < n then
			notifyError(player, "NotEnoughItems")
			return
		end
	end
	Currency.Spend(player, "Gold", stage.Gold)
	for id, n in stage.Items do
		Inventory.SpendStack(player, id, n)
	end
	hero.Advancement = stage.Index
	Hero.MarkDirty(player, heroId)
	syncHero(player, heroId, hero)
	Replication.Notify(player, "Advanced", { Hero = heroId, Stage = stage.Index })
end

function Hero.Start()
	Net.SetTeam:Server():On(setTeam)
	Net.Advance:Server():On(advance)
	Net.ChooseFirstHero:Server():On(chooseFirst)
	Net.BuyHero:Server():On(buy)
	Net.Equip:Server():On(equip)
	Net.Unequip:Server():On(unequip)
	Players.PlayerRemoving:Connect(function(player)
		statCache[player] = nil
	end)
end

return Hero
