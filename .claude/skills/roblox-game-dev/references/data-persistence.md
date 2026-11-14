# Data Persistence

Losing player data is the worst bug a Roblox game can ship. Treat this file as mandatory reading before writing any save system.

## 1. Use a proven library, not raw DataStores

For player profiles, **use ProfileStore** (by loleris; the successor to ProfileService, which the author has stopped developing). Alternatives with real usage: Lyra, Keep, Suphi's DataStore. Raw `DataStoreService` is appropriate for leaderboards, global counters, and non-critical stores — not for the main player profile.

What a profile library gives you that you will otherwise re-implement badly:

- **Session locking** — only one server can hold a player's profile at a time. Without it, two servers (player rejoining fast, or teleporting) both load and both save, and one save wins. This is the single most common cause of item/currency loss.
- Automatic periodic autosave and save-on-leave.
- Retry with backoff, and `BindToClose` handling.
- Data schema/reconciliation against a default template.
- Protection against saving a profile that failed to load (the classic "player's data wiped to defaults" bug).

```lua
--!strict
local ProfileStore = require(ServerPackages.ProfileStore)

local TEMPLATE = {
	Coins = 0,
	Level = 1,
	Inventory = {},
	Version = 3,
}

local Store = ProfileStore.New("PlayerData_v1", TEMPLATE)
local profiles: { [Player]: any } = {}

local function onPlayerAdded(player: Player)
	local profile = Store:StartSessionAsync(`{player.UserId}`, {
		Cancel = function() return player.Parent ~= Players end,
	})

	if not profile then
		player:Kick("Could not load your data. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)      -- GDPR association
	profile:Reconcile()                   -- fill in new template fields
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your data session ended. Please rejoin.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	Migrations.run(profile.Data)
	profiles[player] = profile
end
```

**If the profile fails to load, kick. Never let the player play on default data** — they will earn progress that is then overwritten or lost, and you will get the support tickets.

## 2. Raw DataStore rules, when you do use them

```lua
local ok, err = pcall(function()
	store:UpdateAsync(key, function(old)
		local data = old or defaults()
		data.Coins += amount
		return data
	end)
end)
```

- **`UpdateAsync`, not `GetAsync` + `SetAsync`.** The latter is a read-modify-write race: two servers both read 100, both write 110, one increment is lost. `UpdateAsync` is atomic per key.
- Returning `nil` from the transform function cancels the write.
- The transform function **must not yield** and must be side-effect free (it can be called more than once).
- Always `pcall`. Always handle failure: retry with exponential backoff and jitter, cap the attempts, and log.
- Check budget before bursts: `DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)`.
- `game:BindToClose` to flush saves on shutdown.
- `DataStoreService:GetDataStore(name)` — cache the store object; don't call it per request.

## 3. Limits to design against

Verify current numbers in the docs (`cloud-services/data-stores/error-codes-and-limits`); as of writing:

| Limit | Value |
| --- | --- |
| Value size per key | 4 MB (4,194,304 characters) |
| Data store name / key / scope length | 50 characters each |
| Read throughput | 25 MB/min per experience |
| Write throughput | 4 MB/min per experience |
| Request budget (read) | 300 + 40 × CCU per minute |
| Request budget (write) | 300 + 20 × CCU per minute |
| Request budget (list) | 300 + 2 × CCU per minute |
| Queue depth before throttle errors | 30 requests |
| Total storage per experience | 500 MB + 1 MB × lifetime users |

Design consequences:

- A profile is a few KB, not a few hundred. Do not store the whole world, chat logs, or per-session telemetry in it.
- If a player can accumulate unbounded items, cap the inventory or paginate across keys.
- Autosave every ~60 s per player is fine at normal CCU; every 5 s is not.
- Serialize compactly: ids not names, arrays not verbose dictionaries, and a `Version` field.

## 4. Schema migration

Every profile carries a version. Migrations run once, in order, at load:

```lua
local Migrations = {}

local steps: { (data: any) -> () } = {
	[1] = function(d) d.Inventory = d.Inventory or {} end,
	[2] = function(d)
		d.Cosmetics = {}
		for id, n in d.Inventory do
			if COSMETIC_IDS[id] then d.Cosmetics[id] = n; d.Inventory[id] = nil end
		end
	end,
	[3] = function(d) d.Coins = math.floor(d.Coins) end,
}

function Migrations.run(data)
	local v = data.Version or 0
	for i = v + 1, #steps do
		steps[i](data)
	end
	data.Version = #steps
end

return Migrations
```

Rules: migrations are append-only, never edited after release; they must be idempotent-safe; test with a copy of real old data before shipping. Never rename the DataStore to "start fresh" on a live game.

## 5. Ordered data and leaderboards

`OrderedDataStore` for numeric ranking only (integer values, no tables). Pattern:

- Write the score to the OrderedDataStore on meaningful change, not every tick.
- Read the top N with `GetSortedAsync(false, pageSize)` and cache it for 60+ seconds — every server reading live burns the list budget.
- Reset a seasonal leaderboard by switching to a new store name keyed by season, never by deleting keys one by one.
- For live-updating leaderboards, MemoryStore SortedMap is the right tool; OrderedDataStore is the durable snapshot.

## 6. MemoryStore

Ephemeral, fast, cross-server, TTL-based. Use for matchmaking queues, live leaderboards, rate limits that must be global, and cross-server locks.

- `SortedMap` — ranked or keyed data, supports atomic `UpdateAsync`.
- `Queue` — producer/consumer with invisibility timeout; `ReadAsync` then `RemoveAsync` the claimed items.
- `HashMap` — simple key/value.
- Every item needs an explicit expiration. Quota scales with CCU; a single-server test will not reveal a quota problem.
- MemoryStore is **not durable**. Anything that must survive must also be in a DataStore.

## 7. Data and the law

- `Profile:AddUserId(userId)` (or the equivalent `DataStoreSetOptions:SetMetadata` / `UserIds` argument on `SetAsync`) associates a key with a user so Roblox's right-to-erasure tooling can find it.
- Handle the right-to-erasure requests Roblox forwards (they arrive as messages to the experience owner; larger teams automate this with Open Cloud).
- Do not store personal information beyond what Roblox already provides. No emails, no off-platform identifiers, no chat transcripts keyed to a user without a reason.

## 8. Failure playbook

| Symptom | Cause | Fix |
| --- | --- | --- |
| Progress reverts after rejoin | No session lock; two servers saved | Session-locking library |
| Data wiped to defaults | Saved after a failed load | Never save a profile that did not load; kick instead |
| Currency lost on purchase | `GetAsync`+`SetAsync` race | `UpdateAsync` |
| Throttle errors at peak | Budget exceeded | Check budget, batch, increase autosave interval |
| Data missing after shutdown | No `BindToClose` | Bind and flush |
| Works in Studio, fails live | Studio API access off, or different budget | Enable "Enable Studio Access to API Services"; test in a published place |
| Slowly growing save size | Unbounded array append | Cap and prune |
