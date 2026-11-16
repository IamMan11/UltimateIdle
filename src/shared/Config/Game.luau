--!strict
-- Account-wide constants: capacities, offline/AFK timing, team size, currency ids.

local Freeze = require(script.Parent.Parent.Freeze)

return Freeze({
	SchemaVersion = 4,
	InventoryCapacity = 500,
	-- Numbers stay plain doubles; anything above this is clamped so saves never hold inf.
	MaxCurrency = 1e300,
	Currencies = { "Gold", "Ruby" },
	OfflineShare = 0.2,
	-- Rate averaging: new level income weighs this much against the running average.
	OfflineRateBlend = 0.2,
	AfkRejoinSeconds = 19 * 60 + 30,
	BaseTeamSlots = 1,
	MaxTeamSlots = 4,
	StarterClasses = { "Warrior", "Mage", "Archer" },
	SalvageBatchMax = 100,
	OpenBatchMax = 100,
	-- UI size choices on the Settings page (multiplies the automatic scale).
	UiScales = { 0.85, 1, 1.15, 1.3 },
	-- Floating windows whose place and size are saved (Settings.Windows keys).
	Windows = { "Team", "Tree", "Inventory" },
})
