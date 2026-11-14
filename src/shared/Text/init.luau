--!strict
-- Player-facing strings: names for classes, items, materials, inserts, traits, boxes, tiers, slots, skills, advancements, skill tree nodes, UI labels; phase 6 strings in Text.Eco.

local Items = require(script.Parent.Config.Items)
local Boxes = require(script.Parent.Config.Boxes)
local Skills = require(script.Parent.Config.Skills)
local SkillTree = require(script.Parent.Config.SkillTree)
local Types = require(script.Parent.Types)
local Account = require(script.Parent.Config.Account)
local Inserts = require(script.Parent.Config.Inserts)

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
local MATERIAL: { [string]: string } = {
	EnhanceStone = "Enhance Stone",
	EnchantDust = "Enchant Dust",
	SocketCore = "Socket Core",
	AncientShard = "Ancient Shard",
	GemAtk = "Fury Gem",
	GemHp = "Life Gem",
	GemDef = "Guard Gem",
	ArtLifesteal = "Vampire Fang",
	ArtCrit = "Hawk Eye",
	ArtSplash = "Twin Blade",
	RelicGold = "Golden Idol",
	RelicXp = "Sage Scroll",
	RelicDrop = "Lucky Charm",
}
local SOCKET_KIND = { Gem = "Gem", Artifact = "Artifact", Relic = "Relic" }
local TRAIT: { [string]: string } = {
	AtkPct = "Attack",
	HpPct = "HP",
	DefPct = "Defense",
	AtkSpeed = "Attack speed",
	MoveSpeed = "Move speed",
}
local INSERT_STAT: { [string]: string } = {
	Atk = "attack",
	MaxHp = "HP",
	Def = "defense",
	Lifesteal = "lifesteal",
	Crit = "crit chance",
	GoldPct = "gold (team)",
	XpPct = "xp (team)",
	DropPct = "drop chance (team)",
}
local BOX = { Normal = "Box", Boss = "Boss Box" }
local MONSTER =
	{ Slime = "Slime", Goblin = "Goblin", SkeletonArcher = "Skeleton Archer", Orc = "Orc", OgreKing = "Ogre King" }
local ROW = { Front = "Front", Middle = "Middle", Back = "Back" }
local SKILL: { [string]: string } = {
	IronSkin = "Iron Skin",
	PowerStrike = "Power Strike",
	ShieldWall = "Shield Wall",
	ArcaneFocus = "Arcane Focus",
	Fireball = "Fireball",
	Meteor = "Meteor",
	QuickDraw = "Quick Draw",
	AimedShot = "Aimed Shot",
	ArrowRain = "Arrow Rain",
	Grace = "Grace",
	MassHeal = "Mass Heal",
	Resurrect = "Resurrect",
}
local ADVANCEMENT: { [string]: { string } } = {
	Warrior = { "Knight", "Warlord" },
	Mage = { "Sorcerer", "Archmage" },
	Archer = { "Ranger", "Sharpshooter" },
	Healer = { "Cleric", "Saint" },
}
local NODE: { [string]: string } = {
	c_atk1 = "Sharpen",
	c_squad1 = "Squad I",
	c_hp1 = "Vitality",
	c_def1 = "Bulwark",
	c_squad2 = "Squad II",
	c_berserk = "Berserk",
	c_atk2 = "Keen Edge",
	c_squad3 = "Squad III",
	e_gold1 = "Coin Sense",
	e_offline1 = "Night Shift",
	e_xp1 = "Study",
	e_gold2 = "Merchant",
	e_veteran = "Veteran",
	e_offline2 = "Dream Work",
	s_boxcap1 = "Big Pockets",
	s_autoopen = "Auto Opener",
	s_boxcap2 = "Deep Pockets",
	s_autoopen2 = "Quick Hands",
	s_autoopen3 = "Blur Hands",
}
local BRANCH = { Combat = "Combat", Economy = "Economy", System = "System" }
local EFFECT_PCT: { [string]: string } = {
	AtkPct = "attack",
	HpPct = "HP",
	DefPct = "defense",
	GoldPct = "gold",
	XpPct = "xp",
	DropPct = "drop chance",
	OfflineShare = "offline earnings (of online rate)",
	BoxCapPct = "box stack size",
}

local function pct(v: number): string
	local n = math.floor(math.abs(v) * 100 + 0.5)
	return `{if v < 0 then "-" else "+"}{n}%`
end
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
	return MATERIAL[id] or id
end
function Text.SocketKind(id: string): string
	return (SOCKET_KIND :: { [string]: string })[id] or id
end

-- "Attack +10%" / "Move speed +2".
function Text.Trait(enchant: Types.Enchant): string
	local name = TRAIT[enchant.Id] or enchant.Id
	return if enchant.Id == "MoveSpeed" then `{name} +{enchant.Value}` else `{name} +{enchant.Value}%`
end

-- What one insert does, e.g. "+3% lifesteal" or "+2 attack (x item level)".
function Text.InsertEffect(id: string): string
	local def = Inserts.ById[id]
	if def == nil then
		return id
	end
	local stat = INSERT_STAT[def.Stat] or def.Stat
	if def.Kind == "Gem" then
		return `+{def.Value} {stat} (grows with item level)`
	elseif def.Stat == "Splash" then
		return `+{def.Value} extra target`
	end
	return `{pct(def.Value)} {stat}`
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
function Text.Skill(id: string): string
	return SKILL[id] or id
end

-- "Warrior" before advancing, then the stage name ("Knight", "Warlord").
function Text.Advancement(class: string, advancement: number): string
	local names = ADVANCEMENT[class]
	if advancement <= 0 or names == nil then
		return Text.Class(class)
	end
	return names[math.min(advancement, #names)]
end

function Text.Node(id: string): string
	return NODE[id] or id
end

function Text.Branch(id: string): string
	return (BRANCH :: { [string]: string })[id] or id
end

function Text.Effect(effect: SkillTree.Effect): string
	local kind, v = effect.Kind, effect.Value
	if kind == "TeamSlots" then
		return `+{v} team slot`
	elseif kind == "AutoOpen" then
		return `Auto-open boxes every {v}s`
	elseif kind == "AutoOpenSpeed" then
		return `Auto-open {math.floor(1 / v * 10 + 0.5) / 10}x faster`
	end
	return `{pct(v)} {EFFECT_PCT[kind] or kind}`
end

-- Skill description from its scaled numbers (`r` = Formula.Skills.Resolve result).
function Text.SkillDesc(def: Skills.SkillDef, r: Types.SimSkill, power: number): string
	if def.Kind == "Passive" then
		local b = def.Passive
		local parts = {}
		if b ~= nil then
			if b.AtkPct then
				table.insert(parts, `{pct(b.AtkPct * power)} attack`)
			end
			if b.HpPct then
				table.insert(parts, `{pct(b.HpPct * power)} HP`)
			end
			if b.DefPct then
				table.insert(parts, `{pct(b.DefPct * power)} defense`)
			end
			if b.HealPct then
				table.insert(parts, `{pct(b.HealPct * power)} healing`)
			end
			if b.IntervalPct then
				table.insert(parts, `{pct(-b.IntervalPct * power)} attack speed`)
			end
		end
		return `Passive: {table.concat(parts, ", ")}`
	end
	local cd = `{math.floor(r.Cooldown * 10 + 0.5) / 10}s cooldown`
	if def.Kind == "Damage" then
		local who = if r.Targets > 0
			then `up to {r.Targets} target{if r.Targets > 1 then "s" else ""}`
			else "every enemy in range"
		return `Hits {who} for {math.floor(r.Mult * 100 + 0.5)}% attack · {cd}`
	elseif def.Kind == "Shield" then
		return `Team takes {math.floor(r.Reduce * 100 + 0.5)}% less damage for {r.Duration}s · {cd}`
	elseif def.Kind == "HealAll" then
		return `Heals every ally for {math.floor(r.Mult * 100 + 0.5)}% heal power when one drops under {math.floor(
			r.Threshold * 100
		)}% HP · {cd}`
	elseif def.Kind == "Revive" then
		return `Revives a fallen ally at {math.floor(r.HpRatio * 100 + 0.5)}% HP · {cd}`
	end
	return cd
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

Text.Eco = require(script.Economy)({ Material = Text.Material, Box = Text.Box })

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
	FarmLocked = "Farm unlocks at level " .. tostring(Account.Unlocks.Farm.StageLevel or 0),
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
	Team = "Team",
	Tree = "Skill Tree",
	Skills = "Skills",
	Gear = "Gear",
	Apply = "Apply",
	Reset = "Reset",
	Remove = "Remove",
	Bench = "Not in team",
	TeamHint = "Drag a hero onto a row, or select one and click a row. Changes apply from the next level.",
	Advance = "Advance",
	AdvanceMax = "Fully advanced",
	Locked = "Locked",
	On = "ON",
	Off = "OFF",
	AutoOpen = "Auto-open boxes",
	AutoOpenLocked = "Auto-open boxes: unlock in the skill tree",
	RebirthPoints = "Rebirth points",
	Unlocks = "Unlocks at hero level",
	Forge = "Forge",
	Rebirth = "Rebirth",
	Enhance = "Enhance",
	Sockets = "Sockets",
	Enchant = "Enchant",
	PickItem = "Pick an item on the left",
	EnhanceNote = "Failure keeps the current plus. Gold and materials are used either way.",
	EnhanceMax = "Fully enhanced",
	AddSocket = "Add a socket",
	MergeHint = "Merge a duplicate (same item, tier and socket count). The duplicate is destroyed.",
	NoDuplicates = "No duplicate to merge",
	SocketsMax = "All sockets open",
	NoInserts = "None in bag",
	EnchantNote = "Rerolls every trait line. Current traits are replaced.",
	NoTraits = "No traits",
	Before = "Before",
	After = "After",
	PlayRebirth = "Rebirth to play",
	PlayHint = "Lower rebirths are easier and drop their own items. Applies from the next level.",
	RebirthMaxed = "Highest rebirth reached",
	RebirthKeeps = "Nothing is reset. Caps go up and monsters in the new rebirth are tougher.",
})

Text.Error = table.freeze({
	NotEnoughGold = "Not enough gold",
	HeroLevelTooLow = "Hero level is too low for this item",
	BagFull = "Bag is full",
	BoxFull = "That box stack is full",
	NotEnoughBoxes = "Not enough boxes",
	FarmLocked = "Farm unlocks at level " .. tostring(Account.Unlocks.Farm.StageLevel or 0),
	BadBox = "Those boxes cannot be converted",
	WearCapTooLow = "Advance this hero's class to wear items of that level",
	TeamTooBig = "Not enough team slots (unlock more in the skill tree)",
	RowFull = "That row is full",
	NodeOwned = "Already bought",
	NodeLocked = "Buy the connected node first",
	NotEnoughItems = "Not enough materials",
	NotEnoughPoints = "Not enough rebirth points",
	AutoOpenBagFull = "Auto-open paused: bag is full",
	RebirthMax = "Highest rebirth reached",
	RebirthLocked = "Clear the required level first",
	MaxPlus = "Already at max plus",
	MaterialWorn = "Unequip the duplicate first",
	SocketsFull = "All sockets are open",
	WrongSocketKind = "That insert does not fit this socket kind",
	SocketTaken = "Remove the current insert first",
	ItemInTrade = "That item is in an open trade",
	QuestClaimed = "Already claimed",
	QuestNotDone = "Quest not finished yet",
	NeedPremium = "Unlock the premium pass first",
	PassOwned = "You already own this pass",
	NotForSale = "Not available yet",
	GiftNoTarget = "That player is not in this server",
	GiftOwned = "They already own this pass",
	PremiumOwned = "Premium is already active this season",
	QuotaReached = "Monthly limit reached",
	NotEnoughRuby = "Not enough Ruby",
	TradeUnavailable = "Trade unavailable",
	TradeLocked = "Trading unlocks at account level " .. tostring(Account.Unlocks.Trade.AccountLevel or 0),
	TradePolicy = "Trading is not available for this account",
	TradePartnerLocked = "That player cannot trade yet",
	TradeBusy = "Already in a trade",
	TradeExpired = "Trade request expired",
	TradeTooMany = "Too many things in one offer",
	TradeMissing = "Something in an offer is no longer available",
	TradeWorn = "Unequip items before trading them",
	TradeBagFull = "Not enough bag space for this trade",
	TradeBoxFull = "A box stack would go over its limit",
	TradeNotReady = "Both sides must be ready (wait a moment after changes)",
	TradeEmpty = "Both offers are empty",
} :: { [string]: string })

return table.freeze(Text)
