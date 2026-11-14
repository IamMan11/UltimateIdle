# Networking

## 1. Remotes are a public API

Every RemoteEvent/RemoteFunction is an endpoint an attacker can call with arbitrary arguments, at any rate, from any state. Define each one on paper first:

```
Name:        CollectCoin
Direction:   Client → Server
Payload:     coin: BasePart
Authority:   Server decides whether the coin is collectable and awards it
Validation:  is Instance, IsA BasePart, descendant of workspace.Coins,
             not already collected, within 12 studs of the player's root
Rate limit:  10 / second / player
Failure:     silently ignore (do not echo errors to the client)
```

## 2. Choosing the primitive

| Need | Use |
| --- | --- |
| Fire-and-forget, one direction | `RemoteEvent` |
| Client asks, needs an answer | `RemoteFunction` (server-side handler only) |
| Server needs an answer from a client | **Don't.** Use two `RemoteEvent`s with a request id |
| Read-only shared state | Attributes, `Value` objects, or replicated Instances |
| Many small updates per frame | Batch into one event per tick, or use `UnreliableRemoteEvent` |
| Positional/cosmetic updates that can be dropped | `UnreliableRemoteEvent` |

`RemoteFunction:InvokeClient` is a trap: the client can yield forever or error, hanging the server thread. There is no timeout. Never use it.

`UnreliableRemoteEvent` is unordered and may be dropped; payloads are size-limited. Use it for things like cosmetic effect pings, never for state the game depends on.

## 3. Structure

Define remotes in one place so both sides agree and neither creates them ad hoc:

```lua
--!strict
-- shared/net/Remotes.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local folder: Folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local function get(className: string, name: string): any
	if RunService:IsServer() then
		local r = folder:FindFirstChild(name)
		if not r then
			r = Instance.new(className)
			r.Name = name
			r.Parent = folder
		end
		return r
	end
	return folder:WaitForChild(name)
end

return {
	CollectCoin = get("RemoteEvent", "CollectCoin") :: RemoteEvent,
	RequestShopData = get("RemoteFunction", "RequestShopData") :: RemoteFunction,
}
```

Networking packages (Red, ByteNet, Blink, Zap) add typed schemas, batching, and buffer serialization on top. They are worth it when you have dozens of remotes or high-frequency traffic; they cost a dependency and often ship no Luau types. For a handful of remotes, plain remotes are clearer.

## 4. Server-side validation

Validate in this order, cheapest first, and **return silently** on failure:

```lua
Remotes.CollectCoin.OnServerEvent:Connect(function(player: Player, coin: any)
	-- 1. rate
	if not RateLimiter:Allow(player, "CollectCoin") then return end

	-- 2. type
	if typeof(coin) ~= "Instance" or not coin:IsA("BasePart") then return end

	-- 3. existence / location in the hierarchy the server controls
	local coinsFolder = workspace:FindFirstChild("Coins")
	if not coinsFolder or not coin:IsDescendantOf(coinsFolder) then return end

	-- 4. state
	if coin:GetAttribute("Collected") then return end

	-- 5. ownership / proximity — the server recomputes, never trusts a sent position
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	if (root.Position - coin.Position).Magnitude > 12 then return end

	-- 6. act
	coin:SetAttribute("Collected", true)
	InventoryService.AddItem(player, "Coin", 1)
	coin:Destroy()
end)
```

Never trust from the client: prices, damage numbers, reward amounts, cooldown completion, item ids the player doesn't own, target identity, positions, "I am an admin", elapsed time, RNG results.

Numbers need full checks: `typeof(n) == "number"`, `n == n` (rejects NaN), `n ~= math.huge`, integer-ness if required, and a range. `n > 0` alone passes `math.huge` and `1e308`.

Strings need a length cap before they go anywhere near a DataStore, a UI, or another player.

## 5. Rate limiting

```lua
--!strict
local RateLimiter = {}
local buckets: { [Player]: { [string]: { tokens: number, last: number } } } = {}

local LIMITS = table.freeze({
	CollectCoin = { rate = 10, burst = 15 },   -- per second, max tokens
	BuyItem = { rate = 2, burst = 3 },
})

function RateLimiter:Allow(player: Player, key: string): boolean
	local cfg = LIMITS[key]
	if not cfg then return false end

	local byPlayer = buckets[player]
	if not byPlayer then
		byPlayer = {}
		buckets[player] = byPlayer
	end

	local b = byPlayer[key]
	local now = os.clock()
	if not b then
		b = { tokens = cfg.burst, last = now }
		byPlayer[key] = b
	end

	b.tokens = math.min(cfg.burst, b.tokens + (now - b.last) * cfg.rate)
	b.last = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

game:GetService("Players").PlayerRemoving:Connect(function(p) buckets[p] = nil end)

return RateLimiter
```

Token-bucket, not a flat cooldown: it allows legitimate bursts while capping sustained abuse. Pick limits from real gameplay (how fast can a human actually do this?), then add headroom. Log sustained violations; don't ban on a single trip.

## 6. Replication model

What replicates automatically, server → client:

- Instance creation/destruction and parenting inside replicated containers
- Most property changes made by the server
- Attributes
- Physics state of parts, according to network ownership

What does **not** replicate:

- Client-made changes to most Instances (they stay local — this is why exploiters' local edits don't affect others, and why your client edits don't either)
- Anything in `ServerStorage`/`ServerScriptService`
- Module state, upvalues, tables

Client → server replication happens for: character/assembly physics the client owns, and remote calls. That is the entire attack surface plus network ownership.

## 7. Network ownership

The server can hand physics simulation of an unanchored assembly to a client for responsiveness:

```lua
part:SetNetworkOwner(player)      -- that client simulates it
part:SetNetworkOwner(nil)         -- server simulates it
part:SetNetworkOwnershipAuto()    -- engine decides by proximity
```

By default a player owns their own character. Consequences:

- A client can teleport its own character, change its speed, and fly. The server must *validate movement*, not assume it.
- Never set network ownership of a gameplay-critical object (a capture point, a boss, a vehicle carrying scoring logic) to a player unless you validate the result.
- Anchored parts have no owner. `SetNetworkOwner` errors on anchored or non-BasePart instances — guard with `:CanSetNetworkOwnership()`.

Server-side movement sanity check: sample position each second, compare distance travelled against `Humanoid.WalkSpeed` plus generous tolerance, and account for legitimate teleports by flagging them (`player:SetAttribute("Teleporting", true)`) so you do not false-positive your own code.

## 8. Bandwidth

Each replicated property change and each remote call costs bytes and CPU on both ends. At 50 players, a per-player per-frame remote is 3000 messages/second.

- **Batch**: one event per tick carrying an array beats N events.
- **Throttle**: UI numbers do not need 60 Hz. 5–10 Hz is usually invisible.
- **Shrink**: send ids, not strings; send deltas, not full state; send `Vector3int16`/quantized values for positions when precision allows; use `buffer` for large or frequent payloads.
- **Don't send what the client can derive.** Send "match ends at t=1234", not a countdown tick.
- Measure with the Network section of the Developer Console (F9) and MicroProfiler.

Tables sent over remotes are serialized: they must be pure data (no functions, no metatables, no mixed array/dictionary keys, no cyclic references) — the engine will error or silently drop otherwise.

## 9. Cross-server

| Need | Service | Notes |
| --- | --- | --- |
| Broadcast an event to all servers | `MessagingService:PublishAsync` / `SubscribeAsync` | Small payload cap (~1 KB), rate limited, **delivery is best-effort** — never use it as the only path for anything important |
| Shared short-lived state (queues, live leaderboards, locks) | `MemoryStoreService` (SortedMap, Queue, HashMap) | Fast, has TTL, quota scales with players |
| Durable state | `DataStoreService` | See `data-persistence.md` |
| Move players between places/servers | `TeleportService` | |

Teleporting:

```lua
local options = Instance.new("TeleportOptions")
options.ReservedServerAccessCode = code          -- for a private match server
options:SetTeleportData({ matchId = matchId })   -- convenience only
TeleportService:TeleportAsync(placeId, players, options)
```

**`TeleportData` is client-visible and can be forged on arrival in some flows.** For anything that grants value (a role, an item, a match slot), write the authoritative record to MemoryStore or a DataStore keyed by userId before teleporting, and read it on the destination server. Always handle `TeleportInitFailed` and retry with backoff.

Matchmaking pattern: queue in a MemoryStore SortedMap → a server claims N players atomically via `UpdateAsync` → `ReserveServer` → write match manifest to MemoryStore → teleport → destination reads the manifest.
