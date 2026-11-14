--!strict
-- Shared data shapes: save profile (schema v1), gear items, hero state, combat stats, timeline payload.

export type ClassId = "Warrior" | "Mage" | "Archer" | "Healer"
export type Tier = "Common" | "Uncommon" | "Rare"
export type Row = "Front" | "Middle" | "Back"
export type StageMode = "Progress" | "Farm"
export type SocketKind = "Gem" | "Artifact" | "Relic"
export type CurrencyId = "Gold" | "Ruby"
export type GearSlot =
	"MainHand"
	| "OffHand"
	| "Helmet"
	| "Armor"
	| "Pants"
	| "Boots"
	| "Bracelet1"
	| "Bracelet2"
	| "Ring1"
	| "Ring2"
-- What an item fits: Bracelet fits Bracelet1/2, Ring fits Ring1/2, the rest map 1:1 to a GearSlot.
export type SlotKind = "MainHand" | "OffHand" | "Helmet" | "Armor" | "Pants" | "Boots" | "Bracelet" | "Ring"

-- Kind is nil until the player picks one for an opened socket; Insert is the stack id placed in it.
export type Socket = {
	Kind: SocketKind?,
	Insert: string?,
}

export type Enchant = {
	Id: string,
	Value: number,
}

-- Base stats and descriptions live in Config.Items, keyed by BaseId.
export type GearItem = {
	Uid: string,
	BaseId: string,
	Tier: Tier,
	Level: number,
	Rebirth: number,
	GearScore: number,
	Plus: number,
	Sockets: { Socket },
	Enchants: { Enchant },
}

-- Hero id = ClassId (one hero per class for now).
export type HeroState = {
	Class: ClassId,
	Level: number,
	Xp: number,
	Advancement: number,
	Equipped: { [string]: string }, -- GearSlot -> gear Uid
}

export type TeamSlot = {
	HeroId: string,
	Row: Row,
}

export type StageProgress = {
	Level: number,
	MaxLevel: number,
	FarmLevel: number,
	LastFarmRound: number, -- levels cleared in the last finished Farm round (paid again if you leave Farm mid-round)
}

-- Rebirth = the rebirth being played (<= RebirthState.Count); ByRebirth key = tostring(rebirth).
export type StageState = {
	Mode: StageMode,
	Rebirth: number,
	ByRebirth: { [string]: StageProgress },
}

export type RebirthState = {
	Count: number,
	Points: number,
}

-- Per-second income averaged over recent online levels; offline pays a share of this.
export type Rates = {
	Gold: number,
	Xp: number,
}

-- Receipts: purchaseId -> os.time() granted, so ProcessReceipt never grants twice.
-- Owned: pass id -> true for passes granted through a gift rather than owned on the account.
export type Purchases = {
	Receipts: { [string]: number },
	Owned: { [string]: boolean },
}

export type Settings = {
	AutoSalvage: { [string]: boolean }, -- Tier -> salvage on drop
	AutoOpenBoxes: boolean,
	SkipWave: boolean,
}

-- Dictionaries keyed by string only: DataStore JSON turns sparse numeric keys into broken arrays.
export type ProfileData = {
	SchemaVersion: number,
	Gold: number,
	Ruby: number,
	AccountXp: number,
	AccountLevel: number,
	Heroes: { [string]: HeroState },
	Team: { TeamSlot },
	Gear: { [string]: GearItem },
	Stacks: { [string]: number },
	Boxes: { [string]: number }, -- Config.Boxes.Key(kind, rebirth, band) -> count
	Stage: StageState,
	Rebirth: RebirthState,
	SkillTree: { [string]: number },
	SkillOff: { [string]: boolean },
	Purchases: Purchases,
	LastSeen: number,
	OfflineRate: Rates,
	NextUid: number,
	Settings: Settings,
}

-- Final combat numbers for one hero, cached server-side until something marks it dirty.
export type HeroStats = {
	MaxHp: number,
	Atk: number,
	Def: number,
	AtkInterval: number,
	Range: number,
	Speed: number,
	Splash: number, -- extra targets hit per attack
	Heal: number, -- heal per cast (0 = never heals)
	Power: number, -- single number for UI comparisons
}

export type SimHero = {
	Key: string,
	Class: ClassId,
	Row: Row,
	Stats: HeroStats,
}

export type SimResult = {
	Won: boolean,
	Duration: number,
	Kills: { [string]: number }, -- monster id -> kills
	BossKills: number,
	Events: buffer,
	EventCount: number,
}

-- Sent once per level to the owning client.
export type TimelinePayload = {
	Level: number,
	Mode: StageMode,
	Rebirth: number,
	StartAt: number, -- workspace:GetServerTimeNow() when playback starts
	Duration: number,
	Won: boolean,
	Skip: boolean, -- all waves released at once (only on levels already cleared)
	Team: { { Key: string, Class: ClassId, Row: Row, MaxHp: number } },
	Events: buffer,
	EventCount: number,
}

-- One replicated change: path into ProfileData, then the new value (nil = removed).
export type Delta = { any }

return {}
