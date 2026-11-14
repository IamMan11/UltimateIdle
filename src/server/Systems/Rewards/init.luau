--!strict
-- Turns a Config reward (Ruby, gold-level units, materials, box kinds) into real grants for one player; checks box room first.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Types = require(ReplicatedStorage.Shared.Types)
local Formula = require(ReplicatedStorage.Shared.Formula)
local Boxes = require(ReplicatedStorage.Shared.Config.Boxes)
local PlayerData = require(ServerScriptService.Server.Data.PlayerData)
local Currency = require(script.Parent.Currency)
local Inventory = require(script.Parent.Inventory)
local Box = require(script.Parent.Box)
local Loot = require(script.Parent.Loot)

-- What a reward is worth for this player right now (gold scaled, box kinds turned into stack keys).
export type Resolved = {
	Ruby: number,
	Gold: number,
	Materials: { [string]: number },
	Boxes: { [string]: number },
}

local Rewards = {}

function Rewards.BestLevel(data: Types.ProfileData): number
	local best = 1
	for _, progress in data.Stage.ByRebirth do
		best = math.max(best, progress.MaxLevel)
	end
	return best
end

-- Reward boxes come from the highest rebirth owned, banded by the best level reached there.
function Rewards.BoxKey(data: Types.ProfileData, kind: string): string
	local rebirth = data.Rebirth.Count
	local progress = data.Stage.ByRebirth[tostring(rebirth)]
	local level = if progress ~= nil then progress.MaxLevel else 1
	return Boxes.Key(kind, rebirth, Boxes.Band(Loot.ItemLevel(level, rebirth)))
end

function Rewards.Resolve(data: Types.ProfileData, reward: Types.Reward): Resolved
	local out: Resolved = { Ruby = reward.Ruby or 0, Gold = 0, Materials = {}, Boxes = {} }
	if reward.Gold ~= nil then
		out.Gold = Formula.Economy.Gold(reward.Gold, Rewards.BestLevel(data))
	end
	if reward.Materials ~= nil then
		for id, n in reward.Materials do
			out.Materials[id] = n
		end
	end
	if reward.Boxes ~= nil then
		for kind, n in reward.Boxes do
			local key = Rewards.BoxKey(data, kind)
			out.Boxes[key] = (out.Boxes[key] or 0) + n
		end
	end
	return out
end

-- False + error key when a box stack has no room for the whole reward (nothing is granted then).
function Rewards.CanGrant(player: Player, reward: Types.Reward): (boolean, string?)
	local data = PlayerData.Data(player)
	if data == nil then
		return false, nil
	end
	for key, n in Rewards.Resolve(data, reward).Boxes do
		if (data.Boxes[key] or 0) + n > Box.Cap(player, key) then
			return false, "BoxFull"
		end
	end
	return true, nil
end

-- `source` = Config.Analytics.TransactionTypes key for the currency part.
function Rewards.Grant(player: Player, reward: Types.Reward, source: string): Resolved?
	local data = PlayerData.Data(player)
	if data == nil then
		return nil
	end
	local resolved = Rewards.Resolve(data, reward)
	if resolved.Ruby > 0 then
		Currency.Add(player, "Ruby", resolved.Ruby, source)
	end
	if resolved.Gold > 0 then
		Currency.Add(player, "Gold", resolved.Gold, source)
	end
	for id, n in resolved.Materials do
		Inventory.AddStack(player, id, n)
	end
	for key, n in resolved.Boxes do
		Box.Grant(player, key, n)
	end
	return resolved
end

return Rewards
