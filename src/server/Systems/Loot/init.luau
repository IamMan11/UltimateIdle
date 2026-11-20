--!strict
-- Item rewards: per-level drop rolls, box contents, farm lump (expected counts, one roll), granting with auto-salvage/overflow, salvage remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local Boxes = require(ReplicatedStorage.Shared.Config.Boxes)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Rebirth = require(ReplicatedStorage.Shared.Config.Rebirth)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local DropTables = require(ServerScriptService.Server.Secret.DropTables)
local BoxTables = require(ServerScriptService.Server.Secret.BoxTables)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)
local Rng = require(ServerScriptService.Server.Util.Rng)
local Replication = require(script.Parent.Replication)
local Currency = require(script.Parent.Currency)
local Inventory = require(script.Parent.Inventory)

type GearSpec = Inventory.GearSpec

export type Bundle = {
	Gear: { GearSpec },
	Materials: { [string]: number },
	Boxes: { [string]: number },
}

export type Summary = {
	Gear: number,
	Salvaged: number,
	Gold: number,
	Materials: { [string]: number },
}

local SALVAGE_MATERIAL = "EnhanceStone"

local function emptyBundle(): Bundle
	return { Gear = {}, Materials = {}, Boxes = {} }
end

local function pool(rebirth: number, class: string?, boxOnly: boolean): { Items.ItemDef }
	local out: { Items.ItemDef } = {}
	for _, def in Items.List do
		local rebirthOk = def.Rebirths == nil or table.find(def.Rebirths, rebirth) ~= nil
		if rebirthOk and def.BoxOnly == boxOnly and (class == nil or def.Class == class) then
			table.insert(out, def)
		end
	end
	return out
end

local function addMaterial(bundle: Bundle, id: string, n: number)
	if n > 0 then
		bundle.Materials[id] = (bundle.Materials[id] or 0) + n
	end
end

local Loot = {}

function Loot.ItemLevel(stageLevel: number, rebirth: number): number
	return math.clamp(math.floor(stageLevel), 1, Rebirth.Get(rebirth).ItemLevelCap)
end

-- scoreFloor 0..1 skips the bottom of the tier's gear score range (boxes roll better).
function Loot.RollGear(
	rng: Rng.Rng,
	weights: { [string]: number },
	level: number,
	rebirth: number,
	scoreFloor: number,
	class: string?,
	boxOnlyChance: number
): GearSpec?
	local tierId = rng:Weighted(weights)
	local tier = if tierId ~= nil then Tiers.ById[tierId] else nil
	if tier == nil then
		return nil
	end
	local candidates = pool(rebirth, class, boxOnlyChance > 0 and rng:Chance(boxOnlyChance))
	if #candidates == 0 then
		candidates = pool(rebirth, class, false)
	end
	if #candidates == 0 then
		return nil
	end
	local def = candidates[rng:Int(1, #candidates)]
	local low = tier.GearScoreMin + (tier.GearScoreMax - tier.GearScoreMin) * scoreFloor
	return {
		BaseId = def.Id,
		Tier = tier.Id :: Types.Tier,
		Level = level,
		Rebirth = rebirth,
		GearScore = math.floor(rng:Range(low, tier.GearScoreMax) + 0.5),
	}
end

-- `kind` is a box kind (Normal / Boss / Class_X), not a stack key.
function Loot.RollBox(rng: Rng.Rng, kind: string, level: number, rebirth: number, into: Bundle)
	local box = Boxes.ById[kind]
	if box == nil then
		return
	end
	local tbl = BoxTables.Get(kind)
	for _ = 1, box.GearPerOpen do
		local spec = Loot.RollGear(rng, tbl.TierWeights, level, rebirth, tbl.ScoreFloor, box.Class, tbl.BoxOnlyChance)
		if spec ~= nil then
			table.insert(into.Gear, spec)
		end
	end
	for _, m in tbl.Materials do
		if rng:Chance(m.Chance) then
			addMaterial(into, m.Id, rng:Int(m.Min, m.Max))
		end
	end
end

-- Normal drops for one finished level (Progress mode): rolled per kill. `dropMult` scales every chance (relics).
function Loot.ForLevel(
	rng: Rng.Rng,
	stageLevel: number,
	rebirth: number,
	kills: { [string]: number },
	dropMult: number
): Bundle
	local bundle = emptyBundle()
	local tbl = DropTables.Get(rebirth)
	local level = Loot.ItemLevel(stageLevel, rebirth)
	for monsterId, count in kills do
		local def = Monsters.ById[monsterId]
		if def ~= nil then
			local gearChance = (if def.Boss then tbl.BossGearChance else tbl.GearChance) * dropMult
			local boxChance = (if def.Boss then tbl.BossBoxChance else tbl.NormalBoxChance) * dropMult
			local boxId = Boxes.Key(if def.Boss then "Boss" else "Normal", rebirth, Boxes.Band(level))
			for _ = 1, count do
				if rng:Chance(gearChance) then
					local spec = Loot.RollGear(rng, tbl.TierWeights, level, rebirth, 0, nil, 0)
					if spec ~= nil then
						table.insert(bundle.Gear, spec)
					end
				end
				if rng:Chance(boxChance) then
					bundle.Boxes[boxId] = (bundle.Boxes[boxId] or 0) + 1
				end
				for _, m in tbl.Materials do
					if rng:Chance(m.Chance * dropMult) then
						addMaterial(bundle, m.Id, rng:Int(m.Min, m.Max))
					end
				end
			end
		end
	end
	return bundle
end

-- Farm lump for cleared levels 1..lastLevel: expected counts per 10-level band, rolled once each. Boxes are opened into gear.
function Loot.FarmLump(rng: Rng.Rng, lastLevel: number, rebirth: number, dropMult: number): Bundle
	local bundle = emptyBundle()
	if lastLevel < 1 then
		return bundle
	end
	local tbl = DropTables.Get(rebirth)
	local band = 10
	for from = 1, lastLevel, band do
		local to = math.min(from + band - 1, lastLevel)
		local gear, normalBoxes, bossBoxes = 0, 0, 0
		local mats: { [string]: number } = {}
		for l = from, to do
			local normal, boss = Formula.Combat.KillsPerLevel(l)
			gear += (normal * math.min(tbl.GearChance * dropMult, 1) + boss * math.min(tbl.BossGearChance * dropMult, 1))
			normalBoxes += normal * math.min(tbl.NormalBoxChance * dropMult, 1)
			bossBoxes += boss * math.min(tbl.BossBoxChance * dropMult, 1)
			for _, m in tbl.Materials do
				local chance = math.min(m.Chance * dropMult, 1)
				mats[m.Id] = (mats[m.Id] or 0) + (normal + boss) * chance * (m.Min + m.Max) / 2
			end
		end
		for _ = 1, rng:Count(gear) do
			local level = Loot.ItemLevel(rng:Int(from, to), rebirth)
			local spec = Loot.RollGear(rng, tbl.TierWeights, level, rebirth, 0, nil, 0)
			if spec ~= nil then
				table.insert(bundle.Gear, spec)
			end
		end
		for _ = 1, rng:Count(normalBoxes) do
			Loot.RollBox(rng, "Normal", Loot.ItemLevel(rng:Int(from, to), rebirth), rebirth, bundle)
		end
		for _ = 1, rng:Count(bossBoxes) do
			Loot.RollBox(rng, "Boss", Loot.ItemLevel(rng:Int(from, to), rebirth), rebirth, bundle)
		end
		for id, expected in mats do
			addMaterial(bundle, id, rng:Count(expected))
		end
	end
	return bundle
end

function Loot.SalvageValue(tierId: string, level: number): (number, number)
	local tier = Tiers.ById[tierId]
	if tier == nil then
		return 0, 0
	end
	return math.floor(tier.SalvageGold * Formula.Scaling.Item(level)), tier.SalvageStones
end

-- Grants gear (auto-salvage filter first — see Types.Settings, then bag space; overflow is salvaged) and materials. Boxes are not handled here.
function Loot.Grant(player: Player, bundle: Bundle): Summary
	local summary: Summary = { Gear = 0, Salvaged = 0, Gold = 0, Materials = {} }
	local data = PlayerData.Data(player)
	if data == nil then
		return summary
	end
	local settings = data.Settings
	local stones = 0
	for _, spec in bundle.Gear do
		-- Auto-salvage needs all three: switch on, tier ticked, base on the list.
		local auto = settings.AutoSalvageOn
			and settings.AutoSalvage[spec.Tier] == true
			and settings.SalvageItems[spec.BaseId] == true
		local created = if auto then nil else Inventory.CreateGear(player, spec)
		if created ~= nil then
			summary.Gear += 1
		else
			local gold, s = Loot.SalvageValue(spec.Tier, spec.Level)
			summary.Gold += gold
			stones += s
			summary.Salvaged += 1
		end
	end
	if stones > 0 then
		bundle.Materials[SALVAGE_MATERIAL] = (bundle.Materials[SALVAGE_MATERIAL] or 0) + stones
	end
	for id, n in bundle.Materials do
		if Inventory.AddStack(player, id, n) then
			summary.Materials[id] = n
		end
	end
	Currency.Add(player, "Gold", summary.Gold, "Loot")
	return summary
end

local function salvage(player: Player, uids: { string })
	if not RateLimit.Allow(player, "Salvage") then
		return
	end
	if #uids > Game.SalvageBatchMax then
		return
	end
	local gold, stones, count = 0, 0, 0
	local seen: { [string]: boolean } = {}
	for _, uid in uids do
		if not seen[uid] then
			seen[uid] = true
			local held = Inventory.Get(player, uid)
			local item = if held ~= nil and held.Locked ~= true then Inventory.RemoveGear(player, uid) else nil
			if item ~= nil then
				local g, s = Loot.SalvageValue(item.Tier, item.Level)
				gold += g
				stones += s
				count += 1
			end
		end
	end
	if count == 0 then
		return
	end
	Currency.Add(player, "Gold", gold, "Salvage")
	Inventory.AddStack(player, SALVAGE_MATERIAL, stones)
	Replication.Notify(player, "Salvaged", { Count = count, Gold = gold, Stones = stones })
end

function Loot.Start()
	Net.Salvage:Server():On(salvage)
end

return Loot
