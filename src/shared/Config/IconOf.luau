--!strict
-- Icon lookups by game id: item base, material/insert, box stack, skill/ability, skill tree node, class (+ advancement/path), stage; nil = no icon.

local Icons = require(script.Parent.Icons)
local Boxes = require(script.Parent.Boxes)
local Scenery = require(script.Parent.Scenery)

type Icon = Icons.Icon

-- Class -> path -> icon key per advancement stage (same order as the names in Text).
local ADVANCED: { [string]: { { string } } } = {
	Warrior = { { "Knight", "Warlord" }, { "Guardian", "Paladin" } },
	Mage = { { "Sorcerer", "Archmage" }, { "Enchanter", "Sage" } },
	Archer = { { "Ranger", "Sharpshooter" }, { "Scout", "Warden" } },
	Healer = { { "Cleric", "Saint" }, { "Monk", "Templar" } },
}

local function get(key: string): Icon?
	local icon: Icon? = Icons[key]
	return icon
end

local IconOf = {}

function IconOf.Item(baseId: string): Icon?
	return get(baseId)
end

function IconOf.Material(id: string): Icon?
	return get(id)
end

-- Box stack key ("<Kind>:<rebirth>:<band>") or a bare box kind.
function IconOf.Box(key: string): Icon?
	local parsed = Boxes.Parse(key)
	return get("Box_" .. (if parsed ~= nil then parsed.Kind else key))
end

-- Hero skills and weapon abilities share the Skill_ prefix.
function IconOf.Skill(id: string): Icon?
	return get("Skill_" .. id)
end

function IconOf.Node(id: string): Icon?
	return get("Node_" .. id)
end

function IconOf.Class(classId: string, advancement: number?, path: number?): Icon?
	local byPath = ADVANCED[classId]
	local adv = advancement or 0
	if byPath ~= nil and adv > 0 then
		local names = byPath[path or 1] or byPath[1]
		local icon = get("Class_" .. names[math.min(adv, #names)])
		if icon ~= nil then
			return icon
		end
	end
	return get("Class_" .. classId)
end

-- Every stage uses the same scenery kit for now: its icon, else the generic flag.
function IconOf.Stage(_rebirth: number): Icon?
	return get("Stage_" .. Scenery.Kit.Name) or get("Stage")
end

function IconOf.Path(index: number): Icon?
	return get(if index == 2 then "Path_Guard" else "Path_Power")
end

return IconOf
