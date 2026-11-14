# Monetization, Analytics & Live Ops

## 1. The three products

| Product | Purchased | Ownership | Use for |
| --- | --- | --- | --- |
| **Game Pass** | Once, permanent | Checked with `MarketplaceService:UserOwnsGamePassAsync` | VIP, permanent perks, extra slots |
| **Developer Product** | Repeatable | Not owned — you grant the effect | Currency packs, consumables, revives |
| **Subscription** | Recurring | `Player:GetSubscriptionStatusAsync` | Monthly perks |
| Avatar/UGC items, bundles | Marketplace | `MarketplaceService:PlayerOwnsAsset` | Cosmetics tied to the avatar |

## 2. `ProcessReceipt` — get this exactly right

This is the highest-stakes function in a monetized Roblox game. Robux is taken **before** your callback runs; if you return anything other than `PurchaseGranted`, Roblox will call you again later (including on a different server) until you do or the receipt expires — and if you grant twice you have given the item away free.

```lua
--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")

local receiptHistory = DataStoreService:GetDataStore("PurchaseHistory_v1")

local GRANTS: { [number]: (player: Player) -> boolean } = {
	[123456] = function(player) return CurrencyService.Add(player, 1000) end,
	[123457] = function(player) return InventoryService.AddItem(player, "Revive", 1) end,
}

local function processReceipt(info: { PlayerId: number, PurchaseId: string, ProductId: number, CurrencySpent: number })
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		-- player left; do NOT grant. Roblox retries when they return.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local grant = GRANTS[info.ProductId]
	if not grant then
		warn(`Unknown ProductId {info.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local key = `{info.PlayerId}_{info.PurchaseId}`
	local granted = false

	local ok, err = pcall(function()
		receiptHistory:UpdateAsync(key, function(alreadyHandled)
			if alreadyHandled then
				granted = true          -- idempotency: this receipt was already honoured
				return nil              -- cancel the write
			end
			granted = grant(player)     -- grant INSIDE the transaction
			return granted or nil
		end)
	end)

	if not ok then
		warn(`ProcessReceipt failed for {key}: {err}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Sink,
		"Robux", info.CurrencySpent, 0, Enum.AnalyticsEconomyTransactionType.IAP.Name, tostring(info.ProductId))

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = processReceipt
```

Rules:

- **Exactly one** `ProcessReceipt` assignment in the whole game. A second assignment silently replaces the first and purchases break.
- Key the idempotency record by `PurchaseId` (unique per purchase), not `ProductId`.
- The grant must be **durably recorded** before you return `PurchaseGranted`. If the player's profile save could fail after you return granted, you owe them an item you took money for.
- Return `NotProcessedYet` on any uncertainty — Roblox retries. Returning `PurchaseGranted` on a failed grant loses the player's money permanently.
- Prefer a profile-library-integrated purchase log if your data library offers one (ProfileStore and friends have patterns for this) — it removes the second DataStore round-trip.
- Test in a **published** place; `ProcessReceipt` behaviour in Studio is limited.

## 3. Game passes and prompts

```lua
-- cache ownership per session; UserOwnsGamePassAsync yields and is rate limited
local owns: { [Player]: { [number]: boolean } } = {}

local function ownsPass(player: Player, passId: number): boolean
	local byPlayer = owns[player]
	if byPlayer and byPlayer[passId] ~= nil then return byPlayer[passId] end
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if not ok then return false end
	owns[player] = byPlayer or {}
	owns[player][passId] = result
	return result
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
	if wasPurchased and owns[player] then owns[player][passId] = true end
end)
```

Never cache ownership across sessions in a way that can't be corrected, and always invalidate on `PromptGamePassPurchaseFinished`.

Prompts: `PromptProductPurchase`, `PromptGamePassPurchase`, `PromptSubscriptionPurchase`, `PromptPurchase` (avatar assets). Prompts are triggered from the client or server; the grant is always server-side.

## 4. Designing an economy

- **Sources and sinks.** Every currency needs both, and the ratio determines inflation. Write them down before implementing.
- **Soft currency** (earned) and **hard currency** (Robux-adjacent) should not be freely convertible in the direction that devalues purchases.
- Price anchoring: show the best-value pack next to a small one.
- Do not gate core progression behind payment in a way that makes the free game unfun — retention is the input to revenue.
- `PolicyService:GetPolicyInfoForPlayerAsync` — if `ArePaidRandomItemsRestricted` is true for that player, do not show loot boxes to them at all. Random paid items also need disclosed odds where required.
- Roblox takes a platform cut and DevEx has its own rate; do not quote specific percentages from memory — check the current Creator Hub monetization docs.

## 5. Analytics

`AnalyticsService` feeds the Creator Dashboard's built-in funnels and economy reports. Instrument from day one; retrofitting analytics after launch means a month of blind iteration.

```lua
AnalyticsService:LogOnboardingFunnelStepEvent(player, 2, "TutorialMovement")
AnalyticsService:LogFunnelStepEvent(player, "ShopPurchase", sessionId, 3, "ConfirmPressed")
AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Source,
	"Coins", 50, newBalance, Enum.AnalyticsEconomyTransactionType.Gameplay.Name)
AnalyticsService:LogProgressionEvent(player, "MainStory",
	Enum.AnalyticsProgressionType.Complete, 4, "Chapter1")
AnalyticsService:LogCustomEvent(player, "BossDefeated", 1, { difficulty = "hard" })
```

What to measure first: D1/D7 retention, average session length, tutorial funnel drop-off, first-purchase conversion, and the step where new players quit. The Creator Dashboard gives retention, engagement, and playtime without instrumentation — the funnels are what you must add.

## 6. Live ops

- **MessagingService** for global announcements and cross-server events; remember it is best-effort and rate limited.
- **Remote config**: keep tunable numbers in a DataStore or MemoryStore key that servers read at startup and refresh periodically, so you can change drop rates without a republish. Version the config and validate it before applying — a bad config is an outage.
- **Feature flags / A-B tests**: bucket by `userId % 100`, store the bucket on the profile so a player's experience is stable, and log the bucket with every analytics event.
- **Soft launch**: publish, test with a small audience, watch error rate and D1 before promoting.
- **Rollback plan**: keep the previous place version; Roblox retains version history in the Creator Dashboard. Know how to revert before you need to.
- **Error monitoring**: `ScriptContext.Error` (server) and `LogService.MessageOut` (client) feed a rate-limited reporter; the Creator Dashboard has an error report page. Alert on a spike, not on a single error.
- **Shutdown safety**: `game:BindToClose` flushes saves; a place update kicks every server, so always assume shutdown can happen mid-action.

## 7. Open Cloud

For tooling outside the game: Open Cloud REST APIs (with API keys or OAuth 2.0) cover DataStore read/write, `MessagingService` publish, place publishing, universe/place info, asset upload, and more. Use it for admin dashboards, CI publishing, support tooling, and right-to-erasure automation. Never put an Open Cloud key in a game script — it lives in your CI or backend.

## 8. Discovery basics that change the code

- The **icon and thumbnails** drive click-through; the first 30 seconds drive retention. Build a fast, clear onboarding — a 3-minute unskippable tutorial is a retention hole.
- Sort-ranking rewards qualified playtime and retention, so performance and first-session quality are monetization features.
- Badges (`BadgeService:AwardBadge`) and in-experience notifications drive return visits.
- Make the experience playable within seconds of joining: preload only what's needed, show the world while the rest loads.
