# Architecture

## 1. The DataModel is the architecture

Where an Instance lives decides who can see it, who can run it, and when it exists.

| Container | Replicated to clients | Use for |
| --- | --- | --- |
| `ServerScriptService` | No | Server scripts and server-only modules |
| `ServerStorage` | No | Server-only assets, templates, secrets, loot tables |
| `ReplicatedStorage` | Yes | Shared modules, types, remotes, client-visible assets |
| `ReplicatedFirst` | Yes, **before** the rest | Loading screen only. Keep it tiny |
| `StarterPlayer/StarterPlayerScripts` | Copied into each player once | Client bootstrap that survives respawn |
| `StarterPlayer/StarterCharacterScripts` | Copied into each character | Per-life character scripts |
| `StarterGui` | Copied into `PlayerGui` | UI |
| `Workspace` | Yes | Anything physically in the world |
| `Lighting` / `SoundService` / `MaterialService` | Yes (config) | Environment settings |

**The replication boundary test:** before putting a file in `ReplicatedStorage`, ask "may an exploiter read this?" Loot tables, drop rates, anti-cheat thresholds, admin lists, and server validation logic must not be there. Split a module rather than leaking it: shared *types* and *constants the client legitimately needs* go in shared; the rules stay on the server.

## 2. Script types

| Type | Runs |
| --- | --- |
| `Script` with `RunContext = Legacy` | Server, only in server containers |
| `Script` with `RunContext = Server` | Server, from anywhere in the DataModel |
| `Script` with `RunContext = Client` | Client, from anywhere — replaces most `LocalScript` uses |
| `LocalScript` | Client, only in client containers |
| `ModuleScript` | Wherever it is required |

Prefer: **thin bootstrap scripts, fat modules.** One `init.server.luau` and one `init.client.luau` that require and start systems. This makes ordering explicit and modules testable.

## 3. Folder layout

Small project:

```
src/
├── client/init.client.luau
├── server/init.server.luau
└── shared/
    ├── Types.luau
    └── Config.luau
```

Mid/large project — feature-oriented, because a feature change should touch one folder:

```
src/
├── client/
│   ├── init.client.luau
│   └── controllers/        one per feature, client side
├── server/
│   ├── init.server.luau
│   └── services/           one per feature, server side
└── shared/
    ├── types/
    ├── config/             balance numbers, no logic
    ├── net/                remote definitions shared by both sides
    └── util/
```

Or strictly per-feature when features are large and independent:

```
src/features/Inventory/{server,client,shared}/
src/features/Combat/{server,client,shared}/
```

Pick one and be consistent. Do not mix both schemes in one repo.

## 4. Service / Controller pattern

The dominant Roblox architecture. A **Service** is a server-side singleton owning one domain's authoritative logic. A **Controller** is its client-side counterpart owning presentation and input.

```lua
--!strict
-- ServerScriptService/Server/services/InventoryService.luau

local InventoryService = {}

local DataService        -- injected at Init, not required at the top
local inventories: { [Player]: { [string]: number } } = {}

function InventoryService.Init(deps: { DataService: any })
	DataService = deps.DataService
end

function InventoryService.Start()
	Players.PlayerRemoving:Connect(function(player)
		inventories[player] = nil
	end)
end

function InventoryService.GetCount(player: Player, itemId: string): number
	local inv = inventories[player]
	return inv and inv[itemId] or 0
end

function InventoryService.AddItem(player: Player, itemId: string, amount: number): boolean
	-- validation lives here, not in the remote handler
	if amount <= 0 or amount ~= amount // 1 then
		return false
	end
	local inv = inventories[player]
	if not inv then
		return false
	end
	inv[itemId] = (inv[itemId] or 0) + amount
	InventoryService.ItemChanged:Fire(player, itemId, inv[itemId])
	return true
end

return InventoryService
```

Two-phase startup avoids circular-require deadlocks:

1. `Init()` on every service — store dependencies, create state, **do not** use other services yet.
2. `Start()` on every service — connect events, begin running. All services now exist.

The bootstrap owns the order:

```lua
local services = { DataService, InventoryService, ShopService, CombatService }
for _, s in services do if s.Init then s.Init(registry) end end
for _, s in services do if s.Start then s.Start() end end
```

Not every feature needs both halves. A pure VFX system is client-only; a pure anti-cheat is server-only.

## 5. Component pattern (tags)

For behaviour attached to many world Instances, bind behaviour to a **tag**, not to a script inside every model.

```lua
local CollectionService = game:GetService("CollectionService")

local components: { [Instance]: Door } = {}

local function onAdded(instance: Instance)
	if components[instance] then return end
	if not instance:IsA("Model") then return end
	components[instance] = Door.new(instance)
end

local function onRemoved(instance: Instance)
	local c = components[instance]
	if c then
		c:Destroy()
		components[instance] = nil
	end
end

for _, instance in CollectionService:GetTagged("Door") do
	onAdded(instance)
end
CollectionService:GetInstanceAddedSignal("Door"):Connect(onAdded)
CollectionService:GetInstanceRemovedSignal("Door"):Connect(onRemoved)
```

Why this wins: no per-Instance script overhead, behaviour is versioned in one file, designers add behaviour by tagging in Studio, and it composes (a part can be `Door` + `Damaging` + `Streamable`).

Use **Attributes** for per-Instance configuration (`door:GetAttribute("OpenTime")`) — they replicate, are editable in Studio, are typed, and fire `GetAttributeChangedSignal`.

With `StreamingEnabled`, tagged parts appear and disappear at runtime. The added/removed handlers above are what make streaming safe — never assume `GetTagged` at startup is the full set.

## 6. Lifecycle and cleanup

Every system that creates resources owns their destruction. Use a cleanup collector (Maid / Janitor / Trove pattern — 40 lines, or a package):

```lua
local Trove = {}
Trove.__index = Trove

function Trove.new()
	return setmetatable({ _items = {} }, Trove)
end

function Trove:Add<T>(item: T): T
	table.insert(self._items, item)
	return item
end

function Trove:Clean()
	for i = #self._items, 1, -1 do
		local item = self._items[i]
		if typeof(item) == "RBXScriptConnection" then
			item:Disconnect()
		elseif typeof(item) == "Instance" then
			item:Destroy()
		elseif typeof(item) == "thread" then
			task.cancel(item)
		elseif type(item) == "function" then
			item()
		elseif type(item) == "table" and item.Destroy then
			item:Destroy()
		end
		self._items[i] = nil
	end
end

return Trove
```

Rules:

- The thing that creates a connection disconnects it.
- `Instance:Destroy()` disconnects connections **to** that Instance, but not connections that Instance's script made to *other* Instances. Those leak.
- Player-scoped state goes in a `{[Player]: ...}` table cleared on `PlayerRemoving`.
- Character-scoped state is cleared on `CharacterRemoving` / `Humanoid.Died`, not on respawn-detect hacks.
- Bind server shutdown work with `game:BindToClose(fn)` (you get ~30 s; in Studio, much less).

## 7. Signals

Engine events first. When a module needs to notify another module and no engine event fits, expose a signal **on the module**:

```lua
InventoryService.ItemChanged = Signal.new()   -- (player, itemId, newCount)
```

This makes the dependency visible at the call site. A global event bus (`Bus:On("something")`) hides who talks to whom and makes refactors unsafe — use it only when you genuinely need many-to-many decoupling, and document the event names in one file.

## 8. Dependency direction

```
feature/controller  →  service  →  util / config / types
```

Never the reverse, never a cycle. If two services need each other, one of these is true: the boundary is wrong (merge them), or there is a third concept hiding (extract it), or one should fire a signal the other listens to instead of calling it.

## 9. Config vs state

```lua
-- shared/config/Combat.luau
return table.freeze({
	BaseDamage = 10,
	CritMultiplier = 2,
	AttackCooldown = 0.6,
})
```

Static tuning is data, lives in `shared/config`, is frozen, and never mutates at runtime. Runtime state lives in the owning service. Persisted state is a third category — see `data-persistence.md`. Do not merge the three into one table.

## 10. When to reach for a framework

Knit popularised service/controller but is no longer actively developed — do not add it to a new project by default. Flamework (roblox-ts), Matter (ECS), and Lyra/ProfileStore (data) are live options with real users. Evaluate: maintenance activity, whether types are exported, debugging difficulty, and whether the project actually has the problem the framework solves. Hand-rolling the 100 lines of a service loader is usually cheaper than owning a framework dependency, and is what most production games do.
