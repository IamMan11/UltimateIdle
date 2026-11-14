--!strict
-- Analytics batching and anomaly thresholds (server only reads them; generous so only bugs/dupes trip them).

local Freeze = require(script.Parent.Parent.Freeze)

return Freeze({
	-- Economy events are summed per player and sent once per this many seconds (and on leave).
	FlushSeconds = 60,
	-- A progression event every this many new max levels.
	ProgressEvery = 10,
	-- Rolling window for earn-rate checks.
	WindowSeconds = 300,
	-- Gameplay gold above this many "gold-levels" (Formula.Economy) per minute of window is flagged.
	GoldLevelsPerMinute = 60,
	-- One gameplay gold grant above this many gold-levels is flagged on its own.
	GoldLevelsSingle = 3000,
	-- Ruby from non-purchase sources above this per window is flagged.
	RubyPerWindow = 3000,
	-- Gold arriving by trade above this many gold-levels (of the receiver) is logged.
	TradeGoldLevels = 5000,
	-- Rate-limit refusals per player per minute before a flag.
	RateLimitTripsPerMinute = 40,
	-- The same flag kind for one player is reported at most once per this many seconds.
	FlagCooldown = 300,
	-- Sources that are not gameplay earnings (excluded from the earn-rate check).
	NonGameplay = { "Offline", "Trade", "Shop", "Purchase", "Dev", "Reward", "Quest" },
	-- Currency source -> AnalyticsService transaction type (Enum.AnalyticsEconomyTransactionType names or custom).
	TransactionTypes = {
		Stage = "Gameplay",
		Loot = "Gameplay",
		Salvage = "Gameplay",
		Offline = "TimedReward",
		Quest = "TimedReward",
		Reward = "TimedReward",
		Shop = "Shop",
		Purchase = "IAP",
		Hero = "ContextualPurchase",
		SkillTree = "ContextualPurchase",
		Forge = "ContextualPurchase",
		Trade = "Trade",
	},
})
