--!strict
-- Wearable gear bases: slot kind, class label, level-1 stats at gear score 100, tags, weapon ability, rebirth/box availability.

local Freeze = require(script.Parent.Parent.Freeze)

export type ItemStats = {
	MaxHp: number?,
	Atk: number?,
	Def: number?,
	Speed: number?, -- flat, does not scale with level
}

export type ItemDef = {
	Id: string,
	Slot: string, -- SlotKind
	Class: string,
	Stats: ItemStats,
	Tags: { string },
	Ability: string?, -- weapon ability id, disabled when worn by another class
	Rebirths: { number }?, -- nil = drops in every rebirth
	BoxOnly: boolean,
}

-- SlotKind -> the GearSlots it may occupy.
local SLOTS: { [string]: { string } } = {
	MainHand = { "MainHand" },
	OffHand = { "OffHand" },
	Helmet = { "Helmet" },
	Armor = { "Armor" },
	Pants = { "Pants" },
	Boots = { "Boots" },
	Bracelet = { "Bracelet1", "Bracelet2" },
	Ring = { "Ring1", "Ring2" },
}

local GEAR_SLOTS =
	{ "MainHand", "OffHand", "Helmet", "Armor", "Pants", "Boots", "Bracelet1", "Bracelet2", "Ring1", "Ring2" }

local SLOT_OF: { [string]: string } = {}
for kind, slots in SLOTS do
	for _, slot in slots do
		SLOT_OF[slot] = kind
	end
end

local BASE_STATS: { [string]: ItemStats } = {
	MainHand = { Atk = 6 },
	OffHand = { Def = 3, MaxHp = 20 },
	Helmet = { MaxHp = 25, Def = 2 },
	Armor = { MaxHp = 40, Def = 4 },
	Pants = { MaxHp = 30, Def = 3 },
	Boots = { MaxHp = 15, Speed = 1 },
	Bracelet = { Atk = 3 },
	Ring = { Atk = 2, MaxHp = 10 },
}

-- Per class: base name per slot kind and weapon ability.
local CLASS_GEAR: { [string]: { Names: { [string]: string }, Ability: string } } = {
	Warrior = {
		Ability = "Cleave",
		Names = {
			MainHand = "Sword",
			OffHand = "Shield",
			Helmet = "Helm",
			Armor = "Plate",
			Pants = "Greaves",
			Boots = "Sabatons",
			Bracelet = "Bracer",
			Ring = "Band",
		},
	},
	Mage = {
		Ability = "Overload",
		Names = {
			MainHand = "Staff",
			OffHand = "Orb",
			Helmet = "Hood",
			Armor = "Robe",
			Pants = "Leggings",
			Boots = "Slippers",
			Bracelet = "Charm",
			Ring = "Signet",
		},
	},
	Archer = {
		Ability = "Pierce",
		Names = {
			MainHand = "Bow",
			OffHand = "Quiver",
			Helmet = "Cap",
			Armor = "Jerkin",
			Pants = "Trousers",
			Boots = "Boots",
			Bracelet = "Armguard",
			Ring = "Loop",
		},
	},
	Healer = {
		Ability = "Blessing",
		Names = {
			MainHand = "Wand",
			OffHand = "Tome",
			Helmet = "Circlet",
			Armor = "Vestment",
			Pants = "Skirt",
			Boots = "Sandals",
			Bracelet = "Rosary",
			Ring = "Halo",
		},
	},
}

local SLOT_TAG: { [string]: string } = {
	MainHand = "weapon",
	OffHand = "offhand",
	Helmet = "helmet",
	Armor = "armor",
	Pants = "pants",
	Boots = "boots",
	Bracelet = "bracelet",
	Ring = "ring",
}

local list: { ItemDef } = {}
local byId: { [string]: ItemDef } = {}

local function add(def: ItemDef)
	assert(byId[def.Id] == nil, `duplicate item id {def.Id}`)
	table.insert(list, def)
	byId[def.Id] = def
end

for _, class in { "Warrior", "Mage", "Archer", "Healer" } do
	local gear = CLASS_GEAR[class]
	for _, kind in { "MainHand", "OffHand", "Helmet", "Armor", "Pants", "Boots", "Bracelet", "Ring" } do
		local name = gear.Names[kind]
		add({
			Id = `{class}_{kind}`,
			Slot = kind,
			Class = class,
			Stats = BASE_STATS[kind],
			Tags = { string.lower(name) },
			Ability = if kind == "MainHand" then gear.Ability else nil,
			Rebirths = nil,
			BoxOnly = false,
		})
	end
	-- Box-only weapon: stronger base, same ability.
	local weapon = BASE_STATS.MainHand
	add({
		Id = `{class}_MainHand_Ancient`,
		Slot = "MainHand",
		Class = class,
		Stats = { Atk = (weapon.Atk :: number) * 1.4 },
		Tags = { string.lower(gear.Names.MainHand), "ancient" },
		Ability = gear.Ability,
		Rebirths = nil,
		BoxOnly = true,
	})
end

return Freeze({
	List = list,
	ById = byId,
	Slots = SLOTS,
	SlotOf = SLOT_OF,
	GearSlots = GEAR_SLOTS,
	SlotTag = SLOT_TAG,
	-- Wrong-class gear keeps this share of its stats and loses its weapon ability.
	ClassMismatchMultiplier = 0.5,
})
