--!strict
-- Player-facing strings: names for classes, items, materials, boxes, tiers, slots, and UI labels.

local Items = require(script.Parent.Config.Items)
local Boxes = require(script.Parent.Config.Boxes)

local CLASS = { Warrior = "Warrior", Mage = "Mage", Archer = "Archer", Healer = "Healer" }
local TIER = { Common = "Common", Uncommon = "Uncommon", Rare = "Rare" }
local SLOT = {
	MainHand = "Main hand",
	OffHand = "Off hand",
	Helmet = "Helmet",
	Armor = "Armor",
	Pants = "Pants",
	Boots = "Boots",
	Bracelet1 = "Bracelet",
	Bracelet2 = "Bracelet",
	Ring1 = "Ring",
	Ring2 = "Ring",
}
local MATERIAL = { EnhanceStone = "Enhance Stone", EnchantDust = "Enchant Dust", SocketCore = "Socket Core" }
local BOX = { Normal = "Box", Boss = "Boss Box" }
local MONSTER =
	{ Slime = "Slime", Goblin = "Goblin", SkeletonArcher = "Skeleton Archer", Orc = "Orc", OgreKing = "Ogre King" }
local ROW = { Front = "Front", Middle = "Middle", Back = "Back" }
local ABILITY = {
	Cleave = "Cleave: hits 1 extra target",
	Overload = "Overload: +15% attack",
	Pierce = "Pierce: +6 range",
	Blessing = "Blessing: +25% healing",
}

-- Item display names are built from Config: "<Class> <Base name>" plus "Ancient" for box-only weapons.
local ITEM_NAMES: { [string]: string } = {}
local BASE_NAMES: { [string]: { [string]: string } } = {
	Warrior = {
		MainHand = "Sword",
		OffHand = "Shield",
		Helmet = "Helm",
		Armor = "Plate",
		Pants = "Greaves",
		Boots = "Sabatons",
		Bracelet = "Bracer",
		Ring = "Band",
	},
	Mage = {
		MainHand = "Staff",
		OffHand = "Orb",
		Helmet = "Hood",
		Armor = "Robe",
		Pants = "Leggings",
		Boots = "Slippers",
		Bracelet = "Charm",
		Ring = "Signet",
	},
	Archer = {
		MainHand = "Bow",
		OffHand = "Quiver",
		Helmet = "Cap",
		Armor = "Jerkin",
		Pants = "Trousers",
		Boots = "Boots",
		Bracelet = "Armguard",
		Ring = "Loop",
	},
	Healer = {
		MainHand = "Wand",
		OffHand = "Tome",
		Helmet = "Circlet",
		Armor = "Vestment",
		Pants = "Skirt",
		Boots = "Sandals",
		Bracelet = "Rosary",
		Ring = "Halo",
	},
}
for _, def in Items.List do
	local base = BASE_NAMES[def.Class][def.Slot]
	ITEM_NAMES[def.Id] = if def.BoxOnly then `Ancient {base}` else base
end

local Text = {}

function Text.Class(id: string): string
	return (CLASS :: { [string]: string })[id] or id
end
function Text.Tier(id: string): string
	return (TIER :: { [string]: string })[id] or id
end
function Text.Slot(id: string): string
	return (SLOT :: { [string]: string })[id] or id
end
function Text.Item(baseId: string): string
	return ITEM_NAMES[baseId] or baseId
end
function Text.Material(id: string): string
	return (MATERIAL :: { [string]: string })[id] or id
end
function Text.Monster(id: string): string
	return (MONSTER :: { [string]: string })[id] or id
end
function Text.Row(id: string): string
	return (ROW :: { [string]: string })[id] or id
end
function Text.Ability(id: string): string
	return (ABILITY :: { [string]: string })[id] or id
end
local function boxKind(kind: string): string
	local named = (BOX :: { [string]: string })[kind]
	if named ~= nil then
		return named
	end
	local class = string.match(kind, "^Class_(%a+)$")
	if class ~= nil then
		return `{Text.Class(class)} Box`
	end
	return kind
end

-- Accepts a bare kind ("Boss") or a stack key ("Boss:0:2" -> "Boss Box R0 Lv 26-50").
function Text.Box(key: string): string
	local kind, r, b = string.match(key, "^([%w_]+):(%d+):(%d+)$")
	if kind == nil then
		return boxKind(key)
	end
	local band = tonumber(b) or 1
	return `{boxKind(kind)} R{r} Lv {(band - 1) * Boxes.BandSize + 1}-{band * Boxes.BandSize}`
end

Text.UI = table.freeze({
	ChooseHeroTitle = "Choose your first hero",
	ChooseHeroBody = "Other heroes can be bought with gold later.",
	Choose = "Choose",
	Gold = "Gold",
	Ruby = "Ruby",
	Level = "Level",
	Wave = "Wave",
	SkipWave = "Skip wave",
	SkipOn = "Skip wave: ON",
	SkipWaiting = "Skip wave: ON (clear this level first)",
	SkipOff = "Skip wave: OFF",
	CamLane = "View: lane",
	CamWalk = "View: walk",
	Cam2D = "2D",
	Cam3D = "3D",
	ModeProgress = "Mode: Progress",
	ModeFarm = "Mode: Farm",
	FarmLocked = "Farm unlocks at level 200",
	Heroes = "Heroes",
	Bag = "Bag",
	Boxes = "Boxes",
	Settings = "Settings",
	Close = "Close",
	Cancel = "Cancel",
	Buy = "Buy",
	Owned = "Owned",
	Equip = "Equip",
	Unequip = "Unequip",
	Salvage = "Salvage",
	SalvageSelected = "Salvage selected",
	Select = "Select",
	Search = "Search name or @tag",
	Open = "Open",
	OpenAll = "Open all",
	Convert = "Convert",
	Empty = "Empty",
	AutoSalvage = "Auto-salvage on drop",
	Won = "Cleared",
	Lost = "Team defeated",
	Offline = "While you were away",
	Dev = "Dev",
	EquippedMark = "[E]",
})

Text.Error = table.freeze({
	NotEnoughGold = "Not enough gold",
	HeroLevelTooLow = "Hero level is too low for this item",
	BagFull = "Bag is full",
	BoxFull = "That box stack is full",
	NotEnoughBoxes = "Not enough boxes",
	FarmLocked = "Farm unlocks at level 200",
	BadBox = "Those boxes cannot be converted",
} :: { [string]: string })

return table.freeze(Text)
