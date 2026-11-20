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

-- A power (trait) on a piece: Id = Config.Enchant.ById key. Value = old per-line roll, unused since traits carry fixed effects.
export type Enchant = {
	Id: string,
	Value: number?,
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
	Locked: boolean?, -- player lock: cannot be salvaged or used up in a socket merge
}

-- Hero id = ClassId (one hero per class for now).
export type HeroState = {
	Class: ClassId,
	Level: number,
	Xp: number,
	Advancement: number,
	Path: number?, -- advancement path (Config.Classes.Paths index), chosen with the first advancement; nil = path 1
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
	-- Level the player chose to stay on in Progress mode (1..MaxLevel): replayed win or lose, Level does not move. nil = advance normally.
	Pin: number?,
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
-- Owned: Config.Shop pass key -> true for passes granted through a gift rather than owned on the account.
-- GiftTo: gift product key -> recipient UserId picked before the prompt (read when the receipt arrives).
export type Purchases = {
	Receipts: { [string]: number },
	Owned: { [string]: boolean },
	GiftTo: { [string]: number },
}

-- Key = Period.Key of the period this progress belongs to; a different key means it has reset.
-- Progress is per quest Kind (one counter feeds every quest of that kind in the period).
export type QuestPeriod = {
	Key: string,
	Progress: { [string]: number },
	Claimed: { [string]: boolean },
}

export type QuestState = {
	Daily: QuestPeriod,
	Weekly: QuestPeriod,
	Monthly: QuestPeriod,
}

-- Season = Period.Key("Monthly"). Free/Paid: tostring(tier) -> claimed.
export type PassState = {
	Season: string,
	Points: number,
	Premium: boolean,
	Free: { [string]: boolean },
	Paid: { [string]: boolean },
}

-- Month = Period.Key("Monthly"); Bought: shop item id -> bought this month.
export type ShopState = {
	Month: string,
	Bought: { [string]: number },
}

-- Gold is in gold-level units (Formula.Economy.Gold); Boxes by box kind (key built at grant time).
export type Reward = {
	Ruby: number?,
	Gold: number?,
	Materials: { [string]: number }?,
	Boxes: { [string]: number }?,
}

export type Settings = {
	-- Auto-salvage (drops only): a drop is salvaged when AutoSalvageOn, its tier is ticked and its BaseId is on the list.
	AutoSalvage: { [string]: boolean }, -- Tier -> ticked
	AutoSalvageOn: boolean,
	SalvageItems: { [string]: boolean }, -- gear BaseId -> on the list
	AutoOpenBoxes: boolean,
	SkipWave: boolean,
	UiScale: number, -- one of Config.Game.UiScales (1 = auto size)
	LowDetail: boolean, -- fewer monsters drawn, no skill names over heads
	-- Floating window id (Config.Game.Windows) -> { centre x, centre y, width, height } as screen fractions; width = height = 0 means default size.
	Windows: { [string]: { number } },
}

export type TutorialState = {
	Step: number, -- index into Config.Tutorial.Steps of the step being shown
	Done: boolean,
	Rewarded: number, -- highest step already paid (replaying the tutorial pays nothing again)
}

export type DailyState = {
	Day: string, -- Period key (UTC day) of the last claim
	Streak: number, -- consecutive days claimed, 1 = first day
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
	Quests: QuestState,
	Pass: PassState,
	Shop: ShopState,
	LastSeen: number,
	OfflineRate: Rates,
	NextUid: number,
	Settings: Settings,
	Tutorial: TutorialState,
	Daily: DailyState,
	Codes: { [string]: boolean }, -- redeemed code ids
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
	Lifesteal: number, -- share of damage dealt healed back (artifacts)
	Crit: number, -- chance for a hit to deal Config.Inserts.CritMult damage (artifacts)
	Power: number, -- single number for UI comparisons
}

-- An unlocked active skill with advancement scaling already applied.
export type SimSkill = {
	Index: number, -- Config.Skills.List index
	Kind: string,
	Cooldown: number,
	Mult: number,
	Targets: number,
	Duration: number,
	Reduce: number,
	HpRatio: number,
	Threshold: number,
}

export type SimHero = {
	Key: string,
	Class: ClassId,
	Row: Row,
	Stats: HeroStats,
	Skills: { SimSkill },
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

-- What one side puts into a trade. Boxes keyed by Config.Boxes.Key.
export type TradeOffer = {
	Gear: { string },
	Stacks: { [string]: number },
	Boxes: { [string]: number },
	Gold: number,
	Ruby: number,
}

-- Trade as one side sees it (sent on every change; nil = no trade).
export type TradeView = {
	Id: number,
	PartnerId: number,
	PartnerName: string,
	Mine: TradeOffer,
	Theirs: TradeOffer,
	TheirGear: { [string]: GearItem }, -- partner's offered pieces, by their uid
	MeReady: boolean,
	ThemReady: boolean,
	MeConfirmed: boolean,
	ThemConfirmed: boolean,
	ConfirmAt: number, -- workspace:GetServerTimeNow() from which the final confirm is accepted
}

-- One replicated change: path into ProfileData, then the new value (nil = removed).
export type Delta = { any }

return {}
