--!strict
-- Bag slots (pure, shared so the UI counts what the server counts): units per slot of a material, slots a count takes, slots in use.

local Types = require(script.Parent.Parent.Types)
local Materials = require(script.Parent.Parent.Config.Materials)

local Bag = {}

-- Units of `id` that share one slot, with the skill tree's StackPct applied (never below 1).
function Bag.MaxStack(id: string, stackPct: number): number
	local def = Materials.ById[id]
	local base = if def ~= nil then def.MaxStack else 1
	return math.max(1, math.floor(base * (1 + stackPct)))
end

function Bag.Slots(count: number, maxStack: number): number
	return if count > 0 then math.ceil(count / maxStack) else 0
end

-- Slots taken by every material stack.
function Bag.MaterialSlots(stacks: { [string]: number }, stackPct: number): number
	local n = 0
	for id, count in stacks do
		n += Bag.Slots(count, Bag.MaxStack(id, stackPct))
	end
	return n
end

-- One slot per box stack (a stack's own size cap is Config.Boxes.Cap).
function Bag.BoxSlots(boxes: { [string]: number }): number
	local n = 0
	for _, count in boxes do
		if count > 0 then
			n += 1
		end
	end
	return n
end

-- Slots in use: gear not worn by a hero + material slots + box stacks.
function Bag.Used(data: Types.ProfileData, stackPct: number): number
	local n = 0
	for _ in data.Gear do
		n += 1
	end
	for _, hero in data.Heroes do
		for _ in hero.Equipped do
			n -= 1
		end
	end
	return n + Bag.MaterialSlots(data.Stacks, stackPct) + Bag.BoxSlots(data.Boxes)
end

return table.freeze(Bag)
