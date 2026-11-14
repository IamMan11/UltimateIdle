--!strict
-- Owner of SkillTree (bought nodes) and SkillOff (switched-off toggle nodes): buy (no reset), toggle. Effects are read through Modifiers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local SkillTreeConfig = require(ReplicatedStorage.Shared.Config.SkillTree)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local RateLimit = require(ServerScriptService.Server.Util.RateLimit)
local Replication = require(script.Parent.Replication)
local Currency = require(script.Parent.Currency)
local Inventory = require(script.Parent.Inventory)
local Rebirth = require(script.Parent.Rebirth)
local Modifiers = require(script.Parent.Modifiers)
local Tutorial = require(script.Parent.Tutorial)

local SkillTree = {}

function SkillTree.Owns(data: Types.ProfileData, id: string): boolean
	return (data.SkillTree[id] or 0) > 0
end

-- Error key when the node cannot be bought right now, nil when it can.
function SkillTree.CheckBuy(player: Player, data: Types.ProfileData, def: SkillTreeConfig.NodeDef): string?
	if SkillTree.Owns(data, def.Id) then
		return "NodeOwned"
	end
	for _, req in def.Requires do
		if not SkillTree.Owns(data, req) then
			return "NodeLocked"
		end
	end
	local cost = def.Cost
	if not Currency.Has(player, "Gold", cost.Gold or 0) then
		return "NotEnoughGold"
	end
	local items: { [string]: number } = cost.Items or {}
	for id, n in items do
		if Inventory.StackCount(player, id) < n then
			return "NotEnoughItems"
		end
	end
	if Rebirth.Points(player) < (cost.RebirthPoints or 0) then
		return "NotEnoughPoints"
	end
	return nil
end

local function buy(player: Player, id: string)
	if not RateLimit.Allow(player, "BuyNode") then
		return
	end
	local data = PlayerData.Data(player)
	local def = SkillTreeConfig.ById[id]
	if data == nil or def == nil then
		return
	end
	local problem = SkillTree.CheckBuy(player, data, def)
	if problem ~= nil then
		Replication.Notify(player, "Error", problem)
		return
	end
	-- Everything was checked above and nothing yields between the checks and these spends.
	local cost = def.Cost
	Currency.Spend(player, "Gold", cost.Gold or 0, "SkillTree")
	local items: { [string]: number } = cost.Items or {}
	for itemId, n in items do
		Inventory.SpendStack(player, itemId, n)
	end
	Rebirth.SpendPoints(player, cost.RebirthPoints or 0)
	data.SkillTree[id] = 1
	Replication.Set(player, { "SkillTree", id }, 1)
	Modifiers.MarkDirty(player)
	Replication.Notify(player, "NodeBought", id)
	Tutorial.Event(player, "BuyNode")
end

local function toggle(player: Player, id: string, on: boolean)
	if not RateLimit.Allow(player, "ToggleNode") then
		return
	end
	local data = PlayerData.Data(player)
	local def = SkillTreeConfig.ById[id]
	if data == nil or def == nil or not def.Toggle or not SkillTree.Owns(data, id) then
		return
	end
	local wasOn = data.SkillOff[id] ~= true
	if wasOn == on then
		return
	end
	if on then
		data.SkillOff[id] = nil
	else
		data.SkillOff[id] = true
	end
	Replication.Set(player, { "SkillOff", id }, data.SkillOff[id])
	Modifiers.MarkDirty(player)
end

function SkillTree.Start()
	Net.BuyNode:Server():On(buy)
	Net.ToggleNode:Server():On(toggle)
end

return SkillTree
