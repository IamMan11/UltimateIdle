--!strict
-- Inserts put in the Upgrade slots (Enhance tab): which picks the bag still covers, adding one from the grid, and the kind + tier the grid is narrowed to.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Inserts = require(ReplicatedStorage.Shared.Config.Inserts)

export type Filter = { Kind: string?, Tier: string? }

local UpgradePick = {}

-- True for an insert that has a next tier to upgrade into.
function UpgradePick.Can(id: string): boolean
	local def = Inserts.ById[id]
	return def ~= nil and Inserts.NextTier[def.Tier] ~= nil
end

-- Drops picks the bag no longer covers (spent, traded, or used by the last upgrade).
function UpgradePick.Slots(data: Types.ProfileData, picked: { string }): { string }
	local used: { [string]: number } = {}
	local slots: { string } = {}
	for _, id in picked do
		local n = (used[id] or 0) + 1
		if n <= (data.Stacks[id] or 0) then
			used[id] = n
			table.insert(slots, id)
		end
	end
	return slots
end

-- Slots after clicking insert `id` in the grid; nil = nothing changes. Another kind or tier starts a new set.
function UpgradePick.Add(data: Types.ProfileData, slots: { string }, id: string): { string }?
	local def = Inserts.ById[id]
	if def == nil or not UpgradePick.Can(id) then
		return nil
	end
	local first = if slots[1] ~= nil then Inserts.ById[slots[1]] else nil
	if first ~= nil and (first.Kind ~= def.Kind or first.Tier ~= def.Tier) then
		return { id }
	end
	if #slots >= Inserts.UpgradeCount then
		return nil
	end
	local used = 0
	for _, other in slots do
		if other == id then
			used += 1
		end
	end
	if used >= (data.Stacks[id] or 0) then
		return nil
	end
	local copy = table.clone(slots)
	table.insert(copy, id)
	return copy
end

-- Kind + tier of the inserts already in the slots; empty slots = any upgradable insert.
function UpgradePick.Filter(slots: { string }): Filter
	local first = if slots[1] ~= nil then Inserts.ById[slots[1]] else nil
	return if first ~= nil then { Kind = first.Kind, Tier = first.Tier } else {}
end

return UpgradePick
